"""
SysML v2 execution harness (MVP).

Public API::

    from nl2sysml.sysml_execution import ExecutionRequest, run_sysml_execution

    result = run_sysml_execution(ExecutionRequest(candidate_sysml=code))
    payload = result.to_dict()
"""

from .extractor import classify_kind, extract_topology
from .models import (
    ExecutionRequest,
    ExecutionResult,
    ExtractedTopology,
    KernelExecutionOutput,
)
from .harness_builder import build_consolidated_payload, build_harness_block
from .orchestrator import run_sysml_execution, run_sysml_execution_from_file
from .orchestrator import format_execution_trace, write_execution_trace_file
from .sysml_runtime_bridge import execute_sysml_candidate
from .vector_planner import (
    InputCandidate,
    TypeClassification,
    candidates_for_input,
    candidates_for_trigger,
    classify_input_type,
    input_types_for_target,
    unsupported_reason_for_input,
)

__all__ = [
    "ExecutionRequest",
    "ExecutionResult",
    "ExtractedTopology",
    "KernelExecutionOutput",
    "InputCandidate",
    "TypeClassification",
    "build_consolidated_payload",
    "build_harness_block",
    "classify_kind",
    "classify_input_type",
    "candidates_for_input",
    "candidates_for_trigger",
    "execute_sysml_candidate",
    "extract_topology",
    "format_execution_trace",
    "input_types_for_target",
    "run_sysml_execution",
    "run_sysml_execution_from_file",
    "write_execution_trace_file",
    "unsupported_reason_for_input",
]
