"""Preset simulation-vector generation for underspecified action inputs."""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from .models import ExtractedTopology

DEFAULT_PRESET_VALUES: List[Any] = [0, 1, -1, 0.5, True, False, ""]


def required_action_inputs(
    topology: ExtractedTopology,
    target_behaviors: Optional[List[str]] = None,
) -> List[str]:
    """Return required inputs for the selected composite action usage."""
    composite = topology.primary_composite_usage()
    if target_behaviors:
        composite = next(
            (usage for usage in topology.action_usages if usage.name == target_behaviors[0]),
            composite,
        )
    if composite is None and topology.action_usages:
        composite = max(
            topology.action_usages,
            key=lambda usage: len(usage.inputs) + int(usage.is_composite),
        )
    if composite is None:
        return []
    if composite.inputs:
        return list(dict.fromkeys(composite.inputs))
    if composite.type_ref:
        action_def = next(
            (definition for definition in topology.action_defs if definition.name == composite.type_ref),
            None,
        )
        if action_def:
            return list(dict.fromkeys(action_def.inputs))
    return []


def action_input_types(
    topology: ExtractedTopology,
    target_behaviors: Optional[List[str]] = None,
) -> Dict[str, str]:
    target = None
    if target_behaviors:
        target = next(
            (usage for usage in topology.action_usages if usage.name == target_behaviors[0]),
            None,
        )
    if target is None:
        target_name = preferred_action_target(topology)
        target = next(
            (usage for usage in topology.action_usages if usage.name == target_name),
            None,
        )
    if target is None:
        return {}
    types = dict(target.input_types)
    if target.type_ref:
        definition = next(
            (item for item in topology.action_defs if item.name == target.type_ref),
            None,
        )
        if definition:
            types = {**definition.input_types, **types}
    return types


def unsupported_preset_inputs(
    topology: ExtractedTopology,
    target_behaviors: Optional[List[str]] = None,
) -> List[str]:
    """Return inputs whose structured types cannot be represented by scalar presets."""
    input_types = action_input_types(topology, target_behaviors)
    complex_types = set(topology.complex_attribute_defs)
    return [
        name
        for name in required_action_inputs(topology, target_behaviors)
        if not input_types.get(name)
        or input_types[name].split("::")[-1].strip("'") in complex_types
        or input_types[name].split("::")[-1].strip("'").endswith(
            ("Input", "Output", "State", "StateSpace")
        )
    ]


def preferred_action_target(topology: ExtractedTopology) -> Optional[str]:
    """Choose the strongest typed action usage available for an input-driven probe."""
    typed = [usage for usage in topology.action_usages if usage.type_ref]
    if not typed:
        return None
    return max(
        typed,
        key=lambda usage: (
            len(required_action_inputs(topology, [usage.name])),
            int(usage.is_composite),
        ),
    ).name


def build_preset_vector_attempts(
    required_inputs: List[str],
    provided_vectors: Optional[Dict[str, Any]] = None,
    preset_values: Optional[List[Any]] = None,
    input_types: Optional[Dict[str, str]] = None,
) -> List[Dict[str, Any]]:
    """
    Fill every unspecified input with each preset value.

    This intentionally avoids a Cartesian product, keeping corpus runs bounded.
    """
    provided = dict(provided_vectors or {})
    missing = [name for name in required_inputs if name not in provided]
    if not missing:
        return [provided] if provided else []

    values = preset_values if preset_values is not None else DEFAULT_PRESET_VALUES
    types = input_types or {}
    attempts: List[Dict[str, Any]] = []
    for index, value in enumerate(values):
        attempt = dict(provided)
        for name in missing:
            type_name = types.get(name, "")
            lowered = type_name.lower()
            if "boolean" in lowered:
                typed_values = [False, True]
            elif "string" in lowered:
                typed_values = ["", "test"]
            elif "natural" in lowered:
                typed_values = [0, 1]
            elif "integer" in lowered:
                typed_values = [0, 1, -1]
            else:
                typed_values = values
            attempt[name] = typed_values[min(index, len(typed_values) - 1)]
        attempts.append(attempt)
    return attempts
