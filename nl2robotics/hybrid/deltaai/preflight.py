"""Capture fail-closed DeltaAI/Newton runtime evidence before execution."""

from __future__ import annotations

import argparse
import json
import platform
from pathlib import Path
import subprocess
import sys


def inspect_host(stage: Path | None = None) -> dict:
    checks = []
    machine = platform.machine().lower()
    checks.append(_check(
        "arm64_host", machine in {"aarch64", "arm64"}, machine
    ))
    gpu = _command([
        "nvidia-smi", "--query-gpu=name,driver_version", "--format=csv,noheader"
    ])
    gpu_rows = [row.strip() for row in gpu["stdout"].splitlines() if row.strip()]
    checks.append(_check(
        "deltaai_h100", gpu["returncode"] == 0
        and any("H100" in row.upper() for row in gpu_rows),
        gpu["stderr"] or repr(gpu_rows),
    ))
    omc = _command(["omc", "--version"])
    checks.append(_check(
        "openmodelica", omc["returncode"] == 0,
        omc["stdout"] or omc["stderr"],
    ))
    versions = {}
    try:
        import fmpy
        import newton
        import warp as wp
        from pxr import Usd, UsdPhysics  # noqa: F401

        device = wp.get_device("cuda:0")
        versions = {
            "fmpy": fmpy.__version__,
            "newton": newton.__version__,
            "warp": wp.__version__,
            "cuda_device": str(device),
            "cuda_device_name": getattr(device, "name", None),
            "cuda_architecture": getattr(device, "arch", None),
        }
        checks.append(_check(
            "pinned_python_runtime",
            newton.__version__ == "1.5.0"
            and wp.__version__ == "1.16.0"
            and fmpy.__version__ == "0.3.29",
            repr(versions),
        ))
        checks.append(_check(
            "warp_cuda", bool(device.is_cuda), repr(versions)
        ))
        if stage is not None:
            builder = newton.ModelBuilder()
            imported = builder.add_usd(
                str(stage.resolve()),
                collapse_fixed_joints=False,
                load_visual_shapes=False,
                load_static_visual_shapes=False,
                skip_mesh_approximation=True,
            )
            paths = sorted(imported.get("path_joint_map", {}))
            checks.append(_check(
                "newton_usd_import",
                any(path != "/World/WorldAnchor" for path in paths),
                repr(paths),
            ))
    except Exception as exc:
        checks.append(_check(
            "pinned_python_runtime", False, f"{type(exc).__name__}: {exc}"
        ))
    return {
        "stage": "deltaai_newton_preflight",
        "success": all(row["passed"] for row in checks),
        "platform": {
            "system": platform.system(),
            "machine": platform.machine(),
            "python": sys.version,
        },
        "gpus": gpu_rows,
        "versions": versions,
        "checks": checks,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = inspect_host(args.stage)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(report, indent=2, allow_nan=False))
    raise SystemExit(0 if report["success"] else 1)


def _command(command: list[str]) -> dict:
    try:
        process = subprocess.run(
            command, text=True, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, timeout=30,
        )
        return {
            "returncode": process.returncode,
            "stdout": process.stdout.strip(),
            "stderr": process.stderr.strip(),
        }
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"returncode": -1, "stdout": "", "stderr": str(exc)}


def _check(name: str, passed: bool, detail: str) -> dict:
    return {"name": name, "passed": bool(passed), "detail": detail}


if __name__ == "__main__":
    main()
