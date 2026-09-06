"""Fail-closed audit for the held-out robotics paper prompt benchmark."""

from __future__ import annotations

from collections import Counter
import hashlib
import json
from pathlib import Path
import re

from .capability_matrix import KNOWN_PROFILES, REQUIRED_FAMILIES


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = Path(__file__).with_name("paper_evaluation_manifest.json")
DEVELOPMENT_MANIFEST = Path(__file__).with_name("capability_manifest.json")
MODELICA_MANIFEST = ROOT / "modelica" / "examples" / "manifest.json"
OPENUSD_MANIFEST = ROOT / "openusd" / "examples" / "manifest.json"
MAX_FIVE_GRAM_JACCARD = 0.20
FAMILY_PROFILE = {
    "articulated_manipulation": "articulated_joint_space_h2",
    "mobile_robotics": "mobile_floating_base",
    "aerial_robotics": "aerial_multibody",
    "legged_robotics": "legged_locomotion",
    "marine_robotics": "marine_robotics",
    "contact_manipulation": "contact_environment",
    "trajectory_control": "trajectory_coupled_control",
    "closed_chain_mechanisms": "closed_chain_mechanism",
    "sensor_estimation": "sensor_estimation",
    "fluid_power": "fluid_power_actuation",
    "electromechanical_actuation": "electromechanical_actuation",
    "soft_robotics": "soft_continuum_robotics",
    "multi_robot_systems": "multi_robot_system",
}


def _load(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8"))


def _normalized(text: str) -> str:
    return " ".join(re.findall(r"[a-z0-9]+", text.lower()))


def _ngrams(text: str, width: int = 5) -> set[tuple[str, ...]]:
    tokens = _normalized(text).split()
    return {tuple(tokens[index:index + width])
            for index in range(max(0, len(tokens) - width + 1))}


def _jaccard(left: str, right: str) -> float:
    left_grams, right_grams = _ngrams(left), _ngrams(right)
    union = left_grams | right_grams
    return len(left_grams & right_grams) / len(union) if union else 0.0


def _comparison_rows(path: Path, field: str) -> list[tuple[str, str]]:
    data = _load(path)
    rows = data["cases"] if isinstance(data, dict) else data
    return [(str(row.get("id", "")), str(row.get(field, ""))) for row in rows]


def _semantic_case_count(path: Path) -> int:
    data = _load(path)
    rows = data["cases"] if isinstance(data, dict) else data
    return len({str(row["semantic_case_id"]) for row in rows})


def _maximum_overlap(cases: list[dict], references: list[tuple[str, str]]) -> dict:
    best = {"score": 0.0, "case_id": None, "reference_id": None}
    for case in cases:
        for reference_id, reference in references:
            score = _jaccard(case["request"], reference)
            if score > best["score"]:
                best = {"score": score, "case_id": case["id"],
                        "reference_id": reference_id}
    return best


def _maximum_internal_overlap(cases: list[dict]) -> dict:
    best = {"score": 0.0, "left_case_id": None, "right_case_id": None}
    for index, left in enumerate(cases):
        for right in cases[index + 1:]:
            score = _jaccard(left["request"], right["request"])
            if score > best["score"]:
                best = {"score": score, "left_case_id": left["id"],
                        "right_case_id": right["id"]}
    return best


def audit_manifest(path: Path = MANIFEST) -> dict:
    data = _load(path)
    issues: list[dict] = []
    cases = data.get("cases", []) if isinstance(data, dict) else []
    design = data.get("design", {}) if isinstance(data, dict) else {}
    routes = data.get("rag_family_routes", {}) if isinstance(data, dict) else {}
    development = _load(DEVELOPMENT_MANIFEST)

    def require(condition: bool, code: str, location: str, **detail: object) -> None:
        if not condition:
            issues.append({"code": code, "path": location, **detail})

    require(data.get("schema_version") == "1.0", "unsupported_schema",
            "$.schema_version")
    require(data.get("status") in {
        "candidate_pending_mentor_approval",
        "candidate_execution_protocol_pending_mentor_approval",
    },
            "wrong_freeze_status", "$.status")
    require(data.get("execution_mode") == "capability_tiered",
            "wrong_execution_mode", "$.execution_mode")
    require(isinstance(cases, list), "invalid_cases", "$.cases")
    require(len(cases) == 65, "wrong_case_count", "$.cases", actual=len(cases))
    require(design.get("family_count") == 13, "wrong_design_family_count",
            "$.design.family_count")
    require(design.get("primary_case_count") == 52, "wrong_primary_design_count",
            "$.design.primary_case_count")
    require(design.get("reserve_case_count") == 13, "wrong_reserve_design_count",
            "$.design.reserve_case_count")
    require(set(design.get("development_exclusions", [])) ==
            {f"RCB{index:03d}" for index in range(1, 14)},
            "wrong_development_exclusions", "$.design.development_exclusions")
    require(routes == development.get("rag_family_routes"),
            "rag_routes_drifted_from_audited_capability_matrix",
            "$.rag_family_routes")

    ids: list[str] = []
    normalized_requests: list[str] = []
    family_counts: Counter[str] = Counter()
    family_splits: dict[str, Counter[str]] = {
        family: Counter() for family in REQUIRED_FAMILIES
    }
    family_difficulty: dict[str, Counter[str]] = {
        family: Counter() for family in REQUIRED_FAMILIES
    }
    profiles: set[str] = set()
    for index, case in enumerate(cases):
        prefix = f"$.cases[{index}]"
        require(isinstance(case, dict), "invalid_case", prefix)
        if not isinstance(case, dict):
            continue
        case_id = case.get("id")
        request = case.get("request")
        family = case.get("family")
        expected = case.get("expected_profiles")
        tags = case.get("feature_tags")
        require(isinstance(case_id, str), "invalid_id", f"{prefix}.id")
        require(isinstance(request, str), "invalid_request", f"{prefix}.request")
        require(family in REQUIRED_FAMILIES, "unknown_family", f"{prefix}.family")
        require(case.get("split") in {"primary", "reserve"}, "invalid_split",
                f"{prefix}.split")
        require(case.get("difficulty") in {"foundational", "intermediate", "advanced"},
                "invalid_difficulty", f"{prefix}.difficulty")
        require(isinstance(expected, list) and bool(expected), "invalid_profiles",
                f"{prefix}.expected_profiles")
        require(isinstance(tags, list) and len(tags) >= 5 and len(tags) == len(set(tags)),
                "invalid_feature_tags", f"{prefix}.feature_tags")
        if isinstance(case_id, str):
            ids.append(case_id)
        if isinstance(request, str):
            normalized_requests.append(_normalized(request))
            require(len(request.split()) >= 100, "under_grounded_request",
                    f"{prefix}.request", word_count=len(request.split()))
            require("Hz" in request, "missing_timing", f"{prefix}.request")
            require("Require" in request, "missing_observable_requirements",
                    f"{prefix}.request")
        if family in REQUIRED_FAMILIES:
            family_counts[family] += 1
            family_splits[family][str(case.get("split"))] += 1
            family_difficulty[family][str(case.get("difficulty"))] += 1
        if isinstance(expected, list):
            profiles.update(expected)
            require(not (set(expected) - KNOWN_PROFILES), "unknown_profile",
                    f"{prefix}.expected_profiles",
                    values=sorted(set(expected) - KNOWN_PROFILES))
            require("general_modelica_openusd" in expected,
                    "missing_general_profile", f"{prefix}.expected_profiles")
            if family in FAMILY_PROFILE:
                require(FAMILY_PROFILE[family] in expected,
                        "missing_family_profile", f"{prefix}.expected_profiles",
                        expected=FAMILY_PROFILE[family])
        articulated = family == "articulated_manipulation"
        require(case.get("target_tier") == (5 if articulated else 4),
                "unsupported_target_tier", f"{prefix}.target_tier")
        require(case.get("runtime_candidate") is True,
                "invalid_runtime_candidate", f"{prefix}.runtime_candidate")
        require(("articulated_joint_space_h2" in (expected or [])) is articulated,
                "invalid_runtime_profile", f"{prefix}.expected_profiles")

    require(ids == [f"RBE{index:03d}" for index in range(1, 66)],
            "noncanonical_id_order", "$.cases")
    require(len(ids) == len(set(ids)), "duplicate_id", "$.cases")
    require(len(normalized_requests) == len(set(normalized_requests)),
            "duplicate_request", "$.cases")
    require(set(family_counts) == set(REQUIRED_FAMILIES), "missing_family", "$.cases",
            values=sorted(REQUIRED_FAMILIES - set(family_counts)))
    for family in sorted(REQUIRED_FAMILIES):
        require(family_counts[family] == 5, "unbalanced_family", "$.cases",
                family=family, actual=family_counts[family])
        require(family_splits[family] == Counter({"primary": 4, "reserve": 1}),
                "unbalanced_family_split", "$.cases", family=family,
                actual=dict(family_splits[family]))
        require(family_difficulty[family] ==
                Counter({"intermediate": 2, "advanced": 2, "foundational": 1}),
                "unbalanced_family_difficulty", "$.cases", family=family,
                actual=dict(family_difficulty[family]))
    require(profiles == set(KNOWN_PROFILES), "incomplete_profile_coverage", "$.cases",
            missing=sorted(KNOWN_PROFILES - profiles))

    reference_sets = {
        "development": _comparison_rows(DEVELOPMENT_MANIFEST, "request"),
        "modelica_rag": _comparison_rows(MODELICA_MANIFEST, "requirement"),
        "openusd_rag": _comparison_rows(OPENUSD_MANIFEST, "requirement"),
    }
    internal_overlap = _maximum_internal_overlap(cases)
    require(internal_overlap["score"] < MAX_FIVE_GRAM_JACCARD,
            "high_internal_prompt_overlap", "$.cases", **internal_overlap)
    leakage = {"within_benchmark": {
        "reference_count": len(cases),
        "exact_matches": len(normalized_requests) - len(set(normalized_requests)),
        "maximum_five_gram_jaccard": internal_overlap,
    }}
    eval_request_set = set(normalized_requests)
    for name, rows in reference_sets.items():
        normalized_reference = {_normalized(text) for _, text in rows}
        exact = sorted(eval_request_set & normalized_reference)
        maximum = _maximum_overlap(cases, rows)
        leakage[name] = {"reference_count": len(rows), "exact_matches": len(exact),
                         "maximum_five_gram_jaccard": maximum}
        require(not exact, "exact_prompt_leakage", f"$.leakage.{name}")
        require(maximum["score"] < MAX_FIVE_GRAM_JACCARD,
                "high_prompt_overlap", f"$.leakage.{name}", **maximum)

    manifest_sha256 = hashlib.sha256(path.read_bytes()).hexdigest()
    return {
        "stage": "paper_evaluation_manifest_audit",
        "schema_version": "1.0",
        "success": not issues,
        "benchmark_id": data.get("benchmark_id"),
        "freeze_status": data.get("status"),
        "manifest_sha256": manifest_sha256,
        "case_count": len(cases),
        "primary_case_count": sum(case.get("split") == "primary" for case in cases),
        "reserve_case_count": sum(case.get("split") == "reserve" for case in cases),
        "family_counts": dict(sorted(family_counts.items())),
        "profile_count": len(profiles),
        "runtime_candidate_count": sum(case.get("runtime_candidate") is True
                                       for case in cases),
        "retrieval_corpus": {
            "modelica_prompt_count": len(reference_sets["modelica_rag"]),
            "modelica_semantic_case_count": _semantic_case_count(MODELICA_MANIFEST),
            "openusd_prompt_count": len(reference_sets["openusd_rag"]),
            "openusd_semantic_case_count": _semantic_case_count(OPENUSD_MANIFEST),
        },
        "leakage": leakage,
        "issues": issues,
    }


def main() -> int:
    report = audit_manifest()
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
