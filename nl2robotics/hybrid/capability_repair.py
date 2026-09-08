"""Monotonic, execution-aware repair for broad Modelica capability models."""

from __future__ import annotations

from collections.abc import Callable
import json

from nl2robotics.modelica.pipeline import SYSTEM_PROMPT, clean_code


Evaluate = Callable[[str, int], dict]

REPAIRABLE_FAILURE_STAGES = frozenset({
    "fmu_export",
    "fmu_interface",
    "fmu_execution",
    "runtime_trace",
    "behavior_evaluation",
})


def guarded_capability_runtime_repair(
    requirement: str,
    baseline: dict,
    ask,
    evaluate: Evaluate,
    *,
    max_repairs: int = 1,
) -> dict:
    """Retain only a recompiling, real-execution stage improvement.

    This loop addresses FMU export, interface, initialization, execution,
    trace-survival failures, and deterministic trace-property violations.
    Qualitative properties without a deterministic evaluator are never repair
    targets because changing code cannot manufacture an evaluation oracle.
    """
    current = baseline
    attempts = []
    infrastructure_error = capability_runtime_infrastructure_error(
        current.get("execution", {})
    )
    for attempt in range(1, max_repairs + 1):
        if infrastructure_error is not None:
            break
        execution = current.get("execution", {})
        if not _repairable_execution_failure(execution):
            break
        prompt = build_capability_runtime_repair_prompt(
            requirement, current["modelica"], execution
        )
        # Provider/transport exceptions are infrastructure state, not model
        # outcomes.  Let the study runner stop or mark the cell for rerun.
        repaired = clean_code(ask(prompt))
        if repaired == current["modelica"]:
            attempts.append({
                "attempt": attempt,
                "accepted": False,
                "failure_stage": "unchanged_candidate",
            })
            break
        candidate = evaluate(repaired, attempt)
        infrastructure_error = capability_runtime_infrastructure_error(
            candidate.get("execution", {})
        )
        if infrastructure_error is not None:
            attempts.append({
                "attempt": attempt,
                "accepted": False,
                "failure_stage": "infrastructure",
                "error": infrastructure_error,
                "candidate": candidate,
            })
            break
        before = capability_runtime_quality(current)
        after = capability_runtime_quality(candidate)
        accepted = bool(
            candidate.get("modelica_passed") is True
            and candidate.get("identity_preserved") is True
            and candidate.get("pre_alignment_passed") is True
            and after > before
        )
        attempts.append({
            "attempt": attempt,
            "accepted": accepted,
            "quality_before": list(before),
            "quality_after": list(after),
            "candidate": candidate,
        })
        if not accepted:
            break
        current = candidate
        if current.get("execution", {}).get("execution_completed") is True:
            break
    return {
        "strategy": "modelica_runtime_monotonic_recompile_realign_reexecute",
        "repair_scope": sorted(REPAIRABLE_FAILURE_STAGES),
        "behavioral_violations_are_repair_triggers": True,
        "unevaluable_properties_are_repair_triggers": False,
        "max_repairs": max_repairs,
        "repairs_attempted": len(attempts),
        "repairs_accepted": sum(item.get("accepted") is True for item in attempts),
        "infrastructure_error": infrastructure_error,
        "attempts": attempts,
        "final": current,
    }


def capability_runtime_infrastructure_error(execution: dict) -> str | None:
    """Return a native infrastructure diagnostic without repairing around it."""
    stack: list[object] = [execution]
    while stack:
        item = stack.pop()
        if isinstance(item, dict):
            if (
                item.get("stage") == "infrastructure"
                and item.get("severity") == "error"
            ):
                return str(item.get("message") or "native runtime unavailable")
            stack.extend(item.values())
        elif isinstance(item, list):
            stack.extend(item)
    return None


def capability_runtime_quality(candidate: dict) -> tuple[int, ...]:
    """Order candidates only by structural progress through real execution."""
    report = candidate.get("execution", {})
    fmu = report.get("fmu", {})
    contract = report.get("contract", {})
    runtime = report.get("execution", {})
    trace = report.get("trace_gate", {})
    return (
        int(candidate.get("modelica_passed") is True),
        int(candidate.get("identity_preserved") is True),
        int(candidate.get("pre_alignment_passed") is True),
        int(fmu.get("success") is True),
        int(contract.get("success") is True),
        int(runtime.get("initialized") is True),
        int(runtime.get("success") is True),
        int(trace.get("success") is True),
        int(report.get("execution_completed") is True),
        sum(item.get("status") != "unevaluable"
            for item in report.get("properties", [])),
        sum(item.get("passed") is True
            for item in report.get("properties", [])),
        int(report.get("behavior_passed") is True),
    )


def _repairable_execution_failure(execution: dict) -> bool:
    stage = execution.get("failure_stage")
    if stage != "behavior_evaluation":
        return stage in REPAIRABLE_FAILURE_STAGES
    return any(
        item.get("status") == "violated"
        for item in execution.get("properties", [])
    )


def build_capability_runtime_repair_prompt(
    requirement: str, modelica: str, execution: dict
) -> str:
    feedback = {
        "failure_stage": execution.get("failure_stage"),
        "error": execution.get("error"),
        "fmu_diagnostics": execution.get("fmu", {}).get("diagnostics", []),
        "interface_issues": execution.get("contract", {}).get("issues", []),
        "runtime_diagnostics": execution.get("execution", {}).get(
            "diagnostics", []
        ),
        "trace_gate": execution.get("trace_gate", {}),
        "property_results": execution.get("properties", []),
    }
    return f"""{SYSTEM_PROMPT}

Repair only the Modelica candidate's FMU export, numerical runtime, or concrete
trace-property violation using the grounded native feedback below. Preserve
every grounded numeric requirement, required output name, interface mapping,
property threshold, and intended behavior. Never replace a dynamic signal with
a constant chosen to satisfy a monitor, delete dynamics or checks, clamp an
output solely to hide a violation, or modify the grounded execution contract.
Prefer simple FMI-compatible equations, explicit non-singular initial
conditions, and physically justified numerical regularization. Return one
complete Modelica model and no prose.

Requirement:
{requirement}

Native FMU/runtime feedback:
{json.dumps(feedback, indent=2, sort_keys=True)}

Candidate:
{modelica}
"""
