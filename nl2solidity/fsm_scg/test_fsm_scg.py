"""Unit tests for the FSM-SCG* control loop. No network, no solc, no Slither: all mocked.

    .venv/bin/python -m pytest nl2solidity/fsm_scg/test_fsm_scg.py -q
"""

import json
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))

import run_fsm_scg as r  # noqa: E402
from upstream_prompts import prompt_utils, state_machine_json  # noqa: E402

GOOD_FSM = json.dumps({
    "contractName": "Auction", "initialState": "Open",
    "states": [
        {"name": "Open", "transitions": [{"trigger": "Close", "target": "Closed", "action": "close"}]},
        {"name": "Closed", "transitions": [{"trigger": "Reopen", "target": "Open", "action": "reopen"}]},
    ],
    "events": ["Close", "Reopen"],
})
UNREACHABLE_FSM = json.dumps({
    "initialState": "A",
    "states": [
        {"name": "A", "transitions": [{"trigger": "e", "target": "A"}]},
        {"name": "B", "transitions": [{"trigger": "e", "target": "A"}]},
    ],
    "events": ["e"],
})
ACYCLIC_FSM = json.dumps({
    "initialState": "A",
    "states": [{"name": "A", "transitions": [{"trigger": "e", "target": "B"}]},
               {"name": "B", "transitions": []}],
    "events": ["e"],
})
CODE_1 = "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.26;\ncontract A { uint x; }"
CODE_2 = "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.26;\ncontract B { uint y; }"
CODE_3 = "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.26;\ncontract C { uint z; }"
FINDING = {"check_type": "reentrancy-eth", "impact": "High", "confidence": "Medium",
           "start_line": 3, "end_line": 5, "overall_description": "Reentrancy in C.f()"}


def fence(code, tag="solidity"):
    return f"```{tag}\n{code}\n```"


class ScriptedLLM:
    """Returns the scripted replies in order and records every request."""

    def __init__(self, replies):
        self.replies = list(replies)
        self.requests = []

    def __call__(self, messages, temperature, top_p):
        self.requests.append({"messages": messages, "temperature": temperature, "top_p": top_p})
        return self.replies.pop(0), {"prompt_tokens": 10, "completion_tokens": 5}


class Err:
    def __init__(self, msg):
        self.severity, self.line, self.column, self.message, self.code = "error", 1, 1, msg, "TypeError"

    def is_syntax_error(self):
        return False

    def is_semantic_error(self):
        return True

    def __str__(self):
        return self.message


class Res:
    def __init__(self, ok, msg="Undeclared identifier."):
        self.is_valid = ok
        self.errors = [] if ok else [Err(msg)]

    def format_errors(self):
        return "No errors found." if self.is_valid else f"Found 1 error(s):\n1. Line 1, Column 1: {self.errors[0].message}"


def compiler(bad=()):
    """check_code stand-in: any source containing a string from `bad` fails."""
    return lambda code: Res(not any(b in code for b in bad))


def slither(findings=(), error=None):
    return lambda code: (None, error) if error else ([dict(f) for f in findings], None)


def run(replies, bad=(), findings=(), error=None, sid="U1"):
    llm = ScriptedLLM(replies)
    out = r.run_seed(sid, "An auction contract.", llm, compiler(bad), slither(findings, error))
    assert not llm.replies, "every scripted reply should be consumed"
    return llm, out


# ---- FSM loop ---------------------------------------------------------------------------
def test_valid_fsm_with_cycle_needs_no_repair():
    llm, (code, fsm, tr, st) = run([fence(GOOD_FSM, "json"), fence(CODE_1)])
    assert st["fsm_repairs"] == 0 and st["fsm_accepted"] and st["fsm_has_cycle"]
    assert st["n_calls"] == 2 and fsm["contractName"] == "Auction"


def test_unreachable_state_triggers_one_repair():
    llm, (_, _, tr, st) = run([UNREACHABLE_FSM, GOOD_FSM, fence(CODE_1)])
    assert st["fsm_repairs"] == 1 and st["fsm_accepted"]
    msg = llm.requests[1]["messages"][-1]["content"]
    assert msg == ("The generated FSM has the following issues, please regenerate the FSM:"
                   "\n### List of unreachable states: {'B'}")


def test_missing_cycle_triggers_repair_with_upstream_text():
    llm, (_, _, _, st) = run([ACYCLIC_FSM, GOOD_FSM, fence(CODE_1)])
    assert st["fsm_repairs"] == 1
    assert llm.requests[1]["messages"][-1]["content"].endswith(
        "\n### The graph composed of states does not have cycles")


def test_fsm_budget_stops_at_two_repairs():
    llm, (_, fsm, tr, st) = run([ACYCLIC_FSM] * 3 + [fence(CODE_1)])
    assert st["fsm_repairs"] == 2 and not st["fsm_accepted"]
    assert [c["step"] for c in tr["calls"]] == ["fsm", "fsm_repair", "fsm_repair", "code"]
    assert len(tr["fsm_candidates"]) == 3


def test_json_parse_failure_triggers_repair():
    llm, (_, _, tr, st) = run(["I cannot produce that.", GOOD_FSM, fence(CODE_1)])
    assert st["fsm_repairs"] == 1
    msg = llm.requests[1]["messages"][-1]["content"]
    assert msg.startswith("The generated FSM has the following issues, please regenerate the FSM:"
                          "\n### FSM is not valid JSON: ")
    assert tr["fsm_candidates"][0]["parser"] is None


def test_fsm_with_comments_and_json_tag_parses():
    # Upstream's own format example has // comments; upstream extract_fsm leaves the `json` tag.
    fsm, rec = r.check_fsm(r.data_utils.extract_fsm(fence(state_machine_json, "json")))
    assert fsm is not None and rec["parser"] == "json_repair"
    assert rec["has_cycle"] and rec["unreachable"] == []
    # Upstream quirk, kept: its own example fails validate_fsm (EventC is not in "events").
    assert rec["issues"] == ["The trigger EventC of state State3 is not defined in the event list."]


def test_isolated_initial_state_does_not_crash():
    text = json.dumps({"initialState": "A", "events": [],
                       "states": [{"name": "A", "transitions": []}, {"name": "B"}]})
    _, rec = r.check_fsm(text)
    assert rec["unreachable"] == ["B"] and rec["has_cycle"] is False


def test_missing_keys_become_feedback():
    _, rec = r.check_fsm(json.dumps({"states": []}))
    assert rec["issues"] and rec["issues"][0].startswith("FSM structure error: KeyError")


# ---- compile and security loop ----------------------------------------------------------
def test_compile_error_gets_exactly_one_repair():
    llm, (code, _, tr, st) = run([GOOD_FSM, fence(CODE_1), fence(CODE_2)], bad=("contract",))
    assert st["compile_repairs"] == 1 and not st["compiled_before_security"]
    assert llm.requests[2]["messages"][-1]["content"] == prompt_utils.feedback_by_compile_error_prompt(
        "Found 1 error(s):\n1. Line 1, Column 1: Undeclared identifier.")
    assert code == CODE_2 and st["n_calls"] == 3


def test_compile_repair_that_works_then_security():
    llm, (code, _, _, st) = run([GOOD_FSM, fence(CODE_1), fence(CODE_2), fence(CODE_3)],
                                bad=("contract A",), findings=[FINDING])
    assert st["compile_repairs"] == 1 and st["compiled_before_security"]
    assert st["security_repairs"] == 1 and code == CODE_3 and st["n_calls"] == 4


def test_empty_findings_send_no_security_turn():
    llm, (code, _, _, st) = run([GOOD_FSM, fence(CODE_1)], findings=[])
    assert st["security_repairs"] == 0 and st["security_feedback"] == "none" and st["n_calls"] == 2


def test_findings_send_exactly_one_security_turn():
    llm, (code, _, tr, st) = run([GOOD_FSM, fence(CODE_1), fence(CODE_2)], findings=[FINDING])
    assert st["security_repairs"] == 1 and st["security_feedback"] == "sent"
    assert st["n_slither_findings_fed_back"] == 1
    assert llm.requests[2]["messages"][-1]["content"] == \
        prompt_utils.feedback_by_security_risk_prompt([FINDING])


def test_slither_crash_is_not_feedback():
    llm, (code, _, _, st) = run([GOOD_FSM, fence(CODE_1)], error="solc failed")
    assert st["security_feedback"] == "slither_error" and st["n_calls"] == 2 and code == CODE_1


def test_final_sol_is_last_code_reply():
    replies = [ACYCLIC_FSM, ACYCLIC_FSM, GOOD_FSM, fence(CODE_1), fence(CODE_2), fence(CODE_3, "Solidity")]
    llm, (code, _, tr, st) = run(replies, bad=("contract A",), findings=[FINDING])
    assert st["n_calls"] == 6 and code == CODE_3
    assert tr["messages"][-1] == {"role": "assistant", "content": replies[-1]}


# ---- conversation, prompts, sampling ----------------------------------------------------
def test_history_accumulates_and_uses_upstream_prompts():
    llm, (_, _, tr, _) = run([GOOD_FSM, fence(CODE_1)])
    p1, p2 = prompt_utils.generate_code_with_fsm_prompt("An auction contract.", "0.8.26")
    first, second = llm.requests[0]["messages"], llm.requests[1]["messages"]
    assert first == [{"role": "system", "content": "You are an expert in smart contract programming."},
                     {"role": "user", "content": p1}]
    assert second[:2] == first and second[2] == {"role": "assistant", "content": GOOD_FSM}
    assert second[3] == {"role": "user", "content": p2}
    assert "solidity version is 0.8.26" in p2 and '"initialState": "State1"' in p1


def test_sampling_is_seeded_per_sample_and_recorded():
    a, (_, _, tr_a, _) = run([GOOD_FSM, fence(CODE_1)], sid="U7")
    b, (_, _, tr_b, _) = run([GOOD_FSM, fence(CODE_1)], sid="U7")
    c, _ = run([GOOD_FSM, fence(CODE_1)], sid="U8")
    draws = [(q["temperature"], q["top_p"]) for q in a.requests]
    assert draws == [(q["temperature"], q["top_p"]) for q in b.requests]
    assert draws != [(q["temperature"], q["top_p"]) for q in c.requests]
    assert all(0.6 <= t <= 1.0 and 0.9 <= p <= 1.0 and round(t, 2) == t for t, p in draws)
    assert [(k["temperature"], k["top_p"]) for k in tr_a["calls"]] == draws


def test_empty_replies_raise_as_infra():
    llm = ScriptedLLM([""] * 3)
    with pytest.raises(RuntimeError) as exc:
        r.run_seed("U1", "req", llm, compiler(), slither())
    assert r.INFRA_ERROR.search(str(exc.value))


def test_empty_reply_is_retried_once_then_used():
    llm, (_, _, tr, st) = run(["", GOOD_FSM, fence(CODE_1)])
    assert st["n_calls"] == 2 and tr["calls"][0]["empty_retries"] == 1
    assert llm.requests[0]["temperature"] == llm.requests[1]["temperature"]


@pytest.mark.parametrize("reply", [
    fence(CODE_1), fence(CODE_1, "Solidity"), fence(CODE_1, "sol"), fence(CODE_1, ""),
    "Here you go:\n" + fence(CODE_1) + "\nDone.", CODE_1,
    fence('{"a": 1}', "json") + "\n" + fence(CODE_1),
])
def test_extract_code_variants(reply):
    assert r.extract_code(reply) == CODE_1


# ---- output --------------------------------------------------------------------------
NAIVE_GEN_KEYS = {"id", "model", "pipeline", "created", "elapsed_sec", "empty_output",
                  "nl_prompt_source", "nl_source_path", "validation", "errors"}
SCORER_KEYS = {"quality", "quality_gates", "execution", "security", "spec_alignment", "scoring"}


def test_meta_is_superset_of_naive_schema(tmp_path):
    llm, (code, fsm, tr, st) = run([GOOD_FSM, fence(CODE_1)])
    meta = r.build_meta("U1", code, st, 1.23, "token", compile_fn=compiler())
    keys = set(meta)
    u1 = r._NL2 / "dataset" / "naive_glm" / "U1" / "meta.json"
    naive_keys = set(json.loads(u1.read_text())) - SCORER_KEYS if u1.exists() else NAIVE_GEN_KEYS
    assert naive_keys <= keys and NAIVE_GEN_KEYS <= keys
    assert set(meta["validation"]) == {"is_valid", "error_count", "syntax_error_count",
                                       "semantic_error_count"}
    assert meta["pipeline"] == "fsm_scg_prompting" and meta["model"] == "z-ai/glm-5.2"
    assert meta["nl_source_path"] == "sol_seed.jsonl:U1" and meta["category"] == "token"
    for k in ("n_calls", "fsm_repairs", "fsm_valid_final", "fsm_unreachable", "fsm_has_cycle",
              "compile_repairs", "compiled_before_security", "security_repairs",
              "n_slither_findings_fed_back", "security_feedback", "upstream_commit"):
        assert k in meta["fsm_scg"]
    assert meta["fsm_scg"]["usage"] == {"prompt_tokens": 20, "completion_tokens": 10}

    r.write_seed(tmp_path / "U1", "U1", "An auction contract.", code, fsm, tr, meta)
    assert r.is_done(tmp_path / "U1")
    assert (tmp_path / "U1" / "U1.sol").read_text() == CODE_1 + "\n"
    assert (tmp_path / "U1" / "U1.txt").read_text() == "An auction contract.\n"
    assert json.loads((tmp_path / "U1" / "fsm.json").read_text())["initialState"] == "Open"


def test_final_validation_is_a_fresh_compile():
    # The loop never compiles the security reply; meta.json must not inherit the loop's verdict.
    llm, (code, _, _, st) = run([GOOD_FSM, fence(CODE_1), fence(CODE_2)], findings=[FINDING])
    meta = r.build_meta("U1", code, st, 1.0, "x", compile_fn=compiler(bad=("contract B",)))
    assert st["compiled_before_security"] and not meta["validation"]["is_valid"]


def test_empty_code_is_invalid_and_flagged():
    meta = r.build_meta("U1", "", {}, 0.0, "x", compile_fn=compiler())
    assert meta["empty_output"] and not meta["validation"]["is_valid"] and meta["errors"] == []


# ---- upstream metrics (vrs_metrics.py) ------------------------------------------------
def test_vrs_risk_and_summary(monkeypatch):
    import vrs_metrics as v
    findings = {"high": [dict(FINDING, impact="High", confidence="High"),
                         dict(FINDING, check_type="x", impact="Low", confidence="Medium")],
                "clean": [], "crash": None}
    monkeypatch.setattr(v, "check_code", lambda code: Res("broken" not in code))
    monkeypatch.setattr(v, "slither_findings", lambda code: (findings[code], None)
                        if findings[code] is not None else (None, "boom"))
    s = {k: v.measure(k) for k in ("high", "clean", "crash", "broken")}
    assert s["high"]["risk"] == (9 + 2) / 2 and s["clean"]["risk"] == 0
    assert s["crash"]["risk"] == 10 and s["broken"]["risk"] == 10 and not s["broken"]["compiled"]
    out = v.summarize(s)
    assert out["CPR"] == 75.0 and out["VRS"] == (5.5 + 0 + 10 + 10) / 4
    assert out["n_analysed"] == 2 and out["ZRCP"] == 50.0 and out["HRCP"] == 50.0
    assert out["n_slither_error"] == 1
    res = v.paired(s, s)
    assert [r["metric"] for r in res][0] == "CPR (compiles)" and res[2]["n"] == 2
