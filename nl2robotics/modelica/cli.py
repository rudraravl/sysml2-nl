"""Command-line entry point for the Modelica robotics profile."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .corpus import ExampleCorpus
from .openmodelica import OpenModelicaRunner
from .pipeline import ModelicaPipeline


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    retrieve = sub.add_parser("retrieve")
    retrieve.add_argument("requirement")
    retrieve.add_argument("-k", type=int, default=5)
    retrieve.add_argument(
        "--subset", choices=(
            "core24", "balanced50", "full100", "full300",
            "semantic500", "full1500",
        ),
        default="full1500",
    )

    run = sub.add_parser("run")
    run.add_argument("model", type=Path)
    run.add_argument("--properties", type=Path)
    run.add_argument("--output-dir", type=Path)
    run.add_argument("--backend", choices=("auto", "local", "docker"), default="auto")
    run.add_argument("--stop-time", type=float, default=5.0)
    run.add_argument("--solver", default="dassl")

    compile_model = sub.add_parser("compile")
    compile_model.add_argument("model", type=Path)
    compile_model.add_argument("--output-dir", type=Path)
    compile_model.add_argument(
        "--backend", choices=("auto", "local", "docker"), default="auto"
    )

    fmu = sub.add_parser("fmu")
    fmu.add_argument("model", type=Path)
    fmu.add_argument("--output-dir", type=Path, required=True)
    fmu.add_argument("--properties", type=Path)
    fmu.add_argument("--outputs", nargs="*", default=[])
    fmu.add_argument("--start-values", type=Path)
    fmu.add_argument("--start-time", type=float, default=0.0)
    fmu.add_argument("--stop-time", type=float, default=5.0)
    fmu.add_argument("--step-size", type=float, default=0.01)
    fmu.add_argument(
        "--backend", choices=("auto", "local", "docker"), default="auto"
    )

    generate = sub.add_parser("generate")
    generate.add_argument("--mode", choices=("moe", "single"), default="moe")
    generate.add_argument("requirement")
    generate.add_argument("--model", default="gpt-5.4")
    generate.add_argument("--provider", choices=("codex", "claude"))
    generate.add_argument("--output-dir", type=Path, required=True)
    generate.add_argument("--backend", choices=("auto", "local", "docker"), default="auto")
    generate.add_argument("--max-repairs", type=int, default=2)
    generate.add_argument(
        "--subset", choices=(
            "core24", "balanced50", "full100", "full300",
            "semantic500", "full1500",
        ),
        default="full1500",
    )
    generate.add_argument("-k", type=int, default=5)
    args = parser.parse_args()

    if args.command == "retrieve":
        corpus = ExampleCorpus(subset=args.subset)
        for item, score in corpus.retrieve(args.requirement, k=args.k):
            print(f"{item.id}\t{score:.4f}\t{item.category}\t{item.requirement}")
        return

    subset = args.subset if args.command == "generate" else "full100"
    pipeline = ModelicaPipeline(
        corpus=ExampleCorpus(subset=subset),
        runner=OpenModelicaRunner(backend=args.backend),
    )
    if args.command == "generate":
        args.output_dir.mkdir(parents=True, exist_ok=True)
        if args.mode == "moe":
            from .moe import generate_modelica_moe

            _, report = generate_modelica_moe(
                args.requirement,
                pipeline=pipeline,
                max_repairs=args.max_repairs,
                k=args.k,
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
                max_repairs=args.max_repairs,
                k=args.k,
                output_dir=args.output_dir,
            )
            report.update({
                "generation_mode": "single",
                "single_model": args.model,
                "single_provider": args.provider,
            })
        (args.output_dir / "model.mo").write_text(
            report["final_modelica"], encoding="utf-8"
        )
        (args.output_dir / "report.json").write_text(
            json.dumps(report, indent=2, allow_nan=False), encoding="utf-8"
        )
        print(json.dumps(report, indent=2, allow_nan=False))
        raise SystemExit(0 if report["passed"] else 1)

    code = args.model.read_text(encoding="utf-8")
    if args.command == "compile":
        result = pipeline.compile(code, output_dir=args.output_dir)
        print(json.dumps(result.to_dict(), indent=2, allow_nan=False))
        raise SystemExit(0 if result.passed else 1)

    properties = []
    if args.properties:
        properties = json.loads(args.properties.read_text(encoding="utf-8"))
    if args.command == "fmu":
        start_values = {}
        if args.start_values:
            start_values = json.loads(
                args.start_values.read_text(encoding="utf-8")
            )
        result = pipeline.export_and_execute_fmu(
            code,
            properties=properties,
            outputs=args.outputs,
            start_values=start_values,
            start_time=args.start_time,
            stop_time=args.stop_time,
            step_size=args.step_size,
            output_dir=args.output_dir,
        )
        (args.output_dir / "report.json").write_text(
            json.dumps(result, indent=2, allow_nan=False), encoding="utf-8"
        )
        print(json.dumps(result, indent=2, allow_nan=False))
        raise SystemExit(0 if result["passed"] else 1)

    result = pipeline.evaluate(
        code,
        properties,
        output_dir=args.output_dir,
        stop_time=args.stop_time,
        solver=args.solver,
    )
    print(json.dumps(result.to_dict(), indent=2, allow_nan=False))
    raise SystemExit(0 if result.passed else 1)


if __name__ == "__main__":
    main()
