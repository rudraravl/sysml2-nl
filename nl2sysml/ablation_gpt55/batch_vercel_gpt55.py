#!/usr/bin/env python3
"""Run Vercel AI Gateway GPT-5.5 over generated dataset prompts.

For each generated dataset sample, read ``gen_prompt.txt`` and write
``<sample_id>.gpt55.sysml`` in the same directory.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import random
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


ABLATION_DIR = Path(__file__).resolve().parent
REPO_ROOT = ABLATION_DIR.parents[1]
DEFAULT_DATASET_DIR = REPO_ROOT / "dataset" / "data"
DEFAULT_BASE_URL = "https://ai-gateway.vercel.sh/v1"
DEFAULT_MODEL = "openai/gpt-5.5"
KEY_ENV_VARS = (
    "AI_GATEWAY_API_KEY",
    "VERCEL_AI_GATEWAY_API_KEY",
    "VERCEL_API_KEY",
    "VERCEL_API_TOKEN",
)

SINGLE_SHOT_PREFIX = (
    "You are acting as a single-shot LLM completion. "
    "Do not use tools, do not inspect files, do not run commands. "
    "Answer directly with SysML v2 textual notation only. "
    "Do not include markdown fences, commentary, or explanations.\n\n"
)


def load_dotenv_file(path: Path) -> None:
    """Load simple KEY=VALUE lines without requiring python-dotenv."""
    if not path.exists():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


def get_api_key() -> tuple[str | None, str | None]:
    for env_name in KEY_ENV_VARS:
        value = os.getenv(env_name)
        if value:
            return value, env_name
    return None, None


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


def sample_random_10_percent(prompt_files: list[Path]) -> list[Path]:
    sample_count = round(len(prompt_files) * 0.10)
    if sample_count <= 0:
        return []
    selected = random.Random(0).sample(prompt_files, sample_count)
    return sorted(selected, key=lambda path: sample_sort_key(path.parent))


def post_chat_completion(
    base_url: str,
    api_key: str,
    model: str,
    prompt: str,
    *,
    timeout: int,
) -> dict:
    url = f"{base_url.rstrip('/')}/chat/completions"
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
    }
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code} from Vercel AI Gateway:\n{body}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Network error calling Vercel AI Gateway: {exc}") from exc


def extract_content(response: dict) -> str:
    try:
        content = response["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise RuntimeError("Unexpected response shape") from exc
    if not isinstance(content, str):
        raise RuntimeError("Unexpected non-string message content")
    return content


def run_one(
    prompt_file: Path,
    *,
    base_url: str,
    api_key: str,
    model: str,
    resume: bool,
    timeout: int,
    dry_run: bool,
) -> bool:
    sample_dir = prompt_file.parent
    sample_id = sample_dir.name
    output_file = sample_dir / f"{sample_id}.gpt55.sysml"
    log_file = sample_dir / f"{sample_id}.gpt55.log"

    if resume and output_file.exists() and output_file.read_text(encoding="utf-8").strip():
        print(f"{sample_id}: exists, skipping")
        return True

    gen_prompt = prompt_file.read_text(encoding="utf-8").strip()
    if not gen_prompt:
        print(f"{sample_id}: empty gen_prompt.txt", file=sys.stderr)
        return False

    prompt = SINGLE_SHOT_PREFIX + gen_prompt

    if dry_run:
        print(f"{sample_id}: would call Vercel AI Gateway -> {output_file}")
        return True

    print(f"{sample_id}: calling Vercel AI Gateway...", flush=True)
    start = time.time()
    try:
        response = post_chat_completion(base_url, api_key, model, prompt, timeout=timeout)
        output = extract_content(response).strip()
    except RuntimeError as exc:
        elapsed = time.time() - start
        log_file.write_text(str(exc), encoding="utf-8")
        print(f"{sample_id}: Vercel failed ({elapsed:.1f}s)", file=sys.stderr)
        return False

    elapsed = time.time() - start
    log_file.write_text(json.dumps(response, indent=2, ensure_ascii=False), encoding="utf-8")

    if not output:
        print(f"{sample_id}: empty output ({elapsed:.1f}s)", file=sys.stderr)
        return False

    output_file.write_text(output + "\n", encoding="utf-8")
    print(f"{sample_id}: wrote {output_file} ({elapsed:.1f}s)", flush=True)
    return True


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Batch run Vercel AI Gateway GPT-5.5 on dataset/data/*/gen_prompt.txt",
    )
    parser.add_argument("--dataset-dir", type=Path, default=DEFAULT_DATASET_DIR)
    parser.add_argument("--start-id", type=int, default=387)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--parallel", type=int, default=3, help="Number of concurrent requests")
    parser.add_argument("--model", default=os.getenv("GPT55_MODEL", DEFAULT_MODEL))
    parser.add_argument("--base-url", default=os.getenv("AI_GATEWAY_BASE_URL", DEFAULT_BASE_URL))
    parser.add_argument("--no-resume", action="store_true", help="Overwrite existing .gpt55.sysml files")
    parser.add_argument(
        "--random_10per",
        action="store_true",
        help="Use seed 0 to randomly select 10 percent of eligible prompts",
    )
    parser.add_argument("--timeout", type=int, default=600, help="Per-sample timeout in seconds")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    load_dotenv_file(REPO_ROOT / ".env")
    load_dotenv_file(REPO_ROOT / ".env.local")

    api_key, env_name = get_api_key()
    if not api_key:
        raise SystemExit(
            "Missing Vercel AI Gateway API key. Set one of: " + ", ".join(KEY_ENV_VARS)
        )

    prompt_files = iter_prompt_files(args.dataset_dir, args.start_id)
    total_prompt_files = len(prompt_files)
    if args.random_10per:
        prompt_files = sample_random_10_percent(prompt_files)
    if args.limit is not None:
        prompt_files = prompt_files[: args.limit]
    if not prompt_files:
        raise SystemExit("No gen_prompt.txt files found.")
    if args.parallel < 1:
        raise SystemExit("--parallel must be >= 1")

    print(f"Dataset: {args.dataset_dir}")
    if args.random_10per:
        print(f"Eligible prompts: {total_prompt_files}")
        print("Random 10%: seed=0")
    print(f"Prompts: {len(prompt_files)}")
    print(f"Model: {args.model}")
    print(f"Base URL: {args.base_url}")
    print(f"API key: {env_name}")
    print(f"Resume: {not args.no_resume}")
    print(f"Parallel: {args.parallel}")

    ok = 0
    failed = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.parallel) as executor:
        futures = [
            executor.submit(
                run_one,
                prompt_file,
                base_url=args.base_url,
                api_key=api_key,
                model=args.model,
                resume=not args.no_resume,
                timeout=args.timeout,
                dry_run=args.dry_run,
            )
            for prompt_file in prompt_files
        ]
        for future in concurrent.futures.as_completed(futures):
            if future.result():
                ok += 1
            else:
                failed += 1

    print("\nVercel GPT-5.5 batch complete")
    print(f"  OK:     {ok}")
    print(f"  Failed: {failed}")
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
