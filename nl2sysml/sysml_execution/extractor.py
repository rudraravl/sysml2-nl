"""Regex-based structural extraction from SysML v2 candidate text."""

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
    ExtractedSendAction,
    ExtractedStateMachine,
    ExtractedStateTransition,
    ExtractedTopology,
    ModelKind,
)

# Quoted 'name' or bare identifier
_ID = r"(?:'([^']+)'|([A-Za-z_][\w]*))"

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
_ACTION_USAGE_RE = re.compile(
    rf"^\s*action\s+{_ID}\s*:\s*{_ID}",
    re.MULTILINE,
)
_ACTION_USAGE_SIMPLE_RE = re.compile(
    rf"^\s*action\s+{_ID}\s*:\s*{_ID}\s*;",
    re.MULTILINE,
)
_PIN_RE = re.compile(
    rf"\b(in|out)\s+(?:(?:attribute|item|part|ref)\s+)?{_ID}"
    r"\s*(?::\s*([^=;{\n]+))?"
)
_ACCEPT_ACTION_RE = re.compile(
    rf"^\s*action\s+{_ID}\s+accept\s+(\w+)\s*:\s*(\w+)",
    re.MULTILINE,
)
_SEND_ACTION_RE = re.compile(
    rf"^\s*action\s+{_ID}\s+send\s+(\w+)",
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
_TRANSITION_RE = re.compile(
    rf"^\s*transition\s+({_ID})?\s*(?:first\s+(\S+)\s+)?(?:if\s+(.+?)\s+)?(?:accept\s+(\S+)\s+)?then\s+(\S+)",
    re.MULTILINE,
)
_EXHIBIT_STATE_RE = re.compile(
    rf"^\s*exhibit\s+state\s+(\w+)\s*:\s*{_ID}",
    re.MULTILINE,
)


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
    """Nearest enclosing package / part def / part / action def."""
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
        m = _STATE_DEF_RE.match(line)
        if m:
            return _id_from_match(m)
    return None


def _parse_pins(header: str) -> Tuple[List[str], List[str], dict]:
    ins: List[str] = []
    outs: List[str] = []
    input_types = {}
    for m in _PIN_RE.finditer(header):
        name = (m.group(2) or m.group(3) or "").strip()
        if m.group(1) == "in":
            ins.append(name)
            if m.group(4):
                input_types[name] = m.group(4).strip()
        else:
            outs.append(name)
    return ins, outs, input_types


def _has_default_value(line: str) -> bool:
    """True if attribute line contains a binding default (= ...)."""
    stripped = line.split("//", 1)[0]
    return bool(re.search(r"\s=\s", stripped))


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
        elif idx + 1 < len(lines) and "{" in lines[idx + 1]:
            end_idx = _brace_depth_at(lines, idx + 1)
            has_brace = True

        body = "\n".join(lines[idx : end_idx + 1]) if has_brace else line
        is_composite = has_brace and any(
            tok in body
            for tok in ("action ", "flow ", "first ", "bind ", "merge ", "accept ", "send ")
        )
        ins, outs, input_types = _parse_pins(line)
        if has_brace and not ins and not outs:
            for j in range(idx + 1, min(idx + 20, len(lines))):
                if "{" in lines[j] and j > idx:
                    break
                pin_ins, pin_outs, pin_types = _parse_pins(lines[j])
                ins.extend(pin_ins)
                outs.extend(pin_outs)
                input_types.update(pin_types)
        usages.append(
            ExtractedActionUsage(
                name=name,
                type_ref=type_ref or None,
                package_owner=_current_owner(lines, idx),
                is_composite=is_composite,
                inputs=ins,
                input_types=input_types,
                outputs=outs,
                raw_line=line.strip(),
            )
        )
    return usages


def _extract_state_machines(lines: List[str]) -> List[ExtractedStateMachine]:
    machines: List[ExtractedStateMachine] = []
    for idx, line in enumerate(lines):
        m = _STATE_DEF_RE.match(line)
        if not m:
            continue
        name = _id_from_match(m)
        end_idx = _brace_depth_at(lines, idx) if "{" in line else idx
        body_lines = lines[idx : end_idx + 1]
        transitions: List[ExtractedStateTransition] = []
        for body_idx, body_line in enumerate(body_lines):
            tm = _TRANSITION_RE.match(body_line)
            if not tm:
                continue
            trans_name = _id_from_match(tm) if tm.group(1) or tm.group(2) else None
            source = tm.group(3)
            if_cond = tm.group(4)
            accept_sig = tm.group(5)
            target = tm.group(6)
            trigger = accept_sig or if_cond
            trigger_kind = "accept" if accept_sig else ("if" if if_cond else None)
            transitions.append(
                ExtractedStateTransition(
                    name=trans_name,
                    source=source,
                    target=target,
                    trigger=trigger,
                    trigger_kind=trigger_kind,
                    owner=name,
                    raw_line=body_line.strip(),
                )
            )
        machines.append(
            ExtractedStateMachine(
                name=name,
                owner=_current_owner(lines, idx),
                transitions=transitions,
                raw_line=line.strip(),
            )
        )
    return machines


def extract_topology(candidate_sysml: str) -> ExtractedTopology:
    """
    Scan candidate text and extract packages, parts, attributes, actions, state machines, etc.
    Uses lightweight regex only; incomplete models still return partial topology.
    """
    text = candidate_sysml or ""
    lines = text.splitlines()

    root_package = _extract_root_package(text)
    packages = _dedupe_preserve_order(_ids_from_findall(_PACKAGE_RE.findall(text)))
    part_defs = _dedupe_preserve_order(_ids_from_findall(_PART_DEF_RE.findall(text)))

    attribute_defs: List[ExtractedAttributeDef] = []
    for idx, line in enumerate(lines):
        match = _ATTRIBUTE_DEF_RE.match(line)
        if match:
            attribute_defs.append(
                ExtractedAttributeDef(
                    name=_id_from_match(match),
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
                    has_default=_has_default_value(line),
                    raw_line=line.strip(),
                )
            )

    constraints: List[ExtractedConstraint] = []
    for idx, line in enumerate(lines):
        m = _CONSTRAINT_BLOCK_RE.match(line)
        if m:
            name = _id_from_match(m) if m.lastindex and (m.group(1) or m.group(2)) else ""
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

    state_machines = _extract_state_machines(lines)

    action_defs: List[ExtractedActionDef] = []
    for idx, line in enumerate(lines):
        m = _ACTION_DEF_RE.match(line)
        if not m:
            continue
        name = _id_from_match(m)
        ins, outs, input_types = _parse_pins(line)
        action_defs.append(
            ExtractedActionDef(
                name=name,
                inputs=ins,
                input_types=input_types,
                outputs=outs,
                owner=_current_owner(lines, idx),
                raw_line=line.strip(),
            )
        )

    action_usages = _find_composite_usages(lines)
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

    send_actions: List[ExtractedSendAction] = []
    for idx, line in enumerate(lines):
        m = _SEND_ACTION_RE.match(line)
        if m:
            send_actions.append(
                ExtractedSendAction(
                    action_name=_id_from_match(m),
                    signal_type=m.group(3),
                    owner=_current_owner(lines, idx),
                    raw_line=line.strip(),
                )
            )

    return ExtractedTopology(
        root_package=root_package,
        packages=packages,
        part_defs=part_defs,
        attributes=attributes,
        attribute_defs=attribute_defs,
        constraints=constraints,
        state_machines=state_machines,
        action_defs=action_defs,
        action_usages=action_usages,
        accept_actions=accept_actions,
        send_actions=send_actions,
    )


def classify_kind(topology: ExtractedTopology) -> ModelKind:
    """Classify model as behavioral, structural, or empty."""
    has_behavior = bool(
        topology.action_defs
        or topology.action_usages
        or topology.state_machines
        or topology.accept_actions
        or topology.send_actions
    )
    has_structure = bool(topology.part_defs or topology.constraints or topology.attributes)

    if has_behavior:
        return "behavioral"
    if has_structure:
        return "structural"
    return "empty"
