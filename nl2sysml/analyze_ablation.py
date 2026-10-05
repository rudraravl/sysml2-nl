#!/usr/bin/env python3
"""Paired analysis of the SysML ablation ladder, on the SysML counterparts of the
metrics used by the Solidity ablation analysis and by the naive-vs-full notebook
(`nl2sysml/comparison_results.ipynb`).

The ladder (from `protocol.json`; arms are discovered from the data, so a finished
or extended study needs no code change):

    A1  GLM-5.2 + retrieval           (lowest rung measured: there is no one-shot arm)
    A2  + mixture of experts
    A3  + compiler-guided repair
    A4  + execution-guided (kernel) repair

Two families of paired comparisons are run, both with the full paired-test
treatment of the naive-vs-full analyses (McNemar / Cohen's h for rates, Wilcoxon /
d_z for counts, Holm, power, failure-stage and by-domain tables, plots):

    step        A(k-1) -> A(k)   what does stage k add on its own?
    cumulative  A1     -> A(k)   what has the pipeline bought over retrieval alone?

Metrics (all from the per-task `run.json` / `artifacts/` the harness wrote; the
SysML compiler, the OMG Jupyter kernel and the LLM are NOT called, so it runs in
seconds on a laptop or on PACE alike)

    Compiler-valid (final)                 SysML v2 compiler, after any repair the arm allows
    Compiler-valid before repair (attempt 0)   first generation, before repair
    Syntax-clean / Semantic-clean          no syntax / no semantic compiler errors
    Kernel execution pass                  OMG SysML Jupyter kernel, no ERROR diagnostics
    End-to-end pass                        compiler-valid AND kernel pass
    Compiler errors / Kernel errors        per task (lower is better)
    Std-rule compliance rate               25 Standard Modeling Rules (std_rules.py),
                                           static, over final.sysml; no arm repairs against it

Scope: this is a standalone analysis of the ablation arms. It is NOT compared with the
full-pipeline (`dataset/with_kernel_spec`) or naive (`dataset/naive_glm`) corpora. The
rich-500 study reuses those corpora's long descriptions for its 500 tasks, but it is a
separate run under its own protocol (2 compiler + 2 execution repairs, no specification
alignment), so a pairing would confound the run with the pipeline stage.

Not available here: spec-alignment similarity. The ablation harness ran with
specification_alignment = false, so there is nothing to pair.

Protocol
    * A task is analysed for an arm only if the harness marked it eligible. Cells
      lost to infrastructure interruptions (e.g. an exhausted API credit) are
      excluded, and a pair drops out of any comparison where either side is missing,
      per the study protocol. Each comparison uses only the tasks both arms completed.
    * Intent-to-treat: a task where the model produced nothing counts as a failure
      for every rate and as 0 for std-rule compliance; it has no error count.

Layout under --root:    <root>/A1/tasks/<task>/run.json ... (or a directory up to two
                        levels above it, e.g. dataset/sysml-ablation/outputs/<study>)
Default --root:         dataset/sysml-ablation

Usage
    python nl2sysml/analyze_ablation.py
    python nl2sysml/analyze_ablation.py --root <study dir, or dir holding it>
    python nl2sysml/analyze_ablation.py --mode step --no-plots
    python nl2sysml/analyze_ablation.py --compare A1:A3 --compare A3:A4
"""

from __future__ import annotations

import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Callable, Optional

_NL2 = Path(__file__).resolve().parent
_ROOT = _NL2.parent
sys.path.insert(0, str(_ROOT))
sys.path.insert(0, str(_NL2))            # std_rules lives beside this file

from analysis import ablation  # noqa: E402
from analysis import paired_stats as ps  # noqa: E402
from analysis import report  # noqa: E402
import std_rules  # noqa: E402

DEFAULT_ROOT = _ROOT / "dataset" / "sysml-ablation"
DEFAULT_OUT = _ROOT / "dataset" / "analysis_results" / "sysml_ablation"

# failure_stage as the harness writes it -> readable outcome, in funnel order.
STAGES = [("model_generation", "no model produced"),
          ("compiler_evaluation", "fails compiler"),
          ("kernel_execution", "compiles, kernel execution fails"),
          (None, "passes compiler and kernel")]

# Fields that must match across arms for the ladder to be a fair comparison. The
# condition and the hash that folds it in are the intended differences.
EXPECTED_DIFFERENCES = {"condition", "protocol_core_sha256"}

_EXCLUDED: dict[str, list[str]] = {}     # arm -> infrastructure-excluded task ids
_PROTOCOL: dict[str, dict] = {}          # arm -> protocol.json


# ---- inputs -----------------------------------------------------------------
def _has_arms(d: Path) -> bool:
    return d.is_dir() and any(d.glob("A*/tasks/*/run.json"))


def find_root(arg: Optional[str]) -> Path:
    base = Path(arg) if arg else DEFAULT_ROOT
    if _has_arms(base):
        return base
    for pattern in ("*", "*/*"):         # <base>/<study> or <base>/outputs/<study>
        studies = sorted(p for p in base.glob(pattern) if _has_arms(p))
        if studies:
            return studies[-1]           # newest timestamped study directory
    sys.exit(f"No SysML ablation arms (A*/tasks/*/run.json) found under {base}.\n"
             "Pass --root <study dir, or the dir holding it> (e.g. a PACE copy).")


def discover(root: Path) -> dict[str, str]:
    arms = sorted((p.name for p in root.glob("A*") if p.name[1:].isdigit()
                   and any((p / "tasks").glob("*/run.json"))), key=lambda a: int(a[1:]))
    out = {}
    for a in arms:
        proto = root / a / "protocol.json"
        _PROTOCOL[a] = json.loads(proto.read_text(encoding="utf-8")) if proto.exists() else {}
        out[a] = (_PROTOCOL[a].get("condition") or {}).get("label") or a
    return out


def _load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def _rules_score(text: str) -> float:
    """Fraction of applicable Standard Modeling Rules passed (0 when none apply)."""
    res = std_rules.check(text)
    ok = sum(1 for v in res.values() if v == "pass")
    app = ok + sum(1 for v in res.values() if v == "fail")
    return ok / app if app else 0.0


def _record(run: dict, task_dir: Path) -> dict:
    r = run.get("result") or {}
    comp = r.get("compiler") if isinstance(r.get("compiler"), dict) else None
    ex = r.get("execution") if isinstance(r.get("execution"), dict) else None
    produced = comp is not None
    c0 = None
    if produced:
        attempts = (_load_json(task_dir / "artifacts" / "compiler-attempts.json") or {}).get("attempts")
        if attempts:
            c0 = bool((attempts[0].get("report") or {}).get("passed"))
    text = ""
    final = task_dir / "artifacts" / "final.sysml"
    if produced and final.exists():
        text = final.read_text(encoding="utf-8")
    cr, er = r.get("compiler_repairs") or {}, r.get("execution_repairs") or {}
    dur = run.get("duration_seconds")
    request = task_dir / "artifacts" / "request.txt"
    words = len(request.read_text(encoding="utf-8").split()) if request.exists() else None
    return {
        "domain": run.get("domain") or "unknown",
        "produced": produced,
        "stage": r.get("failure_stage"),
        "passed": bool(r.get("passed")),
        "compiler": comp,
        "c0": c0 if c0 is not None else (bool(comp.get("passed")) if comp else None),
        "kernel": ex,
        "rules": _rules_score(text) if text.strip() else 0.0,
        "duration": float(dur) if isinstance(dur, (int, float)) else None,
        "prompt_words": words,
        "c_rep": (cr.get("attempted") or 0, cr.get("accepted") or 0),
        "e_rep": (er.get("attempted") or 0, er.get("accepted") or 0),
    }


def load(root: Path, arm: str) -> dict[str, dict]:
    out: dict[str, dict] = {}
    excluded: list[str] = []
    for path in sorted((root / arm / "tasks").glob("*/run.json")):
        run = _load_json(path)
        if not isinstance(run, dict):
            print(f"  ! unreadable {path}", file=sys.stderr)
            continue
        if run.get("eligible") is False or run.get("infrastructure_error"):
            excluded.append(path.parent.name)      # infrastructure, not a model outcome
            continue
        out[path.parent.name] = _record(run, path.parent)
    _EXCLUDED[arm] = excluded
    if excluded:
        print(f"  ({arm}: {len(excluded)} infrastructure-excluded: {', '.join(excluded)})")
    return out


# ---- per-task accessors (None = metric unavailable for this task) -----------
def compiler_valid(m: dict) -> Optional[bool]:
    return bool(m["compiler"].get("passed")) if m["compiler"] else False


def compiler_valid_at0(m: dict) -> Optional[bool]:
    return bool(m["c0"]) if m["c0"] is not None else False


def syntax_clean(m: dict) -> Optional[bool]:
    return m["compiler"].get("syntax_error_count") == 0 if m["compiler"] else False


def semantic_clean(m: dict) -> Optional[bool]:
    return m["compiler"].get("semantic_error_count") == 0 if m["compiler"] else False


def kernel_pass(m: dict) -> Optional[bool]:
    return bool(m["kernel"].get("success")) if m["kernel"] else False


def end_to_end(m: dict) -> Optional[bool]:
    return m["passed"]


def compiler_errors(m: dict) -> Optional[float]:
    return float(m["compiler"]["error_count"]) if m["compiler"] and "error_count" in m["compiler"] else None


def kernel_errors(m: dict) -> Optional[float]:
    return float(m["kernel"]["error_count"]) if m["kernel"] and "error_count" in m["kernel"] else None


def rule_compliance(m: dict) -> Optional[float]:
    return m["rules"]


# ---- metric assembly --------------------------------------------------------
def build_metrics(ref: dict, cmp_: dict, keys: list[str], dedupe: bool = True) -> list[ps.PairedMetric]:
    """Every metric is paired on task id. `dedupe` drops the before-repair metric
    when it is identical, task for task, to the final one (arms with no compiler
    repair), because a duplicate row would only inflate the Holm family."""
    def pairs(get: Callable[[dict], Any]):
        return [(k, get(ref[k]), get(cmp_[k])) for k in keys]

    P, C = "proportion", "continuous"
    M = ps.PairedMetric.from_pairs
    final = M("Compiler-valid (final)", P, pairs(compiler_valid),
              note="SysML v2 compiler, after any repair the arm allows")
    at0 = M("Compiler-valid before repair (attempt 0)", P, pairs(compiler_valid_at0),
            note="first generation, before any compiler repair: the cleanest generation-only metric")
    metrics = [final]
    if not (dedupe and (at0.naive, at0.full) == (final.naive, final.full)):
        metrics.append(at0)
    return metrics + [
        M("Syntax-clean", P, pairs(syntax_clean), note="no syntax errors in the final model"),
        M("Semantic-clean", P, pairs(semantic_clean), note="no semantic errors in the final model"),
        M("Kernel execution pass", P, pairs(kernel_pass),
          note="OMG SysML Jupyter kernel: payload compiled/executed without ERROR diagnostics"),
        M("End-to-end pass (compiler + kernel)", P, pairs(end_to_end),
          note="compiler-valid and kernel pass: the harness's own success criterion"),
        M("Compiler errors per task", C, pairs(compiler_errors), lower_is_better=True,
          note="tasks with no model output have no count"),
        M("Kernel errors per task", C, pairs(kernel_errors), lower_is_better=True,
          note="tasks with no model output have no count"),
        M("Std-rule compliance rate", C, pairs(rule_compliance),
          note="fraction of applicable Standard Modeling Rules passed; no arm repairs against it"),
    ]


# ---- per-comparison extras --------------------------------------------------
def _rate(getter, corpus, members, decimals: int = 0) -> str:
    vals = [v for v in (getter(corpus[k]) for k in members) if v is not None]
    return f"{sum(vals) / len(vals) * 100:.{decimals}f}%" if vals else "n/a"


def stage_table(corpora: dict[str, dict], arms: list[str], keys: list[str]) -> str:
    counts = {a: Counter(corpora[a][k]["stage"] for k in keys) for a in arms}
    n = len(keys)
    return report.table_md(
        ["Outcome (first failing stage)"] + arms,
        [[label] + [f"{counts[a][st]} ({counts[a][st] / n * 100:.1f}%)" for a in arms]
         for st, label in STAGES])


def by_domain(ref: dict, cmp_: dict, keys: list[str], labels: tuple[str, str]) -> str:
    a_lab, b_lab = labels
    groups: dict[str, list[str]] = defaultdict(list)
    for k in keys:
        groups[cmp_[k]["domain"]].append(k)
    rows = [[dom, len(m),
             _rate(compiler_valid, ref, m), _rate(compiler_valid, cmp_, m),
             _rate(kernel_pass, ref, m), _rate(kernel_pass, cmp_, m),
             _rate(end_to_end, ref, m), _rate(end_to_end, cmp_, m)]
            for dom, m in sorted(groups.items(), key=lambda kv: -len(kv[1]))]
    return report.table_md(
        ["Domain", "n", f"Compiler {a_lab}", f"Compiler {b_lab}", f"Kernel {a_lab}", f"Kernel {b_lab}",
         f"End-to-end {a_lab}", f"End-to-end {b_lab}"], rows)


def pair_sections(ref_arm: str, cmp_arm: str, ref: dict, cmp_: dict, keys: list[str]):
    return [("First failing stage", stage_table({ref_arm: ref, cmp_arm: cmp_}, [ref_arm, cmp_arm], keys)),
            ("By domain", by_domain(ref, cmp_, keys, (ref_arm, cmp_arm)))]


# ---- ladder -----------------------------------------------------------------
def ladder_metrics(corpus: dict, common: list[str], ctx: dict):
    # (arm, arm) pairing: the "naive" side of each PairedMetric is this arm's value.
    return build_metrics(corpus, corpus, common, dedupe=False)


def ladder_note(ctx: dict) -> str:
    return ", so every column is scored on the same tasks."


def _mean(vals: list[float]) -> str:
    return f"{sum(vals) / len(vals):.2f}" if vals else "n/a"


def cost_table(corpora: dict[str, dict], arms: list[str], keys: list[str]) -> str:
    rows = []
    for a in arms:
        recs = [corpora[a][k] for k in keys]
        dur = [r["duration"] for r in recs if r["duration"] is not None]
        rows.append([a,
                     f"{sum(dur) / len(dur):.0f}" if dur else "n/a",
                     _mean([r["c_rep"][0] for r in recs]), _mean([r["c_rep"][1] for r in recs]),
                     _mean([r["e_rep"][0] for r in recs]), _mean([r["e_rep"][1] for r in recs])])
    return report.table_md(
        ["Arm", "Wall-clock s / task", "Compiler repairs tried", "…kept",
         "Execution repairs tried", "…kept"], rows)


def domain_ladder(corpora: dict[str, dict], arms: list[str], keys: list[str]) -> str:
    groups: dict[str, list[str]] = defaultdict(list)
    for k in keys:
        groups[corpora[arms[-1]][k]["domain"]].append(k)
    rows = [[dom, len(m)] + [_rate(end_to_end, corpora[a], m) for a in arms]
            for dom, m in sorted(groups.items(), key=lambda kv: -len(kv[1]))]
    return report.table_md(["Domain", "n"] + arms, rows)


def provenance(root: Path, corpora: dict[str, dict], arms: list[str]) -> str:
    expected = next((p.get("prompt_count") for p in _PROTOCOL.values() if p.get("prompt_count")), None)
    first = arms[0]
    base_all = _rate(compiler_valid, corpora[first], list(corpora[first]), 1)
    rows = []
    for a in arms:
        n = len(corpora[a])
        done = f"{n}" + (f" / {expected} ({n / expected * 100:.0f}%)" if expected else "")
        rows.append([a, done, len(_EXCLUDED.get(a, [])),
                     _rate(compiler_valid, corpora[first], [k for k in corpora[a] if k in corpora[first]], 1)])
    tbl = report.table_md(
        ["Arm", "Eligible tasks completed", "Infrastructure-excluded",
         f"{first} compiler-valid on this arm's tasks"], rows)

    diffs = []
    ref_proto = _PROTOCOL.get(first, {})
    for a in arms[1:]:
        for key in sorted((set(ref_proto) | set(_PROTOCOL.get(a, {}))) - EXPECTED_DIFFERENCES):
            if ref_proto.get(key) != _PROTOCOL[a].get(key):
                diffs.append(f"`{key}` differs between {first} and {a}")
    dataset = Path(str(ref_proto.get("dataset") or "unknown")).name
    words = sorted(w for a in arms for w in (r["prompt_words"] for r in corpora[a].values())
                   if w is not None)
    prompt_line = (f"**Prompts:** `{dataset}` (sha256 `{str(ref_proto.get('dataset_sha256'))[:12]}…`), "
                   + (f"median {words[len(words) // 2]} words per prompt (range {words[0]}–{words[-1]}). "
                      if words else "prompt length unavailable. ")
                   + "The ablation is a separate run under its own protocol, so absolute rates here "
                   "describe this ablation only and are not paired with the full-pipeline or "
                   "naive-baseline corpora.")
    proto_line = ("**Protocol check:** the protocols of all arms are identical apart from the "
                  "condition under test (same prompts, dataset hash, retrieval corpus, expert and "
                  "combiner models, repair budgets, commit and seed)."
                  if not diffs else "**Protocol check: MISMATCH** — " + "; ".join(diffs) +
                  ". These are potential confounds.")
    return (f"{tbl}\n\n{prompt_line}\n\nThe last column is a representativeness check: it should sit close to "
            f"{first}'s rate on all of its tasks ({base_all}). A gap would mean a later arm's "
            f"completed subset is easier or harder than the corpus.\n\n{proto_line}")


def ladder_sections(root: Path, corpora: dict[str, dict], arms: list[str], common: list[str]):
    return [("First failing stage", stage_table(corpora, arms, common)),
            ("End-to-end pass by domain", domain_ladder(corpora, arms, common)),
            ("Cost and repair activity (mean per task)", cost_table(corpora, arms, common)),
            ("Coverage and protocol", provenance(root, corpora, arms))]


STUDY = ablation.Study(
    domain="SysML",
    doc=__doc__,
    default_out=DEFAULT_OUT,
    unit="tasks",
    key_name="task",
    source_desc="the cached per-task `run.json`",
    cumulative_note=("Each column pairs an arm with {first}, the lowest rung measured here. There is "
                     "no one-shot or naive arm in this study, so {first}→{last} is the cumulative "
                     "effect of everything above retrieval, not full-vs-naive; {first}→{second} is "
                     "already in the step table."),
    notes=[
        "Every arm is scored by the same SysML compiler and OMG Jupyter kernel (the protocol "
        "evaluates both for all conditions), so a metric moves between arms only because of the "
        "stage that was added, not because it started being measured.",
        "A3 repairs against the compiler and A4 against the kernel, so gains on those metrics are "
        "expected by construction. The Standard Modeling Rules are checked statically and no arm "
        "repairs against them, which makes that row the most independent signal here.",
        "Intent-to-treat: a task where the model produced nothing counts as a failure for every "
        "rate and as 0 for std-rule compliance, and has no error count. Infrastructure-excluded "
        "tasks are dropped from every pair they touch.",
        "The compiler and the kernel are different engines: a task can pass the kernel while the "
        "compiler rejects it. `End-to-end pass` requires both, as in the harness.",
        "This ablation is analysed on its own: it is deliberately not paired with the "
        "full-pipeline or naive corpora, which come from separate runs under different "
        "protocols (the ablation caps repair at 2 compiler + 2 execution rounds and disables "
        "specification alignment).",
        "Spec-alignment similarity is not reported: the ablation harness ran with "
        "`specification_alignment = false`. Arms are compared on the tasks both sides "
        "completed; the coverage table shows whether those subsets are representative.",
    ],
    find_root=find_root,
    discover=discover,
    load=load,
    build_metrics=build_metrics,
    pair_sections=pair_sections,
    ladder_metrics=ladder_metrics,
    ladder_note=ladder_note,
    ladder_sections=ladder_sections,
)


if __name__ == "__main__":
    ablation.main(STUDY)
