"""Deterministic 1-DOF fixtures for testing the closed-loop master in CI."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
import math

from .closed_loop import CouplingError


class ReferencePDController:
    def __init__(self, *, position_input: str, velocity_input: str,
                 effort_output: str, target: float, kp: float, kd: float,
                 effort_limit: float):
        self.position_input = position_input
        self.velocity_input = velocity_input
        self.effort_output = effort_output
        self.target = target
        self.kp = kp
        self.kd = kd
        self.effort_limit = effort_limit
        self._initialized = False

    @property
    def metadata(self) -> dict:
        return {
            "backend": "reference_pd_controller",
            "executed": self._initialized,
            "claim_eligible_h2": False,
            "kp": self.kp,
            "kd": self.kd,
            "target": self.target,
            "effort_limit": self.effort_limit,
        }

    def initialize(self, *, start_time: float,
                   start_values: Mapping[str, float]) -> None:
        del start_time
        for name in (self.position_input, self.velocity_input):
            if name not in start_values:
                raise CouplingError(f"missing controller input {name!r}")
        self._initialized = True

    def advance(self, *, current_time: float, step_size: float,
                inputs: Mapping[str, float], outputs: Sequence[str]) -> dict[str, float]:
        del current_time, step_size
        if not self._initialized:
            raise CouplingError("controller is not initialized")
        if list(outputs) != [self.effort_output]:
            raise CouplingError("reference controller exposes one effort output")
        raw = (
            self.kp * (self.target - float(inputs[self.position_input]))
            - self.kd * float(inputs[self.velocity_input])
        )
        effort = max(-self.effort_limit, min(self.effort_limit, raw))
        return {self.effort_output: effort}

    def close(self) -> None:
        pass


class ReferenceOneDOFPhysics:
    """Semi-implicit Euler plant used only as a coupling test double."""

    def __init__(self, *, joint_path: str, joint_type: str = "revolute",
                 inertia: float = 0.5, damping: float = 0.2,
                 initial_position: float = 0.0,
                 initial_velocity: float = 0.0):
        if joint_type not in {"revolute", "prismatic"}:
            raise ValueError("reference physics supports revolute or prismatic joints")
        if inertia <= 0 or damping < 0:
            raise ValueError("inertia must be positive and damping non-negative")
        self.joint_path = joint_path
        self.joint_type = joint_type
        self.inertia = inertia
        self.damping = damping
        self.position = initial_position
        self.velocity = initial_velocity
        self.effort = 0.0
        self._executed = False

    @property
    def metadata(self) -> dict:
        return {
            "backend": "reference_one_dof",
            "engine": "semi_implicit_euler",
            "executed": self._executed,
            "claim_eligible_h2": False,
            "joint_path": self.joint_path,
            "joint_type": self.joint_type,
            "inertia": self.inertia,
            "damping": self.damping,
        }

    def initialize(self, *, step_size: float, substeps: int) -> None:
        if step_size <= 0 or substeps < 1:
            raise CouplingError("invalid reference physics clock")
        self._executed = True

    def read(self, mapping: Mapping[str, object]) -> float:
        self._check_joint(mapping)
        quantity = mapping["usd_quantity"]
        if quantity == "joint_position":
            return self.position
        if quantity == "joint_velocity":
            return self.velocity
        if quantity == "joint_effort":
            return self.effort
        raise CouplingError(f"unsupported reference observation {quantity!r}")

    def apply(self, mapping: Mapping[str, object], value: float) -> None:
        self._check_joint(mapping)
        if mapping["usd_quantity"] != "joint_effort":
            raise CouplingError("reference plant accepts effort commands only")
        self.effort = float(value)

    def step(self, *, step_size: float, substeps: int) -> None:
        dt = step_size / substeps
        for _ in range(substeps):
            acceleration = (self.effort - self.damping * self.velocity) / self.inertia
            self.velocity += acceleration * dt
            self.position += self.velocity * dt
        if not math.isfinite(self.position) or not math.isfinite(self.velocity):
            raise CouplingError("reference physics diverged")

    def close(self) -> None:
        pass

    def _check_joint(self, mapping: Mapping[str, object]) -> None:
        if mapping["usd_joint_path"] != self.joint_path:
            raise CouplingError(f"unknown joint {mapping['usd_joint_path']!r}")
        if mapping["joint_type"] != self.joint_type:
            raise CouplingError("joint type differs from reference plant")
