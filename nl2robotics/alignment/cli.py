"""Evaluate grounded robotics requirements against archived pipeline evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .evaluator import RoboticsAlignmentEvaluator


def _json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ir", type=Path, required=True)
    parser.add_argument("--modelica", type=Path, required=True)
    parser.add_argument("--openusd", type=Path, required=True)
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--hybrid-report", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = RoboticsAlignmentEvaluator().evaluate(
        _json(args.ir),
        modelica=args.modelica.read_text(encoding="utf-8"),
        openusd=args.openusd.read_text(encoding="utf-8"),
        contract=_json(args.contract),
        hybrid_report=_json(args.hybrid_report),
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(report, indent=2, allow_nan=False) + "\n", encoding="utf-8"
    )
    print(json.dumps(report["summary"], indent=2, allow_nan=False))
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
