"""Evaluate a small, explicit Signal Temporal Logic fragment over CSV traces."""

from __future__ import annotations

import csv
import math
from pathlib import Path

from .models import PropertyResult


def read_trace(path: Path) -> dict[str, list[float]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        trace = {name.strip('"'): [] for name in (reader.fieldnames or [])}
        for row in reader:
            for raw_name, raw_value in row.items():
                name = raw_name.strip('"')
                trace[name].append(float(raw_value))
    if "time" not in trace or not trace["time"]:
        raise ValueError("simulation trace has no time samples")
    return trace


def evaluate_properties(trace: dict[str, list[float]], specs: list[dict]) -> list[PropertyResult]:
    return [_evaluate(trace, spec) for spec in specs]


def _evaluate(trace: dict[str, list[float]], spec: dict) -> PropertyResult:
    prop_id = spec["id"]
    kind = spec["kind"]
    signal = spec["signal"]
    if signal not in trace:
        return PropertyResult(prop_id, _formula(spec), False, None,
                              f"signal {signal!r} is missing")
    values = [value for time, value in zip(trace["time"], trace[signal])
              if spec.get("start", -math.inf) <= time <= spec.get("end", math.inf)]
    if not values:
        return PropertyResult(prop_id, _formula(spec), False, None,
                              "property interval has no samples")
    margins = [_margin(value, spec) for value in values]
    if kind == "always":
        robustness = min(margins)
    elif kind == "eventually":
        robustness = max(margins)
    elif kind == "final":
        robustness = margins[-1]
    else:
        raise ValueError(f"unsupported property kind {kind!r}")
    return PropertyResult(
        prop_id,
        _formula(spec),
        robustness >= 0,
        robustness,
        f"{kind} robustness={robustness:.6g}",
    )


def _margin(value: float, spec: dict) -> float:
    margins = []
    if "lower" in spec:
        margins.append(value - float(spec["lower"]))
    if "upper" in spec:
        margins.append(float(spec["upper"]) - value)
    if not margins:
        raise ValueError("property requires lower and/or upper bound")
    return min(margins)


def _formula(spec: dict) -> str:
    bounds = []
    if "lower" in spec:
        bounds.append(f"{spec['lower']} <= {spec['signal']}")
    if "upper" in spec:
        bounds.append(f"{spec['signal']} <= {spec['upper']}")
    interval = f"[{spec.get('start', 0)}, {spec.get('end', 'T')}]"
    op = {"always": "G", "eventually": "F", "final": "final"}[spec["kind"]]
    return f"{op}{interval}({' and '.join(bounds)})"
