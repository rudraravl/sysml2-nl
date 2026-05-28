"""
Self-contained SysML v2 execution harness (SENTINEL Layer 2).

Public API::

    from nl2sysml.sysml_execution import ExecutionRequest, run_sysml_execution

    result = run_sysml_execution(ExecutionRequest(candidate_sysml=code))
    payload = result.to_dict()
"""

from .extractor import classify_topology, extract_topology, requires_layer2
from .models import (
    ExecutionRequest,
    ExecutionResult,
    ExtractedTopology,
    HarnessBuildResult,
    HarnessMetadata,
    KernelExecutionOutput,
    Layer2Status,
    ModelProfile,
)
from .harness_builder import build_consolidated_payload, build_harness_block
from .orchestrator import run_sysml_execution, run_sysml_execution_from_file
from .sysml_runtime_bridge import execute_sysml_candidate

__all__ = [
    "ExecutionRequest",
    "ExecutionResult",
    "ExtractedTopology",
    "HarnessBuildResult",
    "HarnessMetadata",
    "KernelExecutionOutput",
    "Layer2Status",
    "ModelProfile",
    "build_consolidated_payload",
    "build_harness_block",
    "classify_topology",
    "execute_sysml_candidate",
    "extract_topology",
    "requires_layer2",
    "run_sysml_execution",
    "run_sysml_execution_from_file",
]
