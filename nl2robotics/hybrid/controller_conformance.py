"""Behavioral conformance probes for articulated PD controller FMUs."""

from __future__ import annotations

from collections.abc import Callable
import math
from pathlib import Path

from nl2robotics.contracts.articulated_profile import joint_units
from nl2robotics.contracts.units import UnitError, conversion


RuntimeFactory = Callable[[Path], object]


def evaluate_controller_conformance(
    fmu_path: Path,
    requirement_ir: dict,
    mappings: list[dict],
    clock: dict,
    runtime_factory: RuntimeFactory,
) -> dict:
    """Probe each joint law plus cross-channel isolation in a controller FMU."""
    try:
        profiles = _pd_profiles(requirement_ir, mappings)
        probes = _pd_probes(profiles, mappings)
    except (KeyError, TypeError, ValueError, UnitError) as exc:
        return _report(False, [], f"unsupported controller contract: {exc}")

    output_variables = [profile["effort_variable"] for profile in profiles]
    rows = []
    for probe in probes:
        runtime = runtime_factory(fmu_path)
        try:
            runtime.initialize(
                start_time=float(clock["start_time"]),
                start_values=probe["inputs"],
            )
            outputs = runtime.advance(
                current_time=float(clock["start_time"]),
                step_size=float(clock["step_size"]),
                inputs=probe["inputs"],
                outputs=output_variables,
            )
            actual = {name: float(outputs[name]) for name in output_variables}
            checks = {}
            for name, expected in probe["expected_outputs"].items():
                value = actual[name]
                tolerance = max(1e-5, abs(expected) * 1e-4)
                finite = math.isfinite(value)
                checks[name] = {
                    "expected": expected,
                    "actual": value,
                    "absolute_error": abs(value - expected) if finite else None,
                    "tolerance": tolerance,
                    "passed": finite and abs(value - expected) <= tolerance,
                }
            row = {
                "id": probe["id"],
                "joint_id": probe["joint_id"],
                "inputs": probe["inputs"],
                "expected_outputs": probe["expected_outputs"],
                "actual_outputs": actual,
                "output_checks": checks,
                "passed": all(item["passed"] for item in checks.values()),
            }
            if len(checks) == 1:
                check = next(iter(checks.values()))
                row.update({
                    "expected_output": check["expected"],
                    "actual_output": check["actual"],
                    "absolute_error": check["absolute_error"],
                    "tolerance": check["tolerance"],
                })
            rows.append(row)
        except Exception as exc:
            rows.append({
                "id": probe["id"],
                "joint_id": probe["joint_id"],
                "inputs": probe["inputs"],
                "expected_outputs": probe["expected_outputs"],
                "actual_outputs": None,
                "passed": False,
                "error": f"{type(exc).__name__}: {exc}",
            })
        finally:
            try:
                runtime.close()
            except Exception:
                pass

    return _report(
        bool(rows) and all(row["passed"] for row in rows),
        rows,
        joint_count=len(profiles),
    )


def _pd_profiles(requirement_ir: dict, mappings: list[dict]) -> list[dict]:
    controllers = requirement_ir.get("controllers", [])
    if not controllers or any(
            str(item.get("kind", "")).upper() != "PD" for item in controllers):
        raise ValueError("behavioral probing requires grounded PD controllers")
    joints = {
        item["id"]: item for item in requirement_ir.get("joints", [])
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }
    actuated = sorted({
        item.get("joint_id") for item in requirement_ir.get("actuators", [])
        if item.get("command") == "joint_effort"
    })
    if not actuated:
        raise ValueError("behavioral probing requires an effort-actuated joint")

    profiles = []
    for joint_id in actuated:
        joint = joints[joint_id]
        position = _one_joint_mapping(
            mappings, joint_id, "usd_to_fmu", "joint_position"
        )
        velocity = _one_joint_mapping(
            mappings, joint_id, "usd_to_fmu", "joint_velocity"
        )
        effort = _one_joint_mapping(
            mappings, joint_id, "fmu_to_usd", "joint_effort"
        )
        parameters = {
            row.get("quantity"): row
            for row in requirement_ir.get("parameters", [])
            if row.get("joint_id") == joint_id
            and row.get("owner") == "fmu_controller"
        }
        required = {
            "proportional_gain", "derivative_gain", "target_position", "effort_limit"
        }
        missing = required - parameters.keys()
        if missing:
            raise ValueError(
                f"PD controller parameters for {joint_id!r} are missing: "
                f"{sorted(missing)}"
            )
        units = joint_units(str(joint["type"]))
        target = conversion(
            str(parameters["target_position"]["unit"]), units.position
        ).apply(float(parameters["target_position"]["value"]))
        limit = conversion(
            str(parameters["effort_limit"]["unit"]), units.effort
        ).apply(float(parameters["effort_limit"]["value"]))
        kp = conversion(
            str(parameters["proportional_gain"]["unit"]),
            units.proportional_gain,
        ).apply(float(parameters["proportional_gain"]["value"]))
        kd = conversion(
            str(parameters["derivative_gain"]["unit"]),
            units.derivative_gain,
        ).apply(float(parameters["derivative_gain"]["value"]))
        if limit <= 0 or kp <= 0 or kd < 0:
            raise ValueError("PD gains require kp > 0, kd >= 0, and limit > 0")
        profiles.append({
            "joint_id": joint_id,
            "position_variable": position["fmu_variable"],
            "velocity_variable": velocity["fmu_variable"],
            "effort_variable": effort["fmu_variable"],
            "position_fmu_unit": str(position["target_unit"]),
            "velocity_fmu_unit": str(velocity["target_unit"]),
            "effort_fmu_unit": str(effort["source_unit"]),
            "position_unit": units.position,
            "velocity_unit": units.velocity,
            "effort_unit": units.effort,
            "target": target,
            "kp": kp,
            "kd": kd,
            "effort_limit": limit,
        })
    return profiles


def _pd_probes(profiles: list[dict], mappings: list[dict]) -> list[dict]:
    base_inputs = {}
    profile_by_joint = {item["joint_id"]: item for item in profiles}
    for mapping in mappings:
        if mapping.get("direction") != "usd_to_fmu":
            continue
        profile = profile_by_joint.get(mapping.get("semantic_joint_id"))
        canonical = 0.0
        if profile is not None and mapping.get("usd_quantity") == "joint_position":
            canonical = profile["target"]
        source_unit = _canonical_mapping_unit(mapping)
        base_inputs[mapping["fmu_variable"]] = conversion(
            source_unit, str(mapping["target_unit"])
        ).apply(canonical)

    probes = []
    multi = len(profiles) > 1
    for profile in profiles:
        target = profile["target"]
        kp = profile["kp"]
        kd = profile["kd"]
        limit = profile["effort_limit"]
        position_delta = min(0.1, limit / (4.0 * kp))
        velocity_delta = 0.2 if kd == 0 else min(0.2, limit / (4.0 * kd))
        vectors = [
            ("equilibrium", target, 0.0),
            ("positive_position_error", target - position_delta, 0.0),
            ("negative_position_error", target + position_delta, 0.0),
            ("positive_velocity_damping", target, velocity_delta),
            ("negative_velocity_damping", target, -velocity_delta),
            ("positive_saturation", target - 2.0 * limit / kp, 0.0),
            ("negative_saturation", target + 2.0 * limit / kp, 0.0),
        ]
        for probe_id, position, velocity in vectors:
            raw = kp * (target - position) - kd * velocity
            expected_effort = max(-limit, min(limit, raw))
            inputs = dict(base_inputs)
            inputs[profile["position_variable"]] = conversion(
                profile["position_unit"], profile["position_fmu_unit"]
            ).apply(position)
            inputs[profile["velocity_variable"]] = conversion(
                profile["velocity_unit"], profile["velocity_fmu_unit"]
            ).apply(velocity)
            expected_outputs = {
                item["effort_variable"]: conversion(
                    item["effort_unit"], item["effort_fmu_unit"]
                ).apply(expected_effort if item is profile else 0.0)
                for item in profiles
            }
            probes.append({
                "id": f"{profile['joint_id']}__{probe_id}" if multi else probe_id,
                "joint_id": profile["joint_id"],
                "inputs": inputs,
                "expected_outputs": expected_outputs,
            })
    return probes


def _canonical_mapping_unit(mapping: dict) -> str:
    units = joint_units(str(mapping.get("joint_type")))
    return {
        "joint_position": units.position,
        "joint_velocity": units.velocity,
        "joint_effort": units.effort,
    }[str(mapping["usd_quantity"])]


def _one_joint_mapping(mappings: list[dict], joint_id: str,
                       direction: str, quantity: str) -> dict:
    matches = [
        row for row in mappings
        if row.get("semantic_joint_id") == joint_id
        and row.get("direction") == direction
        and row.get("usd_quantity") == quantity
    ]
    if len(matches) != 1:
        raise ValueError(
            f"expected one {direction} {quantity} mapping for {joint_id!r}, "
            f"found {len(matches)}"
        )
    return matches[0]


def _report(success: bool, probes: list[dict], error: str | None = None,
            *, joint_count: int = 0) -> dict:
    report = {
        "stage": "controller_behavioral_conformance",
        "profile": "articulated_independent_pd_effort",
        "success": success,
        "joint_count": joint_count,
        "probe_count": len(probes),
        "passed_probes": sum(row.get("passed") is True for row in probes),
        "probes": probes,
    }
    if error:
        report["error"] = error
    return report
