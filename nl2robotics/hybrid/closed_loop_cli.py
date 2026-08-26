"""Validate and run the closed-loop core against deterministic reference physics."""

from __future__ import annotations

import argparse
from dataclasses import asdict
import json
from pathlib import Path

from nl2robotics.contracts.hybrid_contract import HybridContractValidator, load_json
from nl2robotics.contracts.articulated_profile import axial_length
from nl2robotics.contracts.units import conversion
from nl2robotics.modelica.fmi_controller import FMIContainerControllerRuntime
from nl2robotics.modelica.openmodelica import OpenModelicaRunner

from .closed_loop import ClosedLoopMaster
from .closed_loop_properties import evaluate_closed_loop_properties
from .reference_runtime import ReferenceArticulatedPhysics


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--modelica", type=Path, required=True)
    parser.add_argument("--usd", type=Path, required=True)
    parser.add_argument("--ir", type=Path, required=True)
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument(
        "--inertia", type=float,
        help="legacy/global effective inertia override for every joint",
    )
    parser.add_argument("--damping", type=float, default=0.0)
    parser.add_argument(
        "--joint-dynamics", action="append", default=[], metavar="JOINT=INERTIA,DAMPING",
        help="override one semantic joint ID or USD path; repeat per joint",
    )
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

    try:
        overrides = _parse_joint_dynamics(args.joint_dynamics)
        joint_configs = _reference_joint_configs(
            requirement_ir,
            validation.resolved_mappings,
            inertia=args.inertia,
            damping=args.damping,
            overrides=overrides,
        )
    except ValueError as exc:
        report["error"] = str(exc)
        _finish(args.output_dir, report)

    controller = FMIContainerControllerRuntime(export.fmu_path)
    physics = ReferenceArticulatedPhysics(joint_configs)
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


def _parse_joint_dynamics(values: list[str]) -> dict[str, tuple[float, float]]:
    parsed = {}
    for value in values:
        try:
            name, numbers = value.rsplit("=", 1)
            inertia_text, damping_text = numbers.split(",", 1)
            inertia = float(inertia_text)
            damping = float(damping_text)
        except (TypeError, ValueError) as exc:
            raise ValueError(
                f"invalid --joint-dynamics {value!r}; expected JOINT=INERTIA,DAMPING"
            ) from exc
        if not name or inertia <= 0 or damping < 0:
            raise ValueError(
                f"invalid --joint-dynamics {value!r}; inertia must be positive "
                "and damping non-negative"
            )
        if name in parsed:
            raise ValueError(f"duplicate --joint-dynamics override for {name!r}")
        parsed[name] = (inertia, damping)
    return parsed


def _reference_joint_configs(requirement_ir: dict, mappings: list[dict], *,
                             inertia: float | None, damping: float,
                             overrides: dict[str, tuple[float, float]]) -> list[dict]:
    if inertia is not None and inertia <= 0:
        raise ValueError("--inertia must be positive")
    if damping < 0:
        raise ValueError("--damping must be non-negative")
    joints = {row["id"]: row for row in requirement_ir.get("joints", [])}
    entities = {row["id"]: row for row in requirement_ir.get("entities", [])}
    by_joint: dict[str, list[dict]] = {}
    for mapping in mappings:
        by_joint.setdefault(str(mapping["semantic_joint_id"]), []).append(mapping)
    configs = []
    used_overrides = set()
    for joint_id in sorted(by_joint):
        rows = by_joint[joint_id]
        paths = {str(row["usd_joint_path"]) for row in rows}
        types = {
            str(row.get("joint_type", joints.get(joint_id, {}).get("type", "")))
            for row in rows
        }
        if len(paths) != 1 or len(types) != 1 or joint_id not in joints:
            raise ValueError(f"ambiguous reference dynamics for joint {joint_id!r}")
        path = next(iter(paths))
        joint_type = next(iter(types))
        override_key = joint_id if joint_id in overrides else (
            path if path in overrides else None
        )
        if override_key is not None:
            effective_inertia, effective_damping = overrides[override_key]
            used_overrides.add(override_key)
        else:
            effective_inertia = inertia or _derived_effective_inertia(
                joints[joint_id], entities
            )
            effective_damping = damping
        initial_position = _initial_value(rows, "joint_position")
        initial_velocity = _initial_value(rows, "joint_velocity")
        configs.append({
            "joint_path": path,
            "joint_type": joint_type,
            "inertia": effective_inertia,
            "damping": effective_damping,
            "initial_position": initial_position,
            "initial_velocity": initial_velocity,
        })
    unused = sorted(overrides.keys() - used_overrides)
    if unused:
        raise ValueError(f"unknown --joint-dynamics joints: {unused}")
    if not configs:
        raise ValueError("reference smoke requires at least one mapped joint")
    return configs


def _derived_effective_inertia(joint: dict, entities: dict[str, dict]) -> float:
    child = entities[joint["child"]]
    mass = conversion(str(child["mass_unit"]), "kg").apply(float(child["mass"]))
    if joint["type"] == "prismatic":
        return mass
    length = conversion(str(child["dimension_unit"]), "m").apply(
        axial_length(child)
    )
    return max(mass * length * length / 3.0, 1e-6)


def _initial_value(rows: list[dict], quantity: str) -> float:
    matches = [row for row in rows if row["direction"] == "usd_to_fmu"
               and row["usd_quantity"] == quantity]
    if len(matches) != 1:
        raise ValueError(f"reference joint requires exactly one {quantity} mapping")
    return float(matches[0].get("initial_value", 0.0))


def _finish(output_dir: Path, report: dict) -> None:
    (output_dir / "bundle.json").write_text(
        json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(report, indent=2, allow_nan=False))
    raise SystemExit(0 if report["success"] else 1)


if __name__ == "__main__":
    main()
