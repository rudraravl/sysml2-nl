#!/usr/bin/env python3
"""Paired naive-vs-full analysis of the robotics Modelica study (Modelica twin of
the SysML comparison notebook's compiler / execution / power sections).

Reads ONLY the `run.json` written per study cell — no OpenModelica, FMU or LLM
calls — so it runs in seconds on the local checkout and on a PACE copy alike.

Study layout (one `run.json` per cell):

    <root>/<task_id>/<variant>/<condition>/repeat-NN/run.json

    naive = condition B0   (direct one-shot frontier model, no RAG/MoE/repair/alignment)
    full  = condition FULL (RAG + MoE + tool repair + validated contract + alignment)

Cells are paired on (task_id, variant, repetition). Pairs where EITHER side is an
infrastructure failure are excluded, per the study's exclusion policy
(`study-protocol.json`: infrastructure failures are reruns, never model outcomes).

What is and is not comparable
    Both conditions are scored by the same native harness for: artifact produced,
    Modelica compiles, FMU export, FMU execution, valid finite trace. Those get
    paired tests. Behavioural properties, the normalised IR, the contract and the
    semantic score exist only for FULL (B0 never builds a contract), so they are
    reported descriptively for FULL and never tested against the baseline.
    Failures count as failures (intent-to-treat): a cell that never produced a
    model is a 0 for every downstream metric, not a missing value.

Usage
    python nl2robotics/modelica/analyze_naive_vs_full.py \\
        --naive-root nl2robotics/modelica_naive \\
        --full-root  nl2robotics/robotics-corpus-full-glm52-v1
    # PACE: point both roots at the copied study output directories.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Callable, Optional

_HERE = Path(__file__).resolve().parent
_ROBOTICS = _HERE.parent
_ROOT = _ROBOTICS.parent
sys.path.insert(0, str(_ROOT))

from analysis import paired_stats as ps  # noqa: E402
from analysis import report  # noqa: E402

DEFAULT_NAIVE = _ROBOTICS / "modelica_naive"
DEFAULT_FULL = _ROBOTICS / "robotics-corpus-full-glm52-v1"
DEFAULT_MANIFEST = _ROBOTICS / "corpus" / "pipeline_prompt_manifest.json"
DEFAULT_OUT = _ROBOTICS / "analysis_results" / "modelica_naive_vs_full"

Key = tuple  # (task_id, variant, repetition)


# ---- loading ----------------------------------------------------------------
def load_cells(root: Path, condition: str, variant: str) -> dict[Key, dict]:
    cells: dict[Key, dict] = {}
    for path in sorted(root.glob(f"*/{variant}/{condition}/repeat-*/run.json")):
        try:
            run = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as e:
            print(f"  ! unreadable {path}: {e}", file=sys.stderr)
            continue
        found = (run.get("condition") or {}).get("id")
        if found != condition:
            print(f"  ! {path} holds condition {found!r}, expected {condition!r} — skipped",
                  file=sys.stderr)
            continue
        cells[(run.get("task_id"), run.get("variant"), run.get("repetition"))] = run
    return cells


def is_infra_failure(run: dict) -> bool:
    m = run.get("metrics") or {}
    return bool(run.get("infrastructure_error")) or m.get("infrastructure_available") is False


def load_families(manifest: Path) -> dict[str, str]:
    if not manifest.exists():
        print(f"  (manifest {manifest} not found — family breakdown skipped)")
        return {}
    cases = json.loads(manifest.read_text(encoding="utf-8")).get("cases", [])
    return {c["id"]: c.get("family", "unknown") for c in cases}


# ---- metric accessors (intent-to-treat: anything but True is a failure) -----
def _m(run: dict) -> dict:
    return run.get("metrics") or {}


def flag(name: str) -> Callable[[dict], bool]:
    return lambda run: _m(run).get(name) is True


def artifact_produced(run: dict) -> bool:
    # modelica_build is None only when generation never yielded a model.
    return _m(run).get("modelica_build") is not None


def duration(run: dict) -> Optional[float]:
    v = run.get("duration_seconds")
    return float(v) if isinstance(v, (int, float)) else None


HARNESS_METRICS: list[tuple[str, Callable[[dict], bool], str]] = [
    ("Artifact produced (Modelica generated)", artifact_produced,
     "FULL can also fail earlier, at requirement normalisation, which B0 does not have"),
    ("Modelica compiles (final)", flag("modelica_build"),
     "after any repair the condition allows"),
    ("Modelica compiles (attempt 0)", flag("modelica_build_attempt_0"),
     "first generation, before any repair — the cleanest like-for-like generation metric"),
    ("FMU export succeeds", flag("fmu_export"), ""),
    ("FMU executes", flag("fmu_execution"), ""),
    ("Valid finite trace (stable simulation)", flag("stable_simulation"),
     "the last stage both conditions share"),
]


SHORT = {"Modelica compiles (attempt 0)": "Compiles@0",
         "Modelica compiles (final)": "Compiles",
         "Valid finite trace (stable simulation)": "Valid trace",
         "FMU executes": "FMU exec",
         "FMU export succeeds": "FMU export",
         "Artifact produced (Modelica generated)": "Produced"}


def distinct_harness(pairs: list[tuple[Key, dict, dict]]):
    """HARNESS_METRICS minus any whose paired flags are identical, cell for cell,
    to an earlier one (e.g. FMU execution == valid trace whenever every executed
    FMU yields a finite trace). Duplicates would only inflate the Holm family.
    Returns (kept, [(dropped_name, kept_name)])."""
    kept, dropped, seen = [], [], {}
    for name, get, note in HARNESS_METRICS:
        sig = tuple((get(n), get(f)) for _, n, f in pairs)
        if sig in seen:
            dropped.append((name, seen[sig]))
        else:
            seen[sig] = name
            kept.append((name, get, note))
    return kept, dropped


# ---- analysis ---------------------------------------------------------------
def build_metrics(pairs: list[tuple[Key, dict, dict]], harness=None) -> list[ps.PairedMetric]:
    M = ps.PairedMetric.from_pairs
    out = [M(name, "proportion", [(k, get(n), get(f)) for k, n, f in pairs], note=note)
           for name, get, note in (harness or HARNESS_METRICS)]
    out.append(M("Wall-clock seconds per cell", "continuous",
                 [(k, duration(n), duration(f)) for k, n, f in pairs],
                 lower_is_better=True,
                 note="a cost, not a quality metric: FULL runs more stages by design"))
    return out


def stratified(pairs, key_of: Callable[[Key], str], harness,
               min_n: int = 1) -> list[dict]:
    """Per-group pass rates for the harness metrics: {metric: (naive %, full %)}."""
    groups: dict[str, list] = defaultdict(list)
    for k, n, f in pairs:
        groups[key_of(k)].append((n, f))
    rows = []
    for g, members in groups.items():
        if len(members) < min_n:
            continue
        row = {"group": g, "n": len(members)}
        for name, get, _ in harness:
            a = sum(get(n) for n, _ in members) / len(members) * 100
            b = sum(get(f) for _, f in members) / len(members) * 100
            row[name] = (a, b)
        rows.append(row)
    rows.sort(key=lambda r: -r["n"])
    return rows


def strat_table(rows: list[dict], which: list[str]) -> str:
    headers = ["Group", "n"]
    for w in which:
        headers += [f"{SHORT.get(w, w)} naive", "full", "Δ pp"]
    body = []
    for r in rows:
        line = [r["group"], r["n"]]
        for w in which:
            a, b = r[w]
            line += [f"{a:.0f}%", f"{b:.0f}%", f"{b - a:+.0f}"]
        body.append(line)
    return report.table_md(headers, body)


def stage_distribution(runs: list[dict]) -> Counter:
    return Counter(_m(r).get("failure_stage") or "(none)" for r in runs)


def full_only_descriptives(runs: list[dict]) -> str:
    n = len(runs)

    def frac(pred, denom_pred=lambda r: True):
        pool = [r for r in runs if denom_pred(r)]
        hit = sum(1 for r in pool if pred(r))
        return f"{hit}/{len(pool)} ({hit / len(pool) * 100:.1f}%)" if pool else "n/a"

    def mean_of(name):
        vals = [_m(r).get(name) for r in runs]
        vals = [v for v in vals if isinstance(v, (int, float)) and not isinstance(v, bool)]
        return f"{sum(vals) / len(vals):.3f} (n={len(vals)})" if vals else "n/a"

    rows = [
        ["Requirement normalisation valid", frac(lambda r: _m(r).get("normalization_valid") is True)],
        ["Requirement IR valid", frac(lambda r: _m(r).get("ir_valid") is True)],
        ["Execution contract valid", frac(lambda r: _m(r).get("contract_valid") is True)],
        ["FMU interface matches contract", frac(lambda r: _m(r).get("fmu_interface_valid") is True)],
        ["Behaviour evaluated (trace + properties checked)",
         frac(lambda r: _m(r).get("behavior_evaluated") is True)],
        ["All properties pass, among behaviour evaluated",
         frac(lambda r: _m(r).get("all_properties_pass") is True,
              lambda r: _m(r).get("behavior_evaluated") is True)],
        ["Mean property satisfaction rate, among evaluated", mean_of("property_satisfaction_rate_evaluable")],
        ["Mean semantic score, among evaluated", mean_of("semantic_score")],
        ["Post-execution semantic pass", frac(lambda r: _m(r).get("post_execution_semantic") is True,
                                              lambda r: _m(r).get("post_execution_semantic") is not None)],
        ["End-to-end success (all of the above)", frac(lambda r: _m(r).get("end_to_end") is True)],
        ["Mean repairs used", mean_of("repairs")],
    ]
    return (f"FULL only, over the {n} included cells. The baseline never builds a contract, so "
            "none of this is testable against it.\n\n"
            + report.table_md(["Stage / metric", "FULL"], rows))


def _clip(v: str, width: int = 70) -> str:
    return v if len(v) <= width else v[:width - 1] + "…"


def config_differences(naive: list[dict], full: list[dict]) -> str:
    """Study settings that differ between the two runs. Anything here other than
    the ablation switches themselves is a potential confound."""
    ignore = {"benchmark_manifest", "benchmark_manifest_sha256", "study_protocol_core_sha256"}

    def modal(runs: list[dict]) -> dict[str, tuple[str, int]]:
        acc: dict[str, Counter] = defaultdict(Counter)
        for r in runs:
            for k, v in (r.get("configuration") or {}).items():
                acc[k][json.dumps(v, sort_keys=True)] += 1
        return {k: c.most_common(1)[0] for k, c in acc.items()}

    a, b = modal(naive), modal(full)
    rows = []
    for k in sorted(set(a) | set(b)):
        if k in ignore:
            continue
        va, vb = a.get(k), b.get(k)
        if (va and va[0]) != (vb and vb[0]):
            rows.append([f"`{k}`", _clip(va[0]) if va else "—", _clip(vb[0]) if vb else "—"])
    proto = sorted({(r.get("configuration") or {}).get("study_protocol_core_sha256", "")[:12]
                    for r in naive}), sorted({(r.get("configuration") or {}).get("study_protocol_core_sha256", "")[:12]
                                             for r in full})
    head = (f"Protocol hashes differ between the corpora (naive {proto[0]}, full {proto[1]}), "
            "so these were separate study runs." if proto[0] != proto[1] else
            "Both corpora share one frozen protocol hash.")
    if not rows:
        return head + " No configuration keys differ."
    return (head + " Anything below other than the ablation switches themselves is a potential "
            "confound (e.g. a different model or execution backend); weigh it before attributing "
            "a gap to the pipeline stages. Settings that differ (most common value per corpus):\n\n"
            + report.table_md(["Setting", "Naive", "Full"], rows))


def family_delta_plot(rows: list[dict], metric: str, out_dir: Path) -> Optional[Path]:
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        return None
    rows = sorted(rows, key=lambda r: r[metric][1] - r[metric][0])
    fig, ax = plt.subplots(figsize=(8, max(3, 0.4 * len(rows) + 1.2)))
    deltas = [r[metric][1] - r[metric][0] for r in rows]
    ax.barh([f"{r['group']} (n={r['n']})" for r in rows], deltas,
            color=[report.FULL_COLOR if d >= 0 else report.NAIVE_COLOR for d in deltas],
            edgecolor="black")
    ax.axvline(0, color="black", lw=1)
    ax.set_xlabel("Δ pass rate, full − naive (pp)")
    ax.set_title(f"{metric} by robot family")
    fig.tight_layout()
    p = out_dir / "by_family.png"
    fig.savefig(p, dpi=150)
    plt.close(fig)
    return p


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--naive-root", default=str(DEFAULT_NAIVE))
    ap.add_argument("--full-root", default=str(DEFAULT_FULL))
    ap.add_argument("--naive-condition", default="B0")
    ap.add_argument("--full-condition", default="FULL")
    ap.add_argument("--variant", default="rich", help="prompt variant directory (default rich)")
    ap.add_argument("--manifest", default=str(DEFAULT_MANIFEST),
                    help="prompt manifest, for the per-family breakdown")
    ap.add_argument("--out-dir", default=str(DEFAULT_OUT))
    ap.add_argument("--no-plots", action="store_true")
    args = ap.parse_args()

    naive_root, full_root = Path(args.naive_root), Path(args.full_root)
    for label, d in (("naive", naive_root), ("full", full_root)):
        if not d.is_dir():
            sys.exit(f"{label} root not found: {d}")

    naive = load_cells(naive_root, args.naive_condition, args.variant)
    full = load_cells(full_root, args.full_condition, args.variant)
    keys = sorted(set(naive) & set(full), key=lambda k: (str(k[0]), str(k[1]), k[2] or 0))
    print(f"naive ({args.naive_condition}): {len(naive)} cells  <- {naive_root}")
    print(f"full  ({args.full_condition}): {len(full)} cells  <- {full_root}")
    print(f"paired: {len(keys)}   naive-only: {len(set(naive) - set(full))}   "
          f"full-only: {len(set(full) - set(naive))}")
    if not keys:
        sys.exit("No overlapping (task, variant, repetition) cells — nothing to compare.")

    excl_naive = [k for k in keys if is_infra_failure(naive[k])]
    excl_full = [k for k in keys if is_infra_failure(full[k])]
    excluded = set(excl_naive) | set(excl_full)
    pairs = [(k, naive[k], full[k]) for k in keys if k not in excluded]
    print(f"infrastructure exclusions: naive {len(excl_naive)}, full {len(excl_full)} "
          f"-> {len(excluded)} pairs dropped, {len(pairs)} analysed")
    if not pairs:
        sys.exit("Every pair was an infrastructure exclusion.")

    reps = Counter(k[2] for k, _, _ in pairs)
    families = load_families(Path(args.manifest))

    harness, dropped = distinct_harness(pairs)
    metrics = build_metrics(pairs, harness)
    results = ps.analyze(metrics)
    title = (f"Naive vs full pipeline — Modelica "
             f"({args.naive_condition} vs {args.full_condition}, n={len(pairs)} pairs)")
    report.print_summary(results, title)

    naive_runs = [n for _, n, _ in pairs]
    full_runs = [f for _, _, f in pairs]
    nd, fd = stage_distribution(naive_runs), stage_distribution(full_runs)
    stages = sorted(set(nd) | set(fd), key=lambda s: -(nd[s] + fd[s]))
    stage_tbl = report.table_md(
        ["failure_stage", "Naive", "Full"],
        [[s, f"{nd[s]} ({nd[s] / len(pairs) * 100:.1f}%)", f"{fd[s]} ({fd[s] / len(pairs) * 100:.1f}%)"]
         for s in stages])

    kept_names = {n for n, _, _ in harness}
    which = [w for w in ("Modelica compiles (attempt 0)", "FMU export succeeds", "FMU executes",
                         "Valid finite trace (stable simulation)") if w in kept_names]
    diff_rows = stratified(pairs, lambda k: (naive[k].get("difficulty") or "unknown"), harness)
    diff_rows.sort(key=lambda r: ["foundational", "intermediate", "advanced"].index(r["group"])
                   if r["group"] in ("foundational", "intermediate", "advanced") else 9)
    sections: list[tuple[str, str]] = [
        ("Configuration differences between the two runs", config_differences(naive_runs, full_runs)),
        ("Full-pipeline-only stages", full_only_descriptives(full_runs)),
        ("Failure stage (not paired-tested)",
         "`failure_stage` is where each condition's cell ended. B0's `(none)` means it reached a "
         "valid finite trace; FULL's `(none)` means it completed behaviour evaluation with every "
         "property passing, a strictly harder endpoint, so the two `(none)` rows are not "
         "comparable.\n\n" + stage_tbl),
        ("By difficulty", strat_table(diff_rows, which)),
    ]
    fam_rows: list[dict] = []
    if families:
        fam_rows = stratified(pairs, lambda k: families.get(k[0], "unknown"), harness)
        sections.append(("By robot family", strat_table(fam_rows, which)))

    header = [
        f"- Naive: `{naive_root}` — condition `{args.naive_condition}`, {len(naive)} cells",
        f"- Full: `{full_root}` — condition `{args.full_condition}`, {len(full)} cells",
        f"- Paired on (task, variant, repetition): **{len(keys)}**; infrastructure exclusions "
        f"{len(excluded)} (naive {len(excl_naive)}, full {len(excl_full)}); analysed **{len(pairs)}**",
        f"- Repetitions per task among analysed pairs: {dict(sorted(reps.items(), key=lambda kv: str(kv[0])))}"
        + (" — repeats of one task are not independent; treat n as an upper bound on the "
           "effective sample size." if len(reps) > 1 else ""),
        "- Intent-to-treat: a cell that never reached a stage counts as a failure of that stage "
        "and of everything downstream.",
    ] + [f"- Metric `{d}` is identical to `{k}` cell for cell on this data, so it is not tested "
         "separately (it would only inflate the multiple-comparison family)."
         for d, k in dropped]
    out_dir = Path(args.out_dir)
    written = report.write_outputs(
        out_dir, title=title, header_lines=header, results=results, extra_sections=sections,
        meta={"naive_root": str(naive_root), "full_root": str(full_root),
              "n_paired": len(keys), "n_analysed": len(pairs), "n_excluded": len(excluded),
              "excluded_naive": [list(k) for k in excl_naive],
              "excluded_full": [list(k) for k in excl_full]},
        plots=not args.no_plots, metrics=metrics)
    if fam_rows and not args.no_plots:
        p = family_delta_plot(fam_rows, which[-1], out_dir)
        if p:
            written["by_family"] = p
    print()
    for kind, path in written.items():
        print(f"wrote {kind}: {path}")


if __name__ == "__main__":
    main()
