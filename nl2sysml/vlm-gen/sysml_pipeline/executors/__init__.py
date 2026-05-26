"""Execution backends for generated artifacts."""

from .sandbox import SandboxResult, run_python_script

__all__ = ["SandboxResult", "run_python_script"]
