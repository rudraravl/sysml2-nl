"""Small explicit unit registry for the robotics interface boundary."""

from __future__ import annotations

from dataclasses import dataclass
import math


@dataclass(frozen=True)
class UnitConversion:
    source: str
    target: str
    dimension: str
    scale: float
    offset: float = 0.0

    def apply(self, value: float) -> float:
        return value * self.scale + self.offset


class UnitError(ValueError):
    pass


# Scale and offset convert a value to the canonical unit for its dimension.
_UNITS = {
    "rad": ("angle", 1.0, 0.0),
    "deg": ("angle", math.pi / 180.0, 0.0),
    "rad/s": ("angular_velocity", 1.0, 0.0),
    "deg/s": ("angular_velocity", math.pi / 180.0, 0.0),
    "m": ("length", 1.0, 0.0),
    "mm": ("length", 0.001, 0.0),
    "m/s": ("linear_velocity", 1.0, 0.0),
    "m/s2": ("acceleration", 1.0, 0.0),
    "N": ("force", 1.0, 0.0),
    "N.m": ("torque", 1.0, 0.0),
    "N.m/rad": ("rotational_stiffness", 1.0, 0.0),
    "N.m.s/rad": ("rotational_damping", 1.0, 0.0),
    "N/m": ("linear_stiffness", 1.0, 0.0),
    "N.s/m": ("linear_damping", 1.0, 0.0),
    "kg": ("mass", 1.0, 0.0),
    "kg.m2": ("rotational_inertia", 1.0, 0.0),
    "s": ("time", 1.0, 0.0),
}

_ALIASES = {
    "degree": "deg",
    "degrees": "deg",
    "radian": "rad",
    "radians": "rad",
    "N*m": "N.m",
    "N m": "N.m",
}


def canonical_unit(unit: str) -> str:
    normalized = unit.strip()
    return _ALIASES.get(normalized, normalized)


def conversion(source: str, target: str) -> UnitConversion:
    source_name = canonical_unit(source)
    target_name = canonical_unit(target)
    if source_name not in _UNITS:
        raise UnitError(f"unsupported source unit: {source}")
    if target_name not in _UNITS:
        raise UnitError(f"unsupported target unit: {target}")
    source_dimension, source_scale, source_offset = _UNITS[source_name]
    target_dimension, target_scale, target_offset = _UNITS[target_name]
    if source_dimension != target_dimension:
        raise UnitError(
            f"incompatible units: {source_name} ({source_dimension}) and "
            f"{target_name} ({target_dimension})"
        )
    scale = source_scale / target_scale
    offset = (source_offset - target_offset) / target_scale
    return UnitConversion(
        source=source_name,
        target=target_name,
        dimension=source_dimension,
        scale=scale,
        offset=offset,
    )
