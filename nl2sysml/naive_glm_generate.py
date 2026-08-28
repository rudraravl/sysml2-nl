#!/usr/bin/env python3
"""Naive GLM generation: single model, no RAG, no refinement, no kernel, no spec-alignment.

Generates SysML for the same prompts present in dataset/with_kernel_spec/.
Output: dataset/naive_glm/{ID}/{ID}.sysml, {ID}.txt, meta.json
"""

import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path

_ROOT = Path(__file__).resolve().parent.parent
_NL2 = Path(__file__).resolve().parent
sys.path.insert(0, str(_NL2))

from dotenv import load_dotenv
load_dotenv(_ROOT / ".env")

from compiler_interface import check_code, is_compiler_available

MODEL = "z-ai/glm-5.2"
SYSTEM_PROMPT = (
    "You generate valid SysML v2 concrete syntax only. "
    "No markdown, no fences, no prose. "
    "Prefer correct grammar and consistency. "
    "Produce complete, non-trivial models that satisfy the requirement with appropriate "
    "parts, ports, connections, items/value types (with units), behaviors "
    "(state machines/actions), and requirements when applicable. "
    "Avoid placeholders and undefined references."
)
HUMAN_TEMPLATE = (
    "Generate SysML v2 code for the following requirement. "
    "Produce a complete, detailed, non-trivial model with appropriate parts, ports, "
    "connections, item/value types (with units), behaviors (state machines/actions), "
    "and requirements as applicable. "
    "Avoid placeholders. Requirement: {input}"
)

WKS_DIR = _ROOT / "dataset" / "with_kernel_spec"
OUT_DIR = _ROOT / "dataset" / "naive_glm"


def _openrouter_invoke(model, system_msg, human_msg, key, retries=3):
    import json as _json
    import urllib.error as _err
    import urllib.request as _req

    base = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_msg},
            {"role": "user", "content": human_msg},
        ],
        "temperature": 0.2,
    }
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": f"Bearer {key}",
        "HTTP-Referer": os.getenv("HTTP_REFERER", "https://localhost"),
        "Referer": os.getenv("HTTP_REFERER", "https://localhost"),
        "X-Title": os.getenv("APP_TITLE", "Creatix Agent"),
    }

    last = None
    for attempt in range(retries):
        try:
            req = _req.Request(base + "/chat/completions",
                               data=_json.dumps(payload).encode(), headers=headers)
            with _req.urlopen(req, timeout=120) as resp:
                body = resp.read().decode("utf-8", "replace")
        except _err.HTTPError as e:
            body = e.read().decode("utf-8", "replace")
            last = f"HTTP {e.code}: {body[:200]}"
            time.sleep(2 * (attempt + 1))
            continue
        except Exception as e:
            last = f"{type(e).__name__}: {e}"
            time.sleep(2 * (attempt + 1))
            continue

        if not body.strip():
            last = "empty response body"
            time.sleep(2 * (attempt + 1))
            continue
        try:
            obj = _json.loads(body)
        except _json.JSONDecodeError:
            last = f"non-JSON response: {body[:200]}"
            time.sleep(2 * (attempt + 1))
            continue
        if "error" in obj and "choices" not in obj:
            last = f"API error: {obj['error']}"
            time.sleep(2 * (attempt + 1))
            continue
        try:
            return obj["choices"][0]["message"]["content"]
        except (KeyError, IndexError):
            last = f"unexpected response shape: {body[:200]}"
            time.sleep(2 * (attempt + 1))
            continue

    raise RuntimeError(f"OpenRouter failed after {retries} attempts: {last}")


def _postprocess(code):
    lines = []
    for ln in (code or "").splitlines():
        if ln.strip().startswith("```"):
            continue
        if ln.strip().lower().startswith("sysml") and len(ln.strip().split()) == 1:
            continue
        lines.append(ln)
    return "\n".join(lines).strip()


def _get_sample_ids():
    """Return sorted list of IDs that have completed in with_kernel_spec."""
    ids = []
    for meta in WKS_DIR.glob("*/meta.json"):
        ids.append(meta.parent.name)
    return sorted(ids)


def _read_prompt(sid):
    txt = WKS_DIR / sid / f"{sid}.txt"
    if txt.exists():
        return txt.read_text(encoding="utf-8").strip()
    return None


def generate_one(sid, key):
    prompt = _read_prompt(sid)
    if not prompt:
        return None, None, "no prompt"

    human = HUMAN_TEMPLATE.format(input=prompt)
    t0 = time.time()
    raw = _openrouter_invoke(MODEL, SYSTEM_PROMPT, human, key)
    code = _postprocess(raw)

    # Retry once if empty/degenerate
    if not code or not any(kw in code.lower() for kw in ("package", "part", "attribute")):
        strong = SYSTEM_PROMPT + " No markdown, no fences, no prose. Output SysML v2 code only."
        raw = _openrouter_invoke(MODEL, strong, human, key)
        code = _postprocess(raw)

    elapsed = time.time() - t0

    # Compile (with timeout — Java can hang on complex models)
    meta_extra = {}
    if is_compiler_available() and code:
        import signal

        class _Timeout(Exception):
            pass

        def _alarm(signum, frame):
            raise _Timeout()

        old = signal.signal(signal.SIGALRM, _alarm)
        signal.alarm(60)  # 60s timeout
        try:
            result = check_code(code)
            is_valid = result.is_valid
            errors = result.errors
        except _Timeout:
            is_valid = False
            errors = []
            meta_extra["compiler_timeout"] = True
        finally:
            signal.alarm(0)
            signal.signal(signal.SIGALRM, old)
    else:
        is_valid = False
        errors = []

    syntax_count = sum(1 for e in errors if e.is_syntax_error())
    semantic_count = sum(1 for e in errors if e.is_semantic_error())

    meta = {
        "id": sid,
        "model": MODEL,
        "pipeline": "naive_single_model",
        "created": datetime.now().isoformat(),
        "elapsed_sec": round(elapsed, 1),
        "empty_output": not bool(code),
        "validation": {
            "is_valid": is_valid,
            "error_count": len(errors),
            "syntax_error_count": syntax_count,
            "semantic_error_count": semantic_count,
        },
        "errors": [
            {"line": e.line, "column": e.column, "message": e.message,
             "severity": e.severity, "code": e.code}
            for e in errors
        ],
    }
    if meta_extra:
        meta.update(meta_extra)
    return code, meta, None


def main():
    key = os.getenv("OPENROUTER_API_KEY")
    if not key:
        print("Error: OPENROUTER_API_KEY not set")
        sys.exit(1)

    if not is_compiler_available():
        print("Warning: compiler unavailable — will skip validation")

    ids = _get_sample_ids()
    print(f"Naive GLM generation: {len(ids)} samples from with_kernel_spec")
    print(f"Model: {MODEL}")
    print(f"Output: {OUT_DIR}")
    print(f"Compiler: {'available' if is_compiler_available() else 'UNAVAILABLE'}")
    print("=" * 60)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    stats = {"done": 0, "skipped": 0, "errors": 0, "valid": 0}

    for i, sid in enumerate(ids, 1):
        out = OUT_DIR / sid
        if (out / "meta.json").exists():
            print(f"[{i}/{len(ids)}] {sid}: exists, skipping")
            stats["skipped"] += 1
            continue

        print(f"[{i}/{len(ids)}] {sid}: generating...", end=" ", flush=True)
        try:
            code, meta, err = generate_one(sid, key)
            if err:
                print(f"skip ({err})")
                stats["errors"] += 1
                continue

            out.mkdir(parents=True, exist_ok=True)
            prompt = _read_prompt(sid)
            (out / f"{sid}.sysml").write_text(code + "\n", encoding="utf-8")
            (out / f"{sid}.txt").write_text(prompt + "\n", encoding="utf-8")
            (out / "meta.json").write_text(
                json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

            v = meta["validation"]
            status = "✓ valid" if v["is_valid"] else f"✗ {v['error_count']} errors"
            print(f"{status} ({meta['elapsed_sec']}s)")
            stats["done"] += 1
            if v["is_valid"]:
                stats["valid"] += 1

        except KeyboardInterrupt:
            print("\nInterrupted.")
            break
        except Exception as e:
            print(f"ERROR: {e}")
            stats["errors"] += 1

    print("=" * 60)
    print(f"Done: {stats['done']}, Valid: {stats['valid']}, "
          f"Skipped: {stats['skipped']}, Errors: {stats['errors']}")


if __name__ == "__main__":
    main()
