"""Structured OpenUSD robotics validation using the official Python APIs."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from pxr import Usd, UsdGeom, UsdPhysics


def issue(stage: str, severity: str, code: str, message: str,
          prim: str | None = None) -> dict:
    result = {
        "stage": stage,
        "severity": severity,
        "code": code,
        "message": message,
    }
    if prim:
        result["prim"] = prim
    return result


def validate(path: Path) -> dict:
    issues = []
    stage = Usd.Stage.Open(str(path))
    if stage is None:
        return {
            "success": False,
            "stage_opened": False,
            "issues": [issue(
                "parse", "error", "stage_open_failed",
                "OpenUSD could not open the stage",
            )],
        }

    default_prim = stage.GetDefaultPrim()
    if not default_prim:
        issues.append(issue(
            "metadata", "error", "missing_default_prim",
            "stage must declare a default prim",
        ))
    _validate_metadata(stage, issues)

    physics_scenes = []
    physics_scene_details = []
    rigid_bodies = []
    rigid_body_details = []
    collisions = []
    collision_details = []
    joints = []
    joint_details = []
    articulations = []
    sensors = []
    sensor_details = []
    materials = []
    material_details = []
    for prim in stage.Traverse():
        path_text = str(prim.GetPath())
        if prim.IsA(UsdPhysics.Scene):
            physics_scenes.append(path_text)
            physics_scene_details.append(_physics_scene_detail(prim))
        if prim.HasAPI(UsdPhysics.RigidBodyAPI):
            rigid_bodies.append(path_text)
            rigid_body_details.append(_rigid_body_detail(prim))
            _validate_rigid_body(prim, issues)
        if prim.HasAPI(UsdPhysics.CollisionAPI):
            collisions.append(path_text)
            collision_details.append(_collision_detail(prim))
        if prim.HasAPI(UsdPhysics.ArticulationRootAPI):
            articulations.append(path_text)
        joint = UsdPhysics.Joint(prim)
        if joint:
            joints.append(path_text)
            joint_details.append(_joint_detail(prim, joint))
            _validate_joint(stage, prim, joint, issues)
        if prim.HasAttribute("robotics:sensorType"):
            sensors.append(path_text)
            sensor_details.append(_sensor_detail(prim))
        if prim.HasAPI(UsdPhysics.MaterialAPI):
            materials.append(path_text)
            material_details.append(_material_detail(prim))

    if not physics_scenes:
        issues.append(issue(
            "physics", "error", "missing_physics_scene",
            "stage must contain a UsdPhysics PhysicsScene",
        ))
    if not rigid_bodies:
        issues.append(issue(
            "physics", "warning", "no_rigid_bodies",
            "stage contains no rigid bodies",
        ))
    if joints and not articulations:
        issues.append(issue(
            "articulation", "error", "missing_articulation_root",
            "a jointed robot must declare an articulation root",
        ))
    for body_path in rigid_bodies:
        if not _has_collision_descendant(stage.GetPrimAtPath(body_path)):
            issues.append(issue(
                "collision", "error", "rigid_body_without_collision",
                "dynamic rigid body has no collision API on itself or a child",
                body_path,
            ))

    errors = sum(item["severity"] == "error" for item in issues)
    warnings = sum(item["severity"] == "warning" for item in issues)
    return {
        "success": errors == 0,
        "stage_opened": True,
        "metadata": {
            "default_prim": str(default_prim.GetPath()) if default_prim else None,
            "meters_per_unit": UsdGeom.GetStageMetersPerUnit(stage),
            "kilograms_per_unit": UsdPhysics.GetStageKilogramsPerUnit(stage),
            "up_axis": UsdGeom.GetStageUpAxis(stage),
            "time_codes_per_second": stage.GetTimeCodesPerSecond(),
        },
        "counts": {
            "physics_scenes": len(physics_scenes),
            "rigid_bodies": len(rigid_bodies),
            "collisions": len(collisions),
            "joints": len(joints),
            "articulations": len(articulations),
            "sensors": len(sensors),
            "materials": len(materials),
        },
        "evidence": {
            "physics_scenes": physics_scenes,
            "physics_scene_details": physics_scene_details,
            "rigid_bodies": rigid_bodies,
            "rigid_body_details": rigid_body_details,
            "collisions": collisions,
            "collision_details": collision_details,
            "joints": joints,
            "joint_details": joint_details,
            "articulations": articulations,
            "sensors": sensors,
            "sensor_details": sensor_details,
            "materials": materials,
            "material_details": material_details,
        },
        "issues": issues,
        "error_count": errors,
        "warning_count": warnings,
    }


def _validate_metadata(stage: Usd.Stage, issues: list[dict]) -> None:
    expected = (
        ("metersPerUnit", "meters_per_unit"),
        ("kilogramsPerUnit", "kilograms_per_unit"),
        ("upAxis", "up_axis"),
        ("timeCodesPerSecond", "time_codes_per_second"),
    )
    for key, code in expected:
        if not stage.HasAuthoredMetadata(key):
            issues.append(issue(
                "metadata", "error", f"missing_{code}",
                f"stage must explicitly author {key}",
            ))
    if abs(UsdGeom.GetStageMetersPerUnit(stage) - 1.0) > 1e-12:
        issues.append(issue(
            "metadata", "error", "non_si_length",
            "portable robotics stages must use metersPerUnit = 1",
        ))
    if abs(UsdPhysics.GetStageKilogramsPerUnit(stage) - 1.0) > 1e-12:
        issues.append(issue(
            "metadata", "error", "non_si_mass",
            "portable robotics stages must use kilogramsPerUnit = 1",
        ))
    if UsdGeom.GetStageUpAxis(stage) != UsdGeom.Tokens.z:
        issues.append(issue(
            "metadata", "error", "unsupported_up_axis",
            "portable robotics stages must use Z-up",
        ))


def _validate_rigid_body(prim: Usd.Prim, issues: list[dict]) -> None:
    mass_api = UsdPhysics.MassAPI(prim)
    mass_attr = mass_api.GetMassAttr() if mass_api else None
    mass = mass_attr.Get() if mass_attr and mass_attr.HasAuthoredValueOpinion() else None
    if mass is None:
        issues.append(issue(
            "mass", "warning", "implicit_mass",
            "rigid body has no explicitly authored mass",
            str(prim.GetPath()),
        ))
    elif mass <= 0:
        issues.append(issue(
            "mass", "error", "non_positive_mass",
            "rigid-body mass must be positive",
            str(prim.GetPath()),
        ))


def _physics_scene_detail(prim: Usd.Prim) -> dict:
    scene = UsdPhysics.Scene(prim)
    direction = scene.GetGravityDirectionAttr().Get()
    magnitude = scene.GetGravityMagnitudeAttr().Get()
    return {
        "path": str(prim.GetPath()),
        "gravity_direction": [float(value) for value in direction],
        "gravity_magnitude": _finite_or_none(magnitude),
    }


def _rigid_body_detail(prim: Usd.Prim) -> dict:
    body = UsdPhysics.RigidBodyAPI(prim)
    mass_api = UsdPhysics.MassAPI(prim)
    mass_attr = mass_api.GetMassAttr() if mass_api else None
    kinematic_attr = body.GetKinematicEnabledAttr() if body else None
    return {
        "path": str(prim.GetPath()),
        "mass": mass_attr.Get() if mass_attr and mass_attr.HasAuthoredValueOpinion() else None,
        "kinematic_enabled": bool(kinematic_attr.Get()) if kinematic_attr else False,
        "translation": _vector_attribute(prim, "xformOp:translate"),
        "scale": _vector_attribute(prim, "xformOp:scale"),
    }


def _collision_detail(prim: Usd.Prim) -> dict:
    type_name = prim.GetTypeName()
    size = _number_attribute(prim, "size")
    radius = _number_attribute(prim, "radius")
    height = _number_attribute(prim, "height")
    scale = _vector_attribute(prim, "xformOp:scale") or [1.0, 1.0, 1.0]
    dimensions = None
    if type_name == "Cube" and size is not None:
        dimensions = [abs(size * value) for value in scale]
    return {
        "path": str(prim.GetPath()),
        "parent_rigid_body": _parent_rigid_body(prim),
        "shape": type_name.lower(),
        "size": size,
        "radius": radius,
        "height": height,
        "scale": scale,
        "dimensions": dimensions,
    }


def _sensor_detail(prim: Usd.Prim) -> dict:
    return {
        "path": str(prim.GetPath()),
        "sensor_type": prim.GetAttribute("robotics:sensorType").Get(),
        "parent": str(prim.GetParent().GetPath()),
        "translation": _vector_attribute(prim, "xformOp:translate"),
    }


def _material_detail(prim: Usd.Prim) -> dict:
    material = UsdPhysics.MaterialAPI(prim)
    return {
        "path": str(prim.GetPath()),
        "static_friction": _authored_number(material.GetStaticFrictionAttr()),
        "dynamic_friction": _authored_number(material.GetDynamicFrictionAttr()),
        "restitution": _authored_number(material.GetRestitutionAttr()),
    }


def _parent_rigid_body(prim: Usd.Prim) -> str | None:
    current = prim.GetParent()
    while current:
        if current.HasAPI(UsdPhysics.RigidBodyAPI):
            return str(current.GetPath())
        current = current.GetParent()
    return None


def _number_attribute(prim: Usd.Prim, name: str) -> float | None:
    attribute = prim.GetAttribute(name)
    return _authored_number(attribute)


def _authored_number(attribute) -> float | None:
    if not attribute or not attribute.HasAuthoredValueOpinion():
        return None
    value = attribute.Get()
    return float(value) if value is not None else None


def _vector_attribute(prim: Usd.Prim, name: str) -> list[float] | None:
    attribute = prim.GetAttribute(name)
    if not attribute or not attribute.HasAuthoredValueOpinion():
        return None
    value = attribute.Get()
    return [float(item) for item in value] if value is not None else None


def _validate_joint(stage: Usd.Stage, prim: Usd.Prim, joint: UsdPhysics.Joint,
                    issues: list[dict]) -> None:
    body0 = joint.GetBody0Rel().GetTargets()
    body1 = joint.GetBody1Rel().GetTargets()
    if not body0 and not body1:
        issues.append(issue(
            "joint", "error", "unbound_joint",
            "joint must target at least one body",
            str(prim.GetPath()),
        ))
    for target in [*body0, *body1]:
        if not stage.GetPrimAtPath(target):
            issues.append(issue(
                "joint", "error", "invalid_body_target",
                f"joint target does not resolve: {target}",
                str(prim.GetPath()),
            ))
    if prim.IsA(UsdPhysics.RevoluteJoint):
        typed = UsdPhysics.RevoluteJoint(prim)
        low = typed.GetLowerLimitAttr().Get()
        high = typed.GetUpperLimitAttr().Get()
        if low is not None and high is not None and low > high:
            issues.append(issue(
                "joint", "error", "reversed_limits",
                "revolute joint lower limit exceeds upper limit",
                str(prim.GetPath()),
            ))
    if prim.IsA(UsdPhysics.PrismaticJoint):
        typed = UsdPhysics.PrismaticJoint(prim)
        low = typed.GetLowerLimitAttr().Get()
        high = typed.GetUpperLimitAttr().Get()
        if low is not None and high is not None and low > high:
            issues.append(issue(
                "joint", "error", "reversed_limits",
                "prismatic joint lower limit exceeds upper limit",
                str(prim.GetPath()),
            ))


def _joint_detail(prim: Usd.Prim, joint: UsdPhysics.Joint) -> dict:
    drives = sorted({
        attribute.GetName().split(":")[1]
        for attribute in prim.GetAttributes()
        if attribute.GetName().startswith("drive:")
        and len(attribute.GetName().split(":")) > 2
    })
    result = {
        "path": str(prim.GetPath()),
        "type": "joint",
        "body0": [str(path) for path in joint.GetBody0Rel().GetTargets()],
        "body1": [str(path) for path in joint.GetBody1Rel().GetTargets()],
        "axis": None,
        "lower_limit": None,
        "upper_limit": None,
        "drives": drives,
    }
    if prim.IsA(UsdPhysics.RevoluteJoint):
        typed = UsdPhysics.RevoluteJoint(prim)
        result.update({
            "type": "revolute",
            "axis": typed.GetAxisAttr().Get(),
            "lower_limit": _finite_or_none(typed.GetLowerLimitAttr().Get()),
            "upper_limit": _finite_or_none(typed.GetUpperLimitAttr().Get()),
        })
    elif prim.IsA(UsdPhysics.PrismaticJoint):
        typed = UsdPhysics.PrismaticJoint(prim)
        result.update({
            "type": "prismatic",
            "axis": typed.GetAxisAttr().Get(),
            "lower_limit": _finite_or_none(typed.GetLowerLimitAttr().Get()),
            "upper_limit": _finite_or_none(typed.GetUpperLimitAttr().Get()),
        })
    elif prim.IsA(UsdPhysics.SphericalJoint):
        typed = UsdPhysics.SphericalJoint(prim)
        result.update({
            "type": "spherical",
            "axis": typed.GetAxisAttr().Get(),
        })
    elif prim.IsA(UsdPhysics.FixedJoint):
        result["type"] = "fixed"
    return result


def _finite_or_none(value):
    if value is None or not math.isfinite(float(value)):
        return None
    return value


def _has_collision_descendant(prim: Usd.Prim) -> bool:
    if prim.HasAPI(UsdPhysics.CollisionAPI):
        return True
    return any(child.HasAPI(UsdPhysics.CollisionAPI) for child in Usd.PrimRange(prim))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    try:
        report = validate(args.stage)
    except Exception as exc:
        report = {
            "success": False,
            "issues": [issue(
                "validator", "error", "validator_exception",
                f"{type(exc).__name__}: {exc}",
            )],
            "error_count": 1,
            "warning_count": 0,
        }
    args.report.write_text(
        json.dumps(report, indent=2, allow_nan=False), encoding="utf-8"
    )
    return 0 if report["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
