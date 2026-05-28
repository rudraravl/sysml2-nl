"""Run from repo root: python nl2sysml/sysml_execution/test.py"""

from __future__ import annotations

import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from nl2sysml.sysml_execution import ExecutionRequest, run_sysml_execution  # noqa: E402

_SAMPLE = _REPO_ROOT / "dataset/data/000200/000200.sysml"

result = run_sysml_execution(
    ExecutionRequest(
        candidate_sysml=_SAMPLE.read_text(encoding="utf-8"),
        simulation_vectors={"fuelCmd": 1},
    )
)
print(f"success={result.success} syntax_ok={result.syntax_ok} behavior_ok={result.behavior_ok}")
print(f"layer2_status={result.layer2_status}")
if result.harness_metadata:
    print(f"harness_profile={result.harness_metadata.get('profile')}")
    print(f"probes_runnable={result.harness_metadata.get('probes_runnable')}")
if not result.success and result.diagnostic_pack:
    print(result.diagnostic_pack["recommended_repair_prompt"])
