"""Run and checkpoint the frozen 13-family capability breadth study."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

from spec_aligner.llm import is_cli_usage_limit_message


MANIFEST = Path(__file__).with_name("capability_manifest.json")
RESULT = "result.json"
RECORD = "case-record.json"


def load_cases(path: Path = MANIFEST) -> tuple[dict, list[dict]]:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    cases = manifest.get("cases")
    if not isinstance(cases, list) or not cases:
        raise ValueError("capability manifest must contain cases")
    return manifest, cases


def select_cases(cases: list[dict], case_ids: list[str]) -> list[dict]:
    by_id = {row.get("id"): row for row in cases}
    wanted = case_ids or [str(row["id"]) for row in cases]
    missing = set(wanted) - set(by_id)
    if missing:
        raise ValueError(f"unknown capability case IDs: {sorted(missing)}")
    if len(wanted) != len(set(wanted)):
        raise ValueError("capability case IDs must be unique")
    return [by_id[case_id] for case_id in wanted]


def case_fingerprint(case: dict, configuration: dict, manifest_sha256: str) -> str:
    payload = {
        "case": case,
        "configuration": configuration,
        "manifest_sha256": manifest_sha256,
    }
    encoded = json.dumps(
        payload, sort_keys=True, separators=(",", ":"), allow_nan=False
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def summarize_result(case: dict, result: dict) -> dict:
    capabilities = result.get("capabilities", {})
    return {
        "case_id": case["id"],
        "family": case["family"],
        "passed": result.get("passed") is True,
        "failure_stage": result.get("failure_stage"),
        "highest_reached_tier": capabilities.get("highest_reached_tier"),
        "requested_feature_count": capabilities.get("requested_feature_count"),
        "profile_count": capabilities.get("profile_count"),
        "modelica_passed": result.get("modelica", {}).get("passed") is True,
        "openusd_passed": result.get("openusd", {}).get("passed") is True,
        "modelica_repairs": result.get("modelica", {}).get("repairs"),
        "openusd_repairs": result.get("openusd", {}).get("repairs"),
        "normalization_attempts": result.get("normalization", {}).get(
            "attempt_count"
        ),
        "claim_eligible_h2": result.get("claim_eligible_h2") is True,
        "claim_eligible_deltaai_h2": (
            result.get("claim_eligible_deltaai_h2") is True
        ),
    }


def resumable(case_dir: Path, fingerprint: str) -> bool:
    record_path = case_dir / RECORD
    result_path = case_dir / RESULT
    if not record_path.is_file() or not result_path.is_file():
        return False
    try:
        record = json.loads(record_path.read_text(encoding="utf-8"))
        result = json.loads(result_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    return (
        record.get("fingerprint") == fingerprint
        and record.get("completed") is True
        and result.get("passed") is True
    )


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )


def build_summary(
    *,
    study_id: str,
    manifest_path: Path,
    manifest_sha256: str,
    configuration: dict,
    selected_ids: list[str],
    output_dir: Path,
) -> dict:
    rows = []
    for case_id in selected_ids:
        path = output_dir / case_id / RECORD
        if path.is_file():
            rows.append(json.loads(path.read_text(encoding="utf-8")))
    passed = sum(row.get("summary", {}).get("passed") is True for row in rows)
    stopped = [row for row in rows if row.get("usage_limit_detected") is True]
    return {
        "schema_version": "1.0",
        "stage": "capability_breadth_smoke",
        "study_id": study_id,
        "manifest": str(manifest_path.resolve()),
        "manifest_sha256": manifest_sha256,
        "configuration": configuration,
        "selected_case_ids": selected_ids,
        "completed_case_count": len(rows),
        "passed_case_count": passed,
        "failed_case_count": len(rows) - passed,
        "pending_case_count": len(selected_ids) - len(rows),
        "usage_limit_detected": bool(stopped),
        "success": len(rows) == len(selected_ids) and passed == len(rows),
        "cases": [row.get("summary", {}) for row in rows],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    parser.add_argument("--case-id", action="append", default=[])
    parser.add_argument("--model", default="gpt-5.4")
    parser.add_argument("--provider", choices=("codex", "claude"), default="codex")
    parser.add_argument("--backend", choices=("auto", "local", "docker"), default="auto")
    parser.add_argument(
        "--subset",
        choices=(
            "core24", "balanced50", "full100", "full300",
            "semantic500", "full1500",
        ),
        default="full1500",
    )
    parser.add_argument("-k", type=int, default=5)
    parser.add_argument(
        "--rag-routing",
        choices=("unrestricted", "family-preferred"),
        default="unrestricted",
    )
    parser.add_argument("--max-ir-repairs", type=int, default=1)
    parser.add_argument("--max-profile-repairs", type=int, default=2)
    parser.add_argument("--no-resume", action="store_true")
    parser.add_argument("--continue-on-usage-limit", action="store_true")
    args = parser.parse_args()

    manifest, cases = load_cases(args.manifest)
    try:
        selected = select_cases(cases, args.case_id)
    except ValueError as exc:
        parser.error(str(exc))
    if args.k < 1:
        parser.error("-k must be positive")
    if args.max_ir_repairs < 0 or args.max_profile_repairs < 0:
        parser.error("repair counts must be non-negative")

    manifest_sha256 = hashlib.sha256(args.manifest.read_bytes()).hexdigest()
    configuration = {
        "execution_mode": "capability_tiered",
        "mode": "single",
        "model": args.model,
        "provider": args.provider,
        "modelica_backend": args.backend,
        "modelica_subset": args.subset,
        "openusd_subset": args.subset,
        "retrieval_k": args.k,
        "max_ir_repairs": args.max_ir_repairs,
        "max_profile_repairs": args.max_profile_repairs,
        "max_semantic_repairs": 0,
        "alignment_mode": "deterministic",
    }
    if args.rag_routing != "unrestricted":
        configuration["rag_routing"] = (
            "family_preferred_4_of_5_with_global_fallback"
        )
    args.output_dir.mkdir(parents=True, exist_ok=True)
    selected_ids = [str(row["id"]) for row in selected]

    for index, case in enumerate(selected, 1):
        case_id = str(case["id"])
        case_dir = args.output_dir / case_id
        fingerprint = case_fingerprint(case, configuration, manifest_sha256)
        if not args.no_resume and resumable(case_dir, fingerprint):
            print(
                f"[{index}/{len(selected)}] {case_id} already passed; resuming",
                flush=True,
            )
            continue
        case_dir.mkdir(parents=True, exist_ok=True)

        command = [
            sys.executable,
            "-m", "nl2robotics.orchestrator.cli",
            "--text", str(case["request"]),
            "--output-dir", str(case_dir),
            "--task-id", case_id,
            "--execution-mode", "capability_tiered",
            "--mode", "single",
            "--model", args.model,
            "--provider", args.provider,
            "--backend", args.backend,
            "--subset", args.subset,
            "-k", str(args.k),
            "--max-ir-repairs", str(args.max_ir_repairs),
            "--max-profile-repairs", str(args.max_profile_repairs),
            "--max-semantic-repairs", "0",
            "--alignment-mode", "deterministic",
        ]
        if args.rag_routing == "family-preferred":
            route = manifest["rag_family_routes"][case["family"]]
            for category in route["modelica"]:
                command.extend(("--modelica-rag-category", str(category)))
            for category in route["openusd"]:
                command.extend(("--openusd-rag-category", str(category)))
        print(
            f"[{index}/{len(selected)}] {case_id} {case['family']} starting",
            flush=True,
        )
        started = time.monotonic()
        process = subprocess.run(
            command,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        duration = time.monotonic() - started
        (case_dir / "process.log").write_text(process.stdout, encoding="utf-8")
        result_path = case_dir / RESULT
        if result_path.is_file():
            result = json.loads(result_path.read_text(encoding="utf-8"))
        else:
            result = {
                "passed": False,
                "failure_stage": "orchestrator_process",
                "error": process.stdout.strip() or "orchestrator produced no result.json",
            }
            write_json(result_path, result)
        usage_limit = is_cli_usage_limit_message(
            "\n".join((process.stdout, str(result.get("error", ""))))
        )
        summary = summarize_result(case, result)
        record = {
            "schema_version": "1.0",
            "stage": "capability_breadth_case",
            "fingerprint": fingerprint,
            "manifest_sha256": manifest_sha256,
            "case_id": case_id,
            "family": case["family"],
            "expected_profiles": case["expected_profiles"],
            "target_tier": case["target_tier"],
            "configuration": configuration,
            "duration_seconds": duration,
            "process_exit_code": process.returncode,
            "completed": True,
            "usage_limit_detected": usage_limit,
            "summary": summary,
            "result": RESULT,
            "process_log": "process.log",
        }
        write_json(case_dir / RECORD, record)
        study_summary = build_summary(
            study_id=str(manifest["study_id"]),
            manifest_path=args.manifest,
            manifest_sha256=manifest_sha256,
            configuration=configuration,
            selected_ids=selected_ids,
            output_dir=args.output_dir,
        )
        write_json(args.output_dir / "summary.json", study_summary)
        print(
            f"[{index}/{len(selected)}] {case_id} passed={summary['passed']} "
            f"tier={summary['highest_reached_tier']} "
            f"duration={duration:.1f}s",
            flush=True,
        )
        if usage_limit and not args.continue_on_usage_limit:
            print("Stopping at the provider usage limit; rerun to resume.", flush=True)
            break

    final = build_summary(
        study_id=str(manifest["study_id"]),
        manifest_path=args.manifest,
        manifest_sha256=manifest_sha256,
        configuration=configuration,
        selected_ids=selected_ids,
        output_dir=args.output_dir,
    )
    write_json(args.output_dir / "summary.json", final)
    print(json.dumps(final, indent=2, sort_keys=True, allow_nan=False), flush=True)
    raise SystemExit(0 if final["success"] else 1)


if __name__ == "__main__":
    main()
