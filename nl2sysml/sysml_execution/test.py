"""Run a dataset sample (or any .sysml file) through the execution pipeline.

From repo root::

    python nl2sysml/sysml_execution/test.py 000600
    python nl2sysml/sysml_execution/test.py dataset/data/000200/000200.sysml
    python nl2sysml/sysml_execution/test.py --batch
    python nl2sysml/sysml_execution/test.py --batch --limit 50 --start 000200
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import traceback
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from nl2sysml.sysml_execution import ExecutionRequest, run_sysml_execution  # noqa: E402

_DATA = _REPO_ROOT / "dataset" / "data"
_OUTPUT_DIR = Path(__file__).resolve().parent / "execution_output"


@dataclass
class SampleRunSummary:
    sample_id: str
    sample_path: str
    output_dir: str
    compiled: bool = False
    success: bool = False
    model_kind: Optional[str] = None
    kernel_available: Optional[bool] = None
    n_errors: int = 0
    n_warnings: int = 0
    elapsed_sec: float = 0.0
    status: str = "ok"  # ok | compile_failed | skipped | error
    error: Optional[str] = None


def _resolve_sample_path(arg: str) -> Path:
    path = Path(arg)
    if path.is_file():
        return path.resolve()
    if path.suffix == ".sysml":
        raise FileNotFoundError(f"sample file not found: {path}")

    sample_id = arg.strip("/")
    dataset_path = _DATA / sample_id / f"{sample_id}.sysml"
    if dataset_path.is_file():
        return dataset_path

    raise FileNotFoundError(
        f"sample not found: {arg!r} (expected a .sysml path or dataset id like 000600)"
    )


def _sample_id_for(sample_path: Path) -> str:
    """Prefer dataset folder name (000600) over file stem when possible."""
    if sample_path.parent.name and (sample_path.parent / f"{sample_path.parent.name}.sysml").resolve() == sample_path.resolve():
        return sample_path.parent.name
    return sample_path.stem


def _model_output_dir(sample_path: Path) -> Path:
    return _OUTPUT_DIR / _sample_id_for(sample_path)


def _output_paths(sample_path: Path) -> tuple[Path, Path, Path, Path]:
    """Return (model_dir, harness, trace, diagnostics) for one sample."""
    model_dir = _model_output_dir(sample_path)
    stem = _sample_id_for(sample_path)
    return (
        model_dir,
        model_dir / f"{stem}_with_harness.sysml",
        model_dir / f"{stem}_execution_trace.txt",
        model_dir / f"{stem}_diagnostics.json",
    )


def _assert_generic_result(harness: str, consolidated: str, model_kind: str) -> None:
    if model_kind == "empty":
        raise AssertionError("expected behavioral or structural model, got 'empty'")
    if "package ExecutionHarness" not in harness:
        raise AssertionError("expected generated harness to contain package ExecutionHarness")
    if harness.strip() not in consolidated:
        raise AssertionError("expected consolidated payload to include the harness block")


def _list_dataset_samples(
    *,
    start: Optional[str] = None,
    limit: Optional[int] = None,
) -> List[Path]:
    if not _DATA.is_dir():
        raise FileNotFoundError(f"dataset directory not found: {_DATA}")

    samples: List[Path] = []
    for child in sorted(_DATA.iterdir()):
        if not child.is_dir():
            continue
        sysml = child / f"{child.name}.sysml"
        if sysml.is_file():
            samples.append(sysml)

    if start:
        start_id = start.strip("/")
        samples = [p for p in samples if _sample_id_for(p) >= start_id]

    if limit is not None:
        if limit < 0:
            raise ValueError("--limit must be >= 0")
        samples = samples[:limit]

    return samples


def run_one_sample(sample_path: Path, *, quiet: bool = False) -> SampleRunSummary:
    sample_id = _sample_id_for(sample_path)
    model_dir, output_path, trace_path, diagnostics_path = _output_paths(sample_path)
    started = time.monotonic()

    summary = SampleRunSummary(
        sample_id=sample_id,
        sample_path=str(sample_path),
        output_dir=str(model_dir),
    )

    try:
        code = sample_path.read_text(encoding="utf-8")
        result = run_sysml_execution(
            ExecutionRequest(
                candidate_sysml=code,
                trace_output_path=str(trace_path),
                diagnostics_output_path=str(diagnostics_path),
            )
        )
        _assert_generic_result(result.harness, result.consolidated_payload, result.model_kind)

        model_dir.mkdir(parents=True, exist_ok=True)
        output_path.write_text(result.consolidated_payload, encoding="utf-8")

        summary.compiled = result.compiled
        summary.success = result.success
        summary.model_kind = result.model_kind
        summary.kernel_available = result.kernel_available
        if result.diagnostics:
            summary.n_errors = int(result.diagnostics.get("n_errors", 0))
            summary.n_warnings = int(result.diagnostics.get("n_warnings", 0))

        if not result.kernel_available:
            summary.status = "skipped"
            summary.error = result.bridge_error or "SysML kernel not available"
        elif not result.compiled:
            summary.status = "compile_failed"
        else:
            summary.status = "ok"

        if not quiet:
            print(f"sample={sample_path}")
            print(
                f"compiled={result.compiled} success={result.success} "
                f"kind={result.model_kind}"
            )
            print(f"kernel_available={result.kernel_available}")
            print(
                f"diagnostics: n_errors={summary.n_errors} "
                f"n_warnings={summary.n_warnings}"
            )
            print(f"wrote {output_path}")
            print(f"wrote {trace_path}")
            print(f"wrote {diagnostics_path}")
            if summary.status == "compile_failed":
                print("errors:", result.errors[:5])
                if result.bridge_error:
                    print(result.bridge_error)
            elif summary.status == "skipped":
                print(f"kernel: skipped ({summary.error})")

    except Exception as exc:
        summary.status = "error"
        summary.error = f"{type(exc).__name__}: {exc}"
        if not quiet:
            print(f"FAILED {sample_id}: {summary.error}", file=sys.stderr)
            traceback.print_exc()

    summary.elapsed_sec = round(time.monotonic() - started, 3)
    return summary


def _write_batch_summary(summaries: List[SampleRunSummary]) -> Path:
    _OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    path = _OUTPUT_DIR / "batch_summary.json"

    counts: Dict[str, int] = {}
    for s in summaries:
        counts[s.status] = counts.get(s.status, 0) + 1

    payload: Dict[str, Any] = {
        "n_samples": len(summaries),
        "counts_by_status": counts,
        "n_compiled": sum(1 for s in summaries if s.compiled),
        "n_compile_failed": sum(1 for s in summaries if s.status == "compile_failed"),
        "total_errors": sum(s.n_errors for s in summaries),
        "total_warnings": sum(s.n_warnings for s in summaries),
        "samples": [asdict(s) for s in summaries],
    }
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return path


def run_batch(
    *,
    start: Optional[str] = None,
    limit: Optional[int] = None,
    continue_on_error: bool = True,
) -> int:
    samples = _list_dataset_samples(start=start, limit=limit)
    if not samples:
        print("No dataset samples found.", file=sys.stderr)
        return 1

    print(f"batch: {len(samples)} sample(s) -> {_OUTPUT_DIR}")
    summaries: List[SampleRunSummary] = []

    for idx, sample_path in enumerate(samples, start=1):
        sample_id = _sample_id_for(sample_path)
        print(f"\n[{idx}/{len(samples)}] {sample_id}")
        summary = run_one_sample(sample_path, quiet=False)
        summaries.append(summary)

        if summary.status == "error" and not continue_on_error:
            print("Stopping batch after error (--no-continue-on-error).", file=sys.stderr)
            break

    summary_path = _write_batch_summary(summaries)
    counts: Dict[str, int] = {}
    for s in summaries:
        counts[s.status] = counts.get(s.status, 0) + 1

    print(f"\nbatch complete: {len(summaries)} sample(s)")
    print(f"status counts: {counts}")
    print(f"wrote {summary_path}")

    # Non-zero if any hard failures (exceptions); compile_failed is expected dataset signal.
    if any(s.status == "error" for s in summaries):
        return 1
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Run a SysML sample through the execution harness pipeline",
    )
    parser.add_argument(
        "sample",
        nargs="?",
        default=None,
        help="dataset sample id (e.g. 000600) or path to a .sysml file",
    )
    parser.add_argument(
        "--batch",
        action="store_true",
        help="run every model under dataset/data (writes per-model folders + batch_summary.json)",
    )
    parser.add_argument(
        "--start",
        default=None,
        help="with --batch, start at this sample id (inclusive), e.g. 000200",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="with --batch, process at most N samples",
    )
    parser.add_argument(
        "--no-continue-on-error",
        action="store_true",
        help="with --batch, stop on the first unexpected exception",
    )
    args = parser.parse_args(argv)

    if args.batch:
        return run_batch(
            start=args.start,
            limit=args.limit,
            continue_on_error=not args.no_continue_on_error,
        )

    sample_arg = args.sample or "000200"
    sample_path = _resolve_sample_path(sample_arg)
    summary = run_one_sample(sample_path, quiet=False)

    if summary.status == "error":
        return 1
    if summary.status == "compile_failed":
        return 1
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, FileNotFoundError, ValueError) as exc:
        print(f"FAILED: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
