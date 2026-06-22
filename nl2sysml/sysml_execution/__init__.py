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
from .sysml_runtime_bridge import execute_sysml_candidate
from .vector_planner import InputCandidate, candidates_for_input, input_types_for_target

__all__ = [
    "ExecutionRequest",
    "ExecutionResult",
    "ExtractedTopology",
    "KernelExecutionOutput",
    "InputCandidate",
    "build_consolidated_payload",
    "build_harness_block",
    "classify_kind",
    "candidates_for_input",
    "execute_sysml_candidate",
    "extract_topology",
    "input_types_for_target",
    "run_sysml_execution",
    "run_sysml_execution_from_file",
]
