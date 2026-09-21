"""Extra tables and paper figures for `analyze_naive_vs_full.py`.

Everything here is derived from the cached `meta.json` files plus the `.sol` /
`.txt` next to them; no compiler, Foundry, Slither or LLM is invoked. Sections
that need a metric one corpus lacks (e.g. Slither on an unscored naive corpus)
are skipped and say so, so the module is safe to run at any stage of scoring.

Public entry point: `build(naive, full, sids, out_dir, plots)` ->
(markdown sections, JSON-able numbers).
"""

from __future__ import annotations

import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Callable, Optional, Sequence

import numpy as np

from analysis import paired_stats as ps
from analysis import report

NAIVE_COLOR, FULL_COLOR = report.NAIVE_COLOR, report.FULL_COLOR
MIN_CATEGORY_N = 20   # smaller categories are pooled into "other" in figures


# ---- source-derived features -------------------------------------------------
_STRING = re.compile(r'"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'')
_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
_LINE_COMMENT = re.compile(r"//[^\n]*")
_DECL = re.compile(r"^\s*(?:abstract\s+)?(contract|interface|library)\s+\w+", re.M)


def source_features(code: str) -> dict[str, float]:
    """Cheap structural counts. Comments and string literals are stripped first so a
    `// function foo` or a revert message cannot inflate a count."""
    natspec = len(re.findall(r"^\s*(?:///|/\*\*|\*\s)", code, re.M))
    body = _LINE_COMMENT.sub("", _BLOCK_COMMENT.sub("", _STRING.sub('""', code)))
    lines = [ln for ln in body.splitlines() if ln.strip()]
    return {
        "loc": float(len(lines)),
        "contracts": float(len(_DECL.findall(body))),
        "functions": float(len(re.findall(r"\bfunction\s+\w+", body))),
        "events": float(len(re.findall(r"^\s*event\s+\w+", body, re.M))),
        "modifiers": float(len(re.findall(r"^\s*modifier\s+\w+", body, re.M))),
        "checks": float(len(re.findall(r"\b(?:require|revert|assert)\s*\(|\brevert\s+\w+", body))),
        "imports": float(len(re.findall(r"^\s*import\b", body, re.M))),
        "natspec": float(natspec),
    }


def attach_features(corpus: dict[str, dict]) -> None:
    for sid, meta in corpus.items():
        d = meta.get("_dir")
        if d is None or "_f" in meta:
            continue
        sol = Path(d) / f"{sid}.sol"
        txt = Path(d) / f"{sid}.txt"
        meta["_f"] = source_features(sol.read_text(encoding="utf-8")) if sol.exists() else {}
        meta["_words"] = float(len(txt.read_text(encoding="utf-8").split())) if txt.exists() else None


# ---- solc error taxonomy ------------------------------------------------------
_TAXONOMY: list[tuple[str, Callable[[dict], bool]]] = [
    ("Unresolved import\n(library not on path)",
     lambda e: bool(re.search(r"Source .* not found", e.get("message", "")))),
    ("Event: more than 3\nindexed arguments",
     lambda e: "indexed arguments for event" in e.get("message", "")),
    ("Parse error\n(syntax)", lambda e: e.get("code") == "ParserError"),
    ("Undeclared / duplicate\nidentifier", lambda e: e.get("code") == "DeclarationError"),
    ("Type / conversion error", lambda e: e.get("code") == "TypeError"),
]
_OTHER = "Other"
_IMPORT_LABEL = _TAXONOMY[0][0]


def classify_error(err: dict) -> str:
    for label, test in _TAXONOMY:
        if test(err):
            return label
    return _OTHER


def error_profile(corpus: dict[str, dict], sids: Sequence[str]) -> dict[str, Any]:
    """Classify each failing sample by its FIRST diagnostic (what a reader sees
    first) and separately flag samples whose every error is a missing import."""
    first: Counter = Counter()
    every: Counter = Counter()
    import_only = failing = 0
    for s in sids:
        m = corpus[s]
        if m.get("validation", {}).get("is_valid") is not False:
            continue
        failing += 1
        errs = [e for e in (m.get("errors") or []) if isinstance(e, dict)
                and e.get("severity", "error") == "error"]
        if not errs:
            first["(no diagnostic recorded)"] += 1
            continue
        first[classify_error(errs[0])] += 1
        every.update(set(classify_error(e) for e in errs))
        if all(classify_error(e) == _IMPORT_LABEL for e in errs):
            import_only += 1
    return {"failing": failing, "first": first, "any": every, "import_only": import_only}


# ---- small helpers --------------------------------------------------------------
def _rate(vals: Sequence[Optional[bool]]) -> Optional[float]:
    vals = [v for v in vals if v is not None]
    return sum(vals) / len(vals) if vals else None


def _bootstrap_delta(a: Sequence[bool], b: Sequence[bool], n_boot: int = 2000,
                     seed: int = 20260920) -> tuple[float, float]:
    """Paired bootstrap 95% CI of mean(b) - mean(a), in percentage points."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    rng = np.random.default_rng(seed)
    idx = rng.integers(0, len(a), size=(n_boot, len(a)))
    d = (b[idx].mean(1) - a[idx].mean(1)) * 100
    return float(np.percentile(d, 2.5)), float(np.percentile(d, 97.5))


def _pct(x: Optional[float], digits: int = 1) -> str:
    return "n/a" if x is None else f"{x * 100:.{digits}f}%"


def _savefig(fig, fig_dir: Path, name: str) -> Path:
    fig_dir.mkdir(parents=True, exist_ok=True)
    png = fig_dir / f"{name}.png"
    fig.savefig(png, dpi=200, bbox_inches="tight")
    fig.savefig(fig_dir / f"{name}.pdf", bbox_inches="tight")   # vector copy for LaTeX
    return png


def _style(plt) -> None:
    plt.rcParams.update({
        "font.size": 9, "axes.titlesize": 10, "axes.labelsize": 9,
        "axes.spines.top": False, "axes.spines.right": False,
        "legend.frameon": False, "figure.dpi": 100,
    })


# ---- gates ----------------------------------------------------------------------
def gate_flags(m: dict) -> dict[str, Optional[bool]]:
    """The four quality gates, recomputed from raw fields (the older full corpus has
    no `quality_gates` block). Definitions follow batch_generate.create_meta_json."""
    v = m.get("validation")
    e = m.get("execution")
    s = m.get("security")
    a = m.get("spec_alignment")
    return {
        "solc": None if not isinstance(v, dict) or "is_valid" not in v else bool(v["is_valid"]),
        "execution": None if not isinstance(e, dict) else not e.get("contract_defects"),
        "security": None if not isinstance(s, dict) or s.get("n_actionable") is None
        else s["n_actionable"] == 0,
        "alignment": None if not isinstance(a, dict) or a.get("accepted") is None
        else bool(a["accepted"]),
    }


# ---- main entry -------------------------------------------------------------------
def build(naive: dict[str, dict], full: dict[str, dict], sids: list[str],
          out_dir: Path, plots: bool = True) -> tuple[list[tuple[str, str]], dict[str, Any]]:
    from nl2solidity import analyze_naive_vs_full as core   # metric accessors

    attach_features(naive)
    attach_features(full)
    sections: list[tuple[str, str]] = []
    nums: dict[str, Any] = {}
    n = len(sids)

    scored = [s for s in sids if isinstance(naive[s].get("execution"), dict)
              and isinstance(naive[s].get("spec_alignment"), dict)]
    nums["naive_fully_scored"] = len(scored)
    have_scored = len(scored) > 0

    # ---- compile: contingency, sensitivity, imports --------------------------------
    both = sum(core.is_valid(naive[s]) is True and core.is_valid(full[s]) is True for s in sids)
    full_only = sum(core.is_valid(naive[s]) is False and core.is_valid(full[s]) is True for s in sids)
    naive_only = sum(core.is_valid(naive[s]) is True and core.is_valid(full[s]) is False for s in sids)
    neither = n - both - full_only - naive_only
    nums["compile_contingency"] = {"both": both, "full_only": full_only,
                                   "naive_only": naive_only, "neither": neither}
    tbl = report.table_md(
        ["", "Full compiles", "Full fails"],
        [["**Naive compiles**", both, naive_only], ["**Naive fails**", full_only, neither]])
    all_naive = [s for s in naive if s not in full]
    sens = [f"Naive samples with no full-pipeline output: {len(all_naive)} "
            f"({', '.join(sorted(all_naive))})." if all_naive else "Every naive sample has a full counterpart."]
    if all_naive:
        # intention-to-treat: a sample the pipeline failed to produce is a failure.
        naive_all = [core.is_valid(naive[s]) is True for s in naive]
        full_itt = [core.is_valid(full[s]) is True if s in full else False for s in naive]
        nums["itt"] = {"n": len(naive), "naive_compile": sum(naive_all) / len(naive_all) * 100,
                       "full_compile": sum(full_itt) / len(full_itt) * 100}
        sens.append(f"Counting those as full-pipeline failures over all {len(naive)} prompts: "
                    f"naive {nums['itt']['naive_compile']:.1f}% vs full {nums['itt']['full_compile']:.1f}% "
                    "compile-valid.")
    sections.append(("Compile outcome, paired", tbl + "\n\n" + "\n".join(f"- {x}" for x in sens)))

    prof = error_profile(naive, sids)
    fail = prof["failing"]
    nums["naive_error_profile"] = {
        "failing": fail, "import_only_failures": prof["import_only"],
        "first_error_class": dict(prof["first"]),
    }
    if fail:
        rows = [[k.replace("\n", " "), v, f"{v / fail * 100:.1f}%",
                 prof["any"].get(k, 0)] for k, v in prof["first"].most_common()]
        upper = (sum(core.is_valid(naive[s]) is True for s in sids) + prof["import_only"]) / n
        nums["naive_compile_if_import_only_fixed_pct"] = upper * 100
        sections.append((
            "Why naive contracts fail solc",
            report.table_md(["First diagnostic", "Failing samples", "Share of failures",
                             "Samples with ≥1 error of this class"], rows)
            + f"\n\n- **{prof['import_only']} of {fail} naive failures "
              f"({prof['import_only'] / fail * 100:.0f}%) have only unresolved-import errors** "
              "(e.g. `import \"@openzeppelin/...\"` in a single-file compile). "
              f"If every such contract were repaired by making the import resolvable, the naive "
              f"compile rate would be at most **{upper * 100:.1f}%** (vs {_pct(_rate([core.is_valid(naive[s]) for s in sids]))} "
              "observed): an upper bound, since those contracts may have other latent errors."
            + "\n- The full pipeline's `meta.json` stores only an error *count*, so this taxonomy "
              "is naive-only; the full-pipeline counterpart is the import rate below."))

    imp_n = [naive[s]["_f"].get("imports", 0) for s in sids if naive[s].get("_f")]
    imp_f = [full[s]["_f"].get("imports", 0) for s in sids if full[s].get("_f")]
    if imp_n and imp_f:
        nums["import_usage"] = {"naive_share_with_import": float(np.mean([x > 0 for x in imp_n])) * 100,
                                "full_share_with_import": float(np.mean([x > 0 for x in imp_f])) * 100}
        sections.append(("Import usage", report.table_md(
            ["", "Naive", "Full"],
            [["Contracts with ≥1 `import`", _pct(float(np.mean([x > 0 for x in imp_n]))),
              _pct(float(np.mean([x > 0 for x in imp_f])))],
             ["Mean `import` statements", f"{np.mean(imp_n):.2f}", f"{np.mean(imp_f):.2f}"]])))

    # ---- structural size metrics (secondary family; direction is not "better") -----
    size_specs = [("Lines of code", "loc"), ("Functions", "functions"), ("Events", "events"),
                  ("Modifiers", "modifiers"), ("require/revert/assert checks", "checks"),
                  ("NatSpec/comment-doc lines", "natspec")]
    size_metrics = []
    for label, key in size_specs:
        pairs = [(s, naive[s].get("_f", {}).get(key), full[s].get("_f", {}).get(key)) for s in sids]
        size_metrics.append(ps.PairedMetric.from_pairs(label, "continuous", pairs,
                            note="descriptive: more is not necessarily better"))
    size_results = ps.analyze(size_metrics)
    nums["size_features"] = {r["metric"]: {"naive_mean": r["naive"], "full_mean": r["full"],
                                           "p_holm": r.get("p_holm")}
                             for r in size_results if not r["skipped"]}
    sections.append(("Structural size (secondary family, Holm-adjusted separately)",
                     "Positive Δ means the full pipeline's contracts have *more* of the feature; "
                     "this is descriptive, not a quality judgement.\n\n"
                     + report.markdown_table([r for r in size_results if not r["skipped"]])))

    # ---- generation time (naive only recorded) ---------------------------------------
    times = [naive[s].get("elapsed_sec") for s in sids if naive[s].get("elapsed_sec") is not None]
    if times:
        nums["naive_generation_sec"] = {"mean": float(np.mean(times)),
                                        "median": float(np.median(times)), "p95": float(np.percentile(times, 95))}

    # ---- scored-only sections ------------------------------------------------------------
    if have_scored:
        gate_rows, gate_nums = [], {}
        for g, label in (("solc", "solc compile"), ("execution", "Foundry: builds, 0 contract defects"),
                         ("security", "Slither: 0 actionable"), ("alignment", "Spec alignment accepted")):
            a = _rate([gate_flags(naive[s])[g] for s in scored])
            b = _rate([gate_flags(full[s])[g] for s in scored])
            gate_rows.append([label, _pct(a), _pct(b), f"{(b - a) * 100:+.1f} pp"])
            gate_nums[g] = {"naive": a, "full": b}
        ga = _rate([core.grade_a(naive[s]) for s in scored])
        gb = _rate([core.grade_a(full[s]) for s in scored])
        gate_rows.append(["**Grade A (all four gates)**", _pct(ga), _pct(gb), f"{(gb - ga) * 100:+.1f} pp"])
        nums["gates"] = gate_nums
        sections.append((f"Quality gates (n={len(scored)} pairs with the naive corpus fully scored)",
                         report.table_md(["Gate", "Naive", "Full", "Δ"], gate_rows)
                         + "\n\nThe security gate passes vacuously for a contract Slither could not "
                           "analyse (it did not compile); the paired `Slither actionable-clean` row "
                           "above is restricted to pairs where both contracts compile."))

        sim_n = [core.similarity(naive[s]) for s in scored]
        sim_f = [core.similarity(full[s]) for s in scored]
        rows = []
        for thr in (0.8, 0.9, 0.95):
            rows.append([f"similarity ≥ {thr}",
                         _pct(_rate([x >= thr for x in sim_n if x is not None])),
                         _pct(_rate([x >= thr for x in sim_f if x is not None]))])
        sections.append(("Spec-alignment thresholds", report.table_md(["", "Naive", "Full"], rows)))

        fc_n, fc_f = Counter(), Counter()
        for s in scored:
            for corpus, c in ((naive, fc_n), (full, fc_f)):
                e = corpus[s].get("execution") or {}
                for k, v in (e.get("failure_classes") or {}).items():
                    c[k] += v
        if fc_n or fc_f:
            keys = [k for k, _ in (fc_n + fc_f).most_common()]
            sections.append(("Execution failure classes (total test failures per corpus)",
                             report.table_md(["Class", "Naive", "Full"],
                                             [[k, fc_n.get(k, 0), fc_f.get(k, 0)] for k in keys])))
            nums["failure_classes"] = {"naive": dict(fc_n), "full": dict(fc_f)}
    else:
        sections.append(("Execution / security / alignment",
                         "The naive corpus carries no Foundry, Slither or alignment results yet. "
                         "Run `nl2solidity/score_naive_glm.py`, then rerun this analysis."))

    if plots:
        figs = make_figures(naive, full, sids, scored, prof, size_results, out_dir / "figures", core)
        nums["figures"] = sorted(str(p.relative_to(out_dir)) for p in figs)
    return sections, nums


# ---- figures ---------------------------------------------------------------------------
def make_figures(naive, full, sids, scored, prof, size_results, fig_dir: Path, core) -> list[Path]:
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib not installed — skipping figures")
        return []
    _style(plt)
    out: list[Path] = []
    n = len(sids)
    N, F = "Naive", "Full pipeline"

    def emit(fig, name):
        out.append(_savefig(fig, fig_dir, name))
        plt.close(fig)

    # 1. paired compile outcomes -------------------------------------------------------
    both = sum(core.is_valid(naive[s]) is True and core.is_valid(full[s]) is True for s in sids)
    fo = sum(core.is_valid(naive[s]) is False and core.is_valid(full[s]) is True for s in sids)
    no = sum(core.is_valid(naive[s]) is True and core.is_valid(full[s]) is False for s in sids)
    ne = n - both - fo - no
    fig, ax = plt.subplots(figsize=(7.2, 1.9))
    left = 0
    for lab, v, col in (("Both compile", both, "#8c8c8c"), ("Only full compiles", fo, FULL_COLOR),
                        ("Only naive compiles", no, NAIVE_COLOR), ("Neither", ne, "#d9d9d9")):
        ax.barh([0], [v / n * 100], left=left, color=col, edgecolor="white")
        if v / n > 0.03:
            ax.text(left + v / n * 50, 0, f"{v}\n({v / n * 100:.1f}%)", ha="center", va="center",
                    fontsize=8, color="white" if col != "#d9d9d9" else "black")
        left += v / n * 100
    ax.set_xlim(0, 100); ax.set_yticks([]); ax.set_xlabel("% of paired prompts")
    ax.set_title(f"Paired solc outcome per prompt (n={n})")
    handles = [plt.Rectangle((0, 0), 1, 1, color=c) for c in ("#8c8c8c", FULL_COLOR, NAIVE_COLOR, "#d9d9d9")]
    ax.legend(handles, ["Both compile", "Only full", "Only naive", "Neither"], ncol=4,
              loc="upper center", bbox_to_anchor=(0.5, -0.55))
    emit(fig, "compile_outcome_pairs")

    # 2. solc error-count distribution + paired delta -----------------------------------
    en = [int(core.solc_errors(naive[s])) for s in sids if core.solc_errors(naive[s]) is not None]
    ef = [int(core.solc_errors(full[s])) for s in sids if core.solc_errors(full[s]) is not None]
    bins = [0, 1, 2, 3, 4, 5]
    lab = ["0", "1", "2", "3", "4", "5+"]
    def dist(v):
        c = Counter(min(x, 5) for x in v)
        return [c.get(b, 0) / len(v) * 100 for b in bins]
    fig, axes = plt.subplots(1, 2, figsize=(9.5, 3.4))
    x = np.arange(len(bins)); w = 0.38
    axes[0].bar(x - w / 2, dist(en), w, color=NAIVE_COLOR, label=N)
    axes[0].bar(x + w / 2, dist(ef), w, color=FULL_COLOR, label=F)
    axes[0].set_xticks(x, lab); axes[0].set_xlabel("solc errors in the sample")
    axes[0].set_ylabel("% of samples"); axes[0].set_title("Distribution of solc error count")
    axes[0].legend()
    diffs = [int(core.solc_errors(naive[s]) - core.solc_errors(full[s])) for s in sids
             if core.solc_errors(naive[s]) is not None and core.solc_errors(full[s]) is not None]
    dc = Counter(max(-4, min(d, 6)) for d in diffs)
    ks = sorted(dc)
    axes[1].bar([str(k) if -4 < k < 6 else ("≤-4" if k == -4 else "≥6") for k in ks],
                [dc[k] / len(diffs) * 100 for k in ks],
                color=[FULL_COLOR if k > 0 else ("#8c8c8c" if k == 0 else NAIVE_COLOR) for k in ks])
    axes[1].set_xlabel("naive errors − full errors (per prompt)")
    axes[1].set_ylabel("% of pairs"); axes[1].set_title("Per-prompt change (right = full better)")
    fig.tight_layout(); emit(fig, "solc_error_distribution")

    # 3. why naive fails ----------------------------------------------------------------
    if prof["failing"]:
        fig, axes = plt.subplots(1, 2, figsize=(10, 3.6), gridspec_kw={"width_ratios": [1.5, 1]})
        items = prof["first"].most_common()
        labels = [k for k, _ in items]
        vals = [v / prof["failing"] * 100 for _, v in items]
        axes[0].barh(range(len(items)), vals, color=NAIVE_COLOR)
        axes[0].set_yticks(range(len(items)), labels, fontsize=8); axes[0].invert_yaxis()
        for i, (v, (_, c)) in enumerate(zip(vals, items)):
            axes[0].text(v + 0.8, i, f"{v:.0f}% ({c})", va="center", fontsize=8)
        axes[0].set_xlim(0, max(vals) * 1.25)
        axes[0].set_xlabel("% of failing naive contracts"); axes[0].set_title(
            f"First solc diagnostic of the {prof['failing']} failing naive contracts")
        io, other = prof["import_only"], prof["failing"] - prof["import_only"]
        axes[1].bar(["Only import\nerrors", "Any other\nerror"], [io, other],
                    color=["#dd8452", NAIVE_COLOR])
        for i, v in enumerate([io, other]):
            axes[1].text(i, v + prof["failing"] * 0.01, f"{v} ({v / prof['failing'] * 100:.0f}%)",
                         ha="center", fontsize=8)
        axes[1].set_ylabel("failing naive contracts"); axes[1].set_title("Import errors alone")
        fig.tight_layout(); emit(fig, "naive_error_taxonomy")

    # 4. category compile rates + delta -------------------------------------------------
    groups: dict[str, list[str]] = defaultdict(list)
    for s in sids:
        groups[full[s].get("category") or naive[s].get("category") or "unknown"].append(s)
    big = {k: v for k, v in groups.items() if len(v) >= MIN_CATEGORY_N}
    small = [s for k, v in groups.items() if len(v) < MIN_CATEGORY_N for s in v]
    if small:
        big[f"other (<{MIN_CATEGORY_N} each)"] = small
    rows = []
    for cat, mem in big.items():
        a = [core.is_valid(naive[s]) is True for s in mem]
        b = [core.is_valid(full[s]) is True for s in mem]
        lo, hi = _bootstrap_delta(a, b)
        rows.append((cat, len(mem), np.mean(a) * 100, np.mean(b) * 100, (np.mean(b) - np.mean(a)) * 100, lo, hi))
    rows.sort(key=lambda r: r[4])
    fig, axes = plt.subplots(1, 2, figsize=(10, max(3.5, 0.34 * len(rows) + 1.3)),
                             gridspec_kw={"width_ratios": [1.3, 1]}, sharey=True)
    y = np.arange(len(rows)); h = 0.38
    axes[0].barh(y - h / 2, [r[2] for r in rows], h, color=NAIVE_COLOR, label=N)
    axes[0].barh(y + h / 2, [r[3] for r in rows], h, color=FULL_COLOR, label=F)
    axes[0].set_yticks(y, [f"{r[0]} (n={r[1]})" for r in rows], fontsize=8)
    axes[0].set_xlim(0, 100); axes[0].set_xlabel("solc compile-valid (%)")
    axes[0].legend(loc="upper center", bbox_to_anchor=(0.5, -0.09 - 0.25 / max(1, len(rows) / 10)), ncol=2)
    axes[0].set_title("Compile rate by category")
    axes[1].errorbar([r[4] for r in rows], y, xerr=[[r[4] - r[5] for r in rows], [r[6] - r[4] for r in rows]],
                     fmt="o", color="black", ecolor="#666", capsize=2, ms=4)
    axes[1].axvline(0, color="black", lw=0.8)
    axes[1].set_xlabel("Δ compile rate, full − naive (pp), paired 95% CI")
    axes[1].set_title("Gain from the pipeline")
    fig.tight_layout(); emit(fig, "category_compile")

    # 5. code size distributions ----------------------------------------------------------
    live = [r for r in size_results if not r["skipped"]]
    if live:
        by_name = {"Lines of code": "loc", "Functions": "functions", "Events": "events",
                   "Modifiers": "modifiers", "require/revert/assert checks": "checks"}
        panels = [(k, v) for k, v in by_name.items()]
        fig, axes = plt.subplots(1, len(panels), figsize=(2.6 * len(panels), 3.4))
        for ax, (label, key) in zip(axes, panels):
            dn = [naive[s]["_f"][key] for s in sids if naive[s].get("_f")]
            df = [full[s]["_f"][key] for s in sids if full[s].get("_f")]
            bp = ax.boxplot([dn, df], tick_labels=["Naive", "Full"], patch_artist=True, showfliers=False)
            for patch, col in zip(bp["boxes"], (NAIVE_COLOR, FULL_COLOR)):
                patch.set_facecolor(col); patch.set_alpha(0.65)
            for med in bp["medians"]:
                med.set_color("black")
            ax.set_title(f"{label}\nmean {np.mean(dn):.1f} vs {np.mean(df):.1f}", fontsize=9)
        fig.suptitle("Structural size of generated contracts (paired prompts)", y=1.02)
        fig.tight_layout(); emit(fig, "code_size")

    # 6. compile rate vs prompt length and output size -------------------------------------
    def quintile_rates(keyfn, corpus):
        pts = [(keyfn(corpus[s]), core.is_valid(corpus[s]) is True) for s in sids if keyfn(corpus[s]) is not None]
        pts.sort(key=lambda t: t[0])
        chunks = np.array_split(np.arange(len(pts)), 5)
        return [(np.mean([pts[i][0] for i in c]), np.mean([pts[i][1] for i in c]) * 100) for c in chunks]

    fig, axes = plt.subplots(1, 2, figsize=(9.5, 3.4))
    for ax, keyfn, xlabel, title in (
            (axes[0], lambda m: m.get("_words"), "requirement length (words), quintile mean",
             "Compile rate vs. prompt length"),
            (axes[1], lambda m: (m.get("_f") or {}).get("loc"), "generated lines of code, quintile mean",
             "Compile rate vs. output size")):
        for corpus, col, lab in ((naive, NAIVE_COLOR, N), (full, FULL_COLOR, F)):
            pts = quintile_rates(keyfn, corpus)
            ax.plot([p[0] for p in pts], [p[1] for p in pts], "o-", color=col, label=lab)
        ax.set_xlabel(xlabel); ax.set_ylabel("solc compile-valid (%)"); ax.set_title(title)
        ax.set_ylim(0, 102); ax.legend(loc="lower left")
    fig.tight_layout(); emit(fig, "compile_vs_length")

    if not scored:
        return out

    # ---- figures that need the naive corpus scored ----------------------------------------
    ns = len(scored)

    # 7. failure funnel -----------------------------------------------------------------------
    all_stages = [("empty output", "#7f7f7f"), ("fails solc", "#a1332f"),
                  ("solc ok, execution not scored", "#bdbdbd"),
                  ("solc ok, Foundry build fails", "#dd8452"), ("compiles, fuzz tier fails", "#e6c229"),
                  ("fuzz ok, property tier not passed", "#f2e2a0"), ("passes execution tiers", FULL_COLOR)]
    cn, cf = core.failure_breakdown(naive, scored), core.failure_breakdown(full, scored)
    stages = [(k, c) for k, c in all_stages if cn.get(k) or cf.get(k)]
    order, colors = [k for k, _ in stages], [c for _, c in stages]
    fig, ax = plt.subplots(figsize=(8.5, 2.6))
    for row, (name, c) in enumerate(((N, cn), (F, cf))):
        left = 0
        for k, col in zip(order, colors):
            v = c.get(k, 0) / ns * 100
            ax.barh(row, v, left=left, color=col, edgecolor="white", label=k if row == 0 else None)
            if v > 4:
                ax.text(left + v / 2, row, f"{v:.0f}%", ha="center", va="center", fontsize=8,
                        color="black" if col in ("#f2e2a0", "#bdbdbd", "#e6c229") else "white")
            left += v
    ax.set_yticks([0, 1], [N, F]); ax.invert_yaxis(); ax.set_xlim(0, 100)
    ax.set_xlabel("% of prompts (first stage each contract fails)")
    ax.set_title(f"Where contracts stop passing (n={ns})")
    ax.legend(ncol=3, loc="upper center", bbox_to_anchor=(0.5, -0.35), fontsize=7.5)
    emit(fig, "failure_funnel")

    # 8. gate pass rates -----------------------------------------------------------------------
    gl = [("solc", "solc\ncompile"), ("execution", "Foundry\n0 defects"),
          ("security", "Slither\n0 actionable"), ("alignment", "Spec\nalignment")]
    an = [_rate([gate_flags(naive[s])[g] for s in scored]) * 100 for g, _ in gl] + \
         [_rate([core.grade_a(naive[s]) for s in scored]) * 100]
    af = [_rate([gate_flags(full[s])[g] for s in scored]) * 100 for g, _ in gl] + \
         [_rate([core.grade_a(full[s]) for s in scored]) * 100]
    fig, ax = plt.subplots(figsize=(7.5, 3.4))
    x = np.arange(len(an)); w = 0.38
    bn = ax.bar(x - w / 2, an, w, color=NAIVE_COLOR, label=N)
    bf = ax.bar(x + w / 2, af, w, color=FULL_COLOR, label=F)
    for bars in (bn, bf):
        for b in bars:
            ax.text(b.get_x() + b.get_width() / 2, b.get_height() + 1, f"{b.get_height():.0f}", ha="center", fontsize=8)
    ax.set_xticks(x, [l for _, l in gl] + ["Grade A\n(all gates)"])
    ax.set_ylim(0, 110); ax.set_ylabel("% of prompts passing"); ax.legend(loc="lower left")
    ax.set_title(f"Quality gates (n={ns})")
    emit(fig, "quality_gates")

    # 9. similarity ----------------------------------------------------------------------------
    sn = [core.similarity(naive[s]) for s in scored]
    sf = [core.similarity(full[s]) for s in scored]
    pairs = [(a, b) for a, b in zip(sn, sf) if a is not None and b is not None]
    if pairs:
        fig, axes = plt.subplots(1, 2, figsize=(9.5, 3.6))
        bins_ = np.linspace(0.4, 1.0, 31)
        axes[0].hist([p[0] for p in pairs], bins=bins_, color=NAIVE_COLOR, alpha=0.65, label=N)
        axes[0].hist([p[1] for p in pairs], bins=bins_, color=FULL_COLOR, alpha=0.65, label=F)
        axes[0].axvline(0.8, color="black", ls="--", lw=0.9)
        axes[0].text(0.802, axes[0].get_ylim()[1] * 0.92, "accept ≥ 0.8", fontsize=8)
        axes[0].set_xlabel("twin-blind spec-alignment similarity"); axes[0].set_ylabel("prompts")
        axes[0].set_title("Alignment similarity distribution"); axes[0].legend(loc="upper left")
        axes[1].scatter([p[0] for p in pairs], [p[1] for p in pairs], s=6, alpha=0.35, color="#555")
        axes[1].plot([0.4, 1], [0.4, 1], color="black", lw=0.8)
        axes[1].axhline(0.8, color="grey", ls=":", lw=0.8); axes[1].axvline(0.8, color="grey", ls=":", lw=0.8)
        axes[1].set_xlim(0.4, 1.01); axes[1].set_ylim(0.4, 1.01)
        axes[1].set_xlabel("naive similarity"); axes[1].set_ylabel("full-pipeline similarity")
        axes[1].set_title("Paired (above diagonal = full better)")
        fig.tight_layout(); emit(fig, "alignment_similarity")

    # 10. Slither findings by impact (both compile) --------------------------------------------
    both_ok = [s for s in scored if core.is_valid(naive[s]) is True and core.is_valid(full[s]) is True
               and isinstance(naive[s].get("security"), dict) and isinstance(full[s].get("security"), dict)]
    if both_ok:
        impacts = ["High", "Medium", "Low", "Informational", "Optimization"]
        def mean_impact(corpus, imp):
            return np.mean([(corpus[s]["security"].get("by_impact") or {}).get(imp, 0) for s in both_ok])
        present = [i for i in impacts if mean_impact(naive, i) or mean_impact(full, i)] or impacts[:3]
        fig, ax = plt.subplots(figsize=(7.5, 3.4))
        x = np.arange(len(present)); w = 0.38
        ax.bar(x - w / 2, [mean_impact(naive, i) for i in present], w, color=NAIVE_COLOR, label=N)
        ax.bar(x + w / 2, [mean_impact(full, i) for i in present], w, color=FULL_COLOR, label=F)
        ax.set_xticks(x, present); ax.set_ylabel("mean Slither findings per contract")
        ax.set_title(f"Slither findings by impact (pairs where both compile, n={len(both_ok)})")
        ax.legend()
        emit(fig, "slither_by_impact")

    # 11. category x metric delta heatmap -------------------------------------------------------
    cols = [("solc", core.is_valid, "solc"), ("exec", core.defect_free, "Foundry\n0 defects"),
            ("sec", core.sec_clean, "Slither\nclean"), ("align", core.align_accepted, "Alignment\naccepted"),
            ("A", core.grade_a, "Grade A")]
    cats = sorted([c for c, m in groups.items() if len([s for s in m if s in set(scored)]) >= MIN_CATEGORY_N],
                  key=lambda c: -len(groups[c]))
    if cats:
        mat = np.full((len(cats), len(cols)), np.nan)
        sc = set(scored)
        for i, c in enumerate(cats):
            mem = [s for s in groups[c] if s in sc]
            for j, (_, get, _) in enumerate(cols):
                a = [get(naive[s]) for s in mem]; b = [get(full[s]) for s in mem]
                pr = [(x, y) for x, y in zip(a, b) if x is not None and y is not None]
                if pr:
                    mat[i, j] = (np.mean([y for _, y in pr]) - np.mean([x for x, _ in pr])) * 100
        lim = np.nanmax(np.abs(mat)) or 1
        fig, ax = plt.subplots(figsize=(6.4, 0.34 * len(cats) + 1.6))
        im = ax.imshow(mat, cmap="RdBu", vmin=-lim, vmax=lim, aspect="auto")
        ax.set_xticks(range(len(cols)), [c[2] for c in cols], fontsize=8)
        ax.set_yticks(range(len(cats)), [f"{c} (n={len([s for s in groups[c] if s in sc])})" for c in cats], fontsize=8)
        for i in range(len(cats)):
            for j in range(len(cols)):
                if not np.isnan(mat[i, j]):
                    ax.text(j, i, f"{mat[i, j]:+.0f}", ha="center", va="center", fontsize=7)
        fig.colorbar(im, ax=ax, label="Δ pass rate, full − naive (pp)", shrink=0.8)
        ax.set_title("Pipeline gain by category and gate")
        ax.spines[:].set_visible(False)
        fig.tight_layout(); emit(fig, "category_gate_delta")

    return out
