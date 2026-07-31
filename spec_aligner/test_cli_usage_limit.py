"""Tests for CLI usage-limit detection used by batch generation abort."""

from __future__ import annotations

import unittest
from unittest.mock import patch

from spec_aligner.llm import (
    CliUsageLimitError,
    ask_completion,
    is_cli_policy_refusal_message,
    is_cli_usage_limit_message,
)


class CliUsageLimitDetectionTests(unittest.TestCase):
    def test_detects_claude_and_codex_hard_limits(self):
        self.assertTrue(is_cli_usage_limit_message(
            "5-hour limit reached · resets 4:12 PM"
        ))
        self.assertTrue(is_cli_usage_limit_message(
            "You've hit your usage limit. Limits reset every 5h and every week."
        ))
        self.assertTrue(is_cli_usage_limit_message(
            "You've hit your session limit"
        ))
        self.assertTrue(is_cli_usage_limit_message(
            "message limit exhausted"
        ))

    def test_ignores_transient_capacity_throttle(self):
        self.assertFalse(is_cli_usage_limit_message(
            "Server is temporarily limiting requests (not your usage limit) · Rate limited"
        ))
        self.assertFalse(is_cli_usage_limit_message("some unrelated failure"))

    def test_ask_completion_does_not_retry_usage_limit(self):
        calls = {"n": 0}

        def boom(*args, **kwargs):
            calls["n"] += 1
            raise CliUsageLimitError("5-hour limit reached")

        with patch("spec_aligner.llm._ask_once", side_effect=boom):
            with self.assertRaises(CliUsageLimitError):
                ask_completion("hello", model="openai/gpt-5.4", provider="codex")
        self.assertEqual(calls["n"], 1)

    def test_detects_usage_policy_refusal(self):
        self.assertTrue(is_cli_policy_refusal_message(
            "Claude Code is unable to respond to this request, which appears "
            "to violate our Usage Policy"
        ))

    def test_ask_completion_does_not_retry_policy_refusal(self):
        calls = {"n": 0}

        def boom(*args, **kwargs):
            calls["n"] += 1
            raise RuntimeError(
                "claude CLI failed rc=1: API Error: appears to violate our Usage Policy"
            )

        with patch("spec_aligner.llm._ask_once", side_effect=boom):
            with self.assertRaises(RuntimeError):
                ask_completion(
                    "hello", model="anthropic/claude-sonnet-4.5", provider="claude"
                )
        self.assertEqual(calls["n"], 1)


if __name__ == "__main__":
    unittest.main()
