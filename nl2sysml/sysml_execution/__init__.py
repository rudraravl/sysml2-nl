"""
SysML v2 execution harness (MVP).

Public API::

    from nl2sysml.sysml_execution import ExecutionRequest, run_sysml_execution

    result = run_sysml_execution(ExecutionRequest(candidate_sysml=code))
    payload = result.to_dict()
"""

from .extractor import classify_kind, collect_state_machine_accept_payloads, extract_topology, ordered_transition_path
from .models import (
    ExecutionRequest,
    ExecutionResult,
    ExtractedTopology,
    GuardCondition,
    KernelExecutionOutput,
)
from .harness_builder import build_consolidated_payload, build_harness_block, build_harness_block_with_mocks
from .diagnostics import (
    build_compiler_diagnostics,
    parse_diagnostic_line,
    write_compiler_diagnostics_file,
)
from .orchestrator import run_sysml_execution, run_sysml_execution_from_file
from .orchestrator import format_execution_trace, write_execution_trace_file
from .sysml_runtime_bridge import execute_sysml_candidate
from .vector_planner import (
    InputCandidate,
    PayloadResolution,
    TypeClassification,
    candidates_for_input,
    candidates_for_trigger,
    classify_input_type,
    inject_mock_defs_into_root_package,
    input_types_for_target,
    resolve_payload_types,
    satisfying_value_for_guard,
    type_exists_in_topology,
    unsupported_reason_for_input,
)

__all__ = [
    "ExecutionRequest",
    "ExecutionResult",
    "ExtractedTopology",
    "GuardCondition",
    "KernelExecutionOutput",
    "InputCandidate",
    "PayloadResolution",
    "TypeClassification",
    "build_compiler_diagnostics",
    "build_consolidated_payload",
    "build_harness_block",
    "build_harness_block_with_mocks",
    "classify_kind",
    "classify_input_type",
    "candidates_for_input",
    "candidates_for_trigger",
    "collect_state_machine_accept_payloads",
    "execute_sysml_candidate",
    "extract_topology",
    "format_execution_trace",
    "inject_mock_defs_into_root_package",
    "input_types_for_target",
    "ordered_transition_path",
    "parse_diagnostic_line",
    "resolve_payload_types",
    "run_sysml_execution",
    "run_sysml_execution_from_file",
    "satisfying_value_for_guard",
    "type_exists_in_topology",
    "write_compiler_diagnostics_file",
    "write_execution_trace_file",
    "unsupported_reason_for_input",
]
