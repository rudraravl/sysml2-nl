"""Capability vocabulary and honest verification tiers for broad robotics tasks.

The original articulated profile remains the strict CUDA-executable subset.
This module describes the wider language accepted by the shared IR and routes a
request to one or more named profiles without pretending every feature has the
same runtime evidence.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass


BROAD_JOINT_TYPES = frozenset({
    "revolute", "continuous", "prismatic", "fixed", "spherical", "ball",
    "free", "floating", "distance", "d6", "planar", "screw", "gear",
    "universal", "mimic", "tendon", "cable",
})
BROAD_JOINT_AXES = frozenset({"X", "Y", "Z", "arbitrary", "multi_axis", "none"})
BROAD_LINK_SHAPES = frozenset({
    "box", "sphere", "cylinder", "capsule", "cone", "plane", "mesh",
    "convex_mesh", "heightfield", "compound", "unspecified",
})
BROAD_CONTROLLER_KINDS = frozenset({
    "P", "PI", "PD", "PID", "feedforward", "state_feedback", "trajectory",
    "computed_torque", "impedance", "admittance", "operational_space",
    "differential_drive", "ackermann", "quadrotor", "mpc", "custom",
})
BROAD_INTERFACE_QUANTITIES = frozenset({
    "joint_position", "joint_velocity", "joint_acceleration", "joint_effort",
    "joint_position_target", "joint_velocity_target", "joint_effort_target",
    "base_pose", "base_twist", "base_acceleration", "body_pose", "body_twist",
    "wheel_speed", "wheel_torque", "steering_angle", "thrust", "body_wrench",
    "contact_force", "contact_state", "distance", "range", "imu_acceleration",
    "imu_angular_velocity", "encoder_position", "encoder_velocity",
    "camera_frame", "lidar_scan", "point_cloud", "gps_position", "odometry",
    "temperature", "pressure", "flow", "voltage", "current", "custom_signal",
    "fluid_pressure", "fluid_flow", "motor_torque", "motor_speed", "battery_state",
    "strain", "deformation", "tendon_tension",
})
BROAD_PROPERTY_KINDS = frozenset({
    "always", "eventually", "final", "until", "response", "reach_avoid",
    "settling_time", "overshoot", "energy", "collision_free", "custom",
})


TIER_NAMES = {
    0: "normalized",
    1: "ir_validated",
    2: "artifacts_validated",
    3: "executable_contract_validated",
    4: "behaviorally_executed",
    5: "accelerator_provenance_verified",
}


@dataclass(frozen=True)
class ProfileAssessment:
    profile_id: str
    applicable: bool
    maximum_supported_tier: int
    status: str
    matched_features: tuple[str, ...]
    blockers: tuple[str, ...]

    def to_dict(self) -> dict:
        data = asdict(self)
        data["maximum_supported_tier_name"] = TIER_NAMES[self.maximum_supported_tier]
        return data


def requested_features(ir: dict) -> tuple[str, ...]:
    """Return deterministic feature labels used by routing and study reports."""
    features: set[str] = set()
    entities = [row for row in ir.get("entities", []) if isinstance(row, dict)]
    joints = [row for row in ir.get("joints", []) if isinstance(row, dict)]
    controllers = [row for row in ir.get("controllers", []) if isinstance(row, dict)]
    sensors = [row for row in ir.get("sensors", []) if isinstance(row, dict)]
    environment = [row for row in ir.get("environment", []) if isinstance(row, dict)]
    interfaces = [row for row in ir.get("interfaces", []) if isinstance(row, dict)]

    domain_aliases = {
        "mobile_robotics": "mobile", "aerial_robotics": "aerial",
        "legged_robotics": "legged", "marine_robotics": "marine",
        "soft_robotics": "soft_robotics", "fluid_power": "fluid_power",
        "electromechanical": "electromechanical", "multi_robot": "multi_robot",
        "sensing": "sensing", "contact": "contact_environment",
        "trajectory_control": "trajectory_or_coupled_control",
    }
    for row in ir.get("domains", []):
        if not isinstance(row, dict):
            continue
        kind = str(row.get("kind", "unknown")).lower()
        features.add(f"domain:{domain_aliases.get(kind, kind)}")

    for row in joints:
        features.add(f"joint:{str(row.get('type', 'unknown')).lower()}")
        axis = row.get("axis")
        if axis:
            features.add(f"axis:{axis}")
    for row in entities:
        features.add(f"entity:{str(row.get('kind', 'unknown')).lower()}")
        if row.get("shape"):
            features.add(f"geometry:{str(row['shape']).lower()}")
    for row in controllers:
        features.add(f"controller:{str(row.get('kind', 'unknown')).upper()}")
    for row in sensors:
        features.add(f"sensor:{str(row.get('kind', 'unknown')).lower()}")
    for row in environment:
        features.add(f"environment:{str(row.get('kind', 'unknown')).lower()}")
    for row in interfaces:
        features.add(f"signal:{str(row.get('quantity', 'unknown')).lower()}")

    entity_kinds = {str(row.get("kind", "")).lower() for row in entities}
    joint_types = {str(row.get("type", "")).lower() for row in joints}
    if entity_kinds & {"mobile_base", "wheeled_base", "tracked_base"}:
        features.add("domain:mobile")
    if entity_kinds & {"aerial_base", "quadrotor", "uav"}:
        features.add("domain:aerial")
    if entity_kinds & {"legged_base", "leg", "foot", "quadruped", "humanoid"}:
        features.add("domain:legged")
    if entity_kinds & {
        "marine_base", "underwater_vehicle", "surface_vessel", "auv", "rov",
    }:
        features.add("domain:marine")
    if entity_kinds & {"soft_body", "continuum_link", "deformable", "tendon"}:
        features.add("domain:soft_robotics")
    if joint_types & {"free", "floating"} or entity_kinds & {
        "floating_base", "mobile_base", "wheeled_base", "aerial_base",
    }:
        features.add("topology:floating_base")
    else:
        features.add("topology:fixed_or_unspecified")
    if any(str(row.get("kind", "")).lower() in {
        "contact", "obstacle", "ground", "terrain", "friction", "material",
    } for row in environment):
        features.add("domain:contact_environment")
    if sensors:
        features.add("domain:sensing")
    parameter_quantities = {
        str(row.get("quantity", "")).lower()
        for row in ir.get("parameters", []) if isinstance(row, dict)
    }
    signal_quantities = {
        str(row.get("quantity", "")).lower() for row in interfaces
    }
    if parameter_quantities & {
        "hydraulic_pressure", "pneumatic_pressure", "valve_coefficient",
    } or signal_quantities & {"fluid_pressure", "fluid_flow", "pressure", "flow"}:
        features.add("domain:fluid_power")
    if signal_quantities & {
        "voltage", "current", "motor_torque", "motor_speed", "battery_state",
    }:
        features.add("domain:electromechanical")
    if any(str(row.get("kind", "")).lower() in {
        "trajectory", "mpc", "computed_torque", "operational_space",
    } for row in controllers):
        features.add("domain:trajectory_or_coupled_control")
    children: dict[str, int] = {}
    graph: dict[str, list[str]] = {}
    for row in joints:
        parent, child = row.get("parent"), row.get("child")
        if isinstance(parent, str) and isinstance(child, str):
            children[child] = children.get(child, 0) + 1
            graph.setdefault(parent, []).append(child)
    if any(count > 1 for count in children.values()) or _has_cycle(graph):
        features.add("topology:closed_chain")
    base_count = sum(
        str(row.get("kind", "")).lower() in {
            "fixed_base", "floating_base", "mobile_base", "wheeled_base",
            "tracked_base", "aerial_base", "marine_base", "legged_base",
        }
        for row in entities
    )
    if base_count > 1:
        features.add("domain:multi_robot")
    return tuple(sorted(features))


def _has_cycle(graph: dict[str, list[str]]) -> bool:
    visited: set[str] = set()
    active: set[str] = set()

    def visit(node: str) -> bool:
        if node in active:
            return True
        if node in visited:
            return False
        active.add(node)
        for child in graph.get(node, []):
            if visit(child):
                return True
        active.remove(node)
        visited.add(node)
        return False

    return any(visit(node) for node in graph)


def assess_profiles(ir: dict) -> tuple[ProfileAssessment, ...]:
    """Route a broad IR to honest profile ceilings.

    Tier ceilings describe implemented evidence paths, not backend theoretical
    capability. General Modelica/OpenUSD generation can reach tier 4 through
    the integrated FMU behavioral route; the frozen articulated subset may be
    handed to the stronger tier-5 H2 workflow.
    """
    features = requested_features(ir)
    feature_set = set(features)
    entities = [row for row in ir.get("entities", []) if isinstance(row, dict)]
    joints = [row for row in ir.get("joints", []) if isinstance(row, dict)]
    joint_types = {
        str(row.get("type", "")).lower()
        for row in joints
    }
    shapes = {
        str(row.get("shape", "box")).lower()
        for row in entities
    }
    controller_kinds = {
        str(row.get("kind", "")).upper()
        for row in ir.get("controllers", []) if isinstance(row, dict)
    }
    axes = {
        str(row.get("axis")) for row in ir.get("joints", [])
        if isinstance(row, dict) and row.get("axis") is not None
    }
    articulated_blockers: list[str] = []
    if not joint_types or not joint_types <= {"revolute", "prismatic"}:
        articulated_blockers.append("requires only revolute/prismatic joints")
    if len(axes) != len(joints) or not axes <= {"X", "Y", "Z"}:
        articulated_blockers.append("requires principal-axis joints")
    if shapes and not shapes <= {"box", "sphere", "cylinder", "capsule"}:
        articulated_blockers.append("requires primitive executable collision shapes")
    if controller_kinds != {"PD"}:
        articulated_blockers.append("requires independent PD effort control")
    if "topology:floating_base" in feature_set:
        articulated_blockers.append("requires a fixed-base acyclic articulation")
    if "topology:closed_chain" in feature_set:
        articulated_blockers.append("requires an acyclic articulation tree")
    entity_kinds = {str(row.get("kind", "")).lower() for row in entities}
    fixed_bases = [row for row in entities if row.get("kind") == "fixed_base"]
    if len(fixed_bases) != 1 or not entity_kinds <= {"fixed_base", "rigid_link"}:
        articulated_blockers.append("requires exactly one fixed base and rigid links")
    if not ir.get("actuators") or not ir.get("interfaces"):
        articulated_blockers.append("requires grounded actuators and bidirectional interfaces")
    interface_quantities = {
        str(row.get("quantity", ""))
        for row in ir.get("interfaces", []) if isinstance(row, dict)
    }
    if not {"joint_position", "joint_velocity", "joint_effort"} <= interface_quantities:
        articulated_blockers.append("requires position/velocity feedback and effort commands")
    clock = ir.get("clock")
    if not isinstance(clock, dict) or not isinstance(clock.get("physics_substeps"), int):
        articulated_blockers.append("requires a grounded sampled-data physics clock")
    if not ir.get("properties"):
        articulated_blockers.append("requires at least one grounded behavior property")
    articulated_blockers = list(dict.fromkeys(articulated_blockers))

    rows = [ProfileAssessment(
        profile_id="general_modelica_openusd",
        applicable=True,
        maximum_supported_tier=4,
        status="integrated_fmu_behavior_execution",
        matched_features=features,
        blockers=(),
    )]
    rows.append(ProfileAssessment(
        profile_id="articulated_joint_space_h2",
        applicable=not articulated_blockers,
        maximum_supported_tier=5 if not articulated_blockers else 2,
        status=("eligible_for_strict_h2_preparation" if not articulated_blockers
                else "artifact_only_for_this_request"),
        matched_features=tuple(sorted(feature_set & {
            "joint:revolute", "joint:prismatic", "controller:PD",
            "topology:fixed_or_unspecified",
        })),
        blockers=tuple(articulated_blockers),
    ))
    for profile_id, marker in (
        ("mobile_floating_base", "domain:mobile"),
        ("aerial_multibody", "domain:aerial"),
        ("legged_locomotion", "domain:legged"),
        ("marine_robotics", "domain:marine"),
        ("soft_continuum_robotics", "domain:soft_robotics"),
        ("fluid_power_actuation", "domain:fluid_power"),
        ("electromechanical_actuation", "domain:electromechanical"),
        ("multi_robot_system", "domain:multi_robot"),
        ("closed_chain_mechanism", "topology:closed_chain"),
        ("sensor_estimation", "domain:sensing"),
        ("contact_environment", "domain:contact_environment"),
        ("trajectory_coupled_control", "domain:trajectory_or_coupled_control"),
    ):
        applicable = marker in feature_set
        rows.append(ProfileAssessment(
            profile_id=profile_id,
            applicable=applicable,
            maximum_supported_tier=4 if applicable else 2,
            status=("integrated_fmu_behavior_execution" if applicable
                    else "not_requested"),
            matched_features=(marker,) if applicable else (),
            blockers=(("not a domain-specific Newton/Isaac physics adapter",)
                      if applicable else ()),
        ))
    return tuple(rows)


def capability_report(ir: dict, *, modelica_passed: bool | None = None,
                      openusd_passed: bool | None = None,
                      contract_valid: bool | None = None,
                      execution_completed: bool | None = None,
                      behavior_evaluated: bool | None = None) -> dict:
    artifact_known = modelica_passed is not None and openusd_passed is not None
    artifacts_passed = modelica_passed is True and openusd_passed is True
    reached = 2 if artifacts_passed else 1
    if not artifact_known:
        reached = 1
    if artifacts_passed and contract_valid is True:
        reached = 3
    if (contract_valid is True and execution_completed is True
            and behavior_evaluated is True):
        reached = 4
    return {
        "schema_version": "1.0",
        "stage": "robotics_capability_assessment",
        "task_id": ir.get("task_id"),
        "requested_features": list(requested_features(ir)),
        "grounding": {
            "policy": "grounded_or_explicitly_unresolved",
            "declared_assumptions": list(ir.get("assumptions", [])),
            "declared_unknowns": list(ir.get("unknowns", [])),
            "artifact_grounding_status": "requires_cross_artifact_validation",
        },
        "profiles": [row.to_dict() for row in assess_profiles(ir)],
        "verification": {
            "highest_reached_tier": reached,
            "highest_reached_tier_name": TIER_NAMES[reached],
            "tiers": [
                {"tier": 0, "name": TIER_NAMES[0], "passed": True},
                {"tier": 1, "name": TIER_NAMES[1], "passed": True},
                {"tier": 2, "name": TIER_NAMES[2],
                 "passed": artifacts_passed if artifact_known else None,
                 "modelica_passed": modelica_passed,
                 "openusd_passed": openusd_passed},
                {"tier": 3, "name": TIER_NAMES[3], "passed": contract_valid,
                 "reason": (None if contract_valid is True else
                            "requires a validated executable FMU contract")},
                {"tier": 4, "name": TIER_NAMES[4],
                 "passed": (
                     execution_completed is True and behavior_evaluated is True
                 ) if execution_completed is not None else None,
                 "execution_completed": execution_completed,
                 "behavior_evaluated": behavior_evaluated,
                 "reason": (None if execution_completed is True
                            and behavior_evaluated is True else
                            "requires a real runtime trace and behavior verdicts")},
                {"tier": 5, "name": TIER_NAMES[5], "passed": False,
                 "reason": "requires genuine accelerator execution provenance"},
            ],
        },
        "claim_eligible_h2": False,
        "claim_eligible_deltaai_h2": False,
    }
