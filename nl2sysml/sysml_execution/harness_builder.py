"""Phase 2: synthesize KerML/SysML v2 test harness blocks from extracted topology."""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from .extractor import classify_topology
from .models import (
    ExecutionRequest,
    ExtractedTopology,
    HarnessBuildResult,
    HarnessMetadata,
    ModelProfile,
)


def _format_value(value: Any) -> str:
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, str):
        return f'"{value}"'
    return str(value)


def _ref(name: str, topology: ExtractedTopology) -> str:
    return topology.quoted_name(name)


def build_harness_block(
    topology: ExtractedTopology,
    request: ExecutionRequest,
) -> HarnessBuildResult:
    """Build profile-specific harness and metadata."""
    profile = classify_topology(topology)
    if profile == ModelProfile.ACTION_COMPOSITE:
        return _build_action_composite_harness(topology, request, profile)
    if profile == ModelProfile.ANALYSIS_TOOL:
        return _build_analysis_tool_harness(topology, request, profile)
    if profile == ModelProfile.PART_STATE:
        return _build_part_state_harness(topology, request, profile)
    return _build_structural_only_harness(topology, request, profile)


def _build_structural_only_harness(
    topology: ExtractedTopology,
    request: ExecutionRequest,
    profile: ModelProfile,
) -> HarnessBuildResult:
    lines = [
        "// --- Test harness (auto-generated) ---",
        "package ExecutionHarness {",
        "    // structural-only model: no behavioral probes required",
        "}",
    ]
    meta = HarnessMetadata(
        profile=profile,
        probes_emitted=0,
        probes_runnable=False,
        skipped_reasons=["no behavioral surface detected"],
    )
    return HarnessBuildResult(harness_block="\n".join(lines), metadata=meta)


def _build_analysis_tool_harness(
    topology: ExtractedTopology,
    request: ExecutionRequest,
    profile: ModelProfile,
) -> HarnessBuildResult:
    lines = [
        "// --- Test harness (auto-generated) ---",
        "package ExecutionHarness {",
        "    // analysis/tooling action model: external tool execution not exercised here",
    ]
    for ad in topology.action_defs[:3]:
        lines.append(f"    // action def: {_ref(ad.name, topology)} (ToolExecution metadata)")
    lines.append("}")
    meta = HarnessMetadata(
        profile=profile,
        probes_emitted=0,
        probes_runnable=False,
        primary_target=topology.action_defs[0].name if topology.action_defs else None,
        skipped_reasons=["analysis_tool_execution_requires_external_tool"],
    )
    return HarnessBuildResult(harness_block="\n".join(lines), metadata=meta)


def _build_action_composite_harness(
    topology: ExtractedTopology,
    request: ExecutionRequest,
    profile: ModelProfile,
) -> HarnessBuildResult:
    skipped: List[str] = []
    root = topology.primary_package()
    composite = topology.primary_composite_usage()

    if request.target_behaviors:
        target_name = request.target_behaviors[0]
        composite = next(
            (u for u in topology.action_usages if u.name == target_name),
            composite,
        )

    lines: List[str] = [
        "// --- Test harness (auto-generated) ---",
        "package ExecutionHarness {",
    ]

    if root:
        lines.append(f"    private import {_ref(root, topology)}::Usages::*;")
        lines.append(f"    private import {_ref(root, topology)}::Definitions::*;")
    else:
        skipped.append("no root package for cross-package imports")

    has_assign = False
    has_perform = False
    probes_emitted = 0
    pin_names: List[str] = []

    if not composite:
        skipped.append("no composite action usage extracted")
        lines.append("    // ACTION_COMPOSITE profile but no runnable target")
    else:
        target_ref = _ref(composite.name, topology)
        type_ref = (
            _ref(composite.type_ref, topology) if composite.type_ref else target_ref
        )
        sim = request.simulation_vectors or {}

        lines.append("")
        lines.append("    action def SentinelActionProbe {")
        probes_emitted += 1

        pin_names = composite.inputs or []
        if not pin_names and composite.type_ref:
            for ad in topology.action_defs:
                if ad.name == composite.type_ref:
                    pin_names = ad.inputs
                    break

        assign_lines: List[str] = []
        for pin in pin_names:
            if pin in sim:
                assign_lines.append(f"            assign {pin} = {_format_value(sim[pin])};")
                has_assign = True

        accept_comments: List[str] = []
        for accept in topology.accept_actions:
            sig_ref = _ref(accept.signal_type, topology)
            accept_comments.append(
                f"            // accept trigger: {accept.action_name} "
                f"<- {accept.signal_param}: {sig_ref}"
            )
            accept_comments.append(
                f"            // TODO: kernel send/trigger for {accept.signal_param} "
                f"when API confirmed"
            )

        # Reference the action *definition* via usage:Type (see dataset 000216), not
        # `action run : 'provide power'` which nests a usage as an untyped sub-action.
        if assign_lines or accept_comments:
            lines.append(f"        perform action {target_ref}: {type_ref} {{")
            lines.extend(assign_lines)
            lines.extend(accept_comments)
            if topology.flows:
                lines.append("            // extracted item flows:")
                for flow in topology.flows[:8]:
                    lines.append(f"            //   {flow.source} -> {flow.target}")
            lines.append("        }")
        else:
            if pin_names:
                for pin in pin_names:
                    lines.append(
                        f"        // in pin {pin}: provide simulation_vectors to assign"
                    )
            lines.append(f"        perform action {target_ref}: {type_ref};")

        lines.append("    }")
        lines.append("")
        lines.append("    action sentinelActionRun : SentinelActionProbe {")
        lines.append("    }")
        has_perform = True
        probes_emitted += 1

    if topology.successions:
        lines.append("")
        lines.append("    // control successions (static trace checklist):")
        for succ in topology.successions[:12]:
            lines.append(f"    //   first {succ.source} then {succ.target}")

    lines.append("}")

    provided_inputs = [pin for pin in pin_names if pin in (request.simulation_vectors or {})]
    missing_inputs = [pin for pin in pin_names if pin not in (request.simulation_vectors or {})]
    if composite and missing_inputs:
        skipped.append(
            "missing simulation_vectors for input pins: " + ", ".join(missing_inputs)
        )

    probes_runnable = (
        composite is not None
        and bool(root)
        and not any(s.startswith("no composite") or s.startswith("no root package") for s in skipped)
        and not missing_inputs
    )

    meta = HarnessMetadata(
        profile=profile,
        probes_emitted=probes_emitted,
        probes_runnable=probes_runnable,
        primary_target=composite.name if composite else None,
        skipped_reasons=skipped,
        has_perform_probe=has_perform,
        has_assign_probe=has_assign,
        has_assert_probe=False,
        required_inputs=pin_names,
        provided_inputs=provided_inputs,
        missing_inputs=missing_inputs,
    )
    return HarnessBuildResult(harness_block="\n".join(lines), metadata=meta)


def _build_part_state_harness(
    topology: ExtractedTopology,
    request: ExecutionRequest,
    profile: ModelProfile,
) -> HarnessBuildResult:
    lines: List[str] = [
        "// --- Test harness (auto-generated) ---",
        "package ExecutionHarness {",
    ]

    part_def = topology.primary_part_def()
    part_inst_name = "sentinelTestSubject"
    skipped: List[str] = []
    probes_emitted = 0
    has_assign = False
    has_assert = False
    has_perform = False

    if part_def:
        lines.append(f"    part {part_inst_name} :> {part_def};")
        probes_emitted += 1
    elif topology.part_instances:
        lines.append(f"    // instance-only model: {topology.part_instances[0]}")
    else:
        skipped.append("no part def for structural subject")

    target_behaviors = request.target_behaviors or topology.state_machines
    sim = request.simulation_vectors or {}
    invariants = request.target_invariants or [c.name for c in topology.constraints]

    emit_behavior = bool(target_behaviors) or bool(part_def)
    emit_constraint = bool(invariants) or bool(topology.constraints) or bool(sim)

    if emit_behavior:
        lines.append("")
        lines.append("    action def SentinelBehaviorProbe {")
        if target_behaviors:
            sm = target_behaviors[0]
            lines.append(f"        // target state machine / behavior: {sm}")
            if part_def:
                lines.append(f"        in part subject :> {part_def};")
            lines.append(f"        // perform {topology.quoted_name(sm)};")
            has_perform = True
        elif part_def:
            lines.append(f"        in part subject :> {part_def};")
        lines.append("    }")
        lines.append("")
        lines.append("    action sentinelBehaviorRun : SentinelBehaviorProbe {")
        if part_def:
            lines.append(f"        bind subject = {part_inst_name};")
        lines.append("    }")
        probes_emitted += 1

    if emit_constraint and part_def:
        lines.append("")
        lines.append("    action def SentinelConstraintProbe {")
        lines.append(f"        in part subject :> {part_def};")

        for key, value in sim.items():
            lines.append(f"        assign subject.{key} = {_format_value(value)};")
            has_assign = True

        for inv in invariants[:10]:
            if inv and not inv.startswith("constraint_"):
                lines.append(f"        assert {inv};")
                has_assert = True

        if topology.constraints and not invariants:
            for c in topology.constraints[:10]:
                if c.name and not c.name.startswith("constraint_"):
                    lines.append(f"        assert {c.name};")
                    has_assert = True

        lines.append("    }")
        lines.append("")
        lines.append("    action sentinelConstraintRun : SentinelConstraintProbe {")
        lines.append(f"        bind subject = {part_inst_name};")
        lines.append("    }")
        probes_emitted += 1
    elif emit_constraint and not part_def:
        skipped.append("constraints present but no part def to bind subject")

    lines.append("}")

    probes_runnable = probes_emitted > 0 and (part_def is not None or has_perform)
    if not probes_runnable and (topology.constraints or topology.state_machines):
        skipped.append("insufficient probes for part/state model")

    meta = HarnessMetadata(
        profile=profile,
        probes_emitted=probes_emitted,
        probes_runnable=probes_runnable,
        primary_target=part_def or (target_behaviors[0] if target_behaviors else None),
        skipped_reasons=skipped,
        has_perform_probe=has_perform,
        has_assign_probe=has_assign,
        has_assert_probe=has_assert,
    )
    return HarnessBuildResult(harness_block="\n".join(lines), metadata=meta)


def build_consolidated_payload(
    candidate_sysml: str,
    harness_block: str,
) -> str:
    """Append synthesized harness to immutable candidate source."""
    base = candidate_sysml.rstrip()
    harness = harness_block.strip()
    return f"{base}\n\n{harness}\n"
