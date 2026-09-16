#!/usr/bin/env python3
"""Tests for the ablation harness.

These guard the two properties a sweep cannot be re-run to recover from:

  * the ladder is monotone and each arm adds exactly one stage, so a difference
    between two arms is attributable to that stage and nothing else;
  * shards partition the evaluation set exactly, so N concurrent instances of an
    arm cover every seed once and no seed twice.

Run: .venv/bin/python -m pytest nl2solidity/ablation/test_ablation.py -q
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent
_NL2 = _HERE.parent
_ROOT = _NL2.parent
for _p in (str(_ROOT), str(_NL2), str(_HERE)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import gen_sbatch  # noqa: E402
import profiles  # noqa: E402

PYTHON = str(_ROOT / ".venv" / "bin" / "python")
if not Path(PYTHON).exists():
    PYTHON = sys.executable

STAGE_FLAGS = (
    "RAG_ENABLED",
    "MOE_ENABLED",
    "COMPILER_FEEDBACK_ENABLED",
    "KERNEL_FEEDBACK_ENABLED",
    "PROPERTY_TESTS_ENABLED",
    "SECURITY_ANALYSIS_ENABLED",
    "SPEC_ALIGNMENT_ENABLED",
)

# The one stage (or stage pair) each rung is supposed to introduce.
EXPECTED_ADDITIONS = {
    "A0": set(),
    "A1": {"RAG_ENABLED"},
    "A2": {"MOE_ENABLED"},
    "A3": {"COMPILER_FEEDBACK_ENABLED"},
    "A4": {"KERNEL_FEEDBACK_ENABLED", "PROPERTY_TESTS_ENABLED"},
    "A5": {"SECURITY_ANALYSIS_ENABLED", "SPEC_ALIGNMENT_ENABLED"},
}


def _enabled(arm_id: str, measure_all: bool = False) -> set:
    """Stages this arm has switched on.

    Defaults to measure_all=False: the ladder is defined by what an arm *repairs*
    against, and under the default measure-all mode every arm measures everything,
    which would flatten the ladder into six identical rows.
    """
    env = profiles.get(arm_id).resolved_env(measure_all)
    return {flag for flag in STAGE_FLAGS if env[flag] == "true"}


# --------------------------------------------------------------------------
# The ladder
# --------------------------------------------------------------------------

def test_arm_ids_are_the_six_expected():
    assert profiles.ARM_IDS == ["A0", "A1", "A2", "A3", "A4", "A5"]


def test_a0_enables_nothing():
    assert _enabled("A0") == set()


@pytest.mark.parametrize("arm_id", profiles.ARM_IDS[1:])
def test_ladder_is_monotone(arm_id):
    """Every arm keeps everything the arm below it had."""
    previous = profiles.ARM_IDS[profiles.ARM_IDS.index(arm_id) - 1]
    assert _enabled(previous) <= _enabled(arm_id), (
        f"{arm_id} dropped a stage that {previous} had"
    )


@pytest.mark.parametrize("arm_id", profiles.ARM_IDS)
def test_each_arm_adds_exactly_its_stage(arm_id):
    idx = profiles.ARM_IDS.index(arm_id)
    previous = set() if idx == 0 else _enabled(profiles.ARM_IDS[idx - 1])
    assert _enabled(arm_id) - previous == EXPECTED_ADDITIONS[arm_id]


def test_a5_enables_every_stage():
    assert _enabled("A5") == set(STAGE_FLAGS)


@pytest.mark.parametrize("arm_id", profiles.ARM_IDS)
def test_arm_labels_itself(arm_id):
    assert profiles.get(arm_id).resolved_env()["ABLATION_ID"] == arm_id


def test_arm_lookup_is_case_insensitive_and_rejects_junk():
    assert profiles.get("a3").id == "A3"
    with pytest.raises(KeyError):
        profiles.get("A9")


# --------------------------------------------------------------------------
# measure-all: everything measured, only in-arm stages repaired
# --------------------------------------------------------------------------

CHECKER_FLAGS = {
    "COMPILER_FEEDBACK_ENABLED",
    "KERNEL_FEEDBACK_ENABLED",
    "PROPERTY_TESTS_ENABLED",
    "SECURITY_ANALYSIS_ENABLED",
    "SPEC_ALIGNMENT_ENABLED",
}


@pytest.mark.parametrize("arm_id", profiles.ARM_IDS)
def test_measure_all_enables_every_checker(arm_id):
    assert CHECKER_FLAGS <= _enabled(arm_id, measure_all=True)


@pytest.mark.parametrize("arm_id", profiles.ARM_IDS)
def test_measure_all_is_the_default(arm_id):
    """Every arm carries the full metric set unless cheap mode is asked for."""
    assert profiles.get(arm_id).resolved_env() == \
        profiles.get(arm_id).resolved_env(measure_all=True)
    assert CHECKER_FLAGS <= {f for f in STAGE_FLAGS
                             if profiles.get(arm_id).resolved_env()[f] == "true"}


@pytest.mark.parametrize("arm_id", profiles.ARM_IDS)
def test_apply_defaults_to_measuring_everything(arm_id, isolated_env):
    applied = profiles.apply(arm_id)
    for flag in CHECKER_FLAGS:
        assert applied[flag] == "true", f"{arm_id} would not be measured by {flag}"


def test_every_arm_reports_the_same_metric_set():
    """The property the comparison rests on: no arm is missing a metric."""
    measured = {
        arm_id: {flag for flag in CHECKER_FLAGS
                 if profiles.get(arm_id).resolved_env()[flag] == "true"}
        for arm_id in profiles.ARM_IDS
    }
    assert len(set(map(frozenset, measured.values()))) == 1, measured


@pytest.mark.parametrize("arm_id", profiles.ARM_IDS)
def test_measure_all_does_not_change_how_anything_is_generated(arm_id):
    """It changes what is observed, never what the model is asked to produce."""
    plain = profiles.get(arm_id).resolved_env()
    measured = profiles.get(arm_id).resolved_env(measure_all=True)
    for flag in ("RAG_ENABLED", "MOE_ENABLED"):
        assert plain[flag] == measured[flag]


def test_measure_all_gives_out_of_arm_stages_zero_repairs():
    env = profiles.get("A2").resolved_env(measure_all=True)
    # A2 has no compiler/execution/security/alignment repair of its own.
    assert env["MAX_REFINEMENT_ITERATIONS"] == "0"
    assert env["MAX_KERNEL_REFINEMENT_ITERATIONS"] == "0"
    assert env["MAX_SECURITY_REFINEMENT_ITERATIONS"] == "0"
    assert env["SPEC_ALIGNMENT_MAX_REPAIRS"] == "0"


def test_measure_all_keeps_in_arm_repair_budgets():
    env = profiles.get("A3").resolved_env(measure_all=True)
    # A3 owns compiler repair, so it keeps its budget while the rest go to zero.
    assert env["MAX_REFINEMENT_ITERATIONS"] == "2"
    assert env["MAX_KERNEL_REFINEMENT_ITERATIONS"] == "0"


# --------------------------------------------------------------------------
# apply(): identity forced, tuning yields
# --------------------------------------------------------------------------

@pytest.fixture
def isolated_env(monkeypatch):
    """profiles.apply() writes straight to os.environ, by design - it configures
    the process that is about to import the generator. In-process tests of it
    therefore have to restore the environment themselves, or a leaked
    SECURITY_ANALYSIS_ENABLED=false quietly disables Slither for every test that
    runs after this module.
    """
    for key in profiles._IDENTITY_KEYS | set(profiles._BASE):
        monkeypatch.setenv(key, os.environ.get(key, ""))
        if key not in os.environ:
            monkeypatch.delenv(key, raising=False)
    yield monkeypatch


def test_apply_forces_stage_flags_over_a_polluted_environment(isolated_env):
    monkeypatch = isolated_env
    # An arm must not inherit a stage from a stray export, or the sweep is void.
    monkeypatch.setenv("RAG_ENABLED", "true")
    monkeypatch.setenv("MOE_ENABLED", "true")
    monkeypatch.setenv("ABLATION_ID", "WRONG")
    applied = profiles.apply("A0")
    assert applied["RAG_ENABLED"] == "false"
    assert applied["MOE_ENABLED"] == "false"
    assert applied["ABLATION_ID"] == "A0"
    assert os.environ["MOE_ENABLED"] == "false"


def test_apply_forces_a_repair_budget_off_in_cheap_mode(isolated_env):
    """The same guarantee for feedback stages, where measure-all is not masking it."""
    isolated_env.setenv("SPEC_ALIGNMENT_ENABLED", "true")
    applied = profiles.apply("A0", measure_all=False)
    assert applied["SPEC_ALIGNMENT_ENABLED"] == "false"


def test_apply_lets_an_explicit_tuning_override_stand(isolated_env):
    isolated_env.setenv("MAX_REFINEMENT_ITERATIONS", "5")
    applied = profiles.apply("A3")
    assert applied["MAX_REFINEMENT_ITERATIONS"] == "5"


# --------------------------------------------------------------------------
# Sharding
# --------------------------------------------------------------------------

def _shard_ids(arm_id: str, shards: int, shard: int, num_entries: int) -> list:
    """Seed ids run_ablation would actually generate for this shard."""
    proc = subprocess.run(
        [PYTHON, str(_HERE / "run_ablation.py"),
         "--arm", arm_id, "--shards", str(shards), "--shard", str(shard),
         "--num-entries", str(num_entries), "--no-resume", "--dry-run",
         "--output-root", "/tmp/nl2sol-ablation-dryrun"],
        capture_output=True, text=True, cwd=str(_ROOT), timeout=300,
    )
    assert proc.returncode == 0, proc.stderr[-2000:]
    ids = []
    in_worklist = False
    for line in proc.stdout.splitlines():
        if line.startswith("DRY RUN"):
            in_worklist = True
            continue
        if not in_worklist:
            continue            # timestamped log lines above also start with '['
        stripped = line.strip()
        if stripped.startswith("[") and "]" in stripped:
            ids.append(stripped.split("]", 1)[1].split()[0])
    return ids


@pytest.mark.parametrize("shards", [4, 5, 6])
def test_shards_partition_the_evaluation_set_exactly(shards):
    """Disjoint and complete: the property the whole parallel design rests on."""
    num_entries = 60
    seen: list = []
    per_shard = []
    for shard in range(shards):
        ids = _shard_ids("A0", shards, shard, num_entries)
        per_shard.append(ids)
        seen.extend(ids)

    assert len(seen) == num_entries, f"shards covered {len(seen)} of {num_entries} seeds"
    assert len(set(seen)) == num_entries, "a seed was assigned to more than one shard"
    # Shards should also be near-equal, or one task becomes the walltime.
    sizes = [len(ids) for ids in per_shard]
    assert max(sizes) - min(sizes) <= 1, f"unbalanced shards: {sizes}"


def test_shard_assignment_is_stable_across_arms():
    """Same seed, same shard, every arm — so a shard's failure is comparable."""
    for shard in range(3):
        assert _shard_ids("A0", 3, shard, 30) == _shard_ids("A5", 3, shard, 30)


@pytest.mark.parametrize("shards,shard", [(0, 0), (5, 5), (5, -1)])
def test_invalid_shard_arguments_are_rejected(shards, shard):
    proc = subprocess.run(
        [PYTHON, str(_HERE / "run_ablation.py"), "--arm", "A0",
         "--shards", str(shards), "--shard", str(shard), "--dry-run"],
        capture_output=True, text=True, cwd=str(_ROOT), timeout=120,
    )
    assert proc.returncode != 0


# --------------------------------------------------------------------------
# Generated SLURM scripts
# --------------------------------------------------------------------------

def test_sbatch_scripts_match_profiles():
    """Guards against editing profiles.py and forgetting to regenerate."""
    assert gen_sbatch.main(["--check"]) == 0


@pytest.mark.parametrize("script", sorted((_HERE / "pace").glob("*.sh")) +
                                   sorted((_HERE / "pace").glob("*.sbatch")))
def test_shell_scripts_parse(script):
    proc = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
    assert proc.returncode == 0, proc.stderr


@pytest.mark.parametrize("arm_id", profiles.ARM_IDS)
def test_every_arm_has_an_sbatch_that_runs_it(arm_id):
    script = _HERE / "pace" / f"{arm_id.lower()}.sbatch"
    assert script.is_file()
    text = script.read_text()
    assert f"run_arm {arm_id}" in text
    assert f"--time={profiles.get(arm_id).hours}:00:00" in text


# --------------------------------------------------------------------------
# The generator honours the knobs the profiles set
# --------------------------------------------------------------------------

def _probe(env_overrides: dict, expression: str) -> str:
    """Evaluate an expression in a fresh interpreter under the given env.

    A subprocess, not monkeypatch: several of agent_rag_moe's stage switches are
    module-level constants read once at import, which is exactly the behaviour
    under test.
    """
    env = dict(os.environ)
    # An empty string means "unset this", so a test can probe the pristine default.
    for key, value in env_overrides.items():
        if value == "":
            env.pop(key, None)
        else:
            env[key] = value
    env["PYTHONPATH"] = f"{_ROOT}{os.pathsep}{_NL2}"
    proc = subprocess.run(
        [PYTHON, "-c",
         "import agent_rag_moe as m; from pathlib import Path; print(repr(" + expression + "))"],
        capture_output=True, text=True, env=env, cwd=str(_ROOT), timeout=120,
    )
    assert proc.returncode == 0, proc.stderr[-2000:]
    return proc.stdout.strip()


def test_rag_disabled_yields_no_retrieved_context():
    out = _probe({"RAG_ENABLED": "false"},
                 "m._rag_context('an escrow contract', Path(r'" + str(_ROOT) + "'))")
    assert out == "''"


def test_rag_enabled_yields_retrieved_context():
    out = _probe({"RAG_ENABLED": "true"},
                 "len(m._rag_context('an escrow contract', Path(r'" + str(_ROOT) + "')))")
    assert int(out) > 0, "RAG corpus produced no context; is dataset/data present?"


def test_moe_disabled_leaves_only_the_combiner():
    assert _probe({"MOE_ENABLED": "false"}, "m._active_expert_models()") == "[]"


def test_moe_enabled_uses_the_full_expert_roster():
    assert _probe({"MOE_ENABLED": "true"}, "len(m._active_expert_models())") == "4"


def test_expert_roster_is_overridable():
    out = _probe({"MOE_ENABLED": "true", "ABLATION_EXPERT_MODELS": "a/one, b/two"},
                 "m._active_expert_models()")
    assert out == "['a/one', 'b/two']"


def test_disabled_stage_still_measures_at_zero_repairs():
    """The property measure-all depends on: off means 'no repair', not 'no check'."""
    out = _probe({"COMPILER_FEEDBACK_ENABLED": "false", "MAX_REFINEMENT_ITERATIONS": "2"},
                 "m._repair_iterations('COMPILER_FEEDBACK_ENABLED', "
                 "'MAX_REFINEMENT_ITERATIONS', 2)")
    assert out == "0"


def test_enabled_stage_uses_its_repair_budget():
    out = _probe({"COMPILER_FEEDBACK_ENABLED": "true", "MAX_REFINEMENT_ITERATIONS": "3"},
                 "m._repair_iterations('COMPILER_FEEDBACK_ENABLED', "
                 "'MAX_REFINEMENT_ITERATIONS', 2)")
    assert out == "3"


@pytest.mark.parametrize("arm_id", profiles.ARM_IDS)
def test_stage_config_reported_matches_the_arm(arm_id):
    env = profiles.get(arm_id).resolved_env()
    reported = _probe(env, "m.active_stage_config()")
    config = eval(reported)  # noqa: S307 - our own repr, from our own subprocess
    assert config["ablation"] == arm_id
    assert config["rag"] is (env["RAG_ENABLED"] == "true")
    assert config["moe"] is (env["MOE_ENABLED"] == "true")
    assert config["security_enabled"] is (env["SECURITY_ANALYSIS_ENABLED"] == "true")
    assert config["spec_alignment_enabled"] is (env["SPEC_ALIGNMENT_ENABLED"] == "true")


# --------------------------------------------------------------------------
# Backward compatibility
# --------------------------------------------------------------------------

def test_a5_is_exactly_the_untouched_default_pipeline():
    """The ablation knobs must not have changed how the full pipeline runs.

    A5 is defined as "everything on", and the pre-existing entry point sets no
    ablation variables at all. If those two ever diverge, the 800 samples already
    under dataset/with_kernel_spec stop being comparable to anything new.
    """
    cleared = {flag: "" for flag in STAGE_FLAGS}
    cleared["ABLATION_ID"] = ""
    defaults = eval(_probe(cleared, "m.active_stage_config()"))  # noqa: S307

    a5 = profiles.get("A5").resolved_env()
    assert defaults["rag"] is True
    assert defaults["moe"] is True
    assert defaults["property_tests"] is True
    assert defaults["security_enabled"] is True
    assert defaults["spec_alignment_enabled"] is True
    assert defaults["execution_enabled"] is True
    assert defaults["compiler_repair_iterations"] == int(a5["MAX_REFINEMENT_ITERATIONS"])
    assert defaults["execution_repair_iterations"] == int(a5["MAX_KERNEL_REFINEMENT_ITERATIONS"])
    assert defaults["security_repair_iterations"] == int(a5["MAX_SECURITY_REFINEMENT_ITERATIONS"])
    assert defaults["spec_alignment_max_repairs"] == int(a5["SPEC_ALIGNMENT_MAX_REPAIRS"])
