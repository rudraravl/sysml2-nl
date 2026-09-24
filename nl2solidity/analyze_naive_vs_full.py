#!/usr/bin/env python3
"""Paired naive-vs-full analysis of Solidity generation (Solidity twin of the
SysML comparison notebook's compiler / kernel / spec-alignment / power sections).

Reads ONLY the cached `meta.json` each generator wrote (solc validation, Foundry
execution, Slither security, spec-alignment) — no solc / forge / slither / LLM
calls — so it runs in seconds and works identically on the local checkout and on
a PACE copy of the outputs.

Two corpora, same directory layout (`<dir>/<sid>/meta.json` + `<sid>.sol`):

    naive  = single-model baseline   default dataset/naive_glm
    full   = complete pipeline       default dataset/with_kernel_spec

Only these two are compared; ablation arms and the human-authored reference
corpus (dataset/data) are deliberately not valid inputs here. Samples are paired
on sid and only the intersection is analysed.

`naive_glm` is produced by naive_glm_generate.py, which only runs solc. Foundry,
Slither and spec-alignment results are added to those meta.json files by
score_naive_glm.py (the same checkers, measure-only); until that has run, only the
solc rows are paired and the other rows are reported as skipped. Point
--naive-dir / --full-dir at a PACE copy to run it there.

Besides the paired-test table this writes extra tables and paper figures
(`naive_vs_full_extras.py`) under `<out-dir>/figures/` as PNG + vector PDF, and
every computed number to `extras.json`.

Usage
    python nl2solidity/analyze_naive_vs_full.py
    python nl2solidity/analyze_naive_vs_full.py \\
        --naive-dir /path/to/naive_glm --full-dir /path/to/with_kernel_spec
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Callable, Optional

_NL2 = Path(__file__).resolve().parent
_ROOT = _NL2.parent
sys.path.insert(0, str(_ROOT))

from analysis import paired_stats as ps  # noqa: E402
from analysis import report  # noqa: E402
from nl2solidity import naive_vs_full_extras as extras  # noqa: E402

DATASET = _NL2 / "dataset"
NAIVE_DEFAULT = DATASET / "naive_glm"
FULL_DEFAULT = DATASET / "with_kernel_spec"
DEFAULT_OUT = DATASET / "analysis_results" / "naive_vs_full"


# ---- loading ----------------------------------------------------------------
def load_corpus(directory: Path) -> dict[str, dict]:
    """{sid: meta} for every `<dir>/<sid>/meta.json`, tolerating claim dirs and
    half-written files (skipped, counted by the caller via the returned size)."""
    out: dict[str, dict] = {}
    for meta_path in sorted(directory.glob("*/meta.json")):
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as e:
            print(f"  ! unreadable {meta_path}: {e}", file=sys.stderr)
            continue
        sid = meta_path.parent.name
        sol = meta_path.parent / f"{sid}.sol"
        meta["_empty"] = (not sol.exists()) or not sol.read_text(encoding="utf-8").strip()
        meta["_dir"] = str(meta_path.parent)
        out[sid] = meta
    return out


def resolve_dirs(args: argparse.Namespace) -> tuple[Path, Path]:
    naive = Path(args.naive_dir) if args.naive_dir else NAIVE_DEFAULT
    full = Path(args.full_dir) if args.full_dir else FULL_DEFAULT
    if not any(naive.glob("*/meta.json")):
        sys.exit(
            f"No naive corpus at {naive}.\n"
            "Generate it with nl2solidity/naive_glm_generate.py (then score it with "
            "score_naive_glm.py), or pass --naive-dir pointing at the naive_glm output "
            "(e.g. a copy from PACE).\n"
            "For the full-pipeline corpus alone, see nl2solidity/analyze_with_kernel_spec.py.")
    if not any(full.glob("*/meta.json")):
        sys.exit(f"No full-pipeline corpus at {full}; pass --full-dir.")
    return naive, full


# ---- per-sample accessors (None = metric unavailable for this sample) -------
def _exec(m: dict) -> Optional[dict]:
    e = m.get("execution")
    return e if isinstance(e, dict) else None


def is_valid(m: dict) -> Optional[bool]:
    v = m.get("validation")
    return None if not isinstance(v, dict) or "is_valid" not in v else bool(v["is_valid"])


def solc_errors(m: dict) -> Optional[float]:
    v = m.get("validation")
    return None if not isinstance(v, dict) or "error_count" not in v else float(v["error_count"])


def deploy_compiled(m: dict) -> Optional[bool]:
    e = _exec(m)
    return None if e is None or "compiled" not in e else bool(e["compiled"])


def tier_passed(tier: str) -> Callable[[dict], Optional[bool]]:
    def get(m: dict) -> Optional[bool]:
        e = _exec(m)
        if e is None or tier not in (e.get("tier_status") or {}):
            return None
        return e["tier_status"][tier] == "passed"
    return get


def contract_defects(m: dict) -> Optional[float]:
    e = _exec(m)
    return None if e is None or "contract_defects" not in e else float(e["contract_defects"])


def defect_free(m: dict) -> Optional[bool]:
    e = _exec(m)
    if e is None or "contract_defects" not in e or "compiled" not in e:
        return None
    return bool(e["compiled"]) and e["contract_defects"] == 0


def _sec(m: dict, key: str) -> Optional[float]:
    s = m.get("security")
    return None if not isinstance(s, dict) or key not in s else float(s[key])


def sec_findings(m: dict) -> Optional[float]:
    return _sec(m, "n_findings")


def sec_actionable(m: dict) -> Optional[float]:
    return _sec(m, "n_actionable")


def sec_clean(m: dict) -> Optional[bool]:
    v = _sec(m, "n_actionable")
    return None if v is None else v == 0


def similarity(m: dict) -> Optional[float]:
    s = m.get("spec_alignment")
    if not isinstance(s, dict) or s.get("similarity") is None:
        return None
    return float(s["similarity"])


def align_accepted(m: dict) -> Optional[bool]:
    s = m.get("spec_alignment")
    if not isinstance(s, dict) or s.get("accepted") is None:
        return None
    return bool(s["accepted"])


def grade_a(m: dict) -> Optional[bool]:
    q = m.get("quality")
    return None if q is None else q == "A"


# ---- metric assembly --------------------------------------------------------
def build_metrics(naive: dict[str, dict], full: dict[str, dict],
                  sids: list[str],
                  security_sids: Optional[list[str]] = None) -> list[ps.PairedMetric]:
    """Every metric is paired on sid. Slither returns 0 findings for a contract
    that did not compile (there is nothing to analyse), so a worse-compiling
    corpus would look 'safer'. The security metrics are therefore restricted to
    pairs where BOTH sides compile.

    `security_sids` replaces that restriction with an explicit subset; the
    ablation ladder uses it to score every arm on one common set."""
    def pairs(get, subset=None):
        return [(s, get(naive[s]), get(full[s])) for s in (subset if subset is not None else sids)]

    both_compile = security_sids if security_sids is not None else [
        s for s in sids if is_valid(naive[s]) is True and is_valid(full[s]) is True]
    sec_note = f"restricted to the {len(both_compile)} pairs where both contracts compile"

    P, C = "proportion", "continuous"
    M = ps.PairedMetric.from_pairs
    return [
        M("solc compile-valid", P, pairs(is_valid)),
        M("Deploy-compiled (Foundry build)", P, pairs(deploy_compiled)),
        M("Fuzz tier passed", P, pairs(tier_passed("fuzz"))),
        M("Property tier passed", P, pairs(tier_passed("properties")),
          note="a 'skipped' tier (e.g. no property tests generated) counts as not passed"),
        M("Contract-defect-free execution", P, pairs(defect_free),
          note="compiled under Foundry with zero contract defects"),
        M("Slither actionable-clean", P, pairs(sec_clean, both_compile), note=sec_note),
        M("Spec alignment accepted", P, pairs(align_accepted),
          note="final similarity >= the aligner threshold (0.8)"),
        M("Quality grade A", P, pairs(grade_a),
          note="the pipeline's own quality gate (compile + execute + security + alignment)"),
        M("solc errors per sample", C, pairs(solc_errors), lower_is_better=True),
        M("Contract defects per sample", C, pairs(contract_defects), lower_is_better=True),
        M("Slither findings per sample", C, pairs(sec_findings, both_compile),
          lower_is_better=True, note=sec_note),
        M("Slither actionable findings per sample", C, pairs(sec_actionable, both_compile),
          lower_is_better=True, note=sec_note),
        M("Spec-alignment similarity", C, pairs(similarity),
          note="twin-blind aligner score in [0, 1]"),
    ]


def by_category(naive: dict[str, dict], full: dict[str, dict], sids: list[str],
                labels: tuple[str, str] = report.DEFAULT_LABELS) -> str:
    groups: dict[str, list[str]] = defaultdict(list)
    for s in sids:
        groups[full[s].get("category") or naive[s].get("category") or "unknown"].append(s)

    def rate(getter, corpus, members):
        vals = [getter(corpus[s]) for s in members]
        vals = [v for v in vals if v is not None]
        return f"{sum(vals) / len(vals) * 100:.0f}%" if vals else "n/a"

    def mean_sim(corpus, members):
        vals = [similarity(corpus[s]) for s in members]
        vals = [v for v in vals if v is not None]
        return f"{sum(vals) / len(vals):.3f}" if vals else "n/a"

    def has(getter, corpus):
        return any(getter(corpus[s]) is not None for s in sids)

    cols = [("Compile", is_valid, rate), ("Fuzz", tier_passed("fuzz"), rate),
            ("Slither clean", sec_clean, rate), ("Similarity", similarity, None)]
    cols = [c for c in cols if has(c[1], naive) and has(c[1], full)]  # both sides scored
    headers = ["Category", "n"]
    for name, _, _ in cols:
        headers += [f"{name} {labels[0].lower()}", f"{name} {labels[1].lower()}"]
    rows = []
    for cat, members in sorted(groups.items(), key=lambda kv: -len(kv[1])):
        row = [cat, len(members)]
        for _, getter, fmt in cols:
            if fmt:
                row += [fmt(getter, naive, members), fmt(getter, full, members)]
            else:
                row += [mean_sim(naive, members), mean_sim(full, members)]
        rows.append(row)
    return report.table_md(headers, rows)


def failure_breakdown(corpus: dict[str, dict], sids: list[str]) -> str:
    """Where each sample ends up: the cheapest first-look at *why* rates differ.
    A sample with no execution record is reported as such, never as a pass."""
    c: Counter = Counter()
    for s in sids:
        m = corpus[s]
        if m["_empty"]:
            c["empty output"] += 1
        elif is_valid(m) is False:
            c["fails solc"] += 1
        elif deploy_compiled(m) is None:
            c["solc ok, execution not scored"] += 1
        elif deploy_compiled(m) is False:
            c["solc ok, Foundry build fails"] += 1
        elif tier_passed("fuzz")(m) is False:
            c["compiles, fuzz tier fails"] += 1
        elif tier_passed("properties")(m) is False:
            c["fuzz ok, property tier not passed"] += 1
        else:
            c["passes execution tiers"] += 1
    return c


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--naive-dir", help=f"naive-baseline samples (default {NAIVE_DEFAULT.relative_to(_ROOT)})")
    ap.add_argument("--full-dir", help=f"full-pipeline samples (default {FULL_DEFAULT.relative_to(_ROOT)})")
    ap.add_argument("--out-dir", default=str(DEFAULT_OUT), help="where to write results")
    ap.add_argument("--no-plots", action="store_true")
    ap.add_argument("--naive-label", default=report.DEFAULT_LABELS[0],
                    help="display name of the --naive-dir corpus (e.g. FSM-SCG*)")
    ap.add_argument("--full-label", default=report.DEFAULT_LABELS[1],
                    help="display name of the --full-dir corpus (e.g. FORGE)")
    ap.add_argument("--ids", nargs="+", help="pair only these sample ids (e.g. a pilot)")
    args = ap.parse_args()
    labels = (args.naive_label, args.full_label)

    naive_dir, full_dir = resolve_dirs(args)

    naive, full = load_corpus(naive_dir), load_corpus(full_dir)
    if args.ids:
        wanted = set(args.ids)
        naive = {s: m for s, m in naive.items() if s in wanted}
        full = {s: m for s, m in full.items() if s in wanted}
    sids = sorted(set(naive) & set(full))
    print(f"naive : {naive_dir}  ({len(naive)} samples)")
    print(f"full  : {full_dir}  ({len(full)} samples)")
    print(f"paired: {len(sids)}   naive-only: {len(set(naive) - set(full))}   "
          f"full-only: {len(set(full) - set(naive))}")
    if not sids:
        sys.exit("No overlapping sample ids — nothing to compare.")

    metrics = build_metrics(naive, full, sids)
    results = ps.analyze(metrics)
    title = (f"Naive vs full pipeline — Solidity (naive vs full, n={len(sids)} pairs)"
             if labels == report.DEFAULT_LABELS else
             f"{labels[0]} vs {labels[1]} — Solidity (n={len(sids)} pairs)")
    report.print_summary(results, title, labels)

    nb, fb = failure_breakdown(naive, sids), failure_breakdown(full, sids)
    order = ["empty output", "fails solc", "solc ok, execution not scored",
             "solc ok, Foundry build fails", "compiles, fuzz tier fails",
             "fuzz ok, property tier not passed", "passes execution tiers"]
    order = [k for k in order if nb[k] or fb[k]]
    fail_tbl = report.table_md(
        ["Outcome (first failing stage)", *labels],
        [[k, f"{nb[k]} ({nb[k] / len(sids) * 100:.1f}%)", f"{fb[k]} ({fb[k] / len(sids) * 100:.1f}%)"]
         for k in order])

    out_dir = Path(args.out_dir)
    extra_sections, extra_nums = extras.build(naive, full, sids, out_dir, plots=not args.no_plots)
    header = [
        f"- {labels[0]} corpus: `{naive_dir}` — {len(naive)} samples",
        f"- {labels[1]} corpus: `{full_dir}` — {len(full)} samples",
        f"- Paired on sid: **{len(sids)}** (naive-only {len(set(naive) - set(full))}, "
        f"full-only {len(set(full) - set(naive))})",
        "- All metrics come from cached `meta.json`; a metric missing for either side of a "
        "pair drops that pair from that metric only (see `n` per row).",
    ]
    written = report.write_outputs(
        out_dir, title=title, header_lines=header, results=results,
        extra_sections=[("First failing stage", fail_tbl),
                        ("By category", by_category(naive, full, sids, labels))] + extra_sections,
        meta={"naive_dir": str(naive_dir), "full_dir": str(full_dir), "n_pairs": len(sids),
              "naive_total": len(naive), "full_total": len(full),
              "labels": list(labels), "ids_filter": sorted(args.ids) if args.ids else None},
        plots=not args.no_plots, metrics=metrics, labels=labels)
    extras_path = out_dir / "extras.json"
    extras_path.write_text(json.dumps(extra_nums, indent=2, default=str) + "\n", encoding="utf-8")
    written["extras"] = extras_path
    print()
    for kind, path in written.items():
        print(f"wrote {kind}: {path}")


if __name__ == "__main__":
    main()
