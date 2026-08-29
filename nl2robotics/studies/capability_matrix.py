"""Audit the frozen, paper-facing capability breadth matrix."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from nl2robotics.contracts.capabilities import TIER_NAMES


MANIFEST = Path(__file__).with_name("capability_manifest.json")
LAUNCH = Path(__file__).with_name("capability_launch.json")
ROBOTICS_ROOT = Path(__file__).resolve().parents[1]
MODELICA_MANIFEST = ROBOTICS_ROOT / "modelica" / "examples" / "manifest.json"
OPENUSD_MANIFEST = ROBOTICS_ROOT / "openusd" / "examples" / "manifest.json"
KNOWN_PROFILES = frozenset({
    "general_modelica_openusd", "articulated_joint_space_h2",
    "mobile_floating_base", "aerial_multibody", "legged_locomotion",
    "marine_robotics", "soft_continuum_robotics", "fluid_power_actuation",
    "electromechanical_actuation", "multi_robot_system",
    "closed_chain_mechanism", "sensor_estimation", "contact_environment",
    "trajectory_coupled_control",
})
REQUIRED_FAMILIES = frozenset({
    "articulated_manipulation", "mobile_robotics", "aerial_robotics",
    "legged_robotics", "marine_robotics", "contact_manipulation",
    "trajectory_control", "closed_chain_mechanisms", "sensor_estimation",
    "fluid_power", "electromechanical_actuation", "soft_robotics",
    "multi_robot_systems",
})


def audit_manifest(path: Path = MANIFEST) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    issues: list[dict] = []
    cases = data.get("cases")
    routes = data.get("rag_family_routes")
    if data.get("schema_version") != "1.0":
        issues.append({"code": "unsupported_schema", "path": "$.schema_version"})
    if data.get("execution_mode") != "capability_tiered":
        issues.append({"code": "wrong_execution_mode", "path": "$.execution_mode"})
    if not isinstance(cases, list):
        issues.append({"code": "invalid_cases", "path": "$.cases"})
        cases = []
    if not isinstance(routes, dict):
        issues.append({"code": "invalid_rag_routes", "path": "$.rag_family_routes"})
        routes = {}
    ids: set[str] = set()
    families: set[str] = set()
    profiles: set[str] = set()
    for index, case in enumerate(cases):
        prefix = f"$.cases[{index}]"
        if not isinstance(case, dict):
            issues.append({"code": "invalid_case", "path": prefix})
            continue
        case_id = case.get("id")
        if not isinstance(case_id, str) or not case_id:
            issues.append({"code": "missing_case_id", "path": f"{prefix}.id"})
        elif case_id in ids:
            issues.append({"code": "duplicate_case_id", "path": f"{prefix}.id"})
        ids.add(case_id)
        family = case.get("family")
        if isinstance(family, str):
            families.add(family)
        if not isinstance(case.get("request"), str) or len(case["request"].split()) < 8:
            issues.append({"code": "weak_request", "path": f"{prefix}.request"})
        expected = case.get("expected_profiles")
        if not isinstance(expected, list) or not expected:
            issues.append({"code": "missing_profiles", "path": f"{prefix}.expected_profiles"})
            expected = []
        unknown = set(expected) - KNOWN_PROFILES
        if unknown:
            issues.append({"code": "unknown_profile", "path": f"{prefix}.expected_profiles",
                           "values": sorted(unknown)})
        profiles.update(expected)
        tier = case.get("target_tier")
        if tier not in TIER_NAMES:
            issues.append({"code": "invalid_target_tier", "path": f"{prefix}.target_tier"})
        if tier == 5 and "articulated_joint_space_h2" not in expected:
            issues.append({"code": "unsupported_tier5_claim", "path": f"{prefix}.target_tier"})
        if isinstance(tier, int) and tier > 2 and case_id != "RCB001":
            issues.append({"code": "unimplemented_runtime_claim", "path": f"{prefix}.target_tier"})
    missing_families = REQUIRED_FAMILIES - families
    if missing_families:
        issues.append({"code": "missing_family", "path": "$.cases",
                       "values": sorted(missing_families)})
    missing_routes = REQUIRED_FAMILIES - set(routes)
    extra_routes = set(routes) - REQUIRED_FAMILIES
    if missing_routes:
        issues.append({"code": "missing_rag_route", "path": "$.rag_family_routes",
                       "values": sorted(missing_routes)})
    if extra_routes:
        issues.append({"code": "unknown_rag_route", "path": "$.rag_family_routes",
                       "values": sorted(extra_routes)})
    corpus_categories = {
        "modelica": _corpus_categories(MODELICA_MANIFEST),
        "openusd": _corpus_categories(OPENUSD_MANIFEST),
    }
    for family, route in routes.items():
        prefix = f"$.rag_family_routes.{family}"
        if not isinstance(route, dict):
            issues.append({"code": "invalid_rag_route", "path": prefix})
            continue
        for artifact in ("modelica", "openusd"):
            categories = route.get(artifact)
            if not isinstance(categories, list) or not categories:
                issues.append({"code": "empty_rag_route", "path": f"{prefix}.{artifact}"})
                continue
            unknown = set(categories) - corpus_categories[artifact]
            if unknown:
                issues.append({"code": "unknown_rag_category",
                               "path": f"{prefix}.{artifact}",
                               "values": sorted(unknown)})
    missing_profiles = KNOWN_PROFILES - profiles
    if missing_profiles:
        issues.append({"code": "uncovered_profile", "path": "$.cases",
                       "values": sorted(missing_profiles)})
    tier_counts = {
        str(tier): sum(case.get("target_tier") == tier for case in cases)
        for tier in TIER_NAMES
    }
    launch = _audit_launch(LAUNCH, path, ids)
    issues.extend(launch["issues"])
    return {
        "stage": "capability_breadth_audit", "schema_version": "1.0",
        "success": not issues, "case_count": len(cases),
        "family_count": len(families), "profile_count": len(profiles),
        "families": sorted(families), "profiles": sorted(profiles),
        "target_tier_counts": tier_counts,
        "rag": {
            "modelica_example_count": _corpus_size(MODELICA_MANIFEST),
            "openusd_example_count": _corpus_size(OPENUSD_MANIFEST),
            "routed_family_count": len(routes),
            "modelica_categories": sorted(corpus_categories["modelica"]),
            "openusd_categories": sorted(corpus_categories["openusd"]),
        },
        "launch": launch,
        "issues": issues,
    }


def _audit_launch(path: Path, manifest_path: Path,
                  case_ids: set[str]) -> dict:
    issues: list[dict] = []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {"success": False, "issues": [{
            "code": "invalid_launch_config", "path": str(path),
            "message": str(exc),
        }]}
    manifest_hash = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
    if data.get("capability_manifest_sha256") != manifest_hash:
        issues.append({"code": "launch_manifest_hash_mismatch",
                       "path": "$.capability_manifest_sha256"})
    if set(data.get("case_ids", [])) != case_ids:
        issues.append({"code": "launch_case_mismatch", "path": "$.case_ids"})
    generation = data.get("generation", {})
    for key in ("modelica_subset", "openusd_subset"):
        if generation.get(key) != "full1500":
            issues.append({"code": "launch_requires_full1500", "path": f"$.generation.{key}"})
    if generation.get("freeze_validated_ir_before_artifact_repetitions") is not True:
        issues.append({"code": "launch_requires_frozen_ir",
                       "path": "$.generation.freeze_validated_ir_before_artifact_repetitions"})
    phases = data.get("phases", [])
    if not isinstance(phases, list) or {row.get("id") for row in phases} != {
        "breadth_smoke", "paper_ablation",
    }:
        issues.append({"code": "launch_phase_mismatch", "path": "$.phases"})
    for index, phase in enumerate(phases if isinstance(phases, list) else []):
        if set(phase.get("case_ids", [])) != case_ids:
            issues.append({"code": "launch_phase_case_mismatch",
                           "path": f"$.phases[{index}].case_ids"})
        if phase.get("target_tier") != 2 or phase.get("deltaai_gpu_count") != 0:
            issues.append({"code": "launch_phase_overclaim",
                           "path": f"$.phases[{index}]"})
        expected_retrieval = {
            "breadth_smoke": "unrestricted_semantic_full1500",
            "paper_ablation": "family_preferred_4_of_5_with_global_fallback",
        }.get(phase.get("id"))
        if phase.get("retrieval_policy") != expected_retrieval:
            issues.append({"code": "launch_retrieval_policy_mismatch",
                           "path": f"$.phases[{index}].retrieval_policy"})
    policy = data.get("claim_policy", {})
    if any(policy.get(key) is not False for key in (
        "capability_runs_may_claim_tier_above_2",
        "capability_runs_may_set_claim_eligible_h2",
        "capability_runs_may_set_claim_eligible_deltaai_h2",
    )):
        issues.append({"code": "launch_claim_policy_weakened",
                       "path": "$.claim_policy"})
    return {
        "success": not issues,
        "path": str(path),
        "manifest_sha256": manifest_hash,
        "case_count": len(case_ids),
        "phase_count": len(phases) if isinstance(phases, list) else 0,
        "issues": issues,
    }


def _corpus_rows(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    return [row for row in data if isinstance(row, dict)] if isinstance(data, list) else []


def _corpus_categories(path: Path) -> set[str]:
    return {str(row["category"]) for row in _corpus_rows(path) if row.get("category")}


def _corpus_size(path: Path) -> int:
    return len(_corpus_rows(path))


def main() -> None:
    report = audit_manifest()
    print(json.dumps(report, indent=2, sort_keys=True))
    raise SystemExit(0 if report["success"] else 1)


if __name__ == "__main__":
    main()
