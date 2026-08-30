"""Synthesize Foundry test harnesses from an extracted candidate topology.

The Solidity analog of nl2sysml/sysml_execution/harness_builder.py. Two tiers:

Tier A (``build_fuzz_harness``) - programmatic, prompt-independent.
    Every external mutating function gets a fuzz test over its full parameter
    domain, plus explicit boundary-value tests (0, 1, type max, address(0), ...).

    The load-bearing detail is how a revert is judged, and it takes two rules to
    get right.

    1. A contract that reverts on bad input is *behaving correctly*, so failing a
       test on any revert would flag every ``require`` in a correct contract.
       Each call is wrapped in try/catch: ``require``/``revert`` with a reason
       string or a custom error passes, and only Solidity ``Panic`` codes -
       compiler-inserted invariant violations - fail.

           Panic(0x01) failed assert          Panic(0x11) arithmetic overflow
           Panic(0x12) division by zero       Panic(0x21) invalid enum conversion
           Panic(0x31) pop on empty array     Panic(0x32) array out of bounds

    2. Under Solidity >=0.8 an arithmetic Panic *is* the safety net doing its
       job: `totalSupply += type(uint256).max` reverting is correct behavior, not
       a vulnerability. Flagging it would fail every correct token contract. So
       the two probes judge arithmetic differently:

       * fuzz tests bound numeric inputs to a plausible magnitude (``bound()``,
         default 1e30) and fail on *any* panic - inside a realistic domain an
         overflow means missing validation;
       * boundary tests deliberately push to ``type(uintN).max`` and *tolerate*
         arithmetic panics (0x11/0x12) while still failing on logic panics
         (0x01/0x21/0x31/0x32), so extreme-value probing stays informative
         without punishing a contract for reverting safely.

Tier B (``build_property_harness``) - LLM-authored, requirement-derived.
    Test bodies written from the NL requirement (accounting invariants, access
    control via vm.expectRevert, state-transition properties) are pasted into a
    scaffold that declares ``target`` and ``setUp`` for them.

Both tiers compile against forge-std and run under ``forge test``.
"""

from __future__ import annotations

import re
from typing import List, Optional, Tuple

from .models import (
    ExecutionRequest,
    ExtractedContract,
    ExtractedFunction,
    ExtractedTopology,
    HarnessFile,
)
from .vector_planner import (
    bound_statements,
    boundary_vectors,
    constructor_arguments,
    fuzz_arguments,
    fuzz_declarations,
    requires_enum_support,
    unsupported_reason_for_function,
)

HARNESS_PRAGMA = "pragma solidity >=0.8.1;"
"""try/catch Panic requires 0.8.1; candidates below that cannot use Tier A."""

FUZZ_HARNESS_NAME = "CandidateFuzz.t.sol"
PROPERTY_HARNESS_NAME = "CandidateProps.t.sol"
CANDIDATE_IMPORT = "../src/Candidate.sol"

# Deposited into the test contract so payable paths have ether to move.
INITIAL_BALANCE = "1000 ether"

_PANIC_HINT = ("compiler-inserted invariant violated: 0x01 assert, 0x11 over/underflow, "
               "0x12 divide-by-zero, 0x21 bad enum, 0x31/0x32 array bounds")

# Strict policy (fuzz tests, bounded inputs): any panic is a defect.
_STRICT_CATCH = """        }} catch Panic(uint256 code) {{
            assertTrue(false, string.concat(
                "{label}: Panic(", vm.toString(code), ") on bounded input - {hint}"));
        }} catch Error(string memory) {{
            // require(..., "reason") - input validation, not a defect.
        }} catch (bytes memory) {{
            // Custom error or bare revert - also input validation.
        }}"""

# Tolerant policy (boundary tests at type limits): a checked-arithmetic revert is
# the contract refusing an impossible value, which is correct. Only logic panics
# fail here.
_TOLERANT_CATCH = """        }} catch Panic(uint256 code) {{
            if (code != 0x11 && code != 0x12) {{
                assertTrue(false, string.concat(
                    "{label}: Panic(", vm.toString(code), ") - {hint}"));
            }}
            // 0x11/0x12 at an extreme boundary: checked arithmetic reverted, which
            // is safe behavior rather than a defect.
        }} catch Error(string memory) {{
            // Boundary value rejected explicitly - correct.
        }} catch (bytes memory) {{
            // Custom error or bare revert - correct.
        }}"""


def _solidity_identifier(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9_]", "_", name) or "unnamed"


def _deploy_expression(contract: ExtractedContract) -> Optional[str]:
    """`new Target(args)` when constructor arguments can be synthesized."""
    args = constructor_arguments(contract.constructor, contract.name)
    if args is None:
        return None
    return f"new {contract.name}({', '.join(args)})"


def _call_expression(fn: ExtractedFunction, args: List[str], *,
                     value_expr: Optional[str] = None) -> str:
    value = f"{{value: {value_expr}}}" if value_expr else ""
    return f"target.{fn.name}{value}({', '.join(args)})"


def _scaffold_header(contract_name: str, test_contract: str,
                     extra_imports: str = "") -> List[str]:
    return [
        "// SPDX-License-Identifier: UNLICENSED",
        HARNESS_PRAGMA,
        "",
        'import {Test} from "forge-std/Test.sol";',
        f'import {{{contract_name}}} from "{CANDIDATE_IMPORT}";',
        extra_imports,
        "",
        f"contract {test_contract} is Test {{",
        f"    {contract_name} internal target;",
        "",
        "    // Accept ether so the candidate can pay this contract back.",
        "    receive() external payable {}",
        "",
        "    function _min(uint256 a, uint256 b) private pure returns (uint256) {",
        "        return a < b ? a : b;",
        "    }",
        "",
    ]


def _setup_block(deploy: str) -> List[str]:
    return [
        "    function setUp() public {",
        f"        vm.deal(address(this), {INITIAL_BALANCE});",
        f"        target = {deploy};",
        "    }",
        "",
    ]


def build_fuzz_harness(topology: ExtractedTopology,
                       request: ExecutionRequest) -> Optional[HarnessFile]:
    """Tier A: stateless fuzzing plus boundary probing of the external surface."""
    contract = topology.primary()
    if contract is None:
        return None

    notes: List[str] = []
    deploy = _deploy_expression(contract)
    if deploy is None:
        notes.append(
            f"cannot deploy {contract.name}: constructor takes a parameter type the "
            "harness cannot synthesize (struct/tuple or unrecognized type)")
        return HarnessFile(name=FUZZ_HARNESS_NAME, tier="fuzz", source="",
                           test_count=0, notes=notes)

    lines = _scaffold_header(contract.name, "CandidateFuzzTest")
    lines += _setup_block(deploy)

    test_count = 0
    targets = contract.mutating_functions()
    if len(targets) > request.max_fuzz_functions:
        notes.append(
            f"fuzzing the first {request.max_fuzz_functions} of {len(targets)} "
            "mutating functions (max_fuzz_functions)")
        targets = targets[: request.max_fuzz_functions]

    needs_enum_support = False
    for fn in targets:
        reason = unsupported_reason_for_function(fn, contract.name)
        if reason:
            notes.append(f"skipped fuzzing {fn.signature()}: {reason}")
            continue

        needs_enum_support = needs_enum_support or requires_enum_support(fn)
        lines += _fuzz_test(fn, request.numeric_bound, contract.name)
        test_count += 1

        if request.include_boundary_tests:
            for index, vector in enumerate(boundary_vectors(
                    fn, primary_contract=contract.name)):
                label = "_".join(c.label for c in vector)
                lines += _boundary_test(fn, [c.expression for c in vector],
                                        f"{_solidity_identifier(fn.name)}_"
                                        f"{_solidity_identifier(label)}_{index}")
                test_count += 1

    if test_count == 0:
        # Nothing callable - still assert the contract deploys, which is the
        # weakest useful execution signal (and what a naive harness would do).
        lines += [
            "    function test_Deploys() public view {",
            "        assertTrue(address(target) != address(0));",
            "    }",
            "",
        ]
        test_count = 1
        notes.append("no fuzzable mutating functions; harness only checks deployment")

    lines.append("}")
    source = "\n".join(lines) + "\n"
    if needs_enum_support:
        # `type(SomeEnum).max` is only available from 0.8.8.
        source = source.replace(HARNESS_PRAGMA, "pragma solidity >=0.8.8;", 1)
    return HarnessFile(name=FUZZ_HARNESS_NAME, tier="fuzz", source=source,
                       test_count=test_count, notes=notes)


def _fuzz_test(fn: ExtractedFunction, numeric_bound: str,
               primary_contract: str) -> List[str]:
    """One randomized test over a function's parameter domain.

    Numeric parameters are bounded to a plausible magnitude first, so a panic
    here means the contract mishandles values it should actually support.
    """
    decls = fuzz_declarations(fn)
    args = fuzz_arguments(fn, primary_contract)
    name = _solidity_identifier(fn.name)

    value_expr = None
    if fn.is_payable():
        # Fuzz the ether amount too, bounded so the test contract can fund it.
        decls.append("uint96 msgValue")
        value_expr = "boundedValue"

    signature = f"    function testFuzz_{name}({', '.join(decls)}) public {{"
    body: List[str] = [signature]
    body += bound_statements(fn, numeric_bound, primary_contract)
    if value_expr:
        # Re-fund per run and bound against a constant: taking the modulus of a
        # live balance would itself panic (divide-by-zero) once the test contract
        # spent everything, which would read as a contract defect.
        body += [
            f"        vm.deal(address(this), {INITIAL_BALANCE});",
            f"        uint256 boundedValue = uint256(msgValue) % ({INITIAL_BALANCE} + 1);",
        ]
    body += [
        f"        try {_call_expression(fn, args, value_expr=value_expr)} {{",
        "            // Completed without violating a compiler invariant.",
        _STRICT_CATCH.format(label=f"testFuzz_{name}", hint=_PANIC_HINT),
        "    }",
        "",
    ]
    return body


def _boundary_test(fn: ExtractedFunction, args: List[str], label: str) -> List[str]:
    """One explicit edge-of-domain call, tolerant of checked-arithmetic reverts."""
    value_expr = "1 ether" if fn.is_payable() else None
    return [
        f"    function test_Boundary_{label}() public {{",
        f"        try {_call_expression(fn, args, value_expr=value_expr)} {{",
        "            // Boundary input accepted.",
        _TOLERANT_CATCH.format(label=f"test_Boundary_{label}", hint=_PANIC_HINT),
        "    }",
        "",
    ]


def build_property_harness(topology: ExtractedTopology,
                           request: ExecutionRequest) -> Optional[HarnessFile]:
    """Tier B: scaffold the requirement-derived property tests from generation."""
    body = (request.property_tests or "").strip()
    if not body:
        return None

    contract = topology.primary()
    if contract is None:
        return None

    deploy = _deploy_expression(contract)
    notes: List[str] = []
    if deploy is None:
        notes.append("cannot deploy candidate for property tests")
        return HarnessFile(name=PROPERTY_HARNESS_NAME, tier="properties",
                           source="", test_count=0, notes=notes)

    body = _strip_scaffold(body)

    lines = _scaffold_header(contract.name, "CandidatePropsTest")
    lines += _setup_block(deploy)
    lines.append("    // ---- requirement-derived properties (generated) ----")
    lines.append(body)
    lines.append("}")

    test_count = len(re.findall(r"function\s+(test|invariant)\w*\s*\(", body))
    return HarnessFile(name=PROPERTY_HARNESS_NAME, tier="properties",
                       source="\n".join(lines) + "\n",
                       test_count=test_count, notes=notes)


def _strip_scaffold(body: str) -> str:
    """Drop scaffolding a model may have wrapped around its test functions.

    The property prompt asks for bare function declarations, but models often
    return a whole file. Pragma/import/contract lines would collide with the
    scaffold, so they are removed and only the function bodies kept.
    """
    text = body.strip()
    if text.startswith("```"):
        text = re.sub(r"^```[a-zA-Z]*\n", "", text)
        text = re.sub(r"\n```$", "", text.strip())

    lines = text.splitlines()
    kept: List[str] = []
    depth = 0
    inside_contract = False
    for line in lines:
        stripped = line.strip()
        if not inside_contract:
            if (stripped.startswith("pragma ") or stripped.startswith("import ")
                    or stripped.startswith("// SPDX")):
                continue
            if re.match(r"^(abstract\s+)?contract\s+\w+", stripped):
                inside_contract = True
                depth = line.count("{") - line.count("}")
                continue
        else:
            depth += line.count("{") - line.count("}")
            if depth <= 0 and stripped.startswith("}"):
                inside_contract = False
                continue
        kept.append(line)

    out = "\n".join(kept).strip("\n")
    # Never let a property harness redeclare a member the scaffold already
    # provides - a duplicate setUp/receive/_min is a compile error that would be
    # charged to the contract rather than to the generated test.
    for pattern in (
        r"function\s+setUp\s*\(\s*\)[^{]*\{",
        r"receive\s*\(\s*\)[^{]*\{",
        r"fallback\s*\(\s*\)[^{]*\{",
        r"function\s+_min\s*\([^)]*\)[^{]*\{",
    ):
        out = _drop_member(out, pattern)
    # A redeclared `target` would shadow the scaffold's deployed instance.
    out = re.sub(r"^\s*\w[\w.]*\s+(?:internal|public|private)?\s*target\s*;\s*$", "",
                 out, flags=re.MULTILINE)
    return out.strip("\n")


def _drop_member(source: str, header_pattern: str) -> str:
    """Remove a whole member declaration (header plus its balanced body)."""
    while True:
        match = re.search(header_pattern, source)
        if not match:
            return source
        depth = 0
        index = match.end() - 1
        for position in range(match.end() - 1, len(source)):
            char = source[position]
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    index = position
                    break
        else:
            return source[: match.start()]
        source = source[: match.start()] + source[index + 1:]


def build_harness_files(topology: ExtractedTopology,
                        request: ExecutionRequest) -> Tuple[List[HarnessFile], List[str]]:
    """Build every requested tier; returns (files, harness notes)."""
    files: List[HarnessFile] = []
    notes: List[str] = []

    if "fuzz" in request.tiers:
        harness = build_fuzz_harness(topology, request)
        if harness is not None:
            notes.extend(harness.notes)
            if harness.source:
                files.append(harness)

    if "properties" in request.tiers:
        harness = build_property_harness(topology, request)
        if harness is not None:
            notes.extend(harness.notes)
            if harness.source:
                files.append(harness)

    return files, notes


def build_consolidated_payload(candidate: str, harness_files: List[HarnessFile]) -> str:
    """Candidate plus harness sources, for inspection and refine feedback.

    Mirrors nl2sysml's consolidated payload: the model-visible split marker is
    ``HARNESS_HEADER`` from agent_rag_moe, so the refine prompt can show the
    contract without leaking generated harness code.
    """
    from_agent_header = "// --- Test harness (auto-generated) ---"
    sections = [candidate.rstrip(), "", from_agent_header]
    for harness in harness_files:
        sections.append(f"// ==== {harness.name} (tier: {harness.tier}) ====")
        sections.append(harness.source.rstrip())
        sections.append("")
    return "\n".join(sections) + "\n"
