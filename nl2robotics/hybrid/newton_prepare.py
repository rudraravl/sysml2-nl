"""Prepare a validated Newton H2 execution bundle on the target platform."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .newton_bundle import NewtonBundleError, prepare_newton_bundle


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--modelica", type=Path, required=True)
    parser.add_argument("--usd", type=Path, required=True)
    parser.add_argument("--ir", type=Path, required=True)
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument(
        "--modelica-backend", choices=("auto", "local", "docker"),
        default="local",
    )
    args = parser.parse_args()
    try:
        report = prepare_newton_bundle(
            modelica_path=args.modelica,
            usd_path=args.usd,
            requirement_ir_path=args.ir,
            contract_path=args.contract,
            output_dir=args.output_dir,
            modelica_backend=args.modelica_backend,
        )
    except (NewtonBundleError, OSError, ValueError) as exc:
        report = {
            "stage": "newton_closed_loop_bundle_preparation",
            "success": False,
            "claim_eligible_h2": False,
            "error": f"{type(exc).__name__}: {exc}",
        }
    print(json.dumps(report, indent=2, allow_nan=False))
    raise SystemExit(0 if report.get("success") is True else 1)


if __name__ == "__main__":
    main()
