"""Path B: direct foundation-model SysML v2 generation."""

from __future__ import annotations

import sysml_pipeline.config  # noqa: F401

from agent_rag_moe import _invoke_with_retry, _postprocess

from sysml_pipeline.config import PATH_B_MODEL, require_openrouter

_PATH_B_SYSTEM = """You generate valid SysML v2 concrete syntax only.
Output raw SysML v2 textual notation with no markdown code fences, no backticks, and no prose explanations.
Prefer correct grammar and consistency.
Produce a complete, non-trivial model: parts, ports, connections, value types (with units), behaviors, and requirements when applicable.
Avoid placeholders and undefined references."""

_HUMAN_TEMPLATE = """Generate SysML v2 code for the following engineering requirement.
Requirement:
{requirement}
"""


def generate_direct_sysml(nl_task_prompt: str) -> str:
    """Send NL prompt directly to the foundation model; return post-processed SysML."""
    key = require_openrouter()
    human = _HUMAN_TEMPLATE.format(requirement=nl_task_prompt.strip())
    raw = _invoke_with_retry(PATH_B_MODEL, _PATH_B_SYSTEM, human, key)
    code = _postprocess(raw) if raw else ""
    if not code:
        raise RuntimeError(f"Path B direct generation returned empty output (model={PATH_B_MODEL})")
    return code
