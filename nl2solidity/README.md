# nl2solidity

NL → Solidity smart-contract generation pipeline. This is a retargeted copy of
`nl2sysml/`: the same Mixture-of-Experts (MoE) synthesis + iterative-refinement
framework, aimed at Solidity instead of SysML v2.

## Pipeline (identical control flow to nl2sysml)

```
NL requirement
   │
   ▼
RAG context   ← dataset/data/*.sol examples + spec_index/chunks.jsonl   [DANGLING samples]
   │
   ▼
MoE experts (parallel, OpenRouter)  →  combiner synthesis
   │
   ▼
compiler refine (solc)              [DANGLING compiler → no-op today]
   │
   ▼
execution refine (Foundry/Hardhat)  [DANGLING runner   → no-op today]
   │
   ▼
semantic spec-mismatch align + repair (spec_aligner)  [TWEAKABLE spec matching]
   │
   ▼
final Solidity + prompt_record
```

Each stage degrades gracefully: when the compiler or runner is unavailable, its
refine loop is skipped (exactly how nl2sysml behaves without its JAR / Jupyter
kernel), so the MoE + alignment path runs end to end regardless.

## Files

| File | Role | Status |
| --- | --- | --- |
| `agent_rag_moe.py` | MoE generation engine. Public entry: `generate_solidity_moe(nl) -> (code, record)` | transcribed |
| `batch_generate.py` | Parallel batch runner (claim/resume/stats), writes `{id}.sol`/`{id}.txt`/`meta.json` | transcribed |
| `quality_gate.py` | Post-generation validate→execute→align→repair gate | transcribed |
| `compiler_interface.py` | `solc` wrapper — identical API to nl2sysml | **DANGLING** stub |
| `solidity_execution/` | Foundry/Hardhat test harness runner | **DANGLING** stub |
| `spec_index/chunks.jsonl` | RAG spec chunks (Solidity docs) | **DANGLING** empty |
| `dataset/data/` | RAG example pairs `(NL, .sol)` | **DANGLING** to collect |
| `sol_seed.jsonl` / `dataset.json` | seed prompts (samples included) | sample data |
| `ingest_solidity_spec.py` | build `spec_index` from Solidity docs | stub |

## Dangling pieces (intentionally left for you)

1. **Compiler** — `compiler_interface._init_compiler` returns `None`. Wire up
   `solc --standard-json` (or `forge build --json`) and flip
   `is_compiler_available()`. The generation loop needs no other change.
2. **Execution kernel** — `solidity_execution/orchestrator.run_solidity_execution`
   reports `kernel_available=False`. Implement the extractor → harness_builder →
   `forge test`/`hardhat` bridge (mirrors nl2sysml's `sysml_execution`).
3. **RAG samples** — collect `(NL, .sol)` pairs under `dataset/data/<id>/` and/or
   run `ingest_solidity_spec.py` to fill `spec_index/chunks.jsonl`.
4. **Spec matching** — `quality_gate.py` reuses `spec_aligner` unchanged. Its
   question bank / RUNTIME profile is SysML-flavored; tune it for smart-contract
   semantics.

## Usage

```bash
cd /Users/rudraraval/College/sysml2-nl/nl2solidity
source ../.venv/bin/activate

# Single requirement
python3 agent_rag_moe.py "Create an ERC20 token with a fixed supply"

# One-shot batch from dataset.json → result_rag_moe/
python3 agent_rag_moe.py

# Full batch from sol_seed.jsonl
python3 batch_generate.py --num-entries 5 --prompt-source seed
```

See `BATCH_GENERATION.md` for the full batch guide (workers, resume, rate
limits, quality-gate controls). Requires `OPENROUTER_API_KEY` in the repo `.env`.
