"""CLI: compare one NL file with one SysML v2 file via twin-blind QA."""

from __future__ import annotations

import argparse
import json
import os
import sys

from .llm import ask
from .pipeline import compare_files
from .report import render_markdown, write_json


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="specdiff",
                                description="QA-based NL <-> SysML v2 alignment check.")
    p.add_argument("--nl", required=True, help="natural-language description file")
    p.add_argument("--sysml", required=True, help="SysML v2 model file")
    p.add_argument("--sample-id", help="sample id (default: NL file stem)")
    p.add_argument("--json", dest="json_out", help="JSON report path")
    p.add_argument("--out", help="markdown report path")
    p.add_argument("--shards", type=int, default=5, help="parallel answer shards (default 5)")
    p.add_argument("--universal-only", action="store_true",
                   help="skip template instantiation (Tier 1 only)")
    p.add_argument("--cache", help="cache dir for instantiated questions + NL answers")
    p.add_argument("--model", help="codex model (default gpt-5.5)")
    p.add_argument("--profile", choices=("runtime", "research"), default="research",
                   help="runtime uses a smaller NL-grounded question set")
    p.add_argument("--question-source", choices=("nl", "sysml", "both"),
                   help="override which document the question writer can inspect")
    p.add_argument("--max-instantiated", type=int,
                   help="override the profile's instantiated-question cap")
    args = p.parse_args(argv)

    if args.model:
        os.environ["SPEC_ALIGNER_MODEL"] = args.model

    data = compare_files(args.nl, args.sysml, ask, sample_id=args.sample_id,
                         shards=args.shards, universal_only=args.universal_only,
                         cache_dir=args.cache, profile=args.profile,
                         question_source=args.question_source,
                         max_instantiated=args.max_instantiated)

    if args.json_out:
        write_json(args.json_out, data)
    if args.out:
        from pathlib import Path
        Path(args.out).write_text(render_markdown(data), encoding="utf-8")
    if not args.json_out and not args.out:
        json.dump(data, sys.stdout, indent=2, ensure_ascii=False)
        sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
