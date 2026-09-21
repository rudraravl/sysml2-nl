"""Console / markdown / JSON / plot output for paired naive-vs-full analyses.

Consumes the result dicts produced by `paired_stats.analyze`. matplotlib is an
optional import: without it (or with `plots=False`) everything but the PNGs is
still written.
"""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any, Optional, Sequence

import numpy as np

from .paired_stats import ALPHA, PairedMetric, fmt_p

NAIVE_COLOR = "#c44e52"
FULL_COLOR = "#4c72b0"

# Display names for the two sides of a pairing: (reference, comparison). The result
# dicts keep the keys "naive"/"full" regardless (the reference is always "naive",
# the comparison "full"); only what is printed changes, so the ablation analysis can
# say "A2 vs A3" while the naive-vs-full scripts keep their wording.
Labels = tuple[str, str]
DEFAULT_LABELS: Labels = ("Naive", "Full")


def _fmt_value(r: dict, key: str) -> str:
    v = r[key]
    return f"{v:.1f}%" if r["kind"] == "proportion" else f"{v:.3g}"


def _fmt_delta(r: dict) -> str:
    d = r["delta"]
    return f"{d:+.1f} pp" if r["kind"] == "proportion" else f"{d:+.3g}"


def _fmt_ci(ci: Sequence[float], r: dict) -> str:
    if r["kind"] == "proportion":
        return f"[{ci[0]:.1f}, {ci[1]:.1f}]"
    return f"[{ci[0]:.3g}, {ci[1]:.3g}]"


def _fmt_power(p: float) -> str:
    return "> 0.9999" if p > 0.9999 else f"{p:.3f}"


def metric_rows(results: Sequence[dict]) -> list[dict]:
    return [r for r in results if not r["skipped"]]


def print_summary(results: Sequence[dict], title: str,
                  labels: Labels = DEFAULT_LABELS) -> None:
    rows = metric_rows(results)
    a_lab, b_lab = labels
    width = 132
    print("=" * width)
    print(title)
    print("=" * width)
    print(f"{'Metric':<40}{'n':>6}{a_lab:>10}{b_lab:>10}{'Delta':>11}   "
          f"{f'Effect (+ = {b_lab} better)':<30}{'p (Holm)':>10}{'Power':>9}")
    print("-" * width)
    for r in rows:
        eff = f"{r['effect_name']} {r['effect']:+.2f} ({r['effect_label']})"
        print(f"{r['metric']:<40}{r['n']:>6}{_fmt_value(r, 'naive'):>10}"
              f"{_fmt_value(r, 'full'):>10}{_fmt_delta(r):>11}   "
              f"{eff:<30}{fmt_p(r['p_holm']):>10}{_fmt_power(r['power']):>9}")
    print("-" * width)
    for r in results:
        if r["skipped"]:
            print(f"  (skipped: {r['metric']} — no paired samples with the metric available)")


def markdown_table(results: Sequence[dict], labels: Labels = DEFAULT_LABELS) -> str:
    a_lab, b_lab = labels
    lines = [
        f"| Metric | n | {a_lab} | {b_lab} | Δ ({b_lab} − {a_lab}) | 95% CI {a_lab} | 95% CI {b_lab} | Effect | Test | p (Holm) | Power |",
        "|---|---:|---:|---:|---:|---|---|---|---|---:|---:|",
    ]
    for r in metric_rows(results):
        lines.append(
            f"| {r['metric']} | {r['n']} | {_fmt_value(r, 'naive')} | {_fmt_value(r, 'full')} "
            f"| {_fmt_delta(r)} | {_fmt_ci(r['naive_ci'], r)} | {_fmt_ci(r['full_ci'], r)} "
            f"| {r['effect_name']} {r['effect']:+.2f} ({r['effect_label']}) "
            f"| {r['test']} | {fmt_p(r['p_holm'])} | {_fmt_power(r['power'])} |")
    return "\n".join(lines)


def detail_section(results: Sequence[dict], labels: Labels = DEFAULT_LABELS) -> str:
    a_lab, b_lab = labels
    out: list[str] = []
    for r in metric_rows(results):
        out.append(f"### {r['metric']}")
        if r["note"]:
            out.append(f"_{r['note']}_")
        if r["kind"] == "proportion":
            out.append(
                f"- Discordant pairs: {r['n_discordant']} of {r['n']} "
                f"({r['full_only']} {b_lab}-only wins, {r['naive_only']} {a_lab}-only wins)")
            out.append(f"- Raw p = {fmt_p(r['p'])}, Holm p = {fmt_p(r['p_holm'])}")
            out.append(f"- Observed power (McNemar) {_fmt_power(r['power'])}; "
                       f"n for 80% power at this h: {r['n_needed']} per group; "
                       f"minimum detectable h at n={r['n']}: {r['mde']:.3f}")
        else:
            out.append(
                f"- {b_lab} better on {r['full_better']}, worse on {r['full_worse']}, "
                f"tied on {r['tied']} pairs; median shift {r['median_delta']:+.3g}")
            out.append(f"- Mean Δ {r['delta']:+.3g}, 95% bootstrap CI "
                       f"[{r['delta_ci'][0]:+.3g}, {r['delta_ci'][1]:+.3g}]")
            out.append(f"- Rank-biserial r = {r['rb']:+.3f} ({r['rb_label']}); "
                       f"raw p = {fmt_p(r['p'])}, Holm p = {fmt_p(r['p_holm'])}")
            out.append(f"- Paired power {_fmt_power(r['power'])} (conservative for Wilcoxon); "
                       f"n for 80% power: {r['n_needed']} pairs; "
                       f"minimum detectable d_z at n={r['n']}: {r['mde']:.3f}")
        out.append("")
    under = [r for r in metric_rows(results) if r["power"] < 0.80]
    if under:
        out.append("**Underpowered at 80%** (report as inconclusive, not as \"no difference\"): "
                   + ", ".join(f"{r['metric']} (power {r['power']:.2f})" for r in under))
    else:
        out.append("Every metric reaches ≥ 80% power at this n, so a non-significant result "
                   "here is a genuine null rather than missing sensitivity.")
    return "\n".join(out)


def table_md(headers: Sequence[str], rows: Sequence[Sequence[Any]]) -> str:
    """Small generic markdown table for the per-domain extra sections."""
    lines = ["| " + " | ".join(headers) + " |",
             "|" + "|".join("---" for _ in headers) + "|"]
    lines += ["| " + " | ".join(str(c) for c in row) + " |" for row in rows]
    return "\n".join(lines)


def write_outputs(out_dir: Path, *, title: str, header_lines: Sequence[str],
                  results: Sequence[dict], extra_sections: Sequence[tuple[str, str]] = (),
                  meta: Optional[dict] = None, plots: bool = True,
                  metrics: Optional[Sequence[PairedMetric]] = None,
                  labels: Labels = DEFAULT_LABELS) -> dict[str, Path]:
    a_lab, b_lab = labels
    out_dir.mkdir(parents=True, exist_ok=True)
    written: dict[str, Path] = {}

    payload = {"generated": datetime.now().isoformat(timespec="seconds"),
               "alpha": ALPHA, "meta": meta or {}, "results": list(results)}
    jp = out_dir / "comparison.json"
    jp.write_text(json.dumps(payload, indent=2, default=_json_default) + "\n", encoding="utf-8")
    written["json"] = jp

    md = [f"# {title}", ""]
    md += list(header_lines) + [""]
    md += ["## Paired tests", "",
           f"α = {ALPHA}; p-values are Holm-adjusted across this table. Effect sizes are signed "
           f"so that a positive value means {b_lab} is better, including for "
           "lower-is-better metrics.", "",
           markdown_table(results, labels), ""]
    for heading, body in extra_sections:
        md += [f"## {heading}", "", body, ""]
    md += ["## Per-metric detail", "", detail_section(results, labels), ""]
    mp = out_dir / "comparison.md"
    mp.write_text("\n".join(md) + "\n", encoding="utf-8")
    written["markdown"] = mp

    if plots:
        written.update(save_plots(out_dir, results, metrics or [], labels))
    return written


def _json_default(o: Any):
    if isinstance(o, (np.integer,)):
        return int(o)
    if isinstance(o, (np.floating,)):
        return float(o)
    if isinstance(o, (np.bool_,)):
        return bool(o)
    raise TypeError(f"not JSON serializable: {type(o)}")


def save_plots(out_dir: Path, results: Sequence[dict],
               metrics: Sequence[PairedMetric],
               labels: Labels = DEFAULT_LABELS) -> dict[str, Path]:
    a_lab, b_lab = labels
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib not installed — skipping plots (pip install matplotlib)")
        return {}

    rows = metric_rows(results)
    written: dict[str, Path] = {}
    props = [r for r in rows if r["kind"] == "proportion"]
    conts = [r for r in rows if r["kind"] == "continuous"]

    if props:
        fig, ax = plt.subplots(figsize=(9, max(3.5, 0.55 * len(props) + 1.5)))
        y = np.arange(len(props))
        h = 0.38
        for off, key, color, lab in ((-h / 2, "naive", NAIVE_COLOR, a_lab),
                                     (h / 2, "full", FULL_COLOR, b_lab)):
            vals = [r[key] for r in props]
            err = np.array([[r[key] - r[f"{key}_ci"][0], r[f"{key}_ci"][1] - r[key]] for r in props]).T
            ax.barh(y + off, vals, height=h, xerr=err, color=color, capsize=2,
                    ecolor="black", label=lab)
        ax.set_yticks(y, [f"{r['metric']} (n={r['n']})" for r in props], fontsize=8)
        ax.invert_yaxis()
        ax.set_xlim(0, 105)
        ax.set_xlabel("Rate (%), 95% Wilson CI")
        ax.set_title(f"Pass rates: {a_lab} vs {b_lab}")
        ax.legend(loc="lower right")
        fig.tight_layout()
        p = out_dir / "rates.png"
        fig.savefig(p, dpi=150)
        plt.close(fig)
        written["rates"] = p

    if rows:
        fig, ax = plt.subplots(figsize=(9, max(3.5, 0.5 * len(rows) + 1.5)))
        y = np.arange(len(rows))
        eff = [r["effect"] for r in rows]
        lim = max(1.0, max(abs(e) for e in eff) * 1.35)
        for lo, hi, shade in ((0.2, 0.5, 0.06), (0.5, 0.8, 0.10), (0.8, lim, 0.15)):
            for sgn in (1, -1):
                ax.axvspan(sgn * lo, sgn * hi, color="grey", alpha=shade, lw=0)
        colors = [FULL_COLOR if e >= 0 else NAIVE_COLOR for e in eff]
        ax.barh(y, eff, color=colors, edgecolor="black", height=0.55)
        for i, r in enumerate(rows):
            star = "*" if r["p_holm"] < ALPHA else ""
            off = 0.03 * lim * (1 if r["effect"] >= 0 else -1)
            ax.text(r["effect"] + off, i, f"{r['effect']:+.2f}{star}", va="center",
                    ha="left" if r["effect"] >= 0 else "right", fontsize=8)
        ax.axvline(0, color="black", lw=1)
        ax.set_yticks(y, [r["metric"] for r in rows], fontsize=8)
        ax.set_xlim(-lim, lim)
        ax.invert_yaxis()
        ax.set_xlabel(f"Effect size (Cohen's h / d_z);  right of 0 = {b_lab} better;  * = Holm p < 0.05")
        ax.set_title("Effect sizes")
        fig.tight_layout()
        p = out_dir / "effects.png"
        fig.savefig(p, dpi=150)
        plt.close(fig)
        written["effects"] = p

    by_name = {m.name: m for m in metrics}
    cont_plot = [(r, by_name[r["metric"]]) for r in conts if r["metric"] in by_name]
    if cont_plot:
        cols = min(3, len(cont_plot))
        nrows = (len(cont_plot) + cols - 1) // cols
        fig, axes = plt.subplots(nrows, cols, figsize=(4.2 * cols, 3.6 * nrows), squeeze=False)
        for ax, (r, m) in zip(axes.flat, cont_plot):
            try:  # matplotlib >= 3.9 renamed labels -> tick_labels
                bp = ax.boxplot([m.naive, m.full], tick_labels=[a_lab, b_lab],
                                patch_artist=True, showfliers=False)
            except TypeError:
                bp = ax.boxplot([m.naive, m.full], labels=[a_lab, b_lab],
                                patch_artist=True, showfliers=False)
            for patch, color in zip(bp["boxes"], (NAIVE_COLOR, FULL_COLOR)):
                patch.set_facecolor(color)
                patch.set_alpha(0.6)
            ax.set_title(f"{r['metric']}\n(n={r['n']}, Holm p={fmt_p(r['p_holm'])})", fontsize=9)
        for ax in list(axes.flat)[len(cont_plot):]:
            ax.axis("off")
        fig.tight_layout()
        p = out_dir / "continuous.png"
        fig.savefig(p, dpi=150)
        plt.close(fig)
        written["continuous"] = p
    return written
