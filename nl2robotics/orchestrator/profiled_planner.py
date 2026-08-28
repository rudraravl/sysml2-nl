"""Planning for broad, capability-tiered robotics artifact generation."""

from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass
import json
import re

from nl2robotics.contracts.capabilities import capability_report
from nl2robotics.contracts.requirement_ir import validate_requirement_ir


@dataclass(frozen=True)
class CapabilityPlan:
    task_id: str
    model_name: str
    requirement_ir: dict
    contract: dict
    identifiers: dict
    modelica_requirement: str
    openusd_requirement: str

    def to_dict(self) -> dict:
        return {
            "schema_version": "1.0",
            "task_id": self.task_id,
            "execution_mode": "capability_tiered",
            "model_name": self.model_name,
            "identifiers": self.identifiers,
            "capabilities": self.contract["capabilities"],
        }


def build_capability_plan(requirement_ir: dict) -> CapabilityPlan:
    """Create complementary Modelica and OpenUSD obligations without invention."""
    validation = validate_requirement_ir(requirement_ir)
    if not validation.success:
        # Imported lazily to avoid making the strict planner depend on this module.
        from .planner import PlanIssue, PlanningError
        raise PlanningError([
            PlanIssue(item.code, item.message, item.path)
            for item in validation.issues
        ])
    if requirement_ir.get("execution_mode") != "capability_tiered":
        from .planner import PlanIssue, PlanningError
        raise PlanningError([PlanIssue(
            "unsupported_mode",
            "capability planning requires execution_mode capability_tiered",
            "$.execution_mode",
        )])

    ir = deepcopy(requirement_ir)
    for collection in (
        "domains", "entities", "joints", "parameters", "dynamics", "controllers",
        "actuators", "sensors", "environment", "interfaces", "properties",
    ):
        ir.setdefault(collection, [])
    ir.setdefault("assumptions", [])
    ir.setdefault("unknowns", [])
    task_id = ir["task_id"]
    model_name = f"RobotTask_{_identifier(task_id)}"
    entity_paths = {
        row["id"]: f"/World/{_usd_identifier(row['id'])}"
        for row in ir["entities"]
    }
    joint_paths = {
        row["id"]: f"/World/Joints/{_usd_identifier(row['id'])}"
        for row in ir["joints"]
    }
    sensor_paths = {
        row["id"]: f"/World/Sensors/{_usd_identifier(row['id'])}"
        for row in ir["sensors"]
    }
    mappings = []
    variable_names = {}
    for interface in ir["interfaces"]:
        direction = interface["direction"]
        variable = (
            f"in_{_identifier(interface['id'])}"
            if direction == "usd_to_fmu"
            else f"out_{_identifier(interface['id'])}"
        )
        variable_names[interface["id"]] = variable
        target_kind, target_id, target_path = _interface_target(
            interface, entity_paths, joint_paths, sensor_paths
        )
        mappings.append({
            "id": f"map_{interface['id']}",
            "interface_id": interface["id"],
            "state_id": interface["state_id"],
            "direction": direction,
            "quantity": interface["quantity"],
            "fmu_variable": variable,
            "source_unit": interface["source_unit"],
            "target_unit": interface.get("target_unit", interface["source_unit"]),
            "target_kind": target_kind,
            "target_id": target_id,
            "usd_prim_path": target_path,
            "required": interface.get("required", True),
            "verification_status": "declared_unresolved",
        })

    assessment = capability_report(ir)
    contract = {
        "schema_version": "1.0",
        "contract_kind": "capability_tiered",
        "task_id": task_id,
        "execution_mode": "capability_tiered",
        "clock": deepcopy(ir.get("clock")),
        "mappings": mappings,
        "capabilities": assessment,
        "grounding": {
            "policy": "grounded_or_explicitly_unresolved",
            "declared_assumptions": deepcopy(ir["assumptions"]),
            "declared_unknowns": deepcopy(ir["unknowns"]),
            "artifact_grounding_status": "requires_cross_artifact_validation",
        },
        "verification_ceiling": "artifacts_validated",
        "claim_eligible_h2": False,
    }
    identifiers = {
        "world_prim": "/World",
        "modelica_model": model_name,
        "entity_prim_paths": entity_paths,
        "joint_prim_paths": joint_paths,
        "sensor_prim_paths": sensor_paths,
        "interface_fmu_variables": variable_names,
    }
    return CapabilityPlan(
        task_id=task_id,
        model_name=model_name,
        requirement_ir=ir,
        contract=contract,
        identifiers=identifiers,
        modelica_requirement=_modelica_requirement(ir, contract, model_name),
        openusd_requirement=_openusd_requirement(ir, contract, identifiers),
    )


def _interface_target(interface: dict, entity_paths: dict[str, str],
                      joint_paths: dict[str, str],
                      sensor_paths: dict[str, str]) -> tuple[str, str | None, str | None]:
    for key, kind, paths in (
        ("joint_id", "joint", joint_paths),
        ("entity_id", "entity", entity_paths),
        ("sensor_id", "sensor", sensor_paths),
    ):
        target_id = interface.get(key)
        if isinstance(target_id, str):
            return kind, target_id, paths.get(target_id)
    return "system", None, "/World"


def _modelica_requirement(ir: dict, contract: dict, model_name: str) -> str:
    interface_lines = []
    for row in contract["mappings"]:
        causality = "input" if row["direction"] == "usd_to_fmu" else "output"
        unit = (row["target_unit"] if causality == "input" else row["source_unit"])
        interface_lines.append(
            f"- Declare {causality} Real {row['fmu_variable']}"
            f"(unit=\"{unit}\") for {row['quantity']} ({row['state_id']})."
        )
    return f"""{ir['source_text']}

CAPABILITY-TIERED MODELICA/FMI OBLIGATIONS
- Return one self-contained top-level model named {model_name}.
- Implement the dynamic, control, actuator, sensing/estimation, trajectory, and
  hybrid behavior explicitly grounded in the IR. Do not invent omitted numeric
  parameters; leave omitted behavior explicitly unresolved when it cannot be
  implemented without them.
- Treat retrieved examples only as syntax and modeling-pattern references; they
  are never evidence for a numeric value, component, transform, or behavior.
- Do not mirror USD-owned geometry, mass, environment, pose, contact, or sensor
  implementation into Modelica unless an equation or declared FMU interface
  requires it. In particular, omit ungrounded obstacle dimensions, wheel mass,
  gravity, and absolute initial pose from the Modelica controller artifact.
- Never assign an arbitrary numeric default to an unknown physical value. If an
  unknown is indispensable, identify the omitted behavior with an
  `UNRESOLVED_ASSUMPTION` comment containing the exact unknown text. Do not
  declare an unbound parameter merely to make the omission look implemented;
  the top-level model must remain directly buildable and FMU-exportable.
- For an interface whose unit is `unspecified`, preserve the exact Real input
  and interface name but do not invent a scale, conversion factor, offset, or
  physical unit. Do not use that signal in unit-dependent arithmetic unless a
  separate compatible grounded interface supplies the needed quantity.
- Use Modelica Standard Library components when suitable and keep the model
  directly checkable by OpenModelica. Exportability as a Co-Simulation FMU is
  preferred when the requested semantics permit it.
{chr(10).join(interface_lines) if interface_lines else '- No cross-profile signal interface was grounded.'}
- Modelica owns equations, controller state, actuator dynamics, estimators, and
  abstract plant dynamics assigned to it. It must not duplicate rigid-body state
  explicitly assigned to USD physics.
- This is the broad artifact profile. Successful compilation does not by itself
  claim closed-loop physics execution or CUDA provenance.

GROUNDED REQUIREMENT IR
{json.dumps(ir, indent=2, sort_keys=True)}
"""


def _openusd_requirement(ir: dict, contract: dict, identifiers: dict) -> str:
    entity_lines = [
        f"- {row['kind']} {row['id']} at {identifiers['entity_prim_paths'][row['id']]}"
        + (f", shape {row['shape']}" if row.get("shape") else "")
        + (f", mass {row['mass']} {row.get('mass_unit', 'kg')}" if row.get("mass") is not None else "")
        + "."
        for row in ir["entities"]
    ]
    joint_lines = [
        f"- {row['type']} joint {row['id']} at {identifiers['joint_prim_paths'][row['id']]}, "
        f"body0 {identifiers['entity_prim_paths'].get(row['parent'])}, "
        f"body1 {identifiers['entity_prim_paths'].get(row['child'])}"
        + (f", axis {row['axis']}" if row.get("axis") else "")
        + "."
        for row in ir["joints"]
    ]
    sensor_lines = [
        f"- {row['kind']} sensor {row['id']} at {identifiers['sensor_prim_paths'][row['id']]}."
        for row in ir["sensors"]
    ]
    return f"""{ir['source_text']}

CAPABILITY-TIERED OPENUSD/USD PHYSICS OBLIGATIONS
- Return one self-contained USDA stage rooted at /World using portable OpenUSD
  and UsdPhysics schemas wherever the requested feature has a standard schema.
- Preserve topology, transforms, geometry, collision, mass/inertia, materials,
  environments, joints, drives, sensors, and semantic paths grounded in the IR.
- Treat retrieved examples only as syntax and schema-pattern references; they
  are never evidence for a numeric value, component, transform, or behavior.
- Never author an unstated numeric physical value, including a default mass,
  inertia, dimension, transform, joint limit, gravity, friction, restitution,
  drive gain, or sensor rate. Omit the corresponding physical attribute/API
  when portable USD permits omission.
- When a requested object cannot have concrete geometry or physics without an
  omitted value, preserve it as a semantic Xform placeholder instead of making
  up dimensions. Mark it with `custom bool robotics:placeholder = true` and a
  `custom string[] robotics:unresolved` containing the exact matching unknowns.
  A placeholder must not claim collision, rigid-body, mass, or runtime support.
- Relative placement may choose the robot's initial reference as the world
  origin only as a coordinate-frame convention. If used, declare the convention
  in `custom string robotics:frameConvention`; do not present it as source fact.
- Use fixed, revolute, prismatic, spherical, distance, or configurable D6 joint
  schemas as appropriate. Represent a floating base explicitly rather than
  silently anchoring it. Preserve arbitrary joint frames through local rotations.
{chr(10).join(entity_lines + joint_lines + sensor_lines) if entity_lines or joint_lines or sensor_lines else '- No scene entities were grounded.'}
- If a sensor has no portable UsdPhysics schema, author its placement and typed
  metadata without claiming simulator-native sensor execution.
- Do not author fabricated trajectories or physics results. Artifact validation
  is distinct from closed-loop execution and accelerator evidence.

DECLARED UNRESOLVED FACTS
{json.dumps(ir['unknowns'], indent=2, sort_keys=True)}

DECLARED CROSS-PROFILE MAPPINGS
{json.dumps(contract['mappings'], indent=2, sort_keys=True)}

GROUNDED REQUIREMENT IR
{json.dumps(ir, indent=2, sort_keys=True)}
"""


def _identifier(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_]", "_", value)
    cleaned = re.sub(r"_+", "_", cleaned).strip("_") or "artifact"
    return f"R_{cleaned}" if cleaned[0].isdigit() else cleaned


def _usd_identifier(value: str) -> str:
    return _identifier(value)
