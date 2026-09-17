"""Run a prepared H2 bundle inside the pinned Isaac Sim Python runtime."""

from __future__ import annotations

import argparse
from dataclasses import asdict
import json
from pathlib import Path
import traceback


def main() -> None:
    args = _arguments()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    simulation_app = None
    try:
        from isaacsim import SimulationApp

        simulation_app = SimulationApp({"headless": not args.gui})
        report = _run(args, simulation_app)
    except Exception as exc:
        report = {
            "stage": "isaac_closed_loop",
            "success": False,
            "claim_eligible_h2": False,
            "error": f"{type(exc).__name__}: {exc}",
            "traceback": traceback.format_exc(),
        }
    finally:
        if simulation_app is not None:
            simulation_app.close()
    (args.output_dir / "isaac-report.json").write_text(
        json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(report, indent=2, allow_nan=False))
    raise SystemExit(0 if report.get("success") is True else 1)


def _run(args: argparse.Namespace, simulation_app: object) -> dict:
    from nl2robotics.modelica.fmi_controller import (
        FMIContainerControllerRuntime,
        FMPyControllerRuntime,
    )
    from nl2robotics.alignment.evaluator import RoboticsAlignmentEvaluator

    from .closed_loop import ClosedLoopMaster
    from .closed_loop_properties import evaluate_closed_loop_properties
    from .isaac_backend import IsaacSimPhysics
    from .isaac_bundle import load_isaac_bundle
    from .repeatability import compare_traces

    bundle = load_isaac_bundle(args.bundle)
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
        physics = IsaacSimPhysics(
            stage_path=artifacts["openusd"],
            articulation_root=args.articulation_root,
            mappings=bundle["resolved_mappings"],
            simulation_app=simulation_app,
            device=args.device,
            solver=args.solver,
            required_version_prefix=args.isaac_version_prefix,
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
            and execution.get("claim_eligible_h2") is True
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
        row["execution"].get("physics", {}).get("backend") == "isaac_sim"
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
        "stage": "isaac_closed_loop",
        "success": success,
        "passed": success,
        "claim_eligible_h2": claim_eligible,
        "task_id": bundle["task_id"],
        "bundle_manifest": str(bundle["manifest_path"]),
        "bundle_manifest_sha256": bundle["manifest_sha256"],
        "required_repetitions": args.repetitions,
        "completed_repetitions": len(runs),
        "configuration": {
            "articulation_root": args.articulation_root,
            "controller_backend": args.controller_backend,
            "device": args.device,
            "solver": args.solver,
            "isaac_version_prefix": args.isaac_version_prefix,
            "repeatability_tolerance": args.repeatability_tolerance,
        },
        "contract": {"success": True, "source": "verified_bundle_manifest"},
        "fmu": {"success": True, "source": "verified_bundle_manifest"},
        "execution": {"success": executions_passed},
        "simulator": {"loaded": simulator_loaded, "backend": "isaac_sim"},
        "properties": reported_properties,
        "repeatability": repeatability,
        "alignment": alignment,
        "runs": runs,
    }


def _arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--articulation-root", default="/World")
    parser.add_argument("--controller-backend", choices=("local", "docker"),
                        default="local")
    parser.add_argument("--fmi-runtime-image",
                        default="nl2robotics-fmi-runtime:0.1")
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--solver", choices=("TGS", "PGS"), default="TGS")
    parser.add_argument("--isaac-version-prefix", default="6.0")
    parser.add_argument("--repetitions", type=int, default=3)
    parser.add_argument("--repeatability-tolerance", type=float, default=1e-6)
    parser.add_argument("--gui", action="store_true")
    args = parser.parse_args()
    if args.repetitions < 1:
        parser.error("--repetitions must be positive")
    if args.repeatability_tolerance < 0:
        parser.error("--repeatability-tolerance must be non-negative")
    return args


if __name__ == "__main__":
    main()
