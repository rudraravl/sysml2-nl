"""Pinned OpenUSD kinematic playback authoring and independent inspection."""

from __future__ import annotations

import json
from pathlib import Path
import shutil
import subprocess
import time

from nl2robotics.openusd.validator import OpenUSDValidator


class OpenUSDPlaybackRunner:
    def __init__(self, *, image: str = "nl2robotics-openusd-runtime:0.1",
                 timeout: int = 120,
                 validator: OpenUSDValidator | None = None):
        self.image = image
        self.timeout = timeout
        self.validator = validator or OpenUSDValidator(image=image, timeout=timeout)

    def available(self) -> bool:
        if not shutil.which("docker"):
            return False
        names = [self.image]
        if "/" not in self.image:
            names.append(f"docker.io/library/{self.image}")
        return any(subprocess.run(
            ["docker", "image", "inspect", name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode == 0 for name in names)

    def run(self, source_stage: Path, trace: Path, *, mappings: list[dict],
            clock: dict, output_dir: Path) -> dict:
        if not source_stage.is_file():
            return _failure("missing_stage", f"stage does not exist: {source_stage}")
        if not trace.is_file():
            return _failure("missing_trace", f"trace does not exist: {trace}")
        if not mappings:
            return _failure("missing_mappings", "no resolved mappings were provided")
        if not self.available():
            return _failure(
                "runtime_unavailable", f"OpenUSD runtime image is unavailable: {self.image}"
            )

        output_dir.mkdir(parents=True, exist_ok=True)
        local_stage = output_dir / "source.usda"
        local_trace = output_dir / "fmu-trace.csv"
        animated = output_dir / "animated.usda"
        config_path = output_dir / "playback-config.json"
        author_report_path = output_dir / "author.json"
        inspect_report_path = output_dir / "inspection.json"
        shutil.copy2(source_stage, local_stage)
        shutil.copy2(trace, local_trace)
        config_path.write_text(json.dumps({
            "clock": clock,
            "mappings": mappings,
        }, indent=2, allow_nan=False), encoding="utf-8")
        for stale in (animated, author_report_path, inspect_report_path):
            stale.unlink(missing_ok=True)

        started = time.monotonic()
        author = self._run_container([
            "python3", "/opt/nl2robotics/author_playback.py",
            "--stage", "/work/source.usda",
            "--trace", "/work/fmu-trace.csv",
            "--config", "/work/playback-config.json",
            "--output", "/work/animated.usda",
            "--report", "/work/author.json",
        ], output_dir)
        author_report = _read_report(author_report_path)
        if author.returncode != 0 or not author_report.get("success"):
            return {
                **_failure(
                    "author_failed",
                    author_report.get("error") or author.stdout.strip()
                    or "OpenUSD playback authoring failed",
                ),
                "author": author_report,
                "duration_seconds": time.monotonic() - started,
            }

        inspection = self._run_container([
            "python3", "/opt/nl2robotics/inspect_playback.py",
            "--stage", "/work/animated.usda",
            "--trace", "/work/fmu-trace.csv",
            "--config", "/work/playback-config.json",
            "--report", "/work/inspection.json",
        ], output_dir)
        inspection_report = _read_report(inspect_report_path)
        validation = self.validator.validate(
            animated, output_dir=output_dir / "validation"
        )
        success = (
            inspection.returncode == 0
            and inspection_report.get("success") is True
            and validation.success
        )
        issues = []
        if inspection.returncode != 0 or not inspection_report.get("success"):
            issues.append({
                "code": "inspection_failed",
                "message": inspection_report.get("error")
                or inspection.stdout.strip() or "playback inspection failed",
            })
        if not validation.success:
            issues.append({
                "code": "animated_stage_invalid",
                "message": "animated stage failed OpenUSD validation",
            })
        return {
            "stage": "openusd_playback",
            "success": success,
            "animated_stage": str(animated) if animated.is_file() else None,
            "author": author_report,
            "inspection": inspection_report,
            "validation": validation.to_dict(),
            "issues": issues,
            "duration_seconds": time.monotonic() - started,
        }

    def _run_container(self, command: list[str], work: Path):
        try:
            return subprocess.run(
                [
                    "docker", "run", "--rm", "--platform", "linux/amd64",
                    "-v", f"{work.resolve()}:/work", self.image, *command,
                ],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=self.timeout,
            )
        except subprocess.TimeoutExpired as exc:
            return subprocess.CompletedProcess(
                exc.cmd, 124, stdout=f"runtime timed out after {self.timeout}s"
            )


def _read_report(path: Path) -> dict:
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as exc:
        return {"success": False, "error": f"invalid runtime report: {exc}"}
    return data if isinstance(data, dict) else {
        "success": False, "error": "runtime report root is not an object"
    }


def _failure(code: str, message: str) -> dict:
    return {
        "stage": "openusd_playback",
        "success": False,
        "animated_stage": None,
        "issues": [{"code": code, "message": message}],
    }
