#!/usr/bin/env python3
"""Naive GLM generation: single model, no RAG, no refinement, no kernel, no spec-alignment.

Generates Solidity for the same seed prompts used by batch_generate.py's default
--prompt-source seed_long (description_long in sol_seed.jsonl).
Output: dataset/naive_glm/{ID}/{ID}.sol, {ID}.txt, meta.json
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
    "You generate valid Solidity contracts only. "
    "No markdown, no fences, no prose. "
    "Prefer correct syntax and consistency. "
    "Produce a complete, non-trivial, compilable contract that satisfies the "
    "requirement, including a pragma, all necessary state, events, and functions. "
    "Avoid placeholders and undefined references."
)
HUMAN_TEMPLATE = (
    "Generate a Solidity smart contract for the following requirement. "
    "Produce a complete, detailed, non-trivial, compilable contract with appropriate "
    "state variables, events, modifiers, and functions as applicable. "
    "Avoid placeholders. Requirement: {input}"
)

SEED_FILE = _NL2 / "sol_seed.jsonl"
OUT_DIR = _ROOT / "nl2solidity" / "dataset" / "naive_glm"


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
        if ln.strip().lower().startswith("solidity") and len(ln.strip().split()) == 1:
            continue
        lines.append(ln)
    return "\n".join(lines).strip()


def _load_seeds():
    """Return sorted-by-id list of (id, prompt) using the same seed_long
    resolution as batch_generate.py's default --prompt-source seed_long."""
    seeds = []
    with open(SEED_FILE, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            entry = json.loads(line)
            sid = str(entry.get("id", "")).strip()
            if not sid:
                continue
            long_desc = str(entry.get("description_long") or "").strip()
            short_desc = str(entry.get("description") or "").strip()
            prompt = long_desc or short_desc
            if not prompt:
                continue
            seeds.append((sid, prompt))
    return seeds


def generate_one(sid, prompt, key):
    human = HUMAN_TEMPLATE.format(input=prompt)
    t0 = time.time()
    raw = _openrouter_invoke(MODEL, SYSTEM_PROMPT, human, key)
    code = _postprocess(raw)

    # Retry once if empty/degenerate
    if not code or not any(kw in code.lower() for kw in ("contract", "pragma")):
        strong = SYSTEM_PROMPT + " No markdown, no fences, no prose. Output Solidity code only."
        raw = _openrouter_invoke(MODEL, strong, human, key)
        code = _postprocess(raw)

    elapsed = time.time() - t0

    # Compile (with timeout — solc can hang on complex sources)
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
        "nl_prompt_source": "sol_seed_long",
        "nl_source_path": f"sol_seed.jsonl:{sid}",
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

    seeds = _load_seeds()
    print(f"Naive GLM generation: {len(seeds)} samples from {SEED_FILE.name}")
    print(f"Model: {MODEL}")
    print(f"Output: {OUT_DIR}")
    print(f"Compiler: {'available' if is_compiler_available() else 'UNAVAILABLE'}")
    print("=" * 60)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    stats = {"done": 0, "skipped": 0, "errors": 0, "valid": 0}

    for i, (sid, prompt) in enumerate(seeds, 1):
        out = OUT_DIR / sid
        if (out / "meta.json").exists():
            print(f"[{i}/{len(seeds)}] {sid}: exists, skipping")
            stats["skipped"] += 1
            continue

        print(f"[{i}/{len(seeds)}] {sid}: generating...", end=" ", flush=True)
        try:
            code, meta, err = generate_one(sid, prompt, key)
            if err:
                print(f"skip ({err})")
                stats["errors"] += 1
                continue

            out.mkdir(parents=True, exist_ok=True)
            (out / f"{sid}.sol").write_text(code + "\n", encoding="utf-8")
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
