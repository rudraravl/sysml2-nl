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


def build_preset_vector_attempts(
    required_inputs: List[str],
    provided_vectors: Optional[Dict[str, Any]] = None,
    preset_values: Optional[List[Any]] = None,
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
    attempts: List[Dict[str, Any]] = []
    for value in values:
        attempt = dict(provided)
        attempt.update({name: value for name in missing})
        attempts.append(attempt)
    return attempts
