#!/usr/bin/env python3
"""Single-call generation runs for the v3 paper (R1, R1b, R2, R4, U0, U1, U2, R7).

  python ecir_v3/generate.py preflight [--probe]          toolchains, key, providers (--probe: 1 paid call)
  python ecir_v3/generate.py R1                           Solidity A1, BM25 + lineage diversity
  python ecir_v3/generate.py R1b                          Modelica A1, binary cosine
  python ecir_v3/generate.py R2 --lang sys|sol|mod        A1 with 5 random exemplars (+3 spec chunks, sys)
  python ecir_v3/generate.py R4                           SysML v2 A0
  python ecir_v3/generate.py U0 --lang sol|mod            A0 samples on pool100 (sample 1 = v1 output)
  python ecir_v3/generate.py U1 --lang sol|mod            one k=1 generation per pooled exemplar
  python ecir_v3/generate.py labels --lang sol|mod        assemble runs/U1/<lang>/labels.jsonl (needs U0)
  python ecir_v3/generate.py U2 --lang sol|mod            second sample on 10% of U1 pairs (seed 0)
  python ecir_v3/generate.py R7 --lang sol|mod            A1 with runs/R7/<lang>/top5.jsonl

Provider: OpenRouter default routing, as in the existing generation pipelines (the served provider
is logged per call). --provider P pins one provider with allow_fallbacks=false.
Common flags: --workers N, --limit N (first N jobs, for pilots), --dry-run (write prompts, no calls),
--no-gain2 (compile validity only), --v1-mod-artifacts DIR (U0 Modelica sample 1 from PACE).

Every run writes runs/<task>/<lang>/<condition>/{outputs/,logs/,results.jsonl,run_meta.json}.
Resumable: jobs whose log already holds status ok/empty_output are not re-run; infra errors are
retried (3 attempts per invocation) and then recorded as infra_error, excluded from pairs.
"""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import os
import random
import statistics
import subprocess
import sys
import threading
import time
import traceback
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from pathlib import Path

from common import (EXT, LADDER_SOL, MODEL, REPO, RETR, RUNS, TEMPERATURE, git_commit, load_env,
                    read_ids, read_jsonl, req_seed, retrieval_lists, write_json, write_jsonl)
from corpora import exemplars, requirements
import langs as L
from llm import InfraError, OutOfCredits, chat, credits, endpoints

INFRA_ATTEMPTS = 3
ABORT = threading.Event()          # set on HTTP 402, balance below --min-balance, or --max-cost reached
ABORT_WHY = []
SPENT = [0.0]
SPENT_LOCK = threading.Lock()


def _abort(why):
    if not ABORT.is_set():
        ABORT_WHY.append(why)
        print(f"!! ABORT: {why}", flush=True)
    ABORT.set()


def _credit_watch(args, stop):
    """Poll the OpenRouter balance; log it (analysis/spend_log.jsonl) and abort below the floor."""
    from common import WORK
    path = WORK / "analysis" / "spend_log.jsonl"
    path.parent.mkdir(parents=True, exist_ok=True)
    while not stop.wait(args.credit_poll):
        try:
            c = credits()
        except Exception as e:
            print(f"  (credit poll failed: {e})", flush=True); continue
        with path.open("a") as f:
            f.write(json.dumps({"t": dt.datetime.now(dt.timezone.utc).isoformat(), "remaining": round(c["remaining"], 4),
                                "total_usage": c["total_usage"], "run": sys.argv[1:], "spent_this_run": round(SPENT[0], 4)}) + "\n")
        if c["remaining"] < args.min_balance:
            _abort(f"OpenRouter balance ${c['remaining']:.2f} below floor ${args.min_balance:.2f}")


@dataclass
class Job:
    task: str
    lang: str
    cond: str
    req_id: str
    key: str                       # output stem: <req_id>[__<exemplar_id>|__s<k>]
    ex_ids: list = field(default_factory=list)
    spec_ids: list = field(default_factory=list)
    scores: list = field(default_factory=list)
    extra: dict = field(default_factory=dict)
    code_from: Path | None = None  # reuse an existing program instead of calling the model

    @property
    def root(self) -> Path:
        return RUNS / self.task / self.lang / self.cond


# ---------------------------------------------------------------- job lists
def _top5(lang, name, ids):
    lists = retrieval_lists(lang, name)
    return {i: lists[i] for i in ids}


def jobs_for(task, lang, args) -> list[Job]:
    J = []
    if task in ("R1", "R1b"):
        name = "bm25" if task == "R1" else "cos"
        for rid, r in _top5(lang, name, read_ids(f"ladder500_{lang}.txt")).items():
            J.append(Job(task, lang, f"A1{name}", rid, rid, r["exemplar_ids"][:5], [], r["scores"][:5]))
    elif task == "R2":
        allx = [e.id for e in exemplars(lang)]
        spec = None
        if lang == "sys":
            from retrievers import spec_ids
            spec = spec_ids()
        for rid in read_ids(f"ladder500_{lang}.txt"):
            rng = random.Random(req_seed(rid))
            J.append(Job(task, lang, "A1rand", rid, rid, rng.sample(allx, 5),
                         rng.sample(spec, 3) if spec else []))
    elif task == "R4":
        for rid in read_ids("ladder500_sys.txt"):
            J.append(Job(task, lang, "A0", rid, rid))
    elif task == "U0":
        for rid in read_ids(f"pool100_{lang}.txt"):
            for k in (1, 2, 3):
                j = Job(task, lang, "A0", rid, f"{rid}__s{k}", extra={"sample": k})
                if k == 1:
                    j.code_from = _v1_a0(lang, rid, args)
                    j.extra["source"] = "v1 ladder A0" if j.code_from else "fresh (v1 program not on disk)"
                J.append(j)
    elif task == "U1":
        for row in read_jsonl(RETR / lang / "pool.jsonl"):
            for it in row["pool"]:
                J.append(Job(task, lang, "k1", row["req_id"], f"{row['req_id']}__{it['exemplar_id']}",
                             [it["exemplar_id"]], extra={"random": it["random"], "ranks": it["ranks"]}))
    elif task == "U2":
        pairs = sorted((r["req_id"], r["exemplar_id"]) for r in read_jsonl(RUNS / "U1" / lang / "k1" / "results.jsonl")
                       if r.get("status") != "infra_error")
        if not pairs:
            raise SystemExit("U2 needs finished U1 results")
        pick = random.Random(0).sample(pairs, max(1, round(0.10 * len(pairs))))
        for rid, x in sorted(pick):
            J.append(Job(task, lang, "k1", rid, f"{rid}__{x}", [x]))
    elif task == "R7":
        top = {r["req_id"]: r for r in read_jsonl(RUNS / "R7" / lang / "top5.jsonl")}
        if not top:
            raise SystemExit(f"R7 needs runs/R7/{lang}/top5.jsonl (forge_ecir_tools.py rerank-apply)")
        for rid in read_ids(f"heldout400_{lang}.txt"):
            J.append(Job(task, lang, "A1rerank", rid, rid, top[rid]["exemplar_ids"][:5], [],
                         top[rid]["scores"][:5]))
    else:
        raise SystemExit(f"unknown task {task}")
    return J[: args.limit] if args.limit else J


def _v1_a0(lang, rid, args) -> Path | None:
    if lang == "sol":
        p = LADDER_SOL / "A0" / rid / f"{rid}.sol"
        return p if p.exists() else None
    if args.v1_mod_artifacts:
        for p in (Path(args.v1_mod_artifacts) / rid / "rich/A0/repeat-00/artifacts/modelica/model.mo",
                  Path(args.v1_mod_artifacts) / f"{rid}.mo"):
            if p.exists():
                return p
    return None


# ---------------------------------------------------------------- one job
def run_job(job: Job, args) -> dict:
    root = job.root
    logp = root / "logs" / f"{job.key}.json"
    if logp.exists():
        old = json.loads(logp.read_text())
        orec = old.get("record", {})
        if orec.get("status") in ("ok", "empty_output"):
            # Solidity records scored before import-resolved scoring existed are re-scored from the
            # cached program below (no model call); everything else is final.
            if not (job.lang == "sol" and "gain_res" not in orec and not args.dry_run):
                return orec
    req = requirements(job.lang)[job.req_id]
    rec = {"req_id": job.req_id, "status": "ok", "compile_valid": False, "n_compiler_errors": 0,
           "compiler_error_classes": [], "gain": 0,
           "retrieval": {"exemplar_ids": job.ex_ids, "scores": job.scores, "spec_chunk_ids": job.spec_ids},
           "model_calls": 0, "tokens_in": 0, "tokens_out": 0, **job.extra}
    if job.task in ("U1", "U2"):
        rec["exemplar_id"] = job.ex_ids[0]
    log = {"job": {k: v for k, v in job.__dict__.items() if k != "code_from"},
           "started": dt.datetime.now(dt.timezone.utc).isoformat()}
    # Modelica: the ladder's requirement normalization was computed once and gated every arm.
    if job.lang == "mod" and not req.meta.get("normalization_ok", True):
        rec.update({"normalization_ok": False, "note": "v1 requirement normalization failed: never generated"})
        return _finish(job, rec, log, logp, code=None)

    system, user = L.messages(job.lang, req, job.ex_ids, job.spec_ids)
    log["prompt"] = {"system": system, "user": user}
    if args.dry_run:
        (root / "prompts").mkdir(parents=True, exist_ok=True)
        (root / "prompts" / f"{job.key}.txt").write_text(f"### SYSTEM\n{system}\n### USER\n{user}\n")
        return {**rec, "status": "dry_run"}

    # 1) generation: at most one ladder call (+ its single stricter retry); never repeated once a
    #    completion exists. A completion cached in the log from an earlier invocation is reused.
    gen = (json.loads(logp.read_text()).get("generated") if logp.exists() else None)
    if gen is None and ABORT.is_set():
        return {**rec, "status": "aborted"}           # nothing written: a later invocation resumes it
    if gen is None:
        try:
            if job.code_from:
                gen = {"code": job.code_from.read_text(encoding="utf-8"), "calls": []}
            else:
                code, calls = L.generate(job.lang, system, user,
                                         lambda s, u: chat(s, u, lang=job.lang, provider=args.provider))
                gen = {"code": code, "calls": calls}
        except OutOfCredits as e:
            _abort(f"out of credits: {e}")
            return {**rec, "status": "aborted"}
        except InfraError as e:      # transport retries exhausted: no job-level re-call (billing guard)
            rec.update({"status": "infra_error", "infra_detail": str(e)})
            return _finish(job, rec, log, logp, code=None)
        log["generated"] = gen
        write_json(logp, {**log, "record": {**rec, "status": "scoring"}})
        cost = sum(float((c.get("usage") or {}).get("cost") or 0) for c in gen["calls"])
        with SPENT_LOCK:
            SPENT[0] += cost
            if args.max_cost and SPENT[0] >= args.max_cost:
                _abort(f"--max-cost ${args.max_cost:.2f} reached (${SPENT[0]:.2f})")
    log["generated"] = gen
    code, calls = gen["code"], gen["calls"]
    rec["model_calls"] = len(calls)
    rec["tokens_in"] = sum((c.get("usage") or {}).get("prompt_tokens") or 0 for c in calls)
    rec["tokens_out"] = sum((c.get("usage") or {}).get("completion_tokens") or 0 for c in calls)
    rec["cost_usd"] = round(sum(float((c.get("usage") or {}).get("cost") or 0) for c in calls), 6)
    rec["providers"] = [c.get("provider") for c in calls]
    rec["finish_reasons"] = [c.get("finish_reason") for c in calls]
    rec["possibly_billed_failures"] = sum(c.get("possibly_billed_failures") or 0 for c in calls)
    if not code.strip():
        rec["status"] = "empty_output"
        if job.lang == "sol":
            rec.update({"compile_valid_res": False, "n_compiler_errors_res": 0, "compiler_error_classes_res": [],
                        "gain_res": 0, "res_profile": None, "res_resolved": [], "res_unresolved": [],
                        "res_lib_errors": 0})
        return _finish(job, rec, log, logp, code="")
    # 2) scoring: local toolchains only; retried on infrastructure failure without regenerating.
    last = None
    for attempt in range(1, INFRA_ATTEMPTS + 1):
        try:
            s = L.score(job.lang, code, req, gain2=(not args.no_gain2), workdir=root / "work" / job.key)
            if s.get("infra"):
                raise InfraError(f"scorer: {s['infra']}")
            rec.update({"compile_valid": s["compile_valid"], "n_compiler_errors": s["n_compiler_errors"],
                        "gain": s["gain"], "gain_level2_scored": (not args.no_gain2) and job.lang != "sys"})
            rec["compiler_error_classes"] = [L.solc_class(e) for e in s["errors"]] if job.lang == "sol" else \
                [str(e.get("code") or "other") for e in s["errors"]]
            if s.get("solc"):
                rec["solc"] = s["solc"]
            if job.lang == "sol":
                rec.update({k: s[k] for k in ("compile_valid_res", "n_compiler_errors_res", "gain_res",
                                              "res_profile", "res_resolved", "res_unresolved", "res_lib_errors")})
                rec["compiler_error_classes_res"] = [L.solc_class(e) for e in s["errors_res"]]
            log["score"] = s
            return _finish(job, rec, log, logp, code=code)
        except Exception as e:
            last = f"{type(e).__name__}: {e}"
            log.setdefault("scorer_infra_attempts", []).append(traceback.format_exc()[-2000:])
            time.sleep(5 * attempt)
    rec["status"] = "infra_error"
    rec["infra_detail"] = f"scorer: {last}"
    return _finish(job, rec, log, logp, code=code)


def _finish(job, rec, log, logp, code):
    if code is not None:
        out = job.root / "outputs" / f"{job.key}.{EXT[job.lang]}"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(code + ("\n" if code and not code.endswith("\n") else ""), encoding="utf-8")
    log["record"] = rec
    log["ended"] = dt.datetime.now(dt.timezone.utc).isoformat()
    write_json(logp, log)
    return rec


# ---------------------------------------------------------------- versions and run meta
def versions() -> dict:
    def sh(*cmd):
        try:
            return subprocess.run(cmd, capture_output=True, text=True, timeout=60).stdout.strip().splitlines()[0]
        except Exception:
            return None
    import hashlib
    jar = REPO / "sysml2-compiler/sysml-parser-cli/target/sysml-parser-cli-1.0.0-shaded.jar"
    dense = RETR / "dense_model.json"
    d2 = RETR / "sol" / "d2_solc.json"
    return {
        "harness_commit": git_commit(),
        "python": sys.version.split()[0],
        "solc_installed_set": L.PACE_SOLC,
        "solc_d2": json.loads(d2.read_text())["modal"] if d2.exists() else None,
        "foundry": sh("forge", "--version"),
        "tier_a_fuzz_runs": L.FUZZ_RUNS,
        "openmodelica_image": "openmodelica/openmodelica:v1.27.0-ompython",
        "omc_local": sh("omc", "--version"),
        "fmi_runtime_image": "nl2robotics-fmi-runtime:0.1",
        "sysml_compiler_jar_sha256": hashlib.sha256(jar.read_bytes()).hexdigest() if jar.exists() else None,
        "sysml_compiler_submodule": sh("git", "-C", str(REPO / "sysml2-compiler"), "rev-parse", "HEAD"),
        "java": sh("java", "-version") or subprocess.run(["java", "-version"], capture_output=True,
                                                         text=True).stderr.splitlines()[0],
        "dense_model": json.loads(dense.read_text()) if dense.exists() else None,
    }


def run_task(task, lang, args):
    jobs = jobs_for(task, lang, args)
    if not jobs:
        print("no jobs"); return
    root = jobs[0].root
    root.mkdir(parents=True, exist_ok=True)
    start = dt.datetime.now(dt.timezone.utc).isoformat()
    print(f"{task}/{lang}/{jobs[0].cond}: {len(jobs)} jobs -> {root}")
    recs, lock, done = {}, threading.Lock(), [0]
    stop = threading.Event()
    watcher = None
    if not args.dry_run:
        watcher = threading.Thread(target=_credit_watch, args=(args, stop), daemon=True)
        watcher.start()
    with ThreadPoolExecutor(args.workers) as ex:
        futs = {ex.submit(run_job, j, args): j for j in jobs}
        for f in as_completed(futs):
            j = futs[f]
            r = f.result()
            with lock:
                recs[j.key] = r
                done[0] += 1
                if done[0] % 25 == 0 or done[0] == len(jobs):
                    st = collections.Counter(x["status"] for x in recs.values())
                    cv = sum(bool(x.get("compile_valid")) for x in recs.values())
                    calls = sum(x.get("model_calls") or 0 for x in recs.values())
                    cost = sum(x.get("cost_usd") or 0 for x in recs.values())
                    print(f"  {done[0]}/{len(jobs)} {dict(st)} compile-valid {cv} calls {calls} "
                          f"cost ${cost:.2f} [{dt.datetime.now():%H:%M:%S}]", flush=True)
    stop.set()
    if args.dry_run:
        print(f"dry run: prompts in {root/'prompts'}"); return
    rows = [recs[j.key] for j in jobs if recs[j.key]["status"] != "aborted"]
    n_aborted = len(jobs) - len(rows)
    write_jsonl(root / "results.jsonl", rows)
    served = collections.Counter(p for r in rows for p in (r.get("providers") or []))
    write_json(root / "run_meta.json", {
        "task": task, "lang": lang, "condition": jobs[0].cond, "n_jobs": len(jobs),
        "complete": n_aborted == 0, "n_not_run_aborted": n_aborted, "abort_reason": ABORT_WHY,
        "status_counts": dict(collections.Counter(r["status"] for r in rows)),
        "infra_excluded": [r["req_id"] + ("__" + r["exemplar_id"] if r.get("exemplar_id") else "")
                           for r in rows if r["status"] == "infra_error"],
        "model": MODEL, "temperature": TEMPERATURE,
        "provider_requested": args.provider or "openrouter default routing (as in the existing pipelines)",
        "provider_allow_fallbacks": False if args.provider else True, "providers_served": dict(served),
        "cost_usd": round(sum(r.get("cost_usd") or 0 for r in rows), 4),
        "possibly_billed_failures": sum(r.get("possibly_billed_failures") or 0 for r in rows),
        "max_completion_tokens": __import__("llm").LANG_MAX_TOKENS[lang],
        "model_calls": sum(r.get("model_calls") or 0 for r in rows),
        "tokens_in": sum(r.get("tokens_in") or 0 for r in rows),
        "tokens_out": sum(r.get("tokens_out") or 0 for r in rows),
        "gain_level2": not args.no_gain2, "started": start,
        "ended": dt.datetime.now(dt.timezone.utc).isoformat(),
        "versions": versions(), "argv": sys.argv,
    })
    write_json(RUNS / "versions.json", versions())
    print(f"wrote {root/'results.jsonl'} ({len(rows)}/{len(jobs)} jobs); served providers {dict(served)}")
    if ABORT.is_set():
        print(f"!! run stopped early: {ABORT_WHY}; re-run the same command to resume", flush=True)
        sys.exit(3)


# ---------------------------------------------------------------- labels (U1 + U0 -> labels.jsonl)
def gain_key(lang):
    """Label metric: Solidity uses the import-resolved gain (as Table 1 uses compile_valid_res) unless
    ECIR_SOL_SCORING=single; other languages have one gain."""
    return "gain_res" if lang == "sol" and os.getenv("ECIR_SOL_SCORING", "resolved") != "single" else "gain"


def build_labels(lang):
    gk = gain_key(lang)
    u0 = collections.defaultdict(list)
    for r in read_jsonl(RUNS / "U0" / lang / "A0" / "results.jsonl"):
        if r["status"] != "infra_error":
            u0[r["req_id"]].append(int(r[gk]))
    pool = {row["req_id"]: {it["exemplar_id"]: it for it in row["pool"]}
            for row in read_jsonl(RETR / lang / "pool.jsonl")}
    out, missing = [], set()
    for r in read_jsonl(RUNS / "U1" / lang / "k1" / "results.jsonl"):
        if r["status"] == "infra_error":
            continue
        if not u0.get(r["req_id"]):
            missing.add(r["req_id"]); continue
        it = pool[r["req_id"]][r["exemplar_id"]]
        out.append({"req_id": r["req_id"], "exemplar_id": r["exemplar_id"], "gain": int(r[gk]),
                    "gain_single": int(r["gain"]), "gain_res": r.get("gain_res"), "gain_metric": gk,
                    "g0": int(statistics.median_low(u0[r["req_id"]])),
                    "g0_samples": u0[r["req_id"]], "ranks": it["ranks"], "random": it["random"],
                    "features": it["features"], "status": r["status"]})
    write_jsonl(RUNS / "U1" / lang / "labels.jsonl", out)
    print(f"{lang}: {len(out)} labels ({gk}); requirements lacking U0 samples: {sorted(missing)}")


# ---------------------------------------------------------------- preflight
def preflight(args):
    load_env()
    ok = True
    print("OPENROUTER_API_KEY:", "set" if os.getenv("OPENROUTER_API_KEY") else "MISSING")
    try:
        eps = endpoints()
        names = sorted({e.get("provider_name") or e.get("name") for e in eps})
        tags = sorted({e.get("tag") for e in eps if e.get("tag")})
        print("providers serving", MODEL, ":", names)
        print("endpoint tags (also valid for --provider):", tags)
        if args.provider and args.provider not in names and args.provider not in tags:
            print(f"!! requested provider {args.provider!r} not among them"); ok = False
    except Exception as e:
        print("endpoint listing failed:", e); ok = False
    # compiler controls: a valid and an invalid program must be told apart
    want = set((args.lang or "sys,sol,mod").split(","))
    if "sys" in want:
        sys_ok = L.compile_check("sys", "package P { part def A; }")["compile_valid"]
        sys_bad = L.compile_check("sys", "package P { part def A }} oops")["compile_valid"]
        print("SysML compiler controls (valid, invalid):", sys_ok, sys_bad); ok &= sys_ok and not sys_bad
    if "sol" in want:
        sol = L.compile_check("sol", "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.20;\ncontract C { uint x; }")
        print("solc control:", sol["compile_valid"], sol.get("solc"), "(installed set:", L.PACE_SOLC + ")")
        ok &= sol["compile_valid"] and sol.get("solc") in L.PACE_SOLC.split(",")
        fv = versions()["foundry"]
        print("forge:", fv); ok &= bool(fv)
    if "mod" in want:
        try:
            m = L.compile_check("mod", "model M\n  Real x(start=1);\nequation\n  der(x) = -x;\nend M;")
            print("OpenModelica control:", m["compile_valid"], m.get("infra")); ok &= m["compile_valid"]
        except Exception as e:
            print("OpenModelica control failed:", e); ok = False
    else:
        print("OpenModelica: not checked (--lang excludes mod)")
    if args.probe:
        r = chat("Reply with READY.", "READY?", lang="sol", provider=args.provider)
        print("probe:", r["text"][:40], "served by", r["provider"], r["usage"])
    print("PREFLIGHT", "OK" if ok else "FAILED")
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("task")
    ap.add_argument("--lang")
    ap.add_argument("--provider", default=os.getenv("ECIR_PROVIDER"))
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--limit", type=int)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-gain2", action="store_true")
    ap.add_argument("--probe", action="store_true")
    ap.add_argument("--v1-mod-artifacts")
    ap.add_argument("--max-cost", type=float, help="stop submitting generations after this many USD in this invocation")
    ap.add_argument("--min-balance", type=float, default=3.0, help="abort when the OpenRouter balance drops below this")
    ap.add_argument("--credit-poll", type=float, default=60.0, help="seconds between balance checks")
    a = ap.parse_args()
    load_env()
    fixed = {"R1": "sol", "R1b": "mod", "R4": "sys"}
    if a.task == "preflight":
        return preflight(a)
    if a.task == "labels":
        return build_labels(a.lang)
    lang = fixed.get(a.task) or a.lang
    if not lang:
        raise SystemExit("--lang required")
    run_task(a.task, lang, a)
    return 0


if __name__ == "__main__":
    sys.exit(main())
