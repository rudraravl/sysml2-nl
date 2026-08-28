"""Ground natural-language robotics requirements into a strict shared IR."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import asdict, dataclass, field
import hashlib
import json

from nl2robotics.contracts.requirement_ir import (
    EXECUTION_MODES,
    RECORD_COLLECTIONS,
    validate_requirement_ir,
)


Ask = Callable[[str], str]


@dataclass(frozen=True)
class NormalizationIssue:
    code: str
    message: str
    path: str = "$"


@dataclass
class NormalizationResult:
    task_id: str
    ir: dict | None = None
    issues: list[NormalizationIssue] = field(default_factory=list)
    attempts: list[dict] = field(default_factory=list)

    @property
    def success(self) -> bool:
        return self.ir is not None and not self.issues

    def to_dict(self) -> dict:
        return {
            "stage": "requirement_normalization",
            "task_id": self.task_id,
            "success": self.success,
            "issues": [asdict(item) for item in self.issues],
            "attempts": self.attempts,
        }


class RequirementNormalizer:
    """Use one constrained LLM call, then enforce exact evidence grounding."""

    def normalize(self, source_text: str, ask: Ask, *, task_id: str | None = None,
                  execution_mode: str = "portable_fmu_kinematic",
                  max_repairs: int = 1) -> NormalizationResult:
        source_text = source_text.strip()
        if not source_text:
            raise ValueError("source_text must be non-empty")
        if execution_mode not in EXECUTION_MODES:
            raise ValueError(
                f"execution_mode must be one of {sorted(EXECUTION_MODES)}"
            )
        task_id = task_id or deterministic_task_id(source_text)
        prompt = _normalization_prompt(source_text, task_id, execution_mode)
        attempts: list[dict] = []
        issues: list[NormalizationIssue] = []

        for attempt in range(max_repairs + 1):
            response = ask(prompt)
            provenance = {
                "attempt": attempt,
                "prompt_sha256": hashlib.sha256(prompt.encode("utf-8")).hexdigest(),
                "response_sha256": hashlib.sha256(response.encode("utf-8")).hexdigest(),
                "response": response,
            }
            try:
                candidate = _parse_json_object(response)
            except (json.JSONDecodeError, ValueError) as exc:
                issues = [NormalizationIssue("invalid_json", str(exc))]
            else:
                candidate["schema_version"] = "1.0"
                candidate["task_id"] = task_id
                candidate["source_text"] = source_text
                candidate["execution_mode"] = execution_mode
                for collection in RECORD_COLLECTIONS:
                    candidate.setdefault(collection, [])
                candidate.setdefault("assumptions", [])
                candidate.setdefault("unknowns", [])
                validation = validate_requirement_ir(candidate)
                issues = [NormalizationIssue(item.code, item.message, item.path)
                          for item in validation.issues]
                attempts.append({
                    **provenance,
                    "valid": not issues,
                    "issues": [asdict(item) for item in issues],
                })
                if not issues:
                    return NormalizationResult(task_id, candidate, [], attempts)

            if len(attempts) <= attempt:
                attempts.append({
                    **provenance,
                    "valid": False,
                    "issues": [asdict(item) for item in issues],
                })
            if attempt >= max_repairs:
                break
            prompt = _repair_prompt(
                source_text, task_id, execution_mode, response, issues
            )
        return NormalizationResult(task_id, None, issues, attempts)


def deterministic_task_id(source_text: str) -> str:
    digest = hashlib.sha256(source_text.strip().encode("utf-8")).hexdigest()[:10]
    return f"RGEN-{digest.upper()}"


def _parse_json_object(response: str) -> dict:
    text = response.strip()
    if "```" in text:
        blocks = text.split("```")
        text = max((block.removeprefix("json").strip() for block in blocks), key=len)
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end < start:
        raise ValueError("normalizer returned no JSON object")
    data = json.loads(text[start:end + 1])
    if not isinstance(data, dict):
        raise ValueError("normalizer JSON root must be an object")
    return data


def _normalization_prompt(source_text: str, task_id: str,
                          execution_mode: str) -> str:
    if execution_mode == "capability_tiered":
        return _capability_normalization_prompt(source_text, task_id)
    if execution_mode == "portable_fmu_kinematic":
        profile = """The portable profile uses a Modelica/FMI plant as physical-state
owner and OpenUSD as a kinematic embodiment. Required interfaces flow fmu_to_usd
and carry joint_position."""
        clock_extra = ""
        parameter_owner = '"owner": "fmu_plant"'
        dynamics_owner = '"owner": "fmu_plant"'
        role_examples = '"controllers": [], "actuators": [], "sensors": []'
        interface_examples = (
            '"quantity": "joint_position", "direction": "fmu_to_usd",\n'
            '    "source_unit": "rad|deg|m", "initial_value": 0.0'
        )
    else:
        simulator = (
            "Newton Physics" if execution_mode == "newton_closed_loop"
            else "Isaac Sim/PhysX"
        )
        profile = f"""The closed-loop profile uses OpenUSD/{simulator} as physical-state
owner and a Modelica FMI 2.0 Co-Simulation FMU as controller. It supports one
fixed-base serial or branching articulation with multiple revolute and prismatic
joints on principal axes. Extract every link, joint, controller, actuator,
usd_to_fmu observation, and fmu_to_usd command. Do not infer an actuator,
controller, feedback signal, geometry, mass, gravity, or initial condition."""
        clock_extra = ',\n    "physics_substeps": 2'
        parameter_owner = '"owner": "fmu_controller"'
        dynamics_owner = '"owner": "usd_physics"'
        role_examples = """"controllers": [{
    "id": "...", "owner": "fmu_controller", "kind": "PD",
    "joint_ids": ["joint_id"],
    "evidence": ["..."]
  }],
  "actuators": [{
    "id": "...", "owner": "fmu_controller", "joint_id": "...",
    "command": "joint_effort", "evidence": ["..."]
  }], "sensors": []"""
        interface_examples = (
            '"quantity": "joint_position|joint_velocity|joint_effort",\n'
            '    "direction": "usd_to_fmu|fmu_to_usd",\n'
            '    "source_unit": "rad|rad/s|N.m|m|m/s|N",\n'
            '    "target_unit": "rad|rad/s|N.m|m|m/s|N"'
        )
    return f"""Normalize the robotics request below into one JSON object.

This is a fact extraction task, not a design task. Include only facts stated in
the request. Every record and the clock must contain an `evidence` array whose
entries are exact, case-sensitive substrings copied from SOURCE_TEXT. Preserve
unknown or omitted information in `unknowns`; never invent masses, geometry,
gains, joint frames, sensors, properties, timing, or interfaces.

Use exactly task_id {task_id!r}, schema_version "1.0", execution_mode
{execution_mode!r}, and copy SOURCE_TEXT exactly. IDs must be unique, stable
snake_case semantic identifiers.

{profile}

Required object shape:
{{
  "schema_version": "1.0",
  "task_id": "{task_id}",
  "source_text": "...",
  "execution_mode": "{execution_mode}",
  "clock": {{
    "start_time": 0.0,
    "stop_time": 1.0,
    "frequency_hz": 50.0{clock_extra},
    "evidence": ["exact source excerpt"]
  }},
  "entities": [{{
    "id": "...", "kind": "fixed_base|rigid_link",
    "shape": "box|sphere|cylinder|capsule", "mass": 1.0,
    "mass_unit": "kg", "length": 1.0, "width": 0.1, "depth": 0.1,
    "height": 1.0, "radius": 0.1, "dimension_unit": "m|mm",
    "evidence": ["..."]
  }}],
  "joints": [{{
    "id": "...", "type": "revolute|prismatic", "parent": "entity_id",
    "child": "entity_id", "axis": "X|Y|Z", "lower_limit": 0.0,
    "upper_limit": 1.0, "limit_unit": "deg|rad|m", "evidence": ["..."]
  }}],
  "parameters": [{{
    "id": "...", {parameter_owner}, "joint_id": "...",
    "quantity": "proportional_gain|derivative_gain|target_position|effort_limit",
    "value": 1.0, "unit": "N.m/rad|N.m.s/rad|N/m|N.s/m|N.m|N|rad|deg|m",
    "evidence": ["..."]
  }}],
  "dynamics": [{{
    "id": "...", {dynamics_owner}, "states": ["joint.position"],
    "evidence": ["..."]
  }}],
  {role_examples}, "environment": [],
  "interfaces": [{{
    "id": "...", "joint_id": "...", "state_id": "joint.position",
    {interface_examples},
    "required": true, "evidence": ["..."]
  }}],
  "properties": [{{
    "id": "...", "kind": "always|eventually|final",
    "interface_id": "...", "lower": 0.0, "upper": 1.0,
    "evidence": ["..."]
  }}],
  "assumptions": [], "unknowns": []
}}

Omit optional numeric fields that are not stated. Property bounds must use the
source unit of the referenced interface. Do not place unsupported prose in
numeric fields. Return raw JSON only.

SOURCE_TEXT:
{source_text}
"""


def _capability_normalization_prompt(source_text: str, task_id: str) -> str:
    return f"""Normalize the robotics request below into one grounded JSON object.

This broad profile is not limited to a single-joint arm. Extract every stated
robot, rigid or soft component, fixed or floating base, serial/branching/closed
topology, joint, actuator, controller, trajectory, sensor, estimator,
environment, material/contact fact, interface, timing fact, and property.

This remains fact extraction, not robot design. Every record and the optional
clock must contain an `evidence` array of exact, case-sensitive SOURCE_TEXT
substrings. Never invent dimensions, masses, inertia, gains, transforms,
collision geometry, sensors, timing, or missing interfaces. Put omissions in
`unknowns`. Preserve unsupported-but-grounded features in the IR; capability
routing happens after normalization.

Use task_id {task_id!r}, schema_version "1.0", execution_mode
"capability_tiered", unique snake_case IDs, and copy SOURCE_TEXT exactly.

Vocabulary includes, but is not restricted to:
- entity kinds: fixed_base, floating_base, rigid_link, mobile_base,
  wheeled_base, tracked_base, aerial_base, end_effector, tool, object;
- joints: revolute, continuous, prismatic, fixed, spherical/ball, free,
  distance, D6, planar, screw and gear, with principal `axis` or 3-vector
  `axis_vector` when stated;
- controllers: P, PI, PD, PID, feedforward, trajectory, state_feedback,
  impedance, admittance, computed_torque, operational_space, differential_drive,
  Ackermann, quadrotor, MPC or custom;
- sensors: encoder, IMU, contact, force_torque, camera, lidar, GPS, odometry,
  range, pressure, flow and temperature;
- geometry: box, sphere, cylinder, capsule, cone, plane, mesh, convex_mesh,
  heightfield, compound or unspecified;
- interfaces may target one `joint_id`, `entity_id`, or `sensor_id` and may
  carry joint/base/body motion, effort, wrench, wheel, thrust, contact, sensor,
  electrical, fluid, or custom signals.

Required root shape:
{{
  "schema_version": "1.0",
  "task_id": "{task_id}",
  "source_text": "...",
  "execution_mode": "capability_tiered",
  "domains": [{{
    "id": "...", "kind": "articulated_manipulation|mobile_robotics|aerial_robotics|legged_robotics|marine_robotics|soft_robotics|fluid_power|electromechanical|multi_robot|sensing|contact|trajectory_control|custom",
    "evidence": ["..."]
  }}],
  "clock": {{
    "duration": 1.0, "frequency_hz": 100.0,
    "physics_substeps": 2, "evidence": ["exact excerpt"]
  }},
  "entities": [{{
    "id": "...", "kind": "...", "shape": "...", "mass": 1.0,
    "mass_unit": "kg", "length": 1.0, "width": 0.2, "height": 0.2,
    "radius": 0.1, "dimension_unit": "m", "mesh_uri": "...",
    "evidence": ["..."]
  }}],
  "joints": [{{
    "id": "...", "type": "...", "parent": "entity_id",
    "child": "entity_id", "axis": "X|Y|Z|arbitrary|multi_axis|none",
    "axis_vector": [1.0, 0.0, 0.0], "lower_limit": -1.0,
    "upper_limit": 1.0, "limit_unit": "rad|deg|m", "evidence": ["..."]
  }}],
  "parameters": [{{
    "id": "...", "owner": "fmu_controller|fmu_plant|usd_physics",
    "joint_id": "...", "quantity": "...", "value": 1.0,
    "unit": "...", "evidence": ["..."]
  }}],
  "dynamics": [{{
    "id": "...", "owner": "fmu_plant|usd_physics|fmu_controller",
    "states": ["semantic.state"], "evidence": ["..."]
  }}],
  "controllers": [{{
    "id": "...", "owner": "fmu_controller", "kind": "...",
    "joint_ids": ["..."], "entity_ids": ["..."], "evidence": ["..."]
  }}],
  "actuators": [{{
    "id": "...", "owner": "...", "joint_id": "...",
    "entity_id": "...", "command": "...", "evidence": ["..."]
  }}],
  "sensors": [{{
    "id": "...", "owner": "usd_physics|fmu_plant", "kind": "...",
    "entity_id": "...", "evidence": ["..."]
  }}],
  "environment": [{{
    "id": "...", "kind": "gravity|ground|obstacle|terrain|material|contact",
    "magnitude": 9.81, "unit": "m/s2", "evidence": ["..."]
  }}],
  "interfaces": [{{
    "id": "...", "joint_id": "...", "entity_id": "...",
    "sensor_id": "...", "state_id": "...", "quantity": "...",
    "direction": "usd_to_fmu|fmu_to_usd", "source_unit": "...",
    "target_unit": "...", "initial_value": 0.0, "required": true,
    "evidence": ["..."]
  }}],
  "properties": [{{
    "id": "...", "kind": "always|eventually|final|response|reach_avoid|custom",
    "interface_id": "...", "lower": 0.0, "upper": 1.0,
    "start": 0.0, "end": 1.0, "evidence": ["..."]
  }}],
  "assumptions": [], "unknowns": []
}}

Omit optional fields not stated, including the entire clock when timing is not
stated. A capability clock is all-or-nothing and uses exactly one grounded time
form: use `start_time` plus `stop_time` only when both absolute endpoints are
stated, or use `duration` when SOURCE_TEXT instead says "for N seconds". Never
infer a zero start time or put a duration into `stop_time`. Include
`frequency_hz` only from a stated controller, coordination, or system clock;
when several component sensor rates are stated but no system rate is named,
omit the clock and preserve those rates as sensor facts. Do not include multiple
interface target IDs on one record.

Cross-record consistency is mandatory:
- Every interface requires a non-empty semantic `state_id`, `quantity`,
  `direction`, and `source_unit`.
- Every usd_to_fmu interface state_id must appear verbatim in the `states` list
  of a grounded `dynamics` record. Use owner `usd_physics` for simulator/body,
  contact, and simulator-hosted sensor state; use `fmu_plant` only when the
  source explicitly makes the FMU the physical-state owner. A dynamics record
  may reuse the exact evidence of the interface fact it declares.
- Every interface targets at most one joint_id, entity_id, or sensor_id.
- Every property targets exactly one interface_id, state_id, or entity_id.
- A property that targets state_id must have a matching interface carrying that
  exact state_id so the property is observable in generated artifacts. Prefer
  interface_id for signal-bound properties.
- If a signal is explicitly requested but its unit is omitted, preserve the
  signal with source_unit `unspecified` and record the missing unit in
  `unknowns`; do not guess a physical unit.
- Encode an explicit no-collision/no-contact requirement as a grounded contact
  interface with source_unit `dimensionless` and an `always` property whose
  upper bound is 0. Do not create this encoding unless the prohibition is
  explicit in SOURCE_TEXT.

Return raw JSON only.

SOURCE_TEXT:
{source_text}
"""


def _repair_prompt(source_text: str, task_id: str, execution_mode: str,
                   response: str,
                   issues: list[NormalizationIssue]) -> str:
    diagnostics = "\n".join(
        f"- [{item.code}] {item.path}: {item.message}" for item in issues
    )
    return f"""Correct the JSON extraction using only SOURCE_TEXT. Do not add a
fact to resolve an error. Preserve supported facts whenever the schema can
represent them; delete only unsupported facts and put genuine omissions in
unknowns. Evidence must remain exact substrings. Use task_id {task_id!r} and
execution_mode {execution_mode!r}.

Repair cross-record references, not just the field named by the diagnostic. In
particular, every usd_to_fmu interface `state_id` must be declared verbatim by a
grounded `dynamics.states` entry. Every interface requires `source_unit`; use
`unspecified` plus an unknown when the request states the signal but omits its
unit. Every property targeting `state_id` also requires a matching observable
interface with the exact same state_id. An explicit no-collision/no-contact
requirement may be represented by a dimensionless contact interface and an
always-property with upper bound 0.

For capability_tiered mode, repair an incomplete clock without inventing a
start time: use `duration` plus a stated system `frequency_hz` when SOURCE_TEXT
says "for N seconds"; use `start_time`, `stop_time`, and `frequency_hz` only
when those values are stated; otherwise omit the entire clock. Never return a
partial clock.

VALIDATION_ERRORS:
{diagnostics}

SOURCE_TEXT:
{source_text}

PREVIOUS_JSON:
{response}

Return raw JSON only.
"""
