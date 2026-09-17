from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

from nl2robotics.contracts.hybrid_contract import ContractValidation
from nl2robotics.hybrid.playback import OpenUSDPlaybackRunner
from nl2robotics.hybrid.portable import PortableHybridPipeline
from nl2robotics.hybrid.trace import write_synchronized_trace
from nl2robotics.modelica.models import FMUExecution, ModelicaFMU


MAPPING = {
    "id": "angle",
    "fmu_variable": "jointAngle",
    "usd_driven_prim": "/World/Link",
    "usd_quantity": "joint_position",
    "joint_type": "revolute",
    "target_unit": "deg",
    "axis": "Y",
    "scale": 57.29577951308232,
    "offset": 0.0,
    "lower_limit": -90.0,
    "upper_limit": 90.0,
    "numeric_tolerance": 0.00001,
    "initial_value": 0.0,
}


class TraceTests(unittest.TestCase):
    def test_synchronized_trace_contains_converted_usd_signal(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source.csv"
            destination = root / "hybrid.csv"
            source.write_text(
                "time,jointAngle\n0,0\n1,1.5707963267948966\n",
                encoding="utf-8",
            )
            report = write_synchronized_trace(source, [MAPPING], destination)
            text = destination.read_text(encoding="utf-8")
        self.assertTrue(report["success"])
        self.assertIn("usd:World.Link:joint_position[deg]", text)
        self.assertIn("90.0", text)


class PlaybackTests(unittest.TestCase):
    def test_missing_source_is_structured_failure(self):
        result = OpenUSDPlaybackRunner().run(
            Path("missing.usda"), Path("missing.csv"),
            mappings=[MAPPING], clock={}, output_dir=Path("unused"),
        )
        self.assertFalse(result["success"])
        self.assertEqual("missing_stage", result["issues"][0]["code"])


class PortablePipelineTests(unittest.TestCase):
    def test_orchestration_requires_every_stage_and_property(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source_usd = root / "source.usda"
            source_usd.write_text("#usda 1.0\n", encoding="utf-8")
            fmu_path = root / "candidate.fmu"
            fmu_path.write_bytes(b"fmu")
            trace_path = root / "trace.csv"
            trace_path.write_text("time,jointAngle\n0,0\n1,1\n", encoding="utf-8")

            modelica_runner = type("ModelicaRunner", (), {})()
            modelica_runner.export_fmu = lambda *args, **kwargs: ModelicaFMU(
                True, "Plant", checked=True, exported=True,
                fmu_path=fmu_path, fmi_version="2.0",
                interface_type="co_simulation",
            )
            contract_validator = type("ContractValidator", (), {})()
            contract_validator.validate = lambda *args, **kwargs: ContractValidation(
                "RHY001", resolved_mappings=[MAPPING]
            )
            fmi_runner = type("FMIRunner", (), {})()
            fmi_runner.run = lambda *args, **kwargs: FMUExecution(
                True, initialized=True, simulated=True,
                result_file=trace_path, sample_count=2,
            )

            class PlaybackRunner:
                def run(self, *args, **kwargs):
                    animated = kwargs["output_dir"] / "animated.usda"
                    animated.parent.mkdir(parents=True, exist_ok=True)
                    animated.write_text("#usda 1.0\n", encoding="utf-8")
                    return {"success": True, "animated_stage": str(animated)}

            pipeline = PortableHybridPipeline(
                modelica_runner=modelica_runner,
                fmi_runner=fmi_runner,
                contract_validator=contract_validator,
                playback_runner=PlaybackRunner(),
            )
            report = pipeline.run(
                "model Plant end Plant;",
                source_usd,
                {"properties": [{
                    "id": "p", "kind": "final", "signal": "jointAngle",
                    "lower": 0.9, "upper": 1.1,
                }]},
                {
                    "task_id": "RHY001",
                    "execution_mode": "portable_fmu_kinematic",
                    "clock": {
                        "start_time": 0, "stop_time": 1,
                        "step_size": 1, "time_codes_per_second": 1,
                    },
                },
                output_dir=root / "run",
            )
        self.assertTrue(report["passed"])
        self.assertTrue(report["properties"][0]["passed"])
        self.assertIn("animated_usd_sha256", report["artifacts"])

    def test_initial_value_mismatch_stops_before_playback(self):
        trace = {"time": [0.0, 1.0], "jointAngle": [0.2, 0.3]}
        from nl2robotics.hybrid.portable import _validate_initial_values

        result = _validate_initial_values(trace, [MAPPING])
        self.assertFalse(result["success"])
        self.assertGreater(result["mappings"][0]["error_target_units"], 10.0)


if __name__ == "__main__":
    unittest.main()
