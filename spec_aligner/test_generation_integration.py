"""Deterministic checks for the command-line/batch generation integration."""

from __future__ import annotations

import os
import sys
import types
import unittest
from unittest.mock import patch

try:
    import google.generativeai  # noqa: F401
except ImportError:
    google = sys.modules.setdefault("google", types.ModuleType("google"))
    google.__path__ = getattr(google, "__path__", [])
    generativeai = types.ModuleType("google.generativeai")
    generativeai.configure = lambda **kwargs: None
    sys.modules["google.generativeai"] = generativeai

from nl2sysml import agent_rag_moe


def quality_report(final_sysml: str = "part def Repaired;") -> dict:
    return {
        "accepted": True,
        "final_sysml": final_sysml,
        "repairs": 1,
        "threshold": 0.85,
        "attempts": [{
            "attempt": 1,
            "validation_status": "skipped",
            "validation": None,
            "execution_status": "skipped",
            "execution": None,
            "alignment": {
                "summary": {
                    "similarity": 0.95,
                    "domain_mismatch": False,
                    "reliability_flag": False,
                },
                "mismatches": [],
            },
            "accepted": True,
        }],
    }


class BatchGenerationIntegrationTests(unittest.TestCase):
    def test_generation_returns_quality_gate_repair_and_report(self):
        report = quality_report()
        env = {
            "SPEC_ALIGNMENT_ENABLED": "true",
            "LAYER2_QUALITY_ENABLED": "false",
        }
        with patch.dict(os.environ, env), \
                patch.object(agent_rag_moe, "_load_env",
                             return_value=("gemini-key", "openrouter-key")), \
                patch.object(agent_rag_moe, "_rag_context", return_value=""), \
                patch.object(agent_rag_moe, "_invoke_with_retry",
                             return_value="part def Initial;"), \
                patch.object(agent_rag_moe, "is_compiler_available",
                             return_value=False), \
                patch.object(agent_rag_moe, "_run_post_generation_quality",
                             return_value=report) as gate:
            final, record = agent_rag_moe.generate_sysml_moe("A repaired system.")

        self.assertEqual(final, "part def Repaired;")
        self.assertEqual(record["quality_report"], report)
        self.assertTrue(record["spec_alignment_enabled"])
        gate.assert_called_once_with(
            "A repaired system.", "part def Initial;", "openrouter-key"
        )

    def test_generation_can_explicitly_disable_alignment(self):
        with patch.dict(os.environ, {"SPEC_ALIGNMENT_ENABLED": "false"}), \
                patch.object(agent_rag_moe, "_load_env",
                             return_value=("gemini-key", "openrouter-key")), \
                patch.object(agent_rag_moe, "_rag_context", return_value=""), \
                patch.object(agent_rag_moe, "_invoke_with_retry",
                             return_value="part def Initial;"), \
                patch.object(agent_rag_moe, "is_compiler_available",
                             return_value=False), \
                patch.object(agent_rag_moe, "_run_post_generation_quality") as gate:
            final, record = agent_rag_moe.generate_sysml_moe("A baseline system.")

        self.assertEqual(final, "part def Initial;")
        self.assertFalse(record["spec_alignment_enabled"])
        self.assertNotIn("quality_report", record)
        gate.assert_not_called()


if __name__ == "__main__":
    unittest.main()
