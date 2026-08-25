"""Shared semantics for the executable articulated-robot profile.

This module deliberately contains no simulator bindings.  It is the single
source of truth for units and primitive geometry used by normalization,
planning, cross-artifact validation, and active controller conformance.
"""

from __future__ import annotations

from dataclasses import dataclass


SUPPORTED_JOINT_TYPES = frozenset({"revolute", "prismatic"})
SUPPORTED_JOINT_AXES = frozenset({"X", "Y", "Z"})
SUPPORTED_LINK_SHAPES = frozenset({"box", "sphere", "cylinder", "capsule"})
SUPPORTED_CONTROLLER_KINDS = frozenset({"PD"})


@dataclass(frozen=True)
class JointUnits:
    position: str
    velocity: str
    effort: str
    proportional_gain: str
    derivative_gain: str


_JOINT_UNITS = {
    "revolute": JointUnits(
        position="rad",
        velocity="rad/s",
        effort="N.m",
        proportional_gain="N.m/rad",
        derivative_gain="N.m.s/rad",
    ),
    "prismatic": JointUnits(
        position="m",
        velocity="m/s",
        effort="N",
        proportional_gain="N/m",
        derivative_gain="N.s/m",
    ),
}


def joint_units(joint_type: str) -> JointUnits:
    """Return canonical closed-loop boundary units for a one-DOF joint."""
    try:
        return _JOINT_UNITS[joint_type]
    except KeyError as exc:
        raise ValueError(f"unsupported joint type: {joint_type!r}") from exc


def entity_shape(entity: dict) -> str:
    """Return the explicit primitive shape, preserving legacy box records."""
    return str(entity.get("shape", "box")).lower()


def axial_length(entity: dict) -> float:
    """Return the profile's local-Z layout extent for a rigid link."""
    shape = entity_shape(entity)
    if shape == "box":
        return float(entity["length"])
    if shape == "sphere":
        return 2.0 * float(entity["radius"])
    return float(entity["height"])


def geometry_fields(shape: str) -> tuple[str, ...]:
    return {
        "box": ("length", "width", "depth"),
        "sphere": ("radius",),
        "cylinder": ("radius", "height"),
        "capsule": ("radius", "height"),
    }.get(shape, ())
