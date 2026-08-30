"""Type-aware input planning for generated Solidity harnesses.

The Solidity analog of nl2sysml/sysml_execution/vector_planner.py: it decides
what values a harness can legally feed a function, which types it cannot handle,
and which concrete boundary values are worth an explicit test.

Two products:
  * fuzz declarations - the parameter list Foundry randomizes (Tier A fuzzing)
  * boundary candidates - named literals at the edges of each type's domain
    (zero, one, max, address(0), empty bytes, ...), where contract bugs cluster
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import List, Optional

from .models import ExtractedFunction, ExtractedParam

_UINT_RE = re.compile(r"^uint(\d*)$")
_INT_RE = re.compile(r"^int(\d*)$")
_BYTES_N_RE = re.compile(r"^bytes(\d+)$")
_ARRAY_RE = re.compile(r"^(.*)\[(\d*)\]$")
_USER_TYPE_RE = re.compile(r"^(enum|struct|contract)\s+(.+)$")


def _internal_type(param: ExtractedParam) -> str:
    """The Solidity-level type, which the ABI type alone does not always give.

    solc's ABI is deliberately lossy: `address payable` is reported as `address`,
    an enum as `uint8`, a struct as `tuple`. Calling the function from a harness
    needs the real type - passing an `address` where `address payable` is
    declared is an invalid implicit conversion and will not compile.
    """
    internal = (param.internal_type or "").strip()
    return internal or param.type_name


def call_expression_for(param: ExtractedParam, name: str,
                        primary_contract: Optional[str] = None) -> Optional[str]:
    """How a fuzzed variable is passed to the real signature, or None if it cannot be.

    Returns the argument expression: usually the variable itself, a `payable()`
    wrapper for `address payable`, or an enum cast. User-defined types that would
    need their own import (other contracts, top-level enums) are refused rather
    than guessed at.
    """
    internal = _internal_type(param)
    if internal == param.type_name:
        return name
    if internal in ("address payable", "address payable[]"):
        return f"payable({name})" if not internal.endswith("[]") else None

    match = _USER_TYPE_RE.match(internal)
    if not match:
        return name  # e.g. a contract-local alias that behaves like its ABI type
    kind, qualified = match.group(1), match.group(2).strip()
    if kind != "enum":
        return None
    owner, _, member = qualified.partition(".")
    if not member or owner != primary_contract:
        # The enum lives outside the contract the harness imports.
        return None
    return (f"{qualified}(uint8(bound(uint256({name}), 0, "
            f"uint256(uint8(type({qualified}).max)))))")


def requires_enum_support(fn: "ExtractedFunction") -> bool:
    """True when a function's harness needs Solidity >=0.8.8 (`type(Enum).max`)."""
    return any(_USER_TYPE_RE.match(_internal_type(p) or "") and
               _internal_type(p).startswith("enum ") for p in fn.inputs)


@dataclass(frozen=True)
class TypeClassification:
    """What the harness knows about one ABI type."""

    base: str
    supported: bool
    is_array: bool = False
    is_dynamic_array: bool = False
    bits: Optional[int] = None
    signed: bool = False
    reason: Optional[str] = None


@dataclass(frozen=True)
class InputCandidate:
    """One concrete argument expression plus a label for the test name."""

    expression: str
    label: str


def classify_input_type(type_name: str) -> TypeClassification:
    """Classify an ABI type, and say why it is unsupported when it is."""
    name = (type_name or "").strip()

    array = _ARRAY_RE.match(name)
    if array:
        inner = classify_input_type(array.group(1))
        if not inner.supported:
            return TypeClassification(name, False, is_array=True,
                                      reason=f"array of unsupported {array.group(1)}")
        return TypeClassification(name, True, is_array=True,
                                  is_dynamic_array=array.group(2) == "")

    if name.startswith("tuple"):
        # Structs need a literal constructor the harness cannot infer reliably.
        return TypeClassification(name, False, reason="struct/tuple parameter")
    if name.startswith("function"):
        return TypeClassification(name, False, reason="function-type parameter")
    if name.startswith("contract ") or name.startswith("enum ") or name.startswith("mapping"):
        return TypeClassification(name, False, reason=f"unsupported type {name}")

    match = _UINT_RE.match(name)
    if match:
        return TypeClassification(name, True, bits=int(match.group(1) or 256))
    match = _INT_RE.match(name)
    if match:
        return TypeClassification(name, True, bits=int(match.group(1) or 256), signed=True)
    if name in ("address", "address payable", "bool", "string", "bytes"):
        return TypeClassification(name, True)
    if _BYTES_N_RE.match(name):
        return TypeClassification(name, True)

    return TypeClassification(name, False, reason=f"unrecognized type {name}")


def unsupported_reason_for_input(param: ExtractedParam,
                                 primary_contract: Optional[str] = None) -> Optional[str]:
    """Why this parameter blocks harness generation, or None when it is fine."""
    reason = classify_input_type(param.type_name).reason
    if reason:
        return reason
    if call_expression_for(param, "x", primary_contract) is None:
        return f"user-defined type {_internal_type(param)} the harness cannot construct"
    return None


def unsupported_reason_for_function(fn: ExtractedFunction,
                                    primary_contract: Optional[str] = None) -> Optional[str]:
    """Why this function cannot be exercised, or None when it can."""
    for param in fn.inputs:
        reason = unsupported_reason_for_input(param, primary_contract)
        if reason:
            return f"parameter '{param.name or param.type_name}': {reason}"
    return None


def fuzz_param_name(index: int) -> str:
    return f"a{index}"


def fuzz_declarations(fn: ExtractedFunction) -> List[str]:
    """Solidity parameter declarations for a fuzz test of ``fn``."""
    decls = []
    for index, param in enumerate(fn.inputs):
        solidity_type = _memory_qualified(param.type_name)
        decls.append(f"{solidity_type} {fuzz_param_name(index)}")
    return decls


def fuzz_arguments(fn: ExtractedFunction,
                   primary_contract: Optional[str] = None) -> List[str]:
    """Argument expressions for the call, adapted to the real parameter types."""
    args = []
    for index, param in enumerate(fn.inputs):
        expression = call_expression_for(param, fuzz_param_name(index), primary_contract)
        args.append(expression if expression is not None else fuzz_param_name(index))
    return args


def _memory_qualified(type_name: str) -> str:
    """Reference types need an explicit data location in a function signature."""
    if type_name in ("string", "bytes") or type_name.endswith("[]"):
        return f"{type_name} calldata"
    if _ARRAY_RE.match(type_name):
        return f"{type_name} calldata"
    return type_name


def boundary_values(type_name: str) -> List[InputCandidate]:
    """Edge-of-domain literals for one type, where off-by-one bugs live."""
    info = classify_input_type(type_name)
    if not info.supported:
        return []

    if info.is_array:
        inner = type_name[: type_name.rindex("[")]
        if info.is_dynamic_array:
            return [
                InputCandidate(f"new {inner}[](0)", "emptyArray"),
                InputCandidate(f"new {inner}[](1)", "singletonArray"),
            ]
        return []

    if info.bits and not info.signed:
        bits = info.bits
        return [
            InputCandidate("0", "zero"),
            InputCandidate("1", "one"),
            InputCandidate(f"type(uint{bits}).max", "max"),
        ]

    if info.bits and info.signed:
        bits = info.bits
        return [
            InputCandidate(f"type(int{bits}).min", "min"),
            InputCandidate("-1", "negOne"),
            InputCandidate("0", "zero"),
            InputCandidate(f"type(int{bits}).max", "max"),
        ]

    if type_name in ("address", "address payable"):
        wrap = (lambda expr: f"payable({expr})") if type_name == "address payable" \
            else (lambda expr: expr)
        return [
            InputCandidate(wrap("address(0)"), "zeroAddress"),
            InputCandidate(wrap("address(this)"), "selfAddress"),
            InputCandidate(wrap("address(0xBEEF)"), "otherAddress"),
        ]

    if type_name == "bool":
        return [InputCandidate("true", "true"), InputCandidate("false", "false")]

    if type_name == "string":
        return [
            InputCandidate('""', "emptyString"),
            InputCandidate('"x"', "shortString"),
        ]

    if type_name == "bytes":
        return [
            InputCandidate('hex""', "emptyBytes"),
            InputCandidate('hex"00"', "zeroByte"),
        ]

    match = _BYTES_N_RE.match(type_name)
    if match:
        width = int(match.group(1))
        return [
            InputCandidate(f"bytes{width}(0)", "zero"),
            InputCandidate(f"bytes{width}(type(uint{width * 8}).max)", "max"),
        ]

    return []


def boundary_values_for_param(param: ExtractedParam,
                              primary_contract: Optional[str] = None) -> List[InputCandidate]:
    """Boundary literals with the parameter's real Solidity type.

    The ABI type alone would emit a bare `0` for an enum parameter, which does
    not implicitly convert; and a bare address where `address payable` is
    declared.
    """
    if unsupported_reason_for_input(param, primary_contract):
        return []
    internal = _internal_type(param)
    if internal == param.type_name:
        return boundary_values(param.type_name)
    if internal == "address payable":
        return boundary_values("address payable")

    match = _USER_TYPE_RE.match(internal)
    if match and match.group(1) == "enum":
        qualified = match.group(2).strip()
        # Only the first member is known to exist without reading the AST.
        return [InputCandidate(f"{qualified}(0)", "firstMember")]
    return []


def default_value_for_param(param: ExtractedParam,
                            primary_contract: Optional[str] = None) -> Optional[str]:
    """A benign value with the parameter's real Solidity type."""
    if unsupported_reason_for_input(param, primary_contract):
        return None
    internal = _internal_type(param)
    if internal == "address payable":
        return "payable(address(0xA11CE))"
    match = _USER_TYPE_RE.match(internal)
    if match and match.group(1) == "enum":
        return f"{match.group(2).strip()}(0)"
    return default_value(param.type_name)


def default_value(type_name: str) -> Optional[str]:
    """A single benign value, used for constructor arguments."""
    info = classify_input_type(type_name)
    if not info.supported:
        return None
    if info.is_array:
        inner = type_name[: type_name.rindex("[")]
        return f"new {inner}[](0)" if info.is_dynamic_array else None
    if info.bits and not info.signed:
        # Non-zero: many constructors reject zero supply / zero duration.
        return "1000"
    if info.bits and info.signed:
        return "1"
    if type_name in ("address", "address payable"):
        # A funded, non-zero EOA-ish address the harness controls.
        return ("payable(address(0xA11CE))" if type_name == "address payable"
                else "address(0xA11CE)")
    if type_name == "bool":
        return "true"
    if type_name == "string":
        return '"Candidate"'
    if type_name == "bytes":
        return 'hex"00"'
    if _BYTES_N_RE.match(type_name):
        width = int(_BYTES_N_RE.match(type_name).group(1))
        return f"bytes{width}(uint{width * 8}(1))"
    return None


def constructor_arguments(fn: Optional[ExtractedFunction],
                          primary_contract: Optional[str] = None) -> Optional[List[str]]:
    """Concrete constructor arguments, or None when one cannot be synthesized."""
    if fn is None or not fn.inputs:
        return []
    args = []
    for param in fn.inputs:
        value = default_value_for_param(param, primary_contract)
        if value is None:
            return None
        args.append(value)
    return args


def boundary_vectors(fn: ExtractedFunction, limit: int = 4,
                     primary_contract: Optional[str] = None) -> List[List[InputCandidate]]:
    """Boundary argument tuples for ``fn``.

    One parameter is pushed to an edge at a time (the rest held at a default),
    which keeps the test count linear in parameters instead of exponential.
    """
    if unsupported_reason_for_function(fn, primary_contract):
        return []
    if not fn.inputs:
        return []

    defaults = []
    for param in fn.inputs:
        value = default_value_for_param(param, primary_contract)
        if value is None:
            return []
        defaults.append(InputCandidate(value, "default"))

    vectors: List[List[InputCandidate]] = []
    for index, param in enumerate(fn.inputs):
        # Boundary literals use the parameter's real type, not its ABI shadow.
        for candidate in boundary_values_for_param(param, primary_contract):
            vector = list(defaults)
            vector[index] = InputCandidate(
                candidate.expression, f"{param.name or f'arg{index}'}_{candidate.label}")
            vectors.append(vector)
            if len(vectors) >= limit:
                return vectors
    return vectors


DEFAULT_NUMERIC_BOUND = "1e30"
"""Plausible upper magnitude for a fuzzed amount: 1e30 wei is a trillion tokens
at 18 decimals. Values above this are not realistic inputs, and a contract that
reverts on them under checked arithmetic is behaving correctly - see
harness_builder for why the two probes judge arithmetic differently."""


def bound_statements(fn: ExtractedFunction, numeric_bound: str,
                     primary_contract: Optional[str] = None) -> List[str]:
    """`bound()` calls that pull fuzzed numerics into a plausible range.

    forge-std's ``bound`` maps a random word onto [min, max] without the
    distribution skew of a modulus, and without discarding runs the way
    ``vm.assume`` would.
    """
    statements: List[str] = []
    for index, param in enumerate(fn.inputs):
        info = classify_input_type(param.type_name)
        if not info.supported or info.is_array or not info.bits:
            continue
        if _internal_type(param) != param.type_name:
            # Enums bound themselves inside their cast; other adapted types are
            # not plain numbers and must not be reassigned here.
            continue
        name = fuzz_param_name(index)
        bits = info.bits
        if info.signed:
            low = f"-int256({numeric_bound})"
            high = f"int256({numeric_bound})"
            if bits < 256:
                low = f"int256(type(int{bits}).min)"
                high = f"int256(type(int{bits}).max)"
                statements.append(
                    f"        {name} = int{bits}(bound(int256({name}), {low}, {high}));")
            else:
                statements.append(f"        {name} = bound({name}, {low}, {high});")
            continue

        high = f"uint256({numeric_bound})"
        if bits < 256:
            statements.append(
                f"        {name} = uint{bits}(bound(uint256({name}), 0, "
                f"_min({high}, uint256(type(uint{bits}).max))));")
        else:
            statements.append(f"        {name} = bound({name}, 0, {high});")
    return statements
