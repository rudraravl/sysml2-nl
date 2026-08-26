from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

from nl2robotics.benchmark.suite import BenchmarkSuite


class BenchmarkTests(unittest.TestCase):
    def test_frozen_development_set_is_balanced_and_leakage_safe(self):
        result = BenchmarkSuite().audit()
        self.assertTrue(result["success"], result)
        self.assertEqual(15, result["task_count"])
        self.assertEqual(
            {"modelica": 5, "openusd": 5, "hybrid": 5},
            result["profile_counts"],
        )
        self.assertEqual(45, result["variant_count"])

    def test_prompt_variants_are_selectable(self):
        suite = BenchmarkSuite()
        self.assertEqual(5, len(suite.select(profile="hybrid", variant="concise")))
        self.assertNotEqual(
            suite.select(profile="hybrid", variant="rich")[0][1],
            suite.select(profile="hybrid", variant="underspecified")[0][1],
        )

    def test_custom_hybrid_study_manifest_does_not_require_profile_balance(self):
        source = BenchmarkSuite().tasks[-1]
        row = {
            "id": "CUSTOM-H2", "profile": "hybrid",
            "category": source.category, "difficulty": source.difficulty,
            "target_level": source.target_level,
            "oracle": source.oracle,
            "prompt_variants": source.prompt_variants,
            "labeled_unknowns": list(source.labeled_unknowns),
        }
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "study.json"
            bundle = Path(__file__).resolve().parents[1] / "hybrid" / "oracles" / "RHY101"
            row["oracle"] = {"bundle": str(bundle)}
            path.write_text(json.dumps([row]), encoding="utf-8")
            audit = BenchmarkSuite(manifest_path=path).audit()
        self.assertTrue(audit["success"], audit)
        self.assertEqual({"modelica": 0, "openusd": 0, "hybrid": 1},
                         audit["profile_counts"])


if __name__ == "__main__":
    unittest.main()
