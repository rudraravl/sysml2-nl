from __future__ import annotations

from pathlib import Path
import hashlib
import json
import tempfile
import unittest

from .closed_loop import ClosedLoopMaster, CouplingError
from .newton_backend import NewtonPhysics
from .newton_bundle import (
    BUNDLE_SCHEMA_VERSION,
    NewtonBundleError,
    load_newton_bundle,
)


class FakeNewtonRuntime:
    def __init__(self, paths=None):
        self.paths = paths or ["/World/Shoulder"]
        self.position = 0.0
        self.velocity = 0.0
        self.effort = 0.0
        self.effort_set_calls = 0
        self.closed = False

    @property
    def metadata(self):
        return {
            "backend": "newton_physics_test_double",
            "engine": "Newton Physics",
            "runtime_verified": False,
            "executed": False,
        }

    def initialize(self, **kwargs):
        self.initialization = kwargs

    def joint_paths(self):
        return list(self.paths)

    def read_position(self, index):
        self._index(index)
        return self.position

    def read_velocity(self, index):
        self._index(index)
        return self.velocity

    def read_effort(self, index):
        self._index(index)
        return self.effort

    def set_position_state(self, index, value):
        self._index(index)
        self.position = value

    def set_velocity_state(self, index, value):
        self._index(index)
        self.velocity = value

    def set_effort(self, index, value):
        self._index(index)
        self.effort = value
        self.effort_set_calls += 1

    def step(self, steps):
        self.velocity += self.effort * 0.005 * steps
        self.position += self.velocity * 0.005 * steps

    def close(self):
        self.closed = True

    @staticmethod
    def _index(index):
        if index != 0:
            raise AssertionError(index)


class ClaimingDeltaAIRuntime(FakeNewtonRuntime):
    def __init__(self):
        super().__init__()
        self.executed = False

    @property
    def metadata(self):
        return {
            "backend": "newton_physics",
            "engine": "Newton Physics",
            "runtime_verified": True,
            "executed": self.executed,
            "newton_version": "1.5.0",
            "warp_version": "1.16.0",
            "solver": "featherstone",
            "device": "cuda:0",
            "device_is_cuda": True,
            "device_name": "NVIDIA H100 96GB HBM3",
            "platform_system": "Linux",
            "platform_machine": "aarch64",
        }

    def step(self, steps):
        super().step(steps)
        self.executed = True


class EligibleController:
    def __init__(self):
        self.executed = False

    @property
    def metadata(self):
        return {"backend": "fmpy_fmi2", "executed": self.executed}

    def initialize(self, **kwargs):
        self.executed = True

    def advance(self, **kwargs):
        return {"torque": 1.0}

    def close(self):
        pass


def mapping(quantity, direction="usd_to_fmu", **extra):
    return {
        "usd_joint_path": "/World/Shoulder",
        "usd_quantity": quantity,
        "direction": direction,
        **extra,
    }


class NewtonBackendTests(unittest.TestCase):
    def test_exact_path_exchange_holds_effort_and_test_double_cannot_claim(self):
        with tempfile.TemporaryDirectory() as tmp:
            stage = Path(tmp) / "scene.usda"
            stage.write_text("#usda 1.0\n", encoding="utf-8")
            runtime = FakeNewtonRuntime()
            effort = mapping("joint_effort", "fmu_to_usd")
            position = mapping("joint_position")
            backend = NewtonPhysics(
                stage_path=stage,
                mappings=[position, effort],
                device="cpu",
                runtime=runtime,
            )
            backend.initialize(step_size=0.01, substeps=2)
            backend.apply(effort, 4.0)
            backend.step(step_size=0.01, substeps=2)
            self.assertGreater(backend.read(position), 0.0)
            self.assertEqual(2, runtime.effort_set_calls)
            self.assertEqual(
                "newton_physics_test_double", backend.metadata["backend"]
            )
            self.assertFalse(backend.metadata["provenance_complete"])
            backend.close()
            self.assertTrue(runtime.closed)

    def test_missing_joint_fails_before_exchange_and_closes_runtime(self):
        with tempfile.TemporaryDirectory() as tmp:
            stage = Path(tmp) / "scene.usda"
            stage.write_text("#usda 1.0\n", encoding="utf-8")
            runtime = FakeNewtonRuntime(paths=["/World/Elbow"])
            backend = NewtonPhysics(
                stage_path=stage,
                mappings=[mapping("joint_position")],
                device="cpu",
                runtime=runtime,
            )
            with self.assertRaisesRegex(CouplingError, "missing mapped joints"):
                backend.initialize(step_size=0.01, substeps=1)
            self.assertTrue(runtime.closed)

    def test_multiple_joint_paths_are_resolved_independently(self):
        class MultiRuntime(FakeNewtonRuntime):
            def __init__(self):
                super().__init__(["/World/Shoulder", "/World/Extension"])
                self.positions = [0.1, 0.02]
                self.velocities = [0.0, 0.0]
                self.efforts = [0.0, 0.0]

            def read_position(self, index):
                return self.positions[index]

            def read_velocity(self, index):
                return self.velocities[index]

            def read_effort(self, index):
                return self.efforts[index]

            def set_position_state(self, index, value):
                self.positions[index] = value

            def set_velocity_state(self, index, value):
                self.velocities[index] = value

            def set_effort(self, index, value):
                self.efforts[index] = value
                self.effort_set_calls += 1

            def step(self, steps):
                for index in range(2):
                    self.velocities[index] += self.efforts[index] * 0.005 * steps
                    self.positions[index] += self.velocities[index] * 0.005 * steps

        with tempfile.TemporaryDirectory() as tmp:
            stage = Path(tmp) / "scene.usda"
            stage.write_text("#usda 1.0\n", encoding="utf-8")
            shoulder = mapping("joint_position")
            extension_position = {
                **mapping("joint_position"), "usd_joint_path": "/World/Extension"
            }
            extension_effort = {
                **mapping("joint_effort", "fmu_to_usd"),
                "usd_joint_path": "/World/Extension",
            }
            backend = NewtonPhysics(
                stage_path=stage,
                mappings=[shoulder, extension_position, extension_effort],
                device="cpu", runtime=MultiRuntime(),
            )
            backend.initialize(step_size=0.01, substeps=2)
            backend.apply(extension_effort, 3.0)
            backend.step(step_size=0.01, substeps=2)
            self.assertEqual(0.1, backend.read(shoulder))
            self.assertGreater(backend.read(extension_position), 0.02)
            backend.close()

    def test_grounded_initial_state_is_applied(self):
        with tempfile.TemporaryDirectory() as tmp:
            stage = Path(tmp) / "scene.usda"
            stage.write_text("#usda 1.0\n", encoding="utf-8")
            position = mapping("joint_position", initial_value=0.25)
            velocity = mapping("joint_velocity", initial_value=-0.1)
            backend = NewtonPhysics(
                stage_path=stage,
                mappings=[position, velocity],
                device="cpu",
                runtime=FakeNewtonRuntime(),
            )
            backend.initialize(step_size=0.01, substeps=1)
            self.assertEqual(0.25, backend.read(position))
            self.assertEqual(-0.1, backend.read(velocity))
            backend.close()

    def test_position_commands_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            stage = Path(tmp) / "scene.usda"
            stage.write_text("#usda 1.0\n", encoding="utf-8")
            position = mapping("joint_position", "fmu_to_usd")
            backend = NewtonPhysics(
                stage_path=stage,
                mappings=[position],
                device="cpu",
                runtime=FakeNewtonRuntime(),
            )
            backend.initialize(step_size=0.01, substeps=1)
            with self.assertRaisesRegex(CouplingError, "effort commands"):
                backend.apply(position, 1.0)
            backend.close()

    def test_deltaai_claim_requires_real_backend_and_h100_provenance(self):
        with tempfile.TemporaryDirectory() as tmp:
            stage = Path(tmp) / "scene.usda"
            stage.write_text("#usda 1.0\n", encoding="utf-8")
            position = mapping(
                "joint_position", id="position", fmu_variable="angle",
                source_unit="rad", target_unit="rad", scale=1.0, offset=0.0,
                numeric_tolerance=1e-6, initial_value=0.0,
            )
            effort = mapping(
                "joint_effort", "fmu_to_usd", id="effort",
                fmu_variable="torque", source_unit="N.m", target_unit="N.m",
                scale=1.0, offset=0.0, numeric_tolerance=1e-6,
                command_lower=-5.0, command_upper=5.0,
            )
            backend = NewtonPhysics(
                stage_path=stage,
                mappings=[position, effort],
                device="cuda:0",
                runtime=ClaimingDeltaAIRuntime(),
            )
            report = ClosedLoopMaster().run(
                EligibleController(), backend,
                mappings=[position, effort],
                clock={"start_time": 0.0, "stop_time": 0.01, "step_size": 0.01},
                coupling={"physics_substeps": 2},
                output_dir=Path(tmp) / "output",
            )
            self.assertTrue(report["claim_eligible_newton_h2"])
            self.assertTrue(report["claim_eligible_deltaai_h2"])
            self.assertFalse(report["claim_eligible_isaac_h2"])


class NewtonBundleTests(unittest.TestCase):
    def test_loader_accepts_only_hashed_newton_mode_bundles(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            artifacts = {}
            for name in (
                "request", "modelica", "openusd", "requirement_ir", "contract", "fmu"
            ):
                path = root / name
                path.write_bytes(name.encode("ascii"))
                artifacts[name] = {
                    "path": name,
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                }
            data = {
                "schema_version": BUNDLE_SCHEMA_VERSION,
                "task_id": "RHY201",
                "execution_mode": "newton_closed_loop",
                "artifacts": artifacts,
                "resolved_mappings": [{"id": "map_effort"}],
                "clock": {"start_time": 0.0, "stop_time": 1.0},
                "coupling": {"algorithm": "sampled_data_sequential"},
                "properties": [{"id": "stays_safe"}],
                "preflight": {
                    "contract_validation": {"success": True},
                    "controller_conformance": {"success": True},
                },
            }
            manifest = root / "execution-input.json"
            manifest.write_text(json.dumps(data), encoding="utf-8")
            loaded = load_newton_bundle(manifest)
            self.assertEqual("newton_closed_loop", loaded["execution_mode"])
            data["execution_mode"] = "isaac_closed_loop"
            manifest.write_text(json.dumps(data), encoding="utf-8")
            with self.assertRaisesRegex(NewtonBundleError, "newton_closed_loop"):
                load_newton_bundle(manifest)

if __name__ == "__main__":
    unittest.main()
