#!/usr/bin/env python3
"""Paired analysis of the robotics Modelica ablation ladder, on the same shared driver
and statistics as the Solidity and SysML ablation analyses (`analysis/ablation.py`).

Study layout (one `run.json` per cell), the same as the naive-vs-full corpora:

    <root>/<task_id>/<variant>/<arm>/repeat-NN/run.json      + <root>/study-protocol.json

    A0  direct GLM-5.2 one-shot (no RAG, no MoE, no repair)
    A1  + RAG
    A2  + mixture of experts
    A3  + compiler-guided repair
    A4  + execution-guided repair

The arms and their labels are read from `study-protocol.json`, so an extended study needs
no code change. There is no alignment or validated-contract stage in this ladder (both are
false for every arm), so the ladder stops short of the FULL pipeline.

Two families of paired comparisons, each with the full treatment of the other ablation
analyses (McNemar / Cohen's h, Holm, power, failure-stage and by-group tables, plots):

    step        A(k-1) -> A(k)   what does stage k add on its own?
    cumulative  A0     -> A(k)   what has the pipeline bought over the direct baseline?

What can be measured
    The per-cell `run.json` carries no model text and no diagnostic counts, so the always-on
    metrics are the two Modelica-compile rates below. FMU export / execution / valid-trace
    rates are added automatically once any cell reaches those stages; until then they are
    shown only in the stage funnel (a metric that is 0 in every arm has no discordant pairs
    and would only inflate the Holm family). The summary's "data limitations" section is
    computed from the funnel, so it stays correct if the study is rerun.

    Modelica compiles (final)                after any repair the arm allows
    Modelica compiles before repair (attempt 0)   first generation, before repair

Protocol (from `study-protocol.json`)
    * A cell is analysed only if the harness marked it eligible. Infrastructure failures
      and condition-fidelity failures are excluded, and a pair drops out of any comparison
      where either side is missing.
    * Intent-to-treat: a cell that never reached a stage counts as a failure of that stage
      and everything downstream. Cells that fail requirement normalisation do so
      identically in every arm.

Reads ONLY `run.json` / `study-protocol.json`; no OpenModelica, FMU or LLM calls, so it runs
in seconds on a laptop or on PACE alike.

Usage
    python nl2robotics/modelica/analyze_ablation.py
    python nl2robotics/modelica/analyze_ablation.py --root <study dir> --mode step --no-plots
    python nl2robotics/modelica/analyze_ablation.py --compare A0:A3 --compare A3:A4
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Callable, Optional

_HERE = Path(__file__).resolve().parent
_ROBOTICS = _HERE.parent
_ROOT = _ROBOTICS.parent
sys.path.insert(0, str(_ROOT))

from analysis import ablation  # noqa: E402
from analysis import paired_stats as ps  # noqa: E402
from analysis import report  # noqa: E402

DEFAULT_ROOT = _ROBOTICS / "glm52-ablation-corpus-v2"
DEFAULT_OUT = _ROBOTICS / "analysis_results" / "modelica_ablation"

# Readable arm descriptions keyed by the protocol's condition label.
DESCRIPTIONS = {
    "direct_frontier": "direct GLM-5.2 (no RAG, MoE or repair)",
    "rag": "+ RAG",
    "rag_moe": "+ MoE",
    "rag_moe_compiler_repair": "+ compiler repair",
    "rag_moe_compiler_execution_repair": "+ execution repair",
}

_EXCLUDED: dict[str, list[tuple[str, str]]] = {}   # arm -> [(cell key, reason)]
_STATE: dict[str, Any] = {"protocol": {}}


# ---- inputs -----------------------------------------------------------------
def find_root(arg: Optional[str]) -> Path:
    base = Path(arg) if arg else DEFAULT_ROOT
    if any(base.glob("*/*/A*/repeat-*/run.json")):
        return base
    sys.exit(f"No Modelica ablation cells (<task>/<variant>/A*/repeat-*/run.json) under {base}.\n"
             "Pass --root <study dir> (e.g. a PACE copy).")


def discover(root: Path) -> dict[str, str]:
    proto_path = root / "study-protocol.json"
    proto = json.loads(proto_path.read_text(encoding="utf-8")) if proto_path.exists() else {}
    _STATE["protocol"] = proto
    _STATE.pop("categories", None)
    labels = {c["id"]: c.get("label") for c in proto.get("conditions", [])}
    arms = sorted({p.parts[-3] for p in root.glob("*/*/A*/repeat-*/run.json")
                   if p.parts[-3][1:].isdigit()}, key=lambda a: int(a[1:]))
    return {a: DESCRIPTIONS.get(labels.get(a) or "", labels.get(a) or a) for a in arms}


def _record(run: dict) -> dict:
    m = run.get("metrics") or {}
    r = run.get("result") or {}
    trace = [(s.get("stage"), bool(s.get("reached")), s.get("passed") is True)
             for s in (r.get("stage_trace") or [])]
    dur = run.get("duration_seconds")
    return {
        "difficulty": run.get("difficulty") or "unknown",
        "build": m.get("modelica_build") is True,
        "build0": m.get("modelica_build_attempt_0") is True,
        "stage": m.get("failure_stage") or "(none)",
        "trace": trace,
        "repairs": m.get("repairs") if isinstance(m.get("repairs"), (int, float)) else None,
        "duration": float(dur) if isinstance(dur, (int, float)) else None,
        "fidelity": m.get("condition_fidelity"),
        "fmu_export": m.get("fmu_export") is True,
        "fmu_exec": m.get("fmu_execution") is True,
        "trace_ok": m.get("stable_simulation") is True,
        "error": r.get("error") if isinstance(r.get("error"), str) else None,
    }


def _exclusion_reason(run: dict) -> Optional[str]:
    m = run.get("metrics") or {}
    validity = (run.get("result") or {}).get("study_validity") or {}
    if run.get("infrastructure_error") or m.get("infrastructure_available") is False:
        return "infrastructure"
    if validity.get("eligible") is False or validity.get("condition_fidelity_passed") is False:
        return "study-validity"
    return None


def load(root: Path, arm: str) -> dict[str, dict]:
    out: dict[str, dict] = {}
    excluded: list[tuple[str, str]] = []
    for path in sorted(root.glob(f"*/*/{arm}/repeat-*/run.json")):
        try:
            run = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as e:
            print(f"  ! unreadable {path}: {e}", file=sys.stderr)
            continue
        found = (run.get("condition") or {}).get("id")
        if found != arm:
            print(f"  ! {path} holds condition {found!r}, expected {arm!r} — skipped", file=sys.stderr)
            continue
        key = f"{run.get('task_id')}/{run.get('variant')}/r{int(run.get('repetition') or 0):02d}"
        reason = _exclusion_reason(run)
        if reason:
            excluded.append((key, reason))
            continue
        rec = _record(run)
        rec["_config"] = run.get("configuration") or {}
        out[key] = rec
    _EXCLUDED[arm] = excluded
    if excluded:
        print(f"  ({arm}: {len(excluded)} excluded: "
              + ", ".join(f"{k} [{why}]" for k, why in excluded) + ")")
    return out


def _category(key: str) -> str:
    task = key.split("/")[0]
    if "categories" not in _STATE:
        _STATE["categories"] = {t["task_id"]: t.get("category") or "unknown"
                                for t in _STATE["protocol"].get("task_prompts", [])}
    return _STATE["categories"].get(task, "unknown")


# ---- metric assembly --------------------------------------------------------
def compiles(m: dict) -> bool:
    return m["build"]


def compiles_at0(m: dict) -> bool:
    return m["build0"]


# Stages after the Modelica compile. They are tested only when some cell reaches them: a
# metric that is 0 in every arm has no discordant pairs and would only inflate the Holm
# family. In the study as first run none did (see the stage funnel), so none appear.
DOWNSTREAM = [
    ("FMU export succeeds", "fmu_export", ""),
    ("FMU executes", "fmu_exec", ""),
    ("Valid finite trace (stable simulation)", "trace_ok", "the last stage the harness scores"),
]


def active_downstream(corpora: list[dict]) -> list[tuple[str, str, str]]:
    return [(n, k, note) for n, k, note in DOWNSTREAM
            if any(r[k] for c in corpora for r in c.values())]


def build_metrics(ref: dict, cmp_: dict, keys: list[str], dedupe: bool = True,
                  downstream: Optional[list] = None) -> list[ps.PairedMetric]:
    """Intent-to-treat: a cell that never produced a compiling model counts as a failure.
    `dedupe` drops the before-repair metric when it is identical, cell for cell, to the
    final one (arms with no compiler repair): a duplicate row would only inflate Holm."""
    M = ps.PairedMetric.from_pairs

    def pairs(get: Callable[[dict], Any]):
        return [(k, get(ref[k]), get(cmp_[k])) for k in keys]

    final = M("Modelica compiles (final)", "proportion", pairs(compiles),
              note="after any repair the arm allows")
    at0 = M("Modelica compiles before repair (attempt 0)", "proportion", pairs(compiles_at0),
            note="first generation, before any compiler repair: the cleanest generation-only metric")
    out = [final]
    if not (dedupe and (at0.naive, at0.full) == (final.naive, final.full)):
        out.append(at0)
    if downstream is None:
        downstream = active_downstream([{k: ref[k] for k in keys}, {k: cmp_[k] for k in keys}])
    for name, key, note in downstream:
        out.append(M(name, "proportion", pairs(lambda r, _k=key: r[_k]), note=note))
    return out


# ---- tables -----------------------------------------------------------------
def _pct(n: int, d: int, decimals: int = 1) -> str:
    return f"{n / d * 100:.{decimals}f}%" if d else "n/a"


def stage_table(corpora: dict[str, dict], arms: list[str], keys: list[str]) -> str:
    counts = {a: Counter(corpora[a][k]["stage"] for k in keys) for a in arms}
    stages = sorted({s for a in arms for s in counts[a]},
                    key=lambda s: -sum(counts[a][s] for a in arms))
    n = len(keys)
    return report.table_md(
        ["failure_stage (where the cell ended)"] + arms,
        [[s] + [f"{counts[a][s]} ({_pct(counts[a][s], n)})" for a in arms] for s in stages])


def funnel_counts(corpora: dict[str, dict], arms: list[str], keys: list[str]):
    """({arm: {stage: (reached, passed)}}, stage order).

    Reachability is recomputed here, not read from the trace: the harness stamps every
    stage after the first failure as reached-and-failed (a cell that failed Modelica
    validation shows `modelica_identity` as failed, though the identity check never ran).
    A cell reached stage i only if every earlier stage passed."""
    order: list[str] = []
    out: dict[str, dict[str, tuple[int, int]]] = {}
    for a in arms:
        reached: Counter = Counter()
        passed: Counter = Counter()
        for k in keys:
            alive = True
            if not corpora[a][k]["trace"] and corpora[a][k]["stage"] != "(none)":
                # A cell that failed before any trace was written (requirement normalisation)
                # carries only its failure_stage: it reached that stage and failed it.
                stage = corpora[a][k]["stage"]
                if stage not in order:
                    order.insert(0, stage)
                reached[stage] += 1
                continue
            for stage, _, ok in corpora[a][k]["trace"]:
                if stage not in order:
                    order.append(stage)
                if alive:
                    reached[stage] += 1
                    passed[stage] += ok
                    alive = ok
        out[a] = {s: (reached[s], passed[s]) for s in reached}
    return out, order


def funnel_table(corpora: dict[str, dict], arms: list[str], keys: list[str]) -> str:
    """Cells reaching, and passing, each pipeline stage. Shows exactly where an arm's
    cells stop, including stages no cell ever reached."""
    counts, order = funnel_counts(corpora, arms, keys)
    rows = [[f"`{stage}`"] + ["{} / {}".format(counts[a].get(stage, (0, 0))[1],
                                                counts[a].get(stage, (0, 0))[0]) for a in arms]
            for stage in order]
    return (f"Each cell is **passed / reached** out of {len(keys)} cells; a cell reaches a stage "
            "only if every earlier stage passed.\n\n"
            + report.table_md(["Stage"] + arms, rows))


def _by_group(ref: dict, cmp_: dict, keys: list[str], group: Callable[[str], str],
              labels: tuple[str, str], title: str) -> str:
    a_lab, b_lab = labels
    groups: dict[str, list[str]] = defaultdict(list)
    for k in keys:
        groups[group(k)].append(k)
    rows = []
    for g, m in sorted(groups.items(), key=lambda kv: -len(kv[1])):
        n = len(m)
        rows.append([g, n,
                     _pct(sum(ref[k]["build"] for k in m), n, 0), _pct(sum(cmp_[k]["build"] for k in m), n, 0),
                     _pct(sum(ref[k]["build0"] for k in m), n, 0), _pct(sum(cmp_[k]["build0"] for k in m), n, 0)])
    return report.table_md(
        [title, "n", f"Compiles {a_lab}", f"Compiles {b_lab}",
         f"Attempt-0 {a_lab}", f"Attempt-0 {b_lab}"], rows)


def pair_sections(ref_arm: str, cmp_arm: str, ref: dict, cmp_: dict, keys: list[str]):
    labels = (ref_arm, cmp_arm)
    return [("Failure stage (not paired-tested)",
             stage_table({ref_arm: ref, cmp_arm: cmp_}, [ref_arm, cmp_arm], keys)),
            ("By task category", _by_group(ref, cmp_, keys, _category, labels, "Category")),
            ("By difficulty", _by_group(ref, cmp_, keys, lambda k: (ref[k]["difficulty"]),
                                        labels, "Difficulty"))]


# ---- ladder -----------------------------------------------------------------
def ladder_context(corpora: dict[str, dict], arms: list[str], common: list[str]) -> dict:
    return {"_downstream": active_downstream([corpora[a] for a in arms])}


def ladder_metrics(corpus: dict, common: list[str], ctx: dict):
    # (arm, arm) pairing: the "naive" side of each PairedMetric is this arm's value.
    return build_metrics(corpus, corpus, common, dedupe=False, downstream=ctx["_downstream"])


def ladder_note(ctx: dict) -> str:
    return ", so every column is scored on the same cells."


def cost_table(corpora: dict[str, dict], arms: list[str], keys: list[str]) -> str:
    rows = []
    for a in arms:
        recs = [corpora[a][k] for k in keys]
        dur = [r["duration"] for r in recs if r["duration"] is not None]
        reps = [r["repairs"] for r in recs if r["repairs"] is not None]
        failed0 = [r for r in recs if not r["build0"]]
        rescued = sum(1 for r in failed0 if r["build"])
        rows.append([a, f"{sum(dur) / len(dur):.0f}" if dur else "n/a",
                     f"{sum(reps) / len(reps):.2f}" if reps else "n/a",
                     f"{rescued} / {len(failed0)}"])
    return report.table_md(
        ["Arm", "Wall-clock s / cell", "Repairs used / cell (cells that reached generation)",
         "Attempt-0 failures repaired to valid"], rows)


def category_ladder(corpora: dict[str, dict], arms: list[str], keys: list[str]) -> str:
    groups: dict[str, list[str]] = defaultdict(list)
    for k in keys:
        groups[_category(k)].append(k)
    rows = [[g, len(m)] + [_pct(sum(corpora[a][k]["build"] for k in m), len(m), 0) for a in arms]
            for g, m in sorted(groups.items(), key=lambda kv: -len(kv[1]))]
    return report.table_md(["Category", "n"] + arms, rows)


def coverage(root: Path, corpora: dict[str, dict], arms: list[str]) -> str:
    proto = _STATE["protocol"]
    planned = Counter(c["condition_id"] for c in proto.get("planned_cells", []))
    rows = []
    for a in arms:
        n = len(corpora[a])
        exc = _EXCLUDED.get(a, [])
        rows.append([a, f"{n}" + (f" / {planned[a]} ({_pct(n, planned[a], 0)})" if planned.get(a) else ""),
                     len(exc), ", ".join(f"{k} [{w}]" for k, w in exc) or "—"])
    tbl = report.table_md(["Arm", "Eligible cells completed", "Excluded", "Which"], rows)

    # representativeness: does the completed subset look like the planned corpus?
    cats_all = Counter(t.get("category") or "unknown" for t in proto.get("task_prompts", []))
    done = Counter(_category(k) for k in corpora[arms[0]])
    cat_rows = []
    for c, tot in sorted(cats_all.items(), key=lambda kv: -kv[1]):
        d = done.get(c, 0)
        cat_rows.append([c, tot, d, _pct(tot, sum(cats_all.values())), _pct(d, sum(done.values()))])
    cat_tbl = report.table_md(["Category", "Planned tasks", f"Done ({arms[0]})", "Share of plan",
                               "Share of done"], cat_rows) if cats_all else ""

    # configuration consistency across arms
    ignore = {"benchmark_manifest", "benchmark_manifest_sha256"}
    diffs: list[str] = []
    per_arm = {a: next(iter(corpora[a].values()))["_config"] for a in arms if corpora[a]}
    keys = sorted(set().union(*[set(c) for c in per_arm.values()]) - ignore)
    for k in keys:
        vals = {a: json.dumps(c.get(k), sort_keys=True) for a, c in per_arm.items()}
        if len(set(vals.values())) > 1:
            diffs.append(f"`{k}`: " + "; ".join(f"{a}={v[:40]}" for a, v in vals.items()))
    cfg = ("**Configuration check:** every arm ran with identical settings (models, backends, "
           "repair budgets, seed and protocol hash)." if not diffs else
           "**Configuration check: MISMATCH** — " + " | ".join(diffs) + ". Potential confounds.")
    fid = Counter(r["fidelity"] for a in arms for r in corpora[a].values())
    reached = fid.get(True, 0) + fid.get(False, 0)
    fid_line = (f"Condition fidelity (the harness's check that each cell ran the stages its arm "
                f"specifies) holds for {fid.get(True, 0)} of the {reached} cells that reached "
                f"generation; the other {fid.get(None, 0)} cells failed requirement normalisation "
                f"first, so it was never checked.")
    rep_note = ("The two right-hand columns are a representativeness check: the completed cells "
                "should share the planned corpus's category mix.") if cat_tbl else ""
    return "\n\n".join(x for x in (tbl, cat_tbl, rep_note, fid_line, cfg) if x)


def limitations(corpora: dict[str, dict], arms: list[str], keys: list[str]) -> str:
    """What the data cannot support, computed from the funnel rather than asserted."""
    counts, order = funnel_counts(corpora, arms, keys)
    reached = {st: sum(counts[a].get(st, (0, 0))[0] for a in arms) for st in order}
    passed = {st: sum(counts[a].get(st, (0, 0))[1] for a in arms) for st in order}
    lines = []
    unreached = [s for s in order if reached[s] == 0]
    blocked = [s for s in order if reached[s] > 0 and passed[s] == 0]
    if blocked:
        errs = Counter()
        for a in arms:
            for k in keys:
                if corpora[a][k]["stage"] in blocked and corpora[a][k]["error"]:
                    errs[re.sub(r"'[^']*'", "'…'", corpora[a][k]["error"])] += 1
        msg = f" Typical error: “{errs.most_common(1)[0][0]}” ({errs.most_common(1)[0][1]} cells)." if errs else ""
        lines.append("**Blocked gate:** no cell in any arm passed " + ", ".join(f"`{s}`" for s in blocked)
                     + f" (of {sum(reached[s] for s in blocked)} that reached "
                     + ("it" if len(blocked) == 1 else "them") + ")." + msg)
    if unreached:
        lines.append("**Never reached, in any arm:** " + ", ".join(f"`{s}`" for s in unreached)
                     + ". None of these can be compared, so only earlier stages are tested.")
    exec_stages = {"runtime_initialization", "runtime_execution", "behavior_evaluation"}
    if any(s in unreached for s in exec_stages) and "A4" in arms and "A3" in arms:
        lines.append("**Consequence for A3→A4:** execution repair acts only on cells that reach "
                     "execution, and none did, so any A3/A4 difference is generation noise "
                     "(the before-repair rows make it visible).")
    return "\n\n".join(lines) if lines else (
        "Every pipeline stage was reached by at least one cell and passed by at least one.")


def ladder_sections(root: Path, corpora: dict[str, dict], arms: list[str], common: list[str]):
    return [("Data limitations (computed from the stage funnel)", limitations(corpora, arms, common)),
            ("Stage funnel: where cells stop", funnel_table(corpora, arms, common)),
            ("Failure stage", stage_table(corpora, arms, common)),
            ("Repair activity and cost (mean per cell)", cost_table(corpora, arms, common)),
            ("Compiles by task category", category_ladder(corpora, arms, common)),
            ("Coverage and protocol", coverage(root, corpora, arms))]


STUDY = ablation.Study(
    domain="Modelica",
    doc=__doc__,
    default_out=DEFAULT_OUT,
    unit="cells",
    key_name="cell",
    source_desc="the cached per-cell `run.json`",
    cumulative_note=("Each column pairs an arm with {first}, the direct one-shot baseline (it still "
                     "goes through requirement normalisation and interface planning). "
                     "{first}→{last} is the cumulative effect of every generation and repair stage "
                     "in this study; the study omits the validated contract and spec alignment "
                     "that the FULL condition adds. {first}→{second} is already in the step table."),
    notes=[
        "Only stages that some cell reached can be compared. The stage funnel and the computed "
        "data-limitations section list any stage no cell reached or passed; those are not "
        "tested, because a metric that is 0 in every arm has no discordant pairs.",
        "Cells that fail requirement normalisation do so identically in every arm, so they "
        "dilute every rate equally (intent-to-treat) and never contribute a discordant pair.",
        "Later arms repair against the checker that scores them (A3 against the Modelica "
        "compiler), so the gain on compile validity is expected by construction; the "
        "before-repair row isolates generation quality, and A3/A4 regenerate independently of "
        "A2, so their before-repair rows also show generation noise.",
    ],
    find_root=find_root,
    discover=discover,
    load=load,
    build_metrics=build_metrics,
    pair_sections=pair_sections,
    ladder_context=ladder_context,
    ladder_metrics=ladder_metrics,
    ladder_note=ladder_note,
    ladder_sections=ladder_sections,
)


if __name__ == "__main__":
    ablation.main(STUDY)
