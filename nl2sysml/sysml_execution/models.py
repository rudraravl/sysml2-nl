"""Data models for the SysML v2 execution harness."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any, Dict, List, Optional


@dataclass
class ExecutionRequest:
    """Input to the three-phase execution pipeline."""

    candidate_sysml: str
    target_behaviors: Optional[List[str]] = None
    target_invariants: Optional[List[str]] = None
    simulation_vectors: Optional[Dict[str, Any]] = None
    kernel_name: str = "sysml"
    execution_timeout_sec: float = 120.0


@dataclass
class ExtractedAttribute:
    name: str
    owner: Optional[str] = None
    raw_line: str = ""


@dataclass
class ExtractedConstraint:
    name: str
    owner: Optional[str] = None
    raw_line: str = ""


@dataclass
class ExtractedTopology:
    """Structural summary extracted from candidate SysML text."""

    packages: List[str] = field(default_factory=list)
    part_defs: List[str] = field(default_factory=list)
    part_instances: List[str] = field(default_factory=list)
    attributes: List[ExtractedAttribute] = field(default_factory=list)
    constraints: List[ExtractedConstraint] = field(default_factory=list)
    state_machines: List[str] = field(default_factory=list)
    actions: List[str] = field(default_factory=list)

    def primary_package(self) -> Optional[str]:
        return self.packages[0] if self.packages else None

    def primary_part_def(self) -> Optional[str]:
        return self.part_defs[0] if self.part_defs else None

    def primary_part_instance(self) -> Optional[str]:
        return self.part_instances[0] if self.part_instances else None


@dataclass
class KernelExecutionOutput:
    """Raw output from the Jupyter SysML kernel bridge."""

    execution_status_payload: str
    stdout_lines: List[str] = field(default_factory=list)
    stderr_lines: List[str] = field(default_factory=list)
    error_lines: List[str] = field(default_factory=list)
    raw_kernel_messages: List[Dict[str, Any]] = field(default_factory=list)
    shell_reply: Optional[Dict[str, Any]] = None
    kernel_available: bool = True
    bridge_error: Optional[str] = None


@dataclass
class ExecutionResult:
    """Structured output for orchestration / repair loops."""

    success: bool
    execution_status_payload: str
    execution_logs: List[str]
    constraint_manifest: List[Dict[str, Any]]
    diagnostic_pack: Optional[Dict[str, Any]]
    raw_kernel_messages: List[Dict[str, Any]]
    consolidated_payload: str = ""
    extracted_topology: Optional[ExtractedTopology] = None
    harness_block: str = ""

    def to_dict(self) -> Dict[str, Any]:
        data = asdict(self)
        if self.extracted_topology is not None:
            data["extracted_topology"] = asdict(self.extracted_topology)
        return data
