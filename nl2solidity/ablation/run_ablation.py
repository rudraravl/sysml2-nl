#!/usr/bin/env python3
"""Run one shard of one ablation arm.

This is the single entry point every sbatch task calls. It does three things in
a fixed order, and the order matters:

  1. resolve the arm's stage flags onto os.environ (profiles.apply)
  2. import the generator, so its import-time constants see those flags
  3. hand off to batch_generate.generate_batch for this shard

Each arm writes to its own output directory, so arms never share state. Within an
arm, shards partition the seed list by position (seed_index % shards == shard),
so the N tasks of one array job cover disjoint seeds and finish in roughly equal
time. Reruns are idempotent: a completed seed directory is skipped.

Examples
--------
    # one shard, locally, no model calls
    python nl2solidity/ablation/run_ablation.py --arm A2 --shards 5 --shard 0 \
        --num-entries 300 --dry-run

    # what SLURM task 3 of 5 runs for arm A4
    python nl2solidity/ablation/run_ablation.py --arm A4 --shards 5 --shard 3 \
        --num-entries 300 --workers 4
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_NL2 = _HERE.parent
_ROOT = _NL2.parent

for _path in (str(_ROOT), str(_NL2)):
    if _path not in sys.path:
        sys.path.insert(0, _path)

import profiles  # noqa: E402  (same directory; imported before the generator)


def _parse_args(argv=None):
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--arm", required=True, choices=profiles.ARM_IDS,
                        help="ablation arm to run")
    parser.add_argument("--shards", type=int,
                        default=int(os.getenv("ABLATION_SHARDS", "5")),
                        help="number of shards this arm is split across (env ABLATION_SHARDS, default 5)")
    parser.add_argument("--shard", type=int,
                        default=int(os.getenv("ABLATION_SHARD", "0")),
                        help="0-based index of this shard (env ABLATION_SHARD, default 0)")
    parser.add_argument("--num-entries", type=int,
                        default=int(os.getenv("ABLATION_N", "500")),
                        help=(
                            "seeds from the head of sol_seed.jsonl to use as the "
                            "evaluation set, shared by every arm "
                            "(env ABLATION_N, default 500; the file holds 1500)"
                        ))
    parser.add_argument("--workers", type=int,
                        default=int(os.getenv("BATCH_WORKERS", "4")),
                        help="seeds generated concurrently within this shard (default 4)")
    parser.add_argument("--output-root", type=str,
                        default=os.getenv("ABLATION_OUTPUT_ROOT")
                        or str(_NL2 / "dataset" / "ablation"),
                        help="parent directory; each arm gets <root>/<arm>/ (env ABLATION_OUTPUT_ROOT)")
    parser.add_argument("--seed-file", type=str,
                        default=str(_NL2 / "sol_seed.jsonl"),
                        help="seed file defining the evaluation set and its order")
    parser.add_argument("--prompt-source", choices=("seed_long", "dataset", "seed"),
                        default=os.getenv("ABLATION_PROMPT_SOURCE", "seed_long"),
                        help="NL prompt source; keep identical across arms (default seed_long)")
    parser.add_argument("--no-measure-all", dest="measure_all",
                        action="store_false",
                        default=os.getenv("ABLATION_MEASURE_ALL", "1").lower()
                        not in ("0", "false", "no", "off"),
                        help=(
                            "cheap mode: record only the metrics this arm's own "
                            "stages produce. The default is to run every checker on "
                            "every arm (repairing only with the arm's own stages), "
                            "which is what makes the arms comparable on all metrics"
                        ))
    parser.add_argument("--no-resume", action="store_true",
                        help="regenerate seeds that already have output")
    parser.add_argument("--dry-run", action="store_true",
                        help="print this shard's worklist and exit without calling a model")
    return parser.parse_args(argv)


def main(argv=None) -> int:
    args = _parse_args(argv)

    if args.shards < 1:
        print("Error: --shards must be >= 1", file=sys.stderr)
        return 2
    if not 0 <= args.shard < args.shards:
        print(f"Error: --shard must be in [0, {args.shards - 1}]", file=sys.stderr)
        return 2

    # Step 1, before any generator import: several stage switches in
    # agent_rag_moe are module-level constants evaluated at import time.
    assert "agent_rag_moe" not in sys.modules, \
        "profiles.apply() must run before agent_rag_moe is imported"
    applied = profiles.apply(args.arm, measure_all=args.measure_all)

    arm = profiles.get(args.arm)
    output_dir = Path(args.output_root) / arm.id

    print("=" * 70)
    print(f"Ablation {arm.id}: {arm.title}")
    print(f"  adds:        {arm.adds}")
    print(f"  shard:       {args.shard + 1}/{args.shards}")
    print(f"  eval set:    first {args.num_entries} seeds of {Path(args.seed_file).name}")
    print(f"  prompt:      {args.prompt_source}")
    print(f"  workers:     {args.workers}")
    print(f"  output:      {output_dir}")
    measured = ("all metrics (comparable across arms)" if args.measure_all
                else "only this arm's own stages")
    print(f"  measured by: {measured}")
    print("  stage flags:")
    for key, value in sorted(applied.items()):
        print(f"    {key}={value}")
    print("=" * 70)

    # Step 2: import only now, so the flags above are in force.
    import batch_generate  # noqa: PLC0415  (deliberately deferred; see above)

    seed_file = Path(args.seed_file)
    if not seed_file.exists():
        print(f"Error: seed file not found: {seed_file}", file=sys.stderr)
        return 1

    output_dir.mkdir(parents=True, exist_ok=True)

    # Step 3: generate this shard.
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
