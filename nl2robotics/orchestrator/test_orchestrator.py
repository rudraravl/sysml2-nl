from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest

from nl2robotics.orchestrator.normalizer import RequirementNormalizer
from nl2robotics.orchestrator.pipeline import RoboticsOrchestrator
from nl2robotics.orchestrator.planner import (
    PlanningError,
    build_h1_plan,
    build_h2_plan,
)


ORACLE = (
    Path(__file__).resolve().parents[1] / "hybrid" / "oracles" / "RHY001"
)


def oracle_ir() -> dict:
    return json.loads((ORACLE / "requirement_ir.json").read_text(encoding="utf-8"))


def h2_oracle_ir() -> dict:
    return json.loads(
        (ORACLE.parent / "RHY101" / "requirement_ir.json").read_text(
            encoding="utf-8"
        )
    )


def mixed_h2_oracle_ir() -> dict:
    return json.loads(
        (ORACLE.parent / "RHY202" / "requirement_ir.json").read_text(
            encoding="utf-8"
        )
    )


class NormalizerTests(unittest.TestCase):
    def test_oracle_json_is_accepted_and_authoritative_fields_are_frozen(self):
        source = oracle_ir()["source_text"]
        candidate = oracle_ir()
        candidate["task_id"] = "model_chose_this"
        result = RequirementNormalizer().normalize(
            source,
            lambda _: json.dumps(candidate),
            task_id="RHY001",
            max_repairs=0,
        )
        self.assertTrue(result.success, result.to_dict())
        self.assertEqual("RHY001", result.ir["task_id"])
        self.assertEqual(source, result.ir["source_text"])

    def test_invented_evidence_is_rejected(self):
        candidate = oracle_ir()
        candidate["entities"][0]["evidence"] = ["invented robot fact"]
        result = RequirementNormalizer().normalize(
            candidate["source_text"], lambda _: json.dumps(candidate),
            task_id="RHY001", max_repairs=0,
        )
        self.assertFalse(result.success)
        self.assertIn("ungrounded_evidence", {item.code for item in result.issues})

    def test_h2_mode_is_frozen_and_preserved(self):
        candidate = h2_oracle_ir()
        candidate["execution_mode"] = "portable_fmu_kinematic"
        result = RequirementNormalizer().normalize(
            candidate["source_text"], lambda _: json.dumps(candidate),
            task_id="RHY101", execution_mode="isaac_closed_loop", max_repairs=0,
        )
        self.assertTrue(result.success, result.to_dict())
        self.assertEqual("isaac_closed_loop", result.ir["execution_mode"])


class PlannerTests(unittest.TestCase):
    def test_plan_derives_exact_cross_profile_identifiers(self):
        plan = build_h1_plan(oracle_ir())
        mapping = plan.contract["mappings"][0]
        self.assertEqual("RobotTask_RHY001", plan.model_name)
        self.assertEqual("out_shoulder_angle_to_usd", mapping["fmu_variable"])
        self.assertEqual("/World/Shoulder", mapping["usd_joint_path"])
        self.assertEqual("/World/Link", mapping["usd_driven_prim"])
        self.assertEqual(0.02, plan.contract["clock"]["step_size"])
        self.assertEqual(
            "out_shoulder_angle_to_usd", plan.requirement_ir["properties"][0]["signal"]
        )
        self.assertIn("Preserve these exact output identifiers", plan.modelica_requirement)
        self.assertIn("exact path /World/Shoulder", plan.openusd_requirement)

    def test_prismatic_plan_uses_usda_float_aware_tolerance(self):
        second = json.loads(
            (ORACLE.parent / "RHY002" / "requirement_ir.json").read_text(
                encoding="utf-8"
            )
        )
        plan = build_h1_plan(second)
        self.assertEqual(1e-6, plan.contract["mappings"][0]["numeric_tolerance"])

    def test_missing_clock_stops_before_generation(self):
        ir = oracle_ir()
        del ir["clock"]
        with self.assertRaises(PlanningError) as caught:
            build_h1_plan(ir)
        self.assertIn("missing_clock", {item.code for item in caught.exception.issues})

    def test_interface_state_must_be_owned_by_modelica_dynamics(self):
        ir = oracle_ir()
        ir["interfaces"][0]["state_id"] = "invented.position"
        with self.assertRaises(PlanningError) as caught:
            build_h1_plan(ir)
        self.assertIn(
            "undeclared_interface_state", {item.code for item in caught.exception.issues}
        )

    def test_dynamic_parameter_must_be_finite(self):
        ir = oracle_ir()
        ir["parameters"][0]["value"] = float("inf")
        with self.assertRaises(PlanningError) as caught:
            build_h1_plan(ir)
        self.assertIn(
            "invalid_parameter_value", {item.code for item in caught.exception.issues}
        )

    def test_h2_plan_derives_closed_loop_contract_without_oracle_names(self):
        plan = build_h2_plan(h2_oracle_ir())
        self.assertEqual("RobotTask_RHY101_Controller", plan.model_name)
        self.assertEqual("/World/WorldAnchor", plan.identifiers["articulation_root"])
        self.assertEqual(2, plan.contract["coupling"]["physics_substeps"])
        self.assertEqual(
            {"usd_to_fmu", "fmu_to_usd"},
            {row["direction"] for row in plan.contract["mappings"]},
        )
        self.assertEqual(
            {"usd_physics", "fmu_controller"},
            {row["owner"] for row in plan.contract["mappings"]},
        )
        command = next(
            row for row in plan.contract["mappings"]
            if row["direction"] == "fmu_to_usd"
        )
        self.assertEqual((-5.0, 5.0), (
            command["command_lower"], command["command_upper"]
        ))
        self.assertIn("controller logic only", plan.modelica_requirement)
        self.assertIn("Do not author a position", plan.openusd_requirement)

    def test_h2_requires_grounded_substeps(self):
        ir = h2_oracle_ir()
        del ir["clock"]["physics_substeps"]
        with self.assertRaises(PlanningError) as caught:
            build_h2_plan(ir)
        self.assertIn(
            "missing_physics_substeps", {item.code for item in caught.exception.issues}
        )

    def test_h2_plan_supports_mixed_multi_joint_articulation(self):
        plan = build_h2_plan(mixed_h2_oracle_ir())
        self.assertEqual(6, len(plan.contract["mappings"]))
        commands = {
            row["semantic_joint_id"]: row
            for row in plan.contract["mappings"]
            if row["direction"] == "fmu_to_usd"
        }
        self.assertEqual({"shoulder", "extension"}, set(commands))
        self.assertEqual((-4.0, 4.0), (
            commands["shoulder"]["command_lower"],
            commands["shoulder"]["command_upper"],
        ))
        self.assertEqual((-12.0, 12.0), (
            commands["extension"]["command_lower"],
            commands["extension"]["command_upper"],
        ))
        self.assertIn("independent", plan.modelica_requirement)
        self.assertIn("prismatic joint extension", plan.openusd_requirement)
        self.assertIn("body0 /World/Arm", plan.openusd_requirement)

    def test_h2_topology_accepts_branching_and_rejects_cycles(self):
        branched = mixed_h2_oracle_ir()
        extension = next(row for row in branched["joints"]
                         if row["id"] == "extension")
        extension["parent"] = "base"
        plan = build_h2_plan(branched)
        self.assertIn("body0 /World/Base", plan.openusd_requirement)

        cyclic = mixed_h2_oracle_ir()
        next(row for row in cyclic["joints"]
             if row["id"] == "shoulder")["parent"] = "slider"
        with self.assertRaises(PlanningError) as caught:
            build_h2_plan(cyclic)
        codes = {item.code for item in caught.exception.issues}
        self.assertTrue({"disconnected_articulation", "cyclic_articulation"} & codes)

    def test_h2_rejects_incomplete_pd_semantics_and_missing_properties(self):
        missing_parameter = h2_oracle_ir()
        missing_parameter["parameters"] = [
            row for row in missing_parameter["parameters"]
            if row["quantity"] != "effort_limit"
        ]
        with self.assertRaises(PlanningError) as caught:
            build_h2_plan(missing_parameter)
        self.assertIn(
            "missing_pd_parameters", {item.code for item in caught.exception.issues}
        )

        missing_properties = h2_oracle_ir()
        missing_properties["properties"] = []
        with self.assertRaises(PlanningError) as caught:
            build_h2_plan(missing_properties)
        self.assertIn(
            "missing_behavior_property", {item.code for item in caught.exception.issues}
        )

    def test_h2_rejects_ambiguous_interface_and_parameter_profiles(self):
        duplicate_feedback = h2_oracle_ir()
        duplicate = deepcopy(duplicate_feedback["interfaces"][0])
        duplicate["id"] = "second_position_input"
        duplicate_feedback["interfaces"].append(duplicate)
        with self.assertRaises(PlanningError) as caught:
            build_h2_plan(duplicate_feedback)
        self.assertIn(
            "incomplete_h2_feedback", {item.code for item in caught.exception.issues}
        )

        duplicate_parameter = h2_oracle_ir()
        duplicate = deepcopy(duplicate_parameter["parameters"][0])
        duplicate["id"] = "second_kp"
        duplicate_parameter["parameters"].append(duplicate)
        with self.assertRaises(PlanningError) as caught:
            build_h2_plan(duplicate_parameter)
        self.assertIn(
            "duplicate_h2_parameter", {item.code for item in caught.exception.issues}
        )

    def test_h2_rejects_unreachable_states_and_empty_property_windows(self):
        target = h2_oracle_ir()
        next(row for row in target["parameters"]
             if row["quantity"] == "target_position")["value"] = 100.0
        with self.assertRaises(PlanningError) as caught:
            build_h2_plan(target)
        self.assertIn(
            "unreachable_h2_target", {item.code for item in caught.exception.issues}
        )

        initial = h2_oracle_ir()
        next(row for row in initial["interfaces"]
             if row["quantity"] == "joint_position")["initial_value"] = 2.0
        with self.assertRaises(PlanningError) as caught:
            build_h2_plan(initial)
        self.assertIn(
            "invalid_h2_initial_position", {item.code for item in caught.exception.issues}
        )

        empty_interval = h2_oracle_ir()
        empty_interval["properties"][0].update({"start": 0.0, "end": 0.005})
        with self.assertRaises(PlanningError) as caught:
            build_h2_plan(empty_interval)
        self.assertIn(
            "empty_property_interval", {item.code for item in caught.exception.issues}
        )


class OrchestratorTests(unittest.TestCase):
    def test_one_plan_drives_both_generators_and_h1(self):
        ir = oracle_ir()
        calls = {}

        def generate_modelica(requirement: str, output_dir: Path):
            calls["modelica_requirement"] = requirement
            return "model RobotTask_RHY001 end RobotTask_RHY001;", {
                "passed": True, "repairs": 0, "generation_mode": "test",
            }

        def generate_openusd(requirement: str, output_dir: Path):
            calls["openusd_requirement"] = requirement
            return "#usda 1.0\n", {
                "passed": True, "repairs": 0, "generation_mode": "test",
            }

        class Portable:
            def run(self, modelica, source_usd, requirement_ir, contract, *, output_dir):
                calls["contract"] = deepcopy(contract)
                calls["runtime_ir"] = deepcopy(requirement_ir)
                output_dir.mkdir(parents=True, exist_ok=True)
                return {
                    "passed": True,
                    "contract": {"success": True},
                    "fmu": {"success": True},
                    "execution": {"success": True},
                    "playback": {"success": True},
                    "properties": [{"passed": True}],
                }

        class Alignment:
            def evaluate(self, *args, **kwargs):
                calls["alignment"] = True
                return {
                    "passed": True,
                    "summary": {
                        "question_count": 1,
                        "counts": {"satisfied": 1, "violated": 0,
                                   "unknown": 0, "not_applicable": 0},
                        "weighted_semantic_score": 1.0,
                        "evidence_coverage": 1.0,
                        "blocking_violations": 0,
                        "deterministic_violations": 0,
                        "per_family": {"interface": 1.0},
                    },
                }

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pipeline = RoboticsOrchestrator(
                modelica_generator=generate_modelica,
                openusd_generator=generate_openusd,
                portable_pipeline=Portable(),
                alignment_evaluator=Alignment(),
            )
            result = pipeline.run(
                ir["source_text"], lambda _: json.dumps(ir),
                output_dir=root, task_id="RHY001", max_ir_repairs=0,
            )
            saved = json.loads((root / "result.json").read_text(encoding="utf-8"))
            normalized = json.loads(
                (root / "normalized_requirement_ir.json").read_text(encoding="utf-8")
            )

        self.assertTrue(result["passed"], result)
        self.assertTrue(saved["passed"])
        self.assertTrue(calls["alignment"])
        self.assertEqual("jointAngle", normalized["properties"][0]["signal"])
        self.assertIn("out_shoulder_angle_to_usd", calls["modelica_requirement"])
        self.assertIn("/World/Shoulder", calls["openusd_requirement"])
        self.assertEqual(
            calls["contract"]["mappings"][0]["fmu_variable"],
            calls["runtime_ir"]["properties"][0]["signal"],
        )

    def test_failed_profile_never_reaches_hybrid_runtime(self):
        ir = oracle_ir()

        class Portable:
            def run(self, *args, **kwargs):
                raise AssertionError("hybrid runtime must not run")

        failing = lambda requirement, output_dir: (  # noqa: E731
            "model Bad end Bad;", {"passed": False, "repairs": 2}
        )
        with tempfile.TemporaryDirectory() as tmp:
            pipeline = RoboticsOrchestrator(
                modelica_generator=failing,
                openusd_generator=lambda requirement, output_dir: (
                    "#usda 1.0\n", {"passed": True}
                ),
                portable_pipeline=Portable(),
            )
            result = pipeline.run(
                ir["source_text"], lambda _: json.dumps(ir),
                output_dir=Path(tmp), task_id="RHY001", max_ir_repairs=0,
            )
        self.assertFalse(result["passed"])
        self.assertEqual("modelica_validation", result["failure_stage"])

    def test_deterministic_semantic_repair_is_revalidated_before_acceptance(self):
        ir = oracle_ir()

        class ModelicaValidation:
            def refine_layer1(self, requirement, candidate, repair, **kwargs):
                return {"passed": True, "final_modelica": candidate, "repairs": 0}

        class USDValidation:
            def refine(self, requirement, candidate, repair, **kwargs):
                return {"passed": True, "final_openusd": candidate, "repairs": 0}

        class Portable:
            def run(self, modelica, source_usd, requirement_ir, contract, *, output_dir):
                fixed = 'token physics:axis = "Y"' in source_usd.read_text()
                return {
                    "passed": fixed,
                    "fmu": {"success": True},
                    "contract": {"success": fixed},
                    "execution": {"success": fixed},
                    "playback": {"success": fixed},
                    "properties": [{"passed": fixed}] if fixed else [],
                }

        class Alignment:
            def evaluate(self, requirement_ir, *, openusd, **kwargs):
                fixed = 'token physics:axis = "Y"' in openusd
                return {
                    "passed": fixed,
                    "summary": {
                        "blocking_violations": 0 if fixed else 1,
                        "weighted_semantic_score": 1.0 if fixed else 0.5,
                        "evidence_coverage": 1.0,
                        "question_count": 1,
                        "counts": {"satisfied": int(fixed),
                                   "violated": int(not fixed),
                                   "unknown": 0, "not_applicable": 0},
                        "deterministic_violations": int(not fixed),
                        "per_family": {"joint_axis": 1.0 if fixed else 0.0},
                    },
                    "repair_plan": {"actions": ([] if fixed else [{
                        "owner": "openusd",
                        "violations": [{
                            "qid": "Q-AXIS", "family": "joint_axis",
                            "text": "Use Y axis", "expected": {"axis": "Y"},
                            "diagnostic": "found Z",
                        }],
                    }])},
                }

        bad_usd = '#usda 1.0\ndef Xform "World" { token physics:axis = "Z" }'
        good_usd = '#usda 1.0\ndef Xform "World" { token physics:axis = "Y" }'
        with tempfile.TemporaryDirectory() as tmp:
            pipeline = RoboticsOrchestrator(
                modelica_pipeline=ModelicaValidation(),
                openusd_pipeline=USDValidation(),
                modelica_generator=lambda requirement, output: (
                    "model RobotTask_RHY001 end RobotTask_RHY001;",
                    {"passed": True, "repairs": 0},
                ),
                openusd_generator=lambda requirement, output: (
                    bad_usd, {"passed": True, "repairs": 0},
                ),
                portable_pipeline=Portable(),
                alignment_evaluator=Alignment(),
            )
            result = pipeline.run(
                ir["source_text"], lambda _: json.dumps(ir),
                output_dir=Path(tmp), task_id="RHY001", max_ir_repairs=0,
                semantic_repair_ask=lambda _: good_usd,
            )
        self.assertTrue(result["passed"], result)
        self.assertEqual(1, result["semantic_repair"]["accepted"])
        self.assertTrue(result["hybrid"]["passed"])

    def test_h2_preparation_is_not_misreported_as_execution(self):
        ir = h2_oracle_ir()
        observed = {}

        def prepare(**kwargs):
            observed.update(kwargs)
            observed["execution_mode"] = json.loads(
                kwargs["contract_path"].read_text()
            )["execution_mode"]
            kwargs["output_dir"].mkdir(parents=True, exist_ok=True)
            (kwargs["output_dir"] / "execution-input.json").write_text(
                "{}\n", encoding="utf-8"
            )
            return {
                "stage": "isaac_bundle_preparation",
                "success": True,
                "claim_eligible_h2": False,
                "contract": {"success": True},
            }

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pipeline = RoboticsOrchestrator(
                modelica_generator=lambda requirement, output: (
                    "model RobotTask_RHY101_Controller end RobotTask_RHY101_Controller;",
                    {"passed": True, "repairs": 0},
                ),
                openusd_generator=lambda requirement, output: (
                    "#usda 1.0\n", {"passed": True, "repairs": 0},
                ),
                isaac_preparer=prepare,
            )
            result = pipeline.run(
                ir["source_text"], lambda _: json.dumps(ir),
                output_dir=root, task_id="RHY101",
                execution_mode="isaac_closed_loop", max_ir_repairs=0,
                enable_alignment=False,
            )

        self.assertTrue(result["ready_for_gpu"], result)
        self.assertFalse(result["passed"])
        self.assertFalse(result["hybrid"]["claim_eligible_h2"])
        self.assertEqual("gpu_execution_pending", result["failure_stage"])
        self.assertEqual("isaac_closed_loop", observed["execution_mode"])

    def test_newton_mode_selects_newton_preparer_and_preserves_mode(self):
        ir = h2_oracle_ir()
        ir["execution_mode"] = "newton_closed_loop"
        observed = {}

        def prepare(**kwargs):
            observed["execution_mode"] = json.loads(
                kwargs["contract_path"].read_text()
            )["execution_mode"]
            kwargs["output_dir"].mkdir(parents=True, exist_ok=True)
            (kwargs["output_dir"] / "execution-input.json").write_text(
                "{}\n", encoding="utf-8"
            )
            return {
                "stage": "newton_closed_loop_bundle_preparation",
                "success": True,
                "claim_eligible_h2": False,
                "contract": {"success": True},
            }

        with tempfile.TemporaryDirectory() as tmp:
            pipeline = RoboticsOrchestrator(
                modelica_generator=lambda requirement, output: (
                    "model RobotTask_RHY101_Controller end RobotTask_RHY101_Controller;",
                    {"passed": True, "repairs": 0},
                ),
                openusd_generator=lambda requirement, output: (
                    "#usda 1.0\n", {"passed": True, "repairs": 0},
                ),
                isaac_preparer=lambda **kwargs: self.fail("Isaac preparer called"),
                newton_preparer=prepare,
            )
            result = pipeline.run(
                ir["source_text"], lambda _: json.dumps(ir),
                output_dir=Path(tmp), task_id="RHY201",
                execution_mode="newton_closed_loop", max_ir_repairs=0,
                enable_alignment=False,
            )

        self.assertTrue(result["ready_for_gpu"], result)
        self.assertEqual("newton_closed_loop", observed["execution_mode"])
        self.assertEqual(
            "newton_closed_loop", result["hybrid"]["execution_mode"]
        )

    def test_h2_semantic_repair_is_revalidated_before_gpu_readiness(self):
        ir = h2_oracle_ir()

        class ModelicaValidation:
            runner = object()

            def refine_layer1(self, requirement, candidate, repair, **kwargs):
                return {"passed": True, "final_modelica": candidate, "repairs": 0}

        class USDValidation:
            validator = object()

            def refine(self, requirement, candidate, repair, **kwargs):
                return {"passed": True, "final_openusd": candidate, "repairs": 0}

        def prepare(**kwargs):
            kwargs["output_dir"].mkdir(parents=True, exist_ok=True)
            (kwargs["output_dir"] / "execution-input.json").write_text(
                "{}\n", encoding="utf-8"
            )
            return {
                "success": True,
                "fmu": {"success": True},
                "contract": {"success": True},
            }

        class Alignment:
            def evaluate(self, requirement_ir, *, openusd, **kwargs):
                fixed = 'token physics:axis = "Y"' in openusd
                return {
                    "passed": fixed,
                    "summary": {
                        "blocking_violations": 0 if fixed else 1,
                        "weighted_semantic_score": 1.0 if fixed else 0.5,
                        "evidence_coverage": 1.0,
                        "question_count": 1,
                        "counts": {"satisfied": int(fixed),
                                   "violated": int(not fixed),
                                   "unknown": 0, "not_applicable": 0},
                        "deterministic_violations": int(not fixed),
                        "per_family": {"joint_axis": 1.0 if fixed else 0.0},
                    },
                    "repair_plan": {"actions": ([] if fixed else [{
                        "owner": "openusd",
                        "violations": [{
                            "qid": "Q-AXIS", "family": "joint_axis",
                            "text": "Use Y axis", "expected": {"axis": "Y"},
                            "diagnostic": "found Z",
                        }],
                    }])},
                }

        bad_usd = '#usda 1.0\ndef Xform "World" { token physics:axis = "Z" }'
        good_usd = '#usda 1.0\ndef Xform "World" { token physics:axis = "Y" }'
        with tempfile.TemporaryDirectory() as tmp:
            pipeline = RoboticsOrchestrator(
                modelica_pipeline=ModelicaValidation(),
                openusd_pipeline=USDValidation(),
                modelica_generator=lambda requirement, output: (
                    "model RobotTask_RHY101_Controller end RobotTask_RHY101_Controller;",
                    {"passed": True, "repairs": 0},
                ),
                openusd_generator=lambda requirement, output: (
                    bad_usd, {"passed": True, "repairs": 0},
                ),
                isaac_preparer=prepare,
                alignment_evaluator=Alignment(),
            )
            result = pipeline.run(
                ir["source_text"], lambda _: json.dumps(ir),
                output_dir=Path(tmp), task_id="RHY101",
                execution_mode="isaac_closed_loop", max_ir_repairs=0,
                semantic_repair_ask=lambda _: good_usd,
            )
        self.assertTrue(result["ready_for_gpu"], result)
        self.assertEqual(1, result["semantic_repair"]["accepted"])
        self.assertFalse(result["passed"])


if __name__ == "__main__":
    unittest.main()
