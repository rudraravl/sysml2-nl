"""Synthesize SysML v2 ExecutionHarness blocks from extracted topology."""

from __future__ import annotations

from typing import Any, List, Optional

from .extractor import classify_kind
from .models import ExecutionRequest, ExtractedTopology, ModelKind
from .vector_planner import candidates_for_input, input_types_for_target


def _format_value(value: Any) -> str:
    if isinstance(value, str):
        return f'"{value}"'
    return str(value)


def _ref(name: str, topology: ExtractedTopology) -> str:
    return topology.quoted_name(name)


def build_harness_block(topology: ExtractedTopology, request: ExecutionRequest) -> str:
    """Build a model-kind-specific harness package."""
    kind = classify_kind(topology)
    if kind == "behavioral":
        return _build_behavioral_harness(topology, request)
    if kind == "structural":
        return _build_structural_harness(topology, request)
    return _build_empty_harness()


def _build_empty_harness() -> str:
    return "\n".join(
        [
            "// --- Test harness (auto-generated) ---",
            "package ExecutionHarness {",
            "    // empty model: no probes generated",
            "}",
        ]
    )


def _build_behavioral_harness(topology: ExtractedTopology, request: ExecutionRequest) -> str:
    lines: List[str] = [
        "// --- Test harness (auto-generated) ---",
        "package ExecutionHarness {",
    ]

    root = topology.primary_package()
    if root:
        lines.append(f"    private import {_ref(root, topology)}::Definitions::*;")
        if topology.action_usages:
            lines.append(f"    private import {_ref(root, topology)}::Usages::*;")

    sim = request.simulation_vectors or {}
    composite = topology.primary_composite_usage()
    action_def = topology.primary_action_def()

    # Action probe: bind input pins via validated `in pin = value` syntax
    if composite or action_def:
        type_ref = None
        pin_names: List[str] = []
        probe_name = "actionProbe"

        if composite:
            type_ref = composite.type_ref or composite.name
            pin_names = list(composite.inputs)
            probe_name = f"{composite.name.replace(' ', '_')}Probe"
        elif action_def:
            type_ref = action_def.name
            pin_names = list(action_def.inputs)

        if type_ref:
            if not pin_names and composite and composite.type_ref:
                for ad in topology.action_defs:
                    if ad.name == composite.type_ref:
                        pin_names = list(ad.inputs)
                        break

            input_types = input_types_for_target(topology)
            declarations: List[str] = []
            bindings = {}
            for pin in pin_names:
                if pin in sim:
                    bindings[pin] = _format_value(sim[pin])
                else:
                    candidates = candidates_for_input(
                        topology,
                        pin,
                        input_types.get(pin, ""),
                    )
                    if candidates:
                        bindings[pin] = candidates[0].expression
                        declarations.extend(candidates[0].declarations)

            probe_indent = "    "
            lines.append("")
            if declarations:
                lines.append("    action orchestrator {")
                for declaration in dict.fromkeys(declarations):
                    lines.append(f"        {declaration}")
                probe_indent = "        "

            lines.append(
                f"{probe_indent}action {probe_name} : {_ref(type_ref, topology)} {{"
            )
            for pin in pin_names:
                if pin in bindings:
                    lines.append(f"{probe_indent}    in {pin} = {bindings[pin]};")
                else:
                    lines.append(
                        f"{probe_indent}    // TODO(human): unsupported input type "
                        f"for {pin}: {input_types.get(pin, 'unknown')}"
                    )
            lines.append(f"{probe_indent}}}")
            if declarations:
                lines.append("    }")

    # Accept/send event stubs
    for accept in topology.accept_actions:
        sig = _ref(accept.signal_type, topology)
        lines.append(
            f"    // TODO(human): kernel cannot send/trigger {accept.signal_param} "
            f"({sig}); inject event when API available"
        )
    for send in topology.send_actions:
        sig = _ref(send.signal_type, topology)
        lines.append(
            f"    // TODO(human): kernel cannot send {sig} from {send.action_name}; "
            f"inject when API available"
        )

    # State machine: exhibit on a part subject when possible
    if topology.state_machines:
        sm = topology.state_machines[0]
        part_def = topology.primary_part_def()
        lines.append("")
        if part_def:
            lines.append(f"    part testSubject : {_ref(part_def, topology)} {{")
            lines.append(f"        exhibit state sm : {_ref(sm.name, topology)};")
            lines.append("    }")
        else:
            lines.append(f"    // state machine: {_ref(sm.name, topology)}")

        triggers = [
            t.trigger
            for t in sm.transitions
            if t.trigger and t.trigger_kind == "accept"
        ]
        if triggers:
            trigger_list = ", ".join(triggers)
            lines.append(
                f"    // TODO(human): drive state transitions via events: {trigger_list}"
            )
        elif sm.transitions:
            trans_summary = "; ".join(
                f"{t.source or '?'} -> {t.target or '?'}"
                for t in sm.transitions[:8]
            )
            lines.append(
                f"    // TODO(human): drive state transitions: {trans_summary}"
            )

    lines.append("}")
    return "\n".join(lines)


def _build_structural_harness(topology: ExtractedTopology, request: ExecutionRequest) -> str:
    lines: List[str] = [
        "// --- Test harness (auto-generated) ---",
        "package ExecutionHarness {",
    ]

    root = topology.primary_package()
    if root:
        lines.append(f"    private import {_ref(root, topology)}::*;")

    part_def = topology.primary_part_def()
    sim = request.simulation_vectors or {}

    if part_def:
        lines.append(f"    part testSubject : {_ref(part_def, topology)};")
    else:
        lines.append("    // TODO(human): no part def found; cannot instantiate subject")

    # Value injection for attributes without defaults
    unbound_attrs = [a for a in topology.attributes if not a.has_default]
    if sim:
        for key, value in sim.items():
            attr = next((a for a in topology.attributes if a.name == key), None)
            if attr and attr.has_default:
                lines.append(
                    f"    // TODO(human): cannot override default-valued attribute {key}; "
                    f"kernel rejects binding override"
                )
            elif part_def:
                lines.append(
                    f"    // TODO(human): inject {key} = {_format_value(value)} "
                    f"(attribute value injection not yet supported)"
                )
    elif unbound_attrs:
        names = ", ".join(a.name for a in unbound_attrs[:8])
        lines.append(f"    // TODO(human): define boundary input values for: {names}")

    # Assert constraints (requires boolean expression body; left as TODO when not parsed)
    named_constraints = [
        c for c in topology.constraints if c.name and not c.name.startswith("constraint_")
    ]
    if named_constraints:
        for c in named_constraints[:10]:
            lines.append(
                f"    // TODO(human): assert constraint {c.name} {{ "
                f"testSubject.<attr> <= <limit> }}"
            )
    elif topology.constraints:
        lines.append(
            "    // TODO(human): constraints found but no boolean expression to assert"
        )

    lines.append("}")
    return "\n".join(lines)


def build_consolidated_payload(candidate_sysml: str, harness_block: str) -> str:
    """Append synthesized harness to candidate source."""
    base = candidate_sysml.rstrip()
    harness = harness_block.strip()
    return f"{base}\n\n{harness}\n"
