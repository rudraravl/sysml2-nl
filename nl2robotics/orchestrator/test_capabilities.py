from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest

from nl2robotics.contracts.capabilities import assess_profiles, requested_features
from nl2robotics.contracts.requirement_ir import validate_requirement_ir
from nl2robotics.orchestrator.pipeline import RoboticsOrchestrator
from nl2robotics.orchestrator.modelica_capability import (
    ModelicaCapabilityOrchestrator,
)
from nl2robotics.orchestrator.normalizer import (
    _modelica_capability_normalization_prompt,
)
from nl2robotics.orchestrator.planner import PlanningError, build_h2_plan, build_plan
from nl2robotics.orchestrator.profiled_planner import (
    CapabilityPlan,
    build_modelica_capability_plan,
)


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
    def modelica_ir(self) -> dict:
        ir = deepcopy(broad_ir())
        timing = " Run at 100 Hz for 2 s."
        ir["source_text"] += timing
        ir["execution_mode"] = "modelica_capability"
        ir["clock"] = {
            "duration": 2.0, "frequency_hz": 100.0,
            "evidence": [timing.strip()],
        }
        ir["dynamics"][0]["owner"] = "modelica_plant"
        ir["dynamics"][0]["states"].append("chassis.wrench")
        for interface in ir["interfaces"]:
            interface["direction"] = "modelica_output"
        return ir

    def test_modelica_only_plan_has_no_openusd_obligation(self):
        plan = build_modelica_capability_plan(self.modelica_ir())
        self.assertEqual("modelica_only", plan.contract["artifact_mode"])
        self.assertEqual("modelica_capability_execution",
                         plan.contract["contract_kind"])
        self.assertEqual(plan.model_name, plan.contract["model_name"])
        self.assertEqual("", plan.openusd_requirement)
        self.assertNotIn("OpenUSD artifact", plan.modelica_requirement)
        self.assertTrue(all(
            row["direction"] == "modelica_output"
            for row in plan.contract["mappings"]
        ))

    def test_modelica_normalization_prompt_excludes_dual_artifact_schema(self):
        prompt = _modelica_capability_normalization_prompt("robot", "T")
        self.assertIn('"execution_mode": "modelica_capability"', prompt)
        self.assertIn('"direction": "modelica_output"', prompt)
        self.assertNotIn("usd_to_fmu", prompt)
        self.assertNotIn("fmu_to_usd", prompt)
        self.assertNotIn("usd_physics", prompt)

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
        self.assertIn("plant/controller/estimator", plan.modelica_requirement)
        self.assertIn("Compilation alone is never success", plan.modelica_requirement)
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
    def test_modelica_only_orchestrator_reaches_behavior_without_openusd(self):
        ir = CapabilityPlanningTests().modelica_ir()
        plan = build_modelica_capability_plan(ir)

        def generated_modelica(requirement: str, output_dir: Path):
            self.assertIn("MODELICA-ONLY EXECUTABLE", requirement)
            self.assertIn("bounded controller states", requirement)
            self.assertIn("External monitors—not assert()", requirement)
            return f"model {plan.model_name} end {plan.model_name};", {
                "passed": True, "repairs": 0, "generation_mode": "test",
                "attempts": [{"passed": True}],
            }

        class Pipeline:
            runner = object()
            fmi_runner = object()

        class Execution:
            def run(self, modelica, requirement_ir, contract, *, output_dir):
                return {
                    "passed": True, "execution_mode": "integrated_fmu_behavior",
                    "execution_completed": True, "behavior_evaluated": True,
                    "behavior_passed": True, "clock": {
                        "start_time": 0.0, "stop_time": 2.0,
                        "frequency_hz": 100.0, "step_size": 0.01,
                    },
                    "fmu": {"success": True},
                    "contract": {
                        "success": True,
                        "resolved_mappings": contract["mappings"],
                        "resolved_parameter_mappings": contract["parameter_mappings"],
                    },
                    "execution": {"success": True, "initialized": True},
                    "trace_gate": {"success": True},
                    "properties": [{
                        "id": "bounded_angular_rate", "passed": True,
                        "status": "satisfied",
                    }],
                    "property_summary": {
                        "total": 1, "passed": 1, "violated": 0,
                        "unevaluable": 0,
                    },
                }

        with tempfile.TemporaryDirectory() as tmp:
            result = ModelicaCapabilityOrchestrator(
                modelica_pipeline=Pipeline(),
                modelica_generator=generated_modelica,
                execution_pipeline=Execution(),
            ).run(
                ir["source_text"], lambda _: json.dumps(ir),
                output_dir=Path(tmp), task_id=ir["task_id"],
                max_ir_repairs=0, enable_specification_alignment=False,
            )
        self.assertTrue(result["passed"], result)
        self.assertEqual("modelica_only", result["artifact_mode"])
        self.assertNotIn("openusd", result)
        self.assertTrue(result["hybrid"]["execution_completed"])
        self.assertEqual(2.0, result["hybrid"]["clock"]["stop_time"])

    def test_raw_baseline_bypasses_normalization_and_executes_generated_model(self):
        ir = CapabilityPlanningTests().modelica_ir()
        generated = "model BaselineRobot end BaselineRobot;"

        def generated_modelica(requirement: str, output_dir: Path):
            return generated, {
                "passed": True, "repairs": 0, "generation_mode": "direct",
                "generation_model": "z-ai/glm-5.2",
                "attempts": [{"passed": True}],
            }

        class Pipeline:
            runner = object()
            fmi_runner = object()

        class Execution:
            def run(self, modelica, requirement_ir, contract, *, output_dir):
                self_outer.assertEqual(generated, modelica)
                self_outer.assertEqual("BaselineRobot", contract["model_name"])
                return {
                    "passed": True,
                    "execution_mode": "integrated_fmu_behavior",
                    "execution_completed": True,
                    "behavior_evaluated": True,
                    "behavior_passed": True,
                    "clock": {
                        "start_time": 0.0, "stop_time": 2.0,
                        "frequency_hz": 100.0, "step_size": 0.01,
                    },
                    "fmu": {"success": True},
                    "contract": {
                        "success": True,
                        "resolved_mappings": contract["mappings"],
                        "resolved_parameter_mappings": contract["parameter_mappings"],
                    },
                    "execution": {"success": True, "initialized": True},
                    "trace_gate": {"success": True},
                    "properties": [{
                        "id": "bounded_angular_rate", "passed": True,
                        "status": "satisfied",
                    }],
                    "property_summary": {
                        "total": 1, "passed": 1, "violated": 0,
                        "unevaluable": 0,
                    },
                }

            run_compiler_execution_baseline = run

        self_outer = self
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = ModelicaCapabilityOrchestrator(
                modelica_pipeline=Pipeline(),
                modelica_generator=generated_modelica,
                execution_pipeline=Execution(),
            ).run_compiler_execution_baseline(
                ir["source_text"], output_dir=root, task_id=ir["task_id"],
                clock={"duration": 2.0, "frequency_hz": 100.0},
            )
            execution_contract = json.loads(
                (root / "execution-contract.json").read_text(encoding="utf-8")
            )

        self.assertTrue(result["passed"], result)
        self.assertFalse(result["normalization"]["applicable"])
        self.assertEqual("BaselineRobot", result["modelica"]["model_name"])
        self.assertTrue(result["modelica"]["identity_accepted"])
        self.assertEqual("z-ai/glm-5.2", result["modelica"]["generation_model"])
        self.assertEqual("BaselineRobot", execution_contract["model_name"])
        self.assertFalse((root / "contract.json").exists())

    def test_artifact_validation_without_a_grounded_clock_cannot_pass(self):
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

        self.assertFalse(result["passed"], result)
        self.assertEqual("execution_failed", result["execution_status"])
        self.assertEqual("execution_clock", result["failure_stage"])
        self.assertTrue(result["pre_execution_alignment"]["passed"])
        self.assertEqual("failed", result["stage_trace"][5]["status"])
        self.assertEqual("not_reached", result["stage_trace"][9]["status"])
        self.assertEqual(2, report["verification"]["highest_reached_tier"])
        self.assertFalse(report["claim_eligible_deltaai_h2"])
        self.assertEqual(
            "requires_cross_artifact_validation",
            report["grounding"]["artifact_grounding_status"],
        )

    def test_executed_behavior_and_post_alignment_are_required_for_pass(self):
        ir = broad_ir()
        clock_text = "Run at 100 Hz for 2 s."
        ir["source_text"] += " " + clock_text
        ir["clock"] = {
            "duration": 2.0, "frequency_hz": 100.0,
            "evidence": [clock_text],
        }

        def generated_modelica(requirement: str, output_dir: Path):
            return "model RobotTask_RPROF001 end RobotTask_RPROF001;", {
                "passed": True, "repairs": 0, "generation_mode": "test",
            }

        def generated_usd(requirement: str, output_dir: Path):
            return "#usda 1.0\n", {
                "passed": True, "repairs": 0, "generation_mode": "test",
            }

        class FakeCapabilityExecution:
            def run(self, modelica, requirement_ir, contract, *, output_dir):
                mappings = [
                    {**row, "verification_status": "resolved_fmu_output"}
                    for row in contract["mappings"]
                ]
                return {
                    "passed": True,
                    "execution_mode": "integrated_fmu_behavior",
                    "execution_completed": True,
                    "behavior_evaluated": True,
                    "behavior_passed": True,
                    "fmu": {"success": True},
                    "contract": {
                        "success": True,
                        "resolved_mappings": mappings,
                        "fmu": {"variables": []},
                    },
                    "execution": {
                        "success": True, "initialized": True,
                        "sample_count": 200,
                    },
                    "trace_gate": {"success": True, "finite": True},
                    "properties": [{
                        "id": "bounded_angular_rate",
                        "property_id": "bounded_angular_rate",
                        "passed": True,
                        "status": "satisfied",
                        "robustness": 1.0,
                    }],
                    "property_summary": {
                        "total": 1, "passed": 1,
                        "violated": 0, "unevaluable": 0,
                    },
                }

        with tempfile.TemporaryDirectory() as tmp:
            result = RoboticsOrchestrator(
                modelica_generator=generated_modelica,
                openusd_generator=generated_usd,
                capability_execution_pipeline=FakeCapabilityExecution(),
            ).run(
                ir["source_text"], lambda _: json.dumps(ir),
                output_dir=Path(tmp), task_id=ir["task_id"],
                execution_mode="capability_tiered", max_ir_repairs=0,
            )

        self.assertTrue(result["passed"], result)
        self.assertEqual("behaviorally_executed", result["execution_status"])
        self.assertTrue(result["hybrid"]["execution_completed"])
        self.assertTrue(result["stage_trace"][9]["passed"])
        self.assertTrue(result["stage_trace"][10]["passed"])
        self.assertTrue(result["stage_trace"][11]["passed"])

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
