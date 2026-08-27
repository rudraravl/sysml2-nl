"""Run frozen robotics ablation cells with the configured model transports."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from nl2robotics.benchmark.suite import BenchmarkSuite
from nl2robotics.hybrid.portable import PortableHybridPipeline
from nl2robotics.hybrid.gpu_handoff import run_handoff
from nl2robotics.hybrid.newton_cli import run_newton_bundle
from nl2robotics.modelica.corpus import ExampleCorpus
from nl2robotics.modelica.openmodelica import OpenModelicaRunner
from nl2robotics.modelica.pipeline import ModelicaPipeline
from nl2robotics.openusd.pipeline import OpenUSDPipeline
from spec_aligner.llm import JSON_PREFIX, TEXT_PREFIX, ask_completion

from .conditions import select_conditions
from .executor import PipelineExperimentExecutor
from .metrics import summarize_records
from .records import write_json
from .runner import AblationRunner, experiment_size


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument(
        "--benchmark-manifest", type=Path,
        help="use a study-specific benchmark manifest instead of the frozen development set",
    )
    parser.add_argument("--profile", choices=("modelica", "openusd", "hybrid"))
    parser.add_argument("--task-id", action="append", default=[])
    parser.add_argument("--condition", action="append", default=[])
    parser.add_argument("--variant", choices=("rich", "concise", "underspecified"),
                        default="rich")
    parser.add_argument("--repetitions", type=int, default=1)
    parser.add_argument("--model", default="gpt-5.4")
    parser.add_argument("--provider", choices=("codex", "claude"))
    parser.add_argument("--modelica-backend", choices=("auto", "local", "docker"),
                        default="docker")
    parser.add_argument("--modelica-subset",
                        choices=(
                            "core24", "balanced50", "full100", "full300",
                            "semantic500", "full1500",
                        ),
                        default="full1500")
    parser.add_argument("-k", type=int, default=5)
    parser.add_argument("--max-tool-repairs", type=int, default=2)
    parser.add_argument("--isaac-python", type=Path)
    parser.add_argument(
        "--newton-handoff", action="store_true",
        help="execute newton_h2 cells in this Python environment",
    )
    parser.add_argument("--h2-controller-backend", choices=("local", "docker"),
                        default="local")
    parser.add_argument("--h2-device", default="cpu")
    parser.add_argument("--h2-solver", choices=("TGS", "PGS"), default="TGS")
    parser.add_argument("--h2-repetitions", type=int, default=3)
    parser.add_argument(
        "--newton-controller-backend", choices=("local", "docker"),
        default="local",
    )
    parser.add_argument("--newton-fmi-runtime-image",
                        default="nl2robotics-fmi-runtime:0.1")
    parser.add_argument("--newton-device", default="cuda:0")
    parser.add_argument(
        "--newton-solver", choices=("featherstone", "mujoco_warp"),
        default="featherstone",
    )
    parser.add_argument("--newton-version", default="1.5.0")
    parser.add_argument("--newton-repetitions", type=int, default=3)
    parser.add_argument("--newton-repeatability-tolerance", type=float,
                        default=1e-6)
    parser.add_argument("--no-resume", action="store_true")
    args = parser.parse_args()

    suite = BenchmarkSuite(manifest_path=args.benchmark_manifest)
    audit = suite.audit()
    if audit["success"] is not True:
        parser.error(f"benchmark manifest failed audit: {audit['issues']}")
    selected = suite.select(profile=args.profile, variant=args.variant)
    if args.task_id:
        wanted = set(args.task_id)
        selected = [item for item in selected if item[0].id in wanted]
        missing = wanted - {item[0].id for item in selected}
        if missing:
            parser.error(f"unknown or profile-excluded task IDs: {sorted(missing)}")
    conditions = select_conditions(args.condition or None)
    if not selected:
        parser.error("no benchmark tasks selected")

    text_ask = lambda prompt: ask_completion(  # noqa: E731
        prompt, model=args.model, provider=args.provider, prefix=TEXT_PREFIX
    )
    json_ask = lambda prompt: ask_completion(  # noqa: E731
        prompt, model=args.model, provider=args.provider, prefix=JSON_PREFIX
    )
    omc = OpenModelicaRunner(backend=args.modelica_backend)
    modelica = ModelicaPipeline(
        corpus=ExampleCorpus(subset=args.modelica_subset), runner=omc
    )
    h2_handoff = None
    if args.isaac_python:
        if args.h2_repetitions < 3:
            parser.error("paper-eligible H2 experiments require at least 3 repetitions")

        def h2_handoff(*, bundle_path: Path, output_dir: Path):
            return run_handoff(
                bundle_path=bundle_path,
                output_dir=output_dir,
                isaac_python=args.isaac_python,
                repetitions=args.h2_repetitions,
                controller_backend=args.h2_controller_backend,
                device=args.h2_device,
                solver=args.h2_solver,
            )

    newton_handoff = None
    if args.newton_handoff:
        if args.newton_repetitions < 3:
            parser.error("paper-eligible Newton experiments require 3 repetitions")

        def newton_handoff(*, bundle_path: Path, output_dir: Path):
            report = run_newton_bundle(
                bundle_path=bundle_path,
                output_dir=output_dir,
                controller_backend=args.newton_controller_backend,
                fmi_runtime_image=args.newton_fmi_runtime_image,
                device=args.newton_device,
                solver=args.newton_solver,
                newton_version=args.newton_version,
                repetitions=args.newton_repetitions,
                repeatability_tolerance=args.newton_repeatability_tolerance,
            )
            return {"success": report.get("success") is True,
                    "failure_stage": None if report.get("success") else
                    "newton_execution", "newton_report": report}

    executor = PipelineExperimentExecutor(
        text_ask=text_ask,
        json_ask=json_ask,
        suite=suite,
        modelica_pipeline=modelica,
        openusd_pipeline=OpenUSDPipeline(),
        portable_pipeline=PortableHybridPipeline(modelica_runner=omc),
        k=args.k,
        max_tool_repairs=args.max_tool_repairs,
        h2_handoff=h2_handoff,
        newton_handoff=newton_handoff,
    )
    configuration = {
        "single_model": args.model,
        "single_provider": args.provider,
        "moe_configuration": "shared_with_sysml_pipeline",
        "modelica_backend": args.modelica_backend,
        "modelica_subset": args.modelica_subset,
        "k": args.k,
        "max_tool_repairs": args.max_tool_repairs,
        "benchmark_manifest": audit["manifest"],
        "benchmark_manifest_sha256": audit["manifest_sha256"],
        "isaac_handoff_configured": args.isaac_python is not None,
        "h2_controller_backend": args.h2_controller_backend,
        "h2_device": args.h2_device,
        "h2_solver": args.h2_solver,
        "h2_repetitions": args.h2_repetitions,
        "newton_handoff_configured": args.newton_handoff,
        "newton_controller_backend": args.newton_controller_backend,
        "newton_fmi_runtime_image": args.newton_fmi_runtime_image,
        "newton_device": args.newton_device,
        "newton_solver": args.newton_solver,
        "newton_version": args.newton_version,
        "newton_repetitions": args.newton_repetitions,
        "newton_repeatability_tolerance": args.newton_repeatability_tolerance,
    }
    size = experiment_size(len(selected), len(conditions), 1, args.repetitions)
    print(json.dumps({"experiment_size": size, "configuration": configuration},
                     indent=2))
    records = AblationRunner(
        args.output_dir, configuration=configuration
    ).run(
        selected, conditions, executor,
        variant=args.variant,
        repetitions=args.repetitions,
        resume=not args.no_resume,
    )
    summary = summarize_records(records)
    write_json(args.output_dir / "summary.json", summary)
    print(json.dumps(summary, indent=2, allow_nan=False))


if __name__ == "__main__":
    main()
