from __future__ import annotations

import re
from difflib import SequenceMatcher
from typing import Any

from .schemas import SpecItem

UNIT_MAP = {
    "volt": "V",
    "volts": "V",
    "v": "V",
    "mv": "mV",
    "amp": "A",
    "amps": "A",
    "ampere": "A",
    "amperes": "A",
    "a": "A",
    "watt": "W",
    "watts": "W",
    "w": "W",
    "second": "s",
    "seconds": "s",
    "sec": "s",
    "s": "s",
    "meter": "m",
    "meters": "m",
    "metre": "m",
    "metres": "m",
    "m": "m",
    "newton": "N",
    "newtons": "N",
    "n": "N",
}

OP_MAP = {
    "at least": ">=",
    "no less than": ">=",
    "minimum": ">=",
    "min": ">=",
    "greater than or equal to": ">=",
    "not less than": ">=",
    "at most": "<=",
    "no more than": "<=",
    "maximum": "<=",
    "max": "<=",
    "less than or equal to": "<=",
    "not greater than": "<=",
    "greater than": ">",
    "more than": ">",
    "less than": "<",
    "equal to": "==",
    "equals": "==",
    "must be": "==",
    "shall be": "==",
}


def norm_name(value: Any) -> str:
    if value is None:
        return ""
    text = str(value).strip()
    text = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", text)
    text = re.sub(r"[^A-Za-z0-9]+", " ", text).lower()
    return " ".join(text.split())


def compact_name(value: Any) -> str:
    return norm_name(value).replace(" ", "")


def norm_unit(unit: str | None) -> str | None:
    if not unit:
        return None
    cleaned = unit.strip().strip("[]()").lower()
    return UNIT_MAP.get(cleaned, unit.strip().strip("[]()"))


def norm_operator(op: str | None) -> str | None:
    if not op:
        return None
    cleaned = op.strip().lower()
    return OP_MAP.get(cleaned, op.strip())


def tokens(value: Any) -> set[str]:
    return set(norm_name(value).split())


def token_similarity(a: Any, b: Any) -> float:
    ta = tokens(a)
    tb = tokens(b)
    if not ta or not tb:
        return 0.0
    jaccard = len(ta & tb) / len(ta | tb)
    ratio = SequenceMatcher(None, compact_name(a), compact_name(b)).ratio()
    return max(jaccard, ratio)


def normalize_spec(spec: SpecItem) -> SpecItem:
    spec.operator = norm_operator(spec.operator)
    spec.unit = norm_unit(spec.unit)
    if isinstance(spec.value, str):
        try:
            spec.value = float(spec.value)
        except ValueError:
            pass
    spec.metadata.setdefault("normalized", {})
    spec.metadata["normalized"].update(
        {
            "name": norm_name(spec.name),
            "subject": norm_name(spec.subject),
            "property": norm_name(spec.property),
            "unit": spec.unit,
            "operator": spec.operator,
        }
    )
    return spec
