"""Solidity execution harness (Foundry).

Mirror of nl2sysml/sysml_execution, retargeted to Solidity: the generation
engine calls this to *run* a candidate contract and feed runtime failures back
into refinement.

Flow (same shape as the SysML pipeline):

    extract_topology   ABI from solc: contracts, functions, mutability, events
        v
    build_harness_files   Tier A programmatic fuzz + boundary probing
                          Tier B requirement-derived properties (from generation)
        v
    execute_solidity_candidate   temp Foundry project, forge build + forge test
        v
    build_execution_diagnostics  structured failures for the repair loop

Public API::

    from nl2solidity.solidity_execution import ExecutionRequest, run_solidity_execution

    result = run_solidity_execution(ExecutionRequest(candidate_solidity=code))
    payload = result.to_dict()

Requires Foundry (`forge`) on PATH. Without it, run_solidity_execution returns
kernel_available=False and the kernel-refine stage in agent_rag_moe no-ops
cleanly, exactly as nl2sysml behaves with no Jupyter kernel.
"""

from .models import (
    ExecutionRequest,
    ExecutionResult,
    ExtractedContract,
    ExtractedError,
    ExtractedEvent,
    ExtractedFunction,
    ExtractedParam,
    ExtractedTopology,
    HarnessExecutionOutput,
    HarnessFile,
    SecurityFinding,
    SecurityResult,
    TestOutcome,
)
from .extractor import classify_kind, extract_topology, summarize_topology
from .vector_planner import (
    InputCandidate,
    TypeClassification,
    boundary_values,
    boundary_values_for_param,
    boundary_vectors,
    call_expression_for,
    classify_input_type,
    constructor_arguments,
    default_value,
    fuzz_declarations,
    unsupported_reason_for_function,
    unsupported_reason_for_input,
)
from .harness_builder import (
    build_consolidated_payload,
    build_fuzz_harness,
    build_harness_files,
    build_property_harness,
)
from .diagnostics import (
    build_execution_diagnostics,
    categorize_message,
    write_execution_diagnostics_file,
)
from .foundry_bridge import (
    PANIC_CLASSES,
    check_harness_compiles,
    ensure_forge_std,
    execute_solidity_candidate,
    forge_binary,
    forge_version,
    is_runner_available,
)
from .orchestrator import (
    format_execution_trace,
    run_solidity_execution,
    run_solidity_execution_from_file,
    validate_property_tests,
    write_execution_trace_file,
)

__all__ = [
    "ExecutionRequest",
    "ExecutionResult",
    "ExtractedContract",
    "ExtractedError",
    "ExtractedEvent",
    "ExtractedFunction",
    "ExtractedParam",
    "ExtractedTopology",
    "HarnessExecutionOutput",
    "HarnessFile",
    "InputCandidate",
    "PANIC_CLASSES",
    "SecurityFinding",
    "SecurityResult",
    "TestOutcome",
    "TypeClassification",
    "boundary_values",
    "boundary_values_for_param",
    "boundary_vectors",
    "call_expression_for",
    "build_consolidated_payload",
    "build_execution_diagnostics",
    "build_fuzz_harness",
    "build_harness_files",
    "build_property_harness",
    "check_harness_compiles",
    "categorize_message",
    "classify_input_type",
    "classify_kind",
    "constructor_arguments",
    "default_value",
    "ensure_forge_std",
    "execute_solidity_candidate",
    "extract_topology",
    "format_execution_trace",
    "forge_binary",
    "forge_version",
    "fuzz_declarations",
    "is_runner_available",
    "run_solidity_execution",
    "run_solidity_execution_from_file",
    "summarize_topology",
    "unsupported_reason_for_function",
    "unsupported_reason_for_input",
    "validate_property_tests",
    "write_execution_diagnostics_file",
    "write_execution_trace_file",
]
