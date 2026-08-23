"""Load and statically audit the frozen robotics development benchmark."""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import re

from nl2robotics.contracts.requirement_ir import validate_requirement_ir


PROFILES = {"modelica", "openusd", "hybrid"}
VARIANTS = {"rich", "concise", "underspecified"}


@dataclass(frozen=True)
class BenchmarkTask:
    id: str
    profile: str
    category: str
    difficulty: str
    target_level: str
    oracle: dict
    prompt_variants: dict[str, str]
    labeled_unknowns: tuple[str, ...]


class BenchmarkSuite:
    def __init__(self, root: Path | None = None):
        self.root = root or Path(__file__).resolve().parent
        rows = json.loads((self.root / "manifest.json").read_text(encoding="utf-8"))
        self.tasks = [self._load(row) for row in rows]

    def _load(self, row: dict) -> BenchmarkTask:
        variants = dict(row["prompt_variants"])
        if variants.get("rich") == "@request":
            bundle = (self.root / row["oracle"]["bundle"]).resolve()
            variants["rich"] = (bundle / "request.txt").read_text(encoding="utf-8").strip()
        return BenchmarkTask(
            id=row["id"], profile=row["profile"], category=row["category"],
            difficulty=row["difficulty"], target_level=row["target_level"],
            oracle=dict(row["oracle"]), prompt_variants=variants,
            labeled_unknowns=tuple(row["labeled_unknowns"]),
        )

    def select(self, *, profile: str | None = None,
               variant: str = "rich") -> list[tuple[BenchmarkTask, str]]:
        if variant not in VARIANTS:
            raise ValueError(f"unknown prompt variant {variant!r}")
        return [
            (task, task.prompt_variants[variant]) for task in self.tasks
            if profile is None or task.profile == profile
        ]

    def audit(self) -> dict:
        issues: list[dict] = []
        ids: set[str] = set()
        counts = {profile: 0 for profile in PROFILES}
        modelica_eval = _modelica_evaluation_ids()
        rag_hashes = _rag_artifact_hashes()

        for index, task in enumerate(self.tasks):
            path = f"$[{index}]"
            if task.id in ids:
                issues.append(_issue("duplicate_id", path, task.id))
            ids.add(task.id)
            if task.profile not in PROFILES:
                issues.append(_issue("invalid_profile", path, task.profile))
                continue
            counts[task.profile] += 1
            if set(task.prompt_variants) != VARIANTS:
                issues.append(_issue("missing_variant", path, str(task.prompt_variants)))
            elif len(set(task.prompt_variants.values())) != len(VARIANTS):
                issues.append(_issue("duplicate_variant", path, task.id))
            if not task.labeled_unknowns:
                issues.append(_issue("missing_unknown_labels", path, task.id))
            if task.profile == "modelica":
                evaluation_id = task.oracle.get("evaluation_task_id")
                if evaluation_id not in modelica_eval:
                    issues.append(_issue("unknown_modelica_oracle", path, str(evaluation_id)))
                artifact = (self.root / str(task.oracle.get("artifact", ""))).resolve()
                if not artifact.is_file():
                    issues.append(_issue("missing_modelica_oracle", path, str(artifact)))
                elif _hash_file(artifact) in rag_hashes:
                    issues.append(_issue("rag_artifact_leakage", path, str(artifact)))
            elif task.profile == "openusd":
                artifact = (self.root / str(task.oracle.get("artifact", ""))).resolve()
                if not artifact.is_file():
                    issues.append(_issue("missing_openusd_oracle", path, str(artifact)))
                elif _hash_file(artifact) in rag_hashes:
                    issues.append(_issue("rag_artifact_leakage", path, str(artifact)))
            else:
                bundle = (self.root / str(task.oracle.get("bundle", ""))).resolve()
                required = ("request.txt", "requirement_ir.json", "model.mo",
                            "scene.usda", "contract.json")
                for filename in required:
                    if not (bundle / filename).is_file():
                        issues.append(_issue("missing_hybrid_oracle", path,
                                             str(bundle / filename)))
                if (bundle / "requirement_ir.json").is_file():
                    ir = json.loads((bundle / "requirement_ir.json").read_text())
                    validation = validate_requirement_ir(ir)
                    for item in validation.issues:
                        issues.append(_issue(item.code, path + item.path, item.message))
                    if ir.get("source_text", "").strip() != task.prompt_variants["rich"]:
                        issues.append(_issue("hybrid_prompt_mismatch", path, task.id))

        if counts != {"modelica": 5, "openusd": 5, "hybrid": 5}:
            issues.append(_issue("unbalanced_profiles", "$", str(counts)))
        return {
            "stage": "benchmark_static_audit",
            "schema_version": "1.0",
            "success": not issues,
            "task_count": len(self.tasks),
            "profile_counts": counts,
            "variant_count": len(self.tasks) * len(VARIANTS),
            "issues": issues,
            "manifest_sha256": _hash_file(self.root / "manifest.json"),
        }


def _modelica_evaluation_ids() -> set[str]:
    path = Path(__file__).resolve().parents[1] / "modelica" / "examples" / "evaluation_tasks.json"
    return {item["id"] for item in json.loads(path.read_text(encoding="utf-8"))}


def _rag_artifact_hashes() -> set[str]:
    root = Path(__file__).resolve().parents[1]
    hashes = set()
    for manifest_path, file_key in (
        (root / "modelica" / "examples" / "manifest.json", "model_file"),
        (root / "openusd" / "examples" / "manifest.json", "model"),
    ):
        base = manifest_path.parent
        for row in json.loads(manifest_path.read_text(encoding="utf-8")):
            if row.get("split") == "rag":
                hashes.add(_hash_file(base / row[file_key]))
    return hashes


def token_jaccard(left: str, right: str) -> float:
    pattern = re.compile(r"[A-Za-z][A-Za-z0-9_]*")
    a = {item.lower() for item in pattern.findall(left)}
    b = {item.lower() for item in pattern.findall(right)}
    return len(a & b) / len(a | b) if a or b else 1.0


def _hash_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _issue(code: str, path: str, message: str) -> dict:
    return {"code": code, "path": path, "message": message}
