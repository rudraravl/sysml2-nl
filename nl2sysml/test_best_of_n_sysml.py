"""Offline tests for best_of_n_generate: selection, sharding, output layout, sampling glue.

No network and no JVM are needed except `test_real_compiler_scores_a_candidate`, which is skipped
when the SysML compiler is not installed.

    .venv/bin/python -m pytest nl2sysml/test_best_of_n_sysml.py -q
"""

import json
import sys
from pathlib import Path

import pytest

_NL2 = Path(__file__).resolve().parent
sys.path.insert(0, str(_NL2))
sys.path.insert(0, str(_NL2.parent))

import best_of_n_generate as bon  # noqa: E402


def cand(index, valid=False, unique=0, empty=False, timeout=False, error=None, code="x"):
    return {
        "index": index, "code": code, "sha256": f"h{index}", "empty": empty, "error": error,
        "timeout": timeout, "is_valid": valid, "error_count": unique * 2,
        "unique_error_count": unique, "syntax_error_count": unique, "semantic_error_count": 0,
        "errors": [], "model_calls": 1, "compile_sec": 0.1,
    }


# ------------------------------------------------------------------ selection
def test_valid_beats_fewer_errors():
    assert bon.select_best([cand(0, unique=1), cand(1, valid=True)])["index"] == 1


def test_fewest_unique_errors_wins_among_invalid():
    picked = bon.select_best([cand(0, unique=5), cand(1, unique=2), cand(2, unique=9)])
    assert picked["index"] == 1


def test_ties_go_to_lowest_index():
    assert bon.select_best([cand(3, valid=True), cand(1, valid=True), cand(2, valid=True)])["index"] == 1
    assert bon.select_best([cand(2, unique=4), cand(0, unique=4)])["index"] == 0


def test_empty_never_wins_on_zero_errors():
    # An empty file reports zero errors; it must lose to any scored candidate.
    picked = bon.select_best([cand(0, empty=True, code=""), cand(1, unique=40)])
    assert picked["index"] == 1


def test_timeout_and_transport_failure_rank_last():
    picked = bon.select_best([cand(0, timeout=True), cand(1, error="boom", empty=True), cand(2, unique=12)])
    assert picked["index"] == 2


def test_all_unscored_still_returns_deterministically():
    picked = bon.select_best([cand(2, empty=True, code=""), cand(1, empty=True, code="")])
    assert picked["index"] == 1


def test_no_candidates():
    assert bon.select_best([]) is None


def test_dedup_counts_the_double_reported_parser_errors():
    e = {"line": 3, "column": 4, "message": "mismatched input"}
    assert bon.dedup_error_count([e, dict(e), {**e, "line": 9}]) == 2


# ------------------------------------------------------------------ sharding
@pytest.mark.parametrize("shards", [1, 3, 5, 6])
def test_shards_partition_ids_exactly(shards):
    ids = [f"U{i}" for i in range(1, 102)]
    parts = [bon.shard_ids(ids, shards, k) for k in range(shards)]
    assert sorted(sum(parts, [])) == sorted(ids)
    assert len({s for p in parts for s in p}) == len(ids)          # disjoint
    assert max(map(len, parts)) - min(map(len, parts)) <= 1        # balanced


# ------------------------------------------------------------------ sampling glue
def test_run_seed_samples_n_compiles_n_and_records_failures(monkeypatch):
    calls = []

    def fake_sample(prompt, key):
        i = len(calls)
        calls.append(i)
        if i == 2:
            raise RuntimeError("provider 500")
        return f"package P{i} {{}}", 1

    def fake_compile(code, timeout):
        good = "P4" in code
        return {"is_valid": good, "timeout": False,
                "errors": [] if good else [
                    {"line": 1, "column": 1, "message": "m", "severity": "error", "code": "Syntax",
                     "syntax": True, "semantic": False}]}

    monkeypatch.setattr(bon, "_sample_code", fake_sample)
    monkeypatch.setattr(bon, "_compile", fake_compile)
    result = bon.run_seed({"sid": "U1", "prompt": "p", "n": 6, "key": "k", "compile_timeout": 5})

    assert len(result["candidates"]) == 6
    assert [c["index"] for c in result["candidates"]] == list(range(6))
    assert sum(1 for c in result["candidates"] if c["error"]) == 1
    failed = next(c for c in result["candidates"] if c["error"])
    assert failed["empty"] and "provider 500" in failed["error"]
    assert bon.select_best(result["candidates"])["is_valid"] is True


# ------------------------------------------------------------------ output layout
def test_write_seed_layout_and_naive_compatible_meta(tmp_path):
    cands = [cand(0, unique=3, code="package A {}"), cand(1, valid=True, code="package B {}"),
             cand(2, empty=True, code="")]
    meta = bon.write_seed(tmp_path, "U7", "make a thing", 3,
                          {"candidates": cands, "elapsed_sec": 1.5})

    d = tmp_path / "U7"
    assert (d / "U7.sysml").read_text().strip() == "package B {}"
    assert (d / "U7.txt").read_text().strip() == "make a thing"
    assert {p.name for p in (d / "candidates").iterdir()} == {"cand-0.sysml", "cand-1.sysml", "cand-2.sysml"}

    on_disk = json.loads((d / "meta.json").read_text())
    assert on_disk == json.loads(json.dumps(meta))
    # Fields the existing naive-vs-full tooling reads:
    for field in ("id", "model", "pipeline", "elapsed_sec", "empty_output", "validation", "errors"):
        assert field in on_disk
    assert set(on_disk["validation"]) >= {"is_valid", "error_count", "syntax_error_count",
                                          "semantic_error_count"}
    assert on_disk["validation"]["is_valid"] is True
    b = on_disk["best_of_n"]
    assert (b["n"], b["selected_index"], b["n_valid"], b["n_empty"], b["any_valid"]) == (3, 1, 1, 1, True)
    assert len(b["candidates"]) == 3 and "code" not in b["candidates"][0]


def test_best_of_one_is_the_naive_arm():
    only = cand(0, unique=2)
    assert bon.select_best([only]) is only


# ------------------------------------------------------------------ the baseline is the naive arm
def test_prompt_and_model_are_imported_from_the_naive_script():
    import naive_glm_generate as naive
    assert bon.naive is naive
    assert naive.MODEL == "z-ai/glm-5.2"


def test_sample_code_uses_naive_prompt_and_retries_degenerate_once(monkeypatch):
    import agent_rag_moe as transport
    import naive_glm_generate as naive

    seen = []

    def fake_invoke(model, system, human, key):
        seen.append((model, system, human))
        return "I cannot" if len(seen) == 1 else "```\npackage A { part x; }\n```"

    monkeypatch.setattr(transport, "_openrouter_invoke", fake_invoke)
    code, calls = bon._sample_code("build a drone", "k")

    assert calls == 2 and code == "package A { part x; }"
    assert seen[0][0] == naive.MODEL
    assert seen[0][1] == naive.SYSTEM_PROMPT
    assert seen[0][2] == naive.HUMAN_TEMPLATE.format(input="build a drone")
    assert seen[1][1].startswith(naive.SYSTEM_PROMPT) and seen[1][1] != naive.SYSTEM_PROMPT


# ------------------------------------------------------------------ real compiler
def test_real_compiler_scores_a_candidate():
    from compiler_interface import is_compiler_available
    if not is_compiler_available():
        pytest.skip("SysML compiler (java + parser jar) not available")
    good = bon._compile("package Demo { part def A; }", 60)
    bad = bon._compile("package Demo { part def A ", 60)
    assert good["is_valid"] and not good["errors"]
    assert not bad["is_valid"] and bad["errors"]
    assert bad["timeout"] is False


# ------------------------------------------------------------------ transport failures are not outcomes
def test_seed_with_a_transport_failure_is_not_complete(tmp_path):
    ok = [cand(i, valid=True) for i in range(3)]
    bon.write_seed(tmp_path, "U1", "p", 3, {"candidates": ok, "elapsed_sec": 1.0})
    assert bon.is_complete(tmp_path / "U1" / "meta.json", 3)

    # what the first real run wrote when OpenRouter returned 402: every sample failed, seed "written"
    dead = [cand(i, empty=True, error="RuntimeError: OpenRouter call failed: 402 credits", code="")
            for i in range(3)]
    bon.write_seed(tmp_path, "U2", "p", 3, {"candidates": dead, "elapsed_sec": 1.0})
    assert not bon.is_complete(tmp_path / "U2" / "meta.json", 3)

    partial = [cand(0, valid=True), cand(1, empty=True, error="IncompleteRead", code=""), cand(2)]
    bon.write_seed(tmp_path, "U3", "p", 3, {"candidates": partial, "elapsed_sec": 1.0})
    assert not bon.is_complete(tmp_path / "U3" / "meta.json", 3)


def test_completeness_checks_n_and_tolerates_missing_or_corrupt_meta(tmp_path):
    bon.write_seed(tmp_path, "U1", "p", 3, {"candidates": [cand(i, valid=True) for i in range(3)],
                                            "elapsed_sec": 1.0})
    assert not bon.is_complete(tmp_path / "U1" / "meta.json", 6)      # a best-of-3 is not a best-of-6
    assert not bon.is_complete(tmp_path / "nope" / "meta.json", 3)
    (tmp_path / "U9").mkdir()
    (tmp_path / "U9" / "meta.json").write_text("{not json")
    assert not bon.is_complete(tmp_path / "U9" / "meta.json", 3)
    (tmp_path / "U8").mkdir()
    (tmp_path / "U8" / "meta.json").write_text(json.dumps({"validation": {}}))   # a naive-style meta
    assert not bon.is_complete(tmp_path / "U8" / "meta.json")


def test_model_empty_reply_is_an_outcome_not_a_transport_failure():
    empty_reply = cand(0, empty=True, code="")          # model answered with nothing: error is None
    assert bon.transport_failures({"candidates": [empty_reply]}) == []
    assert bon.transport_failures({"candidates": [cand(1, error="boom", empty=True, code="")]}) == ["boom"]
