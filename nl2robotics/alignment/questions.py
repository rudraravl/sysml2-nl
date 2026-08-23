"""Instantiate concrete alignment questions from grounded requirement facts."""

from __future__ import annotations

from dataclasses import asdict, dataclass
import hashlib
import json

from nl2robotics.contracts.requirement_ir import validate_requirement_ir

from .bank import family_weight


@dataclass(frozen=True)
class FocusedQuestion:
    id: str
    family: str
    text: str
    expected: dict
    owner: str
    weight: float
    evidence: tuple[str, ...]
    subject_id: str
    deterministic_kind: str

    def to_dict(self) -> dict:
        row = asdict(self)
        row["evidence"] = list(self.evidence)
        return row


def instantiate_questions(requirement_ir: dict) -> list[FocusedQuestion]:
    """Create only questions supported by facts explicitly grounded in the NL."""
    validation = validate_requirement_ir(requirement_ir)
    if not validation.success:
        messages = "; ".join(
            f"{item.path}: {item.message}" for item in validation.issues
        )
        raise ValueError(f"cannot instantiate questions from invalid IR: {messages}")

    questions: list[FocusedQuestion] = []
    backend = _grounded_backend(requirement_ir)
    if backend is not None:
        mode, evidence = backend
        questions.append(_question(
            "execution_backend", mode, "cross_profile",
            {"evidence": [evidence]},
            f"Does the contract select the explicitly required "
            f"{evidence} execution backend?",
            {"execution_mode": mode},
        ))
    clock = requirement_ir.get("clock")
    if isinstance(clock, dict):
        expected = _select(clock, "start_time", "stop_time", "frequency_hz")
        questions.append(_question(
            "timing", "clock", "cross_profile", clock,
            "Do the artifacts use the required simulation start, stop, and frequency?",
            expected,
        ))

    for entity in requirement_ir.get("entities", []):
        entity_id = entity["id"]
        questions.append(_question(
            "entity_presence", entity_id, "openusd", entity,
            f"Does the OpenUSD artifact contain the required {entity['kind']} "
            f"entity {entity_id!r}?",
            _select(entity, "kind"),
        ))
        if "mass" in entity:
            questions.append(_question(
                "entity_mass", entity_id, "openusd", entity,
                f"Does entity {entity_id!r} have the required mass?",
                _select(entity, "mass", "mass_unit"),
            ))
        dimensions = _select(
            entity, "length", "width", "height", "depth", "radius",
            "dimension_unit",
        )
        if len(dimensions) > (1 if "dimension_unit" in dimensions else 0):
            questions.append(_question(
                "entity_geometry", entity_id, "openusd", entity,
                f"Does entity {entity_id!r} have the required grounded dimensions?",
                dimensions,
            ))

    for joint in requirement_ir.get("joints", []):
        joint_id = joint["id"]
        questions.append(_question(
            "joint_topology", joint_id, "openusd", joint,
            f"Is joint {joint_id!r} a {joint['type']} joint connecting "
            f"{joint['parent']!r} to {joint['child']!r}?",
            _select(joint, "type", "parent", "child"),
        ))
        if "axis" in joint:
            questions.append(_question(
                "joint_axis", joint_id, "openusd", joint,
                f"Does joint {joint_id!r} use the required {joint['axis']} axis?",
                _select(joint, "axis"),
            ))
        if "lower_limit" in joint or "upper_limit" in joint:
            questions.append(_question(
                "joint_limits", joint_id, "openusd", joint,
                f"Does joint {joint_id!r} use the required motion limits?",
                _select(joint, "lower_limit", "upper_limit", "limit_unit"),
            ))

    for parameter in requirement_ir.get("parameters", []):
        owner = _profile_owner(parameter.get("owner"))
        questions.append(_question(
            "parameter", parameter["id"], owner, parameter,
            f"Does the {owner} artifact implement {parameter.get('quantity')!r} "
            f"for {parameter.get('joint_id')!r} with the required value and unit?",
            _select(parameter, "owner", "joint_id", "quantity", "value", "unit"),
        ))

    for record in requirement_ir.get("dynamics", []):
        questions.append(_question(
            "dynamics", record["id"], "cross_profile", record,
            f"Does the contract assign the required states for dynamics "
            f"{record['id']!r} to {record.get('owner')!r}?",
            _without_metadata(record),
        ))

    for record in requirement_ir.get("controllers", []):
        owner = _profile_owner(record.get("owner"))
        questions.append(_question(
            "controller_presence", record["id"], owner, record,
            f"Does the {owner} profile expose the required controller "
            f"{record['id']!r} through validated inputs and outputs?",
            _select(record, "owner"),
        ))
        if record.get("kind") is not None:
            questions.append(_question(
                "controller_kind", record["id"], owner, record,
                f"Does controller {record['id']!r} implement the required "
                f"{record.get('kind')!r} control law?",
                _select(record, "kind"),
            ))

    for record in requirement_ir.get("actuators", []):
        questions.append(_question(
            "actuator", record["id"], "cross_profile", record,
            f"Does actuator {record['id']!r} command the required joint and quantity?",
            _without_metadata(record),
        ))

    for record in requirement_ir.get("sensors", []):
        owner = _profile_owner(record.get("owner"))
        questions.append(_question(
            "sensor_presence", record["id"], owner, record,
            f"Is required sensor {record['id']!r} present in the validated profile?",
            _select(record, "owner", "kind", "type", "joint_id", "entity_id"),
        ))
        configuration = {
            key: value for key, value in _without_metadata(record).items()
            if key not in {"owner", "kind", "type", "joint_id", "entity_id"}
        }
        if configuration:
            questions.append(_question(
                "sensor_configuration", record["id"], owner, record,
                f"Does sensor {record['id']!r} use the required grounded settings?",
                configuration,
            ))

    for environment in requirement_ir.get("environment", []):
        questions.append(_question(
            "environment", environment["id"], "openusd", environment,
            f"Does the OpenUSD environment implement {environment.get('kind')!r} "
            "with the required grounded settings?",
            _without_metadata(environment),
        ))

    for interface in requirement_ir.get("interfaces", []):
        if not interface.get("required", True):
            continue
        questions.append(_question(
            "interface", interface["id"], "cross_profile", interface,
            f"Is required interface {interface['id']!r} connected with the stated "
            "direction, quantity, joint, state, and units?",
            _without_metadata(interface),
        ))

    for prop in requirement_ir.get("properties", []):
        questions.append(_question(
            "property", prop["id"], "runtime", prop,
            f"Does execution satisfy required {prop.get('kind')!r} property "
            f"{prop['id']!r}?",
            _without_metadata(prop),
        ))

    questions.sort(key=lambda item: item.id)
    return questions


def question_set_hash(questions: list[FocusedQuestion]) -> str:
    payload = json.dumps(
        [item.to_dict() for item in questions], sort_keys=True, separators=(",", ":")
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _question(family: str, subject_id: str, owner: str,
              record: dict, text: str, expected: dict) -> FocusedQuestion:
    return FocusedQuestion(
        id=f"RQ-{family.upper().replace('_', '-')}-{_slug(subject_id)}",
        family=family,
        text=text,
        expected=expected,
        owner=owner,
        weight=family_weight(family),
        evidence=tuple(record.get("evidence", [])),
        subject_id=subject_id,
        deterministic_kind=family,
    )


def _profile_owner(owner: object) -> str:
    value = str(owner or "")
    if value.startswith("fmu_"):
        return "modelica"
    if value == "usd_physics":
        return "openusd"
    return "cross_profile"


def _select(record: dict, *keys: str) -> dict:
    return {key: record[key] for key in keys if key in record}


def _without_metadata(record: dict) -> dict:
    return {
        key: value for key, value in record.items()
        if key not in {"id", "evidence"}
    }


def _slug(value: str) -> str:
    return "".join(char.upper() if char.isalnum() else "-" for char in value).strip("-")


def _grounded_backend(requirement_ir: dict) -> tuple[str, str] | None:
    source = str(requirement_ir.get("source_text", ""))
    mode = requirement_ir.get("execution_mode")
    expected = {
        "isaac_closed_loop": "Isaac Sim",
        "newton_closed_loop": "Newton Physics",
    }.get(mode)
    if expected is not None and expected in source:
        return str(mode), expected
    return None
