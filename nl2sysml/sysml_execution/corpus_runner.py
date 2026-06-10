"""Run the execution harness across the dataset and persist kernel results."""

from __future__ import annotations

import argparse
import csv
import json
import time
from pathlib import Path
from typing import Any, Dict, List

from .models import ExecutionRequest
from .orchestrator import run_sysml_execution

_REPO_ROOT = Path(__file__).resolve().parents[2]
_DEFAULT_DATASET = _REPO_ROOT / "dataset" / "data"
_DEFAULT_OUTPUT = _REPO_ROOT / "results" / "sysml_execution_corpus"


def _summary_row(model_id: str, model_path: Path, result: Dict[str, Any], elapsed: float) -> Dict[str, Any]:
    attempts = result.get("vector_attempts") or []
    metadata = result.get("harness_metadata") or {}
    return {
        "model_id": model_id,
        "model_path": str(model_path),
        "elapsed_sec": round(elapsed, 3),
        "success": result.get("success"),
        "syntax_ok": result.get("syntax_ok"),
        "behavior_ok": result.get("behavior_ok"),
        "layer2_status": result.get("layer2_status"),
        "kernel_timed_out": result.get("kernel_timed_out"),
        "profile": metadata.get("profile"),
        "probes_runnable": metadata.get("probes_runnable"),
        "required_inputs": json.dumps(metadata.get("required_inputs") or []),
        "missing_inputs": json.dumps(metadata.get("missing_inputs") or []),
        "vector_source": result.get("vector_source"),
        "semantic_validity": result.get("semantic_validity"),
        "selected_simulation_vectors": json.dumps(result.get("selected_simulation_vectors")),
        "attempt_count": len(attempts),
        "diagnostic_error_type": (result.get("diagnostic_pack") or {}).get("error_type"),
    }


def _write_summary(rows: List[Dict[str, Any]], output_dir: Path) -> None:
    (output_dir / "summary.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")
    if not rows:
        return
    with (output_dir / "summary.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


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
    for index, model_path in enumerate(model_files, start=1):
        model_id = model_path.stem
        result_path = output_dir / f"{model_id}.json"
        if resume and result_path.exists():
            stored = json.loads(result_path.read_text(encoding="utf-8"))
            rows.append(stored["summary"])
            print(f"[{index}/{len(model_files)}] {model_id}: resumed")
            continue

        started = time.monotonic()
        try:
            request = ExecutionRequest(
                candidate_sysml=model_path.read_text(encoding="utf-8"),
                try_preset_vectors=True,
            )
            result = run_sysml_execution(request).to_dict()
            elapsed = time.monotonic() - started
            summary = _summary_row(model_id, model_path, result, elapsed)
            payload = {
                "model_id": model_id,
                "model_path": str(model_path),
                "footnote": (
                    "Preset fallback vectors are only kernel-accepted; their semantic "
                    "validity as engineering inputs is unknown."
                ),
                "summary": summary,
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
            payload = {"model_id": model_id, "model_path": str(model_path), "summary": summary}

        result_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        rows.append(summary)
        _write_summary(rows, output_dir)
        print(
            f"[{index}/{len(model_files)}] {model_id}: "
            f"syntax_ok={summary.get('syntax_ok')} status={summary.get('layer2_status')} "
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
