"""Multi-modal SysML v2 generation pipeline (Pass 1)."""

import sysml_pipeline.config  # noqa: F401 — bootstrap nl2sysml on sys.path

__all__ = ["run_pass_1"]


def __getattr__(name: str):
    if name == "run_pass_1":
        from .main import run_pass_1 as fn

        return fn
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
