"""Prepare and verify portable inputs for an Isaac-backed H2 run."""

from __future__ import annotations

import hashlib
import json
from collections.abc import Callable
from pathlib import Path
import shutil

from nl2robotics.contracts.hybrid_contract import HybridContractValidator, load_json
from nl2robotics.modelica.fmi_controller import (
    FMIContainerControllerRuntime,
    FMPyControllerRuntime,
)
from nl2robotics.modelica.openmodelica import OpenModelicaRunner
from nl2robotics.openusd.validator import OpenUSDValidator

from .controller_conformance import evaluate_controller_conformance


BUNDLE_SCHEMA_VERSION = "1.1"


class IsaacBundleError(RuntimeError):
    pass


def prepare_isaac_bundle(*, modelica_path: Path, usd_path: Path,
                         requirement_ir_path: Path, contract_path: Path,
                         output_dir: Path,
                         modelica_backend: str = "docker",
                         modelica_runner: OpenModelicaRunner | None = None,
                         usd_validator: OpenUSDValidator | None = None,
                         controller_runtime_factory: Callable[[Path], object]
                         | None = None) -> dict:
    """Compile and cross-check H2 inputs before simulator execution."""
    output_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = output_dir / "execution-input.json"
    if manifest_path.exists():
        raise IsaacBundleError(f"bundle already exists: {manifest_path}")

    modelica = modelica_path.read_text(encoding="utf-8")
    requirement_ir = load_json(requirement_ir_path)
    contract = load_json(contract_path)
    modelica_runner = modelica_runner or OpenModelicaRunner(
        backend=modelica_backend
    )
    usd_validator = usd_validator or OpenUSDValidator()
    export = modelica_runner.export_fmu(
        modelica, output_dir=output_dir / "modelica"
    )
    report = {
        "stage": "isaac_bundle_preparation",
        "success": False,
        "claim_eligible_h2": False,
        "fmu": export.to_dict(),
    }
    if not export.success or export.fmu_path is None:
        return _write_preparation_report(output_dir, report)

    validation = HybridContractValidator(usd_validator=usd_validator).validate(
        contract,
        requirement_ir,
        fmu_path=export.fmu_path,
        usd_path=usd_path,
        output_dir=output_dir / "contract-validation",
    )
    report["contract"] = validation.to_dict()
    if not validation.success:
        return _write_preparation_report(output_dir, report)

    if controller_runtime_factory is None:
        controller_runtime_factory = _controller_runtime_factory(
            modelica_runner.resolved_backend()
        )
    conformance = evaluate_controller_conformance(
        export.fmu_path,
        requirement_ir,
        validation.resolved_mappings,
        contract["clock"],
        controller_runtime_factory,
    )
    report["controller_conformance"] = conformance
    if not conformance["success"]:
        return _write_preparation_report(output_dir, report)

    inputs = output_dir / "inputs"
    inputs.mkdir(parents=True, exist_ok=True)
    request_path = inputs / "request.txt"
    request_path.write_text(
        str(requirement_ir["source_text"]).rstrip() + "\n", encoding="utf-8"
    )
    copied = {
        "request": request_path.resolve(),
        "modelica": _copy(modelica_path, inputs / "controller.mo"),
        "openusd": _copy(usd_path, inputs / "scene.usda"),
        "requirement_ir": _copy(requirement_ir_path, inputs / "requirement_ir.json"),
        "contract": _copy(contract_path, inputs / "contract.json"),
    }
    artifacts = {
        **copied,
        "fmu": export.fmu_path.resolve(),
    }
    manifest = {
        "schema_version": BUNDLE_SCHEMA_VERSION,
        "task_id": contract["task_id"],
        "execution_mode": contract["execution_mode"],
        "artifacts": {
            key: {
                "path": str(path.relative_to(output_dir.resolve())),
                "sha256": _sha256(path),
            }
            for key, path in artifacts.items()
        },
        "resolved_mappings": validation.resolved_mappings,
        "clock": contract["clock"],
        "coupling": contract["coupling"],
        "properties": requirement_ir.get("properties", []),
        "toolchain": {
            "modelica_backend": modelica_runner.resolved_backend(),
            "openmodelica_image": modelica_runner.image,
            "openusd_validator": usd_validator.checker,
            "openusd_runtime_image": usd_validator.image,
        },
        "preflight": {
            "fmu": {
                "fmi_version": validation.fmu.get("fmi_version"),
                "interface_type": validation.fmu.get("interface_type"),
                "model_name": validation.fmu.get("model_name"),
                "model_identifier": validation.fmu.get("model_identifier"),
            },
            "openusd": validation.openusd,
            "contract_validation": validation.to_dict(),
            "controller_conformance": conformance,
        },
    }
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    report.update({
        "success": True,
        "manifest": str(manifest_path),
        "manifest_sha256": _sha256(manifest_path),
    })
    return _write_preparation_report(output_dir, report)


def load_isaac_bundle(manifest_path: Path) -> dict:
    """Load a bundle and reject modified or escaping artifacts."""
    manifest_path = manifest_path.resolve()
    manifest = load_json(manifest_path)
    if manifest.get("schema_version") != BUNDLE_SCHEMA_VERSION:
        raise IsaacBundleError("unsupported Isaac execution bundle schema")
    if manifest.get("execution_mode") != "isaac_closed_loop":
        raise IsaacBundleError("Isaac runner requires isaac_closed_loop mode")
    root = manifest_path.parent
    resolved = {}
    artifacts = manifest.get("artifacts")
    if not isinstance(artifacts, dict) or not artifacts:
        raise IsaacBundleError("bundle has no artifacts")
    for name, record in artifacts.items():
        if not isinstance(record, dict):
            raise IsaacBundleError(f"invalid artifact record {name!r}")
        path = (root / str(record.get("path", ""))).resolve()
        if path != root and root not in path.parents:
            raise IsaacBundleError(f"artifact escapes bundle root: {name}")
        if not path.is_file():
            raise IsaacBundleError(f"bundle artifact is missing: {name}")
        actual = _sha256(path)
        if actual != record.get("sha256"):
            raise IsaacBundleError(f"bundle artifact hash mismatch: {name}")
        resolved[name] = path
    required = {
        "request", "modelica", "openusd", "requirement_ir", "contract", "fmu"
    }
    missing = required - resolved.keys()
    if missing:
        raise IsaacBundleError(f"bundle is missing artifacts: {sorted(missing)}")
    _validate_execution_manifest(manifest)
    manifest["resolved_artifacts"] = resolved
    manifest["manifest_path"] = manifest_path
    manifest["manifest_sha256"] = _sha256(manifest_path)
    return manifest


def _validate_execution_manifest(manifest: dict) -> None:
    if not isinstance(manifest.get("task_id"), str) or not manifest["task_id"]:
        raise IsaacBundleError("bundle has no task_id")
    mappings = manifest.get("resolved_mappings")
    if not isinstance(mappings, list) or not mappings:
        raise IsaacBundleError("bundle has no resolved mappings")
    if not isinstance(manifest.get("clock"), dict):
        raise IsaacBundleError("bundle has no execution clock")
    if not isinstance(manifest.get("coupling"), dict):
        raise IsaacBundleError("bundle has no coupling protocol")
    properties = manifest.get("properties")
    if not isinstance(properties, list) or not properties:
        raise IsaacBundleError("H2 bundle has no behavioral properties")
    preflight = manifest.get("preflight")
    if not isinstance(preflight, dict):
        raise IsaacBundleError("bundle has no preflight evidence")
    contract = preflight.get("contract_validation")
    if not isinstance(contract, dict) or contract.get("success") is not True:
        raise IsaacBundleError("bundle contract preflight did not pass")
    conformance = preflight.get("controller_conformance")
    if not isinstance(conformance, dict) or conformance.get("success") is not True:
        raise IsaacBundleError("bundle controller conformance did not pass")


def _copy(source: Path, destination: Path) -> Path:
    shutil.copy2(source.resolve(), destination)
    return destination.resolve()


def _controller_runtime_factory(backend: str) -> Callable[[Path], object]:
    if backend == "docker":
        return lambda path: FMIContainerControllerRuntime(path)
    return lambda path: FMPyControllerRuntime(path)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _write_preparation_report(output_dir: Path, report: dict) -> dict:
    (output_dir / "preparation.json").write_text(
        json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    return report
