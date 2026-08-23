"""Preflight and launch a frozen H2 bundle on an Isaac Sim GPU host."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import platform
import subprocess
import sys

from .isaac_bundle import IsaacBundleError, load_isaac_bundle


def main() -> None:
    args = _arguments()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    report = run_handoff(
        bundle_path=args.bundle,
        output_dir=args.output_dir,
        isaac_python=args.isaac_python,
        repetitions=args.repetitions,
        controller_backend=args.controller_backend,
        device=args.device,
        solver=args.solver,
        dry_run=args.dry_run,
    )
    (args.output_dir / "gpu-handoff.json").write_text(
        json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(report, indent=2, allow_nan=False))
    raise SystemExit(0 if report.get("success") is True else 1)


def run_handoff(*, bundle_path: Path, output_dir: Path, isaac_python: Path,
                repetitions: int = 3, controller_backend: str = "local",
                device: str = "cpu", solver: str = "TGS",
                dry_run: bool = False) -> dict:
    try:
        bundle = load_isaac_bundle(bundle_path)
    except (IsaacBundleError, OSError, ValueError) as exc:
        return _failure("bundle", str(exc))
    preflight = inspect_gpu_host(isaac_python, controller_backend)
    roots = bundle.get("preflight", {}).get("openusd", {}).get("articulations", [])
    articulation_root = roots[0] if len(roots) == 1 else "/World"
    isaac_output = output_dir / "isaac"
    command = build_isaac_command(
        isaac_python=isaac_python,
        bundle_path=bundle_path.resolve(),
        output_dir=isaac_output.resolve(),
        articulation_root=articulation_root,
        repetitions=repetitions,
        controller_backend=controller_backend,
        device=device,
        solver=solver,
    )
    report = {
        "stage": "gpu_handoff",
        "schema_version": "1.0",
        "success": False,
        "claim_eligible_h2": False,
        "task_id": bundle["task_id"],
        "bundle_manifest_sha256": bundle["manifest_sha256"],
        "preflight": preflight,
        "command": command,
        "dry_run": dry_run,
    }
    if not preflight["success"]:
        report["failure_stage"] = "gpu_preflight"
        return report
    if dry_run:
        report["success"] = True
        report["failure_stage"] = None
        return report

    isaac_output.mkdir(parents=True, exist_ok=True)
    environment = dict(os.environ)
    repo_root = str(Path(__file__).resolve().parents[2])
    environment["PYTHONPATH"] = os.pathsep.join(filter(None, (
        repo_root, environment.get("PYTHONPATH", ""),
    )))
    completed = subprocess.run(
        command, text=True, capture_output=True, env=environment, check=False
    )
    (output_dir / "isaac-stdout.txt").write_text(completed.stdout, encoding="utf-8")
    (output_dir / "isaac-stderr.txt").write_text(completed.stderr, encoding="utf-8")
    report_path = isaac_output / "isaac-report.json"
    isaac_report = None
    if report_path.is_file():
        try:
            isaac_report = json.loads(report_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            pass
    report.update({
        "returncode": completed.returncode,
        "isaac_report": isaac_report,
        "success": (
            completed.returncode == 0
            and isinstance(isaac_report, dict)
            and isaac_report.get("success") is True
        ),
        "claim_eligible_h2": bool(
            isinstance(isaac_report, dict)
            and isaac_report.get("claim_eligible_h2") is True
        ),
    })
    report["failure_stage"] = None if report["success"] else "isaac_execution"
    return report


def inspect_gpu_host(isaac_python: Path,
                     controller_backend: str = "local") -> dict:
    checks = []
    checks.append(_check(
        "linux_x86_64",
        platform.system() == "Linux" and platform.machine() in {"x86_64", "AMD64"},
        f"detected {platform.system()} {platform.machine()}",
    ))
    gpu = _run_command([
        "nvidia-smi", "--query-gpu=name,memory.total,driver_version",
        "--format=csv,noheader,nounits",
    ])
    gpu_rows = parse_nvidia_smi(gpu["stdout"]) if gpu["returncode"] == 0 else []
    checks.append(_check(
        "nvidia_driver", bool(gpu_rows),
        gpu["stderr"] or (json.dumps(gpu_rows) if gpu_rows else "no GPU reported"),
    ))
    checks.append(_check(
        "isaac_python", isaac_python.is_file() and os.access(isaac_python, os.X_OK),
        str(isaac_python),
    ))
    import_check = {"returncode": None, "stdout": "", "stderr": "not run"}
    if isaac_python.is_file() and os.access(isaac_python, os.X_OK):
        script = _isaac_api_probe(controller_backend)
        import_check = _run_command([str(isaac_python), "-c", script])
    checks.append(_check(
        "isaac_api_surface", import_check["returncode"] == 0,
        import_check["stderr"] or import_check["stdout"]
        or "Pinned Isaac and controller APIs are available",
    ))
    return {
        "success": all(item["passed"] for item in checks),
        "checks": checks,
        "gpus": gpu_rows,
        "rt_capability_note": (
            "nvidia-smi does not prove RTX/RT-core compatibility; run NVIDIA's "
            "Isaac Sim Compatibility Checker before headline experiments."
        ),
    }


def build_isaac_command(*, isaac_python: Path, bundle_path: Path,
                        output_dir: Path, articulation_root: str,
                        repetitions: int, controller_backend: str,
                        device: str, solver: str) -> list[str]:
    return [
        str(isaac_python), "-m", "nl2robotics.hybrid.isaac_cli",
        "--bundle", str(bundle_path),
        "--output-dir", str(output_dir),
        "--articulation-root", articulation_root,
        "--controller-backend", controller_backend,
        "--device", device,
        "--solver", solver,
        "--repetitions", str(repetitions),
        "--isaac-version-prefix", "6.0",
    ]


def parse_nvidia_smi(output: str) -> list[dict]:
    rows = []
    for line in output.splitlines():
        parts = [part.strip() for part in line.split(",")]
        if len(parts) != 3:
            continue
        try:
            memory_mib = int(parts[1])
        except ValueError:
            continue
        rows.append({
            "name": parts[0], "memory_mib": memory_mib,
            "driver_version": parts[2],
        })
    return rows


def _isaac_api_probe(controller_backend: str) -> str:
    controller_import = "import fmpy; " if controller_backend == "local" else ""
    return controller_import + """
from isaacsim.core.experimental.prims import Articulation
import isaacsim.core.experimental.utils.stage as stage_utils
from isaacsim.core.simulation_manager import SimulationManager
from isaacsim.core.version import get_version
required_articulation = (
    'fetch_articulation_root_api_prim_paths', 'dof_paths',
    'get_dof_positions', 'get_dof_velocities', 'get_dof_efforts',
    'set_dof_positions', 'set_dof_velocities',
    'set_dof_position_targets', 'set_dof_velocity_targets', 'set_dof_efforts',
    'is_physics_tensor_entity_valid',
)
required_manager = (
    'switch_physics_engine', 'setup_simulation', 'get_physics_scenes',
    'initialize_physics', 'step', 'get_device', 'invalidate_physics',
)
missing = [f'Articulation.{name}' for name in required_articulation
           if not hasattr(Articulation, name)]
missing += [f'SimulationManager.{name}' for name in required_manager
            if not hasattr(SimulationManager, name)]
if not hasattr(stage_utils, 'open_stage'):
    missing.append('stage_utils.open_stage')
version_fields = tuple(str(item) for item in get_version())
version = '.'.join(version_fields[2:5])
if not version.startswith('6.0'):
    missing.append(f'Isaac Sim version 6.0.x (found {version})')
if missing:
    raise RuntimeError('missing pinned APIs: ' + ', '.join(missing))
print('Isaac Sim ' + version + ' API probe passed')
"""


def _run_command(command: list[str]) -> dict:
    try:
        completed = subprocess.run(
            command, text=True, capture_output=True, check=False, timeout=120
        )
        return {
            "returncode": completed.returncode,
            "stdout": completed.stdout.strip(),
            "stderr": completed.stderr.strip(),
        }
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"returncode": -1, "stdout": "", "stderr": str(exc)}


def _check(name: str, passed: bool, detail: str) -> dict:
    return {"name": name, "passed": bool(passed), "detail": detail}


def _failure(stage: str, error: str) -> dict:
    return {
        "stage": "gpu_handoff", "schema_version": "1.0", "success": False,
        "claim_eligible_h2": False, "failure_stage": stage, "error": error,
    }


def _arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--isaac-python", type=Path, required=True)
    parser.add_argument("--repetitions", type=int, default=3)
    parser.add_argument("--controller-backend", choices=("local", "docker"),
                        default="local")
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--solver", choices=("TGS", "PGS"), default="TGS")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if args.repetitions < 3:
        parser.error("paper-eligible H2 handoff requires at least three repetitions")
    return args


if __name__ == "__main__":
    main()
