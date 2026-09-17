"""Machine-check the breadth represented by the articulated study suite."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from nl2robotics.benchmark.suite import BenchmarkSuite
from nl2robotics.contracts.articulated_profile import (
    SUPPORTED_JOINT_AXES,
    SUPPORTED_JOINT_TYPES,
    SUPPORTED_LINK_SHAPES,
    entity_shape,
)
from nl2robotics.orchestrator.planner import PlanningError, build_h2_plan


DEFAULT_MANIFEST = Path(__file__).resolve().parent / "articulated_manifest.json"
REQUIRED_TOPOLOGIES = frozenset({"single", "serial", "branching"})


def audit_articulated_suite(manifest_path: Path = DEFAULT_MANIFEST) -> dict:
    """Audit artifacts plus concrete joint, shape, topology, and channel breadth."""
    suite = BenchmarkSuite(manifest_path=manifest_path)
    base = suite.audit()
    issues = list(base["issues"])
    axes: set[str] = set()
    joint_types: set[str] = set()
    shapes: set[str] = set()
    topologies: set[str] = set()
    joint_counts: set[int] = set()
    max_controlled_joints = 0
    task_coverage = []

    for index, task in enumerate(suite.tasks):
        path = f"$[{index}]"
        if task.profile != "hybrid" or task.target_level != "newton_h2":
            issues.append(_issue(
                "invalid_study_target", path,
                "articulated study tasks must target hybrid newton_h2",
            ))
            continue
        bundle = (suite.root / task.oracle["bundle"]).resolve()
        try:
            ir = json.loads((bundle / "requirement_ir.json").read_text())
            oracle_contract = json.loads((bundle / "contract.json").read_text())
            plan = build_h2_plan(ir)
        except (OSError, ValueError, KeyError, PlanningError) as exc:
            issues.append(_issue("invalid_articulated_oracle", path, str(exc)))
            continue

        joints = list(ir["joints"])
        current_axes = {str(row["axis"]) for row in joints}
        current_types = {str(row["type"]) for row in joints}
        current_shapes = {
            entity_shape(row) for row in ir["entities"]
            if row.get("kind") == "rigid_link"
        }
        topology = _topology(joints)
        controlled = {
            joint_id
            for controller in ir["controllers"]
            for joint_id in controller.get(
                "joint_ids", [controller.get("joint_id")]
            )
            if joint_id
        }
        if not controlled and len(ir["controllers"]) == 1:
            controlled = {
                str(actuator["joint_id"])
                for actuator in ir.get("actuators", [])
                if actuator.get("owner") == "fmu_controller"
            }
        joint_ids = {str(row["id"]) for row in joints}
        if controlled != joint_ids:
            issues.append(_issue(
                "incomplete_controller_coverage", path,
                f"controlled={sorted(controlled)} joints={sorted(joint_ids)}",
            ))
        _audit_mapping_channels(
            oracle_contract.get("mappings", []), joint_ids, path, issues
        )
        if len(plan.contract["mappings"]) != 3 * len(joints):
            issues.append(_issue(
                "planner_channel_count", path,
                f"expected {3 * len(joints)} mappings",
            ))

        axes.update(current_axes)
        joint_types.update(current_types)
        shapes.update(current_shapes)
        topologies.add(topology)
        joint_counts.add(len(joints))
        max_controlled_joints = max(max_controlled_joints, len(controlled))
        task_coverage.append({
            "task_id": task.id,
            "oracle_task_id": ir["task_id"],
            "joint_count": len(joints),
            "controlled_joint_count": len(controlled),
            "joint_types": sorted(current_types),
            "axes": sorted(current_axes),
            "link_shapes": sorted(current_shapes),
            "topology": topology,
            "mapping_count": len(oracle_contract.get("mappings", [])),
            "property_count": len(ir.get("properties", [])),
        })

    requirements = {
        "joint_types": (joint_types, set(SUPPORTED_JOINT_TYPES)),
        "axes": (axes, set(SUPPORTED_JOINT_AXES)),
        "link_shapes": (shapes, set(SUPPORTED_LINK_SHAPES)),
        "topologies": (topologies, set(REQUIRED_TOPOLOGIES)),
        "joint_counts": (joint_counts, {1, 2, 3}),
    }
    for name, (actual, required) in requirements.items():
        missing = required - actual
        if missing:
            issues.append(_issue(
                "missing_breadth_coverage", "$.coverage",
                f"{name} missing {sorted(missing)}",
            ))
    if max_controlled_joints < 3:
        issues.append(_issue(
            "missing_breadth_coverage", "$.coverage",
            "no task controls at least three joints simultaneously",
        ))

    return {
        "stage": "articulated_study_static_audit",
        "schema_version": "1.0",
        "success": not issues,
        "manifest": base["manifest"],
        "manifest_sha256": base["manifest_sha256"],
        "task_count": len(task_coverage),
        "coverage": {
            "joint_count_range": [min(joint_counts), max(joint_counts)]
            if joint_counts else [],
            "joint_counts": sorted(joint_counts),
            "joint_types": sorted(joint_types),
            "axes": sorted(axes),
            "link_shapes": sorted(shapes),
            "topologies": sorted(topologies),
            "max_simultaneously_controlled_joints": max_controlled_joints,
        },
        "tasks": task_coverage,
        "issues": issues,
    }


def _topology(joints: list[dict]) -> str:
    if len(joints) == 1:
        return "single"
    child_counts: dict[str, int] = {}
    for joint in joints:
        parent = str(joint["parent"])
        child_counts[parent] = child_counts.get(parent, 0) + 1
    return "branching" if max(child_counts.values()) > 1 else "serial"


def _audit_mapping_channels(mappings: list[dict], joint_ids: set[str],
                            path: str, issues: list[dict]) -> None:
    expected = {
        (joint_id, direction, quantity)
        for joint_id in joint_ids
        for direction, quantity in (
            ("usd_to_fmu", "joint_position"),
            ("usd_to_fmu", "joint_velocity"),
            ("fmu_to_usd", "joint_effort"),
        )
    }
    actual = {
        (str(row.get("semantic_joint_id")), str(row.get("direction")),
         str(row.get("usd_quantity")))
        for row in mappings
    }
    if actual != expected or len(mappings) != len(expected):
        issues.append(_issue(
            "invalid_joint_channels", path,
            f"missing={sorted(expected - actual)} extra={sorted(actual - expected)}",
        ))


def _issue(code: str, path: str, message: str) -> dict:
    return {"code": code, "path": path, "message": message}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    args = parser.parse_args()
    result = audit_articulated_suite(args.manifest)
    print(json.dumps(result, indent=2, allow_nan=False))
    raise SystemExit(0 if result["success"] else 1)


if __name__ == "__main__":
    main()
