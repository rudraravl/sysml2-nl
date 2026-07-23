"""Single-shot LLM calls via the Codex CLI.

Same scheme as nl2sysml/ablation_gpt55/batch_codex_gpt55.py: one `codex exec`
subprocess per call, read-only sandbox, empty temp cwd, result taken from
--output-last-message. Uses the ChatGPT sign-in (no API billing).
"""

from __future__ import annotations

import os
import subprocess
import tempfile
import time
from pathlib import Path

SINGLE_SHOT_PREFIX = (
    "You are acting as a single-shot LLM completion. "
    "Do not use tools, do not inspect files, do not run commands. "
    "Reply with raw JSON only - no markdown fences, no commentary.\n\n"
)

RETRIES = 3


def ask(prompt: str, model: str | None = None, timeout: int = 600) -> str:
    """codex exec with retries - calls queue under plan rate limits and can
    time out or fail transiently when many run concurrently."""
    last: Exception | None = None
    for attempt in range(RETRIES):
        try:
            return _ask_once(prompt, model, timeout)
        except (subprocess.TimeoutExpired, RuntimeError) as e:
            last = e
            if attempt < RETRIES - 1:
                time.sleep(15 * (attempt + 1))
    raise last


def _ask_once(prompt: str, model: str | None, timeout: int) -> str:
    model = model or os.getenv("SPEC_ALIGNER_MODEL", "gpt-5.5")
    with tempfile.TemporaryDirectory(prefix="spec-aligner-") as tmp:
        out = Path(tmp) / "last_message.txt"
        cmd = [
            "codex", "exec",
            "--sandbox", "read-only",
            "--ignore-rules",
            "--ignore-user-config",
            "--ephemeral",
            "--skip-git-repo-check",
            "--output-last-message", str(out),
            "--model", model,
            SINGLE_SHOT_PREFIX + prompt,
        ]
        res = subprocess.run(cmd, cwd=tmp, text=True, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, timeout=timeout, check=False)
        if res.returncode != 0:
            raise RuntimeError(f"codex exec failed rc={res.returncode}: {res.stdout[-2000:]}")
        text = out.read_text(encoding="utf-8").strip() if out.exists() else ""
        if not text:
            raise RuntimeError("codex exec produced no output")
        return text