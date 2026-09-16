"""One-factor-at-a-time SysML generation, validation, and execution pipeline."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from typing import Any, Callable, Optional

from nl2sysml import agent_rag_moe as agent
from nl2sysml.compiler_interface import check_code
from nl2sysml.sysml_execution import ExecutionRequest, run_sysml_execution

from .conditions import Condition


Ask = Callable[[str, str, str, Optional[str]], str]
Compile = Callable[..., Any]
Execute = Callable[[ExecutionRequest], Any]


class InfrastructureError(RuntimeError):
    """Failure of a provider or native evaluator, not a model outcome."""


def _sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + f".tmp.{os.getpid()}")
    temporary.write_text(
        json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def compiler_report(result: Any) -> dict:
    errors = list(getattr(result, "errors", []) or [])
    return {
        "passed": getattr(result, "is_valid", False) is True,
        "error_count": len(errors),
        "syntax_error_count": sum(error.is_syntax_error() for error in errors),
        "semantic_error_count": sum(error.is_semantic_error() for error in errors),
        "errors": [
            {
                "severity": error.severity,
                "line": error.line,
                "column": error.column,
                "message": error.message,
                "code": error.code,
                "file": error.file,
            }
            for error in errors
        ],
    }


def execution_report(result: Any) -> dict:
    report = result.to_dict()
    diagnostics = report.get("diagnostics") or {}
    report["error_count"] = int(
        diagnostics.get("n_errors", len(report.get("errors", [])))
    )
    report["trace_observed"] = bool(report.get("trace"))
    return report


class StagewiseSysMLPipeline:
    """Run A1--A4 while keeping the final evaluators identical.

    Compiler and kernel execution are applied to every final candidate as
    read-only evaluators. Their diagnostics are exposed to the model only when
    the condition enables the corresponding feedback component.
    """

    def __init__(
        self,
        *,
        repository: Path,
        ask: Ask = agent._invoke_with_retry,
        compile_candidate: Compile = check_code,
        execute_candidate: Execute = run_sysml_execution,
        max_compiler_repairs: int = 2,
        max_execution_repairs: int = 2,
        retrieval_k: int = 3,
    ):
        if max_compiler_repairs < 0 or max_execution_repairs < 0:
            raise ValueError("repair counts must be non-negative")
        self.repository = repository
        self.ask = ask
        self.compile_candidate = compile_candidate
        self.execute_candidate = execute_candidate
        self.max_compiler_repairs = max_compiler_repairs
        self.max_execution_repairs = max_execution_repairs
        self.retrieval_k = retrieval_k

    def run(self, prompt_id: str, requirement: str, condition: Condition,
            output_dir: Path) -> dict:
        output_dir.mkdir(parents=True, exist_ok=True)
        (output_dir / "request.txt").write_text(
            requirement.strip() + "\n", encoding="utf-8"
        )
        context = agent._rag_context(
            requirement, self.repository, k=self.retrieval_k
        )
        if not context.strip():
            raise InfrastructureError("RAG returned no context from the frozen corpus")
        (output_dir / "retrieval-context.txt").write_text(
            context, encoding="utf-8"
        )

        _, openrouter_key = agent._load_env()
        system_prompt = agent._default_system_prompt(None)
        human_prompt = agent.PROMPT_HUMAN_TEMPLATE.format(
            context=context, input=requirement
        )
        (output_dir / "generation-system.txt").write_text(
            system_prompt, encoding="utf-8"
        )
        (output_dir / "generation-user.txt").write_text(
            human_prompt, encoding="utf-8"
        )

        experts: list[dict] = []
        if condition.moe:
            candidate_rows = []
            expert_dir = output_dir / "experts"
            expert_dir.mkdir(exist_ok=True)
            for index, model in enumerate(agent.EXPERT_MODELS, 1):
                candidate = self._ask(
                    model, system_prompt, human_prompt, openrouter_key
                )
                if not candidate.strip():
                    return self._save_generation_failure(
                        prompt_id, requirement, condition,
                        f"expert {model} returned an empty candidate",
                        output_dir,
                    )
                candidate_path = expert_dir / f"{index:02d}.sysml"
                candidate_path.write_text(candidate + "\n", encoding="utf-8")
                candidate_rows.append((model, candidate))
                experts.append({
                    "model": model,
                    "artifact": str(candidate_path.relative_to(output_dir)),
                    "sha256": _sha256_text(candidate),
                })

            blocks = []
            for index, (model, candidate) in enumerate(candidate_rows, 1):
                rating = agent.EXPERT_MODELS_RATING.get(
                    agent._model_group(model), 5
                )
                blocks.append(
                    f"Candidate {index} ({model}, rating={rating}/10):\n"
                    f"{candidate}\n---"
                )
            synthesis_context = (
                context
                + "\n\nUse the following candidate models as additional context.\n"
                + "\n".join(blocks)
            )
            synthesis_system = agent._default_system_prompt(
                "Synthesize a single best model by merging or selecting from "
                "the candidates when provided."
            )
            synthesis_user = agent.PROMPT_HUMAN_TEMPLATE.format(
                context=synthesis_context, input=requirement
            )
            (output_dir / "combiner-system.txt").write_text(
                synthesis_system, encoding="utf-8"
            )
            (output_dir / "combiner-user.txt").write_text(
                synthesis_user, encoding="utf-8"
            )
            candidate = self._ask(
                agent.COMBINER_MODEL, synthesis_system, synthesis_user,
                openrouter_key,
            )
            repair_system = synthesis_system
            repair_user = synthesis_user
        else:
            candidate = self._ask(
                agent.COMBINER_MODEL, system_prompt, human_prompt, openrouter_key
            )
            repair_system = system_prompt
            repair_user = human_prompt

        if not candidate.strip():
            return self._save_generation_failure(
                prompt_id, requirement, condition,
                "generation returned an empty candidate",
                output_dir,
            )
        (output_dir / "candidate-initial.sysml").write_text(
            candidate + "\n", encoding="utf-8"
        )

        compiler_attempts = []
        compilation = self._compile(candidate)
        compiler_attempts.append({
            "attempt": 0, "accepted": True, "report": compilation,
            "artifact": "candidate-initial.sysml",
        })
        if condition.compiler_feedback:
            candidate, compilation, compiler_attempts = self._compiler_repair(
                requirement, candidate, compilation, repair_system, repair_user,
                openrouter_key, output_dir, compiler_attempts,
            )
        (output_dir / "candidate-after-compiler.sysml").write_text(
            candidate + "\n", encoding="utf-8"
        )

        execution = self._execute(candidate, output_dir / "execution-initial")
        execution_attempts = [{
            "attempt": 0,
            "accepted": True,
            "compiler": compilation,
            "execution": execution,
            "artifact": "candidate-after-compiler.sysml",
        }]
        if condition.execution_feedback:
            candidate, compilation, execution, execution_attempts = (
                self._execution_repair(
                    requirement, candidate, compilation, execution,
                    repair_system, repair_user, openrouter_key, output_dir,
                    execution_attempts,
                )
            )

        (output_dir / "final.sysml").write_text(
            candidate + "\n", encoding="utf-8"
        )
        _write_json(output_dir / "compiler-attempts.json", {
            "enabled": condition.compiler_feedback,
            "max_repairs": (
                self.max_compiler_repairs if condition.compiler_feedback else 0
            ),
            "attempts": compiler_attempts,
        })
        _write_json(output_dir / "execution-attempts.json", {
            "enabled": condition.execution_feedback,
            "max_repairs": (
                self.max_execution_repairs if condition.execution_feedback else 0
            ),
            "attempts": execution_attempts,
        })

        result = {
            "schema_version": "1.0",
            "stage": "sysml_stagewise_ablation",
            "task_id": prompt_id,
            "condition": condition.to_dict(),
            "passed": compilation["passed"] and execution["success"],
            "failure_stage": (
                None if compilation["passed"] and execution["success"] else
                "compiler_evaluation" if not compilation["passed"] else
                "kernel_execution"
            ),
            "generation": {
                "passed": True,
                "rag_enabled": True,
                "retrieval_k": self.retrieval_k,
                "retrieval_context_sha256": _sha256_text(context),
                "moe_enabled": condition.moe,
                "expert_models": list(agent.EXPERT_MODELS) if condition.moe else [],
                "expert_candidates": experts,
                "expert_candidate_count": len(experts),
                "combiner_model": agent.COMBINER_MODEL,
                "initial_artifact": "candidate-initial.sysml",
                "final_artifact": "final.sysml",
            },
            "compiler": compilation,
            "execution": execution,
            "compiler_repairs": {
                "enabled": condition.compiler_feedback,
                "attempted": max(0, len(compiler_attempts) - 1),
                "accepted": sum(
                    row.get("accepted") is True for row in compiler_attempts[1:]
                ),
            },
            "execution_repairs": {
                "enabled": condition.execution_feedback,
                "attempted": max(0, len(execution_attempts) - 1),
                "accepted": sum(
                    row.get("accepted") is True for row in execution_attempts[1:]
                ),
            },
            "evaluation_scope": {
                "compiler": "SysML v2 syntax_and_semantics",
                "execution": "OMG SysML Jupyter kernel harness",
                "kernel_success_semantics": (
                    "payload compiled/executed without ERROR diagnostics; "
                    "raw trace is preserved"
                ),
                "specification_alignment": False,
            },
            "study_validity": {"eligible": True, "issues": []},
        }
        _write_json(output_dir / "result.json", result)
        return result

    def _ask(self, model: str, system: str, human: str,
             key: str | None) -> str:
        try:
            return self.ask(model, system, human, key)
        except Exception as exc:
            message = str(exc)
            if "empty response" in message.lower():
                return ""
            raise InfrastructureError(
                f"model transport failed for {model}: {message}"
            ) from exc

    def _compile(self, candidate: str) -> dict:
        return compiler_report(
            self.compile_candidate(candidate, syntax_only=False)
        )

    def _execute(self, candidate: str, output_dir: Path) -> dict:
        output_dir.mkdir(parents=True, exist_ok=True)
        result = self.execute_candidate(ExecutionRequest(
            candidate_sysml=candidate,
            trace_output_path=str(output_dir / "trace.txt"),
            diagnostics_output_path=str(output_dir / "diagnostics.json"),
        ))
        report = execution_report(result)
        _write_json(output_dir / "execution.json", report)
        if report.get("kernel_available") is not True or report.get("bridge_error"):
            raise InfrastructureError(
                "SysML kernel unavailable: "
                + str(report.get("bridge_error") or "unknown kernel failure")
            )
        return report

    def _compiler_repair(
        self, requirement: str, candidate: str, report: dict,
        system: str, human: str, key: str | None, output_dir: Path,
        attempts: list[dict],
    ) -> tuple[str, dict, list[dict]]:
        current, current_report = candidate, report
        for attempt in range(1, self.max_compiler_repairs + 1):
            if current_report["passed"]:
                break
            feedback = json.dumps(current_report["errors"], indent=2)
            repair_system = (
                system + "\n\nRepair the candidate using the native SysML "
                "compiler diagnostics. Preserve the stated requirements. "
                "Return complete SysML v2 only."
            )
            repair_user = (
                f"{human}\n\nPrevious candidate:\n{current}\n\n"
                f"Compiler diagnostics:\n{feedback}\n\nReturn corrected SysML v2."
            )
            revised = self._ask(
                agent.COMBINER_MODEL, repair_system, repair_user, key
            )
            artifact = output_dir / f"compiler-repair-{attempt:02d}.sysml"
            artifact.write_text(revised + "\n", encoding="utf-8")
            revised_report = self._compile(revised)
            accepted = self._compiler_quality(revised_report) > self._compiler_quality(
                current_report
            )
            attempts.append({
                "attempt": attempt,
                "accepted": accepted,
                "report": revised_report,
                "artifact": artifact.name,
            })
            if accepted:
                current, current_report = revised, revised_report
        return current, current_report, attempts

    def _execution_repair(
        self, requirement: str, candidate: str, compilation: dict,
        execution: dict, system: str, human: str, key: str | None,
        output_dir: Path, attempts: list[dict],
    ) -> tuple[str, dict, dict, list[dict]]:
        current = candidate
        current_compilation = compilation
        current_execution = execution
        for attempt in range(1, self.max_execution_repairs + 1):
            if current_execution["success"] and current_compilation["passed"]:
                break
            feedback = {
                "kernel_errors": current_execution.get("errors", []),
                "kernel_diagnostics": current_execution.get("diagnostics", {}),
                "compiler_errors": current_compilation.get("errors", []),
            }
            repair_system = (
                system + "\n\nRepair the candidate using the native compiler "
                "and SysML kernel execution diagnostics. Preserve the stated "
                "requirements and do not emit an ExecutionHarness. Return complete "
                "candidate SysML v2 only."
            )
            repair_user = (
                f"{human}\n\nPrevious candidate:\n{current}\n\n"
                f"Execution feedback:\n{json.dumps(feedback, indent=2)}\n\n"
                "Return corrected SysML v2 only."
            )
            revised = self._ask(
                agent.COMBINER_MODEL, repair_system, repair_user, key
            )
            artifact = output_dir / f"execution-repair-{attempt:02d}.sysml"
            artifact.write_text(revised + "\n", encoding="utf-8")
            revised_compilation = self._compile(revised)
            revised_execution = self._execute(
                revised, output_dir / f"execution-repair-{attempt:02d}"
            )
            accepted = self._execution_quality(
                revised_compilation, revised_execution
            ) > self._execution_quality(current_compilation, current_execution)
            attempts.append({
                "attempt": attempt,
                "accepted": accepted,
                "compiler": revised_compilation,
                "execution": revised_execution,
                "artifact": artifact.name,
            })
            if accepted:
                current = revised
                current_compilation = revised_compilation
                current_execution = revised_execution
        return current, current_compilation, current_execution, attempts

    @staticmethod
    def _compiler_quality(report: dict) -> tuple[int, int]:
        return int(report["passed"]), -int(report["error_count"])

    @staticmethod
    def _execution_quality(compilation: dict, execution: dict) -> tuple[int, ...]:
        return (
            int(compilation["passed"]),
            int(execution.get("success") is True),
            -int(compilation["error_count"]),
            -int(execution.get("error_count", 0)),
            int(execution.get("trace_observed") is True),
        )

    @staticmethod
    def _save_generation_failure(
        prompt_id: str, requirement: str, condition: Condition, reason: str,
        output_dir: Path,
    ) -> dict:
        result = {
            "schema_version": "1.0",
            "stage": "sysml_stagewise_ablation",
            "task_id": prompt_id,
            "condition": condition.to_dict(),
            "passed": False,
            "failure_stage": "model_generation",
            "generation": {"passed": False, "reason": reason},
            "study_validity": {"eligible": True, "issues": []},
            "requirement_sha256": _sha256_text(requirement),
        }
        _write_json(output_dir / "result.json", result)
        return result
