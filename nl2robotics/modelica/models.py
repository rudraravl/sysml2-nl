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
