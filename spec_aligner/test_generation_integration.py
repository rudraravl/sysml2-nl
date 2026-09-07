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
    def test_openrouter_retries_transient_read_timeout(self):
        payload = b'{"choices":[{"message":{"content":"model Ok end Ok;"}}]}'

        class Response:
            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

            def read(self):
                return payload

        with patch.object(
            agent_rag_moe._req, "urlopen",
            side_effect=[TimeoutError("The read operation timed out"), Response()],
        ) as urlopen, patch.object(agent_rag_moe.time, "sleep") as sleep:
            result = agent_rag_moe._openrouter_invoke(
                "z-ai/glm-5.2", "system", "human", "test-key"
            )
        self.assertEqual("model Ok end Ok;", result)
        self.assertEqual(2, urlopen.call_count)
        sleep.assert_called_once_with(5)

    def test_openrouter_does_not_retry_permanent_failure(self):
        error = agent_rag_moe._urlerror.HTTPError(
            "https://openrouter.ai", 401, "Unauthorized", {}, None
        )
        with patch.object(
            agent_rag_moe._req, "urlopen", side_effect=error
        ) as urlopen, patch.object(agent_rag_moe.time, "sleep") as sleep:
            with self.assertRaisesRegex(RuntimeError, "OpenRouter call failed"):
                agent_rag_moe._openrouter_invoke(
                    "z-ai/glm-5.2", "system", "human", "test-key"
                )
        self.assertEqual(1, urlopen.call_count)
        sleep.assert_not_called()

    def test_generation_returns_quality_gate_repair_and_report(self):
        report = quality_report()
        env = {
            "SPEC_ALIGNMENT_ENABLED": "true",
            "KERNEL_FEEDBACK_ENABLED": "false",
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
        self.assertFalse(record["kernel_feedback_enabled"])
        gate.assert_called_once_with(
            "A repaired system.", "part def Initial;", "openrouter-key"
        )

    def test_generation_can_explicitly_disable_alignment(self):
        with patch.dict(os.environ, {
                "SPEC_ALIGNMENT_ENABLED": "false",
                "KERNEL_FEEDBACK_ENABLED": "false",
            }), \
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

    def test_cli_backend_keeps_open_source_experts_on_openrouter(self):
        cli_calls = []
        openrouter_calls = []
        gemini_calls = []

        def fake_cli(model, system_msg, human_msg, *, mode="sysml"):
            cli_calls.append(model)
            return f"part def FromCLI_{model.split('/')[-1].replace('.', '_')};"

        def fake_openrouter(model, system_msg, human_msg, key):
            openrouter_calls.append(model)
            return "part def FromOpenRouter_llama;"

        def fake_gemini(system_msg, human_msg):
            gemini_calls.append("gemini")
            return "part def FromGeminiAPI;"

        expected_experts = [
            "qwen/qwen3.6-plus",
            "z-ai/glm-5.2",
            "deepseek/deepseek-v4-pro",
            "meta-llama/llama-4-maverick",
        ]

        with patch.dict(os.environ, {
                "LLM_BACKEND": "cli",
                "SPEC_ALIGNMENT_ENABLED": "false",
                "KERNEL_FEEDBACK_ENABLED": "false",
            }, clear=False), \
                patch.object(agent_rag_moe, "_load_env",
                             return_value=(None, "openrouter-key")), \
                patch.object(agent_rag_moe, "_rag_context", return_value=""), \
                patch.object(agent_rag_moe, "_cli_invoke", side_effect=fake_cli), \
                patch.object(agent_rag_moe, "_openrouter_invoke",
                             side_effect=fake_openrouter), \
                patch.object(agent_rag_moe, "_gemini_invoke",
                             side_effect=fake_gemini), \
                patch.object(agent_rag_moe, "is_compiler_available",
                             return_value=False):
            final, record = agent_rag_moe.generate_sysml_moe("A CLI-backed system.")

        self.assertTrue(final.startswith("part def FromOpenRouter_"))
        self.assertEqual(record["llm_backend"], "cli")
        self.assertEqual(record["expert_models"], expected_experts)
        self.assertEqual(record["combiner_model"], "z-ai/glm-5.2")
        self.assertEqual(cli_calls, [])
        self.assertEqual(openrouter_calls, [*expected_experts, "z-ai/glm-5.2"])
        self.assertEqual(gemini_calls, [])
        self.assertEqual(record.get("expert_soft_fail_count"), 0)

    def test_expert_soft_fail_continues_with_remaining_experts(self):
        glm_calls = {"n": 0}

        def fake_cli(model, system_msg, human_msg, *, mode="sysml"):
            return f"part def FromCLI_{model.split('/')[-1].replace('.', '_')};"

        def fake_openrouter(model, system_msg, human_msg, key):
            if model == "z-ai/glm-5.2":
                glm_calls["n"] += 1
                # Soft-fail the GLM expert only; its combiner call succeeds.
                if glm_calls["n"] == 1:
                    raise RuntimeError("transient OpenRouter expert failure")
            return "part def FromOpenRouter_llama;"

        with patch.dict(os.environ, {
                "LLM_BACKEND": "cli",
                "SPEC_ALIGNMENT_ENABLED": "false",
                "KERNEL_FEEDBACK_ENABLED": "false",
            }, clear=False), \
                patch.object(agent_rag_moe, "_load_env",
                             return_value=(None, "openrouter-key")), \
                patch.object(agent_rag_moe, "_rag_context", return_value=""), \
                patch.object(agent_rag_moe, "_cli_invoke", side_effect=fake_cli), \
                patch.object(agent_rag_moe, "_openrouter_invoke",
                             side_effect=fake_openrouter), \
                patch.object(agent_rag_moe, "is_compiler_available",
                             return_value=False):
            final, record = agent_rag_moe.generate_sysml_moe("Soft-fail expert test.")

        self.assertTrue(final.startswith("part def FromOpenRouter_"))
        self.assertEqual(record["expert_soft_fail_count"], 1)
        self.assertEqual(record["expert_soft_fails"][0]["model"], "z-ai/glm-5.2")
        self.assertIn("qwen/qwen3.6-plus", record["expert_candidates"])
        self.assertIn("deepseek/deepseek-v4-pro", record["expert_candidates"])
        self.assertNotIn("z-ai/glm-5.2", record["expert_candidates"])

    def test_cli_provider_routing_table(self):
        from spec_aligner.llm import provider_for_model, resolve_cli_model

        # Gemini is proxied through Claude Code (default) or Codex; Llama stays OpenRouter.
        with patch.dict(os.environ, {"CLI_PROXY_VIA": "claude"}, clear=False):
            self.assertEqual(provider_for_model("gemini-2.5-pro"), "claude")
            self.assertEqual(resolve_cli_model("gemini-2.5-pro"), "claude-sonnet-4-5")
        with patch.dict(os.environ, {"CLI_PROXY_VIA": "codex"}, clear=False):
            os.environ.pop("GEMINI_CLI_VIA", None)
            self.assertEqual(provider_for_model("gemini-2.5-pro"), "codex")
            self.assertEqual(resolve_cli_model("gemini-2.5-pro"), "gpt-5.4")
        self.assertEqual(provider_for_model("anthropic/claude-sonnet-4.5"), "claude")
        self.assertEqual(
            resolve_cli_model("anthropic/claude-sonnet-4.5"), "claude-sonnet-4-5"
        )
        self.assertEqual(provider_for_model("openai/gpt-5.4"), "codex")
        with self.assertRaises(RuntimeError):
            provider_for_model("meta-llama/llama-4-maverick")
        with patch.dict(os.environ, {"LLM_BACKEND": "cli"}):
            self.assertTrue(agent_rag_moe._model_uses_cli("gemini-2.5-pro"))
            self.assertFalse(agent_rag_moe._model_uses_cli("meta-llama/llama-4-maverick"))

    def test_cli_backend_gemini_http_is_hard_refused(self):
        with patch.dict(os.environ, {"LLM_BACKEND": "cli"}, clear=False):
            with self.assertRaises(RuntimeError) as ctx:
                agent_rag_moe._gemini_invoke("sys", "user")
            self.assertIn("forbidden", str(ctx.exception).lower())

    def test_cli_subprocess_uses_claude_or_codex_binaries_only(self):
        """ask_completion must spawn claude/codex for CLI-routable models."""
        from pathlib import Path
        from spec_aligner import llm as llm_mod

        seen = []

        def fake_run(cmd, **kwargs):
            seen.append(list(cmd))
            if cmd and cmd[0] == "codex":
                try:
                    idx = cmd.index("--output-last-message")
                    Path(cmd[idx + 1]).write_text("part def Ok;", encoding="utf-8")
                except (ValueError, IndexError):
                    pass

            class Res:
                returncode = 0
                stdout = "part def Ok;"
            return Res()

        with patch.dict(os.environ, {
                "LLM_BACKEND": "cli",
                "CLI_PROXY_VIA": "claude",
            }, clear=False), \
                patch.object(llm_mod, "_run", side_effect=fake_run), \
                patch.object(llm_mod.shutil, "which", return_value="/usr/bin/fake"), \
                patch("urllib.request.urlopen", side_effect=AssertionError("HTTP")):
            for model, expect_bin in [
                ("openai/gpt-5.5", "codex"),
                ("anthropic/claude-sonnet-4.5", "claude"),
                ("openai/gpt-5.4", "codex"),
            ]:
                seen.clear()
                out = llm_mod.ask_completion("hi", model=model, timeout=30, provider=None)
                self.assertTrue(out)
                self.assertTrue(seen, f"no subprocess for {model}")
                self.assertEqual(seen[0][0], expect_bin, f"bad binary for {model}: {seen[0]}")
            with self.assertRaises(RuntimeError):
                llm_mod.provider_for_model("meta-llama/llama-4-maverick")


if __name__ == "__main__":
    unittest.main()
