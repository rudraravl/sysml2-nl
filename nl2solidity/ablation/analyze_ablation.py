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

import sys
from collections import defaultdict
from pathlib import Path
from typing import Optional

_NL2 = Path(__file__).resolve().parent.parent
_ROOT = _NL2.parent
sys.path.insert(0, str(_ROOT))

from analysis import ablation  # noqa: E402
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
def find_root(arg: Optional[str]) -> Path:
    candidates = [Path(arg)] if arg else ROOT_CANDIDATES
    for c in candidates:
        if any(c.glob("A*/*/meta.json")):
            return c
    sys.exit("No ablation arms found under:\n  " + "\n  ".join(map(str, candidates)) +
             "\nPass --root <dir containing A0/ ... A5/> (e.g. the PACE dataset/ablation).")


def discover(root: Path) -> dict[str, str]:
    return {a: ARM_ADDS[a] for a in ARMS if any((root / a).glob("*/meta.json"))}


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


def pair_sections(ref_arm: str, cmp_arm: str, ref: dict, cmp_: dict, sids: list[str]):
    return [("First failing stage", failure_table({ref_arm: ref, cmp_arm: cmp_},
                                                  [ref_arm, cmp_arm], sids)),
            ("By category", by_category(ref, cmp_, sids, (ref_arm, cmp_arm)))]


# ---- ladder -----------------------------------------------------------------
def ladder_context(corpora: dict[str, dict], arms: list[str], common: list[str]) -> dict:
    """Security metrics are restricted to seeds where every arm compiles, so the
    row is comparable across arms (Slither reports 0 findings for uncompilable code)."""
    all_compile = [s for s in common if all(nvf.is_valid(corpora[a][s]) is True for a in arms)]
    return {"all_compile_n": len(all_compile), "_all_compile": all_compile}


def ladder_metrics(corpus: dict, common: list[str], ctx: dict):
    # (arm, arm) pairing: the "naive" side of each PairedMetric is this arm's value.
    return nvf.build_metrics(corpus, corpus, common, security_sids=ctx["_all_compile"])


def ladder_note(ctx: dict) -> str:
    return (f"; the Slither rows are further restricted to the **{ctx['all_compile_n']}** seeds "
            "where every arm compiles, because Slither reports 0 findings for code it cannot "
            "analyse.")


def ladder_sections(root: Path, corpora: dict[str, dict], arms: list[str], common: list[str]):
    """Quality-grade-A rate per category per arm: where in the taxonomy each stage pays."""
    groups: dict[str, list[str]] = defaultdict(list)
    for s in common:
        groups[corpora[arms[-1]][s].get("category") or "unknown"].append(s)
    rows = []
    for cat, m in sorted(groups.items(), key=lambda kv: -len(kv[1])):
        cells = []
        for a in arms:
            vals = [v for v in (nvf.grade_a(corpora[a][s]) for s in m) if v is not None]
            cells.append(f"{sum(vals) / len(vals) * 100:.0f}%" if vals else "n/a")
        rows.append([cat, len(m)] + cells)
    return [("First failing stage", failure_table(corpora, arms, common)),
            ("Quality grade A by category",
             report.table_md(["Category", "n"] + arms, rows))]


STUDY = ablation.Study(
    domain="Solidity",
    doc=__doc__,
    default_out=DEFAULT_OUT,
    unit="seeds",
    key_name="sid",
    source_desc="cached `meta.json`",
    cumulative_note=("Each column pairs an arm with {first}. {first}→{last} is the ablation-native "
                     "full-vs-naive; {first}→{second} is already in the step table."),
    notes=[
        "Every arm is *measured* by every checker (solc, Foundry, Slither, aligner) even where "
        "the stage is not used for repair, so a metric moves between arms only because of the "
        "stage that was added, not because it started being measured.",
        "Later arms repair against the very checkers that score them (A3 against solc, A4 "
        "against Foundry, A5 against Slither and the aligner). Gains on those metrics are "
        "expected by construction; the informative signal is on the metrics a stage does not "
        "repair against.",
    ],
    find_root=find_root,
    discover=discover,
    load=lambda root, arm: nvf.load_corpus(root / arm),
    build_metrics=nvf.build_metrics,
    pair_sections=pair_sections,
    ladder_context=ladder_context,
    ladder_metrics=ladder_metrics,
    ladder_note=ladder_note,
    ladder_sections=ladder_sections,
)


if __name__ == "__main__":
    ablation.main(STUDY)
