#!/usr/bin/env python3
"""Measure real OpenRouter spend per GLM-5.2 generation before committing to the extra runs.

Sends a few representative generations of every call type the runbook uses (A0 one-shot,
A1 k=5 retrieval, k=1 single-exemplar pair) for SysML v2, Solidity and Modelica, with the
same request shape as production (`agent_rag_moe._openrouter_invoke_once`): model
z-ai/glm-5.2, temperature 0.2, max_completion_tokens 32768, no `reasoning` field (provider
default, so reasoning is on and billed), no provider pinning.

Spend is measured three ways so they can cross-check each other:
  1. account balance before vs after (GET /api/v1/credits, falls back to /api/v1/key usage)
  2. `usage.cost` returned on each response
  3. `total_cost` from GET /api/v1/generation?id=... for each call

The per-type averages are then extrapolated to the runbook call mix (RUNBOOK_MIX below).

Examples
--------
    # build prompts and print their sizes, no API calls, no spend
    .venv/bin/python analysis/openrouter_cost_probe.py --dry-run

    # 3 generations of each of the 9 call types (27 calls, roughly $1)
    .venv/bin/python analysis/openrouter_cost_probe.py --n 3

    # re-read the balance later (billing can lag) and recompute against the saved run
    .venv/bin/python analysis/openrouter_cost_probe.py --recheck analysis/cost_probe_results/<file>.json
"""

from __future__ import annotations

import argparse
import json
import os
import random
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path

_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_ROOT))
sys.path.insert(0, str(_ROOT / "nl2sysml"))

try:
    from dotenv import load_dotenv
    load_dotenv(_ROOT / ".env")
except ImportError:
    pass

MODEL = "z-ai/glm-5.2"
BASE = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
TEMPERATURE = 0.2
MAX_COMPLETION_TOKENS = int(os.getenv("OPENROUTER_MAX_TOKENS", "32768"))
OUT_DIR = _ROOT / "analysis" / "cost_probe_results"
SYSML_EXEMPLAR_CHARS = 3000

# Runbook call counts mapped onto the probe's call types. Edit these if the runbook changes.
# U0 (400 extra A0 samples) and the k=1 runs (U1, U2) are split evenly across the languages
# they cover; R7 is treated as A1 k=5 calls spread over the three languages.
RUNBOOK_MIX = {
    "core": {
        "solidity_A1k5": 500 + 500,            # R1 + R2 share
        "modelica_A1k5": 500 + 500,            # R1b + R2 share
        "sysml_A1k5": 500,                     # R2 share
        "sysml_A0": 500 + 400 / 3,             # R4 + U0 share
        "solidity_A0": 400 / 3,                # U0 share
        "modelica_A0": 400 / 3,                # U0 share
        "solidity_k1": (2500 + 250) / 2,       # U1 + U2
        "modelica_k1": (2500 + 250) / 2,       # U1 + U2
    },
    "R7": {
        "sysml_A1k5": 266,
        "solidity_A1k5": 266,
        "modelica_A1k5": 266,
    },
}
CALL_TYPES = ["sysml_A0", "sysml_A1k5", "sysml_k1",
              "solidity_A0", "solidity_A1k5", "solidity_k1",
              "modelica_A0", "modelica_A1k5", "modelica_k1"]


# ---------------------------------------------------------------- prompt sources

def _sysml_items():
    """(requirement, code) pairs from the full-pipeline SysML corpus."""
    from naive_glm_generate import SYSTEM_PROMPT, HUMAN_TEMPLATE  # nl2sysml
    items = []
    for d in sorted((_ROOT / "dataset" / "with_kernel_spec").iterdir()):
        req, code = d / f"{d.name}.txt", d / f"{d.name}.sysml"
        if req.exists() and code.exists():
            # Capped so a k=5 prompt lands near the 22.3k chars measured for the saved v1 A1 prompts.
            items.append((req.read_text(errors="ignore").strip(),
                          code.read_text(errors="ignore")[:SYSML_EXEMPLAR_CHARS]))
    return SYSTEM_PROMPT, HUMAN_TEMPLATE, items


def _solidity_items():
    """(requirement, code) pairs; exemplar code truncated to 80 lines as in the v1 ladder."""
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "sol_naive", _ROOT / "nl2solidity" / "naive_glm_generate.py")
    sol = importlib.util.module_from_spec(spec)
    sys.path.insert(0, str(_ROOT / "nl2solidity"))
    spec.loader.exec_module(sol)
    seeds = dict(sol._load_seeds())
    items = []
    for f in sorted((_ROOT / "nl2solidity" / "dataset" / "data").glob("*/*.sol")):
        meta = f.parent / "meta.json"
        req = None
        if meta.exists():
            try:
                m = json.loads(meta.read_text())
                req = m.get("prompt") or m.get("description") or seeds.get(str(m.get("id")))
            except Exception:
                pass
        code = "\n".join(f.read_text(errors="ignore").splitlines()[:80])
        items.append((req or "", code))
    reqs = list(seeds.values())
    return sol.SYSTEM_PROMPT, sol.HUMAN_TEMPLATE, items, reqs


def _format_exemplars(lang: str, exemplars) -> str:
    blocks = []
    for i, (req, code) in enumerate(exemplars, 1):
        head = f"Example {i}:\n" + (f"Requirement: {req}\n" if req else "")
        blocks.append(f"{head}{lang}:\n{code.strip()}")
    return "\n\n".join(blocks)


def build_prompts(n: int, seed: int):
    """Return [(call_type, system, human)] with n prompts per call type."""
    rng = random.Random(seed)
    out = []

    sys_s, tmpl_s, sysml = _sysml_items()
    for _ in range(n):
        req, *_ = rng.choice(sysml)
        out.append(("sysml_A0", sys_s, tmpl_s.format(input=req)))
        for k, ct in ((5, "sysml_A1k5"), (1, "sysml_k1")):
            target = rng.choice(sysml)
            ex = rng.sample([x for x in sysml if x is not target], k)
            out.append((ct, sys_s, f"Retrieved examples:\n{_format_exemplars('SysML', ex)}\n\n"
                                   + tmpl_s.format(input=target[0])))

    sys_o, tmpl_o, sol, sol_reqs = _solidity_items()
    for _ in range(n):
        out.append(("solidity_A0", sys_o, tmpl_o.format(input=rng.choice(sol_reqs))))
        for k, ct in ((5, "solidity_A1k5"), (1, "solidity_k1")):
            ex = rng.sample(sol, k)
            out.append((ct, sys_o, f"Retrieved examples:\n{_format_exemplars('Solidity', ex)}\n\n"
                                   + tmpl_o.format(input=rng.choice(sol_reqs))))

    from nl2robotics.modelica.pipeline import ModelicaPipeline
    pipe = ModelicaPipeline()
    cases = json.loads((_ROOT / "nl2robotics" / "corpus" / "pipeline_prompt_manifest.json")
                       .read_text())["cases"]
    mreqs = [c["request"] for c in cases if c.get("request")]
    for _ in range(n):
        s, h = pipe.build_baseline_messages(rng.choice(mreqs))
        out.append(("modelica_A0", s, h))
        for k, ct in ((5, "modelica_A1k5"), (1, "modelica_k1")):
            s, h, _hits = pipe.build_messages(rng.choice(mreqs), k=k)
            out.append((ct, s, h))
    return out


# ---------------------------------------------------------------- OpenRouter

def _key() -> str:
    key = os.getenv("OPENROUTER_API_KEY")
    if not key:
        sys.exit("OPENROUTER_API_KEY not set (looked in environment and .env)")
    return key


def _get(path: str):
    req = urllib.request.Request(f"{BASE}{path}", headers={"Authorization": f"Bearer {_key()}"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def balance_snapshot() -> dict:
    snap = {"time": datetime.now().isoformat(timespec="seconds")}
    try:
        d = _get("/credits")["data"]
        snap["total_credits"] = d.get("total_credits")
        snap["total_usage"] = d.get("total_usage")
        snap["balance"] = (d["total_credits"] - d["total_usage"]
                           if d.get("total_credits") is not None else None)
    except Exception as e:
        snap["credits_error"] = str(e)
    try:
        d = _get("/key")["data"]
        snap["key_usage"] = d.get("usage")
        snap["key_limit_remaining"] = d.get("limit_remaining")
    except Exception as e:
        snap["key_error"] = str(e)
    return snap


def call(call_type: str, system: str, human: str) -> dict:
    payload = {
        "model": MODEL,
        "messages": [{"role": "system", "content": system}, {"role": "user", "content": human}],
        "temperature": TEMPERATURE,
        "max_completion_tokens": MAX_COMPLETION_TOKENS,
    }
    req = urllib.request.Request(
        f"{BASE}/chat/completions", data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {_key()}",
                 "HTTP-Referer": os.getenv("HTTP_REFERER", "https://localhost"),
                 "X-Title": os.getenv("APP_TITLE", "Creatix Agent") + " cost-probe"})
    rec = {"call_type": call_type, "prompt_chars": len(system) + len(human)}
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            obj = json.loads(r.read())
    except urllib.error.HTTPError as e:
        rec["error"] = f"HTTP {e.code}: {e.read().decode(errors='ignore')[:300]}"
        return rec
    except Exception as e:
        rec["error"] = str(e)
        return rec
    rec["seconds"] = round(time.time() - t0, 1)
    if obj.get("error"):
        rec["error"] = str(obj["error"])[:300]
        return rec
    u = obj.get("usage") or {}
    rec.update({
        "id": obj.get("id"),
        "provider": obj.get("provider"),
        "finish_reason": (obj.get("choices") or [{}])[0].get("finish_reason"),
        "prompt_tokens": u.get("prompt_tokens"),
        "completion_tokens": u.get("completion_tokens"),
        "reasoning_tokens": (u.get("completion_tokens_details") or {}).get("reasoning_tokens"),
        "usage_cost": u.get("cost"),
        "output_chars": len(((obj.get("choices") or [{}])[0].get("message") or {}).get("content") or ""),
    })
    return rec


def attach_generation_costs(records):
    """Fill `generation_cost` from /generation; it can take a few seconds to appear."""
    for rec in records:
        if not rec.get("id"):
            continue
        for _ in range(5):
            try:
                rec["generation_cost"] = _get(f"/generation?id={rec['id']}")["data"].get("total_cost")
                break
            except Exception:
                time.sleep(3)


# ---------------------------------------------------------------- report

def _avg(xs):
    xs = [x for x in xs if isinstance(x, (int, float))]
    return sum(xs) / len(xs) if xs else None


def _cost(rec):
    for k in ("generation_cost", "usage_cost"):
        if isinstance(rec.get(k), (int, float)):
            return rec[k]
    return None


def report(result: dict) -> str:
    recs = [r for r in result["records"] if not r.get("error")]
    lines = []
    b0, b1 = result["balance_before"], result.get("balance_after", {})
    spent_balance = None
    if b0.get("balance") is not None and b1.get("balance") is not None:
        spent_balance = b0["balance"] - b1["balance"]
    elif b0.get("key_usage") is not None and b1.get("key_usage") is not None:
        spent_balance = b1["key_usage"] - b0["key_usage"]
    summed = sum(c for c in map(_cost, recs) if c is not None)
    errs = len(result["records"]) - len(recs)

    lines.append(f"Model {MODEL} | {len(recs)} successful calls, {errs} failed")
    lines.append(f"Balance before: {b0.get('balance', b0.get('key_usage'))}   after: "
                 f"{b1.get('balance', b1.get('key_usage'))}")
    if spent_balance is not None:
        lines.append(f"Spent per balance diff:  ${spent_balance:.4f}  "
                     f"(${spent_balance / max(len(recs), 1):.4f} per generation)")
    lines.append(f"Spent per summed cost:   ${summed:.4f}  "
                 f"(${summed / max(len(recs), 1):.4f} per generation)")
    lines.append("")
    hdr = f"{'call type':16s} {'n':>3s} {'in tok':>7s} {'out tok':>8s} {'reason':>7s} {'$/call':>8s}  providers"
    lines.append(hdr)
    lines.append("-" * len(hdr))
    per_type = {}
    for ct in CALL_TYPES:
        rs = [r for r in recs if r["call_type"] == ct]
        if not rs:
            continue
        c = _avg([_cost(r) for r in rs])
        per_type[ct] = c
        provs = ",".join(sorted({str(r.get("provider")) for r in rs}))
        fmt = lambda v: f"{v:,.0f}" if v is not None else "-"
        lines.append(f"{ct:16s} {len(rs):3d} {fmt(_avg([r['prompt_tokens'] for r in rs])):>7s} "
                     f"{fmt(_avg([r['completion_tokens'] for r in rs])):>8s} "
                     f"{fmt(_avg([r['reasoning_tokens'] for r in rs])):>7s} "
                     f"{('$%.4f' % c) if c is not None else '-':>8s}  {provs}")

    # Scale per-call costs so their total matches the balance diff, if we have one.
    scale = spent_balance / summed if spent_balance and summed else 1.0
    lines.append("")
    lines.append("Extrapolated to the runbook mix" +
                 (f" (per-call costs scaled x{scale:.2f} to match the balance diff)" if scale != 1.0 else ""))
    for name, mix in RUNBOOK_MIX.items():
        total, calls, missing = 0.0, 0, []
        for ct, count in mix.items():
            if per_type.get(ct) is None:
                missing.append(ct)
                continue
            total += per_type[ct] * scale * count
            calls += count
        lines.append(f"  {name:5s}: {calls:,.0f} calls  ->  ${total:,.2f}"
                     + (f"   (no data for {', '.join(missing)})" if missing else ""))
    return "\n".join(lines)


# ---------------------------------------------------------------- main

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--n", type=int, default=3, help="generations per call type (9 types; default 3)")
    ap.add_argument("--types", nargs="+", choices=CALL_TYPES, default=CALL_TYPES)
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--settle", type=int, default=30,
                    help="seconds to wait after the last call before reading the balance again")
    ap.add_argument("--dry-run", action="store_true", help="build prompts, print sizes, make no calls")
    ap.add_argument("--recheck", type=Path, help="re-read the balance for a saved run and reprint the report")
    args = ap.parse_args(argv)

    if args.recheck:
        result = json.loads(args.recheck.read_text())
        result["balance_after"] = balance_snapshot()
        args.recheck.write_text(json.dumps(result, indent=2))
        print(report(result))
        return 0

    prompts = [p for p in build_prompts(args.n, args.seed) if p[0] in args.types]
    if args.dry_run:
        for ct in args.types:
            sizes = [len(s) + len(h) for c, s, h in prompts if c == ct]
            print(f"{ct:16s} n={len(sizes)}  prompt ~{_avg(sizes) / 3.5:,.0f} tokens "
                  f"({_avg(sizes):,.0f} chars)")
        print(f"\n{len(prompts)} calls would be made.")
        return 0

    before = balance_snapshot()
    print(f"Balance before: {before}")
    print(f"Sending {len(prompts)} calls to {MODEL} with {args.workers} workers...")
    records = []
    with ThreadPoolExecutor(args.workers) as pool:
        for rec in pool.map(lambda p: call(*p), prompts):
            records.append(rec)
            status = rec.get("error") or (f"in={rec['prompt_tokens']} out={rec['completion_tokens']} "
                                          f"reason={rec['reasoning_tokens']} ${rec['usage_cost']}")
            print(f"  [{len(records)}/{len(prompts)}] {rec['call_type']:14s} {status}")

    attach_generation_costs(records)
    print(f"Waiting {args.settle}s for billing to settle...")
    time.sleep(args.settle)
    result = {"model": MODEL, "temperature": TEMPERATURE,
              "max_completion_tokens": MAX_COMPLETION_TOKENS, "n_per_type": args.n,
              "balance_before": before, "balance_after": balance_snapshot(), "records": records}

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / f"probe_{datetime.now():%Y%m%d_%H%M%S}.json"
    out.write_text(json.dumps(result, indent=2))
    print()
    print(report(result))
    print(f"\nSaved {out}\nIf the balance diff looks short, rerun later with --recheck {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
