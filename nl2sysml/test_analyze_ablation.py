"""Tests for the SysML ablation analysis: the rules that would silently corrupt a
result if wrong (exclusions, intent-to-treat, pairing, duplicate-row dropping)."""

import argparse
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import analyze_ablation as aa  # noqa: E402
from analysis import ablation  # noqa: E402


def _write_task(root: Path, arm: str, tid: str, *, passed=False, comp_ok=False, kernel_ok=False,
                errors=3, stage="compiler_evaluation", eligible=True, produced=True,
                attempt0_ok=None, sysml="package P { part def A; }"):
    d = root / arm / "tasks" / tid
    (d / "artifacts").mkdir(parents=True)
    result = {"failure_stage": stage, "passed": passed}
    if produced:
        result.update(
            compiler={"passed": comp_ok, "error_count": 0 if comp_ok else errors,
                      "syntax_error_count": 0, "semantic_error_count": 0 if comp_ok else errors},
            execution={"success": kernel_ok, "error_count": 0 if kernel_ok else 1},
            compiler_repairs={"attempted": 0, "accepted": 0},
            execution_repairs={"attempted": 0, "accepted": 0})
        a0 = comp_ok if attempt0_ok is None else attempt0_ok
        (d / "artifacts" / "compiler-attempts.json").write_text(
            json.dumps({"attempts": [{"attempt": 0, "report": {"passed": a0}}]}))
        (d / "artifacts" / "final.sysml").write_text(sysml)
    (d / "run.json").write_text(json.dumps({
        "task_id": tid, "domain": "energy", "eligible": eligible,
        "infrastructure_error": None if eligible else "HTTP 402", "duration_seconds": 5.0,
        "result": result if eligible else {}}))


@pytest.fixture
def study(tmp_path):
    # T1: A1 fails, A2 passes.   T2: identical.   T3: no model output in A1.
    # T4: infrastructure-excluded in A2 only.    T5: only in A1 (A2 not reached).
    _write_task(tmp_path, "A1", "T1")
    _write_task(tmp_path, "A2", "T1", passed=True, comp_ok=True, kernel_ok=True, stage=None)
    _write_task(tmp_path, "A1", "T2")
    _write_task(tmp_path, "A2", "T2")
    _write_task(tmp_path, "A1", "T3", produced=False, stage="model_generation")
    _write_task(tmp_path, "A2", "T3")
    _write_task(tmp_path, "A1", "T4")
    _write_task(tmp_path, "A2", "T4", eligible=False)
    _write_task(tmp_path, "A1", "T5")
    return tmp_path


def _corpora(root):
    aa._PROTOCOL.clear()
    descs = aa.discover(root)
    return descs, {a: aa.load(root, a) for a in descs}


def test_infrastructure_excluded_cells_are_dropped_and_recorded(study):
    _, c = _corpora(study)
    assert "T4" not in c["A2"] and "T4" in c["A1"]
    assert aa._EXCLUDED["A2"] == ["T4"]
    assert aa._EXCLUDED["A1"] == []


def test_pairs_use_only_tasks_both_arms_completed(study):
    _, c = _corpora(study)
    ms = aa.build_metrics(c["A1"], c["A2"], sorted(set(c["A1"]) & set(c["A2"])))
    assert set(ms[0].ids) == {"T1", "T2", "T3"}          # T4 excluded in A2, T5 not in A2


def test_intent_to_treat_no_output_is_failure_not_missing_for_rates(study):
    _, c = _corpora(study)
    t3 = c["A1"]["T3"]
    assert aa.compiler_valid(t3) is False and aa.kernel_pass(t3) is False
    assert aa.syntax_clean(t3) is False and aa.end_to_end(t3) is False
    assert aa.rule_compliance(t3) == 0.0
    assert aa.compiler_errors(t3) is None and aa.kernel_errors(t3) is None


def test_error_count_pairs_drop_a_task_with_no_output(study):
    _, c = _corpora(study)
    ms = {m.name: m for m in aa.build_metrics(c["A1"], c["A2"], ["T1", "T2", "T3"])}
    assert set(ms["Compiler errors per task"].ids) == {"T1", "T2"}
    assert set(ms["Compiler-valid (final)"].ids) == {"T1", "T2", "T3"}


def test_before_repair_row_dropped_when_identical_to_final_and_kept_for_ladder(study):
    _, c = _corpora(study)
    keys = ["T1", "T2"]
    names = [m.name for m in aa.build_metrics(c["A1"], c["A2"], keys)]
    assert "Compiler-valid before repair (attempt 0)" not in names
    names = [m.name for m in aa.build_metrics(c["A1"], c["A2"], keys, dedupe=False)]
    assert "Compiler-valid before repair (attempt 0)" in names


def test_before_repair_row_kept_when_repair_changed_the_outcome(tmp_path):
    _write_task(tmp_path, "A1", "T1")
    _write_task(tmp_path, "A2", "T1", comp_ok=True, attempt0_ok=False)   # repaired into validity
    _, c = _corpora(tmp_path)
    ms = {m.name: m for m in aa.build_metrics(c["A1"], c["A2"], ["T1"])}
    assert ms["Compiler-valid (final)"].full == [True]
    assert ms["Compiler-valid before repair (attempt 0)"].full == [False]


def test_root_may_be_the_study_dir_or_its_parent(study, tmp_path_factory):
    parent = tmp_path_factory.mktemp("parent")
    (parent / "sysml-ablation-20260101").symlink_to(study)
    assert aa.find_root(str(study)) == study
    assert aa.find_root(str(parent)) == parent / "sysml-ablation-20260101"


def _args(**kw):
    return argparse.Namespace(**{"compare": None, "mode": "both", **kw})


def test_comparison_selection():
    arms = ["A1", "A2", "A3", "A4"]
    both = ablation.parse_comparisons(_args(), arms)
    assert both == [("A1", "A2"), ("A2", "A3"), ("A3", "A4"), ("A1", "A3"), ("A1", "A4")]  # A1->A2 once
    assert ablation.parse_comparisons(_args(mode="step"), arms) == [("A1", "A2"), ("A2", "A3"), ("A3", "A4")]
    assert ablation.parse_comparisons(_args(mode="cumulative"), arms) == [("A1", "A2"), ("A1", "A3"), ("A1", "A4")]
    assert ablation.parse_comparisons(_args(compare=["A2:A4"]), arms) == [("A2", "A4")]
    with pytest.raises(SystemExit):
        ablation.parse_comparisons(_args(compare=["A1:A9"]), arms)
    with pytest.raises(SystemExit):
        ablation.parse_comparisons(_args(compare=["A2:A2"]), arms)


def test_stage_table_counts_every_task_once(study):
    _, c = _corpora(study)
    keys = sorted(c["A1"])
    tbl = aa.stage_table({"A1": c["A1"]}, ["A1"], keys)
    assert "no model produced | 1 " in tbl and "fails compiler | 4 " in tbl


def test_prompt_length_recorded_when_request_present_and_tolerated_when_absent(tmp_path):
    _write_task(tmp_path, "A1", "T1")
    (tmp_path / "A1" / "tasks" / "T1" / "artifacts" / "request.txt").write_text("one two three four")
    _write_task(tmp_path, "A1", "T2")                                   # no request.txt
    _, c = _corpora(tmp_path)
    assert c["A1"]["T1"]["prompt_words"] == 4 and c["A1"]["T2"]["prompt_words"] is None
