#!/usr/bin/env python3
"""
GPT-5.4 ablation study CLI.

Run from repo root:
  python nl2sysml/ablation_gpt54/run_study.py --conditions all

Or from nl2sysml/ablation_gpt54:
  python run_study.py --conditions baseline --ids U1
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

_ABLATION_DIR = Path(__file__).resolve().parent
_NL2 = _ABLATION_DIR.parent
if str(_NL2) not in sys.path:
    sys.path.insert(0, str(_NL2))
if str(_ABLATION_DIR) not in sys.path:
    sys.path.insert(0, str(_ABLATION_DIR))

from config import (  # noqa: E402
    CONDITION_ORDER,
    DEFAULT_DATASET,
    Condition,
    RESULTS_ROOT,
)
from metrics import build_summary, write_summary_files  # noqa: E402
from runners import (  # noqa: E402
    require_compiler,
    run_condition,
    save_prompt_output,
)


def _parse_conditions(raw: str) -> list[Condition]:
    if raw == "all":
        return list(CONDITION_ORDER)
    mapping = {
        "baseline": Condition.BASELINE,
        "rag": Condition.RAG,
        "moe": Condition.MOE,
        "a": Condition.BASELINE,
        "b": Condition.RAG,
        "c": Condition.MOE,
    }
    out: list[Condition] = []
    for part in raw.split(","):
        key = part.strip().lower()
        if key not in mapping:
            raise ValueError(f"Unknown condition: {part}. Use baseline|rag|moe|all")
        c = mapping[key]
        if c not in out:
            out.append(c)
    return out


def load_dataset(path: Path, ids_filter: set[str] | None) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    prompts = data.get("prompts", [])
    rows = []
    for item in prompts:
        pid = str(item.get("id", "")).strip().upper()
        desc = str(item.get("description", "")).strip()
        if not pid or not desc:
            continue
        if ids_filter and pid not in ids_filter:
            continue
        rows.append({"id": pid, "description": desc})
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description="GPT-5.4 ablation study (isolated)")
    parser.add_argument(
        "--conditions",
        default="all",
        help="all | baseline | rag | moe (comma-separated)",
    )
    parser.add_argument(
        "--dataset",
        type=Path,
        default=DEFAULT_DATASET,
        help="Path to dataset.json (default: nl2sysml/dataset.json)",
    )
    parser.add_argument(
        "--ids",
        default="",
        help="Comma-separated prompt IDs to run (e.g. U1,U5). Default: all in dataset.",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Skip prompts that already have a .sysml file in the condition output dir.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print execution plan without calling models or compiler.",
    )
    parser.add_argument(
        "--summary-only",
        action="store_true",
        help="Only aggregate existing results into summary.json / summary.md.",
    )
    args = parser.parse_args()

    ids_filter = None
    if args.ids.strip():
        ids_filter = {x.strip().upper() for x in args.ids.split(",") if x.strip()}

    if not args.dataset.exists():
        print(f"Dataset not found: {args.dataset}", file=sys.stderr)
        sys.exit(1)

    prompts = load_dataset(args.dataset, ids_filter)
    if not prompts:
        print("No prompts to run.", file=sys.stderr)
        sys.exit(1)

    conditions = _parse_conditions(args.conditions)

    if args.dry_run:
        print("Dry run — would execute:")
        print(f"  Dataset: {args.dataset} ({len(prompts)} prompts)")
        for cond in conditions:
            print(f"  {cond.label} -> {RESULTS_ROOT / cond.output_dir_name}/")
        return

    if args.summary_only:
        summary = build_summary(RESULTS_ROOT)
        write_summary_files(summary, RESULTS_ROOT)
        print(f"Wrote {RESULTS_ROOT / 'summary.json'}")
        print(f"Wrote {RESULTS_ROOT / 'summary.md'}")
        return

    require_compiler()

    for cond in conditions:
        out_dir = RESULTS_ROOT / cond.output_dir_name
        out_dir.mkdir(parents=True, exist_ok=True)
        print(f"\n=== {cond.label} ===\nOutput: {out_dir}")

        for item in prompts:
            pid = item["id"]
            desc = item["description"]
            sysml_path = out_dir / f"{pid}.sysml"

            if args.resume and sysml_path.exists():
                print(f"  {pid}: skip (resume)")
                continue

            print(f"  {pid}: generating...", flush=True)
            try:
                code, metrics = run_condition(cond, pid, desc)
                prompt_record = None
                if cond == Condition.MOE:
                    prompt_record = metrics.extra.pop("_prompt_record", None)
                save_prompt_output(
                    out_dir,
                    pid,
                    desc,
                    code,
                    metrics,
                    prompt_record=prompt_record,
                )
                status = "valid" if metrics.is_valid else f"{metrics.error_count} errors"
                print(f"  {pid}: done ({status})", flush=True)
            except Exception as exc:
                print(f"  {pid}: FAILED — {exc}", flush=True)
                raise

    summary = build_summary(RESULTS_ROOT)
    write_summary_files(summary, RESULTS_ROOT)
    print(f"\nWrote {RESULTS_ROOT / 'summary.json'}")
    print(f"Wrote {RESULTS_ROOT / 'summary.md'}")


if __name__ == "__main__":
    main()
