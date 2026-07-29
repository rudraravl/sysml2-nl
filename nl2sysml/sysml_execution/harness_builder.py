"""Synthesize SysML v2 ExecutionHarness blocks from extracted topology."""

from __future__ import annotations

from typing import Any, List, Optional, Tuple

from .extractor import classify_kind, collect_state_machine_accept_payloads, ordered_transition_path
from .models import (
    ExecutionRequest,
    ExtractedAcceptTrigger,
    ExtractedActionUsage,
    ExtractedStateMachine,
    ExtractedStateTransition,
    ExtractedTopology,
    ModelKind,
)
from .vector_planner import (
    candidates_for_input,
    candidates_for_trigger,
    inject_mock_defs_into_root_package,
    input_types_for_target,
    resolve_payload_types,
    satisfying_value_for_guard,
    unsupported_reason_for_input,
)

# (declarations/probe/sends body, optional orchestrator entry action, ordered send names)
_OrchestratorSection = tuple[List[str], Optional[str], List[str]]


def _format_value(value: Any) -> str:
    if isinstance(value, str):
        return f'"{value}"'
    return str(value)


def _ref(name: str, topology: ExtractedTopology) -> str:
    return topology.quoted_name(name)


def _format_trigger_send(
    send_name: str,
    fixture: str,
    target: str,
    port: Optional[str],
    topology: ExtractedTopology,
) -> str:
    """Emit one trigger send action line.

    External harness sends always target the whole component/action with ``to``.
    Port routing belongs on the subject's internal ``accept ... via <port>`` —
    aiming ``to target.port`` triggers a SysML compiler lint warning.
    ``port`` is accepted for API stability but intentionally unused.
    """
    _ = port, topology  # port is intentionally ignored for external sends
    return f"action {send_name} send {fixture} to {target};"


def _emit_part_test_subject(
    lines: List[str],
    topology: ExtractedTopology,
    part_name: str,
    body_lines: Optional[List[str]] = None,
) -> None:
    """Emit ``part testSubject`` typed by ``:`` or aliased with ``=``.

    Formal ``part def`` names are blueprints and must use ``:``. Shorthand
    ``part camera { ... }`` usages are instances; typing against them fails
    ("occurrence must be typed by occurrence definitions"), so we alias with ``=``.
    """
    ref = _ref(part_name, topology)
    body_lines = body_lines or []
    if topology.is_formal_part_def(part_name):
        if body_lines:
            lines.append(f"    part testSubject : {ref} {{")
            lines.extend(body_lines)
            lines.append("    }")
        else:
            lines.append(f"    part testSubject : {ref};")
    else:
        if body_lines:
            lines.append(f"    part testSubject = {ref} {{")
            lines.extend(body_lines)
            lines.append("    }")
        else:
            lines.append(f"    part testSubject = {ref};")


def _harness_import_lines(topology: ExtractedTopology) -> List[str]:
    """Build import lines for ExecutionHarness: candidate root imports, then root ::*."""
    lines: List[str] = []
    for imp in topology.root_imports:
        lines.append(f"    {imp}")
    root = topology.primary_package()
    if root:
        lines.append(f"    private import {_ref(root, topology)}::*;")
    return lines


def _simple_type(type_name: str) -> str:
    return type_name.split("::")[-1].strip().strip("'")


def _lookup_trigger_member_overrides(
    sim: dict[str, Any],
    trigger: ExtractedAcceptTrigger,
) -> dict[str, Any] | None:
    for key in (trigger.param, trigger.payload_type, _simple_type(trigger.payload_type)):
        if not key:
            continue
        value = sim.get(key)
        if isinstance(value, dict):
            return value
    return None


def _trigger_action_name(payload_type: str) -> str:
    return f"trigger{_simple_type(payload_type)}"


def _format_orchestrator_succession(
    entry: Optional[str],
    send_names: List[str],
) -> Optional[str]:
    """Build orchestrator succession as separate first/then statements.

    SysML v2 treats ``first`` and ``then`` as structural prefixes; each step in
    a sequence must be its own statement terminated with a semicolon.
    """
    steps: List[str] = []
    if entry:
        steps.append(entry)
    steps.extend(send_names)
    if not steps:
        return None
    lines = [f"first {steps[0]};"]
    lines.extend(f"then {step};" for step in steps[1:])
    return "\n".join(lines)


def _append_indented(lines: List[str], text: str, indent: str) -> None:
    for line in text.splitlines():
        lines.append(f"{indent}{line}" if line else "")


def _state_machine_part_def(topology: ExtractedTopology, sm: ExtractedStateMachine) -> Optional[str]:
    """Resolve the part def type to instantiate for a state machine's harness instance.

    `sm.instance_name` is the enclosing part/usage name at the `exhibit state` site.
    When it names the part def itself (the common case: `exhibit state` sits
    directly in the `part def` body, not inside a distinct usage), it isn't a
    real instance name and just tells us the type to instantiate.
    """
    if sm.instance_name and sm.instance_name in topology.part_defs:
        return sm.instance_name
    return topology.primary_part_def()


def _state_machine_instance_name(sm: ExtractedStateMachine, part_def: Optional[str]) -> str:
    if sm.instance_name and sm.instance_name != part_def:
        return sm.instance_name
    return "testSubject"


def _guard_overrides_for_path(path: List[ExtractedStateTransition]) -> "dict[str, str]":
    """Structural attribute overrides needed so every guard on the path evaluates true."""
    overrides: dict[str, str] = {}
    for transition in path:
        condition = transition.guard_condition
        if condition and condition.attribute not in overrides:
            overrides[condition.attribute] = satisfying_value_for_guard(condition)
    return overrides


def _build_state_machine_section(
    topology: ExtractedTopology,
    lines: List[str],
    mocked_types: Optional[set] = None,
) -> Optional[_OrchestratorSection]:
    """Emit the state machine's part instantiation and return its orchestrator body.

    Parts are structural elements and can't live inside an action body, so the
    `part <instance> : <PartDef> { ... }` declaration is appended directly to
    `lines` (package scope). The returned section (fixture declarations + targeted
    `send` actions + start name) is meant to be woven into the shared
    `action orchestrator { ... }` block by the caller, alongside any action probe.

    Send commands use dot-notation to target the state machine instance directly
    (e.g. `testSubject.operationalStates`) so the kernel routes signals into the
    exhibited state machine rather than broadcasting into the whole instance pool.
    """
    sm = topology.primary_state_machine()
    if sm is None:
        return None

    part_def = _state_machine_part_def(topology, sm)
    if not part_def:
        lines.append("")
        lines.append(
            f"    // TODO(human): no part def found for state machine "
            f"{_ref(sm.name, topology)}; cannot instantiate subject"
        )
        return None

    instance_name = _state_machine_instance_name(sm, part_def)
    path = ordered_transition_path(sm)
    overrides = _guard_overrides_for_path(path)
    state_usage = topology.part_behavior_usage(part_def, "exhibit_state", sm.name) or "sm"
    send_target = topology.behavior_execution_ref(instance_name, part_def, "exhibit_state", sm.name)

    lines.append("")
    sm_body: List[str] = []
    for attr, value in overrides.items():
        sm_body.append(f"        :>> {attr} = {value};")
    sm_body.append(f"        exhibit state {state_usage} : {_ref(sm.name, topology)};")
    if instance_name == "testSubject":
        _emit_part_test_subject(lines, topology, part_def, body_lines=sm_body)
    else:
        # Named instance bindings other than the default harness subject still use
        # formal typing when available; shorthand models use aliasing.
        ref = _ref(part_def, topology)
        op = ":" if topology.is_formal_part_def(part_def) else "="
        lines.append(f"    part {instance_name} {op} {ref} {{")
        lines.extend(sm_body)
        lines.append("    }")

    seen_trigger_params: set[str] = set()
    trigger_plans: List[tuple[str, str]] = []
    declarations: List[str] = []
    for index, transition in enumerate(path):
        if transition.trigger_kind != "accept" or not transition.trigger:
            continue
        trigger = ExtractedAcceptTrigger(payload_type=transition.trigger)
        candidates = candidates_for_trigger(
            topology, trigger, index, seen_trigger_params, mocked_types=mocked_types
        )
        if candidates:
            trigger_plans.append((transition.trigger, candidates[0].expression))
            declarations.extend(candidates[0].declarations)
        else:
            trigger_plans.append((transition.trigger, ""))

    body: List[str] = []
    for declaration in dict.fromkeys(declarations):
        body.append(declaration)

    for trigger_name, fixture in trigger_plans:
        if not fixture:
            body.append(
                f"// TODO(human): unsupported trigger payload type "
                f"for {_ref(trigger_name, topology)}"
            )

    send_names: List[str] = []
    for trigger_name, fixture in trigger_plans:
        if not fixture:
            continue
        send_name = _trigger_action_name(trigger_name)
        send_names.append(send_name)
        body.append(f"action {send_name} send {fixture} to {send_target};")

    if not body and not send_names:
        return None
    return body, None, send_names


def _build_part_hosted_section(
    topology: ExtractedTopology,
    lines: List[str],
    part_def: str,
    composite: ExtractedActionUsage,
    sim: dict,
    mocked_types: Optional[set] = None,
) -> Optional[_OrchestratorSection]:
    """Emit `part testSubject` at package scope and build orchestrator trigger sends.

    This path is taken when the primary composite action is nested inside a part
    (e.g. 000134's `action takePicture` inside `part camera`). The part auto-runs
    when bound/instantiated, so:
    - Formal ``part def`` subjects use ``part testSubject : PartDef``.
    - Shorthand ``part camera { ... }`` subjects use ``part testSubject = camera``.
    - Accept triggers are driven by ``send ... to testSubject`` (whole component;
      the subject's internal ``accept ... via port`` catches the signal).
    - No action probe is emitted; the succession chain is trigger-only.
    """
    instance_name = "testSubject"

    # -- Resolve input-pin bindings (emitted inside the part block as :>> overrides) --
    input_types = input_types_for_target(topology)
    pin_names = list(composite.inputs)
    declarations: List[str] = []
    part_pin_lines: List[str] = []
    for pin in pin_names:
        if pin in sim:
            part_pin_lines.append(f"    :>> {pin} = {_format_value(sim[pin])};")
        else:
            candidates = candidates_for_input(
                topology,
                pin,
                input_types.get(pin, ""),
            )
            if candidates:
                declarations.extend(candidates[0].declarations)
                part_pin_lines.append(f"    :>> {pin} = {candidates[0].expression};")
            else:
                reason = unsupported_reason_for_input(topology, input_types.get(pin, ""))
                part_pin_lines.append(
                    f"    // TODO(human): unsupported input type "
                    f"for {pin}: {input_types.get(pin, 'unknown')} ({reason})"
                )

    # -- Emit part testSubject at package scope (: typing vs = alias) --
    lines.append("")
    _emit_part_test_subject(lines, topology, part_def, body_lines=part_pin_lines)

    # -- Build trigger-send section for the orchestrator body --
    required_triggers = composite.required_triggers
    seen_trigger_params: set[str] = set()
    trigger_plans: List[tuple[ExtractedAcceptTrigger, str]] = []
    for index, trigger in enumerate(required_triggers):
        overrides = None
        for key in (trigger.param, trigger.payload_type, _simple_type(trigger.payload_type)):
            if key and key in sim and isinstance(sim[key], dict):
                overrides = sim[key]
                break
        candidates = candidates_for_trigger(
            topology,
            trigger,
            index,
            seen_trigger_params,
            member_overrides=overrides,
            mocked_types=mocked_types,
        )
        if candidates:
            trigger_plans.append((trigger, candidates[0].expression))
            declarations.extend(candidates[0].declarations)
        else:
            trigger_plans.append((trigger, ""))

    body: List[str] = []
    for declaration in dict.fromkeys(declarations):
        body.append(declaration)

    for trigger, _fixture in trigger_plans:
        if not _fixture:
            body.append(
                f"// TODO(human): unsupported trigger payload type "
                f"for {_ref(trigger.payload_type, topology)}"
            )

    send_names: List[str] = []
    for trigger, fixture in trigger_plans:
        if not fixture:
            continue
        send_name = _trigger_action_name(trigger.payload_type)
        send_names.append(send_name)
        body.append(
            _format_trigger_send(send_name, fixture, instance_name, trigger.port, topology)
        )

    if not body and not send_names:
        return None
    return body, None, send_names


def _emit_orchestrator(
    lines: List[str],
    action_section: Optional[_OrchestratorSection],
    state_machine_section: Optional[_OrchestratorSection],
) -> None:
    """Weave action-probe and state-machine send actions into one orchestrator.

    The test subject part is instantiated at package scope and its exhibited
    behaviors start automatically; they must not appear in the orchestrator's
    single `first` succession. Only orchestrator-local actions and `send`
    triggers are sequenced.
    """
    sections = [section for section in (action_section, state_machine_section) if section]
    if not sections:
        return

    lines.append("")
    lines.append("    action orchestrator {")
    indent = "        "

    entry: Optional[str] = None
    send_names: List[str] = []
    for section in sections:
        _append_indented(lines, "\n".join(section[0]), indent)
        if section[1] and entry is None:
            entry = section[1]
        send_names.extend(section[2])

    succession = _format_orchestrator_succession(entry, send_names)
    if succession:
        _append_indented(lines, succession, indent)

    lines.append("    }")


def _compute_mocked_types(topology: ExtractedTopology) -> List[str]:
    """Run Pass 1 + Pass 2 and return accept payload names that need mock injection."""
    payloads = collect_state_machine_accept_payloads(topology)
    resolution = resolve_payload_types(topology, payloads)
    return resolution.missing


def build_harness_block_with_mocks(
    topology: ExtractedTopology, request: ExecutionRequest
) -> tuple[str, List[str]]:
    """Build harness and return (harness_text, mock_types) for consolidation.

    mock_types is the list of accept payload names that have no definition in the
    candidate model and need `attribute def T;` injection into the root package before
    the kernel can parse the consolidated payload without type-resolution errors.
    """
    mock_types = _compute_mocked_types(topology)
    mocked_set: Optional[set] = set(mock_types) if mock_types else None
    kind = classify_kind(topology)
    if kind == "behavioral":
        return _build_behavioral_harness(topology, request, mocked_types=mocked_set), mock_types
    if kind == "structural":
        return _build_structural_harness(topology, request), mock_types
    return _build_empty_harness(), mock_types


def build_harness_block(topology: ExtractedTopology, request: ExecutionRequest) -> str:
    """Build a model-kind-specific harness package."""
    harness, _mock_types = build_harness_block_with_mocks(topology, request)
    return harness


def _build_empty_harness() -> str:
    return "\n".join(
        [
            "// --- Test harness (auto-generated) ---",
            "package ExecutionHarness {",
            "    // empty model: no probes generated",
            "}",
        ]
    )


def _build_behavioral_harness(
    topology: ExtractedTopology,
    request: ExecutionRequest,
    mocked_types: Optional[set] = None,
) -> str:
    lines: List[str] = [
        "// --- Test harness (auto-generated) ---",
        "package ExecutionHarness {",
    ]

    lines.extend(_harness_import_lines(topology))

    sim = request.simulation_vectors or {}
    composite = topology.primary_composite_usage()
    action_def = topology.primary_action_def()

    action_section: Optional[_OrchestratorSection] = None
    hosted = topology.part_hosted_target()

    if hosted:
        # Part-hosted path: the primary composite lives inside a part definition.
        # Instantiate `part testSubject : <PartDef>` at package scope and drive
        # accept triggers with `send ... to testSubject[.<port>]`.
        part_def, hosted_composite = hosted
        action_section = _build_part_hosted_section(
            topology, lines, part_def, hosted_composite, sim, mocked_types=mocked_types
        )
    elif composite or action_def:
        # Action-probe path: the primary composite is a top-level Usages action.
        # Instantiate an orchestrator-local action probe and bind its input pins.
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
            required_triggers = topology.required_triggers_for_target()
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

            trigger_plans: List[tuple[ExtractedAcceptTrigger, str]] = []
            seen_trigger_params: set[str] = set()
            for index, trigger in enumerate(required_triggers):
                overrides = _lookup_trigger_member_overrides(sim, trigger)
                candidates = candidates_for_trigger(
                    topology,
                    trigger,
                    index,
                    seen_trigger_params,
                    member_overrides=overrides,
                )
                if candidates:
                    trigger_plans.append((trigger, candidates[0].expression))
                    declarations.extend(candidates[0].declarations)
                else:
                    trigger_plans.append((trigger, ""))

            has_action_content = bool(
                declarations or required_triggers or pin_names or trigger_plans
            )

            body: List[str] = []
            for declaration in dict.fromkeys(declarations):
                body.append(declaration)

            for trigger, _fixture in trigger_plans:
                if not _fixture:
                    body.append(
                        f"// TODO(human): unsupported trigger payload type "
                        f"for {_ref(trigger.payload_type, topology)}"
                    )

            body.append(f"action {probe_name} : {_ref(type_ref, topology)} {{")
            for pin in pin_names:
                if pin in bindings:
                    body.append(f"    in {pin} = {bindings[pin]};")
                else:
                    reason = unsupported_reason_for_input(
                        topology,
                        input_types.get(pin, ""),
                    )
                    body.append(
                        f"    // TODO(human): unsupported input type "
                        f"for {pin}: {input_types.get(pin, 'unknown')} ({reason})"
                    )
            body.append("}")

            send_names: List[str] = []
            for trigger, fixture in trigger_plans:
                if not fixture:
                    continue
                send_name = _trigger_action_name(trigger.payload_type)
                send_names.append(send_name)
                body.append(
                    _format_trigger_send(send_name, fixture, probe_name, trigger.port, topology)
                )

            if has_action_content:
                action_section = (body, probe_name, send_names)

    for send in topology.send_actions:
        sig = _ref(send.signal_type, topology)
        lines.append(
            f"    // TODO(human): kernel cannot send {sig} from {send.action_name}; "
            f"inject when API available"
        )

    # State machine: instantiate the owning part and drive its transitions via targeted sends.
    # The SM section appends its own `part testSubject` block; when both hosted and SM sections
    # target the same part def they are deliberately kept separate (both are valid in SysML v2).
    state_machine_section = _build_state_machine_section(topology, lines, mocked_types=mocked_types)

    _emit_orchestrator(lines, action_section, state_machine_section)

    lines.append("}")
    return "\n".join(lines)


def _build_structural_harness(topology: ExtractedTopology, request: ExecutionRequest) -> str:
    lines: List[str] = [
        "// --- Test harness (auto-generated) ---",
        "package ExecutionHarness {",
    ]

    lines.extend(_harness_import_lines(topology))

    part_def = topology.primary_part_def()
    sim = request.simulation_vectors or {}

    if part_def:
        _emit_part_test_subject(lines, topology, part_def)
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


def build_consolidated_payload(
    candidate_sysml: str,
    harness_block: str,
    mock_defs: Optional[List[str]] = None,
) -> str:
    """Append synthesized harness to candidate source, optionally injecting mock type defs.

    When mock_defs is provided, `attribute def T;` lines are inserted immediately after the
    root package's opening brace so the kernel AST parser can resolve every accept signal
    referenced in the candidate model before encountering the ExecutionHarness package.
    """
    base = inject_mock_defs_into_root_package(candidate_sysml, mock_defs or [])
    harness = harness_block.strip()
    return f"{base.rstrip()}\n\n{harness}\n"
