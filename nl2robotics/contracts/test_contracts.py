from __future__ import annotations

from copy import deepcopy
import json
import math
from pathlib import Path
import unittest

from nl2robotics.contracts.hybrid_contract import HybridContractValidator
from nl2robotics.contracts.requirement_ir import validate_requirement_ir
from nl2robotics.contracts.units import UnitError, conversion
from nl2robotics.modelica.models import FMUVariable


ORACLE = (
    Path(__file__).resolve().parents[1]
    / "hybrid" / "oracles" / "RHY001"
)


def load(name: str) -> dict:
    return json.loads((ORACLE / name).read_text(encoding="utf-8"))


def fmu_metadata() -> dict:
    return {
        "fmi_version": "2.0",
        "interface_type": "co_simulation",
        "model_name": "PortableArmPlant",
        "model_identifier": "PortableArmPlant",
        "variables": [
            FMUVariable(
                "jointAngle", 10, "real", "output", "continuous",
                initial="calculated", unit="rad",
            ),
            FMUVariable(
                "jointAngularVelocity", 11, "real", "output", "continuous",
                initial="calculated", unit="rad/s",
            ),
        ],
    }


def openusd_metadata() -> dict:
    return {
        "success": True,
        "metadata": {"time_codes_per_second": 50.0},
        "evidence": {
            "rigid_body_details": [{
                "path": "/World/Link",
                "mass": 2.0,
                "kinematic_enabled": True,
            }],
            "joint_details": [{
                "path": "/World/Shoulder",
                "type": "revolute",
                "body0": ["/World/Base"],
                "body1": ["/World/Link"],
                "axis": "Y",
                "lower_limit": -90.0,
                "upper_limit": 90.0,
            }],
        },
    }


class RequirementIRTests(unittest.TestCase):
    def test_oracle_is_structurally_valid_and_grounded(self):
        self.assertTrue(validate_requirement_ir(load("requirement_ir.json")).success)
        second = json.loads(
            (ORACLE.parent / "RHY002" / "requirement_ir.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertTrue(validate_requirement_ir(second).success)

    def test_non_source_evidence_is_rejected(self):
        ir = load("requirement_ir.json")
        ir["entities"][0]["evidence"] = ["a phrase absent from the request"]
        result = validate_requirement_ir(ir)
        self.assertIn("ungrounded_evidence", {item.code for item in result.issues})

    def test_non_finite_and_boolean_numbers_are_rejected_at_ir_boundary(self):
        ir = load("requirement_ir.json")
        ir["clock"]["frequency_hz"] = float("nan")
        ir["parameters"][0]["value"] = True
        result = validate_requirement_ir(ir)
        codes = {item.code for item in result.issues}
        self.assertIn("invalid_clock_value", codes)
        self.assertIn("invalid_numeric_value", codes)

    def test_incomplete_records_are_rejected_before_planning(self):
        ir = load("requirement_ir.json")
        del ir["joints"][0]["axis"]
        del ir["interfaces"][0]["state_id"]
        result = validate_requirement_ir(ir)
        self.assertGreaterEqual(
            sum(item.code == "missing_required_field" for item in result.issues), 2
        )

    def test_invalid_property_interval_is_rejected_before_execution(self):
        ir = load("requirement_ir.json")
        ir["properties"][0]["start"] = 0.8
        ir["properties"][0]["end"] = 0.2
        result = validate_requirement_ir(ir)
        self.assertIn(
            "invalid_property_interval", {item.code for item in result.issues}
        )


class UnitTests(unittest.TestCase):
    def test_radians_convert_to_degrees(self):
        result = conversion("rad", "deg")
        self.assertAlmostEqual(180.0, result.apply(math.pi))

    def test_incompatible_dimensions_are_rejected(self):
        with self.assertRaises(UnitError):
            conversion("rad", "m")


class HybridContractTests(unittest.TestCase):
    def validate(self, contract=None, ir=None, fmu=None, openusd=None):
        return HybridContractValidator().validate_metadata(
            contract or load("contract.json"),
            ir or load("requirement_ir.json"),
            fmu or fmu_metadata(),
            openusd or openusd_metadata(),
        )

    def test_oracle_contract_resolves_real_conversion(self):
        result = self.validate()
        self.assertTrue(result.success, result.to_dict())
        self.assertEqual(1, len(result.resolved_mappings))
        self.assertAlmostEqual(180.0 / math.pi, result.resolved_mappings[0]["scale"])
        self.assertEqual("shoulder", result.resolved_mappings[0]["semantic_joint_id"])
        self.assertEqual("base", result.resolved_mappings[0]["semantic_parent_entity_id"])

    def test_dangerous_contract_mutations_are_detected(self):
        mutations = []

        wrong_unit = load("contract.json")
        wrong_unit["mappings"][0]["source_unit"] = "m"
        mutations.append(("wrong unit", wrong_unit, fmu_metadata(), {"fmu_unit_mismatch", "unit_mismatch"}))

        wrong_path = load("contract.json")
        wrong_path["mappings"][0]["usd_joint_path"] = "/World/Missing"
        mutations.append(("wrong path", wrong_path, fmu_metadata(), {"missing_usd_joint"}))

        wrong_causality_fmu = fmu_metadata()
        wrong_causality_fmu["variables"][0] = FMUVariable(
            "jointAngle", 10, "real", "input", "continuous", unit="rad"
        )
        mutations.append(("wrong causality", load("contract.json"), wrong_causality_fmu,
                          {"causality_mismatch"}))

        duplicate_owner = load("contract.json")
        duplicate_owner["state_ownership"].append(deepcopy(
            duplicate_owner["state_ownership"][0]
        ))
        mutations.append(("duplicate ownership", duplicate_owner, fmu_metadata(),
                          {"duplicate_state_owner"}))

        wrong_mapping_owner = load("contract.json")
        wrong_mapping_owner["mappings"][0]["owner"] = "usd_physics"
        mutations.append(("mapping owner", wrong_mapping_owner, fmu_metadata(),
                          {"mapping_owner_mismatch"}))

        bad_clock = load("contract.json")
        bad_clock["clock"]["step_size"] = 0.015
        mutations.append(("clock mismatch", bad_clock, fmu_metadata(),
                          {"incommensurate_clock"}))

        bad_tolerance = load("contract.json")
        bad_tolerance["mappings"][0]["numeric_tolerance"] = 0
        mutations.append(("numeric tolerance", bad_tolerance, fmu_metadata(),
                          {"invalid_numeric_tolerance"}))

        missing_initial = load("contract.json")
        del missing_initial["mappings"][0]["initial_value"]
        mutations.append(("missing initial", missing_initial, fmu_metadata(),
                          {"invalid_initial_value"}))

        effort_playback = load("contract.json")
        effort_playback["mappings"][0]["usd_quantity"] = "joint_effort"
        mutations.append(("portable effort", effort_playback, fmu_metadata(),
                          {"invalid_portable_quantity"}))

        for name, contract, fmu, expected in mutations:
            with self.subTest(name=name):
                result = self.validate(contract=contract, fmu=fmu)
                codes = {item.code for item in result.issues}
                self.assertFalse(result.success)
                self.assertTrue(expected.issubset(codes), codes)

    def test_cross_profile_mass_and_limit_mismatch_are_detected(self):
        openusd = deepcopy(openusd_metadata())
        openusd["evidence"]["rigid_body_details"][0]["mass"] = 3.0
        openusd["evidence"]["joint_details"][0]["upper_limit"] = 120.0
        result = self.validate(openusd=openusd)
        codes = {item.code for item in result.issues}
        self.assertIn("body_mass_mismatch", codes)
        self.assertIn("joint_limit_mismatch", codes)

    def test_joint_limit_comparison_uses_declared_mapping_tolerance(self):
        within = deepcopy(openusd_metadata())
        within["evidence"]["joint_details"][0]["upper_limit"] = 90.000005
        self.assertTrue(self.validate(openusd=within).success)

        outside = deepcopy(openusd_metadata())
        outside["evidence"]["joint_details"][0]["upper_limit"] = 90.00002
        result = self.validate(openusd=outside)
        self.assertIn("joint_limit_mismatch", {item.code for item in result.issues})

    def test_non_finite_contract_values_return_diagnostics_instead_of_crashing(self):
        contract = load("contract.json")
        contract["clock"]["step_size"] = float("nan")
        contract["mappings"][0]["numeric_tolerance"] = float("inf")
        result = self.validate(contract=contract)
        codes = {item.code for item in result.issues}
        self.assertIn("non_finite_clock", codes)
        self.assertIn("invalid_numeric_tolerance", codes)


if __name__ == "__main__":
    unittest.main()
