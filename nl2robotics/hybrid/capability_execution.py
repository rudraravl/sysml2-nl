"""Executable Modelica/FMU behavior path for broad robotics tasks.

This path deliberately does not claim Newton/Isaac/OpenUSD provenance. It
executes an integrated Modelica plant/controller FMU and evaluates externally
owned requirements against the resulting trace.
"""

from __future__ import annotations

from dataclasses import asdict
import math
from pathlib import Path

from nl2robotics.modelica.fmu import FMUInspectionError, inspect_fmu
from nl2robotics.modelica.fmu_runtime import FMIContainerRunner
from nl2robotics.modelica.openmodelica import OpenModelicaRunner
from nl2robotics.modelica.properties import evaluate_properties, read_trace
from nl2robotics.contracts.units import UnitError, canonical_unit, conversion


class CapabilityExecutionPipeline:
    """Export and execute a broad integrated FMU, then evaluate its trace."""

    def __init__(self, *, modelica_runner: OpenModelicaRunner | None = None,
                 fmi_runner: FMIContainerRunner | None = None):
        self.modelica_runner = modelica_runner or OpenModelicaRunner()
        self.fmi_runner = fmi_runner or FMIContainerRunner()

    def run(self, modelica: str, requirement_ir: dict, contract: dict, *,
            output_dir: Path) -> dict:
        output_dir.mkdir(parents=True, exist_ok=True)
        report = {
            "stage": "capability_behavior_execution",
            "schema_version": "1.0",
            "task_id": requirement_ir.get("task_id"),
            "execution_mode": "integrated_fmu_behavior",
            "passed": False,
            "execution_completed": False,
            "behavior_evaluated": False,
            "behavior_passed": False,
            "claim_eligible_h2": False,
            "claim_eligible_newton_h2": False,
            "claim_eligible_deltaai_h2": False,
        }
        if contract.get("contract_kind") not in {
            "capability_execution", "modelica_capability_execution"
        }:
            report["failure_stage"] = "execution_contract"
            report["error"] = (
                "capability execution requires a supported capability contract"
            )
            return report

        clock = _execution_clock(contract.get("clock"))
        if clock is None:
            report["failure_stage"] = "execution_clock"
            report["error"] = "a grounded duration/range and frequency are required"
            return report
        report["clock"] = clock

        fmu = self.modelica_runner.export_fmu(
            modelica, output_dir=output_dir / "export"
        )
        report["fmu"] = fmu.to_dict()
        if not fmu.success or not fmu.fmu_path:
            report["failure_stage"] = "fmu_export"
            return report

        try:
            metadata = inspect_fmu(fmu.fmu_path)
        except FMUInspectionError as exc:
            report["failure_stage"] = "fmu_interface"
            report["error"] = str(exc)
            return report

        variables = {item.name: item for item in metadata["variables"]}
        mappings = []
        parameter_mappings = []
        interface_issues = []
        if metadata.get("fmi_version") != "2.0":
            interface_issues.append({
                "code": "unsupported_fmi_version",
                "expected": "2.0",
                "actual": metadata.get("fmi_version"),
            })
        if metadata.get("interface_type") != "co_simulation":
            interface_issues.append({
                "code": "unsupported_fmi_interface",
                "expected": "co_simulation",
                "actual": metadata.get("interface_type"),
            })
        expected_model_name = contract.get("model_name")
        if (
            isinstance(expected_model_name, str)
            and expected_model_name
            and metadata.get("model_name") != expected_model_name
        ):
            interface_issues.append({
                "code": "fmu_model_identity_mismatch",
                "expected": expected_model_name,
                "actual": metadata.get("model_name"),
            })
        for row in contract.get("mappings", []):
            if row.get("required", True) is not True:
                continue
            variable_name = row.get("fmu_variable")
            variable = variables.get(variable_name)
            if variable is None:
                interface_issues.append({
                    "code": "missing_fmu_output",
                    "interface_id": row.get("interface_id"),
                    "fmu_variable": variable_name,
                })
                continue
            if variable.causality != "output" or variable.scalar_type != "real":
                interface_issues.append({
                    "code": "invalid_fmu_output",
                    "interface_id": row.get("interface_id"),
                    "fmu_variable": variable_name,
                    "causality": variable.causality,
                    "scalar_type": variable.scalar_type,
                })
                continue
            source_unit = str(row.get("source_unit", "unspecified"))
            if source_unit != "unspecified" and not variable.unit:
                interface_issues.append({
                    "code": "missing_fmu_output_unit",
                    "interface_id": row.get("interface_id"),
                    "fmu_variable": variable_name,
                    "expected_unit": source_unit,
                })
                continue
            if (
                source_unit != "unspecified"
                and variable.unit
                and not _units_compatible(source_unit, variable.unit)
            ):
                interface_issues.append({
                    "code": "incompatible_fmu_output_unit",
                    "interface_id": row.get("interface_id"),
                    "fmu_variable": variable_name,
                    "expected_unit": source_unit,
                    "actual_unit": variable.unit,
                })
                continue
            mappings.append({**row, "verification_status": "resolved_fmu_output"})
        for row in contract.get("parameter_mappings", []):
            if row.get("required", True) is not True:
                continue
            variable_name = row.get("fmu_variable")
            variable = variables.get(variable_name)
            if variable is None:
                interface_issues.append({
                    "code": "missing_grounded_parameter",
                    "fact_id": row.get("fact_id"),
                    "fmu_variable": variable_name,
                })
                continue
            if variable.causality != "parameter" or variable.scalar_type != "real":
                interface_issues.append({
                    "code": "invalid_grounded_parameter",
                    "fact_id": row.get("fact_id"),
                    "fmu_variable": variable_name,
                    "causality": variable.causality,
                    "scalar_type": variable.scalar_type,
                })
                continue
            try:
                actual = float(variable.start)
                expected = float(row["expected_value"])
                source_unit = str(row.get("source_unit", "unspecified"))
                if source_unit != "unspecified" and not variable.unit:
                    raise UnitError(
                        f"FMU parameter {variable_name!r} has no unit metadata"
                    )
                target_unit = str(variable.unit or "unspecified")
                if (
                    source_unit != "unspecified"
                    and target_unit != "unspecified"
                    and canonical_unit(source_unit) != canonical_unit(target_unit)
                ):
                    expected = conversion(source_unit, target_unit).apply(expected)
                tolerance = max(1e-9, abs(expected) * 1e-8)
                matched = math.isclose(
                    actual, expected, rel_tol=0.0, abs_tol=tolerance
                )
            except (KeyError, TypeError, ValueError, UnitError) as exc:
                interface_issues.append({
                    "code": "unverifiable_grounded_parameter",
                    "fact_id": row.get("fact_id"),
                    "fmu_variable": variable_name,
                    "error": str(exc),
                })
                continue
            if not matched:
                interface_issues.append({
                    "code": "grounded_parameter_mismatch",
                    "fact_id": row.get("fact_id"),
                    "fmu_variable": variable_name,
                    "expected": expected,
                    "actual": actual,
                    "unit": target_unit,
                })
                continue
            parameter_mappings.append({
                **row,
                "actual_value": actual,
                "actual_unit": target_unit,
                "verification_status": "resolved_fmu_parameter",
            })
        report["contract"] = {
            "success": not interface_issues,
            "issues": interface_issues,
            "resolved_mappings": mappings,
            "resolved_parameter_mappings": parameter_mappings,
            "fmu": {
                "fmi_version": metadata.get("fmi_version"),
                "interface_type": metadata.get("interface_type"),
                "model_name": metadata.get("model_name"),
                "variables": [asdict(item) for item in metadata["variables"]],
            },
        }
        if interface_issues:
            report["failure_stage"] = "fmu_interface"
            return report

        outputs = sorted({row["fmu_variable"] for row in mappings})
        execution = self.fmi_runner.run(
            fmu.fmu_path,
            start_time=clock["start_time"],
            stop_time=clock["stop_time"],
            step_size=clock["step_size"],
            outputs=outputs,
            output_dir=output_dir / "execution",
        )
        report["execution"] = execution.to_dict()
        if not execution.success or not execution.result_file:
            report["failure_stage"] = "fmu_execution"
            return report

        try:
            trace = read_trace(execution.result_file)
        except (OSError, ValueError) as exc:
            report["failure_stage"] = "runtime_trace"
            report["error"] = str(exc)
            return report
        finite = all(
            math.isfinite(value)
            for name, values in trace.items() if name != "time"
            for value in values
        )
        expected_steps = round(
            (clock["stop_time"] - clock["start_time"]) / clock["step_size"]
        )
        trace_gate = {
            "success": bool(
                finite
                and execution.sample_count >= expected_steps
                and all(name in trace for name in outputs)
            ),
            "finite": finite,
            "sample_count": execution.sample_count,
            "minimum_expected_samples": expected_steps,
            "required_outputs": outputs,
            "missing_outputs": [name for name in outputs if name not in trace],
        }
        report["trace_gate"] = trace_gate
        if not trace_gate["success"]:
            report["failure_stage"] = "runtime_trace"
            return report

        properties = _evaluate_behavior_properties(
            trace, requirement_ir.get("properties", []), mappings
        )
        report["properties"] = properties
        report["property_summary"] = {
            "total": len(properties),
            "passed": sum(item.get("passed") is True for item in properties),
            "violated": sum(item.get("status") == "violated" for item in properties),
            "unevaluable": sum(item.get("status") == "unevaluable" for item in properties),
        }
        report["execution_completed"] = True
        report["behavior_evaluated"] = (
            len(properties) == len(requirement_ir.get("properties", []))
        )
        report["behavior_passed"] = bool(properties) and all(
            item.get("passed") is True for item in properties
        )
        report["passed"] = (
            report["execution_completed"]
            and report["behavior_evaluated"]
            and report["behavior_passed"]
        )
        report["failure_stage"] = None if report["passed"] else "behavior_evaluation"
        report["trace"] = str(execution.result_file)
        return report


def _execution_clock(clock: object) -> dict | None:
    if not isinstance(clock, dict):
        return None
    try:
        frequency = float(clock["frequency_hz"])
        if "duration" in clock:
            start = 0.0
            stop = float(clock["duration"])
        else:
            start = float(clock["start_time"])
            stop = float(clock["stop_time"])
    except (KeyError, TypeError, ValueError):
        return None
    if not all(math.isfinite(item) for item in (frequency, start, stop)):
        return None
    if frequency <= 0 or stop <= start:
        return None
    return {
        "start_time": start,
        "stop_time": stop,
        "frequency_hz": frequency,
        "step_size": 1.0 / frequency,
    }


def _units_compatible(expected: str, actual: str) -> bool:
    if expected == actual:
        return True
    try:
        conversion(expected, actual)
    except UnitError:
        return False
    return True


def _evaluate_behavior_properties(trace: dict[str, list[float]],
                                  properties: list[dict],
                                  mappings: list[dict]) -> list[dict]:
    by_interface = {row.get("interface_id"): row for row in mappings}
    by_state = {row.get("state_id"): row for row in mappings}
    results = []
    for prop in properties:
        kind = str(prop.get("kind", ""))
        mapping = (
            by_interface.get(prop.get("interface_id"))
            or by_state.get(prop.get("state_id"))
        )
        signal = mapping.get("fmu_variable") if mapping else None
        if kind in {"always", "eventually", "final"} and signal:
            candidate = {
                key: value for key, value in prop.items()
                if key in {"id", "kind", "lower", "upper", "start", "end"}
            }
            candidate["signal"] = signal
            try:
                result = evaluate_properties(trace, [candidate])[0]
                row = asdict(result)
                row["id"] = row["property_id"]
                row["status"] = "satisfied" if result.passed else "violated"
                row["interface_id"] = prop.get("interface_id")
                results.append(row)
            except (KeyError, TypeError, ValueError) as exc:
                results.append(_unevaluable(prop, f"invalid temporal property: {exc}"))
            continue
        if kind == "response" and signal and ("lower" in prop or "upper" in prop):
            candidate = {
                key: value for key, value in prop.items()
                if key in {"id", "lower", "upper", "start", "end"}
            }
            candidate.update({"kind": "always", "signal": signal})
            try:
                result = evaluate_properties(trace, [candidate])[0]
                row = asdict(result)
                row["id"] = row["property_id"]
                row["status"] = "satisfied" if result.passed else "violated"
                row["interface_id"] = prop.get("interface_id")
                row["interpretation"] = "bounded response interval"
                results.append(row)
            except (KeyError, TypeError, ValueError) as exc:
                results.append(_unevaluable(prop, f"invalid response property: {exc}"))
            continue
        text = " ".join([str(prop.get("id", "")), *map(str, prop.get("evidence", []))]).lower()
        if any(token in text for token in ("finite", "nan", "infinite")):
            results.append({
                "id": prop.get("id"),
                "property_id": prop.get("id"),
                "formula": "all requested runtime outputs are finite",
                "passed": True,
                "status": "satisfied",
                "robustness": None,
                "detail": "finite-value trace gate passed",
            })
            continue
        if "trace" in text and any(token in text for token in ("retain", "retention", "synchronized")):
            results.append({
                "id": prop.get("id"),
                "property_id": prop.get("id"),
                "formula": "runtime trace exists and contains required outputs",
                "passed": True,
                "status": "satisfied",
                "robustness": None,
                "detail": "trace completeness gate passed",
            })
            continue
        results.append(_unevaluable(
            prop, "no deterministic evaluator exists for this grounded property kind"
        ))
    return results


def _unevaluable(prop: dict, detail: str) -> dict:
    return {
        "id": prop.get("id"),
        "property_id": prop.get("id"),
        "formula": str(prop.get("kind", "unknown")),
        "passed": False,
        "status": "unevaluable",
        "robustness": None,
        "detail": detail,
    }
