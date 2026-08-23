"""Container entry point for one FMI Co-Simulation run."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

from fmpy import simulate_fmu


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fmu", type=Path, required=True)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--trace", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()

    report = {"success": False, "initialized": False}
    try:
        config = json.loads(args.config.read_text(encoding="utf-8"))
        outputs = config.get("outputs") or None
        result = simulate_fmu(
            str(args.fmu),
            start_time=float(config["start_time"]),
            stop_time=float(config["stop_time"]),
            output_interval=float(config["step_size"]),
            start_values=config.get("start_values") or {},
            output=outputs,
            fmi_type="CoSimulation",
        )
        report["initialized"] = True
        columns = list(result.dtype.names or [])
        with args.trace.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(columns)
            for row in result:
                writer.writerow([row[name].item() for name in columns])
        report.update({
            "success": True,
            "columns": columns,
            "sample_count": len(result),
        })
    except Exception as exc:
        report["error"] = f"{type(exc).__name__}: {exc}"
    args.report.write_text(json.dumps(report, indent=2), encoding="utf-8")
    return 0 if report["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
