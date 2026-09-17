"""End-to-end portable FMU-owned OpenUSD kinematic execution."""

from __future__ import annotations

from dataclasses import asdict
import hashlib
from pathlib import Path

from nl2robotics.contracts.hybrid_contract import HybridContractValidator
from nl2robotics.modelica.fmu_runtime import FMIContainerRunner
from nl2robotics.modelica.openmodelica import OpenModelicaRunner
from nl2robotics.modelica.properties import evaluate_properties, read_trace

from .playback import OpenUSDPlaybackRunner
from .trace import write_synchronized_trace


class PortableHybridPipeline:
    def __init__(self, *, modelica_runner: OpenModelicaRunner | None = None,
                 fmi_runner: FMIContainerRunner | None = None,
                 contract_validator: HybridContractValidator | None = None,
                 playback_runner: OpenUSDPlaybackRunner | None = None):
        self.modelica_runner = modelica_runner or OpenModelicaRunner()
        self.fmi_runner = fmi_runner or FMIContainerRunner()
        self.contract_validator = contract_validator or HybridContractValidator()
        self.playback_runner = playback_runner or OpenUSDPlaybackRunner()

    def run(self, modelica: str, source_usd: Path, requirement_ir: dict,
            contract: dict, *, output_dir: Path) -> dict:
        output_dir.mkdir(parents=True, exist_ok=True)
        report = {
            "stage": "portable_hybrid",
            "task_id": contract.get("task_id"),
            "execution_mode": contract.get("execution_mode"),
            "passed": False,
        }
        fmu = self.modelica_runner.export_fmu(
            modelica, output_dir=output_dir / "modelica" / "export"
        )
        report["fmu"] = fmu.to_dict()
        if not fmu.success or not fmu.fmu_path:
            return report

        contract_result = self.contract_validator.validate(
            contract,
            requirement_ir,
            fmu_path=fmu.fmu_path,
            usd_path=source_usd,
            output_dir=output_dir / "contract",
        )
        report["contract"] = contract_result.to_dict()
        if not contract_result.success:
            return report

        clock = contract["clock"]
        mappings = contract_result.resolved_mappings
        outputs = sorted({item["fmu_variable"] for item in mappings})
        execution = self.fmi_runner.run(
            fmu.fmu_path,
            start_time=float(clock["start_time"]),
            stop_time=float(clock["stop_time"]),
            step_size=float(clock["step_size"]),
            outputs=outputs,
            output_dir=output_dir / "modelica" / "execution",
        )
        report["execution"] = execution.to_dict()
        if not execution.success or not execution.result_file:
            return report

        trace = read_trace(execution.result_file)
        initialization = _validate_initial_values(trace, mappings)
        report["initialization"] = initialization
        if not initialization["success"]:
            return report
        properties = evaluate_properties(
            trace, requirement_ir.get("properties", [])
        )
        report["properties"] = [asdict(item) for item in properties]
        synchronized = write_synchronized_trace(
            execution.result_file,
            mappings,
            output_dir / "hybrid" / "synchronized-trace.csv",
        )
        report["synchronized_trace"] = synchronized
        playback = self.playback_runner.run(
            source_usd,
            execution.result_file,
            mappings=mappings,
            clock=clock,
            output_dir=output_dir / "hybrid" / "openusd",
        )
        report["playback"] = playback
        report["passed"] = playback.get("success") is True and all(
            item.passed for item in properties
        )
        report["artifacts"] = _artifact_hashes(
            modelica=modelica,
            fmu=fmu.fmu_path,
            source_usd=source_usd,
            trace=execution.result_file,
            synchronized=Path(synchronized["path"]),
            animated=Path(playback["animated_stage"])
            if playback.get("animated_stage") else None,
        )
        return report


def _validate_initial_values(trace: dict[str, list[float]], mappings: list[dict]) -> dict:
    rows = []
    for mapping in mappings:
        variable = mapping["fmu_variable"]
        values = trace.get(variable, [])
        expected = mapping.get("initial_value")
        scale = float(mapping.get("scale", 1.0))
        tolerance = float(mapping["numeric_tolerance"])
        actual = values[0] if values else None
        error_target_units = (
            abs(float(actual) - float(expected)) * abs(scale)
            if actual is not None and isinstance(expected, (int, float)) else None
        )
        passed = error_target_units is not None and error_target_units <= tolerance
        rows.append({
            "mapping_id": mapping.get("id"),
            "fmu_variable": variable,
            "expected_source_value": expected,
            "actual_source_value": actual,
            "error_target_units": error_target_units,
            "tolerance_target_units": tolerance,
            "passed": passed,
        })
    return {"success": all(item["passed"] for item in rows), "mappings": rows}


def _artifact_hashes(*, modelica: str, fmu: Path, source_usd: Path,
                     trace: Path, synchronized: Path,
                     animated: Path | None) -> dict:
    result = {
        "modelica_source_sha256": hashlib.sha256(modelica.encode("utf-8")).hexdigest(),
        "fmu_sha256": _hash_file(fmu),
        "source_usd_sha256": _hash_file(source_usd),
        "fmu_trace_sha256": _hash_file(trace),
        "synchronized_trace_sha256": _hash_file(synchronized),
    }
    if animated and animated.is_file():
        result["animated_usd_sha256"] = _hash_file(animated)
    return result


def _hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()
