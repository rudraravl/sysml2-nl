"""Conservative comparison of grounded requirements and artifact evidence."""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import math

from nl2robotics.contracts.units import UnitError, conversion

from .judge import answer_artifact_questions
from .questions import FocusedQuestion, instantiate_questions, question_set_hash
from .repair import build_repair_plan


@dataclass(frozen=True)
class AlignmentContext:
    contract: dict
    contract_report: dict
    hybrid_report: dict

    @property
    def openusd(self) -> dict:
        return (
            self.contract_report.get("openusd", {})
            or self.hybrid_report.get("native_openusd", {})
        )

    @property
    def resolved_mappings(self) -> list[dict]:
        return self.contract_report.get("resolved_mappings", [])

    @property
    def fmu(self) -> dict:
        return self.contract_report.get("fmu", {})


class RoboticsAlignmentEvaluator:
    """Use formal evidence first and a non-blocking LLM judge only as fallback."""

    def evaluate(
        self,
        requirement_ir: dict,
        *,
        modelica: str,
        openusd: str,
        contract: dict,
        hybrid_report: dict,
        ask=None,
    ) -> dict:
        questions = instantiate_questions(requirement_ir)
        context = AlignmentContext(
            contract=contract,
            contract_report=hybrid_report.get("contract", {}),
            hybrid_report=hybrid_report,
        )
        answers = {
            item.id: _deterministic_answer(item, requirement_ir, context)
            for item in questions
        }
        judge_errors: list[dict] = []
        if ask is not None:
            for owner, artifact in (("modelica", modelica), ("openusd", openusd)):
                pending = [
                    item for item in questions
                    if item.owner == owner and answers[item.id]["status"] == "unknown"
                ]
                if not pending:
                    continue
                try:
                    judged = answer_artifact_questions(pending, artifact, owner, ask)
                except Exception as exc:
                    judge_errors.append({"owner": owner, "error": str(exc)})
                    continue
                for item in pending:
                    answers[item.id] = judged[item.id]

        rows = []
        for item in questions:
            artifact_answer = answers[item.id]
            rows.append({
                "question": item.to_dict(),
                "nl": {
                    "status": "satisfied",
                    "source": "grounded_requirement_ir",
                    "confidence": 1.0,
                    "evidence": list(item.evidence),
                },
                "artifact": artifact_answer,
            })

        summary = _summary(rows)
        claim_ready = (
            summary["blocking_violations"] == 0
            and summary["counts"]["unknown"] == 0
            and summary["counts"]["violated"] == 0
        )
        report = {
            "stage": "robotics_semantic_alignment",
            "schema_version": "1.0",
            "task_id": requirement_ir.get("task_id"),
            "passed": summary["blocking_violations"] == 0,
            "artifact_gate_passed": summary["blocking_violations"] == 0,
            "claim_ready": claim_ready,
            "question_set_sha256": question_set_hash(questions),
            "artifact_hashes": {
                "modelica_sha256": hashlib.sha256(modelica.encode("utf-8")).hexdigest(),
                "openusd_sha256": hashlib.sha256(openusd.encode("utf-8")).hexdigest(),
            },
            "selection": {
                "strategy": "grounded_ir_templates",
                "question_count": len(questions),
                "excluded_unknowns": list(requirement_ir.get("unknowns", [])),
                "unknowns_penalized": False,
            },
            "policy": {
                "llm_answers_can_block": False,
                "repair_requires_deterministic_violation": True,
                "unknowns_reduce_coverage_not_score": True,
                "claim_requires_zero_unknown_or_violated_questions": True,
            },
            "summary": summary,
            "judge_errors": judge_errors,
            "rows": rows,
        }
        report["repair_plan"] = build_repair_plan(report)
        return report


def _deterministic_answer(question: FocusedQuestion, ir: dict,
                          context: AlignmentContext) -> dict:
    if question.family == "execution_backend":
        return _execution_backend_answer(question, context)
    if question.family == "timing":
        return _clock_answer(question, ir, context)
    if question.family == "property":
        return _property_answer(question, context)
    if question.family == "interface":
        return _interface_answer(question, context)
    if question.family in {"joint_topology", "joint_axis", "joint_limits"}:
        return _joint_answer(question, ir, context)
    if question.family in {"entity_presence", "entity_mass", "entity_geometry"}:
        return _entity_answer(question, context)
    if question.family == "parameter":
        return _parameter_answer(question, context)
    if question.family == "dynamics":
        return _dynamics_answer(question, context)
    if question.family == "controller_presence":
        return _controller_presence_answer(question, context)
    if question.family == "controller_kind":
        return _controller_kind_answer(question, context)
    if question.family == "actuator":
        return _actuator_answer(question, context)
    if question.family in {"sensor_presence", "sensor_configuration"}:
        return _sensor_answer(question, context)
    if question.family == "environment":
        return _environment_answer(question, context)
    return _answer("unknown", "no deterministic evidence adapter for this fact")


def _execution_backend_answer(question: FocusedQuestion,
                              context: AlignmentContext) -> dict:
    expected = question.expected.get("execution_mode")
    actual = context.contract.get("execution_mode")
    if actual == expected:
        return _answer(
            "satisfied", f"validated contract execution_mode is {actual!r}"
        )
    return _answer(
        "violated", f"required execution_mode {expected!r}, found {actual!r}",
        blocking=True, repair_eligible=True,
    )


def _clock_answer(question: FocusedQuestion, ir: dict,
                  context: AlignmentContext) -> dict:
    clock = context.contract.get("clock")
    required = ir.get("clock")
    if not isinstance(clock, dict) or not isinstance(required, dict):
        return _answer("violated", "contract is missing the required clock",
                       blocking=True, repair_eligible=True)
    try:
        expected = {
            key: float(required[key])
            for key in ("start_time", "stop_time", "duration", "frequency_hz")
            if key in required
        }
        actual = _normalized_clock(clock, expected)
    except (KeyError, TypeError, ValueError, ZeroDivisionError):
        return _answer("violated", "contract clock is incomplete or non-numeric",
                       blocking=True, repair_eligible=True)
    if not expected or set(actual) != set(expected):
        return _answer("violated", "contract clock is incomplete or non-numeric",
                       blocking=True, repair_eligible=True)
    if all(math.isclose(actual[key], expected[key], rel_tol=0.0, abs_tol=1e-9)
           for key in expected):
        return _answer("satisfied", f"validated contract clock {actual}")
    return _answer(
        "violated", f"required clock {expected}, found {actual}",
        blocking=True, repair_eligible=True,
    )


def _normalized_clock(clock: dict, expected: dict) -> dict:
    actual = {}
    if "start_time" in expected:
        actual["start_time"] = float(clock["start_time"])
    if "stop_time" in expected:
        actual["stop_time"] = float(clock["stop_time"])
    if "duration" in expected:
        if "duration" in clock:
            actual["duration"] = float(clock["duration"])
        else:
            actual["duration"] = (
                float(clock["stop_time"]) - float(clock["start_time"])
            )
    if "frequency_hz" in expected:
        if "frequency_hz" in clock:
            actual["frequency_hz"] = float(clock["frequency_hz"])
        else:
            actual["frequency_hz"] = 1.0 / float(clock["step_size"])
    return actual


def _property_answer(question: FocusedQuestion,
                     context: AlignmentContext) -> dict:
    matches = [
        item for item in context.hybrid_report.get("properties", [])
        if item.get("id", item.get("property_id")) == question.subject_id
    ]
    if not matches:
        return _answer("unknown", "no runtime result exists for this property")
    row = matches[0]
    if row.get("status") == "unevaluable":
        return _answer(
            "unknown",
            f"runtime property {question.subject_id} is unevaluable: "
            f"{row.get('detail')}",
        )
    evidence = (
        f"runtime property {question.subject_id}: passed={row.get('passed')}, "
        f"robustness={row.get('robustness')}"
    )
    if row.get("passed") is True:
        return _answer("satisfied", evidence)
    return _answer("violated", evidence, blocking=True, repair_eligible=False)


def _interface_answer(question: FocusedQuestion,
                      context: AlignmentContext) -> dict:
    mapping = _mapping(context, "interface_id", question.subject_id)
    if mapping is None:
        status = "violated" if context.contract_report else "unknown"
        return _answer(
            status, f"no resolved mapping for interface {question.subject_id}",
            blocking=status == "violated", repair_eligible=status == "violated",
        )
    expected = question.expected
    comparisons = {
        "joint_id": mapping.get("semantic_joint_id"),
        "state_id": mapping.get("state_id"),
        "quantity": mapping.get("usd_quantity"),
        "direction": mapping.get("direction"),
        "source_unit": mapping.get("source_unit"),
        "target_unit": mapping.get("target_unit"),
    }
    mismatches = {
        key: (expected[key], comparisons.get(key))
        for key in comparisons if key in expected and comparisons.get(key) != expected[key]
    }
    if ("initial_value" in expected
            and not _close(mapping.get("initial_value"), expected["initial_value"],
                           tolerance=1e-12)):
        mismatches["initial_value"] = (
            expected["initial_value"], mapping.get("initial_value")
        )
    if mismatches:
        return _answer(
            "violated", f"resolved interface mismatch: {mismatches}",
            blocking=True, repair_eligible=True,
        )
    return _answer(
        "satisfied",
        f"resolved {mapping.get('direction')} mapping to "
        f"{mapping.get('usd_joint_path')} and {mapping.get('fmu_variable')}",
    )


def _joint_answer(question: FocusedQuestion, ir: dict,
                  context: AlignmentContext) -> dict:
    mapping = _mapping(context, "semantic_joint_id", question.subject_id)
    if mapping is None:
        return _answer(
            "violated" if context.contract_report else "unknown",
            f"no resolved mapping for joint {question.subject_id}",
            blocking=bool(context.contract_report),
            repair_eligible=bool(context.contract_report),
        )
    path = mapping.get("usd_joint_path")
    detail = next((item for item in context.openusd.get("joint_details", [])
                   if item.get("path") == path), None)
    if detail is None:
        return _answer(
            "violated", f"OpenUSD joint {path!r} was not resolved",
            blocking=True, repair_eligible=True,
        )
    expected = question.expected
    if question.family == "joint_topology":
        actual = {
            "type": detail.get("type"),
            "parent": mapping.get("semantic_parent_entity_id"),
            "child": mapping.get("semantic_child_entity_id"),
        }
        matched = all(actual.get(key) == value for key, value in expected.items())
    elif question.family == "joint_axis":
        actual = {"axis": detail.get("axis")}
        matched = actual == expected
    else:
        joint = next(item for item in ir.get("joints", [])
                     if item.get("id") == question.subject_id)
        target_unit = "deg" if joint.get("type") == "revolute" else "m"
        try:
            unit_conversion = conversion(str(joint["limit_unit"]), target_unit)
            actual = {
                "lower_limit": detail.get("lower_limit"),
                "upper_limit": detail.get("upper_limit"),
                "limit_unit": target_unit,
            }
            required_lower = unit_conversion.apply(float(joint["lower_limit"]))
            required_upper = unit_conversion.apply(float(joint["upper_limit"]))
            matched = (
                _close(actual["lower_limit"], required_lower)
                and _close(actual["upper_limit"], required_upper)
            )
        except (KeyError, TypeError, ValueError, UnitError):
            return _answer("unknown", "joint limit evidence could not be normalized")
    if matched:
        return _answer("satisfied", f"OpenUSD joint evidence at {path}: {actual}")
    return _answer(
        "violated", f"required {expected}, found {actual} at {path}",
        blocking=True, repair_eligible=True,
    )


def _entity_answer(question: FocusedQuestion,
                   context: AlignmentContext) -> dict:
    paths = set()
    for mapping in context.resolved_mappings:
        if mapping.get("semantic_parent_entity_id") == question.subject_id:
            paths.add(mapping.get("usd_parent_prim"))
        if mapping.get("semantic_child_entity_id") == question.subject_id:
            paths.add(mapping.get("usd_driven_prim"))
    paths.discard(None)
    if not paths:
        return _answer("unknown", "entity is not exposed by a resolved interface")
    if question.family == "entity_presence":
        return _answer("satisfied", f"resolved semantic entity to {sorted(paths)}")
    details = {
        item.get("path"): item
        for item in context.openusd.get("rigid_body_details", [])
    }
    if question.family == "entity_mass":
        expected_mass = question.expected.get("mass")
        try:
            mass_conversion = conversion(
                str(question.expected.get("mass_unit", "kg")), "kg"
            )
            expected_mass = mass_conversion.apply(float(expected_mass))
        except (TypeError, ValueError, UnitError):
            return _answer("unknown", "entity mass could not be normalized to kg")
        for path in sorted(paths):
            actual_mass = details.get(path, {}).get("mass")
            if _close(actual_mass, expected_mass):
                return _answer(
                    "satisfied", f"OpenUSD rigid body {path} has mass {actual_mass} kg"
                )
        return _answer(
            "violated",
            f"required mass {expected_mass} kg was not found on {sorted(paths)}",
            blocking=True, repair_eligible=True,
        )
    return _geometry_answer(question, paths, context)


def _geometry_answer(question: FocusedQuestion, paths: set[str],
                     context: AlignmentContext) -> dict:
    collisions = [
        item for item in context.openusd.get("collision_details", [])
        if item.get("parent_rigid_body") in paths
    ]
    if not collisions:
        return _answer("unknown", "no structured collision geometry evidence")
    unit = str(question.expected.get("dimension_unit", "m"))
    try:
        unit_conversion = conversion(unit, "m")
    except UnitError:
        return _answer("unknown", f"unsupported geometry unit {unit!r}")
    expected_shape = str(question.expected.get("shape", "box")).lower()
    shape_aliases = {"cube": "box"}
    box_dimensions = [
        unit_conversion.apply(float(question.expected[key]))
        for key in ("length", "width", "depth")
        if key in question.expected
    ]
    expected_radius = question.expected.get("radius")
    expected_height = question.expected.get("height")
    for item in collisions:
        actual_shape = shape_aliases.get(
            str(item.get("shape", "")).lower(),
            str(item.get("shape", "")).lower(),
        )
        if actual_shape != expected_shape:
            continue
        actual_dimensions = item.get("dimensions")
        if expected_shape == "box" and box_dimensions and isinstance(
            actual_dimensions, list
        ):
            actual = sorted(float(value) for value in actual_dimensions)
            required = sorted(box_dimensions)
            if len(required) == len(actual) and all(
                _close(left, right) for left, right in zip(actual, required)
            ):
                return _answer(
                    "satisfied", f"collision {item.get('path')} dimensions are {actual} m"
                )
        if expected_radius is not None and item.get("radius") is not None:
            required_radius = unit_conversion.apply(float(expected_radius))
            scale = item.get("scale") or [1.0, 1.0, 1.0]
            actual_radius = float(item["radius"]) * max(abs(float(scale[0])),
                                                        abs(float(scale[1])))
            radius_matches = _close(actual_radius, required_radius)
            height_matches = True
            actual_height = None
            if expected_height is not None:
                if item.get("height") is None:
                    height_matches = False
                else:
                    required_height = unit_conversion.apply(float(expected_height))
                    actual_height = float(item["height"]) * abs(float(scale[2]))
                    height_matches = _close(actual_height, required_height)
            if radius_matches and height_matches:
                detail = f"radius {actual_radius} m"
                if actual_height is not None:
                    detail += f" and height {actual_height} m"
                return _answer(
                    "satisfied", f"collision {item.get('path')} has {detail}"
                )
    return _answer(
        "violated",
        f"required geometry {question.expected} was not found on {sorted(paths)}",
        blocking=True, repair_eligible=True,
    )


def _parameter_answer(question: FocusedQuestion,
                      context: AlignmentContext) -> dict:
    variables = [
        item for item in context.fmu.get("variables", [])
        if item.get("causality") == "parameter"
    ]
    expected = question.expected
    names = {_normalized_name(question.subject_id)}
    names.update(_parameter_aliases(str(expected.get("quantity", ""))))
    matches = [item for item in variables if _normalized_name(item.get("name")) in names]
    if not matches:
        return _answer(
            "unknown", f"no FMU parameter metadata matched {sorted(names)}"
        )
    variable = matches[0]
    try:
        expected_value = float(expected["value"])
        unit_conversion = conversion(str(expected["unit"]), str(variable.get("unit")))
        required = unit_conversion.apply(expected_value)
        actual = float(variable["start"])
    except (KeyError, TypeError, ValueError, UnitError):
        return _answer("unknown", "FMU parameter value or unit is not comparable")
    tolerance = max(1e-8, abs(required) * 1e-6)
    if _close(actual, required, tolerance):
        return _answer(
            "satisfied", f"FMU parameter {variable.get('name')}={actual} "
            f"{variable.get('unit')}"
        )
    return _answer(
        "violated", f"required {required} {variable.get('unit')}, FMU parameter "
        f"{variable.get('name')} starts at {actual}",
        blocking=True, repair_eligible=True,
    )


def _dynamics_answer(question: FocusedQuestion,
                     context: AlignmentContext) -> dict:
    owners = {
        item.get("state_id"): item.get("owner")
        for item in context.contract.get("state_ownership", [])
    }
    expected_owner = question.expected.get("owner")
    states = question.expected.get("states", [])
    missing = [state for state in states if owners.get(state) != expected_owner]
    if missing:
        return _answer(
            "violated", f"state ownership mismatch for {missing}; owners={owners}",
            blocking=True, repair_eligible=False,
        )
    return _answer(
        "satisfied", f"contract assigns states {states} to {expected_owner}"
    )


def _controller_presence_answer(question: FocusedQuestion,
                                context: AlignmentContext) -> dict:
    owner = question.expected.get("owner")
    variables = context.fmu.get("variables", [])
    inputs = [item for item in variables if item.get("causality") == "input"]
    outputs = [item for item in variables if item.get("causality") == "output"]
    if owner == "fmu_controller" and inputs and outputs:
        return _answer(
            "satisfied", f"FMU controller exposes {len(inputs)} inputs and "
            f"{len(outputs)} outputs"
        )
    if owner == "fmu_controller" and context.fmu:
        return _answer(
            "violated", "controller FMU lacks validated input/output causality",
            blocking=True, repair_eligible=True,
        )
    return _answer("unknown", "controller presence is not proven by formal metadata")


def _controller_kind_answer(question: FocusedQuestion,
                            context: AlignmentContext) -> dict:
    conformance = context.hybrid_report.get("controller_conformance")
    if not isinstance(conformance, dict):
        return _answer(
            "unknown", "controller behavior has not been exercised by conformance probes"
        )
    expected = str(question.expected.get("kind", "")).upper()
    profile = str(conformance.get("profile", "")).upper()
    profile_matches = expected == "PD" and "PD" in profile
    if conformance.get("success") is True and profile_matches:
        return _answer(
            "satisfied",
            f"{conformance.get('passed_probes')} of "
            f"{conformance.get('probe_count')} behavioral probes match {expected}",
        )
    return _answer(
        "violated",
        conformance.get("error") or (
            f"controller conformance failed for required {expected}: "
            f"{conformance.get('passed_probes')}/{conformance.get('probe_count')} probes"
        ),
        blocking=True,
        repair_eligible=True,
    )


def _actuator_answer(question: FocusedQuestion,
                     context: AlignmentContext) -> dict:
    expected = question.expected
    command = expected.get("command") or expected.get("quantity")
    mapping = next((
        item for item in context.resolved_mappings
        if item.get("semantic_joint_id") == expected.get("joint_id")
        and item.get("direction") == "fmu_to_usd"
        and (command is None or item.get("usd_quantity") == command)
    ), None)
    if mapping:
        return _answer(
            "satisfied", f"resolved actuator command through {mapping.get('id')}"
        )
    status = "violated" if context.contract_report else "unknown"
    return _answer(
        status, f"no resolved actuator mapping for {expected}",
        blocking=status == "violated", repair_eligible=False,
    )


def _sensor_answer(question: FocusedQuestion,
                   context: AlignmentContext) -> dict:
    expected = question.expected
    if question.owner == "openusd":
        details = context.openusd.get("sensor_details", [])
        kind = expected.get("kind") or expected.get("type")
        matches = [
            item for item in details
            if kind is None or _normalized_name(item.get("sensor_type")) == _normalized_name(kind)
        ]
        if not matches:
            status = "violated" if context.contract_report else "unknown"
            return _answer(
                status, f"no OpenUSD sensor matched {expected}",
                blocking=status == "violated", repair_eligible=status == "violated",
            )
        if question.family == "sensor_presence":
            return _answer("satisfied", f"validated OpenUSD sensor {matches[0]}")
        mismatches = {
            key: (value, matches[0].get(key))
            for key, value in expected.items()
            if key in matches[0] and matches[0].get(key) != value
        }
        if mismatches:
            return _answer(
                "violated", f"sensor configuration mismatch: {mismatches}",
                blocking=True, repair_eligible=True,
            )
        return _answer("satisfied", f"validated sensor settings {matches[0]}")
    mapping = next((
        item for item in context.resolved_mappings
        if item.get("direction") == "usd_to_fmu"
        and (expected.get("joint_id") is None
             or item.get("semantic_joint_id") == expected.get("joint_id"))
    ), None)
    if mapping and question.family == "sensor_presence":
        return _answer("satisfied", f"validated observation mapping {mapping.get('id')}")
    return _answer("unknown", "sensor configuration lacks deterministic evidence")


def _environment_answer(question: FocusedQuestion,
                        context: AlignmentContext) -> dict:
    if question.expected.get("kind") != "gravity":
        return _answer("unknown", "no deterministic adapter for this environment kind")
    scenes = context.openusd.get("physics_scene_details", [])
    if not scenes:
        return _answer(
            "violated", "OpenUSD stage has no resolved physics scene",
            blocking=True, repair_eligible=True,
        )
    required = question.expected.get("magnitude")
    actual = scenes[0].get("gravity_magnitude")
    direction = question.expected.get("direction")
    actual_direction = scenes[0].get("gravity_direction")
    direction_matches = direction is None or (
        isinstance(actual_direction, list) and len(actual_direction) == len(direction)
        and all(_close(left, right) for left, right in zip(actual_direction, direction))
    )
    magnitude_matches = required is None or _close(actual, required)
    if magnitude_matches and direction_matches:
        return _answer("satisfied", f"OpenUSD gravity magnitude is {actual} m/s2")
    return _answer(
        "violated", f"required gravity {required} m/s2, found {actual} m/s2",
        blocking=True, repair_eligible=True,
    )


def _mapping(context: AlignmentContext, key: str, value: str) -> dict | None:
    return next(
        (item for item in context.resolved_mappings if item.get(key) == value), None
    )


def _normalized_name(value: object) -> str:
    return "".join(character.lower() for character in str(value or "")
                   if character.isalnum())


def _parameter_aliases(quantity: str) -> set[str]:
    aliases = {
        "proportional_gain": {"kp", "proportionalgain"},
        "derivative_gain": {"kd", "derivativegain"},
        "integral_gain": {"ki", "integralgain"},
        "target_position": {"target", "targetposition", "targetangle"},
        "effort_limit": {"effortlimit", "torquelimit", "forcelimit"},
        "rotational_inertia": {"inertia", "rotationalinertia"},
        "mass": {"mass"},
        "stiffness": {"stiffness", "springconstant"},
        "damping": {"damping", "dampingcoefficient"},
    }
    return aliases.get(quantity, {_normalized_name(quantity)})


def _answer(status: str, diagnostic: str, *, blocking: bool = False,
            repair_eligible: bool = False) -> dict:
    return {
        "status": status,
        "source": "deterministic_evidence",
        "confidence": 1.0 if status != "unknown" else 0.0,
        "evidence": diagnostic,
        "diagnostic": diagnostic,
        "evidence_valid": True,
        "blocking": blocking,
        "repair_eligible": repair_eligible,
    }


def _summary(rows: list[dict]) -> dict:
    counts = {key: 0 for key in (
        "satisfied", "violated", "unknown", "not_applicable"
    )}
    weighted_satisfied = 0.0
    weighted_assessed = 0.0
    blocking = 0
    deterministic_violations = 0
    per_family: dict[str, dict[str, float]] = {}
    for row in rows:
        question = row["question"]
        answer = row["artifact"]
        status = answer["status"]
        counts[status] = counts.get(status, 0) + 1
        weight = float(question["weight"])
        family = per_family.setdefault(question["family"], {
            "satisfied_weight": 0.0, "assessed_weight": 0.0,
        })
        if status in {"satisfied", "violated"}:
            weighted_assessed += weight
            family["assessed_weight"] += weight
            if status == "satisfied":
                weighted_satisfied += weight
                family["satisfied_weight"] += weight
        if answer.get("blocking"):
            blocking += 1
        if status == "violated" and answer.get("source") == "deterministic_evidence":
            deterministic_violations += 1
    total_weight = sum(float(row["question"]["weight"]) for row in rows)
    semantic_score = (
        round(weighted_satisfied / weighted_assessed, 6)
        if weighted_assessed else None
    )
    coverage = round(weighted_assessed / total_weight, 6) if total_weight else 0.0
    family_scores = {
        family: (
            round(values["satisfied_weight"] / values["assessed_weight"], 6)
            if values["assessed_weight"] else None
        )
        for family, values in sorted(per_family.items())
    }
    return {
        "question_count": len(rows),
        "counts": counts,
        "weighted_semantic_score": semantic_score,
        "evidence_coverage": coverage,
        "blocking_violations": blocking,
        "deterministic_violations": deterministic_violations,
        "per_family": family_scores,
    }


def _close(left: object, right: object, tolerance: float = 1e-6) -> bool:
    try:
        return math.isclose(float(left), float(right), rel_tol=0.0, abs_tol=tolerance)
    except (TypeError, ValueError):
        return False
