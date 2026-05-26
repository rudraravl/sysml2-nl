"""Sandboxed subprocess execution for Path A generated Python (Verifier 1)."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List

from sysml_pipeline.config import OUTPUT_SYSML_FILENAME, SANDBOX_TIMEOUT_SEC


@dataclass
class SandboxResult:
    success: bool
    sysml_output: str
    stdout: str
    stderr: str
    exit_code: int
    logs: List[Dict[str, Any]] = field(default_factory=list)
    work_dir: str = ""


def _log(logs: List[Dict[str, Any]], level: str, message: str, **extra: Any) -> None:
    entry: Dict[str, Any] = {"level": level, "message": message}
    entry.update(extra)
    logs.append(entry)


def _collect_sysml(work_dir: Path, stdout: str) -> str:
    out_file = work_dir / OUTPUT_SYSML_FILENAME
    if out_file.is_file():
        return out_file.read_text(encoding="utf-8").strip()

    for p in sorted(work_dir.glob("*.sysml")):
        text = p.read_text(encoding="utf-8").strip()
        if text:
            return text

    stripped = stdout.strip()
    if stripped and ("package " in stripped or "part " in stripped or "requirement " in stripped):
        return stripped
    return ""


def run_python_script(script: str) -> SandboxResult:
    """
    Execute generated Python in an isolated temp directory.
    Captures stdout/stderr and any written .sysml files.
    """
    logs: List[Dict[str, Any]] = []
    with tempfile.TemporaryDirectory(prefix="vlm_pass1_") as tmp:
        work = Path(tmp)
        script_path = work / "generated_sysml_builder.py"
        script_path.write_text(script, encoding="utf-8")
        env = os.environ.copy()
        env["SYSML_OUTPUT_PATH"] = str(work / OUTPUT_SYSML_FILENAME)

        _log(logs, "info", "Starting sandbox execution", script_path=str(script_path))

        try:
            proc = subprocess.run(
                [sys.executable, str(script_path)],
                cwd=str(work),
                capture_output=True,
                text=True,
                timeout=SANDBOX_TIMEOUT_SEC,
                env=env,
            )
        except subprocess.TimeoutExpired as e:
            _log(logs, "error", f"Execution timed out after {SANDBOX_TIMEOUT_SEC}s")
            return SandboxResult(
                success=False,
                sysml_output="",
                stdout=(e.stdout or "") if e.stdout else "",
                stderr=(e.stderr or "") if e.stderr else "",
                exit_code=-1,
                logs=logs,
                work_dir=str(work),
            )

        stdout = proc.stdout or ""
        stderr = proc.stderr or ""
        sysml = _collect_sysml(work, stdout)
        ok = proc.returncode == 0 and bool(sysml)

        _log(
            logs,
            "info" if ok else "error",
            "Sandbox finished",
            exit_code=proc.returncode,
            sysml_chars=len(sysml),
        )
        if stderr.strip():
            _log(logs, "debug", "stderr", text=stderr[:4000])
        if not ok and proc.returncode != 0:
            _log(logs, "error", "Non-zero exit code", exit_code=proc.returncode)

        return SandboxResult(
            success=ok,
            sysml_output=sysml,
            stdout=stdout,
            stderr=stderr,
            exit_code=proc.returncode,
            logs=logs,
            work_dir=str(work),
        )


def format_execution_error(result: SandboxResult) -> str:
    """Compact traceback message for Path A regeneration."""
    parts = [f"exit_code={result.exit_code}"]
    if result.stderr.strip():
        parts.append("stderr:\n" + result.stderr.strip())
    if result.stdout.strip() and not result.sysml_output:
        parts.append("stdout:\n" + result.stdout.strip()[:2000])
    if not result.sysml_output:
        parts.append("No SysML output file or recognizable stdout SysML.")
    return "\n\n".join(parts)
