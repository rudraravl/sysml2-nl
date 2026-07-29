"""
Agentic Pipeline with RAG + MoE synthesis.

Pipeline (from nl2sysml/agent_rag_moe.py):
- Build RAG context from dataset examples and spec chunks.
- Query multiple experts (EXPERT_MODELS).
- Ask combiner model to synthesize a single best SysML v2 model.
- Post-synthesis gates (in order):
  1. Compiler syntax/semantic refine
  2. SysML kernel execution refine
  3. Spec-mismatch semantic alignment (combiner repair on failures)
- Output only SysML v2 code; no markdown fences.
"""

import os
import json
import re
import asyncio
import sys
from functools import partial
from pathlib import Path
from typing import Any, List, Tuple, Optional
from urllib import request as _req

from fastapi import HTTPException
import google.generativeai as genai

from app.pipelines.base import BasePipeline
from app.core.config import MAX_INPUT_CHARS, GEMINI_API_KEY, OPENROUTER_API_KEY, OPENROUTER_BASE_URL
from app.core.logging import get_logger
from app.pipelines.agentic.inputagent import run_input_agent
from app.tools.sysml_tools import is_validate_sysml_available, validate_sysml

log = get_logger(__name__)

try:
    from nl2sysml.sysml_execution import ExecutionRequest, ExecutionResult, run_sysml_execution
    KERNEL_EXECUTION_AVAILABLE = True
except ImportError:
    ExecutionRequest = None  # type: ignore[assignment,misc]
    ExecutionResult = Any  # type: ignore[misc]
    run_sysml_execution = None  # type: ignore[assignment]
    KERNEL_EXECUTION_AVAILABLE = False

# --- Tool-calling adapter for SysML validation ---
class _ToolCompilerError:
    """Compiler-error shape expected by the existing refinement loop."""

    def __init__(self, diagnostic):
        self.severity = diagnostic.severity
        self.line = diagnostic.line
        self.column = diagnostic.column
        self.message = diagnostic.message
        self.code = diagnostic.code
        self.file = diagnostic.file


class _ToolCompilerResult:
    """Compiler-result shape expected by the existing refinement loop."""

    def __init__(self, errors=None, is_valid=False):
        self.errors = errors or []
        self.is_valid = is_valid

    @property
    def error_count(self):
        return len(self.errors)

    def format_errors(self):
        if not self.errors:
            return "No errors found."
        lines = [f"Found {len(self.errors)} error(s):"]
        for index, error in enumerate(self.errors, 1):
            lines.append(f"{index}. Line {error.line}, Column {error.column}: {error.message}")
        return "\n".join(lines)


def _check_code_fn(code: str, syntax_only: bool = False):
    result = validate_sysml(code, syntax_only=syntax_only)
    errors = [_ToolCompilerError(diagnostic) for diagnostic in result.diagnostics]
    return _ToolCompilerResult(errors=errors, is_valid=result.ok)


def _is_compiler_available_fn():
    return is_validate_sysml_available()


_CompilerResultClass = _ToolCompilerResult

# Env for refinement (same as agent_rag_moe.py)
MAX_REFINEMENT_ITERATIONS = int(os.getenv("MAX_REFINEMENT_ITERATIONS", "2"))
COMPILER_SYNTAX_ONLY = os.getenv("COMPILER_SYNTAX_ONLY", "false").lower() == "true"
MAX_KERNEL_REFINEMENT_ITERATIONS = int(os.getenv("MAX_KERNEL_REFINEMENT_ITERATIONS", "2"))
KERNEL_FEEDBACK_ENABLED = os.getenv("KERNEL_FEEDBACK_ENABLED", "true").lower() == "true"
HARNESS_HEADER = "// --- Test harness (auto-generated) ---"
SPEC_ALIGNMENT_ENABLED = os.getenv("SPEC_ALIGNMENT_ENABLED", "false").lower() == "true"
SPEC_ALIGNMENT_THRESHOLD = float(os.getenv("SPEC_ALIGNMENT_THRESHOLD", "0.85"))
SPEC_ALIGNMENT_MAX_REPAIRS = int(os.getenv("SPEC_ALIGNMENT_MAX_REPAIRS", "1"))
SPEC_ALIGNMENT_PROFILE = os.getenv("SPEC_ALIGNMENT_PROFILE", "runtime")
SPEC_ALIGNMENT_SHARDS = int(os.getenv("SPEC_ALIGNMENT_SHARDS", "3"))

# Expert models
EXPERT_MODELS = [
    "gemini-3-pro-preview",
    "openai/gpt-4o",
    "anthropic/claude-sonnet-4.5",
    "meta-llama/llama-4-maverick",
    # include qwen 235B
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

PROMPT_HUMAN_TEMPLATE = (
    "{context}\n\n"
    "Generate SysML v2 code for the following requirement. "
    "Produce a complete, detailed, non-trivial model with appropriate parts, ports, connections, item/value types (with units), behaviors (state machines/actions), and requirements as applicable. "
    "Avoid placeholders. Requirement: {input}"
)


def _model_group(model_name: str) -> str:
    if model_name.startswith("gemini"):
        return "gemini"
    if model_name.startswith("openai/"):
        return "gpt"
    if model_name.startswith("anthropic/"):
        return "claude"
    if model_name.startswith("meta-llama/"):
        return "llama"
    return "other"


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


def _default_system_prompt(user_hint: Optional[str] = None) -> str:
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


def _postprocess(code: str) -> str:
    lines = []
    for ln in code.splitlines():
        if ln.strip().startswith("```"):
            continue
        if ln.strip().lower().startswith("sysml") and len(ln.strip().split()) == 1:
            continue
        lines.append(ln)
    return "\n".join(lines).strip()


def _gemini_invoke(model_name: str, system_msg: str, human_msg: str) -> str:
    """Invoke Gemini model directly."""
    try:
        model = genai.GenerativeModel(model_name)
        # Combine system and human message
        prompt = f"{system_msg}\n\n{human_msg}"
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        log.warning(f"Gemini invoke failed: {e}")
        return ""


def _openrouter_invoke(model: str, system_msg: str, human_msg: str) -> str:
    """Invoke OpenRouter model via HTTP."""
    if not OPENROUTER_API_KEY:
        return ""
    
    url = f"{OPENROUTER_BASE_URL}/chat/completions"
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
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "HTTP-Referer": os.getenv("HTTP_REFERER", "https://localhost"),
        "Referer": os.getenv("HTTP_REFERER", "https://localhost"),
        "X-Title": os.getenv("APP_TITLE", "SysML-NL Converter"),
        "User-Agent": os.getenv("APP_TITLE", "SysML-NL Converter"),
    }
    req = _req.Request(url, data=data, headers=headers)
    try:
        with _req.urlopen(req, timeout=120) as resp:
            obj = json.loads(resp.read().decode("utf-8", errors="ignore"))
    except Exception as e:
        log.warning(f"OpenRouter request failed for {model}: {e}")
        return ""
    try:
        return obj["choices"][0]["message"]["content"]
    except Exception:
        return ""


def _invoke_with_retry(model: str, system_msg: str, human_msg: str) -> str:
    """Call a model and enforce code-only output via postprocess and a single stricter retry if needed."""
    if model.startswith("gemini"):
        out = _postprocess(_gemini_invoke(model, system_msg, human_msg))
        if (not out) or ("```" in out):
            strong = _default_system_prompt("No markdown, no fences, no prose. Output SysML v2 code only.")
            out = _postprocess(_gemini_invoke(model, strong, human_msg))
        return out
    else:
        out = _postprocess(_openrouter_invoke(model, system_msg, human_msg))
        if (not out) or ("```" in out):
            strong = system_msg + " No markdown, no fences, no prose. Output SysML v2 code only."
            out = _postprocess(_openrouter_invoke(model, strong, human_msg))
        return out


def _alignment_ask_sync(prompt: str) -> str:
    system = (
        "You are a deterministic evaluator. Follow the requested answer schema exactly. "
        "Return strict JSON only, without markdown or commentary."
    )
    last_error = "empty response"
    for _ in range(3):
        out = _openrouter_invoke(COMBINER_MODEL, system, prompt)
        if not out:
            continue
        try:
            from spec_aligner.jsonx import extract_json

            data = extract_json(out)
            if isinstance(data, list) or (
                isinstance(data, dict)
                and any(isinstance(data.get(key), list) for key in ("questions", "answers"))
            ):
                return out
            last_error = "JSON did not contain a questions or answers list"
        except ValueError as exc:
            last_error = str(exc)
    raise RuntimeError(f"spec alignment model returned invalid JSON: {last_error}")


def _alignment_repair_sync(prompt: str) -> str:
    system = _default_system_prompt(
        "Repair an existing SysML v2 model from grounded validation and semantic feedback."
    )
    return _invoke_with_retry(COMBINER_MODEL, system, prompt)


def _alignment_validate_sync(code: str) -> dict:
    result = validate_sysml(code, syntax_only=COMPILER_SYNTAX_ONLY)
    return result.model_dump() if hasattr(result, "model_dump") else result.dict()


def _compact_quality_report(report: dict) -> dict:
    attempts = []
    for attempt in report.get("attempts", []):
        alignment = attempt.get("alignment", {})
        attempts.append({
            "attempt": attempt.get("attempt"),
            "validation_status": attempt.get("validation_status"),
            "execution_status": attempt.get("execution_status"),
            "accepted": attempt.get("accepted"),
            "alignment": {
                "summary": alignment.get("summary", {}),
                "per_category": alignment.get("per_category", {}),
                "mismatches": alignment.get("mismatches", []),
                "question_selection": alignment.get("question_selection", {}),
            },
        })
    return {
        "accepted": report.get("accepted", False),
        "repairs": report.get("repairs", 0),
        "threshold": report.get("threshold"),
        "attempts": attempts,
    }


def _refine_with_compiler_sync(
    code: str,
    combiner_model: str,
    synth_sys_msg: str,
    synth_human_msg: str,
    max_iterations: int,
) -> Tuple[str, "CompilerResult"]:
    """
    Refine code iteratively using compiler feedback (sync, for use in run_in_executor).
    Returns (refined_code, final_compiler_result). CompilerResult type from compiler_interface.
    """
    CompilerResult = _CompilerResultClass  # noqa: F811
    if not _is_compiler_available_fn():
        return code, CompilerResult(errors=[], is_valid=False)
    current_code = code
    iteration = 0
    while iteration < max_iterations:
        result = _check_code_fn(current_code, syntax_only=COMPILER_SYNTAX_ONLY)
        if result.is_valid:
            return current_code, result
        if iteration >= max_iterations - 1:
            return current_code, result
        error_feedback = result.format_errors()
        refinement_hint = (
            f"The previous code had compilation errors. Please fix them:\n\n{error_feedback}\n\n"
            "Generate corrected SysML v2 code that addresses these errors."
        )
        refinement_system = synth_sys_msg + "\n\n" + refinement_hint
        refinement_human = (
            f"{synth_human_msg}\n\n"
            f"Previous code (had errors):\n```sysml\n{current_code}\n```\n\n"
            f"Errors to fix:\n{error_feedback}\n\n"
            "Generate the corrected code."
        )
        refined = _invoke_with_retry(combiner_model, refinement_system, refinement_human)
        if not refined or refined == current_code:
            break
        current_code = refined
        iteration += 1
    final_result = _check_code_fn(current_code, syntax_only=COMPILER_SYNTAX_ONLY)
    return current_code, final_result


def _split_consolidated_at_harness(consolidated: str) -> Tuple[str, str]:
    model_plus_mocks, separator, harness_body = consolidated.partition(HARNESS_HEADER)
    if not separator:
        return consolidated, ""
    return model_plus_mocks, separator + harness_body


def _number_sysml_lines(code: str) -> str:
    return "\n".join(
        f"{line_number:4d}| {line}"
        for line_number, line in enumerate(code.splitlines(), 1)
    )


def _format_kernel_errors(result: ExecutionResult, harness_start_line: int) -> str:
    formatted: List[str] = []
    diagnostics = (result.diagnostics or {}) if result is not None else {}
    diagnostic_errors = diagnostics.get("errors", [])

    if isinstance(diagnostic_errors, list):
        for error in diagnostic_errors:
            if not isinstance(error, dict):
                continue
            message = str(error.get("message", "")).strip()
            line = error.get("line")
            column = error.get("column")
            if not message:
                continue
            location = ""
            if isinstance(line, int):
                location = f"line {line}"
                if isinstance(column, int):
                    location += f", column {column}"
                location += ": "
            harness_note = ""
            if isinstance(line, int) and line >= harness_start_line:
                harness_note = (
                    " (in auto-generated ExecutionHarness — do not edit the harness; "
                    "fix the candidate so the harness can bind to it)"
                )
            formatted.append(f"- {location}{message}{harness_note}")

    if not formatted and result is not None:
        seen = set()
        for chunk in list(result.errors) + list(result.trace):
            for line in str(chunk).splitlines():
                line = line.strip()
                if "ERROR:" not in line.upper() or line in seen:
                    continue
                seen.add(line)
                formatted.append(f"- {line}")

    if not formatted:
        return "- Kernel execution failed without a structured ERROR diagnostic."
    return "\n".join(formatted[:30])


def _refine_with_kernel_sync(
    code: str,
    combiner_model: str,
    synth_sys_msg: str,
    synth_human_msg: str,
    max_iterations: int,
) -> Tuple[str, Optional[ExecutionResult]]:
    """Refine the combined model using SysML kernel feedback."""
    if not KERNEL_EXECUTION_AVAILABLE or ExecutionRequest is None or run_sysml_execution is None:
        return code, None

    current_code = code
    iteration = 0
    while iteration < max_iterations:
        result = run_sysml_execution(ExecutionRequest(candidate_sysml=current_code))
        if not result.kernel_available or result.bridge_error:
            return current_code, result
        if result.success:
            return current_code, result
        if iteration >= max_iterations - 1:
            return current_code, result

        model_plus_mocks, _harness_block = _split_consolidated_at_harness(
            result.consolidated_payload
        )
        harness_start_line = len(model_plus_mocks.splitlines()) + 1
        error_feedback = _format_kernel_errors(result, harness_start_line)
        refinement_hint = (
            "The previous SysML v2 model failed SysML kernel execution. "
            "Fix the candidate model using the kernel errors below.\n\n"
            "Important context:\n"
            "- Before execution, the pipeline may inject mock `attribute def ...;` stubs "
            "into the root package, then tacks on an auto-generated test harness starting "
            f"at `{HARNESS_HEADER}`, followed by `package ExecutionHarness {{ ... }}`.\n"
            "- That harness is NOT shown below and must NOT appear in your output. "
            "It will be regenerated automatically.\n"
            "- Some kernel errors cite line numbers inside ExecutionHarness. Those errors "
            "can still be relevant, such as unresolved names imported from your model. "
            "Fix the candidate so the harness can bind; do not invent harness code.\n"
            "- Line numbers for the shown code refer to the pre-harness kernel payload "
            "(candidate + optional mocks). A few mock lines near the root package `{` may "
            "shift later lines slightly versus the bare candidate.\n"
            "- Emit corrected candidate SysML v2 only: no markdown, no fences, no prose, "
            "no ExecutionHarness, no mock stubs."
        )
        refinement_system = synth_sys_msg + "\n\n" + refinement_hint
        refinement_human = (
            f"{synth_human_msg}\n\n"
            f"Previous candidate (revise this):\n```sysml\n{current_code}\n```\n\n"
            "Pre-harness kernel payload with line numbers (errors in the model/mock region "
            "refer to THESE lines; harness source is omitted — it starts after "
            f"`{HARNESS_HEADER}`):\n```\n"
            f"{_number_sysml_lines(model_plus_mocks)}\n```\n\n"
            f"Kernel errors to fix:\n{error_feedback}\n\n"
            "Generate the corrected candidate SysML v2 code only."
        )
        refined = _invoke_with_retry(combiner_model, refinement_system, refinement_human)
        if not refined or refined == current_code:
            break
        current_code = refined
        iteration += 1

    final_result = run_sysml_execution(ExecutionRequest(candidate_sysml=current_code))
    return current_code, final_result


class AgenticPipeline(BasePipeline):
    """Pipeline using MoE with RAG for SysML generation."""

    def __init__(self):
        self._progress_callback = None

    @property
    def name(self) -> str:
        return "agentic"

    def set_progress_callback(self, callback):
        """Set a callback function for progress updates."""
        self._progress_callback = callback

    def _report_progress(self, stage: str, detail: str = ""):
        """Report progress to callback if set."""
        if self._progress_callback:
            self._progress_callback(stage, detail)
        log.info(f"[{stage}] {detail}")

    async def _query_expert(self, model: str, sys_msg: str, human_msg: str, loop) -> Tuple[str, str, float]:
        """Query a single expert model. Returns (model_name, output, duration_ms)."""
        import time
        start = time.time()
        try:
            out = await loop.run_in_executor(None, _invoke_with_retry, model, sys_msg, human_msg)
            duration = int((time.time() - start) * 1000)
            if out:
                self._report_progress("expert_done", f"{model} returned {len(out)} chars in {duration}ms")
                return (model, out, duration)
            else:
                self._report_progress("expert_done", f"{model} returned empty in {duration}ms")
                return (model, "", duration)
        except Exception as e:
            duration = int((time.time() - start) * 1000)
            self._report_progress("expert_failed", f"{model} failed: {e}")
            return (model, "", duration)

    async def run(self, text: str, max_new_tokens: int) -> tuple[str, dict]:
        """Generate SysML from natural language using RAG + MoE synthesis."""
        import time
        
        # Validate input
        if len(text) > MAX_INPUT_CHARS:
            raise HTTPException(
                status_code=400,
                detail=f"Input too long: {len(text)} chars, max {MAX_INPUT_CHARS}"
            )

        if not GEMINI_API_KEY:
            raise HTTPException(
                status_code=500,
                detail="GEMINI_API_KEY not configured in .env"
            )

        # Configure Gemini
        genai.configure(api_key=GEMINI_API_KEY)

        # Get project root (4 levels up from this file: app/pipelines/agentic/pipeline.py)
        root = Path(__file__).resolve().parents[5]
        
        # Step 1: Build RAG context
        self._report_progress("rag", "Building RAG context...")
        rag_start = time.time()
        context = _rag_context(text, root, k=3)
        rag_ms = int((time.time() - rag_start) * 1000)
        self._report_progress("rag_done", f"RAG context built in {rag_ms}ms")

        # Step 2: Input Agent — refine prompt with Gemini 2.5 Pro + Google Search
        self._report_progress("input_agent", "Input Agent: Refining prompt with online search...")
        ia_result = await run_input_agent(
            nl_input=text,
            rag_context=context,
            progress_callback=self._progress_callback,
        )
        ia_ms = ia_result.get("duration_ms", 0)
        refined_prompt = ia_result.get("refined_prompt", "")
        search_queries = ia_result.get("search_queries", [])

        # Use the refined prompt if available; otherwise fall back to original
        if refined_prompt:
            log.info(f"Input Agent produced refined prompt ({len(refined_prompt)} chars)")
            # The refined prompt already contains enriched context + requirement + guidance
            sys_msg = _default_system_prompt(None)
            human_msg = (
                refined_prompt + "\n\n"
                "Generate SysML v2 code for the above requirement. "
                "Produce a complete, detailed, non-trivial model with appropriate parts, ports, connections, "
                "item/value types (with units), behaviors (state machines/actions), and requirements as applicable. "
                "Avoid placeholders."
            )
        else:
            log.info("Input Agent returned empty; using original RAG prompt")
            sys_msg = _default_system_prompt(None)
            human_msg = PROMPT_HUMAN_TEMPLATE.format(context=context, input=text)

        # Step 3: Query all expert models IN PARALLEL
        self._report_progress("experts", f"Querying {len(EXPERT_MODELS)} experts in parallel...")
        gen_start = time.time()
        
        loop = asyncio.get_event_loop()
        
        # Create tasks for all experts
        tasks = [
            self._query_expert(m, sys_msg, human_msg, loop)
            for m in EXPERT_MODELS
        ]
        
        # Run all expert queries in parallel
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Collect successful candidates
        candidates: List[Tuple[str, str]] = []
        expert_times: dict[str, int] = {}
        
        for result in results:
            if isinstance(result, Exception):
                continue
            model, output, duration = result
            expert_times[model] = duration
            if output:
                candidates.append((model, output))
        
        experts_ms = int((time.time() - gen_start) * 1000)
        self._report_progress("experts_done", f"Got {len(candidates)}/{len(EXPERT_MODELS)} responses in {experts_ms}ms")

        # Step 4: Synthesis by COMBINER_MODEL using candidates as extra context
        synth_start = time.time()
        if candidates:
            self._report_progress("synthesis", f"Synthesizing with {COMBINER_MODEL}...")
            
            cand_block = []
            for i, (name, code) in enumerate(candidates, 1):
                grp = _model_group(name)
                rating = EXPERT_MODELS_RATING.get(grp, 5)
                cand_block.append(f"Candidate {i} ({name}, rating={rating}/10):\n{code}\n---")
            
            synth_context = context + "\n\nUse the following candidate models as additional context.\n" + "\n".join(cand_block)
            synth_sys_hint = "Synthesize a single best model by merging or selecting from candidates when provided."
            synth_sys_msg = _default_system_prompt(synth_sys_hint)
            synth_human_msg = PROMPT_HUMAN_TEMPLATE.format(context=synth_context, input=text)
            
            final = await loop.run_in_executor(None, _invoke_with_retry, COMBINER_MODEL, synth_sys_msg, synth_human_msg)
        else:
            # Fallback to single call with combiner model
            self._report_progress("synthesis", f"No candidates, falling back to {COMBINER_MODEL}...")
            synth_sys_msg = sys_msg
            synth_human_msg = human_msg
            final = await loop.run_in_executor(None, _invoke_with_retry, COMBINER_MODEL, sys_msg, human_msg)

        synth_ms = int((time.time() - synth_start) * 1000)
        total_ms = int((time.time() - gen_start) * 1000)
        self._report_progress("done", f"Synthesis completed in {synth_ms}ms, total {total_ms}ms")

        # Step 5: Optional syntax check and refinement (if compiler available on server)
        final_valid = False
        final_errors = 0
        final_error_details: List[dict] = []
        if _is_compiler_available_fn() and final and final.strip():
            self._report_progress("syntax_check", f"Validating and refining (up to {MAX_REFINEMENT_ITERATIONS} iterations)...")
            refine_start = time.time()
            final, final_result = await loop.run_in_executor(
                None,
                _refine_with_compiler_sync,
                final,
                COMBINER_MODEL,
                synth_sys_msg,
                synth_human_msg,
                MAX_REFINEMENT_ITERATIONS,
            )
            final_valid = final_result.is_valid
            final_errors = getattr(final_result, "error_count", len(final_result.errors))
            if getattr(final_result, "errors", None):
                final_error_details = [
                    {"line": e.line, "column": e.column, "message": e.message, "severity": getattr(e, "severity", "error")}
                    for e in final_result.errors
                ]
            refine_ms = int((time.time() - refine_start) * 1000)
            self._report_progress("syntax_check_done", f"{'Valid' if final_valid else f'{final_errors} errors'} in {refine_ms}ms")
        else:
            if not _is_compiler_available_fn():
                log.debug("Syntax checker not available; skipping validation")
            elif not (final and final.strip()):
                log.debug("No synthesis output; skipping validation")

        # Step 6: Kernel execution refine (dedicated stage after compiler)
        kernel_enabled = os.getenv("KERNEL_FEEDBACK_ENABLED", "true").lower() == "true"
        kernel_diagnostics: dict = {}
        if kernel_enabled and KERNEL_EXECUTION_AVAILABLE and final and final.strip():
            self._report_progress(
                "kernel_check",
                f"Kernel execution refine (up to {MAX_KERNEL_REFINEMENT_ITERATIONS} iterations)...",
            )
            kernel_start = time.time()
            final, kernel_result = await loop.run_in_executor(
                None,
                _refine_with_kernel_sync,
                final,
                COMBINER_MODEL,
                synth_sys_msg,
                synth_human_msg,
                MAX_KERNEL_REFINEMENT_ITERATIONS,
            )
            kernel_ms = int((time.time() - kernel_start) * 1000)
            if kernel_result is None:
                self._report_progress("kernel_check_done", f"unavailable in {kernel_ms}ms")
            elif not kernel_result.kernel_available or kernel_result.bridge_error:
                kernel_diagnostics = {
                    "kernel_available": False,
                    "kernel_bridge_error": kernel_result.bridge_error,
                }
                self._report_progress(
                    "kernel_check_done",
                    f"kernel unavailable: {kernel_result.bridge_error or 'unknown'} ({kernel_ms}ms)",
                )
            else:
                diagnostics_blob = kernel_result.diagnostics or {}
                kernel_error_count = int(
                    diagnostics_blob.get("n_errors", len(kernel_result.errors))
                )
                kernel_diagnostics = {
                    "kernel_available": True,
                    "kernel_compiled": kernel_result.compiled,
                    "kernel_error_count": kernel_error_count,
                }
                status = "passed" if kernel_result.success else f"{kernel_error_count} errors"
                self._report_progress("kernel_check_done", f"{status} in {kernel_ms}ms")

        # Step 7: Spec-mismatch semantic alignment (combiner repair). Kernel is not
        # re-run here; it already ran as its own stage above.
        quality_report = None
        if SPEC_ALIGNMENT_ENABLED and final and final.strip():
            self._report_progress("spec_alignment", "Running post-generation quality gate...")
            if str(root) not in sys.path:
                sys.path.insert(0, str(root))
            from nl2sysml.quality_gate import run_quality_gate

            gate = partial(
                run_quality_gate,
                text,
                final,
                _alignment_ask_sync,
                validate=_alignment_validate_sync if _is_compiler_available_fn() else None,
                execute=None,
                repair=_alignment_repair_sync,
                threshold=SPEC_ALIGNMENT_THRESHOLD,
                max_repairs=SPEC_ALIGNMENT_MAX_REPAIRS,
                alignment_kwargs={
                    "profile": SPEC_ALIGNMENT_PROFILE,
                    "shards": SPEC_ALIGNMENT_SHARDS,
                },
            )
            try:
                full_quality_report = await loop.run_in_executor(None, gate)
                final = full_quality_report["final_sysml"]
                last_attempt = full_quality_report["attempts"][-1]
                if last_attempt["validation_status"] == "passed":
                    final_valid = True
                    final_errors = 0
                    final_error_details = []
                elif last_attempt["validation_status"] == "failed":
                    final_valid = False
                    validation = last_attempt.get("validation") or {}
                    diagnostics_list = validation.get("diagnostics", [])
                    final_errors = validation.get("error_count", len(diagnostics_list))
                    final_error_details = diagnostics_list
                quality_report = _compact_quality_report(full_quality_report)
                last_alignment = quality_report["attempts"][-1]["alignment"]["summary"]
                self._report_progress(
                    "spec_alignment_done",
                    f"accepted={quality_report['accepted']}, similarity={last_alignment.get('similarity')}",
                )
            except Exception as exc:
                quality_report = {"accepted": False, "error": str(exc), "attempts": []}
                self._report_progress("spec_alignment_failed", str(exc))

        # Diagnostics
        diagnostics = {
            "loaded_from_cache": True,  # API doesn't load models
            "model_load_ms": 0,
            "gen_ms": total_ms,
            "rag_ms": rag_ms,
            "input_agent_ms": ia_ms,
            "input_agent_searches": search_queries,
            "experts_ms": experts_ms,
            "synth_ms": synth_ms,
            "num_candidates": len(candidates),
            "expert_models": [c[0] for c in candidates],
            "expert_times": expert_times,
            "combiner_model": COMBINER_MODEL,
            "evicted_models": [],
            "syntax_check_available": _is_compiler_available_fn(),
            "final_valid": final_valid,
            "final_errors": final_errors,
            "kernel_feedback_enabled": kernel_enabled,
            "spec_alignment_enabled": SPEC_ALIGNMENT_ENABLED,
        }
        diagnostics.update(kernel_diagnostics)
        if final_error_details:
            diagnostics["final_error_details"] = final_error_details
        if quality_report:
            diagnostics["quality_report"] = quality_report

        return final, diagnostics
