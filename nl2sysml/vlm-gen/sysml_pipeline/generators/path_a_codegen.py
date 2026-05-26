"""Path A: dynamic Python codegen for programmatic SysML v2 emission."""

from __future__ import annotations

import re

import sysml_pipeline.config  # noqa: F401

from agent_rag_moe import _invoke_with_retry

from sysml_pipeline.config import PATH_A_MODEL, require_openrouter

_PATH_A_SYSTEM = """You write standalone Python 3.10+ scripts that programmatically emit SysML v2 textual syntax.

Rules:
- Output ONLY valid Python source code. No markdown fences, no prose, no explanations.
- The script must BUILD the model with logic (loops, data structures, string formatting, helpers)—not one giant hardcoded SysML string literal for the whole model.
- You may use small string fragments for SysML keywords; domain content (names, counts, attributes) must come from variables/computation driven by the requirement.
- On completion, write the full SysML document to the file named by environment variable SYSML_OUTPUT_PATH (default: output.sysml) in the current working directory, and also print the same content to stdout.
- Use only the Python standard library.
- Include if __name__ == "__main__": guard and call a main() function.
"""

_META_TEMPLATE = """Engineering requirement:
{requirement}

Write a Python script that satisfies this requirement by programmatically constructing and writing valid SysML v2 concrete syntax.
"""

_RETRY_TEMPLATE = """The previous Python script failed when executed.

Requirement:
{requirement}

Previous script:
```python
{script}
```

Execution error (stderr/stdout):
{error}

Fix the script. Output ONLY corrected Python source (no markdown)."""


def _extract_python(raw: str) -> str:
    text = raw.strip()
    m = re.search(r"```(?:python)?\s*\n(.*?)```", text, re.DOTALL | re.IGNORECASE)
    if m:
        return m.group(1).strip()
    if text.startswith("```"):
        lines = text.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        return "\n".join(lines).strip()
    return text


def _invoke_codegen(system_msg: str, human_msg: str) -> str:
    key = require_openrouter()
    raw = _invoke_with_retry(PATH_A_MODEL, system_msg, human_msg, key)
    return _extract_python(raw) if raw else ""


def generate_python_script(
    nl_task_prompt: str,
    *,
    execution_error: str | None = None,
    previous_script: str | None = None,
) -> str:
    """
    Ask the codegen LLM for executable Python (Verifier 1 retry uses execution_error).
    """
    if execution_error and previous_script:
        human = _RETRY_TEMPLATE.format(
            requirement=nl_task_prompt.strip(),
            script=previous_script.strip(),
            error=execution_error.strip(),
        )
        system = _PATH_A_SYSTEM + "\nFix the runtime/syntax errors shown below."
    else:
        human = _META_TEMPLATE.format(requirement=nl_task_prompt.strip())
        system = _PATH_A_SYSTEM

    code = _invoke_codegen(system, human)
    if not code:
        raise RuntimeError(f"Path A codegen returned empty output (model={PATH_A_MODEL})")
    return code
