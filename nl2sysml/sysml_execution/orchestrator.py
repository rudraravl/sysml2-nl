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

from .extractor import classify_topology, extract_topology, requires_layer2
from .harness_builder import build_consolidated_payload, build_harness_block
from .models import (
    ExecutionRequest,
    ExecutionResult,
    HarnessMetadata,
    KernelExecutionOutput,
    Layer2Status,
    ModelProfile,
)
from .sysml_runtime_bridge import execute_sysml_candidate
from .vector_fallback import build_preset_vector_attempts, required_action_inputs

_ERROR_MARKERS = (
    "[ERROR]",
    "ERROR:",
    "Constraint Violation",
    "constraint violation",
    "AssertionError",
)
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
_ACTION_TRACE_RE = re.compile(
    r"(?:perform|action)\s+[`'\"]?([^`'\"]+)[`'\"]?\s*(?:completed|started|done)?",
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


def _parse_action_traces(logs: List[str]) -> List[str]:
    traces: List[str] = []
    for log in logs:
        for m in _ACTION_TRACE_RE.finditer(log):
            traces.append(f"action_trace:{m.group(1).strip()}")
    return traces


def _compute_syntax_ok(kernel_out: KernelExecutionOutput, logs: List[str], status_payload: str) -> bool:
    if not kernel_out.kernel_available or kernel_out.bridge_error:
        return False
    combined_lower = (status_payload + "\n" + "\n".join(logs)).lower()
    has_error_marker = any(m.lower() in combined_lower for m in _ERROR_MARKERS)
    shell_status = None
    if kernel_out.shell_reply:
        shell_status = (kernel_out.shell_reply.get("content") or {}).get("status")
    shell_ok = shell_status in (None, "ok")
    return shell_ok and not has_error_marker and not kernel_out.error_lines


def _compute_behavior_ok(
    syntax_ok: bool,
    harness_meta: HarnessMetadata,
    logs: List[str],
    constraint_manifest: List[Dict[str, Any]],
) -> bool:
    if harness_meta.profile == ModelProfile.ANALYSIS_TOOL:
        return True
    if not harness_meta.probes_runnable:
        return False
    if not syntax_ok:
        return False
    failed_constraints = any(
        c.get("outcome") in ("failed", "violated", "false") for c in constraint_manifest
    )
    if failed_constraints:
        return False
    has_executable_probe = (
        harness_meta.has_perform_probe
        or harness_meta.has_assign_probe
        or harness_meta.has_assert_probe
    )
    if not has_executable_probe:
        return False
    action_traces = _parse_action_traces(logs)
    if action_traces:
        return True
    # Structural reachability: kernel compiled harness with real probes (no log traces yet).
    return syntax_ok and harness_meta.probes_emitted > 0


def _build_layer2_bypassed_pack(
    harness_meta: HarnessMetadata,
    profile: ModelProfile,
) -> Dict[str, Any]:
    reasons = list(harness_meta.skipped_reasons)
    if not harness_meta.probes_runnable:
        reasons.append("harness probes not runnable")
    message = (
        "Layer 2 bypassed: model requires behavioral verification but harness could not "
        f"emit runnable probes (profile={profile.value})."
    )
    if reasons:
        message += f" Reasons: {'; '.join(reasons)}"
    return {
        "error_type": "layer2_bypassed",
        "message": message,
        "suspect_variables": [],
        "recommended_repair_prompt": (
            "Layer 2 was not executed rigorously. "
            f"{message} "
            "Ensure extraction finds composite actions / parts and provide simulation_vectors "
            "for input pins where needed."
        ),
        "skipped_reasons": reasons,
        "profile": profile.value,
    }


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
    if "[ERROR]" in combined or "ERROR:" in combined.upper():
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


def _run_single_execution(request: ExecutionRequest) -> ExecutionResult:
    """
    Run extraction, harness synthesis, and headless kernel execution.
    Returns structured JSON-serializable result via ``ExecutionResult.to_dict()``.
    """
    topology = extract_topology(request.candidate_sysml)
    profile = classify_topology(topology)
    layer2_required = requires_layer2(topology, profile)

    harness_result = build_harness_block(topology, request)
    harness_block = harness_result.harness_block
    harness_meta = harness_result.metadata
    consolidated = build_consolidated_payload(request.candidate_sysml, harness_block)

    kernel_out = execute_sysml_candidate(
        consolidated,
        kernel_name=request.kernel_name,
        timeout_sec=request.execution_timeout_sec,
        jupyter_path=request.jupyter_path,
        kernel_ready_timeout_sec=request.kernel_ready_timeout_sec,
    )

    logs = _parse_execution_logs(kernel_out)
    logs.extend(_parse_state_traces(logs))
    logs.extend(_parse_action_traces(logs))

    constraint_manifest = _parse_constraint_manifest(logs)
    status_payload = kernel_out.execution_status_payload or "\n".join(logs)

    syntax_ok = _compute_syntax_ok(kernel_out, logs, status_payload)

    if profile == ModelProfile.ANALYSIS_TOOL:
        layer2_status = Layer2Status.NOT_REQUIRED.value
        behavior_ok = True
        if kernel_out.bridge_error or not kernel_out.kernel_available:
            diagnostic_pack = {
                "error_type": "kernel_unavailable",
                "message": kernel_out.bridge_error or "SysML kernel not available",
                "suspect_variables": [],
                "recommended_repair_prompt": (
                    "Install the SysML Jupyter kernel for syntax validation. "
                    "Layer 2 behavioral execution is not required for analysis/tooling models."
                ),
            }
            success = False
        else:
            diagnostic_pack = _build_diagnostic_pack(status_payload, logs, constraint_manifest)
            success = syntax_ok
    elif kernel_out.bridge_error or not kernel_out.kernel_available:
        layer2_status = Layer2Status.KERNEL_UNAVAILABLE.value
        diagnostic_pack = {
            "error_type": "kernel_unavailable",
            "message": kernel_out.bridge_error or "SysML kernel not available",
            "suspect_variables": [],
            "recommended_repair_prompt": (
                "Install the SysML Jupyter kernel in the project .venv "
                "(``jupyter kernelspec list`` should show sysml), "
                "or set SYSML_JUPYTER_PATH to .venv/share/jupyter."
            ),
        }
        behavior_ok = False
        success = False
    elif not layer2_required:
        layer2_status = Layer2Status.NOT_REQUIRED.value
        behavior_ok = True
        diagnostic_pack = _build_diagnostic_pack(status_payload, logs, constraint_manifest)
        success = syntax_ok
    elif not harness_meta.probes_runnable:
        layer2_status = Layer2Status.BYPASSED.value
        diagnostic_pack = _build_layer2_bypassed_pack(harness_meta, profile)
        behavior_ok = False
        success = False
    else:
        behavior_ok = _compute_behavior_ok(syntax_ok, harness_meta, logs, constraint_manifest)
        if behavior_ok:
            layer2_status = Layer2Status.VERIFIED.value
            diagnostic_pack = _build_diagnostic_pack(status_payload, logs, constraint_manifest)
        else:
            layer2_status = Layer2Status.BYPASSED.value
            diagnostic_pack = _build_layer2_bypassed_pack(harness_meta, profile)
            if syntax_ok:
                diagnostic_pack["message"] = (
                    "Layer 2 harness compiled but behavioral verification did not complete."
                )
        success = syntax_ok and behavior_ok

    if diagnostic_pack is None and not success and layer2_status == Layer2Status.VERIFIED.value:
        diagnostic_pack = _build_diagnostic_pack(status_payload, logs, constraint_manifest)

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
        syntax_ok=syntax_ok,
        behavior_ok=behavior_ok,
        layer2_status=layer2_status,
        harness_metadata=harness_meta.to_dict(),
        vector_source="provided" if request.simulation_vectors else None,
        semantic_validity="not_assessed" if request.simulation_vectors else None,
        selected_simulation_vectors=request.simulation_vectors,
    )


def run_sysml_execution(request: ExecutionRequest) -> ExecutionResult:
    """
    Run one explicit vector, or try bounded preset vectors for unspecified action inputs.

    Preset acceptance means only that the kernel accepted the model plus harness. It does
    not establish that the selected values are semantically valid engineering inputs.
    """
    if not request.try_preset_vectors:
        return _run_single_execution(request)

    topology = extract_topology(request.candidate_sysml)
    required_inputs = required_action_inputs(topology, request.target_behaviors)
    missing_inputs = [
        name for name in required_inputs if name not in (request.simulation_vectors or {})
    ]
    if not missing_inputs:
        return _run_single_execution(request)
    attempts = build_preset_vector_attempts(
        required_inputs,
        request.simulation_vectors,
        request.preset_values,
    )
    if not attempts:
        return _run_single_execution(request)

    attempt_log: List[Dict[str, Any]] = []
    last_result: Optional[ExecutionResult] = None
    for vectors in attempts:
        attempt_request = ExecutionRequest(
            candidate_sysml=request.candidate_sysml,
            target_behaviors=request.target_behaviors,
            target_invariants=request.target_invariants,
            simulation_vectors=vectors,
            try_preset_vectors=False,
            kernel_name=request.kernel_name,
            execution_timeout_sec=request.execution_timeout_sec,
            kernel_ready_timeout_sec=request.kernel_ready_timeout_sec,
            jupyter_path=request.jupyter_path,
        )
        result = _run_single_execution(attempt_request)
        accepted = result.syntax_ok and bool(
            result.harness_metadata and result.harness_metadata.get("probes_runnable")
        )
        attempt_log.append(
            {
                "simulation_vectors": vectors,
                "kernel_accepted": accepted,
                "syntax_ok": result.syntax_ok,
                "layer2_status": result.layer2_status,
            }
        )
        result.vector_attempts = list(attempt_log)
        result.vector_source = "preset_fallback"
        result.semantic_validity = "unknown"
        result.selected_simulation_vectors = vectors if accepted else None
        last_result = result
        if accepted or result.layer2_status == Layer2Status.KERNEL_UNAVAILABLE.value:
            return result

    assert last_result is not None
    return last_result


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
    parser.add_argument(
        "--try-preset-vectors",
        action="store_true",
        help="Try preset values for unspecified action inputs; semantic validity remains unknown",
    )
    args = parser.parse_args()

    code = Path(args.sysml_file).read_text(encoding="utf-8")
    req = ExecutionRequest(
        candidate_sysml=code,
        try_preset_vectors=args.try_preset_vectors,
    )
    if args.execute:
        result = run_sysml_execution(req)
    else:
        topology = extract_topology(code)
        harness_result = build_harness_block(topology, req)
        profile = classify_topology(topology)
        layer2_required = requires_layer2(topology, profile)
        result = ExecutionResult(
            success=not layer2_required or harness_result.metadata.probes_runnable,
            execution_status_payload="dry-run (harness only; pass --execute for kernel)",
            execution_logs=[],
            constraint_manifest=[],
            diagnostic_pack=(
                _build_layer2_bypassed_pack(harness_result.metadata, profile)
                if layer2_required and not harness_result.metadata.probes_runnable
                else None
            ),
            raw_kernel_messages=[],
            consolidated_payload=build_consolidated_payload(code, harness_result.harness_block),
            extracted_topology=topology,
            harness_block=harness_result.harness_block,
            syntax_ok=False,
            behavior_ok=False,
            layer2_status=(
                Layer2Status.BYPASSED.value
                if layer2_required and not harness_result.metadata.probes_runnable
                else Layer2Status.NOT_REQUIRED.value
            ),
            harness_metadata=harness_result.metadata.to_dict(),
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
    try_preset_vectors: bool = False,
    preset_values: Optional[List[Any]] = None,
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
            try_preset_vectors=try_preset_vectors,
            preset_values=preset_values,
            kernel_name=kernel_name,
            execution_timeout_sec=execution_timeout_sec,
        )
    )
