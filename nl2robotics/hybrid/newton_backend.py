"""Newton Physics 1.5 adapter for the simulator-independent H2 master."""

from __future__ import annotations

from collections.abc import Mapping
import hashlib
from pathlib import Path
import platform
from typing import Protocol

from .closed_loop import CouplingError


NEWTON_VERSION = "1.5.0"
NEWTON_SOLVERS = {"featherstone", "mujoco_warp"}


class NewtonRuntimeBridge(Protocol):
    @property
    def metadata(self) -> dict: ...

    def initialize(self, *, stage_path: Path, physics_dt: float,
                   device: str, solver: str) -> None: ...

    def joint_paths(self) -> list[str]: ...

    def read_position(self, index: int) -> float: ...

    def read_velocity(self, index: int) -> float: ...

    def read_effort(self, index: int) -> float: ...

    def set_position_state(self, index: int, value: float) -> None: ...

    def set_velocity_state(self, index: int, value: float) -> None: ...

    def set_effort(self, index: int, value: float) -> None: ...

    def step(self, steps: int) -> None: ...

    def close(self) -> None: ...


class NewtonPhysics:
    """Expose a Newton-imported UsdPhysics articulation as ``PhysicsBackend``."""

    def __init__(self, *, stage_path: Path, mappings: list[dict],
                 device: str = "cuda:0", solver: str = "featherstone",
                 required_version: str = NEWTON_VERSION,
                 runtime: NewtonRuntimeBridge | None = None):
        self.stage_path = stage_path.resolve()
        self.mappings = mappings
        self.device = device
        self.solver = solver.lower()
        self.required_version = required_version
        self._runtime = runtime
        self._indices: dict[str, int] = {}
        self._held_efforts: dict[int, float] = {}
        self._physics_dt: float | None = None
        self._substeps: int | None = None
        self._initialized = False

    @property
    def metadata(self) -> dict:
        runtime = dict(self._runtime.metadata) if self._runtime else {}
        verified = (
            runtime.get("backend") == "newton_physics"
            and runtime.get("runtime_verified") is True
            and runtime.get("executed") is True
            and runtime.get("newton_version") == self.required_version
        )
        return {
            **runtime,
            "backend": "newton_physics" if verified else runtime.get(
                "backend", "newton_physics_unavailable"
            ),
            "engine": runtime.get("engine", "Newton Physics"),
            "stage_path": str(self.stage_path),
            "stage_sha256": _sha256(self.stage_path) if self.stage_path.is_file() else None,
            "physics_dt": self._physics_dt,
            "physics_substeps": self._substeps,
            "required_version": self.required_version,
            "provenance_complete": bool(
                verified
                and runtime.get("warp_version")
                and runtime.get("solver") == self.solver
                and runtime.get("device")
                and self._physics_dt
                and self.stage_path.is_file()
            ),
        }

    def initialize(self, *, step_size: float, substeps: int) -> None:
        if not self.stage_path.is_file():
            raise CouplingError(f"Newton stage does not exist: {self.stage_path}")
        if step_size <= 0 or substeps < 1:
            raise CouplingError("invalid Newton physics clock")
        if self.solver not in NEWTON_SOLVERS:
            raise CouplingError(
                f"Newton solver must be one of {sorted(NEWTON_SOLVERS)}"
            )
        self._physics_dt = step_size / substeps
        self._substeps = substeps
        if self._runtime is None:
            self._runtime = Newton15Runtime(required_version=self.required_version)
        try:
            self._runtime.initialize(
                stage_path=self.stage_path,
                physics_dt=self._physics_dt,
                device=self.device,
                solver=self.solver,
            )
            paths = self._runtime.joint_paths()
            if len(paths) != len(set(paths)):
                raise CouplingError("Newton import exposes duplicate joint paths")
            self._indices = {path: index for index, path in enumerate(paths)}
            missing = sorted({
                str(row["usd_joint_path"])
                for row in self.mappings
                if str(row["usd_joint_path"]) not in self._indices
            })
            if missing:
                raise CouplingError(
                    f"Newton articulation is missing mapped joints: {missing}"
                )
            self._apply_initial_state()
            self._initialized = True
        except Exception:
            self._runtime.close()
            raise

    def read(self, mapping: Mapping[str, object]) -> float:
        runtime, index = self._resolve(mapping)
        quantity = mapping["usd_quantity"]
        if quantity == "joint_position":
            return runtime.read_position(index)
        if quantity == "joint_velocity":
            return runtime.read_velocity(index)
        if quantity == "joint_effort":
            return runtime.read_effort(index)
        raise CouplingError(f"unsupported Newton observation {quantity!r}")

    def apply(self, mapping: Mapping[str, object], value: float) -> None:
        _, index = self._resolve(mapping)
        if mapping["usd_quantity"] != "joint_effort":
            raise CouplingError(
                "Newton H2 supports effort commands; position and velocity are states"
            )
        self._held_efforts[index] = float(value)

    def step(self, *, step_size: float, substeps: int) -> None:
        if not self._initialized or self._runtime is None:
            raise CouplingError("Newton physics is not initialized")
        expected_dt = step_size / substeps
        if self._physics_dt is None or abs(expected_dt - self._physics_dt) > 1e-12:
            raise CouplingError("Newton step differs from initialized physics clock")
        if substeps != self._substeps:
            raise CouplingError("Newton substep count changed during execution")
        for _ in range(substeps):
            for index, effort in self._held_efforts.items():
                self._runtime.set_effort(index, effort)
            self._runtime.step(1)

    def close(self) -> None:
        if self._runtime is not None:
            self._runtime.close()
        self._held_efforts.clear()
        self._initialized = False

    def _apply_initial_state(self) -> None:
        if self._runtime is None:
            raise CouplingError("Newton runtime is not initialized")
        for mapping in self.mappings:
            if (mapping.get("direction") != "usd_to_fmu"
                    or mapping.get("initial_value") is None):
                continue
            index = self._indices[str(mapping["usd_joint_path"])]
            value = float(mapping["initial_value"])
            quantity = mapping.get("usd_quantity")
            if quantity == "joint_position":
                self._runtime.set_position_state(index, value)
            elif quantity == "joint_velocity":
                self._runtime.set_velocity_state(index, value)
            else:
                raise CouplingError(
                    f"unsupported initial-state quantity {quantity!r}"
                )

    def _resolve(self, mapping: Mapping[str, object]) -> tuple[NewtonRuntimeBridge, int]:
        if not self._initialized or self._runtime is None:
            raise CouplingError("Newton physics is not initialized")
        path = str(mapping["usd_joint_path"])
        if path not in self._indices:
            raise CouplingError(f"unknown Newton joint {path!r}")
        return self._runtime, self._indices[path]


class Newton15Runtime:
    """Thin binding to the pinned Newton 1.5 runtime used on DeltaAI."""

    def __init__(self, *, required_version: str = NEWTON_VERSION):
        self.required_version = required_version
        self._model = None
        self._state_0 = None
        self._state_1 = None
        self._control = None
        self._solver = None
        self._newton = None
        self._joint_paths: list[str] = []
        self._q_indices: list[int] = []
        self._qd_indices: list[int] = []
        self._metadata = {
            "backend": "newton_physics",
            "engine": "Newton Physics",
            "runtime_verified": False,
            "executed": False,
        }

    @property
    def metadata(self) -> dict:
        return dict(self._metadata)

    def initialize(self, *, stage_path: Path, physics_dt: float,
                   device: str, solver: str) -> None:
        try:
            import newton
            import warp as wp
        except ImportError as exc:
            raise CouplingError(
                "Newton runtime is unavailable; install newton[sim,importers]==1.5.0"
            ) from exc
        if newton.__version__ != self.required_version:
            raise CouplingError(
                f"Newton {self.required_version} is required, found {newton.__version__}"
            )
        try:
            resolved_device = wp.get_device(device)
        except Exception as exc:
            raise CouplingError(f"Newton cannot use Warp device {device!r}: {exc}") from exc

        builder = newton.ModelBuilder()
        if solver == "mujoco_warp":
            newton.solvers.SolverMuJoCo.register_custom_attributes(builder)
        imported = builder.add_usd(
            str(stage_path),
            collapse_fixed_joints=False,
            load_visual_shapes=False,
            load_static_visual_shapes=False,
            skip_mesh_approximation=True,
        )
        path_map = imported.get("path_joint_map", {})
        if not isinstance(path_map, dict) or not path_map:
            raise CouplingError("Newton imported no USD joints")

        self._model = builder.finalize(device=device)
        self._newton = newton
        q_starts = self._model.joint_q_start.numpy().tolist()
        qd_starts = self._model.joint_qd_start.numpy().tolist()
        joint_types = self._model.joint_type.numpy().tolist()
        one_dof_types = {
            int(newton.JointType.PRISMATIC), int(newton.JointType.REVOLUTE)
        }
        ordered = sorted(
            (path, index) for path, index in path_map.items()
            if int(joint_types[index]) in one_dof_types
        )
        if not ordered:
            raise CouplingError("Newton imported no supported one-DOF joints")
        self._joint_paths = [path for path, _ in ordered]
        self._q_indices = [int(q_starts[index]) for _, index in ordered]
        self._qd_indices = [int(qd_starts[index]) for _, index in ordered]
        if len(self._q_indices) != len(set(self._q_indices)):
            raise CouplingError("Newton imported ambiguous joint coordinates")
        if len(self._qd_indices) != len(set(self._qd_indices)):
            raise CouplingError("Newton imported ambiguous joint DOFs")
        self._state_0 = self._model.state()
        self._state_1 = self._model.state()
        self._control = self._model.control()
        newton.eval_fk(
            self._model, self._model.joint_q, self._model.joint_qd, self._state_0
        )
        deterministic = wp.DeterministicMode.RUN_TO_RUN
        if solver == "featherstone":
            self._solver = newton.solvers.SolverFeatherstone(
                self._model, deterministic=deterministic
            )
        elif solver == "mujoco_warp":
            self._solver = newton.solvers.SolverMuJoCo(
                self._model,
                disable_contacts=True,
                deterministic=deterministic,
                integrator="implicitfast",
                solver="newton",
            )
        else:
            raise CouplingError(f"unsupported Newton solver {solver!r}")
        self._physics_dt = physics_dt
        self._metadata.update({
            "newton_version": newton.__version__,
            "warp_version": wp.__version__,
            "solver": solver,
            "device_requested": device,
            "device": str(resolved_device),
            "device_is_cuda": bool(resolved_device.is_cuda),
            "device_name": getattr(resolved_device, "name", None),
            "device_architecture": getattr(resolved_device, "arch", None),
            "platform_system": platform.system(),
            "platform_machine": platform.machine(),
            "runtime_verified": True,
        })

    def joint_paths(self) -> list[str]:
        return list(self._joint_paths)

    def read_position(self, index: int) -> float:
        return float(self._state_0.joint_q.numpy()[self._q_indices[index]])

    def read_velocity(self, index: int) -> float:
        return float(self._state_0.joint_qd.numpy()[self._qd_indices[index]])

    def read_effort(self, index: int) -> float:
        return float(self._control.joint_f.numpy()[self._qd_indices[index]])

    def set_position_state(self, index: int, value: float) -> None:
        values = self._state_0.joint_q.numpy()
        values[self._q_indices[index]] = value
        self._state_0.joint_q.assign(values)
        self._sync_kinematics()

    def set_velocity_state(self, index: int, value: float) -> None:
        values = self._state_0.joint_qd.numpy()
        values[self._qd_indices[index]] = value
        self._state_0.joint_qd.assign(values)
        self._sync_kinematics()

    def set_effort(self, index: int, value: float) -> None:
        values = self._control.joint_f.numpy()
        values[self._qd_indices[index]] = value
        self._control.joint_f.assign(values)

    def step(self, steps: int) -> None:
        for _ in range(steps):
            self._state_0.clear_forces()
            self._solver.step(
                self._state_0, self._state_1, self._control, None, self._physics_dt
            )
            self._state_0, self._state_1 = self._state_1, self._state_0
        self._metadata["executed"] = True

    def close(self) -> None:
        self._solver = None
        self._control = None
        self._state_0 = None
        self._state_1 = None
        self._model = None
        self._newton = None

    def _sync_kinematics(self) -> None:
        self._newton.eval_fk(
            self._model,
            self._state_0.joint_q,
            self._state_0.joint_qd,
            self._state_0,
        )


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()
