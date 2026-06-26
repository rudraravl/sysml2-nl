"""
SysML v2 execution orchestrator (MVP).

    from nl2sysml.sysml_execution import ExecutionRequest, run_sysml_execution

    result = run_sysml_execution(ExecutionRequest(candidate_sysml=code))
    print(result.compiled, result.errors)
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any, Dict, List, Optional

from .extractor import classify_kind, extract_topology
from .harness_builder import build_consolidated_payload, build_harness_block
from .models import ExecutionRequest, ExecutionResult, KernelExecutionOutput
from .sysml_runtime_bridge import execute_sysml_candidate

_ERROR_RE = re.compile(r"ERROR:", re.IGNORECASE)


def _flatten_lines(chunks: List[str]) -> List[str]:
    lines: List[str] = []
    for chunk in chunks:
        for part in chunk.splitlines():
            part = part.strip()
            if part:
                lines.append(part)
    return lines


def _is_compiled(kernel_out: KernelExecutionOutput) -> bool:
    if not kernel_out.kernel_available or kernel_out.bridge_error:
        return False
    combined = _kernel_trace_lines(kernel_out) + _flatten_lines(kernel_out.errors)
    return not any(_ERROR_RE.search(line) for line in combined)


def _kernel_trace_lines(kernel_out: KernelExecutionOutput) -> List[str]:
    source = kernel_out.trace if kernel_out.trace else kernel_out.stdout
    return _flatten_lines(source)


def format_execution_trace(trace: List[str], errors: Optional[List[str]] = None) -> str:
    """Format compiler/kernel trace lines for persistence."""
    sections: List[str] = []
    if trace:
        sections.append("\n".join(trace))
    if errors:
        if sections:
            sections.append("")
        sections.append("# errors")
        sections.extend(errors)
    return "\n".join(sections) + ("\n" if sections else "")


def write_execution_trace_file(
    path: str | Path,
    trace: List[str],
    *,
    errors: Optional[List[str]] = None,
) -> str:
    """Write execution trace (and optional errors) to a text file."""
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(format_execution_trace(trace, errors), encoding="utf-8")
    return str(target)


def run_sysml_execution(request: ExecutionRequest) -> ExecutionResult:
    """Extract topology, build harness, run kernel, return structured result."""
    topology = extract_topology(request.candidate_sysml)
    model_kind = classify_kind(topology)
    harness = build_harness_block(topology, request)
    consolidated = build_consolidated_payload(request.candidate_sysml, harness)

    kernel_out = execute_sysml_candidate(
        consolidated,
        kernel_name=request.kernel_name,
        timeout_sec=request.execution_timeout_sec,
        jupyter_path=request.jupyter_path,
        kernel_ready_timeout_sec=request.kernel_ready_timeout_sec,
    )

    trace = _kernel_trace_lines(kernel_out)
    errors = _flatten_lines(kernel_out.errors)
    if kernel_out.bridge_error:
        errors.append(kernel_out.bridge_error)

    compiled = _is_compiled(kernel_out)

    trace_path: Optional[str] = None
    if request.trace_output_path:
        trace_path = write_execution_trace_file(
            request.trace_output_path,
            trace,
            errors=errors or None,
        )

    return ExecutionResult(
        compiled=compiled,
        success=compiled,
        errors=errors,
        trace=trace,
        model_kind=model_kind,
        harness=harness,
        consolidated_payload=consolidated,
        kernel_available=kernel_out.kernel_available,
        extracted_topology=topology,
        bridge_error=kernel_out.bridge_error,
        trace_path=trace_path,
    )


def run_sysml_execution_from_file(
    sysml_path: str,
    *,
    simulation_vectors: Optional[Dict[str, Any]] = None,
    kernel_name: str = "sysml",
    execution_timeout_sec: float = 120.0,
) -> ExecutionResult:
    """Load a .sysml file and execute."""
    code = Path(sysml_path).read_text(encoding="utf-8")
    return run_sysml_execution(
        ExecutionRequest(
            candidate_sysml=code,
            simulation_vectors=simulation_vectors,
            kernel_name=kernel_name,
            execution_timeout_sec=execution_timeout_sec,
        )
    )


def _cli() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="SysML v2 execution harness")
    parser.add_argument("sysml_file", help="Path to candidate .sysml file")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Build harness only; do not invoke kernel",
    )
    parser.add_argument("-o", "--output", help="Write JSON result to file")
    parser.add_argument(
        "--trace-output",
        help="Write compiler/kernel execution trace to a text file",
    )
    args = parser.parse_args()

    code = Path(args.sysml_file).read_text(encoding="utf-8")
    req = ExecutionRequest(
        candidate_sysml=code,
        trace_output_path=args.trace_output,
    )

    if args.dry_run:
        topology = extract_topology(code)
        harness = build_harness_block(topology, req)
        result = ExecutionResult(
            compiled=False,
            success=False,
            errors=[],
            trace=[],
            model_kind=classify_kind(topology),
            harness=harness,
            consolidated_payload=build_consolidated_payload(code, harness),
            kernel_available=False,
            extracted_topology=topology,
        )
    else:
        result = run_sysml_execution(req)

    text = json.dumps(result.to_dict(), indent=2)
    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")
        print(f"Wrote {args.output}")
    else:
        print(text)


if __name__ == "__main__":
    _cli()
