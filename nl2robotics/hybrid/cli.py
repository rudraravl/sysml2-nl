"""Run the portable FMU-owned OpenUSD robotics profile."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from nl2robotics.contracts.hybrid_contract import load_json
from nl2robotics.modelica.openmodelica import OpenModelicaRunner

from .portable import PortableHybridPipeline


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--modelica", type=Path, required=True)
    parser.add_argument("--usd", type=Path, required=True)
    parser.add_argument("--ir", type=Path, required=True)
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument(
        "--modelica-backend", choices=("auto", "local", "docker"), default="auto"
    )
    args = parser.parse_args()
    pipeline = PortableHybridPipeline(modelica_runner=OpenModelicaRunner(
        backend=args.modelica_backend
    ))
    report = pipeline.run(
        args.modelica.read_text(encoding="utf-8"),
        args.usd,
        load_json(args.ir),
        load_json(args.contract),
        output_dir=args.output_dir,
    )
    (args.output_dir / "bundle.json").write_text(
        json.dumps(report, indent=2, allow_nan=False), encoding="utf-8"
    )
    print(json.dumps(report, indent=2, allow_nan=False))
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
