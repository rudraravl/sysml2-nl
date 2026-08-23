"""Prepare and verify portable inputs for a Newton-backed H2 run."""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path

from nl2robotics.modelica.openmodelica import OpenModelicaRunner
from nl2robotics.openusd.validator import OpenUSDValidator
from nl2robotics.openusd.local_validator import LocalOpenUSDValidator

from .isaac_bundle import (
    BUNDLE_SCHEMA_VERSION,
    IsaacBundleError,
    load_hybrid_bundle,
    prepare_hybrid_bundle,
)


NewtonBundleError = IsaacBundleError


def prepare_newton_bundle(*, modelica_path: Path, usd_path: Path,
                          requirement_ir_path: Path, contract_path: Path,
                          output_dir: Path,
                          modelica_backend: str = "docker",
                          modelica_runner: OpenModelicaRunner | None = None,
                          usd_validator: OpenUSDValidator | None = None,
                          controller_runtime_factory: Callable[[Path], object]
                          | None = None) -> dict:
    usd_validator = usd_validator or LocalOpenUSDValidator()
    return prepare_hybrid_bundle(
        modelica_path=modelica_path,
        usd_path=usd_path,
        requirement_ir_path=requirement_ir_path,
        contract_path=contract_path,
        output_dir=output_dir,
        execution_mode="newton_closed_loop",
        modelica_backend=modelica_backend,
        modelica_runner=modelica_runner,
        usd_validator=usd_validator,
        controller_runtime_factory=controller_runtime_factory,
    )


def load_newton_bundle(manifest_path: Path) -> dict:
    return load_hybrid_bundle(
        manifest_path,
        expected_mode="newton_closed_loop",
        backend_name="Newton",
    )


__all__ = [
    "BUNDLE_SCHEMA_VERSION",
    "NewtonBundleError",
    "load_newton_bundle",
    "prepare_newton_bundle",
]
