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
                 randomization_seed: int = 20260830,
                 randomize_task_order: bool = False,
                 shard_count: int = 1, shard_index: int = 0):
        if shard_count < 1:
            raise ValueError("shard_count must be positive")
        if shard_index < 0 or shard_index >= shard_count:
            raise ValueError("shard_index must be in [0, shard_count)")
        self.output_dir = output_dir
        self.configuration = configuration or {}
        self.randomization_seed = randomization_seed
        self.randomize_task_order = randomize_task_order
        self.shard_count = shard_count
        self.shard_index = shard_index
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
            randomize_task_order=self.randomize_task_order,
        )
        records = []
        block_contexts: dict[tuple[str, int], dict | None] = {}
        block_errors: dict[tuple[str, int], str | None] = {}
        stop_reason = None
        assigned_cells = _assigned_cells(
            cells,
            shard_count=self.shard_count,
            shard_index=self.shard_index,
            seed=self.randomization_seed,
        )
        for order_index, cell in assigned_cells:
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
            "randomize_task_order": self.randomize_task_order,
            "shard_count": self.shard_count,
            "shard_index": self.shard_index,
            "planned_cell_count": len(cells),
            "assigned_cell_count": len(assigned_cells),
            "completed_or_resumed_cell_count": len(records),
            "stopped_early": stop_reason is not None,
            "stop_reason": stop_reason,
        }
        control_name = (
            "run-control.json" if self.shard_count == 1 else
            f"run-control-shard-{self.shard_index:03d}-of-{self.shard_count:03d}.json"
        )
        write_json(self.output_dir / control_name, self.last_run_control)
        return records


def planned_cells(tasks: Iterable[tuple[BenchmarkTask, str]],
                  conditions: Iterable[AblationCondition], *, repetitions: int,
                  seed: int, randomize_task_order: bool = False) -> list[dict]:
    """Return deterministic blocked randomization: task/repeat, then condition."""
    rows = []
    condition_rows = list(conditions)
    task_blocks = [
        (task, prompt, repetition)
        for task, prompt in sorted(tasks, key=lambda item: item[0].id)
        for repetition in range(repetitions)
    ]
    if randomize_task_order:
        digest = hashlib.sha256(f"{seed}:task-block-order".encode("utf-8")).digest()
        random.Random(int.from_bytes(digest[:8], "big")).shuffle(task_blocks)
    for task, prompt, repetition in task_blocks:
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


def _assigned_cells(cells: list[dict], *, shard_count: int,
                    shard_index: int, seed: int) -> list[tuple[int, dict]]:
    """Keep task/repetition blocks together and balance each category."""
    category_counts: dict[str, int] = {}
    category_offsets: dict[str, int] = {}
    block_shards: dict[tuple[str, int], int] = {}
    assigned = []
    for order_index, cell in enumerate(cells):
        task = cell["task"]
        block_key = (task.id, cell["repetition"])
        if block_key not in block_shards:
            category = task.category
            if category not in category_offsets:
                digest = hashlib.sha256(
                    f"{seed}:{category}:shard-offset".encode("utf-8")
                ).digest()
                category_offsets[category] = (
                    int.from_bytes(digest[:8], "big") % shard_count
                )
            rank = category_counts.get(category, 0)
            block_shards[block_key] = (
                category_offsets[category] + rank
            ) % shard_count
            category_counts[category] = rank + 1
        if block_shards[block_key] == shard_index:
            assigned.append((order_index, cell))
    return assigned


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
