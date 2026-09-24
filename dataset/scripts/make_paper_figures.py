#!/usr/bin/env python3
"""Regenerate the three SysML v2 dataset figures used in the ICML paper.

Replaces the hand-exported PNGs in presentation/icml/fig/, which had no generator
in the repo: dataset/scripts/statistics.ipynb plots two of the three but only
calls plt.show(), and nothing produced the curated-vs-agent figure at all.

Reads only dataset/data/*/meta.json and *.sysml. Writes PNG (for preview) and
PDF (vector, for LaTeX) side by side.

    python dataset/scripts/make_paper_figures.py
    python dataset/scripts/make_paper_figures.py --data-dir <dir> --out-dir <dir>

Figures:
  sysml_v2_agent_vs_curated_v2  curated (official+community+pilot+esa) vs agent
  sysml_v2_category_distribution  category counts, labeled by Gemini 2.5 Pro
  sysml_v2_loc_distribution       model size in LOC, log x-axis, mean + median
"""
from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

REPO = Path(__file__).resolve().parents[2]

# Validated against scripts/validate_palette.js (light surface #fcfcfb):
# CVD dE 24.7 protan, normal-vision dE 33.6, contrast >= 3:1 -- all checks pass.
BLUE, ORANGE = "#2a78d6", "#eb6834"
INK, INK_MUTED, GRID = "#0b0b0b", "#52514e", "#d8d7d2"

CURATED_SPLITS = ("official", "community", "pilot", "esa")


def load(data_dir: Path):
    """Return (locs, categories, splits) over every numeric sample dir."""
    locs, cats, splits = [], Counter(), Counter()
    for p in sorted(data_dir.iterdir()):
        if not (p.is_dir() and p.name.isdigit()):
            continue
        meta = p / "meta.json"
        if not meta.exists():
            continue
        m = json.loads(meta.read_text())
        cats[m.get("category", "unknown")] += 1
        splits[m.get("split", "unknown")] += 1
        src = p / f"{p.name}.sysml"
        if src.exists():
            locs.append(len(src.read_text(errors="replace").splitlines()))
    return locs, cats, splits


def _style(ax):
    """Recessive axes: no box, muted ink, grid behind the marks."""
    for side in ("top", "right", "left"):
        ax.spines[side].set_visible(False)
    ax.spines["bottom"].set_color(GRID)
    ax.tick_params(colors=INK_MUTED, length=0)
    ax.set_axisbelow(True)


def _save(fig, out_dir: Path, stem: str):
    out_dir.mkdir(parents=True, exist_ok=True)
    for ext in ("png", "pdf"):
        fig.savefig(out_dir / f"{stem}.{ext}", dpi=200, bbox_inches="tight",
                    facecolor="white")
    plt.close(fig)
    print(f"  wrote {stem}.png / .pdf")


def fig_agent_vs_curated(splits: Counter, out_dir: Path, n: int):
    curated = sum(splits.get(s, 0) for s in CURATED_SPLITS)
    agent = n - curated
    # Two hues: the split IS the identity here, so color carries meaning.
    labels = ["Agent-generated", "Curated\n(official + community\n+ pilot + ESA)"]
    values, colors = [agent, curated], [ORANGE, BLUE]

    fig, ax = plt.subplots(figsize=(7.2, 2.9))
    bars = ax.barh(labels, values, color=colors, height=0.55)
    for bar, v in zip(bars, values):
        ax.text(v + n * 0.012, bar.get_y() + bar.get_height() / 2,
                f"{v:,}  ({v / n:.1%})", va="center", color=INK, fontsize=10)
    ax.set_xlim(0, n * 1.16)
    ax.set_xlabel("Number of samples", color=INK_MUTED, fontsize=10)
    ax.set_title(f"Source composition of the SysML v2 dataset (N={n:,})",
                 color=INK, fontsize=12, pad=12, loc="left")
    ax.xaxis.grid(True, color=GRID, lw=0.8)
    _style(ax)
    ax.invert_yaxis()
    _save(fig, out_dir, "sysml_v2_agent_vs_curated_v2")
    return curated, agent


def fig_category(cats: Counter, out_dir: Path, n: int):
    items = cats.most_common()
    names = [k.capitalize() for k, _ in items]
    values = [v for _, v in items]

    # One measure across categories -> ONE hue, not a categorical rainbow.
    fig, ax = plt.subplots(figsize=(7.2, 4.2))
    bars = ax.barh(names, values, color=BLUE, height=0.62)
    for bar, v in zip(bars, values):
        ax.text(v + max(values) * 0.015, bar.get_y() + bar.get_height() / 2,
                f"{v:,}  ({v / n:.1%})", va="center", color=INK, fontsize=9.5)
    ax.set_xlim(0, max(values) * 1.20)
    ax.set_xlabel("Number of samples", color=INK_MUTED, fontsize=10)
    ax.set_title(f"Category distribution of the SysML v2 dataset (N={n:,})\n"
                 "categories labeled by Gemini 2.5 Pro",
                 color=INK, fontsize=12, pad=12, loc="left")
    ax.xaxis.grid(True, color=GRID, lw=0.8)
    _style(ax)
    ax.invert_yaxis()
    _save(fig, out_dir, "sysml_v2_category_distribution")


def fig_loc(locs: list[int], out_dir: Path, n: int):
    arr = np.array(locs)
    mean, median = arr.mean(), np.median(arr)
    bins = np.logspace(np.log10(max(arr.min(), 1)), np.log10(arr.max()), 50)

    fig, ax = plt.subplots(figsize=(7.2, 4.0))
    ax.hist(arr, bins=bins, color=BLUE, edgecolor="white", linewidth=0.4)
    ax.set_xscale("log")
    # Dashed = mean, dotted = median, matching the paper caption.
    ax.axvline(mean, color=ORANGE, ls="--", lw=1.6,
               label=f"Mean  {mean:.0f} LOC")
    ax.axvline(median, color=INK, ls=":", lw=1.6,
               label=f"Median  {median:.0f} LOC")
    ax.set_xlabel("Lines of code (log scale)", color=INK_MUTED, fontsize=10)
    ax.set_ylabel("Number of models", color=INK_MUTED, fontsize=10)
    ax.set_title(f"SysML v2 model size distribution (N={n:,})",
                 color=INK, fontsize=12, pad=12, loc="left")
    leg = ax.legend(frameon=False, loc="upper left", fontsize=10)
    for t in leg.get_texts():
        t.set_color(INK)
    ax.yaxis.grid(True, color=GRID, lw=0.8)
    _style(ax)
    _save(fig, out_dir, "sysml_v2_loc_distribution")
    return mean, median


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--data-dir", type=Path, default=REPO / "dataset" / "data")
    ap.add_argument("--out-dir", type=Path,
                    default=REPO / "presentation" / "icml" / "fig")
    args = ap.parse_args()

    locs, cats, splits = load(args.data_dir)
    n = sum(cats.values())
    if not n:
        raise SystemExit(f"no samples found under {args.data_dir}")
    print(f"{n:,} samples from {args.data_dir}")

    curated, agent = fig_agent_vs_curated(splits, args.out_dir, n)
    fig_category(cats, args.out_dir, n)
    mean, median = fig_loc(locs, args.out_dir, n)

    print(f"\nNumbers the paper captions assert:")
    print(f"  N          {n:,}")
    print(f"  curated    {curated:,}  ({'+'.join(CURATED_SPLITS)})")
    print(f"  agent      {agent:,}")
    print(f"  LOC mean   {mean:.0f}    median {median:.0f}")


if __name__ == "__main__":
    main()
