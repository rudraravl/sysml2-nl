"""Offline tests for the Modelica best-of-N condition. No model, no OpenModelica, no Docker.

    python3 -m unittest nl2robotics.experiments.test_best_of_n
"""

from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch

from nl2robotics.experiments import best_of_n as bon
from nl2robotics.experiments.best_of_n import (
    BestOfNExecutor,
    best_of_n_condition,
    is_best_of_n,
    rank_key,
    select_best,
)
from nl2robotics.experiments.conditions import CONDITIONS
from nl2robotics.experiments.executor import (
    PipelineExperimentExecutor,
    _study_validity,
    generation_strategy,
)
from nl2robotics.experiments.metrics import extract_metrics
from nl2robotics.experiments.run_cli import _load_suite
from nl2robotics.experiments.runner import AblationRunner
from nl2robotics.modelica.models import (
    Diagnostic,
    Layer1CandidateResult,
    ModelicaBuild,
    ModelicaFMU,
)

MANIFEST = Path("nl2robotics/corpus/pipeline_prompt_manifest.json")


def build(*, compiled=True, checked=True, errors=0, available=True, infra=False):
    diagnostics = [Diagnostic("compiler", "error", f"e{i}") for i in range(errors)]
    if infra:
        diagnostics = [Diagnostic("infrastructure", "error", "docker unavailable")]
    return ModelicaBuild(
        available=available, model_name="M", checked=checked, compiled=compiled,
        executable=Path("/x/candidate_build") if compiled and checked else None,
        diagnostics=diagnostics,
    )


class FakeCorpus:
    subset = "full1500"


class FakePipeline:
    """Scores a sample by the marker in its code: `err=<n>` errors, `ok` compiles cleanly."""

    corpus = FakeCorpus()

    def __init__(self):
        self.compiled_dirs = []
        self._lock = threading.Lock()
        self.runner = self
        self.fmi_runner = self

    @staticmethod
    def build_baseline_messages(requirement):
        return "SYSTEM", f"REQ: {requirement}"

    def compile(self, code, *, output_dir=None):
        with self._lock:
            self.compiled_dirs.append(output_dir)
        if "infra" in code:
            return Layer1CandidateResult(code, build(compiled=False, checked=False,
                                                     available=False, infra=True))
        if "ok" in code:
            return Layer1CandidateResult(code, build())
        errors = int(code.split("err=")[1].split()[0])
        return Layer1CandidateResult(code, build(compiled=False, checked=False, errors=errors))

    def export_fmu(self, code, *, output_dir=None):
        return ModelicaFMU(available=True, model_name="M", checked=True, exported=False,
                           diagnostics=[Diagnostic("export", "error", "no fmu")])


def make_executor(replies, n=None, ask_log=None):
    """`replies` is consumed in call order; an Exception instance is raised instead of returned.
    `n` defaults to one sample per scripted reply."""
    queue = list(replies)
    n = len(queue) if n is None else n
    lock = threading.Lock()

    def ask(prompt):
        with lock:
            reply = queue.pop(0)
            if ask_log is not None:
                ask_log.append(prompt)
        if isinstance(reply, Exception):
            raise reply
        return reply

    return BestOfNExecutor(
        n=n, text_ask=lambda _: (_ for _ in ()).throw(AssertionError("support model used")),
        json_ask=lambda _: (_ for _ in ()).throw(AssertionError("normalizer used")),
        baseline_ask=ask, baseline_model="z-ai/glm-5.2",
        modelica_pipeline=FakePipeline(), portable_pipeline=object(),
    )


def model(marker):
    return f"model M // {marker}\nequation\nend M;"


class ConditionTests(unittest.TestCase):
    def test_condition_is_b0_with_a_different_name(self):
        b0, bn = CONDITIONS["B0"].to_dict(), best_of_n_condition(6).to_dict()
        self.assertEqual("BoN6", bn["id"])
        self.assertEqual("best_of_6", bn["label"])
        for control in ("rag", "moe", "tool_repair", "alignment", "validated_contract"):
            self.assertEqual(b0[control], bn[control], control)
        self.assertNotEqual("B0", bn["id"])          # letter o, not zero: never collides with B0
        self.assertEqual("direct", generation_strategy(best_of_n_condition(6)))

    def test_only_best_of_n_conditions_match(self):
        self.assertTrue(is_best_of_n(best_of_n_condition(4)))
        for cid in CONDITIONS:
            self.assertFalse(is_best_of_n(CONDITIONS[cid]), cid)

    def test_importing_the_module_does_not_touch_the_frozen_conditions(self):
        self.assertEqual(["B0", "B1", "B2", "B3", "FULL"], list(CONDITIONS))

    def test_invalid_n(self):
        with self.assertRaises(ValueError):
            best_of_n_condition(0)
        with self.assertRaises(ValueError):
            make_executor([], n=0)


class SelectionTests(unittest.TestCase):
    @staticmethod
    def row(index, quality):
        return {"index": index, "quality": quality}

    def test_compiled_beats_fewer_errors(self):
        rows = [self.row(0, [0, 1, -1]), self.row(1, [1, 1, 0])]
        self.assertEqual(1, select_best(rows)["index"])

    def test_checked_beats_unchecked_then_fewest_errors(self):
        rows = [self.row(0, [0, 0, -1]), self.row(1, [0, 1, -9]), self.row(2, [0, 1, -3])]
        self.assertEqual(2, select_best(rows)["index"])

    def test_ties_go_to_lowest_index(self):
        rows = [self.row(4, [1, 1, 0]), self.row(2, [1, 1, 0]), self.row(3, [1, 1, 0])]
        self.assertEqual(2, select_best(rows)["index"])

    def test_extraction_failure_ranks_last(self):
        rows = [self.row(0, None), self.row(1, [0, 0, -50])]
        self.assertEqual(1, select_best(rows)["index"])

    def test_rank_key_is_the_layer1_quality_ordering(self):
        # FORGE's own compile-repair loop keeps the attempt with the larger quality tuple.
        qualities = [(0, 0, -3), (0, 1, -2), (1, 1, 0), (0, 1, -1), (0, 0, 0)]
        rows = [self.row(i, list(q)) for i, q in enumerate(qualities)]
        by_quality = max(range(len(qualities)), key=lambda i: (qualities[i], -i))
        self.assertEqual(by_quality, select_best(rows)["index"])
        self.assertEqual(sorted(rows, key=rank_key)[0]["index"], select_best(rows)["index"])


class SamplerTests(unittest.TestCase):
    def sample(self, replies, **kwargs):
        executor = make_executor(replies, **kwargs)
        with tempfile.TemporaryDirectory() as tmp:
            code, report = executor._generate_modelica(
                "spin the wheel", best_of_n_condition(len(replies)), Path(tmp))
        return executor, code, report

    def test_n_samples_use_the_b0_prompt_and_transport(self):
        log = []
        executor = make_executor([model(f"err={e}") for e in (3, 1, 4, 1, 5, 9)], ask_log=log)
        with tempfile.TemporaryDirectory() as tmp:
            executor._generate_modelica("spin the wheel", best_of_n_condition(6), Path(tmp))
        system, human = FakePipeline.build_baseline_messages("spin the wheel")
        self.assertEqual(6, len(log))
        self.assertEqual({f"{system}\n\n{human}"}, set(log))     # exactly B0's request, N times

    def test_selects_by_compiler_and_records_every_candidate(self):
        _, code, report = self.sample([model(f"err={e}") for e in (3, 1, 4, 1, 5, 9)])
        block = report["best_of_n"]
        self.assertEqual(1, block["selected_index"])              # first of the two 1-error samples
        self.assertIn("err=1", code)
        self.assertEqual(6, len(block["candidates"]))
        self.assertEqual(list(range(6)), [c["index"] for c in block["candidates"]])
        self.assertEqual(0, block["n_compiling"])
        self.assertFalse(block["any_compiling"])
        self.assertFalse(report["passed"])

    def test_a_compiling_sample_wins_wherever_it_lands(self):
        replies = [model("err=1")] * 5 + [model("ok")]
        _, code, report = self.sample(replies)
        self.assertTrue(report["passed"])
        self.assertEqual(5, report["best_of_n"]["selected_index"])
        self.assertEqual(1, report["best_of_n"]["n_compiling"])
        self.assertTrue(report["best_of_n"]["any_compiling"])
        self.assertIn("ok", code)

    def test_attempt_zero_is_sample_zero_and_no_repair_happens(self):
        _, _, report = self.sample([model("ok"), model("err=2"), model("err=2")])
        self.assertEqual(0, report["attempts"][0]["attempt"])
        self.assertTrue(report["attempts"][0]["passed"])
        self.assertEqual(0, report["repairs"])
        self.assertEqual([True, False, False],
                         [a["accepted_as_best"] for a in report["attempts"]])

    def test_report_shape_matches_what_the_b0_path_and_fidelity_audit_expect(self):
        _, _, report = self.sample([model("ok")] * 2)
        self.assertEqual("direct", report["generation_mode"])
        self.assertEqual("z-ai/glm-5.2", report["generation_model"])
        self.assertEqual([], report["retrieved_examples"])
        controls = report["study_controls"]
        self.assertEqual((False, False, False, 0),
                         (controls["rag_enabled"], controls["moe_enabled"],
                          controls["tool_repair_enabled"], controls["retrieval_k"]))
        validity = _study_validity(
            {"stage": "modelica_experiment", "generation": report,
             "artifact_mode": "modelica_only", "modelica": {"passed": True}},
            best_of_n_condition(2), True)
        self.assertTrue(validity["eligible"], validity["issues"])
        self.assertTrue(validity["condition_fidelity_passed"])

    def test_every_sample_compiles_in_its_own_directory(self):
        executor, _, _ = self.sample([model("ok")] * 6)
        dirs = [str(d) for d in executor.modelica.compiled_dirs]
        self.assertEqual(6, len(set(dirs)))
        self.assertEqual([f"attempt-{i}" for i in range(6)], sorted(Path(d).name for d in dirs))

    def test_a_sample_without_code_is_a_failed_candidate(self):
        # clean_code() raises ValueError on an empty reply.
        _, code, report = self.sample([" ", model("err=7"), model("err=2")])
        block = report["best_of_n"]
        self.assertEqual(1, block["n_extraction_failures"])
        self.assertIsNone(block["candidates"][0]["quality"])
        self.assertEqual(2, block["selected_index"])
        first = report["attempts"][0]
        self.assertEqual("", first["modelica"])
        self.assertFalse(first["passed"])
        self.assertEqual(1, first["build"]["error_count"])       # build-shaped, not None

    def test_no_code_in_any_sample_fails_like_b0(self):
        executor = make_executor(["", " ", "  "])
        with tempfile.TemporaryDirectory() as tmp, self.assertRaisesRegex(
                ValueError, "no Modelica code in any of 3 samples"):
            executor._generate_modelica("x", best_of_n_condition(3), Path(tmp))

    def test_transport_failure_on_any_sample_aborts_the_cell(self):
        # A partial ensemble is never compared as complete; the runner turns this into an
        # infrastructure exclusion and an identical rerun.
        replies = [model("ok")] * 5 + [RuntimeError("OpenRouter call failed (z-ai/glm-5.2): 500")]
        executor = make_executor(replies)
        with tempfile.TemporaryDirectory() as tmp, self.assertRaisesRegex(
                RuntimeError, "OpenRouter call failed"):
            executor._generate_modelica("x", best_of_n_condition(6), Path(tmp))

    def test_infrastructure_diagnostic_makes_the_cell_ineligible(self):
        _, _, report = self.sample([model("ok"), model("infra")])
        block = report["best_of_n"]
        self.assertEqual(1, len(block["infrastructure_diagnostics"]))
        self.assertEqual(1, block["infrastructure_diagnostics"][0]["sample"])
        validity = _study_validity(
            {"stage": "modelica_experiment", "generation": report,
             "artifact_mode": "modelica_only", "best_of_n": block},
            best_of_n_condition(2), True)
        self.assertFalse(validity["eligible"])
        self.assertTrue(any("native infrastructure failure" in i for i in validity["issues"]))

    def test_non_bon_conditions_are_delegated_untouched(self):
        executor = make_executor([], n=1)
        with patch.object(PipelineExperimentExecutor, "_generate_modelica",
                          return_value=("m", {})) as parent, \
                patch.object(PipelineExperimentExecutor, "_run_hybrid",
                             return_value={"x": 1}) as parent_run:
            executor._generate_modelica("r", CONDITIONS["B0"], Path("."))
            executor._run_hybrid(object(), CONDITIONS["FULL"], "p", Path("."))
        parent.assert_called_once()
        parent_run.assert_called_once()


class RunTests(unittest.TestCase):
    def task(self):
        return _load_suite(MANIFEST).select(profile="capability", variant="rich")[0]

    def test_no_block_context_and_no_normalizer(self):
        task, _ = self.task()
        self.assertFalse(BestOfNExecutor.requires_block_context(task, best_of_n_condition(6)))
        self.assertFalse(BestOfNExecutor.requires_block_context(task, CONDITIONS["B0"]))
        self.assertTrue(BestOfNExecutor.requires_block_context(task, CONDITIONS["FULL"]))

    def test_run_uses_the_b0_baseline_path_once_over_the_selected_sample(self):
        task, prompt = self.task()
        executor = make_executor([model("err=3"), model("ok"), model("err=1")], n=3)
        with tempfile.TemporaryDirectory() as tmp, patch(
                "nl2robotics.experiments.best_of_n.ModelicaCapabilityOrchestrator") as orch:
            def run_baseline(source, *, output_dir, task_id, clock):
                code, _ = orch.call_args.kwargs["modelica_generator"](source, Path(tmp) / "g")
                return {"artifact_mode": "modelica_only", "passed": True, "selected": code}
            orch.return_value.run_compiler_execution_baseline.side_effect = run_baseline
            result = executor._run_hybrid(task, best_of_n_condition(3), prompt, Path(tmp))

        orch.return_value.run.assert_not_called()
        orch.return_value.run_compiler_execution_baseline.assert_called_once()
        call = orch.return_value.run_compiler_execution_baseline.call_args
        self.assertEqual(task.id, call.kwargs["task_id"])
        self.assertEqual("frozen_manifest_design_axes", call.kwargs["clock"]["source"])
        self.assertIn("ok", result["selected"])
        self.assertEqual(1, result["best_of_n"]["selected_index"])

    def test_only_the_capability_profile_is_supported(self):
        task, prompt = self.task()
        legacy = type("T", (), {"profile": "modelica", "id": "X", "oracle": {}})()
        with self.assertRaises(NotImplementedError):
            make_executor([], n=1)._run_hybrid(
                legacy, best_of_n_condition(1), prompt, Path("."))

    def test_full_cell_through_runner_orchestrator_and_metrics(self):
        """Real AblationRunner + real ModelicaCapabilityOrchestrator; only the compiler is fake."""
        task, prompt = self.task()
        condition = best_of_n_condition(4)
        executor = make_executor([model("err=5"), model("ok"), model("err=2"), model("ok")], n=4)
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            runner = AblationRunner(out, configuration={"study": "bon-test"})
            (record,) = runner.run([(task, prompt)], [condition], executor, variant="rich")

            self.assertIsNone(record["infrastructure_error"])
            self.assertEqual("BoN4", record["condition"]["id"])
            result = record["result"]
            self.assertTrue(result["study_validity"]["eligible"], result["study_validity"]["issues"])
            self.assertTrue(result["study_validity"]["condition_fidelity_passed"])
            self.assertNotIn("normalization_valid", {k for k, v in record["metrics"].items() if v})

            # the on-disk cell is what analyze_naive_vs_full.py will read
            path = out / task.id / "rich" / "BoN4" / "repeat-00" / "run.json"
            on_disk = json.loads(path.read_text())
            self.assertEqual("BoN4", on_disk["condition"]["id"])
            block = on_disk["result"]["best_of_n"]
            self.assertEqual((4, 1), (block["n"], block["selected_index"]))
            self.assertEqual(2, block["n_compiling"])
            generation = json.loads((path.parent / "artifacts" / "modelica" / "generation.json").read_text())
            self.assertEqual(4, len(generation["attempts"]))
            model_mo = (path.parent / "artifacts" / "modelica" / "model.mo").read_text()
            self.assertEqual(generation["final_modelica"], model_mo)

            # metrics: the compile stage passed (selected sample 1); export then failed in the fake
            m = record["metrics"]
            self.assertIs(True, m["modelica_build"])
            self.assertIs(True, m["modelica_build_attempt_0"] is False)     # sample 0 did not compile
            self.assertEqual("fmu_export", m["failure_stage"])
            self.assertEqual(0, m["repairs"])
            self.assertEqual(m, extract_metrics("capability", result))

            # a rerun resumes from the record instead of sampling again
            executor.baseline_ask = lambda _: self.fail("resumed cell re-sampled")
            (again,) = runner.run([(task, prompt)], [condition], executor, variant="rich")
            self.assertEqual(record["fingerprint"], again["fingerprint"])


class WrapperTests(unittest.TestCase):
    def test_wrapper_registers_the_condition_and_swaps_the_executor(self):
        from nl2robotics.experiments import run_best_of_n as wrapper
        seen = {}

        def fake_main():
            seen["argv"] = list(sys.argv)
            seen["condition"] = dict(CONDITIONS)
            seen["executor"] = wrapper.run_cli.PipelineExperimentExecutor

        real_exec = wrapper.run_cli.PipelineExperimentExecutor
        saved = dict(CONDITIONS)
        try:
            with patch.object(wrapper.run_cli, "main", fake_main), \
                    patch.object(sys, "argv", ["prog"]):
                wrapper.main(["--n", "4", "--output-dir", "o", "--compile-parallelism", "2"])
            self.assertIn("BoN4", seen["condition"])
            self.assertEqual("--condition", seen["argv"][-2])
            self.assertEqual("BoN4", seen["argv"][-1])
            self.assertIn("--profile", seen["argv"])            # defaults to capability
            self.assertNotIn("--n", seen["argv"])               # wrapper-only options are consumed
            executor = seen["executor"]
            self.assertEqual((4, 2), (executor.keywords["n"], executor.keywords["compile_parallelism"]))
            self.assertIs(BestOfNExecutor, executor.func)
        finally:
            wrapper.run_cli.PipelineExperimentExecutor = real_exec
            CONDITIONS.clear()
            CONDITIONS.update(saved)

    def test_wrapper_rejects_a_user_supplied_condition(self):
        from nl2robotics.experiments import run_best_of_n as wrapper
        with self.assertRaises(SystemExit):
            wrapper.main(["--condition", "B0", "--output-dir", "o"])


if __name__ == "__main__":
    unittest.main()
