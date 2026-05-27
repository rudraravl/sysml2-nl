"""
Orchestrates the three-phase SysML v2 execution harness.

Example (from another module):

    from pathlib import Path
    from nl2sysml.sysml_execution import ExecutionRequest, run_sysml_execution

    code = Path("candidate.sysml").read_text(encoding="utf-8")
    result = run_sysml_execution(
        ExecutionRequest(
            candidate_sysml=code,
            simulation_vectors={"capacity": 100.0},
            target_invariants=["capacityWithinBounds"],
        )
    )
    if not result.success and result.diagnostic_pack:
        repair_prompt = result.diagnostic_pack["recommended_repair_prompt"]
"""

from __future__ import annotations

import json
import re
from typing import Any, Dict, List, Optional

from .extractor import extract_topology
from .harness_builder import build_consolidated_payload, build_harness_block
from .models import ExecutionRequest, ExecutionResult, KernelExecutionOutput
from .sysml_runtime_bridge import execute_sysml_candidate

_ERROR_MARKERS = ("[ERROR]", "Constraint Violation", "constraint violation", "AssertionError")
_STATE_CHANGE_RE = re.compile(
    r"(?:state|transition|enter|exit)\s*[:\-]?\s*(\w+)",
    re.IGNORECASE,
)
_ASSERT_RESULT_RE = re.compile(
    r"(?:assert|constraint)\s+[`'\"]?(\w+)[`'\"]?\s*[:\-]?\s*(passed|failed|violated|satisfied|true|false)",
    re.IGNORECASE,
)
_VARIABLE_MISMATCH_RE = re.compile(
    r"(\w+)\s*(?:=|expected|was)\s*([^\s,;]+)",
    re.IGNORECASE,
)


def _parse_execution_logs(kernel_out: KernelExecutionOutput) -> List[str]:
    logs: List[str] = []
    for line in kernel_out.stdout_lines + kernel_out.stderr_lines:
        for part in line.splitlines():
            part = part.strip()
            if part:
                logs.append(part)
    if kernel_out.bridge_error:
        logs.append(f"[bridge] {kernel_out.bridge_error}")
    return logs


def _parse_constraint_manifest(logs: List[str]) -> List[Dict[str, Any]]:
    manifest: List[Dict[str, Any]] = []
    for log in logs:
        m = _ASSERT_RESULT_RE.search(log)
        if m:
            manifest.append(
                {
                    "constraint": m.group(1),
                    "outcome": m.group(2).lower(),
                    "raw": log,
                }
            )
            continue
        if "constraint" in log.lower():
            passed = "fail" not in log.lower() and "violat" not in log.lower()
            manifest.append({"constraint": None, "outcome": "passed" if passed else "failed", "raw": log})
    return manifest


def _parse_state_traces(logs: List[str]) -> List[str]:
    traces: List[str] = []
    for log in logs:
        if any(tok in log.lower() for tok in ("state", "transition", "event")):
            traces.append(log)
        for m in _STATE_CHANGE_RE.finditer(log):
            traces.append(f"state_change:{m.group(1)}")
    return traces


def _build_diagnostic_pack(
    status_payload: str,
    logs: List[str],
    constraint_manifest: List[Dict[str, Any]],
) -> Optional[Dict[str, Any]]:
    combined = status_payload + "\n" + "\n".join(logs)
    if not any(marker.lower() in combined.lower() for marker in _ERROR_MARKERS):
        failed = [c for c in constraint_manifest if c.get("outcome") in ("failed", "violated", "false")]
        if not failed:
            return None

    error_type = "constraint_violation"
    if "[ERROR]" in combined:
        error_type = "kernel_error"
    elif any("transition" in log.lower() for log in logs):
        error_type = "behavioral_trace_failure"

    suspect_variables: List[Dict[str, str]] = []
    for log in logs:
        for m in _VARIABLE_MISMATCH_RE.finditer(log):
            suspect_variables.append({"name": m.group(1), "detail": m.group(2)})

    message = next((log for log in logs if any(m in log for m in _ERROR_MARKERS)), combined[:2000])
    repair_lines = [
        "Layer 2 repair required after SysML execution failure.",
        f"Error type: {error_type}",
        f"Message: {message}",
    ]
    if suspect_variables:
        repair_lines.append(f"Variable mismatches: {json.dumps(suspect_variables)}")
    if constraint_manifest:
        repair_lines.append(f"Constraint manifest: {json.dumps(constraint_manifest)}")

    return {
        "error_type": error_type,
        "message": message,
        "suspect_variables": suspect_variables,
        "recommended_repair_prompt": "\n".join(repair_lines),
    }


def run_sysml_execution(request: ExecutionRequest) -> ExecutionResult:
    """
    Run extraction, harness synthesis, and headless kernel execution.
    Returns structured JSON-serializable result via ``ExecutionResult.to_dict()``.
    """
    topology = extract_topology(request.candidate_sysml)
    harness_block = build_harness_block(topology, request)
    consolidated = build_consolidated_payload(request.candidate_sysml, harness_block)

    kernel_out = execute_sysml_candidate(
        consolidated,
        kernel_name=request.kernel_name,
        timeout_sec=request.execution_timeout_sec,
    )

    logs = _parse_execution_logs(kernel_out)
    state_traces = _parse_state_traces(logs)
    logs.extend(state_traces)

    constraint_manifest = _parse_constraint_manifest(logs)
    status_payload = kernel_out.execution_status_payload or "\n".join(logs)

    diagnostic_pack = None
    if kernel_out.bridge_error or not kernel_out.kernel_available:
        diagnostic_pack = {
            "error_type": "kernel_unavailable",
            "message": kernel_out.bridge_error or "SysML kernel not available",
            "suspect_variables": [],
            "recommended_repair_prompt": (
                "Install and register the SysML Jupyter kernel (kernel_name='sysml'), "
                "e.g. in OrbStack, then retry execution."
            ),
        }
    else:
        diagnostic_pack = _build_diagnostic_pack(status_payload, logs, constraint_manifest)

    has_error_marker = any(m.lower() in status_payload.lower() for m in _ERROR_MARKERS)
    failed_constraints = any(
        c.get("outcome") in ("failed", "violated", "false") for c in constraint_manifest
    )
    success = (
        kernel_out.kernel_available
        and kernel_out.bridge_error is None
        and not has_error_marker
        and not failed_constraints
        and bool(status_payload or logs)
    )

    return ExecutionResult(
        success=success,
        execution_status_payload=status_payload,
        execution_logs=logs,
        constraint_manifest=constraint_manifest,
        diagnostic_pack=diagnostic_pack,
        raw_kernel_messages=kernel_out.raw_kernel_messages,
        consolidated_payload=consolidated,
        extracted_topology=topology,
        harness_block=harness_block,
    )


def _cli() -> None:
    """Smoke CLI: extract + synthesize harness; optional kernel run with --execute."""
    import argparse
    from pathlib import Path

    parser = argparse.ArgumentParser(description="SysML v2 execution harness smoke")
    parser.add_argument("sysml_file", help="Path to candidate .sysml file")
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Run headless Jupyter SysML kernel (requires kernel spec 'sysml')",
    )
    parser.add_argument("-o", "--output", help="Write JSON result to file")
    args = parser.parse_args()

    code = Path(args.sysml_file).read_text(encoding="utf-8")
    req = ExecutionRequest(candidate_sysml=code)
    if args.execute:
        result = run_sysml_execution(req)
    else:
        topology = extract_topology(code)
        harness = build_harness_block(topology, req)
        consolidated = build_consolidated_payload(code, harness)
        result = ExecutionResult(
            success=True,
            execution_status_payload="dry-run (harness only; pass --execute for kernel)",
            execution_logs=[],
            constraint_manifest=[],
            diagnostic_pack=None,
            raw_kernel_messages=[],
            consolidated_payload=consolidated,
            extracted_topology=topology,
            harness_block=harness,
        )

    payload = result.to_dict()
    text = json.dumps(payload, indent=2)
    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")
        print(f"Wrote {args.output}")
    else:
        print(text)


if __name__ == "__main__":
    _cli()


def run_sysml_execution_from_file(
    sysml_path: str,
    *,
    target_behaviors: Optional[List[str]] = None,
    target_invariants: Optional[List[str]] = None,
    simulation_vectors: Optional[Dict[str, Any]] = None,
    kernel_name: str = "sysml",
    execution_timeout_sec: float = 120.0,
) -> ExecutionResult:
    """Convenience wrapper: load a ``.sysml`` file and execute."""
    from pathlib import Path

    code = Path(sysml_path).read_text(encoding="utf-8")
    return run_sysml_execution(
        ExecutionRequest(
            candidate_sysml=code,
            target_behaviors=target_behaviors,
            target_invariants=target_invariants,
            simulation_vectors=simulation_vectors,
            kernel_name=kernel_name,
            execution_timeout_sec=execution_timeout_sec,
        )
    )
