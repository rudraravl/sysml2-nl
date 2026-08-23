"""Validate every frozen development oracle at its available execution level."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from nl2robotics.contracts.hybrid_contract import load_json
from nl2robotics.hybrid.isaac_bundle import prepare_isaac_bundle
from nl2robotics.hybrid.portable import PortableHybridPipeline
from nl2robotics.modelica.openmodelica import OpenModelicaRunner
from nl2robotics.modelica.pipeline import ModelicaPipeline
from nl2robotics.openusd.validator import OpenUSDValidator

from .suite import BenchmarkSuite


def validate_suite(output_dir: Path, *, modelica_backend: str = "docker") -> dict:
    suite = BenchmarkSuite()
    static = suite.audit()
    output_dir.mkdir(parents=True, exist_ok=True)
    if not static["success"]:
        return {"stage": "benchmark_validation", "success": False,
                "static_audit": static, "oracles": []}

    evaluation_tasks = {
        item["id"]: item for item in json.loads(
            (Path(__file__).resolve().parents[1] / "modelica" / "examples"
             / "evaluation_tasks.json").read_text(encoding="utf-8")
        )
    }
    runner = OpenModelicaRunner(backend=modelica_backend)
    modelica = ModelicaPipeline(runner=runner)
    portable = PortableHybridPipeline(modelica_runner=runner)
    usd_validator = OpenUSDValidator()
    rows = []

    for task in suite.tasks:
        task_output = output_dir / task.id
        if task.profile == "modelica":
            oracle = (suite.root / task.oracle["artifact"]).resolve()
            config = evaluation_tasks[task.oracle["evaluation_task_id"]]
            result = modelica.evaluate(
                oracle.read_text(encoding="utf-8"), config["properties"],
                output_dir=task_output, **config["simulation"],
            )
            rows.append({
                "task_id": task.id, "profile": task.profile,
                "target_level": task.target_level, "success": result.passed,
                "executed": result.run.simulated,
                "properties": [
                    {"id": item.property_id, "passed": item.passed,
                     "robustness": item.robustness}
                    for item in result.properties
                ],
            })
        elif task.profile == "openusd":
            oracle = (suite.root / task.oracle["artifact"]).resolve()
            result = usd_validator.validate(oracle, output_dir=task_output)
            counts = result.to_dict().get("counts", {})
            required = task.oracle.get("required_counts", {})
            count_match = all(counts.get(key) == value for key, value in required.items())
            rows.append({
                "task_id": task.id, "profile": task.profile,
                "target_level": task.target_level,
                "success": result.success and count_match,
                "executed": False, "semantic_valid": result.semantic_valid,
                "required_counts": required, "actual_counts": counts,
            })
        else:
            bundle = (suite.root / task.oracle["bundle"]).resolve()
            if task.target_level == "portable_h1":
                result = portable.run(
                    (bundle / "model.mo").read_text(encoding="utf-8"),
                    bundle / "scene.usda",
                    load_json(bundle / "requirement_ir.json"),
                    load_json(bundle / "contract.json"),
                    output_dir=task_output,
                )
                rows.append({
                    "task_id": task.id, "profile": task.profile,
                    "target_level": task.target_level,
                    "success": result.get("passed") is True,
                    "executed": result.get("execution", {}).get("success") is True,
                    "contract_valid": result.get("contract", {}).get("success"),
                    "all_properties_pass": bool(result.get("properties")) and all(
                        item.get("passed") is True for item in result["properties"]
                    ),
                })
            else:
                result = prepare_isaac_bundle(
                    modelica_path=bundle / "model.mo",
                    usd_path=bundle / "scene.usda",
                    requirement_ir_path=bundle / "requirement_ir.json",
                    contract_path=bundle / "contract.json",
                    output_dir=task_output / "isaac-input",
                    modelica_backend=modelica_backend,
                )
                rows.append({
                    "task_id": task.id, "profile": task.profile,
                    "target_level": task.target_level,
                    "success": result.get("success") is True,
                    "executed": False,
                    "prepared_for_external_runtime": result.get("success") is True,
                    "claim_eligible_h2": False,
                })
    success = all(item["success"] for item in rows)
    return {
        "stage": "benchmark_validation",
        "schema_version": "1.0",
        "success": success,
        "claim_eligible_h2": False,
        "static_audit": static,
        "oracle_count": len(rows),
        "oracles": rows,
        "external_actions": [
            "Run RBH005 in Isaac Sim 6.0 three times on supported RTX hardware."
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--modelica-backend", choices=("auto", "local", "docker"),
                        default="docker")
    args = parser.parse_args()
    report = validate_suite(args.output_dir, modelica_backend=args.modelica_backend)
    path = args.output_dir / "benchmark-validation.json"
    path.write_text(
        json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(report, indent=2, allow_nan=False))
    raise SystemExit(0 if report["success"] else 1)


if __name__ == "__main__":
    main()
