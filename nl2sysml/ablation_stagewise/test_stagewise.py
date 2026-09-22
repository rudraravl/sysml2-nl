from __future__ import annotations

import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from nl2sysml.compiler_interface import CompilerError, CompilerResult
from nl2sysml.sysml_execution.models import ExecutionResult

from .conditions import CONDITIONS
from .compare import paired_comparison
from .pipeline import StagewiseSysMLPipeline, compiler_report
from .build_rich_manifest import build_manifest
from .run_study import DEFAULT_DATASET, apply_jupyter_path_override, assigned_rows, load_seed


def _compiler(valid: bool, count: int = 0) -> CompilerResult:
    return CompilerResult(
        errors=[
            CompilerError("error", index + 1, 1, "bad", "Syntax")
            for index in range(count)
        ],
        is_valid=valid,
    )


def _execution(success: bool) -> ExecutionResult:
    return ExecutionResult(
        compiled=success,
        success=success,
        errors=[] if success else ["ERROR: failed"],
        trace=["executed"] if success else ["ERROR: failed"],
        model_kind="behavioral",
        harness="package ExecutionHarness {}",
        consolidated_payload="package Candidate {}",
        kernel_available=True,
        diagnostics={"n_errors": 0 if success else 1},
    )


class StagewiseTests(unittest.TestCase):
    def test_jupyter_override_is_applied_before_protocol_fingerprinting(self):
        with patch.dict(
            "os.environ",
            {"SYSML_JUPYTER_PATH": "/frozen/kernel", "JUPYTER_PATH": "/other"},
            clear=False,
        ):
            apply_jupyter_path_override()
            self.assertEqual(
                "/frozen/kernel:/other", os.environ["JUPYTER_PATH"]
            )

    def test_compiler_report_handles_diagnostics_without_codes(self):
        result = CompilerResult(
            errors=[CompilerError("error", 1, 1, "unclassified", None)],
            is_valid=False,
        )
        report = compiler_report(result)
        self.assertEqual(1, report["error_count"])
        self.assertEqual(0, report["syntax_error_count"])
        self.assertEqual(0, report["semantic_error_count"])

    def test_conditions_are_strictly_cumulative(self):
        self.assertEqual(
            (True, False, False, False),
            tuple(getattr(CONDITIONS["A1"], key) for key in (
                "rag", "moe", "compiler_feedback", "execution_feedback"
            )),
        )
        self.assertFalse(CONDITIONS["A2"].compiler_feedback)
        self.assertTrue(CONDITIONS["A2"].moe)
        self.assertTrue(CONDITIONS["A3"].compiler_feedback)
        self.assertFalse(CONDITIONS["A3"].execution_feedback)
        self.assertTrue(CONDITIONS["A4"].execution_feedback)

    def test_rich500_shards_are_disjoint_balanced_and_complete(self):
        rows = load_seed(DEFAULT_DATASET)
        self.assertEqual(500, len(rows))
        for shard_count in (4, 5, 6):
            owner = {}
            domain_counts = []
            for shard_index in range(shard_count):
                assigned = assigned_rows(
                    rows, shard_count=shard_count, shard_index=shard_index,
                    seed=20260916,
                )
                counts = {}
                for row in assigned:
                    self.assertNotIn(row["id"], owner)
                    owner[row["id"]] = shard_index
                    domain = row.get("domain", "unknown")
                    counts[domain] = counts.get(domain, 0) + 1
                domain_counts.append(counts)
            self.assertEqual(500, len(owner))
            for domain in {row.get("domain", "unknown") for row in rows}:
                values = [counts.get(domain, 0) for counts in domain_counts]
                self.assertLessEqual(max(values) - min(values), 1)

    def test_rich500_manifest_is_reproducible_and_a0_paired(self):
        rows = build_manifest(Path("."), count=500, seed=20260922)
        frozen = load_seed(DEFAULT_DATASET)
        self.assertEqual([row["id"] for row in frozen], [row["id"] for row in rows])
        self.assertTrue(all(row["prompt_source"] == "dataset_rich_nl" for row in rows))
        self.assertTrue(all(int(row["dataset_data_id"]) > 300 for row in rows))
        self.assertTrue(all((Path(".") / row["a0_candidate_path"]).is_file() for row in rows))

    def _run(self, condition_id, *, compiler, executor):
        calls = []

        def ask(model, system, human, key):
            calls.append(model)
            return f"package Candidate{len(calls)} {{}}"

        with tempfile.TemporaryDirectory() as tmp, patch(
            "nl2sysml.ablation_stagewise.pipeline.agent._rag_context",
            return_value="frozen context",
        ), patch(
            "nl2sysml.ablation_stagewise.pipeline.agent._load_env",
            return_value=(None, "key"),
        ):
            pipeline = StagewiseSysMLPipeline(
                repository=Path(tmp), ask=ask,
                compile_candidate=compiler, execute_candidate=executor,
                max_compiler_repairs=2, max_execution_repairs=2,
            )
            result = pipeline.run(
                "U1", "build a system", CONDITIONS[condition_id], Path(tmp) / "out"
            )
            saved = json.loads((Path(tmp) / "out" / "result.json").read_text())
        self.assertEqual(result["passed"], saved["passed"])
        return result, calls

    def test_a1_is_single_rag_call_but_uses_common_evaluators(self):
        compiler_calls = []
        execution_calls = []
        result, calls = self._run(
            "A1",
            compiler=lambda code, syntax_only=False: (
                compiler_calls.append(code) or _compiler(True)
            ),
            executor=lambda request: (
                execution_calls.append(request.candidate_sysml) or _execution(True)
            ),
        )
        self.assertEqual(["z-ai/glm-5.2"], calls)
        self.assertEqual(1, len(compiler_calls))
        self.assertEqual(1, len(execution_calls))
        self.assertTrue(result["passed"])

    def test_a2_requires_all_four_experts_and_combiner_without_repairs(self):
        result, calls = self._run(
            "A2", compiler=lambda *args, **kwargs: _compiler(True),
            executor=lambda request: _execution(True),
        )
        self.assertEqual(5, len(calls))
        self.assertEqual(4, result["generation"]["expert_candidate_count"])
        self.assertEqual(0, result["compiler_repairs"]["attempted"])
        self.assertEqual(0, result["execution_repairs"]["attempted"])

    def test_empty_generation_is_saved_as_eligible_model_failure(self):
        with tempfile.TemporaryDirectory() as tmp, patch(
            "nl2sysml.ablation_stagewise.pipeline.agent._rag_context",
            return_value="frozen context",
        ), patch(
            "nl2sysml.ablation_stagewise.pipeline.agent._load_env",
            return_value=(None, "key"),
        ):
            pipeline = StagewiseSysMLPipeline(
                repository=Path(tmp), ask=lambda *args: "",
                compile_candidate=lambda *args, **kwargs: _compiler(True),
                execute_candidate=lambda request: _execution(True),
            )
            output = Path(tmp) / "out"
            result = pipeline.run(
                "U1", "build a system", CONDITIONS["A1"], output
            )
            saved = json.loads((output / "result.json").read_text())
        self.assertEqual("model_generation", result["failure_stage"])
        self.assertEqual(result, saved)

    def test_a3_accepts_only_improving_compiler_repair(self):
        reports = iter((_compiler(False, 2), _compiler(True)))
        result, calls = self._run(
            "A3", compiler=lambda *args, **kwargs: next(reports),
            executor=lambda request: _execution(True),
        )
        self.assertEqual(6, len(calls))
        self.assertTrue(result["compiler"]["passed"])
        self.assertEqual(1, result["compiler_repairs"]["accepted"])

    def test_a3_uses_second_budgeted_attempt_after_rejected_repair(self):
        reports = iter((
            _compiler(False, 2),
            _compiler(False, 3),
            _compiler(True),
        ))
        result, calls = self._run(
            "A3", compiler=lambda *args, **kwargs: next(reports),
            executor=lambda request: _execution(True),
        )
        self.assertEqual(7, len(calls))
        self.assertTrue(result["compiler"]["passed"])
        self.assertEqual(2, result["compiler_repairs"]["attempted"])
        self.assertEqual(1, result["compiler_repairs"]["accepted"])

    def test_a4_repairs_and_reexecutes_after_kernel_failure(self):
        executions = iter((_execution(False), _execution(True)))
        result, calls = self._run(
            "A4", compiler=lambda *args, **kwargs: _compiler(True),
            executor=lambda request: next(executions),
        )
        self.assertEqual(6, len(calls))
        self.assertTrue(result["execution"]["success"])
        self.assertEqual(1, result["execution_repairs"]["accepted"])

    def test_paired_comparison_uses_only_common_eligible_ids(self):
        def row(compiled):
            return {"result": {
                "compiler": {"passed": compiled},
                "execution": {"success": compiled},
                "passed": compiled,
            }}

        report = paired_comparison(
            {"U1": row(False), "U2": row(True), "left-only": row(True)},
            {"U1": row(True), "U2": row(True), "right-only": row(False)},
            "compiler_pass",
        )
        self.assertEqual(2, report["common_eligible_count"])
        self.assertEqual(1, report["right_only_pass"])
        self.assertEqual(50.0, report["delta_percentage_points"])


if __name__ == "__main__":
    unittest.main()
