"""Reproducible FMI 2.0 Co-Simulation execution through a pinned container."""

from __future__ import annotations

import json
from pathlib import Path
import re
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
                failure_class="runtime_timeout",
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
            report_error = str(report.get("error") or "").strip()
            runtime_log = (process.stdout or "").strip()
            if report_error and runtime_log and runtime_log not in report_error:
                message = f"{report_error}\nNative runtime log:\n{runtime_log[-4000:]}"
            else:
                message = report_error or runtime_log or "FMU execution failed"
            diagnostics.append(Diagnostic("fmi_execution", "error", message))
        else:
            message = ""
        simulated = (
            process.returncode == 0
            and report.get("success") is True
            and trace_path.is_file()
        )
        failure_class, failure_time, initialized_by_call = (
            _classify_fmi_failure(message)
        )
        return FMUExecution(
            True,
            # A reported fmi2DoStep failure proves initialization completed,
            # even though fmpy's all-or-nothing helper returns no partial array.
            initialized=bool(report.get("initialized")) or initialized_by_call,
            simulated=simulated,
            result_file=trace_path if trace_path.is_file() else None,
            report_file=report_path if report_path.is_file() else None,
            columns=list(report.get("columns", [])),
            sample_count=int(report.get("sample_count", 0)),
            failure_class=failure_class,
            failure_time=failure_time,
            diagnostics=diagnostics,
            duration_seconds=duration,
        )


_TIME_PATTERN = re.compile(
    r"(?:at\s+time(?:=|\s+)|during\s+initialization\s+at\s+time\s+)"
    r"([-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)",
    re.IGNORECASE,
)


def _classify_fmi_failure(message: str) -> tuple[str | None, float | None, bool]:
    """Return a stable failure class, failure time, and proven init status."""
    if not message:
        return None, None, False
    lowered = message.lower()
    match = _TIME_PATTERN.search(message)
    failure_time = float(match.group(1)) if match else None
    initialized = "fmi2dostep" in lowered
    if (
        "fmi2exitinitializationmode" in lowered
        or "during initialization" in lowered
    ):
        failure_class = "initialization_failure"
    elif any(token in lowered for token in (
        "inf or nan", "nan or infinite", "division by zero", "non-finite",
    )):
        failure_class = "nonfinite_dynamics"
    elif "assertion has been violated" in lowered:
        failure_class = "behavioral_assertion"
    elif any(token in lowered for token in (
        "non-linear system", "nonlinear system", "solver failed",
    )):
        failure_class = "solver_failure"
    elif "fmi2dostep" in lowered:
        failure_class = "integration_step_failure"
    else:
        failure_class = "runtime_error"
    return failure_class, failure_time, initialized
