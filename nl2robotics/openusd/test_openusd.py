from __future__ import annotations

from pathlib import Path
import json
import tempfile
import unittest
from unittest.mock import patch

from nl2robotics.openusd.corpus import OpenUSDExampleCorpus
from nl2robotics.openusd.audit_corpus import audit
from nl2robotics.openusd import moe
from nl2robotics.openusd.pipeline import OpenUSDPipeline, clean_usda
from nl2robotics.openusd.validator import OpenUSDValidation, OpenUSDValidator


class OpenUSDCorpusTests(unittest.TestCase):
    def test_full300_is_balanced_and_lineage_aware(self):
        corpus = OpenUSDExampleCorpus()
        self.assertEqual(300, len(corpus.examples))
        self.assertEqual(300, len({item.id for item in corpus.examples}))
        self.assertEqual(100, len({item.semantic_case_id for item in corpus.examples}))
        categories = {}
        for item in corpus.examples:
            categories[item.category] = categories.get(item.category, 0) + 1
            self.assertTrue(item.model_path.is_file())
            self.assertTrue(item.code.startswith("#usda 1.0"))
        self.assertEqual(10, len(categories))
        self.assertEqual({30}, set(categories.values()))
        self.assertTrue(audit()["ok"], audit()["errors"])

    def test_named_subsets(self):
        self.assertEqual(20, len(OpenUSDExampleCorpus(subset="core20").examples))
        self.assertEqual(100, len(OpenUSDExampleCorpus(subset="semantic100").examples))

    def test_retrieval_finds_prismatic_lift(self):
        hits = OpenUSDExampleCorpus().retrieve(
            "A prismatic vertical lift with a linear drive", k=3
        )
        self.assertEqual("O002", hits[0][0].id)
        self.assertEqual(
            len(hits), len({item.semantic_case_id for item, _ in hits})
        )


class OpenUSDValidatorTests(unittest.TestCase):
    @patch("nl2robotics.openusd.validator.shutil.which", return_value="/usr/bin/tool")
    @patch("nl2robotics.openusd.validator.subprocess.run")
    def test_available_accepts_fully_qualified_local_image(
        self, run, _which
    ):
        run.side_effect = [
            type("Result", (), {"returncode": 1})(),
            type("Result", (), {"returncode": 0})(),
        ]

        self.assertTrue(OpenUSDValidator().available())
        self.assertEqual(
            "docker.io/library/nl2robotics-openusd-runtime:0.1",
            run.call_args_list[1].args[0][-1],
        )

    def test_missing_stage_is_structured_failure(self):
        result = OpenUSDValidator().validate(Path("missing.usda"))
        self.assertFalse(result.success)
        self.assertEqual("missing_stage", result.issues[0].code)

    def test_missing_checker_is_infrastructure_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            stage = Path(tmp) / "stage.usda"
            stage.write_text("#usda 1.0\n", encoding="utf-8")
            result = OpenUSDValidator(checker="missing-usdchecker").validate(stage)
        self.assertFalse(result.available)
        self.assertEqual("validator_unavailable", result.issues[0].code)

    @patch.object(OpenUSDValidator, "available", return_value=True)
    @patch("nl2robotics.openusd.validator.subprocess.run")
    def test_checker_crash_uses_pinned_parser_without_hiding_failure(
        self, run, _available
    ):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            stage = root / "stage.usda"
            work = root / "validation"
            work.mkdir()
            stage.write_text("#usda 1.0\n", encoding="utf-8")
            calls = {"count": 0}

            def execute(*args, **kwargs):
                calls["count"] += 1
                if calls["count"] == 1:
                    return type("Result", (), {"returncode": -9, "stdout": ""})()
                (work / "semantic.json").write_text(json.dumps({
                    "success": True,
                    "stage_opened": True,
                    "issues": [],
                }), encoding="utf-8")
                return type("Result", (), {"returncode": 0, "stdout": ""})()

            run.side_effect = execute
            result = OpenUSDValidator().validate(stage, output_dir=work)
        self.assertTrue(result.success)
        self.assertTrue(result.checker_fallback)
        self.assertEqual(-9, result.checker_returncode)
        self.assertIn("usdchecker_crashed", {item.code for item in result.issues})


class OpenUSDPipelineTests(unittest.TestCase):
    def test_clean_usda_removes_fence(self):
        self.assertEqual(
            '#usda 1.0\ndef Xform "World" {}',
            clean_usda('```usda\n#usda 1.0\ndef Xform "World" {}\n```'),
        )

    def test_guarded_repair_keeps_valid_candidate(self):
        pipeline = OpenUSDPipeline()
        calls = {"count": 0}

        def validate(path, output_dir=None):
            calls["count"] += 1
            return OpenUSDValidation(
                True, path, syntax_valid=True,
                semantic_valid=calls["count"] == 1,
            )

        pipeline.validator.validate = validate  # type: ignore[method-assign]
        report = pipeline.refine(
            "Create a robot.", '#usda 1.0\ndef Xform "World" {}',
            lambda _: '#usda 1.0\ndef Xform "Worse" {}', max_repairs=1,
        )
        self.assertTrue(report["passed"])
        self.assertEqual(0, report["repairs"])

    def test_unavailable_validator_stops_without_repair(self):
        pipeline = OpenUSDPipeline()
        pipeline.validator.validate = lambda path, output_dir=None: OpenUSDValidation(  # type: ignore[method-assign]
            False, path
        )
        repairs = []
        report = pipeline.refine(
            "Create a robot.", '#usda 1.0\ndef Xform "World" {}',
            lambda prompt: repairs.append(prompt) or "", max_repairs=2,
        )
        self.assertFalse(report["passed"])
        self.assertEqual([], repairs)


class OpenUSDMoETests(unittest.TestCase):
    def test_model_roster_matches_modelica_and_sysml(self):
        from nl2robotics.modelica import moe as modelica_moe

        self.assertEqual(modelica_moe.EXPERT_MODELS, moe.EXPERT_MODELS)
        self.assertEqual(modelica_moe.COMBINER_MODEL, moe.COMBINER_MODEL)
        self.assertEqual(modelica_moe.EXPERT_MODELS_RATING, moe.EXPERT_MODELS_RATING)


if __name__ == "__main__":
    unittest.main()
