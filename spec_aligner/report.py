from __future__ import annotations

import json
from pathlib import Path

from .schemas import AlignmentResult, Mismatch, SpecDocument, SpecItem


def report_data(nl_doc: SpecDocument, sysml_doc: SpecDocument, alignment: AlignmentResult, mismatches: list[Mismatch]) -> dict:
    return {
        "nl_specs": nl_doc.to_dict(),
        "sysml_specs": sysml_doc.to_dict(),
        "alignment": alignment.to_dict(),
        "mismatches": [m.to_dict() for m in mismatches],
        "summary": {
            "nl_spec_count": len(nl_doc.specs),
            "sysml_spec_count": len(sysml_doc.specs),
            "matched_count": len(alignment.matched_pairs),
            "uncertain_match_count": len(alignment.uncertain_pairs),
            "mismatch_count": len(mismatches),
        },
    }


def write_json(path: str | Path, data: dict) -> None:
    Path(path).write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


def render_markdown(nl_doc: SpecDocument, sysml_doc: SpecDocument, mismatches: list[Mismatch]) -> str:
    lines = [
        "# Specification Comparison Report",
        "",
        "## Summary",
        "",
        f"- Natural-language specs: {len(nl_doc.specs)}",
        f"- SysML specs: {len(sysml_doc.specs)}",
        f"- Mismatches / review items: {len(mismatches)}",
        "",
        "## Natural-Language Specs",
        "",
    ]
    lines.extend(_spec_lines(nl_doc.specs))
    lines.extend(["", "## SysML Specs", ""])
    lines.extend(_spec_lines(sysml_doc.specs))
    lines.extend(["", "## Mismatch Report", ""])

    if not mismatches:
        lines.append("No mismatches found by the current extractor and alignment rules.")
        return "\n".join(lines).rstrip() + "\n"

    for severity in ("high", "medium", "low"):
        group = [m for m in mismatches if m.severity == severity]
        if not group:
            continue
        lines.extend([f"### {severity.title()} Severity", ""])
        for mm in group:
            lines.extend(_mismatch_lines(mm))
            lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def write_markdown(path: str | Path, nl_doc: SpecDocument, sysml_doc: SpecDocument, mismatches: list[Mismatch]) -> None:
    Path(path).write_text(render_markdown(nl_doc, sysml_doc, mismatches), encoding="utf-8")


def _spec_lines(specs: list[SpecItem]) -> list[str]:
    if not specs:
        return ["No specs extracted."]
    lines = []
    for spec in specs:
        evidence = spec.source.span if spec.source else ""
        loc = ""
        if spec.source and spec.source.line_start:
            loc = f" lines {spec.source.line_start}-{spec.source.line_end}"
        pred = spec.predicate or spec.name
        lines.append(f"- `{spec.id}` `{spec.kind}` **{spec.name}**: {pred} (confidence {spec.confidence:.2f}){loc}")
        if evidence and evidence != pred:
            lines.append(f"  Evidence: `{_one_line(evidence)}`")
    return lines


def _mismatch_lines(mm: Mismatch) -> list[str]:
    lines = [
        f"#### {mm.summary}",
        "",
        f"- Class: `{mm.class_}`",
        f"- Confidence: {mm.confidence:.2f}",
    ]
    if mm.needs_human_review:
        lines.append("- Needs human review: yes")
    if mm.evidence.get("nl_span"):
        lines.extend(["", "Natural language says:", f"> {_one_line(mm.evidence['nl_span'])}"])
    if mm.evidence.get("sysml_span"):
        lines.extend(["", "SysML says:", "```sysml", mm.evidence["sysml_span"], "```"])
    lines.extend(["", "Diagnosis:", mm.details, "", "Suggested action:", mm.suggested_action])
    return lines


def _one_line(text: str) -> str:
    return " ".join(text.strip().split())
