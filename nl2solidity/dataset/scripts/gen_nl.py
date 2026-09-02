#!/usr/bin/env python3
"""Generate the natural-language side (<id>.txt) for each Solidity sample.

Mirrors script/gen_NL_SysML_v2_Models.py, retargeted to Solidity and routed
through OpenRouter. Resumable: samples that already have a .txt are skipped.
"""
from __future__ import annotations

import json
import os
import sys
import threading
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from dotenv import load_dotenv

DATA = Path(__file__).resolve().parents[1] / "data"
ROOT = Path(__file__).resolve().parents[3]
MODEL = os.getenv("NL_MODEL", "google/gemini-2.5-flash")
PARALLEL = int(os.getenv("NL_PARALLEL", "12"))
MAX_CODE_CHARS = 24000

PROMPT = """Describe, in natural language, the smart contract this Solidity source implements. Write it as a requirement a developer could hand to someone asking them to build this contract - describe what the contract does on-chain, not how the file is written.

Cover: the purpose of the contract, the state it maintains, the main functions/operations callers can perform, access control and permissions, important events, and any notable mechanics (fees, math, upgradeability, security guards, integrations with other protocols).

Good example style:
"This is an escrow contract that holds ETH on behalf of a buyer until a purchase is settled. The contract records the buyer, the seller, and a neutral arbiter at deployment, and tracks whether the deposit is still held, released, or refunded. The buyer funds the escrow once, after which only the arbiter may either release the balance to the seller or refund it to the buyer; every other caller is rejected. Each state change emits an event so off-chain services can follow the lifecycle, and the contract guards against re-entrancy by updating its state before transferring funds."

Rules:
- One flowing description, 120-220 words. No bullet lists, no markdown, no headings.
- Do not mention Solidity version, imports, file layout, or "this code/file".
- Do not invent behavior that is not implemented.

Solidity source:
{content}

Description:"""

_lock = threading.Lock()
_done = {"ok": 0, "skip": 0, "fail": 0}


def call_llm(prompt: str, api_key: str, base: str) -> str:
    body = json.dumps({
        "model": MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.3,
        "max_tokens": 600,
    }).encode()
    req = urllib.request.Request(
        base.rstrip("/") + "/chat/completions",
        data=body,
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"},
    )
    with urllib.request.urlopen(req, timeout=180) as r:
        d = json.load(r)
    return (d["choices"][0]["message"]["content"] or "").strip()


def generate_for(did: str, api_key: str, base: str) -> str:
    d = DATA / did
    sol, txt = d / f"{did}.sol", d / f"{did}.txt"
    if txt.exists() and txt.stat().st_size > 200:
        return "skip"
    code = sol.read_text(encoding="utf-8")[:MAX_CODE_CHARS]
    for attempt in range(4):
        try:
            out = call_llm(PROMPT.format(content=code), api_key, base)
            if len(out) < 150:
                raise ValueError(f"short response ({len(out)} chars)")
            txt.write_text(out + "\n", encoding="utf-8")
            return "ok"
        except Exception as e:
            if attempt == 3:
                print(f"FAIL {did}: {str(e)[:160]}", flush=True)
                return "fail"
            time.sleep(3 * (attempt + 1))
    return "fail"


def main():
    load_dotenv(ROOT / ".env")
    api_key = os.getenv("OPENROUTER_API_KEY")
    base = os.getenv("OPENROUTER_BASE_URL") or "https://openrouter.ai/api/v1"
    if not api_key:
        sys.exit("OPENROUTER_API_KEY not set")
    ids = sorted(p.name for p in DATA.iterdir() if p.is_dir())
    total = len(ids)
    print(f"generating NL for {total} samples with {MODEL} ({PARALLEL} workers)", flush=True)
    start = time.time()
    with ThreadPoolExecutor(max_workers=PARALLEL) as ex:
        futs = {ex.submit(generate_for, i, api_key, base): i for i in ids}
        for n, f in enumerate(as_completed(futs), 1):
            with _lock:
                _done[f.result()] += 1
            if n % 50 == 0:
                el = time.time() - start
                print(f"{n}/{total} ok={_done['ok']} skip={_done['skip']} fail={_done['fail']} "
                      f"({el:.0f}s, eta {el / n * (total - n):.0f}s)", flush=True)
    print(f"done: {_done}", flush=True)


if __name__ == "__main__":
    main()
