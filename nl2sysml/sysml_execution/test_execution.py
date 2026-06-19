"""Tests for SysML execution harness (extraction + harness; kernel optional)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from nl2sysml.sysml_execution.extractor import classify_kind, extract_topology  # noqa: E402
from nl2sysml.sysml_execution.harness_builder import build_harness_block  # noqa: E402
from nl2sysml.sysml_execution.models import ExecutionRequest  # noqa: E402
from nl2sysml.sysml_execution.orchestrator import run_sysml_execution  # noqa: E402

_DATA = _REPO_ROOT / "dataset" / "data"


def _load(sample: str) -> str:
    return (_DATA / sample / f"{sample}.sysml").read_text(encoding="utf-8")


class TestExtraction000200(unittest.TestCase):
    def test_action_defs_and_pins(self):
        topo = extract_topology(_load("000200"))
        self.assertTrue(any(d.name == "Provide Power" for d in topo.action_defs))
        provide = next(d for d in topo.action_defs if d.name == "Provide Power")
        self.assertIn("fuelCmd", provide.inputs)

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

    def test_kind_behavioral(self):
        topo = extract_topology(_load("000200"))
        self.assertEqual(classify_kind(topo), "behavioral")


class TestHarness000200(unittest.TestCase):
    def test_harness_uses_pin_binding_pattern(self):
        topo = extract_topology(_load("000200"))
        req = ExecutionRequest(candidate_sysml="", simulation_vectors={"fuelCmd": 1})
        harness = build_harness_block(topo, req)
        self.assertIn("in fuelCmd = 1", harness)
        self.assertIn("'Provide Power'", harness)
        self.assertNotIn("perform action", harness)
        self.assertNotIn("assign fuelCmd", harness)

    def test_harness_todo_for_missing_vectors(self):
        topo = extract_topology(_load("000200"))
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=""))
        self.assertIn("TODO(human): provide simulation value for in pin fuelCmd", harness)

    def test_harness_todo_for_accept(self):
        topo = extract_topology(_load("000200"))
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=""))
        self.assertIn("TODO(human): kernel cannot send/trigger engineStart", harness)


class TestExtraction000600(unittest.TestCase):
    def test_kind_behavioral_or_structural(self):
        topo = extract_topology(_load("000600"))
        kind = classify_kind(topo)
        self.assertIn(kind, ("behavioral", "structural"))

    def test_state_machines_extracted(self):
        topo = extract_topology(_load("000600"))
        self.assertTrue(any(sm.name == "SystemOperationalStates" for sm in topo.state_machines))

    def test_attributes_have_default_flag(self):
        topo = extract_topology(_load("000600"))
        probe_diameter = next(
            (a for a in topo.attributes if a.name == "probeDiameter"), None
        )
        self.assertIsNotNone(probe_diameter)
        self.assertTrue(probe_diameter.has_default)


class TestHarness000600(unittest.TestCase):
    def test_harness_has_part_or_state_todo(self):
        topo = extract_topology(_load("000600"))
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=""))
        self.assertTrue(
            "testSubject" in harness or "TODO(human)" in harness
        )


class TestKernel000200(unittest.TestCase):
    """Run with: python -m unittest nl2sysml.sysml_execution.test_execution.TestKernel000200"""

    def test_compiles_with_vectors_when_kernel_available(self):
        result = run_sysml_execution(
            ExecutionRequest(
                candidate_sysml=_load("000200"),
                simulation_vectors={"fuelCmd": 1},
            )
        )
        if not result.kernel_available:
            self.skipTest("SysML kernel not installed")
        self.assertTrue(result.compiled, msg=f"errors: {result.errors}")
        self.assertTrue(result.success)
        self.assertEqual(result.model_kind, "behavioral")
        self.assertIn("in fuelCmd = 1", result.harness)


if __name__ == "__main__":
    unittest.main()
