#!/usr/bin/env python3
"""Aggregate completed shard checkpoints without modifying evidence."""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path

from .run_study import DEFAULT_DATASET, _write_json, load_seed, summarize


def aggregate(output_dir: Path, dataset: Path) -> dict:
    expected = load_seed(dataset)
    records = []
    duplicates = []
    seen = set()
    for path in sorted((output_dir / "tasks").glob("*/run.json")):
        row = json.loads(path.read_text(encoding="utf-8"))
        task_id = row.get("task_id")
        if task_id in seen:
            duplicates.append(task_id)
        seen.add(task_id)
        records.append(row)
    expected_ids = {row["id"] for row in expected}
    unknown = sorted(seen - expected_ids)
    missing = sorted(expected_ids - seen)
    report = summarize(records)
    report.update({
        "schema_version": "1.0",
        "stage": "sysml_stagewise_aggregate",
        "expected_prompt_count": len(expected_ids),
        "observed_prompt_count": len(seen),
        "complete": not missing and not duplicates and not unknown,
        "missing_prompt_count": len(missing),
        "missing_prompt_ids": missing,
        "duplicate_prompt_ids": sorted(set(duplicates)),
        "unknown_prompt_ids": unknown,
    })
    by_domain = defaultdict(list)
    for row in records:
        by_domain[str(row.get("domain") or "unknown")].append(row)
    report["per_domain"] = {
        domain: summarize(rows) for domain, rows in sorted(by_domain.items())
    }
    report["condition_counts"] = dict(sorted(Counter(
        row.get("condition", {}).get("id", "unknown") for row in records
    ).items()))
    _write_json(output_dir / "summary.json", report)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--dataset", type=Path, default=DEFAULT_DATASET)
    args = parser.parse_args()
    report = aggregate(args.output_dir, args.dataset)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
