"""Exercise the unified orchestrator with checked oracle source generators."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re

from nl2robotics.hybrid.portable import PortableHybridPipeline
from nl2robotics.modelica.openmodelica import OpenModelicaRunner
from nl2robotics.modelica.pipeline import ModelicaPipeline

from .pipeline import RoboticsOrchestrator
from .planner import build_plan


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "oracle", choices=(
            "RHY001", "RHY002", "RHY003", "RHY004",
            "RHY101", "RHY201", "RHY202", "RHY203",
        )
    )
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--backend", choices=("auto", "local", "docker"),
                        default="docker")
    args = parser.parse_args()

    oracle = Path(__file__).resolve().parents[1] / "hybrid" / "oracles" / args.oracle
    requirement_ir = json.loads(
        (oracle / "requirement_ir.json").read_text(encoding="utf-8")
    )
    plan = build_plan(requirement_ir)
    oracle_contract = json.loads(
        (oracle / "contract.json").read_text(encoding="utf-8")
    )
    modelica = _adapt_modelica_oracle(
        (oracle / "model.mo").read_text(encoding="utf-8"),
        requirement_ir,
        oracle_contract,
        plan,
    )
    openusd = (oracle / "scene.usda").read_text(encoding="utf-8")

    generated = {
        "passed": True,
        "repairs": 0,
        "generation_mode": "checked_oracle_smoke",
    }
    runner = OpenModelicaRunner(backend=args.backend)
    pipeline = RoboticsOrchestrator(
        modelica_generator=lambda requirement, output_dir: (modelica, generated),
        openusd_generator=lambda requirement, output_dir: (openusd, generated),
        modelica_pipeline=ModelicaPipeline(runner=runner),
        portable_pipeline=PortableHybridPipeline(modelica_runner=runner),
    )
    report = pipeline.run(
        requirement_ir["source_text"],
        lambda prompt: json.dumps(requirement_ir),
        output_dir=args.output_dir,
        task_id=requirement_ir["task_id"],
        execution_mode=requirement_ir["execution_mode"],
        max_ir_repairs=0,
    )
    print(json.dumps(report, indent=2, allow_nan=False))
    raise SystemExit(0 if report["passed"] or report.get("ready_for_gpu") else 1)


def _adapt_modelica_oracle(code: str, ir: dict, oracle_contract: dict,
                            plan) -> str:
    match = re.search(r"\bmodel\s+([A-Za-z_]\w*)", code)
    if not match:
        raise ValueError("oracle contains no top-level Modelica model")
    old_model = match.group(1)
    code = re.sub(rf"\b{re.escape(old_model)}\b", plan.model_name, code)
    old_variables = {
        item["interface_id"]: item["fmu_variable"]
        for item in oracle_contract.get("mappings", [])
    }
    for interface_id, new_signal in plan.identifiers[
            "interface_fmu_variables"].items():
        old_signal = old_variables.get(interface_id)
        if old_signal:
            code = re.sub(rf"\b{re.escape(old_signal)}\b", new_signal, code)
    for prop in ir.get("properties", []):
        interface_id = prop.get("interface_id")
        old_signal = prop.get("signal")
        new_signal = plan.identifiers["interface_fmu_variables"].get(interface_id)
        if old_signal and new_signal:
            code = re.sub(rf"\b{re.escape(old_signal)}\b", new_signal, code)
    return code


if __name__ == "__main__":
    main()
