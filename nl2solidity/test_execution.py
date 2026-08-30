#!/usr/bin/env python3
"""Tests for the Foundry execution harness and the security-analysis stage.

Run from the repo root::

    .venv/bin/python3 -m pytest nl2solidity/test_execution.py -v

Tests that need a toolchain skip (rather than fail) when it is absent, so the
suite stays green on machines without Foundry or Slither.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

_REPO_ROOT = Path(__file__).resolve().parents[1]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from nl2solidity.security_analysis import (  # noqa: E402
    actionable_findings,
    analyze_solidity,
    is_analysis_available,
)
from nl2solidity.solidity_execution import (  # noqa: E402
    ExecutionRequest,
    build_harness_files,
    classify_input_type,
    classify_kind,
    constructor_arguments,
    extract_topology,
    is_runner_available,
    run_solidity_execution,
    unsupported_reason_for_function,
)
from nl2solidity.solidity_execution.models import (  # noqa: E402
    ExtractedFunction,
    ExtractedParam,
)

requires_forge = pytest.mark.skipif(
    not is_runner_available(), reason="Foundry (forge) not available")
requires_slither = pytest.mark.skipif(
    not is_analysis_available(), reason="no static analyzer available")

# A correct contract: every failure path is a require, so nothing should be
# reported as a defect. This is the false-positive guard for the whole tier.
GOOD_TOKEN = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SimpleToken {
    uint256 public totalSupply;
    address public owner;
    mapping(address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor(uint256 initialSupply) {
        owner = msg.sender;
        totalSupply = initialSupply;
        balanceOf[msg.sender] = initialSupply;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        require(to != address(0), "zero address");
        require(balanceOf[msg.sender] >= value, "insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function mint(address to, uint256 value) external {
        require(msg.sender == owner, "not owner");
        totalSupply += value;
        balanceOf[to] += value;
    }
}
"""

# Unchecked subtraction against a zero balance: a real underflow.
BUGGY_VAULT = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Vault {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }
}
"""

REENTRANT = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ReentrantBank {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "nothing to withdraw");
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "transfer failed");
        balances[msg.sender] = 0;
    }
}
"""


# --------------------------------------------------------------- extractor --


def test_extractor_reads_abi():
    topology = extract_topology(GOOD_TOKEN)
    assert topology.compiled
    assert topology.primary_contract == "SimpleToken"
    contract = topology.primary()
    names = {fn.name for fn in contract.external_functions()}
    assert {"transfer", "mint", "totalSupply"} <= names
    assert contract.constructor is not None
    assert [p.type_name for p in contract.constructor.inputs] == ["uint256"]


def test_extractor_reports_compile_failure_without_raising():
    topology = extract_topology("pragma solidity ^0.8.0;\ncontract A { bad }")
    assert not topology.compiled
    assert topology.compile_errors
    assert topology.primary() is None


def test_classify_kind():
    assert classify_kind(extract_topology(GOOD_TOKEN)) == "stateful"
    assert classify_kind(extract_topology(BUGGY_VAULT)) == "payable"
    assert classify_kind(extract_topology(
        "pragma solidity ^0.8.0;\ncontract V { uint public x; }")) == "stateless"


# ---------------------------------------------------------- vector planner --


def test_unsupported_types_are_reported_not_guessed():
    fn = ExtractedFunction(name="f", inputs=[ExtractedParam("s", "tuple")])
    assert "struct/tuple" in unsupported_reason_for_function(fn)
    assert classify_input_type("uint128").bits == 128
    assert classify_input_type("int64").signed
    assert classify_input_type("bytes32").supported
    assert not classify_input_type("mapping(uint => uint)").supported


def test_constructor_arguments_bail_on_unsynthesizable_types():
    ok = ExtractedFunction(name="", kind="constructor",
                           inputs=[ExtractedParam("supply", "uint256")])
    assert constructor_arguments(ok) == ["1000"]
    bad = ExtractedFunction(name="", kind="constructor",
                            inputs=[ExtractedParam("cfg", "tuple")])
    assert constructor_arguments(bad) is None


# --------------------------------------------------------- harness builder --


def test_fuzz_harness_covers_mutating_functions():
    topology = extract_topology(GOOD_TOKEN)
    files, _notes = build_harness_files(
        topology, ExecutionRequest(candidate_solidity=GOOD_TOKEN))
    fuzz = next(f for f in files if f.tier == "fuzz")
    assert "function testFuzz_transfer(" in fuzz.source
    assert "function testFuzz_mint(" in fuzz.source
    # View functions are not fuzz targets.
    assert "testFuzz_totalSupply" not in fuzz.source
    # Numeric inputs are bounded before use, and panics are discriminated.
    assert "bound(" in fuzz.source
    assert "catch Panic(uint256 code)" in fuzz.source
    assert "catch Error(string memory)" in fuzz.source


def test_property_harness_strips_model_scaffolding():
    topology = extract_topology(GOOD_TOKEN)
    request = ExecutionRequest(
        candidate_solidity=GOOD_TOKEN,
        property_tests='```solidity\npragma solidity ^0.8.20;\n'
                       'import {Test} from "forge-std/Test.sol";\n'
                       'contract P is Test {\n'
                       '    function test_Supply() public view {\n'
                       '        assertEq(target.totalSupply(), 1000);\n'
                       '    }\n}\n```')
    files, _ = build_harness_files(topology, request)
    props = next(f for f in files if f.tier == "properties")
    # The model's own pragma/import/contract wrapper must be gone, leaving only
    # the scaffold's declarations.
    assert props.source.count("pragma solidity") == 1
    assert props.source.count("contract CandidatePropsTest") == 1
    assert "contract P is Test" not in props.source
    assert "```" not in props.source
    assert "function test_Supply()" in props.source
    assert props.test_count == 1


# ------------------------------------------------------------- execution ----


@requires_forge
def test_correct_contract_passes_every_tier():
    """The false-positive guard: a require-guarded contract must come back clean."""
    result = run_solidity_execution(
        ExecutionRequest(candidate_solidity=GOOD_TOKEN, fuzz_runs=64))
    assert result.compiled
    assert result.success, [o.name for o in result.failures()]
    assert result.tier_status["fuzz"] == "passed"
    assert result.diagnostics["contract_defects"] == 0


@requires_forge
def test_arithmetic_underflow_is_caught():
    result = run_solidity_execution(
        ExecutionRequest(candidate_solidity=BUGGY_VAULT, fuzz_runs=64))
    assert result.compiled
    assert not result.success
    classes = {o.failure_class for o in result.failures()}
    assert "panic_arithmetic" in classes
    assert result.diagnostics["contract_defects"] >= 1
    # The failing input must be reported, not just the fact of failure.
    assert any(o.counterexample for o in result.failures() if o.kind == "fuzz")


@requires_forge
def test_uncompilable_candidate_reports_build_failure():
    result = run_solidity_execution(ExecutionRequest(
        candidate_solidity="pragma solidity ^0.8.0;\ncontract A { function f() { } }"))
    assert not result.compiled
    assert not result.success
    assert result.tier_status["fuzz"] == "build_failed"


@requires_forge
def test_property_violation_is_caught():
    no_access_control = GOOD_TOKEN.replace(
        '        require(msg.sender == owner, "not owner");\n', "")
    result = run_solidity_execution(ExecutionRequest(
        candidate_solidity=no_access_control,
        fuzz_runs=32,
        property_tests="function test_NonOwnerCannotMint() public {\n"
                       "    vm.prank(address(0xBEEF));\n"
                       "    vm.expectRevert();\n"
                       "    target.mint(address(0xBEEF), 1);\n"
                       "}"))
    assert not result.success
    assert result.tier_status["properties"] == "failed"
    assert any(o.failure_class == "expected_revert_not_raised"
               for o in result.failures())


@requires_forge
def test_bad_property_harness_does_not_silence_fuzzing():
    """A property file that will not compile is a harness defect, not a contract one."""
    result = run_solidity_execution(ExecutionRequest(
        candidate_solidity=GOOD_TOKEN, fuzz_runs=32,
        property_tests="function test_X() public { target.doesNotExist(); }"))
    assert result.compiled
    assert result.tier_status["properties"] == "build_failed"
    assert result.tier_status["fuzz"] == "passed"
    assert result.diagnostics["contract_defects"] == 0
    assert result.diagnostics["harness_defects"] >= 1


@requires_forge
def test_execution_result_keeps_the_sysml_contract():
    """Fields agent_rag_moe and quality_gate read must all be present."""
    result = run_solidity_execution(
        ExecutionRequest(candidate_solidity=GOOD_TOKEN, fuzz_runs=32))
    payload = result.to_dict()
    for key in ("compiled", "success", "errors", "trace", "model_kind", "harness",
                "consolidated_payload", "kernel_available", "diagnostics"):
        assert key in payload
    assert "n_errors" in result.diagnostics


# -------------------------------------------------------------- security ----


@requires_slither
def test_reentrancy_is_detected_with_a_line_number():
    result = analyze_solidity(REENTRANT)
    assert result.available and not result.tool_error
    findings = actionable_findings(result)
    assert findings, "expected a high-severity reentrancy finding"
    assert any("reentrancy" in f.detector for f in findings)
    finding = next(f for f in findings if "reentrancy" in f.detector)
    assert finding.line and finding.line > 0
    assert finding.impact in ("High", "Medium")
    # Temp paths must not leak into repair feedback.
    assert "/var/folders" not in finding.description
    assert "/tmp" not in finding.description


@requires_slither
def test_clean_contract_has_no_actionable_findings():
    """Noise guard: a correct contract must not trigger a security repair round."""
    result = analyze_solidity(GOOD_TOKEN)
    assert result.available and not result.tool_error
    assert actionable_findings(result) == []


@requires_slither
def test_uncompilable_contract_reports_tool_error_not_findings():
    result = analyze_solidity("pragma solidity ^0.8.0;\ncontract A { bad }")
    assert result.available
    assert result.tool_error or not result.findings


def test_analysis_availability_is_a_bool():
    assert isinstance(is_analysis_available(), bool)
    assert isinstance(is_runner_available(), bool)


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v"]))


@requires_forge
def test_property_tests_are_compile_checked_before_running():
    """Tier B must be validated with a cheap build, not a full fuzz campaign."""
    from nl2solidity.solidity_execution import validate_property_tests

    ok, errors = validate_property_tests(
        GOOD_TOKEN, "function test_Good() public view { assertTrue(true); }")
    assert ok, errors

    # The exact slip seen in a live run: 0xAB1T3R is not a hex literal.
    ok, errors = validate_property_tests(
        GOOD_TOKEN,
        "function test_Bad() public { address a = address(0xAB1T3R); assertTrue(a != a); }")
    assert not ok
    assert any("CandidateProps" in (e.get("file") or "") for e in errors)


@requires_forge
def test_property_scaffold_survives_a_full_model_style_file():
    """A model returning a whole test file must still produce a compiling harness."""
    from nl2solidity.solidity_execution import validate_property_tests

    model_output = '''```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SimpleToken} from "../src/Candidate.sol";

contract PropsTest is Test {
    SimpleToken internal target;

    function setUp() public {
        target = new SimpleToken(1000);
    }

    receive() external payable {}

    function test_OwnerHoldsSupply() public view {
        assertEq(target.balanceOf(address(this)), target.totalSupply());
    }

    function test_StrangerCannotMint() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert("not owner");
        target.mint(address(0xBEEF), 1);
    }
}
```'''
    ok, errors = validate_property_tests(GOOD_TOKEN, model_output)
    assert ok, errors


# The ABI reports `address payable` as `address` and an enum as `uint8`; a
# harness built from the ABI type alone will not compile against the real
# signature. Both shapes are common in generated escrow/marketplace contracts.
ABI_SHADOWED_TYPES = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Deal {
    enum Status { Pending, Settled }

    struct Record { address seller; uint256 amount; Status status; }

    mapping(uint256 => Record) public records;
    uint256 public nextId;

    function create(address payable seller, uint256 amount) external returns (uint256) {
        require(seller != address(0), "zero seller");
        uint256 id = nextId++;
        records[id] = Record(seller, amount, Status.Pending);
        return id;
    }

    function setStatus(uint256 id, Status status) external {
        require(records[id].seller != address(0), "unknown deal");
        records[id].status = status;
    }
}
"""


@requires_forge
def test_harness_handles_abi_shadowed_types():
    """address payable and enum parameters must produce a compiling harness."""
    result = run_solidity_execution(
        ExecutionRequest(candidate_solidity=ABI_SHADOWED_TYPES, fuzz_runs=32))
    assert result.compiled, result.errors
    assert result.diagnostics["harness_defects"] == 0, result.errors
    assert result.tier_status["fuzz"] == "passed", [o.name for o in result.failures()]
    names = {o.name.split("(")[0] for o in result.outcomes}
    assert "testFuzz_create" in names
    assert "testFuzz_setStatus" in names


def test_parameter_expressions_follow_the_real_solidity_type():
    from nl2solidity.solidity_execution.vector_planner import call_expression_for

    payable_param = ExtractedParam("seller", "address", "address payable")
    assert call_expression_for(payable_param, "a0", "Deal") == "payable(a0)"

    enum_param = ExtractedParam("status", "uint8", "enum Deal.Status")
    expression = call_expression_for(enum_param, "a0", "Deal")
    assert expression.startswith("Deal.Status(")
    assert "type(Deal.Status).max" in expression

    # An enum owned by a contract the harness does not import cannot be built.
    foreign = ExtractedParam("status", "uint8", "enum Other.Status")
    assert call_expression_for(foreign, "a0", "Deal") is None
    assert unsupported_reason_for_function(
        ExtractedFunction(name="f", inputs=[foreign]), "Deal")
