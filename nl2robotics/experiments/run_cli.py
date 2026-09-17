"""Run frozen robotics ablation cells with the configured model transports."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil

from dotenv import load_dotenv

from nl2robotics.benchmark.suite import BenchmarkSuite
from nl2robotics.hybrid.portable import PortableHybridPipeline
from nl2robotics.hybrid.capability_execution import CapabilityExecutionPipeline
from nl2robotics.hybrid.gpu_handoff import run_handoff
from nl2robotics.hybrid.newton_cli import run_newton_bundle
from nl2robotics.modelica.corpus import ExampleCorpus
from nl2robotics.modelica.moe import (
    COMBINER_MODEL,
    EXPERT_MODELS,
    invoke_model as invoke_modelica_model,
    openrouter_transport_config,
    routing as modelica_moe_routing,
)
from nl2robotics.modelica.openmodelica import OpenModelicaRunner
from nl2robotics.modelica.pipeline import ModelicaPipeline
from nl2robotics.openusd.pipeline import OpenUSDPipeline
from nl2robotics.studies.capability_benchmark import CapabilityBenchmarkSuite
from spec_aligner.llm import (
    JSON_PREFIX,
    TEXT_PREFIX,
    probe_completion,
    provider_for_model,
)

from .conditions import select_conditions
from .executor import PipelineExperimentExecutor
from .metrics import summarize_records
from .protocol import freeze_protocol
from .records import write_json
from .runner import AblationRunner, experiment_size


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument(
        "--benchmark-manifest", type=Path,
        help="use a study-specific benchmark manifest instead of the frozen development set",
    )
    parser.add_argument(
        "--profile", choices=("modelica", "openusd", "hybrid", "capability")
    )
    parser.add_argument("--task-id", action="append", default=[])
    parser.add_argument("--family", action="append", default=[],
                        help="select one or more capability families")
    parser.add_argument("--semantic-case-id", action="append", default=[],
                        help="select one or more corpus semantic lineages")
    parser.add_argument("--configuration-variant", action="append", default=[],
                        help="select one or more controlled corpus configurations")
    parser.add_argument(
        "--benchmark-split", choices=("auto", "primary", "reserve", "all"),
        default="auto",
        help=("select held-out primary or reserve cases; auto selects primary "
              "when split metadata exists and otherwise selects all tasks"),
    )
    parser.add_argument("--condition", action="append", default=[])
    parser.add_argument("--variant", choices=("rich", "concise", "underspecified"),
                        default="rich")
    parser.add_argument("--repetitions", type=int, default=1)
    parser.add_argument("--randomization-seed", type=int, default=20260830)
    parser.add_argument("--shard-count", type=int, default=1,
                        help="split the frozen randomized cell plan across workers")
    parser.add_argument("--shard-index", type=int, default=0,
                        help="zero-based worker index within --shard-count")
    parser.add_argument(
        "--model", "--support-model", dest="model",
        default=COMBINER_MODEL, choices=EXPERT_MODELS,
        help=("frozen open-model support role used for normalization, "
              "alignment, and runtime repair"),
    )
    parser.add_argument(
        "--provider", choices=("openrouter",), default="openrouter",
        help="paper-facing robotics experiments use the frozen OpenRouter roster",
    )
    parser.add_argument(
        "--baseline-model", default=COMBINER_MODEL, choices=(COMBINER_MODEL,),
        help=("frozen direct/RAG-single comparison model; kept separate from "
              "the normalization, alignment, and repair --model"),
    )
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
    parser.add_argument(
        "--dry-run", action="store_true",
        help="audit and print the exact experiment grid without model calls",
    )
    args = parser.parse_args()
    if args.shard_count < 1:
        parser.error("--shard-count must be positive")
    if args.shard_index < 0 or args.shard_index >= args.shard_count:
        parser.error("--shard-index must be in [0, --shard-count)")

    suite = _load_suite(args.benchmark_manifest)
    audit = suite.audit()
    if audit["success"] is not True:
        parser.error(f"benchmark manifest failed audit: {audit['issues']}")
    try:
        selected = suite.select(profile=args.profile, variant=args.variant)
    except ValueError as exc:
        parser.error(str(exc))
    effective_benchmark_split = "explicit_task_ids"
    if args.task_id:
        wanted = set(args.task_id)
        selected = [item for item in selected if item[0].id in wanted]
        missing = wanted - {item[0].id for item in selected}
        if missing:
            parser.error(f"unknown or profile-excluded task IDs: {sorted(missing)}")
    else:
        available_splits = {
            task.oracle.get("benchmark_split") for task, _ in selected
        } - {None}
        selected_split = args.benchmark_split
        if selected_split == "auto":
            selected_split = "primary" if "primary" in available_splits else "all"
        effective_benchmark_split = selected_split
        if selected_split != "all":
            selected = [
                item for item in selected
                if item[0].oracle.get("benchmark_split") == selected_split
            ]
    filters = (
        ("family", set(args.family), lambda task: task.category),
        ("semantic case", set(args.semantic_case_id),
         lambda task: task.oracle.get("semantic_case_id")),
        ("configuration variant", set(args.configuration_variant),
         lambda task: task.oracle.get("configuration_variant")),
    )
    for label, wanted, value in filters:
        if not wanted:
            continue
        available = {value(task) for task, _ in selected}
        missing = wanted - available
        if missing:
            parser.error(f"unknown or selection-excluded {label} values: {sorted(missing)}")
        selected = [item for item in selected if value(item[0]) in wanted]
    conditions = select_conditions(args.condition or None)
    if not selected:
        parser.error("no benchmark tasks selected")

    load_dotenv(Path(__file__).resolve().parents[2] / ".env")
    text_ask = lambda prompt: invoke_modelica_model(  # noqa: E731
        args.model, TEXT_PREFIX, prompt, os.getenv("OPENROUTER_API_KEY")
    )
    json_ask = lambda prompt: invoke_modelica_model(  # noqa: E731
        args.model, JSON_PREFIX, prompt, os.getenv("OPENROUTER_API_KEY")
    )
    baseline_ask = lambda prompt: invoke_modelica_model(  # noqa: E731
        args.baseline_model,
        TEXT_PREFIX,
        prompt,
        os.getenv("OPENROUTER_API_KEY"),
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
        baseline_ask=baseline_ask,
        baseline_model=args.baseline_model,
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
        "artifact_mode": (
            "modelica_only"
            if all(task.profile == "capability" for task, _ in selected)
            else "modelica_openusd"
        ),
        "pipeline": (
            "nl_ir_modelica_compile_fmu_execute_spec"
            if all(task.profile == "capability" for task, _ in selected)
            else "legacy_profile_dispatch"
        ),
        # Backward-compatible names now refer to the single-generator arm.
        "single_model": args.baseline_model,
        "single_provider": "openrouter",
        "support_model": args.model,
        "support_provider": "openrouter",
        "baseline_model": args.baseline_model,
        "baseline_provider": "openrouter",
        "openrouter_transport": openrouter_transport_config(),
        "model_policy": "frozen_open_model_roster_only",
        "moe_configuration": "shared_with_sysml_pipeline",
        "modelica_backend": args.modelica_backend,
        "modelica_subset": args.modelica_subset,
        "k": args.k,
        "max_tool_repairs": args.max_tool_repairs,
        "runtime_repair_policy": (
            "tool_conditions_only_monotonic_recompile_reexecute_recheck_behavior"
        ),
        "max_runtime_repairs": args.max_tool_repairs,
        "runtime_repair_model": args.model,
        "runtime_repair_provider": "openrouter",
        "rag_routing": (
            "family_preferred_4_of_5_with_global_fallback"
            if any(task.oracle.get("rag_route") for task, _ in selected)
            else "unrestricted_semantic"
        ),
        "benchmark_manifest": audit["manifest"],
        "benchmark_manifest_sha256": audit["manifest_sha256"],
        "benchmark_split": effective_benchmark_split,
        "family_filter": sorted(set(args.family)),
        "semantic_case_filter": sorted(set(args.semantic_case_id)),
        "configuration_variant_filter": sorted(set(args.configuration_variant)),
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
        "require_complete_moe": True,
        "shard_count": args.shard_count,
        "shard_assignment": "category_stratified_task_block_round_robin",
    }
    randomize_task_order = (
        getattr(suite, "benchmark_id", "")
        in {
            "robotics-pipeline-prompt-corpus-v1",
            "robotics-pipeline-execution-corpus-v2",
            "robotics-paper-execution-evaluation-candidate-v2",
        }
    )
    configuration["task_order"] = (
        "seeded_randomized" if randomize_task_order else "canonical"
    )
    protocol, configuration = freeze_protocol(
        repository=Path(__file__).resolve().parents[2],
        output_dir=args.output_dir,
        tasks=selected,
        conditions=conditions,
        variant=args.variant,
        repetitions=args.repetitions,
        configuration=configuration,
        randomization_seed=args.randomization_seed,
        randomize_task_order=randomize_task_order,
    )
    size = experiment_size(len(selected), len(conditions), 1, args.repetitions)
    print(json.dumps({"experiment_size": size, "configuration": configuration},
                     indent=2))
    if args.dry_run:
        print(json.dumps({
            "stage": "ablation_dry_run",
            "task_ids": [task.id for task, _ in selected],
            "condition_ids": [condition.id for condition in conditions],
            "variant": args.variant,
            "repetitions": args.repetitions,
            "cell_count": size["run_cells"],
            "randomization_seed": args.randomization_seed,
            "protocol_core_sha256": protocol["protocol_core_sha256"],
            "planned_cells": protocol["planned_cells"],
        }, indent=2))
        return
    preflight_suffix = (
        "" if args.shard_count == 1 else
        f"-shard-{args.shard_index:03d}-of-{args.shard_count:03d}"
    )
    modelica_required = any(task.profile != "openusd" for task, _ in selected)
    modelica_preflight = (
        _preflight_modelica_backend(
            modelica,
            args.output_dir / f"runtime-preflight{preflight_suffix}" / "modelica",
        ) if modelica_required else {
            "stage": "modelica_runtime_preflight",
            "success": True,
            "required": False,
            "skipped": True,
            "diagnostics": [],
        }
    )
    fmi_preflight = _preflight_fmi_runtime(
        modelica,
        args.output_dir / f"runtime-preflight{preflight_suffix}" / "fmi",
    ) if modelica_required else {
        "stage": "fmi_runtime_preflight",
        "success": True,
        "required": False,
        "skipped": True,
        "diagnostics": [],
    }
    llm_preflight = _preflight_llm_environment(
        model=args.model, provider=args.provider,
        repository=Path(__file__).resolve().parents[2],
        require_moe=any(condition.moe for condition in conditions),
        baseline_model=args.baseline_model,
        require_baseline=any(not condition.moe for condition in conditions),
    )
    preflight = {
        "stage": "robotics_experiment_runtime_preflight",
        "success": (
            modelica_preflight["success"] is True
            and fmi_preflight["success"] is True
            and llm_preflight["success"] is True
        ),
        "modelica": modelica_preflight,
        "fmi": fmi_preflight,
        "llm": llm_preflight,
        "diagnostics": (
            modelica_preflight["diagnostics"] + fmi_preflight["diagnostics"]
            + llm_preflight["diagnostics"]
        ),
    }
    write_json(
        args.output_dir / f"runtime-preflight{preflight_suffix}.json", preflight
    )
    if preflight["success"] is not True:
        diagnostics = "; ".join(preflight["diagnostics"]) or "unknown failure"
        parser.error(
            "runtime preflight failed before experiment cells: "
            f"{diagnostics}"
        )
    runner = AblationRunner(
        args.output_dir, configuration=configuration,
        randomization_seed=args.randomization_seed,
        randomize_task_order=randomize_task_order,
        shard_count=args.shard_count,
        shard_index=args.shard_index,
    )
    records = runner.run(
        selected, conditions, executor,
        variant=args.variant,
        repetitions=args.repetitions,
        resume=not args.no_resume,
    )
    summary = summarize_records(records)
    summary["run_control"] = runner.last_run_control
    summary["protocol_core_sha256"] = protocol["protocol_core_sha256"]
    summary_name = (
        "summary.json" if args.shard_count == 1 else
        f"summary-shard-{args.shard_index:03d}-of-{args.shard_count:03d}.json"
    )
    write_json(args.output_dir / summary_name, summary)
    print(json.dumps(summary, indent=2, allow_nan=False))


def _load_suite(manifest_path: Path | None):
    if manifest_path is not None and CapabilityBenchmarkSuite.supports(manifest_path):
        return CapabilityBenchmarkSuite(manifest_path)
    return BenchmarkSuite(manifest_path=manifest_path)


def _preflight_modelica_backend(pipeline: ModelicaPipeline,
                                output_dir: Path) -> dict:
    """Build known-good source so backend failures stop before paid model calls."""
    source = """model NL2RoboticsRuntimePreflight
  Real x(start=1.0, fixed=true);
equation
  der(x) = -x;
end NL2RoboticsRuntimePreflight;
"""
    result = pipeline.compile(source, output_dir=output_dir)
    build = result.build
    return {
        "stage": "modelica_runtime_preflight",
        "success": result.passed,
        "requested_backend": pipeline.runner.backend,
        "resolved_backend": pipeline.runner.resolved_backend(),
        "available": build.available,
        "checked": build.checked,
        "compiled": build.compiled,
        "diagnostics": [item.message for item in build.diagnostics],
    }


def _preflight_fmi_runtime(pipeline: ModelicaPipeline,
                           output_dir: Path | None = None) -> dict:
    """Exercise the exact export, FMI metadata, execution, trace, and monitor path."""
    source = """model NL2RoboticsFMIPreflight
  parameter Real fact_parameters_decay_value = 1.0;
  output Real trace_state;
  Real x(start=1.0, fixed=true);
equation
  der(x) = -fact_parameters_decay_value*x;
  trace_state = x;
end NL2RoboticsFMIPreflight;
"""
    ir = {
        "task_id": "NL2RoboticsFMIPreflight",
        "properties": [{
            "id": "bounded_state", "kind": "always",
            "interface_id": "state", "lower": 0.0, "upper": 1.0,
        }],
    }
    contract = {
        "contract_kind": "modelica_capability_execution",
        "model_name": "NL2RoboticsFMIPreflight",
        "clock": {"duration": 0.2, "frequency_hz": 50.0},
        "mappings": [{
            "id": "map_state", "interface_id": "state",
            "state_id": "state", "fmu_variable": "trace_state",
            "required": True,
        }],
        "parameter_mappings": [{
            "id": "fact_decay", "fact_id": "parameters.decay.value",
            "fmu_variable": "fact_parameters_decay_value",
            "expected_value": 1.0, "source_unit": "unspecified",
            "required": True,
        }],
    }
    root = output_dir or Path("/private/tmp/nl2robotics-fmi-preflight")
    result = CapabilityExecutionPipeline(
        modelica_runner=pipeline.runner,
        fmi_runner=pipeline.fmi_runner,
    ).run(source, ir, contract, output_dir=root)
    diagnostics = []
    if result.get("passed") is not True:
        diagnostics.append(
            "FMI export/execution preflight failed at "
            f"{result.get('failure_stage') or 'unknown stage'}"
        )
        for row in result.get("fmu", {}).get("diagnostics", []):
            if isinstance(row, dict) and row.get("message"):
                diagnostics.append(str(row["message"]))
        for row in result.get("execution", {}).get("diagnostics", []):
            if isinstance(row, dict) and row.get("message"):
                diagnostics.append(str(row["message"]))
    return {
        "stage": "fmi_runtime_preflight",
        "success": result.get("passed") is True,
        "required": True,
        "image": pipeline.fmi_runner.image,
        "available": result.get("execution", {}).get("available", False),
        "fmu_exported": result.get("fmu", {}).get("success") is True,
        "interface_valid": result.get("contract", {}).get("success") is True,
        "execution_completed": result.get("execution_completed") is True,
        "trace_valid": result.get("trace_gate", {}).get("success") is True,
        "behavior_passed": result.get("behavior_passed") is True,
        "diagnostics": diagnostics,
        "report": result,
    }


def _preflight_llm_environment(*, model: str, provider: str | None,
                               repository: Path,
                               require_moe: bool = True,
                               baseline_model: str | None = None,
                               require_baseline: bool = False) -> dict:
    """Validate credentials and make one bounded model-compatibility request."""
    load_dotenv(repository / ".env")
    diagnostics = []
    routes = modelica_moe_routing()
    inferred_provider = routes["routes"].get(model)
    if inferred_provider is None:
        try:
            inferred_provider = provider_for_model(model)
        except RuntimeError as exc:
            diagnostics.append(str(exc))
    selected_provider = provider or inferred_provider
    if provider and inferred_provider and provider != inferred_provider:
        diagnostics.append(
            f"provider {provider!r} is incompatible with model {model!r}; "
            f"expected {inferred_provider!r}"
        )
    cli_present = None
    if selected_provider in {"codex", "claude"}:
        cli_present = bool(shutil.which(selected_provider))
        if not cli_present:
            diagnostics.append(f"{selected_provider} CLI is not available on PATH")

    route_values = set(routes["routes"].values())
    openrouter_ready = bool(os.getenv("OPENROUTER_API_KEY"))
    gemini_ready = bool(os.getenv("GEMINI_API_KEY"))
    if selected_provider == "openrouter" and not openrouter_ready:
        diagnostics.append("OPENROUTER_API_KEY is required by the support model")
    if selected_provider == "gemini" and not gemini_ready:
        diagnostics.append("GEMINI_API_KEY is required by the support model")
    if require_moe and "openrouter" in route_values and not openrouter_ready:
        diagnostics.append("OPENROUTER_API_KEY is required by the frozen MoE roster")
    if require_moe and "gemini" in route_values and not gemini_ready:
        diagnostics.append("GEMINI_API_KEY is required by the frozen MoE roster")
    baseline_route = None
    if require_baseline:
        baseline_route = routes["routes"].get(baseline_model)
        if baseline_route is None:
            diagnostics.append(
                f"baseline model {baseline_model!r} is not in the frozen roster"
            )
        elif baseline_route == "openrouter" and not openrouter_ready:
            diagnostics.append(
                "OPENROUTER_API_KEY is required by the frozen baseline model"
            )
        elif baseline_route == "gemini" and not gemini_ready:
            diagnostics.append(
                "GEMINI_API_KEY is required by the frozen baseline model"
            )

    model_probe_attempted = False
    model_probe_passed = False
    if not diagnostics and selected_provider:
        model_probe_attempted = True
        try:
            if selected_provider in {"openrouter", "gemini"}:
                probe_text = invoke_modelica_model(
                    model,
                    TEXT_PREFIX,
                    "Reply with exactly READY and nothing else.",
                    os.getenv("OPENROUTER_API_KEY"),
                )
                if probe_text.strip() != "READY":
                    raise RuntimeError(
                        "model probe returned no exact READY completion"
                    )
            else:
                probe_completion(
                    model=model, provider=selected_provider, timeout=120
                )
            model_probe_passed = True
        except Exception as exc:  # surfaced as infrastructure, never a model outcome
            diagnostics.append(
                f"{selected_provider} model probe failed for {model!r}: {exc}"
            )
    return {
        "stage": "llm_transport_preflight",
        "success": not diagnostics,
        "single_model": baseline_model if require_baseline else None,
        "single_provider": baseline_route if require_baseline else None,
        "support_model": model,
        "support_provider": selected_provider,
        "requested_provider": provider,
        "resolved_provider": selected_provider,
        "provider_cli_present": cli_present,
        "model_probe_attempted": model_probe_attempted,
        "model_probe_passed": model_probe_passed,
        "baseline_required": require_baseline,
        "baseline_model": baseline_model,
        "baseline_route": baseline_route,
        "moe_required": require_moe,
        "moe_backend": routes["backend"],
        "moe_routes": routes["routes"],
        "openrouter_key_present": openrouter_ready,
        "gemini_key_present": gemini_ready,
        "diagnostics": diagnostics,
    }


if __name__ == "__main__":
    main()
