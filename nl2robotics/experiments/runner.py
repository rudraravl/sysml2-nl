"""Resumable experiment runner independent of any one LLM transport."""

from __future__ import annotations

from collections.abc import Callable, Iterable
from pathlib import Path
import time

from nl2robotics.benchmark.suite import BenchmarkTask

from .conditions import AblationCondition
from .metrics import extract_metrics
from .records import run_fingerprint, write_json


Execute = Callable[[BenchmarkTask, AblationCondition, str, Path], dict]


class AblationRunner:
    """Run a frozen task-condition matrix and checkpoint every independent cell."""

    def __init__(self, output_dir: Path, *, configuration: dict | None = None):
        self.output_dir = output_dir
        self.configuration = configuration or {}

    def run(self, tasks: Iterable[tuple[BenchmarkTask, str]],
            conditions: Iterable[AblationCondition], execute: Execute, *,
            variant: str, repetitions: int = 1,
            resume: bool = True) -> list[dict]:
        if repetitions < 1:
            raise ValueError("repetitions must be positive")
        records = []
        for task, prompt in sorted(tasks, key=lambda item: item[0].id):
            for condition in conditions:
                for repetition in range(repetitions):
                    run_dir = (
                        self.output_dir / task.id / variant / condition.id
                        / f"repeat-{repetition:02d}"
                    )
                    path = run_dir / "run.json"
                    fingerprint = run_fingerprint(
                        task_id=task.id, condition=condition.to_dict(),
                        variant=variant, repetition=repetition, prompt=prompt,
                        configuration=self.configuration,
                    )
                    if resume and path.is_file():
                        import json
                        cached = json.loads(path.read_text(encoding="utf-8"))
                        if cached.get("fingerprint") == fingerprint:
                            records.append(cached)
                            continue
                    started = time.monotonic()
                    infrastructure_error = None
                    try:
                        result = execute(task, condition, prompt, run_dir / "artifacts")
                    except Exception as exc:
                        result = {}
                        infrastructure_error = str(exc)
                    duration = time.monotonic() - started
                    record = {
                        "schema_version": "1.0",
                        "fingerprint": fingerprint,
                        "task_id": task.id,
                        "profile": task.profile,
                        "difficulty": task.difficulty,
                        "condition": condition.to_dict(),
                        "variant": variant,
                        "repetition": repetition,
                        "configuration": self.configuration,
                        "duration_seconds": duration,
                        "infrastructure_error": infrastructure_error,
                        "metrics": extract_metrics(
                            task.profile, result,
                            infrastructure_error=infrastructure_error,
                        ),
                        "result": result,
                    }
                    write_json(path, record)
                    records.append(record)
        return records


def experiment_size(task_count: int, condition_count: int,
                    variant_count: int, repetitions: int) -> dict:
    cells = task_count * condition_count * variant_count * repetitions
    return {
        "task_count": task_count,
        "condition_count": condition_count,
        "variant_count": variant_count,
        "repetitions": repetitions,
        "run_cells": cells,
    }
