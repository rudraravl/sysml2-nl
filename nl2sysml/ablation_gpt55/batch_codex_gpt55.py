#!/usr/bin/env python3
"""Run Codex/ChatGPT GPT-5.5 over generated dataset prompts.

For each generated dataset sample, read ``gen_prompt.txt`` and write
``<sample_id>.codex.sysml`` in the same directory.

Codex is invoked as a single-shot completion with a read-only sandbox and an
empty working directory so the model only receives the prompt text supplied by
this script.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path


ABLATION_DIR = Path(__file__).resolve().parent
REPO_ROOT = ABLATION_DIR.parents[1]
DEFAULT_DATASET_DIR = REPO_ROOT / "dataset" / "data"

SINGLE_SHOT_PREFIX = (
    "You are acting as a single-shot LLM completion. "
    "Do not use tools, do not inspect files, do not run commands. "
    "Answer directly with SysML v2 textual notation only. "
    "Do not include markdown fences, commentary, or explanations.\n\n"
)


def sample_sort_key(path: Path) -> tuple[int, str]:
    try:
        return (int(path.name), path.name)
    except ValueError:
        return (10**9, path.name)


def iter_prompt_files(dataset_dir: Path, start_id: int) -> list[Path]:
    prompt_files: list[Path] = []
    for sample_dir in sorted((p for p in dataset_dir.iterdir() if p.is_dir()), key=sample_sort_key):
        try:
            sample_id = int(sample_dir.name)
        except ValueError:
            continue
        if sample_id < start_id:
            continue
        prompt_file = sample_dir / "gen_prompt.txt"
        if prompt_file.exists():
            prompt_files.append(prompt_file)
    return prompt_files


def build_codex_command(prompt: str, output_file: Path, *, model: str | None, json_events: bool) -> list[str]:
    cmd = [
        "codex",
        "exec",
        "--sandbox",
        "read-only",
        "--ignore-rules",
        "--ignore-user-config",
        "--ephemeral",
        "--skip-git-repo-check",
        "--output-last-message",
        str(output_file),
    ]
    if json_events:
        cmd.append("--json")
    if model:
        cmd.extend(["--model", model])
    cmd.append(prompt)
    return cmd


def run_one(
    prompt_file: Path,
    *,
    model: str | None,
    resume: bool,
    json_events: bool,
    timeout: int,
    dry_run: bool,
) -> bool:
    sample_dir = prompt_file.parent
    sample_id = sample_dir.name
    output_file = sample_dir / f"{sample_id}.codex.sysml"
    log_file = sample_dir / f"{sample_id}.codex.log"

    if resume and output_file.exists() and output_file.read_text(encoding="utf-8").strip():
        print(f"{sample_id}: exists, skipping")
        return True

    gen_prompt = prompt_file.read_text(encoding="utf-8").strip()
    if not gen_prompt:
        print(f"{sample_id}: empty gen_prompt.txt", file=sys.stderr)
        return False

    prompt = SINGLE_SHOT_PREFIX + gen_prompt
    cmd = build_codex_command(prompt, output_file, model=model, json_events=json_events)

    if dry_run:
        print(f"{sample_id}: would run codex -> {output_file}")
        return True

    print(f"{sample_id}: running codex...", flush=True)
    start = time.time()
    with tempfile.TemporaryDirectory(prefix="codex-gpt55-") as temp_dir:
        result = subprocess.run(
            cmd,
            cwd=temp_dir,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )

    elapsed = time.time() - start
    log_file.write_text(result.stdout, encoding="utf-8")

    if result.returncode != 0:
        print(f"{sample_id}: codex failed rc={result.returncode} ({elapsed:.1f}s)", file=sys.stderr)
        return False

    if not output_file.exists() or not output_file.read_text(encoding="utf-8").strip():
        print(f"{sample_id}: empty output ({elapsed:.1f}s)", file=sys.stderr)
        return False

    print(f"{sample_id}: wrote {output_file} ({elapsed:.1f}s)", flush=True)
    return True


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Batch run Codex GPT-5.5 on dataset/data/*/gen_prompt.txt",
    )
    parser.add_argument("--dataset-dir", type=Path, default=DEFAULT_DATASET_DIR)
    parser.add_argument("--start-id", type=int, default=387)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--model", default=os.getenv("CODEX_GPT55_MODEL", "gpt-5.5"))
    parser.add_argument("--no-resume", action="store_true", help="Overwrite existing .codex.sysml files")
    parser.add_argument("--json", action="store_true", help="Ask Codex to emit JSONL events to the log")
    parser.add_argument("--timeout", type=int, default=600, help="Per-sample timeout in seconds")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if os.getenv("OPENAI_API_KEY"):
        print(
            "Warning: OPENAI_API_KEY is set; Codex may use API billing instead of ChatGPT sign-in.",
            file=sys.stderr,
        )

    prompt_files = iter_prompt_files(args.dataset_dir, args.start_id)
    if args.limit is not None:
        prompt_files = prompt_files[: args.limit]
    if not prompt_files:
        raise SystemExit("No gen_prompt.txt files found.")

    print(f"Dataset: {args.dataset_dir}")
    print(f"Prompts: {len(prompt_files)}")
    print(f"Model: {args.model}")
    print(f"Resume: {not args.no_resume}")

    ok = 0
    failed = 0
    for prompt_file in prompt_files:
        if run_one(
            prompt_file,
            model=args.model,
            resume=not args.no_resume,
            json_events=args.json,
            timeout=args.timeout,
            dry_run=args.dry_run,
        ):
            ok += 1
        else:
            failed += 1

    print("\nCodex batch complete")
    print(f"  OK:     {ok}")
    print(f"  Failed: {failed}")
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
