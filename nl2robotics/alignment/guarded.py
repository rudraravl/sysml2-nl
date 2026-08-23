"""Monotonic, owner-scoped semantic repair over fully reevaluated candidates."""

from __future__ import annotations

from collections.abc import Callable

from nl2robotics.modelica.pipeline import clean_code
from nl2robotics.openusd.pipeline import clean_usda

from .repair import build_owner_repair_prompt


Evaluate = Callable[[str, str, int], dict]


def guarded_semantic_repair(baseline: dict, ask, evaluate: Evaluate, *,
                            max_repairs: int = 1) -> dict:
    """Attempt deterministic single-owner repairs and retain only improvements."""
    current = baseline
    attempts = []
    for attempt in range(1, max_repairs + 1):
        actions = _direct_actions(current.get("alignment", {}))
        if len(actions) != 1:
            break
        action = actions[0]
        owner = action["owner"]
        source = current[owner]
        prompt = build_owner_repair_prompt(owner, source, action["violations"])
        try:
            response = ask(prompt)
            repaired = clean_code(response) if owner == "modelica" else clean_usda(response)
        except Exception as exc:
            attempts.append({
                "attempt": attempt, "owner": owner, "accepted": False,
                "failure_stage": "repair_generation", "error": str(exc),
            })
            break
        if repaired == source:
            attempts.append({
                "attempt": attempt, "owner": owner, "accepted": False,
                "failure_stage": "unchanged_candidate",
            })
            break
        candidate_modelica = repaired if owner == "modelica" else current["modelica"]
        candidate_openusd = repaired if owner == "openusd" else current["openusd"]
        candidate = evaluate(candidate_modelica, candidate_openusd, attempt)
        candidate_quality = quality_tuple(candidate)
        current_quality = quality_tuple(current)
        accepted = (
            _no_regression(current, candidate)
            and candidate_quality > current_quality
        )
        attempts.append({
            "attempt": attempt,
            "owner": owner,
            "accepted": accepted,
            "quality_before": list(current_quality),
            "quality_after": list(candidate_quality),
            "blocking_before": _blocking(current),
            "blocking_after": _blocking(candidate),
            "candidate": candidate,
        })
        if not accepted:
            break
        current = candidate
        if _blocking(current) == 0:
            break
    return {
        "strategy": "deterministic_single_owner_monotonic",
        "max_repairs": max_repairs,
        "repairs_attempted": len(attempts),
        "repairs_accepted": sum(item.get("accepted") is True for item in attempts),
        "attempts": attempts,
        "final": current,
    }


def quality_tuple(candidate: dict) -> tuple:
    hybrid = candidate.get("hybrid", {})
    alignment = candidate.get("alignment", {})
    summary = alignment.get("summary", {})
    properties = hybrid.get("properties", [])
    property_pass = bool(properties) and all(
        item.get("passed") is True for item in properties
    )
    semantic_score = summary.get("weighted_semantic_score")
    coverage = summary.get("evidence_coverage")
    return (
        int(candidate.get("modelica_passed") is True),
        int(candidate.get("openusd_passed") is True),
        int(hybrid.get("fmu", {}).get("success") is True),
        int(hybrid.get("contract", {}).get("success") is True),
        int(hybrid.get("execution", {}).get("success") is True),
        int(property_pass),
        int(alignment.get("passed") is True),
        float(semantic_score) if isinstance(semantic_score, (int, float)) else -1.0,
        float(coverage) if isinstance(coverage, (int, float)) else 0.0,
        -_blocking(candidate),
    )


def _no_regression(before: dict, after: dict) -> bool:
    before_quality = quality_tuple(before)
    after_quality = quality_tuple(after)
    return all(not bool(old) or bool(new)
               for old, new in zip(before_quality[:7], after_quality[:7]))


def _direct_actions(alignment: dict) -> list[dict]:
    return [
        item for item in alignment.get("repair_plan", {}).get("actions", [])
        if item.get("owner") in {"modelica", "openusd"}
        and item.get("violations")
    ]


def _blocking(candidate: dict) -> int:
    value = candidate.get("alignment", {}).get("summary", {}).get(
        "blocking_violations", 0
    )
    return int(value) if isinstance(value, int) else 0
