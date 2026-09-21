#!/usr/bin/env python3
"""Paired analysis of the Solidity ablation ladder (A0..A5), on the same metrics
and with the same statistics as `nl2solidity/analyze_naive_vs_full.py`.

The ladder is monotone: each arm is the one below it plus exactly one stage
(A0 one-shot -> +RAG -> +MoE -> +compiler repair -> +execution repair -> +Slither
and spec alignment; see ablation/profiles.py). Two families of paired comparisons
answer two different questions, and both are run:

    step        A(k-1) -> A(k)   what does stage k add on its own?
    cumulative  A0     -> A(k)   what has the pipeline bought over one-shot by stage k?
                                 (A0 -> A5 is the ablation-native full-vs-naive)

Each comparison is the full naive-vs-full treatment: McNemar / Cohen's h for the
rates, Wilcoxon / rank-biserial / d_z for the counts, Holm across the metric table,
power, the first-failing-stage table and the by-category table, plus PNGs. On top
sits `ablation_summary.md`: every metric down the whole ladder, then the step and
cumulative effects side by side.

Reads ONLY the cached `meta.json` each arm wrote (every arm is scored on every
metric, so no arm is missing a column). No solc / forge / slither / LLM call, so
it runs in a few seconds (all nine comparisons, plots included) and gives identical
numbers on a laptop and on PACE; no SLURM job is needed.
The metric definitions are imported from analyze_naive_vs_full, not copied, so
"the same metrics" holds by construction.

Layout under --root:    <root>/A0/<sid>/meta.json ... <root>/A5/<sid>/meta.json
Default --root:         dataset/ablation (what the sbatch jobs write). A local
                        copy at ablation/solidity_ablation/ablation is used when
                        that is absent.

Usage
    python nl2solidity/ablation/analyze_ablation.py
    python nl2solidity/ablation/analyze_ablation.py --root <dir holding A0..A5>
    python nl2solidity/ablation/analyze_ablation.py --mode step --no-plots
    python nl2solidity/ablation/analyze_ablation.py --compare A0:A3 --compare A3:A5
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Optional

_NL2 = Path(__file__).resolve().parent.parent
_ROOT = _NL2.parent
sys.path.insert(0, str(_ROOT))

from analysis import paired_stats as ps  # noqa: E402
from analysis import report  # noqa: E402
from nl2solidity import analyze_naive_vs_full as nvf  # noqa: E402

ARMS = ["A0", "A1", "A2", "A3", "A4", "A5"]
ARM_ADDS = {
    "A0": "one-shot GLM-5.2",
    "A1": "+ RAG",
    "A2": "+ MoE",
    "A3": "+ compiler repair",
    "A4": "+ execution repair",
    "A5": "+ Slither & spec alignment (full)",
}

DATASET = _NL2 / "dataset"
ROOT_CANDIDATES = [DATASET / "ablation", _NL2 / "ablation" / "solidity_ablation" / "ablation"]
DEFAULT_OUT = DATASET / "analysis_results" / "ablation"


# ---- inputs -----------------------------------------------------------------
def resolve_root(arg: Optional[str]) -> Path:
    candidates = [Path(arg)] if arg else ROOT_CANDIDATES
    for c in candidates:
        if any(c.glob("A*/*/meta.json")):
            return c
    sys.exit("No ablation arms found under:\n  " + "\n  ".join(map(str, candidates)) +
             "\nPass --root <dir containing A0/ ... A5/> (e.g. the PACE dataset/ablation).")


def parse_comparisons(args: argparse.Namespace, arms: list[str]) -> list[tuple[str, str]]:
    """Ordered, de-duplicated (reference, comparison) arm pairs."""
    pairs: list[tuple[str, str]] = []
    if args.compare:
        for spec in args.compare:
            a, sep, b = spec.partition(":")
            if not sep or a not in ARMS or b not in ARMS or a == b:
                sys.exit(f"--compare expects REF:ARM with distinct arms from {ARMS}, got {spec!r}")
            pairs.append((a, b))
    else:
        if args.mode in ("step", "both"):
            pairs += [(ARMS[i - 1], ARMS[i]) for i in range(1, len(ARMS))]
        if args.mode in ("cumulative", "both"):
            pairs += [(ARMS[0], ARMS[i]) for i in range(1, len(ARMS))]
    seen, out = set(), []
    for p in pairs:
        if p in seen:
            continue
        seen.add(p)
        if p[0] in arms and p[1] in arms:
            out.append(p)
        else:
            print(f"  ! skipping {p[0]} vs {p[1]}: arm not present", file=sys.stderr)
    return out


def slug(a: str, b: str) -> str:
    return f"{a}_to_{b}"


# ---- per-comparison extras (same sections as naive-vs-full) -----------------
def by_category(ref: dict, cmp_: dict, sids: list[str], labels: tuple[str, str]) -> str:
    a_lab, b_lab = labels
    groups: dict[str, list[str]] = defaultdict(list)
    for s in sids:
        groups[cmp_[s].get("category") or ref[s].get("category") or "unknown"].append(s)

    def rate(getter, corpus, members):
        vals = [v for v in (getter(corpus[s]) for s in members) if v is not None]
        return f"{sum(vals) / len(vals) * 100:.0f}%" if vals else "n/a"

    def mean_sim(corpus, members):
        vals = [v for v in (nvf.similarity(corpus[s]) for s in members) if v is not None]
        return f"{sum(vals) / len(vals):.3f}" if vals else "n/a"

    fuzz = nvf.tier_passed("fuzz")
    rows = [[cat, len(m),
             rate(nvf.is_valid, ref, m), rate(nvf.is_valid, cmp_, m),
             rate(fuzz, ref, m), rate(fuzz, cmp_, m),
             mean_sim(ref, m), mean_sim(cmp_, m)]
            for cat, m in sorted(groups.items(), key=lambda kv: -len(kv[1]))]
    return report.table_md(
        ["Category", "n", f"Compile {a_lab}", f"Compile {b_lab}", f"Fuzz {a_lab}", f"Fuzz {b_lab}",
         f"Similarity {a_lab}", f"Similarity {b_lab}"], rows)


FAIL_ORDER = ["empty output", "fails solc", "solc ok, Foundry build fails",
              "compiles, fuzz tier fails", "fuzz ok, property tier not passed",
              "passes execution tiers"]


def failure_table(corpora: dict[str, dict], arms: list[str], sids: list[str]) -> str:
    counts = {a: nvf.failure_breakdown(corpora[a], sids) for a in arms}
    n = len(sids)
    return report.table_md(
        ["Outcome (first failing stage)"] + arms,
        [[k] + [f"{counts[a][k]} ({counts[a][k] / n * 100:.1f}%)" for a in arms] for k in FAIL_ORDER])


def run_comparison(ref_arm: str, cmp_arm: str, corpora: dict[str, dict], out_dir: Path,
                   root: Path, plots: bool) -> dict:
    ref, cmp_ = corpora[ref_arm], corpora[cmp_arm]
    sids = sorted(set(ref) & set(cmp_))
    labels = (ref_arm, cmp_arm)
    metrics = nvf.build_metrics(ref, cmp_, sids)
    results = ps.analyze(metrics)
    title = f"Ablation {ref_arm} -> {cmp_arm}: {ARM_ADDS[ref_arm]} vs {ARM_ADDS[cmp_arm]} (n={len(sids)} pairs)"
    report.print_summary(results, title, labels)

    header = [
        f"- Reference arm **{ref_arm}** ({ARM_ADDS[ref_arm]}): {len(ref)} samples in `{root / ref_arm}`",
        f"- Comparison arm **{cmp_arm}** ({ARM_ADDS[cmp_arm]}): {len(cmp_)} samples in `{root / cmp_arm}`",
        f"- Paired on sid: **{len(sids)}** ({ref_arm}-only {len(set(ref) - set(cmp_))}, "
        f"{cmp_arm}-only {len(set(cmp_) - set(ref))})",
        f"- Δ is the raw difference ({cmp_arm} − {ref_arm}); the effect size is signed so that "
        f"positive means {cmp_arm} is better. All metrics come from cached `meta.json`; a metric "
        "missing for either side of a pair drops that pair from that metric only (see `n` per row).",
    ]
    written = report.write_outputs(
        out_dir, title=title, header_lines=header, results=results,
        extra_sections=[("First failing stage", failure_table({ref_arm: ref, cmp_arm: cmp_},
                                                              [ref_arm, cmp_arm], sids)),
                        ("By category", by_category(ref, cmp_, sids, labels))],
        meta={"reference": ref_arm, "comparison": cmp_arm, "root": str(root),
              "n_pairs": len(sids), "reference_total": len(ref), "comparison_total": len(cmp_)},
        plots=plots, metrics=metrics, labels=labels)
    return {"results": results, "n_pairs": len(sids), "written": written}


# ---- ladder (descriptive, every arm on one common footing) ------------------
def ladder(corpora: dict[str, dict], arms: list[str]) -> dict:
    """Per-arm value of every metric on the sids present in ALL arms. Security
    metrics are further restricted to sids where every arm compiles, so the row is
    comparable across arms (Slither reports 0 findings for uncompilable code)."""
    common = sorted(set.intersection(*(set(corpora[a]) for a in arms)))
    all_compile = [s for s in common if all(nvf.is_valid(corpora[a][s]) is True for a in arms)]
    per_arm: dict[str, dict[str, dict]] = {}
    for a in arms:
        # (arm, arm) pairing: the "naive" side of each PairedMetric is this arm's value.
        for m in nvf.build_metrics(corpora[a], corpora[a], common, security_sids=all_compile):
            vals = [float(v) for v in m.naive]
            entry = {"n": len(vals), "kind": m.kind, "lower_is_better": m.lower_is_better,
                     "note": m.note}
            if not vals:
                entry.update(value=None, ci=None)
            elif m.kind == "proportion":
                k = int(sum(vals))
                entry.update(value=k / len(vals) * 100, ci=ps.wilson_ci(k, len(vals)))
            else:
                entry.update(value=sum(vals) / len(vals), ci=ps.bootstrap_mean_ci(vals))
            per_arm.setdefault(m.name, {})[a] = entry
    return {"common_n": len(common), "all_compile_n": len(all_compile), "metrics": per_arm}


def _fmt(entry: dict) -> str:
    if entry["value"] is None:
        return "n/a"
    return f"{entry['value']:.1f}%" if entry["kind"] == "proportion" else f"{entry['value']:.3g}"


def ladder_table(lad: dict, arms: list[str]) -> str:
    rows = []
    for name, by_arm in lad["metrics"].items():
        first = next(iter(by_arm.values()))
        arrow = " ↓" if first["lower_is_better"] else ""
        rows.append([name + arrow, first["n"]] + [_fmt(by_arm[a]) for a in arms])
    return report.table_md(["Metric (↓ = lower is better)", "n"] + arms, rows)


def effect_table(all_results: dict[tuple[str, str], list[dict]], pairs: list[tuple[str, str]],
                 metric_names: list[str]) -> str:
    """One row per metric, one column per comparison: raw delta (later - earlier),
    marked * when Holm p < 0.05."""
    def cell(r: Optional[dict]) -> str:
        if r is None or r["skipped"]:
            return "n/a"
        d = r["delta"]
        text = f"{d:+.1f} pp" if r["kind"] == "proportion" else f"{d:+.3g}"
        return text + ("*" if r["p_holm"] < ps.ALPHA else "")

    lower = {r["metric"] for r in next(iter(all_results.values())) if r["lower_is_better"]}
    rows = []
    for name in metric_names:
        row = [name + (" ↓" if name in lower else "")]
        for p in pairs:
            match = next((r for r in all_results[p] if r["metric"] == name), None)
            row.append(cell(match))
        rows.append(row)
    return report.table_md(["Metric (↓ = lower is better)"] + [f"{a}→{b}" for a, b in pairs], rows)


def category_ladder(corpora: dict[str, dict], arms: list[str], sids: list[str]) -> str:
    """Quality-grade-A rate per category per arm: where in the taxonomy each stage pays."""
    groups: dict[str, list[str]] = defaultdict(list)
    for s in sids:
        groups[corpora[arms[-1]][s].get("category") or "unknown"].append(s)
    rows = []
    for cat, m in sorted(groups.items(), key=lambda kv: -len(kv[1])):
        cells = []
        for a in arms:
            vals = [v for v in (nvf.grade_a(corpora[a][s]) for s in m) if v is not None]
            cells.append(f"{sum(vals) / len(vals) * 100:.0f}%" if vals else "n/a")
        rows.append([cat, len(m)] + cells)
    return report.table_md(["Category", "n"] + arms, rows)


# ---- ladder plots -----------------------------------------------------------
def ladder_plots(out_dir: Path, lad: dict, arms: list[str]) -> dict[str, Path]:
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib not installed — skipping ladder plots (pip install matplotlib)")
        return {}
    written: dict[str, Path] = {}
    for kind, fname, ylabel in (("proportion", "ladder_rates.png", "Rate (%), 95% Wilson CI"),
                                ("continuous", "ladder_continuous.png", "Mean, 95% bootstrap CI")):
        items = [(n, d) for n, d in lad["metrics"].items()
                 if next(iter(d.values()))["kind"] == kind and all(d[a]["value"] is not None for a in arms)]
        if not items:
            continue
        cols = min(3, len(items))
        nrows = (len(items) + cols - 1) // cols
        fig, axes = plt.subplots(nrows, cols, figsize=(4.4 * cols, 3.2 * nrows), squeeze=False)
        x = list(range(len(arms)))
        for ax, (name, d) in zip(axes.flat, items):
            y = [d[a]["value"] for a in arms]
            lo = [d[a]["value"] - d[a]["ci"][0] for a in arms]
            hi = [d[a]["ci"][1] - d[a]["value"] for a in arms]
            ax.errorbar(x, y, yerr=[lo, hi], marker="o", color=report.FULL_COLOR, capsize=3)
            ax.set_xticks(x, arms)
            ax.set_title(f"{name} (n={d[arms[0]]['n']})", fontsize=9)
            ax.grid(alpha=0.25)
            if kind == "proportion":
                ax.set_ylim(0, 100)
        for ax in list(axes.flat)[len(items):]:
            ax.axis("off")
        fig.supylabel(ylabel, fontsize=9)
        fig.tight_layout()
        p = out_dir / fname
        fig.savefig(p, dpi=150)
        plt.close(fig)
        written[fname.removesuffix(".png")] = p
    return written


# ---- main -------------------------------------------------------------------
def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", help="directory holding A0/ .. A5/ "
                                   f"(default {ROOT_CANDIDATES[0].relative_to(_ROOT)}, else the local copy)")
    ap.add_argument("--out-dir", default=str(DEFAULT_OUT), help="where to write results")
    ap.add_argument("--mode", choices=["both", "step", "cumulative"], default="both",
                    help="step = A(k-1)->A(k); cumulative = A0->A(k); default both")
    ap.add_argument("--compare", action="append", metavar="REF:ARM",
                    help="explicit comparison, repeatable (overrides --mode), e.g. A2:A4")
    ap.add_argument("--no-plots", action="store_true")
    args = ap.parse_args()

    t0 = time.time()
    root = resolve_root(args.root)
    corpora = {a: nvf.load_corpus(root / a) for a in ARMS if any((root / a).glob("*/meta.json"))}
    arms = [a for a in ARMS if a in corpora]
    print(f"root: {root}")
    for a in arms:
        print(f"  {a}  {len(corpora[a]):>4} samples   {ARM_ADDS[a]}")
    missing = [a for a in ARMS if a not in corpora]
    if missing:
        print(f"  ! no samples for {', '.join(missing)}", file=sys.stderr)
    pairs = parse_comparisons(args, arms)
    if not pairs:
        sys.exit("Nothing to compare: need at least two arms.")

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    all_results: dict[tuple[str, str], list[dict]] = {}
    n_pairs: dict[tuple[str, str], int] = {}
    for a, b in pairs:
        print()
        r = run_comparison(a, b, corpora, out_dir / slug(a, b), root, plots=not args.no_plots)
        all_results[(a, b)], n_pairs[(a, b)] = r["results"], r["n_pairs"]

    # -- ladder summary --------------------------------------------------------
    summary_json: dict = {"generated": datetime.now().isoformat(timespec="seconds"),
                          "alpha": ps.ALPHA, "root": str(root), "arms": arms,
                          "comparisons": {f"{a}->{b}": {"n_pairs": n_pairs[(a, b)],
                                                        "results": all_results[(a, b)]}
                                          for a, b in pairs}}
    md = ["# Solidity ablation ladder", "",
          "Arms (each is the one below plus exactly one stage):", ""]
    md += [f"- **{a}** — {ARM_ADDS[a]} ({len(corpora[a])} samples)" for a in arms]
    md.append("")

    if len(arms) >= 2:
        lad = ladder(corpora, arms)
        summary_json["ladder"] = lad
        md += ["## Every metric down the ladder", "",
               f"Descriptive. Restricted to the **{lad['common_n']}** seeds present in every arm; "
               f"the Slither rows are further restricted to the **{lad['all_compile_n']}** seeds "
               "where every arm compiles, because Slither reports 0 findings for code it cannot "
               "analyse. Tests are in the comparison tables below.", "",
               ladder_table(lad, arms), ""]
        common = sorted(set.intersection(*(set(corpora[a]) for a in arms)))
        md += ["## First failing stage", "",
               failure_table(corpora, arms, common), "",
               "## Quality grade A by category", "",
               category_ladder(corpora, arms, common), ""]

    metric_names = [r["metric"] for r in next(iter(all_results.values())) if not r["skipped"]]
    for heading, sel, blurb in (
            ("Step effects: what each stage adds", [p for p in pairs if ARMS.index(p[1]) - ARMS.index(p[0]) == 1],
             "Each column pairs an arm with the one directly below it on the ladder."),
            ("Cumulative effects vs one-shot (A0)", [p for p in pairs if p[0] == "A0" and p[1] != "A1"],
             "Each column pairs an arm with A0. A0→A5 is the ablation-native full-vs-naive; "
             "A0→A1 is already in the step table.")):
        if sel:
            md += [f"## {heading}", "",
                   f"{blurb} Each cell is the raw Δ (later − earlier): a rise is good for a "
                   "rate, a fall is good for a ↓ metric. `*` marks Holm-adjusted p < 0.05 within "
                   "that comparison's table. Effect sizes, CIs and power per comparison are in "
                   "`<from>_to_<to>/comparison.md`.", "",
                   effect_table(all_results, sel, metric_names), ""]
    md += ["## Reading these numbers", "",
           "* Holm correction is applied **within** each comparison's metric table (as in the "
           "naive-vs-full analysis), not across comparisons. With nine comparisons, treat an "
           "isolated `*` at p just under 0.05 as suggestive.",
           "* Every arm is *measured* by every checker (solc, Foundry, Slither, aligner) even where "
           "the stage is not used for repair, so a metric moves between arms only because of the "
           "stage that was added, not because it started being measured.",
           "* Later arms repair against the very checkers that score them (A3 against solc, A4 "
           "against Foundry, A5 against Slither and the aligner). Gains on those metrics are "
           "expected by construction; the informative signal is on the metrics a stage does not "
           "repair against.", ""]
    (out_dir / "ablation_summary.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    (out_dir / "ablation_summary.json").write_text(
        json.dumps(summary_json, indent=2, default=report._json_default) + "\n", encoding="utf-8")
    if not args.no_plots and len(arms) >= 2:
        for kind, path in ladder_plots(out_dir, lad, arms).items():
            print(f"wrote {kind}: {path}")

    print(f"\nwrote {out_dir / 'ablation_summary.md'}")
    print(f"wrote {out_dir / 'ablation_summary.json'}")
    print(f"{len(pairs)} comparisons in {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
