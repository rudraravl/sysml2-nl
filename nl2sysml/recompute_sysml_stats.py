#!/usr/bin/env python3
"""SysML naive-vs-full paired statistics with de-duplicated compiler error counts.

Why this exists: the parser jar reports every syntax error twice (an uncoded ANTLR copy and an
Xtext `Diagnostic.Syntax` copy), so the `error_count` cached in meta.json double-counts them.
The naive arm's error list is stored, so it can be de-duplicated offline. The full arm's
meta.json keeps only the count, so its .sysml files must be recompiled once (`recount`).
Valid/invalid is unaffected by any of this.

Stages
  recount   JVM. Recompile every full-arm .sysml and checkpoint de-duplicated diagnostics to
            dataset/analysis_results/sysml_recount/diagnostics_full.json (resumable).
  stats     No JVM. Five-metric paired table (valid compile, compiler errors, kernel pass,
            kernel errors, std-rule compliance), Holm across the five, at n=1533 (10 stale
            full-arm samples excluded) and n=1543 (sensitivity).

    python nl2sysml/recompute_sysml_stats.py recount --workers 6
    python nl2sysml/recompute_sysml_stats.py stats --count-mode dedup
    python nl2sysml/recompute_sysml_stats.py stats --count-mode raw     # reproduces the old table
"""

import argparse
import json
import os
import re
import signal
import sys
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

_NL2 = Path(__file__).resolve().parent
_ROOT = _NL2.parent
sys.path.insert(0, str(_NL2))
sys.path.insert(0, str(_ROOT))

NAIVE_DIR = _ROOT / "dataset" / "naive_glm"
FULL_DIR = _ROOT / "dataset" / "with_kernel_spec"
OUT_ROOT = _ROOT / "dataset" / "analysis_results" / "sysml_recount"
CHECKPOINT = OUT_ROOT / "diagnostics_full.json"
COMPILE_TIMEOUT_S = 120
# Full-arm samples created 2026-08-07 under a different model roster (see results doc 4.1).
STALE = ["U140", "U298", "U518", "U913", "U1055", "U1428", "U589", "U898", "U1214", "U927"]


def dedupe_count(errors):
    return len({(e["line"], e["column"], e["message"]) for e in errors})


def _sid_key(s):
    return int(re.sub(r"\D", "", s) or 0)


# ---- recount ----------------------------------------------------------------
class _Timeout(Exception):
    pass


def _compile_one(sid):
    """Runs in a worker process (main thread), so SIGALRM works; run() kills the JVM on raise."""
    from compiler_interface import check_code
    from naive_glm_generate import _postprocess

    raw = (FULL_DIR / sid / f"{sid}.sysml").read_text(encoding="utf-8")
    code = _postprocess(raw)
    if not code:
        return sid, {"empty": True, "valid": False, "raw": 0, "unique": 0}

    def _alarm(signum, frame):
        raise _Timeout()

    old = signal.signal(signal.SIGALRM, _alarm)
    signal.alarm(COMPILE_TIMEOUT_S)
    try:
        res = check_code(code)
    except _Timeout:
        return sid, {"timeout": True, "valid": False, "raw": None, "unique": None}
    finally:
        signal.alarm(0)
        signal.signal(signal.SIGALRM, old)
    errs = [{"line": e.line, "column": e.column, "message": e.message} for e in res.errors]
    return sid, {"valid": res.is_valid, "raw": len(errs), "unique": dedupe_count(errs)}


def cmd_recount(args):
    from compiler_interface import is_compiler_available
    if not is_compiler_available():
        sys.exit("SysML compiler unavailable (java / parser jar); cannot recount.")
    naive = {p.parent.name for p in NAIVE_DIR.glob("*/meta.json")}
    full = {p.parent.name for p in FULL_DIR.glob("*/meta.json")}
    ids = sorted(naive & full, key=_sid_key)[:args.limit]
    OUT_ROOT.mkdir(parents=True, exist_ok=True)
    done = json.loads(CHECKPOINT.read_text()) if CHECKPOINT.exists() else {}
    todo = [s for s in ids if s not in done or done[s].get("timeout")]
    print(f"{len(ids)} paired ids; {len(ids) - len(todo)} already checkpointed; {len(todo)} to compile "
          f"({args.workers} workers)", flush=True)

    os.environ["SYSML_COMPILER_MAX_CONCURRENCY"] = "1"  # one JVM per worker process
    with ProcessPoolExecutor(args.workers) as pool:
        futs = [pool.submit(_compile_one, s) for s in todo]
        for i, f in enumerate(as_completed(futs), 1):
            sid, r = f.result()
            done[sid] = r
            if i % 25 == 0 or i == len(todo):
                CHECKPOINT.write_text(json.dumps(done, indent=1) + "\n")
                print(f"  {i}/{len(todo)}", flush=True)
    CHECKPOINT.write_text(json.dumps(done, indent=1) + "\n")

    # cross-check the fresh compile against what the pipeline stored
    same_valid = same_raw = n = 0
    diffs = []
    for sid in ids:
        r = done[sid]
        if r.get("timeout") or r.get("empty"):
            continue
        stored = json.loads((FULL_DIR / sid / "meta.json").read_text())["validation"]
        n += 1
        same_valid += stored["is_valid"] == r["valid"]
        same_raw += stored["error_count"] == r["raw"]
        if stored["error_count"] != r["raw"]:
            diffs.append((sid, stored["error_count"], r["raw"]))
    print(f"\nFresh vs stored (full arm, n={n}): valid flag agrees {same_valid}/{n}; "
          f"raw error count agrees {same_raw}/{n}; timeouts {sum(bool(v.get('timeout')) for v in done.values())}; "
          f"empty {sum(bool(v.get('empty')) for v in done.values())}")
    if diffs:
        print("  first disagreements (sid, stored, fresh):", diffs[:10])


# ---- stats ------------------------------------------------------------------
def _load_meta(d, sid):
    return json.loads((d / sid / "meta.json").read_text(encoding="utf-8"))


def build_metrics(ids, count_mode, full_diag):
    from analysis.paired_stats import PairedMetric
    import std_rules

    nk = json.loads((_ROOT / "dataset" / "kernel_results_naive.json").read_text())
    pk = json.loads((_ROOT / "dataset" / "kernel_results_pipeline.json").read_text())
    nm = {s: _load_meta(NAIVE_DIR, s) for s in ids}
    fm = {s: _load_meta(FULL_DIR, s) for s in ids}

    def naive_errs(s):
        m = nm[s]
        return dedupe_count(m.get("errors", [])) if count_mode == "dedup" else m["validation"]["error_count"]

    def full_errs(s):
        if count_mode == "dedup":
            return full_diag[s]["unique"]
        return fm[s]["validation"]["error_count"]

    def rate(d, s):
        p = d / s / f"{s}.sysml"
        txt = p.read_text(encoding="utf-8").strip() if p.exists() else ""
        res = std_rules.check(txt) if txt else {r: "fail" for r in std_rules.RULES}
        ok = sum(v == "pass" for v in res.values())
        app = ok + sum(v == "fail" for v in res.values())
        return ok / app if app else 0.0

    pair = lambda name, kind, a, b, **kw: PairedMetric(
        name=name, kind=kind, ids=list(ids), naive=[a(s) for s in ids], full=[b(s) for s in ids], **kw)
    return [
        pair("Valid compile rate", "proportion",
             lambda s: bool(nm[s]["validation"]["is_valid"]), lambda s: bool(fm[s]["validation"]["is_valid"])),
        pair("Compiler errors", "continuous", lambda s: naive_errs(s), lambda s: full_errs(s),
             lower_is_better=True),
        pair("Kernel execution pass rate", "proportion",
             lambda s: bool(nk[s].get("success")), lambda s: bool(pk[s].get("success"))),
        pair("Kernel errors", "continuous",
             lambda s: nk[s].get("n_errors", 0), lambda s: pk[s].get("n_errors", 0), lower_is_better=True),
        pair("Std-rule compliance rate", "continuous",
             lambda s: rate(NAIVE_DIR, s), lambda s: rate(FULL_DIR, s)),
    ]


def cmd_stats(args):
    from analysis import paired_stats as ps, report

    naive = {p.parent.name for p in NAIVE_DIR.glob("*/meta.json")}
    full = {p.parent.name for p in FULL_DIR.glob("*/meta.json")}
    paired = sorted(naive & full, key=_sid_key)
    full_diag = None
    if args.count_mode == "dedup":
        if not CHECKPOINT.exists():
            sys.exit(f"{CHECKPOINT} missing: run `recount` first.")
        full_diag = json.loads(CHECKPOINT.read_text())
        missing = [s for s in paired if s not in full_diag or full_diag[s].get("timeout")]
        if missing:
            sys.exit(f"{len(missing)} paired ids lack a completed recount (e.g. {missing[:5]}); rerun `recount`.")

    for tag, ids in (("n1533", [s for s in paired if s not in set(STALE)]), ("n1543_all", paired)):
        metrics = build_metrics(ids, args.count_mode, full_diag)
        results = ps.analyze(metrics)
        out = OUT_ROOT / f"stats_{args.count_mode}_{tag}"
        report.print_summary(results, f"SysML naive vs full [{args.count_mode} counts, {tag}]")
        report.write_outputs(
            out, title=f"SysML naive vs full pipeline ({args.count_mode} error counts, n={len(ids)})",
            header_lines=[f"Compiler-error counts are {'de-duplicated (unique line/column/message)' if args.count_mode == 'dedup' else 'as cached in meta.json (syntax errors double-counted)'}. "
                          f"Stale samples {'excluded' if tag == 'n1533' else 'included'}."],
            results=results, metrics=metrics, plots=False)
        print(f"wrote {out}\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("recount")
    r.add_argument("--workers", type=int, default=6)
    r.add_argument("--limit", type=int, default=None, help="only the first N ids (smoke test)")
    r.set_defaults(fn=cmd_recount)
    s = sub.add_parser("stats")
    s.add_argument("--count-mode", choices=["dedup", "raw"], default="dedup")
    s.set_defaults(fn=cmd_stats)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
