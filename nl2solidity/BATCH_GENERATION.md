# Batch Generation Guide (Solidity)

Retargeted from `nl2sysml/BATCH_GENERATION.md`. This script generates
NL-Solidity pairs using the MoE pipeline, compiler feedback (dangling solc),
execution feedback (dangling runner), and the post-generation spec-mismatch
quality gate.

**Prompts:** By default, NL comes from the richer text in
`nl2solidity/dataset/data/XXXXXX/XXXXXX.txt` (linked via `meta.json`
`source_path: sol_seed.jsonl:U###`). Seed order / output folders use
`sol_seed.jsonl` ids (`U1`, …). Use `--prompt-source seed` for the short seed
descriptions (works out of the box with the sample `sol_seed.jsonl`).

## Usage

```bash
cd /Users/rudraraval/College/sysml2-nl/nl2solidity

# Sample run using the short seeds (no dataset/data needed yet)
python3 batch_generate.py --num-entries 5 --prompt-source seed

# Default: rich NL from dataset/data (requires collected samples)
python3 batch_generate.py --num-entries 50
```

This will:
- Process seeds from `sol_seed.jsonl`
- Generate 4 seeds concurrently (`--workers`)
- Save outputs to `dataset/with_kernel_spec/{id}/` (`{id}.sol`, `{id}.txt`, `meta.json`)
- Run semantic alignment and repair on failures
- Skip entries that already exist (resume capability)
- Log progress to `dataset/with_kernel_spec/generation.log`

## Parallel Generation

Seeds are independent, so several are generated at once (default 4 workers). A
worker atomically claims a seed via `dataset/with_kernel_spec/{id}/.claim/`
(`mkdir` is atomic across threads *and* processes). Completed seeds — those with
all three of `{id}.sol`, `{id}.txt`, `meta.json` — are skipped, so two batches
can run against the same output dir safely.

| Knob | Flag | Env | Default |
| --- | --- | --- | --- |
| Seeds in flight | `--workers` | `BATCH_WORKERS` | 4 |
| Concurrent API calls | `--max-api-concurrency` | `OPENROUTER_MAX_CONCURRENCY` | 8 |
| Seconds between API calls | `--min-api-interval` | `OPENROUTER_MIN_INTERVAL` | 0 (off) |
| Retries per API call | — | `OPENROUTER_MAX_RETRIES` | 5 |
| Concurrent solc processes | — | `SOLC_COMPILER_MAX_CONCURRENCY` | 4 |
| Concurrent runners | — | `SOLIDITY_RUNNER_MAX_CONCURRENCY` | 3 |

## Quality Gate Controls

Default generation order after MoE synthesis:

1. Compiler syntax refine (solc) — **skipped** until the compiler is wired
2. Execution refine (Foundry/Hardhat) — **skipped** until the runner is wired
3. Spec-mismatch semantic alignment (combiner repair on failures; on by default)

```bash
# Disable execution refine
python3 batch_generate.py --no-kernel-feedback

# Disable semantic alignment
python3 batch_generate.py --no-spec-alignment

# Opt into the local-CLI transport (Claude Code / Codex)
python3 batch_generate.py --llm-backend cli --num-entries 10
```

## Resume / Overwrite

```bash
# Resume from index 25
python3 batch_generate.py --start-from 25

# Overwrite existing entries
python3 batch_generate.py --no-resume
```

## Output Structure

```
dataset/with_kernel_spec/
├── U1/
│   ├── U1.sol       # Generated Solidity
│   ├── U1.txt       # NL prompt
│   └── meta.json    # Validation / alignment summary
└── generation.log
```

## Dangling stages

- **Compiler (`solc`)**: `is_compiler_available()` is `False`; the compiler
  refine loop and validation columns in `meta.json` stay empty until wired.
- **Runner (Foundry/Hardhat)**: `run_solidity_execution` reports
  `kernel_available=False`; execution refine is skipped.
- **Spec matching**: reuses `spec_aligner` (SysML-flavored question bank). Tune
  it for smart-contract semantics.

With both compiler and runner dangling, `--prompt-source seed` still produces
`.sol` files via MoE synthesis + semantic alignment. Preflight prints the exact
availability of each stage before a batch starts.
