"""Numerical repeatability checks for repeated simulator traces."""

from __future__ import annotations

import csv
import math
from pathlib import Path


def compare_traces(paths: list[Path], *, tolerance: float) -> dict:
    if len(paths) < 2:
        return {
            "success": False,
            "reason": "at least two traces are required",
            "trace_count": len(paths),
            "tolerance": tolerance,
        }
    traces = [_read(path) for path in paths]
    reference_fields, reference_rows = traces[0]
    if not reference_rows:
        return {
            "success": False,
            "reason": "reference trace is empty",
            "trace_count": len(paths),
            "tolerance": tolerance,
        }
    max_delta = 0.0
    worst = None
    for trace_index, (fields, rows) in enumerate(traces[1:], start=1):
        if fields != reference_fields:
            return {
                "success": False,
                "reason": f"trace {trace_index} has different columns",
                "trace_count": len(paths),
                "tolerance": tolerance,
            }
        if len(rows) != len(reference_rows):
            return {
                "success": False,
                "reason": f"trace {trace_index} has a different sample count",
                "trace_count": len(paths),
                "tolerance": tolerance,
            }
        for row_index, (expected, actual) in enumerate(zip(reference_rows, rows)):
            for field in reference_fields:
                delta = abs(float(expected[field]) - float(actual[field]))
                if not math.isfinite(delta):
                    return {
                        "success": False,
                        "reason": "trace contains a non-finite comparison",
                        "trace_count": len(paths),
                        "tolerance": tolerance,
                    }
                if delta > max_delta:
                    max_delta = delta
                    worst = {
                        "trace_index": trace_index,
                        "row_index": row_index,
                        "column": field,
                        "reference": float(expected[field]),
                        "actual": float(actual[field]),
                    }
    return {
        "success": max_delta <= tolerance,
        "trace_count": len(paths),
        "sample_count": len(reference_rows),
        "column_count": len(reference_fields),
        "tolerance": tolerance,
        "max_absolute_delta": max_delta,
        "worst_case": worst,
    }


def _read(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)
