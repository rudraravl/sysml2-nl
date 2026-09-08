from __future__ import annotations

import json
import unittest

from nl2robotics.modelica.specification import evaluate_modelica_specification


def requirement_ir() -> dict:
    source = "A 2 kg robot shall keep position below 1 m at 10 Hz for 1 s."
    return {
        "task_id": "SPEC001", "source_text": source,
        "entities": [{
            "id": "robot", "kind": "robot", "mass": 2.0,
            "mass_unit": "kg", "evidence": ["2 kg robot"],
        }],
        "joints": [], "parameters": [], "dynamics": [],
        "controllers": [], "actuators": [], "sensors": [],
        "environment": [],
        "clock": {
            "duration": 1.0, "frequency_hz": 10.0,
            "evidence": ["10 Hz for 1 s"],
        },
        "interfaces": [{
            "id": "position", "state_id": "position",
            "quantity": "position", "direction": "modelica_output",
            "source_unit": "m", "required": True,
            "evidence": ["position below 1 m"],
        }],
        "properties": [{
            "id": "bounded_position", "kind": "always",
            "interface_id": "position", "upper": 1.0,
            "evidence": ["position below 1 m"],
        }],
    }


def contract() -> dict:
    return {
        "mappings": [{
            "interface_id": "position", "fmu_variable": "trace_position",
        }],
        "parameter_mappings": [{
            "fact_id": "entities.robot.mass", "fmu_variable": "fact_mass",
        }],
    }


def execution(property_status: str = "satisfied") -> dict:
    passed = property_status == "satisfied"
    return {
        "clock": {
            "start_time": 0.0, "stop_time": 1.0,
            "frequency_hz": 10.0,
        },
        "contract": {
            "resolved_mappings": [{"interface_id": "position"}],
            "resolved_parameter_mappings": [{
                "fact_id": "entities.robot.mass",
            }],
        },
        "properties": [{
            "id": "bounded_position", "status": property_status,
            "passed": passed,
        }],
    }


class ModelicaSpecificationTests(unittest.TestCase):
    def test_native_trace_and_contract_checks_are_fail_closed(self):
        report = evaluate_modelica_specification(
            requirement_ir(), "model Robot end Robot;", contract(),
            execution("violated"), ask=None,
        )
        self.assertFalse(report["passed"])
        self.assertGreater(report["summary"]["blocking_violations"], 0)
        self.assertGreater(report["summary"]["deterministic_violations"], 0)

    def test_semantic_unknown_is_reported_without_becoming_a_pass_claim(self):
        def ask(prompt: str) -> str:
            qid = prompt.split("- ", 1)[1].split(":", 1)[0]
            return json.dumps({"answers": [{
                "qid": qid, "status": "satisfied",
                "evidence": "fabricated code evidence", "confidence": 1.0,
            }]})

        report = evaluate_modelica_specification(
            requirement_ir(), "model Robot end Robot;", contract(),
            execution(), ask=ask,
        )
        self.assertTrue(report["passed"])
        self.assertFalse(report["claim_ready"])
        self.assertGreater(report["summary"]["counts"]["unknown"], 0)


if __name__ == "__main__":
    unittest.main()
