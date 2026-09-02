"""CLI: compare one NL file with one model file (SysML v2 or Solidity) via twin-blind QA."""

from __future__ import annotations

import argparse
import json
import os
import sys

from .bank import BANK_PATH, SOLIDITY_BANK_PATH
from .llm import ask
from .pipeline import compare_files
from .report import render_markdown, write_json


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="specdiff",
                                description="QA-based NL <-> model alignment check "
                                            "(SysML v2 or Solidity).")
    p.add_argument("--nl", required=True, help="natural-language description file")
    # --model is already the LLM model id, so the artifact alias is --contract
    p.add_argument("--sysml", "--contract", dest="sysml", required=True,
                   help="model file: SysML v2 (default) or Solidity with --language solidity")
    p.add_argument("--language", choices=("sysml", "solidity"), default="sysml",
                   help="model-side language, selects the question bank (default sysml)")
    p.add_argument("--bank", help="explicit question bank path (overrides --language)")
    p.add_argument("--sample-id", help="sample id (default: NL file stem)")
    p.add_argument("--json", dest="json_out", help="JSON report path")
    p.add_argument("--out", help="markdown report path")
    p.add_argument("--shards", type=int, default=5, help="parallel answer shards (default 5)")
    p.add_argument("--universal-only", action="store_true",
                   help="skip template instantiation (Tier 1 only)")
    p.add_argument("--cache", help="cache dir for instantiated questions + NL answers")
    p.add_argument("--model", help="model id (default z-ai/glm-5.2 via OpenRouter)")
    p.add_argument("--profile", choices=("runtime", "research"), default="research",
                   help="runtime uses a smaller NL-grounded question set")
    p.add_argument("--question-source", choices=("nl", "sysml", "solidity", "both"),
                   help="override which document the question writer can inspect")
    p.add_argument("--max-instantiated", type=int,
                   help="override the profile's instantiated-question cap")
    args = p.parse_args(argv)

    if args.model:
        os.environ["SPEC_ALIGNER_MODEL"] = args.model

    bank_path = args.bank or (SOLIDITY_BANK_PATH if args.language == "solidity" else BANK_PATH)
    data = compare_files(args.nl, args.sysml, ask, sample_id=args.sample_id,
                         shards=args.shards, universal_only=args.universal_only,
                         cache_dir=args.cache, profile=args.profile,
                         question_source=args.question_source,
                         max_instantiated=args.max_instantiated,
                         bank_path=bank_path)

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
