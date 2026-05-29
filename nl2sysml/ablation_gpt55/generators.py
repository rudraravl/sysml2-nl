"""GPT-5.5 generation helpers for ablation studies (baseline and RAG)."""

from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

_ABLATION_DIR = Path(__file__).resolve().parent
_NL2 = _ABLATION_DIR.parent
if str(_NL2) not in sys.path:
    sys.path.insert(0, str(_NL2))

from agent_rag_moe import (  # noqa: E402
    PROMPT_HUMAN_TEMPLATE,
    _default_system_prompt,
    _invoke_with_retry,
    _rag_context,
)

from config import (  # noqa: E402
    EXECUTABLE_HINT,
    GPT55_MODEL,
    RAG_K,
    REPO_ROOT,
)


def _openrouter_key() -> str:
    load_dotenv(REPO_ROOT / ".env")
    key = os.getenv("OPENROUTER_API_KEY", "").strip()
    if not key:
        raise RuntimeError("OPENROUTER_API_KEY missing in environment or repo-root .env")
    return key


def _generate(
    description: str,
    *,
    context: str,
    system_hint: str | None,
    model: str | None = None,
) -> tuple[str, dict[str, Any]]:
    model_id = model or GPT55_MODEL
    key = _openrouter_key()
    system_msg = _default_system_prompt(system_hint)
    human_msg = PROMPT_HUMAN_TEMPLATE.format(context=context, input=description)
    code = _invoke_with_retry(model_id, system_msg, human_msg, key)
    return code, {
        "model": model_id,
        "retrieval_used": bool(context.strip()),
        "moe_used": False,
        "context_length": len(context),
        "system_prompt": system_msg,
        "human_prompt": human_msg,
    }


def generate_baseline(description: str, *, model: str | None = None) -> tuple[str, dict[str, Any]]:
    """Stage A: single GPT-5.5 call, default system prompt, no RAG."""
    return _generate(description, context="", system_hint=None, model=model)


def generate_with_rag(description: str, *, model: str | None = None) -> tuple[str, dict[str, Any]]:
    """Executable-rule study: GPT-5.5 + lexical RAG + executable-behavior hint."""
    context = _rag_context(description, REPO_ROOT, k=RAG_K)
    return _generate(description, context=context, system_hint=EXECUTABLE_HINT, model=model)
