"""Summarize archived robotics ablation run records."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .metrics import paired_binary_comparison, summarize_records
from .records import load_records, write_json


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runs", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--pair", nargs=2, metavar=("A", "B"))
    parser.add_argument("--metric", default="end_to_end")
    args = parser.parse_args()
    records = load_records(args.runs)
    report = summarize_records(records)
    if args.pair:
        report["paired_comparison"] = paired_binary_comparison(
            records, args.pair[0], args.pair[1], args.metric
        )
    if args.output:
        write_json(args.output, report)
    print(json.dumps(report, indent=2, allow_nan=False))


if __name__ == "__main__":
    main()
