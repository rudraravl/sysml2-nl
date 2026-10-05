#!/usr/bin/env python3
"""Re-score a finished run offline (no model calls) with the current toolchains.

  python ecir_v3/rescore.py R4 sys A0 [--no-gain2] [--workers 4]

Reads the generated program cached in each runs/<task>/<lang>/<cond>/logs/<key>.json, recomputes
compile_valid / errors / gain, keeps the previous verdict as *_prev, and rewrites results.jsonl.
Use after a toolchain change (e.g. the SysML evaluator, README deviation 16).
"""
from __future__ import annotations

import argparse
import json
from concurrent.futures import ThreadPoolExecutor

from common import RUNS, write_json, write_jsonl
from corpora import requirements
import langs as L


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("task"); ap.add_argument("lang"); ap.add_argument("cond")
    ap.add_argument("--no-gain2", action="store_true")
    ap.add_argument("--workers", type=int, default=4)
    a = ap.parse_args()
    root = RUNS / a.task / a.lang / a.cond
    order = [json.loads(l)["req_id"] + (("__" + json.loads(l)["exemplar_id"]) if json.loads(l).get("exemplar_id") else
             ("__s%d" % json.loads(l)["sample"]) if json.loads(l).get("sample") else "")
             for l in (root / "results.jsonl").read_text().splitlines() if l.strip()]
    reqs = requirements(a.lang)

    def one(key):
        p = root / "logs" / f"{key}.json"
        log = json.loads(p.read_text())
        rec = log["record"]
        code = (log.get("generated") or {}).get("code", "")
        if rec["status"] != "ok" or not code.strip():
            return rec
        s = L.score(a.lang, code, reqs[rec["req_id"]], gain2=not a.no_gain2, workdir=root / "work" / key)
        for k in ("compile_valid", "n_compiler_errors", "gain"):
            rec[f"{k}_prev"] = rec.get(k)
        rec.update({"compile_valid": s["compile_valid"], "n_compiler_errors": s["n_compiler_errors"], "gain": s["gain"],
                    "compiler_error_classes": [L.solc_class(e) for e in s["errors"]] if a.lang == "sol"
                    else [str(e.get("code") or "other") for e in s["errors"]]})
        log["record"], log["score"] = rec, s
        write_json(p, log)
        return rec

    with ThreadPoolExecutor(a.workers) as ex:
        rows = list(ex.map(one, order))
    write_jsonl(root / "results.jsonl", rows)
    ch = sum(r.get("compile_valid_prev") is not None and r["compile_valid"] != r["compile_valid_prev"] for r in rows)
    print(f"rescored {len(rows)} rows in {root}; compile verdict changed on {ch}; "
          f"compile-valid now {sum(bool(r['compile_valid']) for r in rows)}")


if __name__ == "__main__":
    main()
