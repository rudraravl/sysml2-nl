"""Minimal type-aware input candidates for generated execution harnesses."""

from __future__ import annotations

from dataclasses import dataclass
from typing import List, Protocol

from .models import ExtractedAcceptTrigger, ExtractedAttributeDef, ExtractedTopology


class _PayloadDef(Protocol):
    name: str
    members: list


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

_EXTERNAL_VALUE_TYPES = {
    "ScalarQuantityValue",
    "DurationValue",
    "LengthValue",
    "MassValue",
    "TimeValue",
    "SpeedValue",
    "ForceValue",
    "DensityValue",
    "VolumeFlowRateValue",
    "FrequencyValue",
    "PowerValue",
    "EnergyValue",
    "ElectricCurrentValue",
    "ElectricPotentialValue",
    "VoltageValue",
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


def _item_def_for_type(topology: ExtractedTopology, type_name: str):
    return next(
        (item for item in topology.item_defs if _matches_type(item.name, type_name)),
        None,
    )


def _payload_def_for_type(
    topology: ExtractedTopology,
    type_name: str,
) -> tuple[str, _PayloadDef] | None:
    attr_def = _attribute_def_for_type(topology, type_name)
    if attr_def:
        return "attribute", attr_def
    item_def = _item_def_for_type(topology, type_name)
    if item_def:
        return "item", item_def
    return None


def _enum_literals_for_type(topology: ExtractedTopology, type_name: str) -> List[str]:
    enum_def = next(
        (item for item in topology.enum_defs if _matches_type(item.name, type_name)),
        None,
    )
    return list(enum_def.literals) if enum_def else []


def _scalar_base_for_type(
    topology: ExtractedTopology,
    type_name: str,
    seen: set[str] | None = None,
) -> str | None:
    simple = _simple_type(type_name)
    if simple in _PRIMITIVE_VALUES:
        return simple
    visited = seen if seen is not None else set()
    if simple in visited:
        return None
    visited.add(simple)
    attr_def = _attribute_def_for_type(topology, type_name)
    if attr_def and attr_def.base_type:
        return _scalar_base_for_type(topology, attr_def.base_type, visited)
    return None


def _is_external_value_type(type_name: str) -> bool:
    simple = _simple_type(type_name)
    return "::" in type_name or simple in _EXTERNAL_VALUE_TYPES or simple.endswith("Value")


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
    scalar_base = _scalar_base_for_type(topology, type_name)
    if scalar_base:
        return TypeClassification("primitive", type_name, True)
    if _enum_literals_for_type(topology, type_name):
        return TypeClassification("enumeration", type_name, True)

    payload = _payload_def_for_type(topology, type_name)
    if payload is None:
        if _is_external_value_type(type_name):
            return TypeClassification("external_value_payload", type_name, True)
        return TypeClassification(
            "unsupported",
            type_name,
            False,
            "type is not a primitive, enum, extracted payload def, or known value type",
        )
    payload_kind, payload_def = payload
    if not payload_def.members:
        if scalar_base:
            return TypeClassification("scalar_payload", type_name, True)
        return TypeClassification(f"nominal_{payload_kind}_payload", type_name, True)

    unsupported_members = [
        member
        for member in payload_def.members
        if _member_declaration(topology, member.name, member.type_name, member.default_value) is None
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


def _literal_for_type(topology: ExtractedTopology, type_name: str) -> str | None:
    scalar_base = _scalar_base_for_type(topology, type_name)
    if scalar_base:
        return _PRIMITIVE_VALUES[scalar_base][0]
    enum_literals = _enum_literals_for_type(topology, type_name)
    if enum_literals:
        return f"{type_name}::{enum_literals[0]}"
    return None


def _member_declaration(
    topology: ExtractedTopology,
    member_name: str,
    type_name: str | None,
    default_value: str | None = None,
    seen: set[str] | None = None,
) -> str | None:
    if default_value:
        return f"attribute {member_name} = {default_value};"
    if not type_name:
        return None

    literal = _literal_for_type(topology, type_name)
    if literal is not None:
        scalar_base = _scalar_base_for_type(topology, type_name)
        if scalar_base and _simple_type(type_name) != scalar_base:
            return f"attribute {member_name} : {type_name} = {literal};"
        return f"attribute {member_name} = {literal};"

    declaration = _declaration_for_value(
        topology,
        member_name,
        type_name,
        seen=seen,
    )
    if declaration:
        return declaration

    if _is_external_value_type(type_name):
        return f"attribute {member_name} : {type_name};"
    return None


def _declaration_for_value(
    topology: ExtractedTopology,
    value_name: str,
    type_name: str,
    seen: set[str] | None = None,
) -> str | None:
    scalar_literal = _literal_for_type(topology, type_name)
    if scalar_literal is not None and _simple_type(type_name) in _PRIMITIVE_VALUES:
        return None

    scalar_base = _scalar_base_for_type(topology, type_name)
    if scalar_base:
        return f"attribute {value_name} : {type_name} = {_PRIMITIVE_VALUES[scalar_base][0]};"

    payload = _payload_def_for_type(topology, type_name)
    if payload is None:
        if _is_external_value_type(type_name):
            return f"attribute {value_name} : {type_name};"
        return None

    keyword, payload_def = payload
    simple = _simple_type(type_name)
    visited = seen if seen is not None else set()
    if simple in visited:
        return None
    nested_seen = set(visited)
    nested_seen.add(simple)

    if not payload_def.members:
        return f"{keyword} {value_name} : {type_name};"

    member_lines = []
    for member in payload_def.members:
        declaration = _member_declaration(
            topology,
            member.name,
            member.type_name,
            member.default_value,
            nested_seen,
        )
        if declaration is None:
            return None
        member_lines.extend(f"    {line}" for line in declaration.splitlines())

    return "\n".join(
        [f"{keyword} {value_name} : {type_name} {{", *member_lines, "}"]
    )


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
    scalar_base = _scalar_base_for_type(topology, type_name)
    if scalar_base and _simple_type(type_name) in _PRIMITIVE_VALUES:
        return [InputCandidate(value) for value in _PRIMITIVE_VALUES[scalar_base]]

    enum_literals = _enum_literals_for_type(topology, type_name)
    if enum_literals:
        return [InputCandidate(f"{type_name}::{literal}") for literal in enum_literals]

    declaration = _declaration_for_value(topology, _fixture_name(pin_name), type_name)
    if declaration:
        fixture = _fixture_name(pin_name)
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
