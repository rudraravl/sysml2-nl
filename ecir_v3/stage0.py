#!/usr/bin/env python3
"""Stage 0: ID lists, retrieval lists (L), the deployed-top-5 sanity check, pools, R7 candidates, D2/D9.

  python ecir_v3/stage0.py ids                      ids/ladder500_*, pool100_*, heldout400_*
  python ecir_v3/stage0.py retrieval [--no-dense]   retrieval/<lang>/{cos,bm25,dense}.jsonl (top 10)
  python ecir_v3/stage0.py check                    recomputed deployed top five vs the v1 A1 logs
  python ecir_v3/stage0.py d2                       D2.solc from the ladder A0/A1 contracts
  python ecir_v3/stage0.py pools                    retrieval/<lang>/pool.jsonl (+2 random, features)
  python ecir_v3/stage0.py cands                    retrieval/<lang>/cands_heldout.jsonl (R7 candidates)
  python ecir_v3/stage0.py all [--no-dense]
"""
from __future__ import annotations

import argparse
import collections
import json
import random
import subprocess
import sys

import numpy as np

from common import (HERE, IDS, LADDER_SOL, LADDER_SYS, LANGS, REPO, RETR, placeholders_set, read_ids,
                    read_jsonl, req_seed, retrieval_lists, sha256_text, write_ids, write_json, write_jsonl)
from corpora import exemplars, mod_ladder_ids, mod_run, requirements
import retrievers as R

NAMES = {"sys": "SysML v2", "sol": "Solidity", "mod": "Modelica"}


# ---------------------------------------------------------------- ids
def cmd_ids():
    sys_ids = sorted(requirements("sys"), key=lambda x: int(x[1:]))
    sol_ids = sorted(requirements("sol"), key=lambda x: int(x[1:]))
    mod_ids = mod_ladder_ids()
    assert len(sys_ids) == 500 and len(sol_ids) == 500 and len(mod_ids) == 498, \
        (len(sys_ids), len(sol_ids), len(mod_ids))
    write_ids("ladder500_sys.txt", sys_ids)
    write_ids("ladder500_sol.txt", sol_ids)
    write_ids("ladder500_mod.txt", mod_ids)
    # Pools: 100 at random, seed 0. Modelica draws only from tasks whose (precomputed, shared)
    # requirement normalization succeeded: the other 66 are never generated in any arm, so every
    # label would be 0 without a model call.
    mreq = requirements("mod")
    mod_elig = [t for t in mod_ids if mreq[t].meta["normalization_ok"]]
    for lang, ids, elig in (("sol", sol_ids, sol_ids), ("mod", mod_ids, mod_elig)):
        pool = sorted(random.Random(0).sample(elig, 100), key=lambda x: (len(x), x))
        held = [i for i in ids if i not in set(pool)]
        write_ids(f"pool100_{lang}.txt", pool)
        write_ids(f"heldout400_{lang}.txt", held)
        print(f"{lang}: ladder {len(ids)}, pool 100 (from {len(elig)} eligible), heldout {len(held)}")


# ---------------------------------------------------------------- retrieval lists
def _row(req_id, ranked, lang):
    ex = exemplars(lang)
    return {"req_id": req_id, "exemplar_ids": [ex[i].id for i, _ in ranked],
            "scores": [round(s, 6) for _, s in ranked]}


def cmd_retrieval(dense=True):
    info = {}
    for lang in LANGS:
        reqs = requirements(lang)
        ids = list(reqs)
        cos, bm, de = [], [], []
        for rid in ids:
            r = _row(rid, R.cos_rank(lang, reqs[rid].text), lang)
            if lang == "sys":
                sp = R.spec_rank(reqs[rid].text)
                r["spec_chunk_ids"] = [c for c, _ in sp]
                r["spec_scores"] = [round(s, 6) for _, s in sp]
            cos.append(r)
            bm.append(_row(rid, R.bm25_rank(lang, reqs[rid]), lang))
        write_jsonl(RETR / lang / "cos.jsonl", cos)
        write_jsonl(RETR / lang / "bm25.jsonl", bm)
        if dense:
            qv = R.dense_query_vecs([reqs[i].text for i in ids])
            np.save(RETR / lang / f"dense_queries.{R.DENSE_MODEL.replace('/', '__')}.npy", qv)
            for rid, v in zip(ids, qv):
                de.append(_row(rid, R.dense_rank_from_vec(lang, v), lang))
            write_jsonl(RETR / lang / "dense.jsonl", de)
        print(f"{lang}: wrote cos/bm25{'/dense' if dense else ''} for {len(ids)} requirements")
    if dense:
        info = R.dense_info()
        write_json(RETR / "dense_model.json", info)
        placeholders_set({"D9.dense": f"{info['name']} (revision {(info['revision'] or 'unknown')[:7]})"},
                         "stage0.py retrieval")


def _query_vec(lang, rid):
    f = RETR / lang / f"dense_queries.{R.DENSE_MODEL.replace('/', '__')}.npy"
    if not f.exists():
        return None
    ids = list(requirements(lang))
    return np.load(f, mmap_mode="r")[ids.index(rid)]


# ---------------------------------------------------------------- sanity check (L2)
def cmd_check():
    from langs import messages
    rep = {}
    # Modelica: the v1 A1 run.json lists the retrieved IDs.
    bm = retrieval_lists("mod", "bm25")
    n = same = 0
    diffs = []
    for t in read_ids("ladder500_mod.txt"):
        logged = [h["id"] for h in ((mod_run(t, "A1").get("result") or {}).get("modelica") or {})
                  .get("retrieved_examples") or []]
        if not logged:
            continue
        n += 1
        mine = bm[t]["exemplar_ids"][:5]
        if mine == logged:
            same += 1
        else:
            diffs.append({"req_id": t, "logged": logged, "recomputed": mine})
    rep["mod"] = {"compared": n, "identical": same, "diffs": diffs[:20],
                  "source": "A1 run.json result.modelica.retrieved_examples"}
    # SysML v2: the v1 A1 artifacts hold the exact prompts; rebuild them from the recomputed IDs.
    cos = retrieval_lists("sys", "cos")
    reqs = requirements("sys")
    n = same = same_hash = 0
    diffs = []
    for t in read_ids("ladder500_sys.txt"):
        a = LADDER_SYS / "A1/tasks" / t / "artifacts"
        if not (a / "generation-user.txt").exists():
            continue
        n += 1
        r = cos[t]
        s, u = messages("sys", reqs[t], r["exemplar_ids"][:5], r["spec_chunk_ids"][:3])
        ok = (s == (a / "generation-system.txt").read_text(encoding="utf-8")
              and u == (a / "generation-user.txt").read_text(encoding="utf-8"))
        ctx_ok = sha256_text((a / "retrieval-context.txt").read_text(encoding="utf-8")) == \
            json.loads((LADDER_SYS / "A1/tasks" / t / "run.json").read_text())["result"]["generation"].get(
                "retrieval_context_sha256")
        same += ok
        same_hash += ctx_ok
        if not ok:
            diffs.append(t)
    rep["sys"] = {"compared": n, "identical_prompts": same, "context_hash_consistent": same_hash,
                  "diffs": diffs[:20], "source": "A1 artifacts/generation-{system,user}.txt"}
    # Solidity: v1 never logged retrieval or prompts; check the corpus is unchanged since the run.
    log = subprocess.run(["git", "log", "--since=2026-09-19", "--format=%h %ad %s", "--date=short", "--",
                          "nl2solidity/dataset/data"], cwd=REPO, capture_output=True, text=True).stdout
    dirty = subprocess.run(["git", "status", "--porcelain", "--", "nl2solidity/dataset/data"], cwd=REPO,
                           capture_output=True, text=True).stdout
    rep["sol"] = {"compared": 0, "note": "v1 Solidity ladder logged neither exemplar IDs nor prompts; "
                  "the deployed scorer is deterministic, so the recomputed list is the v1 list if the "
                  "corpus is unchanged", "corpus_commits_since_run": log.strip().splitlines(),
                  "corpus_uncommitted_changes": dirty.strip().splitlines()}
    write_json(RETR / "sanity_check.json", rep)
    for k, v in rep.items():
        print(k, {kk: vv for kk, vv in v.items() if kk not in ("diffs",)})
    bad = (rep["mod"]["compared"] - rep["mod"]["identical"]) + (rep["sys"]["compared"] - rep["sys"]["identical_prompts"])
    if bad > 5:
        print(f"!! {bad} recomputed deployed lists differ from the v1 logs: stop and tell SV (runbook L2).")
        return 1
    return 0


# ---------------------------------------------------------------- D2
def cmd_d2():
    from langs import solc_version_for
    c = collections.Counter()
    for arm in ("A0", "A1"):
        for f in sorted((LADDER_SOL / arm).glob("U*/U*.sol")):
            c[solc_version_for(f.read_text(encoding="utf-8"))] += 1
    top = c.most_common(1)[0][0]
    write_json(RETR / "sol" / "d2_solc.json", {"selected_versions": dict(c), "modal": top,
                                              "installed_set": __import__("langs").PACE_SOLC})
    placeholders_set({"D2.solc": top}, "stage0.py d2")
    print("solc versions selected for ladder A0+A1 contracts:", dict(c), "-> D2.solc =", top)
    return top


def d2_version():
    p = RETR / "sol" / "d2_solc.json"
    return json.loads(p.read_text())["modal"] if p.exists() else R.D2_SOLC


# ---------------------------------------------------------------- pools and candidates
def _score_vectors(lang, req):
    qv = _query_vec(lang, req.id)
    return {"cos": R.cos_scores(lang, req.text), "bm25": R.bm25_scores(lang, req.text),
            "dense": R.dense_scores_from_vec(lang, qv) if qv is not None else None}


def cmd_pools():
    d2 = d2_version()
    for lang in ("sol", "mod"):
        reqs = requirements(lang)
        lists = {n: retrieval_lists(lang, n) for n in R.RETRIEVER_NAMES}
        all_ids = [e.id for e in exemplars(lang)]
        rows = []
        for rid in read_ids(f"pool100_{lang}.txt"):
            ranks = collections.defaultdict(dict)
            for n, L in lists.items():
                if rid not in L:
                    continue
                for k, x in enumerate(L[rid]["exemplar_ids"][:5], 1):
                    ranks[x][n] = k
            pool = list(ranks)
            rng = random.Random(req_seed(rid))
            rand = rng.sample([x for x in all_ids if x not in ranks], 2)
            feats = R.pair_features(lang, reqs[rid], pool + rand, _score_vectors(lang, reqs[rid]), d2)
            items = [{"exemplar_id": x, "ranks": {n: ranks[x].get(n) for n in R.RETRIEVER_NAMES},
                      "random": False, "features": feats[x]} for x in pool]
            items += [{"exemplar_id": x, "ranks": {n: None for n in R.RETRIEVER_NAMES},
                       "random": True, "features": feats[x]} for x in rand]
            rows.append({"req_id": rid, "pool": items})
        write_jsonl(RETR / lang / "pool.jsonl", rows)
        print(f"{lang}: {len(rows)} pooled requirements, mean pool size "
              f"{np.mean([len(r['pool']) for r in rows]):.1f} (incl. 2 random)")


def cmd_cands():
    d2 = d2_version()
    for lang in ("sol", "mod"):
        reqs = requirements(lang)
        lists = {n: retrieval_lists(lang, n) for n in R.RETRIEVER_NAMES}
        rows = []
        for rid in read_ids(f"heldout400_{lang}.txt"):
            ids = []
            for n, L in lists.items():
                for x in (L.get(rid) or {}).get("exemplar_ids", [])[:10]:
                    if x not in ids:
                        ids.append(x)
            feats = R.pair_features(lang, reqs[rid], ids, _score_vectors(lang, reqs[rid]), d2)
            rows += [{"req_id": rid, "exemplar_id": x, "features": feats[x]} for x in ids]
        write_jsonl(RETR / lang / "cands_heldout.jsonl", rows)
        print(f"{lang}: {len(rows)} candidates for {len(read_ids(f'heldout400_{lang}.txt'))} held-out requirements")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd")
    ap.add_argument("--no-dense", action="store_true")
    a = ap.parse_args()
    if a.cmd in ("ids", "all"):
        cmd_ids()
    if a.cmd in ("retrieval", "all"):
        cmd_retrieval(dense=not a.no_dense)
    if a.cmd in ("d2", "all"):
        cmd_d2()
    if a.cmd in ("check", "all"):
        rc = cmd_check()
        if rc:
            return rc
    if a.cmd in ("pools", "all"):
        cmd_pools()
    if a.cmd in ("cands", "all"):
        cmd_cands()
    return 0


if __name__ == "__main__":
    sys.exit(main())
