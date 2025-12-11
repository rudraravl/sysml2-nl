"""
LangChain + MoE synthesis

Pipeline:
- Build RAG context from dataset examples and spec chunks (local JSONL).
- Compose System/Human messages (same template as agent_rag).
- Query multiple experts (EXPERT_MODELS):
  * gemini-2.5-pro (direct via Google Generative AI)
  * openrouter models: openai/gpt-5, anthropic/claude-sonnet-4.5, meta-llama/llama-4-maverick:free
- Ask gemini-2.5-pro to synthesize a single best SysML v2 model, using the candidates as additional context.
- Output only SysML v2 code; no markdown fences.

One-shot: pass requirement as CLI arg. Batch: no args → read nl2sysml/dataset.json and write results to nl2sysml/result_rag_moe.
"""

from pathlib import Path
import os
import json
import re
from typing import List, Tuple, Optional
from urllib import request as _req

from dotenv import load_dotenv
import google.generativeai as genai

# Import compiler interface
try:
    from compiler_interface import check_code, is_compiler_available, CompilerResult
    COMPILER_AVAILABLE = True
except ImportError:
    COMPILER_AVAILABLE = False
    # Create dummy functions/classes for fallback
    def check_code(code: str, syntax_only: bool = False):
        class DummyResult:
            def __init__(self):
                self.errors = []
                self.is_valid = False
            @property
            def error_count(self):
                return 0
            def format_errors(self):
                return "No errors found."
        return DummyResult()
    def is_compiler_available():
        return False
    class CompilerResult:
        def __init__(self, errors=None, is_valid=False):
            self.errors = errors or []
            self.is_valid = is_valid
        @property
        def error_count(self):
            return len(self.errors)
        def format_errors(self):
            return "No errors found."


# Expert models (one per line)
EXPERT_MODELS = [
    "gemini-2.5-pro",
    "openai/gpt-5",
    "anthropic/claude-sonnet-4.5",
    
    "meta-llama/llama-4-maverick",
    # "meta-llama/llama-4-maverick:free",
]

# Combiner model for the final synthesis step
COMBINER_MODEL = "anthropic/claude-sonnet-4.5"

# Heuristic reliability rating per expert family (0–10)
EXPERT_MODELS_RATING = {
    "gemini": 5,
    "gpt": 7,
    "claude": 10,
    "llama": 5,
}

# Compiler configuration
MAX_REFINEMENT_ITERATIONS = int(os.getenv("MAX_REFINEMENT_ITERATIONS", "2"))
COMPILER_SYNTAX_ONLY = os.getenv("COMPILER_SYNTAX_ONLY", "false").lower() == "true"

def _model_group(model_name: str) -> str:
    if model_name == "gemini-2.5-pro":
        return "gemini"
    if model_name.startswith("openai/"):
        return "gpt"
    if model_name.startswith("anthropic/"):
        return "claude"
    if model_name.startswith("meta-llama/"):
        return "llama"
    return "other"


def _load_env():
    load_dotenv(Path(__file__).parent.parent / ".env")
    gkey = os.getenv("GEMINI_API_KEY")
    if not gkey:
        raise RuntimeError("GEMINI_API_KEY missing in environment/.env")
    genai.configure(api_key=gkey)
    return gkey, os.getenv("OPENROUTER_API_KEY")


def _tokenize(s: str) -> List[str]:
    return [t for t in re.split(r"[^A-Za-z0-9_]+", s.lower()) if t]


def _similarity(a: str, b: str) -> float:
    ta, tb = set(_tokenize(a)), set(_tokenize(b))
    if not ta or not tb:
        return 0.0
    inter = len(ta & tb)
    return inter / (len(ta) ** 0.5 * len(tb) ** 0.5)


def _collect_examples(root: Path, limit: int = 300) -> List[Tuple[str, str]]:
    pairs = []
    data_dir = root / "dataset" / "data"
    if not data_dir.exists():
        return pairs
    for p in sorted(data_dir.glob("*/*")):
        if p.suffix == ".txt":
            sysml = p.with_suffix(".sysml")
            if sysml.exists():
                try:
                    txt = p.read_text(encoding="utf-8")
                    code = sysml.read_text(encoding="utf-8")
                except Exception:
                    continue
                pairs.append((txt, code))
                if len(pairs) >= limit:
                    break
    return pairs


def _rag_context(nl_prompt: str, root: Path, k: int = 3) -> str:
    # Dataset examples
    blocks = []
    examples = _collect_examples(root)
    if examples:
        scored = sorted(
            ((ex, _similarity(nl_prompt, ex[0])) for ex in examples),
            key=lambda x: x[1], reverse=True,
        )
        top_data = [e for (e, s) in scored[:5] if s > 0]
        for i, (txt, code) in enumerate(top_data, 1):
            lines = []
            for ln in code.splitlines():
                t = ln.strip()
                if not t or t.startswith("//"):
                    continue
                lines.append(ln)
                if len(lines) >= 80:
                    break
            code_snip = "\n".join(lines)
            blocks.append(
                f"Example {i} NL:\n{txt.strip()}\n\nExample {i} SysML:\n{code_snip}\n---"
            )

    # Spec chunks
    spec_jsonl = root / "nl2sysml" / "spec_index" / "chunks.jsonl"
    if spec_jsonl.exists():
        try:
            hits = []
            prompt_tokens = _tokenize(nl_prompt)
            keywords = {t for t in prompt_tokens if len(t) >= 4}
            with spec_jsonl.open("r", encoding="utf-8") as fh:
                for line in fh:
                    try:
                        rec = json.loads(line)
                    except Exception:
                        continue
                    txt = rec.get("text", "")
                    title = rec.get("title", "")
                    base = _similarity(nl_prompt, txt)
                    if base <= 0:
                        continue
                    low = txt.lower()
                    kcount = sum(1 for kw in keywords if kw in low)
                    bonus = min(kcount * 0.01, 0.08)
                    title_bonus = 0.05 if ("Textual Notation" in title or "Kernel_Modeling_Language" in title) else 0.0
                    score = base + bonus + title_bonus
                    hits.append((rec, score))
            hits.sort(key=lambda x: x[1], reverse=True)
            for j, (rec, _) in enumerate(hits[:3], 1):
                txt = rec.get("text", "")
                title = rec.get("title", "Spec")
                blocks.append(f"Spec {j} [{title}]:\n{txt}\n---")
        except Exception:
            pass

    if not blocks:
        return ""
    return (
        "Use the following examples and specification excerpts as guidance. "
        "Follow grammar; prefer simple, correct constructs.\n" + "\n".join(blocks)
    )


def _default_system_prompt(user_hint: str | None = None) -> str:
    base = (
        "You generate valid SysML v2 concrete syntax only. "
        "No markdown, no fences, no prose. "
        "Prefer correct grammar and consistency. "
        "Produce complete, non-trivial models that satisfy the requirement with appropriate parts, ports, connections, items/value types (with units), behaviors (state machines/actions), and requirements when applicable. "
        "Avoid placeholders and undefined references."
    )
    if user_hint and user_hint.strip():
        return (user_hint.strip() + " ") + base
    return base


PROMPT_HUMAN_TEMPLATE = (
    "{context}\n\n"
    "Generate SysML v2 code for the following requirement. "
    "Produce a complete, detailed, non-trivial model with appropriate parts, ports, connections, item/value types (with units), behaviors (state machines/actions), and requirements as applicable. "
    "Avoid placeholders. Requirement: {input}"
)


def _postprocess(code: str) -> str:
    lines = []
    for ln in code.splitlines():
        if ln.strip().startswith("```"):
            continue
        if ln.strip().lower().startswith("sysml") and len(ln.strip().split()) == 1:
            continue
        lines.append(ln)
    return "\n".join(lines).strip()


def _gemini_llm():
    from langchain_google_genai import ChatGoogleGenerativeAI
    return ChatGoogleGenerativeAI(model="gemini-2.5-pro", api_key=os.getenv("GEMINI_API_KEY"), temperature=0.2)


def _gemini_invoke(system_msg: str, human_msg: str) -> str:
    # Avoid template parsing of braces by sending concrete messages directly
    from langchain_core.messages import SystemMessage, HumanMessage
    llm = _gemini_llm()
    resp = llm.invoke([SystemMessage(content=system_msg), HumanMessage(content=human_msg)])
    # LangChain returns an AIMessage; extract plain text content
    try:
        return resp.content  # type: ignore[attr-defined]
    except Exception:
        try:
            return str(resp["content"])  # type: ignore[index]
        except Exception:
            return str(resp)


def _openrouter_invoke(model: str, system_msg: str, human_msg: str, key: str) -> str:
    base = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
    url = f"{base}/chat/completions"
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_msg},
            {"role": "user", "content": human_msg},
        ],
        "temperature": 0.2,
    }
    data = json.dumps(payload).encode("utf-8")
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": f"Bearer {key}",
        # Required by OpenRouter for attribution/billing
        "HTTP-Referer": os.getenv("HTTP_REFERER", "https://localhost"),
        "Referer": os.getenv("HTTP_REFERER", "https://localhost"),
        "X-Title": os.getenv("APP_TITLE", "Creatix Agent"),
        "User-Agent": os.getenv("APP_TITLE", "Creatix Agent"),
    }
    req = _req.Request(url, data=data, headers=headers)
    try:
        with _req.urlopen(req, timeout=60) as resp:
            obj = json.loads(resp.read().decode("utf-8", errors="ignore"))
    except Exception as e:
        # Best-effort error surfacing under debug
        if os.getenv("OPENROUTER_DEBUG"):
            try:
                body = getattr(e, 'read', lambda: b'')()
                msg = body.decode('utf-8', errors='ignore') if body else str(e)
                (Path(__file__).parent / "result_rag_moe" / "openrouter_error.log").write_text(msg)
            except Exception:
                pass
        return ""
    try:
        return obj["choices"][0]["message"]["content"]
    except Exception:
        return ""


def _invoke_with_retry(model: str, system_msg: str, human_msg: str, openrouter_key: str | None) -> str:
    """
    Call a model and enforce code-only output via postprocess and a single stricter retry if needed.
    """
    if model == "gemini-2.5-pro":
        out = _postprocess(_gemini_invoke(system_msg, human_msg))
        if (not out) or ("```" in out):
            strong = _default_system_prompt("No markdown, no fences, no prose. Output SysML v2 code only.")
            out = _postprocess(_gemini_invoke(strong, human_msg))
        return out
    else:
        if not openrouter_key:
            return ""
        out = _postprocess(_openrouter_invoke(model, system_msg, human_msg, openrouter_key))
        if (not out) or ("```" in out):
            strong = system_msg + " No markdown, no fences, no prose. Output SysML v2 code only."
            out = _postprocess(_openrouter_invoke(model, strong, human_msg, openrouter_key))
        return out


def _refine_with_compiler(
    code: str, 
    model: str, 
    system_msg: str, 
    human_msg: str, 
    openrouter_key: str | None,
    max_iterations: int = MAX_REFINEMENT_ITERATIONS
) -> Tuple[str, CompilerResult]:
    """
    Refine code iteratively using compiler feedback.
    
    Args:
        code: Initial SysML code
        model: Model name to use for refinement
        system_msg: System message template
        human_msg: Human message template (original prompt)
        openrouter_key: OpenRouter API key
        max_iterations: Maximum number of refinement iterations
    
    Returns:
        Tuple of (refined_code, final_compiler_result)
    """
    if not is_compiler_available():
        # No compiler available, return original code
        return code, CompilerResult(errors=[], is_valid=False)
    
    current_code = code
    iteration = 0
    
    while iteration < max_iterations:
        # Check current code
        result = check_code(current_code, syntax_only=COMPILER_SYNTAX_ONLY)
        
        # If valid, we're done
        if result.is_valid:
            return current_code, result
        
        # If no more iterations, return current code
        if iteration >= max_iterations - 1:
            return current_code, result
        
        # Prepare refinement prompt with error feedback
        error_feedback = result.format_errors()
        refinement_hint = (
            f"The previous code had compilation errors. Please fix them:\n\n{error_feedback}\n\n"
            "Generate corrected SysML v2 code that addresses these errors."
        )
        
        refinement_system = system_msg + "\n\n" + refinement_hint
        refinement_human = (
            f"{human_msg}\n\n"
            f"Previous code (had errors):\n```sysml\n{current_code}\n```\n\n"
            f"Errors to fix:\n{error_feedback}\n\n"
            "Generate the corrected code."
        )
        
        # Get refined code
        refined = _invoke_with_retry(model, refinement_system, refinement_human, openrouter_key)
        if not refined or refined == current_code:
            # No improvement, break
            break
        
        current_code = refined
        iteration += 1
    
    # Final check
    final_result = check_code(current_code, syntax_only=COMPILER_SYNTAX_ONLY)
    return current_code, final_result


def generate_sysml_moe(prompt_text: str) -> Tuple[str, dict]:
    """
    Returns (final_sysml, prompt_record_json)
    """
    _load_env()
    root = Path(__file__).parent.parent
    context = _rag_context(prompt_text, root, k=3)
    sys_msg = _default_system_prompt(None)
    human_msg = PROMPT_HUMAN_TEMPLATE.format(context=context, input=prompt_text)

    # Collect candidates (each receives RAG-context-augmented prompt)
    candidates: List[Tuple[str, str, CompilerResult]] = []
    for m in EXPERT_MODELS:
        _, ok = _load_env()
        out = _invoke_with_retry(m, sys_msg, human_msg, ok)
        if out:
            # Refine with compiler feedback if available
            if is_compiler_available():
                refined_out, result = _refine_with_compiler(
                    out, m, sys_msg, human_msg, ok, MAX_REFINEMENT_ITERATIONS
                )
                candidates.append((m, refined_out, result))
            else:
                # No compiler, use original output
                candidates.append((m, out, CompilerResult(errors=[], is_valid=False)))

    # Synthesis by COMBINER_MODEL using candidates as extra context
    # Prioritize valid candidates
    if candidates:
        # Sort candidates: valid ones first, then by error count
        sorted_candidates = sorted(
            candidates,
            key=lambda x: (not x[2].is_valid, x[2].error_count)
        )
        
        cand_block = []
        cand_log = []
        for i, (name, code, result) in enumerate(sorted_candidates, 1):
            grp = _model_group(name)
            rating = EXPERT_MODELS_RATING.get(grp, 5)
            # Add validation status
            valid_marker = "✓" if result.is_valid else f"✗({result.error_count} err)"
            cand_block.append(
                f"Candidate {i} ({name}, rating={rating}/10, {valid_marker}):\n{code}\n---"
            )
            # Compact log snippet for prompt record
            snippet = "\n".join(code.splitlines()[:40])
            cand_log.append(
                f"Candidate {i} ({name}, rating={rating}/10, {valid_marker}):\n{snippet}\n---"
            )
        
        synth_context = context + "\n\nUse the following candidate models as additional context. "
        if is_compiler_available():
            synth_context += "Valid candidates (marked with ✓) are preferred.\n"
        synth_context += "\n".join(cand_block)
        
        synth_sys_hint = (
            "Synthesize a single best model by merging or selecting from candidates when provided. "
        )
        if is_compiler_available():
            synth_sys_hint += "Prefer valid candidates (marked with ✓) when available."
        synth_sys_msg = _default_system_prompt(synth_sys_hint)
        synth_human_msg = PROMPT_HUMAN_TEMPLATE.format(context=synth_context, input=prompt_text)
        _, ok = _load_env()
        final = _invoke_with_retry(COMBINER_MODEL, synth_sys_msg, synth_human_msg, ok)
        
        # Refine final output if compiler available
        if is_compiler_available() and final:
            final, final_result = _refine_with_compiler(
                final, COMBINER_MODEL, synth_sys_msg, synth_human_msg, ok, MAX_REFINEMENT_ITERATIONS
            )
        else:
            final_result = CompilerResult(errors=[], is_valid=False)
        
        candidates_section = "\n\nCandidates Included (snippets):\n" + "\n".join(cand_log)
    else:
        # Fallback to single call with combiner model
        _, ok = _load_env()
        final = _invoke_with_retry(COMBINER_MODEL, sys_msg, human_msg, ok)
        
        # Refine final output if compiler available
        if is_compiler_available() and final:
            final, final_result = _refine_with_compiler(
                final, COMBINER_MODEL, sys_msg, human_msg, ok, MAX_REFINEMENT_ITERATIONS
            )
        else:
            final_result = CompilerResult(errors=[], is_valid=False)
        
        candidates_section = None

    # Build JSON prompt record
    base_prompt_str = "System:\n" + sys_msg + "\n\n" + "Human:\n" + human_msg
    if candidates:
        combine_prompt_str = (
            "System:\n" + synth_sys_msg + "\n\n" + "Human:\n" + synth_human_msg
        )
    else:
        combine_prompt_str = base_prompt_str

    prompt_record = {
        "gemini_prompt": base_prompt_str,
        "gpt_prompt": base_prompt_str,
        "claude_prompt": base_prompt_str,
        "llama_prompt": base_prompt_str,
        "combine_prompt": combine_prompt_str,
    }
    
    # Add compiler validation info if available
    if is_compiler_available() and 'final_result' in locals():
        prompt_record["final_valid"] = final_result.is_valid
        prompt_record["final_errors"] = final_result.error_count
        if final_result.errors:
            prompt_record["final_error_details"] = [
                {
                    "line": e.line,
                    "column": e.column,
                    "message": e.message,
                    "severity": e.severity
                }
                for e in final_result.errors
            ]

    return final, prompt_record


if __name__ == "__main__":
    import sys
    args = " ".join(sys.argv[1:]).strip()
    base = Path(__file__).parent
    if args:
        code, _prompt = generate_sysml_moe(args)
        print(code)
    else:
        ds_path = base / "dataset.json"
        out_dir = base / "result_rag_moe"
        out_dir.mkdir(parents=True, exist_ok=True)
        data = json.load(open(ds_path))
        prompts = data.get("prompts", [])
        for item in prompts:
            pid = str(item.get("id", "")).strip() or "U?"
            desc = str(item.get("description", "")).strip()
            if not desc:
                continue
            code, prompt_json = generate_sysml_moe(desc)
            (out_dir / f"{pid}.sysml").write_text(f"// {desc}\n{code}\n")
            # Write per-expert prompt .txt only for models listed in EXPERT_MODELS
            dyn_map = []
            for m in EXPERT_MODELS:
                if m == "gemini-2.5-pro":
                    dyn_map.append(("gemini_prompt", f"{pid}_gemini_prompt.txt"))
                elif m.startswith("openai/"):
                    dyn_map.append(("gpt_prompt", f"{pid}_gpt_prompt.txt"))
                elif m.startswith("anthropic/"):
                    dyn_map.append(("claude_prompt", f"{pid}_claude_prompt.txt"))
                elif m.startswith("meta-llama/"):
                    dyn_map.append(("llama_prompt", f"{pid}_llama_prompt.txt"))

            for key, filename in dyn_map:
                val = prompt_json.get(key)
                if isinstance(val, str) and val:
                    (out_dir / filename).write_text(val)

            # Always write the combined synthesis prompt
            combine = prompt_json.get("combine_prompt")
            if isinstance(combine, str) and combine:
                (out_dir / f"{pid}_combine_prompt.txt").write_text(combine)
            print(f"wrote {out_dir / (pid + '.sysml')}")