"""Metric extraction, aggregation, bootstrap intervals, and paired tests."""

from __future__ import annotations

from collections import Counter
import math
import random


BINARY_METRICS = (
    "normalization_valid", "ir_valid", "artifact_valid", "artifact_pair_valid",
    "modelica_build_attempt_0", "usd_semantic_valid_attempt_0",
    "artifact_valid_attempt_0", "artifact_pair_valid_attempt_0",
    "condition_fidelity",
    "modelica_build", "fmu_export", "fmu_execution",
    "usd_semantic_valid", "named_simulator_load", "stable_simulation",
    "contract_valid", "fmu_interface_valid", "pre_execution_semantic",
    "runtime_execution", "runtime_trace_valid", "behavior_evaluated",
    "post_execution_semantic", "specification_claim_ready",
    "configured_pipeline_success", "end_to_end",
    "all_properties_pass",
)

CONTINUOUS_METRICS = (
    "semantic_score", "semantic_coverage", "verification_tier",
    "maximum_stage_reached", "repairs", "property_total",
    "property_evaluable", "property_satisfied", "property_violated",
    "property_unevaluable", "property_evaluability_rate",
    "property_satisfaction_rate_evaluable", "runtime_survival_fraction",
)


def extract_metrics(profile: str, result: dict, *,
                    infrastructure_error: str | None = None) -> dict:
    if infrastructure_error:
        return {
            "infrastructure_available": False,
            "failure_stage": "infrastructure",
            **{name: None for name in BINARY_METRICS},
            **{name: None for name in CONTINUOUS_METRICS},
        }
    if result.get("infrastructure_pending") is True:
        return {
            "infrastructure_available": False,
            "failure_stage": "infrastructure",
            **{name: None for name in BINARY_METRICS},
            **{name: None for name in CONTINUOUS_METRICS},
        }
    modelica = result.get("modelica", {})
    openusd = result.get("openusd", {})
    hybrid = result.get("hybrid", result if result.get("stage") in {
        "portable_hybrid", "isaac_closed_loop", "newton_closed_loop"
    } else {})
    contract = hybrid.get("contract", result.get("contract", {}))
    fmu = hybrid.get("fmu", result.get("fmu", {}))
    execution = hybrid.get("execution", result.get("execution", {}))
    properties = hybrid.get("properties", result.get("properties", []))
    alignment = result.get("alignment", {})
    capabilities = result.get("capabilities", {})
    one_shot = result.get("one_shot", {})
    study_validity = result.get("study_validity", {})

    modelica_pass = _truth(modelica.get("passed"))
    usd_pass = _truth(openusd.get("passed"))
    artifact_mode = result.get("artifact_mode", "modelica_openusd")
    normalization_valid = _truth(result.get("normalization", {}).get("success"))
    ir_valid = _truth(result.get("plan", {}).get("success"))
    artifact_pair_valid = None if artifact_mode == "modelica_only" else (
        modelica_pass and usd_pass
        if isinstance(modelica_pass, bool) and isinstance(usd_pass, bool)
        else None
    )
    artifact_valid = (
        modelica_pass if artifact_mode == "modelica_only" else artifact_pair_valid
    )
    fmu_export = _truth(fmu.get("success"))
    fmu_execution = _truth(execution.get("success"))
    runtime_failure_class = execution.get("failure_class")
    if not isinstance(runtime_failure_class, str) or not runtime_failure_class:
        runtime_failure_class = None
    runtime_survival_fraction = _runtime_survival_fraction(
        execution, hybrid.get("clock", result.get("clock", {}))
    )
    contract_valid = _truth(contract.get("success"))
    property_pass = (
        all(item.get("passed") is True for item in properties)
        if properties else None
    )
    property_total = len(properties) if properties else None
    property_satisfied = (
        sum(item.get("passed") is True for item in properties)
        if properties else None
    )
    property_violated = (
        sum(item.get("status") == "violated" for item in properties)
        if properties else None
    )
    property_unevaluable = (
        sum(item.get("status") == "unevaluable" for item in properties)
        if properties else None
    )
    property_evaluable = (
        property_total - property_unevaluable
        if property_total is not None and property_unevaluable is not None
        else None
    )
    property_evaluability_rate = (
        property_evaluable / property_total
        if property_total else None
    )
    property_satisfaction_rate_evaluable = (
        property_satisfied / property_evaluable
        if property_evaluable else None
    )
    configured_pipeline_success = _truth(
        result.get("passed", result.get("success"))
    )
    end_to_end = configured_pipeline_success
    simulator = hybrid.get("simulator", hybrid.get("runtime", {}))
    simulator_load = _truth(
        simulator.get("loaded") if isinstance(simulator, dict) else None
    )
    repeatability = hybrid.get("repeatability", {})
    stable = _truth(repeatability.get("success", repeatability.get("passed")))
    if stable is None:
        stable = _truth(hybrid.get("trace_gate", {}).get("success"))
    if profile == "modelica":
        modelica_pass = _truth(result.get("passed", modelica_pass))
    elif profile == "openusd":
        usd_pass = _truth(result.get("passed", usd_pass))
    elif profile == "capability" and not result.get("stage_trace"):
        # Legacy validation-only capability results are never end-to-end.
        end_to_end = False
    stage_trace = {
        item.get("stage"): item.get("passed")
        for item in result.get("stage_trace", []) if isinstance(item, dict)
    }
    if profile == "capability" and result.get("stage_trace"):
        alignment_enabled = result.get("ablation", {}).get(
            "condition", {}
        ).get("alignment")
        if alignment_enabled is None:
            alignment_enabled = result.get(
                "pre_execution_alignment", {}
            ).get("enabled")
        if alignment_enabled is not True:
            # A configured pipeline can finish with the semantic stage disabled,
            # but that is not a comparable full-funnel outcome.
            end_to_end = None

    summary = alignment.get("summary", alignment)
    return {
        "infrastructure_available": True,
        "failure_stage": result.get("failure_stage"),
        "runtime_failure_class": runtime_failure_class,
        "normalization_valid": normalization_valid,
        "ir_valid": ir_valid,
        "artifact_valid": artifact_valid,
        "artifact_pair_valid": artifact_pair_valid,
        "modelica_build_attempt_0": _truth(
            one_shot.get("modelica_valid_attempt_0")
        ),
        "usd_semantic_valid_attempt_0": _truth(
            one_shot.get("openusd_valid_attempt_0")
        ),
        "artifact_pair_valid_attempt_0": _truth(
            one_shot.get("artifact_pair_valid_attempt_0")
        ),
        "artifact_valid_attempt_0": _truth(
            one_shot.get("artifact_valid_attempt_0")
        ),
        "condition_fidelity": _truth(
            study_validity.get("condition_fidelity_passed")
        ),
        "modelica_build": modelica_pass,
        "fmu_export": fmu_export,
        "fmu_execution": fmu_execution,
        "usd_semantic_valid": usd_pass,
        "named_simulator_load": simulator_load,
        "stable_simulation": stable,
        "contract_valid": contract_valid,
        "fmu_interface_valid": contract_valid,
        "pre_execution_semantic": _truth(
            stage_trace.get("pre_execution_semantic_alignment")
        ),
        "runtime_execution": _truth(stage_trace.get("runtime_execution")),
        "runtime_trace_valid": _truth(
            hybrid.get("trace_gate", {}).get("success")
        ),
        "behavior_evaluated": _truth(stage_trace.get("behavior_evaluation")),
        "post_execution_semantic": _truth(
            stage_trace.get(
                "modelica_specification_alignment",
                stage_trace.get("post_execution_semantic_alignment"),
            )
        ),
        "specification_claim_ready": _truth(alignment.get("claim_ready")),
        "configured_pipeline_success": configured_pipeline_success,
        "end_to_end": end_to_end,
        "all_properties_pass": property_pass,
        "property_total": property_total,
        "property_evaluable": property_evaluable,
        "property_satisfied": property_satisfied,
        "property_violated": property_violated,
        "property_unevaluable": property_unevaluable,
        "property_evaluability_rate": property_evaluability_rate,
        "property_satisfaction_rate_evaluable": (
            property_satisfaction_rate_evaluable
        ),
        "runtime_survival_fraction": runtime_survival_fraction,
        "semantic_score": summary.get("weighted_semantic_score"),
        "semantic_coverage": summary.get("evidence_coverage"),
        "blocking_violations": summary.get("blocking_violations"),
        "verification_tier": capabilities.get("highest_reached_tier"),
        "maximum_stage_reached": _maximum_stage_reached(result.get("stage_trace", [])),
        "repairs": _repairs(result),
    }


def summarize_records(records: list[dict], *, bootstrap_samples: int = 2000,
                      seed: int = 20260817) -> dict:
    usable = [row for row in records
              if row.get("metrics", {}).get("infrastructure_available") is True]
    infrastructure_failures = len(records) - len(usable)
    by_condition: dict[str, list[dict]] = {}
    for row in usable:
        by_condition.setdefault(row["condition"]["id"], []).append(row)
    summaries = {}
    for condition, rows in sorted(by_condition.items()):
        metric_summary = {}
        for metric in BINARY_METRICS:
            values = [item["metrics"].get(metric) for item in rows]
            binary = [int(value) for value in values if isinstance(value, bool)]
            metric_summary[metric] = _rate_summary(
                binary, bootstrap_samples=bootstrap_samples,
                seed=seed + sum(map(ord, condition + metric)),
            )
        continuous = {}
        for metric in CONTINUOUS_METRICS:
            values = [item["metrics"].get(metric) for item in rows]
            numeric = [float(value) for value in values
                       if isinstance(value, (int, float)) and not isinstance(value, bool)]
            continuous[metric] = _continuous_summary(numeric)
        summaries[condition] = {
            "run_count": len(rows),
            "binary": metric_summary,
            "continuous": continuous,
            "failure_stages": dict(sorted(Counter(
                item["metrics"].get("failure_stage") or "none" for item in rows
            ).items())),
            "runtime_failure_classes": dict(sorted(Counter(
                item["metrics"].get("runtime_failure_class") or (
                    "none" if item["metrics"].get("fmu_execution") is True
                    else "unclassified"
                )
                for item in rows
                if isinstance(item["metrics"].get("fmu_execution"), bool)
            ).items())),
        }
    return {
        "schema_version": "1.0",
        "record_count": len(records),
        "usable_record_count": len(usable),
        "infrastructure_failure_count": infrastructure_failures,
        "conditions": summaries,
    }


def _maximum_stage_reached(rows: list[dict]) -> int | None:
    reached = [
        item.get("index") for item in rows
        if isinstance(item, dict) and (
            item.get("reached") is True
            or ("reached" not in item and item.get("passed") is True)
        )
        and isinstance(item.get("index"), int)
    ]
    return max(reached) if reached else None


def _runtime_survival_fraction(execution: dict, clock: object) -> float | None:
    """Return completed requested simulation time, without treating it as pass."""
    if not isinstance(execution, dict) or not isinstance(clock, dict):
        return None
    success = execution.get("success")
    if not isinstance(success, bool):
        return None
    try:
        start = float(clock["start_time"])
        stop = float(clock["stop_time"])
    except (KeyError, TypeError, ValueError):
        return None
    if not math.isfinite(start) or not math.isfinite(stop) or stop <= start:
        return None
    if success:
        return 1.0
    failure_time = execution.get("failure_time")
    if not isinstance(failure_time, (int, float)) or isinstance(failure_time, bool):
        return 0.0
    if not math.isfinite(float(failure_time)):
        return 0.0
    return min(1.0, max(0.0, (float(failure_time) - start) / (stop - start)))


def paired_binary_comparison(records: list[dict], condition_a: str,
                             condition_b: str, metric: str) -> dict:
    keyed: dict[tuple, dict[str, bool]] = {}
    for row in records:
        value = row.get("metrics", {}).get(metric)
        condition = row.get("condition", {}).get("id")
        if condition not in {condition_a, condition_b} or not isinstance(value, bool):
            continue
        key = (row.get("task_id"), row.get("variant"), row.get("repetition"))
        keyed.setdefault(key, {})[condition] = value
    pairs = [value for value in keyed.values()
             if condition_a in value and condition_b in value]
    a_only = sum(item[condition_a] and not item[condition_b] for item in pairs)
    b_only = sum(item[condition_b] and not item[condition_a] for item in pairs)
    discordant = a_only + b_only
    p_value = min(1.0, 2.0 * _binomial_cdf(min(a_only, b_only), discordant, 0.5)) \
        if discordant else 1.0
    return {
        "condition_a": condition_a,
        "condition_b": condition_b,
        "metric": metric,
        "paired_count": len(pairs),
        "a_only_success": a_only,
        "b_only_success": b_only,
        "exact_mcnemar_p_value": p_value,
    }


def paired_continuous_comparison(
    records: list[dict], condition_a: str, condition_b: str, metric: str, *,
    bootstrap_samples: int = 10000, seed: int = 20260817,
) -> dict:
    """Compare paired numeric outcomes with an effect size and paired CI."""
    keyed: dict[tuple, dict[str, float]] = {}
    for row in records:
        if row.get("metrics", {}).get("infrastructure_available") is not True:
            continue
        value = row.get("metrics", {}).get(metric)
        condition = row.get("condition", {}).get("id")
        if condition not in {condition_a, condition_b}:
            continue
        if not isinstance(value, (int, float)) or isinstance(value, bool):
            continue
        numeric = float(value)
        if not math.isfinite(numeric):
            continue
        key = (row.get("task_id"), row.get("variant"), row.get("repetition"))
        keyed.setdefault(key, {})[condition] = numeric
    pairs = [value for value in keyed.values()
             if condition_a in value and condition_b in value]
    differences = [item[condition_b] - item[condition_a] for item in pairs]
    if not differences:
        return {
            "condition_a": condition_a, "condition_b": condition_b,
            "metric": metric, "paired_count": 0,
            "mean_a": None, "mean_b": None, "mean_difference_b_minus_a": None,
            "median_difference_b_minus_a": None,
            "mean_difference_ci95": None, "improved": 0, "tied": 0,
            "regressed": 0, "paired_sign_test_p_value": None,
        }
    mean_a = sum(item[condition_a] for item in pairs) / len(pairs)
    mean_b = sum(item[condition_b] for item in pairs) / len(pairs)
    ordered = sorted(differences)
    middle = len(ordered) // 2
    median_difference = ordered[middle] if len(ordered) % 2 else (
        ordered[middle - 1] + ordered[middle]
    ) / 2
    rng = random.Random(seed + sum(map(ord, condition_a + condition_b + metric)))
    bootstrapped = sorted(
        sum(rng.choice(differences) for _ in differences) / len(differences)
        for _ in range(bootstrap_samples)
    )
    low = bootstrapped[int(0.025 * (bootstrap_samples - 1))]
    high = bootstrapped[int(0.975 * (bootstrap_samples - 1))]
    improved = sum(value > 0 for value in differences)
    regressed = sum(value < 0 for value in differences)
    tied = len(differences) - improved - regressed
    discordant = improved + regressed
    sign_p = (
        min(1.0, 2.0 * _binomial_cdf(min(improved, regressed), discordant, 0.5))
        if discordant else 1.0
    )
    return {
        "condition_a": condition_a, "condition_b": condition_b,
        "metric": metric, "paired_count": len(pairs),
        "mean_a": mean_a, "mean_b": mean_b,
        "mean_difference_b_minus_a": sum(differences) / len(differences),
        "median_difference_b_minus_a": median_difference,
        "mean_difference_ci95": [low, high],
        "improved": improved, "tied": tied, "regressed": regressed,
        "paired_sign_test_p_value": sign_p,
    }


def _rate_summary(values: list[int], *, bootstrap_samples: int,
                  seed: int) -> dict:
    if not values:
        return {"n": 0, "rate": None, "ci95": None}
    rate = sum(values) / len(values)
    rng = random.Random(seed)
    samples = sorted(
        sum(rng.choice(values) for _ in values) / len(values)
        for _ in range(bootstrap_samples)
    )
    low = samples[int(0.025 * (bootstrap_samples - 1))]
    high = samples[int(0.975 * (bootstrap_samples - 1))]
    return {"n": len(values), "rate": rate, "ci95": [low, high]}


def _continuous_summary(values: list[float]) -> dict:
    if not values:
        return {"n": 0, "mean": None, "median": None}
    ordered = sorted(values)
    middle = len(ordered) // 2
    median = ordered[middle] if len(ordered) % 2 else (
        ordered[middle - 1] + ordered[middle]
    ) / 2
    return {"n": len(values), "mean": sum(values) / len(values), "median": median}


def _binomial_cdf(k: int, n: int, p: float) -> float:
    return sum(
        math.comb(n, i) * (p ** i) * ((1 - p) ** (n - i))
        for i in range(k + 1)
    )


def _truth(value: object) -> bool | None:
    return value if isinstance(value, bool) else None


def _repairs(result: dict) -> int | None:
    values = []
    for key in ("modelica", "openusd"):
        value = result.get(key, {}).get("repairs")
        if isinstance(value, int) and not isinstance(value, bool):
            values.append(value)
    for key in ("semantic_repair", "runtime_repair"):
        value = result.get(key, {}).get("attempted")
        if isinstance(value, int) and not isinstance(value, bool):
            values.append(value)
    return sum(values) if values else None
