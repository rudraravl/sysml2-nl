"""Independently verify authored OpenUSD samples against the FMU trace."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

from pxr import Usd


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage", type=Path, required=True)
    parser.add_argument("--trace", type=Path, required=True)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--tolerance", type=float, default=1e-9)
    args = parser.parse_args()
    report = {"success": False, "mappings": []}
    try:
        config = json.loads(args.config.read_text(encoding="utf-8"))
        rows = _read_trace(args.trace)
        stage = Usd.Stage.Open(str(args.stage))
        if stage is None:
            raise ValueError("OpenUSD could not open the animated stage")
        clock = config["clock"]
        rate = float(clock["time_codes_per_second"])
        if abs(stage.GetTimeCodesPerSecond() - rate) > args.tolerance:
            raise ValueError("animated stage time-code rate differs from the contract")
        if stage.GetInterpolationType() != Usd.InterpolationTypeLinear:
            raise ValueError("animated stage interpolation is not linear")

        all_passed = True
        for mapping in config["mappings"]:
            attr_name = (
                "xformOp:translate:joint"
                if mapping["joint_type"] == "prismatic"
                else f"xformOp:rotate{mapping['axis']}"
            )
            prim = stage.GetPrimAtPath(mapping["usd_driven_prim"])
            attr = prim.GetAttribute(attr_name) if prim else None
            if not attr:
                raise ValueError(f"animated attribute does not exist: {attr_name}")
            time_samples = attr.GetTimeSamples()
            expected_times = [float(row["time"]) * rate for row in rows]
            count_match = len(time_samples) == len(expected_times)
            max_time_error = _max_error(time_samples, expected_times)
            expected_values = [
                float(row[mapping["fmu_variable"]]) * float(mapping["scale"])
                + float(mapping["offset"])
                for row in rows
            ]
            actual_values = [
                _mapped_value(attr.Get(Usd.TimeCode(time)), mapping)
                for time in expected_times
            ]
            max_value_error = _max_error(actual_values, expected_values)
            value_tolerance = float(mapping.get("numeric_tolerance", args.tolerance))
            passed = (
                count_match
                and max_time_error is not None
                and max_value_error is not None
                and max_time_error <= args.tolerance
                and max_value_error <= value_tolerance
            )
            all_passed = all_passed and passed
            report["mappings"].append({
                "id": mapping["id"],
                "attribute": attr_name,
                "passed": passed,
                "expected_samples": len(expected_times),
                "authored_samples": len(time_samples),
                "max_time_code_error": max_time_error,
                "max_value_error": max_value_error,
                "time_code_tolerance": args.tolerance,
                "value_tolerance": value_tolerance,
            })
        report.update({
            "success": all_passed,
            "sample_count": len(rows),
            "tolerance": args.tolerance,
        })
    except Exception as exc:
        report["error"] = f"{type(exc).__name__}: {exc}"
    args.report.write_text(json.dumps(report, indent=2, allow_nan=False), encoding="utf-8")
    return 0 if report["success"] else 1


def _read_trace(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows or "time" not in rows[0]:
        raise ValueError("FMU trace must contain at least one row and a time column")
    return rows


def _max_error(actual: list[float], expected: list[float]) -> float | None:
    if len(actual) != len(expected):
        return None
    return max((abs(left - right) for left, right in zip(actual, expected)), default=0.0)


def _mapped_value(value, mapping: dict) -> float:
    if mapping["joint_type"] != "prismatic":
        return float(value)
    return float(value[{"X": 0, "Y": 1, "Z": 2}[mapping["axis"]]])


if __name__ == "__main__":
    raise SystemExit(main())
