# Batch Generation Guide

This script generates NL-SysML pairs using the MoE pipeline, compiler feedback,
and the post-generation spec mismatch quality gate.

**Prompts:** By default, NL comes from the richer text in
`dataset/data/XXXXXX/XXXXXX.txt` (linked via `meta.json`
`source_path: nl_seed.jsonl:U###`). Seed order / output folders still use
`nl_seed.jsonl` ids (`U140`, …). Use `--prompt-source seed` for the short wiki
seeds.

## Usage

### Basic Usage

```bash
cd /Users/rudraraval/College/sysml2-nl/nl2sysml
python3 batch_generate.py --num-entries 50
```

This will:
- Process the first 50 seeds from `nl_seed.jsonl` (omit `--num-entries` to process all)
- Generate 4 seeds concurrently (`--workers`, see [Parallel Generation](#parallel-generation))
- Use rich NL from `dataset/data/{data_id}/{data_id}.txt` as the generation prompt
- Save outputs to `dataset/with_kernel_spec/{id}/` (same layout as `dataset/with_syntax_check/`)
- Run NL-only focused question selection and semantic alignment
- Repair once when validation or semantic alignment fails
- Write `{id}.sysml`, `{id}.txt` (rich NL), and `meta.json` only
- Skip entries that already exist (resume capability)
- Log progress to `dataset/with_kernel_spec/generation.log`

### Custom Number of Entries

```bash
python3 batch_generate.py --num-entries 100
```

### Parallel Generation

Seeds are independent, so several are generated at once. Default is 4 workers;
each worker still fans its sample out to all experts in parallel.

```bash
# 8 seeds in flight at once
python3 batch_generate.py --workers 8

# Sequential (previous behavior)
python3 batch_generate.py --workers 1
```

**No repeats, no overlap.** Before generating, a worker atomically claims the
seed by creating `dataset/with_kernel_spec/{id}/.claim/` (mkdir is atomic, so
this holds across threads *and* across separate `batch_generate.py` processes
pointed at the same output dir). Already-complete seeds — those with all three
of `{id}.sysml`, `{id}.txt`, `meta.json` — are skipped, both when the worklist
is built and again right before generation, so a seed finished by another
process mid-run is never redone. Claims are released when the entry finishes; a
claim left by a crashed run is reclaimed once its owner process is gone or
after `BATCH_CLAIM_STALE_SEC` (default 7200s).

This means you can safely run two batches at once (e.g. different
`--start-from` windows) against the same output directory.

**Rate limits.** Total in-flight OpenRouter requests are `workers ×
EXPERT_PARALLELISM`, so a global cap sits in front of all of them, and 429 /
5xx / timeout responses are retried with exponential backoff plus jitter,
honoring `Retry-After` when OpenRouter sends it. Only genuinely fatal errors
(auth, bad request, exhausted retries) surface as a soft-fail for that entry.

| Knob | Flag | Env | Default |
| --- | --- | --- | --- |
| Seeds in flight | `--workers` | `BATCH_WORKERS` | 4 |
| Concurrent API calls | `--max-api-concurrency` | `OPENROUTER_MAX_CONCURRENCY` | 8 |
| Seconds between API calls | `--min-api-interval` | `OPENROUTER_MIN_INTERVAL` | 0 (off) |
| Retries per API call | — | `OPENROUTER_MAX_RETRIES` | 5 |
| Concurrent compiler JVMs | — | `SYSML_COMPILER_MAX_CONCURRENCY` | 4 |
| Concurrent SysML kernels | — | `SYSML_KERNEL_MAX_CONCURRENCY` | 3 |

If OpenRouter still rate-limits you, lower `--max-api-concurrency` first (it
throttles without reducing throughput as much as fewer workers would), then add
`--min-api-interval 0.5`. The compiler and kernel caps exist because each of
those spawns a JVM — raise them only if the machine has headroom.

Console output is buffered per entry and printed as one block when the entry
finishes, so parallel runs stay readable; `generation.log` still receives every
line in real time.

### Resume After Interruption

If the script is interrupted, you can resume from where it left off:

```bash
python3 batch_generate.py --start-from 25
```

This will skip the first 25 entries and continue from entry 26.

### Overwrite Existing Entries

By default, the script skips entries that already exist. To overwrite:

```bash
python3 batch_generate.py --no-resume
```

### Quality Gate Controls

Default generation order after MoE synthesis:

1. Compiler syntax refine
2. SysML kernel execution refine (requires Jupyter SysML kernel; on by default)
3. Spec-mismatch semantic alignment (combiner repair on failures; on by default)

```bash
# Disable kernel execution refine
python3 batch_generate.py --no-kernel-feedback

# Disable semantic alignment
python3 batch_generate.py --no-spec-alignment

# Same MoE flow (OpenRouter API is the default for every expert + combiner)
python3 batch_generate.py --num-entries 10

# Opt into the legacy local-CLI transport (Claude Code / Codex)
python3 batch_generate.py --llm-backend cli --num-entries 10
```

If any LLM/provider call fails — OpenRouter errors, CLI 5-hour/weekly limits,
blank model output, auth/binary failures, or alignment LLM failures — batch
generation stops immediately (exit code 2), keeps completed outputs, and prints
a `--start-from N` resume hint.

Generation data flow:

1. RAG + expert MoE → combiner synthesis  
2. Compiler refine  
3. Kernel refine  
4. Semantic align (combiner repair on failures; each repair is re-validated with
   compiler + kernel and kept only if alignment improves without worsening
   executability)

By default (`LLM_BACKEND=api`, or omit the flag) every expert and the combiner
go over OpenRouter HTTP, using `OPENROUTER_API_KEY` from `.env`. The current
model set — `z-ai/glm-5.2` (combiner), `deepseek/deepseek-v4-pro`,
`qwen/qwen3.8-max`, `meta-llama/llama-4-maverick` — has no local CLI route, so
`--llm-backend cli` (or `LLM_BACKEND=cli`) changes nothing unless an
`anthropic/*` or `openai/*` model is put back in `EXPERT_MODELS`; those would
then use Claude Code / Codex via `spec_aligner/llm.py` with local subscription
sign-in (not API billing). CLI failures (missing binary, auth, empty output)
raise immediately.

### Prompt Source

```bash
# Default: rich NL from dataset/data (recommended)
python3 batch_generate.py --prompt-source dataset

# Short wiki seeds from nl_seed.jsonl
python3 batch_generate.py --prompt-source seed

# Skip seeds with no matching dataset/data/*.txt (no fallback)
python3 batch_generate.py --require-dataset-nl
```

### Custom Paths

```bash
python3 batch_generate.py \
    --seed-file /path/to/nl_seed.jsonl \
    --dataset-data-dir /path/to/dataset/data \
    --output-dir /path/to/output
```

## Output Structure

The script creates the same structure as `dataset/data/`:

```
result_rag_moe/   # or batch --output-dir
├── U140/
│   ├── U140.sysml      # Generated SysML v2 code
│   ├── U140.txt        # NL prompt (rich dataset/data text by default)
│   └── meta.json       # Validation / alignment summary (dataset-style)
├── U544/
│   ├── U544.sysml
│   ├── U544.txt
│   └── meta.json
└── generation.log      # Batch runs only
```

Same three files as `dataset/with_syntax_check/{id}/`.

## Features

- **Progress Tracking**: Shows progress every 10 entries
- **Resume Capability**: Automatically skips existing entries
- **Error Handling**: Continues on errors, logs them separately
- **Validation Info**: Includes compiler validation status in meta.json
- **Logging**: Detailed log file with timestamps

## Running Overnight

The script is designed to run safely overnight:

1. **Resume on Interruption**: If interrupted (Ctrl+C), you can resume
2. **Error Recovery**: Individual errors don't stop the batch
3. **Progress Logging**: Check `generation.log` for progress
4. **No Duplication**: Skips existing entries by default

### Recommended Command

```bash
# Option 1: Run in background with nohup (simpler)
cd /Users/rudraraval/College/sysml2-nl/nl2sysml
source ../.venv/bin/activate  # Activate venv first
nohup python3 batch_generate.py > batch_output.log 2>&1 &

# Option 2: Use screen/tmux for better monitoring
screen -S batch_gen
# Inside screen, activate venv and run:
cd /Users/rudraraval/College/sysml2-nl/nl2sysml
source ../.venv/bin/activate
python3 batch_generate.py
# Press Ctrl+A then D to detach
# Reattach with: screen -r batch_gen
```

## Monitoring Progress

While running, you can check progress:

```bash
# Count completed entries (meta.json only exists once an entry is done)
ls dataset/with_kernel_spec/U*/meta.json | wc -l

# Entries currently being generated
ls -d dataset/with_kernel_spec/U*/.claim 2>/dev/null | wc -l

# Check latest log entries
tail -f dataset/with_kernel_spec/generation.log

# Check for errors
grep ERROR dataset/with_kernel_spec/generation.log
```

## Expected Runtime

- Each entry takes approximately 2-5 minutes (depends on API response times)
- With `--workers 4`, wall clock is roughly a quarter of that, until the API
  concurrency cap or the compiler/kernel caps become the bottleneck
- 50 entries: ~2-4 hours sequential, ~40-60 min at `--workers 4`
- With compiler enabled: slightly longer due to validation

## Troubleshooting

### API Rate Limits

429s are retried automatically with backoff. If they persist:
1. Lower `--max-api-concurrency` (e.g. 4)
2. Add `--min-api-interval 0.5` to space requests out
3. Lower `--workers` as a last resort — it costs the most throughput

### Out of Memory

If the process is killed, just resume:
```bash
python3 batch_generate.py --start-from <last_completed_index>
```

### Check Validation Status

```bash
# Count valid vs invalid
grep -r '"is_valid": true' dataset/with_kernel_spec/*/meta.json | wc -l
grep -r '"is_valid": false' dataset/with_kernel_spec/*/meta.json | wc -l
```
