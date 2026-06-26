"""Data models for the SysML v2 execution harness (MVP)."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any, Dict, List, Literal, Optional

ModelKind = Literal["behavioral", "structural", "empty"]


@dataclass
class ExecutionRequest:
    """Input to the execution pipeline."""

    candidate_sysml: str
    simulation_vectors: Optional[Dict[str, Any]] = None
    kernel_name: str = "sysml"
    execution_timeout_sec: float = 120.0
    kernel_ready_timeout_sec: float = 180.0
    jupyter_path: Optional[str] = None
    trace_output_path: Optional[str] = None


@dataclass
class ExtractedAttribute:
    name: str
    owner: Optional[str] = None
    has_default: bool = False
    raw_line: str = ""


@dataclass
class ExtractedAttributeDef:
    name: str
    owner: Optional[str] = None
    raw_line: str = ""


@dataclass
class ExtractedConstraint:
    name: str
    owner: Optional[str] = None
    raw_line: str = ""


@dataclass
class ExtractedAcceptTrigger:
    """Accept blocker inside a target action body (ordered execution dependency)."""

    payload_type: str
    param: Optional[str] = None
    port: Optional[str] = None
    raw_line: str = ""


@dataclass
class ExtractedActionDef:
    name: str
    inputs: List[str] = field(default_factory=list)
    input_types: Dict[str, str] = field(default_factory=dict)
    outputs: List[str] = field(default_factory=list)
    required_triggers: List[ExtractedAcceptTrigger] = field(default_factory=list)
    owner: Optional[str] = None
    raw_line: str = ""


@dataclass
class ExtractedActionUsage:
    name: str
    type_ref: Optional[str] = None
    package_owner: Optional[str] = None
    is_composite: bool = False
    inputs: List[str] = field(default_factory=list)
    input_types: Dict[str, str] = field(default_factory=dict)
    outputs: List[str] = field(default_factory=list)
    required_triggers: List[ExtractedAcceptTrigger] = field(default_factory=list)
    raw_line: str = ""


@dataclass
class ExtractedAcceptAction:
    action_name: str
    signal_param: str
    signal_type: str
    owner: Optional[str] = None
    raw_line: str = ""


@dataclass
class ExtractedSendAction:
    action_name: str
    signal_type: str
    owner: Optional[str] = None
    raw_line: str = ""


@dataclass
class ExtractedStateTransition:
    name: Optional[str] = None
    source: Optional[str] = None
    target: Optional[str] = None
    trigger: Optional[str] = None  # accept <Signal> or if "condition"
    trigger_kind: Optional[str] = None  # "accept" | "if"
    owner: Optional[str] = None
    raw_line: str = ""


@dataclass
class ExtractedStateMachine:
    name: str
    owner: Optional[str] = None
    transitions: List[ExtractedStateTransition] = field(default_factory=list)
    raw_line: str = ""


@dataclass
class ExtractedTopology:
    """Structural summary extracted from candidate SysML text."""

    root_package: Optional[str] = None
    packages: List[str] = field(default_factory=list)
    part_defs: List[str] = field(default_factory=list)
    attributes: List[ExtractedAttribute] = field(default_factory=list)
    attribute_defs: List[ExtractedAttributeDef] = field(default_factory=list)
    constraints: List[ExtractedConstraint] = field(default_factory=list)
    state_machines: List[ExtractedStateMachine] = field(default_factory=list)
    action_defs: List[ExtractedActionDef] = field(default_factory=list)
    action_usages: List[ExtractedActionUsage] = field(default_factory=list)
    accept_actions: List[ExtractedAcceptAction] = field(default_factory=list)
    send_actions: List[ExtractedSendAction] = field(default_factory=list)

    def primary_package(self) -> Optional[str]:
        return self.root_package or (self.packages[0] if self.packages else None)

    def primary_part_def(self) -> Optional[str]:
        return self.part_defs[0] if self.part_defs else None

    def primary_composite_usage(self) -> Optional[ExtractedActionUsage]:
        composites = [u for u in self.action_usages if u.is_composite]
        if not composites:
            return None
        usages_pkg = [u for u in composites if (u.package_owner or "").lower() == "usages"]
        return usages_pkg[0] if usages_pkg else composites[0]

    def primary_action_def(self) -> Optional[ExtractedActionDef]:
        return self.action_defs[0] if self.action_defs else None

    def required_triggers_for_target(self) -> List[ExtractedAcceptTrigger]:
        usage = self.primary_composite_usage()
        if usage and usage.required_triggers:
            return usage.required_triggers
        action_def = self.primary_action_def()
        return list(action_def.required_triggers) if action_def else []

    def quoted_name(self, name: str) -> str:
        """Return SysML-safe reference for an identifier (quoted if needed)."""
        if not name:
            return name
        if " " in name or not name.replace("_", "").isalnum():
            return f"'{name}'"
        return name


@dataclass
class KernelExecutionOutput:
    """Raw output from the Jupyter SysML kernel bridge."""

    stdout: List[str] = field(default_factory=list)
    errors: List[str] = field(default_factory=list)
    trace: List[str] = field(default_factory=list)
    kernel_available: bool = True
    bridge_error: Optional[str] = None


@dataclass
class ExecutionResult:
    """Structured output from the execution pipeline."""

    compiled: bool
    success: bool
    errors: List[str]
    trace: List[str]
    model_kind: str
    harness: str
    consolidated_payload: str
    kernel_available: bool
    extracted_topology: Optional[ExtractedTopology] = None
    bridge_error: Optional[str] = None
    trace_path: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        data = asdict(self)
        if self.extracted_topology is not None:
            data["extracted_topology"] = asdict(self.extracted_topology)
        return data
