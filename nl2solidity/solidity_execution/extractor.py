"""ABI-based structural extraction from a Solidity candidate.

The Solidity analog of nl2sysml/sysml_execution/extractor.py. Where the SysML
extractor regex-parses model text, this one asks solc for the candidate's ABI:
the compiler already knows the contracts, their external surface, parameter
types, mutability, events and custom errors, so the harness builder never has to
guess at Solidity syntax.

Public API::

    topology = extract_topology(source)
    kind = classify_kind(topology)
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

from .models import (
    ExtractedContract,
    ExtractedError,
    ExtractedEvent,
    ExtractedFunction,
    ExtractedParam,
    ExtractedTopology,
)

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

CANDIDATE_FILENAME = "Candidate.sol"


def _checker():
    """The shared solc wrapper, or None when no compiler is reachable."""
    try:
        from nl2solidity.check_solidity import SolidityChecker
    except ImportError:  # pragma: no cover - direct-script fallback
        from check_solidity import SolidityChecker  # type: ignore

    try:
        return SolidityChecker(
            solc_binary=os.getenv("SOLC_BIN"),
            evm_version=os.getenv("SOLC_EVM_VERSION"),
            default_version=os.getenv("SOLC_DEFAULT_VERSION", "0.8.26"),
            auto_install=os.getenv("SOLC_AUTO_INSTALL", "true").lower() != "false",
            timeout=float(os.getenv("SOLC_TIMEOUT_SEC", "60")),
        )
    except Exception:
        return None


def _param(entry: Dict[str, Any]) -> ExtractedParam:
    return ExtractedParam(
        name=entry.get("name", "") or "",
        type_name=entry.get("type", ""),
        internal_type=entry.get("internalType"),
        components=[_param(c) for c in entry.get("components", []) or []],
    )


def _function_from_abi(entry: Dict[str, Any]) -> ExtractedFunction:
    return ExtractedFunction(
        name=entry.get("name", "") or entry.get("type", ""),
        kind=entry.get("type", "function"),
        inputs=[_param(i) for i in entry.get("inputs", []) or []],
        outputs=[_param(o) for o in entry.get("outputs", []) or []],
        state_mutability=entry.get("stateMutability", "nonpayable"),
    )


def _contract_from_artifact(name: str, artifact: Dict[str, Any]) -> ExtractedContract:
    abi = artifact.get("abi", []) or []
    bytecode = ((artifact.get("evm") or {}).get("bytecode") or {}).get("object", "")

    contract = ExtractedContract(
        name=name,
        # Interfaces, abstract contracts and libraries produce no creation code.
        deployable=bool(bytecode) and bytecode != "0x",
    )

    for entry in abi:
        kind = entry.get("type")
        if kind == "function":
            fn = _function_from_abi(entry)
            fn.selector = ((artifact.get("evm") or {})
                           .get("methodIdentifiers") or {}).get(fn.signature())
            contract.functions.append(fn)
        elif kind == "constructor":
            contract.constructor = _function_from_abi(entry)
        elif kind == "receive":
            contract.receive_ether = True
        elif kind == "fallback":
            contract.fallback_payable = entry.get("stateMutability") == "payable"
        elif kind == "event":
            contract.events.append(ExtractedEvent(
                name=entry.get("name", ""),
                inputs=[_param(i) for i in entry.get("inputs", []) or []],
                anonymous=bool(entry.get("anonymous")),
            ))
        elif kind == "error":
            contract.errors.append(ExtractedError(
                name=entry.get("name", ""),
                inputs=[_param(i) for i in entry.get("inputs", []) or []],
            ))

    return contract


def _pragma_of(source: str) -> Optional[str]:
    for line in source.splitlines():
        stripped = line.strip()
        if stripped.startswith("pragma solidity"):
            return stripped
    return None


def extract_topology(source: str) -> ExtractedTopology:
    """Compile the candidate and summarize its deployable surface.

    Compilation failures are not an error here: the topology comes back with
    ``compiled=False`` and ``compile_errors`` populated, and the orchestrator
    reports them as the execution result rather than raising.
    """
    topology = ExtractedTopology(pragma=_pragma_of(source))

    checker = _checker()
    if checker is None:
        topology.compile_errors = [{
            "severity": "error",
            "message": "solc not available; cannot extract ABI",
            "type": "CompilerUnavailable",
        }]
        return topology

    payload = {
        "language": "Solidity",
        "sources": {CANDIDATE_FILENAME: {"content": source}},
        "settings": {
            "outputSelection": {
                "*": {"*": ["abi", "evm.bytecode.object", "evm.methodIdentifiers"]}
            }
        },
    }
    evm_version = os.getenv("SOLC_EVM_VERSION")
    if evm_version:
        payload["settings"]["evmVersion"] = evm_version

    try:
        binary = checker._resolve_binary(checker._pragma_of(source))
        proc = subprocess.run(
            [binary, "--standard-json"],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            timeout=checker.timeout,
        )
        output = json.loads(proc.stdout)
    except Exception as exc:
        topology.compile_errors = [{
            "severity": "error",
            "message": f"ABI extraction failed: {exc}",
            "type": "CompilerFailure",
        }]
        return topology

    errors = [e for e in output.get("errors", []) if e.get("severity") == "error"]
    topology.compile_errors = errors
    topology.compiled = not errors
    if errors:
        return topology

    for _source_name, artifacts in (output.get("contracts") or {}).items():
        for name, artifact in artifacts.items():
            topology.contracts.append(_contract_from_artifact(name, artifact))

    topology.primary_contract = _pick_primary(topology, source)
    return topology


def _pick_primary(topology: ExtractedTopology, source: str) -> Optional[str]:
    """Choose the contract the harness should deploy.

    Heuristics, in order: the last deployable contract declared in the source
    (Solidity convention puts the concrete contract after its bases), breaking
    ties by external surface size.
    """
    deployable = topology.deployable_contracts()
    if not deployable:
        return None
    if len(deployable) == 1:
        return deployable[0].name

    # Declaration order in the source, so `contract Token is ERC20` picks Token.
    order: Dict[str, int] = {}
    for index, line in enumerate(source.splitlines()):
        stripped = line.strip()
        if stripped.startswith("contract "):
            name = stripped[len("contract "):].split("{")[0].split(" is ")[0].strip()
            order.setdefault(name, index)

    def rank(contract: ExtractedContract) -> tuple:
        return (order.get(contract.name, -1), len(contract.external_functions()))

    return max(deployable, key=rank).name


def classify_kind(topology: ExtractedTopology) -> str:
    """Coarse candidate shape, the analog of SysML's behavioral/structural split."""
    contract = topology.primary()
    if contract is None:
        return "empty"
    if contract.receive_ether or any(f.is_payable() for f in contract.external_functions()):
        return "payable"
    if contract.mutating_functions():
        return "stateful"
    return "stateless"


def _type_label(param: "ExtractedParam") -> str:
    """ABI type, plus the Solidity-level type when they differ.

    The ABI flattens `enum Status` to `uint8` and a struct to `tuple`. A prompt
    that shows only the ABI type leads a model to write `assertEq(x, uint8(1))`
    against a getter that actually returns the enum, which will not compile - so
    the internalType is carried through wherever it says something extra.
    """
    internal = (param.internal_type or "").strip()
    if internal and internal != param.type_name:
        return f"{param.type_name} ({internal})"
    return param.type_name


def summarize_topology(topology: ExtractedTopology) -> Dict[str, Any]:
    """Compact ABI summary for prompts (property generation) and diagnostics."""
    contract = topology.primary()
    if contract is None:
        return {"contract": None, "functions": [], "events": []}
    return {
        "contract": contract.name,
        "constructor": [_type_label(p) for p in contract.constructor.inputs]
        if contract.constructor else [],
        "functions": [
            {
                "name": fn.name,
                "inputs": [{"name": p.name, "type": _type_label(p)} for p in fn.inputs],
                "outputs": [_type_label(p) for p in fn.outputs],
                "mutability": fn.state_mutability,
            }
            for fn in contract.external_functions()
        ],
        "events": [
            {"name": ev.name, "inputs": [p.type_name for p in ev.inputs]}
            for ev in contract.events
        ],
        "errors": [err.name for err in contract.errors],
        "receive_ether": contract.receive_ether,
    }
