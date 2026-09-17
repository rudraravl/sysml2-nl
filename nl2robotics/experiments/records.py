"""Stable experiment run records with artifact provenance."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


def run_fingerprint(*, task_id: str, condition: dict, variant: str,
                    repetition: int, prompt: str, configuration: dict) -> str:
    payload = {
        "task_id": task_id,
        "condition": condition,
        "variant": variant,
        "repetition": repetition,
        "prompt_sha256": hashlib.sha256(prompt.encode("utf-8")).hexdigest(),
        "configuration": configuration,
    }
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def load_records(root: Path) -> list[dict]:
    records = []
    for path in sorted(root.glob("**/run.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(data, dict) and data.get("schema_version") in {"1.0", "1.1"}:
            records.append(data)
    return records


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
