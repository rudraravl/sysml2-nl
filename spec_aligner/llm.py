"""Single-shot LLM calls via provider CLIs (Codex / Claude Code).

Same scheme as nl2sysml/ablation_gpt55/batch_codex_gpt55.py: one subprocess per
call, empty temp cwd, no tool use. Uses each provider's local sign-in rather
than OpenRouter / Google Generative AI HTTP APIs.

Under LLM_BACKEND=cli: Claude/GPT use Claude Code / Codex; Gemini is proxied
through those CLIs (CLI_PROXY_VIA / GEMINI_CLI_VIA). Models without a CLI
(e.g. meta-llama/*) stay on OpenRouter.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

JSON_PREFIX = (
    "You are acting as a single-shot LLM completion. "
    "Do not use tools, do not inspect files, do not run commands. "
    "Reply with raw JSON only - no markdown fences, no commentary.\n\n"
)

SYSML_PREFIX = (
    "You are acting as a single-shot LLM completion. "
    "Do not use tools, do not inspect files, do not run commands. "
    "Answer directly with SysML v2 textual notation only. "
    "Do not include markdown fences, commentary, or explanations.\n\n"
)

TEXT_PREFIX = (
    "You are acting as a single-shot LLM completion. "
    "Do not use tools, do not inspect files, do not run commands. "
    "Reply with the requested content only - no markdown fences "
    "unless the caller explicitly asks for them.\n\n"
)

# Backward-compatible alias used by research callers.
SINGLE_SHOT_PREFIX = JSON_PREFIX

RETRIES = 3

# Default host-CLI models when a Gemini expert id is proxied through Claude/Codex.
# Claude Code expects hyphenated ids (claude-sonnet-4-5), not OpenRouter dots.
_DEFAULT_PROXY_CLAUDE_MODEL = "claude-sonnet-4-5"
_DEFAULT_PROXY_CODEX_MODEL = "gpt-5.4"


def ask(prompt: str, model: str | None = None, timeout: int = 600) -> str:
    """JSON-oriented single-shot completion (spec alignment / research CLI)."""
    return ask_completion(prompt, model=model, timeout=timeout, prefix=JSON_PREFIX)


def ask_sysml(prompt: str, model: str | None = None, timeout: int = 600) -> str:
    """SysML-only single-shot completion for generation / repair."""
    return ask_completion(prompt, model=model, timeout=timeout, prefix=SYSML_PREFIX)


def ask_completion(
    prompt: str,
    model: str | None = None,
    timeout: int = 600,
    *,
    prefix: str = TEXT_PREFIX,
    provider: str | None = None,
) -> str:
    """Provider-CLI completion with retries for transient rate-limit failures."""
    last: Exception | None = None
    for attempt in range(RETRIES):
        try:
            return _ask_once(
                prompt, model, timeout, prefix=prefix, provider=provider
            )
        except (subprocess.TimeoutExpired, RuntimeError) as e:
            last = e
            if attempt < RETRIES - 1:
                time.sleep(15 * (attempt + 1))
    assert last is not None
    raise last


def format_chat_prompt(system_msg: str, human_msg: str) -> str:
    """Combine chat-style system/user messages into one CLI prompt body."""
    system = (system_msg or "").strip()
    human = (human_msg or "").strip()
    if system and human:
        return f"System instructions:\n{system}\n\nUser request:\n{human}"
    return system or human


def _normalize_claude_cli_model(name: str) -> str:
    """Map OpenRouter-style Claude ids onto Claude Code model names."""
    # e.g. claude-sonnet-4.5 → claude-sonnet-4-5
    return name.replace(".", "-") if name else name


def _is_native_claude_model(model: str) -> bool:
    lowered = (model or "").strip().lower()
    return lowered.startswith("anthropic/") or "claude" in lowered


def _is_native_codex_model(model: str) -> bool:
    lowered = (model or "").strip().lower()
    return lowered.startswith("openai/") or lowered.startswith("gpt")


def _is_gemini_model(model: str) -> bool:
    lowered = (model or "").strip().lower()
    return lowered.startswith("gemini") or "/gemini" in lowered


def needs_cli_proxy(model: str) -> bool:
    """True when Gemini is proxied through Claude/Codex under CLI backend.

    Llama and other OpenRouter-only ids are not proxied — they stay on OpenRouter.
    """
    return _is_gemini_model(model)


def cli_proxy_via() -> str:
    """Host CLI for proxied Gemini ids: 'claude' (default) or 'codex'.

    Prefers CLI_PROXY_VIA; GEMINI_CLI_VIA remains a backward-compatible alias.
    """
    via = (
        os.getenv("CLI_PROXY_VIA")
        or os.getenv("GEMINI_CLI_VIA")
        or "claude"
    ).strip().lower()
    if via not in ("claude", "codex"):
        raise RuntimeError(
            f"CLI_PROXY_VIA/GEMINI_CLI_VIA must be 'claude' or 'codex', got {via!r}."
        )
    return via


# Backward-compatible alias.
gemini_cli_via = cli_proxy_via


def provider_for_model(model: str) -> str:
    """Map a generation model id onto a local CLI provider (claude or codex)."""
    lowered = (model or "").strip().lower()
    if not lowered:
        raise RuntimeError("model name is required for CLI provider routing")
    if _is_native_claude_model(model):
        return "claude"
    if _is_native_codex_model(model):
        return "codex"
    if _is_gemini_model(model):
        return cli_proxy_via()
    raise RuntimeError(
        f"No CLI provider for model {model!r}. "
        "CLI backend supports gemini (via Claude Code or Codex; set "
        "CLI_PROXY_VIA=claude|codex), anthropic/claude (Claude Code), and "
        "openai/gpt (Codex). Models without a matching CLI (e.g. meta-llama/*) "
        "use OpenRouter even when LLM_BACKEND=cli."
    )


def resolve_cli_model(model: str, provider: str | None = None) -> str:
    """Strip OpenRouter-style prefixes and remap Gemini ids onto the host CLI."""
    provider = provider or provider_for_model(model)
    if needs_cli_proxy(model):
        # Host CLIs cannot take a Gemini model id; remap.
        override = (
            (os.getenv("CLI_PROXY_MODEL") or "").strip()
            or (os.getenv("GEMINI_CLI_MODEL") or "").strip()
        )
        if override:
            return (
                _normalize_claude_cli_model(override)
                if provider == "claude"
                else override
            )
        if provider == "claude":
            return _normalize_claude_cli_model(
                (os.getenv("CLAUDE_CLI_MODEL") or "").strip()
                or _DEFAULT_PROXY_CLAUDE_MODEL
            )
        if provider == "codex":
            return (
                (os.getenv("CODEX_CLI_MODEL") or "").strip()
                or _DEFAULT_PROXY_CODEX_MODEL
            )
        raise RuntimeError(f"Cannot remap proxied model for provider {provider!r}")

    name = model.strip()
    if "/" in name:
        name = name.split("/", 1)[1]
    if provider == "codex":
        return os.getenv("CODEX_CLI_MODEL") or name
    if provider == "claude":
        return _normalize_claude_cli_model(os.getenv("CLAUDE_CLI_MODEL") or name)
    return name


def _ask_once(
    prompt: str,
    model: str | None,
    timeout: int,
    *,
    prefix: str,
    provider: str | None,
) -> str:
    model = model or os.getenv("SPEC_ALIGNER_MODEL") or os.getenv("LLM_CLI_MODEL", "gpt-5.5")
    provider = provider or provider_for_model(model)
    cli_model = resolve_cli_model(model, provider)
    full_prompt = prefix + prompt

    if provider == "codex":
        return _run_codex(full_prompt, cli_model, timeout)
    if provider == "claude":
        return _run_claude(full_prompt, cli_model, timeout)
    raise RuntimeError(
        f"Unsupported CLI provider: {provider}. "
        "Supported providers: claude, codex."
    )


def _require_binary(name: str) -> str:
    path = shutil.which(name)
    if not path:
        raise RuntimeError(
            f"{name} CLI not found on PATH. Install/authenticate it, or unset "
            f"LLM_BACKEND=cli to use the API backend."
        )
    return path


def _run_codex(prompt: str, model: str, timeout: int) -> str:
    _require_binary("codex")
    with tempfile.TemporaryDirectory(prefix="cli-codex-") as tmp:
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
            prompt,
        ]
        res = _run(cmd, cwd=tmp, timeout=timeout)
        if res.returncode != 0:
            raise RuntimeError(
                f"codex exec failed rc={res.returncode}: {res.stdout[-2000:]}"
            )
        text = out.read_text(encoding="utf-8").strip() if out.exists() else ""
        if not text:
            raise RuntimeError("codex exec produced no output")
        return text


def _run_claude(prompt: str, model: str, timeout: int) -> str:
    _require_binary("claude")
    with tempfile.TemporaryDirectory(prefix="cli-claude-") as tmp:
        # Put the prompt immediately after -p so later flags cannot steal it.
        # Empty --tools disables tool use entirely (single-shot completion).
        cmd = [
            "claude",
            "-p",
            prompt,
            "--output-format", "text",
            "--model", model,
            "--tools", "",
        ]
        res = _run(cmd, cwd=tmp, timeout=timeout)
        if res.returncode != 0:
            raise RuntimeError(
                f"claude CLI failed rc={res.returncode}: {res.stdout[-2000:]}"
            )
        text = (res.stdout or "").strip()
        if not text:
            raise RuntimeError("claude CLI produced no output")
        return text


def _run(cmd: list[str], *, cwd: str, timeout: int) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        check=False,
    )
