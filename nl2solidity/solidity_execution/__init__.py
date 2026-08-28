"""
Solidity execution harness (STUB).

Mirror of nl2sysml/sysml_execution, retargeted to Solidity. The generation
engine calls this to *run* a candidate contract (compile + execute a generated
test harness) and feed runtime failures back into refinement.

Public API::

    from nl2solidity.solidity_execution import ExecutionRequest, run_solidity_execution

    result = run_solidity_execution(ExecutionRequest(candidate_solidity=code))
    payload = result.to_dict()

============================== DANGLING STUB ==============================
The real implementation should:
  1. Write the candidate contract to a temp Foundry/Hardhat project.
  2. Synthesize a test harness (deploy contract, exercise public functions,
     assert invariants) — analogous to sysml_execution's harness_builder.
  3. Run `forge test --json` (or `hardhat test`), parse pass/fail + revert
     reasons + gas into ExecutionResult.diagnostics.

Until then, run_solidity_execution() returns kernel_available=False, so the
kernel-refine stage in agent_rag_moe.py no-ops cleanly.
===========================================================================
"""

from .models import ExecutionRequest, ExecutionResult
from .orchestrator import run_solidity_execution, run_solidity_execution_from_file

__all__ = [
    "ExecutionRequest",
    "ExecutionResult",
    "run_solidity_execution",
    "run_solidity_execution_from_file",
]
