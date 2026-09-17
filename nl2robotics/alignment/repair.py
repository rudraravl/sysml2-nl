"""Route only grounded deterministic mismatches to artifact owners."""

from __future__ import annotations


def build_repair_plan(report: dict) -> dict:
    grouped = {"modelica": [], "openusd": [], "cross_profile": [], "runtime": []}
    for row in report.get("rows", []):
        answer = row.get("artifact", {})
        if answer.get("repair_eligible") is not True:
            continue
        grouped.setdefault(row["question"]["owner"], []).append({
            "qid": row["question"]["id"],
            "family": row["question"]["family"],
            "text": row["question"]["text"],
            "expected": row["question"]["expected"],
            "evidence": answer.get("evidence", ""),
            "diagnostic": answer.get("diagnostic", ""),
        })
    actions = [
        {"owner": owner, "violations": violations}
        for owner, violations in grouped.items() if violations
    ]
    direct = [item for item in actions if item["owner"] in {"modelica", "openusd"}]
    automatic_allowed = len(actions) == 1 and len(direct) == 1
    return {
        "strategy": "owner_scoped_deterministic_only",
        "action_count": len(actions),
        "actions": actions,
        "automatic_repair_allowed": automatic_allowed,
        "reason": (
            "Automatic repair is limited to one deterministic artifact owner and "
            "must pass the guarded full-revalidation quality gate."
        ),
    }


def build_owner_repair_prompt(owner: str, source: str, violations: list[dict]) -> str:
    if owner not in {"modelica", "openusd"}:
        raise ValueError("only Modelica and OpenUSD artifacts can be repaired directly")
    language = "Modelica" if owner == "modelica" else "textual USDA"
    rows = "\n".join(
        f"- [{item['qid']}] {item['text']} Expected: {item['expected']}. "
        f"Diagnostic: {item.get('diagnostic') or '(none)'}"
        for item in violations
    )
    return f"""Repair only the grounded defects listed below in this {language} artifact.
Preserve all unrelated content, identifiers, interfaces, and correct behavior.
Do not invent requirements. Return the complete corrected artifact only.

Grounded defects:
{rows}

Current artifact:
{source}
"""
