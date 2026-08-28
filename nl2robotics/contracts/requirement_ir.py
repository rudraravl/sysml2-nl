"""Validation for a grounded, cross-profile robotics requirement IR."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
import json
import math
from pathlib import Path

from .capabilities import (
    BROAD_INTERFACE_QUANTITIES,
    BROAD_JOINT_AXES,
    BROAD_JOINT_TYPES,
    BROAD_LINK_SHAPES,
    BROAD_PROPERTY_KINDS,
)


EXECUTION_MODES = {
    "portable_fmu_kinematic",
    "isaac_closed_loop",
    "newton_closed_loop",
    "capability_tiered",
}
CLOSED_LOOP_MODES = {"isaac_closed_loop", "newton_closed_loop"}
RECORD_COLLECTIONS = (
    "domains",
    "entities",
    "joints",
    "parameters",
    "dynamics",
    "controllers",
    "actuators",
    "sensors",
    "environment",
    "interfaces",
    "properties",
)


def is_closed_loop_mode(mode: object) -> bool:
    return mode in CLOSED_LOOP_MODES


@dataclass(frozen=True)
class IRIssue:
    code: str
    message: str
    path: str


@dataclass
class RequirementIRValidation:
    issues: list[IRIssue] = field(default_factory=list)

    @property
    def success(self) -> bool:
        return not self.issues

    def to_dict(self) -> dict:
        return {
            "success": self.success,
            "issues": [asdict(item) for item in self.issues],
            "error_count": len(self.issues),
        }


def load_requirement_ir(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("requirement IR root must be an object")
    return data


def validate_requirement_ir(data: dict) -> RequirementIRValidation:
    issues: list[IRIssue] = []
    if not isinstance(data, dict):
        return RequirementIRValidation([
            IRIssue("invalid_root", "requirement IR must be an object", "$"),
        ])

    source = data.get("source_text")
    if data.get("schema_version") != "1.0":
        issues.append(IRIssue(
            "unsupported_schema", "schema_version must be '1.0'", "$.schema_version"
        ))
    if not isinstance(source, str) or not source.strip():
        issues.append(IRIssue(
            "missing_source_text", "source_text must be non-empty", "$.source_text"
        ))
        source = ""
    if not isinstance(data.get("task_id"), str) or not data.get("task_id", "").strip():
        issues.append(IRIssue("missing_task_id", "task_id must be non-empty", "$.task_id"))
    if data.get("execution_mode") not in EXECUTION_MODES:
        issues.append(IRIssue(
            "invalid_execution_mode",
            f"execution_mode must be one of {sorted(EXECUTION_MODES)}",
            "$.execution_mode",
        ))

    records: dict[str, list[dict]] = {}
    all_ids: dict[str, str] = {}
    for collection in RECORD_COLLECTIONS:
        value = data.get(collection, [])
        if not isinstance(value, list):
            issues.append(IRIssue(
                "invalid_collection", f"{collection} must be a list", f"$.{collection}"
            ))
            value = []
        records[collection] = []
        for index, record in enumerate(value):
            path = f"$.{collection}[{index}]"
            if not isinstance(record, dict):
                issues.append(IRIssue("invalid_record", "record must be an object", path))
                continue
            records[collection].append(record)
            record_id = record.get("id")
            if not isinstance(record_id, str) or not record_id.strip():
                issues.append(IRIssue("missing_id", "record id must be non-empty", f"{path}.id"))
            elif record_id in all_ids:
                issues.append(IRIssue(
                    "duplicate_id",
                    f"id {record_id!r} already appears at {all_ids[record_id]}",
                    f"{path}.id",
                ))
            else:
                all_ids[record_id] = path
            _validate_evidence(record, source, path, issues)
            _validate_record_shape(
                collection, record, path, issues,
                execution_mode=data.get("execution_mode"),
            )

    entity_ids = {item.get("id") for item in records["entities"]}
    joint_ids = {item.get("id") for item in records["joints"]}
    sensor_ids = {item.get("id") for item in records["sensors"]}
    for index, joint in enumerate(records["joints"]):
        for key in ("parent", "child"):
            reference = joint.get(key)
            if reference not in entity_ids:
                issues.append(IRIssue(
                    "unknown_entity_reference",
                    f"joint {key} references unknown entity {reference!r}",
                    f"$.joints[{index}].{key}",
                ))
    for index, interface in enumerate(records["interfaces"]):
        joint_id = interface.get("joint_id")
        if joint_id is not None and joint_id not in joint_ids:
            issues.append(IRIssue(
                "unknown_joint_reference",
                f"interface references unknown joint {joint_id!r}",
                f"$.interfaces[{index}].joint_id",
            ))
        entity_id = interface.get("entity_id")
        if entity_id is not None and entity_id not in entity_ids:
            issues.append(IRIssue(
                "unknown_entity_reference",
                f"interface references unknown entity {entity_id!r}",
                f"$.interfaces[{index}].entity_id",
            ))
        sensor_id = interface.get("sensor_id")
        if sensor_id is not None and sensor_id not in sensor_ids:
            issues.append(IRIssue(
                "unknown_sensor_reference",
                f"interface references unknown sensor {sensor_id!r}",
                f"$.interfaces[{index}].sensor_id",
            ))
        state_id = interface.get("state_id")
        declared_states = {
            state
            for dynamics in records["dynamics"]
            for state in dynamics.get("states", [])
            if isinstance(state, str)
        }
        if state_id is not None and state_id not in declared_states:
            direction = interface.get("direction")
            if direction != "fmu_to_usd":
                issues.append(IRIssue(
                    "unknown_state_reference",
                    f"interface references undeclared state {state_id!r}",
                    f"$.interfaces[{index}].state_id",
                ))
    for index, parameter in enumerate(records["parameters"]):
        joint_id = parameter.get("joint_id")
        if joint_id is not None and joint_id not in joint_ids:
            issues.append(IRIssue(
                "unknown_joint_reference",
                f"parameter references unknown joint {joint_id!r}",
                f"$.parameters[{index}].joint_id",
            ))
    for index, controller in enumerate(records["controllers"]):
        references = controller.get("joint_ids")
        if references is None and controller.get("joint_id") is not None:
            references = [controller.get("joint_id")]
        if references is not None:
            if (not isinstance(references, list) or not references
                    or any(not isinstance(item, str) or not item for item in references)):
                issues.append(IRIssue(
                    "invalid_controller_joint_ids",
                    "controller joint_ids must be a non-empty list of strings",
                    f"$.controllers[{index}].joint_ids",
                ))
            else:
                for joint_id in references:
                    if joint_id not in joint_ids:
                        issues.append(IRIssue(
                            "unknown_joint_reference",
                            f"controller references unknown joint {joint_id!r}",
                            f"$.controllers[{index}].joint_ids",
                        ))

    if is_closed_loop_mode(data.get("execution_mode")):
        _validate_articulation_topology(records, issues)

    interface_ids = {item.get("id") for item in records["interfaces"]}
    for index, prop in enumerate(records["properties"]):
        interface_id = prop.get("interface_id")
        if interface_id is not None and interface_id not in interface_ids:
            issues.append(IRIssue(
                "unknown_interface_reference",
                f"property references unknown interface {interface_id!r}",
                f"$.properties[{index}].interface_id",
            ))
        entity_id = prop.get("entity_id")
        if entity_id is not None and entity_id not in entity_ids:
            issues.append(IRIssue(
                "unknown_entity_reference",
                f"property references unknown entity {entity_id!r}",
                f"$.properties[{index}].entity_id",
            ))

    clock = data.get("clock")
    if clock is not None:
        if not isinstance(clock, dict):
            issues.append(IRIssue("invalid_clock", "clock must be an object", "$.clock"))
        else:
            _validate_evidence(clock, source, "$.clock", issues)
            for key in ("start_time", "stop_time", "frequency_hz"):
                value = clock.get(key)
                if not _is_finite_number(value):
                    issues.append(IRIssue(
                        "invalid_clock_value",
                        f"clock {key} must be a finite number",
                        f"$.clock.{key}",
                    ))
            start = clock.get("start_time")
            stop = clock.get("stop_time")
            frequency = clock.get("frequency_hz")
            if _is_finite_number(start) and _is_finite_number(stop) and stop <= start:
                issues.append(IRIssue(
                    "invalid_clock_range", "clock stop_time must exceed start_time",
                    "$.clock.stop_time",
                ))
            if _is_finite_number(frequency) and frequency <= 0:
                issues.append(IRIssue(
                    "invalid_clock_frequency", "clock frequency_hz must be positive",
                    "$.clock.frequency_hz",
                ))
            if "physics_substeps" in clock:
                substeps = clock["physics_substeps"]
                if (not isinstance(substeps, int) or isinstance(substeps, bool)
                        or substeps < 1):
                    issues.append(IRIssue(
                        "invalid_physics_substeps",
                        "clock physics_substeps must be a positive integer",
                        "$.clock.physics_substeps",
                    ))

    for name in ("assumptions", "unknowns"):
        value = data.get(name, [])
        if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
            issues.append(IRIssue(
                "invalid_text_list", f"{name} must be a list of strings", f"$.{name}"
            ))
    return RequirementIRValidation(issues)


def _validate_evidence(record: dict, source: str, path: str,
                       issues: list[IRIssue]) -> None:
    evidence = record.get("evidence")
    if not isinstance(evidence, list) or not evidence:
        issues.append(IRIssue(
            "missing_evidence",
            "normalized facts require at least one exact source excerpt",
            f"{path}.evidence",
        ))
        return
    for index, excerpt in enumerate(evidence):
        if not isinstance(excerpt, str) or not excerpt.strip() or excerpt not in source:
            issues.append(IRIssue(
                "ungrounded_evidence",
                "evidence must be a non-empty exact substring of source_text",
                f"{path}.evidence[{index}]",
            ))


def _validate_record_shape(collection: str, record: dict, path: str,
                           issues: list[IRIssue], *,
                           execution_mode: object) -> None:
    required_strings = {
        "domains": ("kind",),
        "entities": ("kind",),
        "joints": ("type", "parent", "child"),
        "parameters": ("quantity", "unit"),
        "dynamics": (),
        "controllers": ("kind",),
        "actuators": ("command",),
        "sensors": ("kind",),
        "environment": ("kind",),
        "interfaces": ("state_id", "quantity", "direction", "source_unit"),
        "properties": ("kind",),
    }
    for key in required_strings.get(collection, ()):
        if not isinstance(record.get(key), str) or not record[key].strip():
            issues.append(IRIssue(
                "missing_required_field",
                f"{collection} record requires non-empty {key}",
                f"{path}.{key}",
            ))

    enum_fields = {
        "joints": {"type": BROAD_JOINT_TYPES, "axis": BROAD_JOINT_AXES},
        "entities": {"shape": BROAD_LINK_SHAPES},
        "interfaces": {
            "direction": {"fmu_to_usd", "usd_to_fmu"},
            "quantity": BROAD_INTERFACE_QUANTITIES,
        },
        "properties": {"kind": BROAD_PROPERTY_KINDS},
    }
    for key, allowed in enum_fields.get(collection, {}).items():
        value = record.get(key)
        # The general artifact path is open-world by design. Unknown but
        # grounded feature names remain representable and are routed to the
        # generic profile. Executable modes stay closed-world.
        open_world = (
            execution_mode == "capability_tiered"
            and not (collection == "interfaces" and key == "direction")
        )
        comparable = value
        if (isinstance(value, str) and collection in {"joints", "entities"}
                and key in {"type", "shape"}):
            comparable = value.lower()
        if isinstance(value, str) and not open_world and comparable not in allowed:
            issues.append(IRIssue(
                "invalid_field_value",
                f"{collection} {key} must be one of {sorted(allowed)}",
                f"{path}.{key}",
            ))

    numeric_fields = {
        "entities": ("mass", "length", "width", "depth", "height", "radius"),
        "joints": ("lower_limit", "upper_limit"),
        "parameters": ("value",),
        "environment": ("magnitude",),
        "interfaces": ("initial_value",),
        "properties": ("lower", "upper", "start", "end"),
    }
    for key in numeric_fields.get(collection, ()):
        if key in record and not _is_finite_number(record[key]):
            issues.append(IRIssue(
                "invalid_numeric_value",
                f"{collection} {key} must be a finite number",
                f"{path}.{key}",
            ))

    if collection == "parameters" and "value" not in record:
        issues.append(IRIssue(
            "missing_required_field", "parameters record requires value",
            f"{path}.value",
        ))
    if collection == "joints":
        joint_type = str(record.get("type", "")).lower()
        if joint_type in {"revolute", "continuous", "prismatic", "planar", "screw"}:
            has_axis = isinstance(record.get("axis"), str) and bool(record["axis"].strip())
            axis_vector = record.get("axis_vector")
            has_vector = (
                isinstance(axis_vector, list) and len(axis_vector) == 3
                and all(_is_finite_number(value) for value in axis_vector)
                and any(abs(float(value)) > 0 for value in axis_vector)
            )
            if not has_axis and not has_vector:
                code = (
                    "missing_required_field"
                    if "axis" not in record and "axis_vector" not in record
                    else "invalid_joint_axis"
                )
                issues.append(IRIssue(
                    code,
                    "one-DOF joint requires axis or nonzero axis_vector",
                    path,
                ))
    if collection == "dynamics":
        states = record.get("states")
        if (not isinstance(states, list) or not states
                or any(not isinstance(item, str) or not item.strip() for item in states)):
            issues.append(IRIssue(
                "invalid_states",
                "dynamics states must be a non-empty list of strings",
                f"{path}.states",
            ))
    if collection == "interfaces":
        targets = [
            key for key in ("joint_id", "entity_id", "sensor_id")
            if isinstance(record.get(key), str) and record[key].strip()
        ]
        if len(targets) > 1:
            issues.append(IRIssue(
                "ambiguous_interface_target",
                "interface may target at most one joint, entity, or sensor",
                path,
            ))
        if "required" in record and not isinstance(record["required"], bool):
            issues.append(IRIssue(
                "invalid_required_flag", "interface required must be boolean",
                f"{path}.required",
            ))
    if collection == "properties":
        targets = [
            key for key in ("interface_id", "state_id", "entity_id")
            if isinstance(record.get(key), str) and record[key].strip()
        ]
        if not targets:
            issues.append(IRIssue(
                "missing_property_target",
                "property requires interface_id, state_id, or entity_id",
                path,
            ))
        elif len(targets) > 1:
            issues.append(IRIssue(
                "ambiguous_property_target",
                "property may target only one interface, state, or entity",
                path,
            ))
    if (collection == "properties"
            and record.get("kind") in {"always", "eventually", "final", "until"}
            and not any(key in record for key in ("lower", "upper"))):
        issues.append(IRIssue(
            "missing_property_bound", "property requires lower and/or upper",
            path,
        ))
    if (collection == "properties" and _is_finite_number(record.get("start"))
            and _is_finite_number(record.get("end"))
            and float(record["start"]) > float(record["end"])):
        issues.append(IRIssue(
            "invalid_property_interval", "property start must not exceed end",
            path,
        ))


def _validate_articulation_topology(records: dict[str, list[dict]],
                                    issues: list[IRIssue]) -> None:
    """Require one connected, acyclic fixed-base articulation tree.

    Serial chains and branching trees are both supported.  A tree gives every
    dynamic link one unambiguous parent transform and keeps both simulator
    adapters on the same portable OpenUSD articulation semantics.
    """
    entities = {
        item.get("id"): item for item in records["entities"]
        if isinstance(item.get("id"), str)
    }
    joints = [item for item in records["joints"] if isinstance(item, dict)]
    fixed = [entity_id for entity_id, item in entities.items()
             if item.get("kind") == "fixed_base"]
    dynamic = [entity_id for entity_id, item in entities.items()
               if item.get("kind") == "rigid_link"]
    if len(fixed) != 1:
        issues.append(IRIssue(
            "invalid_articulation_root_count",
            "closed-loop profile requires exactly one fixed_base root",
            "$.entities",
        ))
    if not joints:
        issues.append(IRIssue(
            "missing_articulated_joint",
            "closed-loop profile requires at least one articulated joint",
            "$.joints",
        ))
        return

    incoming: dict[str, list[str]] = {}
    children: dict[str, list[str]] = {}
    for index, joint in enumerate(joints):
        parent = joint.get("parent")
        child = joint.get("child")
        if parent == child and parent is not None:
            issues.append(IRIssue(
                "self_joint", "joint parent and child must differ",
                f"$.joints[{index}]",
            ))
        if child in entities and entities[child].get("kind") != "rigid_link":
            issues.append(IRIssue(
                "fixed_base_as_joint_child",
                "a fixed_base cannot be the child of an articulated joint",
                f"$.joints[{index}].child",
            ))
        if isinstance(parent, str) and isinstance(child, str):
            incoming.setdefault(child, []).append(str(joint.get("id")))
            children.setdefault(parent, []).append(child)

    for child, joint_ids in incoming.items():
        if len(joint_ids) > 1:
            issues.append(IRIssue(
                "multiple_parent_joints",
                f"entity {child!r} has multiple parent joints {joint_ids}",
                "$.joints",
            ))
    for entity_id in dynamic:
        if len(incoming.get(entity_id, [])) != 1:
            issues.append(IRIssue(
                "unattached_dynamic_link",
                f"rigid_link {entity_id!r} must have exactly one parent joint",
                "$.joints",
            ))

    if len(fixed) != 1:
        return
    reachable: set[str] = set()
    visiting: set[str] = set()
    cycle = False

    def visit(entity_id: str) -> None:
        nonlocal cycle
        if entity_id in visiting:
            cycle = True
            return
        if entity_id in reachable:
            return
        visiting.add(entity_id)
        reachable.add(entity_id)
        for child in children.get(entity_id, []):
            visit(child)
        visiting.remove(entity_id)

    visit(fixed[0])
    if cycle:
        issues.append(IRIssue(
            "cyclic_articulation",
            "closed-loop articulation topology must be acyclic",
            "$.joints",
        ))
    disconnected = sorted(set(entities) - reachable)
    if disconnected:
        issues.append(IRIssue(
            "disconnected_articulation",
            f"entities are not reachable from fixed base {fixed[0]!r}: {disconnected}",
            "$.joints",
        ))


def _is_finite_number(value: object) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )
