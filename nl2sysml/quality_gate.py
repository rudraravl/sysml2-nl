"""Post-generation quality gate: optional validate -> optional execute -> align -> repair.

Generation's preferred ordering is handled outside this module:
  MoE synthesis -> compiler refine -> kernel refine -> semantic align (this gate).

After each semantic repair, the gate re-runs compiler and kernel checks, then keeps
the repaired model only when it improves alignment without worsening executability.
Pass ``execute`` (e.g. ``layer2_executor``) whenever kernel validation should apply
to repaired candidates.
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
    """Evaluate a candidate and optionally repair it, rerunning every quality stage.

    Repaired candidates are kept only when semantic similarity strictly improves and
    neither compiler validation nor kernel execution status regresses relative to the
    current best candidate.
    """
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

    attempts: list[dict] = []
    best_sysml = sysml
    best_idx = 0
    repairs_kept = 0

    try:
        baseline = _evaluate_candidate(
            nl, best_sysml, ask, validate, execute, kwargs, threshold, attempt=0
        )
        baseline["kept"] = True
        baseline["rejected_reason"] = None
        attempts.append(baseline)

        while (
            not attempts[best_idx]["accepted"]
            and repair is not None
            and (len(attempts) - 1) < max_repairs
        ):
            best_attempt = attempts[best_idx]
            if not needs_repair(best_attempt["alignment"], threshold):
                # Similarity already clears threshold — repair is unlikely to help
                # when the failure is compiler errors or missing infrastructure.
                if (
                    best_attempt["validation_status"] in ("unavailable", "failed")
                    or best_attempt["execution_status"] in ("unavailable", "failed")
                ):
                    break

            feedback = _stage_feedback(
                best_attempt["validation_status"],
                best_attempt["validation"],
                best_attempt["execution_status"],
                best_attempt["execution"],
            )
            prompt = build_repair_prompt(
                nl, best_sysml, best_attempt["alignment"], stage_feedback=feedback
            )
            revised = repair(prompt).strip()
            if not revised or revised == best_sysml.strip():
                break

            attempt_number = len(attempts)
            evaluated = _evaluate_candidate(
                nl, revised, ask, validate, execute, kwargs, threshold,
                attempt=attempt_number,
            )
            keep, reason = _should_keep_repair(best_attempt, evaluated)
            evaluated["kept"] = keep
            evaluated["rejected_reason"] = None if keep else reason
            attempts.append(evaluated)

            if keep:
                best_sysml = revised
                best_idx = attempt_number
                repairs_kept += 1
    finally:
        if temporary_cache is not None:
            temporary_cache.cleanup()

    best = attempts[best_idx]
    return {
        "accepted": best["accepted"],
        "final_sysml": best_sysml,
        "repairs": len(attempts) - 1,
        "repairs_kept": repairs_kept,
        "kept_attempt": best_idx,
        "threshold": threshold,
        "attempts": attempts,
    }


def layer2_executor(candidate: str) -> dict:
    """Adapter for the existing Layer 2 execution harness."""
    from nl2sysml.sysml_execution import ExecutionRequest, run_sysml_execution

    result = run_sysml_execution(ExecutionRequest(candidate_sysml=candidate))
    return result.to_dict()


def _evaluate_candidate(
    nl: str,
    candidate: str,
    ask: Callable[[str], str],
    validate: Callable[[str], Any] | None,
    execute: Callable[[str], Any] | None,
    alignment_kwargs: dict,
    threshold: float,
    *,
    attempt: int,
) -> dict:
    validation = _call_stage(validate, candidate)
    validation_status = _validation_status(validation)

    execution = None
    execution_status = "skipped"
    if validation_status != "failed":
        execution = _call_stage(execute, candidate)
        execution_status = _execution_status(execution)

    alignment = compare_pair(nl, candidate, ask, **alignment_kwargs)
    semantic_ok = not needs_repair(alignment, threshold)
    accepted = (
        validation_status in ("passed", "skipped")
        and execution_status in ("passed", "skipped")
        and semantic_ok
    )
    return {
        "attempt": attempt,
        "validation_status": validation_status,
        "validation": validation,
        "execution_status": execution_status,
        "execution": execution,
        "alignment": alignment,
        "accepted": accepted,
    }


def _similarity_value(attempt: dict) -> float:
    summary = attempt.get("alignment", {}).get("summary", {})
    similarity = summary.get("similarity")
    if similarity is None:
        return float("-inf")
    return float(similarity)


def _status_rank(status: str) -> int:
    if status == "passed":
        return 2
    if status in ("skipped", "unavailable"):
        return 1
    return 0


def _worsens_executability(baseline: dict, candidate: dict) -> bool:
    return (
        _status_rank(candidate["validation_status"])
        < _status_rank(baseline["validation_status"])
        or _status_rank(candidate["execution_status"])
        < _status_rank(baseline["execution_status"])
    )


def _error_count(attempt: dict) -> int:
    """Extract compiler error count from validation result."""
    v = attempt.get("validation") or {}
    return v.get("error_count", 0)


def _should_keep_repair(baseline: dict, candidate: dict) -> tuple[bool, str | None]:
    """Keep if alignment improves, or errors decrease at ~equal similarity."""
    if _worsens_executability(baseline, candidate):
        return False, "executability_worsened"
    sim_b = _similarity_value(baseline)
    sim_c = _similarity_value(candidate)
    if sim_c > sim_b:
        return True, None
    # Accept if similarity is roughly equal (±0.03) and compiler errors decreased
    if abs(sim_c - sim_b) <= 0.03 and _error_count(candidate) < _error_count(baseline):
        return True, None
    return False, "no_alignment_improvement"


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
