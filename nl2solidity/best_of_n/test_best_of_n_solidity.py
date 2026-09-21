"""Offline tests for the Solidity best-of-N runner.

* selection and the interception hook are tested in-process against a stub generator;
* the end-to-end test runs `run_best_of_n.main()` in a subprocess with the HTTP layer replaced by a
  fake and the REAL `solc`, so the hook is exercised against the real `generate_solidity_moe`
  and `batch_generate` (skipped when solc is not installed). It never touches the network.

    .venv/bin/python -m pytest nl2solidity/best_of_n/test_best_of_n_solidity.py -q
"""

from __future__ import annotations

import json
import subprocess
import sys
import textwrap
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from types import SimpleNamespace

import pytest

_HERE = Path(__file__).resolve().parent
_NL2 = _HERE.parent
_ROOT = _NL2.parent
for _p in (str(_ROOT), str(_NL2), str(_NL2 / "ablation"), str(_HERE)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import run_best_of_n as bon  # noqa: E402


# ------------------------------------------------------------------ selection
def cand(index, valid=False, errors=0):
    return {"index": index, "is_valid": valid, "error_count": errors}


def test_compiling_beats_fewer_errors():
    assert bon.select_best([cand(0, errors=1), cand(1, valid=True)])["index"] == 1


def test_fewest_errors_then_lowest_index():
    assert bon.select_best([cand(0, errors=5), cand(1, errors=2), cand(2, errors=2)])["index"] == 1
    assert bon.select_best([cand(3, valid=True), cand(1, valid=True)])["index"] == 1


def test_no_candidates():
    assert bon.select_best([]) is None


# ------------------------------------------------------------------ hook, against a stub generator
class Res:
    def __init__(self, n_errors):
        self.errors = [SimpleNamespace(is_syntax_error=lambda: False, is_semantic_error=lambda: True)
                       for _ in range(n_errors)]
        self.is_valid = n_errors == 0


def make_stub(replies, downstream=True, fire=True):
    """A stand-in for agent_rag_moe: enough surface for BestOfN, plus a scripted generator."""
    log = []
    lock = threading.Lock()

    def real_invoke(model, system, human, key):
        with lock:
            log.append((model, system, human))
            i = len([1 for m, s, h in log if h == human and s == system])
        reply = replies(human, i)
        if isinstance(reply, Exception):
            raise reply
        return reply

    stub = SimpleNamespace(
        __file__=str(_NL2 / "agent_rag_moe.py"),
        _invoke_with_retry=real_invoke,
        _active_expert_models=lambda: [],
        _env_flag=lambda name, default: False,
        _rag_context=lambda *a, **k: "",
        _active_combiner_model=lambda: "z-ai/glm-5.2",
        _default_system_prompt=lambda hint: "SYS",
        PROMPT_HUMAN_TEMPLATE="{context}|REQ:{input}",
        COMPILER_SYNTAX_ONLY=False,
        check_code=lambda code, syntax_only=False: Res(int(code.split("err=")[1].split()[0])),
    )

    def real_generate(prompt):
        human = stub.PROMPT_HUMAN_TEMPLATE.format(context="", input=prompt)
        if fire:
            code = stub._invoke_with_retry("z-ai/glm-5.2", "SYS", human, "k")
        else:
            code = "err=0"
        if downstream:
            # later stages: a different human message (repair/property/alignment) must pass through
            stub._invoke_with_retry("z-ai/glm-5.2", "SYS", human + "|REPAIR", "k")
            stub._invoke_with_retry("z-ai/glm-5.2", "OTHER-SYS", human, "k")
        return code, {"final_valid": True}

    stub.generate_solidity_moe = real_generate
    return stub, log


def installed(stub, n=6):
    """Install the hook the way main() does; the stub's generate_solidity_moe is then the wrapper."""
    hook = bon.BestOfN(stub, n)
    hook.install(SimpleNamespace(create_meta_json=lambda *a: {}, write_entry_output=lambda *a: None))
    return hook


def test_hook_samples_n_and_only_the_initial_call():
    stub, log = make_stub(lambda human, i: f"err={[3, 1, 4, 1, 5, 9][(i - 1) % 6]} // {i}"
                          if "REPAIR" not in human else "err=0 repair")
    installed(stub)

    code, record = stub.generate_solidity_moe("build a vault")

    initial = [c for c in log if c[2] == "|REQ:build a vault" and c[1] == "SYS"]
    passthrough = [c for c in log if c not in initial]
    assert len(initial) == 6                       # fanned out N times
    assert len(passthrough) == 2                   # repair + other-system call untouched
    b = record["best_of_n"]
    assert b["n"] == 6 and b["n_candidates"] == 6 and b["n_valid"] == 0
    assert b["selected_error_count"] == 1
    assert code == b["codes"][b["selected_index"]]
    assert [c["index"] for c in b["candidates"]] == list(range(6))
    assert all("code" not in c for c in b["candidates"])


def test_valid_sample_wins_even_when_it_arrives_last():
    stub, _ = make_stub(lambda human, i: "err=0 good" if i == 6 else f"err={i}")
    installed(stub)
    code, record = stub.generate_solidity_moe("p")
    assert code == "err=0 good"
    assert record["best_of_n"]["any_valid"] and record["best_of_n"]["n_valid"] == 1


def test_failed_samples_are_not_candidates():
    stub, _ = make_stub(lambda human, i: RuntimeError("provider 500") if i <= 4 else f"err={i}",
                         downstream=False)
    installed(stub)
    _, record = stub.generate_solidity_moe("p")
    b = record["best_of_n"]
    assert b["n_candidates"] == 2 and b["n_transport_failures"] == 4
    assert len(b["failures"]) == 4 and "provider 500" in b["failures"][0]["error"]


def test_all_samples_failing_raises_like_a_failed_a0_call():
    stub, _ = make_stub(lambda human, i: RuntimeError("down"))
    installed(stub)
    with pytest.raises(RuntimeError, match="all 6 samples failed"):
        stub.generate_solidity_moe("p")


def test_hook_that_never_fires_fails_loudly():
    stub, _ = make_stub(lambda human, i: "err=0", fire=False)
    installed(stub)
    with pytest.raises(RuntimeError, match="never saw the generator's initial call"):
        stub.generate_solidity_moe("p")


def test_refuses_to_run_with_rag_or_moe_on():
    stub, _ = make_stub(lambda human, i: "err=0")
    stub._env_flag = lambda name, default: True
    installed(stub)
    with pytest.raises(RuntimeError, match="RAG/MoE must be off"):
        stub.generate_solidity_moe("p")


def test_concurrent_seeds_do_not_cross_contexts():
    stub, _ = make_stub(lambda human, i: f"err={i} {human.split('REQ:')[1]}")
    installed(stub)
    with ThreadPoolExecutor(6) as pool:
        out = list(pool.map(lambda p: (p, stub.generate_solidity_moe(p)), [f"seed{k}" for k in range(6)]))
    for prompt, (code, record) in out:
        assert prompt in code                                    # picked from its own samples
        assert all(prompt in c for c in record["best_of_n"]["codes"].values())


def test_n_of_one_is_the_a0_call():
    stub, log = make_stub(lambda human, i: "err=2 only", downstream=False)
    installed(stub, 1)
    code, record = stub.generate_solidity_moe("p")
    assert code == "err=2 only" and len(log) == 1
    assert record["best_of_n"]["selected_index"] == 0


def test_invalid_n():
    with pytest.raises(ValueError):
        bon.BestOfN(make_stub(lambda h, i: "")[0], 0)


# ------------------------------------------------------------------ end to end, real generator + solc
def _solc_available() -> bool:
    try:
        from nl2solidity.compiler_interface import is_compiler_available
        return bool(is_compiler_available())
    except Exception:  # noqa: BLE001
        return False


E2E_SCRIPT = textwrap.dedent('''
    import io, json, sys, threading, urllib.request
    sys.path.insert(0, {root!r}); sys.path.insert(0, {nl2!r})
    sys.path.insert(0, {nl2!r} + "/ablation"); sys.path.insert(0, {here!r})

    LOG, LOCK, SEEN = {log!r}, threading.Lock(), {{}}
    # Error count per arrival; SEEDB never compiles, SEEDA gets one clean contract among broken ones.
    def contract(marker, k):
        if marker == "SEEDA" and k == 3:
            body = "uint public x; function set(uint v) public {{ x = v; }}"
        else:
            errs = {{"SEEDA": [2, 4, 1, None, 3, 5], "SEEDB": [4, 2, 5, 2, 6, 3]}}[marker][k]
            body = "function f() public {{ " + " ".join(f"undeclared{{i}} = 1;" for i in range(errs)) + " }}"
        return "// SPDX-License-Identifier: MIT\\npragma solidity ^0.8.20;\\ncontract C {{ " + body + " }}"

    class Resp:
        def __init__(self, data): self.data = data
        def __enter__(self): return self
        def __exit__(self, *a): return False
        def read(self): return self.data

    def fake_urlopen(req, timeout=None):
        msgs = json.loads(req.data)["messages"]
        human = msgs[-1]["content"]
        marker = "SEEDA" if "SEEDA" in human else "SEEDB"
        with LOCK:
            k = SEEN[marker] = SEEN.get(marker, -1) + 1
            open(LOG, "a").write(json.dumps({{"marker": marker, "k": k}}) + "\\n")
        text = contract(marker, k % 6)
        return Resp(json.dumps({{"choices": [{{"message": {{"content": text}}}}]}}).encode())

    urllib.request.urlopen = fake_urlopen
    import run_best_of_n
    sys.exit(run_best_of_n.main({argv!r}))
''')


@pytest.mark.skipif(not _solc_available(), reason="solc not installed")
def test_end_to_end_real_generator_real_solc(tmp_path):
    seeds = tmp_path / "seeds.jsonl"
    seeds.write_text("\n".join(json.dumps({
        "id": f"U{i}", "domain": "test", "description": f"short {m}",
        "description_long": f"Write a contract. Marker {m}."})
        for i, m in ((1, "SEEDA"), (2, "SEEDB"))) + "\n")
    log = tmp_path / "llm.log"
    out_root = tmp_path / "out"
    argv = ["--n", "6", "--num-entries", "2", "--workers", "2", "--no-measure-all",
            "--shards", "1", "--shard", "0",
            "--seed-file", str(seeds), "--output-root", str(out_root)]
    script = tmp_path / "e2e.py"
    script.write_text(E2E_SCRIPT.format(root=str(_ROOT), nl2=str(_NL2), here=str(_HERE),
                                        log=str(log), argv=argv))

    env = {"PATH": "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin", "HOME": str(Path.home()),
           "OPENROUTER_API_KEY": "test-key", "OPENROUTER_BASE_URL": "http://127.0.0.1:9/none",
           "OPENROUTER_MAX_CONCURRENCY": "12", "SOLC_AUTO_INSTALL": "false"}
    proc = subprocess.run([sys.executable, str(script)], env=env, capture_output=True, text=True,
                          timeout=600)
    assert proc.returncode == 0, proc.stdout[-3000:] + proc.stderr[-3000:]

    calls = [json.loads(line) for line in log.read_text().splitlines()]
    assert sum(c["marker"] == "SEEDA" for c in calls) == 6      # exactly N model calls per seed:
    assert sum(c["marker"] == "SEEDB" for c in calls) == 6      # cheap mode has no other stage

    arm = out_root / "BoN6"
    for sid, marker in (("U1", "SEEDA"), ("U2", "SEEDB")):
        d = arm / sid
        meta = json.loads((d / "meta.json").read_text())
        b = meta["best_of_n"]
        assert meta["ablation"] == "BoN6"
        assert b["n"] == 6 and b["n_candidates"] == 6 and len(b["candidates"]) == 6
        assert sorted(p.name for p in (d / "candidates").iterdir()) == [f"cand-{i}.sol" for i in range(6)]
        assert "codes" not in b

        # meta.json's verdict is the selected candidate's, and the selected file is that candidate
        chosen = min(b["candidates"], key=bon.rank_key)
        assert chosen["index"] == b["selected_index"]
        assert (d / f"{sid}.sol").read_text() == (d / "candidates" / f"cand-{chosen['index']}.sol").read_text()
        assert meta["validation"]["is_valid"] is chosen["is_valid"]

        # the recorded compile results are the real solc's, not the hook's opinion
        from nl2solidity.compiler_interface import check_code
        for c in b["candidates"]:
            fresh = check_code((d / "candidates" / f"cand-{c['index']}.sol").read_text())
            assert (fresh.is_valid, fresh.error_count) == (c["is_valid"], c["error_count"])

    a = json.loads((arm / "U1" / "meta.json").read_text())
    assert a["best_of_n"]["any_valid"] and a["validation"]["is_valid"] is True     # picked the clean one
    b2 = json.loads((arm / "U2" / "meta.json").read_text())
    assert not b2["best_of_n"]["any_valid"] and b2["validation"]["is_valid"] is False
    assert b2["best_of_n"]["selected_error_count"] == 2          # fewest of [4,2,5,2,6,3]
