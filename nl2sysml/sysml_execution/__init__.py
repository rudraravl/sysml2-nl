"""
Self-contained SysML v2 execution harness (SENTINEL Layer 2).

Public API::

    from nl2sysml.sysml_execution import ExecutionRequest, run_sysml_execution

    result = run_sysml_execution(ExecutionRequest(candidate_sysml=code))
    payload = result.to_dict()
"""

from .models import (
    ExecutionRequest,
    ExecutionResult,
    ExtractedTopology,
    KernelExecutionOutput,
)
from .orchestrator import run_sysml_execution, run_sysml_execution_from_file
from .sysml_runtime_bridge import execute_sysml_candidate

__all__ = [
    "ExecutionRequest",
    "ExecutionResult",
    "ExtractedTopology",
    "KernelExecutionOutput",
    "execute_sysml_candidate",
    "run_sysml_execution",
    "run_sysml_execution_from_file",
]
