"""Deterministic fixtures for testing the simulator-independent master in CI."""

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


class ReferenceMultiJointPDController:
    """Independent joint-space PD laws used as a multi-channel FMU test double."""

    def __init__(self, channels: list[dict]):
        if not channels:
            raise ValueError("at least one controller channel is required")
        self.channels = channels
        self._initialized = False

    @property
    def metadata(self) -> dict:
        return {
            "backend": "reference_multi_joint_pd_controller",
            "executed": self._initialized,
            "claim_eligible_h2": False,
            "joint_count": len(self.channels),
        }

    def initialize(self, *, start_time: float,
                   start_values: Mapping[str, float]) -> None:
        del start_time
        required = {
            name for channel in self.channels
            for name in (channel["position_input"], channel["velocity_input"])
        }
        missing = sorted(required - start_values.keys())
        if missing:
            raise CouplingError(f"missing controller inputs {missing}")
        self._initialized = True

    def advance(self, *, current_time: float, step_size: float,
                inputs: Mapping[str, float],
                outputs: Sequence[str]) -> dict[str, float]:
        del current_time, step_size
        if not self._initialized:
            raise CouplingError("controller is not initialized")
        available = {channel["effort_output"] for channel in self.channels}
        if set(outputs) != available:
            raise CouplingError("requested outputs differ from controller channels")
        result = {}
        for channel in self.channels:
            raw = (
                float(channel["kp"])
                * (float(channel["target"])
                   - float(inputs[channel["position_input"]]))
                - float(channel["kd"])
                * float(inputs[channel["velocity_input"]])
            )
            limit = float(channel["effort_limit"])
            result[channel["effort_output"]] = max(-limit, min(limit, raw))
        return result

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


class ReferenceArticulatedPhysics:
    """Independent one-DOF plants for exercising multi-joint coupling in CI.

    This remains a test double; claim-eligible dynamics must come from Newton or
    Isaac/PhysX.  The real backends use the same mapping list and master.
    """

    def __init__(self, joints: list[dict]):
        if not joints:
            raise ValueError("at least one reference joint is required")
        self.joints = {}
        for item in joints:
            inertia = float(item.get("inertia", 0.5))
            damping = float(item.get("damping", 0.2))
            if inertia <= 0 or damping < 0:
                raise ValueError("inertia must be positive and damping non-negative")
            self.joints[item["joint_path"]] = {
                "joint_type": item["joint_type"],
                "inertia": inertia,
                "damping": damping,
                "position": float(item.get("initial_position", 0.0)),
                "velocity": float(item.get("initial_velocity", 0.0)),
                "effort": 0.0,
            }
        self._executed = False

    @property
    def metadata(self) -> dict:
        return {
            "backend": "reference_articulated",
            "engine": "independent_semi_implicit_euler",
            "executed": self._executed,
            "claim_eligible_h2": False,
            "joint_count": len(self.joints),
        }

    def initialize(self, *, step_size: float, substeps: int) -> None:
        if step_size <= 0 or substeps < 1:
            raise CouplingError("invalid reference physics clock")
        self._executed = True

    def read(self, mapping: Mapping[str, object]) -> float:
        state = self._joint(mapping)
        quantity = mapping["usd_quantity"]
        if quantity == "joint_position":
            return state["position"]
        if quantity == "joint_velocity":
            return state["velocity"]
        if quantity == "joint_effort":
            return state["effort"]
        raise CouplingError(f"unsupported reference observation {quantity!r}")

    def apply(self, mapping: Mapping[str, object], value: float) -> None:
        state = self._joint(mapping)
        if mapping["usd_quantity"] != "joint_effort":
            raise CouplingError("reference plant accepts effort commands only")
        state["effort"] = float(value)

    def step(self, *, step_size: float, substeps: int) -> None:
        dt = step_size / substeps
        for _ in range(substeps):
            for state in self.joints.values():
                acceleration = (
                    state["effort"] - state["damping"] * state["velocity"]
                ) / state["inertia"]
                state["velocity"] += acceleration * dt
                state["position"] += state["velocity"] * dt
                if (not math.isfinite(state["position"])
                        or not math.isfinite(state["velocity"])):
                    raise CouplingError("reference physics diverged")

    def close(self) -> None:
        pass

    def _joint(self, mapping: Mapping[str, object]) -> dict:
        path = str(mapping["usd_joint_path"])
        if path not in self.joints:
            raise CouplingError(f"unknown joint {path!r}")
        state = self.joints[path]
        if mapping["joint_type"] != state["joint_type"]:
            raise CouplingError("joint type differs from reference plant")
        return state
