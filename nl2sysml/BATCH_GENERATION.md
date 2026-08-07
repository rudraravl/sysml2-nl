# Batch Generation Guide

This script generates NL-SysML pairs from `nl_seed.jsonl` using the MoE pipeline,
compiler feedback, and the post-generation spec mismatch quality gate.

## Usage

### Basic Usage

```bash
cd /Users/rudraraval/College/sysml2-nl/nl2sysml
python3 batch_generate.py --num-entries 50
```

This will:
- Process the first 50 entries from `nl_seed.jsonl` (omit `--num-entries` to process all)
- Save outputs to `dataset/with_kernel_spec/{id}/` (same layout as `dataset/with_syntax_check/`)
- Run NL-only focused question selection and semantic alignment
- Repair once when validation or semantic alignment fails
- Write `{id}.sysml`, `{id}.txt`, and `meta.json` only
- Skip entries that already exist (resume capability)
- Log progress to `dataset/with_kernel_spec/generation.log`

### Custom Number of Entries

```bash
python3 batch_generate.py --num-entries 100
```

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

# Same MoE flow via subscription CLIs + OpenRouter for Llama
# (anthropic/claude → Claude Code, openai/gpt → Codex, meta-llama → OpenRouter).
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

Set `LLM_BACKEND=cli` (or `--llm-backend cli`) to keep the same expert/combiner
model ids and route Claude through Claude Code and GPT through Codex
(`spec_aligner/llm.py`) using local subscription sign-in (not API billing).
Llama stays on OpenRouter.
`meta-llama/*` stays on OpenRouter. CLI failures (missing binary, auth, empty
output) raise immediately.

### Custom Paths

```bash
python3 batch_generate.py \
    --seed-file /path/to/nl_seed.jsonl \
    --output-dir /path/to/output
```

## Output Structure

The script creates the same structure as `dataset/data/`:

```
result_rag_moe/   # or batch --output-dir
├── U140/
│   ├── U140.sysml      # Generated SysML v2 code
│   ├── U140.txt        # NL description (from nl_seed.jsonl)
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
# Count completed entries
ls -d dataset/with_kernel_spec/U* | wc -l

# Check latest log entries
tail -f dataset/with_kernel_spec/generation.log

# Check for errors
grep ERROR dataset/with_kernel_spec/generation.log
```

## Expected Runtime

- Each entry takes approximately 2-5 minutes (depends on API response times)
- 50 entries: ~2-4 hours
- With compiler enabled: slightly longer due to validation

## Troubleshooting

### API Rate Limits

If you hit rate limits, the script will log errors and continue. You can:
1. Wait and resume from the last successful entry
2. Reduce concurrent API calls (modify `agent_rag_moe.py`)

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
