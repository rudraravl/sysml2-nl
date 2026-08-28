"""Concrete adapters from frozen ablation conditions to robotics pipelines."""

from __future__ import annotations

import json
from pathlib import Path

from nl2robotics.benchmark.suite import BenchmarkSuite, BenchmarkTask
from nl2robotics.hybrid.portable import PortableHybridPipeline
from nl2robotics.modelica.moe import generate_modelica_moe
from nl2robotics.modelica.pipeline import ModelicaPipeline, clean_code
from nl2robotics.openusd.moe import generate_openusd_moe
from nl2robotics.openusd.pipeline import OpenUSDPipeline, clean_usda
from nl2robotics.orchestrator.pipeline import RoboticsOrchestrator

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
                 k: int = 5, max_tool_repairs: int = 2):
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
        self.k = k
        self.max_tool_repairs = max_tool_repairs

    def __call__(self, task: BenchmarkTask, condition: AblationCondition,
                 prompt: str, output_dir: Path) -> dict:
        output_dir.mkdir(parents=True, exist_ok=True)
        if task.profile == "modelica":
            result = self._run_modelica(task, condition, prompt, output_dir)
        elif task.profile == "openusd":
            result = self._run_openusd(condition, prompt, output_dir)
        else:
            result = self._run_hybrid(task, condition, prompt, output_dir)
        result["ablation"] = {
            "condition": condition.to_dict(),
            "generation_strategy": generation_strategy(condition),
            "contract_role": (
                "generation_and_validation" if condition.validated_contract
                else "paired_evaluation_only"
            ),
        }
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
                    prompt: str, output_dir: Path) -> dict:
        def modelica_generator(profile_requirement: str, generation_dir: Path):
            requirement = prompt if condition.id == "B0" else profile_requirement
            return self._generate_modelica(requirement, condition, generation_dir)

        def openusd_generator(profile_requirement: str, generation_dir: Path):
            requirement = prompt if condition.id == "B0" else profile_requirement
            return self._generate_openusd(requirement, condition, generation_dir)

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
            task_id=f"{task.id}-{condition.id}",
            execution_mode=(
                {
                    "isaac_h2": "isaac_closed_loop",
                    "newton_h2": "newton_closed_loop",
                    "capability_tier2": "capability_tiered",
                }.get(task.target_level, "portable_fmu_kinematic")
            ),
            max_ir_repairs=1,
            alignment_ask=self.json_ask if condition.alignment else None,
            semantic_repair_ask=self.text_ask if condition.alignment else None,
            max_semantic_repairs=(1 if condition.alignment else 0),
            enable_alignment=condition.alignment,
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
                            output_dir: Path) -> tuple[str, dict]:
        strategy = generation_strategy(condition)
        if strategy == "direct":
            system, human = self.modelica.build_baseline_messages(requirement)
            candidate = clean_code(self.text_ask(f"{system}\n\n{human}"))
            report = self.modelica.refine_layer1(
                requirement, candidate, self.text_ask, hits=[], max_repairs=0,
                output_dir=output_dir,
            )
            report["generation_mode"] = "direct"
            return report["final_modelica"], report
        if strategy == "rag_single":
            report = self.modelica.generate(
                requirement, self.text_ask, k=self.k, max_repairs=0,
                output_dir=output_dir,
            )
            report["generation_mode"] = "rag_single"
            return report["final_modelica"], report
        return self.modelica_moe(
            requirement,
            pipeline=self.modelica,
            k=self.k,
            max_repairs=self.max_tool_repairs if condition.tool_repair else 0,
            output_dir=output_dir,
        )

    def _generate_openusd(self, requirement: str, condition: AblationCondition,
                          output_dir: Path) -> tuple[str, dict]:
        strategy = generation_strategy(condition)
        if strategy == "direct":
            system, human = self.openusd.build_baseline_messages(requirement)
            candidate = clean_usda(self.text_ask(f"{system}\n\n{human}"))
            report = self.openusd.refine(
                requirement, candidate, self.text_ask, hits=[], max_repairs=0,
                output_dir=output_dir,
            )
            report["generation_mode"] = "direct"
            return report["final_openusd"], report
        if strategy == "rag_single":
            report = self.openusd.generate(
                requirement, self.text_ask, k=self.k, max_repairs=0,
                output_dir=output_dir,
            )
            report["generation_mode"] = "rag_single"
            return report["final_openusd"], report
        return self.openusd_moe(
            requirement,
            pipeline=self.openusd,
            k=self.k,
            max_repairs=self.max_tool_repairs if condition.tool_repair else 0,
            output_dir=output_dir,
        )


def generation_strategy(condition: AblationCondition) -> str:
    if not condition.rag and not condition.moe:
        return "direct"
    if condition.rag and not condition.moe:
        return "rag_single"
    return "rag_moe"


def _evaluation_task(task_id: str) -> dict:
    path = (
        Path(__file__).resolve().parents[1] / "modelica" / "examples"
        / "evaluation_tasks.json"
    )
    rows = json.loads(path.read_text(encoding="utf-8"))
    return next(item for item in rows if item["id"] == task_id)
