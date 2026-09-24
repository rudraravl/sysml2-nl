"""Domain-neutral driver for ablation-ladder analyses.

An ablation ladder is an ordered list of arms, each the one before it plus one
stage. This module owns everything that does not depend on the domain: the CLI,
which arm pairs to compare, the paired tests per pair (via `paired_stats`), the
per-arm "ladder" table on a common footing, the step / cumulative effect tables,
plots and file output. A domain script supplies a `Study` describing how to load
its arms and which metrics to score; see nl2solidity/ablation/analyze_ablation.py
and nl2sysml/analyze_ablation.py.

Two families of comparison are run, and answer different questions:

    step        A(k-1) -> A(k)   what does stage k add on its own?
    cumulative  A(first) -> A(k) what has the pipeline bought over the lowest rung?

Outputs under --out-dir
    ablation_summary.md / .json    the ladder, then step and cumulative effects
    ladder_rates.png / ladder_continuous.png
    <from>_to_<to>/comparison.md / .json / *.png     one directory per comparison
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any, Callable, Optional, Sequence

from . import paired_stats as ps
from . import report

Section = tuple[str, str]  # (markdown heading, markdown body)


@dataclass
class Study:
    domain: str                                   # "Solidity"
    doc: str                                      # CLI help text
    default_out: Path
    unit: str                                     # plural noun for one item: "seeds", "tasks"
    key_name: str                                 # what pairs are keyed on: "sid", "task"
    source_desc: str                              # "cached `meta.json`"
    cumulative_note: str                          # {first}/{second}/{last} placeholders
    notes: list[str]                              # bullets under "Reading these numbers"

    find_root: Callable[[Optional[str]], Path]
    discover: Callable[[Path], dict[str, str]]    # ordered {arm: description} present under root
    load: Callable[[Path, str], dict]             # (root, arm) -> {key: record}
    build_metrics: Callable[[dict, dict, list[str]], list[ps.PairedMetric]]
    pair_sections: Callable[[str, str, dict, dict, list[str]], list[Section]]

    # Ladder hooks. `ladder_context` runs once and may return arbitrary values
    # (keys not starting with "_" are copied into the summary JSON); the same dict
    # is handed to `ladder_metrics`, which must score ONE arm's corpus on `common`.
    ladder_context: Callable[[dict[str, dict], list[str], list[str]], dict] = (
        lambda corpora, arms, common: {})
    ladder_metrics: Callable[[dict, list[str], dict], list[ps.PairedMetric]] = None  # set by domain
    ladder_note: Callable[[dict], str] = lambda ctx: "."
    ladder_sections: Callable[[Path, dict[str, dict], list[str], list[str]], list[Section]] = (
        lambda root, corpora, arms, common: [])


# ---- comparison selection ---------------------------------------------------
def parse_comparisons(args: argparse.Namespace, arms: list[str]) -> list[tuple[str, str]]:
    """Ordered, de-duplicated (reference, comparison) arm pairs."""
    pairs: list[tuple[str, str]] = []
    if args.compare:
        for spec in args.compare:
            a, sep, b = spec.partition(":")
            if not sep or a not in arms or b not in arms or a == b:
                sys.exit(f"--compare expects REF:ARM with distinct arms from {arms}, got {spec!r}")
            pairs.append((a, b))
    else:
        if args.mode in ("step", "both"):
            pairs += [(arms[i - 1], arms[i]) for i in range(1, len(arms))]
        if args.mode in ("cumulative", "both"):
            pairs += [(arms[0], arms[i]) for i in range(1, len(arms))]
    seen, out = set(), []
    for p in pairs:
        if p not in seen:
            seen.add(p)
            out.append(p)
    return out


def slug(a: str, b: str) -> str:
    return f"{a}_to_{b}"


# ---- one paired comparison --------------------------------------------------
def run_comparison(study: Study, ref_arm: str, cmp_arm: str, descs: dict[str, str],
                   corpora: dict[str, dict], out_dir: Path, root: Path, plots: bool) -> dict:
    ref, cmp_ = corpora[ref_arm], corpora[cmp_arm]
    keys = sorted(set(ref) & set(cmp_))
    labels = (ref_arm, cmp_arm)
    metrics = study.build_metrics(ref, cmp_, keys)
    results = ps.analyze(metrics)
    title = (f"Ablation {ref_arm} -> {cmp_arm}: {descs[ref_arm]} vs {descs[cmp_arm]} "
             f"(n={len(keys)} pairs)")
    report.print_summary(results, title, labels)

    header = [
        f"- Reference arm **{ref_arm}** ({descs[ref_arm]}): {len(ref)} {study.unit} in `{root / ref_arm}`",
        f"- Comparison arm **{cmp_arm}** ({descs[cmp_arm]}): {len(cmp_)} {study.unit} in `{root / cmp_arm}`",
        f"- Paired on {study.key_name}: **{len(keys)}** ({ref_arm}-only {len(set(ref) - set(cmp_))}, "
        f"{cmp_arm}-only {len(set(cmp_) - set(ref))})",
        f"- Δ is the raw difference ({cmp_arm} − {ref_arm}); the effect size is signed so that "
        f"positive means {cmp_arm} is better. All metrics come from {study.source_desc}; a metric "
        "missing for either side of a pair drops that pair from that metric only (see `n` per row).",
    ]
    written = report.write_outputs(
        out_dir, title=title, header_lines=header, results=results,
        extra_sections=study.pair_sections(ref_arm, cmp_arm, ref, cmp_, keys),
        meta={"reference": ref_arm, "comparison": cmp_arm, "root": str(root),
              "n_pairs": len(keys), "reference_total": len(ref), "comparison_total": len(cmp_)},
        plots=plots, metrics=metrics, labels=labels)
    return {"results": results, "n_pairs": len(keys), "written": written}


# ---- ladder (descriptive, every arm on one common footing) ------------------
def ladder(study: Study, corpora: dict[str, dict], arms: list[str], common: list[str],
           ctx: dict) -> dict:
    """Per-arm value of every metric on the keys present in ALL arms."""
    per_arm: dict[str, dict[str, dict]] = {}
    for a in arms:
        for m in study.ladder_metrics(corpora[a], common, ctx):
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
    public = {k: v for k, v in ctx.items() if not k.startswith("_")}
    return {"common_n": len(common), **public, "metrics": per_arm}


def _fmt(entry: dict) -> str:
    if entry["value"] is None:
        return "n/a"
    return f"{entry['value']:.1f}%" if entry["kind"] == "proportion" else f"{entry['value']:.3g}"


def ladder_table(lad: dict, arms: list[str]) -> str:
    rows = []
    for name, by_arm in lad["metrics"].items():
        first = next(iter(by_arm.values()))
        arrow = " ↓" if first["lower_is_better"] else ""
        rows.append([name + arrow, first["n"]] + [_fmt(by_arm[a]) if a in by_arm else "n/a"
                                                  for a in arms])
    return report.table_md(["Metric (↓ = lower is better)", "n"] + arms, rows)


def effect_table(all_results: dict[tuple[str, str], list[dict]], pairs: Sequence[tuple[str, str]],
                 metric_names: list[str], lower: set[str]) -> str:
    """One row per metric, one column per comparison: raw delta (later - earlier),
    marked * when Holm p < 0.05."""
    def cell(r: Optional[dict]) -> str:
        if r is None or r["skipped"]:
            return "n/a"
        d = r["delta"]
        text = f"{d:+.1f} pp" if r["kind"] == "proportion" else f"{d:+.3g}"
        return text + ("*" if r["p_holm"] < ps.ALPHA else "")

    rows = []
    for name in metric_names:
        row = [name + (" ↓" if name in lower else "")]
        for p in pairs:
            row.append(cell(next((r for r in all_results[p] if r["metric"] == name), None)))
        rows.append(row)
    return report.table_md(["Metric (↓ = lower is better)"] + [f"{a}→{b}" for a, b in pairs], rows)


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
                 if next(iter(d.values()))["kind"] == kind
                 and all(a in d and d[a]["value"] is not None for a in arms)]
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
def main(study: Study, argv: Optional[Sequence[str]] = None) -> None:
    ap = argparse.ArgumentParser(description=study.doc,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", help="directory holding the arms (default: auto-detect)")
    ap.add_argument("--out-dir", default=str(study.default_out), help="where to write results")
    ap.add_argument("--mode", choices=["both", "step", "cumulative"], default="both",
                    help="step = A(k-1)->A(k); cumulative = first arm->A(k); default both")
    ap.add_argument("--compare", action="append", metavar="REF:ARM",
                    help="explicit comparison, repeatable (overrides --mode), e.g. A2:A4")
    ap.add_argument("--no-plots", action="store_true")
    args = ap.parse_args(argv)

    t0 = time.time()
    root = study.find_root(args.root)
    descs = study.discover(root)
    corpora = {a: study.load(root, a) for a in descs}
    arms = [a for a in descs if corpora[a]]
    print(f"root: {root}")
    for a in arms:
        print(f"  {a}  {len(corpora[a]):>4} {study.unit}   {descs[a]}")
    if len(arms) < 2:
        sys.exit("Nothing to compare: need at least two arms with data.")
    pairs = parse_comparisons(args, arms)

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    all_results: dict[tuple[str, str], list[dict]] = {}
    n_pairs: dict[tuple[str, str], int] = {}
    for a, b in pairs:
        print()
        r = run_comparison(study, a, b, descs, corpora, out_dir / slug(a, b), root,
                           plots=not args.no_plots)
        all_results[(a, b)], n_pairs[(a, b)] = r["results"], r["n_pairs"]

    # -- ladder summary --------------------------------------------------------
    common = sorted(set.intersection(*(set(corpora[a]) for a in arms)))
    ctx = study.ladder_context(corpora, arms, common)
    lad = ladder(study, corpora, arms, common, ctx)
    summary_json: dict[str, Any] = {
        "generated": datetime.now().isoformat(timespec="seconds"),
        "alpha": ps.ALPHA, "root": str(root), "arms": arms,
        "comparisons": {f"{a}->{b}": {"n_pairs": n_pairs[(a, b)], "results": all_results[(a, b)]}
                        for a, b in pairs},
        "ladder": lad}

    md = [f"# {study.domain} ablation ladder", "",
          "Arms (each is the one below plus exactly one stage):", ""]
    md += [f"- **{a}** — {descs[a]} ({len(corpora[a])} {study.unit})" for a in arms]
    md.append("")
    md += ["## Every metric down the ladder", "",
           f"Descriptive. Restricted to the **{lad['common_n']}** {study.unit} present in every arm"
           f"{study.ladder_note(ctx)} Tests are in the comparison tables below.", "",
           ladder_table(lad, arms), ""]
    for heading, body in study.ladder_sections(root, corpora, arms, common):
        md += [f"## {heading}", "", body, ""]

    metric_names: list[str] = []
    lower: set[str] = set()
    for res in all_results.values():
        for r in res:
            if not r["skipped"]:
                if r["metric"] not in metric_names:
                    metric_names.append(r["metric"])
                if r["lower_is_better"]:
                    lower.add(r["metric"])
    # Keep the ladder table's row order; a metric dropped from some comparisons (e.g. a
    # duplicate) would otherwise sink to the bottom.
    metric_names = ([n for n in lad["metrics"] if n in metric_names]
                    + [n for n in metric_names if n not in lad["metrics"]])
    first, second, last = arms[0], arms[1], arms[-1]
    step = [p for p in pairs if arms.index(p[1]) - arms.index(p[0]) == 1]
    cumulative = [p for p in pairs if p[0] == first and p[1] != second]
    for heading, sel, blurb in (
            ("Step effects: what each stage adds", step,
             "Each column pairs an arm with the one directly below it on the ladder."),
            (f"Cumulative effects vs {first}", cumulative,
             study.cumulative_note.format(first=first, second=second, last=last))):
        if sel:
            md += [f"## {heading}", "",
                   f"{blurb} Each cell is the raw Δ (later − earlier): a rise is good for a "
                   "rate, a fall is good for a ↓ metric. `*` marks Holm-adjusted p < 0.05 within "
                   "that comparison's table. Effect sizes, CIs and power per comparison are in "
                   "`<from>_to_<to>/comparison.md`.", "",
                   effect_table(all_results, sel, metric_names, lower), ""]
    md += ["## Reading these numbers", "",
           "* Holm correction is applied **within** each comparison's metric table (as in the "
           f"naive-vs-full analysis), not across comparisons. With {len(pairs)} comparisons, treat "
           "an isolated `*` at p just under 0.05 as suggestive."]
    md += [f"* {n}" for n in study.notes] + [""]

    (out_dir / "ablation_summary.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    (out_dir / "ablation_summary.json").write_text(
        json.dumps(summary_json, indent=2, default=report._json_default) + "\n", encoding="utf-8")
    if not args.no_plots:
        for kind, path in ladder_plots(out_dir, lad, arms).items():
            print(f"wrote {kind}: {path}")

    print(f"\nwrote {out_dir / 'ablation_summary.md'}")
    print(f"wrote {out_dir / 'ablation_summary.json'}")
    print(f"{len(pairs)} comparisons in {time.time() - t0:.1f}s")
