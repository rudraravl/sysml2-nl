"""
Pass 1 orchestration: Path A (codegen + sandbox), Path B (direct), MoE merge.
"""

from __future__ import annotations

import asyncio
from typing import Any, Dict, List

import sysml_pipeline.config  # noqa: F401 — bootstrap nl2sysml on sys.path

from sysml_pipeline.config import PATH_A_MAX_RETRIES, load_api_keys
from sysml_pipeline.aggregator.moe_synthesis import synthesize_unified_sysml
from sysml_pipeline.executors.sandbox import format_execution_error, run_python_script
from sysml_pipeline.generators.path_a_codegen import generate_python_script
from sysml_pipeline.generators.path_b_direct import generate_direct_sysml


async def _run_path_a(nl_task_prompt: str, verifier_logs: List[Dict[str, Any]]) -> tuple[str, str]:
    """Codegen → sandbox; up to PATH_A_MAX_RETRIES regenerations on failure."""
    script = await asyncio.to_thread(generate_python_script, nl_task_prompt)
    last_script = script
    result = None

    for attempt in range(PATH_A_MAX_RETRIES + 1):
        result = await asyncio.to_thread(run_python_script, last_script)
        verifier_logs.extend(result.logs)

        if result.success:
            return last_script, result.sysml_output

        if attempt >= PATH_A_MAX_RETRIES:
            break

        err = format_execution_error(result)
        verifier_logs.append(
            {
                "level": "warning",
                "message": "Path A Verifier 1: regenerating Python after execution failure",
                "attempt": attempt + 1,
            }
        )
        last_script = await asyncio.to_thread(
            generate_python_script,
            nl_task_prompt,
            execution_error=err,
            previous_script=last_script,
        )

    return last_script, result.sysml_output if result else ""


async def _run_path_b(
    nl_task_prompt: str, verifier_logs: List[Dict[str, Any]]
) -> str:
    try:
        return await asyncio.to_thread(generate_direct_sysml, nl_task_prompt)
    except Exception as e:
        verifier_logs.append({"level": "error", "message": f"Path B failed: {e}"})
        return ""


async def run_pass_1(nl_task_prompt: str) -> Dict[str, Any]:
    """
    Executes Pass 1 of the hybrid SysML v2 generation pipeline.

    Args:
        nl_task_prompt: The natural language engineering requirements.

    Returns:
        Dictionary with success, unified_sysml_code, path_a_script, path_b_raw, verifier_logs.
    """
    load_api_keys()
    verifier_logs: List[Dict[str, Any]] = []

    path_b_task = asyncio.create_task(_run_path_b(nl_task_prompt, verifier_logs))

    path_a_script = ""
    path_a_sysml = ""
    try:
        path_a_script, path_a_sysml = await _run_path_a(nl_task_prompt, verifier_logs)
    except Exception as e:
        verifier_logs.append({"level": "error", "message": f"Path A failed: {e}"})

    path_b_raw = await path_b_task
    if not path_b_raw:
        verifier_logs.append(
            {"level": "warning", "message": "Path B returned empty or failed"}
        )

    unified = ""
    success = False
    try:
        unified = await asyncio.to_thread(
            synthesize_unified_sysml,
            nl_task_prompt,
            path_a_sysml,
            path_b_raw,
        )
        success = bool(unified.strip())
    except Exception as e:
        verifier_logs.append({"level": "error", "message": f"MoE synthesis failed: {e}"})
        if path_a_sysml or path_b_raw:
            unified = (path_a_sysml or path_b_raw).strip()
            success = bool(unified)

    return {
        "success": success,
        "unified_sysml_code": unified,
        "path_a_script": path_a_script,
        "path_b_raw": path_b_raw,
        "verifier_logs": verifier_logs,
    }


def _cli() -> None:
    import argparse
    import json

    parser = argparse.ArgumentParser(description="Run Pass 1 SysML v2 hybrid pipeline")
    parser.add_argument("prompt", nargs="?", help="Natural language requirement")
    parser.add_argument("-o", "--output", help="Write unified .sysml to this path")
    args = parser.parse_args()
    text = args.prompt or input("Requirement: ").strip()
    if not text:
        raise SystemExit("No prompt provided.")

    out = asyncio.run(run_pass_1(text))
    if args.output:
        from pathlib import Path

        Path(args.output).write_text(out["unified_sysml_code"], encoding="utf-8")
        print(f"Wrote {args.output}")
    else:
        print(json.dumps({k: v for k, v in out.items() if k != "unified_sysml_code"}, indent=2))
        print("\n--- unified_sysml_code ---\n")
        print(out["unified_sysml_code"])


if __name__ == "__main__":
    _cli()
