#!/usr/bin/env python3
"""Summarize a SysMLAgent run directory (gates 7.2 / 7.3 and the full run).

Reads <run>/<ID>/meta.json + transcript.json and reports: converged (ANTLR-valid) rate, ANTLR-valid
at iter-0 (= LLM_Raw+RAG) and after fix round 1, fix-round distribution, calls per seed, the
ANTLR-valid and compile-valid curves by iteration (a seed that stopped earlier carries its last
candidate forward), billed cost and walltime, and a projection to the full 1,543 prompts.

    python nl2sysml/sysml_agent/summarize.py dataset/sysml_agent_pilot [--shards 5 --workers 8]
"""

from __future__ import annotations

import argparse
import json
import statistics as st
import sys
from collections import Counter
from pathlib import Path

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(_HERE.parent))

import best_of_n_generate as bon  # noqa: E402


def load(d: Path) -> list[dict]:
    out = []
    for mp in sorted(d.glob("*/meta.json")):
        m = json.loads(mp.read_text(encoding="utf-8"))
        if "sysml_agent" in m:
            m["_tr"] = json.loads((mp.parent / "transcript.json").read_text(encoding="utf-8"))
            out.append(m)
    return out


def at(its: list, j: int):
    return its[min(j, len(its) - 1)]


def summarize(d: Path, n_full: int = 1543, shards: int = 5, workers: int = 8) -> dict:
    runs = load(d)
    n = len(runs)
    if not n:
        return {"run": str(d), "n": 0}
    its = [r["_tr"]["iterations"] for r in runs]
    rounds = [r["sysml_agent"]["n_fix_rounds"] for r in runs]
    calls = [r["sysml_agent"]["n_calls"] for r in runs]
    cap = max(r["sysml_agent"]["max_fix_rounds"] for r in runs)
    has_compile = all(i[0].get("compile") for i in its)
    pct = lambda k: round(100 * k / n, 1)  # noqa: E731
    curve = {"antlr_valid_pct": [pct(sum(at(i, j)["antlr"]["valid"] for i in its)) for j in range(cap + 1)]}
    if has_compile:
        curve["compile_valid_pct"] = [pct(sum(bool(at(i, j)["compile"]["is_valid"]) for i in its))
                                      for j in range(cap + 1)]
        curve["mean_unique_compile_errors"] = [
            round(st.mean(bon.dedup_error_count(at(i, j)["compile"]["errors"]) for i in its), 2)
            for j in range(cap + 1)]
    cost = [sum(float((i.get("usage") or {}).get("cost") or 0) for i in r["_tr"]["iterations"]) for r in runs]
    toks = [r["sysml_agent"]["tokens"]["total_tokens"] for r in runs]
    wall = [r["elapsed_sec"] for r in runs]
    gen = [r["sysml_agent"]["gen_elapsed_sec"] or 0 for r in runs]
    out = {
        "run": str(d), "n": n, "backbone": runs[0]["sysml_agent"]["backbone"],
        "rag": runs[0]["sysml_agent"]["rag"],
        "converged_pct": pct(sum(r["sysml_agent"]["converged"] for r in runs)),
        "antlr_valid_iter0_pct": curve["antlr_valid_pct"][0],
        "antlr_valid_iter1_pct": curve["antlr_valid_pct"][min(1, cap)],
        "fix_rounds_distribution": dict(sorted(Counter(rounds).items())),
        "calls_per_seed": {"mean": round(st.mean(calls), 2), "median": st.median(calls), "max": max(calls)},
        "curve_by_iter": curve,
        "empty_final": sum(r["empty_output"] for r in runs),
        "antlr_timeouts": sum(any(r["sysml_agent"]["antlr_timeout_by_iter"]) for r in runs),
        "tokens_per_seed_mean": round(st.mean(toks)),
        "cost_usd": {"total": round(sum(cost), 4), "per_seed": round(st.mean(cost), 5)},
        "walltime_sec_per_seed": {"mean": round(st.mean(wall), 1), "median": round(st.median(wall), 1),
                                  "max": max(wall), "llm_loop_mean": round(st.mean(gen), 1)},
    }
    if has_compile:
        out["compile_valid_final_pct"] = curve["compile_valid_pct"][-1]
    out["projection_full"] = {
        "n": n_full, "cost_usd": round(st.mean(cost) * n_full, 2),
        "walltime_hours": round(st.mean(wall) * n_full / (shards * workers) / 3600, 2),
        "assumes": f"{shards} shards x {workers} seeds in flight, pilot's mean seed time",
    }
    return out


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("runs", type=Path, nargs="+")
    ap.add_argument("--shards", type=int, default=5)
    ap.add_argument("--workers", type=int, default=8)
    a = ap.parse_args()
    for d in a.runs:
        print(json.dumps(summarize(d, shards=a.shards, workers=a.workers), indent=1))
