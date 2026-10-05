#!/usr/bin/env python3
"""Convert the v1 ladder outputs into the runbook's set-level schema (runs/ladder/<lang>/<arm>/results.jsonl).

  python ecir_v3/convert_ladder.py [--langs sol,sys,mod] [--arms A0,A1,A3]
                                   [--tier-a all|pool|none] [--workers 4]

What comes from where (v1 logged neither prompts nor retrieval scores for Solidity/SysML, nor
token counts or the served provider for any language):
  compile_valid      the ladder's own verdict (sol meta validation.is_valid, sys result.compiler.passed,
                     mod metrics.modelica_build); never recomputed, so Table 1 stays the v1 numbers.
  compiler errors    sol: solc re-run on the stored .sol (v1 dropped the messages) with the PACE solc set;
                     sys: result.compiler.errors; mod: not stored (v1 kept only run.json) -> null.
  retrieval          sol/sys: the recomputed deployed lists (stage0 check: bit-identical prompts on SysML);
                     mod: run.json retrieved_examples (logged).
  gain               1 = compiles; 2 = Tier A (sol, re-run on the stored contract, Tier A only, 64 fuzz
                     runs) for --tier-a ids; mod gain 2 needs the PACE .mo artifacts (not on disk) -> null.
  status             empty_output when the ladder had no candidate (sys model_generation; sol no code).
                     Modelica requirement-normalization failures stay failures (ok, not compiled), as in v1.
"""
from __future__ import annotations

import argparse
import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from common import LADDER_SOL, LADDER_SYS, RUNS, read_ids, retrieval_lists, write_jsonl
from corpora import mod_run, requirements
from langs import compile_check, solc_class, tier2


def _sol_retrieval(rid, arm, cos):
    if arm == "A0":
        return {"exemplar_ids": [], "scores": [], "spec_chunk_ids": []}
    r = cos[rid]
    return {"exemplar_ids": r["exemplar_ids"][:5], "scores": r["scores"][:5], "spec_chunk_ids": []}


def convert_sol(arm, tier_ids, workers):
    cos = retrieval_lists("sol", "cos")
    reqs = requirements("sol")
    ids = read_ids("ladder500_sol.txt")

    def one(rid):
        d = LADDER_SOL / arm / rid
        meta = json.loads((d / "meta.json").read_text())
        code = (d / f"{rid}.sol").read_text(encoding="utf-8") if (d / f"{rid}.sol").exists() else ""
        rec = {"req_id": rid, "status": "ok" if code.strip() else "empty_output",
               "compile_valid": bool(meta["validation"]["is_valid"]),
               "n_compiler_errors": int(meta["validation"].get("error_count") or 0),
               "retrieval": _sol_retrieval(rid, arm, cos),
               "model_calls": None, "tokens_in": None, "tokens_out": None,
               "source": f"v1 ladder {arm} meta.json"}
        if code.strip():
            c = compile_check("sol", code)
            rec["compiler_error_classes"] = [solc_class(e) for e in c["errors"]]
            rec["compiler_errors"] = [{"code": e["code"], "message": e["message"][:400]} for e in c["errors"]]
            rec["rescored_compile_valid"] = c["compile_valid"]
            rec["solc"] = c.get("solc")
        else:
            rec["compiler_error_classes"] = []
        rec["gain"] = int(rec["compile_valid"])
        if rid in tier_ids and rec["compile_valid"]:
            t = tier2("sol", code, reqs[rid], Path("/tmp"))
            rec["tier2"] = t
            rec["gain"] = 2 if t["passed"] else 1
        rec["gain_level2_scored"] = rid in tier_ids
        return rec

    with ThreadPoolExecutor(workers) as ex:
        rows = list(ex.map(one, ids))
    agree = sum(r.get("rescored_compile_valid") == r["compile_valid"] for r in rows if "rescored_compile_valid" in r)
    print(f"sol {arm}: {len(rows)} rows; compile-valid {sum(r['compile_valid'] for r in rows)}; "
          f"solc rescore agrees on {agree}/{sum('rescored_compile_valid' in r for r in rows)}")
    return rows


def convert_sys(arm):
    cos = retrieval_lists("sys", "cos")
    rows = []
    for rid in read_ids("ladder500_sys.txt"):
        run = json.loads((LADDER_SYS / arm / "tasks" / rid / "run.json").read_text())
        res = run.get("result") or {}
        comp = res.get("compiler") or {}
        gen = res.get("generation") or {}
        status = "infra_error" if (run.get("infrastructure_error") or run.get("eligible") is False) else \
            ("empty_output" if gen.get("passed") is False else "ok")
        errs = comp.get("errors") or []
        r = cos[rid]
        rows.append({"req_id": rid, "status": status, "compile_valid": comp.get("passed") is True,
                     "n_compiler_errors": int(comp.get("error_count") or 0),
                     "compiler_error_classes": ["syntax" if "Syntax" in (e.get("code") or "") else
                                                "linking" if "Linking" in (e.get("code") or "") else "other"
                                                for e in errs],
                     "gain": int(comp.get("passed") is True),
                     "retrieval": {"exemplar_ids": r["exemplar_ids"][:5], "scores": r["scores"][:5],
                                   "spec_chunk_ids": r["spec_chunk_ids"][:3]},
                     "kernel_pass": (res.get("execution") or {}).get("success") is True,
                     "model_calls": None, "tokens_in": None, "tokens_out": None,
                     "source": f"v1 ladder {arm} run.json"})
    print(f"sys {arm}: {len(rows)} rows; compile-valid {sum(r['compile_valid'] for r in rows)}")
    return rows


def rescore_sys(rows, workers):
    """Same rows, compile verdict recomputed with the *current* SysML compiler on v1's final.sysml, so that
    v1 A1 and the v3 SysML runs (R2, R4) are judged by one evaluator (see analysis/sysml_evaluator_drift.json)."""
    from langs import compile_check

    def one(r):
        r = dict(r)
        f = LADDER_SYS / "A1/tasks" / r["req_id"] / "artifacts/final.sysml"
        r["compile_valid_v1"], r["n_compiler_errors_v1"] = r["compile_valid"], r["n_compiler_errors"]
        if r["status"] == "ok" and f.exists() and f.read_text(encoding="utf-8").strip():
            c = compile_check("sys", f.read_text(encoding="utf-8"))
            r.update({"compile_valid": c["compile_valid"], "n_compiler_errors": c["n_compiler_errors"],
                      "gain": int(c["compile_valid"]), "source": "v1 ladder A1 final.sysml, rescored with current compiler"})
        return r
    with ThreadPoolExecutor(workers) as ex:
        out = list(ex.map(one, rows))
    print(f"sys A1 rescored: compile-valid {sum(r['compile_valid'] for r in out)} (v1 verdict "
          f"{sum(r['compile_valid_v1'] for r in out)})")
    return out


def convert_mod(arm):
    rows = []
    for rid in read_ids("ladder500_mod.txt"):
        run = mod_run(rid, arm)
        m = run.get("metrics") or {}
        res = run.get("result") or {}
        hits = (res.get("modelica") or {}).get("retrieved_examples") or []
        status = "infra_error" if (run.get("infrastructure_error") or m.get("infrastructure_available") is False) else "ok"
        rows.append({"req_id": rid, "status": status, "compile_valid": m.get("modelica_build") is True,
                     "compile_valid_attempt0": m.get("modelica_build_attempt_0") is True,
                     "n_compiler_errors": None, "compiler_error_classes": [],
                     "gain": int(m.get("modelica_build") is True), "gain_level2_scored": False,
                     "normalization_ok": bool((res.get("normalization") or {}).get("success")),
                     "retrieval": {"exemplar_ids": [h["id"] for h in hits] if arm != "A0" else [],
                                   "scores": [h["score"] for h in hits] if arm != "A0" else [],
                                   "spec_chunk_ids": []},
                     "model_calls": None, "tokens_in": None, "tokens_out": None,
                     "source": f"v1 ladder {arm} run.json"})
    print(f"mod {arm}: {len(rows)} rows; compile-valid {sum(r['compile_valid'] for r in rows)}")
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--langs", default="sol,sys,mod")
    ap.add_argument("--arms", default="A0,A1,A3")
    ap.add_argument("--tier-a", default="pool", choices=["all", "pool", "none"],
                    help="Solidity gain level 2: all ladder IDs, only the 100 pooled IDs (A0, for U0), or none")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--rescore-sys", action="store_true",
                    help="also write runs/ladder/sys/A1_rescored (current compiler on v1 outputs)")
    a = ap.parse_args()
    for lang in a.langs.split(","):
        for arm in a.arms.split(","):
            if lang == "sys" and arm != "A1":
                continue          # SysML ladder starts at A1 (A0 is R4); A3 is not used on SysML
            if lang == "sol":
                tier = set(read_ids("ladder500_sol.txt")) if a.tier_a == "all" else \
                    set(read_ids("pool100_sol.txt")) if (a.tier_a == "pool" and arm == "A0") else set()
                rows = convert_sol(arm, tier, a.workers)
            elif lang == "sys":
                rows = convert_sys(arm)
                if a.rescore_sys:
                    write_jsonl(RUNS / "ladder" / "sys" / "A1_rescored" / "results.jsonl", rescore_sys(rows, a.workers))
            else:
                rows = convert_mod(arm)
            write_jsonl(RUNS / "ladder" / lang / arm / "results.jsonl", rows)


if __name__ == "__main__":
    main()
