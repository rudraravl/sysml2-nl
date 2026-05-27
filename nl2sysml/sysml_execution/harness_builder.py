"""Phase 2: synthesize KerML/SysML v2 test harness blocks from extracted topology."""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from .models import ExecutionRequest, ExtractedTopology


def _indent_block(lines: List[str], spaces: int = 4) -> str:
    pad = " " * spaces
    return "\n".join(pad + line for line in lines)


def build_harness_block(
    topology: ExtractedTopology,
    request: ExecutionRequest,
) -> str:
    """
    Build a testing action block for behavioral and parametric verification.
    Domain-agnostic: uses first available part/state/constraint from extraction.
    """
    lines: List[str] = [
        "// --- Test harness (auto-generated) ---",
        "package ExecutionHarness {",
    ]

    part_def = topology.primary_part_def()
    # Use a harness-local instance name to avoid colliding with candidate usages.
    part_inst_name = "sentinelTestSubject"
    pkg = topology.primary_package()

    if part_def:
        lines.append(f"    part {part_inst_name} :> {part_def};")
    elif topology.part_instances:
        lines.append(f"    // instance-only model: {topology.part_instances[0]}")
    else:
        lines.append("    // no part def found; behavioral harness is best-effort only")

    # Behavioral state-machine probe
    target_behaviors = request.target_behaviors or topology.state_machines
    lines.append("")
    lines.append("    action def SentinelBehaviorProbe {")
    if target_behaviors:
        sm = target_behaviors[0]
        lines.append(f"        // target state machine / behavior: {sm}")
        if part_def:
            lines.append(f"        in part subject :> {part_def};")
        lines.append("        // TODO: bind concrete incoming event trigger when kernel API is confirmed")
        lines.append('        // perform triggerEvent;')
    else:
        lines.append("        // no state machine extracted; placeholder behavioral trace")
        if part_def:
            lines.append(f"        in part subject :> {part_def};")
    lines.append("    }")
    lines.append("")
    lines.append("    action sentinelBehaviorRun : SentinelBehaviorProbe {")
    if part_def:
        lines.append(f"        in part subject = {part_inst_name};")
    lines.append("    }")

    # Parametric constraint probe
    sim = request.simulation_vectors or {}
    invariants = request.target_invariants or [c.name for c in topology.constraints]

    lines.append("")
    lines.append("    action def SentinelConstraintProbe {")
    if part_def:
        lines.append(f"        in part subject :> {part_def};")

    for key, value in sim.items():
        if isinstance(value, str):
            lines.append(f'        assign subject.{key} = "{value}";')
        else:
            lines.append(f"        assign subject.{key} = {value};")

    for attr in topology.attributes[:5]:
        if attr.name in sim:
            continue
        if sim:
            continue
        lines.append(f"        // attribute available: {attr.name}")

    for inv in invariants[:10]:
        lines.append(f"        assert {inv};")

    if topology.constraints and not invariants:
        for c in topology.constraints[:10]:
            lines.append(f"        assert {c.name};")

    if not invariants and not topology.constraints:
        lines.append("        // no constraints extracted; assert skipped")

    lines.append("    }")
    lines.append("")
    lines.append("    action sentinelConstraintRun : SentinelConstraintProbe {")
    if part_def:
        lines.append(f"        in part subject = {part_inst_name};")
    lines.append("    }")

    if pkg:
        lines.append(f"    // candidate root package: {pkg}")
    lines.append("}")

    return "\n".join(lines)


def build_consolidated_payload(
    candidate_sysml: str,
    harness_block: str,
) -> str:
    """Append synthesized harness to immutable candidate source."""
    base = candidate_sysml.rstrip()
    harness = harness_block.strip()
    return f"{base}\n\n{harness}\n"
