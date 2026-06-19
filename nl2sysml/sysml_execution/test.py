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

result = run_sysml_execution(
    ExecutionRequest(
        candidate_sysml=_SAMPLE.read_text(encoding="utf-8"),
        simulation_vectors={"fuelCmd": 1},
    )
)

_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
_output_path = _OUTPUT_DIR / "000200_with_harness.sysml"
_output_path.write_text(result.consolidated_payload, encoding="utf-8")

print(f"compiled={result.compiled} success={result.success} kind={result.model_kind}")
print(f"kernel_available={result.kernel_available}")
print(f"wrote {_output_path}")
if result.errors:
    print("errors:", result.errors[:5])
if not result.compiled and result.bridge_error:
    print(result.bridge_error)
