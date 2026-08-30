"""Concrete adapters from frozen ablation conditions to robotics pipelines."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from nl2robotics.benchmark.suite import BenchmarkSuite, BenchmarkTask
from nl2robotics.hybrid.portable import PortableHybridPipeline
from nl2robotics.modelica.moe import (
    COMBINER_MODEL,
    EXPERT_MODELS,
    generate_modelica_moe,
)
from nl2robotics.modelica.pipeline import ModelicaPipeline, clean_code
from nl2robotics.openusd.moe import generate_openusd_moe
from nl2robotics.openusd.pipeline import OpenUSDPipeline, clean_usda
from nl2robotics.orchestrator.pipeline import RoboticsOrchestrator
from nl2robotics.orchestrator.normalizer import (
    NormalizationIssue,
    NormalizationResult,
    RequirementNormalizer,
)

from .conditions import AblationCondition


class PipelineExperimentExecutor:
    """Execute B0-FULL using one frozen transport and tool configuration."""

    def __init__(self, *, text_ask, json_ask,
                 suite: BenchmarkSuite | None = None,
                 modelica_pipeline: ModelicaPipeline | None = None,
                 openusd_pipeline: OpenUSDPipeline | None = None,
                 portable_pipeline: PortableHybridPipeline | None = None,
                 isaac_preparer=None,
                 newton_preparer=None,
                 h2_handoff=None,
                 newton_handoff=None,
                 modelica_moe=generate_modelica_moe,
                 openusd_moe=generate_openusd_moe,
                 normalizer: RequirementNormalizer | None = None,
                 k: int = 5, max_tool_repairs: int = 2,
                 require_complete_moe: bool = True):
        self.text_ask = text_ask
        self.json_ask = json_ask
        self.suite = suite or BenchmarkSuite()
        self.modelica = modelica_pipeline or ModelicaPipeline()
        self.openusd = openusd_pipeline or OpenUSDPipeline()
        self.portable = portable_pipeline or PortableHybridPipeline(
            modelica_runner=self.modelica.runner
        )
        self.isaac_preparer = isaac_preparer
        self.newton_preparer = newton_preparer
        self.h2_handoff = h2_handoff
        self.newton_handoff = newton_handoff
        self.modelica_moe = modelica_moe
        self.openusd_moe = openusd_moe
        self.normalizer = normalizer or RequirementNormalizer()
        self.k = k
        self.max_tool_repairs = max_tool_repairs
        self.require_complete_moe = require_complete_moe

    def prepare_block(self, task: BenchmarkTask, prompt: str, repetition: int,
                      output_dir: Path) -> dict:
        """Normalize once, persist it, and reuse it across all paired conditions."""
        output_dir.mkdir(parents=True, exist_ok=True)
        execution_mode = _execution_mode(task)
        payload = {
            "task_id": task.id,
            "repetition": repetition,
            "execution_mode": execution_mode,
            "prompt_sha256": _sha256_text(prompt),
            "max_ir_repairs": 1,
        }
        fingerprint = _sha256_json(payload)
        path = output_dir / "normalization.json"
        if path.is_file():
            cached = json.loads(path.read_text(encoding="utf-8"))
            if cached.get("block_fingerprint") == fingerprint:
                normalized = _normalization_from_dict(
                    cached["normalization"], cached.get("normalized_ir")
                )
                return _block_context(cached, normalized)
        if task.profile in {"modelica", "openusd"}:
            normalized = NormalizationResult(task_id=task.id)
            normalization_applies = False
        else:
            normalized = self.normalizer.normalize(
                prompt,
                self.json_ask,
                task_id=f"{task.id}-R{repetition:02d}",
                execution_mode=execution_mode,
                max_repairs=1,
            )
            normalization_applies = True
        report = {
            "schema_version": "1.0",
            "block_fingerprint": fingerprint,
            **payload,
            "normalization_applies": normalization_applies,
            "normalization": normalized.to_dict(),
            "normalized_ir": normalized.ir,
            "normalized_ir_sha256": (
                _sha256_json(normalized.ir) if normalized.ir is not None else None
            ),
        }
        path.write_text(
            json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n",
            encoding="utf-8",
        )
        return _block_context(report, normalized)

    def __call__(self, task: BenchmarkTask, condition: AblationCondition,
                 prompt: str, output_dir: Path, *,
                 block_context: dict | None = None) -> dict:
        output_dir.mkdir(parents=True, exist_ok=True)
        if task.profile == "modelica":
            result = self._run_modelica(task, condition, prompt, output_dir)
        elif task.profile == "openusd":
            result = self._run_openusd(condition, prompt, output_dir)
        else:
            result = self._run_hybrid(
                task, condition, prompt, output_dir,
                block_context=block_context,
            )
        result["ablation"] = {
            "condition": condition.to_dict(),
            "generation_strategy": generation_strategy(condition),
            "contract_role": (
                "generation_and_validation" if condition.validated_contract
                else "paired_evaluation_only"
            ),
        }
        validity = _study_validity(result, condition, self.require_complete_moe)
        result["study_validity"] = validity
        result["one_shot"] = _one_shot_outcomes(result)
        if block_context is not None:
            result["paired_block"] = {
                key: block_context.get(key) for key in (
                    "block_fingerprint", "normalized_ir_sha256", "repetition"
                )
            }
        if validity["eligible"] is not True:
            result["infrastructure_pending"] = True
            result["infrastructure_reason"] = "; ".join(validity["issues"])
        return result

    def _run_modelica(self, task: BenchmarkTask, condition: AblationCondition,
                      prompt: str, output_dir: Path) -> dict:
        code, generation = self._generate_modelica(prompt, condition,
                                                    output_dir / "generation")
        if generation.get("passed") is not True:
            return {
                "stage": "modelica_experiment", "passed": False,
                "failure_stage": "modelica_build",
                "modelica": {"passed": False}, "generation": generation,
            }
        config = _evaluation_task(task.oracle["evaluation_task_id"])
        properties = config["properties"]
        outputs = sorted({item["signal"] for item in properties})
        execution = self.modelica.export_and_execute_fmu(
            code,
            properties=properties,
            outputs=outputs,
            output_dir=output_dir / "execution",
            **config["simulation"],
        )
        return {
            "stage": "modelica_experiment",
            "passed": execution["passed"],
            "failure_stage": None if execution["passed"] else "fmu_execution",
            "modelica": {"passed": True, "repairs": generation.get("repairs")},
            "generation": generation,
            "fmu": execution["fmu"],
            "execution": execution["execution"] or {},
            "properties": execution["properties"],
        }

    def _run_openusd(self, condition: AblationCondition, prompt: str,
                     output_dir: Path) -> dict:
        stage, generation = self._generate_openusd(
            prompt, condition, output_dir / "generation"
        )
        (output_dir / "scene.usda").write_text(stage, encoding="utf-8")
        return {
            "stage": "openusd_experiment",
            "passed": generation.get("passed") is True,
            "failure_stage": (
                None if generation.get("passed") is True else "openusd_validation"
            ),
            "openusd": {
                "passed": generation.get("passed") is True,
                "repairs": generation.get("repairs"),
            },
            "generation": generation,
        }

    def _run_hybrid(self, task: BenchmarkTask, condition: AblationCondition,
                    prompt: str, output_dir: Path, *,
                    block_context: dict | None = None) -> dict:
        route = task.oracle.get("rag_route", {})
        modelica_categories = tuple(route.get("modelica", ()))
        openusd_categories = tuple(route.get("openusd", ()))

        def modelica_generator(profile_requirement: str, generation_dir: Path):
            requirement = prompt if condition.id == "B0" else profile_requirement
            return self._generate_modelica(
                requirement, condition, generation_dir,
                preferred_categories=modelica_categories,
            )

        def openusd_generator(profile_requirement: str, generation_dir: Path):
            requirement = prompt if condition.id == "B0" else profile_requirement
            return self._generate_openusd(
                requirement, condition, generation_dir,
                preferred_categories=openusd_categories,
            )

        orchestrator = RoboticsOrchestrator(
            modelica_pipeline=self.modelica,
            openusd_pipeline=self.openusd,
            portable_pipeline=self.portable,
            modelica_generator=modelica_generator,
            openusd_generator=openusd_generator,
            k=self.k,
            max_profile_repairs=(self.max_tool_repairs if condition.tool_repair else 0),
            isaac_preparer=self.isaac_preparer,
            newton_preparer=self.newton_preparer,
        )
        result = orchestrator.run(
            prompt,
            self.json_ask,
            output_dir=output_dir,
            task_id=task.id,
            execution_mode=_execution_mode(task),
            max_ir_repairs=1,
            alignment_ask=self.json_ask if condition.alignment else None,
            semantic_repair_ask=self.text_ask if condition.alignment else None,
            max_semantic_repairs=(1 if condition.alignment else 0),
            enable_alignment=condition.alignment,
            precomputed_normalization=(
                block_context.get("normalization")
                if block_context is not None else None
            ),
        )
        if task.target_level in {"isaac_h2", "newton_h2"}:
            return self._complete_h2(result, output_dir, task.target_level)
        return result

    def _complete_h2(self, result: dict, output_dir: Path,
                     target_level: str = "isaac_h2") -> dict:
        backend = "newton" if target_level == "newton_h2" else "isaac"
        if result.get("ready_for_gpu") is not True:
            return result
        handoff_runner = (
            self.newton_handoff if backend == "newton" else self.h2_handoff
        )
        if handoff_runner is None:
            result["infrastructure_pending"] = True
            result["infrastructure_reason"] = (
                f"validated H2 bundle requires the configured {backend} handoff"
            )
            return result
        manifest = result.get("hybrid", {}).get("manifest")
        if not isinstance(manifest, str):
            result["failure_stage"] = "missing_h2_manifest"
            return result
        handoff = handoff_runner(
            bundle_path=output_dir / manifest,
            output_dir=output_dir / "gpu-handoff",
        )
        result[f"{backend}_handoff"] = handoff
        if backend == "isaac":
            result["gpu_handoff"] = handoff
        simulator_report = (
            handoff.get(f"{backend}_report", handoff)
            if isinstance(handoff, dict) else None
        )
        if handoff.get("failure_stage") == "gpu_preflight":
            result["infrastructure_pending"] = True
            result["infrastructure_reason"] = f"{backend} GPU preflight failed"
            return result
        if not isinstance(simulator_report, dict):
            result["passed"] = False
            result["failure_stage"] = f"{backend}_execution"
            return result
        result["h2_preparation"] = result["hybrid"]
        result["hybrid"] = simulator_report
        result["passed"] = simulator_report.get("success") is True
        result["claim_eligible_h2"] = (
            simulator_report.get("claim_eligible_h2") is True
        )
        result["failure_stage"] = (
            None if result["passed"] else f"{backend}_execution"
        )
        return result

    def _generate_modelica(self, requirement: str, condition: AblationCondition,
                            output_dir: Path, *,
                            preferred_categories: tuple[str, ...] = (),
                            ) -> tuple[str, dict]:
        strategy = generation_strategy(condition)
        if strategy == "direct":
            system, human = self.modelica.build_baseline_messages(requirement)
            candidate = clean_code(self.text_ask(f"{system}\n\n{human}"))
            report = self.modelica.refine_layer1(
                requirement, candidate, self.text_ask, hits=[], max_repairs=0,
                output_dir=output_dir,
            )
            report["generation_mode"] = "direct"
            _annotate_generation_report(report, condition, self.k,
                                        self.max_tool_repairs)
            return report["final_modelica"], report
        if strategy == "rag_single":
            report = self.modelica.generate(
                requirement, self.text_ask, k=self.k, max_repairs=0,
                output_dir=output_dir,
                preferred_categories=preferred_categories,
            )
            report["generation_mode"] = "rag_single"
            _annotate_generation_report(report, condition, self.k,
                                        self.max_tool_repairs)
            return report["final_modelica"], report
        code, report = self.modelica_moe(
            requirement,
            pipeline=self.modelica,
            k=self.k,
            max_repairs=self.max_tool_repairs if condition.tool_repair else 0,
            output_dir=output_dir,
            preferred_categories=preferred_categories,
        )
        _annotate_generation_report(report, condition, self.k,
                                    self.max_tool_repairs)
        return code, report

    def _generate_openusd(self, requirement: str, condition: AblationCondition,
                          output_dir: Path, *,
                          preferred_categories: tuple[str, ...] = (),
                          ) -> tuple[str, dict]:
        strategy = generation_strategy(condition)
        if strategy == "direct":
            system, human = self.openusd.build_baseline_messages(requirement)
            candidate = clean_usda(self.text_ask(f"{system}\n\n{human}"))
            report = self.openusd.refine(
                requirement, candidate, self.text_ask, hits=[], max_repairs=0,
                output_dir=output_dir,
            )
            report["generation_mode"] = "direct"
            _annotate_generation_report(report, condition, self.k,
                                        self.max_tool_repairs)
            return report["final_openusd"], report
        if strategy == "rag_single":
            report = self.openusd.generate(
                requirement, self.text_ask, k=self.k, max_repairs=0,
                output_dir=output_dir,
                preferred_categories=preferred_categories,
            )
            report["generation_mode"] = "rag_single"
            _annotate_generation_report(report, condition, self.k,
                                        self.max_tool_repairs)
            return report["final_openusd"], report
        stage, report = self.openusd_moe(
            requirement,
            pipeline=self.openusd,
            k=self.k,
            max_repairs=self.max_tool_repairs if condition.tool_repair else 0,
            output_dir=output_dir,
            preferred_categories=preferred_categories,
        )
        _annotate_generation_report(report, condition, self.k,
                                    self.max_tool_repairs)
        return stage, report


def generation_strategy(condition: AblationCondition) -> str:
    if not condition.rag and not condition.moe:
        return "direct"
    if condition.rag and not condition.moe:
        return "rag_single"
    return "rag_moe"


def _execution_mode(task: BenchmarkTask) -> str:
    return {
        "isaac_h2": "isaac_closed_loop",
        "newton_h2": "newton_closed_loop",
        "capability_tier2": "capability_tiered",
    }.get(task.target_level, "portable_fmu_kinematic")


def _annotate_generation_report(report: dict, condition: AblationCondition,
                                k: int, max_tool_repairs: int) -> None:
    report["study_controls"] = {
        "rag_enabled": condition.rag,
        "moe_enabled": condition.moe,
        "tool_repair_enabled": condition.tool_repair,
        "retrieval_k": k if condition.rag else 0,
        "max_tool_repairs": max_tool_repairs if condition.tool_repair else 0,
    }


def _study_validity(result: dict, condition: AblationCondition,
                    require_complete_moe: bool) -> dict:
    reports = _generation_reports(result)
    issues: list[str] = []
    expected_strategy = generation_strategy(condition)
    observed = []
    for owner, report in reports:
        mode = report.get("generation_mode")
        controls = report.get("study_controls", {})
        retrieved = report.get("retrieved_examples", [])
        candidates = report.get("expert_candidates", [])
        roster = report.get("expert_models", [])
        combiner = report.get("combiner_model")
        soft_fails = report.get("expert_soft_fail_count", 0)
        row = {
            "owner": owner,
            "generation_mode": mode,
            "retrieval_count": len(retrieved) if isinstance(retrieved, list) else None,
            "expert_candidate_count": (
                len(candidates) if isinstance(candidates, list) else None
            ),
            "expert_roster": roster,
            "combiner_model": combiner,
            "expert_soft_fail_count": soft_fails,
            "study_controls": controls,
        }
        observed.append(row)
        if mode != expected_strategy and not (
            expected_strategy == "rag_moe" and mode == "moe"
        ):
            issues.append(
                f"{owner} generation mode {mode!r} != {expected_strategy!r}"
            )
        if controls.get("rag_enabled") is not condition.rag:
            issues.append(f"{owner} RAG control mismatch")
        if controls.get("moe_enabled") is not condition.moe:
            issues.append(f"{owner} MoE control mismatch")
        if controls.get("tool_repair_enabled") is not condition.tool_repair:
            issues.append(f"{owner} tool-repair control mismatch")
        if condition.rag and (not isinstance(retrieved, list) or not retrieved):
            issues.append(f"{owner} RAG was enabled but retrieved no examples")
        expected_k = controls.get("retrieval_k")
        if (condition.rag and isinstance(retrieved, list)
                and isinstance(expected_k, int) and len(retrieved) != expected_k):
            issues.append(
                f"{owner} RAG returned {len(retrieved)} of {expected_k} frozen hits"
            )
        if not condition.rag and isinstance(retrieved, list) and retrieved:
            issues.append(f"{owner} RAG was disabled but examples were retrieved")
        if condition.moe and require_complete_moe:
            if soft_fails != 0:
                issues.append(f"{owner} MoE had {soft_fails} expert soft failure(s)")
            if not isinstance(candidates, list) or len(candidates) != len(EXPERT_MODELS):
                issues.append(
                    f"{owner} MoE produced {len(candidates) if isinstance(candidates, list) else 0} "
                    f"of {len(EXPERT_MODELS)} required expert candidates"
                )
            if roster != list(EXPERT_MODELS):
                issues.append(f"{owner} MoE expert roster does not match the freeze")
            if candidates != list(EXPERT_MODELS):
                issues.append(f"{owner} MoE candidate roster does not match the freeze")
            if combiner != COMBINER_MODEL:
                issues.append(f"{owner} MoE combiner does not match the freeze")
    generation_reached = bool(reports)
    pair_valid = (
        result.get("modelica", {}).get("passed") is True
        and result.get("openusd", {}).get("passed") is True
    )
    alignment = result.get("alignment")
    if condition.alignment and pair_valid:
        if not isinstance(alignment, dict) or alignment.get("enabled") is not True:
            issues.append("alignment was required but did not execute")
    if not condition.alignment and isinstance(alignment, dict):
        if alignment.get("enabled") is True:
            issues.append("alignment executed while disabled")
    fidelity_passed = not issues if generation_reached else None
    return {
        "eligible": not issues,
        "condition_fidelity_passed": fidelity_passed,
        "generation_reached": generation_reached,
        "complete_moe_required": require_complete_moe,
        "expected": condition.to_dict(),
        "observed_generation": observed,
        "alignment_observed": (
            alignment.get("enabled") if isinstance(alignment, dict) else None
        ),
        "contract_created": result.get("plan", {}).get("success") is True,
        "issues": issues,
    }


def _generation_reports(result: dict) -> list[tuple[str, dict]]:
    direct = result.get("generation")
    if isinstance(direct, dict):
        owner = "openusd" if result.get("stage") == "openusd_experiment" else "modelica"
        return [(owner, direct)]
    rows = []
    for owner in ("modelica", "openusd"):
        report = result.get(owner)
        if isinstance(report, dict) and report.get("generation_mode") is not None:
            rows.append((owner, report))
    return rows


def _one_shot_outcomes(result: dict) -> dict:
    rows = dict(_generation_reports(result))
    modelica = _attempt_zero(rows.get("modelica"), "modelica")
    openusd = _attempt_zero(rows.get("openusd"), "openusd")
    pair = (
        modelica and openusd
        if isinstance(modelica, bool) and isinstance(openusd, bool) else None
    )
    return {
        "modelica_valid_attempt_0": modelica,
        "openusd_valid_attempt_0": openusd,
        "artifact_pair_valid_attempt_0": pair,
    }


def _attempt_zero(report: dict | None, owner: str) -> bool | None:
    if not isinstance(report, dict):
        return None
    cached = report.get("attempt_0_valid")
    if isinstance(cached, bool):
        return cached
    attempts = report.get("attempts")
    if not isinstance(attempts, list) or not attempts:
        return None
    first = attempts[0]
    if owner == "modelica":
        value = first.get("passed")
    else:
        value = first.get("validation", {}).get("success")
    return value if isinstance(value, bool) else None


def _normalization_from_dict(data: dict, normalized_ir: dict | None = None
                             ) -> NormalizationResult:
    issues = [
        NormalizationIssue(
            str(item.get("code", "unknown")),
            str(item.get("message", "")),
            str(item.get("path", "$")),
        )
        for item in data.get("issues", [])
    ]
    ir = normalized_ir if isinstance(normalized_ir, dict) else None
    return NormalizationResult(
        task_id=str(data["task_id"]), ir=ir, issues=issues,
        attempts=list(data.get("attempts", [])),
    )


def _block_context(report: dict, normalized: NormalizationResult) -> dict:
    return {
        "block_fingerprint": report["block_fingerprint"],
        "normalized_ir_sha256": report.get("normalized_ir_sha256"),
        "repetition": report["repetition"],
        "normalization": normalized,
    }


def _sha256_text(value: str) -> str:
    return hashlib.sha256(value.strip().encode("utf-8")).hexdigest()


def _sha256_json(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def _evaluation_task(task_id: str) -> dict:
    path = (
        Path(__file__).resolve().parents[1] / "modelica" / "examples"
        / "evaluation_tasks.json"
    )
    rows = json.loads(path.read_text(encoding="utf-8"))
    return next(item for item in rows if item["id"] == task_id)
