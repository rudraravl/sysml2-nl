"""Phase 1: regex-based structural extraction from SysML v2 candidate text."""

from __future__ import annotations

import re
from typing import List, Optional

from .models import (
    ExtractedAttribute,
    ExtractedConstraint,
    ExtractedTopology,
)

_PACKAGE_RE = re.compile(
    r"^\s*package\s+([A-Za-z_][\w]*)",
    re.MULTILINE,
)
_PART_DEF_RE = re.compile(
    r"^\s*part\s+def\s+([A-Za-z_][\w]*)",
    re.MULTILINE,
)
_PART_INSTANCE_RE = re.compile(
    r"^\s*part\s+([A-Za-z_][\w]*)\s*:\s*>\s*([A-Za-z_][\w]*)",
    re.MULTILINE,
)
_PART_SIMPLE_RE = re.compile(
    r"^\s*part\s+([A-Za-z_][\w]*)\s*(?:\{|:)",
    re.MULTILINE,
)
_ATTRIBUTE_RE = re.compile(
    r"^\s*attribute\s+([A-Za-z_][\w]*)",
    re.MULTILINE,
)
_CONSTRAINT_BLOCK_RE = re.compile(
    r"^\s*(?:require\s+)?constraint\s+([A-Za-z_][\w]*)?",
    re.MULTILINE,
)
_ASSERT_CONSTRAINT_RE = re.compile(
    r"^\s*assert\s+constraint",
    re.MULTILINE,
)
_STATE_DEF_RE = re.compile(
    r"^\s*state\s+def\s+([A-Za-z_][\w]*)",
    re.MULTILINE,
)
_STATE_INSTANCE_RE = re.compile(
    r"^\s*state\s+([A-Za-z_][\w]*)\s*:",
    re.MULTILINE,
)
_STATE_MACHINE_RE = re.compile(
    r"^\s*state\s+([A-Za-z_][\w]*[Mm]achine)\s*\{",
    re.MULTILINE,
)
_ACTION_DEF_RE = re.compile(
    r"^\s*action\s+def\s+([A-Za-z_][\w]*)",
    re.MULTILINE,
)
_ACTION_INSTANCE_RE = re.compile(
    r"^\s*action\s+([A-Za-z_][\w]*)\s*:",
    re.MULTILINE,
)


def _dedupe_preserve_order(items: List[str]) -> List[str]:
    seen = set()
    out: List[str] = []
    for item in items:
        if item not in seen:
            seen.add(item)
            out.append(item)
    return out


def _current_owner(lines: List[str], line_index: int) -> Optional[str]:
    """Best-effort owner: nearest preceding part def / part / package."""
    for i in range(line_index, -1, -1):
        line = lines[i]
        m = _PART_DEF_RE.match(line)
        if m:
            return m.group(1)
        m = _PART_INSTANCE_RE.match(line) or _PART_SIMPLE_RE.match(line)
        if m:
            return m.group(1)
        m = _PACKAGE_RE.match(line)
        if m:
            return m.group(1)
    return None


def extract_topology(candidate_sysml: str) -> ExtractedTopology:
    """
    Scan candidate text and extract packages, parts, attributes, and constraints.
    Uses lightweight regex only; incomplete models still return partial topology.
    """
    text = candidate_sysml or ""
    lines = text.splitlines()

    packages = _dedupe_preserve_order(_PACKAGE_RE.findall(text))
    part_defs = _dedupe_preserve_order(_PART_DEF_RE.findall(text))

    part_instances: List[str] = []
    for name, _typ in _PART_INSTANCE_RE.findall(text):
        part_instances.append(name)
    for name in _PART_SIMPLE_RE.findall(text):
        if name not in part_defs:
            part_instances.append(name)
    part_instances = _dedupe_preserve_order(part_instances)

    attributes: List[ExtractedAttribute] = []
    for idx, line in enumerate(lines):
        m = _ATTRIBUTE_RE.match(line)
        if m:
            attributes.append(
                ExtractedAttribute(
                    name=m.group(1),
                    owner=_current_owner(lines, idx),
                    raw_line=line.strip(),
                )
            )

    constraints: List[ExtractedConstraint] = []
    for idx, line in enumerate(lines):
        m = _CONSTRAINT_BLOCK_RE.match(line)
        if m:
            name = m.group(1) or f"constraint_{idx}"
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
        _STATE_DEF_RE.findall(text)
        + _STATE_INSTANCE_RE.findall(text)
        + _STATE_MACHINE_RE.findall(text)
    )
    actions = _dedupe_preserve_order(
        _ACTION_DEF_RE.findall(text) + _ACTION_INSTANCE_RE.findall(text)
    )

    return ExtractedTopology(
        packages=packages,
        part_defs=part_defs,
        part_instances=part_instances,
        attributes=attributes,
        constraints=constraints,
        state_machines=state_machines,
        actions=actions,
    )
