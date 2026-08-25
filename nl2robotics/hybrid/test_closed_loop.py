from __future__ import annotations

from copy import deepcopy
import csv
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from nl2robotics.contracts.hybrid_contract import HybridContractValidator
from nl2robotics.modelica.models import FMUVariable

from .closed_loop import ClosedLoopMaster
from .closed_loop_properties import evaluate_closed_loop_properties
from .controller_conformance import evaluate_controller_conformance
from .reference_runtime import (
    ReferenceArticulatedPhysics,
    ReferenceMultiJointPDController,
    ReferenceOneDOFPhysics,
    ReferencePDController,
)


ORACLE = Path(__file__).resolve().parent / "oracles" / "RHY101"
MIXED_ORACLE = Path(__file__).resolve().parent / "oracles" / "RHY202"


def load(name: str) -> dict:
    return json.loads((ORACLE / name).read_text(encoding="utf-8"))


def fmu_metadata() -> dict:
    return {
        "fmi_version": "2.0",
        "interface_type": "co_simulation",
        "model_name": "ClosedLoopShoulderController",
        "model_identifier": "ClosedLoopShoulderController",
        "variables": [
            FMUVariable("shoulderAngle", 1, "real", "input", "continuous", unit="rad"),
            FMUVariable("shoulderAngularVelocity", 2, "real", "input", "continuous", unit="rad/s"),
            FMUVariable("shoulderTorque", 3, "real", "output", "continuous", unit="N.m"),
        ],
    }


def openusd_metadata() -> dict:
    return {
        "success": True,
        "metadata": {"time_codes_per_second": 100.0},
        "evidence": {
            "physics_scene_details": [{
                "path": "/World/PhysicsScene",
                "gravity_direction": [0.0, 0.0, -1.0],
                "gravity_magnitude": 0.0,
            }],
            "rigid_body_details": [{
                "path": "/World/Link", "mass": 2.0, "kinematic_enabled": False,
            }],
            "joint_details": [{
                "path": "/World/Shoulder",
                "type": "revolute",
                "body0": ["/World/Base"],
                "body1": ["/World/Link"],
                "axis": "Y",
                "lower_limit": -90.0,
                "upper_limit": 90.0,
                "drives": [],
            }, {
                "path": "/World/WorldAnchor",
                "type": "fixed",
                "body0": ["/World/Base"],
                "body1": [],
                "axis": None,
                "lower_limit": None,
                "upper_limit": None,
                "drives": [],
            }],
            "articulations": ["/World/WorldAnchor"],
        },
    }


def resolved_mappings() -> list[dict]:
    result = HybridContractValidator().validate_metadata(
        load("contract.json"), load("requirement_ir.json"),
        fmu_metadata(), openusd_metadata(),
    )
    if not result.success:
        raise AssertionError(result.to_dict())
    return result.resolved_mappings


def mixed_load(name: str) -> dict:
    return json.loads((MIXED_ORACLE / name).read_text(encoding="utf-8"))


def mixed_fmu_metadata() -> dict:
    variables = [
        FMUVariable("shoulderPosition", 1, "real", "input", "continuous", unit="rad"),
        FMUVariable("shoulderVelocity", 2, "real", "input", "continuous", unit="rad/s"),
        FMUVariable("shoulderEffort", 3, "real", "output", "continuous", unit="N.m"),
        FMUVariable("extensionPosition", 4, "real", "input", "continuous", unit="m"),
        FMUVariable("extensionVelocity", 5, "real", "input", "continuous", unit="m/s"),
        FMUVariable("extensionEffort", 6, "real", "output", "continuous", unit="N"),
    ]
    return {
        "fmi_version": "2.0",
        "interface_type": "co_simulation",
        "model_name": "MixedJointController",
        "model_identifier": "MixedJointController",
        "variables": variables,
    }


def mixed_openusd_metadata() -> dict:
    return {
        "success": True,
        "metadata": {"time_codes_per_second": 100.0},
        "evidence": {
            "physics_scene_details": [{
                "path": "/World/PhysicsScene",
                "gravity_direction": [0.0, 0.0, -1.0],
                "gravity_magnitude": 0.0,
            }],
            "rigid_body_details": [
                {"path": "/World/Arm", "mass": 2.0, "kinematic_enabled": False},
                {"path": "/World/Slider", "mass": 1.0, "kinematic_enabled": False},
            ],
            "joint_details": [
                {
                    "path": "/World/Shoulder", "type": "revolute",
                    "body0": ["/World/Base"], "body1": ["/World/Arm"],
                    "axis": "Y", "lower_limit": -60.0, "upper_limit": 60.0,
                    "drives": [],
                },
                {
                    "path": "/World/Extension", "type": "prismatic",
                    "body0": ["/World/Arm"], "body1": ["/World/Slider"],
                    "axis": "X", "lower_limit": -0.15, "upper_limit": 0.15,
                    "drives": [],
                },
                {
                    "path": "/World/WorldAnchor", "type": "fixed",
                    "body0": ["/World/Base"], "body1": [], "axis": None,
                    "lower_limit": None, "upper_limit": None, "drives": [],
                },
            ],
            "articulations": ["/World/WorldAnchor"],
        },
    }


def mixed_resolved_mappings() -> list[dict]:
    result = HybridContractValidator().validate_metadata(
        mixed_load("contract.json"), mixed_load("requirement_ir.json"),
        mixed_fmu_metadata(), mixed_openusd_metadata(),
    )
    if not result.success:
        raise AssertionError(result.to_dict())
    return result.resolved_mappings


class H2ContractTests(unittest.TestCase):
    def validate(self, contract=None, fmu=None, openusd=None):
        return HybridContractValidator().validate_metadata(
            contract or load("contract.json"),
            load("requirement_ir.json"),
            fmu or fmu_metadata(),
            openusd or openusd_metadata(),
        )

    def test_h2_contract_resolves_bidirectional_interface(self):
        result = self.validate()
        self.assertTrue(result.success, result.to_dict())
        self.assertEqual(
            {"usd_to_fmu", "fmu_to_usd"},
            {row["direction"] for row in result.resolved_mappings},
        )
        self.assertEqual([1.0, 1.0, 1.0], [row["scale"] for row in result.resolved_mappings])
        command = next(
            row for row in result.resolved_mappings
            if row["direction"] == "fmu_to_usd"
        )
        self.assertEqual((-5.0, 5.0), (
            command["command_lower"], command["command_upper"]
        ))

    def test_h2_requires_grounded_and_consistent_command_bounds(self):
        missing = load("contract.json")
        del missing["mappings"][-1]["command_lower"]
        missing_result = self.validate(contract=missing)
        self.assertIn(
            "missing_command_bounds", {item.code for item in missing_result.issues}
        )

        inconsistent = load("contract.json")
        inconsistent["mappings"][-1]["command_upper"] = 6.0
        inconsistent_result = self.validate(contract=inconsistent)
        self.assertIn(
            "command_bound_mismatch",
            {item.code for item in inconsistent_result.issues},
        )

    def test_h2_rejects_kinematic_body_and_wrong_fmu_side_unit(self):
        stage = openusd_metadata()
        stage["evidence"]["rigid_body_details"][0]["kinematic_enabled"] = True
        contract = load("contract.json")
        contract["mappings"][0]["target_unit"] = "deg"
        result = self.validate(contract=contract, openusd=stage)
        codes = {item.code for item in result.issues}
        self.assertIn("kinematic_closed_loop_body", codes)
        self.assertIn("fmu_unit_mismatch", codes)

    def test_h2_rejects_contract_initial_state_that_differs_from_ir(self):
        ir = load("requirement_ir.json")
        ir["interfaces"][0]["initial_value"] = 0.25
        contract = load("contract.json")
        result = HybridContractValidator().validate_metadata(
            contract, ir, fmu_metadata(), openusd_metadata()
        )
        self.assertIn("ir_interface_mismatch", {
            item.code for item in result.issues
        })

    def test_h2_rejects_conflicting_command_modes(self):
        contract = load("contract.json")
        extra = deepcopy(contract["mappings"][-1])
        extra.update({
            "id": "second_command",
            "interface_id": "shoulder_torque_to_simulator",
            "usd_quantity": "joint_velocity",
            "source_unit": "rad/s",
            "target_unit": "rad/s",
            "fmu_variable": "shoulderTorque",
        })
        contract["mappings"].append(extra)
        result = self.validate(contract=contract)
        self.assertIn(
            "multiple_joint_command_modes", {item.code for item in result.issues}
        )

    def test_effort_command_rejects_authored_joint_drive(self):
        stage = openusd_metadata()
        stage["evidence"]["joint_details"][0]["drives"] = ["angular"]
        result = self.validate(openusd=stage)
        self.assertIn("effort_drive_conflict", {item.code for item in result.issues})

    def test_h2_rejects_a_fixed_base_that_is_not_anchored_to_world(self):
        stage = openusd_metadata()
        stage["evidence"]["articulations"] = ["/World"]
        result = self.validate(openusd=stage)
        self.assertIn("unanchored_fixed_base", {
            item.code for item in result.issues
        })

    def test_h2_rejects_gravity_that_differs_from_grounded_requirement(self):
        stage = openusd_metadata()
        stage["evidence"]["physics_scene_details"][0][
            "gravity_magnitude"
        ] = 9.81
        result = self.validate(openusd=stage)
        self.assertIn("gravity_mismatch", {item.code for item in result.issues})


class ClosedLoopMasterTests(unittest.TestCase):
    def run_once(self, output_dir: Path) -> tuple[dict, list[dict]]:
        controller = ReferencePDController(
            position_input="shoulderAngle",
            velocity_input="shoulderAngularVelocity",
            effort_output="shoulderTorque",
            target=0.5235987755982988,
            kp=12.0,
            kd=2.0,
            effort_limit=5.0,
        )
        physics = ReferenceOneDOFPhysics(
            joint_path="/World/Shoulder", inertia=0.5, damping=0.2,
        )
        contract = load("contract.json")
        report = ClosedLoopMaster().run(
            controller,
            physics,
            mappings=resolved_mappings(),
            clock=contract["clock"],
            coupling=contract["coupling"],
            output_dir=output_dir,
        )
        with Path(report["trace"]).open(encoding="utf-8", newline="") as handle:
            rows = list(csv.DictReader(handle))
        return report, rows

    def test_reference_oracle_is_deterministic_and_bidirectional(self):
        hashes = []
        with tempfile.TemporaryDirectory() as tmp:
            for index in range(3):
                report, rows = self.run_once(Path(tmp) / str(index))
                self.assertTrue(report["success"], report)
                self.assertFalse(report["claim_eligible_h2"])
                self.assertEqual("reference_closed_loop", report["execution_mode"])
                self.assertEqual(300, len(rows))
                fields = set(rows[0])
                self.assertTrue(any(name.startswith("fmu_input:") for name in fields))
                self.assertTrue(any(name.startswith("fmu_output:") for name in fields))
                self.assertTrue(any(name.startswith("sim_command:") for name in fields))
                final_position = float(next(
                    value for name, value in rows[-1].items()
                    if name.startswith("sim_post:map_shoulder_angle")
                ))
                self.assertLess(abs(final_position - 0.5235987755982988), 0.01)
                properties = evaluate_closed_loop_properties(
                    Path(report["trace"]), resolved_mappings(),
                    load("requirement_ir.json")["properties"],
                )
                self.assertTrue(all(item.passed for item in properties), properties)
                hashes.append(hashlib.sha256(Path(report["trace"]).read_bytes()).hexdigest())
        self.assertEqual(1, len(set(hashes)))

    def test_initial_state_mismatch_fails_before_first_step(self):
        controller = ReferencePDController(
            position_input="shoulderAngle",
            velocity_input="shoulderAngularVelocity",
            effort_output="shoulderTorque",
            target=0.5, kp=1.0, kd=0.1, effort_limit=1.0,
        )
        physics = ReferenceOneDOFPhysics(
            joint_path="/World/Shoulder", initial_position=0.2,
        )
        contract = load("contract.json")
        with tempfile.TemporaryDirectory() as tmp:
            report = ClosedLoopMaster().run(
                controller, physics, mappings=resolved_mappings(),
                clock=contract["clock"], coupling=contract["coupling"],
                output_dir=Path(tmp),
            )
        self.assertFalse(report["success"])
        self.assertEqual(0, report["completed_steps"])
        self.assertIn("initial value mismatch", report["error"])

    def test_out_of_contract_effort_is_rejected_before_physics_step(self):
        class UnsafeController:
            metadata = {"backend": "test", "executed": True}

            def initialize(self, **kwargs):
                del kwargs

            def advance(self, **kwargs):
                del kwargs
                return {"shoulderTorque": 6.0}

            def close(self):
                pass

        physics = ReferenceOneDOFPhysics(joint_path="/World/Shoulder")
        contract = load("contract.json")
        with tempfile.TemporaryDirectory() as tmp:
            report = ClosedLoopMaster().run(
                UnsafeController(), physics, mappings=resolved_mappings(),
                clock=contract["clock"], coupling=contract["coupling"],
                output_dir=Path(tmp),
            )
        self.assertFalse(report["success"])
        self.assertEqual(0, report["completed_steps"])
        self.assertIn("exceeds [-5.0, 5.0]", report["error"])


class ControllerConformanceTests(unittest.TestCase):
    @staticmethod
    def correct_runtime(_path: Path):
        return ReferencePDController(
            position_input="shoulderAngle",
            velocity_input="shoulderAngularVelocity",
            effort_output="shoulderTorque",
            target=0.5235987755982988,
            kp=12.0,
            kd=2.0,
            effort_limit=5.0,
        )

    def test_active_probes_certify_pd_direction_damping_and_saturation(self):
        result = evaluate_controller_conformance(
            Path("unused.fmu"), load("requirement_ir.json"),
            resolved_mappings(), load("contract.json")["clock"],
            self.correct_runtime,
        )
        self.assertTrue(result["success"], result)
        self.assertEqual(7, result["probe_count"])
        self.assertEqual(7, result["passed_probes"])
        self.assertEqual({
            "equilibrium", "positive_position_error", "negative_position_error",
            "positive_velocity_damping", "negative_velocity_damping",
            "positive_saturation", "negative_saturation",
        }, {row["id"] for row in result["probes"]})

    def test_metadata_compatible_but_behaviorally_wrong_controller_is_rejected(self):
        class ZeroController:
            def initialize(self, **kwargs):
                del kwargs

            def advance(self, **kwargs):
                del kwargs
                return {"shoulderTorque": 0.0}

            def close(self):
                pass

        result = evaluate_controller_conformance(
            Path("unused.fmu"), load("requirement_ir.json"),
            resolved_mappings(), load("contract.json")["clock"],
            lambda _: ZeroController(),
        )
        self.assertFalse(result["success"])
        self.assertLess(result["passed_probes"], result["probe_count"])


class MixedJointFunctionalTests(unittest.TestCase):
    @staticmethod
    def controller() -> ReferenceMultiJointPDController:
        return ReferenceMultiJointPDController([
            {
                "position_input": "shoulderPosition",
                "velocity_input": "shoulderVelocity",
                "effort_output": "shoulderEffort",
                "target": 0.3490658503988659,
                "kp": 10.0,
                "kd": 1.5,
                "effort_limit": 4.0,
            },
            {
                "position_input": "extensionPosition",
                "velocity_input": "extensionVelocity",
                "effort_output": "extensionEffort",
                "target": 0.08,
                "kp": 50.0,
                "kd": 8.0,
                "effort_limit": 12.0,
            },
        ])

    def test_contract_resolves_mixed_revolute_prismatic_channels(self):
        mappings = mixed_resolved_mappings()
        self.assertEqual(6, len(mappings))
        self.assertEqual({"revolute", "prismatic"}, {
            row["joint_type"] for row in mappings
        })
        commands = [row for row in mappings if row["direction"] == "fmu_to_usd"]
        self.assertEqual({"N.m", "N"}, {row["target_unit"] for row in commands})

    def test_multi_joint_conformance_checks_each_channel_and_isolation(self):
        result = evaluate_controller_conformance(
            Path("unused.fmu"), mixed_load("requirement_ir.json"),
            mixed_resolved_mappings(), mixed_load("contract.json")["clock"],
            lambda _: self.controller(),
        )
        self.assertTrue(result["success"], result)
        self.assertEqual(2, result["joint_count"])
        self.assertEqual(14, result["probe_count"])
        shoulder_probe = next(
            row for row in result["probes"]
            if row["id"] == "shoulder__positive_position_error"
        )
        self.assertEqual(0.0, shoulder_probe["expected_outputs"]["extensionEffort"])
        self.assertTrue(shoulder_probe["output_checks"]["extensionEffort"]["passed"])

    def test_multi_joint_master_runs_all_channels_and_properties(self):
        physics = ReferenceArticulatedPhysics([
            {"joint_path": "/World/Shoulder", "joint_type": "revolute",
             "inertia": 0.5, "damping": 0.2},
            {"joint_path": "/World/Extension", "joint_type": "prismatic",
             "inertia": 1.0, "damping": 0.2},
        ])
        contract = mixed_load("contract.json")
        with tempfile.TemporaryDirectory() as tmp:
            report = ClosedLoopMaster().run(
                self.controller(), physics, mappings=mixed_resolved_mappings(),
                clock=contract["clock"], coupling=contract["coupling"],
                output_dir=Path(tmp),
            )
            properties = evaluate_closed_loop_properties(
                Path(report["trace"]), mixed_resolved_mappings(),
                mixed_load("requirement_ir.json")["properties"],
            )
        self.assertTrue(report["success"], report)
        self.assertEqual(250, report["completed_steps"])
        self.assertTrue(all(item.passed for item in properties), properties)
        self.assertFalse(report["claim_eligible_h2"])


if __name__ == "__main__":
    unittest.main()
