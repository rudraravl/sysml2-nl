"""Turn an alignment report into grounded SysML repair guidance."""

from __future__ import annotations


def needs_repair(report: dict, threshold: float = 0.85) -> bool:
    summary = report.get("summary", {})
    similarity = summary.get("similarity")
    return bool(
        summary.get("domain_mismatch")
        or summary.get("reliability_flag")
        or similarity is None
        or similarity < threshold
    )


def build_repair_prompt(nl: str, sysml: str, report: dict, *,
                        max_mismatches: int = 12,
                        stage_feedback: str = "") -> str:
    """Build a concise repair prompt using only reported mismatches and evidence."""
    mismatches = report.get("mismatches", [])[:max_mismatches]
    lines = [
        "Repair the SysML v2 model so it faithfully implements the natural-language specification.",
        "Preserve correct model content. Do not invent requirements or components.",
        "Output only the complete corrected SysML v2 text, without markdown fences or prose.",
        "",
        "## Natural-language specification",
        nl.strip(),
        "",
        "## Current SysML v2 model",
        sysml.strip(),
        "",
        "## Semantic mismatches to repair",
    ]
    if not mismatches:
        lines.append("No localized semantic mismatch was available; use the stage feedback below.")
    for index, mismatch in enumerate(mismatches, 1):
        nl_answer = mismatch.get("nl", {})
        sysml_answer = mismatch.get("sysml", {})
        lines += [
            f"{index}. [{mismatch.get('severity', 'unknown')}] {mismatch.get('text', '')}",
            f"   Expected from NL: {nl_answer.get('answer', 'not_stated')}",
            f"   NL evidence: {nl_answer.get('evidence') or '(none)' }",
            f"   Found in SysML: {sysml_answer.get('answer', 'not_stated')}",
            f"   SysML evidence: {sysml_answer.get('evidence') or '(none)' }",
            f"   Outcome: {mismatch.get('outcome', 'unknown')}",
        ]
    if stage_feedback:
        lines += ["", "## Validation or execution feedback", stage_feedback.strip()]
    return "\n".join(lines).rstrip() + "\n"
