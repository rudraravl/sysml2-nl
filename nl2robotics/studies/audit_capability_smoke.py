"""Fail-closed audit and aggregation for capability breadth smoke evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from nl2robotics.contracts.requirement_ir import validate_requirement_ir
from nl2robotics.studies.capability_matrix import (
    KNOWN_PROFILES,
    MANIFEST,
    audit_manifest,
)


REQUIRED_FILES = (
    "request.txt",
    "normalization.json",
    "requirement_ir.json",
    "normalized_requirement_ir.json",
    "contract.json",
    "plan.json",
    "modelica-requirement.txt",
    "openusd-requirement.txt",
    "modelica/generation.json",
    "modelica/model.mo",
    "openusd/generation.json",
    "openusd/scene.usda",
    "capability-report.json",
    "result.json",
)


def audit_smoke(
    run_dir: Path,
    *,
    manifest_path: Path = MANIFEST,
    case_dirs: dict[str, Path] | None = None,
) -> dict:
    """Audit all frozen cases, allowing explicit paths for separately run cases."""
    run_dir = run_dir.resolve()
    overrides = {key: value.resolve() for key, value in (case_dirs or {}).items()}
    matrix = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest_audit = audit_manifest(manifest_path)
    cases = matrix.get("cases", []) if isinstance(matrix, dict) else []
    manifest_sha = _sha256(manifest_path)
    rows: list[dict] = []
    issues: list[dict] = []

    if manifest_audit.get("success") is not True:
        issues.append(_issue("manifest_audit_failed", "$", manifest_audit["issues"]))

    for case in cases:
        case_id = str(case.get("id", ""))
        case_dir = overrides.get(case_id, run_dir / case_id)
        row, case_issues = _audit_case(
            case, case_dir, manifest_sha=manifest_sha,
        )
        rows.append(row)
        issues.extend(case_issues)

    observed = {row["case_id"] for row in rows}
    expected = {str(case.get("id")) for case in cases}
    if observed != expected:
        issues.append(_issue(
            "case_set_mismatch", "$.cases",
            {"expected": sorted(expected), "observed": sorted(observed)},
        ))

    passed_rows = [row for row in rows if row.get("success") is True]
    durations = [
        float(row["duration_seconds"])
        for row in rows if isinstance(row.get("duration_seconds"), (int, float))
    ]
    artifact_hashes = {
        row["case_id"]: row["artifact_sha256"] for row in rows
        if isinstance(row.get("artifact_sha256"), dict)
    }
    return {
        "stage": "capability_breadth_evidence_audit",
        "schema_version": "1.0",
        "success": not issues and len(passed_rows) == len(cases),
        "manifest": str(manifest_path.resolve()),
        "manifest_sha256": manifest_sha,
        "run_dir": str(run_dir),
        "case_overrides": {key: str(value) for key, value in sorted(overrides.items())},
        "case_count": len(rows),
        "passed_case_count": len(passed_rows),
        "family_count": len({row.get("family") for row in rows}),
        "profile_count": len(KNOWN_PROFILES),
        "total_requested_feature_count": sum(
            int(row.get("requested_feature_count", 0)) for row in rows
        ),
        "normalization_attempt_count": sum(
            int(row.get("normalization_attempts", 0)) for row in rows
        ),
        "modelica_repair_count": sum(int(row.get("modelica_repairs", 0)) for row in rows),
        "openusd_repair_count": sum(int(row.get("openusd_repairs", 0)) for row in rows),
        "timed_case_count": len(durations),
        "total_duration_seconds": sum(durations),
        "mean_duration_seconds": sum(durations) / len(durations) if durations else None,
        "claims": {
            "claim_eligible_h2": False,
            "claim_eligible_deltaai_h2": False,
            "maximum_verified_tier": 2,
        },
        "cases": rows,
        "artifact_sha256": artifact_hashes,
        "issues": issues,
    }


def _audit_case(case: dict, case_dir: Path, *, manifest_sha: str) -> tuple[dict, list[dict]]:
    case_id = str(case.get("id", ""))
    prefix = f"$.cases[{case_id}]"
    issues: list[dict] = []
    documents: dict[str, object] = {}
    hashes: dict[str, str] = {}

    if not case_dir.is_dir():
        issues.append(_issue("missing_case_dir", prefix, str(case_dir)))
        return _failed_row(case, case_dir, issues), issues

    for relative in REQUIRED_FILES:
        path = case_dir / relative
        if not path.is_file():
            issues.append(_issue("missing_artifact", f"{prefix}.{relative}", str(path)))
            continue
        hashes[relative] = _sha256(path)

    for path in sorted(case_dir.rglob("*.json")):
        relative = path.relative_to(case_dir).as_posix()
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            issues.append(_issue("invalid_json", f"{prefix}.{relative}", str(exc)))
            continue
        documents[relative] = value
        hashes.setdefault(relative, _sha256(path))

    request = _read_text(case_dir / "request.txt")
    expected_request = str(case.get("request", "")).strip()
    if request != expected_request:
        issues.append(_issue("request_manifest_mismatch", f"{prefix}.request", None))

    result = _object(documents.get("result.json"))
    normalization = _object(documents.get("normalization.json"))
    ir = _object(documents.get("normalized_requirement_ir.json"))
    raw_ir = _object(documents.get("requirement_ir.json"))
    contract = _object(documents.get("contract.json"))
    capability = _object(documents.get("capability-report.json"))
    modelica_report = _object(documents.get("modelica/generation.json"))
    openusd_report = _object(documents.get("openusd/generation.json"))
    modelica = _read_text(case_dir / "modelica/model.mo")
    openusd = _read_text(case_dir / "openusd/scene.usda")

    _require(result.get("passed") is True, issues, "result_not_passed", prefix, result.get("failure_stage"))
    _require(result.get("failure_stage") is None, issues, "unexpected_failure_stage", prefix, result.get("failure_stage"))
    _require(result.get("task_id") == case_id, issues, "task_id_mismatch", prefix, result.get("task_id"))
    _require(result.get("claim_eligible_h2") is False, issues, "h2_overclaim", prefix, result.get("claim_eligible_h2"))
    _require(result.get("claim_eligible_deltaai_h2") is False, issues, "deltaai_overclaim", prefix, result.get("claim_eligible_deltaai_h2"))
    _require(
        result.get("source_text_sha256") == hashlib.sha256(request.encode("utf-8")).hexdigest(),
        issues, "source_hash_mismatch", prefix, result.get("source_text_sha256"),
    )

    _require(normalization.get("success") is True, issues, "normalization_failed", prefix, None)
    normalized_attempt = _last_valid_normalization_response(normalization)
    _require(normalized_attempt == ir, issues, "normalization_ir_mismatch", prefix, None)
    _require(raw_ir == ir, issues, "saved_ir_mismatch", prefix, None)
    validation = validate_requirement_ir(ir) if isinstance(ir, dict) else None
    _require(validation is not None and validation.success, issues, "invalid_requirement_ir", prefix,
             validation.to_dict() if validation is not None else None)
    _require(ir.get("source_text", "").strip() == request, issues, "ir_source_mismatch", prefix, None)
    _require(ir.get("task_id") == case_id, issues, "ir_task_id_mismatch", prefix, ir.get("task_id"))
    _require(ir.get("execution_mode") == "capability_tiered", issues,
             "ir_execution_mode_mismatch", prefix, ir.get("execution_mode"))

    verification = capability.get("verification", {})
    tiers = verification.get("tiers", []) if isinstance(verification, dict) else []
    tier_map = {item.get("tier"): item for item in tiers if isinstance(item, dict)}
    _require(verification.get("highest_reached_tier") == 2, issues,
             "wrong_capability_tier", prefix, verification.get("highest_reached_tier"))
    for tier in range(3):
        _require(tier_map.get(tier, {}).get("passed") is True, issues,
                 "missing_passed_tier", prefix, tier)
    for tier in range(3, 6):
        _require(tier_map.get(tier, {}).get("passed") is False, issues,
                 "capability_tier_overclaim", prefix, tier)
    profiles = capability.get("profiles", [])
    profile_map = {
        item.get("profile_id"): item for item in profiles if isinstance(item, dict)
    }
    _require(set(profile_map) == set(KNOWN_PROFILES), issues,
             "profile_set_mismatch", prefix, sorted(profile_map))
    for profile_id in case.get("expected_profiles", []):
        _require(profile_id in profile_map, issues,
                 "expected_profile_missing", prefix, profile_id)
    _require(capability.get("claim_eligible_h2") is False, issues,
             "capability_h2_overclaim", prefix, capability.get("claim_eligible_h2"))
    _require(capability.get("claim_eligible_deltaai_h2") is False, issues,
             "capability_deltaai_overclaim", prefix,
             capability.get("claim_eligible_deltaai_h2"))

    _require(contract.get("task_id") == case_id, issues, "contract_task_id_mismatch", prefix,
             contract.get("task_id"))
    _require(contract.get("execution_mode") == "capability_tiered", issues,
             "contract_mode_mismatch", prefix, contract.get("execution_mode"))
    _require(contract.get("verification_ceiling") == "artifacts_validated", issues,
             "contract_ceiling_overclaim", prefix, contract.get("verification_ceiling"))
    _require(contract.get("claim_eligible_h2") is False, issues,
             "contract_h2_overclaim", prefix, contract.get("claim_eligible_h2"))

    _audit_modelica(modelica_report, modelica, issues, prefix)
    _audit_openusd(openusd_report, openusd, issues, prefix)
    _audit_mappings(contract.get("mappings"), modelica, openusd, issues, prefix)

    case_record_value = documents.get("case-record.json")
    case_record = _object(case_record_value) if case_record_value is not None else None
    duration = None
    if case_record is not None:
        _require(case_record.get("completed") is True, issues, "case_not_completed", prefix, None)
        _require(case_record.get("manifest_sha256") == manifest_sha, issues,
                 "case_manifest_hash_mismatch", prefix, case_record.get("manifest_sha256"))
        duration = case_record.get("duration_seconds")

    summary = result.get("capabilities", {})
    row = {
        "case_id": case_id,
        "family": case.get("family"),
        "case_dir": str(case_dir),
        "success": not issues,
        "highest_reached_tier": summary.get("highest_reached_tier"),
        "requested_feature_count": summary.get("requested_feature_count", 0),
        "normalization_attempts": result.get("normalization", {}).get("attempt_count", 0),
        "modelica_repairs": result.get("modelica", {}).get("repairs", 0),
        "openusd_repairs": result.get("openusd", {}).get("repairs", 0),
        "json_document_count": len(documents),
        "duration_seconds": duration,
        "artifact_sha256": hashes,
        "issue_count": len(issues),
    }
    return row, issues


def _audit_modelica(report: dict, modelica: str, issues: list[dict], prefix: str) -> None:
    _require(report.get("passed") is True, issues, "modelica_failed", prefix, None)
    _require(report.get("final_modelica", "").strip() == modelica, issues,
             "modelica_artifact_mismatch", prefix, None)
    attempts = report.get("attempts", [])
    final_attempts = [
        item for item in attempts
        if isinstance(item, dict) and item.get("modelica", "").strip() == modelica
    ]
    _require(len(final_attempts) == 1, issues, "modelica_final_attempt_count", prefix,
             len(final_attempts))
    if final_attempts:
        build = final_attempts[0].get("build", {})
        _require(final_attempts[0].get("passed") is True, issues,
                 "modelica_final_attempt_failed", prefix, final_attempts[0].get("attempt"))
        _require(build.get("success") is True and build.get("checked") is True
                 and build.get("compiled") is True,
                 issues, "modelica_build_evidence_failed", prefix, build)


def _audit_openusd(report: dict, openusd: str, issues: list[dict], prefix: str) -> None:
    _require(report.get("passed") is True, issues, "openusd_failed", prefix, None)
    _require(report.get("final_openusd", "").strip() == openusd, issues,
             "openusd_artifact_mismatch", prefix, None)
    attempts = report.get("attempts", [])
    final_attempts = [
        item for item in attempts
        if isinstance(item, dict) and item.get("openusd", "").strip() == openusd
    ]
    _require(len(final_attempts) == 1, issues, "openusd_final_attempt_count", prefix,
             len(final_attempts))
    if final_attempts:
        validation = final_attempts[0].get("validation", {})
        _require(validation.get("success") is True
                 and validation.get("syntax_valid") is True
                 and validation.get("semantic_valid") is True,
                 issues, "openusd_validation_evidence_failed", prefix, validation)


def _audit_mappings(rows: object, modelica: str, openusd: str,
                    issues: list[dict], prefix: str) -> None:
    if not isinstance(rows, list) or not rows:
        issues.append(_issue("missing_contract_mappings", prefix, None))
        return
    ids: set[str] = set()
    for index, row in enumerate(rows):
        path = f"{prefix}.mappings[{index}]"
        if not isinstance(row, dict):
            issues.append(_issue("invalid_contract_mapping", path, None))
            continue
        mapping_id = row.get("id")
        _require(isinstance(mapping_id, str) and mapping_id not in ids, issues,
                 "duplicate_or_missing_mapping_id", path, mapping_id)
        ids.add(mapping_id)
        fmu_variable = row.get("fmu_variable")
        _require(isinstance(fmu_variable, str) and fmu_variable in modelica, issues,
                 "missing_modelica_variable", path, fmu_variable)
        prim_path = row.get("usd_prim_path")
        _require(isinstance(prim_path, str) and prim_path in openusd, issues,
                 "missing_openusd_target", path, prim_path)


def _failed_row(case: dict, case_dir: Path, issues: list[dict]) -> dict:
    return {
        "case_id": str(case.get("id", "")), "family": case.get("family"),
        "case_dir": str(case_dir), "success": False, "issue_count": len(issues),
    }


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def _object(value: object) -> dict:
    return value if isinstance(value, dict) else {}


def _last_valid_normalization_response(report: dict) -> dict:
    attempts = report.get("attempts", [])
    for attempt in reversed(attempts if isinstance(attempts, list) else []):
        if not isinstance(attempt, dict) or attempt.get("valid") is not True:
            continue
        response = attempt.get("response")
        if not isinstance(response, str):
            return {}
        try:
            value = json.loads(response)
        except json.JSONDecodeError:
            return {}
        return value if isinstance(value, dict) else {}
    return {}


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _issue(code: str, path: str, detail: object) -> dict:
    return {"code": code, "path": path, "detail": detail}


def _require(condition: bool, issues: list[dict], code: str,
             path: str, detail: object) -> None:
    if not condition:
        issues.append(_issue(code, path, detail))


def _case_override(value: str) -> tuple[str, Path]:
    case_id, separator, path = value.partition("=")
    if not separator or not case_id or not path:
        raise argparse.ArgumentTypeError("case override must be CASE_ID=PATH")
    return case_id, Path(path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    parser.add_argument("--case-dir", action="append", default=[], type=_case_override,
                        metavar="CASE_ID=PATH")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = audit_smoke(
        args.run_dir,
        manifest_path=args.manifest,
        case_dirs=dict(args.case_dir),
    )
    rendered = json.dumps(report, indent=2, sort_keys=True, allow_nan=False)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)
    raise SystemExit(0 if report["success"] else 1)


if __name__ == "__main__":
    main()
