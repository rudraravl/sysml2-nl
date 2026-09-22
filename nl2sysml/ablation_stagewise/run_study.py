#!/usr/bin/env python3
"""Run one resumable, sharded A1--A4 SysML ablation condition."""

from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import importlib.metadata
import json
import os
import platform
from pathlib import Path
import subprocess
import sys
import time
from typing import Any

from nl2sysml import agent_rag_moe as agent
from nl2sysml.compiler_interface import is_compiler_available
from nl2sysml.sysml_execution import ExecutionRequest, run_sysml_execution

from .conditions import get_condition
from .pipeline import InfrastructureError, StagewiseSysMLPipeline


REPOSITORY = Path(__file__).resolve().parents[2]
DEFAULT_DATASET = Path(__file__).resolve().parent / "rich500_manifest.jsonl"
DEFAULT_SEED = 20260922


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_json(value: Any) -> str:
    return _sha256_bytes(
        json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    )


def _write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + f".tmp.{os.getpid()}")
    temporary.write_text(
        json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def load_seed(path: Path) -> list[dict]:
    rows = []
    for line_number, line in enumerate(
        path.read_text(encoding="utf-8").splitlines(), 1
    ):
        if not line.strip():
            continue
        item = json.loads(line)
        prompt_id = str(item.get("id", "")).strip().upper()
        description = str(item.get("description", "")).strip()
        if not prompt_id or not description:
            raise ValueError(f"invalid seed row at line {line_number}")
        rows.append({**item, "id": prompt_id, "description": description})
    ids = [row["id"] for row in rows]
    if len(ids) != len(set(ids)):
        raise ValueError("seed corpus contains duplicate prompt IDs")
    return rows


def assigned_rows(rows: list[dict], *, shard_count: int, shard_index: int,
                  seed: int) -> list[dict]:
    """Deterministically balance each domain and assign every prompt once."""
    if shard_count < 1 or not 0 <= shard_index < shard_count:
        raise ValueError("invalid shard index/count")
    groups: dict[str, list[dict]] = {}
    for row in rows:
        groups.setdefault(str(row.get("domain") or "unknown"), []).append(row)
    selected = []
    for domain, domain_rows in sorted(groups.items()):
        ordered = sorted(
            domain_rows,
            key=lambda row: _sha256_bytes(
                f"{seed}:{domain}:{row['id']}".encode("utf-8")
            ),
        )
        offset = int(
            _sha256_bytes(f"{seed}:{domain}:offset".encode("utf-8"))[:8], 16
        ) % shard_count
        selected.extend(
            row for rank, row in enumerate(ordered)
            if (offset + rank) % shard_count == shard_index
        )
    return sorted(
        selected,
        key=lambda row: _sha256_bytes(
            f"{seed}:execution-order:{row['id']}".encode("utf-8")
        ),
    )


def repository_commit(repository: Path) -> str:
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=repository, text=True
    ).strip()


def tracked_worktree_dirty(repository: Path) -> bool:
    output = subprocess.check_output(
        ["git", "status", "--porcelain", "--untracked-files=no"],
        cwd=repository,
        text=True,
    )
    return bool(output.strip())


def apply_jupyter_path_override() -> None:
    """Make kernel discovery and later execution use the same frozen path."""
    override = os.environ.get("SYSML_JUPYTER_PATH")
    if not override:
        return
    current = os.environ.get("JUPYTER_PATH", "")
    entries = [override]
    if current:
        entries.extend(
            item for item in current.split(os.pathsep)
            if item and item not in entries
        )
    os.environ["JUPYTER_PATH"] = os.pathsep.join(entries)


def build_protocol(*, condition, dataset: Path, rows: list[dict],
                   shard_count: int, seed: int, commit: str,
                   max_compiler_repairs: int,
                   max_execution_repairs: int) -> dict:
    examples = agent._collect_examples(REPOSITORY)
    spec_index = REPOSITORY / "nl2sysml" / "spec_index" / "chunks.jsonl"
    retrieval = {
        "example_count": len(examples),
        "examples_sha256": _sha256_json([
            [_sha256_bytes(nl.encode("utf-8")), _sha256_bytes(code.encode("utf-8"))]
            for nl, code in examples
        ]),
        "spec_index": str(spec_index.relative_to(REPOSITORY)),
        "spec_index_sha256": (
            _sha256_bytes(spec_index.read_bytes()) if spec_index.is_file() else None
        ),
    }
    core = {
        "schema_version": "1.0",
        "study": "sysml-stagewise-ablation-a1-a4",
        "condition": condition.to_dict(),
        "dataset": str(dataset.resolve()),
        "dataset_sha256": _sha256_bytes(dataset.read_bytes()),
        "prompt_count": len(rows),
        "prompt_ids_sha256": _sha256_json([row["id"] for row in rows]),
        "domain_counts": dict(sorted(Counter(
            str(row.get("domain") or "unknown") for row in rows
        ).items())),
        "repository_commit": commit,
        "randomization_seed": seed,
        "shard_count": shard_count,
        "retrieval_k": 3,
        "retrieval_corpus": retrieval,
        "single_model": agent.COMBINER_MODEL,
        "expert_models": list(agent.EXPERT_MODELS),
        "combiner_model": agent.COMBINER_MODEL,
        "max_compiler_repairs": max_compiler_repairs,
        "max_execution_repairs": max_execution_repairs,
        "compiler_evaluated_for_all_conditions": True,
        "kernel_evaluated_for_all_conditions": True,
        "specification_alignment_enabled": False,
        "runtime_environment": runtime_environment(REPOSITORY),
    }
    return {**core, "protocol_core_sha256": _sha256_json(core)}


def runtime_environment(repository: Path) -> dict:
    try:
        java = subprocess.run(
            ["java", "-version"], capture_output=True, text=True, timeout=10
        )
        java_text = (java.stderr or java.stdout).strip().splitlines()
        java_version = java_text[0] if java_text else None
    except (OSError, subprocess.SubprocessError):
        java_version = None
    compiler_path = repository / "sysml2-compiler"
    compiler_commit = None
    if (compiler_path / ".git").exists():
        try:
            compiler_commit = subprocess.check_output(
                ["git", "-C", str(compiler_path), "rev-parse", "HEAD"],
                text=True, stderr=subprocess.DEVNULL,
            ).strip()
        except (OSError, subprocess.SubprocessError):
            pass
    kernel = {"available": False, "resource_dir": None, "kernel_json_sha256": None}
    try:
        from jupyter_client.kernelspec import KernelSpecManager

        spec = KernelSpecManager().get_kernel_spec("sysml")
        kernel_json = Path(spec.resource_dir) / "kernel.json"
        resource_files = []
        for resource in sorted(Path(spec.resource_dir).iterdir()):
            if resource.is_file():
                resource_files.append({
                    "name": resource.name,
                    "size_bytes": resource.stat().st_size,
                    "sha256": _sha256_bytes(resource.read_bytes()),
                })
        kernel = {
            "available": True,
            "resource_dir": spec.resource_dir,
            "kernel_json_sha256": (
                _sha256_bytes(kernel_json.read_bytes())
                if kernel_json.is_file() else None
            ),
            "argv": list(spec.argv),
            "resource_files": resource_files,
        }
    except Exception:
        pass

    packages = {}
    for name in ("jupyter_client", "python-dotenv"):
        try:
            packages[name] = importlib.metadata.version(name)
        except importlib.metadata.PackageNotFoundError:
            packages[name] = None
    return {
        "python": sys.version,
        "platform": platform.platform(),
        "java": java_version,
        "compiler_submodule_commit": compiler_commit,
        "sysml_jupyter_path_override": os.environ.get("SYSML_JUPYTER_PATH"),
        "sysml_kernel": kernel,
        "python_packages": packages,
    }


def freeze_protocol(output_dir: Path, protocol: dict) -> None:
    path = output_dir / "protocol.json"
    if path.is_file():
        existing = json.loads(path.read_text(encoding="utf-8"))
        if existing.get("protocol_core_sha256") != protocol["protocol_core_sha256"]:
            raise RuntimeError(
                f"output directory contains a different frozen protocol: {path}"
            )
        return
    _write_json(path, protocol)


def run_preflight(output_dir: Path) -> dict:
    issues = []
    try:
        _, key = agent._load_env()
        if not key:
            issues.append("OPENROUTER_API_KEY is unavailable")
    except Exception as exc:
        issues.append(f"model environment: {exc}")
    if not is_compiler_available():
        issues.append("native SysML compiler is unavailable")

    kernel = run_sysml_execution(ExecutionRequest(
        candidate_sysml="package StagewisePreflight {}",
        execution_timeout_sec=60.0,
        kernel_ready_timeout_sec=120.0,
    ))
    kernel_report = kernel.to_dict()
    if not kernel.kernel_available or kernel.bridge_error:
        issues.append(
            "SysML Jupyter kernel is unavailable: "
            + str(kernel.bridge_error or "unknown error")
        )
    elif not kernel.success:
        issues.append("SysML Jupyter kernel rejected the preflight package")

    report = {
        "schema_version": "1.0",
        "stage": "sysml_stagewise_preflight",
        "success": not issues,
        "issues": issues,
        "compiler_available": not any("compiler" in item for item in issues),
        "kernel": kernel_report,
        "models": {
            "single": agent.COMBINER_MODEL,
            "experts": list(agent.EXPERT_MODELS),
            "combiner": agent.COMBINER_MODEL,
        },
    }
    _write_json(output_dir / "preflight.json", report)
    return report


def summarize(records: list[dict]) -> dict:
    eligible = [row for row in records if row.get("eligible") is True]
    generated = [
        row for row in eligible
        if row.get("result", {}).get("generation", {}).get("passed") is True
    ]
    compiled = [
        row for row in eligible
        if row.get("result", {}).get("compiler", {}).get("passed") is True
    ]
    executed = [
        row for row in eligible
        if row.get("result", {}).get("execution", {}).get("success") is True
    ]
    passed = [row for row in eligible if row.get("result", {}).get("passed") is True]
    denominator = len(eligible)

    def rate(count: int) -> float | None:
        return count / denominator if denominator else None

    return {
        "record_count": len(records),
        "eligible_count": denominator,
        "infrastructure_exclusion_count": len(records) - denominator,
        "generated_count": len(generated),
        "compiler_pass_count": len(compiled),
        "kernel_execution_pass_count": len(executed),
        "end_to_end_pass_count": len(passed),
        "generated_rate": rate(len(generated)),
        "compiler_pass_rate": rate(len(compiled)),
        "kernel_execution_pass_rate": rate(len(executed)),
        "end_to_end_pass_rate": rate(len(passed)),
        "failure_stages": dict(sorted(Counter(
            row.get("result", {}).get("failure_stage") or "passed"
            for row in eligible
        ).items())),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--condition", required=True, choices=("A1", "A2", "A3", "A4"))
    parser.add_argument("--dataset", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--shard-count", type=int, default=1)
    parser.add_argument("--shard-index", type=int, default=0)
    parser.add_argument("--randomization-seed", type=int, default=DEFAULT_SEED)
    parser.add_argument("--max-compiler-repairs", type=int, default=2)
    parser.add_argument("--max-execution-repairs", type=int, default=2)
    parser.add_argument("--task-id", action="append", default=[])
    parser.add_argument(
        "--env-file", type=Path,
        help="Load provider credentials from this dotenv file without copying it",
    )
    parser.add_argument("--no-resume", action="store_true")
    parser.add_argument("--skip-preflight", action="store_true")
    parser.add_argument(
        "--preflight-only", action="store_true",
        help="Validate frozen dependencies and exit before any model call",
    )
    parser.add_argument("--allow-dirty", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if args.shard_count < 1 or not 0 <= args.shard_index < args.shard_count:
        parser.error("--shard-index must be in [0, --shard-count)")
    if args.max_compiler_repairs < 0 or args.max_execution_repairs < 0:
        parser.error("repair counts must be non-negative")
    if not args.dataset.is_file():
        parser.error(f"dataset does not exist: {args.dataset}")
    if args.env_file:
        if not args.env_file.is_file():
            parser.error(f"environment file does not exist: {args.env_file}")
        try:
            from dotenv import load_dotenv
        except ImportError as exc:
            parser.error(f"python-dotenv is required for --env-file: {exc}")
        load_dotenv(args.env_file, override=False)
    apply_jupyter_path_override()
    if tracked_worktree_dirty(REPOSITORY) and not args.allow_dirty:
        parser.error("tracked worktree is dirty; commit the frozen study code first")

    condition = get_condition(args.condition)
    all_rows = load_seed(args.dataset)
    if args.task_id:
        wanted = {item.upper() for item in args.task_id}
        all_rows = [row for row in all_rows if row["id"] in wanted]
        missing = wanted - {row["id"] for row in all_rows}
        if missing:
            parser.error(f"unknown task IDs: {sorted(missing)}")
    rows = assigned_rows(
        all_rows, shard_count=args.shard_count, shard_index=args.shard_index,
        seed=args.randomization_seed,
    )
    commit = repository_commit(REPOSITORY)
    protocol = build_protocol(
        condition=condition,
        dataset=args.dataset,
        rows=all_rows,
        shard_count=args.shard_count,
        seed=args.randomization_seed,
        commit=commit,
        max_compiler_repairs=args.max_compiler_repairs,
        max_execution_repairs=args.max_execution_repairs,
    )

    if args.dry_run:
        print(json.dumps({
            "condition": condition.to_dict(),
            "global_prompt_count": len(all_rows),
            "assigned_prompt_count": len(rows),
            "assigned_domain_counts": dict(sorted(Counter(
                str(row.get("domain") or "unknown") for row in rows
            ).items())),
            "assigned_prompt_ids": [row["id"] for row in rows],
            "protocol": protocol,
        }, indent=2))
        return

    args.output_dir.mkdir(parents=True, exist_ok=True)
    freeze_protocol(args.output_dir, protocol)
    preflight_path = args.output_dir / (
        f"preflight-shard-{args.shard_index:03d}-of-{args.shard_count:03d}"
    )
    if not args.skip_preflight:
        preflight = run_preflight(preflight_path)
        if preflight["success"] is not True:
            raise SystemExit("preflight failed: " + "; ".join(preflight["issues"]))
        if args.preflight_only:
            print(json.dumps(preflight, indent=2))
            return
    elif args.preflight_only:
        parser.error("--preflight-only cannot be combined with --skip-preflight")

    pipeline = StagewiseSysMLPipeline(
        repository=REPOSITORY,
        max_compiler_repairs=args.max_compiler_repairs,
        max_execution_repairs=args.max_execution_repairs,
    )
    records = []
    stopped_reason = None
    for index, row in enumerate(rows):
        task_dir = args.output_dir / "tasks" / row["id"]
        record_path = task_dir / "run.json"
        fingerprint = _sha256_json({
            "protocol_core_sha256": protocol["protocol_core_sha256"],
            "task_id": row["id"],
            "requirement": row["description"],
        })
        if not args.no_resume and record_path.is_file():
            cached = json.loads(record_path.read_text(encoding="utf-8"))
            if cached.get("fingerprint") == fingerprint and cached.get("eligible") is True:
                records.append(cached)
                continue

        started = time.monotonic()
        try:
            result = pipeline.run(
                row["id"], row["description"], condition,
                task_dir / "artifacts",
            )
            record = {
                "schema_version": "1.0",
                "fingerprint": fingerprint,
                "task_id": row["id"],
                "domain": row.get("domain", "unknown"),
                "condition": condition.to_dict(),
                "eligible": True,
                "infrastructure_error": None,
                "duration_seconds": time.monotonic() - started,
                "result": result,
            }
        except InfrastructureError as exc:
            record = {
                "schema_version": "1.0",
                "fingerprint": fingerprint,
                "task_id": row["id"],
                "domain": row.get("domain", "unknown"),
                "condition": condition.to_dict(),
                "eligible": False,
                "infrastructure_error": str(exc),
                "duration_seconds": time.monotonic() - started,
                "result": {},
            }
            stopped_reason = str(exc)
        except Exception as exc:
            record = {
                "schema_version": "1.0",
                "fingerprint": fingerprint,
                "task_id": row["id"],
                "domain": row.get("domain", "unknown"),
                "condition": condition.to_dict(),
                "eligible": False,
                "infrastructure_error": (
                    f"unexpected study implementation failure: "
                    f"{type(exc).__name__}: {exc}"
                ),
                "duration_seconds": time.monotonic() - started,
                "result": {},
            }
            stopped_reason = record["infrastructure_error"]
        _write_json(record_path, record)
        records.append(record)
        print(
            f"[{index + 1}/{len(rows)}] {condition.id} {row['id']}: "
            + (
                "infrastructure stop" if record["eligible"] is False else
                str(record["result"].get("failure_stage") or "passed")
            ),
            flush=True,
        )
        if stopped_reason:
            break

    summary = summarize(records)
    summary.update({
        "condition": condition.to_dict(),
        "shard_count": args.shard_count,
        "shard_index": args.shard_index,
        "assigned_prompt_count": len(rows),
        "stopped_early": stopped_reason is not None,
        "stop_reason": stopped_reason,
        "protocol_core_sha256": protocol["protocol_core_sha256"],
    })
    _write_json(
        args.output_dir
        / f"summary-shard-{args.shard_index:03d}-of-{args.shard_count:03d}.json",
        summary,
    )
    print(json.dumps(summary, indent=2))
    if stopped_reason:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
