"""Reproducible FMI 2.0 Co-Simulation execution through a pinned container."""

from __future__ import annotations

import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

from .models import Diagnostic, FMUExecution


class FMIContainerRunner:
    def __init__(self, *, image: str = "nl2robotics-fmi-runtime:0.1",
                 timeout: int = 120):
        self.image = image
        self.timeout = timeout

    def available(self) -> bool:
        if not shutil.which("docker"):
            return False
        image_names = [self.image]
        if "/" not in self.image:
            image_names.append(f"docker.io/library/{self.image}")
        return any(
            subprocess.run(
                ["docker", "image", "inspect", image],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            ).returncode == 0
            for image in image_names
        )

    def run(self, fmu_path: Path, *, start_time: float = 0.0,
            stop_time: float = 5.0, step_size: float = 0.01,
            start_values: dict[str, float | int | bool] | None = None,
            outputs: list[str] | None = None,
            output_dir: Path | None = None) -> FMUExecution:
        if stop_time <= start_time or step_size <= 0:
            raise ValueError("invalid FMI simulation configuration")
        if not fmu_path.is_file():
            return FMUExecution(False, diagnostics=[Diagnostic(
                "fmi_source", "error", f"FMU does not exist: {fmu_path}"
            )])
        if not self.available():
            return FMUExecution(False, diagnostics=[Diagnostic(
                "infrastructure", "error",
                f"FMI runtime image is unavailable: {self.image}",
            )])

        work = output_dir or Path(tempfile.mkdtemp(prefix="fmi-run-"))
        work.mkdir(parents=True, exist_ok=True)
        local_fmu = work / "model.fmu"
        if fmu_path.resolve() != local_fmu.resolve():
            shutil.copy2(fmu_path, local_fmu)
        config = {
            "start_time": start_time,
            "stop_time": stop_time,
            "step_size": step_size,
            "start_values": start_values or {},
            "outputs": outputs or [],
        }
        (work / "config.json").write_text(
            json.dumps(config, indent=2), encoding="utf-8"
        )
        for stale in ("trace.csv", "execution.json"):
            (work / stale).unlink(missing_ok=True)

        command = [
            "docker", "run", "--rm",
            "-v", f"{work.resolve()}:/work",
            self.image,
            "python3", "/opt/nl2robotics/simulate_fmu.py",
            "--fmu", "/work/model.fmu",
            "--config", "/work/config.json",
            "--trace", "/work/trace.csv",
            "--report", "/work/execution.json",
        ]
        started = time.monotonic()
        try:
            process = subprocess.run(
                command,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=self.timeout,
            )
        except subprocess.TimeoutExpired:
            return FMUExecution(
                True,
                duration_seconds=time.monotonic() - started,
                diagnostics=[Diagnostic(
                    "fmi_execution", "error",
                    f"FMU execution timed out after {self.timeout}s",
                )],
            )

        duration = time.monotonic() - started
        report_path = work / "execution.json"
        trace_path = work / "trace.csv"
        report = {}
        diagnostics = []
        if report_path.is_file():
            try:
                report = json.loads(report_path.read_text(encoding="utf-8"))
            except (json.JSONDecodeError, OSError) as exc:
                diagnostics.append(Diagnostic(
                    "fmi_execution", "error", f"invalid execution report: {exc}"
                ))
        if process.returncode != 0 or not report.get("success"):
            message = report.get("error") or process.stdout.strip() or "FMU execution failed"
            diagnostics.append(Diagnostic("fmi_execution", "error", message))
        simulated = (
            process.returncode == 0
            and report.get("success") is True
            and trace_path.is_file()
        )
        return FMUExecution(
            True,
            initialized=bool(report.get("initialized")),
            simulated=simulated,
            result_file=trace_path if trace_path.is_file() else None,
            report_file=report_path if report_path.is_file() else None,
            columns=list(report.get("columns", [])),
            sample_count=int(report.get("sample_count", 0)),
            diagnostics=diagnostics,
            duration_seconds=duration,
        )
