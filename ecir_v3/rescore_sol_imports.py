#!/usr/bin/env python3
"""Add import-resolved verdicts (sol_imports.py) to finished Solidity runs, offline (no model calls).

  python ecir_v3/rescore_sol_imports.py [--arms ladder/A0,ladder/A1,...] [--workers 8]

For every row of runs/<arm>/results.jsonl (arm = <task>/<cond> under runs/<task>/sol/<cond>) this adds
  compile_valid_res, n_compiler_errors_res, compiler_error_classes_res,
  res_profile (oz5 | oz4 | null = nothing resolvable), res_resolved, res_unresolved, res_lib_errors
and leaves the single-file fields (compile_valid, ...) untouched. As a harness check, each program is
also recompiled single-file through the same standard-JSON path; that verdict must equal the stored
compile_valid (disagreements are listed in the report). Re-running is idempotent. convert_ladder.py
rewrites ladder results.jsonl without these fields, so re-run this after it.
"""
from __future__ import annotations

import argparse
import collections
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from common import RUNS, WORK, read_jsonl, write_json, write_jsonl
import sol_imports as S
from analyze import _sol_program
from langs import solc_class

ARMS = ("ladder/A0", "ladder/A1", "ladder/A3", "R1/A1bm25", "R2/A1rand")


def rescore(arm: str, workers: int) -> dict:
    task, cond = arm.split("/")
    path = RUNS / task / "sol" / cond / "results.jsonl"
    rows = read_jsonl(path)

    def one(r):
        if r["status"] == "infra_error":
            return r, None
        code = _sol_program(Path(path), r["req_id"])
        if not code.strip():                       # empty_output: a failure under any scoring
            r.update({"compile_valid_res": False, "n_compiler_errors_res": r.get("n_compiler_errors", 0),
                      "compiler_error_classes_res": r.get("compiler_error_classes") or [],
                      "res_profile": None, "res_resolved": [], "res_unresolved": [], "res_lib_errors": 0})
            return r, None
        single = not S._solc({"Candidate.sol": code}, code)
        x = S.compile_resolved(code)
        if x["infra"]:
            raise RuntimeError(f"{arm} {r['req_id']}: {x['infra']}")
        r.update({"compile_valid_res": x["compile_valid"], "n_compiler_errors_res": x["n_compiler_errors"],
                  "compiler_error_classes_res": [solc_class(e) for e in x["errors"]],
                  "res_profile": x["profile"], "res_resolved": x["resolved_imports"],
                  "res_unresolved": x["unresolved_imports"], "res_lib_errors": x["lib_errors"]})
        return r, single

    with ThreadPoolExecutor(workers) as ex:
        out = list(ex.map(one, rows))
    rows = [r for r, _ in out]
    write_jsonl(path, rows)

    ok = [r for r in rows if r["status"] != "infra_error"]
    disagree = [r["req_id"] for r, s in out if s is not None and s != bool(r["compile_valid"])]
    flips = [r for r in ok if bool(r["compile_valid_res"]) != bool(r["compile_valid"])]
    rep = {"n": len(ok),
           "compile_valid": sum(bool(r["compile_valid"]) for r in ok),
           "compile_valid_res": sum(bool(r["compile_valid_res"]) for r in ok),
           "fail_to_valid": sum(bool(r["compile_valid_res"]) for r in flips),
           "valid_to_fail": sum(not r["compile_valid_res"] for r in flips),
           "profiles": dict(collections.Counter(str(r["res_profile"]) for r in ok)),
           "valid_by_profile": dict(collections.Counter(str(r["res_profile"]) for r in ok if r["compile_valid_res"])),
           "still_unresolved": dict(collections.Counter(u for r in ok for u in r["res_unresolved"]).most_common(15)),
           "single_file_harness_disagreements": disagree}
    print(f"{arm}: n={rep['n']} single-file {rep['compile_valid']} -> resolved {rep['compile_valid_res']} "
          f"(+{rep['fail_to_valid']} / -{rep['valid_to_fail']}); harness disagreements {len(disagree)}")
    return rep


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--arms", default=",".join(ARMS))
    ap.add_argument("--workers", type=int, default=8)
    a = ap.parse_args()
    if not S.selftest():
        raise SystemExit("sol_imports selftest failed")
    rep = {"profiles": S.PROFILE_VERSIONS, "arms": {arm: rescore(arm, a.workers) for arm in a.arms.split(",")}}
    write_json(WORK / "analysis" / "RES_rescore.json", rep)


if __name__ == "__main__":
    main()
