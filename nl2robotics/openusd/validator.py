"""Pinned syntax and robotics-semantic validation for OpenUSD stages."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time


@dataclass(frozen=True)
class OpenUSDIssue:
    stage: str
    severity: str
    code: str
    message: str
    prim: str | None = None


@dataclass
class OpenUSDValidation:
    available: bool
    stage_path: Path
    syntax_valid: bool = False
    semantic_valid: bool = False
    report_file: Path | None = None
    metadata: dict = field(default_factory=dict)
    counts: dict = field(default_factory=dict)
    evidence: dict = field(default_factory=dict)
    issues: list[OpenUSDIssue] = field(default_factory=list)
    duration_seconds: float = 0.0
    checker_returncode: int | None = None
    checker_output: str = ""
    checker_fallback: bool = False

    @property
    def success(self) -> bool:
        return self.available and self.syntax_valid and self.semantic_valid

    @property
    def error_count(self) -> int:
        return sum(item.severity == "error" for item in self.issues)

    def to_dict(self) -> dict:
        data = asdict(self)
        data["success"] = self.success
        data["error_count"] = self.error_count
        data["stage_path"] = str(self.stage_path)
        data["report_file"] = str(self.report_file) if self.report_file else None
        return data


class OpenUSDValidator:
    def __init__(self, *, checker: str = "usdchecker",
                 image: str = "nl2robotics-openusd-runtime:0.1",
                 timeout: int = 60):
        self.checker = checker
        self.image = image
        self.timeout = timeout

    def available(self) -> bool:
        if not shutil.which(self.checker) or not shutil.which("docker"):
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

    def validate(self, stage_path: Path, *,
                 output_dir: Path | None = None) -> OpenUSDValidation:
        if not stage_path.is_file():
            return OpenUSDValidation(False, stage_path, issues=[OpenUSDIssue(
                "source", "error", "missing_stage",
                f"OpenUSD stage does not exist: {stage_path}",
            )])
        if not self.available():
            return OpenUSDValidation(False, stage_path, issues=[OpenUSDIssue(
                "infrastructure", "error", "validator_unavailable",
                "usdchecker or the pinned OpenUSD runtime image is unavailable",
            )])

        work = output_dir or Path(tempfile.mkdtemp(prefix="openusd-validate-"))
        work.mkdir(parents=True, exist_ok=True)
        report_path = work / "semantic.json"
        report_path.unlink(missing_ok=True)
        started = time.monotonic()
        try:
            syntax = subprocess.run(
                [self.checker, "--strict", str(stage_path)],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=self.timeout,
            )
        except subprocess.TimeoutExpired:
            return OpenUSDValidation(
                True,
                stage_path,
                duration_seconds=time.monotonic() - started,
                issues=[OpenUSDIssue(
                    "syntax", "error", "checker_timeout",
                    f"usdchecker timed out after {self.timeout}s",
                )],
            )

        checker_output = syntax.stdout.strip()
        checker_crashed = syntax.returncode < 0 or (
            syntax.returncode in {128 + 9, 128 + 11} and not checker_output
        )
        syntax_valid = syntax.returncode == 0
        issues = []
        if not syntax_valid and not checker_crashed:
            issues.append(OpenUSDIssue(
                "syntax", "error", "usdchecker_failed",
                checker_output or "usdchecker rejected the stage",
            ))
            return OpenUSDValidation(
                True,
                stage_path,
                syntax_valid=False,
                issues=issues,
                duration_seconds=time.monotonic() - started,
                checker_returncode=syntax.returncode,
                checker_output=checker_output,
            )
        if checker_crashed:
            issues.append(OpenUSDIssue(
                "infrastructure", "warning", "usdchecker_crashed",
                f"usdchecker exited {syntax.returncode} without a diagnostic; "
                "using the pinned OpenUSD parser as the syntax authority",
            ))

        command = [
            "docker", "run", "--rm", "--platform", "linux/amd64",
            "-v", f"{stage_path.parent.resolve()}:/input:ro",
            "-v", f"{work.resolve()}:/output",
            self.image,
            "python3", "/opt/nl2robotics/validate_stage.py",
            f"/input/{stage_path.name}",
            "--report", "/output/semantic.json",
        ]
        try:
            semantic = subprocess.run(
                command,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=self.timeout,
            )
        except subprocess.TimeoutExpired:
            return OpenUSDValidation(
                True,
                stage_path,
                syntax_valid=True,
                duration_seconds=time.monotonic() - started,
                issues=[OpenUSDIssue(
                    "semantic", "error", "semantic_timeout",
                    f"OpenUSD semantic validation timed out after {self.timeout}s",
                )],
            )

        report = {}
        if report_path.is_file():
            try:
                report = json.loads(report_path.read_text(encoding="utf-8"))
            except (json.JSONDecodeError, OSError) as exc:
                issues.append(OpenUSDIssue(
                    "semantic", "error", "invalid_semantic_report", str(exc)
                ))
        else:
            issues.append(OpenUSDIssue(
                "semantic", "error", "missing_semantic_report",
                semantic.stdout.strip() or "semantic validator returned no report",
            ))
        issues.extend(_issues(report.get("issues", [])))
        stage_opened = report.get("stage_opened") is True
        syntax_valid = syntax_valid or (checker_crashed and stage_opened)
        semantic_valid = semantic.returncode == 0 and report.get("success") is True
        return OpenUSDValidation(
            True,
            stage_path,
            syntax_valid=syntax_valid,
            semantic_valid=semantic_valid,
            report_file=report_path if report_path.is_file() else None,
            metadata=report.get("metadata", {}),
            counts=report.get("counts", {}),
            evidence=report.get("evidence", {}),
            issues=issues,
            duration_seconds=time.monotonic() - started,
            checker_returncode=syntax.returncode,
            checker_output=checker_output,
            checker_fallback=checker_crashed,
        )


def _issues(rows: list[dict]) -> list[OpenUSDIssue]:
    return [OpenUSDIssue(
        stage=str(row.get("stage", "semantic")),
        severity=str(row.get("severity", "error")),
        code=str(row.get("code", "unknown")),
        message=str(row.get("message", "")),
        prim=row.get("prim"),
    ) for row in rows]
