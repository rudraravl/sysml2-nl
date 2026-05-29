#!/usr/bin/env python3
"""Batch Stage A: GPT-5.5 baseline generation from nl_seed.jsonl (no RAG, no MOE).

OpenRouter generation only — no SysML JVM/compiler checks or repair.

Full corpus:
  python nl2sysml/ablation_gpt55/batch_nl_seed.py --num-entries 1574
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import traceback
from datetime import datetime
from pathlib import Path
from typing import Any

# Ensure compiler is never loaded for this script (even if SYSML_COMPILER_ENABLED=true).
os.environ["SYSML_COMPILER_ENABLED"] = "false"

ABLATION_DIR = Path(__file__).resolve().parent
NL2SYSML_DIR = ABLATION_DIR.parent
if str(NL2SYSML_DIR) not in sys.path:
    sys.path.insert(0, str(NL2SYSML_DIR))
if str(ABLATION_DIR) not in sys.path:
    sys.path.insert(0, str(ABLATION_DIR))

from config import (  # noqa: E402
    BASELINE_DEFAULT_NUM_ENTRIES,
    BASELINE_OUTPUT_DIR,
    GPT55_MODEL,
    NL_SEED_FILE,
)
from generators import generate_baseline  # noqa: E402


def create_meta_json(entry: dict[str, Any], prompt_record: dict[str, Any]) -> dict[str, Any]:
    meta: dict[str, Any] = {
        "id": entry.get("id", "UNKNOWN"),
        "source_path": f"nl_seed.jsonl:{entry.get('id', 'UNKNOWN')}",
        "split": "generated",
        "generator": "gpt55_baseline",
        "model": prompt_record.get("model", GPT55_MODEL),
        "retrieval_used": False,
        "moe_used": False,
        "compiler_checked": False,
        "category": entry.get("domain", "unknown"),
        "created": datetime.now().isoformat(),
    }
    if entry.get("provenance"):
        meta["provenance"] = entry.get("provenance")
    if entry.get("source_title"):
        meta["source_title"] = entry.get("source_title")
    return meta


def generate_batch(
    seed_file: Path,
    output_dir: Path,
    *,
    model: str,
    num_entries: int,
    start_from: int,
    resume: bool,
) -> None:
    entries: list[dict[str, Any]] = []
    with seed_file.open("r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line:
                entries.append(json.loads(line))

    if not entries:
        raise SystemExit("No entries found in seed file")

    entries_to_process = entries[:num_entries]
    total = len(entries_to_process)
    output_dir.mkdir(parents=True, exist_ok=True)
    log_file = output_dir / "generation.log"

    def log(message: str, level: str = "INFO") -> None:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_msg = f"[{timestamp}] [{level}] {message}"
        print(log_msg)
        with log_file.open("a", encoding="utf-8") as fh:
            fh.write(log_msg + "\n")

    log(f"Stage A baseline: model={model}, prompts={total}, output={output_dir}")
    log("Compiler/JVM checks disabled (GPT output only)")

    stats = {"processed": 0, "skipped": 0, "errors": 0}

    for idx, entry in enumerate(entries_to_process[start_from:], start=start_from):
        entry_id = str(entry.get("id", f"UNKNOWN_{idx}"))
        description = str(entry.get("description", "")).strip()
        domain = entry.get("domain", "unknown")

        entry_dir = output_dir / entry_id
        sysml_file = entry_dir / f"{entry_id}.sysml"
        txt_file = entry_dir / f"{entry_id}.txt"
        meta_file = entry_dir / "meta.json"
        prompt_file = entry_dir / f"{entry_id}_prompt.json"

        if resume and sysml_file.exists() and txt_file.exists() and meta_file.exists():
            log(f"[{idx + 1}/{total}] {entry_id}: already exists, skipping")
            stats["skipped"] += 1
            continue

        log(f"[{idx + 1}/{total}] {entry_id}: generating ({domain})...")
        log(f"  Description: {description[:80]}...")

        try:
            start_time = time.time()
            sysml_code, prompt_record = generate_baseline(description, model=model)
            elapsed = time.time() - start_time

            if not sysml_code or not sysml_code.strip():
                log("  Empty output", "ERROR")
                stats["errors"] += 1
                continue

            entry_dir.mkdir(parents=True, exist_ok=True)
            sysml_file.write_text(sysml_code.strip() + "\n", encoding="utf-8")
            txt_file.write_text(description + "\n", encoding="utf-8")
            meta_file.write_text(
                json.dumps(create_meta_json(entry, prompt_record), indent=2, ensure_ascii=False) + "\n",
                encoding="utf-8",
            )
            prompt_file.write_text(
                json.dumps(prompt_record, indent=2, ensure_ascii=False) + "\n",
                encoding="utf-8",
            )

            stats["processed"] += 1
            log(f"  OK ({elapsed:.1f}s)")

        except KeyboardInterrupt:
            log("Interrupted by user", "WARNING")
            print(f"\nProcessed: {stats['processed']}/{total}")
            print(f"Resume with: --start-from {idx}")
            sys.exit(0)

        except Exception as exc:
            log(f"  Error: {exc}", "ERROR")
            (output_dir / f"{entry_id}_error.log").write_text(
                f"Error processing {entry_id}:\n{exc}\n\n{traceback.format_exc()}",
                encoding="utf-8",
            )
            stats["errors"] += 1

        if (idx + 1) % 10 == 0:
            log(
                f"Progress: {idx + 1}/{total} "
                f"({stats['processed']} generated, {stats['errors']} errors)"
            )

    print("\n" + "=" * 70)
    print("Stage A baseline batch complete")
    print(f"  Processed: {stats['processed']}")
    print(f"  Skipped:   {stats['skipped']}")
    print(f"  Errors:    {stats['errors']}")
    print(f"  Output:    {output_dir}")
    print("=" * 70)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Stage A: GPT-5.5 baseline batch on nl_seed.jsonl (no RAG, no MOE, no compiler)",
    )
    parser.add_argument(
        "--num-entries",
        type=int,
        default=BASELINE_DEFAULT_NUM_ENTRIES,
        help="Number of seed lines to process",
    )
    parser.add_argument("--start-from", type=int, default=0, help="0-based index to resume from")
    parser.add_argument("--no-resume", action="store_true", help="Overwrite existing outputs")
    parser.add_argument("--seed-file", type=Path, default=NL_SEED_FILE)
    parser.add_argument("--output-dir", type=Path, default=BASELINE_OUTPUT_DIR)
    parser.add_argument("--model", default=GPT55_MODEL, help=f"OpenRouter model (default: {GPT55_MODEL})")
    parser.add_argument("--dry-run", action="store_true", help="Print plan only")
    args = parser.parse_args()

    if not args.seed_file.exists():
        raise SystemExit(f"Seed file not found: {args.seed_file}")

    if args.dry_run:
        print("Dry run — Stage A baseline (GPT only, no compiler):")
        print(f"  Model:      {args.model}")
        print(f"  Seed file:  {args.seed_file}")
        print(f"  Entries:    {args.num_entries} (start at {args.start_from})")
        print(f"  Output dir: {args.output_dir}")
        return

    generate_batch(
        args.seed_file,
        args.output_dir,
        model=args.model,
        num_entries=args.num_entries,
        start_from=args.start_from,
        resume=not args.no_resume,
    )


if __name__ == "__main__":
    main()
