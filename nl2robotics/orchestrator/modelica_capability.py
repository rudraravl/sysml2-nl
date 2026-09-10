"""Authoritative NL-to-Modelica-to-FMU behavioral pipeline."""

from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path

from nl2robotics.contracts.capabilities import capability_report
from nl2robotics.hybrid.capability_execution import CapabilityExecutionPipeline
from nl2robotics.hybrid.capability_repair import (
    REPAIRABLE_FAILURE_STAGES,
    capability_runtime_infrastructure_error,
    guarded_capability_runtime_repair,
)
from nl2robotics.modelica.openmodelica import find_model_name
from nl2robotics.modelica.pipeline import ModelicaPipeline
from nl2robotics.modelica.specification import (
    evaluate_modelica_specification,
    skipped_modelica_specification,
)

from .normalizer import Ask, NormalizationResult, RequirementNormalizer
from .planner import PlanningError
from .profiled_planner import build_modelica_capability_plan


class ModelicaCapabilityOrchestrator:
    """Generate, compile, execute, and externally verify one Modelica model."""

    def __init__(self, *, modelica_pipeline: ModelicaPipeline,
                 modelica_generator, normalizer: RequirementNormalizer | None = None,
                 execution_pipeline: CapabilityExecutionPipeline | None = None):
        self.modelica_pipeline = modelica_pipeline
        self.modelica_generator = modelica_generator
        self.normalizer = normalizer or RequirementNormalizer()
        self.execution_pipeline = execution_pipeline or CapabilityExecutionPipeline(
            modelica_runner=modelica_pipeline.runner,
            fmi_runner=modelica_pipeline.fmi_runner,
        )

    def run_compiler_execution_baseline(
        self, source_text: str, *, output_dir: Path, task_id: str,
        clock: dict,
    ) -> dict:
        """Run raw-NL B0 without normalization, contracts, or semantic scoring."""
        output_dir.mkdir(parents=True, exist_ok=True)
        (output_dir / "request.txt").write_text(
            source_text.strip() + "\n", encoding="utf-8"
        )
        result = {
            "stage": "modelica_compiler_execution_baseline",
            "schema_version": "1.0",
            "artifact_mode": "modelica_only",
            "evaluation_scope": "compile_export_execute_finite_trace",
            "task_id": task_id,
            "passed": False,
            "failure_stage": "modelica_generation",
            "source_text_sha256": hashlib.sha256(
                source_text.strip().encode("utf-8")
            ).hexdigest(),
            "normalization": {
                "applicable": False,
                "success": None,
                "reason": "B0 consumes the raw NL request directly",
            },
            "claim_eligible_h2": False,
            "claim_eligible_newton_h2": False,
            "claim_eligible_deltaai_h2": False,
        }
        modelica_dir = output_dir / "modelica"
        modelica_dir.mkdir(parents=True, exist_ok=True)
        try:
            modelica, generation = self.modelica_generator(
                source_text, modelica_dir / "generation"
            )
        except Exception as exc:
            result["error"] = str(exc)
            return _finish(output_dir, result)
        (modelica_dir / "model.mo").write_text(modelica, encoding="utf-8")
        _write_json(modelica_dir / "generation.json", generation)
        result["modelica"] = _profile_summary(generation)
        if generation.get("passed") is not True:
            result["failure_stage"] = "modelica_validation"
            result["stage_trace"] = _baseline_stage_trace(result)
            return _finish(output_dir, result)
        try:
            actual_model_name = find_model_name(modelica)
        except ValueError as exc:
            result["failure_stage"] = "modelica_identity"
            result["error"] = str(exc)
            result["stage_trace"] = _baseline_stage_trace(result)
            return _finish(output_dir, result)
        result["modelica"].update({
            "model_name": actual_model_name,
            "identity_accepted": True,
            "identity_policy": "generated_top_level_model",
        })
        execution_ir = {
            "schema_version": "1.0",
            "task_id": task_id,
            "source_text": source_text.strip(),
            "properties": [],
        }
        execution_contract = {
            "schema_version": "1.0",
            "contract_kind": "baseline_compiler_execution",
            "task_id": task_id,
            "model_name": actual_model_name,
            "clock": clock,
            "mappings": [],
            "parameter_mappings": [],
            "evaluation_scope": "compile_export_execute_finite_trace",
        }
        _write_json(output_dir / "baseline-execution-ir.json", execution_ir)
        _write_json(output_dir / "execution-contract.json", execution_contract)
        execution = self.execution_pipeline.run_compiler_execution_baseline(
            modelica, execution_ir, execution_contract,
            output_dir=output_dir / "execution",
        )
        _write_json(output_dir / "execution.json", execution)
        result["hybrid"] = _execution_summary(execution)
        alignment = skipped_modelica_specification(task_id)
        _write_json(output_dir / "alignment.json", alignment)
        result["alignment"] = {
            "enabled": False,
            "passed": True,
            "skipped": True,
            "not_run": False,
            "claim_ready": False,
            "report": "alignment.json",
            **alignment["summary"],
        }
        result["passed"] = execution.get("passed") is True
        result["failure_stage"] = (
            None if result["passed"] else execution.get("failure_stage")
        )
        result["stage_trace"] = _baseline_stage_trace(result)
        return _finish(output_dir, result)

    def run(self, source_text: str, ask_ir: Ask, *, output_dir: Path,
            task_id: str | None = None, max_ir_repairs: int = 1,
            runtime_repair_ask: Ask | None = None,
            max_runtime_repairs: int = 1,
            specification_ask: Ask | None = None,
            enable_specification_alignment: bool = True,
            enforce_model_identity: bool = True,
            precomputed_normalization: NormalizationResult | None = None) -> dict:
        output_dir.mkdir(parents=True, exist_ok=True)
        (output_dir / "request.txt").write_text(
            source_text.strip() + "\n", encoding="utf-8"
        )
        result = {
            "stage": "modelica_capability_orchestrator",
            "schema_version": "1.0",
            "artifact_mode": "modelica_only",
            "passed": False,
            "failure_stage": "requirement_normalization",
            "source_text_sha256": hashlib.sha256(
                source_text.strip().encode("utf-8")
            ).hexdigest(),
            "claim_eligible_h2": False,
            "claim_eligible_newton_h2": False,
            "claim_eligible_deltaai_h2": False,
        }
        try:
            normalized = precomputed_normalization or self.normalizer.normalize(
                source_text, ask_ir, task_id=task_id,
                execution_mode="modelica_capability",
                max_repairs=max_ir_repairs,
            )
            if precomputed_normalization is not None and normalized.ir is not None:
                if normalized.ir.get("source_text") != source_text.strip():
                    raise ValueError("precomputed normalization source does not match request")
                if normalized.ir.get("execution_mode") != "modelica_capability":
                    raise ValueError("precomputed normalization mode is not modelica_capability")
        except Exception as exc:
            result["error"] = str(exc)
            return _finish(output_dir, result)
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
            return _finish(output_dir, result)
        _write_json(output_dir / "normalized_requirement_ir.json", normalized.ir)

        try:
            plan = build_modelica_capability_plan(normalized.ir)
        except PlanningError as exc:
            result["failure_stage"] = "interface_planning"
            result["issues"] = exc.to_dict()["issues"]
            return _finish(output_dir, result)
        _write_json(output_dir / "requirement_ir.json", plan.requirement_ir)
        _write_json(output_dir / "contract.json", plan.contract)
        _write_json(output_dir / "plan.json", plan.to_dict())
        (output_dir / "modelica-requirement.txt").write_text(
            plan.modelica_requirement, encoding="utf-8"
        )
        result["plan"] = {
            "success": True,
            "model_name": plan.model_name,
            "mapping_count": len(plan.contract["mappings"]),
            "parameter_mapping_count": len(plan.contract["parameter_mappings"]),
            "report": "plan.json",
            "contract": "contract.json",
            "requirement_ir": "requirement_ir.json",
        }

        modelica_dir = output_dir / "modelica"
        modelica_dir.mkdir(parents=True, exist_ok=True)
        try:
            modelica, generation = self.modelica_generator(
                plan.modelica_requirement, modelica_dir / "generation"
            )
        except Exception as exc:
            result["failure_stage"] = "modelica_generation"
            result["error"] = str(exc)
            return _finish(output_dir, result)
        (modelica_dir / "model.mo").write_text(modelica, encoding="utf-8")
        _write_json(modelica_dir / "generation.json", generation)
        result["modelica"] = _profile_summary(generation)
        if generation.get("passed") is not True:
            result["failure_stage"] = "modelica_validation"
            result["stage_trace"] = _stage_trace(result)
            return _finish(output_dir, result)
        try:
            actual_model_name = find_model_name(modelica)
        except ValueError as exc:
            result["failure_stage"] = "modelica_identity"
            result["error"] = str(exc)
            result["stage_trace"] = _stage_trace(result)
            return _finish(output_dir, result)
        identity_preserved = actual_model_name == plan.model_name
        if not identity_preserved and enforce_model_identity:
            result["failure_stage"] = "modelica_identity"
            result["error"] = (
                f"generated top-level model {actual_model_name!r} does not match "
                f"planned name {plan.model_name!r}"
            )
            result["stage_trace"] = _stage_trace(result)
            return _finish(output_dir, result)
        execution_contract = plan.contract
        if not identity_preserved:
            # Raw-prompt baselines are never told the pipeline's internal
            # RobotTask_<id> wrapper name. Execute their exact generated model
            # by adapting only the evaluator's expected FMU identity; do not
            # rewrite the candidate or relax any observable/value/unit checks.
            execution_contract = deepcopy(plan.contract)
            execution_contract["model_name"] = actual_model_name
            _write_json(output_dir / "execution-contract.json", execution_contract)
        result["modelica"].update({
            "model_name": actual_model_name,
            "expected_model_name": plan.model_name,
            "identity_preserved": identity_preserved,
            "identity_accepted": identity_preserved or not enforce_model_identity,
            "identity_policy": (
                "enforced_contract_name" if enforce_model_identity else
                "generated_name_accepted_for_posthoc_execution"
            ),
            "execution_contract": (
                "contract.json" if identity_preserved else "execution-contract.json"
            ),
        })

        execution = self.execution_pipeline.run(
            modelica, plan.requirement_ir, execution_contract,
            output_dir=output_dir / "execution",
        )
        runtime_enabled = runtime_repair_ask is not None and max_runtime_repairs > 0
        result["runtime_repair"] = {
            "enabled": runtime_enabled,
            "triggered": False,
            "max_repairs": max_runtime_repairs if runtime_enabled else 0,
            "report": None,
            "attempted": 0,
            "accepted": 0,
            "original_model": None,
            "final_model": "modelica/model.mo",
        }
        if (
            runtime_enabled
            and execution.get("failure_stage") in REPAIRABLE_FAILURE_STAGES
            and capability_runtime_infrastructure_error(execution) is None
        ):
            baseline = {
                "modelica": modelica,
                "modelica_passed": True,
                "identity_preserved": True,
                "pre_alignment_passed": (
                    execution.get("contract", {}).get("success") is True
                ),
                "alignment": {"passed": True},
                "execution": execution,
            }

            def evaluate_candidate(candidate: str, attempt: int) -> dict:
                attempt_dir = output_dir / "runtime-repair" / f"attempt-{attempt}"
                validation = self.modelica_pipeline.refine_layer1(
                    plan.modelica_requirement, candidate, runtime_repair_ask,
                    hits=[], max_repairs=0,
                    output_dir=attempt_dir / "modelica-validation",
                )
                modelica_passed = validation.get("passed") is True
                try:
                    identity = find_model_name(candidate) == find_model_name(modelica)
                except ValueError:
                    identity = False
                candidate_execution = (
                    self.execution_pipeline.run(
                        candidate, plan.requirement_ir, plan.contract,
                        output_dir=attempt_dir / "execution",
                    ) if modelica_passed and identity else {
                        "stage": "capability_behavior_execution",
                        "passed": False,
                        "execution_completed": False,
                        "failure_stage": (
                            "modelica_identity" if modelica_passed else
                            "modelica_validation"
                        ),
                    }
                )
                contract_preserved = (
                    candidate_execution.get("contract", {}).get("success") is True
                )
                _write_json(attempt_dir / "modelica-validation.json", validation)
                _write_json(attempt_dir / "execution.json", candidate_execution)
                return {
                    "modelica": candidate,
                    "modelica_passed": modelica_passed,
                    "identity_preserved": identity,
                    "pre_alignment_passed": contract_preserved,
                    "alignment": {"passed": contract_preserved},
                    "execution": candidate_execution,
                }

            repair = guarded_capability_runtime_repair(
                plan.modelica_requirement, baseline, runtime_repair_ask,
                evaluate_candidate, max_repairs=max_runtime_repairs,
            )
            final = repair["final"]
            if repair["repairs_accepted"]:
                (modelica_dir / "pre-runtime-model.mo").write_text(
                    modelica, encoding="utf-8"
                )
                modelica = final["modelica"]
                execution = final["execution"]
                (modelica_dir / "model.mo").write_text(modelica, encoding="utf-8")
            _write_json(output_dir / "runtime-repair.json", repair)
            result["runtime_repair"] = {
                "enabled": True,
                "triggered": True,
                "max_repairs": max_runtime_repairs,
                "report": "runtime-repair.json",
                "attempted": repair["repairs_attempted"],
                "accepted": repair["repairs_accepted"],
                "infrastructure_error": repair.get("infrastructure_error"),
                "original_model": (
                    "modelica/pre-runtime-model.mo"
                    if repair["repairs_accepted"] else None
                ),
                "final_model": "modelica/model.mo",
            }

        _write_json(output_dir / "execution.json", execution)
        result["hybrid"] = _execution_summary(execution)
        if enable_specification_alignment and execution.get("execution_completed"):
            alignment = evaluate_modelica_specification(
                plan.requirement_ir, modelica, plan.contract, execution,
                ask=specification_ask,
            )
        elif enable_specification_alignment:
            alignment = skipped_modelica_specification(plan.task_id)
            alignment.update({
                "enabled": True, "skipped": False, "not_run": True,
                "passed": False,
            })
        else:
            alignment = skipped_modelica_specification(plan.task_id)
        _write_json(output_dir / "alignment.json", alignment)
        result["alignment"] = {
            "enabled": enable_specification_alignment,
            "passed": alignment.get("passed") is True,
            "skipped": alignment.get("skipped", False),
            "not_run": alignment.get("not_run", False),
            "claim_ready": alignment.get("claim_ready", False),
            "report": "alignment.json",
            **alignment["summary"],
        }
        report = capability_report(
            plan.requirement_ir,
            modelica_passed=True,
            contract_valid=execution.get("contract", {}).get("success"),
            execution_completed=execution.get("execution_completed"),
            behavior_evaluated=execution.get("behavior_evaluated"),
            artifact_mode="modelica_only",
        )
        _write_json(output_dir / "capability-report.json", report)
        result["capabilities"] = {
            "report": "capability-report.json",
            **report["verification"],
            "requested_feature_count": len(report["requested_features"]),
            "profile_count": len(report["profiles"]),
        }
        aligned = not enable_specification_alignment or alignment.get("passed") is True
        result["passed"] = execution.get("passed") is True and aligned
        result["failure_stage"] = (
            None if result["passed"] else
            execution.get("failure_stage") or "modelica_specification_alignment"
        )
        result["stage_trace"] = _stage_trace(result)
        return _finish(output_dir, result)


def _profile_summary(report: dict) -> dict:
    attempts = report.get("attempts", [])
    attempt_zero = None
    if isinstance(attempts, list) and attempts:
        value = attempts[0].get("passed")
        attempt_zero = value if isinstance(value, bool) else None
    return {
        "passed": report.get("passed") is True,
        "repairs": report.get("repairs"),
        "generation_mode": report.get("generation_mode"),
        "generation_model": report.get("generation_model"),
        "retrieved_examples": list(report.get("retrieved_examples", [])),
        "attempt_0_valid": attempt_zero,
        "expert_models": list(report.get("expert_models", [])),
        "expert_candidates": list(report.get("expert_candidates", [])),
        "combiner_model": report.get("combiner_model"),
        "expert_soft_fail_count": report.get("expert_soft_fail_count", 0),
        "study_controls": dict(report.get("study_controls", {})),
        "artifact": "modelica/model.mo",
        "report": "modelica/generation.json",
    }


def _execution_summary(report: dict) -> dict:
    properties = list(report.get("properties", []))
    return {
        "passed": report.get("passed") is True,
        "execution_completed": report.get("execution_completed") is True,
        "behavior_evaluated": report.get("behavior_evaluated") is True,
        "behavior_passed": report.get("behavior_passed") is True,
        "execution_mode": report.get("execution_mode"),
        "failure_stage": report.get("failure_stage"),
        "clock": report.get("clock", {}),
        "report": "execution.json",
        "fmu": report.get("fmu", {}),
        "contract": report.get("contract", {}),
        "execution": report.get("execution", {}),
        "trace_gate": report.get("trace_gate", {}),
        "properties": properties,
        "property_summary": report.get("property_summary", {}),
        "property_count": len(properties),
    }


def _stage_trace(result: dict) -> list[dict]:
    execution = result.get("hybrid", {})
    alignment = result.get("alignment", {})
    values = (
        ("requirement_normalization", "normalization" in result,
         result.get("normalization", {}).get("success") is True),
        ("interface_planning", "plan" in result,
         result.get("plan", {}).get("success") is True),
        ("modelica_validation", "modelica" in result,
         result.get("modelica", {}).get("passed") is True),
        ("modelica_identity", "modelica" in result,
         result.get("modelica", {}).get("identity_accepted") is True),
        ("fmu_export", bool(execution.get("fmu")),
         execution.get("fmu", {}).get("success") is True),
        ("fmu_interface_contract", bool(execution.get("contract")),
         execution.get("contract", {}).get("success") is True),
        ("runtime_initialization", bool(execution.get("execution")),
         execution.get("execution", {}).get("initialized") is True),
        ("runtime_execution", bool(execution.get("execution")),
         execution.get("execution_completed") is True),
        ("behavior_evaluation", execution.get("execution_completed") is True,
         execution.get("behavior_evaluated") is True),
        ("modelica_specification_alignment", bool(alignment),
         alignment.get("passed") is True),
    )
    return [{
        "index": index,
        "stage": stage,
        "reached": reached,
        "passed": passed if reached else None,
        "status": "passed" if reached and passed else "failed" if reached else "not_reached",
    } for index, (stage, reached, passed) in enumerate(values)]


def _baseline_stage_trace(result: dict) -> list[dict]:
    execution = result.get("hybrid", {})
    values = (
        ("modelica_validation", "modelica" in result,
         result.get("modelica", {}).get("passed") is True),
        ("modelica_identity", "modelica" in result,
         result.get("modelica", {}).get("identity_accepted") is True),
        ("fmu_export", bool(execution.get("fmu")),
         execution.get("fmu", {}).get("success") is True),
        ("runtime_initialization", bool(execution.get("execution")),
         execution.get("execution", {}).get("initialized") is True),
        ("runtime_execution", bool(execution.get("execution")),
         execution.get("execution_completed") is True),
        ("runtime_trace", bool(execution.get("trace_gate")),
         execution.get("trace_gate", {}).get("success") is True),
    )
    return [{
        "index": index,
        "stage": stage,
        "reached": reached,
        "passed": passed if reached else None,
        "status": (
            "passed" if reached and passed else
            "failed" if reached else "not_reached"
        ),
    } for index, (stage, reached, passed) in enumerate(values)]


def _write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )


def _finish(output_dir: Path, result: dict) -> dict:
    _write_json(output_dir / "result.json", result)
    return result
