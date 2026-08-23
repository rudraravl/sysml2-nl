from __future__ import annotations

import unittest

from nl2robotics.retrieval_eval import evaluate


class RetrievalEvaluationTests(unittest.TestCase):
    def test_frozen_queries_recall_expected_family_without_duplicate_cases(self):
        report = evaluate()
        self.assertTrue(report["success"], report)
        self.assertGreaterEqual(report["modelica"]["top1_accuracy"], 0.8)
        self.assertGreaterEqual(report["openusd"]["top1_accuracy"], 0.8)
        self.assertEqual(1.0, report["modelica"]["diverse_at_5"])
        self.assertEqual(1.0, report["openusd"]["diverse_at_5"])
        modelica = report["subset_ablation"]["modelica"]
        self.assertGreater(
            modelica["full100"]["top1_accuracy"],
            modelica["core24"]["top1_accuracy"],
        )
        self.assertEqual(
            report["openusd"]["recall_at_5"],
            report["subset_ablation"]["openusd"]["core20"]["recall_at_5"],
        )


if __name__ == "__main__":
    unittest.main()
