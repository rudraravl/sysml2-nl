from __future__ import annotations

import unittest

from nl2robotics.alignment.guarded import guarded_semantic_repair


def candidate(*, source="bad", blocking=1, execution=True,
              modelica=True, openusd=True):
    return {
        "modelica": "model Good end Good;",
        "openusd": source,
        "modelica_passed": modelica,
        "openusd_passed": openusd,
        "hybrid": {
            "fmu": {"success": modelica},
            "contract": {"success": blocking == 0},
            "execution": {"success": execution},
            "properties": [{"passed": execution}],
        },
        "alignment": {
            "passed": blocking == 0,
            "summary": {
                "blocking_violations": blocking,
                "weighted_semantic_score": 1.0 if blocking == 0 else 0.8,
                "evidence_coverage": 1.0,
            },
            "repair_plan": {"actions": ([{
                "owner": "openusd",
                "violations": [{
                    "qid": "Q1", "text": "axis", "expected": {"axis": "Y"},
                    "diagnostic": "found Z",
                }],
            }] if blocking else [])},
        },
    }


class GuardedRepairTests(unittest.TestCase):
    def test_accepts_only_fully_reevaluated_improvement(self):
        baseline = candidate()
        result = guarded_semantic_repair(
            baseline,
            lambda prompt: "#usda 1.0\ndef Xform \"World\" {}",
            lambda modelica, openusd, attempt: candidate(source=openusd, blocking=0),
        )
        self.assertEqual(1, result["repairs_accepted"])
        self.assertTrue(result["final"]["alignment"]["passed"])

    def test_rejects_semantic_fix_that_breaks_execution(self):
        baseline = candidate()
        result = guarded_semantic_repair(
            baseline,
            lambda prompt: "#usda 1.0\ndef Xform \"World\" {}",
            lambda modelica, openusd, attempt: candidate(
                source=openusd, blocking=0, execution=False
            ),
        )
        self.assertEqual(0, result["repairs_accepted"])
        self.assertIs(result["final"], baseline)

    def test_cross_profile_action_is_never_automatically_repaired(self):
        baseline = candidate()
        baseline["alignment"]["repair_plan"]["actions"][0]["owner"] = "cross_profile"
        result = guarded_semantic_repair(
            baseline,
            lambda prompt: self.fail("repair must not be called"),
            lambda *args: self.fail("evaluation must not be called"),
        )
        self.assertEqual(0, result["repairs_attempted"])


if __name__ == "__main__":
    unittest.main()
