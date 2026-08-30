#!/usr/bin/env python3
"""Tests for the solc-backed compiler interface.

Run from the repo root::

    .venv/bin/python3 -m pytest nl2solidity/test_compiler_interface.py -v

Every test skips (rather than fails) when no solc binary is reachable, so the
suite stays green on machines without the toolchain installed.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

_REPO_ROOT = Path(__file__).resolve().parents[1]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from nl2solidity.compiler_interface import (  # noqa: E402
    CompilerError,
    CompilerResult,
    check_code,
    is_compiler_available,
)

VALID = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Counter {
    uint256 public count;

    event Incremented(uint256 newCount);

    function increment() public {
        count += 1;
        emit Incremented(count);
    }
}
"""

SYNTAX_ERROR = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Broken {
    function f() public {
"""

TYPE_ERROR = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Mistyped {
    uint256 public count;

    function set() public {
        count = "not a number";
    }
}
"""

UNDECLARED = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Undeclared {
    function f() public view returns (uint256) {
        return missingVariable;
    }
}
"""


requires_solc = pytest.mark.skipif(
    not is_compiler_available(), reason="solc not available on this machine")


def test_compiler_reports_availability():
    """Availability must be a decisive bool, never an exception."""
    assert isinstance(is_compiler_available(), bool)


@requires_solc
def test_valid_contract_compiles_clean():
    result = check_code(VALID)
    assert result.is_valid, result.format_errors()
    assert result.error_count == 0


@requires_solc
def test_syntax_error_detected():
    result = check_code(SYNTAX_ERROR)
    assert not result.is_valid
    assert result.error_count >= 1
    assert any(e.is_syntax_error() for e in result.errors), result.format_errors()


@requires_solc
def test_type_error_detected():
    result = check_code(TYPE_ERROR)
    assert not result.is_valid
    assert any(e.is_semantic_error() for e in result.errors), result.format_errors()
    # The diagnostic must point at the offending assignment, not line 0.
    assert any(e.line > 0 for e in result.errors)


@requires_solc
def test_undeclared_identifier_detected():
    result = check_code(UNDECLARED)
    assert not result.is_valid
    assert any("missingVariable" in e.message for e in result.errors), \
        result.format_errors()


@requires_solc
def test_syntax_only_ignores_type_errors():
    """Parse-only mode must accept code that only fails type checking."""
    assert check_code(TYPE_ERROR, syntax_only=True).is_valid
    # ...but still reject unparseable code.
    assert not check_code(SYNTAX_ERROR, syntax_only=True).is_valid


@requires_solc
def test_warnings_do_not_invalidate():
    """A contract with no SPDX header warns but still compiles."""
    result = check_code("pragma solidity ^0.8.0;\ncontract W {}\n")
    assert result.is_valid, result.format_errors()


@requires_solc
def test_error_locations_are_one_based_and_accurate():
    result = check_code(TYPE_ERROR)
    errors = [e for e in result.errors if e.severity == "error"]
    assert errors
    # `count = "not a number";` is on line 8 of TYPE_ERROR.
    assert any(e.line == 8 for e in errors), [str(e) for e in errors]
    assert all(e.column >= 1 for e in errors)


@requires_solc
def test_format_errors_is_llm_ready():
    text = check_code(TYPE_ERROR).format_errors()
    assert "Line" in text and "TypeError" in text


@requires_solc
def test_older_pragma_selects_matching_compiler():
    """A 0.7.x contract must be checked by a 0.7.x solc, not the default 0.8."""
    src = """// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

contract Legacy {
    uint256 public total;

    function add(uint256 amount) public {
        // Unchecked overflow is legal in 0.7 but the syntax is what matters.
        total += amount;
    }
}
"""
    result = check_code(src)
    assert result.is_valid, result.format_errors()


def test_result_contract_shape():
    """CompilerResult/CompilerError keep the surface agent_rag_moe consumes."""
    err = CompilerError("error", 3, 5, "boom", code="TypeError", file="C.sol")
    result = CompilerResult(errors=[err], is_valid=False)
    assert result.error_count == 1
    assert "boom" in result.format_errors()
    assert err.is_semantic_error() and not err.is_syntax_error()
    assert "C.sol:3:5" in str(err)


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v"]))
