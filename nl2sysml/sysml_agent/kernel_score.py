#!/usr/bin/env python3
"""Jupyter-kernel execution scores for any corpus, exactly as comparison_results.ipynb cell 8.

Same call (`run_sysml_execution(ExecutionRequest(candidate_sysml=code))` on the stripped <ID>.sysml),
same per-sample record ({success, compiled, n_errors, n_warnings}; empty file -> success False,
"empty": True; an exception -> "error"), same checkpoint layout as dataset/kernel_results_naive.json.
Two additions only: samples run in parallel processes, and a sample whose code is byte-identical
to one already executed (common across the iter-0 / iter-1 / final snapshots) reuses its record.

    python nl2sysml/sysml_agent/kernel_score.py dataset/sysml_agent dataset/sysml_agent_iter0 \\
        dataset/sysml_agent_iter1 --workers 6
    -> dataset/kernel_results_<corpus>.json
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_NL2 = _HERE.parent
_ROOT = _NL2.parent
sys.path.insert(0, str(_NL2))


def run_one(code: str) -> dict:
    from sysml_execution import ExecutionRequest, run_sysml_execution
    try:
        d = run_sysml_execution(ExecutionRequest(candidate_sysml=code)).to_dict()
        diag = d.get("diagnostics") or {}
        return {"success": d.get("success", False), "compiled": d.get("compiled", False),
                "n_errors": int(diag.get("n_errors", len(d.get("errors", [])))),
                "n_warnings": int(diag.get("n_warnings", 0))}
    except Exception as e:  # noqa: BLE001 - same as the notebook: recorded, retried next run
        return {"success": False, "compiled": False, "n_errors": 0,
                "error": f"{type(e).__name__}: {e}"[:300]}


def _save(path: Path, state: dict):
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, indent=1, sort_keys=True), encoding="utf-8")
    tmp.replace(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("corpora", type=Path, nargs="+")
    ap.add_argument("--workers", type=int, default=6)
    a = ap.parse_args()

    ckpt = {c: _ROOT / "dataset" / f"kernel_results_{c.name}.json" for c in a.corpora}
    res = {c: (json.loads(p.read_text()) if p.exists() else {}) for c, p in ckpt.items()}
    by_hash, want = {}, {}  # sha -> record ; sha -> [(corpus, sid)]
    for c in a.corpora:
        for mp in sorted(c.glob("*/meta.json")):
            sid = mp.parent.name
            p = c / sid / f"{sid}.sysml"
            code = p.read_text(encoding="utf-8").strip() if p.exists() else ""
            if not code:
                res[c][sid] = {"success": False, "compiled": False, "n_errors": 0, "empty": True}
                continue
            h = hashlib.sha256(code.encode()).hexdigest()
            rec = res[c].get(sid)
            if rec is not None and "error" not in rec and rec.get("sha256") == h:
                by_hash.setdefault(h, rec)
                continue
            want.setdefault(h, {"code": code, "targets": []})["targets"].append((c, sid))

    todo = {h: w for h, w in want.items() if h not in by_hash}
    for h, w in want.items():
        if h in by_hash:
            for c, sid in w["targets"]:
                res[c][sid] = by_hash[h]
    print(f"{sum(len(w['targets']) for w in want.values())} samples to score, "
          f"{len(todo)} distinct models to execute", flush=True)
    done = 0
    with ProcessPoolExecutor(max_workers=a.workers) as pool:
        futs = {pool.submit(run_one, w["code"]): h for h, w in todo.items()}
        for f in as_completed(futs):
            h = futs[f]
            rec = {**f.result(), "sha256": h}
            for c, sid in todo[h]["targets"]:
                res[c][sid] = rec
            done += 1
            if done % 50 == 0 or done == len(todo):
                for c in a.corpora:
                    _save(ckpt[c], res[c])
                print(f"  {done}/{len(todo)}", flush=True)
    for c in a.corpora:
        _save(ckpt[c], res[c])
        n = len(res[c])
        print(f"{c}: {n} scored, kernel pass {sum(bool(r.get('success')) for r in res[c].values())}/{n} "
              f"-> {ckpt[c]}")


if __name__ == "__main__":
    main()
