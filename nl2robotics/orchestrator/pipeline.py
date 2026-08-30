"""One authoritative NL-to-Modelica/OpenUSD-to-H1 orchestration path."""

from __future__ import annotations

from collections.abc import Callable
import hashlib
import json
from pathlib import Path

from nl2robotics.alignment.evaluator import RoboticsAlignmentEvaluator
from nl2robotics.alignment.guarded import guarded_semantic_repair
from nl2robotics.contracts.capabilities import capability_report
from nl2robotics.hybrid.isaac_bundle import prepare_isaac_bundle
from nl2robotics.hybrid.newton_bundle import prepare_newton_bundle
from nl2robotics.hybrid.portable import PortableHybridPipeline
from nl2robotics.modelica.moe import generate_modelica_moe
from nl2robotics.modelica.pipeline import ModelicaPipeline
from nl2robotics.openusd.moe import generate_openusd_moe
from nl2robotics.openusd.pipeline import OpenUSDPipeline

from .normalizer import Ask, NormalizationResult, RequirementNormalizer
from .planner import H2Plan, PlanningError, build_plan
from .profiled_planner import CapabilityPlan


ProfileGenerator = Callable[[str, Path], tuple[str, dict]]
H2Preparer = Callable[..., dict]


class RoboticsOrchestrator:
    """Generate both profiles from one frozen plan and execute portable H1."""

    def __init__(
        self,
        *,
        normalizer: RequirementNormalizer | None = None,
        modelica_pipeline: ModelicaPipeline | None = None,
        openusd_pipeline: OpenUSDPipeline | None = None,
        portable_pipeline: PortableHybridPipeline | None = None,
        modelica_generator: ProfileGenerator | None = None,
        openusd_generator: ProfileGenerator | None = None,
        alignment_evaluator: RoboticsAlignmentEvaluator | None = None,
        isaac_preparer: H2Preparer | None = None,
        newton_preparer: H2Preparer | None = None,
        k: int = 5,
        max_profile_repairs: int = 2,
        modelica_preferred_categories: tuple[str, ...] = (),
        openusd_preferred_categories: tuple[str, ...] = (),
    ):
        self.normalizer = normalizer or RequirementNormalizer()
        self.modelica_pipeline = modelica_pipeline or ModelicaPipeline()
        self.openusd_pipeline = openusd_pipeline or OpenUSDPipeline()
        self.portable_pipeline = portable_pipeline or PortableHybridPipeline()
        self.modelica_generator = modelica_generator
        self.openusd_generator = openusd_generator
        self.alignment_evaluator = alignment_evaluator or RoboticsAlignmentEvaluator()
        self.isaac_preparer = isaac_preparer or prepare_isaac_bundle
        self.newton_preparer = newton_preparer or prepare_newton_bundle
        self.k = k
        self.max_profile_repairs = max_profile_repairs
        self.modelica_preferred_categories = modelica_preferred_categories
        self.openusd_preferred_categories = openusd_preferred_categories

    def run(
        self,
        source_text: str,
        ask_ir: Ask,
        *,
        output_dir: Path,
        task_id: str | None = None,
        execution_mode: str = "portable_fmu_kinematic",
        max_ir_repairs: int = 1,
        alignment_ask: Ask | None = None,
        semantic_repair_ask: Ask | None = None,
        max_semantic_repairs: int = 1,
        enable_alignment: bool = True,
        precomputed_normalization: NormalizationResult | None = None,
    ) -> dict:
        output_dir.mkdir(parents=True, exist_ok=True)
        (output_dir / "request.txt").write_text(
            source_text.strip() + "\n", encoding="utf-8"
        )
        result = {
            "stage": "robotics_orchestrator",
            "schema_version": "1.0",
            "passed": False,
            "failure_stage": "requirement_normalization",
            "source_text_sha256": hashlib.sha256(
                source_text.strip().encode("utf-8")
            ).hexdigest(),
        }

        try:
            if precomputed_normalization is None:
                normalized = self.normalizer.normalize(
                    source_text,
                    ask_ir,
                    task_id=task_id,
                    execution_mode=execution_mode,
                    max_repairs=max_ir_repairs,
                )
            else:
                normalized = precomputed_normalization
                if normalized.ir is not None:
                    frozen_source = normalized.ir.get("source_text")
                    frozen_mode = normalized.ir.get("execution_mode")
                    if frozen_source != source_text.strip():
                        raise ValueError(
                            "precomputed normalization source does not match request"
                        )
                    if frozen_mode != execution_mode:
                        raise ValueError(
                            "precomputed normalization execution mode does not match run"
                        )
        except Exception as exc:
            result["error"] = str(exc)
            return self._finish(output_dir, result)
        _write_json(output_dir / "normalization.json", normalized.to_dict())
        result["task_id"] = normalized.task_id
        result["normalization"] = {
            "success": normalized.success,
            "attempt_count": len(normalized.attempts),
            "report": "normalization.json",
            "precomputed": precomputed_normalization is not None,
        }
        if not normalized.success or normalized.ir is None:
            result["issues"] = normalized.to_dict()["issues"]
            return self._finish(output_dir, result)

        _write_json(output_dir / "normalized_requirement_ir.json", normalized.ir)

        try:
            plan = build_plan(normalized.ir)
        except PlanningError as exc:
            result["failure_stage"] = "interface_planning"
            result["issues"] = exc.to_dict()["issues"]
            return self._finish(output_dir, result)

        _write_json(output_dir / "requirement_ir.json", plan.requirement_ir)
        _write_json(output_dir / "contract.json", plan.contract)
        _write_json(output_dir / "plan.json", plan.to_dict())
        (output_dir / "modelica-requirement.txt").write_text(
            plan.modelica_requirement, encoding="utf-8"
        )
        (output_dir / "openusd-requirement.txt").write_text(
            plan.openusd_requirement, encoding="utf-8"
        )
        result["plan"] = {
            "success": True,
            "model_name": plan.model_name,
            "mapping_count": len(plan.contract["mappings"]),
            "report": "plan.json",
            "contract": "contract.json",
            "requirement_ir": "requirement_ir.json",
            "normalized_requirement_ir": "normalized_requirement_ir.json",
        }

        modelica_dir = output_dir / "modelica"
        modelica_dir.mkdir(parents=True, exist_ok=True)
        try:
            modelica, modelica_report = self._generate_modelica(
                plan.modelica_requirement, modelica_dir / "generation"
            )
        except Exception as exc:
            result["failure_stage"] = "modelica_generation"
            result["error"] = str(exc)
            return self._finish(output_dir, result)
        (modelica_dir / "model.mo").write_text(modelica, encoding="utf-8")
        _write_json(modelica_dir / "generation.json", modelica_report)
        result["modelica"] = _profile_summary(
            modelica_report, "modelica/model.mo", "modelica/generation.json"
        )
        if (modelica_report.get("passed") is not True
                and not isinstance(plan, CapabilityPlan)):
            result["failure_stage"] = "modelica_validation"
            return self._finish(output_dir, result)

        openusd_dir = output_dir / "openusd"
        openusd_dir.mkdir(parents=True, exist_ok=True)
        try:
            openusd, openusd_report = self._generate_openusd(
                plan.openusd_requirement, openusd_dir / "generation"
            )
        except Exception as exc:
            result["failure_stage"] = "openusd_generation"
            result["error"] = str(exc)
            return self._finish(output_dir, result)
        source_usd = openusd_dir / "scene.usda"
        source_usd.write_text(openusd, encoding="utf-8")
        _write_json(openusd_dir / "generation.json", openusd_report)
        result["openusd"] = _profile_summary(
            openusd_report, "openusd/scene.usda", "openusd/generation.json"
        )
        if (openusd_report.get("passed") is not True
                and not isinstance(plan, CapabilityPlan)):
            result["failure_stage"] = "openusd_validation"
            return self._finish(output_dir, result)

        if isinstance(plan, CapabilityPlan):
            report = capability_report(
                plan.requirement_ir,
                modelica_passed=modelica_report.get("passed") is True,
                openusd_passed=openusd_report.get("passed") is True,
            )
            _write_json(output_dir / "capability-report.json", report)
            result["capabilities"] = {
                "report": "capability-report.json",
                **report["verification"],
                "requested_feature_count": len(report["requested_features"]),
                "profile_count": len(report["profiles"]),
            }
            pair_passed = (
                modelica_report.get("passed") is True
                and openusd_report.get("passed") is True
            )
            if enable_alignment and pair_passed:
                alignment = self.alignment_evaluator.evaluate(
                    plan.requirement_ir,
                    modelica=modelica,
                    openusd=openusd,
                    contract=plan.contract,
                    hybrid_report={
                        "contract": {},
                        "properties": [],
                        "capabilities": report,
                    },
                    ask=alignment_ask,
                )
            else:
                alignment = _skipped_alignment(plan.task_id)
            _write_json(output_dir / "alignment.json", alignment)
            result["alignment"] = {
                "enabled": enable_alignment,
                "passed": alignment["passed"],
                "claim_ready": alignment.get("claim_ready", False),
                "report": "alignment.json",
                **alignment["summary"],
            }
            aligned = not enable_alignment or alignment["passed"] is True
            result["execution_status"] = (
                "artifacts_validated" if pair_passed and aligned
                else "artifact_validation_failed"
            )
            result["claim_eligible_h2"] = False
            result["claim_eligible_deltaai_h2"] = False
            result["passed"] = pair_passed and aligned
            if pair_passed and aligned:
                result["failure_stage"] = None
            elif modelica_report.get("passed") is not True:
                result["failure_stage"] = "modelica_validation"
            elif openusd_report.get("passed") is not True:
                result["failure_stage"] = "openusd_validation"
            else:
                result["failure_stage"] = "semantic_alignment"
            return self._finish(output_dir, result)

        if isinstance(plan, H2Plan):
            return self._prepare_h2(
                output_dir=output_dir,
                result=result,
                plan=plan,
                modelica=modelica,
                openusd=openusd,
                source_usd=source_usd,
                alignment_ask=alignment_ask,
                semantic_repair_ask=semantic_repair_ask,
                max_semantic_repairs=max_semantic_repairs,
                enable_alignment=enable_alignment,
            )

        result["failure_stage"] = "portable_hybrid_execution"
        h1_dir = output_dir / "hybrid"
        try:
            h1 = self.portable_pipeline.run(
                modelica,
                source_usd,
                plan.requirement_ir,
                plan.contract,
                output_dir=h1_dir,
            )
        except Exception as exc:
            result["error"] = str(exc)
            return self._finish(output_dir, result)
        _write_json(h1_dir / "bundle.json", h1)
        result["hybrid"] = _h1_summary(h1)
        if enable_alignment:
            alignment = self.alignment_evaluator.evaluate(
                plan.requirement_ir,
                modelica=modelica,
                openusd=openusd,
                contract=plan.contract,
                hybrid_report=h1,
                ask=alignment_ask,
            )
        else:
            alignment = {
                "stage": "robotics_semantic_alignment",
                "schema_version": "1.0",
                "task_id": plan.task_id,
                "passed": True,
                "skipped": True,
                "reason": "disabled by ablation condition",
                "summary": {
                    "question_count": 0,
                    "counts": {"satisfied": 0, "violated": 0,
                               "unknown": 0, "not_applicable": 0},
                    "weighted_semantic_score": None,
                    "evidence_coverage": 0.0,
                    "blocking_violations": 0,
                    "deterministic_violations": 0,
                    "per_family": {},
                },
                "repair_plan": {"actions": []},
            }
        repair_report = None
        if (enable_alignment and semantic_repair_ask is not None
                and max_semantic_repairs > 0
                and alignment["summary"]["blocking_violations"] > 0):
            baseline = {
                "modelica": modelica,
                "openusd": openusd,
                "modelica_passed": modelica_report.get("passed") is True,
                "openusd_passed": openusd_report.get("passed") is True,
                "hybrid": h1,
                "alignment": alignment,
            }

            def evaluate_candidate(candidate_modelica: str, candidate_openusd: str,
                                   attempt: int) -> dict:
                attempt_dir = output_dir / "semantic-repair" / f"attempt-{attempt}"
                model_report = self.modelica_pipeline.refine_layer1(
                    plan.modelica_requirement,
                    candidate_modelica,
                    semantic_repair_ask,
                    hits=[], max_repairs=0,
                    output_dir=attempt_dir / "modelica-validation",
                )
                usd_report = self.openusd_pipeline.refine(
                    plan.openusd_requirement,
                    candidate_openusd,
                    semantic_repair_ask,
                    hits=[], max_repairs=0,
                    output_dir=attempt_dir / "openusd-validation",
                )
                model_passed = model_report.get("passed") is True
                usd_passed = usd_report.get("passed") is True
                candidate_hybrid: dict = {}
                candidate_alignment: dict = {
                    "passed": False,
                    "summary": {"blocking_violations": 1},
                    "repair_plan": {"actions": []},
                }
                usd_path = attempt_dir / "scene.usda"
                usd_path.parent.mkdir(parents=True, exist_ok=True)
                usd_path.write_text(candidate_openusd, encoding="utf-8")
                (attempt_dir / "model.mo").write_text(
                    candidate_modelica, encoding="utf-8"
                )
                if model_passed and usd_passed:
                    candidate_hybrid = self.portable_pipeline.run(
                        candidate_modelica,
                        usd_path,
                        plan.requirement_ir,
                        plan.contract,
                        output_dir=attempt_dir / "hybrid",
                    )
                    candidate_alignment = self.alignment_evaluator.evaluate(
                        plan.requirement_ir,
                        modelica=candidate_modelica,
                        openusd=candidate_openusd,
                        contract=plan.contract,
                        hybrid_report=candidate_hybrid,
                        ask=alignment_ask,
                    )
                _write_json(attempt_dir / "modelica-validation.json", model_report)
                _write_json(attempt_dir / "openusd-validation.json", usd_report)
                _write_json(attempt_dir / "hybrid.json", candidate_hybrid)
                _write_json(attempt_dir / "alignment.json", candidate_alignment)
                return {
                    "modelica": candidate_modelica,
                    "openusd": candidate_openusd,
                    "modelica_passed": model_passed,
                    "openusd_passed": usd_passed,
                    "hybrid": candidate_hybrid,
                    "alignment": candidate_alignment,
                }

            repair_report = guarded_semantic_repair(
                baseline,
                semantic_repair_ask,
                evaluate_candidate,
                max_repairs=max_semantic_repairs,
            )
            final_candidate = repair_report["final"]
            if repair_report["repairs_accepted"]:
                modelica = final_candidate["modelica"]
                openusd = final_candidate["openusd"]
                h1 = final_candidate["hybrid"]
                alignment = final_candidate["alignment"]
                (modelica_dir / "model.mo").write_text(modelica, encoding="utf-8")
                source_usd.write_text(openusd, encoding="utf-8")
                _write_json(h1_dir / "bundle.json", h1)
            _write_json(output_dir / "semantic-repair.json", repair_report)
        _write_json(output_dir / "alignment.json", alignment)
        if repair_report is not None:
            result["semantic_repair"] = {
                "report": "semantic-repair.json",
                "attempted": repair_report["repairs_attempted"],
                "accepted": repair_report["repairs_accepted"],
            }
        result["hybrid"] = _h1_summary(h1)
        result["alignment"] = {
            "enabled": enable_alignment,
            "passed": alignment["passed"],
            "claim_ready": alignment.get("claim_ready", False),
            "report": "alignment.json",
            **alignment["summary"],
        }
        result["passed"] = h1.get("passed") is True and alignment["passed"]
        if h1.get("passed") is not True:
            result["failure_stage"] = _h1_failure_stage(h1)
        elif not alignment["passed"]:
            result["failure_stage"] = "semantic_alignment"
        else:
            result["failure_stage"] = None
        return self._finish(output_dir, result)

    def _generate_modelica(self, requirement: str,
                           output_dir: Path) -> tuple[str, dict]:
        if self.modelica_generator is not None:
            return self.modelica_generator(requirement, output_dir)
        return generate_modelica_moe(
            requirement,
            pipeline=self.modelica_pipeline,
            k=self.k,
            max_repairs=self.max_profile_repairs,
            output_dir=output_dir,
            preferred_categories=self.modelica_preferred_categories,
        )

    def _generate_openusd(self, requirement: str,
                          output_dir: Path) -> tuple[str, dict]:
        if self.openusd_generator is not None:
            return self.openusd_generator(requirement, output_dir)
        return generate_openusd_moe(
            requirement,
            pipeline=self.openusd_pipeline,
            k=self.k,
            max_repairs=self.max_profile_repairs,
            output_dir=output_dir,
            preferred_categories=self.openusd_preferred_categories,
        )

    def _prepare_h2(self, *, output_dir: Path, result: dict, plan: H2Plan,
                    modelica: str, openusd: str, source_usd: Path,
                    alignment_ask: Ask | None,
                    semantic_repair_ask: Ask | None,
                    max_semantic_repairs: int,
                    enable_alignment: bool) -> dict:
        result["failure_stage"] = "h2_bundle_preparation"
        bundle_dir = output_dir / "hybrid"
        execution_mode = plan.requirement_ir["execution_mode"]
        preparer = (
            self.newton_preparer
            if execution_mode == "newton_closed_loop"
            else self.isaac_preparer
        )
        try:
            preparation = preparer(
                modelica_path=output_dir / "modelica" / "model.mo",
                usd_path=source_usd,
                requirement_ir_path=output_dir / "requirement_ir.json",
                contract_path=output_dir / "contract.json",
                output_dir=bundle_dir,
                modelica_runner=self.modelica_pipeline.runner,
                usd_validator=self.openusd_pipeline.validator,
            )
        except Exception as exc:
            result["error"] = str(exc)
            return self._finish(output_dir, result)
        _write_json(bundle_dir / "bundle.json", preparation)
        prep_passed = preparation.get("success") is True
        result["hybrid"] = _h2_summary(
            preparation, report_path="hybrid/bundle.json",
            manifest_path="hybrid/execution-input.json",
            execution_mode=execution_mode,
        )
        if not prep_passed:
            return self._finish(output_dir, result)

        if enable_alignment:
            alignment = self.alignment_evaluator.evaluate(
                plan.requirement_ir,
                modelica=modelica,
                openusd=openusd,
                contract=plan.contract,
                hybrid_report=preparation,
                ask=alignment_ask,
            )
        else:
            alignment = _skipped_alignment(plan.task_id)
        repair_report = None
        if (enable_alignment and semantic_repair_ask is not None
                and max_semantic_repairs > 0
                and alignment["summary"]["blocking_violations"] > 0):
            baseline = {
                "modelica": modelica,
                "openusd": openusd,
                "modelica_passed": True,
                "openusd_passed": True,
                "hybrid": preparation,
                "alignment": alignment,
                "bundle_report": "hybrid/bundle.json",
                "bundle_manifest": "hybrid/execution-input.json",
            }

            def evaluate_candidate(candidate_modelica: str, candidate_openusd: str,
                                   attempt: int) -> dict:
                attempt_root = output_dir / "semantic-repair" / f"attempt-{attempt}"
                attempt_root.mkdir(parents=True, exist_ok=True)
                model_report = self.modelica_pipeline.refine_layer1(
                    plan.modelica_requirement,
                    candidate_modelica,
                    semantic_repair_ask,
                    hits=[], max_repairs=0,
                    output_dir=attempt_root / "modelica-validation",
                )
                usd_report = self.openusd_pipeline.refine(
                    plan.openusd_requirement,
                    candidate_openusd,
                    semantic_repair_ask,
                    hits=[], max_repairs=0,
                    output_dir=attempt_root / "openusd-validation",
                )
                model_passed = model_report.get("passed") is True
                usd_passed = usd_report.get("passed") is True
                candidate_preparation: dict = {}
                candidate_alignment = {
                    "passed": False,
                    "summary": {"blocking_violations": 1},
                    "repair_plan": {"actions": []},
                }
                bundle_report = None
                bundle_manifest = None
                if model_passed and usd_passed:
                    model_path = attempt_root / "model.mo"
                    usd_path = attempt_root / "scene.usda"
                    model_path.write_text(candidate_modelica, encoding="utf-8")
                    usd_path.write_text(candidate_openusd, encoding="utf-8")
                    ir_path = attempt_root / "requirement_ir.json"
                    contract_path = attempt_root / "contract.json"
                    _write_json(ir_path, plan.requirement_ir)
                    _write_json(contract_path, plan.contract)
                    bundle_path = attempt_root / "hybrid"
                    try:
                        candidate_preparation = preparer(
                            modelica_path=model_path,
                            usd_path=usd_path,
                            requirement_ir_path=ir_path,
                            contract_path=contract_path,
                            output_dir=bundle_path,
                            modelica_runner=self.modelica_pipeline.runner,
                            usd_validator=self.openusd_pipeline.validator,
                        )
                    except Exception as exc:
                        candidate_preparation = {
                            "success": False, "error": str(exc),
                        }
                    _write_json(bundle_path / "bundle.json", candidate_preparation)
                    if candidate_preparation.get("success") is True:
                        candidate_alignment = self.alignment_evaluator.evaluate(
                            plan.requirement_ir,
                            modelica=candidate_modelica,
                            openusd=candidate_openusd,
                            contract=plan.contract,
                            hybrid_report=candidate_preparation,
                            ask=alignment_ask,
                        )
                        prefix = f"semantic-repair/attempt-{attempt}/hybrid"
                        bundle_report = f"{prefix}/bundle.json"
                        bundle_manifest = f"{prefix}/execution-input.json"
                _write_json(attempt_root / "alignment.json", candidate_alignment)
                return {
                    "modelica": candidate_modelica,
                    "openusd": candidate_openusd,
                    "modelica_passed": model_passed,
                    "openusd_passed": usd_passed,
                    "hybrid": candidate_preparation,
                    "alignment": candidate_alignment,
                    "bundle_report": bundle_report,
                    "bundle_manifest": bundle_manifest,
                }

            repair_report = guarded_semantic_repair(
                baseline,
                semantic_repair_ask,
                evaluate_candidate,
                max_repairs=max_semantic_repairs,
            )
            final_candidate = repair_report["final"]
            if repair_report["repairs_accepted"]:
                modelica = final_candidate["modelica"]
                openusd = final_candidate["openusd"]
                preparation = final_candidate["hybrid"]
                alignment = final_candidate["alignment"]
                (output_dir / "modelica" / "model.mo").write_text(
                    modelica, encoding="utf-8"
                )
                source_usd.write_text(openusd, encoding="utf-8")
                result["hybrid"] = _h2_summary(
                    preparation,
                    report_path=final_candidate["bundle_report"],
                    manifest_path=final_candidate["bundle_manifest"],
                    execution_mode=execution_mode,
                )
            _write_json(output_dir / "semantic-repair.json", repair_report)
        _write_json(output_dir / "alignment.json", alignment)
        if repair_report is not None:
            result["semantic_repair"] = {
                "report": "semantic-repair.json",
                "attempted": repair_report["repairs_attempted"],
                "accepted": repair_report["repairs_accepted"],
            }
        result["alignment"] = {
            "enabled": enable_alignment,
            "passed": alignment["passed"],
            "claim_ready": alignment.get("claim_ready", False),
            "report": "alignment.json",
            **alignment["summary"],
        }
        ready = alignment["passed"] is True
        result["ready_for_gpu"] = ready
        result["execution_status"] = f"pending_{execution_mode}"
        result["passed"] = False
        result["failure_stage"] = (
            "gpu_execution_pending" if ready else "semantic_alignment"
        )
        return self._finish(output_dir, result)

    @staticmethod
    def _finish(output_dir: Path, result: dict) -> dict:
        _write_json(output_dir / "result.json", result)
        return result


def _profile_summary(report: dict, artifact: str, report_path: str) -> dict:
    return {
        "passed": report.get("passed") is True,
        "repairs": report.get("repairs"),
        "generation_mode": report.get("generation_mode"),
        "retrieved_examples": list(report.get("retrieved_examples", [])),
        "attempt_0_valid": _profile_attempt_zero_valid(report),
        "expert_models": list(report.get("expert_models", [])),
        "expert_candidates": list(report.get("expert_candidates", [])),
        "combiner_model": report.get("combiner_model"),
        "expert_soft_fail_count": report.get("expert_soft_fail_count", 0),
        "study_controls": dict(report.get("study_controls", {})),
        "artifact": artifact,
        "report": report_path,
    }


def _profile_attempt_zero_valid(report: dict) -> bool | None:
    attempts = report.get("attempts")
    if not isinstance(attempts, list) or not attempts:
        return None
    first = attempts[0]
    if isinstance(first.get("passed"), bool):
        return first["passed"]
    value = first.get("validation", {}).get("success")
    return value if isinstance(value, bool) else None


def _h1_summary(report: dict) -> dict:
    properties = list(report.get("properties", []))
    return {
        "passed": report.get("passed") is True,
        "report": "hybrid/bundle.json",
        "contract_passed": report.get("contract", {}).get("success"),
        "contract": report.get("contract", {}),
        "fmu": report.get("fmu", {}),
        "execution": report.get("execution", {}),
        "initialization": report.get("initialization", {}),
        "playback": report.get("playback", {}),
        "properties": properties,
        "property_count": len(properties),
    }


def _h2_summary(report: dict, *, report_path: str,
                manifest_path: str | None, execution_mode: str) -> dict:
    prepared = report.get("success") is True
    return {
        "passed": False,
        "prepared": prepared,
        "claim_eligible_h2": False,
        "report": report_path,
        "manifest": manifest_path if prepared else None,
        "contract_passed": report.get("contract", {}).get("success"),
        "contract": report.get("contract", {}),
        "fmu": report.get("fmu", {}),
        "controller_conformance": report.get("controller_conformance", {}),
        "execution_mode": execution_mode,
        "execution": {"success": False, "status": f"pending_{execution_mode}"},
        "properties": [],
        "property_count": 0,
    }


def _skipped_alignment(task_id: str) -> dict:
    return {
        "stage": "robotics_semantic_alignment",
        "schema_version": "1.0",
        "task_id": task_id,
        "passed": True,
        "skipped": True,
        "reason": "disabled by ablation condition",
        "summary": {
            "question_count": 0,
            "counts": {"satisfied": 0, "violated": 0, "unknown": 0,
                       "not_applicable": 0},
            "weighted_semantic_score": None,
            "evidence_coverage": 0.0,
            "blocking_violations": 0,
            "deterministic_violations": 0,
            "per_family": {},
        },
        "repair_plan": {"actions": []},
    }


def _h1_failure_stage(report: dict) -> str:
    if not report.get("fmu", {}).get("success"):
        return "fmu_export"
    if not report.get("contract", {}).get("success"):
        return "cross_profile_contract"
    if not report.get("execution", {}).get("success"):
        return "fmu_execution"
    if report.get("initialization", {}).get("success") is not True:
        return "initialization_contract"
    if any(item.get("passed") is not True for item in report.get("properties", [])):
        return "property_evaluation"
    if not report.get("playback", {}).get("success"):
        return "openusd_playback"
    return "portable_hybrid_execution"


def _write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
