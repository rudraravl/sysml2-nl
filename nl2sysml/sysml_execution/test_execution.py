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
from nl2sysml.sysml_execution.vector_planner import (  # noqa: E402
    candidates_for_input,
    candidates_for_trigger,
    input_types_for_target,
)

_DATA = _REPO_ROOT / "dataset" / "data"


def _load(sample: str) -> str:
    return (_DATA / sample / f"{sample}.sysml").read_text(encoding="utf-8")


class TestExtraction000200(unittest.TestCase):
    def test_action_defs_and_pins(self):
        topo = extract_topology(_load("000200"))
        self.assertTrue(any(d.name == "Provide Power" for d in topo.action_defs))
        provide = next(d for d in topo.action_defs if d.name == "Provide Power")
        self.assertIn("fuelCmd", provide.inputs)
        self.assertEqual(provide.input_types["fuelCmd"], "FuelCmd")

    def test_attribute_defs_are_payload_types(self):
        topo = extract_topology(_load("000200"))
        self.assertIn("FuelCmd", [item.name for item in topo.attribute_defs])

    def test_accept_actions(self):
        topo = extract_topology(_load("000200"))
        self.assertTrue(any(a.action_name == "engineStarted" for a in topo.accept_actions))
        self.assertTrue(any(a.signal_type == "EngineStart" for a in topo.accept_actions))

    def test_required_triggers_for_target_000200(self):
        topo = extract_topology(_load("000200"))
        triggers = topo.required_triggers_for_target()
        self.assertEqual([t.payload_type for t in triggers], ["EngineStart", "EngineOff"])
        self.assertEqual([t.param for t in triggers], ["engineStart", "engineOff"])
        self.assertIsNone(triggers[0].port)
        self.assertIsNone(triggers[1].port)

    def test_composite_usage(self):
        topo = extract_topology(_load("000200"))
        primary = topo.primary_composite_usage()
        self.assertIsNotNone(primary)
        self.assertEqual(primary.name, "provide power")
        self.assertTrue(primary.is_composite)
        self.assertEqual(primary.input_types["fuelCmd"], "FuelCmd")

    def test_kind_behavioral(self):
        topo = extract_topology(_load("000200"))
        self.assertEqual(classify_kind(topo), "behavioral")


class TestRequiredTriggersExtraction(unittest.TestCase):
    def test_nested_bare_accept_with_via(self):
        code = """
package P {
    package Usages {
        action run : Run {
            in x : Integer;
            then action stepA { accept evt : EvA; }
            then action stepB { accept evt : EvB via myPort; }
        }
    }
}
"""
        topo = extract_topology(code)
        triggers = topo.required_triggers_for_target()
        self.assertEqual([t.payload_type for t in triggers], ["EvA", "EvB"])
        self.assertEqual(triggers[0].param, "evt")
        self.assertIsNone(triggers[0].port)
        self.assertEqual(triggers[1].param, "evt")
        self.assertEqual(triggers[1].port, "myPort")

    def test_type_only_accept(self):
        code = """
package P {
    package Usages {
        action run : Run {
            accept DoneSignal;
        }
    }
}
"""
        topo = extract_topology(code)
        triggers = topo.required_triggers_for_target()
        self.assertEqual(len(triggers), 1)
        self.assertEqual(triggers[0].payload_type, "DoneSignal")
        self.assertIsNone(triggers[0].param)
        self.assertIsNone(triggers[0].port)


class TestHarness000200(unittest.TestCase):
    def test_harness_uses_pin_binding_pattern(self):
        topo = extract_topology(_load("000200"))
        req = ExecutionRequest(candidate_sysml="", simulation_vectors={"fuelCmd": 1})
        harness = build_harness_block(topo, req)
        self.assertIn("in fuelCmd = 1", harness)
        self.assertIn("'Provide Power'", harness)
        self.assertNotIn("perform action", harness)
        self.assertNotIn("assign fuelCmd", harness)

    def test_harness_generates_typed_payload_without_vectors(self):
        topo = extract_topology(_load("000200"))
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=""))
        self.assertIn("attribute testFuelCmd : FuelCmd;", harness)
        self.assertIn("in fuelCmd = testFuelCmd;", harness)
        self.assertNotIn("in fuelCmd = 1", harness)

    def test_harness_generates_trigger_payloads_000200(self):
        topo = extract_topology(_load("000200"))
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=""))
        self.assertIn("attribute testEngineStart : EngineStart;", harness)
        self.assertIn("attribute testEngineOff : EngineOff;", harness)

    def test_harness_generates_send_actions_000200(self):
        topo = extract_topology(_load("000200"))
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=""))
        self.assertIn("send testEngineStart to provide_powerProbe", harness)
        self.assertIn("send testEngineOff to provide_powerProbe", harness)

    def test_harness_generates_send_not_todo_for_accept(self):
        topo = extract_topology(_load("000200"))
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=""))
        self.assertNotIn("TODO(human): kernel cannot send/trigger engineStart", harness)
        self.assertIn("action triggerEngineStart send testEngineStart", harness)

    def test_harness_via_port_send(self):
        code = """
package P {
    package Definitions {
        attribute def EvA;
        attribute def EvB;
    }
    package Usages {
        action run : Run {
            in x : Integer;
            then action stepA { accept evt : EvA; }
            then action stepB { accept evt : EvB via myPort; }
        }
    }
}
"""
        topo = extract_topology(code)
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=code))
        self.assertIn("send testEvt to runProbe", harness)
        self.assertIn("send testEvt1 via myPort to runProbe", harness)

    def test_harness_sequences_probe_000200(self):
        topo = extract_topology(_load("000200"))
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=""))
        self.assertIn("first provide_powerProbe;", harness)

    def test_harness_sequences_triggers_000200(self):
        topo = extract_topology(_load("000200"))
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=""))
        self.assertIn("first triggerEngineStart then triggerEngineOff;", harness)


class TestHarnessSequencer(unittest.TestCase):
    def test_single_trigger_succession(self):
        code = """
package P {
    package Definitions {
        attribute def DoneSignal;
    }
    package Usages {
        action run : Run {
            accept done : DoneSignal;
        }
    }
}
"""
        topo = extract_topology(code)
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=code))
        self.assertIn("first runProbe;", harness)
        self.assertIn("first triggerDoneSignal;", harness)
        self.assertNotIn(" then ", harness.split("first triggerDoneSignal;")[0])

    def test_three_trigger_succession_chain(self):
        code = """
package P {
    package Definitions {
        attribute def SigA;
        attribute def SigB;
        attribute def SigC;
    }
    package Usages {
        action run : Run {
            accept a : SigA;
            accept b : SigB;
            accept c : SigC;
        }
    }
}
"""
        topo = extract_topology(code)
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=code))
        self.assertIn(
            "first triggerSigA then triggerSigB then triggerSigC;",
            harness,
        )


class TestVectorPlanning(unittest.TestCase):
    def test_resolves_fuel_cmd_type(self):
        topo = extract_topology(_load("000200"))
        self.assertEqual(input_types_for_target(topo), {"fuelCmd": "FuelCmd"})

    def test_builds_nominal_payload_fixture(self):
        topo = extract_topology(_load("000200"))
        candidates = candidates_for_input(topo, "fuelCmd", "FuelCmd")
        self.assertEqual(candidates[0].expression, "testFuelCmd")
        self.assertEqual(
            candidates[0].declarations,
            ("attribute testFuelCmd : FuelCmd;",),
        )

    def test_candidates_for_trigger_disambiguates_duplicate_params(self):
        topo = extract_topology(_load("000200"))
        triggers = topo.required_triggers_for_target()
        seen: set[str] = set()
        first = candidates_for_trigger(topo, triggers[0], 0, seen)
        second = candidates_for_trigger(topo, triggers[1], 1, seen)
        self.assertEqual(first[0].expression, "testEngineStart")
        self.assertEqual(second[0].expression, "testEngineOff")

        code = """
package P {
    package Definitions {
        attribute def EvA;
        attribute def EvB;
    }
    package Usages {
        action run : Run {
            accept evt : EvA;
            accept evt : EvB;
        }
    }
}
"""
        topo = extract_topology(code)
        triggers = topo.required_triggers_for_target()
        seen = set()
        self.assertEqual(
            candidates_for_trigger(topo, triggers[0], 0, seen)[0].expression,
            "testEvt",
        )
        self.assertEqual(
            candidates_for_trigger(topo, triggers[1], 1, seen)[0].expression,
            "testEvt1",
        )

    def test_builds_small_primitive_boundary_set(self):
        topo = extract_topology(_load("000200"))
        candidates = candidates_for_input(topo, "level", "Integer")
        self.assertEqual([item.expression for item in candidates], ["0", "1", "-1"])

    def test_harness_uses_first_primitive_boundary(self):
        code = """
package PrimitiveInput {
    action def Probe { in level: Integer; }
}
"""
        topo = extract_topology(code)
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=code))
        self.assertIn("in level = 0;", harness)

    def test_harness_marks_unknown_type_unsupported(self):
        code = """
package UnknownInput {
    action def Probe { in value: MissingType; }
}
"""
        topo = extract_topology(code)
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=code))
        self.assertIn("unsupported input type for value: MissingType", harness)


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


class TestKernelTraceCapture(unittest.TestCase):
    def test_extracts_json_execute_result(self):
        from nl2sysml.sysml_execution.sysml_runtime_bridge import _trace_entries_from_content

        entries = _trace_entries_from_content(
            {"data": {"application/json": {"event": "EngineStart", "step": 1}}}
        )
        self.assertEqual(len(entries), 1)
        self.assertIn("EngineStart", entries[0])

    def test_orchestrator_uses_kernel_trace(self):
        from nl2sysml.sysml_execution.models import KernelExecutionOutput
        from nl2sysml.sysml_execution.orchestrator import _kernel_trace_lines

        kernel_out = KernelExecutionOutput(
            trace=['{"discrete": ["probe", "trigger"]}', "line two"],
            stdout=["ignored when trace present"],
        )
        self.assertEqual(
            _kernel_trace_lines(kernel_out),
            ['{"discrete": ["probe", "trigger"]}', "line two"],
        )

    def test_writes_trace_file(self):
        from tempfile import TemporaryDirectory

        from nl2sysml.sysml_execution.orchestrator import write_execution_trace_file

        with TemporaryDirectory() as tmp:
            path = write_execution_trace_file(
                f"{tmp}/trace.txt",
                ["step one", '{"event": "start"}'],
                errors=["ERROR: example"],
            )
            text = Path(path).read_text(encoding="utf-8")
            self.assertIn("step one", text)
            self.assertIn('"event": "start"', text)
            self.assertIn("# errors", text)
            self.assertIn("ERROR: example", text)


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

    def test_compiles_with_generated_payload_when_kernel_available(self):
        result = run_sysml_execution(
            ExecutionRequest(candidate_sysml=_load("000200"))
        )
        if not result.kernel_available:
            self.skipTest("SysML kernel not installed")
        self.assertTrue(result.compiled, msg=f"errors: {result.errors}")
        self.assertIn("attribute testFuelCmd : FuelCmd;", result.harness)
        self.assertIn("in fuelCmd = testFuelCmd;", result.harness)
        self.assertIsInstance(result.trace, list)


if __name__ == "__main__":
    unittest.main()
