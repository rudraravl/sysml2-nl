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
        profile = """The closed-loop profile uses OpenUSD/Isaac physics as physical-state
owner and a Modelica FMI 2.0 Co-Simulation FMU as controller. Extract explicit
usd_to_fmu observations and fmu_to_usd commands. Do not infer an actuator,
controller, feedback signal, geometry, mass, gravity, or initial condition."""
        clock_extra = ',\n    "physics_substeps": 2'
        parameter_owner = '"owner": "fmu_controller"'
        dynamics_owner = '"owner": "usd_physics"'
        role_examples = """"controllers": [{
    "id": "...", "owner": "fmu_controller", "kind": "PD|PI|PID",
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
    "id": "...", "kind": "fixed_base|rigid_link", "mass": 1.0,
    "mass_unit": "kg", "evidence": ["..."]
  }}],
  "joints": [{{
    "id": "...", "type": "revolute|prismatic", "parent": "entity_id",
    "child": "entity_id", "axis": "X|Y|Z", "lower_limit": 0.0,
    "upper_limit": 1.0, "limit_unit": "deg|rad|m", "evidence": ["..."]
  }}],
  "parameters": [{{
    "id": "...", {parameter_owner}, "joint_id": "...",
    "quantity": "rotational_inertia|mass|stiffness|damping|target_position",
    "value": 1.0, "unit": "kg.m2|kg|N.m/rad|N.m.s/rad|N/m|N.s/m|rad|deg|m",
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


def _repair_prompt(source_text: str, task_id: str, execution_mode: str,
                   response: str,
                   issues: list[NormalizationIssue]) -> str:
    diagnostics = "\n".join(
        f"- [{item.code}] {item.path}: {item.message}" for item in issues
    )
    return f"""Correct the JSON extraction using only SOURCE_TEXT. Do not add a
fact to resolve an error. Delete unsupported facts or put omissions in unknowns.
Evidence must remain exact substrings. Use task_id {task_id!r} and execution_mode
{execution_mode!r}.

VALIDATION_ERRORS:
{diagnostics}

SOURCE_TEXT:
{source_text}

PREVIOUS_JSON:
{response}

Return raw JSON only.
"""
