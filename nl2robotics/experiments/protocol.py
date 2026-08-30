"""Immutable study-input and execution-plan provenance for paper runs."""

from __future__ import annotations

import hashlib
from importlib import metadata
import json
from pathlib import Path
import platform
import subprocess

from nl2robotics.modelica.moe import COMBINER_MODEL, EXPERT_MODELS

from .records import run_fingerprint
from .runner import planned_cells


def freeze_protocol(*, repository: Path, output_dir: Path, tasks: list,
                    conditions: list, variant: str, repetitions: int,
                    configuration: dict, randomization_seed: int
                    ) -> tuple[dict, dict]:
    """Write the frozen inputs and exact ordered/fingerprinted cell plan."""
    core = {
        "schema_version": "1.0",
        "stage": "robotics_study_protocol_freeze",
        "randomization": {
            "design": "task_repetition_blocked_condition_randomization",
            "seed": randomization_seed,
        },
        "configuration": configuration,
        "conditions": [condition.to_dict() for condition in conditions],
        "task_prompts": [
            {
                "task_id": task.id,
                "profile": task.profile,
                "category": task.category,
                "prompt_sha256": _sha256_bytes(prompt.strip().encode("utf-8")),
            }
            for task, prompt in sorted(tasks, key=lambda item: item[0].id)
        ],
        "model_roster": {
            "experts": list(EXPERT_MODELS),
            "combiner": COMBINER_MODEL,
            "partial_ensembles_eligible": False,
        },
        "source_provenance": _source_provenance(repository),
        "corpora": {
            "modelica": _tree_provenance(
                repository / "nl2robotics" / "modelica" / "examples"
            ),
            "openusd": _tree_provenance(
                repository / "nl2robotics" / "openusd" / "examples"
            ),
        },
        "runtime_versions": _runtime_versions(),
        "validator_sources": {
            path: _file_sha256(repository / path)
            for path in (
                "nl2robotics/modelica/openmodelica.py",
                "nl2robotics/modelica/pipeline.py",
                "nl2robotics/openusd/validator.py",
                "nl2robotics/openusd/local_validator.py",
                "nl2robotics/openusd/runtime/validate_stage.py",
            )
        },
        "exclusion_policy": {
            "provider_usage_limit": "stop_without_recording_active_cell_then_resume",
            "missing_moe_expert": "infrastructure_exclusion_and_identical_rerun",
            "condition_fidelity_failure": "infrastructure_exclusion_and_identical_rerun",
            "generated_artifact_failure": "retain_as_model_outcome",
            "manual_artifact_edit": "prohibited",
        },
    }
    core_sha256 = _sha256_json(core)
    frozen_configuration = {
        **configuration,
        "study_protocol_core_sha256": core_sha256,
        "randomization_seed": randomization_seed,
    }
    plan = []
    for index, cell in enumerate(planned_cells(
        tasks, conditions, repetitions=repetitions, seed=randomization_seed
    )):
        task, prompt = cell["task"], cell["prompt"]
        condition, repetition = cell["condition"], cell["repetition"]
        plan.append({
            "order_index": index,
            "task_id": task.id,
            "condition_id": condition.id,
            "repetition": repetition,
            "fingerprint": run_fingerprint(
                task_id=task.id,
                condition=condition.to_dict(),
                variant=variant,
                repetition=repetition,
                prompt=prompt,
                configuration=frozen_configuration,
            ),
        })
    report = {
        **core,
        "protocol_core_sha256": core_sha256,
        "variant": variant,
        "repetitions": repetitions,
        "planned_cell_count": len(plan),
        "planned_cells": plan,
    }
    path = output_dir / "study-protocol.json"
    if path.is_file():
        existing = json.loads(path.read_text(encoding="utf-8"))
        if existing != report:
            raise ValueError(
                "study protocol differs from the existing frozen output; use a new "
                "output directory or restore the original configuration"
            )
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n",
            encoding="utf-8",
        )
    return report, frozen_configuration


def _source_provenance(repository: Path) -> dict:
    def git(*args: str) -> str:
        try:
            return subprocess.run(
                ("git", *args), cwd=repository, check=True,
                capture_output=True, text=True,
            ).stdout.strip()
        except (OSError, subprocess.CalledProcessError):
            return "unavailable"

    return {
        "repository": str(repository.resolve()),
        "git_commit": git("rev-parse", "HEAD"),
        "git_branch": git("branch", "--show-current"),
        "git_status": git("status", "--short"),
        "tracked_diff_sha256": _sha256_bytes(
            git("diff", "--no-ext-diff").encode("utf-8")
        ),
    }


def _tree_provenance(root: Path) -> dict:
    rows = []
    for path in sorted(item for item in root.rglob("*") if item.is_file()):
        rows.append({
            "path": str(path.relative_to(root)),
            "sha256": _sha256_bytes(path.read_bytes()),
        })
    return {
        "root": str(root.resolve()),
        "file_count": len(rows),
        "tree_sha256": _sha256_json(rows),
        "manifest_sha256": _file_sha256(root / "manifest.json"),
        "subsets_sha256": _file_sha256(root / "corpus_subsets.json"),
    }


def _runtime_versions() -> dict:
    packages = {}
    for name in ("FMPy", "newton", "warp-lang", "usd-core", "usd-exchange"):
        try:
            packages[name] = metadata.version(name)
        except metadata.PackageNotFoundError:
            packages[name] = "not_installed_in_planning_environment"
    return {
        "python": platform.python_version(),
        "platform": platform.platform(),
        "packages": packages,
        "modelica_validator": "OpenModelica selected backend recorded per run",
        "openusd_validator": "repository semantic validator plus configured pxr runtime",
    }


def _file_sha256(path: Path) -> str:
    return _sha256_bytes(path.read_bytes()) if path.is_file() else "missing"


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_json(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"))
    return _sha256_bytes(encoded.encode("utf-8"))
