"""Create one synchronized trace across FMU and OpenUSD quantities."""

from __future__ import annotations

import csv
from pathlib import Path


def write_synchronized_trace(source: Path, mappings: list[dict],
                             destination: Path) -> dict:
    with source.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        source_fields = list(reader.fieldnames or [])
    if not rows or "time" not in source_fields:
        raise ValueError("FMU trace must contain at least one row and a time column")

    derived = []
    for mapping in mappings:
        variable = mapping["fmu_variable"]
        if variable not in source_fields:
            raise ValueError(f"FMU trace is missing mapped variable: {variable}")
        column = _column_name(mapping)
        if column in source_fields or column in derived:
            raise ValueError(f"duplicate synchronized trace column: {column}")
        derived.append(column)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=[*source_fields, *derived])
        writer.writeheader()
        for source_row in rows:
            row = dict(source_row)
            for mapping, column in zip(mappings, derived):
                row[column] = (
                    float(source_row[mapping["fmu_variable"]])
                    * float(mapping["scale"])
                    + float(mapping["offset"])
                )
            writer.writerow(row)
    return {
        "success": True,
        "source": str(source),
        "path": str(destination),
        "sample_count": len(rows),
        "columns": [*source_fields, *derived],
        "derived_columns": derived,
    }


def _column_name(mapping: dict) -> str:
    prim = str(mapping["usd_driven_prim"]).strip("/").replace("/", ".")
    return (
        f"usd:{prim}:{mapping['usd_quantity']}"
        f"[{mapping['target_unit']}]"
    )
