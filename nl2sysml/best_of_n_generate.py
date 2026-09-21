#!/usr/bin/env python3
"""Best-of-N sampling baseline for SysML: N samples of the naive GLM-5.2 call, pick one by compiler.

Answers the compute-fairness question "does the harness beat plain best-of-N sampling from the
same cheap model, scored by the same compiler?". FORGE spends several model calls per requirement
(experts + combiner + repair); this baseline spends the same budget on N independent one-shot
samples of the naive baseline and keeps whichever one the SysML compiler likes best. It has no
retrieval, no experts, no combiner, no repair loop and no feedback of any kind.

Everything that defines the sample is imported from naive_glm_generate.py, not copied: the model,
the system prompt, the human template, the prompt set, the post-processing and the degenerate-output
retry. A best-of-1 run of this script is therefore the naive arm, and the only thing N changes is N.

Selection rule (deterministic, compiler-only, no oracle):
    1. a candidate that compiles cleanly beats any that does not;
    2. otherwise the fewest DE-DUPLICATED compiler errors (the parser jar reports every syntax error
       twice, see recompute_sysml_stats.py; raw counts are stored too);
    3. empty and compiler-timeout candidates rank below every candidate the compiler actually scored
       (an empty file has "0 errors" and must not win on that);
    4. ties go to the lowest sample index.

Output layout matches naive_glm, so the existing comparison tooling reads it unchanged:
    dataset/best_of_<N>/<ID>/<ID>.sysml     the selected candidate
    dataset/best_of_<N>/<ID>/<ID>.txt       the prompt
    dataset/best_of_<N>/<ID>/meta.json      naive-compatible fields + a `best_of_n` block
    dataset/best_of_<N>/<ID>/candidates/    every sample, for audit

The `best_of_n` block records every candidate's compile result, so pass@k style numbers
(any-of-N valid, mean per-sample validity) fall out of meta.json with no rerun. The mean per-sample
validity over candidates is the naive rate measured with N times the data.

Parallelism: one process per seed (SIGALRM compile timeouts need a main thread, the same reason
recompute_sysml_stats.py uses processes), N threads inside it for the API calls. Shard k of S takes
seeds at sorted positions p with p % S == k, so SLURM array tasks are disjoint; rerunning resumes.

Examples
    python nl2sysml/best_of_n_generate.py --dry-run --limit 10
    python nl2sysml/best_of_n_generate.py --n 6 --workers 6 --shards 5 --shard 2
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
from concurrent.futures import FIRST_COMPLETED, ProcessPoolExecutor, ThreadPoolExecutor, wait
from datetime import datetime
from pathlib import Path
from typing import Optional

_NL2 = Path(__file__).resolve().parent
_ROOT = _NL2.parent
for _p in (str(_ROOT), str(_NL2)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from dotenv import load_dotenv  # noqa: E402

load_dotenv(_ROOT / ".env")

import naive_glm_generate as naive  # noqa: E402  (the baseline this script samples N times)

DEFAULT_N = 6
DEFAULT_COMPILE_TIMEOUT = 120  # seconds; the naive script's 60 s is too tight for a 6x workload


# --------------------------------------------------------------------------- selection
def dedup_error_count(errors: list[dict]) -> int:
    """Unique (line, column, message) triples. The jar double-reports syntax errors."""
    return len({(e.get("line"), e.get("column"), e.get("message")) for e in errors})


def rank_key(cand: dict) -> tuple:
    """Sort key; the minimum is the selected candidate. See the module docstring."""
    scored = not (cand.get("empty") or cand.get("timeout") or cand.get("error"))
    return (
        not cand.get("is_valid", False),   # valid first
        not scored,                        # compiler actually scored it
        cand.get("unique_error_count", 0) if scored else 0,
        cand["index"],
    )


def select_best(candidates: list[dict]) -> Optional[dict]:
    """Best candidate by the compiler, or None when there are no candidates at all."""
    return min(candidates, key=rank_key) if candidates else None


# --------------------------------------------------------------------------- one candidate
def _sample_code(prompt: str, key: str) -> tuple[str, int]:
    """One naive-arm sample: (post-processed code, model calls spent). Mirrors
    naive_glm_generate.generate_one, including its single degenerate-output retry."""
    import agent_rag_moe as transport  # hardened OpenRouter transport shared with FORGE

    human = naive.HUMAN_TEMPLATE.format(input=prompt)
    calls = 1
    code = naive._postprocess(transport._openrouter_invoke(naive.MODEL, naive.SYSTEM_PROMPT, human, key))
    if not code or not any(kw in code.lower() for kw in ("package", "part", "attribute")):
        strong = naive.SYSTEM_PROMPT + " No markdown, no fences, no prose. Output SysML v2 code only."
        code = naive._postprocess(transport._openrouter_invoke(naive.MODEL, strong, human, key))
        calls += 1
    return code, calls


class _CompileTimeout(Exception):
    pass


def _compile(code: str, timeout: int) -> dict:
    """Compile with the same checker the naive arm used. Must run on a process's main thread."""
    from compiler_interface import check_code

    out = {"is_valid": False, "errors": [], "timeout": False}
    if not code:
        return out

    def _alarm(signum, frame):
        raise _CompileTimeout()

    old = signal.signal(signal.SIGALRM, _alarm)
    signal.alarm(timeout)
    try:
        res = check_code(code)
        out["is_valid"] = res.is_valid
        out["errors"] = [
            {"line": e.line, "column": e.column, "message": e.message,
             "severity": e.severity, "code": e.code,
             "syntax": bool(e.is_syntax_error()), "semantic": bool(e.is_semantic_error())}
            for e in res.errors
        ]
    except _CompileTimeout:
        out["timeout"] = True
    finally:
        signal.alarm(0)
        signal.signal(signal.SIGALRM, old)
    return out


def run_seed(job: dict) -> dict:
    """Worker-process entry point: sample N, compile N, select. Returns plain data only."""
    sid, prompt, n, key = job["sid"], job["prompt"], job["n"], job["key"]
    os.environ["SYSML_COMPILER_MAX_CONCURRENCY"] = "1"  # one JVM per worker process
    t0 = time.time()

    # I/O-bound: all N API calls in flight at once. The transport's own gate caps concurrency.
    def sample(i: int):
        try:
            return i, _sample_code(prompt, key), None
        except Exception as exc:  # noqa: BLE001 - a failed sample is data, not a crash
            return i, ("", 1), f"{type(exc).__name__}: {exc}"

    with ThreadPoolExecutor(max_workers=n) as pool:
        drawn = sorted(pool.map(sample, range(n)), key=lambda r: r[0])

    candidates = []
    for i, (code, calls), err in drawn:
        c_t0 = time.time()
        compiled = _compile(code, job["compile_timeout"])
        errors = compiled["errors"]
        candidates.append({
            "index": i,
            "code": code,
            "sha256": hashlib.sha256(code.encode("utf-8")).hexdigest()[:16],
            "empty": not code,
            "error": err,                       # transport failure for this sample, if any
            "timeout": compiled["timeout"],
            "is_valid": compiled["is_valid"],
            "error_count": len(errors),         # raw, as the naive arm's meta.json counts it
            "unique_error_count": dedup_error_count(errors),
            "syntax_error_count": sum(e["syntax"] for e in errors),
            "semantic_error_count": sum(e["semantic"] for e in errors),
            "errors": errors,
            "model_calls": calls,
            "compile_sec": round(time.time() - c_t0, 1),
        })

    return {"sid": sid, "candidates": candidates, "elapsed_sec": round(time.time() - t0, 1)}


# --------------------------------------------------------------------------- output
def build_meta(sid: str, n: int, result: dict, chosen: dict) -> dict:
    cands = result["candidates"]
    return {
        "id": sid,
        "model": naive.MODEL,
        "pipeline": f"best_of_{n}_single_model",
        "created": datetime.now().isoformat(),
        "elapsed_sec": result["elapsed_sec"],
        "empty_output": chosen["empty"],
        "validation": {
            "is_valid": chosen["is_valid"],
            "error_count": chosen["error_count"],
            "syntax_error_count": chosen["syntax_error_count"],
            "semantic_error_count": chosen["semantic_error_count"],
        },
        "errors": [
            {k: e[k] for k in ("line", "column", "message", "severity", "code")}
            for e in chosen["errors"]
        ],
        **({"compiler_timeout": True} if chosen["timeout"] else {}),
        "best_of_n": {
            "n": n,
            "selection_rule": "valid > compiler-scored > fewest unique errors > lowest index",
            "selected_index": chosen["index"],
            "selected_unique_error_count": chosen["unique_error_count"],
            "n_valid": sum(c["is_valid"] for c in cands),
            "any_valid": any(c["is_valid"] for c in cands),
            "n_distinct": len({c["sha256"] for c in cands if not c["empty"]}),
            "n_empty": sum(c["empty"] for c in cands),
            "n_transport_failures": sum(bool(c["error"]) for c in cands),
            "n_timeouts": sum(c["timeout"] for c in cands),
            "n_model_calls": sum(c["model_calls"] for c in cands),
            "candidates": [
                {k: c[k] for k in (
                    "index", "sha256", "is_valid", "error_count", "unique_error_count",
                    "syntax_error_count", "semantic_error_count", "empty", "timeout",
                    "error", "model_calls", "compile_sec")}
                for c in cands
            ],
        },
    }


def write_seed(out_dir: Path, sid: str, prompt: str, n: int, result: dict) -> dict:
    """Write one seed's directory. meta.json goes last: it is the completion marker."""
    chosen = select_best(result["candidates"])
    seed_dir = out_dir / sid
    (seed_dir / "candidates").mkdir(parents=True, exist_ok=True)
    for c in result["candidates"]:
        (seed_dir / "candidates" / f"cand-{c['index']}.sysml").write_text(
            c["code"] + "\n", encoding="utf-8")
    (seed_dir / f"{sid}.sysml").write_text(chosen["code"] + "\n", encoding="utf-8")
    (seed_dir / f"{sid}.txt").write_text(prompt + "\n", encoding="utf-8")
    meta = build_meta(sid, n, result, chosen)
    (seed_dir / "meta.json").write_text(
        json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return meta


# --------------------------------------------------------------------------- driver
def shard_ids(ids: list[str], shards: int, shard: int) -> list[str]:
    """Positions p with p % shards == shard over the sorted id list: disjoint and complete."""
    return [sid for pos, sid in enumerate(ids) if pos % shards == shard]


def _parse_args(argv=None):
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--n", type=int, default=DEFAULT_N, help=f"samples per seed (default {DEFAULT_N})")
    p.add_argument("--workers", type=int, default=int(os.getenv("BATCH_WORKERS", "4")),
                   help="seeds in flight at once (one process each)")
    p.add_argument("--shards", type=int, default=int(os.getenv("BON_SHARDS", "1")))
    p.add_argument("--shard", type=int, default=int(os.getenv("BON_SHARD", "0")))
    p.add_argument("--limit", type=int, default=None,
                   help="first LIMIT seeds of the sorted id list (default all); identical for all arms")
    p.add_argument("--out-dir", type=Path, default=None,
                   help="default dataset/best_of_<N>")
    p.add_argument("--compile-timeout", type=int,
                   default=int(os.getenv("SYSML_COMPILE_TIMEOUT", DEFAULT_COMPILE_TIMEOUT)))
    p.add_argument("--no-resume", action="store_true", help="regenerate seeds that already have output")
    p.add_argument("--dry-run", action="store_true", help="print this shard's worklist and exit")
    return p.parse_args(argv)


def main(argv=None) -> int:
    args = _parse_args(argv)
    if args.n < 1:
        print("Error: --n must be >= 1", file=sys.stderr)
        return 2
    if args.shards < 1 or not 0 <= args.shard < args.shards:
        print(f"Error: --shard must be in [0, {args.shards - 1}]", file=sys.stderr)
        return 2

    out_dir = args.out_dir or (_ROOT / "dataset" / f"best_of_{args.n}")
    ids = naive._get_sample_ids()
    if args.limit is not None:
        ids = ids[:args.limit]
    mine = shard_ids(ids, args.shards, args.shard)
    todo = [s for s in mine if args.no_resume or not (out_dir / s / "meta.json").exists()]

    print("=" * 70)
    print(f"SysML best-of-{args.n} | model {naive.MODEL} | selector: SysML compiler")
    print(f"  eval set:  {len(ids)} seeds (same id list as the naive arm)")
    print(f"  shard:     {args.shard + 1}/{args.shards} -> {len(mine)} seeds, {len(todo)} to do")
    print(f"  workers:   {args.workers} seeds x {args.n} samples in flight")
    print(f"  output:    {out_dir}")
    print("=" * 70)
    if args.dry_run:
        for s in todo[:20]:
            print("  ", s)
        if len(todo) > 20:
            print(f"   ... {len(todo) - 20} more")
        return 0

    key = os.getenv("OPENROUTER_API_KEY")
    if not key:
        print("Error: OPENROUTER_API_KEY not set", file=sys.stderr)
        return 1
    from compiler_interface import is_compiler_available
    if not is_compiler_available():
        print("Error: SysML compiler unavailable (java / parser jar). Best-of-N is "
              "selected by the compiler, so there is nothing to run without it.", file=sys.stderr)
        return 1

    out_dir.mkdir(parents=True, exist_ok=True)
    stop = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: (print("SIGTERM: draining in-flight seeds", flush=True),
                                              stop.set()))

    prompts: dict[str, str] = {}
    queue = []
    for sid in todo:
        prompt = naive._read_prompt(sid)
        if prompt:
            prompts[sid] = prompt
            queue.append(sid)
        else:
            print(f"  {sid}: no prompt, skipping")

    stats = {"done": 0, "valid": 0, "any_valid": 0, "errors": 0}
    t_start = time.time()
    pending: dict = {}
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        it = iter(queue)

        def submit_next() -> bool:
            if stop.is_set():
                return False
            sid = next(it, None)
            if sid is None:
                return False
            job = {"sid": sid, "prompt": prompts[sid], "n": args.n, "key": key,
                   "compile_timeout": args.compile_timeout}
            pending[pool.submit(run_seed, job)] = sid
            return True

        for _ in range(args.workers):
            if not submit_next():
                break
        try:
            while pending:
                finished, _ = wait(pending, return_when=FIRST_COMPLETED)
                for fut in finished:
                    sid = pending.pop(fut)
                    try:
                        result = fut.result()
                        meta = write_seed(out_dir, sid, prompts[sid], args.n, result)
                    except Exception as exc:  # noqa: BLE001
                        stats["errors"] += 1
                        print(f"[{sid}] ERROR: {type(exc).__name__}: {exc}", flush=True)
                        submit_next()
                        continue
                    b = meta["best_of_n"]
                    stats["done"] += 1
                    stats["valid"] += meta["validation"]["is_valid"]
                    stats["any_valid"] += b["any_valid"]
                    status = "valid" if meta["validation"]["is_valid"] else \
                        f"{b['selected_unique_error_count']} errors"
                    print(f"[{sid}] {status} | {b['n_valid']}/{args.n} samples valid | "
                          f"{meta['elapsed_sec']}s", flush=True)
                    submit_next()
        except KeyboardInterrupt:
            print("\nInterrupted; in-flight seeds are discarded and will rerun on resume.")
            stop.set()
            for fut in pending:
                fut.cancel()

    print("=" * 70)
    print(f"Done {stats['done']} in {time.time() - t_start:.0f}s | selected valid {stats['valid']} | "
          f"any-of-{args.n} valid {stats['any_valid']} | errors {stats['errors']}")
    return 1 if stats["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())
