"""Validation for a grounded, cross-profile robotics requirement IR."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
import json
import math
from pathlib import Path


EXECUTION_MODES = {
    "portable_fmu_kinematic",
    "isaac_closed_loop",
    "newton_closed_loop",
}
CLOSED_LOOP_MODES = {"isaac_closed_loop", "newton_closed_loop"}
RECORD_COLLECTIONS = (
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
            _validate_record_shape(collection, record, path, issues)

    entity_ids = {item.get("id") for item in records["entities"]}
    joint_ids = {item.get("id") for item in records["joints"]}
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

    interface_ids = {item.get("id") for item in records["interfaces"]}
    for index, prop in enumerate(records["properties"]):
        interface_id = prop.get("interface_id")
        if interface_id is not None and interface_id not in interface_ids:
            issues.append(IRIssue(
                "unknown_interface_reference",
                f"property references unknown interface {interface_id!r}",
                f"$.properties[{index}].interface_id",
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
                           issues: list[IRIssue]) -> None:
    required_strings = {
        "entities": ("kind",),
        "joints": ("type", "parent", "child", "axis"),
        "parameters": ("owner", "quantity", "unit"),
        "dynamics": ("owner",),
        "controllers": ("owner", "kind"),
        "actuators": ("owner", "joint_id", "command"),
        "sensors": ("owner", "kind"),
        "environment": ("kind",),
        "interfaces": (
            "joint_id", "state_id", "quantity", "direction", "source_unit"
        ),
        "properties": ("kind", "interface_id"),
    }
    for key in required_strings.get(collection, ()):
        if not isinstance(record.get(key), str) or not record[key].strip():
            issues.append(IRIssue(
                "missing_required_field",
                f"{collection} record requires non-empty {key}",
                f"{path}.{key}",
            ))

    enum_fields = {
        "joints": {"type": {"revolute", "prismatic"}, "axis": {"X", "Y", "Z"}},
        "interfaces": {
            "direction": {"fmu_to_usd", "usd_to_fmu"},
            "quantity": {"joint_position", "joint_velocity", "joint_effort"},
        },
        "properties": {"kind": {"always", "eventually", "final"}},
    }
    for key, allowed in enum_fields.get(collection, {}).items():
        value = record.get(key)
        if isinstance(value, str) and value not in allowed:
            issues.append(IRIssue(
                "invalid_field_value",
                f"{collection} {key} must be one of {sorted(allowed)}",
                f"{path}.{key}",
            ))

    numeric_fields = {
        "entities": ("mass", "length", "width", "depth"),
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
        if "required" in record and not isinstance(record["required"], bool):
            issues.append(IRIssue(
                "invalid_required_flag", "interface required must be boolean",
                f"{path}.required",
            ))
        if (record.get("direction") == "usd_to_fmu"
                and (not isinstance(record.get("target_unit"), str)
                     or not record["target_unit"].strip())):
            issues.append(IRIssue(
                "missing_required_field",
                "usd_to_fmu interface requires target_unit",
                f"{path}.target_unit",
            ))
    if collection == "properties" and not any(
            key in record for key in ("lower", "upper")):
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


def _is_finite_number(value: object) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )
