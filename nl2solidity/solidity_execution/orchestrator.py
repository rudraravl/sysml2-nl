"""
Solidity execution orchestrator (STUB).

    from nl2solidity.solidity_execution import ExecutionRequest, run_solidity_execution

    result = run_solidity_execution(ExecutionRequest(candidate_solidity=code))
    print(result.compiled, result.errors)

============================== DANGLING STUB ==============================
Today this reports the runner as unavailable, so the kernel-refine stage in
agent_rag_moe no-ops (identical to running nl2sysml with no Jupyter kernel).

Real implementation outline (mirrors nl2sysml's extractor -> harness_builder ->
runtime_bridge split):
  1. extractor:  parse the contract (contract names, public/external fns, events,
                 constructor args) — the Solidity analog of extract_topology.
  2. harness_builder: emit a Foundry test (`contract X_Test is Test { ... }`)
                 that deploys the candidate and exercises its functions /
                 asserts invariants — the analog of build_consolidated_payload.
  3. runtime_bridge: `forge test --json` (or hardhat) in a temp project, parse
                 pass/fail, revert reasons and gas into diagnostics.
Fill run_solidity_execution to return a populated ExecutionResult and flip
kernel_available to True when a runner is detected.
===========================================================================
"""

from __future__ import annotations

import json
import os
import shutil
from pathlib import Path
from typing import Any, Dict, Optional

from .models import ExecutionRequest, ExecutionResult


def _runner_available() -> bool:
    """DANGLING: probe for a Solidity test runner (forge / hardhat).

    Returns False until the harness bridge is implemented, which keeps the
    kernel-refine path disabled. Even if `forge` is on PATH, we return False
    because the harness builder/bridge below is not wired yet.
    """
    if os.getenv("SOLIDITY_RUNNER_ENABLED", "true").lower() == "false":
        return False
    # A real check would be: bool(shutil.which(os.getenv("FORGE_BIN", "forge")))
    # but the bridge is not implemented, so stay unavailable on purpose.
    _ = shutil  # keep import meaningful for the eventual implementation
    return False


def run_solidity_execution(request: ExecutionRequest) -> ExecutionResult:
    """Compile + execute a candidate contract and return a structured result.

    DANGLING: returns kernel_available=False so refinement skips execution.
    """
    code = request.candidate_solidity or ""

    if not _runner_available():
        return ExecutionResult(
            compiled=False,
            success=False,
            errors=[],
            trace=[],
            model_kind="unknown",
            harness="",
            consolidated_payload=code,
            kernel_available=False,
            bridge_error="Solidity execution runner not implemented (dangling stub)",
            diagnostics={"n_errors": 0, "errors": []},
        )

    # ---- BEGIN dangling harness + runner wiring -----------------------
    # topology = extract_topology(code)
    # harness = build_foundry_harness(topology, request)
    # consolidated = code + "\n\n" + harness
    # run = run_forge_test(consolidated, timeout=request.execution_timeout_sec)
    # return ExecutionResult(compiled=run.compiled, success=run.success,
    #                        errors=run.errors, trace=run.trace,
    #                        model_kind=topology.kind, harness=harness,
    #                        consolidated_payload=consolidated,
    #                        kernel_available=True, diagnostics=run.diagnostics)
    # ---- END dangling harness + runner wiring -------------------------

    raise NotImplementedError("Solidity execution runner not implemented")


def run_solidity_execution_from_file(
    sol_path: str,
    *,
    simulation_vectors: Optional[Dict[str, Any]] = None,
    execution_timeout_sec: float = 120.0,
) -> ExecutionResult:
    """Load a .sol file and execute."""
    code = Path(sol_path).read_text(encoding="utf-8")
    return run_solidity_execution(
        ExecutionRequest(
            candidate_solidity=code,
            simulation_vectors=simulation_vectors,
            execution_timeout_sec=execution_timeout_sec,
        )
    )


def _cli() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="Solidity execution harness (stub)")
    parser.add_argument("sol_file", help="Path to candidate .sol file")
    parser.add_argument("-o", "--output", help="Write JSON result to file")
    args = parser.parse_args()

    result = run_solidity_execution_from_file(args.sol_file)
    text = json.dumps(result.to_dict(), indent=2)
    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")
        print(f"Wrote {args.output}")
    else:
        print(text)


if __name__ == "__main__":
    _cli()
