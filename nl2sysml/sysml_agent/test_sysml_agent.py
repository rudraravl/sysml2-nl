"""Offline tests for the SysMLAgent baseline: validator, retrieval, Algorithm 1 loop, outputs.

Mocked LLM, no network, no JVM (the per-snapshot compile is switched off or stubbed).

    .venv/bin/python -m pytest nl2sysml/sysml_agent/test_sysml_agent.py -q
"""

import json
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent
_ROOT = _HERE.parent.parent
for _p in (str(_HERE), str(_HERE.parent), str(_ROOT)):
    sys.path.insert(0, _p)

import antlr_validator as av  # noqa: E402
import context_engine  # noqa: E402
import materialize  # noqa: E402
import run_sysml_agent as run  # noqa: E402

# Curated references the validator must accept (official, community-free, simple imports).
REFS = ["000001", "000002", "000010", "000100", "000300"]
VALID = "package P {\n  private import ScalarValues::*;\n  part def A {\n    attribute m : Real;\n  }\n}\n"


# ------------------------------------------------------------------ validator
@pytest.mark.parametrize("f", sorted((_HERE / "grammar" / "examples").glob("*.sysml")),
                         ids=lambda p: p.name)
def test_accepts_grammar_repo_examples(f):
    code = f.read_text(encoding="utf-8")
    assert av.validate(code, checks=())["valid"]  # the grammar repo's own parse fixtures
    r = av.validate(code)
    # toaster and vehicle use Real/Integer/... without `import ScalarValues::*`; the Pilot compiler
    # rejects them the same way ("Couldn't resolve reference to Type 'Real'"), so those flags are
    # correct and the only ones allowed
    names = {e["message"].split("'")[1] for e in r["errors"]}
    assert all(e["kind"] == "semantic" for e in r["errors"])
    assert names <= {"Real", "Integer", "Boolean", "String", "Natural"}, names
    assert r["valid"] == (f.name == "camera.sysml")


@pytest.mark.parametrize("sid", REFS)
def test_accepts_curated_references(sid):
    r = av.validate((_ROOT / "dataset" / "data" / sid / f"{sid}.sysml").read_text(encoding="utf-8"))
    assert r["valid"], r["errors"][:3]


def test_rejects_syntax_error_on_the_right_line():
    code = "package P {\n  part def A;\n  part def B\n  part x : A;\n}\n"
    r = av.validate(code)
    assert not r["valid"]
    assert r["errors"][0]["kind"] == "syntax" and r["errors"][0]["line"] == 4


def test_duplicate_name_fires_and_is_scoped():
    bad = "package P {\n  private import ScalarValues::*;\n  part def A;\n  part def A;\n}\n"
    r = av.validate(bad)
    assert not r["valid"] and r["errors"][0]["kind"] == "semantic"
    assert r["errors"][0]["line"] == 4 and "duplicate name 'A'" in r["errors"][0]["message"]
    ok = "package P {\n  part def A { attribute x; }\n  part def B { attribute x; }\n}\n"
    assert av.validate(ok)["valid"]  # same name in two different namespaces is fine


def test_unresolved_reference_fires_then_import_supplies_the_name():
    bad = VALID.replace("  private import ScalarValues::*;\n", "")
    r = av.validate(bad)
    assert not r["valid"]
    assert [(e["line"], e["column"], e["kind"]) for e in r["errors"]] == [(3, 18, "semantic")]
    assert "unresolved reference 'Real'" in r["errors"][0]["message"]
    assert av.validate(VALID)["valid"]
    assert av.validate(bad.replace("package P {\n", "package P {\n  import ScalarValues::*;\n"))["valid"]
    assert av.validate(bad.replace("package P {\n", "package P {\n  import ScalarValues::Real;\n"))["valid"]


def test_unresolved_is_conservative():
    # qualified names resolve by their first segment; library supertypes' features may be
    # redefined; an import of an unknown namespace makes the check abstain
    assert av.validate("package P { part def A { attribute m : ISQ::MassValue; } }")["valid"]
    assert av.validate("package P { part def A { attribute m; } part a : A { attribute :>> m = 1; } }")["valid"]
    assert av.validate("package P { import Foo::*; part x : Bar; }")["valid"]


def test_checks_can_be_switched_off():
    bad = VALID.replace("  private import ScalarValues::*;\n", "")
    assert av.validate(bad, checks=())["valid"]
    assert av.validate(bad, checks=("duplicates",))["valid"]


def test_format_errors_caps_at_40():
    errs = [{"line": i, "column": 0, "kind": "syntax", "message": "m"} for i in range(1, 46)]
    lines = av.format_errors(errs).splitlines()
    assert len(lines) == 41 and lines[0] == "line 1:0 syntax m" and lines[-1] == "... (5 more)"


# ------------------------------------------------------------------ retrieval
def _eval_data_ids():
    ids = set()
    for m in (_ROOT / "dataset" / "with_kernel_spec").glob("*/meta.json"):
        ids.add(json.loads(m.read_text(encoding="utf-8")).get("dataset_data_id"))
    return ids


def test_retrieval_returns_two_hits_from_the_official_pool_only():
    evil = _eval_data_ids()
    assert evil and min(evil) > "000250"
    for sid in ["U1", "U10", "U500"]:
        hits = context_engine.retrieve(run.read_prompt(sid))
        assert len(hits) == 2
        assert hits[0]["similarity"] >= hits[1]["similarity"]
        for h in hits:
            assert "000001" <= h["id"] <= "000250" and h["id"] not in evil
            assert h["code"] and h["description"]
    assert set(context_engine.pool()["ids"]).isdisjoint(evil)


def test_first_turn_layout():
    hits = [{"id": "000001", "description": "d1", "code": "c1"},
            {"id": "000002", "description": "d2", "code": "c2"}]
    t = run.first_turn("REQ", hits)
    assert t.startswith(run.USER_PROMPT)
    assert "Example 1 description:\nd1\nExample 1 SysML v2 model:\nc1" in t
    assert "Example 2 description:\nd2" in t and t.endswith("User input:\nREQ")
    assert run.first_turn("REQ", None) == run.USER_PROMPT_NORAG + "\n\nUser input:\nREQ"


def test_extract_strips_fences_and_prose():
    raw = "Here is the model:\n```sysml\npackage P {\n}\n```\nHope this helps."
    assert run.extract(raw) == "package P {\n}"
    assert run.extract("package P {}\n") == "package P {}"


# ------------------------------------------------------------------ Algorithm 1 loop
class FakeLLM:
    """Replies from a script; records every message list it was sent."""

    def __init__(self, replies):
        self.replies = list(replies)
        self.seen = []

    def __call__(self, messages):
        self.seen.append([dict(m) for m in messages])
        return self.replies.pop(0), {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}


def _hits(text, k):
    return [{"id": "000001", "description": "d", "code": "package E {}", "similarity": 0.5},
            {"id": "000002", "description": "e", "code": "package F {}", "similarity": 0.4}][:k]


BAD = "package P {\n  part def A\n}\n"


def test_valid_first_generation_means_zero_fix_rounds():
    llm = FakeLLM([VALID])
    res = run.run_agent("req", llm, retrieve=_hits)
    assert res["converged"] and res["n_fix_rounds"] == 0 and res["n_calls"] == 1
    assert [m["role"] for m in res["messages"]] == ["system", "user", "assistant"]
    assert res["messages"][0]["content"] == run.SYSTEM_PROMPT


def test_persistently_invalid_stops_after_six_fix_rounds():
    llm = FakeLLM([BAD] * 10)
    res = run.run_agent("req", llm, retrieve=_hits)
    assert not res["converged"] and res["n_fix_rounds"] == 6 and res["n_calls"] == 7
    assert len(res["iterations"]) == 7 and len(llm.replies) == 3


def test_fixer_turn_carries_model_and_errors_and_history_accumulates():
    llm = FakeLLM([BAD, BAD, VALID])
    res = run.run_agent("req", llm, retrieve=_hits)
    assert res["converged"] and res["n_fix_rounds"] == 2
    fix = llm.seen[1][-1]
    assert fix["role"] == "user" and fix["content"].startswith("The SysML v2 model you generated is not valid.")
    assert "Here is the current model:\n" + BAD.strip() in fix["content"]
    assert "line 3:0 syntax" in fix["content"]
    # amendment A1: the offending source line follows each error, underlined (Parr, Sec. 9.2)
    assert "line 3:0 syntax mismatched input '}' expecting {';', '{'}\n    }\n    ^\n" in fix["content"]
    assert [len(s) for s in llm.seen] == [2, 4, 6]  # the whole conversation is resent each turn
    assert llm.seen[2][:4] == llm.seen[1]


def test_empty_reply_is_invalid():
    res = run.run_agent("req", FakeLLM(["", VALID]), retrieve=_hits)
    assert res["n_fix_rounds"] == 1 and res["iterations"][0]["antlr"]["errors"] == [run.EMPTY_ERROR]


def test_no_rag_skips_retrieval():
    llm = FakeLLM([VALID])
    res = run.run_agent("req", llm, rag=False, retrieve=lambda *a: pytest.fail("retrieved"))
    assert res["retrieval"] == [] and "Example 1" not in llm.seen[0][1]["content"]


def test_provider_error_discards_the_seed(monkeypatch):
    def boom(messages):
        raise RuntimeError("HTTP 429")
    monkeypatch.setattr(context_engine, "retrieve", _hits)
    out = run.run_seed({"sid": "U1", "prompt": "req", "chat": boom, "rag": True, "max_rounds": 6,
                        "compile": False, "validate_timeout": 60})
    assert "infra_error" in out and "iterations" not in out


# ------------------------------------------------------------------ outputs
def _fake_compile(code, timeout):
    return {"is_valid": code == VALID.strip(), "timeout": False, "empty": not code,
            "error_count": 0 if code == VALID.strip() else 2, "unique_error_count": 1,
            "syntax_error_count": 1, "semantic_error_count": 0,
            "errors": [] if code == VALID.strip() else
            [{"line": 2, "column": 2, "message": "m", "severity": "error", "code": None}] * 2}


def _run_and_write(tmp_path, monkeypatch, replies):
    monkeypatch.setattr(context_engine, "retrieve", _hits)
    monkeypatch.setattr(run, "compile_summary", _fake_compile)
    res = run.run_seed({"sid": "U7", "prompt": "req text", "chat": FakeLLM(replies), "rag": True,
                        "max_rounds": 6, "compile": True, "compile_timeout": 5,
                        "validate_timeout": 60})
    meta = run.write_seed(tmp_path / "sysml_agent", "U7", "req text", res, run.MODEL, True, 6)
    return tmp_path / "sysml_agent" / "U7", meta


def test_every_snapshot_is_written_and_final_equals_last(tmp_path, monkeypatch):
    d, meta = _run_and_write(tmp_path, monkeypatch, [BAD] * 7)
    snaps = sorted(d.glob("candidates/iter-*.sysml"))
    assert [p.name for p in snaps] == [f"iter-{i}.sysml" for i in range(7)]
    assert (d / "U7.sysml").read_text() == (d / "candidates" / "iter-6.sysml").read_text()
    b = meta["sysml_agent"]
    assert b["converged"] is False and b["n_fix_rounds"] == 6 and b["n_calls"] == 7
    assert b["antlr_valid_by_iter"] == [False] * 7
    assert b["antlr_errors_by_iter"][0] == {"syntax": 1, "semantic": 0}
    assert b["retrieval_ids"] == ["000001", "000002"] and b["grammar_tag"] == av.GRAMMAR_TAG
    assert b["tokens"]["total_tokens"] == 7 * 15
    tr = json.loads((d / "transcript.json").read_text())
    assert len(tr["messages"]) == 2 + 7 * 2 - 1 and len(tr["iterations"]) == 7
    assert tr["iterations"][0]["compile"]["error_count"] == 2
    assert run.is_complete(d / "meta.json")


def test_meta_keys_are_a_superset_of_the_naive_arm(tmp_path, monkeypatch):
    _, meta = _run_and_write(tmp_path, monkeypatch, [BAD, VALID])
    naive = json.loads((_ROOT / "dataset" / "naive_glm" / "U1" / "meta.json").read_text())
    assert set(naive) - {"compiler_timeout"} <= set(meta)
    assert set(naive["validation"]) <= set(meta["validation"])
    assert set(naive["errors"][0]) <= set(meta["errors"][0]) if meta["errors"] else True
    assert meta["pipeline"] == "sysml_agent" and meta["model"] == "z-ai/glm-5.2"
    assert meta["validation"]["is_valid"] is True


def test_materialize_builds_iter0_and_iter1(tmp_path, monkeypatch):
    _run_and_write(tmp_path, monkeypatch, [BAD, BAD, VALID])  # iter0 bad, iter1 bad, iter2 valid
    counts = materialize.materialize(tmp_path / "sysml_agent", tmp_path)
    assert set(counts.values()) == {1}
    m0 = json.loads((tmp_path / "sysml_agent_iter0" / "U7" / "meta.json").read_text())
    m1 = json.loads((tmp_path / "sysml_agent_iter1" / "U7" / "meta.json").read_text())
    assert m0["pipeline"] == "sysml_agent_iter0" and m0["snapshot"]["n_calls"] == 1
    assert m1["snapshot"]["iter"] == 1 and m1["snapshot"]["tokens"]["total_tokens"] == 30
    assert m0["validation"]["is_valid"] is False and m0["validation"]["error_count"] == 2
    assert (tmp_path / "sysml_agent_iter1" / "U7" / "U7.txt").read_text() == "req text\n"


def test_materialize_iter1_falls_back_to_iter0_when_already_valid(tmp_path, monkeypatch):
    _run_and_write(tmp_path, monkeypatch, [VALID])
    materialize.materialize(tmp_path / "sysml_agent", tmp_path)
    m1 = json.loads((tmp_path / "sysml_agent_iter1" / "U7" / "meta.json").read_text())
    assert m1["snapshot"]["iter"] == 0 and m1["validation"]["is_valid"] is True
    assert (tmp_path / "sysml_agent_iter1" / "U7" / "U7.sysml").read_text().strip() == VALID.strip()


def test_underline_marks_the_offending_token_and_keeps_tabs():
    code = "package P {\n\tpart x : Real;\n}\n"
    e = av.validate(code)["errors"][0]
    assert e["length"] == 4
    assert av.underline(code, e) == ["    \tpart x : Real;", "    \t         ^^^^"]
    assert av.format_errors([e]) == av.format_errors([e], code=code).splitlines()[0]
