"""Regex-based structural extraction from SysML v2 candidate text."""

from __future__ import annotations

import re
from typing import List, Optional, Tuple

from .models import (
    ExtractedAcceptAction,
    ExtractedAcceptTrigger,
    ExtractedActionDef,
    ExtractedActionUsage,
    ExtractedAttribute,
    ExtractedAttributeDef,
    ExtractedAttributeMember,
    ExtractedConstraint,
    ExtractedEnumDef,
    ExtractedItemDef,
    ExtractedPartBehavior,
    ExtractedSendAction,
    ExtractedStateMachine,
    ExtractedStateTransition,
    ExtractedTopology,
    GuardCondition,
    ModelKind,
)

# Quoted 'name' or bare identifier
_ID = r"(?:'([^']+)'|([A-Za-z_][\w]*))"

_ROOT_PACKAGE_RE = re.compile(
    rf"^\s*package\s+{_ID}\s*\{{",
    re.MULTILINE,
)
_IMPORT_RE = re.compile(
    r"^\s*(?:(?P<visibility>public|private)\s+)?import\s+(?P<target>.+?)\s*;\s*$",
)
_PACKAGE_RE = re.compile(
    rf"^\s*package\s+{_ID}",
    re.MULTILINE,
)
_PART_DEF_RE = re.compile(
    rf"^\s*part\s+def\s+{_ID}",
    re.MULTILINE,
)
# Matches shorthand `part X {` (no `: TypeRef`) — these are part *usages*
# (instances), not formal `part def` blueprints.
_PART_SHORTHAND_DEF_RE = re.compile(
    rf"^\s*part\s+{_ID}\s*\{{",
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
    rf"^\s*attribute\s+def\s+{_ID}(?:\s*(?::>|:)\s*([^=;{{\n]+))?",
    re.MULTILINE,
)
_ATTRIBUTE_USAGE_RE = re.compile(
    rf"^\s*attribute\s+(?:(?:redefines|:>>)\s+)?{_ID}\s*(?!def)(?::\s*([^=;{{\n]+))?",
    re.MULTILINE,
)
_ITEM_DEF_RE = re.compile(
    rf"^\s*item\s+def\s+{_ID}",
    re.MULTILINE,
)
_ENUM_DEF_RE = re.compile(
    rf"^\s*enum\s+def\s+{_ID}",
    re.MULTILINE,
)
_ENUM_LITERAL_RE = re.compile(
    rf"^\s*(?:enum\s+)?{_ID}\s*;?\s*$",
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
    rf"^\s*action\s+{_ID}\s+accept\s+{_ID}\s*:\s*{_ID}(?:\s+via\s+{_ID})?",
    re.MULTILINE,
)
_ACCEPT_ACTION_BODY_RE = re.compile(
    rf"action\s+{_ID}\s+accept\s+{_ID}\s*:\s*{_ID}(?:\s+via\s+{_ID})?",
)
_ACCEPT_PARAM_TYPE_BODY_RE = re.compile(
    rf"accept\s+{_ID}\s*:\s*{_ID}(?:\s+via\s+{_ID})?",
)
_ACCEPT_TYPE_VIA_BODY_RE = re.compile(
    rf"accept\s+{_ID}\s+via\s+{_ID}",
)
_ACCEPT_TYPE_ONLY_BODY_RE = re.compile(
    rf"accept\s+{_ID}\s*;",
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
# Matches a single logical `transition ...;` statement. Callers must first join
# multi-line transition statements (see `_merge_transition_statements`) since
# `first`/`if`/`accept`/`then` clauses may each sit on their own physical line.
_TRANSITION_RE = re.compile(
    r"^\s*transition\s+(?P<name>[A-Za-z_]\w*)?\s*"
    r"(?:first\s+(?P<source>\S+)\s+)?"
    r"(?:if\s+(?P<if_cond>.+?)\s+)?"
    r"(?:accept\s+(?P<accept_sig>\S+?)(?:\s*\[\s*(?P<accept_guard>[^\]]+?)\s*\])?\s+)?"
    r"then\s+(?P<target>[A-Za-z_]\w*)\s*;?\s*$",
    re.MULTILINE,
)
_TRANSITION_START_RE = re.compile(r"^\s*transition\b")
_ENTRY_STATE_RE = re.compile(r"\bentry\s*;\s*then\s+([A-Za-z_]\w*)\s*;")
_EXHIBIT_STATE_RE = re.compile(
    rf"^\s*exhibit\s+state\s+(\w+)\s*:\s*{_ID}",
    re.MULTILINE,
)
_PERFORM_ACTION_RE = re.compile(
    rf"^\s*perform\s+action\s+{_ID}\s*:\s*{_ID}",
    re.MULTILINE,
)
_GUARD_CONDITION_RE = re.compile(
    r"^\s*([A-Za-z_]\w*)\s*(>=|<=|==|>|<)\s*(-?\d+(?:\.\d+)?)\s*$"
)


def _id_from_match(m: re.Match) -> str:
    return (m.group(1) or m.group(2) or "").strip()


def _id_at(m: re.Match, pair_index: int) -> str:
    """Resolve identifier from the nth _ID capture pair (1-based) in a regex match."""
    base = pair_index * 2 - 1
    return (m.group(base) or m.group(base + 1) or "").strip()


def _optional_id_at(m: re.Match, pair_index: int) -> Optional[str]:
    value = _id_at(m, pair_index)
    return value or None


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
        if depth <= 0 and ("{" in lines[start] or i > start):
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
        type_ref = m.group(4).strip() if m.group(4) else ""
        if type_ref.startswith(">>"):
            continue
        if m.group(1) == "in":
            ins.append(name)
            if type_ref:
                input_types[name] = type_ref
        else:
            outs.append(name)
    return ins, outs, input_types


def _has_default_value(line: str) -> bool:
    """True if attribute line contains a binding default (= ...)."""
    stripped = line.split("//", 1)[0]
    return bool(re.search(r"\s=\s", stripped))


def _extract_default_value(line: str) -> Optional[str]:
    """Return a simple default expression from `= value` when present."""
    stripped = line.split("//", 1)[0]
    match = re.search(r"\s=\s*(.+?)(?:;|\{|$)", stripped)
    if not match:
        return None
    value = match.group(1).strip()
    return value or None


def _clean_type_ref(type_ref: Optional[str]) -> Optional[str]:
    if not type_ref:
        return None
    return type_ref.strip().rstrip(";").strip()


def _extract_root_package(text: str) -> Optional[str]:
    m = _ROOT_PACKAGE_RE.search(text)
    if m:
        return _id_from_match(m)
    m = _PACKAGE_RE.search(text)
    if m:
        return _id_from_match(m)
    return None


def _extract_root_package_imports(text: str) -> List[str]:
    """Return import statements declared directly in the root package body.

    Nested package imports (e.g. inside ``Definitions``) are excluded. The harness
    needs the same external library imports as the candidate so value types like
    ``LengthValue`` resolve when referenced in orchestrator fixtures.
    """
    m = _ROOT_PACKAGE_RE.search(text)
    if not m:
        return []
    lines = text.splitlines()
    start_line = text[: m.start()].count("\n")
    imports: List[str] = []
    depth = 0
    for i, line in enumerate(lines):
        if i < start_line:
            continue
        for ch in line:
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
        if i == start_line:
            continue
        if depth == 1:
            im = _IMPORT_RE.match(line)
            if im:
                visibility = im.group("visibility") or "private"
                imports.append(f"{visibility} import {im.group('target').strip()};")
        elif depth == 0 and i > start_line:
            break
    return _dedupe_preserve_order(imports)


def _match_accept_trigger_line(line: str) -> Optional[ExtractedAcceptTrigger]:
    """Match one accept blocker line (action accept, param:type, type via port, type only)."""
    stripped = line.strip()
    if not stripped or stripped.startswith("//") or stripped.startswith("/*"):
        return None

    m = _ACCEPT_ACTION_BODY_RE.search(line)
    if m:
        return ExtractedAcceptTrigger(
            payload_type=_id_at(m, 3),
            param=_optional_id_at(m, 2),
            port=_optional_id_at(m, 4),
            raw_line=stripped,
        )

    m = _ACCEPT_PARAM_TYPE_BODY_RE.search(line)
    if m:
        return ExtractedAcceptTrigger(
            payload_type=_id_at(m, 2),
            param=_optional_id_at(m, 1),
            port=_optional_id_at(m, 3),
            raw_line=stripped,
        )

    m = _ACCEPT_TYPE_VIA_BODY_RE.search(line)
    if m:
        return ExtractedAcceptTrigger(
            payload_type=_id_at(m, 1),
            port=_optional_id_at(m, 2),
            raw_line=stripped,
        )

    m = _ACCEPT_TYPE_ONLY_BODY_RE.search(line)
    if m:
        return ExtractedAcceptTrigger(
            payload_type=_id_at(m, 1),
            raw_line=stripped,
        )

    return None


def _extract_required_triggers(body: str) -> List[ExtractedAcceptTrigger]:
    triggers: List[ExtractedAcceptTrigger] = []
    for line in body.splitlines():
        record = _match_accept_trigger_line(line)
        if record:
            triggers.append(record)
    return triggers


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
            for j in range(idx + 1, end_idx + 1):
                if "{" in lines[j] and j > idx:
                    break
                pin_ins, pin_outs, pin_types = _parse_pins(lines[j])
                ins.extend(pin_ins)
                outs.extend(pin_outs)
                input_types.update(pin_types)
        required_triggers = _extract_required_triggers(body) if has_brace else []
        enclosing_part = _enclosing_part_def(lines, idx)
        usages.append(
            ExtractedActionUsage(
                name=name,
                type_ref=type_ref or None,
                package_owner=_current_owner(lines, idx),
                is_composite=is_composite,
                inputs=ins,
                input_types=input_types,
                outputs=outs,
                required_triggers=required_triggers,
                enclosing_part_def=enclosing_part,
                raw_line=line.strip(),
            )
        )
    return usages


def _extract_attribute_members(lines: List[str], start: int, end: int) -> List[ExtractedAttributeMember]:
    members: List[ExtractedAttributeMember] = []
    for line in lines[start + 1 : end + 1]:
        if _ATTRIBUTE_DEF_RE.match(line):
            continue
        match = _ATTRIBUTE_USAGE_RE.match(line)
        if not match:
            continue
        members.append(
            ExtractedAttributeMember(
                name=_id_from_match(match),
                type_name=_clean_type_ref(match.group(3)),
                has_default=_has_default_value(line),
                default_value=_extract_default_value(line),
                raw_line=line.strip(),
            )
        )
    return members


def _extract_enum_literals(lines: List[str], start: int, end: int) -> List[str]:
    literals: List[str] = []
    for line in lines[start + 1 : end + 1]:
        stripped = line.strip()
        if not stripped or stripped in ("{", "}") or stripped.startswith("//"):
            continue
        match = _ENUM_LITERAL_RE.match(line)
        if match:
            literal = _id_from_match(match)
            if literal and literal not in literals:
                literals.append(literal)
    return literals


def _extract_part_behaviors(lines: List[str]) -> List[ExtractedPartBehavior]:
    """Scan part definitions for `perform action` and `exhibit state` entry points."""
    behaviors: List[ExtractedPartBehavior] = []
    for idx, line in enumerate(lines):
        match = _PART_DEF_RE.match(line)
        if not match:
            continue
        part_def = _id_from_match(match)
        end_idx = _brace_depth_at(lines, idx) if "{" in line else idx
        body = "\n".join(lines[idx : end_idx + 1])
        for body_line in body.splitlines():
            exhibit = _EXHIBIT_STATE_RE.match(body_line)
            if exhibit:
                behaviors.append(
                    ExtractedPartBehavior(
                        part_def=part_def,
                        usage_name=exhibit.group(1),
                        kind="exhibit_state",
                        type_ref=(exhibit.group(2) or exhibit.group(3) or "").strip() or None,
                        raw_line=body_line.strip(),
                    )
                )
                continue
            perform = _PERFORM_ACTION_RE.match(body_line)
            if perform:
                behaviors.append(
                    ExtractedPartBehavior(
                        part_def=part_def,
                        usage_name=_id_at(perform, 1),
                        kind="perform_action",
                        type_ref=_id_at(perform, 2) or None,
                        raw_line=body_line.strip(),
                    )
                )
    return behaviors


def _merge_transition_statements(body_lines: List[str]) -> List[str]:
    """Join multi-line `transition ...;` statements into single logical lines.

    Real-world state machines spread `first`/`if`/`accept`/`then` clauses across
    several physical lines (see dataset/data/000600), but `_TRANSITION_RE` matches
    one logical line at a time.
    """
    merged: List[str] = []
    i = 0
    while i < len(body_lines):
        line = body_lines[i]
        if _TRANSITION_START_RE.match(line):
            parts = [line.strip()]
            while not parts[-1].endswith(";") and i + 1 < len(body_lines):
                i += 1
                parts.append(body_lines[i].strip())
            merged.append(" ".join(p for p in parts if p))
        else:
            merged.append(line)
        i += 1
    return merged


def _parse_guard_condition(guard: Optional[str]) -> Optional[GuardCondition]:
    """Parse a simple numeric guard (`voltage > 10.0`) into a GuardCondition."""
    if not guard:
        return None
    m = _GUARD_CONDITION_RE.match(guard)
    if not m:
        return None
    return GuardCondition(attribute=m.group(1), operator=m.group(2), value=float(m.group(3)))


def _extract_entry_state(body_text: str) -> Optional[str]:
    m = _ENTRY_STATE_RE.search(body_text)
    return m.group(1) if m else None


def _extract_state_machines(lines: List[str]) -> List[ExtractedStateMachine]:
    machines: List[ExtractedStateMachine] = []
    for idx, line in enumerate(lines):
        m = _STATE_DEF_RE.match(line)
        if not m:
            continue
        name = _id_from_match(m)
        end_idx = _brace_depth_at(lines, idx) if "{" in line else idx
        body_lines = lines[idx : end_idx + 1]
        entry_state = _extract_entry_state("\n".join(body_lines))

        transitions: List[ExtractedStateTransition] = []
        for body_line in _merge_transition_statements(body_lines):
            tm = _TRANSITION_RE.match(body_line)
            if not tm:
                continue
            trans_name = tm.group("name")
            source = tm.group("source")
            if_cond = tm.group("if_cond")
            accept_sig = tm.group("accept_sig")
            accept_guard = tm.group("accept_guard")
            target = tm.group("target")
            trigger = accept_sig or if_cond
            trigger_kind = "accept" if accept_sig else ("if" if if_cond else None)
            transitions.append(
                ExtractedStateTransition(
                    name=trans_name,
                    source=source,
                    target=target,
                    trigger=trigger,
                    trigger_kind=trigger_kind,
                    guard=accept_guard,
                    guard_condition=_parse_guard_condition(accept_guard),
                    owner=name,
                    raw_line=body_line.strip(),
                )
            )
        machines.append(
            ExtractedStateMachine(
                name=name,
                owner=_current_owner(lines, idx),
                transitions=transitions,
                entry_state=entry_state,
                raw_line=line.strip(),
            )
        )
    return machines


def ordered_transition_path(sm: ExtractedStateMachine) -> List[ExtractedStateTransition]:
    """Walk the transition graph from the entry state in chronological order.

    Prefers an `accept`-triggered outgoing edge per state (since that is what a
    harness can actually drive via `send`), falling back to the first declared
    edge otherwise. Stops on a revisited state (cycle) or a dead end. Branching
    topologies only exercise one path per call — this is an MVP heuristic, not a
    full state-space exploration.
    """
    if not sm.transitions:
        return []

    by_source: dict[str, List[ExtractedStateTransition]] = {}
    for t in sm.transitions:
        if t.source:
            by_source.setdefault(t.source, []).append(t)

    current = sm.entry_state or sm.transitions[0].source
    visited: set[str] = set()
    path: List[ExtractedStateTransition] = []

    while current and current not in visited:
        visited.add(current)
        edges = by_source.get(current)
        if not edges:
            break
        edge = next((e for e in edges if e.trigger_kind == "accept"), edges[0])
        path.append(edge)
        current = edge.target

    return path


def _open_brace_stack_at(lines: List[str], line_index: int) -> List[int]:
    """Return line indices whose `{` is still open (unmatched) at `line_index`."""
    stack: List[int] = []
    for i in range(0, line_index + 1):
        for ch in lines[i]:
            if ch == "{":
                stack.append(i)
            elif ch == "}" and stack:
                stack.pop()
    return stack


def _enclosing_named_owner(lines: List[str], line_index: int) -> Optional[str]:
    """Brace-depth-aware nearest enclosing package/part def/part/action def name.

    Unlike `_current_owner` (a naive nearest-preceding-line scan, which mistakes
    one-line sibling declarations like `part power : PowerSupply;` for an
    enclosing scope), this walks the actual open-brace stack so it correctly
    resolves ownership even when many sibling usages sit between the enclosing
    def and the target line.
    """
    for open_idx in reversed(_open_brace_stack_at(lines, line_index)):
        line = lines[open_idx]
        for matcher in (
            _PACKAGE_RE,
            _PART_DEF_RE,
            _PART_INSTANCE_RE,
            _PART_SIMPLE_RE,
            _ACTION_DEF_RE,
            _STATE_DEF_RE,
        ):
            m = matcher.match(line)
            if m:
                return _id_from_match(m)
    return None


def _enclosing_part_def(lines: List[str], line_index: int) -> Optional[str]:
    """Return the name of the nearest enclosing part (formal def or shorthand usage).

    Returns a name when the enclosing brace belongs to:
    - `part def X {` — explicit definition
    - `part X {`     — shorthand usage/instance (no `: TypeRef`)

    Typed part instances (`part x : Type {`) are excluded: their type is already
    named elsewhere, and the harness should target that type (or the usage if it
    is the owner of nested behavior).
    """
    for open_idx in reversed(_open_brace_stack_at(lines, line_index)):
        line = lines[open_idx]
        m = _PART_DEF_RE.match(line)
        if m:
            return _id_from_match(m)
        m = _PART_SHORTHAND_DEF_RE.match(line)
        if m:
            name = _id_from_match(m)
            # Recheck the raw line: reject `part name : SomeThing {`
            if not re.search(rf"^\s*part\s+{_ID}\s*:", line):
                return name
    return None


def _link_state_machine_instances(lines: List[str], machines: List[ExtractedStateMachine]) -> None:
    """Resolve `exhibit state <usage> : <SMDef>;` to the owning part/usage name."""
    if not machines:
        return
    by_name = {m.name: m for m in machines}
    for idx, line in enumerate(lines):
        m = _EXHIBIT_STATE_RE.match(line)
        if not m:
            continue
        sm_def_name = (m.group(2) or m.group(3) or "").strip()
        sm = by_name.get(sm_def_name)
        if sm is not None:
            sm.instance_name = _enclosing_named_owner(lines, idx)


def extract_topology(candidate_sysml: str) -> ExtractedTopology:
    """
    Scan candidate text and extract packages, parts, attributes, actions, state machines, etc.
    Uses lightweight regex only; incomplete models still return partial topology.
    """
    text = candidate_sysml or ""
    lines = text.splitlines()

    root_package = _extract_root_package(text)
    root_imports = _extract_root_package_imports(text)
    packages = _dedupe_preserve_order(_ids_from_findall(_PACKAGE_RE.findall(text)))

    # Formal `part def X` are typing blueprints; shorthand `part X {` are instances.
    # Keep both in part_defs for structure/behavior targeting; formal_part_defs is
    # used by the harness to choose `:` typing vs `=` aliasing.
    formal_part_defs = _dedupe_preserve_order(_ids_from_findall(_PART_DEF_RE.findall(text)))
    _shorthand_part_usages: List[str] = []
    for line in lines:
        m = _PART_SHORTHAND_DEF_RE.match(line)
        if m and not re.search(rf"^\s*part\s+{_ID}\s*:", line):
            _shorthand_part_usages.append(_id_from_match(m))
    part_defs = _dedupe_preserve_order(formal_part_defs + _shorthand_part_usages)

    attribute_defs: List[ExtractedAttributeDef] = []
    for idx, line in enumerate(lines):
        match = _ATTRIBUTE_DEF_RE.match(line)
        if match:
            end_idx = _brace_depth_at(lines, idx) if "{" in line else idx
            attribute_defs.append(
                ExtractedAttributeDef(
                    name=_id_from_match(match),
                    owner=_current_owner(lines, idx),
                    base_type=_clean_type_ref(match.group(3)),
                    members=_extract_attribute_members(lines, idx, end_idx),
                    raw_line=line.strip(),
                )
            )

    enum_defs: List[ExtractedEnumDef] = []
    for idx, line in enumerate(lines):
        match = _ENUM_DEF_RE.match(line)
        if match:
            end_idx = _brace_depth_at(lines, idx) if "{" in line else idx
            enum_defs.append(
                ExtractedEnumDef(
                    name=_id_from_match(match),
                    owner=_current_owner(lines, idx),
                    literals=_extract_enum_literals(lines, idx, end_idx),
                    raw_line=line.strip(),
                )
            )

    item_defs: List[ExtractedItemDef] = []
    for idx, line in enumerate(lines):
        match = _ITEM_DEF_RE.match(line)
        if match:
            end_idx = _brace_depth_at(lines, idx) if "{" in line else idx
            item_defs.append(
                ExtractedItemDef(
                    name=_id_from_match(match),
                    owner=_current_owner(lines, idx),
                    members=_extract_attribute_members(lines, idx, end_idx),
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
                    type_name=_clean_type_ref(m.group(3)),
                    has_default=_has_default_value(line),
                    default_value=_extract_default_value(line),
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
    _link_state_machine_instances(lines, state_machines)

    action_defs: List[ExtractedActionDef] = []
    for idx, line in enumerate(lines):
        m = _ACTION_DEF_RE.match(line)
        if not m:
            continue
        name = _id_from_match(m)
        ins, outs, input_types = _parse_pins(line)
        required_triggers: List[ExtractedAcceptTrigger] = []
        if "{" in line:
            end_idx = _brace_depth_at(lines, idx)
            body = "\n".join(lines[idx : end_idx + 1])
            required_triggers = _extract_required_triggers(body)
            for body_line in lines[idx + 1 : end_idx + 1]:
                pin_ins, pin_outs, pin_types = _parse_pins(body_line)
                ins.extend(pin_ins)
                outs.extend(pin_outs)
                input_types.update(pin_types)
        elif idx + 1 < len(lines) and "{" in lines[idx + 1]:
            end_idx = _brace_depth_at(lines, idx + 1)
            body = "\n".join(lines[idx : end_idx + 1])
            required_triggers = _extract_required_triggers(body)
            for body_line in lines[idx + 1 : end_idx + 1]:
                pin_ins, pin_outs, pin_types = _parse_pins(body_line)
                ins.extend(pin_ins)
                outs.extend(pin_outs)
                input_types.update(pin_types)
        action_defs.append(
            ExtractedActionDef(
                name=name,
                inputs=ins,
                input_types=input_types,
                outputs=outs,
                required_triggers=required_triggers,
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
                    signal_param=_id_at(m, 2),
                    signal_type=_id_at(m, 3),
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

    part_behaviors = _extract_part_behaviors(lines)

    return ExtractedTopology(
        root_package=root_package,
        root_imports=root_imports,
        packages=packages,
        part_defs=part_defs,
        formal_part_defs=formal_part_defs,
        attributes=attributes,
        attribute_defs=attribute_defs,
        enum_defs=enum_defs,
        item_defs=item_defs,
        constraints=constraints,
        state_machines=state_machines,
        action_defs=action_defs,
        action_usages=action_usages,
        accept_actions=accept_actions,
        send_actions=send_actions,
        part_behaviors=part_behaviors,
    )


def collect_state_machine_accept_payloads(topology: ExtractedTopology) -> List[str]:
    """Return deduped accept payload type names from all state machine transitions.

    Scans every transition in every extracted state machine (not just the ordered
    execution path) so that off-path accepts like AcknowledgeAlarm are included.
    The kernel's AST parser requires type definitions for every accept signal in the
    source text, even transitions that are never reached during a test run.
    """
    seen: set[str] = set()
    result: List[str] = []
    for sm in topology.state_machines:
        for transition in sm.transitions:
            if transition.trigger_kind == "accept" and transition.trigger:
                if transition.trigger not in seen:
                    seen.add(transition.trigger)
                    result.append(transition.trigger)
    return result


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
