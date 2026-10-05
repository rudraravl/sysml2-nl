#!/usr/bin/env python3
"""Paired comparison of the SysMLAgent corpora against naive and FORGE (measure-only).

Metrics, defined exactly as in recompute_sysml_stats.build_metrics (the tab:sysml-main table):
  valid compile   our compiler (naive / SysMLAgent: meta.json; FORGE: the de-duplicated recount
                  in dataset/analysis_results/sysml_recount/diagnostics_full.json)
  compiler errors de-duplicated (unique line/column/message)
  kernel pass, kernel errors   dataset/kernel_results_<corpus>.json (FORGE: kernel_results_pipeline)
  std-rule compliance          std_rules.check, pass / (pass + fail), empty file = all rules fail
plus SysMLAgent's own metric, ANTLR-valid (reports/antlr_valid_<corpus>.json), when available.

Pairing: ids present in every arm with every score available, minus the 10 stale FORGE seeds
(recompute_sysml_stats.STALE), as in tab:sysml-main. Each comparison is its own Holm family.

    python nl2sysml/sysml_agent/compare_arms.py
    -> dataset/analysis_results/sysml_agent/{comparison.json, comparison.md}
"""

from __future__ import annotations

import json
import statistics as st
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_NL2 = _HERE.parent
_ROOT = _NL2.parent
for _p in (str(_ROOT), str(_NL2), str(_HERE)):
    sys.path.insert(0, _p)

import std_rules  # noqa: E402
from analysis import paired_stats as ps  # noqa: E402
from recompute_sysml_stats import CHECKPOINT, STALE, dedupe_count  # noqa: E402

D = _ROOT / "dataset"
OUT = D / "analysis_results" / "sysml_agent"
ARMS = {  # key: (label, corpus dir, kernel checkpoint)
    "naive": ("Naive GLM-5.2", D / "naive_glm", D / "kernel_results_naive.json"),
    "sa0": ("SysMLAgent iter-0 (= LLM_Raw+RAG)", D / "sysml_agent_iter0", D / "kernel_results_sysml_agent_iter0.json"),
    "sa1": ("SysMLAgent iter-1 (budget-matched)", D / "sysml_agent_iter1", D / "kernel_results_sysml_agent_iter1.json"),
    "sa": ("SysMLAgent final (faithful)", D / "sysml_agent", D / "kernel_results_sysml_agent.json"),
    "forge": ("FORGE", D / "with_kernel_spec", D / "kernel_results_pipeline.json"),
}
METRICS = [  # (key, name, kind, lower_is_better)
    ("valid", "Valid compile rate", "proportion", False),
    ("errs", "Compiler errors (unique)", "continuous", True),
    ("kpass", "Kernel execution pass rate", "proportion", False),
    ("kerrs", "Kernel errors", "continuous", True),
    ("rules", "Std-rule compliance rate", "continuous", False),
    ("antlr", "ANTLR-valid (SysMLAgent's metric)", "proportion", False),
]
COMPARISONS = [  # (a, b): delta = b - a
    ("naive", "sa0"), ("naive", "sa1"), ("naive", "sa"),
    ("sa0", "forge"), ("sa1", "forge"), ("sa", "forge"),
    ("naive", "forge"),
]


def rule_rate(d: Path, s: str) -> float:
    """Verbatim from recompute_sysml_stats.build_metrics.rate."""
    p = d / s / f"{s}.sysml"
    txt = p.read_text(encoding="utf-8").strip() if p.exists() else ""
    res = std_rules.check(txt) if txt else {r: "fail" for r in std_rules.RULES}
    ok = sum(v == "pass" for v in res.values())
    app = ok + sum(v == "fail" for v in res.values())
    return ok / app if app else 0.0


def load_arm(key: str, ids: list[str], forge_diag: dict) -> dict:
    label, d, kpath = ARMS[key]
    kern = json.loads(kpath.read_text()) if kpath.exists() else {}
    ap = _HERE / "reports" / f"antlr_valid_{d.name}.json"
    antlr = json.loads(ap.read_text())["per_id"] if ap.exists() else {}
    out = {}
    for s in ids:
        if key == "forge":
            fd = forge_diag.get(s)
            valid, errs = (fd["valid"], fd["unique"]) if fd and not fd.get("timeout") else (None, None)
        else:
            mp = d / s / "meta.json"
            m = json.loads(mp.read_text()) if mp.exists() else None
            valid = bool(m["validation"]["is_valid"]) if m else None
            errs = dedupe_count(m.get("errors", [])) if m else None
        k = kern.get(s)
        k = None if (k is None or "error" in k) else k
        out[s] = {"valid": valid, "errs": errs,
                  "kpass": bool(k.get("success")) if k else None,
                  "kerrs": k.get("n_errors", 0) if k else None,
                  "rules": rule_rate(d, s) if (d / s / "meta.json").exists() else None,
                  "antlr": antlr[s]["antlr_valid"] if s in antlr else None}
    return out


def main():
    forge_diag = json.loads(CHECKPOINT.read_text())
    sa_ids = {p.parent.name for p in (D / "sysml_agent").glob("*/meta.json")}
    ids = sorted(sa_ids - set(STALE), key=lambda s: int(s[1:]))
    arms = {k: load_arm(k, ids, forge_diag) for k in ARMS}
    have_antlr = all(any(v["antlr"] is not None for v in arms[k].values()) for k in ARMS)
    metrics = [m for m in METRICS if m[0] != "antlr" or have_antlr]
    # one common id set: every arm, every metric present
    common = [s for s in ids if all(arms[k][s][m[0]] is not None for k in ARMS for m in metrics)]

    table = {k: {} for k in ARMS}
    for k in ARMS:
        for key, name, kind, _ in metrics:
            v = [arms[k][s][key] for s in common]
            table[k][key] = 100 * sum(map(bool, v)) / len(v) if kind == "proportion" else st.mean(v)

    tests = []
    for a, b in COMPARISONS:
        pm = [ps.PairedMetric(name=name, kind=kind, ids=common, lower_is_better=lib,
                              naive=[arms[a][s][key] for s in common],
                              full=[arms[b][s][key] for s in common])
              for key, name, kind, lib in metrics]
        for r in ps.analyze(pm):
            tests.append({"a": a, "b": b, **{k: r.get(k) for k in (
                "metric", "n", "naive", "full", "delta", "p", "p_holm", "effect_name", "effect",
                "effect_label", "naive_only", "full_only", "full_better", "full_worse", "tied")}})

    sa = [json.loads((D / "sysml_agent" / s / "meta.json").read_text())["sysml_agent"] for s in common]
    behaviour = {"converged_pct": 100 * st.mean(b["converged"] for b in sa),
                 "mean_fix_rounds": st.mean(b["n_fix_rounds"] for b in sa)}
    OUT.mkdir(parents=True, exist_ok=True)
    res = {"n": len(common), "n_sysml_agent_seeds": len(sa_ids), "excluded_stale": STALE,
           "table": table, "tests": tests, "sysml_agent_behaviour": behaviour,
           "metrics": [m[1] for m in metrics]}
    (OUT / "comparison.json").write_text(json.dumps(res, indent=1) + "\n")

    fmt = lambda key, kind, v: f"{v:.1f}%" if kind == "proportion" else f"{v:.3f}" if key == "rules" else f"{v:.1f}"  # noqa: E731
    L = [f"# SysMLAgent vs naive vs FORGE (n = {len(common)} paired seeds)", "",
         "| Arm | " + " | ".join(m[1] for m in metrics) + " |",
         "|---|" + "---|" * len(metrics)]
    for k in ARMS:
        L.append(f"| {ARMS[k][0]} | " + " | ".join(fmt(m[0], m[2], table[k][m[0]]) for m in metrics) + " |")
    L += ["", "## Paired tests (delta = second arm - first arm; Holm within each comparison)", "",
          "| Comparison | Metric | Δ | p (Holm) | effect |", "|---|---|---|---|---|"]
    for t in tests:
        d = f"{t['delta']:+.1f} pp" if t["metric"].endswith(("rate", "metric)")) and "compliance" not in t["metric"] \
            else f"{t['delta']:+.3f}"
        L.append(f"| {ARMS[t['a']][0].split(' (')[0]} → {ARMS[t['b']][0].split(' (')[0]} | {t['metric']} | {d} | "
                 f"{ps.fmt_p(t['p_holm'])} | {t['effect_name']} {t['effect']:+.2f} ({t['effect_label']}) |")
    (OUT / "comparison.md").write_text("\n".join(L) + "\n")
    print("\n".join(L[:len(ARMS) + 4]))
    print(f"\n-> {OUT}/comparison.{{md,json}}")


if __name__ == "__main__":
    main()
