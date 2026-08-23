"""Prepare a validated H2 execution bundle outside Isaac Sim."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .isaac_bundle import IsaacBundleError, prepare_isaac_bundle


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--modelica", type=Path, required=True)
    parser.add_argument("--usd", type=Path, required=True)
    parser.add_argument("--ir", type=Path, required=True)
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument(
        "--modelica-backend", choices=("auto", "local", "docker"),
        default="docker",
    )
    args = parser.parse_args()
    try:
        report = prepare_isaac_bundle(
            modelica_path=args.modelica,
            usd_path=args.usd,
            requirement_ir_path=args.ir,
            contract_path=args.contract,
            output_dir=args.output_dir,
            modelica_backend=args.modelica_backend,
        )
    except (IsaacBundleError, OSError, ValueError) as exc:
        report = {
            "stage": "isaac_bundle_preparation",
            "success": False,
            "claim_eligible_h2": False,
            "error": f"{type(exc).__name__}: {exc}",
        }
    print(json.dumps(report, indent=2, allow_nan=False))
    raise SystemExit(0 if report.get("success") is True else 1)


if __name__ == "__main__":
    main()
