"""Tests for rigorous SysML execution harness (extraction + harness; kernel optional)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import patch

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from nl2sysml.sysml_execution.extractor import (  # noqa: E402
    classify_topology,
    extract_topology,
    requires_layer2,
)
from nl2sysml.sysml_execution.harness_builder import build_harness_block  # noqa: E402
from nl2sysml.sysml_execution.models import (  # noqa: E402
    ExecutionRequest,
    KernelExecutionOutput,
    Layer2Status,
    ModelProfile,
)
from nl2sysml.sysml_execution.orchestrator import run_sysml_execution  # noqa: E402
from nl2sysml.sysml_execution.vector_fallback import (  # noqa: E402
    build_preset_vector_attempts,
    required_action_inputs,
)

_DATA = _REPO_ROOT / "dataset" / "data"


def _load(sample: str) -> str:
    return (_DATA / sample / f"{sample}.sysml").read_text(encoding="utf-8")


class TestExtraction000200(unittest.TestCase):
    def test_action_names_quoted(self):
        topo = extract_topology(_load("000200"))
        self.assertIn("provide power", topo.actions)
        self.assertTrue(any(d.name == "Provide Power" for d in topo.action_defs))
        self.assertTrue(any(d.name == "Generate Torque" for d in topo.action_defs))

    def test_attribute_defs_not_def(self):
        topo = extract_topology(_load("000200"))
        names = {a.name for a in topo.attribute_defs}
        self.assertIn("FuelCmd", names)
        self.assertIn("EngineStart", names)
        self.assertNotIn("def", names)

    def test_accept_actions(self):
        topo = extract_topology(_load("000200"))
        self.assertTrue(any(a.action_name == "engineStarted" for a in topo.accept_actions))
        self.assertTrue(any(a.signal_type == "EngineStart" for a in topo.accept_actions))

    def test_composite_usage(self):
        topo = extract_topology(_load("000200"))
        primary = topo.primary_composite_usage()
        self.assertIsNotNone(primary)
        self.assertEqual(primary.name, "provide power")
        self.assertTrue(primary.is_composite)

    def test_profile_action_composite(self):
        topo = extract_topology(_load("000200"))
        self.assertEqual(classify_topology(topo), ModelProfile.ACTION_COMPOSITE)
        self.assertTrue(requires_layer2(topo, ModelProfile.ACTION_COMPOSITE))


class TestHarness000200(unittest.TestCase):
    def test_harness_has_sentinel_action_probe(self):
        topo = extract_topology(_load("000200"))
        result = build_harness_block(topo, ExecutionRequest(candidate_sysml=""))
        self.assertIn("SentinelActionProbe", result.harness_block)
        self.assertIn("perform action", result.harness_block)
        self.assertIn("'provide power'", result.harness_block)
        self.assertNotIn("bind run = run", result.harness_block)
        self.assertEqual(result.metadata.profile, ModelProfile.ACTION_COMPOSITE)

    def test_harness_not_runnable_without_vectors(self):
        topo = extract_topology(_load("000200"))
        result = build_harness_block(topo, ExecutionRequest(candidate_sysml=""))
        self.assertFalse(result.metadata.probes_runnable)
        self.assertTrue(any("simulation_vectors" in r for r in result.metadata.skipped_reasons))

    def test_harness_runnable_with_vectors(self):
        topo = extract_topology(_load("000200"))
        req = ExecutionRequest(
            candidate_sysml="",
            simulation_vectors={"fuelCmd": 1},
        )
        result = build_harness_block(topo, req)
        self.assertTrue(result.metadata.probes_runnable)
        self.assertIn("perform action", result.harness_block)
        self.assertIn("assign fuelCmd", result.harness_block)

    def test_harness_requires_every_input_vector(self):
        code = """
package MultiInput {
    action def Probe { in firstInput: Integer; in secondInput: Integer; }
    action run: Probe {
        in firstInput: Integer;
        in secondInput: Integer;
        action child: Probe;
    }
}
"""
        topo = extract_topology(code)
        result = build_harness_block(
            topo,
            ExecutionRequest(candidate_sysml="", simulation_vectors={"firstInput": 1}),
        )
        self.assertFalse(result.metadata.probes_runnable)
        self.assertEqual(result.metadata.missing_inputs, ["secondInput"])


class TestPresetVectorFallback(unittest.TestCase):
    def test_builds_attempts_for_000200_fuel_cmd(self):
        topology = extract_topology(_load("000200"))
        required = required_action_inputs(topology)
        attempts = build_preset_vector_attempts(required, preset_values=[0, 1])
        self.assertEqual(required, ["fuelCmd"])
        self.assertEqual(attempts, [{"fuelCmd": 0}, {"fuelCmd": 1}])

    @patch("nl2sysml.sysml_execution.orchestrator.execute_sysml_candidate")
    def test_stops_on_first_kernel_accepted_preset(self, execute_mock):
        rejected = KernelExecutionOutput(
            execution_status_payload="ERROR: rejected",
            stderr_lines=["ERROR: rejected"],
            error_lines=["ERROR: rejected"],
        )
        accepted = KernelExecutionOutput(
            execution_status_payload="accepted",
            shell_reply={"content": {"status": "ok"}},
        )
        execute_mock.side_effect = [rejected, accepted]

        result = run_sysml_execution(
            ExecutionRequest(
                candidate_sysml=_load("000200"),
                try_preset_vectors=True,
                preset_values=[0, 1, -1],
            )
        )

        self.assertEqual(execute_mock.call_count, 2)
        self.assertEqual(result.selected_simulation_vectors, {"fuelCmd": 1})
        self.assertEqual(result.vector_source, "preset_fallback")
        self.assertEqual(result.semantic_validity, "unknown")
        self.assertEqual(len(result.vector_attempts), 2)
        self.assertFalse(result.vector_attempts[0]["kernel_accepted"])
        self.assertTrue(result.vector_attempts[1]["kernel_accepted"])


class TestExtraction000600(unittest.TestCase):
    def test_part_state_profile(self):
        topo = extract_topology(_load("000600"))
        self.assertEqual(classify_topology(topo), ModelProfile.PART_STATE)
        self.assertIsNotNone(topo.primary_part_def())

    def test_harness_has_part_subject(self):
        topo = extract_topology(_load("000600"))
        result = build_harness_block(topo, ExecutionRequest(candidate_sysml=""))
        self.assertIn("sentinelTestSubject", result.harness_block)


class TestExtraction000001(unittest.TestCase):
    def test_analysis_tool_profile(self):
        topo = extract_topology(_load("000001"))
        self.assertEqual(classify_topology(topo), ModelProfile.ANALYSIS_TOOL)

    def test_layer2_not_required_on_run(self):
        result = run_sysml_execution(ExecutionRequest(candidate_sysml=_load("000001")))
        self.assertEqual(result.layer2_status, Layer2Status.NOT_REQUIRED.value)


class TestFailClosed000200(unittest.TestCase):
    def test_no_false_success_without_vectors(self):
        result = run_sysml_execution(ExecutionRequest(candidate_sysml=_load("000200")))
        if result.layer2_status == Layer2Status.KERNEL_UNAVAILABLE.value:
            self.skipTest("SysML kernel not installed")
        self.assertFalse(result.success)
        self.assertIn(
            result.layer2_status,
            (Layer2Status.BYPASSED.value, Layer2Status.VERIFIED.value),
        )
        if not result.behavior_ok:
            self.assertIsNotNone(result.diagnostic_pack)
            self.assertEqual(result.diagnostic_pack.get("error_type"), "layer2_bypassed")


class TestKernel000200(unittest.TestCase):
    """Run with: python -m unittest nl2sysml.sysml_execution.test_execution.TestKernel000200"""

    def test_success_with_vectors_when_kernel_available(self):
        result = run_sysml_execution(
            ExecutionRequest(
                candidate_sysml=_load("000200"),
                simulation_vectors={"fuelCmd": 1},
            )
        )
        if result.layer2_status == Layer2Status.KERNEL_UNAVAILABLE.value:
            self.skipTest("SysML kernel not installed")
        self.assertTrue(result.syntax_ok)
        if result.harness_metadata and result.harness_metadata.get("probes_runnable"):
            self.assertIn("SentinelActionProbe", result.harness_block)


if __name__ == "__main__":
    unittest.main()
