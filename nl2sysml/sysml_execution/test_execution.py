"""Tests for SysML execution harness (extraction + harness; kernel optional)."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from nl2sysml.sysml_execution.extractor import (  # noqa: E402
    classify_kind,
    extract_topology,
    ordered_transition_path,
)
from nl2sysml.sysml_execution.harness_builder import build_harness_block, build_harness_block_with_mocks  # noqa: E402
from nl2sysml.sysml_execution.models import ExecutionRequest, GuardCondition  # noqa: E402
from nl2sysml.sysml_execution.orchestrator import run_sysml_execution  # noqa: E402
from nl2sysml.sysml_execution.vector_planner import (  # noqa: E402
    candidates_for_input,
    candidates_for_trigger,
    classify_input_type,
    input_types_for_target,
    satisfying_value_for_guard,
    unsupported_reason_for_input,
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
        self.assertIn("send testEvt1 to runProbe", harness)
        self.assertNotIn("to runProbe.myPort", harness)
        self.assertNotIn("via myPort", harness)

    def test_harness_sequences_probe_000200(self):
        topo = extract_topology(_load("000200"))
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=""))
        self.assertIn("first provide_powerProbe;", harness)
        self.assertIn("then triggerEngineStart;", harness)
        self.assertIn("then triggerEngineOff;", harness)

    def test_harness_sequences_triggers_000200(self):
        topo = extract_topology(_load("000200"))
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=""))
        self.assertIn("first provide_powerProbe;", harness)
        self.assertIn("then triggerEngineStart;", harness)
        self.assertIn("then triggerEngineOff;", harness)
        self.assertNotRegex(harness, r"first provide_powerProbe;\s*\n\s*first ")


class TestHarness000134(unittest.TestCase):
    """000134 (Messaging Example) uses `part camera { action takePicture ... }` —
    the composite is nested inside a shorthand part *usage*, so the harness
    should alias `part testSubject = camera` and send to the whole component.
    """

    def _topo(self):
        return extract_topology(_load("000134"))

    def _harness(self):
        code = _load("000134")
        return build_harness_block(self._topo(), ExecutionRequest(candidate_sysml=code))

    # --- extractor coverage ---

    def test_shorthand_part_def_collected(self):
        topo = self._topo()
        self.assertIn("camera", topo.part_defs)
        self.assertNotIn("camera", topo.formal_part_defs)

    def test_composite_enclosing_part_def_set(self):
        topo = self._topo()
        composites = [u for u in topo.action_usages if u.is_composite]
        tp = next((u for u in composites if u.name == "takePicture"), None)
        self.assertIsNotNone(tp)
        self.assertEqual(tp.enclosing_part_def, "camera")

    def test_provide_power_has_no_enclosing_part_def(self):
        topo = extract_topology(_load("000200"))
        composites = [u for u in topo.action_usages if u.is_composite]
        pp = next((u for u in composites if "power" in u.name.lower()), None)
        self.assertIsNotNone(pp)
        self.assertIsNone(pp.enclosing_part_def)

    def test_part_hosted_target_returns_camera(self):
        topo = self._topo()
        result = topo.part_hosted_target()
        self.assertIsNotNone(result)
        part_def, composite = result
        self.assertEqual(part_def, "camera")
        self.assertEqual(composite.name, "takePicture")

    # --- harness shape ---

    def test_aliases_test_subject_to_instance(self):
        harness = self._harness()
        self.assertIn("part testSubject = camera", harness)
        self.assertNotIn("part testSubject : camera", harness)

    def test_sends_to_test_subject_component(self):
        harness = self._harness()
        self.assertIn("send testScene to testSubject", harness)
        self.assertNotIn("to testSubject.viewPort", harness)

    def test_sequences_trigger_only(self):
        harness = self._harness()
        self.assertIn("first triggerScene", harness)

    def test_no_action_probe_emitted(self):
        harness = self._harness()
        self.assertNotIn("takePictureProbe", harness)
        self.assertNotIn("TakePictureProbe", harness)

    def test_no_via_keyword_in_harness(self):
        harness = self._harness()
        self.assertNotIn("via viewPort", harness)

    def test_no_first_test_subject_in_succession(self):
        harness = self._harness()
        self.assertNotIn("first testSubject", harness)

    # --- part-hosted model with input pins ---

    _PART_HOSTED_WITH_PINS = """
package PartHostedPins {
    item def Cmd;
    attribute def StartSignal;
    part def Processor;
    part processor {
        action process : Processor {
            in item cmd : Cmd;
            action trigger accept sig : StartSignal via ioPort;
        }
    }
}
"""

    def test_part_hosted_with_pins_sends_to_component(self):
        code = self._PART_HOSTED_WITH_PINS
        topo = extract_topology(code)
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=code))
        self.assertIn("part testSubject = processor", harness)
        self.assertIn("send testSig to testSubject", harness)
        self.assertNotIn("to testSubject.ioPort", harness)
        self.assertNotIn("via ioPort", harness)

    def test_formal_part_def_still_uses_typing(self):
        code = """
package FormalPart {
    attribute def StartSignal;
    action def TakePicture;
    part def Camera {
        action takePicture : TakePicture {
            action trigger accept scene : StartSignal via viewPort;
        }
    }
}
"""
        topo = extract_topology(code)
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=code))
        self.assertIn("part testSubject : Camera", harness)
        self.assertIn("send testScene to testSubject", harness)
        self.assertNotIn("to testSubject.viewPort", harness)


_TRIGGER_OVERRIDE_MODEL = """
package P {
    package Definitions {
        attribute def FuelCmd;
        attribute def EngineStart {
            attribute voltage : Real;
        }
        attribute def EngineOff;
        action def 'Provide Power' { in fuelCmd: FuelCmd; }
    }
    package Usages {
        action 'provide power': 'Provide Power' {
            in fuelCmd: FuelCmd;
            action engineStarted accept engineStart: EngineStart;
            action engineStopped accept engineOff: EngineOff;
        }
    }
}
"""


class TestHarnessTriggerOverrides(unittest.TestCase):
    def test_harness_applies_trigger_override_by_param(self):
        topo = extract_topology(_TRIGGER_OVERRIDE_MODEL)
        harness = build_harness_block(
            topo,
            ExecutionRequest(
                candidate_sysml=_TRIGGER_OVERRIDE_MODEL,
                simulation_vectors={"engineStart": {"voltage": 12.0}},
            ),
        )
        self.assertIn("attribute testEngineStart : EngineStart {", harness)
        self.assertIn(":>> voltage = 12.0;", harness)
        self.assertIn("attribute testEngineOff : EngineOff;", harness)

    def test_harness_applies_trigger_override_by_payload_type(self):
        topo = extract_topology(_TRIGGER_OVERRIDE_MODEL)
        harness = build_harness_block(
            topo,
            ExecutionRequest(
                candidate_sysml=_TRIGGER_OVERRIDE_MODEL,
                simulation_vectors={"EngineStart": {"voltage": 12.0}},
            ),
        )
        self.assertIn("attribute testEngineStart : EngineStart {", harness)
        self.assertIn(":>> voltage = 12.0;", harness)

    def test_harness_trigger_override_does_not_affect_pins(self):
        topo = extract_topology(_load("000200"))
        harness = build_harness_block(
            topo,
            ExecutionRequest(
                candidate_sysml="",
                simulation_vectors={
                    "fuelCmd": 1,
                    "engineStart": {"voltage": 12.0},
                },
            ),
        )
        self.assertIn("in fuelCmd = 1", harness)
        self.assertIn("attribute testEngineStart : EngineStart {", harness)
        self.assertIn(":>> voltage = 12.0;", harness)

    def test_harness_without_trigger_override_unchanged(self):
        topo = extract_topology(_load("000200"))
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=""))
        self.assertIn("attribute testEngineStart : EngineStart;", harness)
        self.assertNotIn(":>> voltage", harness)


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
        self.assertIn("then triggerDoneSignal;", harness)
        self.assertNotRegex(harness, r"first runProbe;\s*\n\s*first ")

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
        self.assertIn("first runProbe;", harness)
        self.assertIn("then triggerSigA;", harness)
        self.assertIn("then triggerSigB;", harness)
        self.assertIn("then triggerSigC;", harness)


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

    def test_extracts_multiline_action_def_pin_types(self):
        code = """
package MultilinePins {
    action def Probe {
        in cmd: Command;
        out result: Boolean;
    }
    attribute def Command;
}
"""
        topo = extract_topology(code)
        probe = next(item for item in topo.action_defs if item.name == "Probe")
        self.assertEqual(probe.input_types["cmd"], "Command")

    def test_extracts_attribute_def_members(self):
        code = """
package Payloads {
    attribute def Command {
        attribute enabled : Boolean;
        attribute level : Integer = 1;
    }
}
"""
        topo = extract_topology(code)
        command = next(item for item in topo.attribute_defs if item.name == "Command")
        self.assertEqual([member.name for member in command.members], ["enabled", "level"])
        self.assertEqual(command.members[0].type_name, "Boolean")
        self.assertTrue(command.members[1].has_default)
        self.assertEqual(command.members[1].default_value, "1")

    def test_builds_enum_boundary_candidates(self):
        code = """
package EnumInput {
    enum def Mode {
        off;
        on;
    }
    action def Probe { in mode: Mode; }
}
"""
        topo = extract_topology(code)
        candidates = candidates_for_input(topo, "mode", "Mode")
        self.assertEqual([item.expression for item in candidates], ["Mode::off", "Mode::on"])
        self.assertEqual(classify_input_type(topo, "Mode").kind, "enumeration")

    def test_builds_structured_payload_fixture_when_members_are_constructible(self):
        code = """
package StructuredInput {
    attribute def Command {
        attribute enabled : Boolean;
        attribute level : Integer;
    }
    action def Probe { in cmd: Command; }
}
"""
        topo = extract_topology(code)
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=code))
        self.assertIn("attribute testCmd : Command {", harness)
        self.assertIn("attribute enabled = false;", harness)
        self.assertIn("attribute level = 0;", harness)
        self.assertIn("in cmd = testCmd;", harness)

    def test_preserves_payload_member_defaults(self):
        code = """
package DefaultPayload {
    attribute def SignalStrength {
        attribute value : Real;
        attribute unit : String = "dBm";
    }
    action def Probe { in signal: SignalStrength; }
}
"""
        topo = extract_topology(code)
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=code))
        self.assertIn("attribute testSignal : SignalStrength {", harness)
        self.assertIn("attribute value = 0.0;", harness)
        self.assertIn('attribute unit = "dBm";', harness)
        self.assertIn("in signal = testSignal;", harness)

    def test_builds_scalar_alias_payload_with_value(self):
        code = """
package ScalarAlias {
    attribute def IMSI :> String;
    action def Probe { in userIdentity: IMSI; }
}
"""
        topo = extract_topology(code)
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=code))
        self.assertIn('attribute testUserIdentity : IMSI = "";', harness)
        self.assertIn("in userIdentity = testUserIdentity;", harness)

    def test_builds_nested_payload_members(self):
        code = """
package NestedPayload {
    attribute def Position {
        attribute latitude : Real;
        attribute longitude : Real;
    }
    attribute def TargetData {
        attribute position : Position;
        attribute classification : String = "unknown";
    }
    action def Probe { in targetData: TargetData; }
}
"""
        topo = extract_topology(code)
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=code))
        self.assertIn("attribute testTargetData : TargetData {", harness)
        self.assertIn("attribute position : Position {", harness)
        self.assertIn("attribute latitude = 0.0;", harness)
        self.assertIn('attribute classification = "unknown";', harness)

    def test_builds_item_payload_fixture(self):
        code = """
package ItemPayload {
    attribute def FieldValue :> Real;
    item def MagneticField {
        attribute fieldStrength : FieldValue;
    }
    action def Probe { in item inputField: MagneticField; }
}
"""
        topo = extract_topology(code)
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=code))
        self.assertIn("item testInputField : MagneticField {", harness)
        self.assertIn("attribute fieldStrength : FieldValue = 0.0;", harness)
        self.assertIn("in inputField = testInputField;", harness)

    def test_builds_quantity_payload_with_unit_reference(self):
        code = """
package QuantityPayload {
    attribute def CurrentValue :> ScalarQuantityValue {
        attribute redefines num : Real;
        attribute redefines mRef : SI::A;
    }
    action def Probe { in current: CurrentValue; }
}
"""
        topo = extract_topology(code)
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=code))
        self.assertIn("attribute testCurrent : CurrentValue {", harness)
        self.assertIn("attribute num = 0.0;", harness)
        self.assertIn("attribute mRef : SI::A;", harness)
        self.assertIn("in current = testCurrent;", harness)

    def test_ignores_redefinition_pins_when_resolving_usage_inputs(self):
        code = """
package RedefinedPins {
    item def MagneticField {
        attribute strength : Real;
    }
    action def Sense {
        in item inputField : MagneticField;
    }
    action sense : Sense {
        in item :>> inputField;
    }
}
"""
        topo = extract_topology(code)
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=code))
        self.assertNotIn("unsupported input type for item", harness)
        self.assertIn("item testInputField : MagneticField {", harness)
        self.assertIn("in inputField = testInputField;", harness)

    def test_explains_unsupported_structured_payload_members(self):
        code = """
package UnsupportedPayload {
    attribute def Command {
        attribute nested : MissingType;
    }
    action def Probe { in cmd: Command; }
}
"""
        topo = extract_topology(code)
        self.assertIn(
            "unsupported structured payload members: nested",
            unsupported_reason_for_input(topo, "Command"),
        )


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

    def test_root_imports_extracted(self):
        topo = extract_topology(_load("000600"))
        self.assertIn("private import ISQ::*;", topo.root_imports)
        self.assertIn("private import SI::*;", topo.root_imports)
        self.assertIn("private import ScalarValues::*;", topo.root_imports)


class TestHarness000600(unittest.TestCase):
    def test_harness_has_part_or_state_todo(self):
        topo = extract_topology(_load("000600"))
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=""))
        self.assertTrue(
            "testSubject" in harness or "TODO(human)" in harness
        )

    def test_harness_includes_candidate_root_imports(self):
        topo = extract_topology(_load("000600"))
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=""))
        self.assertIn("private import ISQ::*;", harness)
        self.assertIn("private import SI::*;", harness)
        self.assertIn("private import ScalarValues::*;", harness)
        self.assertIn("private import EsophagealDopplerMonitoringSystem::*;", harness)

    def test_harness_schedules_state_machine_behavior_entry_point(self):
        topo = extract_topology(_load("000600"))
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=""))
        self.assertIn("exhibit state operationalStates : SystemOperationalStates;", harness)
        # probe comes first, then SM triggers as separate first/then statements
        self.assertIn("first estimateDiameterProbe;", harness)
        self.assertIn("then triggerStartCalibration;", harness)
        self.assertIn("then triggerStopMonitoring;", harness)
        self.assertNotIn("first testSubject.operationalStates;", harness)
        self.assertNotIn("first testSubject;", harness)
        # one first statement followed by then steps, not multiple first statements
        self.assertNotRegex(harness, r"first estimateDiameterProbe;\s*\n\s*first ")


class TestStateMachineExtraction000600(unittest.TestCase):
    """Multi-line `transition ...;` statements spread across several physical lines."""

    def _sm(self):
        topo = extract_topology(_load("000600"))
        return next(sm for sm in topo.state_machines if sm.name == "SystemOperationalStates")

    def test_entry_state_extracted(self):
        self.assertEqual(self._sm().entry_state, "powerOn")

    def test_accept_transition_extracted_across_lines(self):
        sm = self._sm()
        transition = next(t for t in sm.transitions if t.name == "standby_to_calibrating")
        self.assertEqual(transition.source, "standby")
        self.assertEqual(transition.target, "calibrating")
        self.assertEqual(transition.trigger, "StartCalibration")
        self.assertEqual(transition.trigger_kind, "accept")

    def test_if_guard_transition_extracted_across_lines(self):
        sm = self._sm()
        transition = next(t for t in sm.transitions if t.name == "powerOn_to_standby")
        self.assertEqual(transition.source, "powerOn")
        self.assertEqual(transition.target, "standby")
        self.assertEqual(transition.trigger_kind, "if")

    def test_instance_linkage_resolves_owning_part(self):
        sm = self._sm()
        self.assertEqual(sm.instance_name, "EsophagealDopplerSystem")

    def test_part_behavior_entry_points_extracted(self):
        topo = extract_topology(_load("000600"))
        self.assertEqual(
            topo.part_behavior_usage(
                "EsophagealDopplerSystem",
                "exhibit_state",
                "SystemOperationalStates",
            ),
            "operationalStates",
        )
        self.assertEqual(
            topo.part_behavior_usage(
                "EsophagealDopplerSystem",
                "perform_action",
                "MonitorHemodynamics",
            ),
            "monitoring",
        )
        self.assertEqual(
            topo.behavior_execution_ref(
                "testSubject",
                "EsophagealDopplerSystem",
                "exhibit_state",
                "SystemOperationalStates",
            ),
            "testSubject.operationalStates",
        )


class TestGuardParsing(unittest.TestCase):
    _MODEL = """
package P {
    package Definitions {
        attribute def StartSignal;
        part def Widget {
            attribute voltage : Real;
            state def OpStates {
                entry; then off;
                state off;
                transition off_to_on
                    first off
                    accept StartSignal [voltage > 10.0]
                    then on;
                state on;
            }
        }
    }
}
"""

    def test_accept_guard_bracket_syntax_extracted(self):
        topo = extract_topology(self._MODEL)
        sm = topo.state_machines[0]
        transition = sm.transitions[0]
        self.assertEqual(transition.trigger, "StartSignal")
        self.assertEqual(transition.trigger_kind, "accept")
        self.assertEqual(transition.guard, "voltage > 10.0")
        self.assertEqual(
            transition.guard_condition,
            GuardCondition(attribute="voltage", operator=">", value=10.0),
        )

    def test_satisfying_value_for_guard_operators(self):
        self.assertEqual(
            satisfying_value_for_guard(GuardCondition("voltage", ">", 10.0)), "11.0"
        )
        self.assertEqual(
            satisfying_value_for_guard(GuardCondition("voltage", ">=", 10.0)), "10.0"
        )
        self.assertEqual(
            satisfying_value_for_guard(GuardCondition("voltage", "<", 10.0)), "9.0"
        )
        self.assertEqual(
            satisfying_value_for_guard(GuardCondition("voltage", "<=", 10.0)), "10.0"
        )
        self.assertEqual(
            satisfying_value_for_guard(GuardCondition("voltage", "==", 10.0)), "10.0"
        )


class TestOrderedTransitionPath(unittest.TestCase):
    _BRANCHING_MODEL = """
package P {
    package Definitions {
        attribute def Go;
        attribute def Stop;
        state def Cycle {
            entry; then idle;
            state idle;
            transition idle_to_running
                first idle
                accept Go
                then running;
            state running;
            transition running_to_done
                first running
                if "work complete"
                then done;
            state done;
            transition done_to_idle
                first done
                accept Stop
                then idle;
        }
    }
}
"""

    def test_walks_from_entry_and_stops_on_cycle(self):
        topo = extract_topology(self._BRANCHING_MODEL)
        sm = topo.primary_state_machine()
        path = ordered_transition_path(sm)
        self.assertEqual(
            [t.name for t in path],
            ["idle_to_running", "running_to_done", "done_to_idle"],
        )
        # Cycles back to `idle`, which is already visited, so the walk stops there.
        self.assertEqual(path[-1].target, "idle")

    def test_empty_state_machine_yields_empty_path(self):
        code = """
package P {
    package Definitions {
        state def Empty {
        }
    }
}
"""
        topo = extract_topology(code)
        sm = topo.primary_state_machine()
        self.assertIsNotNone(sm)
        self.assertEqual(ordered_transition_path(sm), [])


class TestStateMachineHarness(unittest.TestCase):
    _MODEL = """
package P {
    package Definitions {
        attribute def StartCalibration;
        attribute def StopMonitoring;
        part def Widget {
            attribute voltage : Real;
            state def OpStates {
                entry; then off;
                state off;
                transition off_to_on
                    first off
                    accept StartCalibration [voltage > 10.0]
                    then on;
                state on;
                transition on_to_off
                    first on
                    accept StopMonitoring
                    then off;
            }
            exhibit state ops : OpStates;
        }
    }
}
"""

    def _harness(self):
        topo = extract_topology(self._MODEL)
        return build_harness_block(topo, ExecutionRequest(candidate_sysml=self._MODEL))

    def test_instantiates_part_with_guard_override(self):
        harness = self._harness()
        self.assertIn("part testSubject : Widget {", harness)
        self.assertIn(":>> voltage = 11.0;", harness)
        self.assertIn("exhibit state ops : OpStates;", harness)

    def test_sends_are_targeted_at_instance_not_bare(self):
        harness = self._harness()
        # dot-notation targets the exhibited state machine, not the bare instance
        self.assertIn("send testStartCalibration to testSubject.ops;", harness)
        self.assertIn("send testStopMonitoring to testSubject.ops;", harness)
        self.assertNotRegex(harness, r"\bsend\s+\w+\s*;")

    def test_starts_trigger_chain_without_scheduling_test_subject(self):
        harness = self._harness()
        self.assertIn("first triggerStartCalibration;", harness)
        self.assertIn("then triggerStopMonitoring;", harness)
        self.assertNotIn("first testSubject", harness)


class TestStateMachineForkWithAction(unittest.TestCase):
    """Action probe and exhibited state machine run concurrently without sequencing the part."""

    _MODEL = """
package P {
    package Definitions {
        attribute def Count;
        attribute def StartSignal;
        action def Probe { in count: Count; }
        part def Widget {
            state def OpStates {
                entry; then off;
                state off;
                transition off_to_on
                    first off
                    accept StartSignal
                    then on;
                state on;
            }
            exhibit state ops : OpStates;
        }
    }
    package Usages {
        action monitor : Probe {
            in count: Count;
        }
    }
}
"""

    def test_orchestrator_sequences_only_local_probe_not_test_subject(self):
        topo = extract_topology(self._MODEL)
        harness = build_harness_block(topo, ExecutionRequest(candidate_sysml=self._MODEL))
        self.assertIn("first monitorProbe;", harness)
        self.assertIn("then triggerStartSignal;", harness)
        self.assertNotIn("first testSubject", harness)
        self.assertNotRegex(harness, r"first monitorProbe;\s*\n\s*first ")


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

    def test_parses_compiler_diagnostics(self):
        from nl2sysml.sysml_execution.diagnostics import (
            build_compiler_diagnostics,
            parse_diagnostic_line,
        )

        err = parse_diagnostic_line(
            "ERROR:no viable alternative at input 'then' (1.sysml line : 280 column : 9)"
        )
        self.assertIsNotNone(err)
        assert err is not None
        self.assertEqual(err["severity"], "ERROR")
        self.assertEqual(err["line"], 280)
        self.assertEqual(err["column"], 9)
        self.assertEqual(err["category"], "parse")

        warn = parse_diagnostic_line(
            "WARNING:Duplicate of inherited member name 'age' from PatientData "
            "(1.sysml line : 586 column : 27)"
        )
        self.assertIsNotNone(warn)
        assert warn is not None
        self.assertEqual(warn["severity"], "WARNING")
        self.assertEqual(warn["category"], "duplicate_member")

        diagnostics = build_compiler_diagnostics(
            [
                "ERROR:Must be an accessible feature (use dot notation for nesting) "
                "(1.sysml line : 309 column : 35)",
                "WARNING:Duplicate of inherited member name 'age' from PatientData "
                "(1.sysml line : 586 column : 27)",
                "Package ExecutionHarness (abc)",
            ],
            compiled=False,
            model_kind="behavioral",
        )
        self.assertEqual(diagnostics["n_errors"], 1)
        self.assertEqual(diagnostics["n_warnings"], 1)
        self.assertEqual(diagnostics["first_error_line"], 309)
        self.assertEqual(
            diagnostics["error_counts_by_category"].get("feature_access"), 1
        )
        self.assertEqual(
            diagnostics["warning_counts_by_category"].get("duplicate_member"), 1
        )
        self.assertTrue(diagnostics["raw_trace"].startswith("ERROR:"))

    def test_writes_diagnostics_json(self):
        from tempfile import TemporaryDirectory

        from nl2sysml.sysml_execution.diagnostics import (
            build_compiler_diagnostics,
            write_compiler_diagnostics_file,
        )

        diagnostics = build_compiler_diagnostics(
            ["ERROR:example (1.sysml line : 10 column : 2)"],
            compiled=False,
        )
        with TemporaryDirectory() as tmp:
            path = write_compiler_diagnostics_file(f"{tmp}/diag.json", diagnostics)
            data = json.loads(Path(path).read_text(encoding="utf-8"))
            self.assertEqual(data["n_errors"], 1)
            self.assertEqual(len(data["errors"]), 1)
            self.assertEqual(data["errors"][0]["line"], 10)


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


class TestPayloadResolution(unittest.TestCase):
    """Two-pass resolution: extract accept payloads, classify, inject mock defs."""

    def test_collects_all_sm_accepts_from_000600(self):
        from nl2sysml.sysml_execution.extractor import collect_state_machine_accept_payloads
        topo = extract_topology(_load("000600"))
        payloads = collect_state_machine_accept_payloads(topo)
        # All three accept signals in SystemOperationalStates must be collected,
        # including AcknowledgeAlarm which is on an off-path transition.
        self.assertIn("StartCalibration", payloads)
        self.assertIn("StopMonitoring", payloads)
        self.assertIn("AcknowledgeAlarm", payloads)

    def test_resolve_marks_undefined_payloads_as_missing(self):
        from nl2sysml.sysml_execution.extractor import collect_state_machine_accept_payloads
        from nl2sysml.sysml_execution.vector_planner import resolve_payload_types
        topo = extract_topology(_load("000600"))
        payloads = collect_state_machine_accept_payloads(topo)
        resolution = resolve_payload_types(topo, payloads)
        self.assertIn("StartCalibration", resolution.missing)
        self.assertIn("StopMonitoring", resolution.missing)
        self.assertIn("AcknowledgeAlarm", resolution.missing)

    def test_resolve_marks_defined_payloads_as_existing(self):
        from nl2sysml.sysml_execution.extractor import collect_state_machine_accept_payloads
        from nl2sysml.sysml_execution.vector_planner import resolve_payload_types
        code = """
package P {
    attribute def StartCalibration;
    part def D {
        state def S {
            entry; then a;
            state a;
            transition a_b first a accept StartCalibration then b;
            state b;
        }
        exhibit state s : S;
    }
}
"""
        topo = extract_topology(code)
        payloads = collect_state_machine_accept_payloads(topo)
        resolution = resolve_payload_types(topo, payloads)
        self.assertIn("StartCalibration", resolution.existing)
        self.assertEqual(resolution.missing, [])

    def test_inject_mock_defs_adds_item_defs_to_root_package(self):
        from nl2sysml.sysml_execution.vector_planner import inject_mock_defs_into_root_package
        code = "package P {\n    part def Widget;\n}"
        result = inject_mock_defs_into_root_package(code, ["StartCalibration", "StopMonitoring"])
        self.assertIn("attribute def StartCalibration;", result)
        self.assertIn("attribute def StopMonitoring;", result)
        # injection appears inside the root package (after the opening brace)
        p_idx = result.index("package P {")
        sc_idx = result.index("attribute def StartCalibration;")
        self.assertGreater(sc_idx, p_idx)

    def test_inject_skips_already_defined_types(self):
        from nl2sysml.sysml_execution.vector_planner import inject_mock_defs_into_root_package
        code = "package P {\n    attribute def StartCalibration;\n}"
        result = inject_mock_defs_into_root_package(code, ["StartCalibration"])
        # existing definition must not be duplicated
        self.assertEqual(result.count("StartCalibration"), 1)

    def test_inject_noop_when_no_missing_types(self):
        from nl2sysml.sysml_execution.vector_planner import inject_mock_defs_into_root_package
        code = "package P {\n    part def Widget;\n}"
        self.assertEqual(inject_mock_defs_into_root_package(code, []), code)

    def test_consolidated_payload_contains_mock_defs_for_000600(self):
        topo = extract_topology(_load("000600"))
        harness, mock_types = build_harness_block_with_mocks(topo, ExecutionRequest(candidate_sysml=_load("000600")))
        from nl2sysml.sysml_execution.harness_builder import build_consolidated_payload
        consolidated = build_consolidated_payload(_load("000600"), harness, mock_types)
        self.assertIn("attribute def StartCalibration;", consolidated)
        self.assertIn("attribute def StopMonitoring;", consolidated)
        self.assertIn("attribute def AcknowledgeAlarm;", consolidated)
        # mocks must appear inside the root package, before the harness
        harness_pos = consolidated.index("package ExecutionHarness")
        mock_pos = consolidated.index("attribute def StartCalibration;")
        self.assertLess(mock_pos, harness_pos)


class TestMockNominalFixture(unittest.TestCase):
    """Undefined accept types are mocked and generate real fixtures, not TODOs."""

    _MODEL = """
package P {
    part def Device {
        state def OpStates {
            entry; then standby;
            state standby;
            transition standby_to_active
                first standby
                accept StartCalibration
                then active;
            state active;
        }
        exhibit state ops : OpStates;
    }
}
"""

    def _harness(self):
        topo = extract_topology(self._MODEL)
        return build_harness_block(topo, ExecutionRequest(candidate_sysml=self._MODEL))

    def test_undefined_accept_type_generates_fixture_not_todo(self):
        harness = self._harness()
        self.assertNotIn("TODO(human): unsupported trigger payload type", harness)
        self.assertIn("attribute testStartCalibration : StartCalibration;", harness)

    def test_undefined_accept_type_generates_send_action(self):
        harness = self._harness()
        self.assertIn("send testStartCalibration", harness)
        self.assertIn("triggerStartCalibration", harness)

    def test_mock_types_returned_from_with_mocks(self):
        topo = extract_topology(self._MODEL)
        _harness, mock_types = build_harness_block_with_mocks(
            topo, ExecutionRequest(candidate_sysml=self._MODEL)
        )
        self.assertIn("StartCalibration", mock_types)


if __name__ == "__main__":
    unittest.main()
