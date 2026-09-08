from __future__ import annotations

import unittest

from nl2robotics.hybrid.capability_repair import (
    build_capability_runtime_repair_prompt,
    capability_runtime_infrastructure_error,
    guarded_capability_runtime_repair,
)
from spec_aligner.llm import CliUsageLimitError


def candidate(modelica: str, *, failure_stage: str | None,
              executed: bool = False) -> dict:
    return {
        "modelica": modelica,
        "modelica_passed": True,
        "identity_preserved": True,
        "pre_alignment_passed": True,
        "alignment": {"passed": True},
        "execution": {
            "failure_stage": failure_stage,
            "fmu": {"success": executed},
            "contract": {"success": executed},
            "execution": {"initialized": executed, "success": executed},
            "trace_gate": {"success": executed},
            "execution_completed": executed,
        },
    }


class CapabilityRuntimeRepairTests(unittest.TestCase):
    def test_accepts_only_revalidated_execution_progress(self):
        baseline = candidate(
            "model Broken end Broken;", failure_stage="fmu_export"
        )
        fixed = candidate(
            "model Fixed end Fixed;", failure_stage="behavior_evaluation",
            executed=True,
        )
        report = guarded_capability_runtime_repair(
            "Execute the model.", baseline,
            lambda _: fixed["modelica"],
            lambda modelica, attempt: fixed,
            max_repairs=2,
        )
        self.assertEqual(1, report["repairs_attempted"])
        self.assertEqual(1, report["repairs_accepted"])
        self.assertIs(fixed, report["final"])

    def test_unevaluable_property_is_not_a_repair_trigger(self):
        baseline = candidate(
            "model Valid end Valid;", failure_stage="behavior_evaluation",
            executed=True,
        )
        baseline["execution"]["properties"] = [{
            "status": "unevaluable", "passed": False,
        }]
        calls = []
        report = guarded_capability_runtime_repair(
            "Keep error under a limit.", baseline,
            lambda prompt: calls.append(prompt) or baseline["modelica"],
            lambda *_: self.fail("unevaluable properties must not be repaired"),
            max_repairs=2,
        )
        self.assertEqual([], calls)
        self.assertEqual(0, report["repairs_attempted"])

    def test_deterministic_behavior_violation_can_be_monotonically_repaired(self):
        baseline = candidate(
            "model Valid end Valid;", failure_stage="behavior_evaluation",
            executed=True,
        )
        baseline["execution"]["properties"] = [{
            "status": "violated", "passed": False,
        }]
        fixed = candidate(
            "model Valid end Valid; // fixed", failure_stage=None,
            executed=True,
        )
        fixed["execution"]["properties"] = [{
            "status": "satisfied", "passed": True,
        }]
        fixed["execution"]["behavior_passed"] = True
        report = guarded_capability_runtime_repair(
            "Keep error under a limit.", baseline,
            lambda _: fixed["modelica"], lambda *_: fixed,
        )
        self.assertEqual(1, report["repairs_accepted"])
        self.assertIs(fixed, report["final"])

    def test_rejects_candidate_that_does_not_advance_execution(self):
        baseline = candidate(
            "model Broken end Broken;", failure_stage="fmu_export"
        )
        unchanged_quality = candidate(
            "model Different end Different;", failure_stage="fmu_export"
        )
        report = guarded_capability_runtime_repair(
            "Execute the model.", baseline,
            lambda _: unchanged_quality["modelica"],
            lambda *_: unchanged_quality,
        )
        self.assertEqual(0, report["repairs_accepted"])
        self.assertIs(baseline, report["final"])

    def test_rejects_renamed_model_even_if_it_executes(self):
        baseline = candidate(
            "model RequiredName end RequiredName;", failure_stage="fmu_export"
        )
        renamed = candidate(
            "model Renamed end Renamed;", failure_stage=None, executed=True
        )
        renamed["identity_preserved"] = False
        report = guarded_capability_runtime_repair(
            "Execute the model.", baseline,
            lambda _: renamed["modelica"],
            lambda *_: renamed,
        )
        self.assertEqual(0, report["repairs_accepted"])
        self.assertIs(baseline, report["final"])

    def test_prompt_forbids_deleting_checks_or_grounded_values(self):
        prompt = build_capability_runtime_repair_prompt(
            "Mass is 10 kg.",
            "model Broken end Broken;",
            {"failure_stage": "fmu_execution"},
        )
        self.assertIn("Preserve\nevery grounded numeric requirement", prompt)
        self.assertIn("delete dynamics or checks", prompt)
        self.assertIn("Never replace a dynamic signal with", prompt)
        self.assertIn("fmu_execution", prompt)

    def test_provider_usage_limit_propagates_without_becoming_model_failure(self):
        baseline = candidate(
            "model Broken end Broken;", failure_stage="fmu_export"
        )

        def quota_stop(_prompt):
            raise CliUsageLimitError("5-hour limit reached")

        with self.assertRaises(CliUsageLimitError):
            guarded_capability_runtime_repair(
                "Execute the model.", baseline, quota_stop,
                lambda *_: self.fail("quota stop must not evaluate a candidate"),
            )

    def test_native_infrastructure_failure_does_not_trigger_repair(self):
        baseline = candidate(
            "model Valid end Valid;", failure_stage="fmu_export"
        )
        baseline["execution"]["fmu"]["diagnostics"] = [{
            "stage": "infrastructure", "severity": "error",
            "message": "Docker daemon unavailable",
        }]
        calls = []
        report = guarded_capability_runtime_repair(
            "Execute the model.", baseline,
            lambda prompt: calls.append(prompt) or baseline["modelica"],
            lambda *_: self.fail("infrastructure must not evaluate a candidate"),
        )
        self.assertEqual([], calls)
        self.assertEqual(0, report["repairs_attempted"])
        self.assertEqual(
            "Docker daemon unavailable", report["infrastructure_error"]
        )
        self.assertEqual(
            "Docker daemon unavailable",
            capability_runtime_infrastructure_error(baseline["execution"]),
        )


if __name__ == "__main__":
    unittest.main()
