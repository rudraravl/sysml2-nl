"""MoE aggregator: merge Path A (codegen) and Path B (direct) SysML candidates."""

from __future__ import annotations

import sysml_pipeline.config  # noqa: F401

from agent_rag_moe import _default_system_prompt, _invoke_with_retry, _postprocess

from sysml_pipeline.config import MOE_MODEL, require_openrouter

_MOE_HINT = (
    "You are a mixture-of-experts synthesizer for SysML v2. "
    "Two generation paths produced candidate models for the same requirement. "
    "Analyze structural coverage, resolve syntax mismatches, and merge the highest-fidelity "
    "fragments from each path into one coherent model. "
    "Prefer syntactically valid constructs; drop broken sections rather than inventing placeholders."
)

_HUMAN_TEMPLATE = """Original engineering requirement:
{requirement}

---
Path A output (Python execution — programmatic generation):
{path_a}

---
Path B output (direct foundation model generation):
{path_b}

---
Synthesize a single unified SysML v2 model that best satisfies the requirement.
Output only raw SysML v2 concrete syntax (no markdown, no fences, no prose).
"""


def synthesize_unified_sysml(
    nl_task_prompt: str,
    path_a_sysml: str,
    path_b_sysml: str,
) -> str:
    """MoE synthesis over dual-path candidates."""
    key = require_openrouter()
    sys_msg = _default_system_prompt(_MOE_HINT)
    human = _HUMAN_TEMPLATE.format(
        requirement=nl_task_prompt.strip(),
        path_a=(path_a_sysml or "(empty — Path A failed)").strip(),
        path_b=(path_b_sysml or "(empty — Path B failed)").strip(),
    )
    raw = _invoke_with_retry(MOE_MODEL, sys_msg, human, key)
    unified = _postprocess(raw) if raw else ""
    if not unified:
        # Fallback: prefer longer non-empty candidate
        candidates = [c for c in (path_a_sysml, path_b_sysml) if c and c.strip()]
        if candidates:
            return max(candidates, key=len).strip()
        raise RuntimeError(f"MoE synthesis failed (model={MOE_MODEL})")
    return unified
