"""Isaac Sim 6 articulation adapter for the simulator-independent H2 master."""

from __future__ import annotations

from collections.abc import Mapping
import hashlib
from pathlib import Path
from typing import Protocol

from .closed_loop import CouplingError


class IsaacRuntimeBridge(Protocol):
    @property
    def metadata(self) -> dict: ...

    def initialize(self, *, stage_path: Path, articulation_root: str,
                   physics_dt: float, device: str, solver: str) -> None: ...

    def dof_paths(self) -> list[str]: ...

    def read_position(self, index: int) -> float: ...

    def read_velocity(self, index: int) -> float: ...

    def read_effort(self, index: int) -> float: ...

    def set_position_state(self, index: int, value: float) -> None: ...

    def set_velocity_state(self, index: int, value: float) -> None: ...

    def set_position_target(self, index: int, value: float) -> None: ...

    def set_velocity_target(self, index: int, value: float) -> None: ...

    def set_effort(self, index: int, value: float) -> None: ...

    def step(self, steps: int) -> None: ...

    def close(self) -> None: ...


class IsaacSimPhysics:
    """Expose one loaded Isaac articulation through ``PhysicsBackend``."""

    def __init__(self, *, stage_path: Path, articulation_root: str,
                 mappings: list[dict], simulation_app: object | None = None,
                 device: str = "cpu", solver: str = "TGS",
                 required_version_prefix: str = "6.0",
                 runtime: IsaacRuntimeBridge | None = None):
        self.stage_path = stage_path.resolve()
        self.articulation_root = articulation_root
        self.mappings = mappings
        self.device = device
        self.solver = solver.upper()
        self.required_version_prefix = required_version_prefix
        self._runtime = runtime
        self._simulation_app = simulation_app
        self._indices: dict[str, int] = {}
        self._physics_dt: float | None = None
        self._substeps: int | None = None
        self._held_efforts: dict[int, float] = {}
        self._initialized = False

    @property
    def metadata(self) -> dict:
        runtime = dict(self._runtime.metadata) if self._runtime else {}
        verified = (
            runtime.get("backend") == "isaac_sim"
            and runtime.get("runtime_verified") is True
            and runtime.get("executed") is True
        )
        return {
            **runtime,
            "backend": "isaac_sim" if verified else runtime.get(
                "backend", "isaac_sim_unavailable"
            ),
            "engine": runtime.get("engine", "PhysX"),
            "stage_path": str(self.stage_path),
            "stage_sha256": _sha256(self.stage_path) if self.stage_path.is_file() else None,
            "articulation_root": self.articulation_root,
            "physics_dt": self._physics_dt,
            "physics_substeps": self._substeps,
            "required_version_prefix": self.required_version_prefix,
            "provenance_complete": bool(
                verified
                and runtime.get("isaac_version")
                and runtime.get("solver")
                and runtime.get("device")
                and self._physics_dt
                and self.stage_path.is_file()
            ),
        }

    def initialize(self, *, step_size: float, substeps: int) -> None:
        if not self.stage_path.is_file():
            raise CouplingError(f"Isaac stage does not exist: {self.stage_path}")
        if step_size <= 0 or substeps < 1:
            raise CouplingError("invalid Isaac physics clock")
        if self.solver not in {"TGS", "PGS"}:
            raise CouplingError("Isaac solver must be TGS or PGS")
        self._physics_dt = step_size / substeps
        self._substeps = substeps
        if self._runtime is None:
            if self._simulation_app is None:
                raise CouplingError("SimulationApp is required for the Isaac runtime")
            self._runtime = IsaacSim6Runtime(
                self._simulation_app,
                required_version_prefix=self.required_version_prefix,
            )
        try:
            self._runtime.initialize(
                stage_path=self.stage_path,
                articulation_root=self.articulation_root,
                physics_dt=self._physics_dt,
                device=self.device,
                solver=self.solver,
            )
            paths = self._runtime.dof_paths()
            if len(paths) != len(set(paths)):
                raise CouplingError("Isaac articulation exposes duplicate DOF paths")
            self._indices = {path: index for index, path in enumerate(paths)}
            missing = sorted({
                str(row["usd_joint_path"])
                for row in self.mappings
                if str(row["usd_joint_path"]) not in self._indices
            })
            if missing:
                raise CouplingError(
                    f"Isaac articulation is missing mapped DOFs: {missing}"
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
        raise CouplingError(f"unsupported Isaac observation {quantity!r}")

    def apply(self, mapping: Mapping[str, object], value: float) -> None:
        runtime, index = self._resolve(mapping)
        quantity = mapping["usd_quantity"]
        if quantity == "joint_position":
            runtime.set_position_target(index, float(value))
            return
        if quantity == "joint_velocity":
            runtime.set_velocity_target(index, float(value))
            return
        if quantity == "joint_effort":
            self._held_efforts[index] = float(value)
            return
        raise CouplingError(f"unsupported Isaac command {quantity!r}")

    def step(self, *, step_size: float, substeps: int) -> None:
        if not self._initialized or self._runtime is None:
            raise CouplingError("Isaac physics is not initialized")
        expected_dt = step_size / substeps
        if self._physics_dt is None or abs(expected_dt - self._physics_dt) > 1e-12:
            raise CouplingError("Isaac step differs from initialized physics clock")
        if substeps != self._substeps:
            raise CouplingError("Isaac substep count changed during execution")
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
            raise CouplingError("Isaac runtime is not initialized")
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

    def _resolve(self, mapping: Mapping[str, object]) -> tuple[IsaacRuntimeBridge, int]:
        if not self._initialized or self._runtime is None:
            raise CouplingError("Isaac physics is not initialized")
        path = str(mapping["usd_joint_path"])
        if path not in self._indices:
            raise CouplingError(f"unknown Isaac joint {path!r}")
        return self._runtime, self._indices[path]


class IsaacSim6Runtime:
    """Thin binding to APIs available only inside Isaac Sim's Python runtime."""

    def __init__(self, simulation_app: object, *,
                 required_version_prefix: str = "6.0"):
        self.simulation_app = simulation_app
        self.required_version_prefix = required_version_prefix
        self._articulation = None
        self._manager = None
        self._metadata = {
            "backend": "isaac_sim",
            "engine": "PhysX",
            "runtime_verified": False,
            "executed": False,
        }

    @property
    def metadata(self) -> dict:
        return dict(self._metadata)

    def initialize(self, *, stage_path: Path, articulation_root: str,
                   physics_dt: float, device: str, solver: str) -> None:
        try:
            from isaacsim.core.experimental.prims import Articulation
            import isaacsim.core.experimental.utils.stage as stage_utils
            from isaacsim.core.simulation_manager import SimulationManager
            from isaacsim.core.version import get_version
        except ImportError as exc:
            raise CouplingError(
                "Isaac Sim 6 Python runtime is unavailable; launch with Isaac python.sh"
            ) from exc

        opened = stage_utils.open_stage(str(stage_path))
        success = opened[0] if isinstance(opened, tuple) else opened
        if not success:
            raise CouplingError(f"Isaac Sim could not open stage: {stage_path}")
        if not SimulationManager.switch_physics_engine("physx"):
            raise CouplingError("Isaac Sim could not select the PhysX engine")
        SimulationManager.setup_simulation(dt=physics_dt, device=device)
        scenes = SimulationManager.get_physics_scenes()
        if len(scenes) != 1:
            raise CouplingError(
                f"H2 requires exactly one physics scene, found {len(scenes)}"
            )
        scene = scenes[0]
        if not hasattr(scene, "set_solver_type"):
            raise CouplingError("selected Isaac physics scene is not PhysX-backed")
        scene.set_dt(physics_dt)
        scene.set_solver_type(solver)
        roots = [
            path for path in Articulation.fetch_articulation_root_api_prim_paths(
                articulation_root
            )
            if path is not None
        ]
        if len(roots) != 1:
            raise CouplingError(
                f"expected one articulation root below {articulation_root!r}, "
                f"found {roots}"
            )
        resolved_root = str(roots[0])
        articulation = Articulation(resolved_root)
        SimulationManager.initialize_physics()
        self._articulation = articulation
        self._manager = SimulationManager
        self.simulation_app.update()
        if not articulation.valid or not articulation.is_physics_tensor_entity_valid():
            raise CouplingError(
                f"invalid Isaac articulation root: {articulation_root}"
            )

        actual_dt = float(scene.get_dt())
        actual_solver = str(scene.get_solver_type()).upper()
        actual_device = str(SimulationManager.get_device())
        if abs(actual_dt - physics_dt) > 1e-12:
            raise CouplingError(
                f"Isaac physics dt {actual_dt} differs from requested {physics_dt}"
            )
        if actual_solver != solver:
            raise CouplingError(
                f"Isaac solver {actual_solver!r} differs from requested {solver!r}"
            )
        if actual_device != device:
            raise CouplingError(
                f"Isaac device {actual_device!r} differs from requested {device!r}"
            )

        version_fields = tuple(str(item) for item in get_version())
        version = ".".join(version_fields[2:5])
        if not version.startswith(self.required_version_prefix):
            raise CouplingError(
                f"Isaac Sim {version} does not match pinned prefix "
                f"{self.required_version_prefix}"
            )
        self._metadata.update({
            "runtime_verified": True,
            "isaac_version": version,
            "isaac_version_fields": list(version_fields),
            "solver": actual_solver,
            "device": actual_device,
            "physics_dt": actual_dt,
            "gpu_dynamics": bool(scene.get_enabled_gpu_dynamics()),
            "physics_scene": str(scene.path),
            "resolved_articulation_root": resolved_root,
        })

    def dof_paths(self) -> list[str]:
        articulation = self._require_articulation()
        paths = articulation.dof_paths
        if len(paths) == 1 and isinstance(paths[0], (list, tuple)):
            paths = paths[0]
        return [str(path) for path in paths]

    def read_position(self, index: int) -> float:
        return _scalar(self._require_articulation().get_dof_positions(
            dof_indices=[index]
        ))

    def read_velocity(self, index: int) -> float:
        return _scalar(self._require_articulation().get_dof_velocities(
            dof_indices=[index]
        ))

    def read_effort(self, index: int) -> float:
        return _scalar(self._require_articulation().get_dof_efforts(
            dof_indices=[index]
        ))

    def set_position_state(self, index: int, value: float) -> None:
        self._require_articulation().set_dof_positions(
            [[value]], dof_indices=[index]
        )

    def set_velocity_state(self, index: int, value: float) -> None:
        self._require_articulation().set_dof_velocities(
            [[value]], dof_indices=[index]
        )

    def set_position_target(self, index: int, value: float) -> None:
        self._require_articulation().set_dof_position_targets(
            [[value]], dof_indices=[index]
        )

    def set_velocity_target(self, index: int, value: float) -> None:
        self._require_articulation().set_dof_velocity_targets(
            [[value]], dof_indices=[index]
        )

    def set_effort(self, index: int, value: float) -> None:
        self._require_articulation().set_dof_efforts(
            [[value]], dof_indices=[index]
        )

    def step(self, steps: int) -> None:
        if self._manager is None:
            raise CouplingError("Isaac runtime is not initialized")
        self._manager.step(steps=steps)
        self.simulation_app.update()
        self._metadata["executed"] = True
        self._metadata["physics_steps"] = int(
            self._manager.get_num_physics_steps()
        )
        self._metadata["simulation_time"] = float(
            self._manager.get_simulation_time()
        )

    def close(self) -> None:
        if self._manager is not None:
            self._manager.invalidate_physics()
        self._articulation = None
        self._manager = None

    def _require_articulation(self):
        if self._articulation is None:
            raise CouplingError("Isaac articulation is not initialized")
        return self._articulation


def _scalar(value: object) -> float:
    if hasattr(value, "numpy"):
        value = value.numpy()
    if hasattr(value, "reshape"):
        flattened = value.reshape(-1)
        if len(flattened) != 1:
            raise CouplingError("Isaac joint query returned an unexpected shape")
        return float(flattened[0])
    if isinstance(value, (list, tuple)):
        while isinstance(value, (list, tuple)) and len(value) == 1:
            value = value[0]
    return float(value)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()
