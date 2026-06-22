"""Minimal type-aware input candidates for generated execution harnesses."""

from __future__ import annotations

from dataclasses import dataclass
from typing import List

from .models import ExtractedTopology


@dataclass(frozen=True)
class InputCandidate:
    expression: str
    declarations: tuple[str, ...] = ()


_PRIMITIVE_VALUES = {
    "Boolean": ("false", "true"),
    "Integer": ("0", "1", "-1"),
    "Natural": ("0", "1"),
    "Real": ("0.0", "1.0", "-1.0"),
    "String": ('""', '"test"'),
}


def _simple_type(type_name: str) -> str:
    return type_name.split("::")[-1].strip().strip("'")


def _fixture_name(pin_name: str) -> str:
    return "test" + pin_name[:1].upper() + pin_name[1:]


def input_types_for_target(topology: ExtractedTopology) -> dict[str, str]:
    """Resolve input types from the primary usage and its action definition."""
    usage = topology.primary_composite_usage()
    if usage is None:
        action_def = topology.primary_action_def()
        return dict(action_def.input_types) if action_def else {}

    resolved = {}
    if usage.type_ref:
        action_def = next(
            (item for item in topology.action_defs if item.name == usage.type_ref),
            None,
        )
        if action_def:
            resolved.update(action_def.input_types)
    resolved.update(usage.input_types)
    return resolved


def candidates_for_input(
    topology: ExtractedTopology,
    pin_name: str,
    type_name: str,
) -> List[InputCandidate]:
    """Return bounded candidates for one primitive or nominal payload input."""
    simple = _simple_type(type_name)
    if simple in _PRIMITIVE_VALUES:
        return [InputCandidate(value) for value in _PRIMITIVE_VALUES[simple]]

    payload_names = {item.name for item in topology.attribute_defs}
    if simple in payload_names:
        fixture = _fixture_name(pin_name)
        declaration = f"attribute {fixture} : {type_name};"
        return [InputCandidate(fixture, (declaration,))]

    return []
