"""Summarize nvidia-smi samples captured around a DeltaAI Newton run."""

from __future__ import annotations

import argparse
import csv
import json
import os
from collections import defaultdict
from pathlib import Path


FIELDS = (
    "timestamp",
    "index",
    "uuid",
    "name",
    "memory_total_mib",
    "memory_used_mib",
    "utilization_gpu_percent",
)


def summarize_samples(path: Path) -> dict:
    """Return per-device VRAM and utilization peaks from nvidia-smi CSV."""
    samples: dict[str, list[dict]] = defaultdict(list)
    with path.open(encoding="utf-8", newline="") as handle:
        for line_number, row in enumerate(csv.reader(handle), start=1):
            if not row or all(not value.strip() for value in row):
                continue
            if len(row) != len(FIELDS):
                raise ValueError(
                    f"expected {len(FIELDS)} columns on line {line_number}, got {len(row)}"
                )
            values = dict(zip(FIELDS, (value.strip() for value in row)))
            try:
                values["index"] = int(values["index"])
                values["memory_total_mib"] = float(values["memory_total_mib"])
                values["memory_used_mib"] = float(values["memory_used_mib"])
                values["utilization_gpu_percent"] = float(
                    values["utilization_gpu_percent"]
                )
            except ValueError as exc:
                raise ValueError(f"non-numeric nvidia-smi value on line {line_number}") from exc
            samples[str(values["uuid"])].append(values)

    if not samples:
        raise ValueError("nvidia-smi produced no GPU samples")

    devices = []
    for uuid, rows in sorted(samples.items()):
        baseline = float(rows[0]["memory_used_mib"])
        peak = max(float(row["memory_used_mib"]) for row in rows)
        devices.append({
            "index": rows[0]["index"],
            "uuid": uuid,
            "name": rows[0]["name"],
            "memory_total_mib": rows[0]["memory_total_mib"],
            "baseline_memory_used_mib": baseline,
            "peak_memory_used_mib": peak,
            "incremental_peak_memory_mib": max(0.0, peak - baseline),
            "peak_utilization_gpu_percent": max(
                float(row["utilization_gpu_percent"]) for row in rows
            ),
            "sample_count": len(rows),
            "first_timestamp": rows[0]["timestamp"],
            "last_timestamp": rows[-1]["timestamp"],
        })

    return {
        "schema_version": "1.0",
        "stage": "deltaai_gpu_memory_profile",
        "source": "nvidia-smi",
        "sample_interval_ms": 200,
        "slurm_job_id": os.getenv("SLURM_JOB_ID"),
        "slurm_job_gpus": os.getenv("SLURM_JOB_GPUS"),
        "device_count": len(devices),
        "devices": devices,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = summarize_samples(args.samples)
    args.output.write_text(
        json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
