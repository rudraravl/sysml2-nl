from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest

from nl2robotics.contracts.capabilities import assess_profiles, requested_features
from nl2robotics.contracts.requirement_ir import validate_requirement_ir
from nl2robotics.orchestrator.pipeline import RoboticsOrchestrator
from nl2robotics.orchestrator.planner import PlanningError, build_h2_plan, build_plan
from nl2robotics.orchestrator.profiled_planner import CapabilityPlan


ORACLES = Path(__file__).resolve().parents[1] / "hybrid" / "oracles"


def broad_ir() -> dict:
    source = (
        "Build a floating mobile robot with a mesh chassis and capsule mast, a "
        "spherical mast joint, PID trajectory control, body wrench actuation, an "
        "IMU reporting angular velocity, and contact with a frictional ground."
    )
    evidence = [source]
    return {
        "schema_version": "1.0",
        "task_id": "RPROF001",
        "source_text": source,
        "execution_mode": "capability_tiered",
        "domains": [
            {"id": "mobile_domain", "kind": "mobile_robotics", "evidence": evidence},
            {"id": "sensor_domain", "kind": "sensing", "evidence": evidence},
            {"id": "contact_domain", "kind": "contact", "evidence": evidence},
        ],
        "entities": [
            {"id": "chassis", "kind": "mobile_base", "shape": "mesh",
             "evidence": evidence},
            {"id": "mast", "kind": "rigid_link", "shape": "capsule",
             "evidence": evidence},
        ],
        "joints": [
            {"id": "mast_ball", "type": "spherical", "parent": "chassis",
             "child": "mast", "axis": "multi_axis", "evidence": evidence},
        ],
        "parameters": [],
        "dynamics": [
            {"id": "robot_dynamics", "owner": "usd_physics",
             "states": ["imu.angular_velocity"], "evidence": evidence},
        ],
        "controllers": [
            {"id": "trajectory_controller", "owner": "fmu_controller",
             "kind": "PID", "entity_ids": ["chassis"], "evidence": evidence},
        ],
        "actuators": [
            {"id": "chassis_wrench", "owner": "fmu_controller",
             "entity_id": "chassis", "command": "body_wrench", "evidence": evidence},
        ],
        "sensors": [
            {"id": "body_imu", "owner": "usd_physics", "kind": "imu",
             "entity_id": "chassis", "evidence": evidence},
        ],
        "environment": [
            {"id": "ground_contact", "kind": "ground", "evidence": evidence},
            {"id": "ground_friction", "kind": "friction", "evidence": evidence},
        ],
        "interfaces": [
            {"id": "imu_angular_velocity", "sensor_id": "body_imu",
             "state_id": "imu.angular_velocity", "quantity": "imu_angular_velocity",
             "direction": "usd_to_fmu", "source_unit": "rad/s",
             "target_unit": "rad/s", "required": True, "evidence": evidence},
            {"id": "commanded_wrench", "entity_id": "chassis",
             "state_id": "chassis.wrench", "quantity": "body_wrench",
             "direction": "fmu_to_usd", "source_unit": "N",
             "target_unit": "N", "required": True, "evidence": evidence},
        ],
        "properties": [
            {"id": "bounded_angular_rate", "kind": "always",
             "interface_id": "imu_angular_velocity", "upper": 5.0,
             "evidence": evidence},
        ],
        "assumptions": [],
        "unknowns": ["mesh URI, dimensions, masses, gains, and timing are unspecified"],
    }


class CapabilityPlanningTests(unittest.TestCase):
    def test_broad_mobile_sensor_contact_request_is_representable(self):
        ir = broad_ir()
        validation = validate_requirement_ir(ir)
        self.assertTrue(validation.success, validation.to_dict())
        features = set(requested_features(ir))
        self.assertTrue({
            "domain:mobile", "domain:sensing", "domain:contact_environment",
            "topology:floating_base", "joint:spherical", "controller:PID",
        } <= features)

        plan = build_plan(ir)
        self.assertIsInstance(plan, CapabilityPlan)
        self.assertEqual(2, len(plan.contract["mappings"]))
        self.assertIn("floating base", plan.openusd_requirement)
        self.assertIn("controller state", plan.modelica_requirement)
        self.assertIn("retrieved examples only as syntax", plan.modelica_requirement)
        self.assertIn("robotics:placeholder", plan.openusd_requirement)
        self.assertEqual(
            "requires_cross_artifact_validation",
            plan.contract["grounding"]["artifact_grounding_status"],
        )
        profiles = {row.profile_id: row for row in assess_profiles(ir)}
        self.assertTrue(profiles["mobile_floating_base"].applicable)
        self.assertFalse(profiles["articulated_joint_space_h2"].applicable)

    def test_arbitrary_axis_vector_is_valid_but_zero_vector_is_not(self):
        ir = broad_ir()
        ir["joints"][0] = {
            "id": "mast_hinge", "type": "revolute", "parent": "chassis",
            "child": "mast", "axis_vector": [1.0, 1.0, 0.0],
            "evidence": [ir["source_text"]],
        }
        self.assertTrue(validate_requirement_ir(ir).success)
        ir["joints"][0]["axis_vector"] = [0.0, 0.0, 0.0]
        self.assertIn(
            "invalid_joint_axis",
            {row.code for row in validate_requirement_ir(ir).issues},
        )

    def test_broad_mode_preserves_future_grounded_feature_names(self):
        ir = broad_ir()
        ir["joints"][0]["type"] = "magnetic_levitation_constraint"
        ir["entities"][1]["shape"] = "neural_sdf"
        ir["interfaces"][0]["quantity"] = "event_camera_packets"
        ir["properties"][0]["kind"] = "probabilistic_reachability"
        self.assertTrue(validate_requirement_ir(ir).success)

        strict = deepcopy(ir)
        strict["execution_mode"] = "newton_closed_loop"
        codes = {row.code for row in validate_requirement_ir(strict).issues}
        self.assertIn("invalid_field_value", codes)

    def test_state_property_requires_an_observable_interface(self):
        ir = broad_ir()
        ir["dynamics"][0]["states"].append("chassis.pitch")
        ir["properties"][0].pop("interface_id")
        ir["properties"][0]["state_id"] = "chassis.pitch"
        validation = validate_requirement_ir(ir)
        self.assertIn(
            "unobservable_property_state",
            {row.code for row in validation.issues},
        )

        ir["interfaces"].append({
            "id": "chassis_pitch", "entity_id": "chassis",
            "state_id": "chassis.pitch", "quantity": "pitch",
            "direction": "usd_to_fmu", "source_unit": "rad",
            "evidence": [ir["source_text"]],
        })
        self.assertTrue(validate_requirement_ir(ir).success)

    def test_strict_h2_profile_remains_strict(self):
        ir = json.loads(
            (ORACLES / "RHY101" / "requirement_ir.json").read_text(encoding="utf-8")
        )
        ir["joints"][0]["type"] = "spherical"
        ir["joints"][0]["axis"] = "multi_axis"
        with self.assertRaises(PlanningError) as caught:
            build_h2_plan(ir)
        self.assertIn(
            "unsupported_h2_joint", {row.code for row in caught.exception.issues}
        )

    def test_verified_articulated_oracle_routes_to_strict_h2(self):
        ir = json.loads(
            (ORACLES / "RHY203" / "requirement_ir.json").read_text(encoding="utf-8")
        )
        profile = {
            row.profile_id: row for row in assess_profiles(ir)
        }["articulated_joint_space_h2"]
        self.assertTrue(profile.applicable, profile.to_dict())
        self.assertEqual(5, profile.maximum_supported_tier)


class CapabilityOrchestratorTests(unittest.TestCase):
    def test_artifact_profile_finishes_at_explicit_tier_two(self):
        ir = broad_ir()

        def generated_modelica(requirement: str, output_dir: Path):
            self.assertIn("CAPABILITY-TIERED MODELICA", requirement)
            return "model RobotTask_RPROF001 end RobotTask_RPROF001;", {
                "passed": True, "repairs": 0, "generation_mode": "test",
            }

        def generated_usd(requirement: str, output_dir: Path):
            self.assertIn("CAPABILITY-TIERED OPENUSD", requirement)
            return "#usda 1.0\n", {
                "passed": True, "repairs": 0, "generation_mode": "test",
            }

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = RoboticsOrchestrator(
                modelica_generator=generated_modelica,
                openusd_generator=generated_usd,
            ).run(
                ir["source_text"], lambda _: json.dumps(ir),
                output_dir=root, task_id=ir["task_id"],
                execution_mode="capability_tiered", max_ir_repairs=0,
            )
            report = json.loads(
                (root / "capability-report.json").read_text(encoding="utf-8")
            )

        self.assertTrue(result["passed"], result)
        self.assertEqual("artifacts_validated", result["execution_status"])
        self.assertTrue(result["alignment"]["enabled"])
        self.assertTrue(result["alignment"]["passed"])
        self.assertEqual(2, report["verification"]["highest_reached_tier"])
        self.assertFalse(report["claim_eligible_deltaai_h2"])
        self.assertEqual(
            "requires_cross_artifact_validation",
            report["grounding"]["artifact_grounding_status"],
        )

    def test_artifact_profiles_are_both_evaluated_on_partial_failure(self):
        ir = broad_ir()
        calls = {"modelica": 0, "openusd": 0}

        def generated_modelica(requirement: str, output_dir: Path):
            calls["modelica"] += 1
            return "model Broken end Broken;", {
                "passed": False, "repairs": 0, "generation_mode": "test",
            }

        def generated_usd(requirement: str, output_dir: Path):
            calls["openusd"] += 1
            return "#usda 1.0\n", {
                "passed": True, "repairs": 0, "generation_mode": "test",
            }

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = RoboticsOrchestrator(
                modelica_generator=generated_modelica,
                openusd_generator=generated_usd,
            ).run(
                ir["source_text"], lambda _: json.dumps(ir),
                output_dir=root, task_id=ir["task_id"],
                execution_mode="capability_tiered", max_ir_repairs=0,
            )
            report = json.loads(
                (root / "capability-report.json").read_text(encoding="utf-8")
            )

        self.assertEqual({"modelica": 1, "openusd": 1}, calls)
        self.assertFalse(result["passed"])
        self.assertEqual("modelica_validation", result["failure_stage"])
        self.assertEqual(1, report["verification"]["highest_reached_tier"])


if __name__ == "__main__":
    unittest.main()
