"""Tests for the Modelica ablation analysis: the rules that would silently corrupt a result
if wrong (exclusions, intent-to-treat, the harness's over-reported stage trace, and metrics
that must appear only when a stage is actually reached)."""

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from nl2robotics.modelica import analyze_ablation as aa  # noqa: E402

STAGES = ["requirement_normalization", "interface_planning", "modelica_validation",
          "modelica_identity", "fmu_export"]


def _trace(passed_upto: int, harness_quirk: bool = True):
    """Stages [0, passed_upto) pass, the next one fails. Like the real harness, every stage
    after the failure is stamped reached-and-failed when `harness_quirk` (up to identity)."""
    out = []
    for i, s in enumerate(STAGES):
        if i < passed_upto:
            out.append({"stage": s, "status": "passed", "reached": True, "passed": True})
        elif i == passed_upto:
            out.append({"stage": s, "status": "failed", "reached": True, "passed": False})
        elif harness_quirk and s == "modelica_identity":
            out.append({"stage": s, "status": "failed", "reached": True, "passed": False})
        else:
            out.append({"stage": s, "status": "not_reached", "reached": False, "passed": None})
    return out


def _cell(root: Path, task: str, arm: str, *, upto=3, build0=None, infra=False,
          eligible=True, cond_id=None, fmu=False, error=None, dur=10.0):
    """upto=3: compiled, failed at identity. upto=2: failed Modelica validation.
    upto=0: failed requirement normalisation."""
    d = root / task / "rich" / arm / "repeat-00"
    d.mkdir(parents=True)
    compiled = upto >= 3
    reached_gen = upto >= 2
    metrics = {
        "modelica_build": compiled if reached_gen else None,
        "modelica_build_attempt_0": (compiled if build0 is None else build0) if reached_gen else None,
        "failure_stage": STAGES[min(upto, len(STAGES) - 1)] if upto < 5 else None,
        "infrastructure_available": not infra, "repairs": 0 if reached_gen else None,
        "condition_fidelity": True if reached_gen else None,
        "fmu_export": True if fmu else None,
    }
    (d / "run.json").write_text(json.dumps({
        "task_id": task, "variant": "rich", "repetition": 0, "difficulty": "easy",
        "condition": {"id": cond_id or arm}, "duration_seconds": dur,
        "infrastructure_error": "boom" if infra else None,
        "metrics": metrics, "configuration": {"model": "glm"},
        "result": {"stage_trace": (_trace(min(upto, 4) if not fmu else 5) if upto > 0 else None),
                   "error": error, "study_validity": {"eligible": eligible}}}))


def _protocol(root: Path, tasks):
    (root / "study-protocol.json").write_text(json.dumps({
        "conditions": [{"id": "A0", "label": "direct_frontier"}, {"id": "A1", "label": "rag"}],
        "planned_cells": [{"condition_id": a, "task_id": t} for a in ("A0", "A1") for t in tasks],
        "task_prompts": [{"task_id": t, "category": "cat_a" if i % 2 else "cat_b"}
                         for i, t in enumerate(tasks)]}))


@pytest.fixture
def study(tmp_path):
    # T1: A0 fails compile, A1 compiles.  T2: both compile.  T3: both fail normalisation.
    # T4: A1 excluded (infrastructure).   T5: eligible=False in A0 (study validity).
    tasks = ["T1", "T2", "T3", "T4", "T5"]
    _protocol(tmp_path, tasks)
    _cell(tmp_path, "T1", "A0", upto=2); _cell(tmp_path, "T1", "A1", upto=3)
    _cell(tmp_path, "T2", "A0", upto=3); _cell(tmp_path, "T2", "A1", upto=3, error=
          "generated top-level model 'Foo' does not match planned name 'RobotTask_T2_R00'")
    _cell(tmp_path, "T3", "A0", upto=0); _cell(tmp_path, "T3", "A1", upto=0)
    _cell(tmp_path, "T4", "A0", upto=3); _cell(tmp_path, "T4", "A1", upto=3, infra=True)
    _cell(tmp_path, "T5", "A0", upto=3, eligible=False); _cell(tmp_path, "T5", "A1", upto=3)
    return tmp_path


def _load(root):
    aa._EXCLUDED.clear()
    descs = aa.discover(root)
    return descs, {a: aa.load(root, a) for a in descs}


def test_arms_and_labels_come_from_the_protocol(study):
    descs, _ = _load(study)
    assert list(descs) == ["A0", "A1"] and descs["A1"] == "+ RAG"


def test_infrastructure_and_study_validity_exclusions_are_dropped_and_recorded(study):
    _, c = _load(study)
    assert "T4/rich/r00" not in c["A1"] and "T5/rich/r00" not in c["A0"]
    assert aa._EXCLUDED["A1"] == [("T4/rich/r00", "infrastructure")]
    assert aa._EXCLUDED["A0"] == [("T5/rich/r00", "study-validity")]


def test_pairs_drop_a_cell_excluded_on_either_side(study):
    _, c = _load(study)
    keys = sorted(set(c["A0"]) & set(c["A1"]))
    assert keys == ["T1/rich/r00", "T2/rich/r00", "T3/rich/r00"]      # T4 and T5 gone


def test_intent_to_treat_cells_that_never_reached_generation_are_failures(study):
    _, c = _load(study)
    t3 = c["A0"]["T3/rich/r00"]
    assert aa.compiles(t3) is False and aa.compiles_at0(t3) is False


def test_before_repair_row_dropped_when_identical_and_kept_when_repair_changed_it(study, tmp_path_factory):
    _, c = _load(study)
    keys = ["T1/rich/r00", "T2/rich/r00", "T3/rich/r00"]
    names = [m.name for m in aa.build_metrics(c["A0"], c["A1"], keys)]
    assert names == ["Modelica compiles (final)"]
    assert len(aa.build_metrics(c["A0"], c["A1"], keys, dedupe=False)) == 2

    root = tmp_path_factory.mktemp("rep")
    _protocol(root, ["T1"])
    _cell(root, "T1", "A0", upto=3, build0=False)                     # repaired into validity
    _cell(root, "T1", "A1", upto=3)
    _, c2 = _load(root)
    names = [m.name for m in aa.build_metrics(c2["A0"], c2["A1"], ["T1/rich/r00"])]
    assert "Modelica compiles before repair (attempt 0)" in names


def test_funnel_recomputes_reachability_instead_of_trusting_the_harness_trace(study):
    """The harness stamps modelica_identity reached+failed even for a cell that failed
    Modelica validation. The funnel must count only cells that passed validation."""
    _, c = _load(study)
    keys = ["T1/rich/r00", "T2/rich/r00", "T3/rich/r00"]
    counts, order = aa.funnel_counts(c, ["A0"], keys)
    # T3 failed normalisation and, like the real harness, has no trace at all: it must still
    # count as having reached (and failed) that stage, or the funnel reads 2/2 instead of 2/3.
    assert counts["A0"]["requirement_normalization"] == (3, 2)
    assert counts["A0"]["modelica_validation"] == (2, 1)              # T1 failed here
    assert counts["A0"]["modelica_identity"] == (1, 0)                # only T2 truly reached it
    assert counts["A0"].get("fmu_export", (0, 0)) == (0, 0)


def test_limitations_are_computed_and_name_the_blocked_gate(study):
    _, c = _load(study)
    keys = ["T1/rich/r00", "T2/rich/r00", "T3/rich/r00"]
    text = aa.limitations(c, ["A0", "A1"], keys)
    assert "no cell in any arm passed `modelica_identity`" in text
    assert "does not match planned name" in text and "`fmu_export`" in text


def test_downstream_metrics_appear_only_once_a_cell_reaches_them(study, tmp_path_factory):
    _, c = _load(study)
    keys = ["T1/rich/r00", "T2/rich/r00", "T3/rich/r00"]
    assert aa.active_downstream([c["A0"], c["A1"]]) == []
    assert "FMU export succeeds" not in [m.name for m in aa.build_metrics(c["A0"], c["A1"], keys)]

    root = tmp_path_factory.mktemp("fixed")
    _protocol(root, ["T1"])
    _cell(root, "T1", "A0", upto=3)
    _cell(root, "T1", "A1", upto=5, fmu=True)
    _, c2 = _load(root)
    ms = {m.name: m for m in aa.build_metrics(c2["A0"], c2["A1"], ["T1/rich/r00"])}
    assert ms["FMU export succeeds"].naive == [False] and ms["FMU export succeeds"].full == [True]


def test_a_cell_holding_the_wrong_condition_is_skipped(tmp_path, capsys):
    _protocol(tmp_path, ["T1"])
    _cell(tmp_path, "T1", "A0", cond_id="A1")
    _, c = _load(tmp_path)
    assert c["A0"] == {} and "holds condition" in capsys.readouterr().err


def test_category_lookup_uses_the_protocol(study):
    _load(study)
    assert {aa._category("T1/rich/r00"), aa._category("T2/rich/r00")} == {"cat_a", "cat_b"}
    assert aa._category("NOPE/rich/r00") == "unknown"


def test_find_root_rejects_a_directory_without_cells(tmp_path):
    with pytest.raises(SystemExit):
        aa.find_root(str(tmp_path))
