#!/usr/bin/env python3
"""Evaluate SysML 2 Executable rules over dataset .sysml files.

Default input is the canonical `dataset/data`, but any directory can be passed with
`--input`. The script writes one row per `.sysml` file and one status/score
pair per executable rule.
"""

from __future__ import annotations

import argparse
import csv
import os
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from sysml_executable_rules import EXECUTABLE_RULE_IDS, evaluate_executable_rules


CSV_FIELDS = [
    "file",
    "sample_id",
    "file_status",
    "overall_score",
    "pass_count",
    "fail_count",
    "not_applicable_count",
    "unsupported_count",
]

for rule_id in EXECUTABLE_RULE_IDS:
    CSV_FIELDS.extend(
        [
            f"{rule_id}_status",
            f"{rule_id}_score",
            f"{rule_id}_checked_elements",
            f"{rule_id}_failing_elements",
            f"{rule_id}_rationale",
        ]
    )


def _is_probably_dataless(path: Path) -> bool:
    try:
        st = path.stat()
    except OSError:
        return False
    # macOS cloud placeholder files commonly report size > 0 but zero blocks.
    return st.st_size > 0 and getattr(st, "st_blocks", 1) == 0


def _sample_id(path: Path) -> str:
    return path.stem


def _discover_sysml_files(root: Path) -> list[Path]:
    if root.is_file():
        return [root]
    return sorted(root.rglob("*.sysml"))


def _empty_row(path: Path, status: str) -> dict[str, str]:
    row = {
        "file": str(path),
        "sample_id": _sample_id(path),
        "file_status": status,
        "overall_score": "",
        "pass_count": "0",
        "fail_count": "0",
        "not_applicable_count": "0",
        "unsupported_count": str(len(EXECUTABLE_RULE_IDS)),
    }
    for rule_id in EXECUTABLE_RULE_IDS:
        row[f"{rule_id}_status"] = "unsupported"
        row[f"{rule_id}_score"] = "0.5"
        row[f"{rule_id}_checked_elements"] = "0"
        row[f"{rule_id}_failing_elements"] = ""
        row[f"{rule_id}_rationale"] = f"File could not be evaluated: {status}."
    return row


def evaluate_file(path: Path, *, include_dataless: bool) -> dict[str, str]:
    if _is_probably_dataless(path) and not include_dataless:
        return _empty_row(path, "dataless")

    try:
        code = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        try:
            code = path.read_text(encoding="utf-8", errors="replace")
        except OSError as exc:
            return _empty_row(path, f"read_error:{exc}")
    except OSError as exc:
        return _empty_row(path, f"read_error:{exc}")

    results = evaluate_executable_rules(code)
    counts = {
        "pass": sum(1 for r in results if r.status == "pass"),
        "fail": sum(1 for r in results if r.status == "fail"),
        "not_applicable": sum(1 for r in results if r.status == "not_applicable"),
        "unsupported": sum(1 for r in results if r.status == "unsupported"),
    }
    overall_score = sum(r.score for r in results) / len(results) if results else 0.0
    row: dict[str, str] = {
        "file": str(path),
        "sample_id": _sample_id(path),
        "file_status": "ok",
        "overall_score": f"{overall_score:.3f}",
        "pass_count": str(counts["pass"]),
        "fail_count": str(counts["fail"]),
        "not_applicable_count": str(counts["not_applicable"]),
        "unsupported_count": str(counts["unsupported"]),
    }
    for result in results:
        row[f"{result.rule_id}_status"] = result.status
        row[f"{result.rule_id}_score"] = f"{result.score:.3f}"
        row[f"{result.rule_id}_checked_elements"] = str(result.checked_elements)
        row[f"{result.rule_id}_failing_elements"] = "; ".join(result.failing_elements)
        row[f"{result.rule_id}_rationale"] = result.rationale
    return row


def write_csv(rows: list[dict[str, str]], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=CSV_FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate executable SysML rules over .sysml files.")
    parser.add_argument("--input", type=Path, default=Path("dataset/data"))
    parser.add_argument("--output", type=Path, default=Path("tmp/executable_rule_scores.csv"))
    parser.add_argument("--limit", type=int, default=0, help="Optional max number of files for smoke tests.")
    parser.add_argument(
        "--include-dataless",
        action="store_true",
        help="Force reading macOS dataless/cloud placeholder files. May block while files download.",
    )
    args = parser.parse_args()

    files = _discover_sysml_files(args.input)
    if args.limit > 0:
        files = files[: args.limit]
    rows = [evaluate_file(path, include_dataless=args.include_dataless) for path in files]
    write_csv(rows, args.output)
    ok = sum(1 for row in rows if row["file_status"] == "ok")
    dataless = sum(1 for row in rows if row["file_status"] == "dataless")
    print(f"Wrote {args.output}")
    print(f"Files: {len(rows)} evaluated, {ok} ok, {dataless} dataless/skipped")


if __name__ == "__main__":
    main()
