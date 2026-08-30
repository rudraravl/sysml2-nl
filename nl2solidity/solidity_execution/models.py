"""Data models for the Solidity execution harness.

Retargeted from nl2sysml/sysml_execution/models.py. The SysML topology types are
replaced by ABI-derived contract structure; the ExecutionResult contract consumed
by the generation engine (agent_rag_moe._refine_with_kernel and
quality_gate.layer2_executor) keeps its field names so nothing downstream changes.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any, Dict, List, Literal, Optional

# Deployable shape of the candidate, analogous to SysML's behavioral/structural.
ModelKind = Literal["empty", "stateless", "stateful", "payable"]

# Which harness tiers to build and run.
Tier = Literal["fuzz", "properties"]


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

    # --- Tier A: programmatic fuzzing ------------------------------------
    fuzz_runs: int = 256
    """Random inputs per fuzzed function. Foundry's own default is 256; the
    cost is linear in runs x fuzzable functions x candidates, so batch runs
    usually want this lower than an interactive audit would."""

    max_fuzz_functions: int = 24
    """Cap on generated fuzz tests, so a 100-function contract cannot make one
    candidate dominate a batch."""

    numeric_bound: str = "1e30"
    """Upper magnitude fuzzed numeric parameters are bounded to. Panics inside
    this domain are defects; the boundary tests probe past it and tolerate
    checked-arithmetic reverts. See harness_builder for the rationale."""

    include_boundary_tests: bool = True
    """Emit explicit boundary-value unit tests (0, 1, type max, address(0), ...)
    alongside the random fuzzing."""

    # --- Tier B: LLM-authored properties ---------------------------------
    property_tests: Optional[str] = None
    """Solidity test-function bodies produced by the generation stage from the
    NL requirement. Held fixed across repair iterations so a repair cannot pass
    by weakening its own properties."""

    invariant_runs: int = 64
    invariant_depth: int = 32

    tiers: List[str] = field(default_factory=lambda: ["fuzz", "properties"])

    # --- runner configuration --------------------------------------------
    forge_bin: Optional[str] = None
    evm_version: Optional[str] = None
    keep_project: bool = False
    """Leave the generated Foundry project on disk (debugging)."""

    # Back-compat: allow ExecutionRequest(candidate_sysml=...) from copied code.
    candidate_sysml: Optional[str] = None

    def __post_init__(self):
        if not self.candidate_solidity and self.candidate_sysml:
            self.candidate_solidity = self.candidate_sysml
        # Keep both views consistent.
        self.candidate_sysml = self.candidate_solidity


# --------------------------------------------------------------------------
# ABI-derived structure (the Solidity analog of ExtractedTopology)
# --------------------------------------------------------------------------


@dataclass
class ExtractedParam:
    """One ABI input/output parameter."""

    name: str
    type_name: str
    internal_type: Optional[str] = None
    components: List["ExtractedParam"] = field(default_factory=list)

    def is_tuple(self) -> bool:
        return self.type_name.startswith("tuple")


@dataclass
class ExtractedFunction:
    """One callable ABI entry."""

    name: str
    kind: str = "function"  # function | constructor | receive | fallback
    inputs: List[ExtractedParam] = field(default_factory=list)
    outputs: List[ExtractedParam] = field(default_factory=list)
    state_mutability: str = "nonpayable"  # pure | view | nonpayable | payable
    selector: Optional[str] = None

    def is_mutating(self) -> bool:
        return self.state_mutability in ("nonpayable", "payable")

    def is_payable(self) -> bool:
        return self.state_mutability == "payable"

    def signature(self) -> str:
        return f"{self.name}({','.join(p.type_name for p in self.inputs)})"


@dataclass
class ExtractedEvent:
    name: str
    inputs: List[ExtractedParam] = field(default_factory=list)
    anonymous: bool = False


@dataclass
class ExtractedError:
    name: str
    inputs: List[ExtractedParam] = field(default_factory=list)


@dataclass
class ExtractedContract:
    """One compiled contract from the candidate source unit."""

    name: str
    deployable: bool = False
    """True when solc produced non-empty creation bytecode (not an interface,
    abstract contract, or library)."""
    functions: List[ExtractedFunction] = field(default_factory=list)
    events: List[ExtractedEvent] = field(default_factory=list)
    errors: List[ExtractedError] = field(default_factory=list)
    constructor: Optional[ExtractedFunction] = None
    receive_ether: bool = False
    fallback_payable: bool = False

    def external_functions(self) -> List[ExtractedFunction]:
        return [f for f in self.functions if f.kind == "function"]

    def mutating_functions(self) -> List[ExtractedFunction]:
        return [f for f in self.external_functions() if f.is_mutating()]

    def view_functions(self) -> List[ExtractedFunction]:
        return [f for f in self.external_functions() if not f.is_mutating()]


@dataclass
class ExtractedTopology:
    """Structural summary extracted from a compiled candidate.

    Same role as SysML's ExtractedTopology: everything the harness builder needs
    in order to exercise the model, with no compiler access of its own.
    """

    contracts: List[ExtractedContract] = field(default_factory=list)
    primary_contract: Optional[str] = None
    pragma: Optional[str] = None
    compiled: bool = False
    compile_errors: List[Dict[str, Any]] = field(default_factory=list)

    def primary(self) -> Optional[ExtractedContract]:
        if self.primary_contract:
            for contract in self.contracts:
                if contract.name == self.primary_contract:
                    return contract
        deployable = self.deployable_contracts()
        return deployable[0] if deployable else None

    def deployable_contracts(self) -> List[ExtractedContract]:
        return [c for c in self.contracts if c.deployable]

    def contract_names(self) -> List[str]:
        return [c.name for c in self.contracts]


@dataclass
class HarnessFile:
    """One generated Foundry test file."""

    name: str  # e.g. "CandidateFuzz.t.sol"
    tier: str  # "fuzz" | "properties"
    source: str
    test_count: int = 0
    notes: List[str] = field(default_factory=list)
    """Why functions were skipped: unsupported parameter types, undeployable
    constructor, and so on. These are harness limitations, not contract defects,
    and must never be reported to the model as bugs."""


@dataclass
class TestOutcome:
    """One test function's result, distilled from `forge test --json`."""

    name: str
    contract: str
    tier: str
    status: str  # Success | Failure | Skipped
    kind: str = "unit"  # unit | fuzz | invariant
    reason: Optional[str] = None
    counterexample: Optional[str] = None
    logs: List[str] = field(default_factory=list)
    gas: Optional[int] = None
    runs: Optional[int] = None
    reverts: Optional[int] = None
    failure_class: Optional[str] = None
    """Classified failure: panic_arithmetic, panic_assert, panic_division,
    assertion_failed, setup_failed, unexpected_revert, ..."""

    def failed(self) -> bool:
        return self.status == "Failure"


@dataclass
class HarnessExecutionOutput:
    """Raw output from the Foundry runner bridge."""

    stdout: List[str] = field(default_factory=list)
    errors: List[str] = field(default_factory=list)
    trace: List[str] = field(default_factory=list)
    kernel_available: bool = True
    bridge_error: Optional[str] = None
    build_errors: List[Dict[str, Any]] = field(default_factory=list)
    outcomes: List[TestOutcome] = field(default_factory=list)
    compiled: bool = False
    project_path: Optional[str] = None


@dataclass
class SecurityFinding:
    """One static-analysis finding (Slither / Aderyn)."""

    detector: str
    impact: str  # High | Medium | Low | Informational | Optimization
    confidence: str  # High | Medium | Low
    description: str
    contract: Optional[str] = None
    function: Optional[str] = None
    file: Optional[str] = None
    line: Optional[int] = None
    tool: str = "slither"


@dataclass
class SecurityResult:
    """Outcome of the static-analysis pass."""

    available: bool
    findings: List[SecurityFinding] = field(default_factory=list)
    tool: str = "slither"
    tool_error: Optional[str] = None
    analyzed: bool = False

    def blocking(self) -> List[SecurityFinding]:
        """High/medium-impact findings, i.e. the ones worth a repair round."""
        return [f for f in self.findings if f.impact in ("High", "Medium")]

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class ExecutionResult:
    """Structured output from the execution pipeline.

    Same contract as nl2sysml's ExecutionResult, so agent_rag_moe's
    _refine_with_kernel / _format_kernel_errors and quality_gate.layer2_executor
    consume it unchanged. The Solidity-specific tier detail rides in
    ``diagnostics`` and the extra fields below, which SysML-era callers ignore.
    """

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
    diagnostics: Optional[Dict[str, Any]] = None
    diagnostics_path: Optional[str] = None

    # Solidity-specific detail
    harness_files: List[HarnessFile] = field(default_factory=list)
    outcomes: List[TestOutcome] = field(default_factory=list)
    tier_status: Dict[str, str] = field(default_factory=dict)
    """Per-tier verdict: "passed" | "failed" | "skipped" | "build_failed"."""
    harness_notes: List[str] = field(default_factory=list)

    def failures(self) -> List[TestOutcome]:
        return [o for o in self.outcomes if o.failed()]

    def to_dict(self) -> Dict[str, Any]:
        data = asdict(self)
        if self.extracted_topology is not None:
            data["extracted_topology"] = asdict(self.extracted_topology)
        return data
