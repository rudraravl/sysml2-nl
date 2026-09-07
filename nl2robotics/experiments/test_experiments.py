from __future__ import annotations

from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from nl2robotics.benchmark.suite import BenchmarkSuite
from nl2robotics.experiments.conditions import CONDITIONS
from nl2robotics.experiments.executor import (
    COMBINER_MODEL,
    EXPERT_MODELS,
    PipelineExperimentExecutor,
    _one_shot_outcomes,
    _study_validity,
    generation_requirement,
    generation_strategy,
)
from nl2robotics.experiments.metrics import (
    extract_metrics,
    paired_binary_comparison,
    summarize_records,
)
from nl2robotics.experiments.protocol import freeze_protocol
from nl2robotics.experiments.runner import AblationRunner, planned_cells
from nl2robotics.experiments.run_cli import (
    _load_suite,
    _preflight_llm_environment,
    _preflight_modelica_backend,
)
from nl2robotics.modelica.models import Diagnostic, ModelicaBuild
from nl2robotics.orchestrator.normalizer import NormalizationResult
from nl2robotics.studies.capability_matrix import MANIFEST as CAPABILITY_MANIFEST


class ExperimentTests(unittest.TestCase):
    def test_capability_manifest_is_selected_by_experiment_cli(self):
        suite = _load_suite(CAPABILITY_MANIFEST)
        selected = suite.select(profile="capability", variant="rich")
        self.assertEqual(13, len(selected))
        self.assertEqual("RCB001", selected[0][0].id)

    def test_frozen_conditions_map_to_distinct_generation_strategies(self):
        self.assertEqual("direct", generation_strategy(CONDITIONS["B0"]))
        self.assertEqual("rag_single", generation_strategy(CONDITIONS["B1"]))
        self.assertEqual("rag_moe", generation_strategy(CONDITIONS["B2"]))
        self.assertEqual("rag_moe", generation_strategy(CONDITIONS["FULL"]))

    def test_contract_prompt_is_hidden_from_non_contract_baselines(self):
        for condition_id in ("B0", "B1", "B2"):
            self.assertEqual(
                "raw",
                generation_requirement("raw", "profiled", CONDITIONS[condition_id]),
            )
        for condition_id in ("B3", "FULL"):
            self.assertEqual(
                "profiled",
                generation_requirement("raw", "profiled", CONDITIONS[condition_id]),
            )

    def test_runner_checkpoints_and_resumes_exact_cells(self):
        task = BenchmarkSuite().select(profile="modelica")[0]
        calls = {"count": 0}

        def execute(task, condition, prompt, output_dir):
            calls["count"] += 1
            return {"passed": condition.id == "FULL", "failure_stage": None}

        with tempfile.TemporaryDirectory() as tmp:
            runner = AblationRunner(Path(tmp), configuration={"model": "test"})
            first = runner.run([task], [CONDITIONS["B0"], CONDITIONS["FULL"]],
                               execute, variant="rich")
            second = runner.run([task], [CONDITIONS["B0"], CONDITIONS["FULL"]],
                                execute, variant="rich")
        self.assertEqual(2, calls["count"])
        self.assertEqual(first, second)

    def test_runner_prepares_one_shared_block_for_all_conditions(self):
        task = BenchmarkSuite().select(profile="hybrid")[0]

        class Executor:
            def __init__(self):
                self.prepares = 0
                self.contexts = []

            def prepare_block(self, task, prompt, repetition, output_dir):
                self.prepares += 1
                return {"token": object()}

            def __call__(self, task, condition, prompt, output_dir, *, block_context):
                self.contexts.append(block_context)
                return {
                    "passed": False,
                    "study_validity": {"eligible": True},
                }

        execute = Executor()
        with tempfile.TemporaryDirectory() as tmp:
            AblationRunner(Path(tmp)).run(
                [task], [CONDITIONS["B0"], CONDITIONS["FULL"]], execute,
                variant="rich",
            )
        self.assertEqual(1, execute.prepares)
        self.assertEqual(2, len(execute.contexts))
        self.assertIs(execute.contexts[0], execute.contexts[1])

    def test_shards_are_disjoint_and_cover_the_global_randomized_plan(self):
        tasks = BenchmarkSuite().select(profile="hybrid")[:5]
        conditions = [CONDITIONS["B0"], CONDITIONS["FULL"]]
        seen = [[], []]

        def execute(task, condition, prompt, output_dir):
            seen[current_shard].append((task.id, condition.id))
            return {
                "passed": True,
                "study_validity": {"eligible": True},
            }

        with tempfile.TemporaryDirectory() as tmp:
            for current_shard in range(2):
                runner = AblationRunner(
                    Path(tmp), randomization_seed=17,
                    randomize_task_order=True,
                    shard_count=2, shard_index=current_shard,
                )
                records = runner.run(
                    tasks, conditions, execute, variant="rich",
                )
                self.assertEqual(
                    current_shard,
                    runner.last_run_control["shard_index"],
                )
            self.assertTrue((Path(tmp) / "run-control-shard-000-of-002.json").is_file())
            self.assertTrue((Path(tmp) / "run-control-shard-001-of-002.json").is_file())
        self.assertFalse(set(seen[0]) & set(seen[1]))
        self.assertEqual(
            sorted(
                (task.id, condition.id)
                for task, _ in tasks for condition in conditions
            ),
            sorted(seen[0] + seen[1]),
        )
        owner = {}
        for shard_index, rows in enumerate(seen):
            for task_id, _ in rows:
                owner.setdefault(task_id, set()).add(shard_index)
        self.assertTrue(all(len(shards) == 1 for shards in owner.values()))

    def test_normalization_block_is_cached_and_reconstructed_exactly(self):
        task, prompt = BenchmarkSuite().select(profile="hybrid")[0]
        ir = {"source_text": prompt, "execution_mode": "portable_fmu_kinematic"}

        class Normalizer:
            def __init__(self):
                self.calls = 0

            def normalize(self, *args, task_id, **kwargs):
                self.calls += 1
                return NormalizationResult(task_id=task_id, ir={
                    **ir, "task_id": task_id, "schema_version": "1.0",
                }, attempts=[{"attempt": 0, "valid": True, "response": "{}"}])

        normalizer = Normalizer()
        executor = PipelineExperimentExecutor(
            text_ask=lambda _: "", json_ask=lambda _: "", normalizer=normalizer,
        )
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            first = executor.prepare_block(task, prompt, 0, root)
            second = executor.prepare_block(task, prompt, 0, root)
        self.assertEqual(1, normalizer.calls)
        self.assertEqual(first["normalized_ir_sha256"], second["normalized_ir_sha256"])
        self.assertEqual(first["normalization"].ir, second["normalization"].ir)

    def test_condition_order_is_blocked_randomized_and_reproducible(self):
        tasks = BenchmarkSuite().select(profile="hybrid")[:3]
        conditions = list(CONDITIONS.values())
        first = planned_cells(tasks, conditions, repetitions=2, seed=17)
        second = planned_cells(tasks, conditions, repetitions=2, seed=17)
        third = planned_cells(tasks, conditions, repetitions=2, seed=18)
        key = lambda rows: [
            (row["task"].id, row["repetition"], row["condition"].id)
            for row in rows
        ]
        self.assertEqual(key(first), key(second))
        self.assertNotEqual(key(first), key(third))
        for offset in range(0, len(first), len(conditions)):
            block = first[offset:offset + len(conditions)]
            self.assertEqual(len(conditions), len({row["condition"].id for row in block}))

    def test_corpus_task_order_is_seeded_randomized_and_reproducible(self):
        tasks = BenchmarkSuite().select()[:10]
        conditions = [CONDITIONS["FULL"]]
        first = planned_cells(
            tasks, conditions, repetitions=1, seed=17,
            randomize_task_order=True,
        )
        second = planned_cells(
            tasks, conditions, repetitions=1, seed=17,
            randomize_task_order=True,
        )
        third = planned_cells(
            tasks, conditions, repetitions=1, seed=18,
            randomize_task_order=True,
        )
        ids = lambda rows: [row["task"].id for row in rows]
        canonical = sorted(task.id for task, _ in tasks)
        self.assertEqual(ids(first), ids(second))
        self.assertNotEqual(canonical, ids(first))
        self.assertNotEqual(ids(first), ids(third))
        self.assertEqual(canonical, sorted(ids(first)))

    def test_runtime_preflight_reports_backend_failure(self):
        class Pipeline:
            class Runner:
                backend = "docker"

                @staticmethod
                def resolved_backend():
                    return "docker"

            runner = Runner()

            @staticmethod
            def compile(source, *, output_dir):
                self.assertIn("NL2RoboticsRuntimePreflight", source)
                return type("Result", (), {"passed": False, "build": ModelicaBuild(
                    True, "NL2RoboticsRuntimePreflight",
                    diagnostics=[Diagnostic(
                        "infrastructure", "error", "Docker daemon unavailable"
                    )],
                )})()

        with tempfile.TemporaryDirectory() as tmp:
            report = _preflight_modelica_backend(Pipeline(), Path(tmp))
        self.assertFalse(report["success"])
        self.assertEqual(["Docker daemon unavailable"], report["diagnostics"])

    def test_llm_preflight_rejects_provider_model_mismatch_without_calls(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch(
                "nl2robotics.experiments.run_cli.shutil.which",
                return_value="/usr/bin/claude",
            ), patch.dict(
                "os.environ", {"OPENROUTER_API_KEY": "present"}, clear=True,
            ):
                report = _preflight_llm_environment(
                    model="gpt-5.4", provider="claude", repository=Path(tmp)
                )
        self.assertFalse(report["success"])
        self.assertTrue(any(
            "incompatible" in item for item in report["diagnostics"]
        ))

    def test_non_moe_preflight_does_not_require_openrouter(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch(
                "nl2robotics.experiments.run_cli.shutil.which",
                return_value="/usr/bin/codex",
            ), patch(
                "nl2robotics.experiments.run_cli.probe_completion",
                return_value="READY",
            ), patch.dict("os.environ", {}, clear=True):
                report = _preflight_llm_environment(
                    model="gpt-5.4", provider="codex",
                    repository=Path(tmp), require_moe=False,
                )
        self.assertTrue(report["success"])
        self.assertFalse(report["moe_required"])
        self.assertTrue(report["model_probe_attempted"])
        self.assertTrue(report["model_probe_passed"])

    def test_llm_preflight_rejects_unusable_model_before_cells(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch(
                "nl2robotics.experiments.run_cli.shutil.which",
                return_value="/usr/bin/codex",
            ), patch(
                "nl2robotics.experiments.run_cli.probe_completion",
                side_effect=RuntimeError("model is not supported"),
            ), patch.dict("os.environ", {}, clear=True):
                report = _preflight_llm_environment(
                    model="gpt-unsupported", provider="codex",
                    repository=Path(tmp), require_moe=False,
                )
        self.assertFalse(report["success"])
        self.assertTrue(report["model_probe_attempted"])
        self.assertFalse(report["model_probe_passed"])
        self.assertTrue(any(
            "model is not supported" in item for item in report["diagnostics"]
        ))

    def test_usage_limit_stops_without_recording_failed_cell(self):
        task = BenchmarkSuite().select(profile="modelica")[0]

        def execute(*args, **kwargs):
            raise RuntimeError("You've hit your usage limit. Try again later.")

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            runner = AblationRunner(root)
            records = runner.run(
                [task], [CONDITIONS["B0"], CONDITIONS["FULL"]], execute,
                variant="rich",
            )
            self.assertEqual([], records)
            self.assertTrue(runner.last_run_control["stopped_early"])
            self.assertEqual([], list(root.glob("**/run.json")))

    def test_infrastructure_degraded_cell_is_not_resumed(self):
        task = BenchmarkSuite().select(profile="modelica")[0]
        calls = {"count": 0}

        def execute(*args, **kwargs):
            calls["count"] += 1
            return {"infrastructure_pending": True, "passed": False}

        with tempfile.TemporaryDirectory() as tmp:
            runner = AblationRunner(Path(tmp))
            runner.run([task], [CONDITIONS["B0"]], execute, variant="rich")
            runner.run([task], [CONDITIONS["B0"]], execute, variant="rich")
        self.assertEqual(2, calls["count"])

    def test_missing_moe_expert_is_infrastructure_ineligible(self):
        report = {
            "generation_mode": "moe",
            "retrieved_examples": [{"id": "X"}],
            "expert_candidates": ["only-one"],
            "expert_soft_fail_count": 1,
            "study_controls": {
                "rag_enabled": True, "moe_enabled": True,
                "tool_repair_enabled": False,
            },
        }
        validity = _study_validity(
            {"stage": "modelica_experiment", "generation": report},
            CONDITIONS["B2"], True,
        )
        self.assertFalse(validity["eligible"])
        self.assertTrue(any("expert" in issue for issue in validity["issues"]))

    def test_provider_timeout_is_infrastructure_ineligible(self):
        validity = _study_validity({
            "stage": "robotics_orchestrator",
            "failure_stage": "openusd_generation",
            "error": (
                "OpenRouter call failed (z-ai/glm-5.2): "
                "The read operation timed out"
            ),
            "modelica": {
                "passed": True,
                "generation_mode": "moe",
                "retrieved_examples": [{"id": str(i)} for i in range(5)],
                "expert_candidates": list(EXPERT_MODELS),
                "expert_models": list(EXPERT_MODELS),
                "expert_soft_fail_count": 0,
                "combiner_model": COMBINER_MODEL,
                "study_controls": {
                    "rag_enabled": True,
                    "moe_enabled": True,
                    "tool_repair_enabled": True,
                    "retrieval_k": 5,
                },
            },
        }, CONDITIONS["FULL"], True)
        self.assertFalse(validity["eligible"])
        self.assertTrue(any(
            "provider infrastructure failure" in issue
            for issue in validity["issues"]
        ))

    def test_attempt_zero_is_separate_from_repaired_final_validity(self):
        result = {
            "stage": "modelica_experiment",
            "passed": True,
            "modelica": {"passed": True},
            "generation": {
                "generation_mode": "direct",
                "attempts": [{"attempt": 0, "passed": False},
                             {"attempt": 1, "passed": True}],
            },
        }
        result["one_shot"] = _one_shot_outcomes(result)
        metrics = extract_metrics("modelica", result)
        self.assertFalse(metrics["modelica_build_attempt_0"])
        self.assertTrue(metrics["modelica_build"])

    def test_protocol_freezes_corpora_models_and_exact_cell_fingerprints(self):
        task = BenchmarkSuite().select(profile="modelica")[:1]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "repo"
            for domain in ("modelica", "openusd"):
                corpus = root / "nl2robotics" / domain / "examples"
                corpus.mkdir(parents=True)
                (corpus / "manifest.json").write_text("[]\n", encoding="utf-8")
                (corpus / "corpus_subsets.json").write_text("{}\n", encoding="utf-8")
                (corpus / "artifact.txt").write_text(domain, encoding="utf-8")
            report, configuration = freeze_protocol(
                repository=root,
                output_dir=Path(tmp) / "out",
                tasks=task,
                conditions=[CONDITIONS["B0"], CONDITIONS["FULL"]],
                variant="rich",
                repetitions=2,
                configuration={"single_model": "test"},
                randomization_seed=11,
            )
            with self.assertRaises(ValueError):
                freeze_protocol(
                    repository=root,
                    output_dir=Path(tmp) / "out",
                    tasks=task,
                    conditions=[CONDITIONS["B0"], CONDITIONS["FULL"]],
                    variant="rich",
                    repetitions=2,
                    configuration={"single_model": "changed"},
                    randomization_seed=11,
                )
        self.assertEqual(4, report["planned_cell_count"])
        self.assertEqual(4, len({row["fingerprint"] for row in report["planned_cells"]}))
        self.assertEqual(3, report["corpora"]["modelica"]["file_count"])
        self.assertIn("study_protocol_core_sha256", configuration)

    def test_summary_separates_infrastructure_failure(self):
        base = {
            "task_id": "T1", "profile": "hybrid", "variant": "rich",
            "repetition": 0,
        }
        records = [
            {**base, "condition": {"id": "B0"}, "metrics": {
                "infrastructure_available": True, "end_to_end": False,
                "failure_stage": "generation",
            }},
            {**base, "condition": {"id": "FULL"}, "metrics": {
                "infrastructure_available": True, "end_to_end": True,
                "failure_stage": None,
            }},
            {**base, "task_id": "T2", "condition": {"id": "FULL"}, "metrics": {
                "infrastructure_available": False, "end_to_end": None,
                "failure_stage": "infrastructure",
            }},
        ]
        summary = summarize_records(records, bootstrap_samples=100)
        self.assertEqual(1, summary["infrastructure_failure_count"])
        self.assertEqual(1.0, summary["conditions"]["FULL"]["binary"]
                         ["end_to_end"]["rate"])
        paired = paired_binary_comparison(records, "B0", "FULL", "end_to_end")
        self.assertEqual(1, paired["paired_count"])
        self.assertEqual(1, paired["b_only_success"])

    def test_isaac_result_populates_headline_metrics(self):
        result = {
            "stage": "isaac_closed_loop",
            "success": True,
            "passed": True,
            "contract": {"success": True},
            "fmu": {"success": True},
            "execution": {"success": True},
            "simulator": {"loaded": True},
            "repeatability": {"success": True},
            "properties": [{"passed": True}],
        }
        metrics = extract_metrics("hybrid", result)
        self.assertTrue(metrics["end_to_end"])
        self.assertTrue(metrics["fmu_execution"])
        self.assertTrue(metrics["contract_valid"])
        self.assertTrue(metrics["named_simulator_load"])
        self.assertTrue(metrics["stable_simulation"])
        self.assertTrue(metrics["all_properties_pass"])

    def test_pending_h2_infrastructure_is_excluded_from_rates(self):
        metrics = extract_metrics("hybrid", {
            "infrastructure_pending": True,
            "ready_for_gpu": True,
            "passed": False,
        })
        self.assertFalse(metrics["infrastructure_available"])
        self.assertIsNone(metrics["end_to_end"])

    def test_legacy_capability_validation_is_not_end_to_end_execution(self):
        metrics = extract_metrics("capability", {
            "passed": True, "failure_stage": None,
            "normalization": {"success": True},
            "plan": {"success": True},
            "modelica": {"passed": True},
            "openusd": {"passed": True},
            "capabilities": {"highest_reached_tier": 2},
        })
        self.assertTrue(metrics["normalization_valid"])
        self.assertTrue(metrics["ir_valid"])
        self.assertTrue(metrics["artifact_pair_valid"])
        self.assertEqual(2, metrics["verification_tier"])
        self.assertFalse(metrics["end_to_end"])
        self.assertIsNone(metrics["fmu_execution"])

    def test_disabled_alignment_is_not_counted_as_full_funnel_success(self):
        metrics = extract_metrics("capability", {
            "passed": True,
            "ablation": {"condition": {"alignment": False}},
            "stage_trace": [
                {"index": 8, "stage": "runtime_execution", "reached": True,
                 "passed": True, "status": "passed"},
                {"index": 11, "stage": "post_execution_semantic_alignment",
                 "reached": False, "passed": None, "status": "disabled"},
            ],
        })
        self.assertTrue(metrics["configured_pipeline_success"])
        self.assertIsNone(metrics["end_to_end"])

    def test_h2_handoff_result_replaces_preparation_for_metrics(self):
        isaac = {
            "stage": "isaac_closed_loop", "success": True, "passed": True,
            "claim_eligible_h2": True,
        }
        executor = object.__new__(PipelineExperimentExecutor)
        executor.h2_handoff = lambda **kwargs: {
            "success": True, "failure_stage": None, "isaac_report": isaac,
        }
        executor.newton_handoff = None
        with tempfile.TemporaryDirectory() as tmp:
            result = executor._complete_h2({
                "ready_for_gpu": True,
                "passed": False,
                "hybrid": {"manifest": "hybrid/execution-input.json"},
            }, Path(tmp))
        self.assertTrue(result["passed"])
        self.assertTrue(result["claim_eligible_h2"])
        self.assertIs(result["hybrid"], isaac)

    def test_newton_handoff_result_populates_claim_metrics(self):
        newton = {
            "stage": "newton_closed_loop", "success": True, "passed": True,
            "claim_eligible_h2": True, "claim_eligible_newton_h2": True,
        }
        executor = object.__new__(PipelineExperimentExecutor)
        executor.h2_handoff = None
        executor.newton_handoff = lambda **kwargs: {
            "success": True, "failure_stage": None, "newton_report": newton,
        }
        with tempfile.TemporaryDirectory() as tmp:
            result = executor._complete_h2({
                "ready_for_gpu": True,
                "passed": False,
                "hybrid": {"manifest": "hybrid/execution-input.json"},
            }, Path(tmp), "newton_h2")
        self.assertTrue(result["passed"])
        self.assertTrue(result["claim_eligible_h2"])
        self.assertIs(result["hybrid"], newton)


if __name__ == "__main__":
    unittest.main()
