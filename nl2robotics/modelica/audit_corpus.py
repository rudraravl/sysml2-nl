"""Audit corpus balance, provenance, duplication, and evaluation isolation."""

from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re


ROOT = Path(__file__).with_name("examples")
TOKEN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*|[-+]?\d+(?:\.\d+)?")


def normalized_code(code: str) -> str:
    code = re.sub(r"(?m)^\s*model\s+\w+", "model MODEL", code)
    code = re.sub(r"(?m)^\s*end\s+\w+;", "end MODEL;", code)
    return " ".join(TOKEN.findall(code.lower()))


def jaccard(left: str, right: str) -> float:
    a, b = set(TOKEN.findall(left.lower())), set(TOKEN.findall(right.lower()))
    return len(a & b) / len(a | b) if a or b else 1.0


def audit() -> dict:
    rows = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    subsets = json.loads((ROOT / "corpus_subsets.json").read_text(encoding="utf-8"))
    evaluation = json.loads((ROOT / "evaluation_tasks.json").read_text(encoding="utf-8"))
    errors = []
    ids = [row["id"] for row in rows]
    if len(rows) != 100 or len(set(ids)) != 100:
        errors.append("manifest must contain 100 unique IDs")
    categories = Counter(row["category"] for row in rows)
    if len(categories) != 10 or set(categories.values()) != {10}:
        errors.append(f"expected ten balanced categories, got {dict(categories)}")
    tiers = Counter(row["tier"] for row in rows)
    if tiers != {"core": 24, "expanded": 76}:
        errors.append(f"unexpected tier counts: {dict(tiers)}")
    requirements = [row["requirement"].strip().lower() for row in rows]
    if len(set(requirements)) != len(requirements):
        errors.append("duplicate natural-language requirements")
    code_hashes: dict[str, list[str]] = {}
    codes = {}
    property_ids = []
    for row in rows:
        path = ROOT / row["model_file"]
        if not path.is_file():
            errors.append(f"missing model file for {row['id']}")
            continue
        code = normalized_code(path.read_text(encoding="utf-8"))
        codes[row["id"]] = code
        digest = hashlib.sha256(code.encode()).hexdigest()
        code_hashes.setdefault(digest, []).append(row["id"])
        for key in ("split", "tier", "category", "archetype", "difficulty",
                    "source", "license", "simulation", "properties"):
            if not row.get(key):
                errors.append(f"{row['id']} missing {key}")
        property_ids.extend(item.get("id") for item in row.get("properties", []))
    duplicates = [group for group in code_hashes.values() if len(group) > 1]
    if duplicates:
        errors.append(f"duplicate normalized code: {duplicates}")
    if len(property_ids) != len(set(property_ids)):
        errors.append("duplicate or missing property IDs")
    expected_subsets = {"core24": 24, "balanced50": 50, "full100": 100}
    for name, size in expected_subsets.items():
        values = subsets.get(name, [])
        if len(values) != size or len(set(values)) != size or not set(values) <= set(ids):
            errors.append(f"invalid {name} subset")
    eval_ids = {row["id"] for row in evaluation}
    if eval_ids & set(ids):
        errors.append("evaluation IDs overlap the RAG corpus")
    eval_categories = Counter(row["category"] for row in evaluation)
    if set(eval_categories) != set(categories) or set(eval_categories.values()) != {1}:
        errors.append("evaluation tasks must cover every corpus category exactly once")
    overlap = []
    sorted_ids = sorted(codes)
    for index, left in enumerate(sorted_ids):
        for right in sorted_ids[index + 1:]:
            score = jaccard(codes[left], codes[right])
            if score >= 0.90:
                overlap.append({"left": left, "right": right, "jaccard": round(score, 4)})
    return {
        "ok": not errors,
        "examples": len(rows),
        "categories": dict(sorted(categories.items())),
        "tiers": dict(tiers),
        "subsets": {name: len(values) for name, values in subsets.items()},
        "evaluation_tasks": len(evaluation),
        "exact_code_duplicates": duplicates,
        "high_overlap_pairs": sorted(overlap, key=lambda row: -row["jaccard"]),
        "errors": errors,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = audit()
    text = json.dumps(report, indent=2, allow_nan=False)
    print(text)
    if args.output:
        args.output.write_text(text + "\n", encoding="utf-8")
    raise SystemExit(0 if report["ok"] else 1)


if __name__ == "__main__":
    main()
