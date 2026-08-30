from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

from .articulated import audit_articulated_suite
from .capability_matrix import audit_manifest as audit_capabilities
from .capability_benchmark import CapabilityBenchmarkSuite
from .paper_evaluation import (
    MANIFEST as PAPER_EVALUATION_MANIFEST,
    audit_manifest as audit_paper_evaluation,
)
from .run_capability_smoke import (
    case_fingerprint,
    load_cases,
    resumable,
    select_cases,
    summarize_result,
)


class ArticulatedStudyTests(unittest.TestCase):
    def test_study_covers_supported_articulated_breadth(self):
        report = audit_articulated_suite()
        self.assertTrue(report["success"], report)
        self.assertEqual([1, 3], report["coverage"]["joint_count_range"])
        self.assertEqual(["prismatic", "revolute"],
                         report["coverage"]["joint_types"])
        self.assertEqual(["X", "Y", "Z"], report["coverage"]["axes"])
        self.assertEqual(["box", "capsule", "cylinder", "sphere"],
                         report["coverage"]["link_shapes"])
        self.assertEqual(["branching", "serial", "single"],
                         report["coverage"]["topologies"])
        self.assertEqual(3,
                         report["coverage"]["max_simultaneously_controlled_joints"])


class CapabilityBreadthStudyTests(unittest.TestCase):
    def test_capability_manifest_adapts_to_rich_ablation_tasks(self):
        suite = CapabilityBenchmarkSuite()
        audit = suite.audit()
        self.assertTrue(audit["success"], audit)
        selected = suite.select(profile="capability", variant="rich")
        self.assertEqual(13, len(selected))
        self.assertEqual("capability_tier2", selected[0][0].target_level)
        self.assertEqual(3, len(selected[0][0].oracle["rag_route"]["modelica"]))
        with self.assertRaises(ValueError):
            suite.select(profile="capability", variant="concise")

    def test_study_covers_broad_profile_matrix_without_overclaiming(self):
        report = audit_capabilities()
        self.assertTrue(report["success"], report)
        self.assertEqual(13, report["case_count"])
        self.assertEqual(13, report["family_count"])
        self.assertEqual(1, report["target_tier_counts"]["5"])
        self.assertEqual(12, report["target_tier_counts"]["2"])
        self.assertEqual(13, report["rag"]["routed_family_count"])
        self.assertEqual(1500, report["rag"]["modelica_example_count"])
        self.assertEqual(1500, report["rag"]["openusd_example_count"])
        self.assertTrue(report["launch"]["success"], report["launch"])
        self.assertEqual(2, report["launch"]["phase_count"])

    def test_every_family_has_a_paper_grade_grounded_request(self):
        _, cases = load_cases()
        self.assertEqual(13, len(cases))
        for case in cases:
            with self.subTest(case=case["id"]):
                request = case["request"]
                self.assertGreaterEqual(len(request.split()), 100)
                self.assertIn("Hz", request)
                self.assertIn("Require", request)

    def test_case_selection_is_ordered_and_rejects_unknown_ids(self):
        _, cases = load_cases()
        selected = select_cases(cases, ["RCB013", "RCB001"])
        self.assertEqual(["RCB013", "RCB001"], [row["id"] for row in selected])
        with self.assertRaises(ValueError):
            select_cases(cases, ["RCB999"])

    def test_resume_requires_matching_fingerprint_and_passed_result(self):
        _, cases = load_cases()
        case = cases[0]
        fingerprint = case_fingerprint(case, {"model": "test"}, "abc")
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            (root / "case-record.json").write_text(json.dumps({
                "fingerprint": fingerprint,
                "completed": True,
            }), encoding="utf-8")
            (root / "result.json").write_text(json.dumps({
                "passed": True,
            }), encoding="utf-8")
            self.assertTrue(resumable(root, fingerprint))
            self.assertFalse(resumable(root, "different"))

    def test_smoke_summary_preserves_honest_claim_state(self):
        _, cases = load_cases()
        summary = summarize_result(cases[0], {
            "passed": True,
            "failure_stage": None,
            "capabilities": {
                "highest_reached_tier": 2,
                "requested_feature_count": 20,
                "profile_count": 2,
            },
            "modelica": {"passed": True, "repairs": 0},
            "openusd": {"passed": True, "repairs": 1},
            "normalization": {"attempt_count": 1},
            "claim_eligible_h2": False,
            "claim_eligible_deltaai_h2": False,
        })
        self.assertTrue(summary["passed"])
        self.assertEqual(2, summary["highest_reached_tier"])
        self.assertFalse(summary["claim_eligible_h2"])
        self.assertFalse(summary["claim_eligible_deltaai_h2"])


class PaperEvaluationBenchmarkTests(unittest.TestCase):
    def test_candidate_benchmark_is_balanced_grounded_and_held_out(self):
        report = audit_paper_evaluation()
        self.assertTrue(report["success"], report)
        self.assertEqual(65, report["case_count"])
        self.assertEqual(52, report["primary_case_count"])
        self.assertEqual(13, report["reserve_case_count"])
        self.assertEqual(13, len(report["family_counts"]))
        self.assertEqual({5}, set(report["family_counts"].values()))
        self.assertEqual(5, report["runtime_candidate_count"])

    def test_candidate_manifest_loads_in_the_experiment_harness(self):
        suite = CapabilityBenchmarkSuite(PAPER_EVALUATION_MANIFEST)
        audit = suite.audit()
        self.assertTrue(audit["success"], audit)
        selected = suite.select(profile="capability", variant="rich")
        self.assertEqual(65, len(selected))
        splits = [task.oracle["benchmark_split"] for task, _ in selected]
        self.assertEqual(52, splits.count("primary"))
        self.assertEqual(13, splits.count("reserve"))
        self.assertEqual(5, sum(task.oracle["runtime_candidate"]
                                for task, _ in selected))

    def test_retrieval_corpus_is_large_but_not_counted_as_evaluation(self):
        report = audit_paper_evaluation()
        corpus = report["retrieval_corpus"]
        self.assertEqual(1500, corpus["modelica_prompt_count"])
        self.assertEqual(500, corpus["modelica_semantic_case_count"])
        self.assertEqual(1500, corpus["openusd_prompt_count"])
        self.assertEqual(500, corpus["openusd_semantic_case_count"])
        for leakage in report["leakage"].values():
            self.assertEqual(0, leakage["exact_matches"])


if __name__ == "__main__":
    unittest.main()
