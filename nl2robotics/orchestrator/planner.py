"""Derive frozen cross-profile interfaces from grounded requirement facts."""

from __future__ import annotations

from copy import deepcopy
from dataclasses import asdict, dataclass
import json
import math
import re

from nl2robotics.contracts.requirement_ir import validate_requirement_ir
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
            "execution_mode": "isaac_closed_loop",
            "model_name": self.model_name,
            "identifiers": self.identifiers,
        }


def build_plan(requirement_ir: dict) -> H1Plan | H2Plan:
    mode = requirement_ir.get("execution_mode")
    if mode == "portable_fmu_kinematic":
        return build_h1_plan(requirement_ir)
    if mode == "isaac_closed_loop":
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
        "H2 one-DOF profile places the fixed-base joint at the world origin and "
        "centers the box link one half-length below that joint.",
        "H2 one-DOF profile uses a 0.2 m fixed-base collision cube when the "
        "request does not specify base geometry.",
    ):
        if assumption not in ir["assumptions"]:
            ir["assumptions"].append(assumption)
    task_id = ir["task_id"]
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
        item["joint_id"]: conversion(str(item["unit"]), "N.m").apply(
            float(item["value"])
        )
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
        "execution_mode": "isaac_closed_loop",
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
    if ir.get("execution_mode") != "isaac_closed_loop":
        issues.append(PlanIssue(
            "unsupported_mode", "H2 planning requires isaac_closed_loop",
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
    if (len(dynamics) != 1
            or any(item.get("owner") != "usd_physics" for item in dynamics)):
        issues.append(PlanIssue(
            "invalid_h2_dynamics_owner",
            "H2 requires exactly one dynamics record owned by usd_physics",
            "$.dynamics",
        ))
    if len(joints) != 1:
        issues.append(PlanIssue(
            "unsupported_h2_topology",
            "the generated H2 MVP supports exactly one articulated joint",
            "$.joints",
        ))
    if (len(controllers) != 1
            or controllers[0].get("owner") != "fmu_controller"
            or str(controllers[0].get("kind", "")).upper() != "PD"):
        issues.append(PlanIssue(
            "unsupported_h2_controller",
            "the generated H2 profile requires exactly one fmu_controller PD controller",
            "$.controllers",
        ))
    if (len(actuators) != 1
            or actuators[0].get("owner") != "fmu_controller"
            or actuators[0].get("command") != "joint_effort"):
        issues.append(PlanIssue(
            "missing_fmu_actuator",
            "H2 requires exactly one fmu_controller joint_effort actuator",
            "$.actuators",
        ))

    required = [item for item in ir.get("interfaces", [])
                if isinstance(item, dict) and item.get("required", True)]
    directions = {item.get("direction") for item in required}
    if "usd_to_fmu" not in directions or "fmu_to_usd" not in directions:
        issues.append(PlanIssue(
            "open_loop_interface",
            "H2 requires at least one observation and one command interface",
            "$.interfaces",
        ))
    command_joints = {
        item.get("joint_id") for item in required
        if item.get("direction") == "fmu_to_usd"
    }
    actuator_joints = {item.get("joint_id") for item in actuators}
    if command_joints != actuator_joints:
        issues.append(PlanIssue(
            "actuator_interface_mismatch",
            "actuator joints and command-interface joints must match exactly",
            "$.actuators",
        ))
    commands = [item for item in required if item.get("direction") == "fmu_to_usd"]
    feedback = [item for item in required if item.get("direction") == "usd_to_fmu"]
    feedback_quantities = [item.get("quantity") for item in feedback]
    if len(commands) != 1 or commands[0].get("quantity") != "joint_effort":
        issues.append(PlanIssue(
            "unsupported_h2_command",
            "the generated H2 MVP requires exactly one joint_effort command",
            "$.interfaces",
        ))
    if (len(feedback) != 2
            or feedback_quantities.count("joint_position") != 1
            or feedback_quantities.count("joint_velocity") != 1):
        issues.append(PlanIssue(
            "incomplete_h2_feedback",
            "the generated H2 MVP requires exactly one position and one velocity input",
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
        if joint.get("type") != "revolute" or joint.get("axis") not in {"X", "Y"}:
            issues.append(PlanIssue(
                "unsupported_h2_joint",
                "the generated H2 MVP supports X- or Y-axis revolute joints",
                path,
            ))
        limits = (joint.get("lower_limit"), joint.get("upper_limit"))
        if not all(_finite_number(value) for value in limits):
            issues.append(PlanIssue(
                "missing_joint_limits", "H2 joints require finite grounded limits", path
            ))
        elif float(limits[0]) > float(limits[1]):
            issues.append(PlanIssue(
                "reversed_joint_limits", "joint lower limit exceeds upper limit", path
            ))
        child = entities.get(joint.get("child"), {})
        if (not _finite_number(child.get("mass"))
                or float(child.get("mass", 0)) <= 0
                or child.get("mass_unit") != "kg"):
            issues.append(PlanIssue(
                "missing_dynamic_body_mass",
                "H2 dynamic links require a positive grounded mass in kg",
                f"$.entities[{joint.get('child')}].mass",
            ))
        dimensions = (child.get("length"), child.get("width"), child.get("depth"))
        if (not all(_finite_number(value) and float(value) > 0 for value in dimensions)
                or child.get("dimension_unit") != "m"):
            issues.append(PlanIssue(
                "missing_collision_geometry",
                "H2 dynamic links require positive box dimensions in meters",
                f"$.entities[{joint.get('child')}].length",
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
    required_parameter_units = {
        "proportional_gain": "N.m/rad",
        "derivative_gain": "N.m.s/rad",
        "target_position": "rad",
        "effort_limit": "N.m",
    }
    for joint_id in joints:
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
        if not isinstance(interface.get("target_unit"), str):
            issues.append(PlanIssue(
                "missing_target_unit", "H2 interfaces require explicit target_unit",
                f"{path}.target_unit",
            ))
        try:
            conversion(str(interface.get("source_unit")), str(interface.get("target_unit")))
        except UnitError as exc:
            issues.append(PlanIssue("unit_mismatch", str(exc), f"{path}.source_unit"))
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


def _h2_modelica_requirement(ir: dict, contract: dict, model_name: str) -> str:
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
    parameter_lines = [
        f"- Declare parameter Real {_modelica_identifier(item['id'])}"
        f"(unit=\"{item['unit']}\") = {item['value']}."
        for item in ir["parameters"]
    ]
    return f"""{ir['source_text']}

FROZEN H2 MODELICA/FMI CONTROLLER OBLIGATIONS
- Return exactly one self-contained top-level model named {model_name}.
- The model contains controller logic only; it must not reproduce the rigid-body
  plant dynamics owned by Isaac/UsdPhysics.
- It must compile in OpenModelica and export as an FMI 2.0 Co-Simulation FMU.
{chr(10).join(interface_lines)}
{chr(10).join(parameter_lines)}
- Preserve every exact variable name, causality, unit, parameter, saturation,
  and control law stated in the grounded IR.

GROUNDED REQUIREMENT IR
{json.dumps(ir, indent=2, sort_keys=True)}
"""


def _h2_openusd_requirement(ir: dict, contract: dict) -> str:
    entity_lines = []
    for entity in ir["entities"]:
        path = f"/World/{_usd_identifier(entity['id'])}"
        if entity["kind"] == "fixed_base":
            entity_lines.append(f"- Fixed base {entity['id']} at exact path {path}.")
        else:
            entity_lines.append(
                f"- Dynamic rigid link {entity['id']} at exact path {path}, mass "
                f"{entity['mass']} {entity['mass_unit']}, box dimensions "
                f"{entity['length']} x {entity['width']} x {entity['depth']} "
                f"{entity['dimension_unit']}. Apply PhysicsRigidBodyAPI and set "
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
            f"{joint['limit_unit']}."
        )
    gravity_lines = [
        f"- Author one PhysicsScene with gravity magnitude {item['magnitude']} "
        f"{item['unit']}."
        for item in ir["environment"] if item.get("kind") == "gravity"
    ]
    rate = contract["clock"]["time_codes_per_second"]
    driven_id = ir["joints"][0]["child"]
    driven = next(item for item in ir["entities"] if item["id"] == driven_id)
    half_length = float(driven["length"]) / 2.0
    return f"""{ir['source_text']}

FROZEN H2 OPENUSD/USD PHYSICS OBLIGATIONS
- Return one self-contained USDA stage with default prim /World. Apply
  PhysicsArticulationRootAPI to the fixed world-anchor joint at exact path
  /World/WorldAnchor. Set metersPerUnit=1, kilogramsPerUnit=1, upAxis=Z, and
  timeCodesPerSecond={rate:g}.
{chr(10).join(entity_lines)}
{chr(10).join(joint_lines)}
{chr(10).join(gravity_lines)}
- Use portable OpenUSD/UsdPhysics core schemas for the plant. Include collision
  geometry. Fix each fixed base to the world using the articulation-root joint.
- Use the frozen one-DOF layout: put the world-anchor joint at the world origin,
  use a 0.2 m collision cube for the fixed base when no base size was stated,
  orient the box link's declared length along Z, center it at
  (0, 0, {-half_length:g}), and set the revolute joint's body1 local position to
  (0, 0, {half_length:g}). These are disclosed profile assumptions, not NL facts.
- The FMU commands joint effort at runtime. Do not author a position or velocity
  drive on an effort-commanded joint, and do not author a prerecorded trajectory.

GROUNDED REQUIREMENT IR
{json.dumps(ir, indent=2, sort_keys=True)}
"""


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
