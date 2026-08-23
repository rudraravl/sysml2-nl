"""Command-line entry point for the portable OpenUSD robotics profile."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .corpus import OpenUSDExampleCorpus
from .pipeline import OpenUSDPipeline
from .validator import OpenUSDValidator


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)

    retrieve = commands.add_parser("retrieve")
    retrieve.add_argument("requirement")
    retrieve.add_argument("-k", type=int, default=5)
    retrieve.add_argument(
        "--subset", choices=("core20", "semantic100", "full300"),
        default="full300",
    )

    validate = commands.add_parser("validate")
    validate.add_argument("stage", type=Path)
    validate.add_argument("--output-dir", type=Path, required=True)

    generate = commands.add_parser("generate")
    generate.add_argument("requirement")
    generate.add_argument("--mode", choices=("moe", "single"), default="moe")
    generate.add_argument("--model", default="gpt-5.4")
    generate.add_argument("--provider", choices=("codex", "claude"))
    generate.add_argument("--output-dir", type=Path, required=True)
    generate.add_argument("--max-repairs", type=int, default=2)
    generate.add_argument("-k", type=int, default=5)
    args = parser.parse_args()

    if args.command == "retrieve":
        for example, score in OpenUSDExampleCorpus(subset=args.subset).retrieve(
            args.requirement, k=args.k
        ):
            print(
                f"{example.id}\t{score:.4f}\t{example.category}\t"
                f"{example.requirement}"
            )
        return

    if args.command == "validate":
        result = OpenUSDValidator().validate(
            args.stage, output_dir=args.output_dir
        )
        print(json.dumps(result.to_dict(), indent=2, allow_nan=False))
        raise SystemExit(0 if result.success else 1)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    pipeline = OpenUSDPipeline()
    if args.mode == "moe":
        from .moe import generate_openusd_moe

        _, report = generate_openusd_moe(
            args.requirement,
            pipeline=pipeline,
            k=args.k,
            max_repairs=args.max_repairs,
            output_dir=args.output_dir,
        )
    else:
        from spec_aligner.llm import TEXT_PREFIX, ask_completion

        ask = lambda prompt: ask_completion(  # noqa: E731
            prompt, model=args.model, provider=args.provider, prefix=TEXT_PREFIX
        )
        report = pipeline.generate(
            args.requirement,
            ask,
            k=args.k,
            max_repairs=args.max_repairs,
            output_dir=args.output_dir,
        )
        report.update({
            "generation_mode": "single",
            "single_model": args.model,
            "single_provider": args.provider,
        })
    (args.output_dir / "scene.usda").write_text(
        report["final_openusd"], encoding="utf-8"
    )
    (args.output_dir / "report.json").write_text(
        json.dumps(report, indent=2, allow_nan=False), encoding="utf-8"
    )
    print(json.dumps(report, indent=2, allow_nan=False))
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
