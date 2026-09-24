#!/usr/bin/env python3
"""FSM-SCG* baseline: the prompting-only variant of FSM-SCG (Luo et al., IJCAI 2025) on our seeds.

This reproduces upstream `_Model.generate_use_fsm_scg` (commit 9dcd83e) with z-ai/glm-5.2 as the
backbone. The whole seed is one multi-turn chat whose history accumulates:

    1. prompt_1 (requirement -> FSM, with the state_machine_json format example)
    2. FSM check: parse, validate_fsm, reachability + cycle. On failure, send the upstream repair
       message. At most 2 * feedback_count = 2 repair turns.
    3. prompt_2 (FSM -> Solidity)
    4. compile with our solc. If it fails, send one compile-feedback turn.
    5. Slither (upstream finding rules). If there are findings, send one security-feedback turn.
    6. The final contract is the last code the model returned. It is not recompiled inside the
       loop, as upstream does. meta.json gets a fresh check_code of it afterwards.

That is 2-6 model calls per seed: 2 when the FSM, compile and Slither checks all pass.
Prompts and FSM utilities are copied verbatim (upstream_prompts.py, upstream_fsm_utils.py). Every
place we differ from upstream is listed in DEVIATIONS.md.

Output: <output-dir>/U###/{U###.sol, U###.txt, fsm.json, transcript.json, meta.json}. meta.json
uses the naive_glm schema, so score_naive_glm.py and analyze_naive_vs_full.py read it unchanged.
meta.json is written last and is the completion marker. A seed that raises (provider error, empty
reply, anything else) writes nothing and is redone on the next run, so it is never scored.

Examples
    python nl2solidity/fsm_scg/run_fsm_scg.py --dry-run
    python nl2solidity/fsm_scg/run_fsm_scg.py --pilot 20 --output-dir nl2solidity/dataset/fsm_scg_pilot
    python nl2solidity/fsm_scg/run_fsm_scg.py --shards 15 --shard 3 --workers 4
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import random
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import traceback
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_NL2 = _HERE.parent
_ROOT = _NL2.parent
for _p in (str(_ROOT), str(_NL2), str(_HERE)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import json_repair  # noqa: E402

import naive_glm_generate as naive  # noqa: E402  (also loads $REPO/.env)
from compiler_interface import check_code, is_compiler_available  # noqa: E402
from security_analysis import (_PATH_NOISE_RE, _analysis_gate, _solc_binary_for,  # noqa: E402
                               _tool_binary, analyzer_version)
from upstream_fsm_utils import data_utils, fsm_utils, merge_check_items, nx  # noqa: E402
from upstream_prompts import prompt_utils  # noqa: E402

MODEL = naive.MODEL                      # z-ai/glm-5.2, same as naive_glm and the FORGE combiner
SYSTEM_PROMPT = "You are an expert in smart contract programming."   # upstream utils/Model.py
SOLIDITY_VERSION = "0.8.26"              # our SOLC_DEFAULT_VERSION; fills upstream's {version}
FEEDBACK_COUNT = 1                       # upstream default: 2 FSM, 1 compile, 1 security repair
UPSTREAM_COMMIT = "9dcd83ed533cc12b6c6b91bdfa0bfc4c3a46c6ea"
PIPELINE = "fsm_scg_prompting"
FSM_REPAIR_HEADER = "The generated FSM has the following issues, please regenerate the FSM:"
EMPTY_REPLY_RETRIES = 2                  # an empty completion is a provider hiccup, not an answer
OUT_DEFAULT = _NL2 / "dataset" / "fsm_scg"
SEED_FILE = naive.SEED_FILE
INFRA_ERROR = re.compile(r"OpenRouter|OPENROUTER_API_KEY|IncompleteRead|Timeout|timed out"
                         r"|Connection|empty content", re.I)
STOP = threading.Event()


# --------------------------------------------------------------------------- the model
def seed_rng(sid: str) -> random.Random:
    return random.Random(int(hashlib.sha256(sid.encode()).hexdigest(), 16) % 2**32)


def openrouter_llm(key: str, retries: int):
    def llm(messages, temperature, top_p):
        text, obj = naive._openrouter_chat(MODEL, messages, key, temperature=temperature,
                                           top_p=top_p, retries=retries)
        return text or "", obj.get("usage")
    return llm


def ask(conv: dict, content: str, step: str) -> str:
    """One turn of upstream `multiple_dialogue(..., random_parameters=True)`."""
    rng = conv["rng"]
    temperature = round(rng.uniform(0.6, 1.0), 2)
    top_p = round(rng.uniform(0.9, 1.0), 2)
    conv["messages"].append({"role": "user", "content": content})
    t0 = time.time()
    for empty in range(EMPTY_REPLY_RETRIES + 1):
        text, usage = conv["llm"](list(conv["messages"]), temperature, top_p)
        if text.strip():
            break
    else:
        raise RuntimeError(f"OpenRouter returned empty content {EMPTY_REPLY_RETRIES + 1}x at {step}")
    conv["messages"].append({"role": "assistant", "content": text})
    conv["calls"].append({"step": step, "temperature": temperature, "top_p": top_p,
                          "latency_sec": round(time.time() - t0, 2), "usage": usage,
                          "empty_retries": empty})
    return text


# --------------------------------------------------------------------------- FSM check
def parse_fsm(text: str):
    """(fsm dict, parser, error). Upstream hands validate_fsm the raw string (bug 2)."""
    obj, parser, err = None, None, None
    try:
        obj, parser = json.loads(text), "json"
    except ValueError as exc:
        err = str(exc)
        try:
            obj, parser = json_repair.loads(text), "json_repair"
        except Exception:  # noqa: BLE001
            obj = None
    if isinstance(obj, dict) and obj:
        return obj, parser, None
    return None, None, err or f"expected a JSON object, got {type(obj).__name__}"


def graph_check(fsm: dict):
    """Upstream check_reachability_and_cycles; if it crashes (an initial state with no
    transitions is not a graph node, a state without a "transitions" key), redo it with every
    state as a node and a missing transition list read as empty, which is what validate_fsm does."""
    try:
        return fsm_utils.check_reachability_and_cycles(fsm)
    except (nx.NetworkXError, KeyError):
        g = nx.DiGraph()
        g.add_nodes_from(s["name"] for s in fsm["states"])
        for s in fsm["states"]:
            for t in s.get("transitions", []):
                g.add_edge(s["name"], t["target"])
        g.add_node(fsm["initialState"])
        reach = nx.descendants(g, fsm["initialState"]) | {fsm["initialState"]}
        return {s["name"] for s in fsm["states"]} - reach, not nx.is_directed_acyclic_graph(g)


def _set_repr(names) -> str:
    # Upstream prints the Python set; sorted so the message does not depend on hash seed.
    return "{" + ", ".join(repr(n) for n in sorted(names, key=str)) + "}"


def check_fsm(text: str):
    """Upstream check_fsm_format_and_graph's test on one FSM. Returns (fsm, record); the
    record's `issues` are the `###` lines of the repair message (empty = accepted)."""
    fsm, parser, err = parse_fsm(text)
    rec = {"parser": parser, "valid": False, "message": None, "unreachable": None,
           "has_cycle": None, "issues": []}
    if fsm is None:
        rec["issues"] = [f"FSM is not valid JSON: {err}"]
        return None, rec
    try:
        ok, msg = fsm_utils.validate_fsm(fsm)
    except Exception as exc:  # noqa: BLE001 - malformed structure is feedback, not a crash
        ok, msg = False, f"FSM structure error: {type(exc).__name__}: {exc}"
    rec["valid"], rec["message"] = ok, msg
    if not ok:
        rec["issues"].append(msg)
    try:
        unreachable, has_cycle = graph_check(fsm)
    except Exception as exc:  # noqa: BLE001
        if ok:
            rec["issues"].append(f"FSM structure error: {type(exc).__name__}: {exc}")
        return fsm, rec
    rec["unreachable"], rec["has_cycle"] = sorted(unreachable, key=str), bool(has_cycle)
    if unreachable:
        rec["issues"].append(f"List of unreachable states: {_set_repr(unreachable)}")
    if not has_cycle:
        rec["issues"].append("The graph composed of states does not have cycles")
    return fsm, rec


def fsm_repair_message(issues) -> str:
    return FSM_REPAIR_HEADER + "".join(f"\n### {i}" for i in issues)


# --------------------------------------------------------------------------- code, solc, Slither
_FENCE_SOL = re.compile(r"```[ \t]*(?:solidity|sol)\b[^\n]*\n(.*?)```", re.I | re.S)
_FENCE_BARE = re.compile(r"```[ \t]*\n(.*?)```", re.S)


def extract_code(text: str) -> str:
    """Upstream extract_code only matches a lowercase ```solidity fence (bug 5). Take the first
    solidity/sol fence in any case, else the first bare fence, else the whole reply, then apply
    naive_glm's post-processing (drops stray fence and language-tag lines)."""
    m = _FENCE_SOL.search(text) or _FENCE_BARE.search(text)
    return naive._postprocess(m.group(1) if m else text)


def compile_record(res) -> dict:
    errs = list(res.errors)
    return {"is_valid": bool(res.is_valid), "error_count": len(errs),
            "errors": [str(e) for e in errs[:20]]}


def slither_findings(code: str, timeout: float | None = None):
    """Upstream check_one_by_slither's finding set: every detector, drop Informational and
    Optimization, keep the first element of each result, merge overlapping line ranges per
    check type. Returns (findings, None), or (None, error) when Slither cannot analyse the code."""
    binary = _tool_binary("slither", "SLITHER_BIN")
    if binary is None:
        return None, "slither not installed"
    timeout = timeout or float(os.getenv("SECURITY_TIMEOUT_SEC", "180"))
    workdir = Path(tempfile.mkdtemp(prefix="fsm-scg-slither-"))
    path = workdir / "Candidate.sol"
    try:
        path.write_text(code, encoding="utf-8")
        args = [binary, str(path), "--json", "-"]
        solc = _solc_binary_for(code)
        if solc:
            args += ["--solc", solc]
        with _analysis_gate():
            proc = subprocess.run(args, capture_output=True, text=True, timeout=timeout,
                                  cwd=str(workdir))
    except subprocess.TimeoutExpired:
        return None, f"slither timed out after {timeout:g}s"
    finally:
        shutil.rmtree(workdir, ignore_errors=True)

    out = proc.stdout or ""
    brace = out.find("{")
    if brace < 0:
        return None, "slither produced no JSON: " + (proc.stderr or out).strip()[-300:]
    try:
        payload = json.loads(out[brace:])
    except json.JSONDecodeError as exc:
        return None, f"could not parse slither JSON: {exc}"
    if not payload.get("success", True) and not payload.get("results"):
        return None, str(payload.get("error") or "slither could not analyze the contract")[:500]

    check_info = []
    for det in (payload.get("results") or {}).get("detectors") or []:
        if det.get("impact") in ("Informational", "Optimization"):
            continue
        for element in det.get("elements", []):
            lines = (element.get("source_mapping") or {}).get("lines") or []
            check_info.append({
                "check_type": det.get("check"),
                "impact": det.get("impact"),
                "confidence": det.get("confidence"),
                "start_line": lines[0] if lines else 0,
                "end_line": lines[-1] if lines else 0,
                "overall_description": _PATH_NOISE_RE.sub("Candidate.sol", det.get("description", "")),
            })
            break
    return merge_check_items(check_info), None


# --------------------------------------------------------------------------- one seed
def run_seed(sid: str, requirement: str, llm, compile_fn=check_code, slither_fn=slither_findings):
    """Upstream generate_use_fsm_scg for one requirement. Returns (code, fsm, transcript, stats)."""
    conv = {"rng": seed_rng(sid), "llm": llm, "calls": [],
            "messages": [{"role": "system", "content": SYSTEM_PROMPT}]}
    tr = {"fsm_candidates": [], "code_candidates": []}
    prompt_1, prompt_2 = prompt_utils.generate_code_with_fsm_prompt(requirement, SOLIDITY_VERSION)

    # FSM generation and check loop (upstream check_fsm_format_and_graph).
    fsm_text = data_utils.extract_fsm(ask(conv, prompt_1, "fsm"))
    fsm_repairs = 0
    while True:
        fsm, rec = check_fsm(fsm_text)
        tr["fsm_candidates"].append({"repair": fsm_repairs, "text": fsm_text, **rec})
        if not rec["issues"] or fsm_repairs >= 2 * FEEDBACK_COUNT:
            break
        fsm_text = data_utils.extract_fsm(ask(conv, fsm_repair_message(rec["issues"]), "fsm_repair"))
        fsm_repairs += 1

    # Code generation, then compile and security feedback (upstream check_compilation_and_security,
    # unrolled for feedback_count=1; its extra loop pass only re-checks code that did not change).
    code = extract_code(ask(conv, prompt_2, "code"))
    res = compile_fn(code)
    tr["code_candidates"].append({"step": "code", "code": code, "compile": compile_record(res)})
    compile_repairs = 0
    if not res.is_valid:
        reply = ask(conv, prompt_utils.feedback_by_compile_error_prompt(res.format_errors()),
                    "compile_repair")
        code = extract_code(reply)
        res = compile_fn(code)
        compile_repairs = 1
        tr["code_candidates"].append({"step": "compile_repair", "code": code,
                                      "compile": compile_record(res)})

    findings, slither_err = slither_fn(code)
    tr["code_candidates"][-1]["slither"] = {"findings": findings, "error": slither_err}
    security_repairs, fed_back = 0, 0
    if slither_err is not None:
        security_feedback = "slither_error"
    elif findings:
        reply = ask(conv, prompt_utils.feedback_by_security_risk_prompt(findings), "security_repair")
        code = extract_code(reply)
        security_repairs, fed_back, security_feedback = 1, len(findings), "sent"
        tr["code_candidates"].append({"step": "security_repair", "code": code})
    else:
        security_feedback = "none"

    last = tr["fsm_candidates"][-1]
    usage = {}
    for call in conv["calls"]:
        for k, v in (call["usage"] or {}).items():
            if isinstance(v, (int, float)) and not isinstance(v, bool):
                usage[k] = usage.get(k, 0) + v
    stats = {
        "n_calls": len(conv["calls"]),
        "fsm_repairs": fsm_repairs,
        "fsm_parsed_final": last["parser"] is not None,
        "fsm_parser_final": last["parser"],
        "fsm_valid_final": bool(last["valid"]),
        "fsm_unreachable": last["unreachable"],
        "fsm_has_cycle": last["has_cycle"],
        "fsm_accepted": not last["issues"],
        "compile_repairs": compile_repairs,
        "compiled_before_security": bool(res.is_valid),
        "security_repairs": security_repairs,
        "n_slither_findings_fed_back": fed_back,
        "security_feedback": security_feedback,
        "slither_error": slither_err,
        "llm_sec": round(sum(c["latency_sec"] for c in conv["calls"]), 1),
        "usage": usage,
        "solidity_version": SOLIDITY_VERSION,
        "feedback_count": FEEDBACK_COUNT,
        "upstream_commit": UPSTREAM_COMMIT,
    }
    tr["messages"] = conv["messages"]
    tr["calls"] = conv["calls"]
    return code, (fsm if fsm is not None else fsm_text), tr, stats


def build_meta(sid: str, code: str, stats: dict, elapsed: float, domain: str,
               compile_fn=check_code) -> dict:
    """naive_glm/U1/meta.json schema. validation/errors come from a fresh compile of the final
    .sol: it was never compiled in the loop, and score_naive_glm.py trusts this block."""
    res = compile_fn(code) if code else None
    errors = list(res.errors) if res else []
    is_valid = bool(res and res.is_valid)
    return {
        "id": sid,
        "model": MODEL,
        "pipeline": PIPELINE,
        "created": datetime.now().isoformat(),
        "elapsed_sec": round(elapsed, 1),
        "empty_output": not bool(code),
        "nl_prompt_source": "sol_seed_long",
        "nl_source_path": f"sol_seed.jsonl:{sid}",
        "validation": {
            "is_valid": is_valid,
            "error_count": len(errors),
            "syntax_error_count": sum(1 for e in errors if e.is_syntax_error()),
            "semantic_error_count": sum(1 for e in errors if e.is_semantic_error()),
        },
        "errors": [{"line": e.line, "column": e.column, "message": e.message,
                    "severity": e.severity, "code": e.code} for e in errors],
        "category": domain,
        "fsm_scg": stats,
    }


def write_seed(out: Path, sid: str, requirement: str, code: str, fsm, tr: dict, meta: dict):
    out.mkdir(parents=True, exist_ok=True)
    (out / f"{sid}.sol").write_text(code + "\n", encoding="utf-8")
    (out / f"{sid}.txt").write_text(requirement + "\n", encoding="utf-8")
    (out / "fsm.json").write_text(json.dumps(fsm, indent=2, ensure_ascii=False) + "\n",
                                  encoding="utf-8")
    (out / "transcript.json").write_text(json.dumps(tr, indent=2, ensure_ascii=False) + "\n",
                                         encoding="utf-8")
    tmp = out / "meta.json.tmp"      # meta.json is the completion marker: last, atomic
    tmp.write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.replace(tmp, out / "meta.json")


def is_done(out: Path) -> bool:
    try:
        return "validation" in json.loads((out / "meta.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return False


def generate(sid: str, requirement: str, domain: str, out_dir: Path, llm) -> str:
    t0 = time.time()
    code, fsm, tr, stats = run_seed(sid, requirement, llm)
    elapsed = time.time() - t0
    meta = build_meta(sid, code, stats, elapsed, domain)
    write_seed(out_dir / sid, sid, requirement, code, fsm, tr, meta)
    return (f"valid={meta['validation']['is_valid']} calls={stats['n_calls']} "
            f"fsm_rep={stats['fsm_repairs']} cmp_rep={stats['compile_repairs']} "
            f"sec={stats['security_feedback']}({stats['n_slither_findings_fed_back']}) "
            f"{elapsed:.0f}s")


# --------------------------------------------------------------------------- worklist
def load_seeds():
    """[(sid, requirement, domain)] in seed-file order; requirement exactly as naive_glm used it."""
    domains = {}
    for line in SEED_FILE.read_text(encoding="utf-8").splitlines():
        if line.strip():
            row = json.loads(line)
            domains[str(row.get("id"))] = row.get("domain", "unknown")
    return [(sid, req, domains.get(sid, "unknown")) for sid, req in naive._load_seeds()]


def pilot_ids(seeds, n: int) -> list[str]:
    """n seeds stratified by domain: one per domain from the n largest domains (a second round
    if there are fewer domains than n), each the seed with the smallest sha256(id), among seeds
    that already have both a naive_glm and a with_kernel_spec meta.json."""
    ds = _NL2 / "dataset"
    have = [s for s in seeds if (ds / "naive_glm" / s[0] / "meta.json").exists()
            and (ds / "with_kernel_spec" / s[0] / "meta.json").exists()]
    by_dom: dict[str, list[str]] = {}
    for sid, _, dom in have:
        by_dom.setdefault(dom, []).append(sid)
    for ids in by_dom.values():
        ids.sort(key=lambda s: hashlib.sha256(s.encode()).hexdigest())
    order = sorted(by_dom, key=lambda d: (-len(by_dom[d]), d))
    picked, rnd = [], 0
    while len(picked) < n and any(len(by_dom[d]) > rnd for d in order):
        picked += [by_dom[d][rnd] for d in order if len(by_dom[d]) > rnd][: n - len(picked)]
        rnd += 1
    return picked


def parse_args(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--shards", type=int, default=int(os.getenv("FSM_SCG_SHARDS", "1")))
    ap.add_argument("--shard", type=int, default=int(os.getenv("FSM_SCG_SHARD", "0")))
    ap.add_argument("--workers", type=int, default=int(os.getenv("FSM_SCG_WORKERS", "4")),
                    help="seeds in flight (each is one sequential chat)")
    ap.add_argument("--num-entries", type=int, default=1500,
                    help="first N seeds of sol_seed.jsonl (1500 = all, like naive_glm)")
    ap.add_argument("--ids", nargs="+", help="only these seed ids")
    ap.add_argument("--pilot", type=int, metavar="N",
                    help="N seeds stratified by domain (see pilot_ids); overrides --ids")
    ap.add_argument("--output-dir", "--output-root", dest="output_dir",
                    default=os.getenv("FSM_SCG_OUTPUT_DIR") or str(OUT_DEFAULT))
    ap.add_argument("--retries", type=int, default=int(os.getenv("FSM_SCG_RETRIES", "6")),
                    help="transport retries per model call")
    ap.add_argument("--infra-passes", type=int, default=2,
                    help="extra passes over seeds that failed for provider reasons")
    ap.add_argument("--no-resume", dest="resume", action="store_false")
    ap.add_argument("--resume", dest="resume", action="store_true", default=True)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--print-ids", action="store_true",
                    help="print this shard's seed ids (done or not) and exit; the sbatch scores these")
    return ap.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    if args.shards < 1 or not 0 <= args.shard < args.shards:
        print(f"Error: --shard must be in [0, {args.shards - 1}]", file=sys.stderr)
        return 2
    out_dir = Path(args.output_dir)
    seeds = load_seeds()[: args.num_entries]
    if args.pilot:
        wanted = set(pilot_ids(seeds, args.pilot))
    else:
        wanted = set(args.ids) if args.ids else None
    # Position in the seed file decides the shard, as in batch_generate, so a rerun or a
    # different shard count never moves a finished seed.
    todo = [s for i, s in enumerate(seeds)
            if i % args.shards == args.shard and (wanted is None or s[0] in wanted)]
    if args.print_ids:
        print(" ".join(s[0] for s in todo))
        return 0
    done = [s for s in todo if args.resume and is_done(out_dir / s[0])]
    todo = [s for s in todo if s not in done]

    print("=" * 70)
    print(f"FSM-SCG* (prompting variant, upstream {UPSTREAM_COMMIT[:7]}) with {MODEL}")
    print(f"  shard {args.shard + 1}/{args.shards}: {len(todo)} to run, {len(done)} already done")
    print(f"  workers {args.workers}, retries {args.retries}, output {out_dir}")
    print("=" * 70)
    if args.dry_run or not todo:
        print(" ".join(s[0] for s in todo[:40]) + (" ..." if len(todo) > 40 else ""))
        if args.dry_run and todo:
            p1, p2 = prompt_utils.generate_code_with_fsm_prompt(todo[0][1], SOLIDITY_VERSION)
            print(f"\n--- prompt_1 for {todo[0][0]} ---\n{p1}\n--- prompt_2 ---\n{p2}")
        return 0

    key = os.getenv("OPENROUTER_API_KEY")
    if not key:
        print("Error: OPENROUTER_API_KEY not set", file=sys.stderr)
        return 1
    if not is_compiler_available():
        print("Error: solc unavailable; the compile loop needs it (nl2solidity/pace/prestage.sh)",
              file=sys.stderr)
        return 1
    ver = analyzer_version()
    if not ver or not ver.startswith("slither"):
        print("Error: slither unavailable; the security loop needs it", file=sys.stderr)
        return 1
    print(f"  solc ok, {ver}")

    # SLURM forwards TERM before walltime: start no new seeds, let in-flight ones finish.
    signal.signal(signal.SIGTERM, lambda *_: (STOP.set(), print("SIGTERM: draining", flush=True)))
    llm = openrouter_llm(key, args.retries)
    err_dir = out_dir / "_gen_errors"
    out_dir.mkdir(parents=True, exist_ok=True)

    def one(seed):
        sid, req, dom = seed
        if STOP.is_set():
            return seed, "stopped", ""
        try:
            return seed, "ok", generate(sid, req, dom, out_dir, llm)
        except Exception as exc:  # noqa: BLE001 - one seed never stops the shard
            err_dir.mkdir(exist_ok=True)
            (err_dir / f"{sid}.log").write_text(f"{exc}\n\n{traceback.format_exc()}",
                                                encoding="utf-8")
            kind = "infra" if INFRA_ERROR.search(str(exc)) else "error"
            return seed, kind, f"{type(exc).__name__}: {str(exc)[:200]}"

    tally = {"ok": 0, "infra": 0, "error": 0, "stopped": 0}
    for attempt in range(args.infra_passes + 1):
        if attempt:
            print(f"\n-- infra retry pass {attempt}: {len(todo)} seed(s), waiting 60s --", flush=True)
            time.sleep(60)
        failed = []
        with ThreadPoolExecutor(max_workers=max(1, args.workers)) as pool:
            futs = [pool.submit(one, s) for s in todo]
            for n, fut in enumerate(as_completed(futs), 1):
                seed, kind, detail = fut.result()
                if kind == "infra":
                    failed.append(seed)
                else:
                    tally[kind] += 1
                if kind != "stopped":
                    print(f"[{n}/{len(todo)}] {seed[0]}: {kind} {detail}", flush=True)
        todo = failed
        if not todo or STOP.is_set():
            break
    tally["infra"] = len(todo)
    print(f"\nok {tally['ok']}, infra-failed {tally['infra']} (rerun to redo), "
          f"other errors {tally['error']}, not started {tally['stopped']}"
          + (f"; logs in {err_dir}" if tally["infra"] or tally["error"] else ""))
    return 0 if not (tally["infra"] or tally["error"]) else 1


if __name__ == "__main__":
    sys.exit(main())
