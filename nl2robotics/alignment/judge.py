"""Optional twin-blind LLM answering for facts not covered by formal evidence."""

from __future__ import annotations

import json

from .questions import FocusedQuestion


VALID_STATUSES = {"satisfied", "violated", "unknown", "not_applicable"}


def answer_artifact_questions(questions: list[FocusedQuestion], artifact: str,
                              modality: str, ask) -> dict[str, dict]:
    if not questions:
        return {}
    raw = ask(_answer_prompt(questions, artifact, modality))
    return parse_answers(raw, questions, artifact, modality)


def parse_answers(raw: str, questions: list[FocusedQuestion], artifact: str,
                  modality: str) -> dict[str, dict]:
    data = _parse_json(raw)
    rows = data.get("answers", []) if isinstance(data, dict) else []
    allowed = {item.id for item in questions}
    result: dict[str, dict] = {}
    for row in rows if isinstance(rows, list) else []:
        if not isinstance(row, dict) or row.get("qid") not in allowed:
            continue
        qid = row["qid"]
        status = str(row.get("status", "unknown")).strip().lower()
        evidence = " ".join(str(row.get("evidence", "")).split())
        confidence = _confidence(row.get("confidence"))
        evidence_valid = bool(evidence) and evidence in artifact
        if status not in VALID_STATUSES or (status != "unknown" and not evidence_valid):
            status = "unknown"
            confidence = 0.0
        result[qid] = {
            "status": status,
            "source": f"llm_{modality}",
            "confidence": confidence,
            "evidence": evidence if evidence_valid else "",
            "evidence_valid": evidence_valid,
            "blocking": False,
            "repair_eligible": False,
        }
    for question in questions:
        result.setdefault(question.id, {
            "status": "unknown",
            "source": f"llm_{modality}",
            "confidence": 0.0,
            "evidence": "",
            "evidence_valid": False,
            "blocking": False,
            "repair_eligible": False,
        })
    return result


def _answer_prompt(questions: list[FocusedQuestion], artifact: str,
                   modality: str) -> str:
    rendered = "\n".join(
        f"- {item.id}: {item.text} Expected facts: "
        f"{json.dumps(item.expected, sort_keys=True)}"
        for item in questions
    )
    return f"""Evaluate concrete robotics requirements against ONE {modality} artifact.

Use only the artifact below. Do not infer facts from naming conventions or from
what a reasonable robot would contain. For each question return one status:
satisfied, violated, unknown, or not_applicable. `violated` requires direct
contradictory artifact evidence. Missing or ambiguous evidence is `unknown`.
Evidence must be one exact, compact substring copied from the artifact.

Return strict JSON only:
{{"answers":[{{"qid":"...","status":"satisfied|violated|unknown|not_applicable","evidence":"exact substring","confidence":0.0}}]}}

Questions:
{rendered}

Artifact:
```{modality}
{artifact.strip()}
```
"""


def _parse_json(raw: str) -> dict:
    text = raw.strip()
    if "```" in text:
        text = max((part.removeprefix("json").strip() for part in text.split("```")),
                   key=len)
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end < start:
        raise ValueError("alignment judge returned no JSON object")
    data = json.loads(text[start:end + 1])
    if not isinstance(data, dict):
        raise ValueError("alignment judge JSON root must be an object")
    return data


def _confidence(value: object) -> float:
    try:
        return max(0.0, min(1.0, float(value)))
    except (TypeError, ValueError):
        return 0.0
