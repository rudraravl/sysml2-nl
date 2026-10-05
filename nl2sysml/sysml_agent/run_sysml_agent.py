#!/usr/bin/env python3
"""SysMLAgent baseline (Cibrian et al., Computers in Industry 172 (2025) 104350), reimplemented.

Algorithm 1 of the paper, as an explicit loop in one multi-turn conversation (DEVIATIONS.md D3):
    retrieve the k=2 nearest database models (context_engine.py)
    generate with the paper's system + user prompts, retrieved models inserted (D9)
    validate with the ANTLR validation engine (antlr_validator.py)
    while invalid and fewer than 6 fix rounds (D5):
        send the Fixer turn (current model + validator errors, D4) in the same conversation
        re-validate
Every candidate is kept: candidates/iter-0.sysml is the initial generation (the paper's
LLM_Raw+RAG ablation), iter-j the model after fix round j. <ID>.sysml is the last candidate, valid
or not (D6). materialize.py turns the snapshots into the iter-0 / iter-1 / final corpora.

After the loop our own scoring compiler (compiler_interface.check_code, errors only, no kernel) runs
on every snapshot. It never feeds back into the loop; it gives the per-iteration compile curve and
the naive-compatible `validation` block of meta.json.

Layout (naive-compatible, so the existing tooling reads it):
    <out>/<ID>/<ID>.sysml  <ID>.txt  meta.json  transcript.json  retrieval.json  candidates/iter-*.sysml
meta.json is written last and is the completion marker (a seed is done once it has a
`sysml_agent` block). A provider error anywhere in a seed's conversation discards the seed; it is
redone on resume and never scored.

Parallelism, sharding and resume follow best_of_n_generate.py: one process per seed (SIGALRM
compile timeouts need a main thread), shard k of S takes sorted positions p with p % S == k.

Examples
    python nl2sysml/sysml_agent/run_sysml_agent.py --dry-run --limit 10
    python nl2sysml/sysml_agent/run_sysml_agent.py --workers 8 --shards 5 --shard 2
    python nl2sysml/sysml_agent/run_sysml_agent.py --prompt-set paper --model openai/gpt-4o-mini \\
        --out-dir dataset/sysml_agent_fidelity/full
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import signal
import sys
import threading
import time
from concurrent.futures import FIRST_COMPLETED, ProcessPoolExecutor, wait
from datetime import datetime
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_NL2 = _HERE.parent
_ROOT = _NL2.parent
for _p in (str(_ROOT), str(_NL2), str(_HERE)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from dotenv import load_dotenv  # noqa: E402

load_dotenv(_ROOT / ".env")

import best_of_n_generate as bon  # noqa: E402  (compile, dedup, sharding: shared with best-of-N)
import naive_glm_generate as naive  # noqa: E402  (prompt set + post-processing: shared with naive)

MODEL = naive.MODEL  # z-ai/glm-5.2, D11
MAX_FIX_ROUNDS = 6   # D5
K = 2                # "the two nearest models"
PIPELINE = "sysml_agent"

# Paper Sec. 3.2.2, verbatim (including its grammar).
SYSTEM_PROMPT = ("you are a helpful assistant who is in charge of creating SysML v2 models given an "
                 "input from a user.")
USER_PROMPT = ("given that user input, give me a valid SysML v2 model in that represents what the "
               "user wants. Return ONLY the SysML v2 code. In order to help you, I have extracted "
               "the two nearest models that we have in our local database to give you a little bit "
               "more of context. Remember, return me JUST the SysML v2 code generated.")
# Agent_NoRAG ablation (fidelity check only, D13): the retrieval sentence is dropped, nothing else.
USER_PROMPT_NORAG = ("given that user input, give me a valid SysML v2 model in that represents what "
                     "the user wants. Return ONLY the SysML v2 code. Remember, return me JUST the "
                     "SysML v2 code generated.")
# D4: the paper gives no Fixer prompt; this is a literal rendering of Algorithm 1's
# "corrective prompt including the current model and the extracted errors". Never tuned. Each error
# is followed by its underlined source line (DEVIATIONS.md amendment A1).
FIX_PROMPT = ("The SysML v2 model you generated is not valid. The validator reported the following "
              "errors:\n{errors}\nHere is the current model:\n{model}\nFix the errors and return "
              "ONLY the corrected SysML v2 code.")
EMPTY_ERROR = {"line": 1, "column": 0, "kind": "syntax",
               "message": "empty model: the response contains no SysML v2 code"}  # D12
DEFAULT_VALIDATE_TIMEOUT = 300  # s; see antlr_check
FIXER_FORMAT = "A1-underline"   # error report format of the Fixer turn (DEVIATIONS.md amendment A1)
# A2: a reply with no code (e.g. a reasoning backbone spending its whole token budget on hidden
# reasoning, finish_reason=length) is re-requested with the identical messages, up to this many
# times, as the naive and FORGE arms retry empty replies. Still empty after that = model outcome.
EMPTY_RETRIES = 2


# --------------------------------------------------------------------------- prompts
def first_turn(requirement: str, hits: list[dict] | None) -> str:
    """D9: paper user prompt, then each retrieved example, then the requirement."""
    if hits is None:
        return f"{USER_PROMPT_NORAG}\n\nUser input:\n{requirement}"
    ex = "\n\n".join(f"Example {i} description:\n{h['description']}\n"
                     f"Example {i} SysML v2 model:\n{h['code']}" for i, h in enumerate(hits, 1))
    return f"{USER_PROMPT}\n\n{ex}\n\nUser input:\n{requirement}"


def fix_turn(code: str, errors: list[dict]) -> str:
    import antlr_validator
    return FIX_PROMPT.format(errors=antlr_validator.format_errors(errors, code=code), model=code)


def extract(raw: str) -> str:
    """D10: keep only fenced code when the reply has fences (drops prose around them), then the
    naive arm's post-processing, so every arm is extracted the same way."""
    lines = (raw or "").splitlines()
    fences = [i for i, ln in enumerate(lines) if ln.strip().startswith("```")]
    if len(fences) >= 2:
        keep = []
        for a, b in zip(fences[0::2], fences[1::2]):
            keep += lines[a:b + 1]
        lines = keep
    return naive._postprocess("\n".join(lines))


class _Timeout(Exception):
    pass


def antlr_check(code: str, timeout: int = DEFAULT_VALIDATE_TIMEOUT) -> dict:
    """The Validation Engine step of Algorithm 1. An empty candidate is invalid (D12). A parse that
    exceeds `timeout` counts as invalid with no locatable error (recorded, never silently valid)."""
    import antlr_validator
    if not code.strip():
        return {"valid": False, "errors": [EMPTY_ERROR], "timeout": False}

    def _alarm(signum, frame):
        raise _Timeout()

    main = threading.current_thread() is threading.main_thread()
    if main:
        old = signal.signal(signal.SIGALRM, _alarm)
        signal.alarm(timeout)
    try:
        r = antlr_validator.validate(code)
        r["timeout"] = False
    except _Timeout:
        r = {"valid": False, "timeout": True, "errors": [
            {"line": 1, "column": 0, "kind": "syntax",
             "message": f"validator timed out after {timeout}s"}]}
    finally:
        if main:
            signal.alarm(0)
            signal.signal(signal.SIGALRM, old)
    return r


# --------------------------------------------------------------------------- Algorithm 1
def openrouter_chat(model: str, key: str):
    """chat(messages) -> (text, usage) over the hardened transport FORGE and best-of-N use."""
    import agent_rag_moe as transport

    def chat(messages):
        usage = {}
        text = transport._openrouter_invoke(model, "", "", key, messages=messages, usage_out=usage)
        return text, usage
    return chat


def run_agent(requirement: str, chat, rag: bool = True, max_rounds: int = MAX_FIX_ROUNDS,
              validate=antlr_check, retrieve=None) -> dict:
    """One conversation. Returns {messages, retrieval, iterations[], converged, n_fix_rounds,
    n_calls}. Provider errors propagate: the caller discards the whole seed."""
    if rag and retrieve is None:
        import context_engine
        retrieve = context_engine.retrieve
    hits = retrieve(requirement, K) if rag else None
    messages = [{"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": first_turn(requirement, hits)}]
    iters = []

    def step():
        t0 = time.time()
        retried = []  # usage of discarded empty replies (A2)
        while True:
            raw, usage = chat(messages)
            code = extract(raw)
            if code.strip() or len(retried) >= EMPTY_RETRIES:
                break
            retried.append(usage)
        latency = time.time() - t0
        messages.append({"role": "assistant", "content": raw})
        t1 = time.time()
        v = validate(code)
        iters.append({"iter": len(iters), "code": code, "antlr": v, "usage": usage,
                      "empty_retry_usage": retried,
                      "latency_sec": round(latency, 2), "validate_sec": round(time.time() - t1, 2)})
        return code, v

    code, v = step()
    while not v["valid"] and len(iters) - 1 < max_rounds:
        messages.append({"role": "user", "content": fix_turn(code, v["errors"])})
        code, v = step()

    return {
        "messages": messages,
        "retrieval": [{k: h[k] for k in ("id", "description", "similarity")} for h in hits or []],
        "iterations": iters,
        "converged": v["valid"],
        "n_fix_rounds": len(iters) - 1,
        "n_calls": len(iters),
    }


# --------------------------------------------------------------------------- worker
def compile_summary(code: str, timeout: int) -> dict:
    """Our scoring compiler on one snapshot, in best-of-N's candidate format."""
    c = bon._compile(code, timeout)
    errs = c["errors"]
    return {"is_valid": c["is_valid"], "timeout": c["timeout"], "empty": not code,
            "error_count": len(errs), "unique_error_count": bon.dedup_error_count(errs),
            "syntax_error_count": sum(e["syntax"] for e in errs),
            "semantic_error_count": sum(e["semantic"] for e in errs),
            "errors": [{k: e[k] for k in ("line", "column", "message", "severity", "code")}
                       for e in errs]}


def run_seed(job: dict) -> dict:
    """Worker-process entry point: the agent loop, then our compiler on every snapshot."""
    os.environ["SYSML_COMPILER_MAX_CONCURRENCY"] = "1"  # one JVM per worker process
    t0 = time.time()
    try:
        chat = job.get("chat") or openrouter_chat(job["model"], job["key"])
        res = run_agent(job["prompt"], chat, rag=job["rag"], max_rounds=job["max_rounds"],
                        validate=lambda c: antlr_check(c, job["validate_timeout"]))
    except Exception as exc:  # noqa: BLE001 - provider/infra failure: seed is redone, not scored
        return {"sid": job["sid"], "infra_error": f"{type(exc).__name__}: {exc}"}
    res["gen_elapsed_sec"] = round(time.time() - t0, 1)
    if job["compile"]:
        for it in res["iterations"]:
            c0 = time.time()
            it["compile"] = compile_summary(it["code"], job["compile_timeout"])
            it["compile"]["compile_sec"] = round(time.time() - c0, 1)
    res["sid"] = job["sid"]
    res["elapsed_sec"] = round(time.time() - t0, 1)
    return res


# --------------------------------------------------------------------------- output
def _tokens(iters: list[dict]) -> dict:
    """Summed provider usage; `cost` is OpenRouter's billed USD."""
    us = [u or {} for it in iters for u in [it.get("usage")] + list(it.get("empty_retry_usage") or [])]
    tot = {k: sum(int(u.get(k) or 0) for u in us)
           for k in ("prompt_tokens", "completion_tokens", "total_tokens")}
    tot["cost"] = round(sum(float(u.get("cost") or 0) for u in us), 6)
    return tot


def agent_block(res: dict, model: str, rag: bool, max_rounds: int) -> dict:
    import antlr_validator
    its = res["iterations"]
    return {
        "converged": res["converged"],
        "n_fix_rounds": res["n_fix_rounds"],
        "n_calls": res["n_calls"],
        "antlr_valid_by_iter": [it["antlr"]["valid"] for it in its],
        "antlr_errors_by_iter": [{"syntax": sum(e["kind"] == "syntax" for e in it["antlr"]["errors"]),
                                  "semantic": sum(e["kind"] == "semantic" for e in it["antlr"]["errors"])}
                                 for it in its],
        "antlr_timeout_by_iter": [bool(it["antlr"].get("timeout")) for it in its],
        "antlr_unresolved_abstained_by_iter": [bool(it["antlr"].get("unresolved_abstained"))
                                               for it in its],
        "finish_reason_by_iter": [(it.get("usage") or {}).get("finish_reason") for it in its],
        "provider_by_iter": [(it.get("usage") or {}).get("provider") for it in its],
        "empty_retries_by_iter": [len(it.get("empty_retry_usage") or []) for it in its],
        "empty_retry_policy": EMPTY_RETRIES,
        "compile_valid_by_iter": [it.get("compile", {}).get("is_valid") for it in its],
        "grammar_tag": antlr_validator.GRAMMAR_TAG,
        "retrieval_ids": [h["id"] for h in res["retrieval"]],
        "rag": rag,
        "max_fix_rounds": max_rounds,
        "backbone": model,
        "tokens": _tokens(its),
        "gen_elapsed_sec": res.get("gen_elapsed_sec"),
        "fixer_format": FIXER_FORMAT,
        "code_version": CODE_VERSION,
    }


def build_meta(sid: str, res: dict, snap: int, pipeline: str, model: str, rag: bool,
               max_rounds: int) -> dict:
    """naive-compatible meta.json for snapshot `snap` (-1 = final) of one seed's run."""
    it = res["iterations"][snap]
    c = it.get("compile") or {"is_valid": False, "error_count": 0, "syntax_error_count": 0,
                              "semantic_error_count": 0, "errors": [], "timeout": False}
    meta = {
        "id": sid,
        "model": model,
        "pipeline": pipeline,
        "created": datetime.now().isoformat(),
        "elapsed_sec": res.get("elapsed_sec"),
        "empty_output": not it["code"],
        "validation": {k: c[k] for k in ("is_valid", "error_count", "syntax_error_count",
                                         "semantic_error_count")},
        "errors": c["errors"],
    }
    if c.get("timeout"):
        meta["compiler_timeout"] = True
    meta["snapshot_iter"] = it["iter"]
    meta["sysml_agent"] = agent_block(res, model, rag, max_rounds)
    return meta


def transcript(res: dict) -> dict:
    return {
        "messages": res["messages"],
        "retrieval": res["retrieval"],
        "iterations": [{
            "iter": it["iter"],
            "sha256": hashlib.sha256(it["code"].encode("utf-8")).hexdigest()[:16],
            "antlr": {"valid": it["antlr"]["valid"], "timeout": bool(it["antlr"].get("timeout")),
                      "unresolved_abstained": bool(it["antlr"].get("unresolved_abstained")),
                      "syntax": [e for e in it["antlr"]["errors"] if e["kind"] == "syntax"],
                      "semantic": [e for e in it["antlr"]["errors"] if e["kind"] == "semantic"]},
            "latency_sec": it["latency_sec"], "validate_sec": it["validate_sec"],
            "usage": it["usage"], "empty_retry_usage": it.get("empty_retry_usage", []),
            "compile": it.get("compile"),
        } for it in res["iterations"]],
        "converged": res["converged"], "n_fix_rounds": res["n_fix_rounds"],
        "n_calls": res["n_calls"],
    }


def write_seed(out_dir: Path, sid: str, prompt: str, res: dict, model: str, rag: bool,
               max_rounds: int, pipeline: str = PIPELINE) -> dict:
    """Write one seed's directory. meta.json goes last: it is the completion marker."""
    d = out_dir / sid
    (d / "candidates").mkdir(parents=True, exist_ok=True)
    for it in res["iterations"]:
        (d / "candidates" / f"iter-{it['iter']}.sysml").write_text(it["code"] + "\n", encoding="utf-8")
    (d / f"{sid}.sysml").write_text(res["iterations"][-1]["code"] + "\n", encoding="utf-8")
    (d / f"{sid}.txt").write_text(prompt + "\n", encoding="utf-8")
    (d / "retrieval.json").write_text(json.dumps(res["retrieval"], indent=1, ensure_ascii=False) + "\n",
                                      encoding="utf-8")
    (d / "transcript.json").write_text(json.dumps(transcript(res), indent=1, ensure_ascii=False) + "\n",
                                       encoding="utf-8")
    meta = build_meta(sid, res, -1, pipeline, model, rag, max_rounds)
    (d / "meta.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return meta


def is_complete(meta_path: Path, model: str | None = None, rag: bool | None = None) -> bool:
    """Done = meta.json has a `sysml_agent` block. With model/rag given, a seed written under a
    different configuration raises instead of being silently kept (never mix configs in one dir)."""
    try:
        b = json.loads(meta_path.read_text(encoding="utf-8")).get("sysml_agent")
    except (OSError, json.JSONDecodeError):
        return False
    if not b:
        return False
    if (model is not None and b.get("backbone") != model) or (rag is not None and b.get("rag") != rag):
        raise SystemExit(f"{meta_path}: written with backbone={b.get('backbone')} rag={b.get('rag')}, "
                         f"this run is backbone={model} rag={rag}; use a different --out-dir")
    return True


def _code_version() -> str:
    import subprocess
    try:
        return subprocess.run(["git", "-C", str(_ROOT), "describe", "--always", "--dirty", "--abbrev=9"],
                              capture_output=True, text=True, timeout=10).stdout.strip() or "unknown"
    except (OSError, subprocess.SubprocessError):
        return "unknown"


CODE_VERSION = _code_version()


# --------------------------------------------------------------------------- prompt sets
def eval_ids() -> list[str]:
    return naive._get_sample_ids()  # the 1,543 ids with dataset/with_kernel_spec/<ID>/meta.json


def read_prompt(sid: str) -> str | None:
    return naive._read_prompt(sid)


def paper_prompts() -> list[dict]:
    return json.loads((_HERE / "paper_prompts.json").read_text(encoding="utf-8"))["prompts"]


def _sort_key(sid: str):
    return (sid[0], int(sid[1:])) if sid[1:].isdigit() else (sid, 0)


# --------------------------------------------------------------------------- driver
def _parse_args(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--workers", type=int, default=int(os.getenv("BATCH_WORKERS", "4")),
                   help="seeds in flight at once (one process each)")
    p.add_argument("--shards", type=int, default=int(os.getenv("SA_SHARDS", "1")))
    p.add_argument("--shard", type=int, default=int(os.getenv("SA_SHARD", "0")))
    p.add_argument("--limit", type=int, default=None, help="first LIMIT seeds of the sorted id list")
    p.add_argument("--ids", default=None, help="comma-separated ids, or @file with one id per line")
    p.add_argument("--prompt-set", choices=("eval", "paper"), default="eval",
                   help="eval: the 1,543 FORGE prompts; paper: Cibrian et al. Table 2 (fidelity check)")
    p.add_argument("--model", default=MODEL)
    p.add_argument("--no-rag", action="store_true", help="Agent_NoRAG ablation (fidelity check)")
    p.add_argument("--max-fix-rounds", type=int, default=MAX_FIX_ROUNDS)
    p.add_argument("--out-dir", type=Path, default=None, help="default dataset/sysml_agent")
    p.add_argument("--compile-timeout", type=int,
                   default=int(os.getenv("SYSML_COMPILE_TIMEOUT", bon.DEFAULT_COMPILE_TIMEOUT)))
    p.add_argument("--validate-timeout", type=int, default=DEFAULT_VALIDATE_TIMEOUT)
    p.add_argument("--no-compile", action="store_true",
                   help="skip our compiler on the snapshots (fidelity check only needs ANTLR)")
    p.add_argument("--no-resume", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    return p.parse_args(argv)


def main(argv=None) -> int:
    a = _parse_args(argv)
    if a.shards < 1 or not 0 <= a.shard < a.shards:
        print(f"Error: --shard must be in [0, {a.shards - 1}]", file=sys.stderr)
        return 2
    out_dir = a.out_dir or (_ROOT / "dataset" / "sysml_agent")
    if a.prompt_set == "paper":
        prompts = {p["id"]: p["description"] for p in paper_prompts()}
        ids = sorted(prompts, key=_sort_key)
    else:
        ids = eval_ids()
        prompts = None
    if a.ids:
        want = (Path(a.ids[1:]).read_text().split() if a.ids.startswith("@") else a.ids.split(","))
        ids = [s for s in ids if s in set(want)]
    if a.limit is not None:
        ids = ids[:a.limit]
    mine = bon.shard_ids(ids, a.shards, a.shard)
    rag = not a.no_rag
    todo = [s for s in mine if a.no_resume or not is_complete(out_dir / s / "meta.json", a.model, rag)]

    print("=" * 70)
    print(f"SysMLAgent | model {a.model} | RAG {'on' if rag else 'OFF'} | "
          f"max {a.max_fix_rounds} fix rounds | T=0.2")
    print(f"  prompts:  {a.prompt_set} ({len(ids)} seeds)")
    print(f"  shard:    {a.shard + 1}/{a.shards} -> {len(mine)} seeds, {len(todo)} to do")
    print(f"  workers:  {a.workers}")
    print(f"  output:   {out_dir}")
    print("=" * 70)
    if a.dry_run:
        for s in todo[:20]:
            print("  ", s)
        if len(todo) > 20:
            print(f"   ... {len(todo) - 20} more")
        return 0

    key = os.getenv("OPENROUTER_API_KEY")
    if not key:
        print("Error: OPENROUTER_API_KEY not set", file=sys.stderr)
        return 1
    if not a.no_compile:
        from compiler_interface import is_compiler_available
        if not is_compiler_available():
            print("Error: SysML compiler unavailable (java / parser jar); pass --no-compile to "
                  "skip the per-snapshot compile (not for scored runs).", file=sys.stderr)
            return 1

    out_dir.mkdir(parents=True, exist_ok=True)
    stop = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: (print("SIGTERM: draining in-flight seeds", flush=True),
                                              stop.set()))
    text = {}
    for sid in todo:
        t = prompts[sid] if prompts else read_prompt(sid)
        if t:
            text[sid] = t
        else:
            print(f"  {sid}: no prompt, skipping")
    queue = [s for s in todo if s in text]
    if rag:  # every query embedding must be cached: nodes have no model download (HF_HUB_OFFLINE)
        import context_engine
        missing = [s for s in queue if context_engine._key(text[s]) not in context_engine._queries()]
        if missing and os.getenv("HF_HUB_OFFLINE") == "1":
            print(f"Error: {len(missing)} prompts have no cached query embedding (e.g. {missing[:3]}); "
                  f"run context_engine.py --precompute on a machine with the model", file=sys.stderr)
            return 1

    stats = {"done": 0, "converged": 0, "compile_valid": 0, "errors": 0, "infra": 0, "rounds": 0}
    t_start = time.time()
    pending: dict = {}
    with ProcessPoolExecutor(max_workers=a.workers) as pool:
        it = iter(queue)

        def submit_next() -> bool:
            if stop.is_set():
                return False
            sid = next(it, None)
            if sid is None:
                return False
            job = {"sid": sid, "prompt": text[sid], "model": a.model, "key": key, "rag": rag,
                   "max_rounds": a.max_fix_rounds, "compile": not a.no_compile,
                   "compile_timeout": a.compile_timeout, "validate_timeout": a.validate_timeout}
            pending[pool.submit(run_seed, job)] = sid
            return True

        for _ in range(a.workers):
            if not submit_next():
                break
        try:
            while pending:
                finished, _ = wait(pending, return_when=FIRST_COMPLETED)
                for fut in finished:
                    sid = pending.pop(fut)
                    try:
                        res = fut.result()
                        if res.get("infra_error"):
                            stats["infra"] += 1
                            print(f"[{sid}] provider error ({res['infra_error'][:100]}); NOT written, "
                                  f"will rerun on resume", flush=True)
                            submit_next()
                            continue
                        meta = write_seed(out_dir, sid, text[sid], res, a.model, rag, a.max_fix_rounds)
                    except Exception as exc:  # noqa: BLE001
                        stats["errors"] += 1
                        print(f"[{sid}] ERROR: {type(exc).__name__}: {exc}", flush=True)
                        submit_next()
                        continue
                    b = meta["sysml_agent"]
                    stats["done"] += 1
                    stats["converged"] += b["converged"]
                    stats["compile_valid"] += bool(meta["validation"]["is_valid"])
                    stats["rounds"] += b["n_fix_rounds"]
                    print(f"[{sid}] ANTLR {'valid' if b['converged'] else 'INVALID'} after "
                          f"{b['n_fix_rounds']} fix rounds | compiler "
                          f"{'valid' if meta['validation']['is_valid'] else str(meta['validation']['error_count']) + ' errors'} "
                          f"| {meta['elapsed_sec']}s", flush=True)
                    submit_next()
        except KeyboardInterrupt:
            print("\nInterrupted; in-flight seeds are discarded and will rerun on resume.")
            stop.set()
            for fut in pending:
                fut.cancel()

    n = max(stats["done"], 1)
    print("=" * 70)
    print(f"Done {stats['done']} in {time.time() - t_start:.0f}s | ANTLR-converged {stats['converged']} | "
          f"compiler-valid {stats['compile_valid']} | mean fix rounds {stats['rounds'] / n:.2f} | "
          f"errors {stats['errors']} | provider errors (rerun to fill) {stats['infra']}")
    return 1 if (stats["errors"] or stats["infra"]) else 0


if __name__ == "__main__":
    sys.exit(main())
