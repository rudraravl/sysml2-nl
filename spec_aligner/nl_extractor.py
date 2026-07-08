from __future__ import annotations

import re

from .ingest import TextDocument
from .normalizer import norm_operator, norm_unit
from .schemas import SourceEvidence, SpecDocument, SpecItem

REQ_WORDS = re.compile(r"\b(shall|must|required|requirement|should|needs? to|at least|at most|minimum|maximum)\b", re.I)
NUMERIC = re.compile(
    r"(?P<prop>[A-Za-z][A-Za-z0-9 _/-]{0,50}?)\s+"
    r"(?P<op>at least|no less than|not less than|minimum|min|greater than or equal to|"
    r"at most|no more than|not greater than|maximum|max|less than or equal to|"
    r"greater than|more than|less than|equal to|equals|=|>=|<=|>|<)\s*"
    r"(?P<value>-?\d+(?:\.\d+)?)\s*(?P<unit>\[[A-Za-z/%]+\]|[A-Za-z/%]+)?",
    re.I,
)


def extract(text: str | TextDocument) -> SpecDocument:
    doc = text if isinstance(text, TextDocument) else TextDocument(str(text), str(text).splitlines())
    specs: list[SpecItem] = []
    chunks = _chunks(doc.text)
    for idx, chunk in enumerate(chunks, 1):
        specs.extend(_extract_chunk(chunk, idx))
    return SpecDocument("natural_language", [s for s in specs if s.source and s.source.span.strip()])


def _chunks(text: str) -> list[str]:
    bits = re.split(r"(?<=[.!?])\s+|\n+", text.strip())
    return [b.strip(" -\t") for b in bits if b.strip(" -\t")]


def _extract_chunk(chunk: str, idx: int) -> list[SpecItem]:
    out: list[SpecItem] = []
    subject = _subject(chunk)
    evidence = SourceEvidence("natural_language", chunk)
    numeric = NUMERIC.search(chunk)

    if REQ_WORDS.search(chunk) and not numeric:
        conf = 0.9 if re.search(r"\b(shall|must|required)\b", chunk, re.I) else 0.62
        if re.search(r"\b(fast enough|appropriate|adequate|sufficient|as needed)\b", chunk, re.I):
            conf = 0.45
        out.append(
            SpecItem(
                id=f"nl_{idx:03d}",
                kind="requirement" if conf >= 0.6 else "constraint",
                name=_name_from_text(chunk),
                subject=subject,
                predicate=chunk,
                related_entities=[subject] if subject else [],
                source=evidence,
                confidence=conf,
                metadata={"ambiguous": conf < 0.6} if conf < 0.6 else {},
            )
        )

    if numeric:
        prop = _clean_prop(numeric.group("prop"))
        subject, prop = _split_subject_property(subject, prop)
        op = norm_operator(numeric.group("op"))
        value = float(numeric.group("value"))
        unit = norm_unit(numeric.group("unit"))
        out.append(
            SpecItem(
                id=f"nl_{idx:03d}_c",
                kind="constraint",
                name=f"{subject or 'system'}_{prop}_{op}_{value:g}".replace(" ", "_"),
                subject=subject,
                predicate=f"{prop} {op} {value:g}{(' ' + unit) if unit else ''}",
                property=prop,
                operator=op,
                value=value,
                unit=unit,
                related_entities=[subject] if subject else [],
                source=evidence,
                confidence=0.88,
            )
        )

    for ent in _entities(chunk):
        out.append(
            SpecItem(
                id=f"nl_{idx:03d}_e_{len(out)+1}",
                kind="entity",
                name=ent,
                subject=ent,
                predicate=f"entity {ent}",
                related_entities=[ent],
                source=evidence,
                confidence=0.7,
            )
        )
    return out or [
        SpecItem(
            id=f"nl_{idx:03d}",
            kind="requirement",
            name=_name_from_text(chunk),
            subject=subject,
            predicate=chunk,
            related_entities=[subject] if subject else [],
            source=evidence,
            confidence=0.5,
            metadata={"ambiguous": True},
        )
    ]


def _subject(text: str) -> str | None:
    m = re.search(r"\b(?:the|a|an)\s+([A-Za-z][A-Za-z0-9 _-]{1,40}?)(?:\s+shall|\s+must|\s+should|\s+is|\s+has|\s+with|\s+using|,|\.|$)", text, re.I)
    if m:
        return m.group(1).strip()
    ents = _entities(text)
    return ents[0] if ents else None


def _entities(text: str) -> list[str]:
    ents = re.findall(r"\b(?:using|with|contains?|includes?|comprises?)\s+(?:a|an|the)?\s*([A-Z][A-Za-z0-9_]*(?:\s+[A-Z][A-Za-z0-9_]*)?)", text)
    ents += re.findall(r"\b([A-Z][A-Za-z0-9_]*(?:\s+[A-Z][A-Za-z0-9_]*)?)\b", text)
    skip = {"The", "A", "An", "Create", "This", "System"}
    clean = []
    for ent in ents:
        ent = ent.strip()
        if ent and ent not in skip and ent not in clean:
            clean.append(ent)
    return clean[:4]


def _name_from_text(text: str) -> str:
    words = re.findall(r"[A-Za-z0-9]+", text.lower())[:8]
    return "_".join(words) or "requirement"


def _clean_prop(text: str) -> str:
    text = re.sub(r"\b(the|a|an|shall|must|should|be|is|are|requires?)\b", " ", text, flags=re.I)
    words = text.strip().split()
    return " ".join(words[-3:]) if words else "value"


def _split_subject_property(subject: str | None, prop: str) -> tuple[str | None, str]:
    words = prop.split()
    common_props = {
        "voltage",
        "current",
        "power",
        "mass",
        "weight",
        "force",
        "speed",
        "temperature",
        "pressure",
        "length",
        "height",
        "width",
        "duration",
        "time",
    }
    if len(words) >= 2 and words[-1].lower() in common_props:
        return " ".join(words[:-1]), words[-1]
    return subject, prop
