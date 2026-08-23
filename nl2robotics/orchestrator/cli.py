"""Generate a validated Modelica+OpenUSD robotics execution bundle from NL."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from nl2robotics.hybrid.portable import PortableHybridPipeline
from nl2robotics.modelica.corpus import ExampleCorpus
from nl2robotics.modelica.openmodelica import OpenModelicaRunner
from nl2robotics.modelica.pipeline import ModelicaPipeline
from nl2robotics.openusd.pipeline import OpenUSDPipeline
from spec_aligner.llm import JSON_PREFIX, TEXT_PREFIX, ask_completion

from .pipeline import RoboticsOrchestrator


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--request", type=Path)
    source.add_argument("--text")
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--task-id")
    parser.add_argument(
        "--execution-mode",
        choices=(
            "portable_fmu_kinematic", "isaac_closed_loop", "newton_closed_loop"
        ),
        default="portable_fmu_kinematic",
    )
    parser.add_argument("--mode", choices=("moe", "single"), default="moe")
    parser.add_argument("--model", default="gpt-5.4")
    parser.add_argument("--provider", choices=("codex", "claude"))
    parser.add_argument("--backend", choices=("auto", "local", "docker"),
                        default="auto")
    parser.add_argument(
        "--subset", choices=("core24", "balanced50", "full100", "full300"),
        default="full300",
    )
    parser.add_argument("-k", type=int, default=5)
    parser.add_argument("--max-ir-repairs", type=int, default=1)
    parser.add_argument("--max-profile-repairs", type=int, default=2)
    parser.add_argument("--max-semantic-repairs", type=int, default=1)
    parser.add_argument(
        "--alignment-mode", choices=("hybrid", "deterministic"), default="hybrid",
        help="Use formal evidence plus an LLM judge, or formal evidence only.",
    )
    args = parser.parse_args()

    requirement = (
        args.request.read_text(encoding="utf-8") if args.request else args.text
    )
    modelica_runner = OpenModelicaRunner(backend=args.backend)
    modelica_pipeline = ModelicaPipeline(
        corpus=ExampleCorpus(subset=args.subset), runner=modelica_runner
    )
    openusd_pipeline = OpenUSDPipeline()
    text_ask = lambda prompt: ask_completion(  # noqa: E731
        prompt, model=args.model, provider=args.provider, prefix=TEXT_PREFIX
    )
    kwargs = {}
    if args.mode == "single":
        def modelica_generator(profile_requirement: str, output_dir: Path):
            report = modelica_pipeline.generate(
                profile_requirement,
                text_ask,
                k=args.k,
                max_repairs=args.max_profile_repairs,
                output_dir=output_dir,
            )
            report.update({
                "generation_mode": "single",
                "single_model": args.model,
                "single_provider": args.provider,
            })
            return report["final_modelica"], report

        def openusd_generator(profile_requirement: str, output_dir: Path):
            report = openusd_pipeline.generate(
                profile_requirement,
                text_ask,
                k=args.k,
                max_repairs=args.max_profile_repairs,
                output_dir=output_dir,
            )
            report.update({
                "generation_mode": "single",
                "single_model": args.model,
                "single_provider": args.provider,
            })
            return report["final_openusd"], report

        kwargs.update({
            "modelica_generator": modelica_generator,
            "openusd_generator": openusd_generator,
        })

    orchestrator = RoboticsOrchestrator(
        modelica_pipeline=modelica_pipeline,
        openusd_pipeline=openusd_pipeline,
        portable_pipeline=PortableHybridPipeline(modelica_runner=modelica_runner),
        k=args.k,
        max_profile_repairs=args.max_profile_repairs,
        **kwargs,
    )
    ir_ask = lambda prompt: ask_completion(  # noqa: E731
        prompt, model=args.model, provider=args.provider, prefix=JSON_PREFIX
    )
    report = orchestrator.run(
        requirement,
        ir_ask,
        output_dir=args.output_dir,
        task_id=args.task_id,
        execution_mode=args.execution_mode,
        max_ir_repairs=args.max_ir_repairs,
        alignment_ask=ir_ask if args.alignment_mode == "hybrid" else None,
        semantic_repair_ask=text_ask if args.max_semantic_repairs else None,
        max_semantic_repairs=args.max_semantic_repairs,
    )
    print(json.dumps(report, indent=2, allow_nan=False))
    raise SystemExit(0 if report["passed"] or report.get("ready_for_gpu") else 1)


if __name__ == "__main__":
    main()
