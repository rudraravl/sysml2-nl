"""Run a prepared H2 bundle with pinned Newton Physics on CPU or CUDA."""

from __future__ import annotations

import argparse
from dataclasses import asdict
import json
from pathlib import Path
import traceback


def main() -> None:
    args = _arguments()
    report = run_newton_bundle(
        bundle_path=args.bundle,
        output_dir=args.output_dir,
        controller_backend=args.controller_backend,
        fmi_runtime_image=args.fmi_runtime_image,
        device=args.device,
        solver=args.solver,
        newton_version=args.newton_version,
        repetitions=args.repetitions,
        repeatability_tolerance=args.repeatability_tolerance,
    )
    print(json.dumps(report, indent=2, allow_nan=False))
    raise SystemExit(0 if report.get("success") is True else 1)


def run_newton_bundle(*, bundle_path: Path, output_dir: Path,
                      controller_backend: str = "local",
                      fmi_runtime_image: str = "nl2robotics-fmi-runtime:0.1",
                      device: str = "cuda:0", solver: str = "featherstone",
                      newton_version: str = "1.5.0", repetitions: int = 3,
                      repeatability_tolerance: float = 1e-6) -> dict:
    """Execute one verified bundle and persist the complete Newton report.

    This public entry point lets the experiment runner use the exact same
    fail-closed path as the command-line tool instead of shelling out or
    duplicating claim logic.
    """
    if controller_backend not in {"local", "docker"}:
        raise ValueError("controller_backend must be local or docker")
    if solver not in {"featherstone", "mujoco_warp"}:
        raise ValueError("unsupported Newton solver")
    if repetitions < 1:
        raise ValueError("repetitions must be positive")
    if repeatability_tolerance < 0:
        raise ValueError("repeatability_tolerance must be non-negative")
    output_dir.mkdir(parents=True, exist_ok=True)
    args = argparse.Namespace(
        bundle=bundle_path,
        output_dir=output_dir,
        controller_backend=controller_backend,
        fmi_runtime_image=fmi_runtime_image,
        device=device,
        solver=solver,
        newton_version=newton_version,
        repetitions=repetitions,
        repeatability_tolerance=repeatability_tolerance,
    )
    try:
        report = _run(args)
    except Exception as exc:
        report = {
            "stage": "newton_closed_loop",
            "success": False,
            "passed": False,
            "claim_eligible_h2": False,
            "claim_eligible_newton_h2": False,
            "claim_eligible_deltaai_h2": False,
            "claim_eligible_isaac_h2": False,
            "error": f"{type(exc).__name__}: {exc}",
            "traceback": traceback.format_exc(),
        }
    (output_dir / "newton-report.json").write_text(
        json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    return report


def _run(args: argparse.Namespace) -> dict:
    from nl2robotics.alignment.evaluator import RoboticsAlignmentEvaluator
    from nl2robotics.modelica.fmi_controller import (
        FMIContainerControllerRuntime,
        FMPyControllerRuntime,
    )

    from .closed_loop import ClosedLoopMaster
    from .closed_loop_properties import evaluate_closed_loop_properties
    from .newton_backend import NewtonPhysics
    from .newton_bundle import load_newton_bundle
    from .repeatability import compare_traces

    bundle = load_newton_bundle(args.bundle)
    artifacts = bundle["resolved_artifacts"]
    runs = []
    trace_paths = []
    for index in range(args.repetitions):
        controller = (
            FMPyControllerRuntime(artifacts["fmu"])
            if args.controller_backend == "local"
            else FMIContainerControllerRuntime(
                artifacts["fmu"], image=args.fmi_runtime_image
            )
        )
        physics = NewtonPhysics(
            stage_path=artifacts["openusd"],
            mappings=bundle["resolved_mappings"],
            device=args.device,
            solver=args.solver,
            required_version=args.newton_version,
        )
        execution = ClosedLoopMaster().run(
            controller,
            physics,
            mappings=bundle["resolved_mappings"],
            clock=bundle["clock"],
            coupling=bundle["coupling"],
            output_dir=args.output_dir / f"run-{index + 1:03d}",
        )
        properties = []
        if execution.get("success") is True:
            properties = evaluate_closed_loop_properties(
                Path(execution["trace"]),
                bundle["resolved_mappings"],
                bundle["properties"],
            )
            trace_paths.append(Path(execution["trace"]))
        run_success = (
            execution.get("success") is True
            and execution.get("claim_eligible_newton_h2") is True
            and properties
            and all(item.passed for item in properties)
        )
        runs.append({
            "run": index + 1,
            "success": bool(run_success),
            "execution": execution,
            "properties": [asdict(item) for item in properties],
        })
        if not run_success:
            break

    repeatability = compare_traces(
        trace_paths, tolerance=args.repeatability_tolerance
    ) if len(trace_paths) >= 2 else {
        "success": False,
        "reason": "fewer than two successful traces",
        "trace_count": len(trace_paths),
        "tolerance": args.repeatability_tolerance,
    }
    completed = len(runs) == args.repetitions and all(
        row["success"] for row in runs
    )
    simulation_success = completed and repeatability["success"]
    executions_passed = bool(runs) and all(
        row["execution"].get("success") is True for row in runs
    )
    simulator_loaded = bool(runs) and all(
        row["execution"].get("physics", {}).get("backend") == "newton_physics"
        and row["execution"].get("physics", {}).get("runtime_verified") is True
        for row in runs
    )
    reported_properties = runs[-1]["properties"] if runs else []
    requirement_ir = json.loads(
        artifacts["requirement_ir"].read_text(encoding="utf-8")
    )
    contract = json.loads(artifacts["contract"].read_text(encoding="utf-8"))
    preflight = bundle.get("preflight", {})
    alignment = RoboticsAlignmentEvaluator().evaluate(
        requirement_ir,
        modelica=artifacts["modelica"].read_text(encoding="utf-8"),
        openusd=artifacts["openusd"].read_text(encoding="utf-8"),
        contract=contract,
        hybrid_report={
            "contract": preflight.get("contract_validation", {}),
            "controller_conformance": preflight.get(
                "controller_conformance", {}
            ),
            "properties": reported_properties,
        },
    )
    (args.output_dir / "post-execution-alignment.json").write_text(
        json.dumps(alignment, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    success = simulation_success and alignment.get("claim_ready") is True
    claim_eligible = success and args.repetitions >= 3
    return {
        "stage": "newton_closed_loop",
        "success": success,
        "passed": success,
        "claim_eligible_h2": claim_eligible,
        "claim_eligible_newton_h2": claim_eligible,
        "claim_eligible_deltaai_h2": bool(
            claim_eligible
            and runs
            and all(
                row["execution"].get("claim_eligible_deltaai_h2") is True
                for row in runs
            )
        ),
        "claim_eligible_isaac_h2": False,
        "task_id": bundle["task_id"],
        "bundle_manifest": str(bundle["manifest_path"]),
        "bundle_manifest_sha256": bundle["manifest_sha256"],
        "required_repetitions": args.repetitions,
        "completed_repetitions": len(runs),
        "configuration": {
            "controller_backend": args.controller_backend,
            "device": args.device,
            "solver": args.solver,
            "newton_version": args.newton_version,
            "repeatability_tolerance": args.repeatability_tolerance,
        },
        "contract": {"success": True, "source": "verified_bundle_manifest"},
        "fmu": {"success": True, "source": "verified_bundle_manifest"},
        "execution": {"success": executions_passed},
        "simulator": {"loaded": simulator_loaded, "backend": "newton_physics"},
        "properties": reported_properties,
        "repeatability": repeatability,
        "alignment": alignment,
        "runs": runs,
    }


def _arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument(
        "--controller-backend", choices=("local", "docker"), default="local"
    )
    parser.add_argument("--fmi-runtime-image", default="nl2robotics-fmi-runtime:0.1")
    parser.add_argument("--device", default="cuda:0")
    parser.add_argument(
        "--solver", choices=("featherstone", "mujoco_warp"),
        default="featherstone",
    )
    parser.add_argument("--newton-version", default="1.5.0")
    parser.add_argument("--repetitions", type=int, default=3)
    parser.add_argument("--repeatability-tolerance", type=float, default=1e-6)
    args = parser.parse_args()
    if args.repetitions < 1:
        parser.error("--repetitions must be positive")
    if args.repeatability_tolerance < 0:
        parser.error("--repeatability-tolerance must be non-negative")
    return args


if __name__ == "__main__":
    main()
