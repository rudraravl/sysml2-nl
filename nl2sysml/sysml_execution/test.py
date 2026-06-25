"""Run from repo root: python nl2sysml/sysml_execution/test.py"""

from __future__ import annotations

import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from nl2sysml.sysml_execution import ExecutionRequest, run_sysml_execution  # noqa: E402

_SAMPLE = _REPO_ROOT / "dataset/data/000200/000200.sysml"
_OUTPUT_DIR = Path(__file__).resolve().parent / "test_output"
_OUTPUT_PATH = _OUTPUT_DIR / "000200_with_harness.sysml"


def _assert_harness(harness: str) -> None:
    required = [
        "attribute testFuelCmd : FuelCmd;",
        "in fuelCmd = testFuelCmd;",
        "'Provide Power'",
        "TODO(human): kernel cannot send/trigger engineStart",
    ]
    for fragment in required:
        if fragment not in harness:
            raise AssertionError(f"expected harness to contain: {fragment!r}")

    forbidden = ["in fuelCmd = 1", "perform action", "assign fuelCmd"]
    for fragment in forbidden:
        if fragment in harness:
            raise AssertionError(f"expected harness not to contain: {fragment!r}")


def main() -> int:
    code = _SAMPLE.read_text(encoding="utf-8")
    result = run_sysml_execution(ExecutionRequest(candidate_sysml=code))

    if result.model_kind != "behavioral":
        raise AssertionError(f"expected behavioral model, got {result.model_kind!r}")

    _assert_harness(result.harness)

    _OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    _OUTPUT_PATH.write_text(result.consolidated_payload, encoding="utf-8")

    print(f"compiled={result.compiled} success={result.success} kind={result.model_kind}")
    print(f"kernel_available={result.kernel_available}")
    print(f"wrote {_OUTPUT_PATH}")

    if result.kernel_available:
        if not result.compiled:
            print("errors:", result.errors[:5])
            if result.bridge_error:
                print(result.bridge_error)
            return 1
    else:
        print("kernel: skipped (SysML kernel not available)")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as exc:
        print(f"FAILED: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
