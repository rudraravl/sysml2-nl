"""Simulator-independent sampled-data master for closed-loop robotics runs."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
import csv
import math
from pathlib import Path
from typing import Protocol


class CouplingError(RuntimeError):
    pass


class ControllerRuntime(Protocol):
    @property
    def metadata(self) -> dict: ...

    def initialize(self, *, start_time: float,
                   start_values: Mapping[str, float]) -> None: ...

    def advance(self, *, current_time: float, step_size: float,
                inputs: Mapping[str, float],
                outputs: Sequence[str]) -> dict[str, float]: ...

    def close(self) -> None: ...


class PhysicsBackend(Protocol):
    @property
    def metadata(self) -> dict: ...

    def initialize(self, *, step_size: float, substeps: int) -> None: ...

    def read(self, mapping: Mapping[str, object]) -> float: ...

    def apply(self, mapping: Mapping[str, object], value: float) -> None: ...

    def step(self, *, step_size: float, substeps: int) -> None: ...

    def close(self) -> None: ...


class ClosedLoopMaster:
    """Execute the H2 exchange order without depending on a simulator API."""

    def __init__(self, *, max_abs_value: float = 1e9):
        self.max_abs_value = max_abs_value

    def run(self, controller: ControllerRuntime, physics: PhysicsBackend, *,
            mappings: list[dict], clock: dict, coupling: dict,
            output_dir: Path) -> dict:
        output_dir.mkdir(parents=True, exist_ok=True)
        feedback = [row for row in mappings if row["direction"] == "usd_to_fmu"]
        commands = [row for row in mappings if row["direction"] == "fmu_to_usd"]
        if not feedback or not commands:
            raise CouplingError("closed loop requires feedback and command mappings")

        start = float(clock["start_time"])
        stop = float(clock["stop_time"])
        step_size = float(clock["step_size"])
        steps_float = (stop - start) / step_size
        steps = round(steps_float)
        if steps <= 0 or abs(steps_float - steps) > 1e-9:
            raise CouplingError("simulation duration must be an integer number of steps")
        substeps = int(coupling["physics_substeps"])
        outputs = [row["fmu_variable"] for row in commands]
        trace_path = output_dir / "closed-loop-trace.csv"
        rows: list[dict[str, float | int]] = []

        controller_initialized = False
        physics_initialized = False
        try:
            physics.initialize(step_size=step_size, substeps=substeps)
            physics_initialized = True
            initial_inputs = self._read_feedback(physics, feedback)
            self._validate_initial_feedback(physics, feedback)
            controller.initialize(start_time=start, start_values=initial_inputs)
            controller_initialized = True

            for index in range(steps):
                time_start = start + index * step_size
                source_observations = {
                    row["id"]: self._finite(physics.read(row), row["id"])
                    for row in feedback
                }
                fmu_inputs = {
                    row["fmu_variable"]: self._convert(source_observations[row["id"]], row)
                    for row in feedback
                }
                fmu_outputs = controller.advance(
                    current_time=time_start,
                    step_size=step_size,
                    inputs=fmu_inputs,
                    outputs=outputs,
                )
                simulator_commands = {}
                for row in commands:
                    variable = row["fmu_variable"]
                    if variable not in fmu_outputs:
                        raise CouplingError(f"controller omitted output {variable!r}")
                    command = self._convert(
                        self._finite(fmu_outputs[variable], variable), row
                    )
                    self._finite(command, row["id"])
                    self._validate_command_bounds(command, row)
                    physics.apply(row, command)
                    simulator_commands[row["id"]] = command

                physics.step(step_size=step_size, substeps=substeps)
                post_observations = {
                    row["id"]: self._finite(physics.read(row), row["id"])
                    for row in feedback
                }
                rows.append(self._trace_row(
                    index=index,
                    time_start=time_start,
                    time_end=time_start + step_size,
                    feedback=feedback,
                    commands=commands,
                    source_observations=source_observations,
                    fmu_inputs=fmu_inputs,
                    fmu_outputs=fmu_outputs,
                    simulator_commands=simulator_commands,
                    post_observations=post_observations,
                ))
        except Exception as exc:
            return {
                "stage": "closed_loop_core",
                "success": False,
                "claim_eligible_h2": False,
                "error": f"{type(exc).__name__}: {exc}",
                "completed_steps": len(rows),
                "controller": dict(controller.metadata),
                "physics": dict(physics.metadata),
            }
        finally:
            if controller_initialized:
                _close(controller)
            if physics_initialized:
                _close(physics)

        _write_trace(trace_path, rows)
        physics_metadata = dict(physics.metadata)
        controller_metadata = dict(controller.metadata)
        claim_eligible = (
            physics_metadata.get("backend") == "isaac_sim"
            and physics_metadata.get("executed") is True
            and physics_metadata.get("engine") == "PhysX"
            and physics_metadata.get("provenance_complete") is True
            and controller_metadata.get("backend") in {
                "fmpy_fmi2", "fmpy_fmi2_container",
            }
            and controller_metadata.get("executed") is True
        )
        return {
            "stage": "closed_loop_core",
            "success": True,
            "execution_mode": (
                "isaac_closed_loop" if claim_eligible else "reference_closed_loop"
            ),
            "claim_eligible_h2": claim_eligible,
            "coupling": dict(coupling),
            "clock": dict(clock),
            "completed_steps": len(rows),
            "sample_count": len(rows),
            "trace": str(trace_path),
            "controller": controller_metadata,
            "physics": physics_metadata,
            "runtime_invariants": {
                "finite_exchange_values": True,
                "command_bounds_enforced": all(
                    row.get("command_lower") is not None
                    and row.get("command_upper") is not None
                    for row in commands
                ),
                "integer_communication_steps": True,
            },
        }

    def _read_feedback(self, physics: PhysicsBackend,
                       feedback: list[dict]) -> dict[str, float]:
        return {
            row["fmu_variable"]: self._convert(
                self._finite(physics.read(row), row["id"]), row
            )
            for row in feedback
        }

    def _validate_initial_feedback(self, physics: PhysicsBackend,
                                   feedback: list[dict]) -> None:
        for mapping in feedback:
            expected = mapping.get("initial_value")
            if expected is None:
                continue
            actual = self._finite(physics.read(mapping), mapping["id"])
            error_target_units = (
                abs(actual - float(expected)) * abs(float(mapping["scale"]))
            )
            if error_target_units > float(mapping["numeric_tolerance"]):
                raise CouplingError(
                    f"initial value mismatch for {mapping['id']}: "
                    f"expected {expected}, got {actual} {mapping['source_unit']}"
                )

    def _finite(self, value: object, label: str) -> float:
        number = float(value)
        if not math.isfinite(number):
            raise CouplingError(f"non-finite value for {label}")
        if abs(number) > self.max_abs_value:
            raise CouplingError(f"divergent value for {label}: {number}")
        return number

    @staticmethod
    def _validate_command_bounds(value: float,
                                 mapping: Mapping[str, object]) -> None:
        lower = mapping.get("command_lower")
        upper = mapping.get("command_upper")
        if lower is None or upper is None:
            raise CouplingError(
                f"command mapping {mapping.get('id')!r} has no enforced bounds"
            )
        tolerance = float(mapping.get("numeric_tolerance", 0.0))
        if value < float(lower) - tolerance or value > float(upper) + tolerance:
            raise CouplingError(
                f"command {mapping.get('id')!r}={value} exceeds "
                f"[{lower}, {upper}] {mapping.get('target_unit')}"
            )

    @staticmethod
    def _convert(value: float, mapping: Mapping[str, object]) -> float:
        return value * float(mapping["scale"]) + float(mapping["offset"])

    @staticmethod
    def _trace_row(*, index: int, time_start: float, time_end: float,
                   feedback: list[dict], commands: list[dict],
                   source_observations: dict, fmu_inputs: dict,
                   fmu_outputs: dict, simulator_commands: dict,
                   post_observations: dict) -> dict[str, float | int]:
        row: dict[str, float | int] = {
            "step": index,
            "time_start": time_start,
            "time_end": time_end,
        }
        for mapping in feedback:
            mapping_id = mapping["id"]
            variable = mapping["fmu_variable"]
            row[f"sim_pre:{mapping_id}[{mapping['source_unit']}]"] = (
                source_observations[mapping_id]
            )
            row[f"fmu_input:{variable}[{mapping['target_unit']}]"] = (
                fmu_inputs[variable]
            )
            row[f"sim_post:{mapping_id}[{mapping['source_unit']}]"] = (
                post_observations[mapping_id]
            )
        for mapping in commands:
            mapping_id = mapping["id"]
            variable = mapping["fmu_variable"]
            row[f"fmu_output:{variable}[{mapping['source_unit']}]"] = (
                fmu_outputs[variable]
            )
            row[f"sim_command:{mapping_id}[{mapping['target_unit']}]"] = (
                simulator_commands[mapping_id]
            )
        return row


def _write_trace(path: Path, rows: list[dict[str, float | int]]) -> None:
    if not rows:
        raise CouplingError("closed-loop run produced no samples")
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def _close(runtime: object) -> None:
    try:
        runtime.close()
    except Exception:
        pass
