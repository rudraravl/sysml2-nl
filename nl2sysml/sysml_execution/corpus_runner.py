"""Run the execution harness across the dataset and persist kernel results."""

from __future__ import annotations

import argparse
import csv
import json
import time
from pathlib import Path
from typing import Any, Dict, List

from .extractor import extract_topology
from .models import ExecutionRequest
from .orchestrator import compile_sysml_candidate, run_sysml_execution
from .vector_fallback import required_action_inputs

_REPO_ROOT = Path(__file__).resolve().parents[2]
_DEFAULT_DATASET = _REPO_ROOT / "dataset" / "data"
_DEFAULT_OUTPUT = _REPO_ROOT / "results" / "sysml_execution_corpus_v3"
_RUN_SCHEMA_VERSION = 3


def _summary_row(model_id: str, model_path: Path, result: Dict[str, Any], elapsed: float) -> Dict[str, Any]:
    attempts = result.get("vector_attempts") or []
    metadata = result.get("harness_metadata") or {}
    return {
        "model_id": model_id,
        "model_path": str(model_path),
        "elapsed_sec": round(elapsed, 3),
        "success": result.get("success"),
        "syntax_ok": result.get("syntax_ok"),
        "harness_compile_ok": result.get("harness_compile_ok"),
        "input_injected": result.get("input_injected"),
        "behavior_observed": result.get("behavior_observed"),
        "verification_level": result.get("verification_level"),
        "behavior_ok": result.get("behavior_ok"),
        "layer2_status": result.get("layer2_status"),
        "kernel_timed_out": result.get("kernel_timed_out"),
        "profile": metadata.get("profile"),
        "probes_runnable": metadata.get("probes_runnable"),
        "required_inputs": json.dumps(metadata.get("required_inputs") or []),
        "missing_inputs": json.dumps(metadata.get("missing_inputs") or []),
        "input_types": json.dumps(metadata.get("input_types") or {}),
        "unsupported_inputs": json.dumps(metadata.get("unsupported_inputs") or []),
        "available_action_targets": json.dumps(metadata.get("available_action_targets") or []),
        "structural_attribute_count": len(metadata.get("structural_attributes") or []),
        "state_machine_count": len(metadata.get("state_machines") or []),
        "accept_trigger_count": len(metadata.get("accept_triggers") or []),
        "constraint_count": metadata.get("constraint_count"),
        "test_strategy": metadata.get("test_strategy"),
        "coverage_status": metadata.get("coverage_status"),
        "vector_source": result.get("vector_source"),
        "semantic_validity": result.get("semantic_validity"),
        "selected_simulation_vectors": json.dumps(result.get("selected_simulation_vectors")),
        "attempt_count": len(attempts),
        "diagnostic_error_type": (result.get("diagnostic_pack") or {}).get("error_type"),
    }


def _action_targets(candidate_sysml: str) -> List[str]:
    topology = extract_topology(candidate_sysml)
    targets: List[str] = []
    for usage in topology.action_usages:
        if usage.type_ref and required_action_inputs(topology, [usage.name]) and usage.name not in targets:
            targets.append(usage.name)
    return targets


def _aggregate_target_summaries(
    model_id: str,
    model_path: Path,
    target_summaries: List[Dict[str, Any]],
    elapsed: float,
) -> Dict[str, Any]:
    coverage_counts: Dict[str, int] = {}
    for summary in target_summaries:
        status = str(summary.get("coverage_status"))
        coverage_counts[status] = coverage_counts.get(status, 0) + 1
    return {
        "model_id": model_id,
        "model_path": str(model_path),
        "elapsed_sec": round(elapsed, 3),
        "success": all(bool(summary.get("success")) for summary in target_summaries),
        "syntax_ok": all(bool(summary.get("syntax_ok")) for summary in target_summaries),
        "behavior_ok": all(bool(summary.get("behavior_ok")) for summary in target_summaries),
        "harness_compile_ok": all(
            bool(summary.get("harness_compile_ok")) for summary in target_summaries
        ),
        "input_injected": any(bool(summary.get("input_injected")) for summary in target_summaries),
        "behavior_observed": any(
            bool(summary.get("behavior_observed")) for summary in target_summaries
        ),
        "verification_level": (
            "behavior_observed"
            if any(bool(summary.get("behavior_observed")) for summary in target_summaries)
            else (
                "input_harness_compiled"
                if any(bool(summary.get("input_injected")) for summary in target_summaries)
                else "structural_harness_compiled"
            )
        ),
        "layer2_status": "multi_target",
        "kernel_timed_out": any(bool(summary.get("kernel_timed_out")) for summary in target_summaries),
        "profile": "multi_action",
        "action_target_count": len(target_summaries),
        "input_tests_performed": coverage_counts.get("input_test_performed", 0),
        "inputs_not_constructible": coverage_counts.get(
            "inputs_detected_but_not_constructible", 0
        ),
        "coverage_status": json.dumps(coverage_counts, sort_keys=True),
        "attempt_count": sum(int(summary.get("attempt_count") or 0) for summary in target_summaries),
        "diagnostic_error_type": (
            None
            if all(
                summary.get("diagnostic_error_type") in (None, "behavior_not_observed")
                for summary in target_summaries
            )
            else "one_or_more_target_failures"
        ),
    }


def _write_csv(rows: List[Dict[str, Any]], path: Path) -> None:
    if not rows:
        return
    fieldnames = list(dict.fromkeys(key for row in rows for key in row))
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _write_summary(
    rows: List[Dict[str, Any]], target_rows: List[Dict[str, Any]], output_dir: Path
) -> None:
    (output_dir / "summary.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")
    (output_dir / "targets.json").write_text(
        json.dumps(target_rows, indent=2), encoding="utf-8"
    )
    _write_csv(rows, output_dir / "summary.csv")
    _write_csv(target_rows, output_dir / "targets.csv")
    audit = {
        "run_schema_version": _RUN_SCHEMA_VERSION,
        "models_completed": len(rows),
        "baseline_syntax_ok": sum(bool(row.get("baseline_syntax_ok")) for row in rows),
        "baseline_syntax_failed": sum(
            row.get("baseline_syntax_ok") is False for row in rows
        ),
        "harness_compile_ok": sum(bool(row.get("harness_compile_ok")) for row in rows),
        "harness_regressions": sum(
            row.get("baseline_syntax_ok") is True
            and row.get("harness_compile_ok") is False
            for row in rows
        ),
        "models_with_input_injection": sum(bool(row.get("input_injected")) for row in rows),
        "models_with_behavior_observed": sum(
            bool(row.get("behavior_observed")) for row in rows
        ),
        "targets_recorded": len(target_rows),
        "targets_with_input_injection": sum(
            bool(row.get("input_injected")) for row in target_rows
        ),
        "targets_with_behavior_observed": sum(
            bool(row.get("behavior_observed")) for row in target_rows
        ),
        "targets_not_constructible": sum(
            row.get("coverage_status") == "inputs_detected_but_not_constructible"
            for row in target_rows
        ),
        "important_note": (
            "Input harness compilation proves injection syntax was accepted, not that "
            "the SysML behavior executed or the engineering values were semantically valid."
        ),
    }
    (output_dir / "audit.json").write_text(json.dumps(audit, indent=2), encoding="utf-8")


def run_corpus(
    dataset_dir: Path,
    output_dir: Path,
    *,
    limit: int | None = None,
    resume: bool = True,
) -> List[Dict[str, Any]]:
    """Run every dataset model, stopping each model at its first accepted preset vector."""
    output_dir.mkdir(parents=True, exist_ok=True)
    model_files = sorted(dataset_dir.glob("*/*.sysml"))
    if limit is not None:
        model_files = model_files[:limit]

    rows: List[Dict[str, Any]] = []
    target_rows: List[Dict[str, Any]] = []
    for index, model_path in enumerate(model_files, start=1):
        model_id = model_path.stem
        result_path = output_dir / f"{model_id}.json"
        if resume and result_path.exists():
            stored = json.loads(result_path.read_text(encoding="utf-8"))
            if stored.get("run_schema_version") == _RUN_SCHEMA_VERSION:
                rows.append(stored["summary"])
                target_rows.extend(stored.get("target_summaries") or [])
                print(f"[{index}/{len(model_files)}] {model_id}: resumed")
                continue

        started = time.monotonic()
        try:
            candidate_sysml = model_path.read_text(encoding="utf-8")
            baseline = compile_sysml_candidate(
                ExecutionRequest(candidate_sysml=candidate_sysml)
            )
            targets = _action_targets(candidate_sysml)
            if targets:
                target_results = []
                target_summaries = []
                for target in targets:
                    target_started = time.monotonic()
                    result = run_sysml_execution(
                        ExecutionRequest(
                            candidate_sysml=candidate_sysml,
                            target_behaviors=[target],
                            try_preset_vectors=True,
                        )
                    ).to_dict()
                    target_elapsed = time.monotonic() - target_started
                    target_summary = _summary_row(model_id, model_path, result, target_elapsed)
                    target_summary["action_target"] = target
                    target_results.append({"action_target": target, "result": result})
                    target_summaries.append(target_summary)
                elapsed = time.monotonic() - started
                summary = _aggregate_target_summaries(
                    model_id, model_path, target_summaries, elapsed
                )
                summary["baseline_syntax_ok"] = baseline["syntax_ok"]
                payload = {
                    "run_schema_version": _RUN_SCHEMA_VERSION,
                    "model_id": model_id,
                    "model_path": str(model_path),
                    "footnote": (
                        "Preset fallback vectors are only kernel-accepted; their semantic "
                        "validity as engineering inputs is unknown."
                    ),
                    "summary": summary,
                    "baseline_result": baseline,
                    "target_summaries": target_summaries,
                    "target_results": target_results,
                }
            else:
                request = ExecutionRequest(
                    candidate_sysml=candidate_sysml,
                    try_preset_vectors=True,
                )
                result = run_sysml_execution(request).to_dict()
                elapsed = time.monotonic() - started
                summary = _summary_row(model_id, model_path, result, elapsed)
                summary["baseline_syntax_ok"] = baseline["syntax_ok"]
                summary["action_target_count"] = 0
                summary["input_tests_performed"] = int(
                    summary.get("coverage_status") == "input_test_performed"
                )
                summary["inputs_not_constructible"] = int(
                    summary.get("coverage_status") == "inputs_detected_but_not_constructible"
                )
                payload = {
                    "run_schema_version": _RUN_SCHEMA_VERSION,
                    "model_id": model_id,
                    "model_path": str(model_path),
                    "footnote": (
                        "No injectable typed action target was found. Structural/state "
                        "harness compilation does not constitute an input-vector test."
                    ),
                    "summary": summary,
                    "baseline_result": baseline,
                    "result": result,
                }
        except Exception as exc:
            elapsed = time.monotonic() - started
            summary = {
                "model_id": model_id,
                "model_path": str(model_path),
                "elapsed_sec": round(elapsed, 3),
                "success": False,
                "diagnostic_error_type": "runner_exception",
                "exception": repr(exc),
            }
            payload = {
                "run_schema_version": _RUN_SCHEMA_VERSION,
                "model_id": model_id,
                "model_path": str(model_path),
                "summary": summary,
            }

        result_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        rows.append(summary)
        target_rows.extend(payload.get("target_summaries") or [])
        _write_summary(rows, target_rows, output_dir)
        print(
            f"[{index}/{len(model_files)}] {model_id}: "
            f"syntax_ok={summary.get('syntax_ok')} status={summary.get('layer2_status')} "
            f"baseline_ok={summary.get('baseline_syntax_ok')} "
            f"targets={summary.get('action_target_count', 0)} "
            f"input_tests={summary.get('input_tests_performed', 0)} "
            f"attempts={summary.get('attempt_count', 0)}"
        )
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description="Run SysML execution harness across the corpus")
    parser.add_argument("--dataset", type=Path, default=_DEFAULT_DATASET)
    parser.add_argument("--output", type=Path, default=_DEFAULT_OUTPUT)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--no-resume", action="store_true")
    args = parser.parse_args()
    run_corpus(args.dataset, args.output, limit=args.limit, resume=not args.no_resume)


if __name__ == "__main__":
    main()
