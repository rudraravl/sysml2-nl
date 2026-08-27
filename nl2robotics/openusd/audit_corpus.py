"""Audit OpenUSD corpus scale, balance, lineage, and model uniqueness."""

from __future__ import annotations

from collections import Counter
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).with_name("examples")


def audit() -> dict:
    rows = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    subsets = json.loads((ROOT / "corpus_subsets.json").read_text(encoding="utf-8"))
    errors = []
    ids = [row.get("id") for row in rows]
    if len(rows) != 1500 or len(set(ids)) != 1500:
        errors.append("manifest must contain 1,500 unique retrieval-pair IDs")
    categories = Counter(row.get("category") for row in rows)
    if len(categories) != 10 or set(categories.values()) != {150}:
        errors.append(f"expected ten balanced categories, got {dict(categories)}")
    semantic = Counter(row.get("semantic_case_id") for row in rows)
    if len(semantic) != 500 or set(semantic.values()) != {3}:
        errors.append("expected 500 semantic cases with three NL formulations each")
    requirements = [str(row.get("requirement", "")).strip().lower() for row in rows]
    if len(set(requirements)) != len(requirements):
        errors.append("duplicate natural-language requirements")
    semantic_hashes = {}
    for row in rows:
        for key in (
            "id", "split", "tier", "category", "difficulty", "requirement",
            "tags", "model", "provenance", "semantic_case_id", "lineage_id",
            "variant_type",
        ):
            if not row.get(key):
                errors.append(f"{row.get('id')} missing {key}")
        path = ROOT / str(row.get("model", ""))
        if not path.is_file():
            errors.append(f"missing model file for {row.get('id')}")
            continue
        semantic_id = row.get("semantic_case_id")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        prior = semantic_hashes.setdefault(semantic_id, digest)
        if prior != digest:
            errors.append(f"semantic case {semantic_id} references inconsistent models")
    if len(set(semantic_hashes.values())) != 500:
        errors.append("the 500 OpenUSD semantic cases must have unique stage content")
    expected_subsets = {
        "core20": 20, "semantic100": 100, "full300": 300,
        "semantic500": 500, "full1500": 1500,
    }
    for name, size in expected_subsets.items():
        values = subsets.get(name, [])
        if len(values) != size or len(set(values)) != size or not set(values) <= set(ids):
            errors.append(f"invalid {name} subset")
    return {
        "ok": not errors,
        "retrieval_pairs": len(rows),
        "semantic_cases": len(semantic),
        "structural_lineages": len({row.get("lineage_id") for row in rows}),
        "categories": dict(sorted(categories.items())),
        "subsets": {key: len(value) for key, value in subsets.items()},
        "errors": errors,
    }


if __name__ == "__main__":
    report = audit()
    print(json.dumps(report, indent=2))
    raise SystemExit(0 if report["ok"] else 1)
