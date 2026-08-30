"""Resumable experiment runner independent of any one LLM transport."""

from __future__ import annotations

from collections.abc import Callable, Iterable
import hashlib
import json
from pathlib import Path
import random
import time

from nl2robotics.benchmark.suite import BenchmarkTask
from spec_aligner.llm import is_cli_usage_limit_message

from .conditions import AblationCondition
from .metrics import extract_metrics
from .records import run_fingerprint, write_json


Execute = Callable[..., dict]


class AblationRunner:
    """Run a frozen task-condition matrix and checkpoint every independent cell."""

    def __init__(self, output_dir: Path, *, configuration: dict | None = None,
                 randomization_seed: int = 20260830):
        self.output_dir = output_dir
        self.configuration = configuration or {}
        self.randomization_seed = randomization_seed
        self.last_run_control: dict = {}

    def run(self, tasks: Iterable[tuple[BenchmarkTask, str]],
            conditions: Iterable[AblationCondition], execute: Execute, *,
            variant: str, repetitions: int = 1,
            resume: bool = True) -> list[dict]:
        if repetitions < 1:
            raise ValueError("repetitions must be positive")
        task_rows = sorted(list(tasks), key=lambda item: item[0].id)
        condition_rows = list(conditions)
        cells = planned_cells(
            task_rows, condition_rows, repetitions=repetitions,
            seed=self.randomization_seed,
        )
        records = []
        block_contexts: dict[tuple[str, int], dict | None] = {}
        block_errors: dict[tuple[str, int], str | None] = {}
        stop_reason = None
        for order_index, cell in enumerate(cells):
            task, prompt = cell["task"], cell["prompt"]
            condition, repetition = cell["condition"], cell["repetition"]
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
                cached = json.loads(path.read_text(encoding="utf-8"))
                if (_resumable(cached, fingerprint)):
                    records.append(cached)
                    continue
            block_key = (task.id, repetition)
            if block_key not in block_contexts:
                prepare = getattr(execute, "prepare_block", None)
                try:
                    block_contexts[block_key] = (
                        prepare(
                            task, prompt, repetition,
                            self.output_dir / "paired-blocks" / task.id
                            / variant / f"repeat-{repetition:02d}",
                        ) if callable(prepare) else None
                    )
                except Exception as exc:
                    if is_cli_usage_limit_message(str(exc)):
                        stop_reason = str(exc)
                        break
                    block_contexts[block_key] = None
                    block_errors[block_key] = str(exc)
                else:
                    block_errors[block_key] = None
            block_prepare_error = block_errors.get(block_key)
            started = time.monotonic()
            infrastructure_error = block_prepare_error
            result: dict = {}
            if infrastructure_error is None:
                try:
                    if block_contexts[block_key] is None:
                        result = execute(
                            task, condition, prompt, run_dir / "artifacts"
                        )
                    else:
                        result = execute(
                            task, condition, prompt, run_dir / "artifacts",
                            block_context=block_contexts[block_key],
                        )
                except Exception as exc:
                    if is_cli_usage_limit_message(str(exc)):
                        stop_reason = str(exc)
                        break
                    infrastructure_error = str(exc)
            if _contains_usage_limit(result):
                stop_reason = "provider usage limit detected in cell result"
                break
            duration = time.monotonic() - started
            record = {
                "schema_version": "1.1",
                "fingerprint": fingerprint,
                "planned_order_index": order_index,
                "randomization_seed": self.randomization_seed,
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
        self.last_run_control = {
            "schema_version": "1.0",
            "stage": "ablation_run_control",
            "randomization_seed": self.randomization_seed,
            "planned_cell_count": len(cells),
            "completed_or_resumed_cell_count": len(records),
            "stopped_early": stop_reason is not None,
            "stop_reason": stop_reason,
        }
        write_json(self.output_dir / "run-control.json", self.last_run_control)
        return records


def planned_cells(tasks: Iterable[tuple[BenchmarkTask, str]],
                  conditions: Iterable[AblationCondition], *, repetitions: int,
                  seed: int) -> list[dict]:
    """Return deterministic blocked randomization: task/repeat, then condition."""
    rows = []
    condition_rows = list(conditions)
    for task, prompt in sorted(tasks, key=lambda item: item[0].id):
        for repetition in range(repetitions):
            shuffled = list(condition_rows)
            digest = hashlib.sha256(
                f"{seed}:{task.id}:{repetition}".encode("utf-8")
            ).digest()
            random.Random(int.from_bytes(digest[:8], "big")).shuffle(shuffled)
            for condition in shuffled:
                rows.append({
                    "task": task,
                    "prompt": prompt,
                    "condition": condition,
                    "repetition": repetition,
                })
    return rows


def _resumable(record: dict, fingerprint: str) -> bool:
    return (
        record.get("schema_version") == "1.1"
        and record.get("fingerprint") == fingerprint
        and record.get("metrics", {}).get("infrastructure_available") is True
        and record.get("result", {}).get("study_validity", {}).get("eligible")
        is not False
    )


def _contains_usage_limit(result: dict) -> bool:
    if not result:
        return False
    try:
        text = json.dumps(result, sort_keys=True)
    except (TypeError, ValueError):
        text = str(result)
    return is_cli_usage_limit_message(text)


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
