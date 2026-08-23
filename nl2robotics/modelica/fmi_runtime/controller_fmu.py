"""JSON-line FMI 2.0 controller worker used by the closed-loop master."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import sys

from fmpy import extract, read_model_description
from fmpy.fmi2 import FMU2Slave


class Worker:
    def __init__(self, path: Path):
        self.path = path
        self.description = read_model_description(str(path))
        if self.description.fmiVersion != "2.0" or self.description.coSimulation is None:
            raise ValueError("controller must be an FMI 2.0 Co-Simulation FMU")
        self.variables = {item.name: item for item in self.description.modelVariables}
        self.directory = extract(str(path))
        self.fmu = FMU2Slave(
            guid=self.description.guid,
            unzipDirectory=self.directory,
            modelIdentifier=self.description.coSimulation.modelIdentifier,
            instanceName="nl2robotics_h2_sidecar",
        )
        self.initialized = False

    def request(self, message: dict) -> dict:
        command = message.get("command")
        if command == "initialize":
            self._check(message.get("start_values", {}), "input")
            self.fmu.instantiate(loggingOn=False)
            self.fmu.setupExperiment(startTime=float(message["start_time"]))
            self._set(message.get("start_values", {}))
            self.fmu.enterInitializationMode()
            self.fmu.exitInitializationMode()
            self.initialized = True
            return {"success": True}
        if command == "advance":
            if not self.initialized:
                raise RuntimeError("FMU is not initialized")
            inputs = message.get("inputs", {})
            outputs = message.get("outputs", [])
            self._check(inputs, "input")
            self._check({name: 0.0 for name in outputs}, "output")
            self._set(inputs)
            self.fmu.doStep(
                currentCommunicationPoint=float(message["current_time"]),
                communicationStepSize=float(message["step_size"]),
            )
            references = [self.variables[name].valueReference for name in outputs]
            values = self.fmu.getReal(references)
            return {
                "success": True,
                "outputs": {name: float(value) for name, value in zip(outputs, values)},
            }
        if command == "close":
            return {"success": True, "closed": True}
        raise ValueError(f"unknown command {command!r}")

    def close(self) -> None:
        try:
            if self.initialized:
                self.fmu.terminate()
        finally:
            try:
                self.fmu.freeInstance()
            finally:
                shutil.rmtree(self.directory, ignore_errors=True)

    def _set(self, values: dict) -> None:
        if values:
            references = [self.variables[name].valueReference for name in values]
            self.fmu.setReal(references, [float(value) for value in values.values()])

    def _check(self, values: dict, causality: str) -> None:
        for name in values:
            variable = self.variables.get(name)
            if variable is None or variable.causality != causality:
                raise ValueError(f"{name!r} is not an FMI {causality}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fmu", type=Path, required=True)
    args = parser.parse_args()
    worker = Worker(args.fmu)
    try:
        for line in sys.stdin:
            try:
                response = worker.request(json.loads(line))
            except Exception as exc:
                response = {"success": False, "error": f"{type(exc).__name__}: {exc}"}
            print(json.dumps(response, allow_nan=False), flush=True)
            if response.get("closed"):
                break
    finally:
        worker.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
