#!/usr/bin/env python3
"""Draft LaTeX + markdown table: naive, Best-of-6, FSM-SCG*, FORGE on the pre-registered Solidity
outcomes, each baseline paired against FORGE. Reads cached meta.json only (plus vrs_metrics.py's
cache for the upstream metrics). No LLM, solc or Slither calls.

Outcomes (FSM_SCG_BASELINE_SPEC.md section 9, as amended 2026-09-23):
  primary    contract-defect-free execution among executed contracts; spec-alignment accepted
  secondary  Tier B property pass; solc compile-valid; Slither actionable-clean; quality grade A;
             CPR, VRS, ZRCP, HRCP
  tests      paired vs FORGE, McNemar (rates) / Wilcoxon (VRS), Holm at alpha = 0.05 over ALL
             (baseline x metric) rows together
  cost       mean model calls, tokens and wall-clock per seed, where the corpus records them

Amendment 2026-09-23: Tier B property pass moved from primary to secondary. Over naive vs FORGE
(n=1485) its effect is +3.7 pp (26.3% -> 30.0%, Cohen's h 0.08), below the 80%-power minimum
detectable effect (h ~ 0.10). The change was made after the 20-seed FSM-SCG* pilot had been
scored, so the paper should disclose it. Tiers only order and label the rows: every test sits
in one Holm family, so no p-value depends on this split.

"Contract-defect-free execution" is reported two ways: among pairs where both contracts executed
under Foundry (the pre-registered definition), and over all pairs with a non-executing contract
counted as a failure (the tab:solidity-stats definition, analyze_naive_vs_full.defect_free).

    python nl2solidity/fsm_scg/paper_table.py
    python nl2solidity/fsm_scg/paper_table.py --corpus fsm_scg=nl2solidity/dataset/fsm_scg_pilot \\
        --vrs-dir nl2solidity/dataset/analysis_results/fsm_scg_pilot/vrs --ids U18 ...
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_NL2 = _HERE.parent
_ROOT = _NL2.parent
for _p in (str(_ROOT), str(_NL2), str(_HERE)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from analysis import paired_stats as ps  # noqa: E402
from nl2solidity import analyze_naive_vs_full as core  # noqa: E402
from vrs_metrics import DEFAULT_CORPORA, LABELS, analysed  # noqa: E402

REF = "with_kernel_spec"


def executed(m):
    e = core._exec(m)
    return None if e is None or "compiled" not in e else bool(e["compiled"])


def defects_zero(m):
    e = core._exec(m)
    return None if e is None or "contract_defects" not in e else e["contract_defects"] == 0


# (key, label, kind, getter, subset rule, tier)
ROWS = [
    ("defect_exec", "Defect-free (executed)", "proportion", defects_zero, "both_executed", "primary"),
    ("align", "Spec-alignment accepted", "proportion", core.align_accepted, None, "primary"),
    ("props", "Tier B property pass", "proportion", core.tier_passed("properties"), None, "secondary"),
    ("valid", "solc compile-valid", "proportion", core.is_valid, None, "secondary"),
    ("sec_clean", "Slither actionable-clean", "proportion", core.sec_clean, "both_compile", "secondary"),
    ("grade_a", "Quality grade A", "proportion", core.grade_a, None, "secondary"),
    ("defect_all", "Defect-free (all, tab:solidity-stats)", "proportion", core.defect_free, None,
     "secondary"),
]


def cost(meta: dict) -> dict:
    """Generation-only cost of one seed, from whatever the corpus recorded (None = not recorded)."""
    f = meta.get("fsm_scg")
    if f:
        return {"calls": f["n_calls"], "tokens": (f.get("usage") or {}).get("total_tokens"),
                "sec": meta.get("elapsed_sec")}
    b = meta.get("best_of_n")
    if b:
        return {"calls": b["n"], "tokens": None, "sec": meta.get("elapsed_sec")}
    if meta.get("pipeline") == "naive_single_model":
        return {"calls": 1, "tokens": None, "sec": meta.get("elapsed_sec")}
    return {"calls": None, "tokens": None, "sec": meta.get("elapsed_sec")}


def mean(xs):
    xs = [x for x in xs if x is not None]
    return sum(xs) / len(xs) if xs else None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--corpus", action="append", default=[], metavar="NAME=DIR",
                    help="override a default corpus path (names: " + ", ".join(DEFAULT_CORPORA) + ")")
    ap.add_argument("--vrs-dir", default=str(_NL2 / "dataset" / "analysis_results" / "vrs"),
                    help="vrs_metrics.py --out-dir (its per-corpus caches supply CPR/VRS/ZRCP/HRCP)")
    ap.add_argument("--ids", nargs="+")
    ap.add_argument("--out-dir", default=str(_NL2 / "dataset" / "analysis_results" / "fsm_scg_table"))
    args = ap.parse_args()

    paths = dict(DEFAULT_CORPORA)
    for spec in args.corpus:
        name, _, p = spec.partition("=")
        paths[name] = Path(p)
    corpora = {}
    for name, p in paths.items():
        c = core.load_corpus(Path(p)) if Path(p).exists() else {}
        if args.ids:
            c = {s: m for s, m in c.items() if s in set(args.ids)}
        if c:
            corpora[name] = c
        else:
            print(f"skip {name}: no samples at {p}")
    if REF not in corpora:
        sys.exit("FORGE corpus (with_kernel_spec) missing")
    vrs = {}
    for name in corpora:
        f = Path(args.vrs_dir) / f"vrs_{name}.json"
        vrs[name] = json.loads(f.read_text())["samples"] if f.exists() else {}

    ref = corpora[REF]
    shared = sorted(set.intersection(*(set(c) for c in corpora.values())))
    print(f"seeds present in every corpus: {len(shared)}")

    # Per-corpus rates over the shared seeds, and every baseline-vs-FORGE paired test.
    table, tests = {}, []
    for name, c in corpora.items():
        col = {}
        for key, _, _, get, _, _ in ROWS:
            vals = [get(c[s]) for s in shared]
            col[key] = mean([float(v) for v in vals if v is not None])
            col[key + "_n"] = sum(v is not None for v in vals)
        vs = vrs[name]
        have = [s for s in shared if s in vs]
        ok = [vs[s] for s in have if analysed(vs[s])]
        col["CPR"] = mean([float(vs[s]["compiled"]) for s in have])
        col["VRS"] = mean([vs[s]["risk"] for s in have])
        col["ZRCP"] = mean([float(r["risk"] == 0) for r in ok])
        col["HRCP"] = mean([float(r["by_impact"]["High"] > 0) for r in ok])
        costs = [cost(c[s]) for s in shared]
        for k in ("calls", "tokens", "sec"):
            col[k] = mean([x[k] for x in costs])
        table[name] = col
        if name == REF:
            continue
        for key, label, kind, get, rule, tier in ROWS:
            sids = shared
            if rule == "both_executed":
                sids = [s for s in shared if executed(c[s]) and executed(ref[s])]
            elif rule == "both_compile":
                sids = [s for s in shared if core.is_valid(c[s]) and core.is_valid(ref[s])]
            tests.append(((name, key, tier), ps.PairedMetric.from_pairs(
                label, kind, [(s, get(c[s]), get(ref[s])) for s in sids])))
        rv = vrs[REF]
        both = [s for s in shared if s in vs and s in rv]
        both_ok = [s for s in both if analysed(vs[s]) and analysed(rv[s])]
        for key, label, kind, pairs, lib in (
            ("CPR", "CPR", "proportion", [(s, vs[s]["compiled"], rv[s]["compiled"]) for s in both], False),
            ("VRS", "VRS", "continuous", [(s, vs[s]["risk"], rv[s]["risk"]) for s in both], True),
            ("ZRCP", "ZRCP", "proportion",
             [(s, vs[s]["risk"] == 0, rv[s]["risk"] == 0) for s in both_ok], False),
            ("HRCP", "no High (HRCP)", "proportion",
             [(s, vs[s]["by_impact"]["High"] == 0, rv[s]["by_impact"]["High"] == 0) for s in both_ok],
             False),
        ):
            tests.append(((name, key, "secondary"),
                          ps.PairedMetric.from_pairs(label, kind, pairs, lower_is_better=lib)))

    # Holm over every (baseline x metric) row at once, as tab:solidity-stats does.
    results = ps.analyze([m for _, m in tests])
    stats = {tag: r for (tag, _), r in zip(tests, results)}

    def cell(name, key, pct=True, digits=1):
        v = table[name].get(key)
        if v is None:
            return "--"
        s = f"{v * 100:.{digits}f}" if pct else f"{v:.{digits}f}"
        r = stats.get((name, key, "primary")) or stats.get((name, key, "secondary"))
        if r and not r["skipped"] and r["p_holm"] < ps.ALPHA:
            s += "$^{*}$"
        return s

    cols = [(k, lab, True, 1) for k, lab, *_ in ROWS] + [
        ("CPR", "CPR", True, 1), ("VRS", "VRS", False, 2), ("ZRCP", "ZRCP", True, 1),
        ("HRCP", "HRCP", True, 1),
        ("calls", "Calls", False, 1), ("tokens", "Tokens", False, 0), ("sec", "Sec", False, 0)]
    order = [n for n in ("naive_glm", "BoN6", "fsm_scg", REF) if n in corpora]
    row_names = {"naive_glm": "Naive (GLM-5.2)", "BoN6": "Best-of-6", "fsm_scg": "FSM-SCG$^\\dagger$ (GLM-5.2)",
                 REF: "FORGE"}
    tex = ["% Draft generated by nl2solidity/fsm_scg/paper_table.py; values are % unless noted.",
           "\\begin{table}[t]", "\\centering",
           f"\\caption{{Solidity baselines vs.\\ FORGE on $n={len(shared)}$ shared requirements. "
           "Primary: defect-free execution (among pairs where both contracts execute) and "
           "spec-alignment accepted; the rest are secondary. $^{*}$: differs from FORGE, paired McNemar/Wilcoxon, "
           "Holm-corrected at $\\alpha=0.05$ over every baseline$\\times$metric test. "
           "VRS: FSM-SCG risk score (lower is better). Cost is generation only, per seed; -- = not recorded. "
           "$^\\dagger$FSM-SCG$^*$, the prompting variant.}",
           "\\label{tab:solidity-baselines}", "\\scriptsize", "\\setlength{\\tabcolsep}{3pt}",
           "\\begin{tabular}{@{}l" + "r" * len(cols) + "@{}}", "\\toprule",
           "Arm & " + " & ".join(lab for _, lab, _, _ in cols) + " \\\\", "\\midrule"]
    md = ["| Arm | " + " | ".join(lab for _, lab, _, _ in cols) + " |",
          "|---|" + "---|" * len(cols)]
    for n in order:
        cells = [cell(n, k, p, d) for k, _, p, d in cols]
        tex.append(f"{row_names[n]} & " + " & ".join(cells) + " \\\\")
        md.append(f"| {LABELS.get(n, n)} | " + " | ".join(c.replace("$^{*}$", "*") for c in cells) + " |")
    tex += ["\\bottomrule", "\\end{tabular}", "\\end{table}"]

    detail = ["| Baseline | Metric | tier | n | baseline | FORGE | Δ | p (Holm) |", "|---|---|---|---|---|---|---|---|"]
    for (name, key, tier), r in stats.items():
        if r["skipped"]:
            detail.append(f"| {LABELS.get(name, name)} | {r['metric']} | {tier} | 0 | | | | skipped |")
            continue
        u = "%" if r["kind"] == "proportion" else ""
        detail.append(f"| {LABELS.get(name, name)} | {r['metric']} | {tier} | {r['n']} | "
                      f"{r['naive']:.2f}{u} | {r['full']:.2f}{u} | {r['delta']:+.2f} | "
                      f"{ps.fmt_p(r['p_holm'])} |")

    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    (out / "table.tex").write_text("\n".join(tex) + "\n", encoding="utf-8")
    (out / "table.md").write_text("\n".join(md + ["", "## Paired tests vs FORGE (Holm over all rows)", ""]
                                            + detail) + "\n", encoding="utf-8")
    print("\n".join(md), "\n", "\n".join(detail), sep="\n")
    print(f"\nwrote {out / 'table.tex'} and {out / 'table.md'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
