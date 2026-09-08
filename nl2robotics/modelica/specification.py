"""Modelica-only NL/artifact and runtime-specification alignment."""

from __future__ import annotations

from dataclasses import asdict
import hashlib
import json

from nl2robotics.alignment.bank import family_weight
from nl2robotics.alignment.judge import answer_artifact_questions
from nl2robotics.alignment.questions import FocusedQuestion


_COLLECTION_FAMILIES = {
    "entities": "entity_presence",
    "joints": "joint_topology",
    "parameters": "parameter",
    "dynamics": "dynamics",
    "controllers": "controller_kind",
    "actuators": "actuator",
    "sensors": "sensor_presence",
    "environment": "environment",
}


def evaluate_modelica_specification(
    requirement_ir: dict,
    modelica: str,
    contract: dict,
    execution: dict,
    *,
    ask=None,
) -> dict:
    """Combine native contract/trace verdicts with a labeled semantic judge."""
    questions = _static_questions(requirement_ir)
    judged = (
        answer_artifact_questions(questions, modelica, "modelica", ask)
        if ask is not None else {}
    )
    rows = []
    for question in questions:
        answer = judged.get(question.id, _unknown("semantic judge disabled"))
        # A direct, evidence-backed contradiction is a semantic gate. Missing
        # evidence stays unknown and reduces coverage without becoming a pass.
        if answer.get("status") == "violated":
            answer = {**answer, "blocking": True}
        rows.append(_row(question, answer))

    clock = requirement_ir.get("clock")
    if isinstance(clock, dict):
        matched = _clock_matches(clock, execution.get("clock"))
        rows.append(_deterministic_row(
            "timing", "clock", "runtime clock preserves grounded timing",
            matched,
            "executed clock matches the grounded contract" if matched
            else "executed clock does not match the grounded contract",
        ))

    resolved_interfaces = {
        item.get("interface_id")
        for item in execution.get("contract", {}).get("resolved_mappings", [])
    }
    for interface in requirement_ir.get("interfaces", []):
        if interface.get("required", True) is not True:
            continue
        matched = interface.get("id") in resolved_interfaces
        rows.append(_deterministic_row(
            "interface", str(interface.get("id")),
            "required observable is present in the exported FMU",
            matched,
            "resolved required FMU output" if matched else
            "required FMU output was not resolved",
        ))

    resolved_facts = {
        item.get("fact_id")
        for item in execution.get("contract", {}).get(
            "resolved_parameter_mappings", []
        )
    }
    for mapping in contract.get("parameter_mappings", []):
        matched = mapping.get("fact_id") in resolved_facts
        rows.append(_deterministic_row(
            "parameter", str(mapping.get("fact_id")),
            "grounded scalar fact is preserved in FMU metadata",
            matched,
            "grounded FMU parameter matched value and unit" if matched else
            "grounded FMU parameter was missing or mismatched",
        ))

    property_results = {
        item.get("id", item.get("property_id")): item
        for item in execution.get("properties", [])
    }
    for prop in requirement_ir.get("properties", []):
        prop_id = str(prop.get("id"))
        outcome = property_results.get(prop_id)
        if outcome is None or outcome.get("status") == "unevaluable":
            answer = _unknown(
                "no evaluable runtime verdict" if outcome is None
                else str(outcome.get("detail") or "property is unevaluable")
            )
        elif outcome.get("passed") is True:
            answer = _answer("satisfied", "external trace monitor passed")
        else:
            answer = _answer(
                "violated", "external trace monitor found a violation",
                blocking=True,
            )
        question = _question(
            "property", prop_id,
            "external monitor evaluates the grounded property", prop,
        )
        rows.append(_row(question, answer))

    summary = _summary(rows)
    passed = summary["blocking_violations"] == 0
    claim_ready = passed and summary["counts"]["unknown"] == 0
    return {
        "stage": "modelica_specification_alignment",
        "schema_version": "1.0",
        "task_id": requirement_ir.get("task_id"),
        "enabled": True,
        "semantic_judge_enabled": ask is not None,
        "passed": passed,
        "artifact_gate_passed": passed,
        "claim_ready": claim_ready,
        "artifact_hashes": {
            "modelica_sha256": hashlib.sha256(modelica.encode("utf-8")).hexdigest(),
        },
        "policy": {
            "native_contract_and_trace_answers_can_block": True,
            "evidence_backed_semantic_contradictions_can_block": True,
            "unknowns_reduce_coverage_not_score": True,
            "claim_requires_zero_unknown_or_violated_questions": True,
            "property_thresholds_are_external_to_generated_code": True,
        },
        "summary": summary,
        "rows": rows,
    }


def skipped_modelica_specification(task_id: str) -> dict:
    return {
        "stage": "modelica_specification_alignment",
        "schema_version": "1.0",
        "task_id": task_id,
        "enabled": False,
        "skipped": True,
        "passed": True,
        "claim_ready": False,
        "summary": {
            "question_count": 0,
            "counts": {"satisfied": 0, "violated": 0, "unknown": 0,
                       "not_applicable": 0},
            "weighted_semantic_score": None,
            "evidence_coverage": 0.0,
            "blocking_violations": 0,
            "deterministic_violations": 0,
            "per_family": {},
        },
        "rows": [],
    }


def _static_questions(ir: dict) -> list[FocusedQuestion]:
    rows = []
    for collection, family in _COLLECTION_FAMILIES.items():
        for record in ir.get(collection, []):
            record_id = str(record.get("id"))
            rows.append(_question(
                family, f"{collection}.{record_id}",
                f"Modelica implements grounded {collection} fact {record_id}",
                record,
            ))
    return rows


def _question(family: str, subject_id: str, text: str,
              record: dict) -> FocusedQuestion:
    expected = {
        key: value for key, value in record.items()
        if key not in {"id", "evidence"}
    }
    slug = "".join(
        char.upper() if char.isalnum() else "-" for char in subject_id
    ).strip("-")
    return FocusedQuestion(
        id=f"MRQ-{family.upper().replace('_', '-')}-{slug}",
        family=family,
        text=text,
        expected=expected,
        owner="modelica",
        weight=family_weight(family),
        evidence=tuple(record.get("evidence", [])),
        subject_id=subject_id,
        deterministic_kind=family,
    )


def _deterministic_row(family: str, subject_id: str, text: str,
                       matched: bool, diagnostic: str) -> dict:
    question = _question(
        family, subject_id, text,
        {"id": subject_id, "evidence": []},
    )
    return _row(question, _answer(
        "satisfied" if matched else "violated",
        diagnostic,
        blocking=not matched,
    ))


def _row(question: FocusedQuestion, answer: dict) -> dict:
    return {
        "question": asdict(question),
        "nl": {
            "status": "satisfied",
            "source": "grounded_requirement_ir",
            "confidence": 1.0,
            "evidence": list(question.evidence),
        },
        "artifact": answer,
    }


def _answer(status: str, diagnostic: str, *, blocking: bool = False) -> dict:
    return {
        "status": status,
        "source": "deterministic_evidence",
        "confidence": 1.0,
        "evidence": diagnostic,
        "evidence_valid": True,
        "blocking": blocking,
        "repair_eligible": False,
    }


def _unknown(diagnostic: str) -> dict:
    return {
        "status": "unknown",
        "source": "modelica_semantic_alignment",
        "confidence": 0.0,
        "evidence": "",
        "evidence_valid": False,
        "diagnostic": diagnostic,
        "blocking": False,
        "repair_eligible": False,
    }


def _clock_matches(expected: dict, actual: object) -> bool:
    if not isinstance(actual, dict):
        return False
    try:
        frequency = float(expected["frequency_hz"])
        if "duration" in expected:
            start, stop = 0.0, float(expected["duration"])
        else:
            start = float(expected["start_time"])
            stop = float(expected["stop_time"])
        return all(abs(left - right) <= 1e-9 for left, right in (
            (frequency, float(actual["frequency_hz"])),
            (start, float(actual["start_time"])),
            (stop, float(actual["stop_time"])),
        ))
    except (KeyError, TypeError, ValueError):
        return False


def _summary(rows: list[dict]) -> dict:
    counts = {key: 0 for key in (
        "satisfied", "violated", "unknown", "not_applicable"
    )}
    assessed = satisfied = total = 0.0
    blocking = deterministic = 0
    families: dict[str, list[float]] = {}
    for row in rows:
        question = row["question"]
        answer = row["artifact"]
        status = answer["status"]
        counts[status] = counts.get(status, 0) + 1
        weight = float(question["weight"])
        total += weight
        if status in {"satisfied", "violated"}:
            assessed += weight
            families.setdefault(question["family"], [0.0, 0.0])[1] += weight
            if status == "satisfied":
                satisfied += weight
                families[question["family"]][0] += weight
        if answer.get("blocking"):
            blocking += 1
        if status == "violated" and answer.get("source") == "deterministic_evidence":
            deterministic += 1
    return {
        "question_count": len(rows),
        "counts": counts,
        "weighted_semantic_score": (
            round(satisfied / assessed, 6) if assessed else None
        ),
        "evidence_coverage": round(assessed / total, 6) if total else 0.0,
        "blocking_violations": blocking,
        "deterministic_violations": deterministic,
        "per_family": {
            key: round(value[0] / value[1], 6) if value[1] else None
            for key, value in sorted(families.items())
        },
    }
