"""
Agentic Pipeline with RAG + MoE synthesis.

Pipeline (from nl2sysml/agent_rag_moe.py):
- Build RAG context from dataset examples and spec chunks.
- Query multiple experts (EXPERT_MODELS):
  * gemini-2.5-pro (direct via Google Generative AI)
  * openrouter models: openai/gpt-5.1-codex-max, anthropic/claude-sonnet-4.5, meta-llama/llama-4-maverick
- Ask combiner model to synthesize a single best SysML v2 model.
- Output only SysML v2 code; no markdown fences.
"""

import os
import json
import re
import asyncio
from pathlib import Path
from typing import List, Tuple, Optional
from urllib import request as _req

from fastapi import HTTPException
import google.generativeai as genai

from app.pipelines.base import BasePipeline
from app.core.config import MAX_INPUT_CHARS, GEMINI_API_KEY, OPENROUTER_API_KEY, OPENROUTER_BASE_URL
from app.core.logging import get_logger

log = get_logger(__name__)

# Expert models (using available models on OpenRouter)
EXPERT_MODELS = [
    "gemini-2.0-flash",  # Fast Gemini model
    "openai/gpt-4o-mini",  # OpenAI via OpenRouter
    "anthropic/claude-3.5-sonnet",  # Claude via OpenRouter
    "meta-llama/llama-3.1-70b-instruct",  # Llama via OpenRouter
]

# Combiner model for the final synthesis step
COMBINER_MODEL = "anthropic/claude-3.5-sonnet"

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


class AgenticPipeline(BasePipeline):
    """Pipeline using MoE with RAG for SysML generation."""

    @property
    def name(self) -> str:
        return "agentic"

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
        rag_start = time.time()
        context = _rag_context(text, root, k=3)
        rag_ms = int((time.time() - rag_start) * 1000)
        log.info(f"RAG context built in {rag_ms}ms")

        sys_msg = _default_system_prompt(None)
        human_msg = PROMPT_HUMAN_TEMPLATE.format(context=context, input=text)

        # Step 2: Query all expert models (run in thread pool to avoid blocking)
        gen_start = time.time()
        candidates: List[Tuple[str, str]] = []
        
        loop = asyncio.get_event_loop()
        for m in EXPERT_MODELS:
            log.info(f"Querying expert: {m}")
            try:
                out = await loop.run_in_executor(None, _invoke_with_retry, m, sys_msg, human_msg)
                if out:
                    candidates.append((m, out))
                    log.info(f"Expert {m} returned {len(out)} chars")
            except Exception as e:
                log.warning(f"Expert {m} failed: {e}")

        # Step 3: Synthesis by COMBINER_MODEL using candidates as extra context
        if candidates:
            cand_block = []
            for i, (name, code) in enumerate(candidates, 1):
                grp = _model_group(name)
                rating = EXPERT_MODELS_RATING.get(grp, 5)
                cand_block.append(f"Candidate {i} ({name}, rating={rating}/10):\n{code}\n---")
            
            synth_context = context + "\n\nUse the following candidate models as additional context.\n" + "\n".join(cand_block)
            synth_sys_hint = "Synthesize a single best model by merging or selecting from candidates when provided."
            synth_sys_msg = _default_system_prompt(synth_sys_hint)
            synth_human_msg = PROMPT_HUMAN_TEMPLATE.format(context=synth_context, input=text)
            
            log.info(f"Synthesizing with {COMBINER_MODEL} using {len(candidates)} candidates")
            final = await loop.run_in_executor(None, _invoke_with_retry, COMBINER_MODEL, synth_sys_msg, synth_human_msg)
        else:
            # Fallback to single call with combiner model
            log.info(f"No candidates, falling back to {COMBINER_MODEL}")
            final = await loop.run_in_executor(None, _invoke_with_retry, COMBINER_MODEL, sys_msg, human_msg)

        gen_ms = int((time.time() - gen_start) * 1000)
        log.info(f"MoE synthesis completed in {gen_ms}ms")

        # Diagnostics
        diagnostics = {
            "loaded_from_cache": True,  # API doesn't load models
            "model_load_ms": 0,
            "gen_ms": gen_ms,
            "rag_ms": rag_ms,
            "num_candidates": len(candidates),
            "expert_models": [c[0] for c in candidates],
            "combiner_model": COMBINER_MODEL,
            "evicted_models": [],
        }

        return final, diagnostics
