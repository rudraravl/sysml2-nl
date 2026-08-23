"""Validate the shared robotics IR and FMU-to-OpenUSD contract."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .hybrid_contract import HybridContractValidator, load_json


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ir", type=Path, required=True)
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--fmu", type=Path, required=True)
    parser.add_argument("--usd", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    result = HybridContractValidator().validate(
        load_json(args.contract),
        load_json(args.ir),
        fmu_path=args.fmu,
        usd_path=args.usd,
        output_dir=args.output_dir,
    )
    report = result.to_dict()
    (args.output_dir / "contract-validation.json").write_text(
        json.dumps(report, indent=2, allow_nan=False), encoding="utf-8"
    )
    print(json.dumps(report, indent=2, allow_nan=False))
    raise SystemExit(0 if result.success else 1)


if __name__ == "__main__":
    main()
