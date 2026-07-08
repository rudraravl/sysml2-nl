from __future__ import annotations

from .schemas import AlignmentResult, Mismatch, SpecDocument, SpecItem


def diff(nl_doc: SpecDocument, sysml_doc: SpecDocument, alignment: AlignmentResult) -> list[Mismatch]:
    nl_by_id = {s.id: s for s in nl_doc.specs}
    sys_by_id = {s.id: s for s in sysml_doc.specs}
    out: list[Mismatch] = []

    for pair in alignment.matched_pairs + alignment.uncertain_pairs:
        nl = nl_by_id[pair.nl_spec_id]
        sys = sys_by_id[pair.sysml_spec_id]
        if nl.confidence < 0.6 or nl.metadata.get("ambiguous"):
            out.append(
                _mm(
                    out,
                    "ambiguous_requirement",
                    "low",
                    nl,
                    sys,
                    f"Ambiguous natural-language spec: {nl.name}.",
                    "The natural-language evidence is too vague to compare precisely against SysML.",
                    "Clarify the measurable requirement, then align or update the SysML model.",
                    nl.confidence,
                    True,
                )
            )
            continue
        if pair.needs_human_review:
            out.append(
                _mm(
                    out,
                    "parse_or_extraction_uncertain",
                    "low",
                    nl,
                    sys,
                    f"Uncertain alignment: {nl.name} vs {sys.name}.",
                    "The extracted specs look related, but the match score is low enough to require review.",
                    "Review whether these two specs describe the same system concern.",
                    pair.confidence,
                    True,
                )
            )
            continue
        conflict = _matched_conflict(nl, sys)
        if conflict:
            out.append(_mm(out, *conflict))

    for spec_id in alignment.nl_only:
        nl = nl_by_id[spec_id]
        cls = "ambiguous_requirement" if nl.confidence < 0.6 or nl.metadata.get("ambiguous") else "missing_in_model"
        severity = "low" if cls == "ambiguous_requirement" else _missing_severity(nl)
        action = "Clarify the natural-language requirement before modeling it." if cls == "ambiguous_requirement" else "Add or trace the corresponding SysML specification."
        out.append(
            _mm(
                out,
                cls,
                severity,
                nl,
                None,
                f"NL spec has no SysML counterpart: {nl.name}.",
                f"Natural language contains `{nl.predicate or nl.name}`, but no aligned SysML spec was found.",
                action,
                nl.confidence,
                cls == "ambiguous_requirement",
            )
        )

    for spec_id in alignment.sysml_only:
        sys = sys_by_id[spec_id]
        out.append(
            _mm(
                out,
                "extra_in_model",
                _extra_severity(sys),
                None,
                sys,
                f"SysML spec has no NL counterpart: {sys.name}.",
                f"SysML contains `{sys.predicate or sys.name}`, but no aligned natural-language spec was found.",
                "Check whether this model element is intended, or add/trace the source requirement.",
                sys.confidence,
                False,
            )
        )
    return out


def _matched_conflict(nl: SpecItem, sys: SpecItem):
    if nl.kind != sys.kind and {nl.kind, sys.kind} <= {"requirement", "constraint"}:
        return None
    if nl.kind != sys.kind:
        return (
            "naming_or_type_mismatch",
            "low",
            nl,
            sys,
            f"Spec kinds differ for {nl.name} and {sys.name}.",
            f"Natural language was extracted as `{nl.kind}`, while SysML was extracted as `{sys.kind}`.",
            "Review the extraction or rename/retype the SysML element if needed.",
            min(nl.confidence, sys.confidence),
            True,
        )
    if nl.kind == "constraint" and sys.kind == "constraint":
        if nl.property and sys.property and nl.property.lower() != sys.property.lower():
            return (
                "semantic_conflict",
                "high",
                nl,
                sys,
                f"Constraint property differs: {nl.property} vs {sys.property}.",
                f"NL constrains `{nl.property}`, but SysML constrains `{sys.property}`.",
                "Check which property should carry this constraint.",
                min(nl.confidence, sys.confidence),
                False,
            )
        if nl.operator and sys.operator and nl.operator != sys.operator:
            return (
                "semantic_conflict",
                "high",
                nl,
                sys,
                f"Constraint operator differs for {nl.property or nl.name}.",
                f"NL uses `{nl.operator}`, but SysML uses `{sys.operator}`.",
                "Update the SysML constraint or clarify the source requirement.",
                min(nl.confidence, sys.confidence),
                False,
            )
        if _num(nl.value) is not None and _num(sys.value) is not None and _num(nl.value) != _num(sys.value):
            return (
                "semantic_conflict",
                "high",
                nl,
                sys,
                f"Constraint value differs for {nl.property or nl.name}.",
                f"Natural language requires `{nl.predicate}`, but SysML specifies `{sys.predicate}`.",
                f"Check whether the SysML value should be updated to `{nl.value:g}`.",
                min(nl.confidence, sys.confidence),
                False,
            )
        if nl.unit and sys.unit and nl.unit != sys.unit:
            return (
                "semantic_conflict",
                "medium",
                nl,
                sys,
                f"Constraint unit differs for {nl.property or nl.name}.",
                f"NL uses `{nl.unit}`, but SysML uses `{sys.unit}`.",
                "Confirm the intended unit and normalize the model if needed.",
                min(nl.confidence, sys.confidence),
                False,
            )
    return None


def _mm(items, class_, severity, nl, sys, summary, details, action, confidence, review=False) -> Mismatch:
    return Mismatch(
        id=f"mm_{len(items) + 1:03d}",
        class_=class_,
        severity=severity,
        nl_spec_id=nl.id if nl else None,
        sysml_spec_id=sys.id if sys else None,
        summary=summary,
        details=details,
        evidence={
            "nl_span": nl.source.span if nl and nl.source else "",
            "sysml_span": sys.source.span if sys and sys.source else "",
        },
        confidence=round(confidence, 3),
        suggested_action=action,
        needs_human_review=review,
    )


def _num(value):
    return value if isinstance(value, (int, float)) else None


def _missing_severity(spec: SpecItem) -> str:
    return "high" if spec.kind in {"constraint", "requirement", "behavior"} else "medium"


def _extra_severity(spec: SpecItem) -> str:
    return "medium" if spec.kind in {"constraint", "requirement", "connection"} else "low"
