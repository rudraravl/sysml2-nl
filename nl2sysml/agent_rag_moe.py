"""
LangChain + MoE synthesis

Pipeline:
- Build RAG context from dataset examples and spec chunks (local JSONL).
- Compose System/Human messages (same template as agent_rag).
- Query multiple experts (EXPERT_MODELS), all via OpenRouter:
  * z-ai/glm-5.2 (structural generation, also the combiner)
  * deepseek/deepseek-v4-pro (structural generation)
  * qwen/qwen3.8-max (third distinct family, former Gemini slot)
  * meta-llama/llama-4-maverick
- Ask the combiner to synthesize a single best SysML v2 model from candidates.
- Post-synthesis gates (in order):
  1. Compiler syntax/semantic refine
  2. SysML kernel execution refine
  3. Spec-mismatch semantic alignment (combiner repair on failures;
     each repair is re-validated with compiler + kernel and kept only if
     alignment improves without worsening executability)
- Output only SysML v2 code; no markdown fences.

LLM backends:
- api (default): all experts/combiner via OpenRouter HTTP.
- cli: models with a local CLI route (anthropic/*, openai/*) use Claude Code /
  Codex; everything else falls back to OpenRouter. No model in the current
  expert set has a CLI route, so this is a no-op today. CLI failures raise
  immediately.

One-shot: pass requirement as CLI arg. Batch: no args → read nl2sysml/dataset.json and write results to nl2sysml/result_rag_moe.
"""

from __future__ import annotations

from pathlib import Path
import os
import json
import random
import re
import sys
import threading
import time
from typing import Any, List, Tuple, Optional
from urllib import error as _urlerror
from urllib import request as _req

from dotenv import load_dotenv

_REPO_ROOT = Path(__file__).resolve().parents[1]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

# Import compiler interface
try:
    from nl2sysml.compiler_interface import check_code, is_compiler_available, CompilerResult
    COMPILER_AVAILABLE = True
except ImportError:
    COMPILER_AVAILABLE = False
    # Create dummy functions/classes for fallback
    def check_code(code: str, syntax_only: bool = False):
        class DummyResult:
            def __init__(self):
                self.errors = []
                self.is_valid = False
            @property
            def error_count(self):
                return 0
            def format_errors(self):
                return "No errors found."
        return DummyResult()
    def is_compiler_available():
        return False
    class CompilerResult:
        def __init__(self, errors=None, is_valid=False):
            self.errors = errors or []
            self.is_valid = is_valid
        @property
        def error_count(self):
            return len(self.errors)
        def format_errors(self):
            return "No errors found."

# Import kernel execution interface
try:
    from nl2sysml.sysml_execution import ExecutionRequest, ExecutionResult, run_sysml_execution
    KERNEL_EXECUTION_AVAILABLE = True
except ImportError:
    try:
        from sysml_execution import ExecutionRequest, ExecutionResult, run_sysml_execution
        KERNEL_EXECUTION_AVAILABLE = True
    except ImportError:
        ExecutionRequest = None  # type: ignore[assignment,misc]
        ExecutionResult = Any  # type: ignore[misc]
        run_sysml_execution = None  # type: ignore[assignment]
        KERNEL_EXECUTION_AVAILABLE = False


# Expert models (one per line). All served over OpenRouter.
EXPERT_MODELS = [
    "qwen/qwen3.6-plus",       # third distinct family (was the gemini slot)
    "z-ai/glm-5.2",            # was anthropic/claude-sonnet-4.5
    "deepseek/deepseek-v4-pro",  # was openai/gpt-5.x
    "meta-llama/llama-4-maverick",
]

# Combiner model for the final synthesis step (strongest structural generator)
COMBINER_MODEL = "z-ai/glm-5.2"

# Experts are queried concurrently; per-entry wall clock is the slowest expert
# rather than the sum. Set to 1 to restore sequential querying.
EXPERT_PARALLELISM = int(os.getenv("EXPERT_PARALLELISM", "4"))

# Heuristic reliability rating per expert family (0–10)
EXPERT_MODELS_RATING = {
    "glm": 10,
    "deepseek": 9,
    "qwen": 7,
    "gemma": 5,
    "gemini": 5,
    "gpt": 7,
    "claude": 10,
    "llama": 5,
    "other": 5,
}

# Compiler configuration
MAX_REFINEMENT_ITERATIONS = int(os.getenv("MAX_REFINEMENT_ITERATIONS", "2"))
COMPILER_SYNTAX_ONLY = os.getenv("COMPILER_SYNTAX_ONLY", "false").lower() == "true"

# Kernel feedback configuration
MAX_KERNEL_REFINEMENT_ITERATIONS = int(os.getenv("MAX_KERNEL_REFINEMENT_ITERATIONS", "2"))
HARNESS_HEADER = "// --- Test harness (auto-generated) ---"

# Spec-mismatch / semantic alignment configuration
SPEC_ALIGNMENT_THRESHOLD = float(os.getenv("SPEC_ALIGNMENT_THRESHOLD", "0.8"))
SPEC_ALIGNMENT_MAX_REPAIRS = int(os.getenv("SPEC_ALIGNMENT_MAX_REPAIRS", "1"))
SPEC_ALIGNMENT_PROFILE = os.getenv("SPEC_ALIGNMENT_PROFILE", "runtime")
SPEC_ALIGNMENT_SHARDS = int(os.getenv("SPEC_ALIGNMENT_SHARDS", "3"))

def _split_consolidated_at_harness(consolidated: str) -> Tuple[str, str]:
    """Split the kernel payload without exposing generated harness code to the LLM."""
    model_plus_mocks, separator, harness_body = consolidated.partition(HARNESS_HEADER)
    if not separator:
        return consolidated, ""
    return model_plus_mocks, separator + harness_body


def _number_sysml_lines(code: str) -> str:
    """Add kernel-aligned, one-based line numbers to SysML source."""
    return "\n".join(
        f"{line_number:4d}| {line}"
        for line_number, line in enumerate(code.splitlines(), 1)
    )


def _format_kernel_errors(result: ExecutionResult, harness_start_line: int) -> str:
    """Format a bounded set of kernel errors for the refinement model."""
    formatted: List[str] = []
    diagnostics = result.diagnostics or {}
    diagnostic_errors = diagnostics.get("errors", [])

    if isinstance(diagnostic_errors, list):
        for error in diagnostic_errors:
            if not isinstance(error, dict):
                continue
            message = str(error.get("message", "")).strip()
            line = error.get("line")
            column = error.get("column")
            if not message:
                continue

            location = ""
            if isinstance(line, int):
                location = f"line {line}"
                if isinstance(column, int):
                    location += f", column {column}"
                location += ": "

            harness_note = ""
            if isinstance(line, int) and line >= harness_start_line:
                harness_note = (
                    " (in auto-generated ExecutionHarness — do not edit the harness; "
                    "fix the candidate so the harness can bind to it)"
                )
            formatted.append(f"- {location}{message}{harness_note}")

    if not formatted:
        seen = set()
        for chunk in list(result.errors) + list(result.trace):
            for line in str(chunk).splitlines():
                line = line.strip()
                if "ERROR:" not in line.upper() or line in seen:
                    continue
                seen.add(line)
                formatted.append(f"- {line}")

    if not formatted:
        return "- Kernel execution failed without a structured ERROR diagnostic."
    return "\n".join(formatted[:30])

def _model_group(model_name: str) -> str:
    lowered = model_name.lower()
    if model_name.startswith("z-ai/") or "glm" in lowered:
        return "glm"
    if model_name.startswith("deepseek/") or "deepseek" in lowered:
        return "deepseek"
    if model_name.startswith("qwen/") or lowered.startswith("qwen"):
        return "qwen"
    if "gemma" in lowered:
        return "gemma"
    if model_name == "gemini-2.5-pro" or lowered.startswith("gemini"):
        return "gemini"
    if model_name.startswith("openai/") or lowered.startswith("gpt"):
        return "gpt"
    if model_name.startswith("anthropic/") or "claude" in lowered:
        return "claude"
    if model_name.startswith("meta-llama/") or "llama" in lowered:
        return "llama"
    return "other"


def _llm_backend() -> str:
    """Return 'api' or 'cli'. Default api (OpenRouter), which every model in the
    current expert set uses. Accepts LLM_BACKEND=cli|codex|codex-cli aliases."""
    raw = (os.getenv("LLM_BACKEND") or "api").strip().lower()
    if raw in ("cli", "codex", "codex-cli", "claude", "claude-cli"):
        return "cli"
    return "api"


def _model_uses_cli(model: str) -> bool:
    """True when LLM_BACKEND=cli and this model has a Claude/Codex (or Gemini-proxy) route."""
    if _llm_backend() != "cli":
        return False
    from spec_aligner.llm import provider_for_model

    try:
        provider_for_model(model)
        return True
    except RuntimeError:
        return False


def _active_expert_models() -> List[str]:
    """Same expert set for API and CLI backends."""
    return list(EXPERT_MODELS)


def _active_combiner_model() -> str:
    """Same combiner for API and CLI; only the transport differs."""
    return COMBINER_MODEL


def _load_env():
    load_dotenv(Path(__file__).parent.parent / ".env")
    gkey = os.getenv("GEMINI_API_KEY")
    openrouter_key = os.getenv("OPENROUTER_API_KEY")

    experts = _active_expert_models()
    combiner = _active_combiner_model()

    if _llm_backend() == "cli":
        # Models with a local CLI route use it; everything else (the current
        # z-ai / deepseek / qwen / meta-llama set) needs OpenRouter.
        needs_openrouter = any(not _model_uses_cli(m) for m in experts + [combiner])
        if needs_openrouter and not openrouter_key:
            raise RuntimeError(
                "OPENROUTER_API_KEY missing in environment/.env "
                "(required for non-CLI experts such as z-ai/*, deepseek/*, "
                "qwen/* and meta-llama/* when LLM_BACKEND=cli)"
            )
        return gkey, openrouter_key

    needs_gemini = any(
        m == "gemini-2.5-pro" or m.lower().startswith("gemini") for m in experts
    )
    needs_openrouter = any(
        not (m == "gemini-2.5-pro" or m.lower().startswith("gemini"))
        for m in experts + [combiner]
    )

    if needs_gemini:
        if not gkey:
            raise RuntimeError("GEMINI_API_KEY missing in environment/.env")
        try:
            import google.generativeai as genai

            genai.configure(api_key=gkey)
        except ImportError as exc:
            raise RuntimeError(
                "google-generativeai is required for Gemini expert calls "
                "(or set LLM_BACKEND=cli to use provider CLIs instead)"
            ) from exc

    if needs_openrouter and not openrouter_key:
        raise RuntimeError(
            "OPENROUTER_API_KEY missing in environment/.env "
            "(or set LLM_BACKEND=cli to use provider CLIs instead)"
        )

    return gkey, openrouter_key


def _tokenize(s: str) -> List[str]:
    return [t for t in re.split(r"[^A-Za-z0-9_]+", s.lower()) if t]


def _similarity(a: str, b: str) -> float:
    ta, tb = set(_tokenize(a)), set(_tokenize(b))
    if not ta or not tb:
        return 0.0
    inter = len(ta & tb)
    return inter / (len(ta) ** 0.5 * len(tb) ** 0.5)


def _collect_examples(root: Path, limit: int = 300) -> List[Tuple[str, str]]:
    pairs = []
    data_dir = root / "dataset" / "data"
    if not data_dir.exists():
        return pairs
    for p in sorted(data_dir.glob("*/*")):
        if p.suffix == ".txt":
            sysml = p.with_suffix(".sysml")
            if sysml.exists():
                try:
                    txt = p.read_text(encoding="utf-8")
                    code = sysml.read_text(encoding="utf-8")
                except Exception:
                    continue
                pairs.append((txt, code))
                if len(pairs) >= limit:
                    break
    return pairs


def _rag_context(nl_prompt: str, root: Path, k: int = 3) -> str:
    # Dataset examples
    blocks = []
    examples = _collect_examples(root)
    if examples:
        scored = sorted(
            ((ex, _similarity(nl_prompt, ex[0])) for ex in examples),
            key=lambda x: x[1], reverse=True,
        )
        top_data = [e for (e, s) in scored[:5] if s > 0]
        for i, (txt, code) in enumerate(top_data, 1):
            lines = []
            for ln in code.splitlines():
                t = ln.strip()
                if not t or t.startswith("//"):
                    continue
                lines.append(ln)
                if len(lines) >= 80:
                    break
            code_snip = "\n".join(lines)
            blocks.append(
                f"Example {i} NL:\n{txt.strip()}\n\nExample {i} SysML:\n{code_snip}\n---"
            )

    # Spec chunks
    spec_jsonl = root / "nl2sysml" / "spec_index" / "chunks.jsonl"
    if spec_jsonl.exists():
        try:
            hits = []
            prompt_tokens = _tokenize(nl_prompt)
            keywords = {t for t in prompt_tokens if len(t) >= 4}
            with spec_jsonl.open("r", encoding="utf-8") as fh:
                for line in fh:
                    try:
                        rec = json.loads(line)
                    except Exception:
                        continue
                    txt = rec.get("text", "")
                    title = rec.get("title", "")
                    base = _similarity(nl_prompt, txt)
                    if base <= 0:
                        continue
                    low = txt.lower()
                    kcount = sum(1 for kw in keywords if kw in low)
                    bonus = min(kcount * 0.01, 0.08)
                    title_bonus = 0.05 if ("Textual Notation" in title or "Kernel_Modeling_Language" in title) else 0.0
                    score = base + bonus + title_bonus
                    hits.append((rec, score))
            hits.sort(key=lambda x: x[1], reverse=True)
            for j, (rec, _) in enumerate(hits[:3], 1):
                txt = rec.get("text", "")
                title = rec.get("title", "Spec")
                blocks.append(f"Spec {j} [{title}]:\n{txt}\n---")
        except Exception:
            pass

    if not blocks:
        return ""
    return (
        "Use the following examples and specification excerpts as guidance. "
        "Follow grammar; prefer simple, correct constructs.\n" + "\n".join(blocks)
    )


def _default_system_prompt(user_hint: str | None = None) -> str:
    base = (
        "You generate valid SysML v2 concrete syntax only. "
        "No markdown, no fences, no prose. "
        "Prefer correct grammar and consistency. "
        "Produce complete, non-trivial models that satisfy the requirement with appropriate parts, ports, connections, items/value types (with units), behaviors (state machines/actions), and requirements when applicable. "
        "Avoid placeholders and undefined references."
    )
    if user_hint and user_hint.strip():
        return (user_hint.strip() + " ") + base
    return base


PROMPT_HUMAN_TEMPLATE = (
    "{context}\n\n"
    "Generate SysML v2 code for the following requirement. "
    "Produce a complete, detailed, non-trivial model with appropriate parts, ports, connections, item/value types (with units), behaviors (state machines/actions), and requirements as applicable. "
    "Avoid placeholders. Requirement: {input}"
)


_SYSML_KEYWORDS = (
    "package", "part def", "part ", "attribute", "action", "port",
    "requirement", "item def", "connection", "state ", "interface",
)


def _is_degenerate(code: str) -> bool:
    """True for non-answers that are non-blank and so slip past emptiness checks.

    Some OpenRouter models (observed on qwen/qwen3-coder-*) intermittently reply
    with the literal string "None"/"null" instead of a model. Such a candidate
    must not reach the combiner as if it were SysML.
    """
    stripped = (code or "").strip()
    if stripped.lower().strip(".\"'` ") in ("none", "null", "n/a", "nil", ""):
        return True
    lowered = stripped.lower()
    return not any(keyword in lowered for keyword in _SYSML_KEYWORDS)


def _postprocess(code: str) -> str:
    lines = []
    for ln in code.splitlines():
        if ln.strip().startswith("```"):
            continue
        if ln.strip().lower().startswith("sysml") and len(ln.strip().split()) == 1:
            continue
        lines.append(ln)
    return "\n".join(lines).strip()


def _gemini_llm():
    from langchain_google_genai import ChatGoogleGenerativeAI
    return ChatGoogleGenerativeAI(model="gemini-2.5-pro", api_key=os.getenv("GEMINI_API_KEY"), temperature=0.2)


def _gemini_invoke(system_msg: str, human_msg: str) -> str:
    if _llm_backend() == "cli":
        raise RuntimeError(
            "Gemini HTTP API is forbidden under LLM_BACKEND=cli; "
            "use Claude Code / Codex via _cli_invoke"
        )
    # Avoid template parsing of braces by sending concrete messages directly
    from langchain_core.messages import SystemMessage, HumanMessage
    try:
        llm = _gemini_llm()
        resp = llm.invoke([SystemMessage(content=system_msg), HumanMessage(content=human_msg)])
        # LangChain returns an AIMessage; extract plain text content
        try:
            text = resp.content  # type: ignore[attr-defined]
        except Exception:
            try:
                text = str(resp["content"])  # type: ignore[index]
            except Exception:
                text = str(resp)
    except Exception as e:
        raise RuntimeError(f"Gemini API call failed: {e}") from e
    if not str(text).strip():
        raise RuntimeError("Gemini API returned empty content")
    return str(text)


# --- OpenRouter throttling -------------------------------------------------
# Batch generation can run several samples at once, and each sample fans out to
# every expert, so in-flight requests multiply fast. These guards keep a wide
# batch from tripping OpenRouter rate limits: a global cap on concurrent HTTP
# calls, optional pacing between calls, and retry-with-backoff on 429/5xx.
_RETRYABLE_STATUS = {408, 409, 425, 429, 500, 502, 503, 504}
_throttle_lock = threading.Lock()
_openrouter_slots: threading.BoundedSemaphore | None = None
_openrouter_last_call = 0.0


def _openrouter_gate() -> threading.BoundedSemaphore:
    """Lazily built so CLI flags / .env can set the cap before the first call."""
    global _openrouter_slots
    with _throttle_lock:
        if _openrouter_slots is None:
            cap = max(1, int(os.getenv("OPENROUTER_MAX_CONCURRENCY", "8")))
            _openrouter_slots = threading.BoundedSemaphore(cap)
        return _openrouter_slots


def _openrouter_pace() -> None:
    """Space consecutive requests by OPENROUTER_MIN_INTERVAL seconds (0 = off)."""
    global _openrouter_last_call
    try:
        min_interval = float(os.getenv("OPENROUTER_MIN_INTERVAL", "0"))
    except ValueError:
        min_interval = 0.0
    if min_interval <= 0:
        return
    while True:
        with _throttle_lock:
            wait = _openrouter_last_call + min_interval - time.monotonic()
            if wait <= 0:
                _openrouter_last_call = time.monotonic()
                return
        time.sleep(wait)


def _retry_after_seconds(exc: BaseException, attempt: int) -> float:
    """Honor Retry-After when present, else exponential backoff with jitter."""
    header = None
    headers = getattr(exc, "headers", None)
    if headers is not None:
        try:
            header = headers.get("Retry-After")
        except Exception:
            header = None
    if header:
        try:
            return max(1.0, min(120.0, float(str(header).strip())))
        except ValueError:
            pass
    base = min(60.0, 2.0 ** attempt)
    return base + random.uniform(0, base * 0.5)


def _is_retryable_openrouter_error(exc: BaseException) -> bool:
    if isinstance(exc, _urlerror.HTTPError):
        return exc.code in _RETRYABLE_STATUS
    if isinstance(exc, (_urlerror.URLError, TimeoutError, OSError)):
        # Connection resets / read timeouts are transient under load.
        return True
    return False


def _openrouter_invoke(model: str, system_msg: str, human_msg: str, key: str) -> str:
    """Rate-limit-aware OpenRouter call: capped concurrency + retry on 429/5xx."""
    max_retries = max(0, int(os.getenv("OPENROUTER_MAX_RETRIES", "5")))
    attempt = 0
    while True:
        try:
            return _openrouter_invoke_once(model, system_msg, human_msg, key)
        except _RetryableOpenRouterError as exc:
            if attempt >= max_retries:
                raise RuntimeError(
                    f"OpenRouter call failed ({model}) after {attempt + 1} attempts: "
                    f"{exc.detail}"
                ) from exc
            delay = exc.retry_after if exc.retry_after is not None else _retry_after_seconds(
                exc.cause or exc, attempt
            )
            print(
                f"    ⏳ OpenRouter retry {attempt + 1}/{max_retries} for {model} "
                f"in {delay:.1f}s ({exc.detail[:120]})",
                flush=True,
            )
            time.sleep(delay)
            attempt += 1


class _RetryableOpenRouterError(Exception):
    """Transient OpenRouter failure (rate limit / server error / timeout)."""

    def __init__(self, detail: str, cause: BaseException | None = None,
                 retry_after: float | None = None):
        super().__init__(detail)
        self.detail = detail
        self.cause = cause
        self.retry_after = retry_after


def _openrouter_invoke_once(model: str, system_msg: str, human_msg: str, key: str) -> str:
    # Allowed under LLM_BACKEND=cli for non-CLI experts (e.g. meta-llama/*).
    if not key:
        raise RuntimeError(f"OPENROUTER_API_KEY missing for model {model}")
    base = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
    url = f"{base}/chat/completions"
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_msg},
            {"role": "user", "content": human_msg},
        ],
        "temperature": 0.2,
    }
    data = json.dumps(payload).encode("utf-8")
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": f"Bearer {key}",
        # Required by OpenRouter for attribution/billing
        "HTTP-Referer": os.getenv("HTTP_REFERER", "https://localhost"),
        "Referer": os.getenv("HTTP_REFERER", "https://localhost"),
        "X-Title": os.getenv("APP_TITLE", "Creatix Agent"),
        "User-Agent": os.getenv("APP_TITLE", "Creatix Agent"),
    }
    req = _req.Request(url, data=data, headers=headers)
    try:
        with _openrouter_gate():
            _openrouter_pace()
            with _req.urlopen(req, timeout=120) as resp:  # Increased timeout to 120s
                raw = resp.read().decode("utf-8", errors="ignore")
                obj = json.loads(raw)
    except Exception as e:
        detail = str(e)
        # Read the error body first: HTTPError bodies carry the provider message,
        # and OPENROUTER_DEBUG then persists it.
        body_text = ""
        try:
            body = getattr(e, "read", lambda: b"")()
            body_text = body.decode("utf-8", errors="ignore") if body else ""
        except Exception:
            body_text = ""
        if body_text:
            detail = body_text
        if os.getenv("OPENROUTER_DEBUG") and body_text:
            try:
                log_path = Path(__file__).parent / "result_rag_moe" / "openrouter_error.log"
                log_path.parent.mkdir(parents=True, exist_ok=True)
                log_path.write_text(body_text)
            except Exception:
                pass
        if _is_retryable_openrouter_error(e):
            raise _RetryableOpenRouterError(
                f"OpenRouter call failed ({model}): {detail}", cause=e
            ) from e
        raise RuntimeError(f"OpenRouter call failed ({model}): {detail}") from e

    if isinstance(obj, dict) and obj.get("error"):
        error = obj["error"]
        code = error.get("code") if isinstance(error, dict) else None
        # OpenRouter also reports upstream rate limits as HTTP 200 + error body.
        if code in _RETRYABLE_STATUS:
            raise _RetryableOpenRouterError(f"OpenRouter error ({model}): {error}")
        raise RuntimeError(f"OpenRouter error ({model}): {error}")
    try:
        text = obj["choices"][0]["message"]["content"]
    except Exception as e:
        raise RuntimeError(
            f"OpenRouter returned unexpected payload for {model}: {obj!r}"
        ) from e
    if not str(text).strip():
        raise RuntimeError(f"OpenRouter returned empty content for {model}")
    return str(text)


def _cli_invoke(
    model: str,
    system_msg: str,
    human_msg: str,
    *,
    mode: str = "sysml",
) -> str:
    """Single-shot completion via the model family's local CLI.

    Raises on missing binaries, auth/runtime failures, or empty responses.
    Never falls back to HTTP APIs.
    """
    from spec_aligner.llm import (
        JSON_PREFIX,
        SYSML_PREFIX,
        TEXT_PREFIX,
        ask_completion,
        format_chat_prompt,
        needs_cli_proxy,
        provider_for_model,
        resolve_cli_model,
    )

    prefix = {
        "sysml": SYSML_PREFIX,
        "json": JSON_PREFIX,
        "text": TEXT_PREFIX,
    }.get(mode, TEXT_PREFIX)
    provider = provider_for_model(model)
    cli_model = resolve_cli_model(model, provider)
    prompt = format_chat_prompt(system_msg, human_msg)
    timeout = int(os.getenv("LLM_CLI_TIMEOUT", "600"))
    if needs_cli_proxy(model):
        print(
            f"    → CLI provider={provider} model={cli_model} "
            f"(proxied from {model})",
            flush=True,
        )
    else:
        print(f"    → CLI provider={provider} model={cli_model}", flush=True)
    return ask_completion(
        prompt,
        model=model,
        timeout=timeout,
        prefix=prefix,
        provider=provider,
    )


def _env_flag(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in ("1", "true", "yes", "on")


def _alignment_ask(prompt: str, openrouter_key: str | None) -> str:
    combiner = _active_combiner_model()
    system = (
        "You are a deterministic evaluator. Follow the requested answer schema exactly. "
        "Return strict JSON only, without markdown or commentary."
    )
    last_error = "empty response"
    for _ in range(3):
        if _model_uses_cli(combiner):
            # JSON prefix is applied inside the Codex helper.
            out = _cli_invoke(combiner, system, prompt, mode="json")
        else:
            if not openrouter_key:
                raise RuntimeError(
                    "OPENROUTER_API_KEY is required for spec alignment "
                    "(or set LLM_BACKEND=cli)"
                )
            out = _openrouter_invoke(combiner, system, prompt, openrouter_key)
        if not out:
            continue
        try:
            from spec_aligner.jsonx import extract_json

            data = extract_json(out)
            if isinstance(data, list) or (
                isinstance(data, dict)
                and any(isinstance(data.get(key), list) for key in ("questions", "answers"))
            ):
                return out
            last_error = "JSON did not contain a questions or answers list"
        except ValueError as exc:
            last_error = str(exc)
    raise RuntimeError(f"spec alignment model returned invalid JSON: {last_error}")


def _alignment_validate(code: str) -> dict:
    if not is_compiler_available():
        return {"available": False, "is_valid": False, "errors": []}
    result = check_code(code, syntax_only=COMPILER_SYNTAX_ONLY)
    errors = [
        {
            "line": error.line,
            "column": error.column,
            "message": error.message,
            "severity": error.severity,
            "code": error.code,
            "file": error.file,
        }
        for error in result.errors
    ]
    return {
        "available": True,
        "is_valid": result.is_valid,
        "error_count": result.error_count,
        "errors": errors,
    }


def _run_post_generation_quality(prompt_text: str, candidate: str,
                                 openrouter_key: str | None) -> dict | None:
    """Semantic spec-mismatch gate with post-repair compiler + kernel revalidation."""
    if not _env_flag("SPEC_ALIGNMENT_ENABLED", True):
        return None

    from nl2sysml.quality_gate import layer2_executor, run_quality_gate

    # Re-check syntax and kernel after every semantic repair; keep only improvements.
    validate = _alignment_validate if is_compiler_available() else None
    execute = None
    if _env_flag("KERNEL_FEEDBACK_ENABLED", True) and KERNEL_EXECUTION_AVAILABLE:
        execute = layer2_executor

    def repair(repair_prompt: str) -> str:
        system = _default_system_prompt(
            "Repair an existing SysML v2 model from grounded validation and semantic feedback."
        )
        return _invoke_with_retry(
            _active_combiner_model(), system, repair_prompt, openrouter_key
        )

    return run_quality_gate(
        prompt_text,
        candidate,
        lambda prompt: _alignment_ask(prompt, openrouter_key),
        validate=validate,
        execute=execute,
        repair=repair,
        threshold=float(os.getenv(
            "SPEC_ALIGNMENT_THRESHOLD", str(SPEC_ALIGNMENT_THRESHOLD)
        )),
        max_repairs=int(os.getenv(
            "SPEC_ALIGNMENT_MAX_REPAIRS", str(SPEC_ALIGNMENT_MAX_REPAIRS)
        )),
        alignment_kwargs={
            "profile": os.getenv("SPEC_ALIGNMENT_PROFILE", SPEC_ALIGNMENT_PROFILE),
            "shards": int(os.getenv(
                "SPEC_ALIGNMENT_SHARDS", str(SPEC_ALIGNMENT_SHARDS)
            )),
        },
    )


def _invoke_with_retry(model: str, system_msg: str, human_msg: str, openrouter_key: str | None) -> str:
    """
    Call a model and enforce code-only output via postprocess and a single stricter retry if needed.

    Under LLM_BACKEND=cli: models with a local CLI (anthropic/*, openai/*) go
    through it; models without one (z-ai/*, deepseek/*, qwen/*, meta-llama/*)
    stay on OpenRouter.

    Any provider/CLI failure, blank response, or degenerate non-answer (e.g. the
    literal "None") raises — callers must not continue.
    """
    def _require(out: str, stage: str) -> str:
        if not out or not str(out).strip():
            raise RuntimeError(f"{stage}: empty response from {model}")
        if _is_degenerate(out):
            raise RuntimeError(
                f"{stage}: {model} returned no SysML ({str(out).strip()[:80]!r})"
            )
        return out

    def _needs_retry(out: str) -> bool:
        return (not out) or ("```" in out) or _is_degenerate(out)

    if _model_uses_cli(model):
        # Propagate CLI failures (missing binary, auth, empty output, etc.).
        out = _postprocess(_cli_invoke(model, system_msg, human_msg, mode="sysml"))
        if _needs_retry(out):
            strong = system_msg + " No markdown, no fences, no prose. Output SysML v2 code only."
            out = _postprocess(_cli_invoke(model, strong, human_msg, mode="sysml"))
        return _require(out, "CLI invoke")

    if model == "gemini-2.5-pro" or model.lower().startswith("gemini"):
        out = _postprocess(_gemini_invoke(system_msg, human_msg))
        if _needs_retry(out):
            strong = _default_system_prompt("No markdown, no fences, no prose. Output SysML v2 code only.")
            out = _postprocess(_gemini_invoke(strong, human_msg))
        return _require(out, "Gemini invoke")

    if not openrouter_key:
        raise RuntimeError(
            f"OPENROUTER_API_KEY missing for model {model}"
        )
    out = _postprocess(_openrouter_invoke(model, system_msg, human_msg, openrouter_key))
    if _needs_retry(out):
        strong = system_msg + " No markdown, no fences, no prose. Output SysML v2 code only."
        out = _postprocess(_openrouter_invoke(model, strong, human_msg, openrouter_key))
    return _require(out, "OpenRouter invoke")


def _refine_with_compiler(
    code: str, 
    model: str, 
    system_msg: str, 
    human_msg: str, 
    openrouter_key: str | None,
    max_iterations: int = MAX_REFINEMENT_ITERATIONS
) -> Tuple[str, CompilerResult]:
    """
    Refine code iteratively using compiler feedback.
    
    Args:
        code: Initial SysML code
        model: Model name to use for refinement
        system_msg: System message template
        human_msg: Human message template (original prompt)
        openrouter_key: OpenRouter API key
        max_iterations: Maximum number of refinement iterations
    
    Returns:
        Tuple of (refined_code, final_compiler_result)
    """
    if not is_compiler_available():
        # No compiler available, return original code
        return code, CompilerResult(errors=[], is_valid=False)
    
    current_code = code
    iteration = 0
    
    while iteration < max_iterations:
        # Check current code
        result = check_code(current_code, syntax_only=COMPILER_SYNTAX_ONLY)
        
        # If valid, we're done
        if result.is_valid:
            return current_code, result
        
        # If no more iterations, return current code
        if iteration >= max_iterations - 1:
            return current_code, result
        
        # Prepare refinement prompt with error feedback
        error_feedback = result.format_errors()
        refinement_hint = (
            f"The previous code had compilation errors. Please fix them:\n\n{error_feedback}\n\n"
            "Generate corrected SysML v2 code that addresses these errors."
        )
        
        refinement_system = system_msg + "\n\n" + refinement_hint
        refinement_human = (
            f"{human_msg}\n\n"
            f"Previous code (had errors):\n```sysml\n{current_code}\n```\n\n"
            f"Errors to fix:\n{error_feedback}\n\n"
            "Generate the corrected code."
        )
        
        # Get refined code
        refined = _invoke_with_retry(model, refinement_system, refinement_human, openrouter_key)
        if not refined or refined == current_code:
            # No improvement, break
            break
        
        current_code = refined
        iteration += 1
    
    # Final check
    final_result = check_code(current_code, syntax_only=COMPILER_SYNTAX_ONLY)
    return current_code, final_result


def _refine_with_kernel(
    code: str,
    model: str,
    system_msg: str,
    human_msg: str,
    openrouter_key: str | None,
    max_iterations: int = MAX_KERNEL_REFINEMENT_ITERATIONS,
) -> Tuple[str, Optional[ExecutionResult]]:
    """Refine the combined model using feedback from the SysML kernel."""
    if not KERNEL_EXECUTION_AVAILABLE or ExecutionRequest is None or run_sysml_execution is None:
        return code, None

    current_code = code
    iteration = 0

    while iteration < max_iterations:
        result = run_sysml_execution(ExecutionRequest(candidate_sysml=current_code))

        if not result.kernel_available or result.bridge_error:
            return current_code, result
        if result.success:
            return current_code, result
        if iteration >= max_iterations - 1:
            return current_code, result

        model_plus_mocks, _harness_block = _split_consolidated_at_harness(
            result.consolidated_payload
        )
        harness_start_line = len(model_plus_mocks.splitlines()) + 1
        error_feedback = _format_kernel_errors(result, harness_start_line)

        refinement_hint = (
            "The previous SysML v2 model failed SysML kernel execution. "
            "Fix the candidate model using the kernel errors below.\n\n"
            "Important context:\n"
            "- Before execution, the pipeline may inject mock `attribute def ...;` stubs "
            "into the root package, then tacks on an auto-generated test harness starting "
            f"at `{HARNESS_HEADER}`, followed by `package ExecutionHarness {{ ... }}`.\n"
            "- That harness is NOT shown below and must NOT appear in your output. "
            "It will be regenerated automatically.\n"
            "- Some kernel errors cite line numbers inside ExecutionHarness. Those errors "
            "can still be relevant, such as unresolved names imported from your model. "
            "Fix the candidate so the harness can bind; do not invent harness code.\n"
            "- Line numbers for the shown code refer to the pre-harness kernel payload "
            "(candidate + optional mocks). A few mock lines near the root package `{` may "
            "shift later lines slightly versus the bare candidate.\n"
            "- Emit corrected candidate SysML v2 only: no markdown, no fences, no prose, "
            "no ExecutionHarness, no mock stubs."
        )
        refinement_system = system_msg + "\n\n" + refinement_hint
        refinement_human = (
            f"{human_msg}\n\n"
            f"Previous candidate (revise this):\n```sysml\n{current_code}\n```\n\n"
            "Pre-harness kernel payload with line numbers (errors in the model/mock region "
            "refer to THESE lines; harness source is omitted — it starts after "
            f"`{HARNESS_HEADER}`):\n```\n"
            f"{_number_sysml_lines(model_plus_mocks)}\n```\n\n"
            f"Kernel errors to fix:\n{error_feedback}\n\n"
            "Generate the corrected candidate SysML v2 code only."
        )

        refined = _invoke_with_retry(
            model, refinement_system, refinement_human, openrouter_key
        )
        if not refined or refined == current_code:
            break

        current_code = refined
        iteration += 1

    final_result = run_sysml_execution(ExecutionRequest(candidate_sysml=current_code))
    return current_code, final_result


def generate_sysml_moe(prompt_text: str) -> Tuple[str, dict]:
    """
    Returns (final_sysml, prompt_record_json)

    Data flow: RAG/MoE → combiner → compiler refine → kernel refine → semantic align.
    Semantic failures repair via the active combiner model (COMBINER_MODEL / CLI combiner).
    Repaired models are kept only when alignment improves without worsening executability.
    """
    _load_env()
    backend = _llm_backend()
    experts = _active_expert_models()
    combiner = _active_combiner_model()
    root = Path(__file__).parent.parent
    context = _rag_context(prompt_text, root, k=3)
    sys_msg = _default_system_prompt(None)
    human_msg = PROMPT_HUMAN_TEMPLATE.format(context=context, input=prompt_text)

    print(f"LLM backend: {backend}", flush=True)
    if backend == "cli":
        from spec_aligner.llm import provider_for_model

        routing = []
        for m in experts:
            if _model_uses_cli(m):
                routing.append(f"{m}->{provider_for_model(m)}")
            else:
                routing.append(f"{m}->openrouter")
        print(f"  Experts: {', '.join(routing)}", flush=True)
        combiner_route = (
            provider_for_model(combiner) if _model_uses_cli(combiner) else "openrouter"
        )
        print(f"  Combiner: {combiner}->{combiner_route}", flush=True)

    # Collect candidates (each receives RAG-context-augmented prompt).
    # Soft-fail individual experts (AUP / empty / transient); keep going.
    # Hard CLI usage limits still abort so the batch can pause cleanly.
    try:
        from spec_aligner.llm import CliUsageLimitError
    except ImportError:
        CliUsageLimitError = ()  # type: ignore[misc, assignment]

    candidates: List[Tuple[str, str]] = []
    expert_soft_fails: List[dict] = []
    _, ok = _load_env()

    def _query_expert(model: str) -> str:
        out = _invoke_with_retry(model, sys_msg, human_msg, ok)
        if not out or not out.strip():
            raise RuntimeError(f"Expert {model} returned empty SysML")
        return out

    # Experts are independent, so query them concurrently: per-entry wall clock
    # becomes the slowest expert instead of the sum of all of them. Results are
    # re-ordered to EXPERT_MODELS order so the combiner prompt stays stable.
    print(f"  Querying {len(experts)} experts in parallel...", flush=True)
    results: dict[str, Any] = {}
    if EXPERT_PARALLELISM > 1 and len(experts) > 1:
        from concurrent.futures import ThreadPoolExecutor

        with ThreadPoolExecutor(max_workers=min(EXPERT_PARALLELISM, len(experts))) as pool:
            futures = {pool.submit(_query_expert, m): m for m in experts}
            for future, model in futures.items():
                try:
                    results[model] = future.result()
                except Exception as exc:  # noqa: BLE001 - classified below
                    results[model] = exc
    else:
        for m in experts:
            try:
                results[m] = _query_expert(m)
            except Exception as exc:  # noqa: BLE001 - classified below
                results[m] = exc

    for i, m in enumerate(experts, 1):
        outcome = results.get(m)
        if CliUsageLimitError and isinstance(outcome, CliUsageLimitError):
            raise outcome
        if isinstance(outcome, BaseException):
            print(f"  [{i}/{len(experts)}] ✗ Soft-fail expert {m}: {outcome}", flush=True)
            expert_soft_fails.append({"model": m, "error": str(outcome)})
            continue
        print(f"  [{i}/{len(experts)}] ✓ Got response from {m}", flush=True)
        candidates.append((m, outcome))

    # Synthesis by combiner using candidates as extra context (or direct if none).
    _, ok = _load_env()
    if candidates:
        cand_block = []
        for i, (name, code) in enumerate(candidates, 1):
            grp = _model_group(name)
            rating = EXPERT_MODELS_RATING.get(grp, 5)
            cand_block.append(
                f"Candidate {i} ({name}, rating={rating}/10):\n{code}\n---"
            )
        synth_context = (
            context
            + "\n\nUse the following candidate models as additional context.\n"
            + "\n".join(cand_block)
        )
        synth_sys_hint = (
            "Synthesize a single best model by merging or selecting from "
            "candidates when provided."
        )
        synth_sys_msg = _default_system_prompt(synth_sys_hint)
        synth_human_msg = PROMPT_HUMAN_TEMPLATE.format(
            context=synth_context, input=prompt_text
        )
        print(f"\nSynthesizing final model with {combiner}...", flush=True)
        final = _invoke_with_retry(combiner, synth_sys_msg, synth_human_msg, ok)
    else:
        print(
            f"\nNo expert candidates (soft-fails={len(expert_soft_fails)}); "
            f"using {combiner} directly...",
            flush=True,
        )
        synth_sys_msg = sys_msg
        synth_human_msg = human_msg
        final = _invoke_with_retry(combiner, synth_sys_msg, synth_human_msg, ok)
    if not final or not final.strip():
        raise RuntimeError(f"Combiner {combiner} returned empty SysML")
    print("  ✓ Got synthesis response", flush=True)
    if expert_soft_fails:
        print(
            f"  ⚠ Expert soft-fails this sample: {len(expert_soft_fails)}/"
            f"{len(experts)}",
            flush=True,
        )
    # Compiler validation and refinement happens AFTER synthesis
    # The synthesis model does a synthesis pass, then gets checked by compiler MAX_REFINEMENT_ITERATIONS times
    final_result = CompilerResult(errors=[], is_valid=False)
    if is_compiler_available() and final:
        print(f"  Validating and refining final output (up to {MAX_REFINEMENT_ITERATIONS} iterations)...", flush=True)
        final, final_result = _refine_with_compiler(
            final, combiner, synth_sys_msg, synth_human_msg, ok, MAX_REFINEMENT_ITERATIONS
        )
        status = "✓ Valid" if final_result.is_valid else f"✗ {final_result.error_count} errors"
        print(f"  {status} after refinement", flush=True)

    # Kernel execution and refinement happens after compiler refinement and only
    # operates on the combined model.
    kernel_enabled = _env_flag("KERNEL_FEEDBACK_ENABLED", True)
    kernel_result: Optional[ExecutionResult] = None
    if kernel_enabled and KERNEL_EXECUTION_AVAILABLE and final:
        print(
            f"  Executing and refining final output with the SysML kernel "
            f"(up to {MAX_KERNEL_REFINEMENT_ITERATIONS} iterations)...",
            flush=True,
        )
        final, kernel_result = _refine_with_kernel(
            final,
            combiner,
            synth_sys_msg,
            synth_human_msg,
            ok,
            MAX_KERNEL_REFINEMENT_ITERATIONS,
        )
        if kernel_result is None:
            print("  ✗ Kernel execution unavailable", flush=True)
        elif not kernel_result.kernel_available or kernel_result.bridge_error:
            print(
                f"  ✗ Kernel unavailable: {kernel_result.bridge_error or 'unknown error'}",
                flush=True,
            )
        else:
            kernel_error_count = int(
                (kernel_result.diagnostics or {}).get(
                    "n_errors", len(kernel_result.errors)
                )
            )
            status = (
                "✓ Kernel execution passed"
                if kernel_result.success
                else f"✗ {kernel_error_count} kernel errors"
            )
            print(f"  {status} after refinement", flush=True)

    # Semantic spec-mismatch gate last; combiner repairs go back through the combiner model.
    # LLM failures here must abort generation (no soft-continue).
    quality_report = None
    if final and final.strip() and _env_flag("SPEC_ALIGNMENT_ENABLED", True):
        print("  Running post-generation spec alignment...", flush=True)
        quality_report = _run_post_generation_quality(prompt_text, final, ok)
        if not quality_report:
            raise RuntimeError("Spec alignment returned no quality report")
        final = quality_report["final_sysml"]
        if not final or not str(final).strip():
            raise RuntimeError("Spec alignment / repair produced empty SysML")
        if quality_report.get("error"):
            raise RuntimeError(f"Spec alignment error: {quality_report['error']}")
        kept_idx = quality_report.get("kept_attempt", len(quality_report["attempts"]) - 1)
        kept_alignment = quality_report["attempts"][kept_idx]["alignment"]["summary"]
        print(
            "  "
            + ("✓" if quality_report["accepted"] else "✗")
            + " Spec alignment "
            + f"(similarity={kept_alignment.get('similarity')}, "
            + f"repairs={quality_report['repairs']}, "
            + f"kept={quality_report.get('repairs_kept', 0)})",
            flush=True,
        )

    if not final or not str(final).strip():
        raise RuntimeError("Generation finished with empty SysML")

    # Build JSON prompt record
    base_prompt_str = "System:\n" + sys_msg + "\n\n" + "Human:\n" + human_msg
    combine_prompt_str = (
        "System:\n" + synth_sys_msg + "\n\n" + "Human:\n" + synth_human_msg
    )

    prompt_record = {
        "llm_backend": backend,
        "expert_models": experts,
        "combiner_model": combiner,
        "expert_candidates": [name for name, _ in candidates],
        "expert_soft_fails": expert_soft_fails,
        "expert_soft_fail_count": len(expert_soft_fails),
        "combine_prompt": combine_prompt_str,
    }
    # One record entry per expert family actually in play (qwen/glm/deepseek/llama).
    for m in experts:
        prompt_record[f"{_model_group(m)}_prompt"] = base_prompt_str
    
    # Add compiler validation info if available
    if is_compiler_available():
        last_attempt = (
            quality_report.get("attempts", [])[-1]
            if quality_report and quality_report.get("attempts")
            else None
        )
        if last_attempt and last_attempt["validation_status"] in ("passed", "failed"):
            validation = last_attempt.get("validation") or {}
            prompt_record["final_valid"] = last_attempt["validation_status"] == "passed"
            prompt_record["final_errors"] = validation.get(
                "error_count", len(validation.get("errors", []))
            )
            if validation.get("errors"):
                prompt_record["final_error_details"] = validation["errors"]
        else:
            prompt_record["final_valid"] = final_result.is_valid
            prompt_record["final_errors"] = final_result.error_count
        if final_result.errors and "final_error_details" not in prompt_record:
            prompt_record["final_error_details"] = [
                {
                    "line": e.line,
                    "column": e.column,
                    "message": e.message,
                    "severity": e.severity
                }
                for e in final_result.errors
            ]

    if kernel_result is not None:
        diagnostics = kernel_result.diagnostics or {}
        diagnostic_errors = diagnostics.get("errors", [])
        prompt_record["kernel_compiled"] = kernel_result.compiled
        prompt_record["kernel_available"] = kernel_result.kernel_available
        prompt_record["kernel_error_count"] = int(
            diagnostics.get("n_errors", len(kernel_result.errors))
        )
        if kernel_result.bridge_error:
            prompt_record["kernel_bridge_error"] = kernel_result.bridge_error
        if isinstance(diagnostic_errors, list) and diagnostic_errors:
            prompt_record["kernel_error_details"] = [
                {
                    "line": error.get("line"),
                    "column": error.get("column"),
                    "message": error.get("message"),
                    "severity": error.get("severity"),
                }
                for error in diagnostic_errors[:30]
                if isinstance(error, dict)
            ]

    prompt_record["kernel_feedback_enabled"] = kernel_enabled
    prompt_record["spec_alignment_enabled"] = _env_flag("SPEC_ALIGNMENT_ENABLED", True)
    if quality_report is not None:
        prompt_record["quality_report"] = quality_report

    return final, prompt_record


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Generate SysML v2 via RAG/MoE → combiner → refine → align"
    )
    parser.add_argument(
        "requirement",
        nargs="*",
        help="Natural-language requirement (omit to batch from dataset.json)",
    )
    parser.add_argument(
        "--llm-backend",
        choices=("api", "cli", "codex"),
        default=None,
        help="Model transport: api (default; OpenRouter HTTP) or cli (Claude Code / Codex)",
    )
    args = parser.parse_args()
    if args.llm_backend:
        os.environ["LLM_BACKEND"] = args.llm_backend

    requirement = " ".join(args.requirement).strip()
    base = Path(__file__).parent
    if requirement:
        code, _prompt = generate_sysml_moe(requirement)
        print(code)
    else:
        ds_path = base / "dataset.json"
        out_dir = base / "result_rag_moe"
        out_dir.mkdir(parents=True, exist_ok=True)
        data = json.load(open(ds_path))
        prompts = data.get("prompts", [])
        try:
            from nl2sysml.batch_generate import write_entry_output
        except ModuleNotFoundError:
            from batch_generate import write_entry_output
        for item in prompts:
            pid = str(item.get("id", "")).strip() or "U?"
            desc = str(item.get("description", "")).strip()
            if not desc:
                continue
            code, prompt_json = generate_sysml_moe(desc)
            entry = {
                "id": pid,
                "description": desc,
                "domain": item.get("domain") or item.get("category") or "unknown",
                "provenance": item.get("provenance"),
                "source_title": item.get("source_title"),
            }
            write_entry_output(out_dir / pid, entry, code, prompt_json)
            print(f"wrote {out_dir / pid / (pid + '.sysml')}")
