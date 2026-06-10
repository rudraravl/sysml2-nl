"""Phase 1: regex-based structural extraction from SysML v2 candidate text."""

from __future__ import annotations

import re
from typing import List, Optional, Tuple

from .models import (
    ExtractedAcceptAction,
    ExtractedActionDef,
    ExtractedActionUsage,
    ExtractedAttribute,
    ExtractedAttributeDef,
    ExtractedConstraint,
    ExtractedFlow,
    ExtractedSuccession,
    ExtractedTopology,
    ModelProfile,
)

# Quoted 'name' or bare identifier
_ID = r"(?:'([^']+)'|([A-Za-z_][\w]*))"
_ID_CAPTURE = re.compile(_ID)

_ROOT_PACKAGE_RE = re.compile(
    rf"^\s*package\s+{_ID}\s*\{{",
    re.MULTILINE,
)
_PACKAGE_RE = re.compile(
    rf"^\s*package\s+{_ID}",
    re.MULTILINE,
)
_PART_DEF_RE = re.compile(
    rf"^\s*part\s+def\s+{_ID}",
    re.MULTILINE,
)
_PART_INSTANCE_RE = re.compile(
    rf"^\s*part\s+{_ID}\s*:\s*>\s+{_ID}",
    re.MULTILINE,
)
_PART_SIMPLE_RE = re.compile(
    rf"^\s*part\s+{_ID}\s*(?:\{{|:)",
    re.MULTILINE,
)
_ATTRIBUTE_DEF_RE = re.compile(
    rf"^\s*attribute\s+def\s+{_ID}",
    re.MULTILINE,
)
_ATTRIBUTE_USAGE_RE = re.compile(
    rf"^\s*attribute\s+{_ID}\s*(?!def)",
    re.MULTILINE,
)
_ACTION_DEF_RE = re.compile(
    rf"^\s*action\s+def\s+{_ID}",
    re.MULTILINE,
)
_ACTION_DEF_HEADER_RE = re.compile(
    rf"^\s*action\s+def\s+{_ID}\s*\{{(.*)\}}\s*$",
    re.MULTILINE,
)
_ACTION_USAGE_RE = re.compile(
    rf"^\s*action\s+{_ID}\s*:\s*{_ID}",
    re.MULTILINE,
)
_ACTION_USAGE_SIMPLE_RE = re.compile(
    rf"^\s*action\s+{_ID}\s*:\s*{_ID}\s*;",
    re.MULTILINE,
)
_PIN_RE = re.compile(r"\b(in|out)\s+(\w+)\s*:")
_ACCEPT_ACTION_RE = re.compile(
    rf"^\s*action\s+{_ID}\s+accept\s+(\w+)\s*:\s*(\w+)",
    re.MULTILINE,
)
_FLOW_RE = re.compile(
    r"^\s*flow\s+(.+?)\s+to\s+(.+?)\s*(?:\{|;)",
    re.MULTILINE,
)
_SUCCESSION_RE = re.compile(
    rf"^\s*first\s+(.+?)\s+then\s+(.+?)\s*(?:\{{|;)",
    re.MULTILINE,
)
_CONSTRAINT_BLOCK_RE = re.compile(
    rf"^\s*(?:require\s+)?constraint\s+{_ID}?",
    re.MULTILINE,
)
_ASSERT_CONSTRAINT_RE = re.compile(
    r"^\s*assert\s+constraint",
    re.MULTILINE,
)
_STATE_DEF_RE = re.compile(
    rf"^\s*state\s+def\s+{_ID}",
    re.MULTILINE,
)
_STATE_INSTANCE_RE = re.compile(
    rf"^\s*state\s+{_ID}\s*:",
    re.MULTILINE,
)
_STATE_MACHINE_RE = re.compile(
    rf"^\s*state\s+{_ID}\s*\{{",
    re.MULTILINE,
)
_ACTION_DEF_LINE_RE = re.compile(
    rf"^\s*action\s+def\s+{_ID}",
    re.MULTILINE,
)
_ACTION_USAGE_LINE_RE = re.compile(
    rf"^\s*action\s+{_ID}",
    re.MULTILINE,
)
_TOOL_EXECUTION_RE = re.compile(r"metadata\s+ToolExecution", re.MULTILINE)


def _id_from_match(m: re.Match) -> str:
    return (m.group(1) or m.group(2) or "").strip()


def _ids_from_findall(rows: List[Tuple[str, ...]]) -> List[str]:
    out: List[str] = []
    for row in rows:
        for i in range(0, len(row), 2):
            if i + 1 < len(row):
                name = (row[i] or row[i + 1] or "").strip()
            else:
                name = (row[i] or "").strip()
            if name:
                out.append(name)
                break
    return out


def _dedupe_preserve_order(items: List[str]) -> List[str]:
    seen = set()
    out: List[str] = []
    for item in items:
        if item not in seen:
            seen.add(item)
            out.append(item)
    return out


def _brace_depth_at(lines: List[str], start: int) -> int:
    depth = 0
    for i in range(start, len(lines)):
        depth += lines[i].count("{") - lines[i].count("}")
        if depth <= 0 and i > start:
            return i
    return len(lines) - 1


def _current_owner(lines: List[str], line_index: int) -> Optional[str]:
    """Nearest enclosing package / part def / part (not nested action usages)."""
    for i in range(line_index, -1, -1):
        line = lines[i]
        m = _PACKAGE_RE.match(line)
        if m:
            return _id_from_match(m)
        m = _PART_DEF_RE.match(line)
        if m:
            return _id_from_match(m)
        m = _PART_INSTANCE_RE.match(line) or _PART_SIMPLE_RE.match(line)
        if m:
            return _id_from_match(m)
        m = _ACTION_DEF_RE.match(line)
        if m:
            return _id_from_match(m)
    return None


def _parse_pins(header: str) -> Tuple[List[str], List[str]]:
    ins: List[str] = []
    outs: List[str] = []
    for m in _PIN_RE.finditer(header):
        if m.group(1) == "in":
            ins.append(m.group(2))
        else:
            outs.append(m.group(2))
    return ins, outs


def _extract_root_package(text: str) -> Optional[str]:
    m = _ROOT_PACKAGE_RE.search(text)
    if m:
        return _id_from_match(m)
    m = _PACKAGE_RE.search(text)
    if m:
        return _id_from_match(m)
    return None


def _find_composite_usages(lines: List[str]) -> List[ExtractedActionUsage]:
    usages: List[ExtractedActionUsage] = []
    for idx, line in enumerate(lines):
        m = _ACTION_USAGE_RE.match(line)
        if not m:
            continue
        name = _id_from_match(m)
        type_ref = (m.group(3) or m.group(4) or "").strip()
        has_brace = "{" in line
        end_idx = idx
        if has_brace:
            end_idx = _brace_depth_at(lines, idx)
        else:
            # check next line for opening brace
            if idx + 1 < len(lines) and "{" in lines[idx + 1]:
                end_idx = _brace_depth_at(lines, idx + 1)
                has_brace = True

        body = "\n".join(lines[idx : end_idx + 1]) if has_brace else line
        is_composite = has_brace and any(
            tok in body
            for tok in ("action ", "flow ", "first ", "bind ", "merge ", "accept ")
        )
        ins, outs = _parse_pins(line)
        if has_brace and not ins and not outs:
            for j in range(idx + 1, min(idx + 20, len(lines))):
                if "{" in lines[j] and j > idx:
                    break
                pin_ins, pin_outs = _parse_pins(lines[j])
                ins.extend(pin_ins)
                outs.extend(pin_outs)
        usages.append(
            ExtractedActionUsage(
                name=name,
                type_ref=type_ref or None,
                package_owner=_current_owner(lines, idx),
                is_composite=is_composite,
                inputs=ins,
                outputs=outs,
                raw_line=line.strip(),
            )
        )
    return usages


def extract_topology(candidate_sysml: str) -> ExtractedTopology:
    """
    Scan candidate text and extract packages, parts, attributes, actions, flows, etc.
    Uses lightweight regex only; incomplete models still return partial topology.
    """
    text = candidate_sysml or ""
    lines = text.splitlines()

    root_package = _extract_root_package(text)
    packages = _dedupe_preserve_order(_ids_from_findall(_PACKAGE_RE.findall(text)))
    part_defs = _dedupe_preserve_order(_ids_from_findall(_PART_DEF_RE.findall(text)))
    part_def_owners = {}
    for idx, line in enumerate(lines):
        match = _PART_DEF_RE.match(line)
        if match:
            owner = _current_owner(lines, idx - 1)
            if owner:
                part_def_owners[_id_from_match(match)] = owner

    part_instances: List[str] = []
    for row in _PART_INSTANCE_RE.findall(text):
        name = (row[0] or row[1] or "").strip()
        if name:
            part_instances.append(name)
    for row in _PART_SIMPLE_RE.findall(text):
        name = (row[0] or row[1] or "").strip()
        if name and name not in part_defs:
            part_instances.append(name)
    part_instances = _dedupe_preserve_order(part_instances)

    attribute_defs: List[ExtractedAttributeDef] = []
    for idx, line in enumerate(lines):
        m = _ATTRIBUTE_DEF_RE.match(line)
        if m:
            attribute_defs.append(
                ExtractedAttributeDef(
                    name=_id_from_match(m),
                    owner=_current_owner(lines, idx),
                    raw_line=line.strip(),
                )
            )

    attributes: List[ExtractedAttribute] = []
    for idx, line in enumerate(lines):
        if _ATTRIBUTE_DEF_RE.match(line):
            continue
        m = _ATTRIBUTE_USAGE_RE.match(line)
        if m:
            attributes.append(
                ExtractedAttribute(
                    name=_id_from_match(m),
                    owner=_current_owner(lines, idx),
                    raw_line=line.strip(),
                )
            )

    constraints: List[ExtractedConstraint] = []
    for idx, line in enumerate(lines):
        m = _CONSTRAINT_BLOCK_RE.match(line)
        if m:
            name = _id_from_match(m) if m.lastindex and m.group(1) or m.group(2) else ""
            if not name:
                name = f"constraint_{idx}"
            constraints.append(
                ExtractedConstraint(
                    name=name,
                    owner=_current_owner(lines, idx),
                    raw_line=line.strip(),
                )
            )
        elif _ASSERT_CONSTRAINT_RE.match(line):
            constraints.append(
                ExtractedConstraint(
                    name=f"assert_constraint_{idx}",
                    owner=_current_owner(lines, idx),
                    raw_line=line.strip(),
                )
            )

    state_machines = _dedupe_preserve_order(
        _ids_from_findall(_STATE_DEF_RE.findall(text))
        + _ids_from_findall(_STATE_INSTANCE_RE.findall(text))
        + _ids_from_findall(_STATE_MACHINE_RE.findall(text))
    )

    action_defs: List[ExtractedActionDef] = []
    for idx, line in enumerate(lines):
        m = _ACTION_DEF_RE.match(line)
        if not m:
            continue
        name = _id_from_match(m)
        ins, outs = _parse_pins(line)
        has_tool = bool(_TOOL_EXECUTION_RE.search(line))
        if not has_tool and idx + 1 < len(lines):
            end = min(idx + 15, len(lines))
            has_tool = bool(_TOOL_EXECUTION_RE.search("\n".join(lines[idx:end])))
        action_defs.append(
            ExtractedActionDef(
                name=name,
                inputs=ins,
                outputs=outs,
                owner=_current_owner(lines, idx),
                raw_line=line.strip(),
                has_tool_execution=has_tool,
            )
        )

    action_usages = _find_composite_usages(lines)
    # Also pick up simple action usages without composite body
    for idx, line in enumerate(lines):
        m = _ACTION_USAGE_SIMPLE_RE.match(line)
        if m:
            name = _id_from_match(m)
            if not any(u.name == name for u in action_usages):
                type_ref = (m.group(3) or m.group(4) or "").strip()
                action_usages.append(
                    ExtractedActionUsage(
                        name=name,
                        type_ref=type_ref or None,
                        package_owner=_current_owner(lines, idx),
                        is_composite=False,
                        raw_line=line.strip(),
                    )
                )

    accept_actions: List[ExtractedAcceptAction] = []
    for idx, line in enumerate(lines):
        m = _ACCEPT_ACTION_RE.match(line)
        if m:
            accept_actions.append(
                ExtractedAcceptAction(
                    action_name=_id_from_match(m),
                    signal_param=m.group(3),
                    signal_type=m.group(4),
                    owner=_current_owner(lines, idx),
                    raw_line=line.strip(),
                )
            )

    flows: List[ExtractedFlow] = []
    for idx, line in enumerate(lines):
        m = _FLOW_RE.match(line)
        if m:
            flows.append(
                ExtractedFlow(
                    source=m.group(1).strip(),
                    target=m.group(2).strip(),
                    owner=_current_owner(lines, idx),
                    raw_line=line.strip(),
                )
            )

    successions: List[ExtractedSuccession] = []
    for idx, line in enumerate(lines):
        m = _SUCCESSION_RE.match(line)
        if m:
            successions.append(
                ExtractedSuccession(
                    source=m.group(1).strip(),
                    target=m.group(2).strip(),
                    owner=_current_owner(lines, idx),
                    raw_line=line.strip(),
                )
            )

    action_names = _dedupe_preserve_order(
        [d.name for d in action_defs] + [u.name for u in action_usages]
    )
    has_tool = any(d.has_tool_execution for d in action_defs) or bool(
        _TOOL_EXECUTION_RE.search(text)
    )

    return ExtractedTopology(
        root_package=root_package,
        packages=packages,
        part_defs=part_defs,
        part_def_owners=part_def_owners,
        part_instances=part_instances,
        attributes=attributes,
        attribute_defs=attribute_defs,
        constraints=constraints,
        state_machines=state_machines,
        actions=action_names,
        action_defs=action_defs,
        action_usages=action_usages,
        accept_actions=accept_actions,
        flows=flows,
        successions=successions,
        has_tool_execution_metadata=has_tool,
    )


def classify_topology(topology: ExtractedTopology) -> ModelProfile:
    """Classify model for harness profile selection."""
    if topology.has_tool_execution_metadata and not topology.part_defs:
        if not topology.action_usages or all(
            not u.is_composite for u in topology.action_usages
        ):
            return ModelProfile.ANALYSIS_TOOL

    composites = [u for u in topology.action_usages if u.is_composite]
    if composites and not topology.part_defs:
        return ModelProfile.ACTION_COMPOSITE

    if topology.part_defs or topology.state_machines:
        return ModelProfile.PART_STATE

    if (
        topology.action_defs
        or topology.action_usages
        or topology.state_machines
        or topology.constraints
    ):
        if composites:
            return ModelProfile.ACTION_COMPOSITE
        return ModelProfile.PART_STATE

    return ModelProfile.STRUCTURAL_ONLY


def requires_layer2(topology: ExtractedTopology, profile: ModelProfile) -> bool:
    if profile in (ModelProfile.PART_STATE, ModelProfile.ACTION_COMPOSITE):
        return True
    if topology.constraints:
        return True
    if topology.action_defs or topology.action_usages:
        return True
    if topology.state_machines:
        return True
    return False
