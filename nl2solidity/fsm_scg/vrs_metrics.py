#!/usr/bin/env python3
"""FSM-SCG's own metrics (CPR, VRS, ZRCP, HRCP) over any Solidity corpus. Measure-only, no LLM.

Upstream definitions (evaluate/effectiveness/CPR.py, evaluate/security/slither_check.py @ 9dcd83e):

    CPR   % of contracts that compile                       (here: our check_code, not py-solc-x)
    risk  per contract: mean over merged Slither findings of impact_score x confidence_score
          (High 3, Medium 2, Low 1); 0 with no findings; 10 when the contract cannot be analysed
          (upstream conflates "does not compile" with "Slither raised": both score 10)
    VRS   mean risk over ALL contracts
    ZRCP  % of analysed contracts with risk 0
    HRCP  % of analysed contracts with at least one High-impact finding

Findings follow run_fsm_scg.slither_findings: every detector except Informational/Optimization,
one element per result, overlapping line ranges merged per check type. "Analysed" = compiles and
Slither produced a result; a compiling contract Slither cannot analyse is counted separately.

Paired tests on shared seed ids, each corpus vs --reference (FORGE by default), Holm-adjusted
within each comparison: McNemar for CPR, ZRCP and "no High finding" (1 - HRCP, so that + means
the reference is better), Wilcoxon for per-contract risk. ZRCP/HRCP pairs use seeds analysed on
both sides.

Per-sample results are cached in <out-dir>/vrs_<name>.json and reused on rerun (--recompute to
redo), so it is safe to interrupt. Slither concurrency follows SECURITY_MAX_CONCURRENCY.

    python nl2solidity/fsm_scg/vrs_metrics.py --workers 6
    python nl2solidity/fsm_scg/vrs_metrics.py --corpus fsm_scg=nl2solidity/dataset/fsm_scg_pilot \\
        --corpus naive_glm=nl2solidity/dataset/naive_glm --ids U18 U66 ...
"""

from __future__ import annotations

import argparse
import json
import sys
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_NL2 = _HERE.parent
_ROOT = _NL2.parent
for _p in (str(_ROOT), str(_NL2), str(_HERE)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from analysis import paired_stats as ps  # noqa: E402
from analysis import report  # noqa: E402
from run_fsm_scg import check_code, slither_findings  # noqa: E402
from security_analysis import analyzer_version  # noqa: E402
from upstream_fsm_utils import confidence_map, impact_map  # noqa: E402

DS = _NL2 / "dataset"
DEFAULT_CORPORA = {
    "naive_glm": DS / "naive_glm",
    "BoN6": DS / "best_of_n" / "BoN6",
    "fsm_scg": DS / "fsm_scg",
    "with_kernel_spec": DS / "with_kernel_spec",
}
LABELS = {"naive_glm": "Naive", "BoN6": "Best-of-6", "fsm_scg": "FSM-SCG*",
          "with_kernel_spec": "FORGE"}
FAIL_RISK = 10.0


def measure(code: str) -> dict:
    if not code.strip():
        return {"compiled": False, "empty": True, "slither_error": None, "risk": FAIL_RISK}
    if not check_code(code).is_valid:
        return {"compiled": False, "empty": False, "slither_error": None, "risk": FAIL_RISK}
    findings, err = slither_findings(code)
    if err is not None:
        return {"compiled": True, "empty": False, "slither_error": err, "risk": FAIL_RISK}
    scores = [impact_map[f["impact"]] * confidence_map[f["confidence"]] for f in findings]
    by = {k: sum(f["impact"] == k for f in findings) for k in ("High", "Medium", "Low")}
    return {"compiled": True, "empty": False, "slither_error": None,
            "risk": sum(scores) / len(scores) if scores else 0.0,
            "n_findings": len(findings), "by_impact": by,
            "checks": sorted({f["check_type"] for f in findings})}


def analysed(s: dict) -> bool:
    return s["compiled"] and s["slither_error"] is None


def corpus_ids(path: Path, ids) -> list[str]:
    have = sorted(p.parent.name for p in path.glob("*/meta.json"))
    return [s for s in have if s in ids] if ids else have


def run_corpus(name: str, path: Path, out_dir: Path, ids, workers: int, recompute: bool) -> dict:
    cache_path = out_dir / f"vrs_{name}.json"
    cache = {} if recompute or not cache_path.exists() else \
        json.loads(cache_path.read_text(encoding="utf-8")).get("samples", {})
    sids = corpus_ids(path, ids)
    todo = [s for s in sids if s not in cache]
    print(f"{name}: {len(sids)} samples in {path}, {len(todo)} to measure", flush=True)
    lock = threading.Lock()

    def save():
        cache_path.write_text(json.dumps({"corpus": name, "path": str(path),
                                          "samples": cache}, indent=1) + "\n", encoding="utf-8")

    def one(sid):
        sol = path / sid / f"{sid}.sol"
        rec = measure(sol.read_text(encoding="utf-8") if sol.exists() else "")
        meta = json.loads((path / sid / "meta.json").read_text(encoding="utf-8"))
        rec["meta_is_valid"] = (meta.get("validation") or {}).get("is_valid")
        return sid, rec

    with ThreadPoolExecutor(max_workers=max(1, workers)) as pool:
        for n, fut in enumerate(as_completed([pool.submit(one, s) for s in todo]), 1):
            sid, rec = fut.result()
            with lock:
                cache[sid] = rec
                if n % 25 == 0:
                    save()
                    print(f"  {name}: {n}/{len(todo)}", flush=True)
    save()
    return {s: cache[s] for s in sids}


def summarize(samples: dict) -> dict:
    rows = list(samples.values())
    n = len(rows)
    ok = [r for r in rows if analysed(r)]
    pct = lambda k, m: 100.0 * k / m if m else None  # noqa: E731
    return {
        "n": n,
        "CPR": pct(sum(r["compiled"] for r in rows), n),
        "VRS": sum(r["risk"] for r in rows) / n if n else None,
        "ZRCP": pct(sum(r["risk"] == 0 for r in ok), len(ok)),
        "HRCP": pct(sum(r["by_impact"]["High"] > 0 for r in ok), len(ok)),
        "n_analysed": len(ok),
        "n_slither_error": sum(r["compiled"] and r["slither_error"] is not None for r in rows),
        "n_empty": sum(r.get("empty", False) for r in rows),
        "total_by_impact": {k: sum(r["by_impact"][k] for r in ok) for k in ("High", "Medium", "Low")},
        "meta_validity_disagreements": sum(r.get("meta_is_valid") is not None
                                           and bool(r["meta_is_valid"]) != r["compiled"] for r in rows),
    }


def paired(a: dict, b: dict) -> list:
    """a = compared corpus ("naive" slot), b = reference ("full" slot)."""
    sids = sorted(set(a) & set(b))
    both = [s for s in sids if analysed(a[s]) and analysed(b[s])]
    M, P, C = ps.PairedMetric.from_pairs, "proportion", "continuous"
    return ps.analyze([
        M("CPR (compiles)", P, [(s, a[s]["compiled"], b[s]["compiled"]) for s in sids]),
        M("Per-contract risk (VRS)", C, [(s, a[s]["risk"], b[s]["risk"]) for s in sids],
          lower_is_better=True, note="10 = does not compile / not analysable"),
        M("Zero-risk (ZRCP)", P, [(s, a[s]["risk"] == 0, b[s]["risk"] == 0) for s in both],
          note="pairs analysed on both sides"),
        M("No High finding (100 - HRCP)", P,
          [(s, a[s]["by_impact"]["High"] == 0, b[s]["by_impact"]["High"] == 0) for s in both],
          note="pairs analysed on both sides"),
    ])


def fmt(x, d=1):
    return "n/a" if x is None else f"{x:.{d}f}"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--corpus", action="append", default=[], metavar="NAME=DIR",
                    help="corpus to measure (repeatable; default: naive_glm, BoN6, fsm_scg, "
                         "with_kernel_spec, whichever exist)")
    ap.add_argument("--reference", default="with_kernel_spec")
    ap.add_argument("--ids", nargs="+", help="only these seed ids (e.g. a pilot)")
    ap.add_argument("--num-entries", type=int,
                    help="only the first N seeds of sol_seed.jsonl (500 = the ablation set)")
    ap.add_argument("--out-dir", default=str(DS / "analysis_results" / "vrs"))
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--recompute", action="store_true")
    args = ap.parse_args()

    corpora = dict(DEFAULT_CORPORA) if not args.corpus else {}
    for spec in args.corpus:
        name, _, path = spec.partition("=")
        corpora[name] = Path(path)
    if args.corpus and args.reference not in corpora:
        corpora[args.reference] = DEFAULT_CORPORA[args.reference]
    missing = [n for n, p in corpora.items() if not any(Path(p).glob("*/meta.json"))]
    for n in missing:
        print(f"skip {n}: no corpus at {corpora[n]}")
        corpora.pop(n)
    if args.reference not in corpora:
        sys.exit(f"reference corpus {args.reference} not found")

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    ids = set(args.ids) if args.ids else None
    if args.num_entries:
        from run_fsm_scg import load_seeds
        first = {s[0] for s in load_seeds()[: args.num_entries]}
        ids = ids & first if ids else first
    data = {n: run_corpus(n, Path(p), out_dir, ids, args.workers, args.recompute)
            for n, p in corpora.items()}
    summary = {n: summarize(d) for n, d in data.items()}
    comparisons = {n: paired(d, data[args.reference])
                   for n, d in data.items() if n != args.reference}

    label = lambda n: LABELS.get(n, n)  # noqa: E731
    md = [f"# FSM-SCG metrics (CPR / VRS / ZRCP / HRCP) over the Solidity corpora", "",
          f"- Slither: {analyzer_version()}; findings per upstream check_one_by_slither "
          "(all detectors, no Informational/Optimization, merged line ranges).",
          "- CPR by our `check_code` (solc standard-JSON, pragma-selected version).",
          "- Risk 10 for a contract that does not compile or that Slither cannot analyse; "
          "ZRCP/HRCP are over analysed contracts only.",
          f"- Seed filter: {len(ids)} ids" if ids else "- Seed filter: none", "",
          "| Corpus | n | CPR % | VRS | ZRCP % | HRCP % | analysed | Slither errors | High / Med / Low findings | meta≠solc |",
          "|---|---|---|---|---|---|---|---|---|---|"]
    for n, s in summary.items():
        t = s["total_by_impact"]
        md.append(f"| {label(n)} | {s['n']} | {fmt(s['CPR'])} | {fmt(s['VRS'], 2)} | "
                  f"{fmt(s['ZRCP'])} | {fmt(s['HRCP'])} | {s['n_analysed']} | "
                  f"{s['n_slither_error']} | {t['High']} / {t['Medium']} / {t['Low']} | "
                  f"{s['meta_validity_disagreements']} |")
    for n, res in comparisons.items():
        md += ["", f"## {label(n)} vs {label(args.reference)} (paired, Holm within this table)", "",
               report.markdown_table(res, (label(n), label(args.reference)))]
    (out_dir / "vrs_table.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    (out_dir / "vrs_summary.json").write_text(json.dumps(
        {"generated": datetime.now().isoformat(timespec="seconds"),
         "slither": analyzer_version(), "reference": args.reference,
         "ids_filter": sorted(ids) if ids else None,
         "corpora": {n: str(p) for n, p in corpora.items()}, "summary": summary,
         "paired": comparisons}, indent=2, default=report._json_default) + "\n", encoding="utf-8")
    print("\n".join(md))
    print(f"\nwrote {out_dir / 'vrs_table.md'} and vrs_summary.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
