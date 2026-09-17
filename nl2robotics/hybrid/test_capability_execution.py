from __future__ import annotations

import csv
from pathlib import Path
import tempfile
import unittest
from zipfile import ZipFile

from nl2robotics.hybrid.capability_execution import CapabilityExecutionPipeline
from nl2robotics.modelica.models import FMUExecution, ModelicaFMU


MODEL_DESCRIPTION = """<?xml version="1.0" encoding="UTF-8"?>
<fmiModelDescription fmiVersion="2.0" modelName="Behavior" guid="g">
  <CoSimulation modelIdentifier="Behavior"/>
  <ModelVariables>
    <ScalarVariable name="trace_position" valueReference="1" causality="output">
      <Real unit="m"/>
    </ScalarVariable>
    <ScalarVariable name="fact_mass" valueReference="2" causality="parameter" variability="fixed" initial="exact">
      <Real unit="kg" start="2.0"/>
    </ScalarVariable>
  </ModelVariables>
</fmiModelDescription>
"""


class Exporter:
    def export_fmu(self, modelica, *, output_dir):
        output_dir.mkdir(parents=True, exist_ok=True)
        path = output_dir / "Behavior.fmu"
        with ZipFile(path, "w") as archive:
            archive.writestr("modelDescription.xml", MODEL_DESCRIPTION)
        return ModelicaFMU(
            available=True, model_name="Behavior", checked=True,
            exported=True, fmu_path=path, fmi_version="2.0",
            interface_type="co_simulation", model_identifier="Behavior",
        )


class Executor:
    image = "test-fmi"

    def run(self, fmu_path, *, start_time, stop_time, step_size, outputs,
            output_dir):
        output_dir.mkdir(parents=True, exist_ok=True)
        trace = output_dir / "trace.csv"
        with trace.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=["time", "trace_position"])
            writer.writeheader()
            for index in range(11):
                writer.writerow({
                    "time": index * 0.1,
                    "trace_position": min(1.0, index * 0.1),
                })
        return FMUExecution(
            available=True, initialized=True, simulated=True,
            result_file=trace, columns=["time", "trace_position"],
            sample_count=11,
        )


def contract() -> dict:
    return {
        "contract_kind": "capability_execution",
        "clock": {"duration": 1.0, "frequency_hz": 10.0},
        "mappings": [{
            "id": "map_position", "interface_id": "position",
            "fmu_variable": "trace_position", "required": True,
        }],
    }


def requirement_ir() -> dict:
    return {
        "task_id": "CAPEXEC001",
        "properties": [{
            "id": "reaches_target", "kind": "eventually",
            "interface_id": "position", "lower": 0.9,
        }],
    }


class CapabilityExecutionTests(unittest.TestCase):
    def test_real_trace_is_required_and_behavior_is_evaluated(self):
        with tempfile.TemporaryDirectory() as tmp:
            report = CapabilityExecutionPipeline(
                modelica_runner=Exporter(), fmi_runner=Executor()
            ).run(
                "model Behavior end Behavior;", requirement_ir(), contract(),
                output_dir=Path(tmp),
            )
        self.assertTrue(report["execution_completed"], report)
        self.assertTrue(report["trace_gate"]["finite"])
        self.assertTrue(report["behavior_passed"])
        self.assertTrue(report["passed"])
        self.assertEqual("satisfied", report["properties"][0]["status"])
        self.assertFalse(report["claim_eligible_newton_h2"])

    def test_missing_required_fmu_channel_fails_before_execution(self):
        broken = contract()
        broken["mappings"][0]["fmu_variable"] = "trace_missing"
        with tempfile.TemporaryDirectory() as tmp:
            report = CapabilityExecutionPipeline(
                modelica_runner=Exporter(), fmi_runner=Executor()
            ).run(
                "model Behavior end Behavior;", requirement_ir(), broken,
                output_dir=Path(tmp),
            )
        self.assertFalse(report["execution_completed"])
        self.assertEqual("fmu_interface", report["failure_stage"])
        self.assertEqual("missing_fmu_output", report["contract"]["issues"][0]["code"])

    def test_one_shot_baseline_executes_without_internal_trace_abi(self):
        undisclosed = contract()
        undisclosed["mappings"][0]["fmu_variable"] = "trace_internal_name"
        with tempfile.TemporaryDirectory() as tmp:
            report = CapabilityExecutionPipeline(
                modelica_runner=Exporter(), fmi_runner=Executor()
            ).run_compiler_execution_baseline(
                "model Behavior end Behavior;", requirement_ir(), undisclosed,
                output_dir=Path(tmp),
            )
        self.assertTrue(report["passed"], report)
        self.assertTrue(report["execution_completed"])
        self.assertTrue(report["trace_gate"]["success"])
        self.assertTrue(report["contract"]["not_applicable"])
        self.assertIsNone(report["contract"]["success"])
        self.assertFalse(report["behavior_evaluated"])
        self.assertEqual([], report["properties"])

    def test_qualitative_property_is_never_silently_passed(self):
        ir = requirement_ir()
        ir["properties"] = [{"id": "looks_good", "kind": "custom"}]
        with tempfile.TemporaryDirectory() as tmp:
            report = CapabilityExecutionPipeline(
                modelica_runner=Exporter(), fmi_runner=Executor()
            ).run(
                "model Behavior end Behavior;", ir, contract(),
                output_dir=Path(tmp),
            )
        self.assertTrue(report["execution_completed"])
        self.assertFalse(report["behavior_passed"])
        self.assertEqual("unevaluable", report["properties"][0]["status"])

    def test_state_linked_property_resolves_to_trace_mapping(self):
        ir = requirement_ir()
        ir["properties"][0].pop("interface_id")
        ir["properties"][0]["state_id"] = "position_state"
        mapped = contract()
        mapped["mappings"][0]["state_id"] = "position_state"
        with tempfile.TemporaryDirectory() as tmp:
            report = CapabilityExecutionPipeline(
                modelica_runner=Exporter(), fmi_runner=Executor()
            ).run(
                "model Behavior end Behavior;", ir, mapped,
                output_dir=Path(tmp),
            )
        self.assertTrue(report["behavior_passed"], report)

    def test_grounded_parameter_is_checked_in_exported_fmu_metadata(self):
        mapped = contract()
        mapped["parameter_mappings"] = [{
            "id": "fact_body_mass", "fact_id": "entities.body.mass",
            "fmu_variable": "fact_mass", "expected_value": 2.0,
            "source_unit": "kg", "required": True,
        }]
        with tempfile.TemporaryDirectory() as tmp:
            report = CapabilityExecutionPipeline(
                modelica_runner=Exporter(), fmi_runner=Executor()
            ).run(
                "model Behavior end Behavior;", requirement_ir(), mapped,
                output_dir=Path(tmp),
            )
        self.assertTrue(report["contract"]["success"], report)
        self.assertEqual(
            "resolved_fmu_parameter",
            report["contract"]["resolved_parameter_mappings"][0]
            ["verification_status"],
        )

    def test_grounded_parameter_mismatch_fails_before_execution(self):
        mapped = contract()
        mapped["parameter_mappings"] = [{
            "id": "fact_body_mass", "fact_id": "entities.body.mass",
            "fmu_variable": "fact_mass", "expected_value": 3.0,
            "source_unit": "kg", "required": True,
        }]
        with tempfile.TemporaryDirectory() as tmp:
            report = CapabilityExecutionPipeline(
                modelica_runner=Exporter(), fmi_runner=Executor()
            ).run(
                "model Behavior end Behavior;", requirement_ir(), mapped,
                output_dir=Path(tmp),
            )
        self.assertEqual("fmu_interface", report["failure_stage"])
        self.assertEqual(
            "grounded_parameter_mismatch",
            report["contract"]["issues"][0]["code"],
        )


if __name__ == "__main__":
    unittest.main()
