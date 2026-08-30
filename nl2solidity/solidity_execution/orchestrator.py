"""Solidity execution orchestrator.

    from nl2solidity.solidity_execution import ExecutionRequest, run_solidity_execution

    result = run_solidity_execution(ExecutionRequest(candidate_solidity=code))
    print(result.compiled, result.success, result.failures())

Mirrors nl2sysml/sysml_execution/orchestrator.py:

    extract topology -> build harness -> run runtime -> classify -> diagnostics

with the SysML kernel replaced by Foundry and the single naive harness replaced
by two tiers (see harness_builder): programmatic fuzz/boundary probing, and
requirement-derived properties written during generation.

``success`` means every test in every built tier passed. ``compiled`` means the
candidate plus its harness compiled. A harness that could not be generated (an
unsynthesizable constructor, say) is reported through ``harness_notes`` and
leaves ``success`` untouched rather than blaming the contract.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List, Optional

from .diagnostics import build_execution_diagnostics, write_execution_diagnostics_file
from .extractor import classify_kind, extract_topology, summarize_topology
from .foundry_bridge import (
    execute_solidity_candidate,
    forge_version,
    is_runner_available,
)
from .harness_builder import (
    PROPERTY_HARNESS_NAME,
    build_consolidated_payload,
    build_harness_files,
    build_property_harness,
)
from .models import ExecutionRequest, ExecutionResult, HarnessFile, TestOutcome


def format_execution_trace(trace: List[str], errors: Optional[List[str]] = None) -> str:
    """Format execution trace lines for persistence."""
    sections: List[str] = []
    if trace:
        sections.append("\n".join(trace))
    if errors:
        if sections:
            sections.append("")
        sections.append("# errors")
        sections.extend(errors)
    return "\n".join(sections) + ("\n" if sections else "")


def write_execution_trace_file(path: str | Path, trace: List[str], *,
                               errors: Optional[List[str]] = None) -> str:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(format_execution_trace(trace, errors), encoding="utf-8")
    return str(target)


def _all_errors_in(build_errors: List[Dict[str, Any]], filename: str) -> bool:
    return bool(build_errors) and all(
        (e.get("file") or "").endswith(filename) for e in build_errors)


def _execute(code: str, harness_files: List[HarnessFile],
             request: ExecutionRequest):
    return execute_solidity_candidate(
        code, harness_files,
        fuzz_runs=request.fuzz_runs,
        invariant_runs=request.invariant_runs,
        invariant_depth=request.invariant_depth,
        build_timeout_sec=request.build_timeout_sec,
        execution_timeout_sec=request.execution_timeout_sec,
        evm_version=request.evm_version,
        forge_bin=request.forge_bin,
        project_path=request.project_path,
        keep_project=request.keep_project,
    )


def _run_with_tier_isolation(code: str, harness_files: List[HarnessFile],
                             request: ExecutionRequest):
    """Run the tiers, and never let a bad Tier B harness silence Tier A.

    Tier B properties are LLM-authored and sometimes do not compile. Since forge
    builds the whole project at once, that would fail the build and discard the
    fuzz results too - reporting a harness defect as if the contract were
    unexecutable. When every build error is in the property file, the run is
    retried with only the programmatic tier.
    """
    output = _execute(code, harness_files, request)

    if not output.build_errors:
        return output
    if not _all_errors_in(output.build_errors, PROPERTY_HARNESS_NAME):
        return output

    fuzz_only = [h for h in harness_files if h.name != PROPERTY_HARNESS_NAME]
    if not fuzz_only:
        return output

    retry = _execute(code, fuzz_only, request)
    if retry.build_errors:
        # The candidate itself does not build either; report the original.
        return output

    retry.build_errors = output.build_errors
    retry.errors = list(output.errors)
    return retry


def _tier_status(outcomes: List[TestOutcome], harness_files: List[HarnessFile],
                 compiled: bool,
                 build_errors: Optional[List[Dict[str, Any]]] = None) -> Dict[str, str]:
    status: Dict[str, str] = {}
    failed_files = {(e.get("file") or "").split("/")[-1] for e in (build_errors or [])}
    for harness in harness_files:
        if harness.name in failed_files:
            # This tier's own harness did not compile - a harness defect.
            status[harness.tier] = "build_failed"
            continue
        if not compiled:
            status[harness.tier] = "build_failed"
            continue
        tier_outcomes = [o for o in outcomes if o.tier == harness.tier]
        if not tier_outcomes:
            status[harness.tier] = "skipped"
        elif any(o.failed() for o in tier_outcomes):
            status[harness.tier] = "failed"
        else:
            status[harness.tier] = "passed"
    for tier in ("fuzz", "properties"):
        status.setdefault(tier, "skipped")
    return status


def _unavailable(request: ExecutionRequest, reason: str) -> ExecutionResult:
    code = request.candidate_solidity or ""
    return ExecutionResult(
        compiled=False,
        success=False,
        errors=[],
        trace=[],
        model_kind="unknown",
        harness="",
        consolidated_payload=code,
        kernel_available=False,
        bridge_error=reason,
        diagnostics=build_execution_diagnostics(
            [], bridge_error=reason, kernel_available=False, compiled=False,
            success=False),
    )


def run_solidity_execution(request: ExecutionRequest) -> ExecutionResult:
    """Extract ABI, build harnesses, run Foundry, return a structured result."""
    code = request.candidate_solidity or ""

    if not is_runner_available():
        return _unavailable(
            request,
            "Foundry runner unavailable (install foundry, or set FORGE_BIN / "
            "SOLIDITY_RUNNER_ENABLED=false)")

    # --- stage 1: structure -------------------------------------------------
    topology = extract_topology(code)
    model_kind = classify_kind(topology)

    if not topology.compiled:
        errors = [e.get("formattedMessage") or e.get("message", "")
                  for e in topology.compile_errors]
        diagnostics = build_execution_diagnostics(
            [],
            build_errors=[{
                "severity": "error",
                "type": e.get("type"),
                "message": e.get("message", ""),
                "file": "src/Candidate.sol",
                "formatted": e.get("formattedMessage"),
            } for e in topology.compile_errors],
            bridge_error=None, compiled=False, success=False,
            model_kind=model_kind, kernel_available=True)
        return ExecutionResult(
            compiled=False, success=False, errors=errors, trace=[],
            model_kind=model_kind, harness="", consolidated_payload=code,
            kernel_available=True, extracted_topology=topology,
            diagnostics=diagnostics,
            tier_status={"fuzz": "build_failed", "properties": "build_failed"},
        )

    # --- stage 2: harness ---------------------------------------------------
    harness_files, harness_notes = build_harness_files(topology, request)
    consolidated = build_consolidated_payload(code, harness_files)
    harness_source = "\n\n".join(h.source for h in harness_files)

    if not harness_files:
        note = "; ".join(harness_notes) or "no harness could be generated"
        diagnostics = build_execution_diagnostics(
            [], harness_notes=harness_notes, bridge_error=note, compiled=True,
            success=False, model_kind=model_kind, kernel_available=True)
        return ExecutionResult(
            compiled=True, success=False, errors=[], trace=[],
            model_kind=model_kind, harness="", consolidated_payload=consolidated,
            kernel_available=True, extracted_topology=topology,
            bridge_error=note, diagnostics=diagnostics,
            harness_notes=harness_notes,
            tier_status={"fuzz": "skipped", "properties": "skipped"},
        )

    # --- stage 3: run -------------------------------------------------------
    output = _run_with_tier_isolation(code, harness_files, request)

    # A build error inside the property harness is a harness defect: the
    # candidate still compiled and its programmatic tier still ran.
    harness_only_build_failure = _all_errors_in(output.build_errors,
                                                PROPERTY_HARNESS_NAME)
    compiled = output.compiled and (not output.build_errors or harness_only_build_failure)
    failures = [o for o in output.outcomes if o.failed()]
    # `success` is a verdict on the *contract*: a property harness that failed
    # to compile is recorded (tier_status + diagnostics) but must not make the
    # refine loop keep rewriting a contract whose own tier passed.
    success = bool(compiled and output.outcomes and not failures
                   and not output.bridge_error)

    errors = list(output.errors)
    if output.bridge_error:
        errors.append(output.bridge_error)
    errors += [f"{o.name}: {o.reason or 'failed'}" for o in failures]

    trace = [
        f"{o.status:8} {o.tier:10} {o.kind:9} {o.name}"
        + (f"  [{o.failure_class}]" if o.failure_class else "")
        for o in output.outcomes
    ]

    diagnostics = build_execution_diagnostics(
        output.outcomes,
        build_errors=output.build_errors,
        harness_files=harness_files,
        harness_notes=harness_notes,
        bridge_error=output.bridge_error,
        compiled=compiled,
        success=success,
        model_kind=model_kind,
        kernel_available=output.kernel_available,
        extra={"abi": summarize_topology(topology),
               "forge": forge_version(),
               "fuzz_runs": request.fuzz_runs},
    )

    trace_path = None
    if request.trace_output_path:
        trace_path = write_execution_trace_file(request.trace_output_path, trace,
                                                errors=errors or None)
    diagnostics_path = None
    if request.diagnostics_output_path:
        diagnostics_path = write_execution_diagnostics_file(
            request.diagnostics_output_path, diagnostics)

    return ExecutionResult(
        compiled=compiled,
        success=success,
        errors=errors,
        trace=trace,
        model_kind=model_kind,
        harness=harness_source,
        consolidated_payload=consolidated,
        kernel_available=output.kernel_available,
        extracted_topology=topology,
        bridge_error=output.bridge_error,
        trace_path=trace_path,
        diagnostics=diagnostics,
        diagnostics_path=diagnostics_path,
        harness_files=harness_files,
        outcomes=output.outcomes,
        tier_status=_tier_status(output.outcomes, harness_files, compiled,
                                 output.build_errors),
        harness_notes=harness_notes,
    )


def validate_property_tests(candidate: str, property_tests: str,
                            request: Optional[ExecutionRequest] = None):
    """Compile-check Tier B properties against a candidate.

    Returns ``(ok, errors)`` where errors are the build diagnostics attributed to
    the property file. Lets the generation stage repair its own test code before
    spending a fuzz campaign on a harness that will not build.
    """
    from .foundry_bridge import check_harness_compiles

    request = request or ExecutionRequest(candidate_solidity=candidate)
    request.property_tests = property_tests

    topology = extract_topology(candidate)
    if not topology.compiled:
        return False, [{"message": "candidate does not compile", "file": "src/Candidate.sol"}]

    harness = build_property_harness(topology, request)
    if harness is None or not harness.source:
        return False, [{"message": "no property harness could be built",
                        "file": PROPERTY_HARNESS_NAME}]

    errors = check_harness_compiles(candidate, [harness],
                                    build_timeout_sec=request.build_timeout_sec,
                                    evm_version=request.evm_version,
                                    forge_bin=request.forge_bin)
    return (not errors), errors


def run_solidity_execution_from_file(
    sol_path: str,
    *,
    simulation_vectors: Optional[Dict[str, Any]] = None,
    execution_timeout_sec: float = 120.0,
    property_tests: Optional[str] = None,
) -> ExecutionResult:
    """Load a .sol file and execute."""
    code = Path(sol_path).read_text(encoding="utf-8")
    return run_solidity_execution(
        ExecutionRequest(
            candidate_solidity=code,
            simulation_vectors=simulation_vectors,
            execution_timeout_sec=execution_timeout_sec,
            property_tests=property_tests,
        )
    )


def _cli() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="Solidity execution harness (Foundry)")
    parser.add_argument("sol_file", help="Path to candidate .sol file")
    parser.add_argument("--dry-run", action="store_true",
                        help="Build the harness only; do not invoke forge")
    parser.add_argument("--fuzz-runs", type=int, default=256)
    parser.add_argument("--properties", help="File of Tier B property test functions")
    parser.add_argument("--keep-project", action="store_true",
                        help="Leave the generated Foundry project on disk")
    parser.add_argument("-o", "--output", help="Write JSON result to file")
    parser.add_argument("--trace-output", help="Write execution trace to a text file")
    parser.add_argument("--diagnostics-output", help="Write diagnostics JSON to a file")
    args = parser.parse_args()

    code = Path(args.sol_file).read_text(encoding="utf-8")
    properties = Path(args.properties).read_text(encoding="utf-8") if args.properties else None
    request = ExecutionRequest(
        candidate_solidity=code,
        fuzz_runs=args.fuzz_runs,
        property_tests=properties,
        keep_project=args.keep_project,
        trace_output_path=args.trace_output,
        diagnostics_output_path=args.diagnostics_output,
    )

    if args.dry_run:
        topology = extract_topology(code)
        harness_files, notes = build_harness_files(topology, request)
        result = ExecutionResult(
            compiled=topology.compiled, success=False, errors=[], trace=[],
            model_kind=classify_kind(topology),
            harness="\n\n".join(h.source for h in harness_files),
            consolidated_payload=build_consolidated_payload(code, harness_files),
            kernel_available=False, extracted_topology=topology,
            harness_files=harness_files, harness_notes=notes)
    else:
        result = run_solidity_execution(request)

    text = json.dumps(result.to_dict(), indent=2)
    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")
        print(f"Wrote {args.output}")
    else:
        print(text)


if __name__ == "__main__":
    _cli()
