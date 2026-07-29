"""Post-generation quality gate: optional validate -> optional execute -> align -> repair.

Generation's preferred ordering is handled outside this module:
  MoE synthesis -> compiler refine -> kernel refine -> semantic align (this gate).
When used from generation, pass execute=None so kernel is not duplicated here.
"""

from __future__ import annotations

import hashlib
import tempfile
from dataclasses import asdict, is_dataclass
from typing import Any, Callable

from spec_aligner.feedback import build_repair_prompt, needs_repair
from spec_aligner.pipeline import compare_pair


def run_quality_gate(nl: str, sysml: str, ask: Callable[[str], str], *,
                     validate: Callable[[str], Any] | None = None,
                     execute: Callable[[str], Any] | None = None,
                     repair: Callable[[str], str] | None = None,
                     threshold: float = 0.85, max_repairs: int = 1,
                     alignment_kwargs: dict | None = None) -> dict:
    """Evaluate a candidate and optionally repair it, rerunning every quality stage."""
    if not nl.strip() or not sysml.strip():
        raise ValueError("natural language and SysML must be non-empty")
    if not 0.0 <= threshold <= 1.0:
        raise ValueError("threshold must be between 0 and 1")
    if max_repairs < 0:
        raise ValueError("max_repairs must be non-negative")

    kwargs = {"profile": "runtime", "shards": 3}
    kwargs.update(alignment_kwargs or {})
    kwargs.setdefault("sample_id", f"runtime-{hashlib.sha1(nl.encode()).hexdigest()[:12]}")
    temporary_cache = None
    if "cache_dir" not in kwargs:
        temporary_cache = tempfile.TemporaryDirectory(prefix="spec-alignment-")
        kwargs["cache_dir"] = temporary_cache.name
    candidate = sysml
    attempts = []

    try:
        for attempt_number in range(max_repairs + 1):
            validation = _call_stage(validate, candidate)
            validation_status = _validation_status(validation)

            execution = None
            execution_status = "skipped"
            if validation_status != "failed":
                execution = _call_stage(execute, candidate)
                execution_status = _execution_status(execution)

            alignment = compare_pair(nl, candidate, ask, **kwargs)
            semantic_ok = not needs_repair(alignment, threshold)
            accepted = (
                validation_status in ("passed", "skipped")
                and execution_status in ("passed", "skipped")
                and semantic_ok
            )
            attempts.append({
                "attempt": attempt_number,
                "validation_status": validation_status,
                "validation": validation,
                "execution_status": execution_status,
                "execution": execution,
                "alignment": alignment,
                "accepted": accepted,
            })

            if accepted or repair is None or attempt_number >= max_repairs:
                break
            if validation_status == "unavailable" or execution_status == "unavailable":
                # Infrastructure absence is reported but is not something a model repair can fix.
                if semantic_ok:
                    break

            feedback = _stage_feedback(validation_status, validation,
                                       execution_status, execution)
            prompt = build_repair_prompt(nl, candidate, alignment,
                                         stage_feedback=feedback)
            revised = repair(prompt).strip()
            if not revised or revised == candidate.strip():
                break
            candidate = revised
    finally:
        if temporary_cache is not None:
            temporary_cache.cleanup()

    last = attempts[-1]
    return {
        "accepted": last["accepted"],
        "final_sysml": candidate,
        "repairs": len(attempts) - 1,
        "threshold": threshold,
        "attempts": attempts,
    }


def layer2_executor(candidate: str) -> dict:
    """Adapter for the existing Layer 2 execution harness."""
    from nl2sysml.sysml_execution import ExecutionRequest, run_sysml_execution

    result = run_sysml_execution(ExecutionRequest(candidate_sysml=candidate))
    return result.to_dict()


def _call_stage(callback, candidate):
    if callback is None:
        return None
    return _to_dict(callback(candidate))


def _to_dict(value):
    if value is None or isinstance(value, dict):
        return value
    if hasattr(value, "to_dict"):
        return value.to_dict()
    if is_dataclass(value):
        return asdict(value)
    return {"result": str(value)}


def _validation_status(result: dict | None) -> str:
    if result is None:
        return "skipped"
    if result.get("available") is False:
        return "unavailable"
    for key in ("ok", "is_valid", "valid"):
        if key in result and isinstance(result[key], bool):
            return "passed" if result[key] else "failed"
    return "unavailable"


def _execution_status(result: dict | None) -> str:
    if result is None:
        return "skipped"
    if result.get("kernel_available") is False or result.get("available") is False:
        return "unavailable"
    for key in ("success", "compiled", "ok"):
        if key in result and isinstance(result[key], bool):
            return "passed" if result[key] else "failed"
    return "unavailable"


def _stage_feedback(validation_status, validation, execution_status, execution) -> str:
    lines = []
    if validation_status == "failed":
        lines.append(f"Validation failed: {validation}")
    if execution_status == "failed":
        lines.append(f"Layer 2 execution failed: {execution}")
    return "\n".join(lines)
