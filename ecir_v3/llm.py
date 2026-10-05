"""OpenRouter chat transport for the v3 runs: provider pinning plus served-provider/usage logging.

Mirrors nl2sysml.agent_rag_moe._openrouter_invoke_once (payload, headers, retry classes,
total response deadline) and adds what the runbook requires:
  * "provider": {"order": [<provider>], "allow_fallbacks": false} in every request;
  * the served provider, token usage, finish_reason and generation id returned per call.
Per-language max-token settings follow the v1 ladder transports (see LANG_MAX_TOKENS).
"""
from __future__ import annotations

import json
import os
import random
import socket
import threading
import time
from urllib import error as urlerror
from urllib import request as urlreq

from common import MODEL, TEMPERATURE

RETRYABLE = {408, 409, 425, 429, 500, 502, 503, 504, 520, 522, 524, 529}
# v1 ladder: SysML sent max_completion_tokens=32768; the Solidity and Modelica (ee45ceb) transports sent none.
LANG_MAX_TOKENS = {"sys": 32768, "sol": None, "mod": None}
_GATE = threading.BoundedSemaphore(int(os.getenv("OPENROUTER_MAX_CONCURRENCY", "8")))


class InfraError(RuntimeError):
    """Transport/provider failure after retries: not a model outcome."""


class OutOfCredits(RuntimeError):
    """HTTP 402: the OpenRouter balance is exhausted. Runs must stop, not retry."""


def credits() -> dict:
    """{"total_credits", "total_usage", "remaining"} from OpenRouter /credits."""
    key = os.getenv("OPENROUTER_API_KEY", "")
    base = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
    req = urlreq.Request(f"{base}/credits", headers={"Authorization": f"Bearer {key}"})
    with urlreq.urlopen(req, timeout=30) as r:
        d = json.loads(r.read().decode())["data"]
    d["remaining"] = float(d["total_credits"]) - float(d["total_usage"])
    return d


def _post(payload: dict, key: str, timeout: float = 300.0, deadline: float = 900.0) -> dict:
    base = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
    req = urlreq.Request(f"{base}/chat/completions", data=json.dumps(payload).encode(), headers={
        "Content-Type": "application/json", "Accept": "application/json",
        "Authorization": f"Bearer {key}",
        "HTTP-Referer": os.getenv("HTTP_REFERER", "https://localhost"),
        "X-Title": os.getenv("APP_TITLE", "ecir-v3"),
    })
    with _GATE:
        with urlreq.urlopen(req, timeout=timeout) as resp:
            end = time.monotonic() + deadline
            chunks = []
            while True:
                if time.monotonic() > end:
                    raise TimeoutError(f"response exceeded {deadline:g}s total timeout")
                c = resp.read(64 * 1024)
                if not c:
                    break
                chunks.append(c)
    return json.loads(b"".join(chunks).decode("utf-8", errors="ignore"))


class _MaybeBilled(Exception):
    """The request reached the provider and may have produced (and billed) a completion."""


def chat(system: str, user: str, *, lang: str, provider: str | None, key: str | None = None,
         max_retries: int = 5, max_billable_retries: int = 1) -> dict:
    """One completion. Returns {"text", "provider", "usage", "finish_reason", "id", "attempts", ...}.

    Billing guard: rate-limit / 5xx rejections (no completion produced) are retried up to
    max_retries times; failures after the provider may have generated (timeouts, dropped
    connections, unparsable bodies) are retried at most max_billable_retries times.
    provider=None keeps OpenRouter's default routing, as the existing pipelines do.
    Raises InfraError when retries are exhausted."""
    key = key or os.getenv("OPENROUTER_API_KEY")
    if not key:
        raise InfraError("OPENROUTER_API_KEY missing")
    payload = {"model": MODEL, "temperature": TEMPERATURE, "usage": {"include": True},
               "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}]}
    if LANG_MAX_TOKENS.get(lang):
        payload["max_completion_tokens"] = LANG_MAX_TOKENS[lang]
    if provider:
        payload["provider"] = {"order": [provider], "allow_fallbacks": False}
    last, rejected, billable = None, 0, 0
    while True:
        try:
            try:
                obj = _post(payload, key)
            except urlerror.HTTPError:
                raise
            except (TimeoutError, socket.timeout, ConnectionError, json.JSONDecodeError) as e:
                raise _MaybeBilled(f"{type(e).__name__}: {e}")
            except urlerror.URLError as e:      # DNS / connect refused: never reached a provider
                raise urlerror.HTTPError("", 503, f"URLError: {e}", None, None)
            err = obj.get("error") if isinstance(obj, dict) else None
            if err:
                code = err.get("code") if isinstance(err, dict) else None
                if code == 402:
                    raise OutOfCredits(str(err))
                if code in RETRYABLE:
                    raise urlerror.HTTPError("", int(code), str(err), None, None)
                raise InfraError(f"OpenRouter error: {err}")
            ch = (obj.get("choices") or [{}])[0]
            return {"text": (ch.get("message") or {}).get("content") or "",
                    "provider": obj.get("provider"), "usage": obj.get("usage") or {},
                    "finish_reason": ch.get("finish_reason"), "id": obj.get("id"),
                    "attempts": 1 + rejected + billable, "possibly_billed_failures": billable}
        except (InfraError, OutOfCredits):
            raise
        except urlerror.HTTPError as e:
            body = ""
            try:
                body = e.read().decode("utf-8", errors="ignore") if e.fp else ""
            except Exception:
                pass
            last = f"HTTP {e.code}: {body or e.msg}"
            if e.code == 402 or "insufficient credits" in last.lower():
                raise OutOfCredits(last)
            if e.code not in RETRYABLE:
                raise InfraError(last)
            rejected += 1
            if rejected > max_retries:
                raise InfraError(f"rejected {rejected} times: {last}")
            time.sleep(min(60.0, 2 ** rejected + random.random()))
        except _MaybeBilled as e:
            last = str(e)
            billable += 1
            if billable > max_billable_retries:
                raise InfraError(f"possibly-billed failures: {billable}: {last}")
            time.sleep(5)


def endpoints(model: str = MODEL) -> list[dict]:
    """Providers currently serving the model (OpenRouter /models/<id>/endpoints)."""
    key = os.getenv("OPENROUTER_API_KEY", "")
    base = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
    req = urlreq.Request(f"{base}/models/{model}/endpoints",
                         headers={"Authorization": f"Bearer {key}"})
    with urlreq.urlopen(req, timeout=60) as r:
        data = json.loads(r.read().decode())
    return (data.get("data") or {}).get("endpoints") or []
