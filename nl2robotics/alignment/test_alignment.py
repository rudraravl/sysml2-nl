from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import unittest

from nl2robotics.alignment.evaluator import RoboticsAlignmentEvaluator
from nl2robotics.alignment.bank import load_bank
from nl2robotics.alignment.judge import parse_answers
from nl2robotics.alignment.questions import instantiate_questions


ORACLE = Path(__file__).resolve().parents[1] / "hybrid" / "oracles" / "RHY101"


def oracle_ir() -> dict:
    return json.loads((ORACLE / "requirement_ir.json").read_text(encoding="utf-8"))


def oracle_contract() -> dict:
    return json.loads((ORACLE / "contract.json").read_text(encoding="utf-8"))


def evidence_report() -> dict:
    contract = oracle_contract()
    mappings = deepcopy(contract["mappings"])
    return {
        "passed": True,
        "contract": {
            "success": True,
            "issues": [],
            "resolved_mappings": mappings,
            "fmu": {
                "variables": [
                    {"name": "targetAngle", "causality": "parameter",
                     "unit": "rad", "start": str(3.141592653589793 / 6)},
                    {"name": "kp", "causality": "parameter",
                     "unit": "N.m/rad", "start": "12"},
                    {"name": "kd", "causality": "parameter",
                     "unit": "N.m.s/rad", "start": "2"},
                    {"name": "torqueLimit", "causality": "parameter",
                     "unit": "N.m", "start": "5"},
                    {"name": "shoulderAngle", "causality": "input",
                     "unit": "rad", "start": "0"},
                    {"name": "shoulderAngularVelocity", "causality": "input",
                     "unit": "rad/s", "start": "0"},
                    {"name": "shoulderTorque", "causality": "output",
                     "unit": "N.m", "start": None},
                ]
            },
            "openusd": {
                "success": True,
                "joint_details": [
                    {
                        "path": "/World/WorldAnchor", "type": "fixed",
                        "axis": None, "body0": ["/World/Base"], "body1": [],
                        "lower_limit": None, "upper_limit": None, "drives": [],
                    },
                    {
                        "path": "/World/Shoulder", "type": "revolute",
                        "axis": "Y", "body0": ["/World/Base"],
                        "body1": ["/World/Link"], "lower_limit": -90.0,
                        "upper_limit": 90.0, "drives": [],
                    },
                ],
                "rigid_body_details": [
                    {"path": "/World/Base", "mass": None},
                    {"path": "/World/Link", "mass": 2.0},
                ],
                "physics_scene_details": [
                    {"path": "/World/PhysicsScene", "gravity_magnitude": 0.0}
                ],
                "collision_details": [
                    {"path": "/World/Link/Collision",
                     "parent_rigid_body": "/World/Link", "shape": "cube",
                     "dimensions": [0.1, 0.1, 0.6], "scale": [0.1, 0.1, 0.6]}
                ],
            },
        },
        "properties": [
            {"property_id": "within_joint_limits", "passed": True, "robustness": 1.0},
            {"property_id": "reaches_target", "passed": True, "robustness": 0.01},
        ],
    }


class QuestionTests(unittest.TestCase):
    def test_bank_is_versioned_and_declares_evidence_policy(self):
        bank = load_bank()
        self.assertEqual("1.0.0", bank["version"])
        self.assertTrue(bank["policy"]["instantiate_only_grounded_facts"])
        self.assertGreaterEqual(len(bank["families"]), 17)

    def test_questions_are_concrete_and_only_instantiated_from_grounded_facts(self):
        ir = oracle_ir()
        questions = instantiate_questions(ir)
        ids = {item.id for item in questions}
        self.assertEqual(23, len(questions))
        self.assertIn("execution_backend", {item.family for item in questions})
        self.assertIn("RQ-JOINT-LIMITS-SHOULDER", ids)
        self.assertIn("RQ-PARAMETER-TORQUE-LIMIT", ids)
        self.assertFalse(any("friction" in item.text.lower() for item in questions))
        self.assertTrue(all(item.evidence for item in questions))
        self.assertIn("RQ-CONTROLLER-PRESENCE-SHOULDER-PD", ids)
        self.assertIn("RQ-CONTROLLER-KIND-SHOULDER-PD", ids)

    def test_backend_question_requires_matching_grounded_mode_and_source(self):
        ir = oracle_ir()
        ir["execution_mode"] = "newton_closed_loop"
        self.assertNotIn(
            "execution_backend",
            {item.family for item in instantiate_questions(ir)},
        )


class EvaluatorTests(unittest.TestCase):
    def evaluate(self, report: dict | None = None,
                 contract: dict | None = None) -> dict:
        return RoboticsAlignmentEvaluator().evaluate(
            oracle_ir(),
            modelica=(ORACLE / "model.mo").read_text(encoding="utf-8"),
            openusd=(ORACLE / "scene.usda").read_text(encoding="utf-8"),
            contract=contract or oracle_contract(),
            hybrid_report=report or evidence_report(),
        )

    def test_formal_evidence_passes_and_unknowns_only_reduce_coverage(self):
        result = self.evaluate()
        self.assertTrue(result["passed"], result)
        self.assertTrue(result["artifact_gate_passed"])
        self.assertFalse(result["claim_ready"])
        self.assertEqual(0, result["summary"]["blocking_violations"])
        self.assertGreater(result["summary"]["counts"]["satisfied"], 0)
        self.assertGreater(result["summary"]["counts"]["unknown"], 0)
        self.assertLess(result["summary"]["evidence_coverage"], 1.0)
        self.assertEqual(
            ["Contact material and joint friction"],
            result["selection"]["excluded_unknowns"],
        )
        timing = next(item for item in result["rows"]
                      if item["question"]["family"] == "timing")
        self.assertEqual("satisfied", timing["artifact"]["status"])
        parameter = next(item for item in result["rows"]
                         if item["question"]["id"] == "RQ-PARAMETER-KP")
        self.assertEqual("satisfied", parameter["artifact"]["status"])
        geometry = next(item for item in result["rows"]
                        if item["question"]["family"] == "entity_geometry")
        self.assertEqual("satisfied", geometry["artifact"]["status"])

    def test_post_execution_evidence_is_required_for_claim_readiness(self):
        report = evidence_report()
        report["controller_conformance"] = {
            "stage": "controller_behavioral_conformance",
            "profile": "one_dof_pd_effort",
            "success": True,
            "probe_count": 7,
            "passed_probes": 7,
            "probes": [],
        }
        result = self.evaluate(report)
        self.assertTrue(result["passed"], result)
        self.assertTrue(result["claim_ready"], result)
        self.assertEqual(0, result["summary"]["counts"]["unknown"])
        controller_kind = next(
            row for row in result["rows"]
            if row["question"]["family"] == "controller_kind"
        )
        self.assertEqual("satisfied", controller_kind["artifact"]["status"])

    def test_parameter_perturbation_is_localized_and_modelica_repairable(self):
        report = evidence_report()
        report["contract"]["fmu"]["variables"][1]["start"] = "9"
        result = self.evaluate(report)
        violated = [row for row in result["rows"]
                    if row["artifact"]["status"] == "violated"]
        self.assertEqual(["RQ-PARAMETER-KP"],
                         [row["question"]["id"] for row in violated])
        self.assertEqual("modelica", result["repair_plan"]["actions"][0]["owner"])

    def test_grounded_initial_value_is_compared_by_interface_adapter(self):
        ir = oracle_ir()
        ir["interfaces"][0]["initial_value"] = 0.25
        report = evidence_report()
        result = RoboticsAlignmentEvaluator().evaluate(
            ir,
            modelica=(ORACLE / "model.mo").read_text(encoding="utf-8"),
            openusd=(ORACLE / "scene.usda").read_text(encoding="utf-8"),
            contract=oracle_contract(), hybrid_report=report,
        )
        row = next(
            item for item in result["rows"]
            if item["question"]["id"] == "RQ-INTERFACE-SHOULDER-ANGLE-TO-CONTROLLER"
        )
        self.assertEqual("violated", row["artifact"]["status"])

    def test_geometry_perturbation_is_localized_and_openusd_repairable(self):
        report = evidence_report()
        report["contract"]["openusd"]["collision_details"][0]["dimensions"] = [
            0.05, 0.05, 0.3
        ]
        result = self.evaluate(report)
        violated = [row for row in result["rows"]
                    if row["artifact"]["status"] == "violated"]
        self.assertEqual(["RQ-ENTITY-GEOMETRY-LINK"],
                         [row["question"]["id"] for row in violated])
        self.assertEqual("openusd", result["repair_plan"]["actions"][0]["owner"])

    def test_openusd_sensor_presence_and_configuration_are_deterministic(self):
        ir = oracle_ir()
        sensor_evidence = "an IMU on the link translated 0.2 meters upward"
        ir["source_text"] += " Add " + sensor_evidence + "."
        ir["sensors"] = [{
            "id": "link_imu", "owner": "usd_physics", "kind": "imu",
            "entity_id": "link", "translation": [0.0, 0.0, 0.2],
            "evidence": [sensor_evidence],
        }]
        report = evidence_report()
        report["contract"]["openusd"]["sensor_details"] = [{
            "path": "/World/Link/IMU", "sensor_type": "imu",
            "parent": "/World/Link", "translation": [0.0, 0.0, 0.2],
        }]
        result = RoboticsAlignmentEvaluator().evaluate(
            ir,
            modelica=(ORACLE / "model.mo").read_text(encoding="utf-8"),
            openusd=(ORACLE / "scene.usda").read_text(encoding="utf-8"),
            contract=oracle_contract(), hybrid_report=report,
        )
        sensor_rows = [
            row for row in result["rows"]
            if row["question"]["family"].startswith("sensor_")
        ]
        self.assertEqual(2, len(sensor_rows))
        self.assertTrue(all(
            row["artifact"]["status"] == "satisfied" for row in sensor_rows
        ))

        report["contract"]["openusd"]["sensor_details"][0]["translation"] = [0, 0, 0]
        changed = RoboticsAlignmentEvaluator().evaluate(
            ir,
            modelica=(ORACLE / "model.mo").read_text(encoding="utf-8"),
            openusd=(ORACLE / "scene.usda").read_text(encoding="utf-8"),
            contract=oracle_contract(), hybrid_report=report,
        )
        configuration = next(
            row for row in changed["rows"]
            if row["question"]["family"] == "sensor_configuration"
        )
        self.assertEqual("violated", configuration["artifact"]["status"])

    def test_deterministic_perturbation_matrix_covers_major_evidence_families(self):
        cases = [
            (lambda contract, report: contract["clock"].__setitem__("step_size", 0.02),
             "timing"),
            (lambda contract, report: report["contract"]["openusd"]["rigid_body_details"][1]
             .__setitem__("mass", 4.0), "entity_mass"),
            (lambda contract, report: report["contract"]["openusd"]["joint_details"][1]
             .__setitem__("upper_limit", 80.0), "joint_limits"),
            (lambda contract, report: contract["state_ownership"][0]
             .__setitem__("owner", "fmu_controller"), "dynamics"),
            (lambda contract, report: report["contract"]["resolved_mappings"][0]
             .__setitem__("target_unit", "deg"), "interface"),
            (lambda contract, report: report["contract"]["openusd"]["physics_scene_details"][0]
             .__setitem__("gravity_magnitude", 9.81), "environment"),
            (lambda contract, report: report["contract"]["fmu"]["variables"][-1]
             .__setitem__("causality", "local"), "controller_presence"),
        ]
        for mutate, expected_family in cases:
            with self.subTest(family=expected_family):
                report = evidence_report()
                contract = oracle_contract()
                mutate(contract, report)
                result = self.evaluate(report, contract)
                violated = {
                    row["question"]["family"] for row in result["rows"]
                    if row["artifact"]["status"] == "violated"
                }
                self.assertIn(expected_family, violated, result)
                self.assertFalse(result["passed"])

    def test_seeded_axis_mismatch_blocks_and_routes_to_openusd(self):
        report = evidence_report()
        report["contract"]["openusd"]["joint_details"][1]["axis"] = "Z"
        result = self.evaluate(report)
        self.assertFalse(result["passed"])
        row = next(
            item for item in result["rows"]
            if item["question"]["id"] == "RQ-JOINT-AXIS-SHOULDER"
        )
        self.assertEqual("violated", row["artifact"]["status"])
        self.assertTrue(row["artifact"]["repair_eligible"])
        self.assertEqual("openusd", result["repair_plan"]["actions"][0]["owner"])

    def test_failed_runtime_property_blocks_but_does_not_guess_repair_owner(self):
        report = evidence_report()
        report["properties"][1]["passed"] = False
        result = self.evaluate(report)
        self.assertFalse(result["passed"])
        row = next(
            item for item in result["rows"]
            if item["question"]["id"] == "RQ-PROPERTY-REACHES-TARGET"
        )
        self.assertTrue(row["artifact"]["blocking"])
        self.assertFalse(row["artifact"]["repair_eligible"])

    def test_llm_only_violation_is_diagnostic_not_blocking(self):
        ir = oracle_ir()
        modelica = (ORACLE / "model.mo").read_text(encoding="utf-8")
        usd = (ORACLE / "scene.usda").read_text(encoding="utf-8")

        def ask(prompt: str) -> str:
            artifact = modelica if "```modelica" in prompt else usd
            questions = instantiate_questions(ir)
            pending = [item for item in questions if item.id in prompt]
            return json.dumps({"answers": [
                {
                    "qid": item.id,
                    "status": "violated" if item.id == "RQ-CONTROLLER-KIND-SHOULDER-PD" else "unknown",
                    "evidence": "shoulderTorque = max" if (
                        item.id == "RQ-CONTROLLER-KIND-SHOULDER-PD" and artifact == modelica
                    ) else "",
                    "confidence": 0.99,
                }
                for item in pending
            ]})

        result = RoboticsAlignmentEvaluator().evaluate(
            ir, modelica=modelica, openusd=usd, contract=oracle_contract(),
            hybrid_report=evidence_report(), ask=ask,
        )
        row = next(item for item in result["rows"]
                   if item["question"]["id"] == "RQ-CONTROLLER-KIND-SHOULDER-PD")
        self.assertEqual("violated", row["artifact"]["status"])
        self.assertFalse(row["artifact"]["blocking"])
        self.assertFalse(row["artifact"]["repair_eligible"])
        self.assertTrue(result["passed"])


class JudgeTests(unittest.TestCase):
    def test_non_verbatim_evidence_is_rejected(self):
        question = instantiate_questions(oracle_ir())[0]
        result = parse_answers(
            json.dumps({"answers": [{
                "qid": question.id, "status": "violated",
                "evidence": "invented evidence", "confidence": 1.0,
            }]}),
            [question], "actual artifact", "modelica",
        )
        self.assertEqual("unknown", result[question.id]["status"])
        self.assertEqual(0.0, result[question.id]["confidence"])


if __name__ == "__main__":
    unittest.main()
