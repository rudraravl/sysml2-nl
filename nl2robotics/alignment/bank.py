"""Load and validate the reviewable robotics question-family registry."""

from __future__ import annotations

import json
from pathlib import Path


_PATH = Path(__file__).with_name("bank.json")


def load_bank(path: Path = _PATH) -> dict:
    bank = json.loads(path.read_text(encoding="utf-8"))
    if bank.get("version") != "1.0.0":
        raise ValueError("unsupported robotics question bank version")
    families = bank.get("families")
    if not isinstance(families, dict) or not families:
        raise ValueError("question bank must define families")
    for name, definition in families.items():
        if not isinstance(definition, dict):
            raise ValueError(f"family {name!r} must be an object")
        weight = definition.get("weight")
        if not isinstance(weight, (int, float)) or weight <= 0:
            raise ValueError(f"family {name!r} has invalid weight")
        if not definition.get("authority") or not definition.get("repair_owner"):
            raise ValueError(f"family {name!r} lacks evidence policy")
    return bank


BANK = load_bank()


def family_weight(name: str) -> float:
    try:
        return float(BANK["families"][name]["weight"])
    except KeyError as exc:
        raise ValueError(f"unknown question family {name!r}") from exc
