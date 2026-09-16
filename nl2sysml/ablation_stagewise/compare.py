#!/usr/bin/env python3
"""Paired A1--A4 comparisons over common eligible SysML prompts."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from .run_study import _write_json


CONDITIONS = ("A1", "A2", "A3", "A4")


def _records(path: Path) -> dict[str, dict]:
    rows = {}
    for record_path in sorted((path / "tasks").glob("*/run.json")):
        row = json.loads(record_path.read_text(encoding="utf-8"))
        if row.get("eligible") is True:
            rows[str(row["task_id"])] = row
    return rows


def _outcome(row: dict, field: str) -> bool:
    result = row.get("result", {})
    if field == "compiler_pass":
        return result.get("compiler", {}).get("passed") is True
    if field == "kernel_pass":
        return result.get("execution", {}).get("success") is True
    if field == "end_to_end_pass":
        return result.get("passed") is True
    raise ValueError(field)


def _mcnemar_exact(b: int, c: int) -> float:
    discordant = b + c
    if discordant == 0:
        return 1.0
    tail = sum(math.comb(discordant, k) for k in range(0, min(b, c) + 1))
    return min(1.0, 2.0 * tail / (2 ** discordant))


def paired_comparison(left: dict[str, dict], right: dict[str, dict],
                      field: str) -> dict:
    common = sorted(set(left) & set(right))
    left_only = right_only = both = neither = 0
    for task_id in common:
        a = _outcome(left[task_id], field)
        b = _outcome(right[task_id], field)
        if a and b:
            both += 1
        elif a:
            left_only += 1
        elif b:
            right_only += 1
        else:
            neither += 1
    n = len(common)
    return {
        "common_eligible_count": n,
        "left_pass_count": both + left_only,
        "right_pass_count": both + right_only,
        "left_rate": (both + left_only) / n if n else None,
        "right_rate": (both + right_only) / n if n else None,
        "delta_percentage_points": (
            100.0 * (right_only - left_only) / n if n else None
        ),
        "both_pass": both,
        "left_only_pass": left_only,
        "right_only_pass": right_only,
        "neither_pass": neither,
        "mcnemar_exact_two_sided_p": _mcnemar_exact(left_only, right_only),
    }


def compare(output_root: Path) -> dict:
    rows = {condition: _records(output_root / condition) for condition in CONDITIONS}
    comparisons = {}
    for left, right in zip(CONDITIONS, CONDITIONS[1:]):
        comparisons[f"{right}_minus_{left}"] = {
            field: paired_comparison(rows[left], rows[right], field)
            for field in ("compiler_pass", "kernel_pass", "end_to_end_pass")
        }
    all_common = set.intersection(*(set(rows[item]) for item in CONDITIONS))
    report = {
        "schema_version": "1.0",
        "stage": "sysml_stagewise_paired_comparison",
        "condition_eligible_counts": {
            key: len(value) for key, value in rows.items()
        },
        "all_condition_common_eligible_count": len(all_common),
        "comparisons": comparisons,
        "interpretation": (
            "Each adjacent contrast changes one generation/feedback component. "
            "McNemar tests use only prompts eligible in both conditions."
        ),
    }
    _write_json(output_root / "paired-comparison.json", report)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-root", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(compare(args.output_root), indent=2))


if __name__ == "__main__":
    main()
