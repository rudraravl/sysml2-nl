#!/usr/bin/env python3
"""Does FSM-SCG* win only because it writes smaller contracts, and is FORGE's extra code relevant?

Exploratory follow-up to the FSM-SCG* vs FORGE comparison (not pre-registered). FSM-SCG*'s contracts
are about half FORGE's size, and smaller code is easier to fuzz and has fewer Slither findings. This
reads cached meta.json, the .sol files and vrs_metrics.py's cache (no LLM, solc or Slither calls) and
asks three questions:

  1. Size-matched pairs: on requirements where both arms wrote contracts of similar length
     (shorter/longer >= --match-ratio), who wins?
  2. Size-adjusted difference: over all pairs, regress the per-requirement difference
     (FSM-SCG* - FORGE) on the log length ratio. The intercept is the difference at equal size.
  3. Requirement difficulty: split requirements into tertiles by how long the naive arm's contract
     is (a proxy neither compared arm influences) and compare within each.

Relevance of the code: the share of a requirement's specific terms (words in it, minus stopwords and
words in more than 30% of requirements) that appear among the contract's identifiers (comments and
string literals removed, camelCase split, light stemming); and the share of non-view functions whose
name contains such a term.

    python nl2solidity/fsm_scg/size_relevance.py
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path

import numpy as np

_HERE = Path(__file__).resolve().parent
_NL2 = _HERE.parent
_ROOT = _NL2.parent
for _p in (str(_ROOT), str(_NL2), str(_HERE)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from analysis import paired_stats as ps  # noqa: E402
from nl2solidity import analyze_naive_vs_full as core  # noqa: E402
from run_fsm_scg import load_seeds  # noqa: E402

DS = _NL2 / "dataset"
ARMS = {"naive": "naive_glm", "fsm": "fsm_scg", "forge": "with_kernel_spec"}
STOP = set("""this that with from their they them than then have been being will would which what when
where while each such also into onto only other some more most must shall should could about above
after before between both during every either within without across along upon over under again
further once here there these those very same able need needs contract contracts callers caller can
record records maintains maintain allows allow allowing user users designated""".split())


# --------------------------------------------------------------------------- text features
def stem(w: str) -> str:
    for suf in ("ings", "ing", "ies", "ed", "es", "s"):
        if w.endswith(suf) and len(w) - len(suf) >= 4:
            return w[: -len(suf)] + ("y" if suf == "ies" else "")
    return w


def words(text: str) -> list[str]:
    return [stem(w) for w in re.findall(r"[a-z]+", text.lower()) if len(w) >= 4 and w not in STOP]


def code_terms(code: str) -> set[str]:
    code = re.sub(r"/\*.*?\*/", " ", code, flags=re.S)
    code = re.sub(r"//[^\n]*", " ", code)
    code = re.sub(r'"(?:\\.|[^"\\])*"', " ", code)
    ids = re.findall(r"[A-Za-z_][A-Za-z0-9_]*", code)
    parts = []
    for ident in ids:
        parts += re.findall(r"[A-Z]+(?![a-z])|[A-Z]?[a-z]+", ident)
    return {stem(p.lower()) for p in parts if len(p) >= 4}


def loc(code: str) -> int:
    code = re.sub(r"/\*.*?\*/", " ", code, flags=re.S)
    return sum(1 for ln in code.splitlines() if ln.strip() and not ln.strip().startswith("//"))


def functions(code: str) -> list[tuple[str, bool]]:
    return [(n, bool(re.search(r"\b(view|pure)\b", rest)))
            for n, rest in re.findall(r"function\s+(\w+)\s*\([^)]*\)([^{;]*)", code)]


# --------------------------------------------------------------------------- stats helpers
def ols_hc1(y: np.ndarray, x: np.ndarray):
    """y = a + b*x with HC1 robust SEs. Returns (a, se_a, p_a, b, se_b, p_b)."""
    X = np.column_stack([np.ones_like(x), x])
    xtx_inv = np.linalg.inv(X.T @ X)
    beta = xtx_inv @ X.T @ y
    e = y - X @ beta
    n, k = X.shape
    V = xtx_inv @ (X.T * e**2) @ X @ xtx_inv * n / (n - k)
    se = np.sqrt(np.diag(V))
    p = [ps.p_from_z(abs(beta[i] / se[i])) if se[i] > 0 else 1.0 for i in range(2)]
    return beta[0], se[0], p[0], beta[1], se[1], p[1]


def fmt_p(p):
    return ps.fmt_p(p)


# --------------------------------------------------------------------------- main
def main() -> int:
    seeds = load_seeds()[:500]
    ids = [s for s, _, _ in seeds]
    req = {s: q for s, q, _ in seeds}
    df = Counter()
    for s in ids:
        df.update(set(words(req[s])))
    common = {w for w, c in df.items() if c > 0.3 * len(ids)}
    rterms = {s: set(words(req[s])) - common for s in ids}

    vrs = {a: json.loads((DS / "analysis_results" / "vrs" / f"vrs_{d}.json").read_text())["samples"]
           for a, d in ARMS.items()}
    M, F = {}, {}
    for a, d in ARMS.items():
        M[a], F[a] = {}, {}
        for s in ids:
            m = json.loads((DS / d / s / "meta.json").read_text(encoding="utf-8"))
            code = (DS / d / s / f"{s}.sol").read_text(encoding="utf-8")
            terms = code_terms(code)
            fns = functions(code)
            act = [n for n, view in fns if not view]
            rt = rterms[s]
            M[a][s] = m
            F[a][s] = {
                "loc": loc(code),
                "n_fn": len(fns),
                "recall": len(rt & terms) / len(rt) if rt else None,
                "fn_rel": (sum(bool(code_terms(n) & rt) for n in act) / len(act)) if act else None,
            }

    ex = core._exec

    def executed(m):
        e = ex(m)
        return None if e is None or "compiled" not in e else bool(e["compiled"])

    out = {
        "similarity": lambda a, s: core.similarity(M[a][s]),
        "defect_free_exec": lambda a, s: (ex(M[a][s])["contract_defects"] == 0) if executed(M[a][s]) else None,
        "fuzz_pass_exec": lambda a, s: (ex(M[a][s])["tier_status"].get("fuzz") == "passed") if executed(M[a][s]) else None,
        "slither_findings": lambda a, s: vrs[a][s]["n_findings"] if vrs[a][s]["compiled"] and vrs[a][s]["slither_error"] is None else None,
        "slither_actionable_clean": lambda a, s: core.sec_clean(M[a][s]) if core.is_valid(M[a][s]) else None,
        "req_term_recall": lambda a, s: F[a][s]["recall"],
    }
    kinds = {"similarity": "continuous", "slither_findings": "continuous", "req_term_recall": "continuous"}
    lower = {"slither_findings"}

    def pairs(metric, subset):
        g = out[metric]
        return [(s, g("fsm", s), g("forge", s)) for s in subset
                if g("fsm", s) is not None and g("forge", s) is not None]

    lines = ["# Contract size and relevance: FSM-SCG* vs FORGE (500 ablation seeds, exploratory)", ""]
    # ---- descriptive
    lines += ["## Size and relevance per arm", "",
              "| Arm | median lines | mean functions | requirement-term recall | relevant share of non-view functions |",
              "|---|---|---|---|---|"]
    for a, lab in (("naive", "Naive"), ("fsm", "FSM-SCG*"), ("forge", "FORGE")):
        v = F[a]
        lines.append(f"| {lab} | {np.median([v[s]['loc'] for s in ids]):.0f} | "
                     f"{np.mean([v[s]['n_fn'] for s in ids]):.1f} | "
                     f"{np.mean([v[s]['recall'] for s in ids if v[s]['recall'] is not None]):.3f} | "
                     f"{np.mean([v[s]['fn_rel'] for s in ids if v[s]['fn_rel'] is not None]):.3f} |")
    rel = ps.analyze([
        ps.PairedMetric.from_pairs("Requirement-term recall", "continuous",
                                   [(s, F["fsm"][s]["recall"], F["forge"][s]["recall"]) for s in ids]),
        ps.PairedMetric.from_pairs("Relevant share of non-view functions", "continuous",
                                   [(s, F["fsm"][s]["fn_rel"], F["forge"][s]["fn_rel"]) for s in ids]),
    ])
    lines += ["", "Paired FSM-SCG* vs FORGE (Wilcoxon, Holm over these two):", ""]
    for r in rel:
        lines.append(f"- {r['metric']}: FSM-SCG* {r['naive']:.3f} vs FORGE {r['full']:.3f}, "
                     f"n = {r['n']}, p = {fmt_p(r['p_holm'])}")
    # does recall track the aligner?
    for a, lab in (("fsm", "FSM-SCG*"), ("forge", "FORGE")):
        xs = [(F[a][s]["recall"], core.similarity(M[a][s])) for s in ids
              if F[a][s]["recall"] is not None and core.similarity(M[a][s]) is not None]
        rho = np.corrcoef(*zip(*xs))[0, 1]
        lines.append(f"- Correlation of recall with alignment similarity, {lab}: r = {rho:.2f} (n = {len(xs)})")

    # ---- 1. size-matched
    ratio = {s: min(F["fsm"][s]["loc"], F["forge"][s]["loc"]) / max(F["fsm"][s]["loc"], F["forge"][s]["loc"], 1)
             for s in ids}
    matched = [s for s in ids if ratio[s] >= MATCH]
    res = ps.analyze([ps.PairedMetric.from_pairs(m, kinds.get(m, "proportion"), pairs(m, matched),
                                                 lower_is_better=m in lower) for m in out])
    lines += ["", f"## 1. Size-matched requirements (shorter/longer >= {MATCH}, n = {len(matched)})", "",
              "| Outcome | n | FSM-SCG* | FORGE | p (Holm) |", "|---|---|---|---|---|"]
    for r in res:
        if r["skipped"]:
            continue
        f = (lambda v: f"{v:.1f}%") if r["kind"] == "proportion" else (lambda v: f"{v:.3f}")
        lines.append(f"| {r['metric']} | {r['n']} | {f(r['naive'])} | {f(r['full'])} | {fmt_p(r['p_holm'])} |")

    # ---- 2. size-adjusted
    lines += ["", "## 2. Difference at equal size (all pairs)", "",
              "Per requirement, d = FSM-SCG* - FORGE, regressed on log(FSM-SCG* lines / FORGE lines). "
              "The intercept is the expected difference when both contracts are the same length; the "
              "slope is how much of the difference moves with relative length. HC1 robust SEs.", "",
              "| Outcome | n | raw mean d | d at equal size | p | slope per log-ratio | p |",
              "|---|---|---|---|---|---|---|"]
    reg = {}
    for m in out:
        pr = pairs(m, ids)
        d = np.array([float(a) - float(b) for _, a, b in pr])
        x = np.array([np.log(F["fsm"][s]["loc"] / F["forge"][s]["loc"]) for s, _, _ in pr])
        a0, sa, pa, b1, sb, pb = ols_hc1(d, x)
        reg[m] = {"n": len(pr), "raw": float(d.mean()), "intercept": a0, "p_intercept": pa, "slope": b1, "p_slope": pb}
        lines.append(f"| {m} | {len(pr)} | {d.mean():+.3f} | {a0:+.3f} | {fmt_p(pa)} | {b1:+.3f} | {fmt_p(pb)} |")

    # ---- 3. difficulty strata
    nl = np.array([F["naive"][s]["loc"] for s in ids])
    cuts = np.quantile(nl, [1 / 3, 2 / 3])
    strata = {"short": [s for s in ids if F["naive"][s]["loc"] <= cuts[0]],
              "medium": [s for s in ids if cuts[0] < F["naive"][s]["loc"] <= cuts[1]],
              "long": [s for s in ids if F["naive"][s]["loc"] > cuts[1]]}
    lines += ["", f"## 3. By requirement difficulty (naive contract length tertiles: <= {cuts[0]:.0f}, "
              f"<= {cuts[1]:.0f}, > {cuts[1]:.0f} lines)", "",
              "| Outcome | stratum | n | FSM-SCG* | FORGE | p (unadjusted) |", "|---|---|---|---|---|---|"]
    for m in out:
        for name, sub in strata.items():
            r = ps.analyze_metric(ps.PairedMetric.from_pairs(m, kinds.get(m, "proportion"), pairs(m, sub),
                                                             lower_is_better=m in lower))
            if r["skipped"]:
                continue
            f = (lambda v: f"{v:.1f}%") if r["kind"] == "proportion" else (lambda v: f"{v:.3f}")
            lines.append(f"| {m} | {name} | {r['n']} | {f(r['naive'])} | {f(r['full'])} | {fmt_p(r['p'])} |")
    lines += ["", "Median lines per stratum:", ""]
    for name, sub in strata.items():
        lines.append(f"- {name}: naive {np.median([F['naive'][s]['loc'] for s in sub]):.0f}, "
                     f"FSM-SCG* {np.median([F['fsm'][s]['loc'] for s in sub]):.0f}, "
                     f"FORGE {np.median([F['forge'][s]['loc'] for s in sub]):.0f}")

    out_dir = DS / "analysis_results" / "fsm_scg_size"
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (out_dir / "regression.json").write_text(json.dumps(reg, indent=2, default=float) + "\n")
    print("\n".join(lines))
    print(f"\nwrote {out_dir / 'report.md'}")
    return 0


MATCH = 0.75

if __name__ == "__main__":
    sys.exit(main())
