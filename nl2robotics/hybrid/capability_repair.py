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

    Behavioral requirement violations and unevaluable qualitative properties
    are intentionally not repair triggers.  This loop addresses only FMU
    export, interface, initialization, execution, and trace-survival failures.
    """
    current = baseline
    attempts = []
    for attempt in range(1, max_repairs + 1):
        execution = current.get("execution", {})
        if execution.get("failure_stage") not in REPAIRABLE_FAILURE_STAGES:
            break
        prompt = build_capability_runtime_repair_prompt(
            requirement, current["modelica"], execution
        )
        try:
            repaired = clean_code(ask(prompt))
        except Exception as exc:
            attempts.append({
                "attempt": attempt,
                "accepted": False,
                "failure_stage": "repair_generation",
                "error": str(exc),
            })
            break
        if repaired == current["modelica"]:
            attempts.append({
                "attempt": attempt,
                "accepted": False,
                "failure_stage": "unchanged_candidate",
            })
            break
        candidate = evaluate(repaired, attempt)
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
        "behavioral_violations_are_repair_triggers": False,
        "max_repairs": max_repairs,
        "repairs_attempted": len(attempts),
        "repairs_accepted": sum(item.get("accepted") is True for item in attempts),
        "attempts": attempts,
        "final": current,
    }


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
    }
    return f"""{SYSTEM_PROMPT}

Repair only the Modelica candidate's FMU export or numerical runtime failure
using the grounded native feedback below. Preserve every grounded numeric
requirement, required output name, interface mapping, assertion, and intended
behavior. Do not delete dynamics or checks merely to make execution pass. Do
not change the OpenUSD artifact or contract. Prefer simple FMI-compatible
equations, explicit non-singular initial conditions, and physically justified
numerical regularization. Return one complete Modelica model and no prose.

Requirement:
{requirement}

Native FMU/runtime feedback:
{json.dumps(feedback, indent=2, sort_keys=True)}

Candidate:
{modelica}
"""
