#!/usr/bin/env python3
"""Score the naive GLM corpus on every metric the full pipeline records.

`naive_glm_generate.py` only compiles what it generates, so each naive meta.json
carries solc validity and nothing else. The full pipeline's meta.json also holds
Foundry execution, Slither findings, spec alignment and a quality grade, so
`analyze_naive_vs_full.py` can only pair the solc rows. This script closes that
gap by *measuring* the existing naive `.sol` files with the same checkers, at
zero repair passes: the contract text is never changed.

It is ablation arm A0's measurement path (`ablation/profiles.py`, measure_all)
pointed at contracts that already exist, and it calls the generator's own helpers
rather than reimplementing them, so a naive score and a full-pipeline score are
produced by identical code:

    Tier B property tests   agent_rag_moe._generate_property_tests   (combiner, GLM-5.2)
    Foundry fuzz + props    agent_rag_moe._refine_with_kernel          (0 repairs)
    Slither                 agent_rag_moe._refine_with_security        (0 repairs)
    twin-blind aligner      agent_rag_moe._run_post_generation_quality (0 repairs)
    meta.json assembly      batch_generate.create_meta_json

Each finished sample gets `execution`, `security`, `spec_alignment`, `quality`,
`quality_gates` and `category` merged into its meta.json, plus a `scoring` block
recording how. Existing keys (`validation`, `errors`, `elapsed_sec`, ...) are
left exactly as generation wrote them. Reruns skip scored samples, so it is safe
to interrupt and resume, and to shard across PACE tasks.

Cost: one property-test call and a few aligner calls per sample (OpenRouter), and
a Foundry fuzz run per contract that compiles. Use --limit / --ids first.

Usage
    python nl2solidity/score_naive_glm.py --limit 3              # smoke test
    python nl2solidity/score_naive_glm.py --workers 4            # everything
    python nl2solidity/score_naive_glm.py --shards 5 --shard 2   # one PACE task
    python nl2solidity/score_naive_glm.py --dry-run              # list the worklist
"""

from __future__ import annotations

import argparse
import io
import json
import os
import sys
import threading
import time
import traceback
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

_NL2 = Path(__file__).resolve().parent
_ROOT = _NL2.parent
for _p in (str(_ROOT), str(_NL2)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

NAIVE_DEFAULT = _NL2 / "dataset" / "naive_glm"
SEED_DEFAULT = _NL2 / "sol_seed.jsonl"
SCORER = "score_naive_glm.py"


def load_seed_domains(seed_file: Path) -> Dict[str, dict]:
    out: Dict[str, dict] = {}
    if not seed_file.exists():
        return out
    for line in seed_file.read_text(encoding="utf-8").splitlines():
        if line.strip():
            row = json.loads(line)
            out[str(row.get("id"))] = row
    return out


def worklist(naive_dir: Path, ids: Optional[List[str]], shards: int, shard: int,
             limit: Optional[int], rescore: bool) -> List[str]:
    """Sample ids to score, in a stable order. Shard k takes positions where
    `position % shards == k` of the *full* sorted list, so a resumed run puts
    every sample in the same shard it was in before."""
    def natural(sid: str):
        digits = "".join(ch for ch in sid if ch.isdigit())
        return (int(digits) if digits else 0, sid)

    all_ids = sorted((p.parent.name for p in naive_dir.glob("*/meta.json")), key=natural)
    if ids:
        wanted = set(ids)
        all_ids = [s for s in all_ids if s in wanted]
    mine = [s for i, s in enumerate(all_ids) if i % shards == shard]
    if not rescore:
        mine = [s for s in mine if "scoring" not in json.loads(
            (naive_dir / s / "meta.json").read_text(encoding="utf-8"))]
    return mine[:limit] if limit else mine


def build_prompt_record(prompt: str, code: str, stored_valid: bool, stored_errors: int,
                        agent) -> dict:
    """Run the pipeline's checkers once each, at zero repair passes, and return the
    same `prompt_record` shape `generate_solidity_moe` hands to create_meta_json."""
    combiner = agent._active_combiner_model()
    _, key = agent._load_env()
    record: Dict[str, Any] = {
        "ablation": "A0-scored",
        "ablation_stages": agent.active_stage_config(),
        "final_valid": stored_valid,
        "final_errors": stored_errors,
        "spec_alignment_enabled": agent._env_flag("SPEC_ALIGNMENT_ENABLED", True),
        "kernel_feedback_enabled": agent._env_flag("KERNEL_FEEDBACK_ENABLED", True),
        "security_analysis_enabled": agent.SECURITY_ANALYSIS_ENABLED,
        "property_tests_enabled": agent.PROPERTY_TESTS_ENABLED,
    }

    # Tier B: properties are written once, against the requirement.
    property_tests, property_record = "", {"requested": False, "generated": False}
    if (record["kernel_feedback_enabled"] and agent.KERNEL_EXECUTION_AVAILABLE
            and agent.PROPERTY_TESTS_ENABLED):
        property_tests, property_record = agent._generate_property_tests(
            prompt, code, combiner, key)
    record["property_tests"] = property_record

    # Foundry fuzz + property tiers. max_iterations=0 => measure, never repair.
    kernel_result = None
    if record["kernel_feedback_enabled"] and agent.KERNEL_EXECUTION_AVAILABLE:
        _, kernel_result = agent._refine_with_kernel(
            code, combiner, "", "", key, 0, property_tests=property_tests or None)
    if kernel_result is not None:
        diagnostics = kernel_result.diagnostics or {}
        record["kernel_compiled"] = kernel_result.compiled
        record["kernel_available"] = kernel_result.kernel_available
        record["execution_tier_status"] = kernel_result.tier_status
        record["execution_harness_notes"] = kernel_result.harness_notes
        record["execution_tests"] = {
            "n_tests": diagnostics.get("n_tests"),
            "n_passed": diagnostics.get("n_passed"),
            "n_failed": diagnostics.get("n_failed"),
            "failure_classes": diagnostics.get("failure_classes"),
            "contract_defects": diagnostics.get("contract_defects"),
            "harness_defects": diagnostics.get("harness_defects"),
            "fuzz_runs": agent.FUZZ_RUNS,
        }

    # Slither.
    if record["security_analysis_enabled"]:
        from nl2solidity.security_analysis import summarize
        _, security_result = agent._refine_with_security(code, combiner, "", "", key, 0)
        if security_result is not None:
            record["security_analysis"] = summarize(security_result)

    # Twin-blind spec alignment (max_repairs=0 via the A0 measure-only profile).
    if record["spec_alignment_enabled"]:
        report = agent._run_post_generation_quality(
            prompt, code, key, property_tests or None)
        if not report:
            raise RuntimeError("spec alignment returned no quality report")
        if report.get("error"):
            raise RuntimeError(f"spec alignment error: {report['error']}")
        record["quality_report"] = report

    record["_combiner"] = combiner
    return record


def score_one(sid: str, naive_dir: Path, seeds: Dict[str, dict], agent, batch) -> str:
    entry_dir = naive_dir / sid
    meta_path = entry_dir / "meta.json"
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    code = (entry_dir / f"{sid}.sol").read_text(encoding="utf-8")
    prompt = (entry_dir / f"{sid}.txt").read_text(encoding="utf-8").strip()
    if not code.strip():
        raise RuntimeError("empty .sol; nothing to score")

    validation = meta.get("validation") or {}
    started = time.time()
    record = build_prompt_record(
        prompt, code,
        stored_valid=bool(validation.get("is_valid")),
        stored_errors=int(validation.get("error_count", 0)),
        agent=agent)
    combiner = record.pop("_combiner")

    seed = seeds.get(sid, {})
    entry = {"id": sid, "domain": seed.get("domain", "unknown"),
             "nl_prompt_source": meta.get("nl_prompt_source", "sol_seed_long"),
             "nl_source_path": meta.get("nl_source_path")}
    scored = batch.create_meta_json(entry, code, record)

    for key in ("quality", "quality_gates", "category", "execution", "security",
                "spec_alignment"):
        if key in scored:
            meta[key] = scored[key]
    meta["scoring"] = {
        "tool": SCORER,
        "mode": "measure_only",
        "repair_passes": 0,
        "combiner_model": combiner,
        "elapsed_sec": round(time.time() - started, 1),
        "scored_at": datetime.now().isoformat(timespec="seconds"),
        "validation_source": "generation-time solc (not re-run)",
    }
    tmp = meta_path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.replace(tmp, meta_path)

    ex = meta.get("execution") or {}
    sec = meta.get("security") or {}
    al = meta.get("spec_alignment") or {}
    return (f"valid={validation.get('is_valid')} compiled={ex.get('compiled')} "
            f"tiers={ex.get('tier_status')} defects={ex.get('contract_defects')} "
            f"slither_actionable={sec.get('n_actionable')} sim={al.get('similarity')} "
            f"grade={meta.get('quality')}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--naive-dir", default=str(NAIVE_DEFAULT))
    ap.add_argument("--seed-file", default=str(SEED_DEFAULT),
                    help="sol_seed.jsonl, only used to recover each sample's domain")
    ap.add_argument("--workers", type=int, default=int(os.getenv("BATCH_WORKERS", "4")))
    ap.add_argument("--shards", type=int, default=1)
    ap.add_argument("--shard", type=int, default=0)
    ap.add_argument("--limit", type=int, help="score at most this many (smoke test)")
    ap.add_argument("--ids", nargs="+", help="score only these sample ids")
    ap.add_argument("--rescore", action="store_true",
                    help="re-measure samples that already carry a `scoring` block")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not 0 <= args.shard < args.shards:
        print(f"--shard must be in [0, {args.shards - 1}]", file=sys.stderr)
        return 2
    naive_dir = Path(args.naive_dir)
    if not any(naive_dir.glob("*/meta.json")):
        print(f"No naive corpus at {naive_dir}", file=sys.stderr)
        return 1

    todo = worklist(naive_dir, args.ids, args.shards, args.shard, args.limit, args.rescore)
    print(f"{len(todo)} sample(s) to score in {naive_dir} "
          f"(shard {args.shard + 1}/{args.shards}, {args.workers} workers)")
    if args.dry_run or not todo:
        print(", ".join(todo[:20]) + (" ..." if len(todo) > 20 else ""))
        return 0

    # Measure-only flags must be in os.environ before agent_rag_moe is imported:
    # several stage switches are module-level constants read at import time.
    assert "agent_rag_moe" not in sys.modules
    from ablation import profiles
    applied = profiles.apply("A0", measure_all=True)
    print("stage flags:", ", ".join(f"{k}={v}" for k, v in sorted(applied.items())
                                    if k.endswith("_ENABLED") or "REPAIRS" in k
                                    or "ITERATIONS" in k))

    import agent_rag_moe as agent  # noqa: PLC0415  (deliberately deferred)
    import batch_generate as batch  # noqa: PLC0415

    seeds = load_seed_domains(Path(args.seed_file))
    err_dir = naive_dir / "_score_errors"
    real_stdout = sys.stdout
    routed = batch._ThreadRoutedStdout(real_stdout) if args.workers > 1 else None
    if routed is not None:
        sys.stdout = routed
    lock = threading.Lock()
    tally = {"ok": 0, "error": 0}

    def run(sid: str) -> tuple[str, str, str]:
        buf = io.StringIO()
        if routed is not None:
            routed.set_buffer(buf)
        try:
            return sid, "ok", score_one(sid, naive_dir, seeds, agent, batch)
        except Exception as exc:  # noqa: BLE001 - one bad sample must not stop the run
            err_dir.mkdir(exist_ok=True)
            (err_dir / f"{sid}.log").write_text(
                f"{exc}\n\n{traceback.format_exc()}", encoding="utf-8")
            return sid, "error", str(exc)
        finally:
            if routed is not None:
                routed.clear_buffer()

    try:
        with ThreadPoolExecutor(max_workers=max(1, args.workers)) as pool:
            futures = [pool.submit(run, sid) for sid in todo]
            for done, fut in enumerate(as_completed(futures), 1):
                sid, status, detail = fut.result()
                with lock:
                    tally[status] += 1
                    print(f"[{done}/{len(todo)}] {sid}: {status}  {detail}",
                          file=real_stdout, flush=True)
    except KeyboardInterrupt:
        print("\ninterrupted; finished samples are saved, rerun to resume",
              file=real_stdout)
    finally:
        sys.stdout = real_stdout

    print(f"\nscored {tally['ok']}, failed {tally['error']}"
          + (f" (see {err_dir})" if tally["error"] else ""))
    return 0 if not tally["error"] else 1


if __name__ == "__main__":
    sys.exit(main())
