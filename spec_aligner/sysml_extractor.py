from __future__ import annotations

import re

from .ingest import TextDocument
from .normalizer import norm_unit
from .schemas import SourceEvidence, SpecDocument, SpecItem

DEF_RE = re.compile(r"\b(?P<kw>part|item|attribute|port|connection|requirement|constraint|action|state)\s+def\s+(?P<name>['\"]?[^:{;\"]+['\"]?)", re.I)
USE_RE = re.compile(r"^\s*(?P<kw>attribute|port|part|item|connection|constraint|perform|action)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\b(?P<rest>[^;{}]*)", re.I)
COMPARE_RE = re.compile(r"(?P<prop>[A-Za-z_][A-Za-z0-9_.]*)\s*(?P<op>>=|<=|==|=|>|<)\s*(?P<value>-?\d+(?:\.\d+)?)\s*(?:\[?(?P<unit>[A-Za-z/%]+)\]?)?")

KIND_MAP = {
    "part": "entity",
    "item": "entity",
    "attribute": "attribute",
    "port": "port",
    "connection": "connection",
    "requirement": "requirement",
    "constraint": "constraint",
    "action": "behavior",
    "state": "behavior",
}


def extract(text: str | TextDocument) -> SpecDocument:
    doc = text if isinstance(text, TextDocument) else TextDocument(str(text), str(text).splitlines())
    specs: list[SpecItem] = []
    counter = 1
    stack: list[str] = []

    for i, line in enumerate(doc.lines, 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("//"):
            continue

        if stripped.lower().count(" def ") > 1 and "{" not in stripped:
            for m in DEF_RE.finditer(stripped):
                kw = m.group("kw").lower()
                name = _clean_name(m.group("name"))
                span = _statement_span(stripped, m.start())
                specs.append(_item(counter, KIND_MAP[kw], name, name, span, i, i, kw))
                counter += 1
            continue

        m = DEF_RE.search(stripped)
        if m:
            kw = m.group("kw").lower()
            name = _clean_name(m.group("name"))
            end = _block_end(doc.lines, i)
            span = doc.span(i, end)
            specs.append(_item(counter, KIND_MAP[kw], name, name, span, i, end, kw))
            counter += 1
            if "{" in line:
                stack.append(name)
            constraints = _constraint_specs(span, i, counter, subject=name)
            specs.extend(constraints)
            counter += len(constraints)
            continue

        m = USE_RE.search(stripped)
        if m:
            kw = m.group("kw").lower()
            if kw == "perform":
                kw = "action"
            name = m.group("name")
            kind = KIND_MAP.get(kw, "relation")
            subject = stack[-1] if stack else name
            rest = m.group("rest")
            type_name = _type_name(rest)
            spec = _item(counter, kind, name, subject, stripped, i, i, kw)
            if kind == "attribute":
                spec.property = name
                spec.value = _default_value(rest)
                spec.metadata["type"] = type_name
                spec.related_entities = [subject] if subject else []
            elif type_name:
                spec.related_entities = [subject, type_name] if subject else [type_name]
            specs.append(spec)
            counter += 1

        for c in _constraint_specs(stripped, i, counter, subject=stack[-1] if stack else None):
            specs.append(c)
            counter += 1

        if "{" in line and not stripped.startswith(("}", "};")):
            name = _opening_name(stripped)
            if name:
                stack.append(name)
        if "}" in line and stack:
            for _ in range(line.count("}")):
                if stack:
                    stack.pop()

    return SpecDocument("sysml", _dedupe(specs))


def _item(counter: int, kind: str, name: str, subject: str | None, span: str, start: int, end: int, syntax: str) -> SpecItem:
    return SpecItem(
        id=f"sysml_{counter:03d}",
        kind=kind,  # type: ignore[arg-type]
        name=name,
        subject=subject,
        predicate=span.strip(),
        related_entities=[subject] if subject else [],
        source=SourceEvidence("sysml", span.strip(), start, end),
        confidence=0.92,
        metadata={"syntax": syntax},
    )


def _constraint_specs(span: str, line_no: int, counter: int, subject: str | None) -> list[SpecItem]:
    out = []
    for m in COMPARE_RE.finditer(span):
        prop = m.group("prop").split(".")[-1]
        value = float(m.group("value"))
        unit = norm_unit(m.group("unit"))
        op = "==" if m.group("op") == "=" else m.group("op")
        pred = f"{prop} {op} {value:g}{(' ' + unit) if unit else ''}"
        out.append(
            SpecItem(
                id=f"sysml_{counter + len(out):03d}",
                kind="constraint",
                name=f"{subject or 'model'}_{prop}_{op}_{value:g}".replace(" ", "_"),
                subject=subject,
                predicate=pred,
                property=prop,
                operator=op,
                value=value,
                unit=unit,
                related_entities=[subject] if subject else [],
                source=SourceEvidence("sysml", m.group(0), line_no, line_no),
                confidence=0.9,
            )
        )
    return out


def _block_end(lines: list[str], start: int) -> int:
    depth = 0
    seen = False
    for i in range(start, len(lines) + 1):
        line = lines[i - 1]
        depth += line.count("{")
        if "{" in line:
            seen = True
        depth -= line.count("}")
        if seen and depth <= 0:
            return i
        if not seen and ";" in line:
            return i
    return start


def _opening_name(line: str) -> str | None:
    m = DEF_RE.search(line) or USE_RE.search(line)
    return _clean_name(m.group("name")) if m else None


def _clean_name(name: str) -> str:
    return name.strip().strip("'\"").strip()


def _statement_span(line: str, start: int) -> str:
    end = line.find(";", start)
    if end == -1:
        end = len(line)
    return line[start : end + 1].strip()


def _type_name(rest: str) -> str | None:
    m = re.search(r":\s*([A-Za-z_][A-Za-z0-9_]*)", rest)
    return m.group(1) if m else None


def _default_value(rest: str) -> str | float | None:
    m = re.search(r"=\s*([^;]+)", rest)
    if not m:
        return None
    value = m.group(1).strip().strip('"')
    try:
        return float(value)
    except ValueError:
        return value


def _dedupe(specs: list[SpecItem]) -> list[SpecItem]:
    seen = set()
    out = []
    for spec in specs:
        key = (spec.kind, spec.name, spec.source.line_start if spec.source else None, spec.predicate)
        if key not in seen:
            seen.add(key)
            out.append(spec)
    for i, spec in enumerate(out, 1):
        spec.id = f"sysml_{i:03d}"
    return out
