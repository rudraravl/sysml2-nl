"""Metric extraction, aggregation, bootstrap intervals, and paired tests."""

from __future__ import annotations

from collections import Counter
import math
import random


BINARY_METRICS = (
    "modelica_build", "fmu_export", "fmu_execution",
    "usd_semantic_valid", "named_simulator_load", "stable_simulation",
    "contract_valid", "end_to_end", "all_properties_pass",
)


def extract_metrics(profile: str, result: dict, *,
                    infrastructure_error: str | None = None) -> dict:
    if infrastructure_error:
        return {
            "infrastructure_available": False,
            "failure_stage": "infrastructure",
            **{name: None for name in BINARY_METRICS},
        }
    if result.get("infrastructure_pending") is True:
        return {
            "infrastructure_available": False,
            "failure_stage": "infrastructure",
            **{name: None for name in BINARY_METRICS},
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

    modelica_pass = _truth(modelica.get("passed"))
    usd_pass = _truth(openusd.get("passed"))
    fmu_export = _truth(fmu.get("success"))
    fmu_execution = _truth(execution.get("success"))
    contract_valid = _truth(contract.get("success"))
    property_pass = (
        all(item.get("passed") is True for item in properties)
        if properties else None
    )
    end_to_end = _truth(result.get("passed", result.get("success")))
    simulator = hybrid.get("simulator", hybrid.get("runtime", {}))
    simulator_load = _truth(
        simulator.get("loaded") if isinstance(simulator, dict) else None
    )
    repeatability = hybrid.get("repeatability", {})
    stable = _truth(repeatability.get("success", repeatability.get("passed")))
    if profile == "modelica":
        modelica_pass = _truth(result.get("passed", modelica_pass))
    elif profile == "openusd":
        usd_pass = _truth(result.get("passed", usd_pass))

    summary = alignment.get("summary", alignment)
    return {
        "infrastructure_available": True,
        "failure_stage": result.get("failure_stage"),
        "modelica_build": modelica_pass,
        "fmu_export": fmu_export,
        "fmu_execution": fmu_execution,
        "usd_semantic_valid": usd_pass,
        "named_simulator_load": simulator_load,
        "stable_simulation": stable,
        "contract_valid": contract_valid,
        "end_to_end": end_to_end,
        "all_properties_pass": property_pass,
        "semantic_score": summary.get("weighted_semantic_score"),
        "semantic_coverage": summary.get("evidence_coverage"),
        "blocking_violations": summary.get("blocking_violations"),
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
        for metric in ("semantic_score", "semantic_coverage", "repairs"):
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
        }
    return {
        "schema_version": "1.0",
        "record_count": len(records),
        "usable_record_count": len(usable),
        "infrastructure_failure_count": infrastructure_failures,
        "conditions": summaries,
    }


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
    return sum(values) if values else None
