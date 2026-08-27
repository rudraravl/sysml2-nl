"""Frozen lexical retrieval checks for both robotics generation profiles."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from nl2robotics.modelica.corpus import ExampleCorpus
from nl2robotics.openusd.corpus import OpenUSDExampleCorpus


MODELICA_QUERIES = (
    ("joint_mechanics", "compliant revolute joint with inertia stiffness and damping"),
    ("joint_mechanics", "prismatic robot axis with a soft mechanical stop"),
    ("electric_actuation", "DC motor winding current voltage torque and back EMF"),
    ("electric_actuation", "battery powered geared electric servo with current limit"),
    ("feedback_control", "PID robot position controller with anti windup"),
    ("feedback_control", "cascade joint position and velocity feedback control"),
    ("coupled_transmissions", "two stage gear train driving a robot joint"),
    ("coupled_transmissions", "differential dual motor transmission and synchronized outputs"),
    ("hybrid_safety", "emergency stop disables a robot actuator"),
    ("hybrid_safety", "thermal shutdown and timed actuator fault mode"),
    ("mobile_aerial", "differential drive mobile robot pose kinematics"),
    ("mobile_aerial", "aerial vehicle roll controller and angular motion"),
    ("sensing_estimation", "biased encoder and filtered position measurement"),
    ("sensing_estimation", "IMU gyro drift and complementary sensor fusion"),
    ("fluid_power", "hydraulic cylinder pressure flow and piston dynamics"),
    ("fluid_power", "servo valve controlling hydraulic flow rate"),
    ("trajectory_generation", "minimum jerk waypoint trajectory for a robot axis"),
    ("trajectory_generation", "trapezoidal velocity limited position profile"),
    ("multibody_kinematics", "two link planar arm forward kinematics and Jacobian"),
    ("multibody_kinematics", "SCARA revolute prismatic end effector geometry"),
)

OPENUSD_QUERIES = (
    ("joint_drives", "revolute shoulder joint angular drive target and limits"),
    ("joint_drives", "vertical prismatic lift with linear drive"),
    ("geometry_transforms", "capsule link translation orientation and scale"),
    ("geometry_transforms", "rotated cylindrical wheel collision geometry"),
    ("rigid_body_collision", "dynamic sphere rigid body above static ground collider"),
    ("rigid_body_collision", "box payload rigid body collision API and platform"),
    ("mass_inertia", "explicit center of mass diagonal inertia principal axes"),
    ("mass_inertia", "flywheel mass tensor and cylindrical collider"),
    ("joint_topology", "fixed joint connects tool to mount"),
    ("joint_topology", "spherical gimbal joint with swing limits"),
    ("articulations", "two link arm articulation shoulder elbow joints"),
    ("articulations", "mobile chassis articulation with two axle wheels"),
    ("materials_contact", "high friction gripper physics material"),
    ("materials_contact", "bouncy bumper restitution contact material"),
    ("environments", "robot test environment with ground and box obstacles"),
    ("environments", "inclined ramp and dynamic probe body"),
    ("sensor_placement", "forward camera marker mounted on robot body"),
    ("sensor_placement", "IMU sensor at aerial robot center"),
    ("stage_metadata", "Z up SI stage at 120 time codes per second"),
    ("stage_metadata", "lunar gravity robotics stage metadata"),
)


def _evaluate_corpus(corpus, queries: tuple[tuple[str, str], ...]) -> dict:
    rows = []
    for expected, query in queries:
        hits = corpus.retrieve(query, k=5)
        categories = [item.category for item, _ in hits]
        semantic_ids = [item.semantic_case_id for item, _ in hits]
        rows.append({
            "query": query,
            "expected_category": expected,
            "top1_category": categories[0],
            "top1_correct": categories[0] == expected,
            "recall_at_5": expected in categories,
            "semantic_case_ids": semantic_ids,
            "semantic_diversity": len(semantic_ids) == len(set(semantic_ids)),
        })
    return {
        "queries": len(rows),
        "top1_accuracy": sum(row["top1_correct"] for row in rows) / len(rows),
        "recall_at_5": sum(row["recall_at_5"] for row in rows) / len(rows),
        "diverse_at_5": sum(row["semantic_diversity"] for row in rows) / len(rows),
        "rows": rows,
    }


def _metrics(result: dict) -> dict:
    return {
        key: result[key]
        for key in ("queries", "top1_accuracy", "recall_at_5", "diverse_at_5")
    }


def evaluate() -> dict:
    profiles = {
        "modelica": (ExampleCorpus, "full1500", MODELICA_QUERIES),
        "openusd": (OpenUSDExampleCorpus, "full1500", OPENUSD_QUERIES),
    }
    report = {"stage": "robotics_retrieval_evaluation", "schema_version": "1.0"}
    all_rows = []
    for profile, (corpus_type, subset, queries) in profiles.items():
        report[profile] = _evaluate_corpus(corpus_type(subset=subset), queries)
        all_rows.extend(report[profile]["rows"])
    report["subset_ablation"] = {
        "modelica": {
            subset: _metrics(_evaluate_corpus(
                ExampleCorpus(subset=subset), MODELICA_QUERIES
            ))
            for subset in (
                "core24", "balanced50", "full100", "full300",
                "semantic500", "full1500",
            )
        },
        "openusd": {
            subset: _metrics(_evaluate_corpus(
                OpenUSDExampleCorpus(subset=subset), OPENUSD_QUERIES
            ))
            for subset in (
                "core20", "semantic100", "full300", "semantic500", "full1500",
            )
        },
    }
    report["success"] = all(
        row["recall_at_5"] and row["semantic_diversity"] for row in all_rows
    )
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = evaluate()
    text = json.dumps(report, indent=2, allow_nan=False)
    print(text)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text + "\n", encoding="utf-8")
    raise SystemExit(0 if report["success"] else 1)


if __name__ == "__main__":
    main()
