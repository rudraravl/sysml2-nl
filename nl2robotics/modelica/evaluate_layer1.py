"""Run the held-out, compile-only Modelica Layer 1 experiment."""

from __future__ import annotations

import argparse
import csv
import json
import os
from pathlib import Path

from dotenv import load_dotenv

from spec_aligner.llm import CliUsageLimitError

from .corpus import ExampleCorpus
from . import moe
from .openmodelica import OpenModelicaRunner
from .pipeline import ModelicaPipeline, clean_code


CONDITIONS = ("baseline", "rag", "full")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--conditions", nargs="+", choices=CONDITIONS, default=list(CONDITIONS)
    )
    parser.add_argument("--ids", nargs="*", help="optional held-out task IDs")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--backend", choices=("auto", "local", "docker"),
                        default="auto")
    parser.add_argument("--llm-backend", choices=("api", "cli"), default="cli")
    parser.add_argument("--single-model", default="openai/gpt-5.4")
    parser.add_argument(
        "--subset", choices=("core24", "balanced50", "full100", "full300"),
        default="full300",
    )
    parser.add_argument("-k", type=int, default=5)
    parser.add_argument("--max-repairs", type=int, default=2)
    parser.add_argument("--resume", action="store_true")
    args = parser.parse_args()

    if args.limit is not None and args.limit < 1:
        parser.error("--limit must be positive")
    if args.max_repairs < 0:
        parser.error("--max-repairs cannot be negative")

    os.environ["LLM_BACKEND"] = args.llm_backend
    load_dotenv(Path(__file__).resolve().parents[2] / ".env")
    openrouter_key = os.getenv("OPENROUTER_API_KEY")
    tasks = _load_tasks(args.ids, args.limit)
    pipeline = ModelicaPipeline(
        corpus=ExampleCorpus(subset=args.subset),
        runner=OpenModelicaRunner(backend=args.backend),
    )
    args.output_dir.mkdir(parents=True, exist_ok=True)

    rows = []
    for condition in args.conditions:
        for task in tasks:
            target = args.output_dir / condition / task["id"]
            report_file = target / "report.json"
            if args.resume and report_file.is_file():
                report = json.loads(report_file.read_text(encoding="utf-8"))
            else:
                target.mkdir(parents=True, exist_ok=True)
                try:
                    report = _run_condition(
                        condition,
                        task["requirement"],
                        pipeline,
                        target,
                        model=args.single_model,
                        openrouter_key=openrouter_key,
                        k=args.k,
                        max_repairs=args.max_repairs,
                    )
                except CliUsageLimitError:
                    raise
                except Exception as exc:
                    report = {
                        "stage": "layer1",
                        "condition": condition,
                        "passed": False,
                        "error": str(exc),
                        "attempts": [],
                    }
                report.update({
                    "task_id": task["id"],
                    "category": task["category"],
                    "requirement": task["requirement"],
                })
                report_file.write_text(
                    json.dumps(report, indent=2, allow_nan=False), encoding="utf-8"
                )
                if report.get("final_modelica"):
                    (target / "model.mo").write_text(
                        report["final_modelica"], encoding="utf-8"
                    )
            row = _metric_row(report)
            rows.append(row)
            status = "PASS" if row["final_build_passed"] else "FAIL"
            print(f"{condition:8s} {task['id']}: {status}", flush=True)

    summary = _summarize(rows, args, len(tasks))
    (args.output_dir / "summary.json").write_text(
        json.dumps(summary, indent=2, allow_nan=False), encoding="utf-8"
    )
    with (args.output_dir / "results.csv").open(
        "w", newline="", encoding="utf-8"
    ) as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(json.dumps(summary["conditions"], indent=2), flush=True)


def _load_tasks(ids: list[str] | None, limit: int | None) -> list[dict]:
    path = Path(__file__).with_name("examples") / "evaluation_tasks.json"
    tasks = json.loads(path.read_text(encoding="utf-8"))
    if ids:
        wanted = {item.upper() for item in ids}
        tasks = [task for task in tasks if task["id"].upper() in wanted]
        missing = wanted - {task["id"].upper() for task in tasks}
        if missing:
            raise ValueError(f"unknown evaluation IDs: {sorted(missing)}")
    if limit is not None:
        tasks = tasks[:limit]
    if not tasks:
        raise ValueError("no evaluation tasks selected")
    return tasks


def _run_condition(condition: str, requirement: str,
                   pipeline: ModelicaPipeline, output_dir: Path, *,
                   model: str, openrouter_key: str | None,
                   k: int, max_repairs: int) -> dict:
    if condition == "full":
        _, report = moe.generate_modelica_moe(
            requirement,
            pipeline=pipeline,
            k=k,
            max_repairs=max_repairs,
            output_dir=output_dir,
        )
        report["condition"] = condition
        return report

    if condition == "baseline":
        system, human = pipeline.build_baseline_messages(requirement)
        hits = []
    elif condition == "rag":
        system, human, hits = pipeline.build_messages(requirement, k=k)
    else:
        raise ValueError(f"unknown condition {condition!r}")

    candidate = clean_code(moe._invoke(
        model, system, human, openrouter_key
    ))
    report = pipeline.refine_layer1(
        requirement,
        candidate,
        lambda _: candidate,
        hits=hits,
        max_repairs=0,
        output_dir=output_dir,
    )
    report.update({
        "condition": condition,
        "generation_mode": "single",
        "single_model": model,
        "llm_backend": moe.sysml_moe._llm_backend(),
        "generation_prompt": f"System:\n{system}\n\nHuman:\n{human}",
    })
    return report


def _metric_row(report: dict) -> dict:
    attempts = report.get("attempts") or []
    initial = bool(attempts and attempts[0].get("passed"))
    final = bool(report.get("passed"))
    duration = sum(
        float(attempt.get("build", {}).get("duration_seconds", 0.0))
        for attempt in attempts
    )
    return {
        "task_id": report.get("task_id", ""),
        "category": report.get("category", ""),
        "condition": report.get("condition", ""),
        "initial_build_passed": initial,
        "final_build_passed": final,
        "repair_succeeded": bool(not initial and final),
        "repair_attempts": int(report.get("repairs", 0)),
        "expert_soft_fails": int(report.get("expert_soft_fail_count", 0)),
        "compiler_seconds": round(duration, 6),
        "error": report.get("error", ""),
    }


def _summarize(rows: list[dict], args: argparse.Namespace,
               task_count: int) -> dict:
    conditions = {}
    for name in args.conditions:
        selected = [row for row in rows if row["condition"] == name]
        conditions[name] = {
            "samples": len(selected),
            "initial_build_passes": sum(row["initial_build_passed"] for row in selected),
            "final_build_passes": sum(row["final_build_passed"] for row in selected),
            "repair_successes": sum(row["repair_succeeded"] for row in selected),
            "generation_errors": sum(bool(row["error"]) for row in selected),
            "compiler_seconds": round(sum(row["compiler_seconds"] for row in selected), 6),
        }
    return {
        "stage": "layer1",
        "tasks": task_count,
        "evaluation_split": "code-free held-out smoke set",
        "llm_backend": args.llm_backend,
        "single_model": args.single_model,
        "corpus_subset": args.subset,
        "retrieval_k": args.k,
        "max_repairs": args.max_repairs,
        "conditions": conditions,
        "results": rows,
    }


if __name__ == "__main__":
    main()
