"""Validate and run the closed-loop core against deterministic reference physics."""

from __future__ import annotations

import argparse
from dataclasses import asdict
import json
from pathlib import Path

from nl2robotics.contracts.hybrid_contract import HybridContractValidator, load_json
from nl2robotics.modelica.fmi_controller import FMIContainerControllerRuntime
from nl2robotics.modelica.openmodelica import OpenModelicaRunner

from .closed_loop import ClosedLoopMaster
from .closed_loop_properties import evaluate_closed_loop_properties
from .reference_runtime import ReferenceOneDOFPhysics


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--modelica", type=Path, required=True)
    parser.add_argument("--usd", type=Path, required=True)
    parser.add_argument("--ir", type=Path, required=True)
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--inertia", type=float, required=True)
    parser.add_argument("--damping", type=float, default=0.0)
    parser.add_argument("--modelica-backend", choices=("auto", "local", "docker"),
                        default="docker")
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    contract = load_json(args.contract)
    requirement_ir = load_json(args.ir)
    modelica = args.modelica.read_text(encoding="utf-8")
    export = OpenModelicaRunner(backend=args.modelica_backend).export_fmu(
        modelica, output_dir=args.output_dir / "fmu"
    )
    report = {
        "stage": "closed_loop_reference_smoke",
        "success": False,
        "claim_eligible_h2": False,
        "fmu": export.to_dict(),
    }
    if not export.success or export.fmu_path is None:
        _finish(args.output_dir, report)

    validation = HybridContractValidator().validate(
        contract,
        requirement_ir,
        fmu_path=export.fmu_path,
        usd_path=args.usd,
        output_dir=args.output_dir / "contract",
    )
    report["contract"] = validation.to_dict()
    if not validation.success:
        _finish(args.output_dir, report)

    commands = [row for row in validation.resolved_mappings
                if row["direction"] == "fmu_to_usd"]
    joint_paths = {row["usd_joint_path"] for row in validation.resolved_mappings}
    joint_types = {row["joint_type"] for row in validation.resolved_mappings}
    if len(joint_paths) != 1 or len(joint_types) != 1 or len(commands) != 1:
        report["error"] = "reference smoke requires exactly one joint and one command"
        _finish(args.output_dir, report)

    controller = FMIContainerControllerRuntime(export.fmu_path)
    physics = ReferenceOneDOFPhysics(
        joint_path=next(iter(joint_paths)),
        joint_type=next(iter(joint_types)),
        inertia=args.inertia,
        damping=args.damping,
    )
    execution = ClosedLoopMaster().run(
        controller,
        physics,
        mappings=validation.resolved_mappings,
        clock=contract["clock"],
        coupling=contract["coupling"],
        output_dir=args.output_dir / "execution",
    )
    report["execution"] = execution
    properties = []
    if execution.get("success") is True:
        properties = evaluate_closed_loop_properties(
            Path(execution["trace"]),
            validation.resolved_mappings,
            requirement_ir.get("properties", []),
        )
    report["properties"] = [asdict(item) for item in properties]
    report["success"] = execution.get("success") is True and all(
        item.passed for item in properties
    )
    _finish(args.output_dir, report)


def _finish(output_dir: Path, report: dict) -> None:
    (output_dir / "bundle.json").write_text(
        json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(report, indent=2, allow_nan=False))
    raise SystemExit(0 if report["success"] else 1)


if __name__ == "__main__":
    main()
