"""Tests for repair feedback and the post-generation quality gate."""

from __future__ import annotations

import unittest
from unittest.mock import patch

from nl2sysml.quality_gate import run_quality_gate
from spec_aligner.feedback import build_repair_prompt, needs_repair


def alignment(similarity, mismatch=True):
    mismatches = []
    if mismatch:
        mismatches.append({
            "severity": "high",
            "text": "Does the vehicle include a battery?",
            "outcome": "missing_in_model",
            "nl": {"answer": "yes", "evidence": "The vehicle shall include a battery."},
            "sysml": {"answer": "no", "evidence": "No battery part is declared."},
        })
    return {
        "summary": {
            "similarity": similarity,
            "domain_mismatch": False,
            "reliability_flag": False,
        },
        "mismatches": mismatches,
    }


class FeedbackTests(unittest.TestCase):
    def test_repair_prompt_is_grounded_in_two_sided_evidence(self):
        report = alignment(0.4)
        prompt = build_repair_prompt("vehicle requirement", "part def Vehicle;", report)
        self.assertIn("vehicle include a battery", prompt)
        self.assertIn("The vehicle shall include a battery", prompt)
        self.assertIn("No battery part is declared", prompt)
        self.assertTrue(needs_repair(report, 0.85))
        self.assertFalse(needs_repair(alignment(0.9, mismatch=False), 0.85))


class QualityGateTests(unittest.TestCase):
    def test_repair_reruns_validation_execution_and_alignment(self):
        calls = []
        reports = [alignment(0.4), alignment(0.95, mismatch=False)]

        def validate(code):
            calls.append(("validate", code))
            return {"ok": True, "available": True}

        def execute(code):
            calls.append(("execute", code))
            return {"success": True, "kernel_available": True}

        def compare(nl, code, ask, **kwargs):
            calls.append(("align", code, kwargs["profile"]))
            return reports.pop(0)

        with patch("nl2sysml.quality_gate.compare_pair", side_effect=compare):
            result = run_quality_gate(
                "vehicle requirement",
                "part def Vehicle;",
                lambda prompt: "{}",
                validate=validate,
                execute=execute,
                repair=lambda prompt: "part def Vehicle { part battery; }",
            )

        self.assertTrue(result["accepted"])
        self.assertEqual(result["repairs"], 1)
        self.assertIn("part battery", result["final_sysml"])
        self.assertEqual([call[0] for call in calls],
                         ["validate", "execute", "align",
                          "validate", "execute", "align"])

    def test_unavailable_layer2_does_not_trigger_a_pointless_repair(self):
        with patch("nl2sysml.quality_gate.compare_pair",
                   return_value=alignment(0.95, mismatch=False)):
            result = run_quality_gate(
                "vehicle requirement",
                "part def Vehicle;",
                lambda prompt: "{}",
                execute=lambda code: {"success": False, "kernel_available": False},
                repair=lambda prompt: "should not be called",
            )
        self.assertFalse(result["accepted"])
        self.assertEqual(result["repairs"], 0)
        self.assertEqual(result["attempts"][0]["execution_status"], "unavailable")


if __name__ == "__main__":
    unittest.main()
