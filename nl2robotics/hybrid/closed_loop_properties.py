"""Evaluate the supported temporal-property fragment over simulator state."""

from __future__ import annotations

from copy import deepcopy
import csv
from pathlib import Path

from nl2robotics.modelica.models import PropertyResult
from nl2robotics.modelica.properties import evaluate_properties


def evaluate_closed_loop_properties(trace_path: Path, mappings: list[dict],
                                    properties: list[dict]) -> list[PropertyResult]:
    feedback = {
        row["interface_id"]: row for row in mappings
        if row["direction"] == "usd_to_fmu"
    }
    with trace_path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    trace: dict[str, list[float]] = {
        "time": [float(row["time_end"]) for row in rows],
    }
    rewritten = []
    missing = []
    for prop in properties:
        mapping = feedback.get(prop.get("interface_id"))
        if mapping is None:
            missing.append(PropertyResult(
                property_id=str(prop.get("id", "unknown")),
                formula="unresolved closed-loop property",
                passed=False,
                robustness=None,
                detail="property does not reference a USD-to-FMU observation",
            ))
            continue
        signal = f"sim_post:{mapping['id']}[{mapping['source_unit']}]"
        trace[signal] = [float(row[signal]) for row in rows]
        candidate = deepcopy(prop)
        candidate["signal"] = signal
        rewritten.append(candidate)
    return [*evaluate_properties(trace, rewritten), *missing]
