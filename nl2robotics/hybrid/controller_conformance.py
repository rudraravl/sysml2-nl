"""Behavioral conformance probes for the supported H2 controller profile."""

from __future__ import annotations

from collections.abc import Callable
import math
from pathlib import Path

from nl2robotics.contracts.units import UnitError, conversion


RuntimeFactory = Callable[[Path], object]


def evaluate_controller_conformance(
    fmu_path: Path,
    requirement_ir: dict,
    mappings: list[dict],
    clock: dict,
    runtime_factory: RuntimeFactory,
) -> dict:
    """Execute discriminating input vectors against a one-DOF PD controller FMU."""
    try:
        profile = _pd_profile(requirement_ir, mappings)
        probes = _pd_probes(profile)
    except (KeyError, TypeError, ValueError, UnitError) as exc:
        return _report(False, [], f"unsupported controller contract: {exc}")

    rows = []
    for probe in probes:
        runtime = runtime_factory(fmu_path)
        try:
            inputs = {
                profile["position_variable"]: probe["position"],
                profile["velocity_variable"]: probe["velocity"],
            }
            runtime.initialize(
                start_time=float(clock["start_time"]),
                start_values=inputs,
            )
            outputs = runtime.advance(
                current_time=float(clock["start_time"]),
                step_size=float(clock["step_size"]),
                inputs=inputs,
                outputs=[profile["effort_variable"]],
            )
            actual = float(outputs[profile["effort_variable"]])
            expected = float(probe["expected"])
            tolerance = max(1e-5, abs(expected) * 1e-4)
            finite = math.isfinite(actual)
            passed = finite and abs(actual - expected) <= tolerance
            rows.append({
                "id": probe["id"],
                "inputs": inputs,
                "expected_output": expected,
                "actual_output": actual,
                "absolute_error": abs(actual - expected) if finite else None,
                "tolerance": tolerance,
                "passed": passed,
            })
        except Exception as exc:
            rows.append({
                "id": probe["id"],
                "inputs": {
                    profile["position_variable"]: probe["position"],
                    profile["velocity_variable"]: probe["velocity"],
                },
                "expected_output": probe["expected"],
                "actual_output": None,
                "absolute_error": None,
                "tolerance": None,
                "passed": False,
                "error": f"{type(exc).__name__}: {exc}",
            })
        finally:
            try:
                runtime.close()
            except Exception:
                pass

    return _report(bool(rows) and all(row["passed"] for row in rows), rows)


def _pd_profile(requirement_ir: dict, mappings: list[dict]) -> dict:
    controllers = requirement_ir.get("controllers", [])
    if len(controllers) != 1 or str(controllers[0].get("kind", "")).upper() != "PD":
        raise ValueError("behavioral probing currently requires exactly one PD controller")
    position = _one_mapping(mappings, "usd_to_fmu", "joint_position")
    velocity = _one_mapping(mappings, "usd_to_fmu", "joint_velocity")
    effort = _one_mapping(mappings, "fmu_to_usd", "joint_effort")
    joint_id = effort["semantic_joint_id"]
    if any(row["semantic_joint_id"] != joint_id for row in (position, velocity)):
        raise ValueError("PD observation and command mappings must reference one joint")

    parameters = {
        row.get("quantity"): row
        for row in requirement_ir.get("parameters", [])
        if row.get("joint_id") == joint_id and row.get("owner") == "fmu_controller"
    }
    required = {
        "proportional_gain", "derivative_gain", "target_position", "effort_limit"
    }
    missing = required - parameters.keys()
    if missing:
        raise ValueError(f"PD controller parameters are missing: {sorted(missing)}")

    position_unit = str(position["target_unit"])
    velocity_unit = str(velocity["target_unit"])
    effort_unit = str(effort["source_unit"])
    target = conversion(
        str(parameters["target_position"]["unit"]), position_unit
    ).apply(float(parameters["target_position"]["value"]))
    limit = conversion(
        str(parameters["effort_limit"]["unit"]), effort_unit
    ).apply(float(parameters["effort_limit"]["value"]))
    if limit <= 0:
        raise ValueError("effort_limit must be positive")

    # Gain values are compared in their declared controller-side units. The
    # supported H2 profile freezes SI position, velocity, and effort interfaces.
    if position_unit != "rad" or velocity_unit != "rad/s" or effort_unit != "N.m":
        raise ValueError("PD conformance currently requires rad, rad/s, and N.m")
    kp = float(parameters["proportional_gain"]["value"])
    kd = float(parameters["derivative_gain"]["value"])
    if kp <= 0 or kd < 0:
        raise ValueError("PD gains must satisfy kp > 0 and kd >= 0")
    return {
        "position_variable": position["fmu_variable"],
        "velocity_variable": velocity["fmu_variable"],
        "effort_variable": effort["fmu_variable"],
        "target": target,
        "kp": kp,
        "kd": kd,
        "effort_limit": limit,
    }


def _pd_probes(profile: dict) -> list[dict]:
    target = profile["target"]
    kp = profile["kp"]
    kd = profile["kd"]
    limit = profile["effort_limit"]
    position_delta = min(0.1, limit / (4.0 * kp))
    velocity_delta = 0.2 if kd == 0 else min(0.2, limit / (4.0 * kd))

    def expected(position: float, velocity: float) -> float:
        raw = kp * (target - position) - kd * velocity
        return max(-limit, min(limit, raw))

    vectors = [
        ("equilibrium", target, 0.0),
        ("positive_position_error", target - position_delta, 0.0),
        ("negative_position_error", target + position_delta, 0.0),
        ("positive_velocity_damping", target, velocity_delta),
        ("negative_velocity_damping", target, -velocity_delta),
        ("positive_saturation", target - 2.0 * limit / kp, 0.0),
        ("negative_saturation", target + 2.0 * limit / kp, 0.0),
    ]
    return [
        {"id": probe_id, "position": position, "velocity": velocity,
         "expected": expected(position, velocity)}
        for probe_id, position, velocity in vectors
    ]


def _one_mapping(mappings: list[dict], direction: str, quantity: str) -> dict:
    matches = [
        row for row in mappings
        if row.get("direction") == direction and row.get("usd_quantity") == quantity
    ]
    if len(matches) != 1:
        raise ValueError(
            f"expected one {direction} {quantity} mapping, found {len(matches)}"
        )
    return matches[0]


def _report(success: bool, probes: list[dict], error: str | None = None) -> dict:
    report = {
        "stage": "controller_behavioral_conformance",
        "profile": "one_dof_pd_effort",
        "success": success,
        "probe_count": len(probes),
        "passed_probes": sum(row.get("passed") is True for row in probes),
        "probes": probes,
    }
    if error:
        report["error"] = error
    return report
