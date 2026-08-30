"""Turn Foundry build/test output into analysis-friendly JSON.

The Solidity analog of nl2sysml/sysml_execution/diagnostics.py. It keeps that
module's output contract - ``errors`` records with message/line/column/file,
plus counts by category - because agent_rag_moe._format_kernel_errors reads
exactly those keys to build the repair prompt. On top of that it records the
per-tier verdict, fuzz counterexamples and gas, which the SysML pipeline has no
equivalent of.
"""

from __future__ import annotations

import json
from collections import Counter
from pathlib import Path
from typing import Any, Dict, List, Optional

from .models import HarnessFile, TestOutcome

CANDIDATE_FILE = "src/Candidate.sol"

# Failure classes that indicate a defect in the contract rather than a harness
# or property problem. Used to keep the repair loop pointed at real bugs.
CONTRACT_DEFECT_CLASSES = {
    "panic_assert",
    "panic_arithmetic",
    "panic_division_by_zero",
    "panic_enum_conversion",
    "panic_storage_encoding",
    "panic_pop_empty_array",
    "panic_array_out_of_bounds",
    "panic_memory_overflow",
    "panic_uninitialized_function",
    "panic_other",
    "assertion_failed",
    "expected_revert_not_raised",
    "out_of_gas",
}


def categorize_message(message: str) -> str:
    """Coarse category for distribution analysis across the dataset."""
    lowered = (message or "").lower()
    if "panic(17)" in lowered or "overflow" in lowered or "underflow" in lowered:
        return "arithmetic"
    if "panic(" in lowered:
        return "panic"
    if "assertion failed" in lowered or "assert" in lowered:
        return "assertion"
    if "did not revert" in lowered:
        return "missing_access_control"
    if "setup failed" in lowered:
        return "setup"
    if "out of gas" in lowered:
        return "gas"
    if "revert" in lowered:
        return "revert"
    return "other"


def _error_record(outcome: TestOutcome) -> Dict[str, Any]:
    """One failing test rendered as a diagnostic record.

    Line/column are None: a Foundry failure is behavioral, not positional, and
    inventing a line number would mislead the repair model.
    """
    detail = outcome.reason or "test failed without a reason string"
    if outcome.counterexample:
        detail = f"{detail} [counterexample: {outcome.counterexample}]"
    return {
        "severity": "ERROR",
        "message": f"{outcome.name}: {detail}",
        "test": outcome.name,
        "tier": outcome.tier,
        "kind": outcome.kind,
        "failure_class": outcome.failure_class,
        "category": categorize_message(outcome.reason or ""),
        "counterexample": outcome.counterexample,
        "logs": outcome.logs,
        "file": None,
        "line": None,
        "column": None,
        "contract_defect": outcome.failure_class in CONTRACT_DEFECT_CLASSES,
    }


def _build_error_record(entry: Dict[str, Any]) -> Dict[str, Any]:
    """One solc/forge build error, attributed to the candidate or the harness."""
    file_name = entry.get("file") or ""
    in_harness = file_name.startswith("test/")
    return {
        "severity": "ERROR",
        "message": entry.get("message", ""),
        "type": entry.get("type"),
        "category": "compile",
        "file": file_name or None,
        "line": entry.get("line"),
        "column": entry.get("column"),
        "in_harness": in_harness,
        "contract_defect": not in_harness,
        "formatted": entry.get("formatted"),
    }


def build_execution_diagnostics(
    outcomes: List[TestOutcome],
    *,
    build_errors: Optional[List[Dict[str, Any]]] = None,
    harness_files: Optional[List[HarnessFile]] = None,
    harness_notes: Optional[List[str]] = None,
    bridge_error: Optional[str] = None,
    compiled: Optional[bool] = None,
    success: Optional[bool] = None,
    model_kind: Optional[str] = None,
    kernel_available: Optional[bool] = None,
    security: Optional[Dict[str, Any]] = None,
    extra: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """Build the dataset-analysis blob for one execution."""
    build_errors = build_errors or []
    harness_files = harness_files or []

    error_records = [_build_error_record(e) for e in build_errors]
    error_records += [_error_record(o) for o in outcomes if o.failed()]

    failures = [o for o in outcomes if o.failed()]
    passed = [o for o in outcomes if o.status == "Success"]

    class_counts = Counter(o.failure_class for o in failures if o.failure_class)
    tier_counts: Dict[str, Dict[str, int]] = {}
    for outcome in outcomes:
        bucket = tier_counts.setdefault(outcome.tier, {"passed": 0, "failed": 0})
        bucket["failed" if outcome.failed() else "passed"] += 1

    payload: Dict[str, Any] = {
        "errors": error_records,
        "n_errors": len(error_records),
        "n_tests": len(outcomes),
        "n_passed": len(passed),
        "n_failed": len(failures),
        "has_errors": bool(error_records),
        "failure_classes": dict(class_counts.most_common()),
        "error_counts_by_category": dict(
            Counter(r["category"] for r in error_records).most_common()),
        "contract_defects": sum(1 for r in error_records if r.get("contract_defect")),
        "harness_defects": sum(1 for r in error_records if not r.get("contract_defect")),
        "tests_by_tier": tier_counts,
        "tests": [
            {
                "name": o.name,
                "tier": o.tier,
                "kind": o.kind,
                "status": o.status,
                "failure_class": o.failure_class,
                "runs": o.runs,
                "reverts": o.reverts,
                "gas": o.gas,
            }
            for o in outcomes
        ],
        "harness": [
            {"name": h.name, "tier": h.tier, "tests": h.test_count, "notes": h.notes}
            for h in harness_files
        ],
        "harness_notes": harness_notes or [],
        "bridge_error": bridge_error,
    }

    # Invariant runs that revert on nearly every call have explored almost
    # nothing; record it so a green invariant is not mistaken for coverage.
    weak = [
        o.name for o in outcomes
        if o.kind == "invariant" and o.runs and o.reverts is not None
        and o.reverts > 0 and o.status == "Success"
    ]
    if weak:
        payload["low_coverage_invariants"] = weak

    if compiled is not None:
        payload["compiled"] = compiled
    if success is not None:
        payload["success"] = success
    if model_kind is not None:
        payload["model_kind"] = model_kind
    if kernel_available is not None:
        payload["kernel_available"] = kernel_available
    if security is not None:
        payload["security"] = security
    if extra:
        payload.update(extra)

    return payload


def format_execution_diagnostics_json(diagnostics: Dict[str, Any]) -> str:
    return json.dumps(diagnostics, indent=2, ensure_ascii=False) + "\n"


def write_execution_diagnostics_file(path: str | Path,
                                     diagnostics: Dict[str, Any]) -> str:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(format_execution_diagnostics_json(diagnostics), encoding="utf-8")
    return str(target)


# Backwards-compatible aliases matching the SysML module's names.
build_compiler_diagnostics = build_execution_diagnostics
write_compiler_diagnostics_file = write_execution_diagnostics_file
