"""Turn an alignment report into grounded repair guidance for the model side."""

from __future__ import annotations

# Per-language wording for the repair prompt. The model-side answer key in a
# report ("sysml", "solidity") selects the entry.
LANGUAGES = {
    "sysml": {
        "display": "SysML",
        "artifact": "SysML v2 model",
        "output": "SysML v2 text",
        "preserve": "Do not invent requirements or components.",
    },
    "solidity": {
        "display": "Solidity",
        "artifact": "Solidity contract",
        "output": "Solidity source",
        "preserve": ("Do not invent functionality, roles, or tokens the specification "
                     "does not call for, and do not weaken existing access control, "
                     "input validation, or re-entrancy protection."),
    },
}


def needs_repair(report: dict, threshold: float = 0.85) -> bool:
    summary = report.get("summary", {})
    similarity = summary.get("similarity")
    return bool(
        summary.get("domain_mismatch")
        or summary.get("reliability_flag")
        or similarity is None
        or similarity < threshold
    )


def build_repair_prompt(nl: str, model_text: str, report: dict, *,
                        max_mismatches: int = 12,
                        stage_feedback: str = "",
                        language: dict | None = None) -> str:
    """Build a concise repair prompt using only reported mismatches and evidence."""
    key = report.get("model_key", "sysml")
    lang = dict(LANGUAGES.get(key, LANGUAGES["sysml"]))
    lang.update(language or {})

    mismatches = report.get("mismatches", [])[:max_mismatches]
    lines = [
        f"Repair the {lang['artifact']} so it faithfully implements the "
        "natural-language specification.",
        f"Preserve correct content. {lang['preserve']}",
        f"Output only the complete corrected {lang['output']}, without markdown "
        "fences or prose.",
        "",
        "## Natural-language specification",
        nl.strip(),
        "",
        f"## Current {lang['artifact']}",
        model_text.strip(),
        "",
        "## Semantic mismatches to repair",
    ]
    if not mismatches:
        lines.append("No localized semantic mismatch was available; use the stage feedback below.")
    for index, mismatch in enumerate(mismatches, 1):
        nl_answer = mismatch.get("nl", {})
        model_answer = mismatch.get(key, {})
        lines += [
            f"{index}. [{mismatch.get('severity', 'unknown')}] {mismatch.get('text', '')}",
            f"   Expected from NL: {nl_answer.get('answer', 'not_stated')}",
            f"   NL evidence: {nl_answer.get('evidence') or '(none)' }",
            f"   Found in {lang['display']}: {model_answer.get('answer', 'not_stated')}",
            f"   {lang['display']} evidence: {model_answer.get('evidence') or '(none)' }",
            f"   Outcome: {mismatch.get('outcome', 'unknown')}",
        ]
    if stage_feedback:
        lines += ["", "## Validation or execution feedback", stage_feedback.strip()]
    return "\n".join(lines).rstrip() + "\n"
