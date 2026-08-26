from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

from nl2robotics.benchmark.suite import BenchmarkSuite
from nl2robotics.experiments.conditions import CONDITIONS
from nl2robotics.experiments.executor import PipelineExperimentExecutor, generation_strategy
from nl2robotics.experiments.metrics import (
    extract_metrics,
    paired_binary_comparison,
    summarize_records,
)
from nl2robotics.experiments.runner import AblationRunner


class ExperimentTests(unittest.TestCase):
    def test_frozen_conditions_map_to_distinct_generation_strategies(self):
        self.assertEqual("direct", generation_strategy(CONDITIONS["B0"]))
        self.assertEqual("rag_single", generation_strategy(CONDITIONS["B1"]))
        self.assertEqual("rag_moe", generation_strategy(CONDITIONS["B2"]))
        self.assertEqual("rag_moe", generation_strategy(CONDITIONS["FULL"]))

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
