"""Data models for the Solidity execution harness (STUB).

Retargeted from nl2sysml/sysml_execution/models.py. The SysML-specific topology
extraction structures are dropped; the ExecutionResult contract consumed by the
generation engine (agent_rag_moe._refine_with_kernel and quality_gate) is kept
field-for-field so nothing downstream changes.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any, Dict, List, Optional


@dataclass
class ExecutionRequest:
    """Input to the execution pipeline.

    Note: the field is ``candidate_solidity`` (the Solidity analog of nl2sysml's
    ``candidate_sysml``). A ``candidate_sysml`` alias is accepted for callers
    transcribed verbatim from the SysML pipeline.
    """

    candidate_solidity: str = ""
    simulation_vectors: Optional[Dict[str, Any]] = None
    harness_name: str = "foundry"
    execution_timeout_sec: float = 120.0
    build_timeout_sec: float = 180.0
    project_path: Optional[str] = None
    trace_output_path: Optional[str] = None
    diagnostics_output_path: Optional[str] = None

    # Back-compat: allow ExecutionRequest(candidate_sysml=...) from copied code.
    candidate_sysml: Optional[str] = None

    def __post_init__(self):
        if not self.candidate_solidity and self.candidate_sysml:
            self.candidate_solidity = self.candidate_sysml
        # Keep both views consistent.
        self.candidate_sysml = self.candidate_solidity


@dataclass
class HarnessExecutionOutput:
    """Raw output from the Foundry/Hardhat runner bridge."""

    stdout: List[str] = field(default_factory=list)
    errors: List[str] = field(default_factory=list)
    trace: List[str] = field(default_factory=list)
    kernel_available: bool = True
    bridge_error: Optional[str] = None


@dataclass
class ExecutionResult:
    """Structured output from the execution pipeline.

    Same contract as nl2sysml's ExecutionResult (minus SysML topology), so
    agent_rag_moe._refine_with_kernel / _format_kernel_errors and
    quality_gate.layer2_executor consume it unchanged.
    """

    compiled: bool
    success: bool
    errors: List[str]
    trace: List[str]
    model_kind: str
    harness: str
    consolidated_payload: str
    kernel_available: bool
    bridge_error: Optional[str] = None
    trace_path: Optional[str] = None
    diagnostics: Optional[Dict[str, Any]] = None
    diagnostics_path: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)
