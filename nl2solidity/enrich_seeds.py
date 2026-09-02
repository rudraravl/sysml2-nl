#!/usr/bin/env python3
"""Add `description_long` to every seed in sol_seed.jsonl.

Why: the shallow one-line seeds state no facts, so a twin-blind alignment check
degenerates - the NL answerer can only say `not_stated`, and similarity collapses
onto the `extra_in_model` credit (measured: 91/192 entries scored exactly 0.8500).
A scorable NL side needs committed facts.

Grounding, and what is deliberately NOT used:
  * USED:     the protocol title, its domain, and the protocol description
              harvested from the public DefiLlama catalog - all external to this
              repository.
  * NOT USED: nl2solidity/dataset (the RAG retrieval corpus). Grounding a prompt
              in a corpus sample would let retrieval return the very contract the
              prompt describes.
  * NOT USED: any previously generated contract. Deriving a spec from generated
              output makes alignment circular: the spec inherits the generator's
              omissions, so a model is scored against a specification quietly
              lowered to match what it already produced.

The spec is therefore written before any contract exists, from an external
description of what the real protocol does.

Resumable: seeds that already carry a description_long are skipped.
"""
from __future__ import annotations

import json
import os
import sys
import threading
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from dotenv import load_dotenv

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
SEED_PATH = HERE / "sol_seed.jsonl"
MODEL = os.getenv("SEED_MODEL", "google/gemini-2.5-flash")
PARALLEL = int(os.getenv("SEED_PARALLEL", "12"))

PROMPT = """Write a build-ready specification for a smart contract, as a product owner would hand it to a Solidity developer.

Context for you only - the real protocol this is modeled on:
  Name: {title}
  Category: {domain}
  What it does: {description}

Write 4-6 sentences covering, in this order:
1. What the contract is for and what it custodies, if anything.
2. The state it maintains (per-account records, pools, positions, configuration).
3. The operations callers can perform, naming them as actions.
4. Who is privileged and what only they may do.
5. At least two concrete, checkable facts: a limit, a fee, a delay, a ratio, a cap, or a required ordering. Invent plausible specific values where the context is vague - the specification must be decidable, not aspirational.
6. What the contract announces to observers.

Hard rules - these are checked automatically and violations are regenerated:
- Do NOT name the real protocol, its token ticker, or its company. Describe the mechanism generically ("a liquid staking contract", not "Lido").
- Do NOT name ANY third-party protocol, product, or company anywhere, including integrations and dependencies. Describe them by what they are: say "an external price oracle" not "Chainlink"; "a concentrated-liquidity pool" not "Uniswap V3"; "an interest-bearing deposit receipt token" not "an Aave aToken"; "a multi-signature wallet" not "Safe".
- Do NOT write code identifiers. No function names, no camelCase or snake_case names, no parentheses after a verb. Write "callers can withdraw their deposit", never "callers can withdraw()" or "the setFee function".
- Do NOT write Solidity type or keyword names: no uint256, address, mapping, bytes32, msg.sender, payable, modifier.
- Do NOT use any markdown: no backticks, no asterisks, no bold, no bullets, no headings.
- Refer to roles in plain words in lower case ("the owner", "a designated operator"), never as a quoted or capitalized identifier.
- Every sentence must state something a reader could later check against an implementation. No marketing language, no "secure and efficient", no goals without mechanisms.
- One paragraph of flowing prose.

Specification:"""

_lock = threading.Lock()
_stats = {"ok": 0, "skip": 0, "fail": 0}


def call_llm(prompt: str, api_key: str, base: str) -> str:
    body = json.dumps({
        "model": MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.4,
        "max_tokens": 700,
    }).encode()
    req = urllib.request.Request(
        base.rstrip("/") + "/chat/completions", data=body,
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"},
    )
    with urllib.request.urlopen(req, timeout=180) as r:
        return (json.load(r)["choices"][0]["message"]["content"] or "").strip()


def enrich(rec: dict, api_key: str, base: str) -> str:
    if rec.get("description_long") and len(rec["description_long"]) > 200:
        return "skip"
    # hand-written seeds carry their own spec; harvested ones carry DefiLlama's
    grounding = rec.get("source_description") or rec.get("description", "")
    prompt = PROMPT.format(title=rec.get("source_title", "a protocol"),
                           domain=rec.get("domain", "defi"),
                           description=grounding)
    for attempt in range(4):
        try:
            out = call_llm(prompt, api_key, base)
            if len(out) < 250:
                raise ValueError(f"too short ({len(out)} chars)")
            rec["description_long"] = " ".join(out.split())
            return "ok"
        except Exception as e:
            if attempt == 3:
                print(f"FAIL {rec['id']}: {str(e)[:140]}", flush=True)
                return "fail"
            time.sleep(3 * (attempt + 1))
    return "fail"


def main():
    load_dotenv(ROOT / ".env")
    api_key = os.getenv("OPENROUTER_API_KEY")
    base = os.getenv("OPENROUTER_BASE_URL") or "https://openrouter.ai/api/v1"
    if not api_key:
        sys.exit("OPENROUTER_API_KEY not set")

    records = [json.loads(l) for l in SEED_PATH.read_text(encoding="utf-8").splitlines() if l.strip()]
    print(f"enriching {len(records)} seeds with {MODEL} ({PARALLEL} workers)", flush=True)
    start = time.time()
    with ThreadPoolExecutor(max_workers=PARALLEL) as ex:
        futs = {ex.submit(enrich, r, api_key, base): r["id"] for r in records}
        for n, f in enumerate(as_completed(futs), 1):
            with _lock:
                _stats[f.result()] += 1
            if n % 100 == 0:
                el = time.time() - start
                print(f"{n}/{len(records)} {_stats} ({el:.0f}s, eta {el/n*(len(records)-n):.0f}s)",
                      flush=True)

    order = ["id", "description", "description_long", "source_title", "domain",
             "provenance", "source_description"]
    with open(SEED_PATH, "w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps({k: r[k] for k in order if k in r}, ensure_ascii=False) + "\n")
    print(f"done: {_stats} -> {SEED_PATH}", flush=True)


if __name__ == "__main__":
    main()
