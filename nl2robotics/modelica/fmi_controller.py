"""Incremental FMI 2.0 Co-Simulation adapter for the H2 master."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
import json
from pathlib import Path
import shutil
import subprocess

from .fmu import inspect_fmu


class FMIControllerError(RuntimeError):
    pass


class FMPyControllerRuntime:
    """Advance one controller FMU at explicit communication points."""

    def __init__(self, fmu_path: Path, *, instance_name: str = "nl2robotics_h2"):
        self.fmu_path = fmu_path.resolve()
        self.instance_name = instance_name
        metadata = inspect_fmu(self.fmu_path)
        if metadata["fmi_version"] != "2.0" or metadata["interface_type"] != "co_simulation":
            raise FMIControllerError(
                "H2 controller must be an FMI 2.0 Co-Simulation FMU"
            )
        self._description = metadata
        self._variables = {item.name: item for item in metadata["variables"]}
        self._fmu = None
        self._unzip_dir: str | None = None
        self._executed = False

    @property
    def metadata(self) -> dict:
        return {
            "backend": "fmpy_fmi2",
            "runtime_version": "0.3.29",
            "fmi_version": self._description["fmi_version"],
            "interface_type": self._description["interface_type"],
            "model_name": self._description["model_name"],
            "model_identifier": self._description["model_identifier"],
            "executed": self._executed,
        }

    def initialize(self, *, start_time: float,
                   start_values: Mapping[str, float]) -> None:
        if self._fmu is not None:
            raise FMIControllerError("FMU is already initialized")
        try:
            from fmpy import extract
            from fmpy.fmi2 import FMU2Slave
        except ImportError as exc:
            raise FMIControllerError(
                "FMPy 0.3.29 is required in the H2 master environment"
            ) from exc

        self._check_variables(start_values, causality="input")
        self._unzip_dir = extract(str(self.fmu_path))
        self._fmu = FMU2Slave(
            guid=self._description["guid"],
            unzipDirectory=self._unzip_dir,
            modelIdentifier=self._description["model_identifier"],
            instanceName=self.instance_name,
        )
        try:
            self._fmu.instantiate(loggingOn=False)
            self._fmu.setupExperiment(startTime=float(start_time))
            self._set_reals(start_values)
            self._fmu.enterInitializationMode()
            self._fmu.exitInitializationMode()
            self._executed = True
        except Exception:
            self.close()
            raise

    def advance(self, *, current_time: float, step_size: float,
                inputs: Mapping[str, float], outputs: Sequence[str]) -> dict[str, float]:
        if self._fmu is None:
            raise FMIControllerError("FMU is not initialized")
        self._check_variables(inputs, causality="input")
        self._check_variables({name: 0.0 for name in outputs}, causality="output")
        self._set_reals(inputs)
        self._fmu.doStep(
            currentCommunicationPoint=float(current_time),
            communicationStepSize=float(step_size),
        )
        references = [self._variables[name].value_reference for name in outputs]
        values = self._fmu.getReal(references)
        return {name: float(value) for name, value in zip(outputs, values)}

    def close(self) -> None:
        if self._fmu is not None:
            try:
                self._fmu.terminate()
            except Exception:
                pass
            try:
                self._fmu.freeInstance()
            except Exception:
                pass
            self._fmu = None
        if self._unzip_dir:
            shutil.rmtree(self._unzip_dir, ignore_errors=True)
            self._unzip_dir = None

    def _set_reals(self, values: Mapping[str, float]) -> None:
        if not values:
            return
        references = [self._variables[name].value_reference for name in values]
        self._fmu.setReal(references, [float(value) for value in values.values()])

    def _check_variables(self, values: Mapping[str, float], *, causality: str) -> None:
        for name in values:
            variable = self._variables.get(name)
            if variable is None:
                raise FMIControllerError(f"FMU variable {name!r} does not exist")
            if variable.scalar_type != "real" or variable.causality != causality:
                raise FMIControllerError(
                    f"FMU variable {name!r} must be a Real {causality}"
                )


class FMIContainerControllerRuntime:
    """Run incremental FMI exchange in the project's pinned sidecar image."""

    def __init__(self, fmu_path: Path, *,
                 image: str = "nl2robotics-fmi-runtime:0.1"):
        self.fmu_path = fmu_path.resolve()
        self.image = image
        self._description = inspect_fmu(self.fmu_path)
        if (self._description["fmi_version"] != "2.0"
                or self._description["interface_type"] != "co_simulation"):
            raise FMIControllerError(
                "H2 controller must be an FMI 2.0 Co-Simulation FMU"
            )
        self._process: subprocess.Popen | None = None
        self._executed = False

    @property
    def metadata(self) -> dict:
        return {
            "backend": "fmpy_fmi2_container",
            "runtime_image": self.image,
            "runtime_version": "0.3.29",
            "fmi_version": self._description["fmi_version"],
            "model_name": self._description["model_name"],
            "model_identifier": self._description["model_identifier"],
            "executed": self._executed,
        }

    def initialize(self, *, start_time: float,
                   start_values: Mapping[str, float]) -> None:
        if not shutil.which("docker"):
            raise FMIControllerError(
                "Docker is required for the pinned FMI sidecar"
            )
        command = [
            "docker", "run", "--rm", "-i",
            "-v", f"{self.fmu_path}:/work/model.fmu:ro",
            self.image,
            "python3", "/opt/nl2robotics/controller_fmu.py",
            "--fmu", "/work/model.fmu",
        ]
        self._process = subprocess.Popen(
            command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
        try:
            self._request({
                "command": "initialize",
                "start_time": float(start_time),
                "start_values": dict(start_values),
            })
        except Exception:
            self.close()
            raise
        self._executed = True

    def advance(self, *, current_time: float, step_size: float,
                inputs: Mapping[str, float], outputs: Sequence[str]) -> dict[str, float]:
        response = self._request({
            "command": "advance",
            "current_time": float(current_time),
            "step_size": float(step_size),
            "inputs": dict(inputs),
            "outputs": list(outputs),
        })
        return {name: float(value) for name, value in response["outputs"].items()}

    def close(self) -> None:
        process = self._process
        if process is None:
            return
        try:
            if process.poll() is None:
                self._request({"command": "close"})
                process.wait(timeout=10)
        except Exception:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
        finally:
            self._process = None

    def _request(self, message: dict) -> dict:
        process = self._process
        if process is None or process.stdin is None or process.stdout is None:
            raise FMIControllerError("FMI sidecar is not running")
        if process.poll() is not None:
            error = process.stderr.read().strip() if process.stderr else ""
            raise FMIControllerError(error or "FMI sidecar exited unexpectedly")
        process.stdin.write(json.dumps(message, allow_nan=False) + "\n")
        process.stdin.flush()
        noise = []
        response = None
        for _ in range(20):
            line = process.stdout.readline()
            if not line:
                break
            try:
                candidate = json.loads(line)
            except json.JSONDecodeError:
                noise.append(line.strip())
                continue
            if isinstance(candidate, dict) and "success" in candidate:
                response = candidate
                break
            noise.append(line.strip())
        if response is None:
            error = process.stderr.read().strip() if process.stderr else ""
            detail = error or "; ".join(item for item in noise if item)
            raise FMIControllerError(
                detail or "FMI sidecar returned no protocol response"
            )
        if response.get("success") is not True:
            raise FMIControllerError(
                response.get("error", "FMI sidecar request failed")
            )
        return response
