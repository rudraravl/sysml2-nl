"""Cross-check an FMU and OpenUSD stage against one hybrid contract."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
import json
import math
from pathlib import Path

from nl2robotics.modelica.fmu import FMUInspectionError, inspect_fmu
from nl2robotics.openusd.validator import OpenUSDValidator

from .requirement_ir import is_closed_loop_mode, validate_requirement_ir
from .units import UnitError, canonical_unit, conversion


@dataclass(frozen=True)
class ContractIssue:
    code: str
    message: str
    path: str
    stage: str = "contract"


@dataclass
class ContractValidation:
    task_id: str
    issues: list[ContractIssue] = field(default_factory=list)
    resolved_mappings: list[dict] = field(default_factory=list)
    fmu: dict = field(default_factory=dict)
    openusd: dict = field(default_factory=dict)
    requirement_ir: dict = field(default_factory=dict)

    @property
    def success(self) -> bool:
        return not self.issues

    def to_dict(self) -> dict:
        return {
            "stage": "hybrid_contract",
            "task_id": self.task_id,
            "success": self.success,
            "issues": [asdict(item) for item in self.issues],
            "error_count": len(self.issues),
            "resolved_mappings": self.resolved_mappings,
            "fmu": self.fmu,
            "openusd": self.openusd,
            "requirement_ir": self.requirement_ir,
        }


class HybridContractValidator:
    def __init__(self, *, usd_validator: OpenUSDValidator | None = None):
        self.usd_validator = usd_validator or OpenUSDValidator()

    def validate(self, contract: dict, requirement_ir: dict, *,
                 fmu_path: Path, usd_path: Path,
                 output_dir: Path | None = None) -> ContractValidation:
        issues: list[ContractIssue] = []
        try:
            fmu = inspect_fmu(fmu_path)
        except FMUInspectionError as exc:
            fmu = {}
            issues.append(ContractIssue(
                "invalid_fmu", str(exc), "$.fmu", stage="fmu"
            ))
        usd_validation = self.usd_validator.validate(
            usd_path,
            output_dir=(output_dir / "openusd") if output_dir else None,
        )
        usd = usd_validation.to_dict()
        if not usd_validation.success:
            issues.append(ContractIssue(
                "invalid_openusd",
                "OpenUSD stage must pass syntax and semantic validation",
                "$.openusd",
                stage="openusd",
            ))
        result = self.validate_metadata(contract, requirement_ir, fmu, usd)
        result.issues = issues + result.issues
        return result

    def validate_metadata(self, contract: dict, requirement_ir: dict,
                          fmu: dict, openusd: dict) -> ContractValidation:
        issues: list[ContractIssue] = []
        ir_result = validate_requirement_ir(requirement_ir)
        issues.extend(ContractIssue(
            item.code, item.message, item.path, stage="requirement_ir"
        ) for item in ir_result.issues)
        task_id = str(contract.get("task_id", "")) if isinstance(contract, dict) else ""
        if not isinstance(contract, dict):
            return ContractValidation(task_id, [ContractIssue(
                "invalid_root", "hybrid contract must be an object", "$"
            )])
        if contract.get("schema_version") != "1.0":
            issues.append(ContractIssue(
                "unsupported_schema", "schema_version must be '1.0'", "$.schema_version"
            ))
        if task_id != requirement_ir.get("task_id"):
            issues.append(ContractIssue(
                "task_id_mismatch", "contract and requirement IR task IDs differ", "$.task_id"
            ))
        mode = contract.get("execution_mode")
        if mode != requirement_ir.get("execution_mode"):
            issues.append(ContractIssue(
                "execution_mode_mismatch",
                "contract and requirement IR execution modes differ",
                "$.execution_mode",
            ))

        _validate_fmu_interface(fmu, issues)
        _validate_clock(contract.get("clock"), openusd, issues)
        _validate_coupling(contract.get("coupling"), mode, issues)
        state_owners = _validate_ownership(
            contract.get("state_ownership"), mode, issues
        )
        resolved = _validate_mappings(
            contract.get("mappings"), requirement_ir, fmu, openusd,
            state_owners, mode, issues,
        )
        return ContractValidation(
            task_id=task_id,
            issues=issues,
            resolved_mappings=resolved,
            fmu={
                "fmi_version": fmu.get("fmi_version"),
                "interface_type": fmu.get("interface_type"),
                "model_name": fmu.get("model_name"),
                "model_identifier": fmu.get("model_identifier"),
                "variables": [
                    {
                        "name": _field(item, "name"),
                        "causality": _field(item, "causality"),
                        "variability": _field(item, "variability"),
                        "scalar_type": _field(item, "scalar_type"),
                        "unit": _field(item, "unit"),
                        "start": _field(item, "start"),
                    }
                    for item in fmu.get("variables", [])
                ],
            },
            openusd={
                "success": openusd.get("success"),
                "metadata": openusd.get("metadata", {}),
                "articulations": openusd.get("evidence", {}).get(
                    "articulations", []
                ),
                "physics_scene_details": openusd.get("evidence", {}).get(
                    "physics_scene_details", []
                ),
                "rigid_body_details": openusd.get("evidence", {}).get(
                    "rigid_body_details", []
                ),
                "joint_details": openusd.get("evidence", {}).get("joint_details", []),
                "collision_details": openusd.get("evidence", {}).get(
                    "collision_details", []
                ),
                "sensor_details": openusd.get("evidence", {}).get(
                    "sensor_details", []
                ),
                "material_details": openusd.get("evidence", {}).get(
                    "material_details", []
                ),
            },
            requirement_ir=ir_result.to_dict(),
        )


def load_json(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return data


def _validate_fmu_interface(fmu: dict, issues: list[ContractIssue]) -> None:
    if fmu.get("fmi_version") != "2.0":
        issues.append(ContractIssue(
            "unsupported_fmi_version", "hybrid execution requires FMI 2.0", "$.fmu"
        ))
    if fmu.get("interface_type") != "co_simulation":
        issues.append(ContractIssue(
            "wrong_fmi_interface",
            "hybrid execution requires a Co-Simulation FMU",
            "$.fmu",
        ))


def _validate_clock(clock: object, openusd: dict,
                    issues: list[ContractIssue]) -> None:
    if not isinstance(clock, dict):
        issues.append(ContractIssue("missing_clock", "clock must be an object", "$.clock"))
        return
    try:
        start = float(clock["start_time"])
        stop = float(clock["stop_time"])
        step = float(clock["step_size"])
        time_codes = float(clock["time_codes_per_second"])
    except (KeyError, TypeError, ValueError):
        issues.append(ContractIssue(
            "invalid_clock", "clock fields must be numeric", "$.clock"
        ))
        return
    if not all(math.isfinite(value) for value in (start, stop, step, time_codes)):
        issues.append(ContractIssue(
            "non_finite_clock", "clock fields must be finite", "$.clock"
        ))
        return
    if stop <= start or step <= 0 or time_codes <= 0:
        issues.append(ContractIssue(
            "invalid_clock_range",
            "clock requires stop > start and positive step/rate",
            "$.clock",
        ))
    duration_steps = (stop - start) / step if step > 0 else 0.0
    if step > 0 and abs(duration_steps - round(duration_steps)) > 1e-9:
        issues.append(ContractIssue(
            "fractional_final_step",
            "simulation duration must be an integer number of communication steps",
            "$.clock",
        ))
    samples_per_step = step * time_codes
    if abs(samples_per_step - round(samples_per_step)) > 1e-9:
        issues.append(ContractIssue(
            "incommensurate_clock",
            "step_size * time_codes_per_second must be an integer",
            "$.clock",
        ))
    usd_rate = openusd.get("metadata", {}).get("time_codes_per_second")
    try:
        usd_rate_value = float(usd_rate)
    except (TypeError, ValueError):
        usd_rate_value = math.nan
    if (not math.isfinite(usd_rate_value)
            or abs(usd_rate_value - time_codes) > 1e-9):
        issues.append(ContractIssue(
            "usd_clock_mismatch",
            "contract time-code rate differs from the OpenUSD stage",
            "$.clock.time_codes_per_second",
        ))


def _validate_coupling(coupling: object, mode: object,
                       issues: list[ContractIssue]) -> None:
    if not is_closed_loop_mode(mode):
        if coupling is not None:
            issues.append(ContractIssue(
                "unexpected_coupling",
                "coupling configuration is reserved for closed-loop execution",
                "$.coupling",
            ))
        return
    if not isinstance(coupling, dict):
        issues.append(ContractIssue(
            "missing_coupling",
            "closed-loop execution requires an explicit coupling configuration",
            "$.coupling",
        ))
        return
    expected = {
        "algorithm": "sampled_data_sequential",
        "hold": "zero_order",
        "observation_phase": "step_start",
        "command_phase": "before_physics_step",
    }
    for key, value in expected.items():
        if coupling.get(key) != value:
            issues.append(ContractIssue(
                "unsupported_coupling_semantics",
                f"{key} must be {value!r} for the H2 MVP",
                f"$.coupling.{key}",
            ))
    substeps = coupling.get("physics_substeps")
    if not isinstance(substeps, int) or isinstance(substeps, bool) or substeps < 1:
        issues.append(ContractIssue(
            "invalid_physics_substeps",
            "physics_substeps must be a positive integer",
            "$.coupling.physics_substeps",
        ))


def _validate_ownership(rows: object, mode: object,
                        issues: list[ContractIssue]) -> dict[str, str]:
    if not isinstance(rows, list) or not rows:
        issues.append(ContractIssue(
            "missing_state_ownership",
            "state_ownership must declare at least one physical state",
            "$.state_ownership",
        ))
        return {}
    expected_owner = {
        "portable_fmu_kinematic": "fmu_plant",
        "isaac_closed_loop": "usd_physics",
        "newton_closed_loop": "usd_physics",
    }.get(mode)
    state_owners: dict[str, str] = {}
    for index, row in enumerate(rows):
        path = f"$.state_ownership[{index}]"
        if not isinstance(row, dict):
            issues.append(ContractIssue("invalid_owner", "owner must be an object", path))
            continue
        state_id = row.get("state_id")
        if not isinstance(state_id, str) or not state_id:
            issues.append(ContractIssue("missing_state_id", "state_id is required", path))
        elif state_id in state_owners:
            issues.append(ContractIssue(
                "duplicate_state_owner", f"state {state_id!r} has multiple owners", path
            ))
        else:
            state_owners[state_id] = str(row.get("owner", ""))
        if row.get("kind") == "physical" and expected_owner and row.get("owner") != expected_owner:
            issues.append(ContractIssue(
                "invalid_physical_owner",
                f"{mode} requires physical state owner {expected_owner}",
                f"{path}.owner",
            ))
    return state_owners


def _validate_mappings(rows: object, requirement_ir: dict, fmu: dict,
                       openusd: dict, state_owners: dict[str, str], mode: object,
                       issues: list[ContractIssue]) -> list[dict]:
    if not isinstance(rows, list) or not rows:
        issues.append(ContractIssue(
            "missing_mappings", "mappings must be a non-empty list", "$.mappings"
        ))
        return []
    variables = {_field(item, "name"): item for item in fmu.get("variables", [])}
    joint_details = {
        item.get("path"): item
        for item in openusd.get("evidence", {}).get("joint_details", [])
    }
    body_details = {
        item.get("path"): item
        for item in openusd.get("evidence", {}).get("rigid_body_details", [])
    }
    ir_joints = {
        item.get("id"): item for item in requirement_ir.get("joints", [])
        if isinstance(item, dict)
    }
    ir_entities = {
        item.get("id"): item for item in requirement_ir.get("entities", [])
        if isinstance(item, dict)
    }
    effort_limits = {
        item.get("joint_id"): item
        for item in requirement_ir.get("parameters", [])
        if isinstance(item, dict) and item.get("quantity") == "effort_limit"
    }
    ir_interfaces = {
        item.get("id"): item for item in requirement_ir.get("interfaces", [])
        if isinstance(item, dict) and item.get("required", True)
    }
    required_interfaces = set(ir_interfaces)
    mapped_interfaces: set[str] = set()
    mapped_targets: set[tuple] = set()
    resolved = []
    _validate_fixed_base_anchors(
        rows,
        ir_entities,
        joint_details,
        set(openusd.get("evidence", {}).get("articulations", [])),
        mode,
        issues,
    )
    _validate_environment(requirement_ir, openusd, mode, issues)
    for index, row in enumerate(rows):
        path = f"$.mappings[{index}]"
        if not isinstance(row, dict):
            issues.append(ContractIssue("invalid_mapping", "mapping must be an object", path))
            continue
        interface_id = row.get("interface_id")
        mapped_interfaces.add(interface_id)
        if interface_id not in required_interfaces:
            issues.append(ContractIssue(
                "unknown_interface", f"unknown IR interface {interface_id!r}",
                f"{path}.interface_id",
            ))
        else:
            _validate_ir_interface_mapping(
                row, ir_interfaces[interface_id], path, issues
            )
        semantic_joint_id = row.get("semantic_joint_id")
        ir_joint = ir_joints.get(semantic_joint_id)
        if ir_joint is None:
            issues.append(ContractIssue(
                "unknown_semantic_joint",
                f"unknown IR joint {semantic_joint_id!r}",
                f"{path}.semantic_joint_id",
            ))
        state_id = row.get("state_id")
        if state_id not in state_owners:
            issues.append(ContractIssue(
                "unknown_state", f"mapping references unowned state {state_id!r}",
                f"{path}.state_id",
            ))
        elif row.get("owner") != state_owners[state_id]:
            issues.append(ContractIssue(
                "mapping_owner_mismatch",
                f"mapping owner {row.get('owner')!r} differs from state owner "
                f"{state_owners[state_id]!r}",
                f"{path}.owner",
            ))
        direction = row.get("direction")
        if direction not in {"fmu_to_usd", "usd_to_fmu"}:
            issues.append(ContractIssue(
                "invalid_direction", "unsupported mapping direction", f"{path}.direction"
            ))
        if mode == "portable_fmu_kinematic" and direction != "fmu_to_usd":
            issues.append(ContractIssue(
                "invalid_portable_direction",
                "portable FMU-owned playback permits only fmu_to_usd mappings",
                f"{path}.direction",
            ))
        if (mode == "portable_fmu_kinematic"
                and row.get("usd_quantity") != "joint_position"):
            issues.append(ContractIssue(
                "invalid_portable_quantity",
                "portable playback supports joint_position mappings only",
                f"{path}.usd_quantity",
            ))

        variable_name = row.get("fmu_variable")
        variable = variables.get(variable_name)
        if variable is None:
            issues.append(ContractIssue(
                "missing_fmu_variable", f"FMU variable {variable_name!r} does not exist",
                f"{path}.fmu_variable", stage="fmu",
            ))
        else:
            expected_causality = "output" if direction == "fmu_to_usd" else "input"
            if _field(variable, "causality") != expected_causality:
                issues.append(ContractIssue(
                    "causality_mismatch",
                    f"{direction} requires FMI causality {expected_causality}",
                    f"{path}.fmu_variable",
                    stage="fmu",
                ))
            if _field(variable, "scalar_type") != "real":
                issues.append(ContractIssue(
                    "non_real_signal", "hybrid numeric mappings require FMI Real",
                    f"{path}.fmu_variable", stage="fmu",
                ))

        source_unit = row.get("source_unit")
        target_unit = row.get("target_unit")
        numeric_tolerance = row.get("numeric_tolerance")
        if (not _finite_number(numeric_tolerance)
                or float(numeric_tolerance) <= 0):
            issues.append(ContractIssue(
                "invalid_numeric_tolerance",
                "numeric_tolerance must be a positive value in target units",
                f"{path}.numeric_tolerance",
            ))
        initial_value = row.get("initial_value")
        initial_required = (
            mode == "portable_fmu_kinematic" or direction == "usd_to_fmu"
        )
        if initial_required and not _finite_number(initial_value):
            issues.append(ContractIssue(
                "invalid_initial_value",
                "initial_value must be numeric in source units",
                f"{path}.initial_value",
            ))
        elif initial_value is not None and not _finite_number(initial_value):
            issues.append(ContractIssue(
                "invalid_initial_value",
                "initial_value must be numeric when supplied",
                f"{path}.initial_value",
            ))
        command_lower = row.get("command_lower")
        command_upper = row.get("command_upper")
        if (is_closed_loop_mode(mode) and direction == "fmu_to_usd"
                and row.get("usd_quantity") == "joint_effort"):
            limit_record = effort_limits.get(semantic_joint_id)
            if limit_record is None:
                issues.append(ContractIssue(
                    "missing_effort_limit",
                    "effort-commanded H2 joints require a grounded effort_limit",
                    f"{path}.command_upper",
                ))
            else:
                try:
                    limit = conversion(
                        str(limit_record.get("unit")), str(target_unit)
                    ).apply(float(limit_record.get("value")))
                except (TypeError, ValueError, UnitError) as exc:
                    issues.append(ContractIssue(
                        "invalid_effort_limit", str(exc),
                        f"{path}.command_upper",
                    ))
                else:
                    tolerance = (
                        float(numeric_tolerance)
                        if _finite_number(numeric_tolerance) else 0.0
                    )
                    if (not _finite_number(command_lower)
                            or not _finite_number(command_upper)):
                        issues.append(ContractIssue(
                            "missing_command_bounds",
                            "H2 effort mappings require finite command bounds",
                            f"{path}.command_lower",
                        ))
                    elif (not math.isclose(float(command_lower), -limit,
                                           rel_tol=0.0, abs_tol=tolerance)
                          or not math.isclose(float(command_upper), limit,
                                              rel_tol=0.0, abs_tol=tolerance)):
                        issues.append(ContractIssue(
                            "command_bound_mismatch",
                            f"grounded effort bounds are {-limit} to {limit} "
                            f"{target_unit}, found {command_lower} to {command_upper}",
                            f"{path}.command_lower",
                        ))
                    elif float(command_lower) >= float(command_upper):
                        issues.append(ContractIssue(
                            "invalid_command_bounds",
                            "command_lower must be less than command_upper",
                            f"{path}.command_lower",
                        ))
        unit_result = None
        try:
            unit_result = conversion(str(source_unit), str(target_unit))
        except UnitError as exc:
            issues.append(ContractIssue("unit_mismatch", str(exc), f"{path}.source_unit"))
        if variable is not None:
            fmu_unit = _field(variable, "unit")
            fmu_contract_field = (
                "source_unit" if direction == "fmu_to_usd" else "target_unit"
            )
            fmu_contract_unit = row.get(fmu_contract_field)
            if (not fmu_unit or canonical_unit(str(fmu_unit))
                    != canonical_unit(str(fmu_contract_unit))):
                issues.append(ContractIssue(
                    "fmu_unit_mismatch",
                    f"FMU declares {fmu_unit!r}, contract declares "
                    f"{fmu_contract_unit!r} on the FMU side",
                    f"{path}.{fmu_contract_field}",
                    stage="fmu",
                ))

        joint_path = row.get("usd_joint_path")
        joint = joint_details.get(joint_path)
        if joint is None:
            issues.append(ContractIssue(
                "missing_usd_joint", f"USD joint {joint_path!r} does not exist",
                f"{path}.usd_joint_path", stage="openusd",
            ))
        else:
            if row.get("axis") != joint.get("axis"):
                issues.append(ContractIssue(
                    "joint_axis_mismatch",
                    f"contract axis {row.get('axis')!r} differs from USD axis "
                    f"{joint.get('axis')!r}",
                    f"{path}.axis", stage="openusd",
                ))
            driven_prim = row.get("usd_driven_prim")
            if driven_prim not in joint.get("body1", []):
                issues.append(ContractIssue(
                    "driven_prim_mismatch",
                    "usd_driven_prim must be the joint body1 target",
                    f"{path}.usd_driven_prim", stage="openusd",
                ))
            if row.get("usd_parent_prim") not in joint.get("body0", []):
                issues.append(ContractIssue(
                    "parent_prim_mismatch",
                    "usd_parent_prim must be the joint body0 target",
                    f"{path}.usd_parent_prim", stage="openusd",
                ))
            _validate_target_quantity(row, joint, path, mode, issues)
            if ir_joint is not None:
                _validate_joint_consistency(
                    row, ir_joint, ir_entities, joint, body_details,
                    mode, path, issues,
                )

        target_key = (joint_path, row.get("usd_quantity"), direction)
        if target_key in mapped_targets:
            issues.append(ContractIssue(
                "duplicate_target_mapping", "multiple mappings drive the same USD quantity",
                path,
            ))
        mapped_targets.add(target_key)
        if variable is not None and joint is not None and unit_result is not None:
            resolved.append({
                "id": row.get("id"),
                "interface_id": interface_id,
                "state_id": state_id,
                "semantic_joint_id": semantic_joint_id,
                "semantic_parent_entity_id": row.get("semantic_parent_entity_id"),
                "semantic_child_entity_id": row.get("semantic_child_entity_id"),
                "owner": row.get("owner"),
                "direction": direction,
                "fmu_variable": variable_name,
                "fmu_value_reference": _field(variable, "value_reference"),
                "usd_joint_path": joint_path,
                "usd_parent_prim": row.get("usd_parent_prim"),
                "usd_driven_prim": row.get("usd_driven_prim"),
                "usd_quantity": row.get("usd_quantity"),
                "joint_type": joint.get("type"),
                "source_unit": row.get("source_unit"),
                "target_unit": row.get("target_unit"),
                "axis": row.get("axis"),
                "lower_limit": joint.get("lower_limit"),
                "upper_limit": joint.get("upper_limit"),
                "scale": unit_result.scale,
                "offset": unit_result.offset,
                "interpolation": row.get("interpolation"),
                "numeric_tolerance": numeric_tolerance,
                "initial_value": initial_value,
                "command_lower": command_lower,
                "command_upper": command_upper,
            })
    for missing in sorted(required_interfaces - mapped_interfaces):
        issues.append(ContractIssue(
            "unmapped_required_interface",
            f"required IR interface {missing!r} has no contract mapping",
            "$.mappings",
        ))
    if is_closed_loop_mode(mode):
        _validate_closed_loop_mappings(rows, issues)
    return resolved


def _validate_ir_interface_mapping(row: dict, interface: dict, path: str,
                                   issues: list[ContractIssue]) -> None:
    expected = {
        "semantic_joint_id": interface.get("joint_id"),
        "state_id": interface.get("state_id"),
        "direction": interface.get("direction"),
        "usd_quantity": interface.get("quantity"),
        "source_unit": interface.get("source_unit"),
    }
    if interface.get("target_unit") is not None:
        expected["target_unit"] = interface.get("target_unit")
    mismatches = {
        key: {"expected": value, "actual": row.get(key)}
        for key, value in expected.items() if row.get(key) != value
    }
    if "initial_value" in interface:
        if (not _finite_number(row.get("initial_value"))
                or not math.isclose(
                    float(row["initial_value"]),
                    float(interface["initial_value"]),
                    rel_tol=0.0,
                    abs_tol=1e-12,
                )):
            mismatches["initial_value"] = {
                "expected": interface["initial_value"],
                "actual": row.get("initial_value"),
            }
    if mismatches:
        issues.append(ContractIssue(
            "ir_interface_mismatch",
            f"contract mapping differs from grounded interface: {mismatches}",
            path,
            stage="cross_profile",
        ))


def _validate_fixed_base_anchors(rows: list[dict], ir_entities: dict,
                                 joint_details: dict,
                                 articulation_roots: set[str], mode: object,
                                 issues: list[ContractIssue]) -> None:
    if not is_closed_loop_mode(mode):
        return
    semantic_to_usd: dict[str, set[str]] = {}
    for row in rows:
        if not isinstance(row, dict):
            continue
        entity_id = row.get("semantic_parent_entity_id")
        prim_path = row.get("usd_parent_prim")
        if isinstance(entity_id, str) and isinstance(prim_path, str):
            semantic_to_usd.setdefault(entity_id, set()).add(prim_path)
    for entity_id, entity in ir_entities.items():
        if entity.get("kind") != "fixed_base":
            continue
        paths = semantic_to_usd.get(entity_id, set())
        if len(paths) != 1:
            issues.append(ContractIssue(
                "ambiguous_fixed_base_mapping",
                f"fixed base {entity_id!r} must map to exactly one USD prim",
                "$.mappings",
                stage="cross_profile",
            ))
            continue
        body_path = next(iter(paths))
        anchors = [
            joint for joint in joint_details.values()
            if joint.get("type") == "fixed"
            and body_path in [*joint.get("body0", []), *joint.get("body1", [])]
            and (not joint.get("body0") or not joint.get("body1"))
        ]
        rooted = [
            joint for joint in anchors
            if joint.get("path") in articulation_roots
        ]
        if not rooted:
            issues.append(ContractIssue(
                "unanchored_fixed_base",
                f"USD prim {body_path!r} must be fixed to the world by the "
                "articulation-root joint",
                "$.mappings",
                stage="openusd",
            ))


def _validate_environment(requirement_ir: dict, openusd: dict, mode: object,
                          issues: list[ContractIssue]) -> None:
    if not is_closed_loop_mode(mode):
        return
    gravity = [
        row for row in requirement_ir.get("environment", [])
        if isinstance(row, dict) and row.get("kind") == "gravity"
    ]
    if not gravity:
        return
    scenes = openusd.get("evidence", {}).get("physics_scene_details", [])
    if len(scenes) != 1:
        issues.append(ContractIssue(
            "ambiguous_gravity_scene",
            "a grounded gravity requirement needs exactly one physics scene",
            "$.openusd",
            stage="openusd",
        ))
        return
    expected = gravity[0]
    try:
        magnitude = conversion(str(expected.get("unit")), "m/s2").apply(
            float(expected.get("magnitude"))
        )
    except (TypeError, ValueError, UnitError) as exc:
        issues.append(ContractIssue(
            "invalid_gravity_requirement", str(exc), "$.environment",
            stage="requirement_ir",
        ))
        return
    actual = scenes[0].get("gravity_magnitude")
    try:
        actual_value = float(actual)
    except (TypeError, ValueError):
        actual_value = math.nan
    if (not math.isfinite(magnitude) or not math.isfinite(actual_value)
            or abs(actual_value - magnitude) > 1e-9):
        issues.append(ContractIssue(
            "gravity_mismatch",
            f"required gravity magnitude {magnitude} m/s2 differs from USD "
            f"{actual!r}",
            "$.openusd",
            stage="cross_profile",
        ))


def _validate_target_quantity(row: dict, joint: dict, path: str,
                              mode: object,
                              issues: list[ContractIssue]) -> None:
    joint_type = joint.get("type")
    quantity = row.get("usd_quantity")
    direction = row.get("direction")
    simulator_field = "target_unit" if direction == "fmu_to_usd" else "source_unit"
    simulator_unit = canonical_unit(str(row.get(simulator_field)))
    expected_units = {
        ("revolute", "joint_position"): (
            "deg" if mode == "portable_fmu_kinematic" else "rad"
        ),
        ("revolute", "joint_velocity"): "rad/s",
        ("revolute", "joint_effort"): "N.m",
        ("prismatic", "joint_position"): "m",
        ("prismatic", "joint_velocity"): "m/s",
        ("prismatic", "joint_effort"): "N",
    }
    expected = expected_units.get((joint_type, quantity))
    if expected is not None and simulator_unit != expected:
        issues.append(ContractIssue(
            "invalid_simulator_unit",
            f"{joint_type} {quantity} uses {expected} at the simulator API boundary",
            f"{path}.{simulator_field}",
            stage="openusd",
        ))
    if quantity not in {"joint_position", "joint_velocity", "joint_effort"}:
        issues.append(ContractIssue(
            "unsupported_usd_quantity", f"unsupported USD quantity {quantity!r}",
            f"{path}.usd_quantity", stage="openusd",
        ))


def _validate_closed_loop_mappings(rows: list[dict],
                                   issues: list[ContractIssue]) -> None:
    feedback = [row for row in rows if isinstance(row, dict)
                and row.get("direction") == "usd_to_fmu"]
    commands = [row for row in rows if isinstance(row, dict)
                and row.get("direction") == "fmu_to_usd"]
    if not feedback:
        issues.append(ContractIssue(
            "missing_feedback_mapping",
            "closed-loop execution requires at least one USD-to-FMU observation",
            "$.mappings",
        ))
    if not commands:
        issues.append(ContractIssue(
            "missing_command_mapping",
            "closed-loop execution requires at least one FMU-to-USD command",
            "$.mappings",
        ))
    command_joints: set[str] = set()
    for index, row in enumerate(rows):
        if not isinstance(row, dict) or row.get("direction") != "fmu_to_usd":
            continue
        joint = str(row.get("usd_joint_path"))
        if joint in command_joints:
            issues.append(ContractIssue(
                "multiple_joint_command_modes",
                "H2 MVP permits exactly one command mapping per joint",
                f"$.mappings[{index}]",
            ))
        command_joints.add(joint)
        if row.get("interpolation") != "zero_order":
            issues.append(ContractIssue(
                "invalid_command_hold",
                "closed-loop commands require zero_order interpolation",
                f"$.mappings[{index}].interpolation",
            ))


def _validate_joint_consistency(row: dict, ir_joint: dict, ir_entities: dict,
                                usd_joint: dict, body_details: dict,
                                mode: object, path: str,
                                issues: list[ContractIssue]) -> None:
    if ir_joint.get("type") != usd_joint.get("type"):
        issues.append(ContractIssue(
            "joint_type_mismatch",
            f"IR joint type {ir_joint.get('type')!r} differs from USD type "
            f"{usd_joint.get('type')!r}",
            f"{path}.semantic_joint_id",
            stage="cross_profile",
        ))
    if ir_joint.get("axis") != usd_joint.get("axis"):
        issues.append(ContractIssue(
            "ir_usd_axis_mismatch",
            "requirement IR and OpenUSD joint axes differ",
            f"{path}.semantic_joint_id",
            stage="cross_profile",
        ))
    target_limit_unit = "deg" if ir_joint.get("type") == "revolute" else "m"
    limit_conversion = None
    try:
        limit_conversion = conversion(
            str(ir_joint.get("limit_unit")), target_limit_unit
        )
    except UnitError as exc:
        issues.append(ContractIssue(
            "joint_limit_unit_mismatch", str(exc),
            f"{path}.semantic_joint_id", stage="cross_profile",
        ))
    for ir_key, usd_key in (("lower_limit", "lower_limit"),
                            ("upper_limit", "upper_limit")):
        ir_value = ir_joint.get(ir_key)
        usd_value = usd_joint.get(usd_key)
        try:
            if ir_value is not None and limit_conversion is not None:
                ir_value = limit_conversion.apply(float(ir_value))
            tolerance = float(row.get("numeric_tolerance", 1e-6))
            values_valid = (
                ir_value is None
                or (
                    usd_value is not None
                    and math.isfinite(float(ir_value))
                    and math.isfinite(float(usd_value))
                    and math.isfinite(tolerance)
                )
            )
        except (TypeError, ValueError):
            values_valid = False
            tolerance = math.nan
        if ir_value is not None and (
            not values_valid or abs(float(ir_value) - float(usd_value)) > tolerance
        ):
            issues.append(ContractIssue(
                "joint_limit_mismatch",
                f"IR {ir_key} {ir_value!r} differs from USD {usd_value!r}",
                f"{path}.semantic_joint_id",
                stage="cross_profile",
            ))

    if ir_joint.get("parent") != row.get("semantic_parent_entity_id"):
        issues.append(ContractIssue(
            "semantic_parent_mismatch",
            "mapping parent entity differs from the IR joint parent",
            f"{path}.semantic_parent_entity_id",
            stage="cross_profile",
        ))
    child_id = row.get("semantic_child_entity_id")
    if ir_joint.get("child") != child_id:
        issues.append(ContractIssue(
            "semantic_child_mismatch",
            "mapping child entity differs from the IR joint child",
            f"{path}.semantic_child_entity_id",
            stage="cross_profile",
        ))
    body = body_details.get(row.get("usd_driven_prim"))
    child = ir_entities.get(child_id, {})
    if body is None:
        issues.append(ContractIssue(
            "missing_driven_body",
            "driven prim must have UsdPhysics RigidBodyAPI",
            f"{path}.usd_driven_prim",
            stage="openusd",
        ))
        return
    if mode == "portable_fmu_kinematic" and not body.get("kinematic_enabled"):
        issues.append(ContractIssue(
            "non_kinematic_playback_body",
            "portable FMU-owned playback requires a kinematic driven body",
            f"{path}.usd_driven_prim",
            stage="openusd",
        ))
    if is_closed_loop_mode(mode) and body.get("kinematic_enabled"):
        issues.append(ContractIssue(
            "kinematic_closed_loop_body",
            "closed-loop execution requires USD physics to own a dynamic driven body",
            f"{path}.usd_driven_prim",
            stage="openusd",
        ))
    if (is_closed_loop_mode(mode)
            and row.get("direction") == "fmu_to_usd"
            and row.get("usd_quantity") == "joint_effort"
            and usd_joint.get("drives")):
        issues.append(ContractIssue(
            "effort_drive_conflict",
            "effort-commanded joints must not have an authored position or velocity drive",
            f"{path}.usd_joint_path",
            stage="openusd",
        ))
    expected_mass = child.get("mass")
    if expected_mass is not None:
        try:
            expected_mass = conversion(
                str(child.get("mass_unit")), "kg"
            ).apply(float(expected_mass))
        except (TypeError, ValueError, UnitError) as exc:
            issues.append(ContractIssue(
                "body_mass_unit_mismatch", str(exc),
                f"{path}.semantic_child_entity_id", stage="cross_profile",
            ))
            expected_mass = None
    body_mass = body.get("mass")
    try:
        mass_matches = (
            expected_mass is None
            or (
                body_mass is not None
                and math.isfinite(float(expected_mass))
                and math.isfinite(float(body_mass))
                and abs(float(expected_mass) - float(body_mass)) <= 1e-9
            )
        )
    except (TypeError, ValueError):
        mass_matches = False
    if expected_mass is not None and not mass_matches:
        issues.append(ContractIssue(
            "body_mass_mismatch",
            f"IR mass {expected_mass!r} differs from USD mass {body.get('mass')!r}",
            f"{path}.usd_driven_prim",
            stage="cross_profile",
        ))


def _field(item: object, name: str):
    if isinstance(item, dict):
        return item.get(name)
    return getattr(item, name, None)


def _finite_number(value: object) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )
