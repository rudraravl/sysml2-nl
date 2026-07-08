from __future__ import annotations

from .normalizer import normalize_spec, token_similarity
from .schemas import AlignmentPair, AlignmentResult, SpecDocument, SpecItem


def align(nl_doc: SpecDocument, sysml_doc: SpecDocument) -> AlignmentResult:
    nl_specs = [normalize_spec(s) for s in nl_doc.specs]
    sysml_specs = [normalize_spec(s) for s in sysml_doc.specs]
    used: set[str] = set()
    result = AlignmentResult()

    for nl in sorted(nl_specs, key=_priority):
        best: tuple[float, SpecItem | None, str] = (0.0, None, "")
        for sys in sysml_specs:
            if sys.id in used:
                continue
            score, rationale = _score(nl, sys)
            if score > best[0]:
                best = (score, sys, rationale)
        score, sys, rationale = best
        if not sys or score < 0.35:
            result.nl_only.append(nl.id)
            continue
        if nl.confidence >= 0.6 and nl.kind in {"constraint", "requirement"} and sys.kind == "entity" and score < 0.62:
            result.nl_only.append(nl.id)
            continue
        pair = AlignmentPair(
            nl_spec_id=nl.id,
            sysml_spec_id=sys.id,
            score=round(score, 3),
            confidence=round(min(0.99, max(0.2, score)), 3),
            needs_human_review=score < 0.62,
            rationale=rationale,
        )
        used.add(sys.id)
        if pair.needs_human_review:
            result.uncertain_pairs.append(pair)
        else:
            result.matched_pairs.append(pair)

    result.sysml_only = [s.id for s in sysml_specs if s.id not in used]
    return result


def _score(nl: SpecItem, sys: SpecItem) -> tuple[float, str]:
    score = 0.0
    reasons: list[str] = []

    if nl.kind == sys.kind:
        score += 0.32
        reasons.append("same kind")
    elif {nl.kind, sys.kind} <= {"requirement", "constraint"}:
        score += 0.22
        reasons.append("requirement/constraint compatible")
    elif nl.kind == "entity" and sys.kind in {"entity", "attribute", "port"}:
        score += 0.12

    subject = max(token_similarity(nl.subject, sys.subject), token_similarity(nl.subject, sys.name))
    prop = token_similarity(nl.property, sys.property)
    name = token_similarity(nl.name, sys.name)
    related = _related_similarity(nl, sys)

    if subject:
        score += 0.28 * subject
        reasons.append(f"subject {subject:.2f}")
    if prop:
        score += 0.24 * prop
        reasons.append(f"property {prop:.2f}")
    if name:
        score += 0.18 * name
        reasons.append(f"name {name:.2f}")
    if related:
        score += 0.12 * related
        reasons.append(f"related {related:.2f}")

    if nl.operator and sys.operator and nl.operator == sys.operator:
        score += 0.05
    if nl.unit and sys.unit and nl.unit == sys.unit:
        score += 0.05
    return min(score, 1.0), ", ".join(reasons)


def _related_similarity(nl: SpecItem, sys: SpecItem) -> float:
    best = 0.0
    for a in nl.related_entities:
        for b in sys.related_entities:
            best = max(best, token_similarity(a, b))
    return best


def _priority(spec: SpecItem) -> int:
    order = {"constraint": 0, "requirement": 1, "connection": 2, "port": 3, "attribute": 4, "entity": 5}
    return order.get(spec.kind, 9)
