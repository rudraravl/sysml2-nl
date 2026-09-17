from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from .closed_loop import CouplingError
from .isaac_backend import IsaacSimPhysics
from .isaac_bundle import (
    BUNDLE_SCHEMA_VERSION,
    IsaacBundleError,
    load_isaac_bundle,
)
from .repeatability import compare_traces


class FakeIsaacRuntime:
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
            "backend": "isaac_sim_test_double",
            "runtime_verified": False,
            "executed": False,
        }

    def initialize(self, **kwargs):
        self.initialization = kwargs

    def dof_paths(self):
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

    def set_position_target(self, index, value):
        self._index(index)
        self.position = value

    def set_velocity_target(self, index, value):
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

    def _index(self, index):
        if index != 0:
            raise AssertionError(index)


def mapping(quantity, direction="usd_to_fmu", **extra):
    return {
        "usd_joint_path": "/World/Shoulder",
        "usd_quantity": quantity,
        "direction": direction,
        **extra,
    }


class IsaacBackendTests(unittest.TestCase):
    def test_exact_joint_path_exchange_and_test_double_cannot_claim_isaac(self):
        with tempfile.TemporaryDirectory() as tmp:
            stage = Path(tmp) / "scene.usda"
            stage.write_text("#usda 1.0\n", encoding="utf-8")
            runtime = FakeIsaacRuntime()
            backend = IsaacSimPhysics(
                stage_path=stage,
                articulation_root="/World",
                mappings=[mapping("joint_position"), mapping(
                    "joint_effort", "fmu_to_usd"
                )],
                runtime=runtime,
            )
            backend.initialize(step_size=0.01, substeps=2)
            backend.apply(mapping("joint_effort", "fmu_to_usd"), 4.0)
            backend.step(step_size=0.01, substeps=2)
            self.assertGreater(backend.read(mapping("joint_position")), 0.0)
            self.assertEqual(2, runtime.effort_set_calls)
            self.assertEqual("isaac_sim_test_double", backend.metadata["backend"])
            self.assertFalse(backend.metadata["provenance_complete"])
            backend.close()
            self.assertTrue(runtime.closed)

    def test_missing_joint_fails_before_exchange_and_closes_runtime(self):
        with tempfile.TemporaryDirectory() as tmp:
            stage = Path(tmp) / "scene.usda"
            stage.write_text("#usda 1.0\n", encoding="utf-8")
            runtime = FakeIsaacRuntime(paths=["/World/Elbow"])
            backend = IsaacSimPhysics(
                stage_path=stage,
                articulation_root="/World",
                mappings=[mapping("joint_position")],
                runtime=runtime,
            )
            with self.assertRaisesRegex(CouplingError, "missing mapped DOFs"):
                backend.initialize(step_size=0.01, substeps=1)
            self.assertTrue(runtime.closed)

    def test_grounded_initial_state_is_applied_before_exchange(self):
        with tempfile.TemporaryDirectory() as tmp:
            stage = Path(tmp) / "scene.usda"
            stage.write_text("#usda 1.0\n", encoding="utf-8")
            runtime = FakeIsaacRuntime()
            position = mapping("joint_position", initial_value=0.25)
            velocity = mapping("joint_velocity", initial_value=-0.1)
            backend = IsaacSimPhysics(
                stage_path=stage,
                articulation_root="/World",
                mappings=[position, velocity],
                runtime=runtime,
            )
            backend.initialize(step_size=0.01, substeps=1)
            self.assertEqual(0.25, backend.read(position))
            self.assertEqual(-0.1, backend.read(velocity))
            backend.close()


class IsaacBundleTests(unittest.TestCase):
    @staticmethod
    def manifest(artifacts):
        return {
            "schema_version": BUNDLE_SCHEMA_VERSION,
            "task_id": "RHY101",
            "execution_mode": "isaac_closed_loop",
            "artifacts": artifacts,
            "resolved_mappings": [{"id": "map_effort"}],
            "clock": {"start_time": 0.0, "stop_time": 1.0, "step_size": 0.01},
            "coupling": {"algorithm": "sampled_data_sequential"},
            "properties": [{"id": "stays_safe"}],
            "preflight": {
                "contract_validation": {"success": True},
                "controller_conformance": {"success": True},
            },
        }

    def test_bundle_hashes_are_enforced(self):
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
            manifest = root / "execution-input.json"
            manifest.write_text(
                json.dumps(self.manifest(artifacts)), encoding="utf-8"
            )
            loaded = load_isaac_bundle(manifest)
            self.assertEqual((root / "fmu").resolve(),
                             loaded["resolved_artifacts"]["fmu"])
            (root / "openusd").write_text("modified", encoding="utf-8")
            with self.assertRaisesRegex(IsaacBundleError, "hash mismatch"):
                load_isaac_bundle(manifest)

    def test_bundle_requires_successful_semantic_preflight(self):
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
            data = self.manifest(artifacts)
            data["preflight"]["controller_conformance"]["success"] = False
            manifest = root / "execution-input.json"
            manifest.write_text(json.dumps(data), encoding="utf-8")
            with self.assertRaisesRegex(
                IsaacBundleError, "controller conformance did not pass"
            ):
                load_isaac_bundle(manifest)


class RepeatabilityTests(unittest.TestCase):
    def test_reports_maximum_numerical_delta(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            first = root / "first.csv"
            second = root / "second.csv"
            _trace(first, [0.0, 1.0])
            _trace(second, [0.0, 1.0000005])
            passing = compare_traces([first, second], tolerance=1e-6)
            failing = compare_traces([first, second], tolerance=1e-8)
            self.assertTrue(passing["success"])
            self.assertFalse(failing["success"])
            self.assertAlmostEqual(5e-7, failing["max_absolute_delta"])
            self.assertEqual("position", failing["worst_case"]["column"])


def _trace(path: Path, values: list[float]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["step", "position"])
        writer.writeheader()
        for index, value in enumerate(values):
            writer.writerow({"step": index, "position": value})


if __name__ == "__main__":
    unittest.main()
