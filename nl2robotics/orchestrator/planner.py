"""Derive frozen cross-profile interfaces from grounded requirement facts."""

from __future__ import annotations

from copy import deepcopy
from dataclasses import asdict, dataclass
import json
import math
import re

from nl2robotics.contracts.requirement_ir import (
    is_closed_loop_mode,
    validate_requirement_ir,
)
from nl2robotics.contracts.articulated_profile import (
    SUPPORTED_CONTROLLER_KINDS,
    SUPPORTED_JOINT_AXES,
    SUPPORTED_JOINT_TYPES,
    entity_shape,
    geometry_fields,
    joint_units,
)
from nl2robotics.contracts.units import UnitError, conversion


@dataclass(frozen=True)
class PlanIssue:
    code: str
    message: str
    path: str


class PlanningError(ValueError):
    def __init__(self, issues: list[PlanIssue]):
        self.issues = issues
        super().__init__("; ".join(f"{item.path}: {item.message}" for item in issues))

    def to_dict(self) -> dict:
        return {"issues": [asdict(item) for item in self.issues]}


@dataclass(frozen=True)
class H1Plan:
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
            "execution_mode": "portable_fmu_kinematic",
            "model_name": self.model_name,
            "identifiers": self.identifiers,
        }


@dataclass(frozen=True)
class H2Plan:
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
            "execution_mode": self.requirement_ir["execution_mode"],
            "model_name": self.model_name,
            "identifiers": self.identifiers,
        }


def build_plan(requirement_ir: dict) -> H1Plan | H2Plan:
    mode = requirement_ir.get("execution_mode")
    if mode == "portable_fmu_kinematic":
        return build_h1_plan(requirement_ir)
    if is_closed_loop_mode(mode):
        return build_h2_plan(requirement_ir)
    raise PlanningError([PlanIssue(
        "unsupported_mode", f"unsupported execution mode {mode!r}",
        "$.execution_mode",
    )])


def build_h1_plan(requirement_ir: dict) -> H1Plan:
    issues = _readiness_issues(requirement_ir)
    if issues:
        raise PlanningError(issues)

    ir = deepcopy(requirement_ir)
    for collection in (
        "entities", "joints", "parameters", "dynamics", "controllers",
        "actuators", "sensors", "environment", "interfaces", "properties",
    ):
        ir.setdefault(collection, [])
    ir.setdefault("assumptions", [])
    ir.setdefault("unknowns", [])
    task_id = ir["task_id"]
    model_name = f"RobotTask_{_modelica_identifier(task_id)}"
    entities = {item["id"]: item for item in ir["entities"]}
    joints = {item["id"]: item for item in ir["joints"]}
    interfaces = [item for item in ir["interfaces"] if item.get("required", True)]
    clock_fact = ir["clock"]
    frequency = float(clock_fact["frequency_hz"])
    clock = {
        "start_time": float(clock_fact["start_time"]),
        "stop_time": float(clock_fact["stop_time"]),
        "step_size": 1.0 / frequency,
        "time_codes_per_second": frequency,
    }

    entity_paths = {
        entity_id: f"/World/{_usd_identifier(entity_id)}" for entity_id in entities
    }
    joint_paths = {
        joint_id: f"/World/{_usd_identifier(joint_id)}" for joint_id in joints
    }
    mappings = []
    interface_names = {}
    for interface in interfaces:
        joint = joints[interface["joint_id"]]
        variable = f"out_{_modelica_identifier(interface['id'])}"
        interface_names[interface["id"]] = variable
        state_id = interface.get("state_id") or f"{joint['id']}.position"
        target_unit = "deg" if joint["type"] == "revolute" else "m"
        initial_value = float(interface.get("initial_value", 0.0))
        if "initial_value" not in interface:
            assumption = (
                f"Portable H1 profile defaulted {interface['id']} initial_value "
                "to 0 in source units because the request did not specify it."
            )
            if assumption not in ir["assumptions"]:
                ir["assumptions"].append(assumption)
        mappings.append({
            "id": f"map_{interface['id']}",
            "interface_id": interface["id"],
            "state_id": state_id,
            "semantic_joint_id": joint["id"],
            "semantic_parent_entity_id": joint["parent"],
            "semantic_child_entity_id": joint["child"],
            "owner": "fmu_plant",
            "direction": "fmu_to_usd",
            "fmu_variable": variable,
            "source_unit": interface["source_unit"],
            "usd_joint_path": joint_paths[joint["id"]],
            "usd_parent_prim": entity_paths[joint["parent"]],
            "usd_driven_prim": entity_paths[joint["child"]],
            "usd_quantity": "joint_position",
            "target_unit": target_unit,
            "axis": joint["axis"],
            "interpolation": "linear",
            "numeric_tolerance": 1e-5 if joint["type"] == "revolute" else 1e-6,
            "initial_value": initial_value,
        })
        interface["state_id"] = state_id
        interface["fmu_variable"] = variable
        interface["usd_joint_path"] = joint_paths[joint["id"]]

    owned_states = []
    seen_states = set()
    for dynamics in ir["dynamics"]:
        for state_id in dynamics.get("states", []):
            if state_id not in seen_states:
                seen_states.add(state_id)
                owned_states.append({
                    "state_id": state_id,
                    "kind": "physical",
                    "owner": "fmu_plant",
                })
    for mapping in mappings:
        if mapping["state_id"] not in seen_states:
            seen_states.add(mapping["state_id"])
            owned_states.append({
                "state_id": mapping["state_id"],
                "kind": "physical",
                "owner": "fmu_plant",
            })

    for prop in ir["properties"]:
        interface_id = prop.get("interface_id")
        if interface_id is None and len(interface_names) == 1:
            interface_id = next(iter(interface_names))
            prop["interface_id"] = interface_id
        prop["signal"] = interface_names[interface_id]

    contract = {
        "schema_version": "1.0",
        "task_id": task_id,
        "execution_mode": "portable_fmu_kinematic",
        "clock": clock,
        "state_ownership": owned_states,
        "mappings": mappings,
    }
    identifiers = {
        "world_prim": "/World",
        "modelica_model": model_name,
        "entity_prim_paths": entity_paths,
        "joint_prim_paths": joint_paths,
        "interface_fmu_variables": interface_names,
    }
    return H1Plan(
        task_id=task_id,
        model_name=model_name,
        requirement_ir=ir,
        contract=contract,
        identifiers=identifiers,
        modelica_requirement=_modelica_requirement(ir, contract, model_name),
        openusd_requirement=_openusd_requirement(ir, contract),
    )


def build_h2_plan(requirement_ir: dict) -> H2Plan:
    issues = _h2_readiness_issues(requirement_ir)
    if issues:
        raise PlanningError(issues)

    ir = deepcopy(requirement_ir)
    for collection in (
        "entities", "joints", "parameters", "dynamics", "controllers",
        "actuators", "sensors", "environment", "interfaces", "properties",
    ):
        ir.setdefault(collection, [])
    ir.setdefault("assumptions", [])
    ir.setdefault("unknowns", [])
    for assumption in (
        "The articulated H2 profile derives a deterministic collision-free rest "
        "layout from the grounded parent-child topology when joint frames are not "
        "specified by the request.",
        "The articulated H2 profile uses a 0.2 m fixed-base collision cube when "
        "the request does not specify base geometry.",
    ):
        if assumption not in ir["assumptions"]:
            ir["assumptions"].append(assumption)
    task_id = ir["task_id"]
    execution_mode = ir["execution_mode"]
    model_name = f"RobotTask_{_modelica_identifier(task_id)}_Controller"
    entities = {item["id"]: item for item in ir["entities"]}
    joints = {item["id"]: item for item in ir["joints"]}
    entity_paths = {
        entity_id: f"/World/{_usd_identifier(entity_id)}" for entity_id in entities
    }
    joint_paths = {
        joint_id: f"/World/{_usd_identifier(joint_id)}" for joint_id in joints
    }
    frequency = float(ir["clock"]["frequency_hz"])
    clock = {
        "start_time": float(ir["clock"]["start_time"]),
        "stop_time": float(ir["clock"]["stop_time"]),
        "step_size": 1.0 / frequency,
        "time_codes_per_second": frequency,
    }
    coupling = {
        "algorithm": "sampled_data_sequential",
        "hold": "zero_order",
        "observation_phase": "step_start",
        "command_phase": "before_physics_step",
        "physics_substeps": int(ir["clock"]["physics_substeps"]),
    }

    mappings = []
    interface_names = {}
    owners: dict[str, dict] = {}
    effort_limits = {
        item["joint_id"]: conversion(
            str(item["unit"]),
            joint_units(joints[item["joint_id"]]["type"]).effort,
        ).apply(float(item["value"]))
        for item in ir["parameters"]
        if item.get("quantity") == "effort_limit"
    }
    for dynamics in ir["dynamics"]:
        for state_id in dynamics["states"]:
            owners[state_id] = {
                "state_id": state_id, "kind": "physical", "owner": "usd_physics"
            }
    for interface in ir["interfaces"]:
        if not interface.get("required", True):
            continue
        joint = joints[interface["joint_id"]]
        direction = interface["direction"]
        prefix = "in" if direction == "usd_to_fmu" else "out"
        variable = f"{prefix}_{_modelica_identifier(interface['id'])}"
        interface_names[interface["id"]] = variable
        state_id = interface["state_id"]
        owner = "usd_physics" if direction == "usd_to_fmu" else "fmu_controller"
        kind = "physical" if direction == "usd_to_fmu" else "control"
        owners.setdefault(state_id, {
            "state_id": state_id, "kind": kind, "owner": owner,
        })
        initial_value = interface.get("initial_value")
        if direction == "usd_to_fmu" and initial_value is None:
            initial_value = 0.0
            assumption = (
                f"H2 protocol defaulted {interface['id']} initial_value to 0 in "
                "simulator units because the request did not specify initial state."
            )
            if assumption not in ir["assumptions"]:
                ir["assumptions"].append(assumption)
        mapping = {
            "id": f"map_{interface['id']}",
            "interface_id": interface["id"],
            "state_id": state_id,
            "semantic_joint_id": joint["id"],
            "semantic_parent_entity_id": joint["parent"],
            "semantic_child_entity_id": joint["child"],
            "owner": owner,
            "direction": direction,
            "fmu_variable": variable,
            "source_unit": interface["source_unit"],
            "usd_joint_path": joint_paths[joint["id"]],
            "usd_parent_prim": entity_paths[joint["parent"]],
            "usd_driven_prim": entity_paths[joint["child"]],
            "usd_quantity": interface["quantity"],
            "target_unit": interface["target_unit"],
            "axis": joint["axis"],
            "interpolation": "sample" if direction == "usd_to_fmu" else "zero_order",
            "numeric_tolerance": 1e-6,
        }
        if initial_value is not None:
            mapping["initial_value"] = float(initial_value)
        if direction == "fmu_to_usd" and interface["quantity"] == "joint_effort":
            limit = effort_limits[joint["id"]]
            mapping["command_lower"] = -limit
            mapping["command_upper"] = limit
        mappings.append(mapping)
        interface["fmu_variable"] = variable
        interface["usd_joint_path"] = joint_paths[joint["id"]]

    contract = {
        "schema_version": "1.0",
        "task_id": task_id,
        "execution_mode": execution_mode,
        "clock": clock,
        "coupling": coupling,
        "state_ownership": list(owners.values()),
        "mappings": mappings,
    }
    identifiers = {
        "world_prim": "/World",
        "articulation_root": "/World/WorldAnchor",
        "modelica_model": model_name,
        "entity_prim_paths": entity_paths,
        "joint_prim_paths": joint_paths,
        "interface_fmu_variables": interface_names,
    }
    return H2Plan(
        task_id=task_id,
        model_name=model_name,
        requirement_ir=ir,
        contract=contract,
        identifiers=identifiers,
        modelica_requirement=_h2_modelica_requirement(ir, contract, model_name),
        openusd_requirement=_h2_openusd_requirement(ir, contract),
    )


def _readiness_issues(ir: dict) -> list[PlanIssue]:
    validation = validate_requirement_ir(ir)
    issues = [PlanIssue(item.code, item.message, item.path)
              for item in validation.issues]
    if ir.get("execution_mode") != "portable_fmu_kinematic":
        issues.append(PlanIssue(
            "unsupported_mode", "the unified MVP currently supports portable H1",
            "$.execution_mode",
        ))
    if not isinstance(ir.get("clock"), dict):
        issues.append(PlanIssue(
            "missing_clock", "H1 requires grounded start, stop, and frequency facts",
            "$.clock",
        ))
    else:
        for key in ("start_time", "stop_time", "frequency_hz"):
            value = ir["clock"].get(key)
            if isinstance(value, (int, float)) and not math.isfinite(float(value)):
                issues.append(PlanIssue(
                    "non_finite_clock", f"clock {key} must be finite", f"$.clock.{key}"
                ))
    joints = {item.get("id"): item for item in ir.get("joints", [])
              if isinstance(item, dict)}
    entities = {item.get("id"): item for item in ir.get("entities", [])
                if isinstance(item, dict)}
    dynamics = [item for item in ir.get("dynamics", []) if isinstance(item, dict)]
    parameters = [item for item in ir.get("parameters", []) if isinstance(item, dict)]
    declared_states = {
        state for item in dynamics for state in item.get("states", [])
        if isinstance(state, str)
    }
    if not dynamics:
        issues.append(PlanIssue(
            "missing_dynamics", "H1 requires a Modelica-owned dynamics record",
            "$.dynamics",
        ))
    for index, item in enumerate(dynamics):
        if item.get("owner") != "fmu_plant":
            issues.append(PlanIssue(
                "invalid_state_owner", "portable H1 dynamics must be owned by fmu_plant",
                f"$.dynamics[{index}].owner",
            ))
    for index, item in enumerate(parameters):
        path = f"$.parameters[{index}]"
        if item.get("owner") != "fmu_plant":
            issues.append(PlanIssue(
                "invalid_parameter_owner",
                "portable H1 dynamic parameters must be owned by fmu_plant",
                f"{path}.owner",
            ))
        value = item.get("value")
        if (not isinstance(value, (int, float))
                or not math.isfinite(float(value))):
            issues.append(PlanIssue(
                "invalid_parameter_value", "parameter value must be finite and numeric",
                f"{path}.value",
            ))
        if not isinstance(item.get("unit"), str) or not item["unit"].strip():
            issues.append(PlanIssue(
                "missing_parameter_unit", "parameter unit must be explicit",
                f"{path}.unit",
            ))
    required = [item for item in ir.get("interfaces", [])
                if isinstance(item, dict) and item.get("required", True)]
    if not required:
        issues.append(PlanIssue(
            "missing_interface", "H1 requires at least one FMU-to-USD interface",
            "$.interfaces",
        ))
    used_names: set[str] = set()
    used_paths: set[str] = set()
    for index, interface in enumerate(required):
        path = f"$.interfaces[{index}]"
        joint = joints.get(interface.get("joint_id"))
        if interface.get("direction") != "fmu_to_usd":
            issues.append(PlanIssue(
                "unsupported_direction", "portable H1 supports fmu_to_usd only",
                f"{path}.direction",
            ))
        if interface.get("quantity") != "joint_position":
            issues.append(PlanIssue(
                "unsupported_quantity", "portable H1 supports joint_position only",
                f"{path}.quantity",
            ))
        initial_value = interface.get("initial_value", 0.0)
        if (not isinstance(initial_value, (int, float))
                or not math.isfinite(float(initial_value))):
            issues.append(PlanIssue(
                "invalid_initial_value",
                "interface initial_value must be finite and numeric when supplied",
                f"{path}.initial_value",
            ))
        if joint is None:
            continue
        state_id = interface.get("state_id") or f"{joint.get('id')}.position"
        if state_id not in declared_states:
            issues.append(PlanIssue(
                "undeclared_interface_state",
                f"mapped state {state_id!r} is absent from the dynamics states",
                f"{path}.state_id",
            ))
        if joint.get("type") not in {"revolute", "prismatic"}:
            issues.append(PlanIssue(
                "unsupported_joint", "H1 supports revolute and prismatic joints",
                f"$.joints[{interface.get('joint_id')}]",
            ))
            continue
        if joint.get("axis") not in {"X", "Y", "Z"}:
            issues.append(PlanIssue(
                "unsupported_axis", "H1 supports principal X, Y, or Z axes",
                f"$.joints[{interface.get('joint_id')}].axis",
            ))
        for key in ("lower_limit", "upper_limit", "limit_unit"):
            if joint.get(key) is None:
                issues.append(PlanIssue(
                    "missing_joint_limit",
                    f"portable benchmark joint requires grounded {key}",
                    f"$.joints[{interface.get('joint_id')}].{key}",
                ))
        limits = (joint.get("lower_limit"), joint.get("upper_limit"))
        if any(not isinstance(value, (int, float))
               or not math.isfinite(float(value)) for value in limits):
            issues.append(PlanIssue(
                "invalid_joint_limit", "joint limits must be finite and numeric",
                f"$.joints[{interface.get('joint_id')}]",
            ))
        elif float(limits[0]) > float(limits[1]):
            issues.append(PlanIssue(
                "reversed_joint_limits", "joint lower limit exceeds upper limit",
                f"$.joints[{interface.get('joint_id')}]",
            ))
        child = entities.get(joint.get("child"), {})
        if child.get("mass") is None or child.get("mass_unit") is None:
            issues.append(PlanIssue(
                "missing_body_mass",
                "the driven body requires a grounded mass and mass unit",
                f"$.entities[{joint.get('child')}].mass",
            ))
        else:
            if (not isinstance(child["mass"], (int, float))
                    or not math.isfinite(float(child["mass"]))
                    or float(child["mass"]) <= 0):
                issues.append(PlanIssue(
                    "invalid_body_mass", "driven body mass must be finite and positive",
                    f"$.entities[{joint.get('child')}].mass",
                ))
            try:
                conversion(str(child["mass_unit"]), "kg")
            except UnitError as exc:
                issues.append(PlanIssue(
                    "body_mass_unit_mismatch", str(exc),
                    f"$.entities[{joint.get('child')}].mass_unit",
                ))
        target = "deg" if joint.get("type") == "revolute" else "m"
        try:
            conversion(str(interface.get("source_unit")), target)
        except UnitError as exc:
            issues.append(PlanIssue("unit_mismatch", str(exc), f"{path}.source_unit"))
        variable = f"out_{_modelica_identifier(str(interface.get('id', '')))}"
        joint_path = f"/World/{_usd_identifier(str(joint.get('id', '')))}"
        if variable in used_names:
            issues.append(PlanIssue(
                "identifier_collision", f"duplicate derived FMU name {variable!r}", path
            ))
        if joint_path in used_paths:
            issues.append(PlanIssue(
                "identifier_collision", f"duplicate derived USD path {joint_path!r}", path
            ))
        used_names.add(variable)
        used_paths.add(joint_path)

    interface_ids = {item.get("id") for item in required}
    for index, prop in enumerate(ir.get("properties", [])):
        interface_id = prop.get("interface_id")
        if interface_id is None and len(interface_ids) != 1:
            issues.append(PlanIssue(
                "ambiguous_property_signal",
                "property must name interface_id when multiple interfaces exist",
                f"$.properties[{index}].interface_id",
            ))
        elif interface_id is not None and interface_id not in interface_ids:
            issues.append(PlanIssue(
                "unknown_property_interface",
                f"property references unknown required interface {interface_id!r}",
                f"$.properties[{index}].interface_id",
            ))
        if prop.get("kind") not in {"always", "eventually", "final"}:
            issues.append(PlanIssue(
                "unsupported_property_kind",
                "property kind must be always, eventually, or final",
                f"$.properties[{index}].kind",
            ))
        bounds = [prop.get(key) for key in ("lower", "upper") if key in prop]
        if not bounds:
            issues.append(PlanIssue(
                "missing_property_bound", "property requires lower and/or upper",
                f"$.properties[{index}]",
            ))
        elif any(not isinstance(value, (int, float))
                 or not math.isfinite(float(value)) for value in bounds):
            issues.append(PlanIssue(
                "invalid_property_bound", "property bounds must be finite numbers",
                f"$.properties[{index}]",
            ))
        if (isinstance(prop.get("lower"), (int, float))
                and isinstance(prop.get("upper"), (int, float))
                and float(prop["lower"]) > float(prop["upper"])):
            issues.append(PlanIssue(
                "reversed_property_bounds", "property lower bound exceeds upper bound",
                f"$.properties[{index}]",
            ))
    return issues


def _h2_readiness_issues(ir: dict) -> list[PlanIssue]:
    validation = validate_requirement_ir(ir)
    issues = [PlanIssue(item.code, item.message, item.path)
              for item in validation.issues]
    if not is_closed_loop_mode(ir.get("execution_mode")):
        issues.append(PlanIssue(
            "unsupported_mode", "H2 planning requires a closed-loop mode",
            "$.execution_mode",
        ))
    clock = ir.get("clock")
    if not isinstance(clock, dict):
        issues.append(PlanIssue(
            "missing_clock", "H2 requires a grounded communication clock", "$.clock"
        ))
    else:
        for key in ("start_time", "stop_time", "frequency_hz"):
            if not _finite_number(clock.get(key)):
                issues.append(PlanIssue(
                    "invalid_clock_value", f"H2 clock {key} must be finite",
                    f"$.clock.{key}",
                ))
        substeps = clock.get("physics_substeps")
        if (not isinstance(substeps, int) or isinstance(substeps, bool)
                or substeps < 1):
            issues.append(PlanIssue(
                "missing_physics_substeps",
                "H2 requires a grounded positive physics_substeps value",
                "$.clock.physics_substeps",
            ))
        if (all(_finite_number(clock.get(key)) for key in (
                "start_time", "stop_time", "frequency_hz"))
                and float(clock["frequency_hz"]) > 0
                and float(clock["stop_time"]) > float(clock["start_time"])):
            step_count = (
                (float(clock["stop_time"]) - float(clock["start_time"]))
                * float(clock["frequency_hz"])
            )
            if (step_count <= 0
                    or not math.isclose(step_count, round(step_count),
                                        rel_tol=0.0, abs_tol=1e-9)):
                issues.append(PlanIssue(
                    "fractional_final_step",
                    "H2 duration must contain an integer number of communication steps",
                    "$.clock",
                ))

    entities = {item.get("id"): item for item in ir.get("entities", [])
                if isinstance(item, dict)}
    joints = {item.get("id"): item for item in ir.get("joints", [])
              if isinstance(item, dict)}
    dynamics = [item for item in ir.get("dynamics", []) if isinstance(item, dict)]
    controllers = [item for item in ir.get("controllers", []) if isinstance(item, dict)]
    actuators = [item for item in ir.get("actuators", []) if isinstance(item, dict)]

    if not dynamics or any(
            item.get("owner") != "usd_physics" for item in dynamics):
        issues.append(PlanIssue(
            "invalid_h2_dynamics_owner",
            "H2 requires one or more dynamics records owned by usd_physics",
            "$.dynamics",
        ))
    if not controllers:
        issues.append(PlanIssue(
            "missing_h2_controller",
            "H2 requires at least one grounded fmu_controller",
            "$.controllers",
        ))
    for index, controller in enumerate(controllers):
        if (controller.get("owner") != "fmu_controller"
                or str(controller.get("kind", "")).upper()
                not in SUPPORTED_CONTROLLER_KINDS):
            issues.append(PlanIssue(
                "unsupported_h2_controller",
                "the executable articulated profile supports fmu_controller PD laws",
                f"$.controllers[{index}]",
            ))

    actuator_joints: set[object] = set()
    for index, actuator in enumerate(actuators):
        joint_id = actuator.get("joint_id")
        if (actuator.get("owner") != "fmu_controller"
                or actuator.get("command") != "joint_effort"):
            issues.append(PlanIssue(
                "invalid_fmu_actuator",
                "H2 actuators must be fmu_controller joint_effort actuators",
                f"$.actuators[{index}]",
            ))
        if joint_id in actuator_joints:
            issues.append(PlanIssue(
                "duplicate_joint_actuator",
                f"joint {joint_id!r} has multiple effort actuators",
                f"$.actuators[{index}]",
            ))
        actuator_joints.add(joint_id)
    if not actuators:
        issues.append(PlanIssue(
            "missing_fmu_actuator",
            "H2 requires at least one grounded joint_effort actuator",
            "$.actuators",
        ))
    issues.extend(_controller_assignment_issues(controllers, actuator_joints))

    required = [item for item in ir.get("interfaces", [])
                if isinstance(item, dict) and item.get("required", True)]
    commands = [item for item in required if item.get("direction") == "fmu_to_usd"]
    feedback = [item for item in required if item.get("direction") == "usd_to_fmu"]
    if not commands or not feedback:
        issues.append(PlanIssue(
            "open_loop_interface",
            "H2 requires at least one observation and one command interface",
            "$.interfaces",
        ))

    command_joints = {item.get("joint_id") for item in commands}
    if command_joints != actuator_joints:
        issues.append(PlanIssue(
            "actuator_interface_mismatch",
            "actuator joints and command-interface joints must match exactly",
            "$.actuators",
        ))
    grouped_interfaces: dict[tuple[object, object, object], list[dict]] = {}
    for interface in required:
        key = (interface.get("joint_id"), interface.get("direction"),
               interface.get("quantity"))
        grouped_interfaces.setdefault(key, []).append(interface)
    for key, rows in grouped_interfaces.items():
        if len(rows) > 1:
            issues.append(PlanIssue(
                "duplicate_h2_interface",
                f"multiple required interfaces have joint/direction/quantity {key}",
                "$.interfaces",
            ))
    for joint_id in joints:
        for quantity in ("joint_position", "joint_velocity"):
            if len(grouped_interfaces.get(
                    (joint_id, "usd_to_fmu", quantity), [])) != 1:
                issues.append(PlanIssue(
                    "incomplete_h2_feedback",
                    f"joint {joint_id!r} requires exactly one {quantity} observation",
                    "$.interfaces",
                ))
        expected_commands = 1 if joint_id in actuator_joints else 0
        if len(grouped_interfaces.get(
                (joint_id, "fmu_to_usd", "joint_effort"), [])) != expected_commands:
            issues.append(PlanIssue(
                "unsupported_h2_command",
                f"joint {joint_id!r} requires {expected_commands} joint_effort command",
                "$.interfaces",
            ))
    if any(item.get("quantity") != "joint_effort" for item in commands):
        issues.append(PlanIssue(
            "unsupported_h2_command",
            "closed-loop commands must use joint_effort",
            "$.interfaces",
        ))
    feedback_states = {item.get("state_id") for item in feedback}
    dynamics_states = {
        state for item in dynamics for state in item.get("states", [])
        if isinstance(state, str)
    }
    if feedback_states != dynamics_states:
        issues.append(PlanIssue(
            "h2_state_interface_mismatch",
            "USD dynamics states must exactly match controller feedback states",
            "$.dynamics",
        ))

    for joint_id, joint in joints.items():
        path = f"$.joints[{joint_id}]"
        if (joint.get("type") not in SUPPORTED_JOINT_TYPES
                or joint.get("axis") not in SUPPORTED_JOINT_AXES):
            issues.append(PlanIssue(
                "unsupported_h2_joint",
                "H2 supports revolute or prismatic joints on principal X/Y/Z axes",
                path,
            ))
            continue
        units = joint_units(str(joint["type"]))
        limits = (joint.get("lower_limit"), joint.get("upper_limit"))
        if not all(_finite_number(value) for value in limits):
            issues.append(PlanIssue(
                "missing_joint_limits", "H2 joints require finite grounded limits", path
            ))
        elif float(limits[0]) > float(limits[1]):
            issues.append(PlanIssue(
                "reversed_joint_limits", "joint lower limit exceeds upper limit", path
            ))
        try:
            conversion(str(joint.get("limit_unit")), units.position)
        except UnitError as exc:
            issues.append(PlanIssue(
                "invalid_joint_limit_unit", str(exc), f"{path}.limit_unit"
            ))
        child = entities.get(joint.get("child"), {})
        try:
            mass = conversion(str(child.get("mass_unit")), "kg").apply(
                float(child.get("mass"))
            )
        except (TypeError, ValueError, UnitError) as exc:
            issues.append(PlanIssue(
                "missing_dynamic_body_mass", str(exc),
                f"$.entities[{joint.get('child')}].mass",
            ))
        else:
            if mass <= 0:
                issues.append(PlanIssue(
                    "missing_dynamic_body_mass",
                    "H2 dynamic links require positive mass",
                    f"$.entities[{joint.get('child')}].mass",
                ))
        shape = entity_shape(child)
        fields = geometry_fields(shape)
        if not fields:
            issues.append(PlanIssue(
                "unsupported_collision_geometry",
                f"unsupported rigid-link shape {shape!r}",
                f"$.entities[{joint.get('child')}].shape",
            ))
        try:
            dimensions = [
                conversion(str(child.get("dimension_unit")), "m").apply(
                    float(child.get(field))
                )
                for field in fields
            ]
        except (TypeError, ValueError, UnitError) as exc:
            issues.append(PlanIssue(
                "missing_collision_geometry", str(exc),
                f"$.entities[{joint.get('child')}].{fields[0] if fields else 'shape'}",
            ))
        else:
            if any(value <= 0 for value in dimensions):
                issues.append(PlanIssue(
                    "missing_collision_geometry",
                    f"H2 {shape} dimensions must be positive",
                    f"$.entities[{joint.get('child')}].{fields[0]}",
                ))

    parameters_by_joint: dict[object, dict[object, dict]] = {}
    for index, parameter in enumerate(ir.get("parameters", [])):
        if parameter.get("owner") != "fmu_controller":
            issues.append(PlanIssue(
                "invalid_h2_parameter_owner",
                "H2 controller parameters must be owned by fmu_controller",
                f"$.parameters[{index}].owner",
            ))
        joint_parameters = parameters_by_joint.setdefault(parameter.get("joint_id"), {})
        quantity = parameter.get("quantity")
        if quantity in joint_parameters:
            issues.append(PlanIssue(
                "duplicate_h2_parameter",
                f"H2 has multiple {quantity!r} parameters for one joint",
                f"$.parameters[{index}]",
            ))
        else:
            joint_parameters[quantity] = parameter
    for joint_id in actuator_joints & joints.keys():
        units = joint_units(str(joints[joint_id]["type"]))
        required_parameter_units = {
            "proportional_gain": units.proportional_gain,
            "derivative_gain": units.derivative_gain,
            "target_position": units.position,
            "effort_limit": units.effort,
        }
        joint_parameters = parameters_by_joint.get(joint_id, {})
        missing = required_parameter_units.keys() - joint_parameters.keys()
        if missing:
            issues.append(PlanIssue(
                "missing_pd_parameters",
                f"H2 PD controller for {joint_id!r} is missing {sorted(missing)}",
                "$.parameters",
            ))
            continue
        for quantity, target_unit in required_parameter_units.items():
            parameter = joint_parameters[quantity]
            try:
                conversion(str(parameter.get("unit")), target_unit)
            except UnitError as exc:
                issues.append(PlanIssue(
                    "invalid_pd_parameter_unit", str(exc),
                    f"$.parameters[{parameter.get('id')}].unit",
                ))
        effort_limit = joint_parameters["effort_limit"].get("value")
        kp = joint_parameters["proportional_gain"].get("value")
        kd = joint_parameters["derivative_gain"].get("value")
        if not _finite_number(effort_limit) or float(effort_limit) <= 0:
            issues.append(PlanIssue(
                "invalid_effort_limit", "H2 effort_limit must be positive",
                f"$.parameters[{joint_parameters['effort_limit'].get('id')}].value",
            ))
        if not _finite_number(kp) or float(kp) <= 0:
            issues.append(PlanIssue(
                "invalid_proportional_gain", "H2 proportional gain must be positive",
                f"$.parameters[{joint_parameters['proportional_gain'].get('id')}].value",
            ))
        if not _finite_number(kd) or float(kd) < 0:
            issues.append(PlanIssue(
                "invalid_derivative_gain", "H2 derivative gain must be non-negative",
                f"$.parameters[{joint_parameters['derivative_gain'].get('id')}].value",
            ))
        joint = joints[joint_id]
        try:
            target = conversion(
                str(joint_parameters["target_position"].get("unit")),
                str(joint.get("limit_unit")),
            ).apply(float(joint_parameters["target_position"].get("value")))
            lower = float(joint.get("lower_limit"))
            upper = float(joint.get("upper_limit"))
        except (TypeError, ValueError, UnitError):
            pass
        else:
            if target < lower or target > upper:
                issues.append(PlanIssue(
                    "unreachable_h2_target",
                    f"controller target {target} lies outside joint limits "
                    f"[{lower}, {upper}] {joint.get('limit_unit')}",
                    f"$.parameters[{joint_parameters['target_position'].get('id')}].value",
                ))
    for index, interface in enumerate(required):
        path = f"$.interfaces[{index}]"
        if interface.get("joint_id") not in joints:
            continue
        joint = joints[interface["joint_id"]]
        units = joint_units(str(joint["type"]))
        if not isinstance(interface.get("target_unit"), str):
            issues.append(PlanIssue(
                "missing_target_unit", "H2 interfaces require explicit target_unit",
                f"{path}.target_unit",
            ))
        try:
            conversion(str(interface.get("source_unit")), str(interface.get("target_unit")))
        except UnitError as exc:
            issues.append(PlanIssue("unit_mismatch", str(exc), f"{path}.source_unit"))
        simulator_unit = (
            interface.get("source_unit")
            if interface.get("direction") == "usd_to_fmu"
            else interface.get("target_unit")
        )
        expected_unit = {
            "joint_position": units.position,
            "joint_velocity": units.velocity,
            "joint_effort": units.effort,
        }.get(interface.get("quantity"))
        if expected_unit is not None and str(simulator_unit) != expected_unit:
            issues.append(PlanIssue(
                "invalid_h2_simulator_unit",
                f"{joint['type']} {interface.get('quantity')} must use "
                f"{expected_unit} at the simulator boundary",
                path,
            ))
        if (interface.get("direction") == "usd_to_fmu"
                and interface.get("quantity") == "joint_position"
                and _finite_number(interface.get("initial_value"))):
            joint = joints[interface["joint_id"]]
            try:
                initial = conversion(
                    str(interface.get("source_unit")), str(joint.get("limit_unit"))
                ).apply(float(interface["initial_value"]))
                lower = float(joint["lower_limit"])
                upper = float(joint["upper_limit"])
            except (KeyError, TypeError, ValueError, UnitError):
                pass
            else:
                if initial < lower or initial > upper:
                    issues.append(PlanIssue(
                        "invalid_h2_initial_position",
                        f"initial position {initial} lies outside joint limits "
                        f"[{lower}, {upper}] {joint.get('limit_unit')}",
                        f"{path}.initial_value",
                    ))
    observed = {
        item.get("id") for item in required if item.get("direction") == "usd_to_fmu"
    }
    if not ir.get("properties"):
        issues.append(PlanIssue(
            "missing_behavior_property",
            "claim-eligible H2 generation requires at least one grounded property",
            "$.properties",
        ))
    for index, prop in enumerate(ir.get("properties", [])):
        if prop.get("interface_id") not in observed:
            issues.append(PlanIssue(
                "unobservable_property",
                "H2 properties must reference a USD-to-FMU observation",
                f"$.properties[{index}].interface_id",
            ))
        interval_values_valid = all(
            key not in prop or _finite_number(prop.get(key))
            for key in ("start", "end")
        )
        if (isinstance(clock, dict) and interval_values_valid
                and all(_finite_number(clock.get(key)) for key in (
                    "start_time", "stop_time", "frequency_hz"))
                and float(clock["frequency_hz"]) > 0
                and float(clock["stop_time"]) > float(clock["start_time"])):
            simulation_start = float(clock["start_time"])
            simulation_stop = float(clock["stop_time"])
            step = 1.0 / float(clock["frequency_hz"])
            interval_start = float(prop.get("start", simulation_start + step))
            interval_end = float(prop.get("end", simulation_stop))
            first_index = max(
                1, math.ceil((interval_start - simulation_start) / step - 1e-9)
            )
            last_index = min(
                round((simulation_stop - simulation_start) / step),
                math.floor((interval_end - simulation_start) / step + 1e-9),
            )
            if first_index > last_index:
                issues.append(PlanIssue(
                    "empty_property_interval",
                    "property interval contains no closed-loop trace sample",
                    f"$.properties[{index}]",
                ))
    return issues


def _controller_assignment_issues(controllers: list[dict],
                                  actuator_joints: set[object]) -> list[PlanIssue]:
    issues: list[PlanIssue] = []
    assigned: set[object] = set()
    for index, controller in enumerate(controllers):
        references = controller.get("joint_ids")
        if references is None and controller.get("joint_id") is not None:
            references = [controller.get("joint_id")]
        if references is None:
            if len(controllers) == 1:
                references = sorted(actuator_joints, key=str)
            else:
                issues.append(PlanIssue(
                    "ambiguous_controller_assignment",
                    "multiple controllers must declare joint_ids",
                    f"$.controllers[{index}].joint_ids",
                ))
                continue
        if not isinstance(references, list):
            continue
        for joint_id in references:
            if joint_id not in actuator_joints:
                issues.append(PlanIssue(
                    "controller_actuator_mismatch",
                    f"controller references non-actuated joint {joint_id!r}",
                    f"$.controllers[{index}].joint_ids",
                ))
            if joint_id in assigned:
                issues.append(PlanIssue(
                    "duplicate_controller_assignment",
                    f"joint {joint_id!r} is assigned to multiple controllers",
                    f"$.controllers[{index}].joint_ids",
                ))
            assigned.add(joint_id)
    missing = sorted(actuator_joints - assigned, key=str)
    if missing:
        issues.append(PlanIssue(
            "unassigned_actuator_controller",
            f"actuated joints lack a controller assignment: {missing}",
            "$.controllers",
        ))
    return issues


def _h2_modelica_requirement(ir: dict, contract: dict, model_name: str) -> str:
    joints = {item["id"]: item for item in ir["joints"]}
    interface_lines = []
    for mapping in contract["mappings"]:
        causality = "input" if mapping["direction"] == "usd_to_fmu" else "output"
        fmu_unit = (
            mapping["target_unit"]
            if mapping["direction"] == "usd_to_fmu"
            else mapping["source_unit"]
        )
        interface_lines.append(
            f"- Declare {causality} Real {mapping['fmu_variable']}"
            f"(unit=\"{fmu_unit}\") for {mapping['state_id']}."
        )
    parameter_lines = []
    for item in ir["parameters"]:
        target_unit = _controller_parameter_unit(item, joints)
        value = float(item["value"])
        if str(item["unit"]) != target_unit:
            value = conversion(str(item["unit"]), target_unit).apply(value)
        parameter_lines.append(
            f"- Declare parameter Real {_modelica_identifier(item['id'])}"
            f"(unit=\"{target_unit}\") = {value:.17g}; this is the canonical "
            f"SI representation of {item['value']} {item['unit']}."
        )
    mappings = {
        (row["semantic_joint_id"], row["direction"], row["usd_quantity"]): row
        for row in contract["mappings"]
    }
    parameters = {
        (item.get("joint_id"), item.get("quantity")): item
        for item in ir["parameters"]
    }
    control_lines = []
    for actuator in ir["actuators"]:
        joint_id = actuator["joint_id"]
        position = mappings[(joint_id, "usd_to_fmu", "joint_position")]
        velocity = mappings[(joint_id, "usd_to_fmu", "joint_velocity")]
        effort = mappings[(joint_id, "fmu_to_usd", "joint_effort")]
        kp = _modelica_identifier(parameters[(joint_id, "proportional_gain")]["id"])
        kd = _modelica_identifier(parameters[(joint_id, "derivative_gain")]["id"])
        target = _modelica_identifier(parameters[(joint_id, "target_position")]["id"])
        limit = _modelica_identifier(parameters[(joint_id, "effort_limit")]["id"])
        control_lines.append(
            f"- Implement exactly {effort['fmu_variable']} = max(-{limit}, "
            f"min({limit}, {kp} * ({target} - {position['fmu_variable']}) - "
            f"{kd} * {velocity['fmu_variable']}))."
        )
    return f"""{ir['source_text']}

ARTICULATED H2 MODELICA/FMI CONTROLLER OBLIGATIONS
- Return exactly one self-contained top-level model named {model_name}.
- The model contains controller logic only; it must not reproduce the rigid-body
  plant dynamics owned by the selected OpenUSD physics backend.
- It must compile in OpenModelica and export as an FMI 2.0 Co-Simulation FMU.
{chr(10).join(interface_lines)}
{chr(10).join(parameter_lines)}
{chr(10).join(control_lines)}
- The per-joint equations are independent unless the grounded requirement says
  otherwise. Preserve every exact variable name, causality, SI boundary unit,
  parameter value, saturation, and control law above.

GROUNDED REQUIREMENT IR
{json.dumps(ir, indent=2, sort_keys=True)}
"""


def _h2_openusd_requirement(ir: dict, contract: dict) -> str:
    layout = _h2_layout(ir)
    entity_lines = []
    for entity in ir["entities"]:
        path = f"/World/{_usd_identifier(entity['id'])}"
        if entity["kind"] == "fixed_base":
            entity_lines.append(
                f"- Fixed base {entity['id']} at exact path {path}, world "
                f"translation {_format_vector(layout['entities'][entity['id']])}. "
                "If no source geometry is present, use a 0.2 m collision cube."
            )
        else:
            entity_lines.append(
                f"- Dynamic rigid link {entity['id']} at exact path {path}, mass "
                f"{entity['mass']} {entity['mass_unit']}, "
                f"{_geometry_description(entity)}, world translation "
                f"{_format_vector(layout['entities'][entity['id']])}. Apply "
                "PhysicsMassAPI and PhysicsRigidBodyAPI and set "
                "physics:kinematicEnabled=false."
            )
    joint_lines = []
    mappings_by_joint = {}
    for mapping in contract["mappings"]:
        mappings_by_joint.setdefault(mapping["semantic_joint_id"], mapping)
    for joint in ir["joints"]:
        mapping = mappings_by_joint[joint["id"]]
        joint_lines.append(
            f"- {joint['type']} joint {joint['id']} at exact path "
            f"{mapping['usd_joint_path']}, body0 {mapping['usd_parent_prim']}, "
            f"body1 {mapping['usd_driven_prim']}, axis {joint['axis']}, limits "
            f"{joint['lower_limit']} to {joint['upper_limit']} "
            f"{joint['limit_unit']}, physics:localPos0 "
            f"{_format_vector(layout['joints'][joint['id']]['local_pos0'])}, and "
            f"physics:localPos1 "
            f"{_format_vector(layout['joints'][joint['id']]['local_pos1'])}."
        )
    gravity_lines = [
        f"- Author one PhysicsScene with gravity magnitude {item['magnitude']} "
        f"{item['unit']}."
        for item in ir["environment"] if item.get("kind") == "gravity"
    ]
    rate = contract["clock"]["time_codes_per_second"]
    return f"""{ir['source_text']}

ARTICULATED H2 OPENUSD/USD PHYSICS OBLIGATIONS
- Return one self-contained USDA stage with default prim /World. Apply
  PhysicsArticulationRootAPI to the fixed world-anchor joint at exact path
  /World/WorldAnchor. Set metersPerUnit=1, kilogramsPerUnit=1, upAxis=Z, and
  timeCodesPerSecond={rate:g}.
{chr(10).join(entity_lines)}
{chr(10).join(joint_lines)}
{chr(10).join(gravity_lines)}
- Use portable OpenUSD/UsdPhysics core schemas for the plant. Include collision
  geometry. Fix the single fixed base to the world using the articulation-root
  joint. Author every listed body and joint; preserve the serial or branching
  topology exactly.
- The exact translations and joint frames above are a deterministic derived rest
  layout. Orient each box length or cylinder/capsule height along local Z. Joint
  local rotations are identity. These are disclosed layout assumptions, not NL
  facts.
- The FMU commands effort at runtime on actuated joints. Do not author a position
  or velocity drive on any effort-commanded joint, and do not author a prerecorded
  trajectory. Passive joints have no drive.

GROUNDED REQUIREMENT IR
{json.dumps(ir, indent=2, sort_keys=True)}
"""


def _controller_parameter_unit(parameter: dict, joints: dict[str, dict]) -> str:
    joint = joints.get(parameter.get("joint_id"))
    if joint is None:
        return str(parameter["unit"])
    units = joint_units(str(joint["type"]))
    return {
        "proportional_gain": units.proportional_gain,
        "derivative_gain": units.derivative_gain,
        "target_position": units.position,
        "effort_limit": units.effort,
    }.get(str(parameter.get("quantity")), str(parameter["unit"]))


def _h2_layout(ir: dict) -> dict:
    """Derive deterministic non-overlapping body translations and joint frames."""
    entities = {item["id"]: item for item in ir["entities"]}
    joints = {item["id"]: item for item in ir["joints"]}
    children: dict[str, list[dict]] = {}
    for joint in joints.values():
        children.setdefault(joint["parent"], []).append(joint)
    for rows in children.values():
        rows.sort(key=lambda item: item["id"])
    root = next(item["id"] for item in ir["entities"]
                if item["kind"] == "fixed_base")

    widths = [_entity_lateral_extent_m(item) for item in entities.values()
              if item.get("kind") == "rigid_link"]
    spacing = max([0.4, *(2.5 * value for value in widths)])
    leaf_order: list[str] = []

    def collect_leaves(entity_id: str) -> list[str]:
        rows = children.get(entity_id, [])
        if not rows:
            leaf_order.append(entity_id)
            return [entity_id]
        leaves = []
        for row in rows:
            leaves.extend(collect_leaves(row["child"]))
        return leaves

    collect_leaves(root)
    center = (len(leaf_order) - 1) / 2.0
    leaf_x = {
        entity_id: (index - center) * spacing
        for index, entity_id in enumerate(leaf_order)
    }

    def subtree_x(entity_id: str) -> float:
        rows = children.get(entity_id, [])
        if not rows:
            return leaf_x[entity_id]
        values = [subtree_x(row["child"]) for row in rows]
        return sum(values) / len(values)

    entity_positions: dict[str, tuple[float, float, float]] = {
        root: (subtree_x(root), 0.0, 0.0)
    }
    joint_frames: dict[str, dict[str, tuple[float, float, float]]] = {}

    def place(parent_id: str) -> None:
        parent_position = entity_positions[parent_id]
        parent = entities[parent_id]
        parent_half = (
            0.0 if parent.get("kind") == "fixed_base"
            else _entity_axial_extent_m(parent) / 2.0
        )
        for joint in children.get(parent_id, []):
            child_id = joint["child"]
            child_half = _entity_axial_extent_m(entities[child_id]) / 2.0
            child_x = subtree_x(child_id)
            pivot_z = parent_position[2] - parent_half
            entity_positions[child_id] = (
                child_x, parent_position[1], pivot_z - child_half
            )
            joint_frames[joint["id"]] = {
                "local_pos0": (
                    child_x - parent_position[0], 0.0, -parent_half
                ),
                "local_pos1": (0.0, 0.0, child_half),
            }
            place(child_id)

    place(root)
    return {"entities": entity_positions, "joints": joint_frames}


def _entity_axial_extent_m(entity: dict) -> float:
    unit = str(entity.get("dimension_unit", "m"))
    shape = entity_shape(entity)
    raw = (2.0 * float(entity["radius"]) if shape == "sphere"
           else float(entity["length"] if shape == "box" else entity["height"]))
    return conversion(unit, "m").apply(raw)


def _entity_lateral_extent_m(entity: dict) -> float:
    unit = str(entity.get("dimension_unit", "m"))
    shape = entity_shape(entity)
    if shape == "box":
        raw = max(float(entity["width"]), float(entity["depth"]))
    else:
        raw = 2.0 * float(entity["radius"])
    return conversion(unit, "m").apply(raw)


def _geometry_description(entity: dict) -> str:
    shape = entity_shape(entity)
    unit = entity["dimension_unit"]
    if shape == "box":
        return (f"box collision dimensions {entity['length']} x "
                f"{entity['width']} x {entity['depth']} {unit}")
    if shape == "sphere":
        return f"sphere collision radius {entity['radius']} {unit}"
    return (f"{shape} collision radius {entity['radius']} {unit} and height "
            f"{entity['height']} {unit}")


def _format_vector(values: tuple[float, float, float]) -> str:
    return "(" + ", ".join(f"{value:.9g}" for value in values) + ")"


def _finite_number(value: object) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _modelica_requirement(ir: dict, contract: dict, model_name: str) -> str:
    obligations = []
    for mapping in contract["mappings"]:
        obligations.append(
            f"- Declare output Real {mapping['fmu_variable']}(unit=\""
            f"{mapping['source_unit']}\") for semantic state {mapping['state_id']}."
        )
    return f"""{ir['source_text']}

FROZEN MODELICA/FMI PROFILE OBLIGATIONS
- Return exactly one self-contained top-level model named {model_name}.
- The model must be directly compilable by OpenModelica and exportable as an
  FMI 2.0 Co-Simulation FMU.
{chr(10).join(obligations)}
- Preserve these exact output identifiers and units; do not alias or rename them.
- Modelica owns every physical state and must provide deterministic initial values.

GROUNDED REQUIREMENT IR
{json.dumps(ir, indent=2, sort_keys=True)}
"""


def _openusd_requirement(ir: dict, contract: dict) -> str:
    entity_lines = []
    for entity in ir["entities"]:
        path = f"/World/{_usd_identifier(entity['id'])}"
        detail = f" at exact path {path}"
        if entity.get("mass") is not None:
            detail += f" with mass {entity['mass']} {entity.get('mass_unit', 'kg')}"
        entity_lines.append(f"- {entity['kind']} {entity['id']}{detail}.")
    joint_lines = []
    joints = {item["id"]: item for item in ir["joints"]}
    for mapping in contract["mappings"]:
        joint = joints[mapping["semantic_joint_id"]]
        joint_lines.append(
            f"- {joint['type']} joint {joint['id']} at exact path "
            f"{mapping['usd_joint_path']}, body0 {mapping['usd_parent_prim']}, "
            f"body1 {mapping['usd_driven_prim']}, axis {joint['axis']}, limits "
            f"{joint.get('lower_limit')} to {joint.get('upper_limit')} "
            f"{joint.get('limit_unit')}. The body1 prim must have "
            "PhysicsRigidBodyAPI and physics:kinematicEnabled = true."
        )
    rate = contract["clock"]["time_codes_per_second"]
    return f"""{ir['source_text']}

FROZEN OPENUSD/USD PHYSICS PROFILE OBLIGATIONS
- Return one self-contained portable USDA stage rooted at exact path /World.
- Set metersPerUnit=1, kilogramsPerUnit=1, upAxis=Z, and
  timeCodesPerSecond={rate:g}.
{chr(10).join(entity_lines)}
{chr(10).join(joint_lines)}
- Use only portable OpenUSD/UsdPhysics core schemas. Preserve every exact prim
  path, relationship, axis, limit, mass, and kinematic ownership obligation.
- Include primitive collision geometry and a valid articulation root.
- Do not author time samples, animations, simulated trajectories, or custom FMU
  signal attributes. This stage is a static embodiment; the verified H1 runtime
  authors playback from the real FMU trace after contract validation.

GROUNDED REQUIREMENT IR
{json.dumps(ir, indent=2, sort_keys=True)}
"""


def _modelica_identifier(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_]", "_", value)
    cleaned = re.sub(r"_+", "_", cleaned).strip("_") or "artifact"
    if cleaned[0].isdigit():
        cleaned = f"n_{cleaned}"
    return cleaned


def _usd_identifier(value: str) -> str:
    parts = re.findall(r"[A-Za-z0-9]+", value)
    cleaned = "".join(part[:1].upper() + part[1:] for part in parts) or "Artifact"
    if cleaned[0].isdigit():
        cleaned = f"N{cleaned}"
    return cleaned
