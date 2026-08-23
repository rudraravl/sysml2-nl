from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from zipfile import ZipFile

from nl2robotics.modelica.audit_corpus import audit
from nl2robotics.modelica.corpus import ExampleCorpus
from nl2robotics.modelica import evaluate_layer1, moe
from nl2robotics.modelica.models import (
    Diagnostic,
    FMUExecution,
    Layer1CandidateResult,
    ModelicaBuild,
    ModelicaFMU,
)
from nl2robotics.modelica.fmu import FMUInspectionError, inspect_fmu
from nl2robotics.modelica.fmu_runtime import FMIContainerRunner
from nl2robotics.modelica.openmodelica import (
    OpenModelicaRunner,
    _build_script,
    _fmu_script,
)
from nl2robotics.modelica.pipeline import ModelicaPipeline, clean_code
from nl2robotics.modelica.properties import evaluate_properties, read_trace


class CorpusTests(unittest.TestCase):
    def test_manifest_is_balanced_and_files_exist(self):
        corpus = ExampleCorpus()
        self.assertEqual(300, len(corpus.examples))
        self.assertEqual(300, len({item.id for item in corpus.examples}))
        self.assertEqual(100, len({item.semantic_case_id for item in corpus.examples}))
        categories = {}
        for item in corpus.examples:
            categories[item.category] = categories.get(item.category, 0) + 1
            self.assertTrue(item.model_path.is_file())
            self.assertIn("model ", item.code)
        self.assertEqual(10, len(categories))
        self.assertTrue(all(count == 30 for count in categories.values()))

    def test_named_ablation_subsets(self):
        self.assertEqual(24, len(ExampleCorpus(subset="core24").examples))
        balanced = ExampleCorpus(subset="balanced50").examples
        self.assertEqual(50, len(balanced))
        counts = {}
        for item in balanced:
            counts[item.category] = counts.get(item.category, 0) + 1
        self.assertEqual({5}, set(counts.values()))
        self.assertEqual(100, len(ExampleCorpus(subset="full100").examples))

    def test_corpus_audit(self):
        report = audit()
        self.assertTrue(report["ok"], report["errors"])
        self.assertEqual([], report["exact_code_duplicates"])

    def test_retrieval_uses_domain_terms(self):
        hits = ExampleCorpus().retrieve(
            "A voltage driven DC motor with winding current and back EMF", k=3
        )
        self.assertEqual("M004", hits[0][0].id)
        self.assertTrue(all(item.split == "rag" for item, _ in hits))
        self.assertEqual(
            len(hits), len({item.semantic_case_id for item, _ in hits})
        )

    def test_evaluation_ids_are_not_retrievable(self):
        corpus = ExampleCorpus()
        task_file = corpus.root / "evaluation_tasks.json"
        task_ids = {row["id"] for row in json.loads(task_file.read_text())}
        self.assertTrue(task_ids.isdisjoint(item.id for item in corpus.examples))


class PropertyTests(unittest.TestCase):
    def test_csv_and_stl_fragment(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "trace.csv"
            path.write_text('"time","angle"\n0,0\n1,0.8\n2,1.0\n', encoding="utf-8")
            trace = read_trace(path)
        results = evaluate_properties(trace, [
            {"id": "p1", "kind": "eventually", "signal": "angle",
             "start": 0, "end": 2, "lower": 0.9},
            {"id": "p2", "kind": "always", "signal": "angle",
             "start": 1, "end": 2, "upper": 1.1},
            {"id": "p3", "kind": "final", "signal": "angle",
             "lower": 0.95, "upper": 1.05},
        ])
        self.assertTrue(all(item.passed for item in results))
        self.assertAlmostEqual(0.05, results[-1].robustness)

    def test_missing_signal_fails(self):
        result = evaluate_properties(
            {"time": [0.0], "angle": [0.0]},
            [{"id": "p", "kind": "final", "signal": "speed", "lower": 0}],
        )[0]
        self.assertFalse(result.passed)


class PipelineTests(unittest.TestCase):
    def test_clean_code_removes_fence(self):
        self.assertEqual("model A\nend A;", clean_code("```modelica\nmodel A\nend A;\n```"))

    def test_guarded_repair_keeps_better_candidate(self):
        pipeline = ModelicaPipeline()
        good = Layer1CandidateResult(
            "model Good end Good;",
            ModelicaBuild(
                True, "Good", checked=True,
                diagnostics=[Diagnostic("compiler", "error", "one error")],
            ),
        )
        worse = Layer1CandidateResult(
            "model Worse end Worse;",
            ModelicaBuild(
                True, "Worse",
                diagnostics=[
                    Diagnostic("compiler", "error", "error one"),
                    Diagnostic("compiler", "error", "error two"),
                ],
            ),
        )
        results = iter((good, worse))
        pipeline.compile = lambda *args, **kwargs: next(results)  # type: ignore[method-assign]
        answers = iter((good.code, worse.code))
        report = pipeline.generate("move", lambda _: next(answers), max_repairs=1)
        self.assertEqual(good.code, report["final_modelica"])
        self.assertFalse(report["attempts"][1]["accepted_as_best"])
        self.assertEqual("full300", report["corpus_subset"])
        self.assertEqual(5, len(report["retrieved_examples"]))

    def test_compile_only_script_never_runs_the_model(self):
        script = _build_script("Candidate")
        self.assertIn("checkModel(Candidate)", script)
        self.assertIn("buildModel(Candidate", script)
        self.assertNotIn("simulate(", script)

    def test_fmu_export_script_requests_fmi2_co_simulation(self):
        script = _fmu_script("Candidate")
        self.assertIn('buildModelFMU(Candidate, version="2.0", fmuType="cs"', script)
        self.assertIn('fileNamePrefix="candidate"', script)
        self.assertNotIn("simulate(", script)

    def test_malformed_output_becomes_repairable_diagnostic(self):
        result = OpenModelicaRunner(backend="local", omc="missing-omc").compile(
            "this is not Modelica"
        )
        self.assertFalse(result.success)
        self.assertEqual("source", result.diagnostics[0].stage)
        self.assertIn("top-level Modelica model", result.diagnostics[0].message)

    def test_unavailable_compiler_does_not_trigger_repairs(self):
        pipeline = ModelicaPipeline()
        unavailable = Layer1CandidateResult(
            "model Candidate end Candidate;",
            ModelicaBuild(
                False, "Candidate",
                diagnostics=[Diagnostic(
                    "infrastructure", "error", "OpenModelica is unavailable"
                )],
            ),
        )
        pipeline.compile = lambda *args, **kwargs: unavailable  # type: ignore[method-assign]
        calls = []

        def ask(prompt):
            calls.append(prompt)
            return unavailable.code

        report = pipeline.generate("Model a joint.", ask, max_repairs=2)
        self.assertEqual(1, len(calls))
        self.assertEqual(0, report["repairs"])
        self.assertFalse(report["passed"])

    def test_fmi_pipeline_stops_when_export_fails(self):
        pipeline = ModelicaPipeline()
        pipeline.runner.export_fmu = lambda *args, **kwargs: ModelicaFMU(  # type: ignore[method-assign]
            True, "Candidate",
            diagnostics=[Diagnostic("fmu_export", "error", "failed")],
        )
        pipeline.fmi_runner.run = lambda *args, **kwargs: self.fail(  # type: ignore[method-assign]
            "runtime should not be called"
        )
        report = pipeline.export_and_execute_fmu("model Candidate end Candidate;")
        self.assertFalse(report["passed"])
        self.assertIsNone(report["execution"])

    def test_fmi_pipeline_reports_successful_execution(self):
        pipeline = ModelicaPipeline()
        pipeline.runner.export_fmu = lambda *args, **kwargs: ModelicaFMU(  # type: ignore[method-assign]
            True, "Candidate", checked=True, exported=True,
            fmu_path=Path("candidate.fmu"), fmi_version="2.0",
            interface_type="co_simulation",
        )
        pipeline.fmi_runner.run = lambda *args, **kwargs: FMUExecution(  # type: ignore[method-assign]
            True, initialized=True, simulated=True, result_file=Path("trace.csv")
        )
        report = pipeline.export_and_execute_fmu(
            "model Candidate end Candidate;"
        )
        self.assertTrue(report["passed"])
        self.assertEqual("fmi_execution", report["stage"])


class FMUTests(unittest.TestCase):
    @patch("nl2robotics.modelica.fmu_runtime.shutil.which", return_value="/usr/bin/docker")
    @patch("nl2robotics.modelica.fmu_runtime.subprocess.run")
    def test_runtime_accepts_fully_qualified_local_image(self, run, _which):
        run.side_effect = [
            type("Result", (), {"returncode": 1})(),
            type("Result", (), {"returncode": 0})(),
        ]

        self.assertTrue(FMIContainerRunner().available())
        self.assertEqual(
            "docker.io/library/nl2robotics-fmi-runtime:0.1",
            run.call_args_list[1].args[0][-1],
        )

    def test_inspects_fmi2_co_simulation_metadata(self):
        xml = b'''<?xml version="1.0" encoding="UTF-8"?>
<fmiModelDescription fmiVersion="2.0" modelName="ArmController"
  guid="test-guid" generationTool="OpenModelica">
  <CoSimulation modelIdentifier="ArmController"/>
  <ModelVariables>
    <ScalarVariable name="angle" valueReference="1" causality="input"
      variability="continuous"><Real unit="rad" start="0"/></ScalarVariable>
    <ScalarVariable name="torque" valueReference="2" causality="output"
      variability="continuous" initial="calculated"><Real unit="N.m"/></ScalarVariable>
  </ModelVariables>
</fmiModelDescription>'''
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "controller.fmu"
            with ZipFile(path, "w") as archive:
                archive.writestr("modelDescription.xml", xml)
            result = inspect_fmu(path)
        self.assertEqual("2.0", result["fmi_version"])
        self.assertEqual("co_simulation", result["interface_type"])
        self.assertEqual("ArmController", result["model_identifier"])
        self.assertEqual("rad", result["variables"][0].unit)
        self.assertEqual("output", result["variables"][1].causality)

    def test_rejects_archive_without_model_description(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "broken.fmu"
            with ZipFile(path, "w") as archive:
                archive.writestr("readme.txt", "missing metadata")
            with self.assertRaisesRegex(FMUInspectionError, "modelDescription.xml"):
                inspect_fmu(path)

    def test_runtime_rejects_invalid_time_range(self):
        with self.assertRaisesRegex(ValueError, "invalid FMI"):
            FMIContainerRunner().run(
                Path("missing.fmu"), start_time=1.0, stop_time=0.0
            )

    def test_runtime_reports_missing_fmu_without_docker(self):
        result = FMIContainerRunner().run(Path("missing.fmu"))
        self.assertFalse(result.success)
        self.assertEqual("fmi_source", result.diagnostics[0].stage)


class MoETests(unittest.TestCase):
    def pipeline(self):
        pipeline = ModelicaPipeline(corpus=ExampleCorpus(subset="core24"))
        passed = Layer1CandidateResult(
            "model Combined end Combined;",
            ModelicaBuild(
                True, "Combined", checked=True, compiled=True,
                executable=Path("candidate_build"),
            ),
        )
        pipeline.compile = lambda *args, **kwargs: passed  # type: ignore[method-assign]
        return pipeline

    def test_same_models_ratings_and_combiner_as_sysml(self):
        self.assertEqual(tuple(moe.sysml_moe.EXPERT_MODELS), moe.EXPERT_MODELS)
        self.assertEqual(moe.sysml_moe.COMBINER_MODEL, moe.COMBINER_MODEL)
        self.assertEqual(moe.sysml_moe.EXPERT_MODELS_RATING,
                         moe.EXPERT_MODELS_RATING)

    def test_moe_calls_four_experts_then_combiner(self):
        calls = []

        def invoke(model, system, human, key):
            calls.append((model, human))
            return f"model Candidate{len(calls)} end Candidate{len(calls)};"

        with patch.object(moe.sysml_moe, "_llm_backend", return_value="cli"):
            final, report = moe.generate_modelica_moe(
                "Model a joint.", pipeline=self.pipeline(), invoke=invoke,
                openrouter_key="key", max_repairs=0,
            )
        self.assertEqual(
            [model for model, _ in calls],
            [*moe.EXPERT_MODELS, moe.COMBINER_MODEL],
        )
        self.assertEqual("model Combined end Combined;", final)
        self.assertEqual("moe", report["generation_mode"])
        self.assertEqual(list(moe.EXPERT_MODELS), report["expert_candidates"])
        self.assertEqual(0, report["expert_soft_fail_count"])
        combine_prompt = calls[-1][1]
        self.assertIn("rating=10/10", combine_prompt)
        self.assertIn("rating=7/10", combine_prompt)
        self.assertIn("rating=5/10", combine_prompt)

    def test_expert_soft_failure_does_not_skip_combiner(self):
        calls = []

        def invoke(model, system, human, key):
            calls.append(model)
            if model == moe.EXPERT_MODELS[1] and calls.count(model) == 1:
                raise RuntimeError("expert refused")
            return "model Candidate end Candidate;"

        with patch.object(moe.sysml_moe, "_llm_backend", return_value="api"):
            _, report = moe.generate_modelica_moe(
                "Model a motor.", pipeline=self.pipeline(), invoke=invoke,
                openrouter_key="key", max_repairs=0,
            )
        self.assertEqual(moe.COMBINER_MODEL, calls[-1])
        self.assertEqual(1, report["expert_soft_fail_count"])
        self.assertNotIn(moe.EXPERT_MODELS[1], report["expert_candidates"])

    def test_combiner_failure_is_hard(self):
        count = {"calls": 0}

        def invoke(model, system, human, key):
            count["calls"] += 1
            if count["calls"] == 5:
                raise RuntimeError("combiner unavailable")
            return "model Candidate end Candidate;"

        with patch.object(moe.sysml_moe, "_llm_backend", return_value="api"):
            with self.assertRaisesRegex(RuntimeError, "combiner unavailable"):
                moe.generate_modelica_moe(
                    "Model a motor.", pipeline=self.pipeline(), invoke=invoke,
                    openrouter_key="key", max_repairs=0,
                )


class EvaluationHarnessTests(unittest.TestCase):
    def test_baseline_is_rag_free_and_rag_condition_records_examples(self):
        pipeline = ModelicaPipeline(corpus=ExampleCorpus(subset="core24"))
        passed = Layer1CandidateResult(
            "model Generated end Generated;",
            ModelicaBuild(
                True, "Generated", checked=True, compiled=True,
                executable=Path("candidate_build"),
            ),
        )
        pipeline.compile = lambda *args, **kwargs: passed  # type: ignore[method-assign]
        with patch.object(
            evaluate_layer1.moe, "_invoke",
            return_value="model Generated end Generated;",
        ):
            baseline = evaluate_layer1._run_condition(
                "baseline", "Model a joint.", pipeline, Path("unused"),
                model="openai/gpt-5.4", openrouter_key=None,
                k=5, max_repairs=2,
            )
            rag = evaluate_layer1._run_condition(
                "rag", "Model a joint.", pipeline, Path("unused"),
                model="openai/gpt-5.4", openrouter_key=None,
                k=5, max_repairs=2,
            )
        self.assertEqual([], baseline["retrieved_examples"])
        self.assertEqual(5, len(rag["retrieved_examples"]))
        self.assertNotIn("Retrieved examples:", baseline["generation_prompt"])
        self.assertIn("Retrieved examples:", rag["generation_prompt"])


if __name__ == "__main__":
    unittest.main()
