"""Minimal type-aware input candidates for generated execution harnesses."""

from __future__ import annotations

from dataclasses import dataclass
from typing import List

from .models import ExtractedAcceptTrigger, ExtractedAttributeDef, ExtractedTopology


@dataclass(frozen=True)
class InputCandidate:
    expression: str
    declarations: tuple[str, ...] = ()


@dataclass(frozen=True)
class TypeClassification:
    kind: str
    type_name: str
    supported: bool
    reason: str = ""


_PRIMITIVE_VALUES = {
    "Boolean": ("false", "true"),
    "Integer": ("0", "1", "-1"),
    "Natural": ("0", "1"),
    "Real": ("0.0", "1.0", "-1.0"),
    "String": ('""', '"test"'),
}


def _simple_type(type_name: str) -> str:
    return type_name.split("::")[-1].strip().strip("'")


def _matches_type(candidate_name: str, type_name: str) -> bool:
    return candidate_name == type_name or candidate_name == _simple_type(type_name)


def _fixture_name(pin_name: str) -> str:
    return "test" + pin_name[:1].upper() + pin_name[1:]


def _attribute_def_for_type(
    topology: ExtractedTopology,
    type_name: str,
) -> ExtractedAttributeDef | None:
    return next(
        (item for item in topology.attribute_defs if _matches_type(item.name, type_name)),
        None,
    )


def _enum_literals_for_type(topology: ExtractedTopology, type_name: str) -> List[str]:
    enum_def = next(
        (item for item in topology.enum_defs if _matches_type(item.name, type_name)),
        None,
    )
    return list(enum_def.literals) if enum_def else []


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


def classify_input_type(
    topology: ExtractedTopology,
    type_name: str,
) -> TypeClassification:
    """Classify one input type for fixture/vector generation."""
    simple = _simple_type(type_name)
    if not simple:
        return TypeClassification("unsupported", type_name, False, "missing declared type")
    if simple in _PRIMITIVE_VALUES:
        return TypeClassification("primitive", type_name, True)
    if _enum_literals_for_type(topology, type_name):
        return TypeClassification("enumeration", type_name, True)

    attr_def = _attribute_def_for_type(topology, type_name)
    if attr_def is None:
        return TypeClassification(
            "unsupported",
            type_name,
            False,
            "type is not a primitive, enum, or extracted attribute def",
        )
    if not attr_def.members:
        return TypeClassification("nominal_payload", type_name, True)

    unsupported_members = [
        member
        for member in attr_def.members
        if not member.type_name
        or not classify_input_type(topology, member.type_name).supported
    ]
    if unsupported_members:
        names = ", ".join(member.name for member in unsupported_members)
        return TypeClassification(
            "structured_payload",
            type_name,
            False,
            f"unsupported structured payload members: {names}",
        )
    return TypeClassification("structured_payload", type_name, True)


def _member_default_expression(topology: ExtractedTopology, type_name: str) -> str | None:
    candidates = candidates_for_input(topology, "member", type_name)
    if not candidates or candidates[0].declarations:
        return None
    return candidates[0].expression


def unsupported_reason_for_input(
    topology: ExtractedTopology,
    type_name: str,
) -> str:
    return classify_input_type(topology, type_name).reason or "no constructible candidate"


def candidates_for_input(
    topology: ExtractedTopology,
    pin_name: str,
    type_name: str,
) -> List[InputCandidate]:
    """Return bounded candidates for one primitive, enum, or payload input."""
    simple = _simple_type(type_name)
    if simple in _PRIMITIVE_VALUES:
        return [InputCandidate(value) for value in _PRIMITIVE_VALUES[simple]]

    enum_literals = _enum_literals_for_type(topology, type_name)
    if enum_literals:
        return [InputCandidate(f"{type_name}::{literal}") for literal in enum_literals]

    attr_def = _attribute_def_for_type(topology, type_name)
    if attr_def:
        fixture = _fixture_name(pin_name)
        if not attr_def.members:
            declaration = f"attribute {fixture} : {type_name};"
        else:
            member_lines = []
            for member in attr_def.members:
                if not member.type_name:
                    return []
                value = _member_default_expression(topology, member.type_name)
                if value is None:
                    return []
                member_lines.append(f"    attribute {member.name} = {value};")
            declaration = "\n".join(
                [f"attribute {fixture} : {type_name} {{", *member_lines, "}"]
            )
        return [InputCandidate(fixture, (declaration,))]

    return []


def _trigger_fixture_key(
    trigger: ExtractedAcceptTrigger,
    index: int,
    seen_params: set[str],
) -> str:
    if trigger.param:
        if trigger.param in seen_params:
            return f"{trigger.param}{index}"
        seen_params.add(trigger.param)
        return trigger.param
    return f"{_simple_type(trigger.payload_type)}{index}"


def candidates_for_trigger(
    topology: ExtractedTopology,
    trigger: ExtractedAcceptTrigger,
    index: int,
    seen_params: set[str] | None = None,
) -> List[InputCandidate]:
    """Return fixture candidates for one required accept trigger payload."""
    params = seen_params if seen_params is not None else set()
    key = _trigger_fixture_key(trigger, index, params)
    return candidates_for_input(topology, key, trigger.payload_type)
