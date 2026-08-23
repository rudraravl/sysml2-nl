"""Data returned by the Modelica validation and execution stages."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class Diagnostic:
    stage: str
    severity: str
    message: str


@dataclass
class ModelicaBuild:
    """Layer 1 result: the model checks and builds, but is never executed."""

    available: bool
    model_name: str
    checked: bool = False
    compiled: bool = False
    executable: Path | None = None
    check_message: str = ""
    build_message: str = ""
    diagnostics: list[Diagnostic] = field(default_factory=list)
    duration_seconds: float = 0.0

    @property
    def error_count(self) -> int:
        return sum(item.severity == "error" for item in self.diagnostics)

    @property
    def success(self) -> bool:
        return (
            self.available
            and self.checked
            and self.compiled
            and self.executable is not None
        )

    def to_dict(self) -> dict:
        data = asdict(self)
        data["success"] = self.success
        data["error_count"] = self.error_count
        data["executable"] = str(self.executable) if self.executable else None
        return data


@dataclass
class ModelicaRun:
    available: bool
    model_name: str
    checked: bool = False
    compiled: bool = False
    simulated: bool = False
    check_message: str = ""
    result_file: Path | None = None
    diagnostics: list[Diagnostic] = field(default_factory=list)
    duration_seconds: float = 0.0

    @property
    def success(self) -> bool:
        return self.available and self.checked and self.compiled and self.simulated

    def to_dict(self) -> dict:
        data = asdict(self)
        data["success"] = self.success
        data["result_file"] = str(self.result_file) if self.result_file else None
        return data


@dataclass(frozen=True)
class FMUVariable:
    name: str
    value_reference: int
    scalar_type: str
    causality: str
    variability: str
    initial: str | None = None
    unit: str | None = None
    start: str | None = None


@dataclass
class ModelicaFMU:
    available: bool
    model_name: str
    checked: bool = False
    exported: bool = False
    fmu_path: Path | None = None
    fmi_version: str = ""
    interface_type: str = ""
    model_identifier: str = ""
    variables: list[FMUVariable] = field(default_factory=list)
    diagnostics: list[Diagnostic] = field(default_factory=list)
    duration_seconds: float = 0.0

    @property
    def success(self) -> bool:
        return (
            self.available
            and self.checked
            and self.exported
            and self.fmu_path is not None
            and self.interface_type == "co_simulation"
        )

    @property
    def inputs(self) -> list[FMUVariable]:
        return [item for item in self.variables if item.causality == "input"]

    @property
    def outputs(self) -> list[FMUVariable]:
        return [item for item in self.variables if item.causality == "output"]

    def to_dict(self) -> dict:
        data = asdict(self)
        data["success"] = self.success
        data["fmu_path"] = str(self.fmu_path) if self.fmu_path else None
        data["inputs"] = [asdict(item) for item in self.inputs]
        data["outputs"] = [asdict(item) for item in self.outputs]
        return data


@dataclass
class FMUExecution:
    available: bool
    initialized: bool = False
    simulated: bool = False
    result_file: Path | None = None
    report_file: Path | None = None
    columns: list[str] = field(default_factory=list)
    sample_count: int = 0
    diagnostics: list[Diagnostic] = field(default_factory=list)
    duration_seconds: float = 0.0

    @property
    def success(self) -> bool:
        return (
            self.available
            and self.initialized
            and self.simulated
            and self.result_file is not None
        )

    def to_dict(self) -> dict:
        data = asdict(self)
        data["success"] = self.success
        data["result_file"] = str(self.result_file) if self.result_file else None
        data["report_file"] = str(self.report_file) if self.report_file else None
        return data


@dataclass(frozen=True)
class PropertyResult:
    property_id: str
    formula: str
    passed: bool
    robustness: float | None
    detail: str


@dataclass
class Layer1CandidateResult:
    code: str
    build: ModelicaBuild

    @property
    def passed(self) -> bool:
        return self.build.success

    @property
    def quality(self) -> tuple[int, int, int]:
        # Error reduction is useful progress when a repair does not yet build.
        return (
            int(self.build.compiled),
            int(self.build.checked),
            -self.build.error_count,
        )

    def to_dict(self) -> dict:
        return {
            "passed": self.passed,
            "quality": list(self.quality),
            "build": self.build.to_dict(),
        }


@dataclass
class CandidateResult:
    code: str
    run: ModelicaRun
    properties: list[PropertyResult] = field(default_factory=list)

    @property
    def passed(self) -> bool:
        return self.run.success and all(item.passed for item in self.properties)

    @property
    def quality(self) -> tuple[int, int, int]:
        passed = sum(item.passed for item in self.properties)
        return (int(self.run.compiled), int(self.run.simulated), passed)

    def to_dict(self) -> dict:
        return {
            "passed": self.passed,
            "quality": list(self.quality),
            "run": self.run.to_dict(),
            "properties": [asdict(item) for item in self.properties],
        }
