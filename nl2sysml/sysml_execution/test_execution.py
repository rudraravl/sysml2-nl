"""Tests for rigorous SysML execution harness (extraction + harness; kernel optional)."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
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
from nl2sysml.sysml_execution.corpus_runner import (  # noqa: E402
    _enrich_stored_payload,
    _redact_local_paths,
    run_corpus,
)
from nl2sysml.sysml_execution.models import (  # noqa: E402
    ExecutionRequest,
    KernelExecutionOutput,
    Layer2Status,
    ModelProfile,
)
from nl2sysml.sysml_execution.orchestrator import run_sysml_execution  # noqa: E402
from nl2sysml.sysml_execution.vector_fallback import (  # noqa: E402
    action_input_types,
    build_preset_vector_attempts,
    required_action_inputs,
    unsupported_preset_inputs,
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
        self.assertEqual(primary.inputs, ["fuelCmd"])

    def test_action_definition_pins_do_not_absorb_later_actions(self):
        topo = extract_topology(_load("000200"))
        generate = next(d for d in topo.action_defs if d.name == "Generate Torque")
        self.assertEqual(generate.inputs, ["fuelCmd"])
        self.assertEqual(generate.outputs, ["engineTorque"])

    def test_multiline_action_inputs(self):
        topo = extract_topology(_load("000002"))
        dynamics = next(d for d in topo.action_defs if d.name == "StraightLineVehicleDynamics")
        self.assertEqual(
            dynamics.inputs,
            ["dt", "whlpwr", "Cd", "Cf", "tm", "v_in", "x_in"],
        )
        dyn2 = next(u for u in topo.action_usages if u.name == "dyn2")
        self.assertEqual(dyn2.inputs, [])

    def test_fuel_cmd_type_is_extracted(self):
        topo = extract_topology(_load("000200"))
        self.assertEqual(action_input_types(topo, ["provide power"]), {"fuelCmd": "FuelCmd"})
        self.assertEqual(unsupported_preset_inputs(topo, ["provide power"]), [])

    def test_profile_action_composite(self):
        topo = extract_topology(_load("000200"))
        self.assertEqual(classify_topology(topo), ModelProfile.ACTION_COMPOSITE)
        self.assertTrue(requires_layer2(topo, ModelProfile.ACTION_COMPOSITE))

    def test_extracts_static_analysis_relationships(self):
        topo = extract_topology(_load("000004"))
        self.assertIn("FuelEconomyRequirement", topo.requirements)
        self.assertIn("Acceleration", topo.calc_defs)
        self.assertTrue(any("fuelInPort.fuel" in binding for binding in topo.bindings))
        self.assertTrue(any("a == Acceleration" in equation for equation in topo.equations))

    def test_extracts_states_and_transitions(self):
        topo = extract_topology(_load("000074"))
        self.assertIn("S1", topo.states)
        self.assertTrue(any(line.startswith("transition") for line in topo.transitions))


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
        self.assertIn("in fuelCmd = 1;", result.harness_block)

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

    def test_builds_type_aware_attempts(self):
        attempts = build_preset_vector_attempts(
            ["enabled", "name", "count"],
            preset_values=[0, 1, -1],
            input_types={
                "enabled": "Boolean",
                "name": "String",
                "count": "Natural",
            },
        )
        self.assertEqual(
            attempts,
            [
                {"enabled": False, "name": "", "count": 0},
                {"enabled": True, "name": "test", "count": 1},
                {"enabled": True, "name": "test", "count": 1},
            ],
        )

    def test_structured_inputs_are_not_given_scalar_presets(self):
        topology = extract_topology(_load("000082"))
        self.assertEqual(
            action_input_types(topology, ["cartBehavior"]),
            {"input": "CartInput"},
        )
        self.assertEqual(
            unsupported_preset_inputs(topology, ["cartBehavior"]),
            ["input"],
        )
        self.assertIn("StateSpaceRepresentation::*", topology.imports)
        self.assertEqual(
            unsupported_preset_inputs(topology, ["pusherBehavior"]),
            ["input"],
        )

    @patch("nl2sysml.sysml_execution.orchestrator.execute_sysml_candidate")
    def test_structured_inputs_skip_preset_loop(self, execute_mock):
        execute_mock.return_value = KernelExecutionOutput(
            execution_status_payload="accepted",
            shell_reply={"content": {"status": "ok"}},
        )

        result = run_sysml_execution(
            ExecutionRequest(candidate_sysml=_load("000082"), try_preset_vectors=True)
        )

        self.assertEqual(execute_mock.call_count, 1)
        self.assertEqual(result.vector_attempts, [])
        self.assertIsNone(result.selected_simulation_vectors)
        self.assertEqual(
            result.harness_metadata["coverage_status"],
            "inputs_detected_but_not_constructible",
        )

    def test_external_action_type_import_is_reproduced(self):
        topology = extract_topology(_load("000082"))
        result = build_harness_block(
            topology,
            ExecutionRequest(candidate_sysml="", target_behaviors=["cartBehavior"]),
        )
        self.assertIn(
            "private import StateSpaceRepresentation::*;",
            result.harness_block,
        )

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
        self.assertTrue(result.input_injected)
        self.assertFalse(result.behavior_observed)
        self.assertEqual(result.verification_level, "input_harness_compiled")
        self.assertEqual(
            result.diagnostic_pack["error_type"],
            "behavior_not_observed",
        )
        self.assertFalse(result.vector_attempts[0]["kernel_accepted"])
        self.assertTrue(result.vector_attempts[1]["kernel_accepted"])


class TestExtraction000600(unittest.TestCase):
    def test_part_state_profile(self):
        topo = extract_topology(_load("000600"))
        self.assertEqual(classify_topology(topo), ModelProfile.PART_STATE)
        self.assertIsNotNone(topo.primary_part_def())

    def test_nested_part_def_is_qualified(self):
        topo = extract_topology(_load("000003"))
        self.assertEqual(
            topo.qualified_part_def("Ideal Gas Parcel"),
            "'Turbojet Stage Analysis'::'Thermodynamics Structure'::'Ideal Gas Parcel'",
        )

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


class TestCorpusReporting(unittest.TestCase):
    def test_redacts_local_paths_recursively(self):
        redacted = _redact_local_paths(
            {
                "path": str(_REPO_ROOT / "dataset"),
                "nested": [str(Path.home() / "secret")],
            }
        )
        self.assertEqual(redacted["path"], "<REPO_ROOT>/dataset")
        self.assertEqual(redacted["nested"], ["<HOME>/secret"])

    def test_enriches_existing_payload_without_kernel_rerun(self):
        payload = {"summary": {}, "result": {}, "target_summaries": [], "target_results": []}
        _enrich_stored_payload(payload, _load("000004"))
        self.assertGreater(payload["summary"]["requirement_count"], 0)
        self.assertGreater(payload["summary"]["calc_def_count"], 0)
        self.assertGreater(payload["summary"]["equation_count"], 0)
        self.assertIn("requirements", payload["result"]["extracted_topology"])

    @patch("nl2sysml.sysml_execution.corpus_runner.run_sysml_execution")
    @patch("nl2sysml.sysml_execution.corpus_runner.compile_sysml_candidate")
    def test_writes_baseline_target_and_audit_outputs(self, compile_mock, run_mock):
        compile_mock.return_value = {"syntax_ok": True}
        run_mock.return_value = SimpleNamespace(
            to_dict=lambda: {
                "success": False,
                "syntax_ok": True,
                "harness_compile_ok": True,
                "input_injected": True,
                "behavior_observed": False,
                "verification_level": "input_harness_compiled",
                "behavior_ok": False,
                "layer2_status": "compiled_only",
                "kernel_timed_out": False,
                "harness_metadata": {
                    "profile": "action_composite",
                    "probes_runnable": True,
                    "required_inputs": ["fuelCmd"],
                    "coverage_status": "input_test_performed",
                },
                "vector_attempts": [{"simulation_vectors": {"fuelCmd": 0}}],
                "selected_simulation_vectors": {"fuelCmd": 0},
            }
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dataset = root / "dataset" / "000200"
            dataset.mkdir(parents=True)
            (dataset / "000200.sysml").write_text(_load("000200"), encoding="utf-8")
            output = root / "results"

            rows = run_corpus(root / "dataset", output)

            self.assertTrue(rows[0]["baseline_syntax_ok"])
            self.assertEqual(rows[0]["model_path"], "000200/000200.sysml")
            self.assertTrue((output / "summary.csv").exists())
            self.assertTrue((output / "targets.csv").exists())
            audit = __import__("json").loads((output / "audit.json").read_text())
            self.assertEqual(audit["models_with_input_injection"], 1)
            self.assertEqual(audit["models_with_behavior_observed"], 0)


if __name__ == "__main__":
    unittest.main()
