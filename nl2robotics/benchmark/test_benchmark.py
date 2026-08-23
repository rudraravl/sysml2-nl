from __future__ import annotations

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


if __name__ == "__main__":
    unittest.main()
