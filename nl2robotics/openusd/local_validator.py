"""In-process OpenUSD validation for Linux/ARM64 research containers."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time

from .validator import OpenUSDIssue, OpenUSDValidation, _issues


class LocalOpenUSDValidator:
    """Run the pinned semantic inspector with the current OpenUSD Python SDK."""

    def __init__(self, *, python: str = sys.executable, timeout: int = 60):
        self.python = python
        self.timeout = timeout
        self.checker = "local_openusd_python"
        self.image = None
        self.script = Path(__file__).parent / "runtime" / "validate_stage.py"

    def available(self) -> bool:
        if not self.script.is_file():
            return False
        probe = subprocess.run(
            [self.python, "-c", "from pxr import Usd, UsdPhysics"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return probe.returncode == 0

    def validate(self, stage_path: Path, *,
                 output_dir: Path | None = None) -> OpenUSDValidation:
        if not stage_path.is_file():
            return OpenUSDValidation(False, stage_path, issues=[OpenUSDIssue(
                "source", "error", "missing_stage",
                f"OpenUSD stage does not exist: {stage_path}",
            )])
        if not self.available():
            return OpenUSDValidation(False, stage_path, issues=[OpenUSDIssue(
                "infrastructure", "error", "local_validator_unavailable",
                "the current Python environment cannot import pxr.Usd and UsdPhysics",
            )])
        work = output_dir or Path(tempfile.mkdtemp(prefix="openusd-local-"))
        work.mkdir(parents=True, exist_ok=True)
        report_path = work / "semantic.json"
        report_path.unlink(missing_ok=True)
        started = time.monotonic()
        try:
            process = subprocess.run(
                [
                    self.python, str(self.script), str(stage_path.resolve()),
                    "--report", str(report_path),
                ],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=self.timeout,
            )
        except subprocess.TimeoutExpired:
            return OpenUSDValidation(
                True, stage_path, duration_seconds=time.monotonic() - started,
                issues=[OpenUSDIssue(
                    "semantic", "error", "semantic_timeout",
                    f"OpenUSD semantic validation timed out after {self.timeout}s",
                )],
            )
        if not report_path.is_file():
            return OpenUSDValidation(
                True, stage_path, duration_seconds=time.monotonic() - started,
                checker_returncode=process.returncode,
                checker_output=process.stdout.strip(),
                issues=[OpenUSDIssue(
                    "semantic", "error", "missing_semantic_report",
                    process.stdout.strip() or "semantic validator returned no report",
                )],
            )
        try:
            report = json.loads(report_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as exc:
            return OpenUSDValidation(
                True, stage_path, duration_seconds=time.monotonic() - started,
                issues=[OpenUSDIssue(
                    "semantic", "error", "invalid_semantic_report", str(exc)
                )],
            )
        stage_opened = report.get("stage_opened") is True
        semantic_valid = process.returncode == 0 and report.get("success") is True
        return OpenUSDValidation(
            True,
            stage_path,
            syntax_valid=stage_opened,
            semantic_valid=semantic_valid,
            report_file=report_path,
            metadata=report.get("metadata", {}),
            counts=report.get("counts", {}),
            evidence=report.get("evidence", {}),
            issues=_issues(report.get("issues", [])),
            duration_seconds=time.monotonic() - started,
            checker_returncode=process.returncode,
            checker_output=process.stdout.strip(),
            checker_fallback=False,
        )
