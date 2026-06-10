"""Data models for the SysML v2 execution harness."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional


class ModelProfile(str, Enum):
    """Topology classification for harness selection."""

    PART_STATE = "part_state"
    ACTION_COMPOSITE = "action_composite"
    ANALYSIS_TOOL = "analysis_tool"
    STRUCTURAL_ONLY = "structural_only"


class Layer2Status(str, Enum):
    VERIFIED = "verified"
    BYPASSED = "bypassed"
    NOT_REQUIRED = "not_required"
    KERNEL_UNAVAILABLE = "kernel_unavailable"


@dataclass
class ExecutionRequest:
    """Input to the three-phase execution pipeline."""

    candidate_sysml: str
    target_behaviors: Optional[List[str]] = None
    target_invariants: Optional[List[str]] = None
    simulation_vectors: Optional[Dict[str, Any]] = None
    kernel_name: str = "sysml"
    execution_timeout_sec: float = 120.0
    kernel_ready_timeout_sec: float = 180.0
    jupyter_path: Optional[str] = None  # override; default uses active .venv kernelspecs
    try_preset_vectors: bool = False
    preset_values: Optional[List[Any]] = None


@dataclass
class ExtractedAttribute:
    name: str
    owner: Optional[str] = None
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
class ExtractedActionDef:
    name: str
    inputs: List[str] = field(default_factory=list)
    outputs: List[str] = field(default_factory=list)
    owner: Optional[str] = None
    raw_line: str = ""
    has_tool_execution: bool = False


@dataclass
class ExtractedActionUsage:
    name: str
    type_ref: Optional[str] = None
    package_owner: Optional[str] = None
    is_composite: bool = False
    inputs: List[str] = field(default_factory=list)
    outputs: List[str] = field(default_factory=list)
    raw_line: str = ""


@dataclass
class ExtractedAcceptAction:
    action_name: str
    signal_param: str
    signal_type: str
    owner: Optional[str] = None
    raw_line: str = ""


@dataclass
class ExtractedFlow:
    source: str
    target: str
    owner: Optional[str] = None
    raw_line: str = ""


@dataclass
class ExtractedSuccession:
    source: str
    target: str
    owner: Optional[str] = None
    raw_line: str = ""


@dataclass
class ExtractedTopology:
    """Structural summary extracted from candidate SysML text."""

    root_package: Optional[str] = None
    packages: List[str] = field(default_factory=list)
    part_defs: List[str] = field(default_factory=list)
    part_def_owners: Dict[str, str] = field(default_factory=dict)
    part_instances: List[str] = field(default_factory=list)
    attributes: List[ExtractedAttribute] = field(default_factory=list)
    attribute_defs: List[ExtractedAttributeDef] = field(default_factory=list)
    constraints: List[ExtractedConstraint] = field(default_factory=list)
    state_machines: List[str] = field(default_factory=list)
    actions: List[str] = field(default_factory=list)
    action_defs: List[ExtractedActionDef] = field(default_factory=list)
    action_usages: List[ExtractedActionUsage] = field(default_factory=list)
    accept_actions: List[ExtractedAcceptAction] = field(default_factory=list)
    flows: List[ExtractedFlow] = field(default_factory=list)
    successions: List[ExtractedSuccession] = field(default_factory=list)
    has_tool_execution_metadata: bool = False

    def primary_package(self) -> Optional[str]:
        return self.root_package or (self.packages[0] if self.packages else None)

    def primary_part_def(self) -> Optional[str]:
        return self.part_defs[0] if self.part_defs else None

    def qualified_part_def(self, name: str) -> str:
        """Return a root/package-qualified reference for a part definition."""
        root = self.primary_package()
        owner = self.part_def_owners.get(name)
        segments = [segment for segment in (root, owner, name) if segment]
        deduped: List[str] = []
        for segment in segments:
            if not deduped or segment != deduped[-1]:
                deduped.append(segment)
        return "::".join(self.quoted_name(segment) for segment in deduped)

    def primary_part_instance(self) -> Optional[str]:
        return self.part_instances[0] if self.part_instances else None

    def primary_composite_usage(self) -> Optional[ExtractedActionUsage]:
        composites = [u for u in self.action_usages if u.is_composite]
        if not composites:
            return None
        usages_pkg = [u for u in composites if (u.package_owner or "").lower() == "usages"]
        return usages_pkg[0] if usages_pkg else composites[0]

    def quoted_name(self, name: str) -> str:
        """Return SysML-safe reference for an identifier (quoted if needed)."""
        if not name:
            return name
        if " " in name or not name.replace("_", "").isalnum():
            return f"'{name}'"
        return name


@dataclass
class HarnessMetadata:
    profile: ModelProfile
    probes_emitted: int = 0
    probes_runnable: bool = False
    primary_target: Optional[str] = None
    skipped_reasons: List[str] = field(default_factory=list)
    has_perform_probe: bool = False
    has_assign_probe: bool = False
    has_assert_probe: bool = False
    required_inputs: List[str] = field(default_factory=list)
    provided_inputs: List[str] = field(default_factory=list)
    missing_inputs: List[str] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "profile": self.profile.value,
            "probes_emitted": self.probes_emitted,
            "probes_runnable": self.probes_runnable,
            "primary_target": self.primary_target,
            "skipped_reasons": self.skipped_reasons,
            "has_perform_probe": self.has_perform_probe,
            "has_assign_probe": self.has_assign_probe,
            "has_assert_probe": self.has_assert_probe,
            "required_inputs": self.required_inputs,
            "provided_inputs": self.provided_inputs,
            "missing_inputs": self.missing_inputs,
        }


@dataclass
class HarnessBuildResult:
    harness_block: str
    metadata: HarnessMetadata


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
    timed_out: bool = False


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
    syntax_ok: bool = False
    behavior_ok: bool = False
    layer2_status: str = Layer2Status.NOT_REQUIRED.value
    harness_metadata: Optional[Dict[str, Any]] = None
    vector_source: Optional[str] = None
    semantic_validity: Optional[str] = None
    selected_simulation_vectors: Optional[Dict[str, Any]] = None
    vector_attempts: List[Dict[str, Any]] = field(default_factory=list)
    kernel_timed_out: bool = False

    def to_dict(self) -> Dict[str, Any]:
        data = asdict(self)
        if self.extracted_topology is not None:
            data["extracted_topology"] = asdict(self.extracted_topology)
        return data
