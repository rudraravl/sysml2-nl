"""
nl2solidity: NL -> Solidity smart-contract generation pipeline.

Mirror of nl2sysml, retargeted from SysML v2 to Solidity. The MoE synthesis,
compiler-refine, execution-refine and semantic-alignment control flow are the
same; only the target language and its tooling differ.

DANGLING (to be implemented by the project owner):
- compiler_interface.py     -> wraps solc; currently a stub that reports
                               "compiler unavailable" so the refine loop no-ops.
- solidity_execution/       -> Foundry/Hardhat test harness; currently a stub
                               that reports "kernel unavailable".
- spec_index/chunks.jsonl   -> RAG spec chunks (Solidity docs). Empty for now.
- sol_seed.jsonl / dataset.json -> RAG example pairs to be collected.
- spec matching             -> reuses spec_aligner; tune the question bank /
                               thresholds for smart-contract semantics.
"""
