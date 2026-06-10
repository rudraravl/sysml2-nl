#!/usr/bin/env python3
"""Write wiki-seed generation prompts into generated dataset sample directories.

Default behavior creates ``gen_prompt.txt`` only for samples whose ``meta.json``
points back to ``nl_seed.jsonl:U...``. The prompt uses the original wiki seed
description from ``nl_seed.jsonl``, not the generated natural-language
description stored in ``dataset/data/<id>/<id>.txt``.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Iterable

NL2SYSML_DIR = Path(__file__).resolve().parent
REPO_ROOT = NL2SYSML_DIR.parent

if str(NL2SYSML_DIR) not in sys.path:
    sys.path.insert(0, str(NL2SYSML_DIR))


def load_seed_descriptions(seed_file: Path) -> dict[str, str]:
    if not seed_file.exists():
        raise SystemExit(f"Seed file not found: {seed_file}")

    seeds: dict[str, str] = {}
    with seed_file.open("r", encoding="utf-8") as fh:
        for line_no, line in enumerate(fh, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError as exc:
                raise SystemExit(f"Invalid JSON in {seed_file}:{line_no}: {exc}") from exc

            seed_id = str(entry.get("id", "")).strip()
            description = str(entry.get("description", "")).strip()
            if seed_id and description:
                seeds[seed_id] = description
    return seeds


def seed_id_from_meta(sample_dir: Path) -> str | None:
    meta_file = sample_dir / "meta.json"
    if not meta_file.exists():
        return None

    try:
        meta = json.loads(meta_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None

    source_path = str(meta.get("source_path", "")).strip()
    prefix = "nl_seed.jsonl:"
    if not source_path.startswith(prefix):
        return None
    seed_id = source_path[len(prefix) :].strip()
    return seed_id or None


def iter_sample_dirs(dataset_dir: Path) -> Iterable[Path]:
    for child in sorted(dataset_dir.iterdir()):
        if not child.is_dir():
            continue
        if seed_id_from_meta(child) is not None:
            yield child


def build_prompt(description: str) -> str:
    return (
        "Generate SysML v2 code for the following requirement. "
        "Produce a complete, detailed, non-trivial model with appropriate parts, ports, "
        "connections, item/value types (with units), behaviors (state machines/actions), "
        "and requirements as applicable. Avoid placeholders. "
        f"Requirement: {description}\n"
    )


def generate_prompt_files(
    dataset_dir: Path,
    *,
    seed_file: Path,
    output_name: str,
    start_from: int,
    limit: int | None,
    overwrite: bool,
    dry_run: bool,
) -> dict[str, int]:
    if not dataset_dir.exists():
        raise SystemExit(f"Dataset directory not found: {dataset_dir}")
    if not dataset_dir.is_dir():
        raise SystemExit(f"Dataset path is not a directory: {dataset_dir}")

    seed_descriptions = load_seed_descriptions(seed_file)
    sample_dirs = list(iter_sample_dirs(dataset_dir))
    selected = sample_dirs[start_from:]
    if limit is not None:
        selected = selected[:limit]

    stats = {"found": len(sample_dirs), "selected": len(selected), "written": 0, "skipped": 0, "errors": 0}

    for idx, sample_dir in enumerate(selected, start=start_from):
        seed_id = seed_id_from_meta(sample_dir)
        if seed_id is None:
            stats["errors"] += 1
            print(f"[{idx}] {sample_dir.name}: missing nl_seed source_path")
            continue

        out_file = sample_dir / output_name
        if out_file.exists() and not overwrite:
            stats["skipped"] += 1
            print(f"[{idx}] {sample_dir.name}: exists, skipping")
            continue

        description = seed_descriptions.get(seed_id, "")
        if not description:
            stats["errors"] += 1
            print(f"[{idx}] {sample_dir.name}: seed {seed_id} not found or empty")
            continue

        prompt = build_prompt(description)

        if dry_run:
            stats["skipped"] += 1
            print(f"[{idx}] {sample_dir.name}: would write {out_file}")
            continue

        out_file.write_text(prompt, encoding="utf-8")
        stats["written"] += 1
        print(f"[{idx}] {sample_dir.name}: wrote {out_file}")

    return stats


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create gen_prompt.txt for generated dataset samples from nl_seed.jsonl.",
    )
    parser.add_argument(
        "--dataset-dir",
        type=Path,
        default=REPO_ROOT / "dataset" / "data",
        help="Directory containing per-sample subdirectories (default: dataset/data)",
    )
    parser.add_argument(
        "--seed-file",
        type=Path,
        default=NL2SYSML_DIR / "nl_seed.jsonl",
        help="Path to nl_seed.jsonl",
    )
    parser.add_argument(
        "--output-name",
        default="gen_prompt.txt",
        help="Prompt filename to write inside each sample directory",
    )
    parser.add_argument("--start-from", type=int, default=0, help="0-based sample index to start from")
    parser.add_argument("--limit", type=int, default=None, help="Maximum number of samples to process")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite existing prompt files")
    parser.add_argument("--dry-run", action="store_true", help="Print planned writes without modifying files")
    args = parser.parse_args()

    stats = generate_prompt_files(
        args.dataset_dir,
        seed_file=args.seed_file,
        output_name=args.output_name,
        start_from=args.start_from,
        limit=args.limit,
        overwrite=args.overwrite,
        dry_run=args.dry_run,
    )

    print("\nBatch prompt generation complete")
    print(f"  Found:    {stats['found']}")
    print(f"  Selected: {stats['selected']}")
    print(f"  Written:  {stats['written']}")
    print(f"  Skipped:  {stats['skipped']}")
    print(f"  Errors:   {stats['errors']}")


if __name__ == "__main__":
    main()
