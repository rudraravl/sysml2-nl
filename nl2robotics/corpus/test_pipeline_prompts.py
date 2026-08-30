from __future__ import annotations

from collections import Counter
import unittest

from nl2robotics.studies.capability_benchmark import CapabilityBenchmarkSuite

from .pipeline_prompts import MANIFEST, audit_manifest, build_cases


class PipelinePromptCorpusTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cases = build_cases()
        cls.report = audit_manifest()

    def test_corpus_is_large_balanced_and_lineage_aware(self):
        self.assertTrue(self.report["success"], self.report)
        self.assertEqual(1560, self.report["prompt_count"])
        self.assertEqual(260, self.report["semantic_case_count"])
        self.assertEqual({120}, set(self.report["family_counts"].values()))
        self.assertEqual({20}, set(self.report["semantic_case_counts"].values()))
        self.assertEqual([6], self.report["configurations_per_lineage"])

    def test_difficulty_and_natural_language_styles_are_balanced(self):
        self.assertEqual(
            {"advanced": 520, "foundational": 520, "intermediate": 520},
            self.report["difficulty_counts"],
        )
        self.assertEqual(6, len(self.report["prompt_style_counts"]))
        self.assertEqual({260}, set(self.report["prompt_style_counts"].values()))
        self.assertGreaterEqual(min(len(case["request"].split())
                                    for case in self.cases), 100)

    def test_every_semantic_scenario_has_six_controlled_inputs(self):
        counts = Counter(case["semantic_case_id"] for case in self.cases)
        self.assertEqual(260, len(counts))
        self.assertEqual({6}, set(counts.values()))
        for leakage in self.report["leakage"].values():
            self.assertEqual(0, leakage["exact_match_count"])

    def test_experiment_harness_can_select_corpus_metadata(self):
        suite = CapabilityBenchmarkSuite(MANIFEST)
        selected = suite.select(profile="capability", variant="rich")
        self.assertEqual(1560, len(selected))
        task = selected[0][0]
        self.assertEqual("corpus", task.oracle["benchmark_split"])
        self.assertTrue(task.oracle["semantic_case_id"].startswith("RPS"))
        self.assertTrue(task.oracle["lineage_id"])
        self.assertTrue(task.oracle["configuration_variant"].startswith(
            "controlled_config_"
        ))


if __name__ == "__main__":
    unittest.main()
