#!/usr/bin/env python3
"""Best-of-N sampling baseline for Solidity: N samples of the A0 one-shot call, `solc` picks one.

Answers the compute-fairness question "does the harness beat plain best-of-N sampling from the
same cheap model, scored by the same compiler?". It is a drop-in REPLACEMENT for the naive GLM data
(`dataset/naive_glm`, from naive_glm_generate.py) over all seeds: FORGE spends several model calls per
requirement; this spends the same budget on N independent samples of the naive call and keeps the
one `solc` likes best. It is not part of the ablation ladder.

How it stays comparable
-----------------------
The N samples are naive_glm_generate.py's call, imported not copied: its model, system prompt, human
template and post-processing, over the same seed_long prompts. So best-of-1 is the naive arm. To
score the winner with every metric the other corpora carry, the script drives the ordinary generator
(`batch_generate.py` -> `generate_solidity_moe`) with every generation and repair stage off
(bare requirement, no RAG / experts / repair) and fans its single initial model call out into N
samples, each compiled with the same `check_code` its compile stage uses. The winner is returned in
that call's place, and every downstream stage then runs on it measure-only (Foundry fuzz +
requirement-derived properties, Slither, twin-blind spec alignment, zero repair passes), so
`meta.json` carries the same fields as `naive_glm` and `with_kernel_spec` and
`analyze_naive_vs_full.py` reads it unchanged. (`--prompt-template a0` samples the ablation A0
prompt instead, for a like-for-like with that arm; the default is the naive one.)

Selection rule (deterministic; the compiler is the only judge; nothing sees Foundry/Slither/aligner):
    1. a contract that compiles cleanly beats any that does not;
    2. otherwise the fewest `solc` errors;
    3. ties go to the lowest sample index.
Samples whose call failed (provider error, empty or degenerate reply) are not candidates.

The interception matches the initial call by exact (system, human) message equality and is
thread-local, so repair, property-test and alignment calls, and other seeds running in parallel
worker threads, are never touched. If the generator ever stops making that call the run fails loudly
rather than silently degrading to best-of-1.

Output: <output-root>/BoN<N>/U###/{U###.sol, U###.txt, meta.json, candidates/cand-k.sol}
Default eval set: ALL 1500 seeds of sol_seed.jsonl, the same set as naive_glm and with_kernel_spec.
`meta.json` gains a `best_of_n` block listing every candidate's compile result, so any-of-N and
mean-per-sample validity come straight out of the data.

Examples
    python nl2solidity/best_of_n/run_best_of_n.py --shards 15 --shard 0 --dry-run
    python nl2solidity/best_of_n/run_best_of_n.py --n 6 --shards 15 --shard 3
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any, Callable, Optional

_HERE = Path(__file__).resolve().parent
_NL2 = _HERE.parent
_ROOT = _NL2.parent
for _path in (str(_ROOT), str(_NL2), str(_NL2 / "ablation")):
    if _path not in sys.path:
        sys.path.insert(0, _path)

DEFAULT_N = 6
DEFAULT_NUM_ENTRIES = 1500          # every seed in sol_seed.jsonl, like naive_glm / with_kernel_spec
BASE_ARM = "A0"                    # a stage-flag profile only: everything off, measure-only
# Provider/transport failures (rate limit, exhausted credits, dropped connection, missing key). These
# are infrastructure, not model outcomes: the seed must be redone, never scored on a partial ensemble.
INFRA_ERROR = re.compile(
    r"OpenRouter call failed|OpenRouter error|OpenRouter returned|OPENROUTER_API_KEY missing"
    r"|IncompleteRead|Timeout|timed out|Connection", re.I)
SELECTION_RULE = "compiles cleanly > fewest solc errors > lowest sample index"


# --------------------------------------------------------------------------- selection
def rank_key(cand: dict) -> tuple:
    """Sort key; the minimum is the selected candidate."""
    return (not cand["is_valid"], cand["error_count"], cand["index"])


def select_best(candidates: list[dict]) -> Optional[dict]:
    return min(candidates, key=rank_key) if candidates else None


def _sha(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()[:16]


# --------------------------------------------------------------------------- the hook
class BestOfN:
    """Fans the generator's initial generation call out into N compiler-ranked samples.

    `install()` rebinds three names on the already-imported modules; nothing on disk changes.
    """

    def __init__(self, amoe: Any, n: int,
                 check: Optional[Callable[[str], Any]] = None,
                 template: str = "naive", naive: Any = None):
        if n < 1:
            raise ValueError("n must be >= 1")
        if template not in ("naive", "a0"):
            raise ValueError("template must be 'naive' or 'a0'")
        self.amoe = amoe
        self.n = n
        self.template = template
        self._naive = naive
        self._check = check
        self._real_invoke = amoe._invoke_with_retry
        self._real_generate = amoe.generate_solidity_moe
        self._local = threading.local()

    # -- compile -----------------------------------------------------------
    def _compile(self, code: str):
        if self._check is not None:
            return self._check(code)
        # Exactly the call _refine_with_compiler makes for its final verdict.
        return self.amoe.check_code(code, syntax_only=self.amoe.COMPILER_SYNTAX_ONLY)

    # -- the fan-out -------------------------------------------------------
    def _draw_naive(self, prompt: str, key) -> str:
        """One sample of naive_glm_generate.generate_one's model call, incl. its degenerate retry."""
        naive = self._naive
        human = naive.HUMAN_TEMPLATE.format(input=prompt)
        invoke = self.amoe._openrouter_invoke      # FORGE's hardened transport, same model/temp
        code = naive._postprocess(invoke(naive.MODEL, naive.SYSTEM_PROMPT, human, key))
        if not code or not any(kw in code.lower() for kw in ("contract", "pragma")):
            strong = naive.SYSTEM_PROMPT + " No markdown, no fences, no prose. Output Solidity code only."
            code = naive._postprocess(invoke(naive.MODEL, strong, human, key))
        if not code:
            raise RuntimeError("empty response after the degenerate-output retry")
        return code

    def _sample(self, ctx: dict, model: str, system: str, human: str, key) -> str:
        def draw(i: int):
            try:
                if self.template == "naive":
                    return i, self._draw_naive(ctx["prompt"], key), None
                return i, self._real_invoke(model, system, human, key), None
            except Exception as exc:  # noqa: BLE001 - a failed sample is data, not a crash
                return i, None, f"{type(exc).__name__}: {exc}"

        # N calls in flight; the transport's own OPENROUTER_MAX_CONCURRENCY gate caps them.
        with ThreadPoolExecutor(max_workers=self.n) as pool:
            drawn = sorted(pool.map(draw, range(self.n)), key=lambda r: r[0])

        candidates, failures = [], []
        for i, code, err in drawn:
            if err is not None:
                failures.append({"index": i, "error": err})
                continue
            res = self._compile(code)
            errors = list(res.errors)
            candidates.append({
                "index": i,
                "code": code,
                "sha256": _sha(code),
                "is_valid": bool(res.is_valid),
                "error_count": len(errors),
                "syntax_error_count": sum(1 for e in errors if e.is_syntax_error()),
                "semantic_error_count": sum(1 for e in errors if e.is_semantic_error()),
            })
        infra = [f for f in failures if INFRA_ERROR.search(f["error"])]
        if infra:
            # A partial ensemble is never kept: it would be written as a complete seed and skipped on
            # resume. Raising soft-fails the seed (no meta.json), so a rerun redoes exactly it.
            raise RuntimeError(
                f"best-of-{self.n}: {len(infra)}/{self.n} samples hit a transport failure "
                f"({infra[0]['error'][:120]}); not keeping a partial ensemble")
        chosen = select_best(candidates)
        if chosen is None:
            raise RuntimeError(
                f"best-of-{self.n}: all {self.n} samples failed: "
                + "; ".join(f["error"][:120] for f in failures[:3]))

        ctx["record"] = {
            "n": self.n,
            "sample_template": self.template,
            "selection_rule": SELECTION_RULE,
            "selected_index": chosen["index"],
            "selected_error_count": chosen["error_count"],
            "n_candidates": len(candidates),
            "n_transport_failures": len(failures),
            "n_valid": sum(c["is_valid"] for c in candidates),
            "any_valid": any(c["is_valid"] for c in candidates),
            "n_distinct": len({c["sha256"] for c in candidates}),
            "candidates": [{k: v for k, v in c.items() if k != "code"} for c in candidates],
            "failures": failures,
            "codes": {c["index"]: c["code"] for c in candidates},   # popped before meta.json
        }
        return chosen["code"]

    # -- replacement for agent_rag_moe._invoke_with_retry -------------------
    def invoke(self, model: str, system_msg: str, human_msg: str, key):
        ctx = getattr(self._local, "ctx", None)
        if (ctx is not None and not ctx["fired"]
                and model == ctx["model"]
                and system_msg == ctx["system"] and human_msg == ctx["human"]):
            ctx["fired"] = True
            return self._sample(ctx, model, system_msg, human_msg, key)
        return self._real_invoke(model, system_msg, human_msg, key)

    # -- replacement for agent_rag_moe.generate_solidity_moe ----------------
    def generate(self, prompt_text: str):
        amoe = self.amoe
        experts = amoe._active_expert_models()
        if experts or amoe._env_flag("RAG_ENABLED", True):
            raise RuntimeError(
                "best-of-N samples the A0 one-shot arm; RAG/MoE must be off "
                f"(experts={experts}, RAG={amoe._env_flag('RAG_ENABLED', True)})")
        root = Path(amoe.__file__).parent.parent
        context = amoe._rag_context(prompt_text, root, k=3)
        ctx = {
            "prompt": prompt_text,
            "fired": False,
            "model": amoe._active_combiner_model(),
            "system": amoe._default_system_prompt(None),
            "human": amoe.PROMPT_HUMAN_TEMPLATE.format(context=context, input=prompt_text),
            "record": None,
        }
        self._local.ctx = ctx
        try:
            code, record = self._real_generate(prompt_text)
        finally:
            self._local.ctx = None
        if not ctx["fired"] or ctx["record"] is None:
            raise RuntimeError(
                "best-of-N hook never saw the generator's initial call: generate_solidity_moe "
                "changed shape. Refusing to report a best-of-1 run as best-of-N.")
        record["best_of_n"] = ctx["record"]
        return code, record

    def install(self, batch_generate: Any) -> None:
        self.amoe._invoke_with_retry = self.invoke
        self.amoe.generate_solidity_moe = self.generate

        real_create_meta = batch_generate.create_meta_json
        real_write = batch_generate.write_entry_output

        def create_meta_json(entry, solidity_code, prompt_record):
            meta = real_create_meta(entry, solidity_code, prompt_record)
            block = prompt_record.get("best_of_n")
            if block:
                meta["best_of_n"] = {k: v for k, v in block.items() if k != "codes"}
            return meta

        def write_entry_output(entry_dir, entry, solidity_code, prompt_record):
            # Candidates first: meta.json is the completion marker and must land last.
            codes = (prompt_record.get("best_of_n") or {}).get("codes") or {}
            if codes:
                cdir = Path(entry_dir) / "candidates"
                cdir.mkdir(parents=True, exist_ok=True)
                for idx, code in codes.items():
                    (cdir / f"cand-{idx}.sol").write_text(code.strip() + "\n", encoding="utf-8")
            real_write(entry_dir, entry, solidity_code, prompt_record)

        batch_generate.create_meta_json = create_meta_json
        batch_generate.write_entry_output = write_entry_output


# --------------------------------------------------------------------------- CLI
def _parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--n", type=int, default=int(os.getenv("BON_N", DEFAULT_N)),
                        help=f"samples per seed (env BON_N, default {DEFAULT_N})")
    parser.add_argument("--shards", type=int, default=int(os.getenv("BON_SHARDS", "15")))
    parser.add_argument("--shard", type=int, default=int(os.getenv("BON_SHARD", "0")))
    parser.add_argument("--num-entries", type=int,
                        default=int(os.getenv("BON_NUM_ENTRIES", DEFAULT_NUM_ENTRIES)),
                        help="first N seeds of sol_seed.jsonl (default 1500 = all, like naive_glm)")
    parser.add_argument("--prompt-template", choices=("naive", "a0"),
                        default=os.getenv("BON_PROMPT_TEMPLATE", "naive"),
                        help="whose call to sample: naive_glm_generate.py's (default, replaces the "
                             "naive data) or the ablation A0 arm's")
    parser.add_argument("--workers", type=int, default=int(os.getenv("BATCH_WORKERS", "4")),
                        help="seeds in flight within this shard (each fans out to N samples)")
    parser.add_argument("--output-root", type=str,
                        default=os.getenv("BON_OUTPUT_ROOT") or str(_NL2 / "dataset" / "best_of_n"),
                        help="parent directory; output goes to <root>/BoN<N>/")
    parser.add_argument("--seed-file", type=str, default=str(_NL2 / "sol_seed.jsonl"))
    parser.add_argument("--prompt-source", choices=("seed_long", "dataset", "seed"),
                        default=os.getenv("BON_PROMPT_SOURCE", "seed_long"),
                        help="NL prompt source (default seed_long, what naive_glm used)")
    parser.add_argument("--no-measure-all", dest="measure_all", action="store_false",
                        default=os.getenv("BON_MEASURE_ALL", "1").lower()
                        not in ("0", "false", "no", "off"),
                        help="cheap mode: compile only, skip Foundry / Slither / alignment measurement")
    parser.add_argument("--no-resume", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args(argv)


def main(argv=None) -> int:
    args = _parse_args(argv)
    if args.n < 1:
        print("Error: --n must be >= 1", file=sys.stderr)
        return 2
    if args.shards < 1 or not 0 <= args.shard < args.shards:
        print(f"Error: --shard must be in [0, {args.shards - 1}]", file=sys.stderr)
        return 2

    # Stage flags first: agent_rag_moe reads several of them at import time.
    import profiles  # noqa: PLC0415  (nl2solidity/ablation/profiles.py)
    for name in ("agent_rag_moe", "nl2solidity.agent_rag_moe"):
        assert name not in sys.modules, "profiles.apply() must run before agent_rag_moe is imported"
    applied = profiles.apply(BASE_ARM, measure_all=args.measure_all)
    os.environ["ABLATION_ID"] = applied["ABLATION_ID"] = f"BoN{args.n}"

    arm_id = f"BoN{args.n}"
    output_dir = Path(args.output_root) / arm_id

    print("=" * 70)
    print(f"Best-of-{args.n} (sampling the {args.prompt_template} one-shot GLM-5.2 call), selector: solc")
    print(f"  shard:       {args.shard + 1}/{args.shards}")
    print(f"  eval set:    first {args.num_entries} seeds of {Path(args.seed_file).name} (1500 = all)")
    print(f"  workers:     {args.workers} seeds x {args.n} samples in flight")
    print(f"  output:      {output_dir}")
    print(f"  measured by: {'all metrics (same fields as naive_glm / with_kernel_spec)' if args.measure_all else 'compile only'}")
    print("  stage flags:")
    for key, value in sorted(applied.items()):
        print(f"    {key}={value}")
    print("=" * 70)

    try:
        import nl2solidity.agent_rag_moe as amoe  # noqa: PLC0415
    except ModuleNotFoundError as exc:
        if exc.name != "nl2solidity":
            raise
        import agent_rag_moe as amoe  # noqa: PLC0415
    import batch_generate  # noqa: PLC0415

    seed_file = Path(args.seed_file)
    if not seed_file.exists():
        print(f"Error: seed file not found: {seed_file}", file=sys.stderr)
        return 1
    if not args.dry_run:
        if not amoe.is_compiler_available():
            print("Error: solc unavailable. Best-of-N is selected by the compiler, so there is "
                  "nothing to run without it (run nl2solidity/pace/prestage.sh).", file=sys.stderr)
            return 1
        try:
            amoe._load_env()  # also reads $REPO/.env; raises when the key is missing
        except RuntimeError as exc:
            print(f"Error: {exc}", file=sys.stderr)
            return 1

    naive = None
    if args.prompt_template == "naive":
        try:
            import nl2solidity.naive_glm_generate as naive  # noqa: PLC0415
        except ModuleNotFoundError as exc:
            if exc.name != "nl2solidity":
                raise
            import naive_glm_generate as naive  # noqa: PLC0415
    BestOfN(amoe, args.n, template=args.prompt_template, naive=naive).install(batch_generate)
    output_dir.mkdir(parents=True, exist_ok=True)

    # The generator resolves generate_solidity_moe from the module at call time, so the
    # rebinding above is what generate_batch will run.
    batch_generate.generate_batch(
        seed_file=seed_file,
        output_dir=output_dir,
        num_entries=args.num_entries,
        start_from=0,
        resume=not args.no_resume,
        dataset_data_dir=_NL2 / "dataset" / "data",
        prompt_source=args.prompt_source,
        require_dataset_nl=False,
        workers=args.workers,
        shard_index=args.shard,
        shard_count=args.shards,
        dry_run=args.dry_run,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
