#!/usr/bin/env python3
"""Follow-up checks behind the FSM-SCG* vs FORGE write-up (exploratory, not pre-registered).

Recomputes every number RESULTS.md quotes that is not in the paired analysis, the VRS table or the
paper table. Reads cached meta.json, transcript.json, the .sol files and vrs_metrics.py's cache
only: no LLM, solc or Slither calls.

  1. FSM-SCG* generation statistics (calls, repairs, cost, import-only compile failures, the
     security turn breaking compiling contracts, Slither errors)
  2. Execution outcomes per arm (tier statuses, defects, failure classes, missing property tests)
  3. How spec-alignment acceptance depends on the property tier
  4. Contract size, guards and size-normalised Slither findings
  5. Paired FSM-SCG* vs FORGE tests on comparable subsets, Holm-adjusted within this family

    python nl2solidity/fsm_scg/followup_checks.py
"""

from __future__ import annotations

import json
import re
import statistics as st
import sys
from collections import Counter
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_NL2 = _HERE.parent
_ROOT = _NL2.parent
for _p in (str(_ROOT), str(_NL2), str(_HERE)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from analysis import paired_stats as ps  # noqa: E402
from nl2solidity import analyze_naive_vs_full as core  # noqa: E402
from run_fsm_scg import load_seeds  # noqa: E402
from size_relevance import loc  # noqa: E402

DS = _NL2 / "dataset"
ARMS = {"naive": "naive_glm", "fsm": "fsm_scg", "forge": "with_kernel_spec"}
LABEL = {"naive": "Naive", "fsm": "FSM-SCG*", "forge": "FORGE"}


def ex(m):
    return m.get("execution") or {}


def executed(m):
    return bool(ex(m).get("compiled"))


def crashes(m):
    fc = ex(m).get("failure_classes") or {}
    return sum(v for k, v in fc.items() if k.startswith("panic") or k == "assertion_failed")


def main() -> int:
    ids = [s for s, _, _ in load_seeds()[:500]]
    M = {a: {s: json.loads((DS / d / s / "meta.json").read_text(encoding="utf-8")) for s in ids}
         for a, d in ARMS.items()}
    code = {a: {s: (DS / d / s / f"{s}.sol").read_text(encoding="utf-8") for s in ids}
            for a, d in ARMS.items()}
    vrs = {a: json.loads((DS / "analysis_results" / "vrs" / f"vrs_{d}.json").read_text())["samples"]
           for a, d in ARMS.items()}
    L = ["# FSM-SCG* follow-up checks (500 ablation seeds, exploratory)", ""]
    nums: dict = {}

    # ---- 1. generation statistics
    f = {s: M["fsm"][s]["fsm_scg"] for s in ids}
    imp = 0
    for s in ids:
        c = json.loads((DS / "fsm_scg" / s / "transcript.json").read_text())["code_candidates"][0]["compile"]
        imp += (not c["is_valid"]) and all("not found" in e for e in c["errors"])
    broke = [s for s in ids if f[s]["compiled_before_security"] and f[s]["security_feedback"] == "sent"
             and not M["fsm"][s]["validation"]["is_valid"]]
    sl_err = {s: f[s]["compiled_before_security"] for s in ids if f[s]["security_feedback"] == "slither_error"}
    gen = {
        "n": len(ids),
        "calls": dict(sorted(Counter(f[s]["n_calls"] for s in ids).items())),
        "mean_calls": st.mean(f[s]["n_calls"] for s in ids),
        "mean_tokens": st.mean(f[s]["usage"].get("total_tokens", 0) for s in ids),
        "mean_cost_usd": st.mean(f[s]["usage"].get("cost", 0) for s in ids),
        "total_cost_usd": sum(f[s]["usage"].get("cost", 0) for s in ids),
        "elapsed_sec_mean": st.mean(M["fsm"][s]["elapsed_sec"] for s in ids),
        "elapsed_sec_median": st.median(M["fsm"][s]["elapsed_sec"] for s in ids),
        "fsm_repairs": dict(sorted(Counter(f[s]["fsm_repairs"] for s in ids).items())),
        "fsm_accepted": sum(f[s]["fsm_accepted"] for s in ids),
        "compile_repairs": sum(f[s]["compile_repairs"] for s in ids),
        "compile_repairs_import_only": imp,
        "compiled_before_security": sum(f[s]["compiled_before_security"] for s in ids),
        "final_valid": sum(M["fsm"][s]["validation"]["is_valid"] for s in ids),
        "security_turn_broke_compiling": len(broke),
        "security_feedback": dict(Counter(f[s]["security_feedback"] for s in ids)),
        "slither_error_seeds": sl_err,
    }
    nums["generation"] = gen
    L += ["## 1. FSM-SCG* generation", "",
          f"- Calls per seed: {gen['calls']} (mean {gen['mean_calls']:.2f})",
          f"- Mean {gen['mean_tokens']:,.0f} tokens, ${gen['mean_cost_usd']:.4f} and {gen['elapsed_sec_mean']:.0f} s "
          f"(median {gen['elapsed_sec_median']:.0f} s) per seed; ${gen['total_cost_usd']:.2f} in total",
          f"- FSM repairs: {gen['fsm_repairs']}; final FSM accepted in {gen['fsm_accepted']}/500",
          f"- Compile repairs: {gen['compile_repairs']}, of which {imp} fixed import-only failures",
          f"- Compiled before the security turn: {gen['compiled_before_security']}; compile at the end: "
          f"{gen['final_valid']}; the security turn broke {len(broke)} compiling contracts",
          f"- Security feedback: {gen['security_feedback']}",
          f"- Slither errors (seed: compiled before security): {sl_err}", ""]

    # ---- 2. execution outcomes
    L += ["## 2. Execution outcomes per arm (contracts that built under Foundry)", "",
          "| Arm | executed | fuzz passed / failed / skipped | property passed / failed / no tests / build failed "
          "| any contract defect | any harness defect | crash or assert failure |",
          "|---|---|---|---|---|---|---|"]
    nums["execution"] = {}
    for a in ARMS:
        run = [s for s in ids if executed(M[a][s])]
        fz = Counter(ex(M[a][s])["tier_status"].get("fuzz") for s in run)
        pt = Counter(ex(M[a][s])["tier_status"].get("properties") for s in run)
        row = {
            "executed": len(run), "fuzz": dict(fz), "properties": dict(pt),
            "contract_defect": sum(ex(M[a][s]).get("contract_defects", 0) > 0 for s in run),
            "harness_defect": sum(ex(M[a][s]).get("harness_defects", 0) > 0 for s in run),
            "crash": sum(crashes(M[a][s]) > 0 for s in run),
            "no_property_tests": sum(not ex(M[a][s]).get("property_tests") for s in run),
            "failure_classes": dict(sum((Counter(ex(M[a][s]).get("failure_classes") or {}) for s in run),
                                        Counter()).most_common(8)),
        }
        nums["execution"][a] = row
        L.append(f"| {LABEL[a]} | {len(run)} | {fz['passed']} / {fz['failed']} / {fz['skipped']} | "
                 f"{pt['passed']} / {pt['failed']} / {pt['skipped']} / {pt['build_failed']} | "
                 f"{row['contract_defect']} | {row['harness_defect']} | {row['crash']} |")
    fg = [s for s in ids if executed(M["forge"][s])]
    w = [s for s in fg if ex(M["forge"][s]).get("property_tests")]
    wo = [s for s in fg if not ex(M["forge"][s]).get("property_tests")]
    rate = lambda ss: 100 * sum(ex(M["forge"][s])["contract_defects"] == 0 for s in ss) / len(ss)  # noqa: E731
    nums["forge_defect_free_by_tests"] = {"with": [len(w), rate(w)], "without": [len(wo), rate(wo)]}
    L += ["", f"FORGE defect-free with property tests: {rate(w):.1f}% (n = {len(w)}); without any: "
          f"{rate(wo):.1f}% (n = {len(wo)}). A property tier marked \"no tests\" means the generator "
          "wrote zero property tests.", "",
          "Failure classes (top 8):", ""]
    for a in ARMS:
        L.append(f"- {LABEL[a]}: {nums['execution'][a]['failure_classes']}")

    # ---- 3. acceptance vs property tier
    L += ["", "## 3. Spec-alignment acceptance by property-tier status", "",
          "| Arm | passed | no tests | failed | build failed |", "|---|---|---|---|---|"]
    nums["acceptance_by_property_tier"] = {}
    for a in ARMS:
        t = {}
        for s in ids:
            acc = (M[a][s].get("spec_alignment") or {}).get("accepted")
            if acc is None:
                continue
            k = ex(M[a][s]).get("tier_status", {}).get("properties", "not executed")
            n_acc, n_all = t.get(k, (0, 0))
            t[k] = (n_acc + bool(acc), n_all + 1)
        nums["acceptance_by_property_tier"][a] = t
        cell = lambda k: "{}/{}".format(*t.get(k, (0, 0)))  # noqa: E731
        L.append(f"| {LABEL[a]} | {cell('passed')} | {cell('skipped')} | {cell('failed')} | {cell('build_failed')} |")

    # ---- 4. size, guards, normalised findings
    L += ["", "## 4. Size, guards and Slither findings per 100 lines", "",
          "| Arm | median lines | mean lines | functions | events | require/revert | findings / 100 lines "
          "| High+Medium / 100 lines |", "|---|---|---|---|---|---|---|---|"]
    lines = {a: {s: loc(code[a][s]) for s in ids} for a in ARMS}
    nums["size"] = {}
    for a in ARMS:
        c = code[a]
        ok = [s for s in ids if vrs[a][s]["compiled"] and vrs[a][s]["slither_error"] is None]
        tot = sum(lines[a][s] for s in ok)
        row = {
            "median_lines": st.median(lines[a].values()), "mean_lines": st.mean(lines[a].values()),
            "functions": st.mean(len(re.findall(r"\bfunction\s+\w+", c[s])) for s in ids),
            "events": st.mean(len(re.findall(r"\bevent\s+\w+", c[s])) for s in ids),
            "guards": st.mean(len(re.findall(r"\brequire\s*\(|\brevert\b", c[s])) for s in ids),
            "findings_per_100": 100 * sum(vrs[a][s]["n_findings"] for s in ok) / tot,
            "high_med_per_100": 100 * sum(vrs[a][s]["by_impact"]["High"] + vrs[a][s]["by_impact"]["Medium"]
                                          for s in ok) / tot,
        }
        nums["size"][a] = row
        L.append(f"| {LABEL[a]} | {row['median_lines']:.0f} | {row['mean_lines']:.0f} | {row['functions']:.1f} | "
                 f"{row['events']:.1f} | {row['guards']:.1f} | {row['findings_per_100']:.2f} | "
                 f"{row['high_med_per_100']:.2f} |")

    # ---- 5. paired tests on comparable subsets
    F, G = M["fsm"], M["forge"]
    ran = lambda m: ex(m).get("tier_status", {}).get("properties") in ("passed", "failed")  # noqa: E731
    has_tests = lambda m: executed(m) and bool(ex(m).get("property_tests"))  # noqa: E731
    both = lambda pred: [s for s in ids if pred(F[s]) and pred(G[s])]  # noqa: E731
    analysed = lambda a, s: vrs[a][s]["compiled"] and vrs[a][s]["slither_error"] is None  # noqa: E731
    per100 = lambda a, s: 100 * vrs[a][s]["n_findings"] / max(1, lines[a][s])  # noqa: E731
    P, C = "proportion", "continuous"
    tests = [
        ps.PairedMetric.from_pairs("Property tier passed | property tests ran on both", P,
                                   [(s, ex(F[s])["tier_status"]["properties"] == "passed",
                                     ex(G[s])["tier_status"]["properties"] == "passed") for s in both(ran)]),
        ps.PairedMetric.from_pairs("Defect-free | both executed", P,
                                   [(s, ex(F[s])["contract_defects"] == 0, ex(G[s])["contract_defects"] == 0)
                                    for s in both(executed)]),
        ps.PairedMetric.from_pairs("Defect-free | both executed with property tests", P,
                                   [(s, ex(F[s])["contract_defects"] == 0, ex(G[s])["contract_defects"] == 0)
                                    for s in both(has_tests)]),
        ps.PairedMetric.from_pairs("No crash/assert failure | both executed", P,
                                   [(s, crashes(F[s]) == 0, crashes(G[s]) == 0) for s in both(executed)]),
        ps.PairedMetric.from_pairs("Alignment accepted | both executed with property tests", P,
                                   [(s, (F[s].get("spec_alignment") or {}).get("accepted"),
                                     (G[s].get("spec_alignment") or {}).get("accepted")) for s in both(has_tests)]),
        ps.PairedMetric.from_pairs("Slither findings per 100 lines | both analysed", C,
                                   [(s, per100("fsm", s), per100("forge", s)) for s in ids
                                    if analysed("fsm", s) and analysed("forge", s)], lower_is_better=True),
    ]
    res = ps.analyze(tests)
    nums["paired"] = res
    L += ["", "## 5. Paired FSM-SCG* vs FORGE on comparable subsets (Holm within this table)", "",
          "| Test | n | FSM-SCG* | FORGE | p | p (Holm) |", "|---|---|---|---|---|---|"]
    for r in res:
        fmt = (lambda v: f"{v:.1f}%") if r["kind"] == P else (lambda v: f"{v:.2f}")
        L.append(f"| {r['metric']} | {r['n']} | {fmt(r['naive'])} | {fmt(r['full'])} | "
                 f"{ps.fmt_p(r['p'])} | {ps.fmt_p(r['p_holm'])} |")

    out = DS / "analysis_results" / "fsm_scg_followups"
    out.mkdir(parents=True, exist_ok=True)
    (out / "followups.md").write_text("\n".join(L) + "\n", encoding="utf-8")
    (out / "followups.json").write_text(json.dumps(nums, indent=2, default=str) + "\n", encoding="utf-8")
    print("\n".join(L))
    print(f"\nwrote {out / 'followups.md'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
