"""BenchmarkSuite-compatible view of the frozen capability study manifest."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from nl2robotics.benchmark.suite import BenchmarkTask

from .capability_matrix import MANIFEST, audit_manifest as audit_capability_manifest
from .paper_evaluation import audit_manifest as audit_paper_manifest


class CapabilityBenchmarkSuite:
    """Expose rich capability prompts without inventing post-freeze variants."""

    def __init__(self, manifest_path: Path = MANIFEST):
        self.manifest_path = manifest_path.resolve()
        self.root = self.manifest_path.parent
        data = json.loads(self.manifest_path.read_text(encoding="utf-8"))
        cases = data.get("cases") if isinstance(data, dict) else None
        routes = data.get("rag_family_routes") if isinstance(data, dict) else None
        if not isinstance(cases, list) or not cases:
            raise ValueError("capability manifest must contain a non-empty case list")
        if not isinstance(routes, dict):
            raise ValueError("capability manifest must contain RAG family routes")
        self.tasks = [self._task(case, routes) for case in cases]

    @staticmethod
    def supports(path: Path) -> bool:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return False
        return (
            isinstance(data, dict)
            and data.get("execution_mode") == "capability_tiered"
            and isinstance(data.get("cases"), list)
        )

    def _task(self, case: dict, routes: dict) -> BenchmarkTask:
        family = str(case["family"])
        return BenchmarkTask(
            id=str(case["id"]),
            profile="capability",
            category=family,
            difficulty=str(case.get("difficulty", "broad")),
            target_level="capability_tier2",
            oracle={
                "expected_profiles": list(case["expected_profiles"]),
                "source_target_tier": case["target_tier"],
                "benchmark_split": case.get("split"),
                "runtime_candidate": case.get("runtime_candidate") is True,
                "rag_route": dict(routes[family]),
            },
            prompt_variants={"rich": str(case["request"])},
            labeled_unknowns=("normalized_request_scoped_unknowns",),
        )

    def select(self, *, profile: str | None = None,
               variant: str = "rich") -> list[tuple[BenchmarkTask, str]]:
        if variant != "rich":
            raise ValueError(
                "the frozen capability study defines only the rich prompt variant"
            )
        if profile not in (None, "capability"):
            return []
        return [(task, task.prompt_variants["rich"]) for task in self.tasks]

    def audit(self) -> dict:
        data = json.loads(self.manifest_path.read_text(encoding="utf-8"))
        source = (
            audit_paper_manifest(self.manifest_path)
            if data.get("benchmark_id") == "robotics-paper-evaluation-candidate-v1"
            else audit_capability_manifest(self.manifest_path)
        )
        return {
            "stage": "capability_benchmark_static_audit",
            "schema_version": "1.0",
            "success": source.get("success") is True,
            "task_count": len(self.tasks),
            "profile_counts": {"capability": len(self.tasks)},
            "variant_count": len(self.tasks),
            "available_variants": ["rich"],
            "issues": source.get("issues", []),
            "manifest": str(self.manifest_path),
            "manifest_sha256": hashlib.sha256(
                self.manifest_path.read_bytes()
            ).hexdigest(),
            "source_audit": source,
        }
