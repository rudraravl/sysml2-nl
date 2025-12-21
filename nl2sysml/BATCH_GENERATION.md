# Batch Generation Guide

This script generates NL-SysML pairs from `nl_seed.jsonl` using the MoE pipeline with compiler feedback.

## Usage

### Basic Usage (First 50 entries)

```bash
cd /Users/rudraraval/College/sysml2-nl/nl2sysml
python3 batch_generate.py
```

This will:
- Process the first 50 entries from `nl_seed.jsonl`
- Save outputs to `dataset/with_syntax_check/`
- Skip entries that already exist (resume capability)
- Log progress to `dataset/with_syntax_check/generation.log`

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

### Custom Paths

```bash
python3 batch_generate.py \
    --seed-file /path/to/nl_seed.jsonl \
    --output-dir /path/to/output
```

## Output Structure

The script creates the same structure as `dataset/data/`:

```
dataset/with_syntax_check/
├── U140/
│   ├── U140.sysml      # Generated SysML v2 code
│   ├── U140.txt        # NL description (from nl_seed.jsonl)
│   └── meta.json       # Metadata
├── U544/
│   ├── U544.sysml
│   ├── U544.txt
│   └── meta.json
└── generation.log      # Generation log with timestamps
```

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
ls -d dataset/with_syntax_check/U* | wc -l

# Check latest log entries
tail -f dataset/with_syntax_check/generation.log

# Check for errors
grep ERROR dataset/with_syntax_check/generation.log
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
grep -r '"is_valid": true' dataset/with_syntax_check/*/meta.json | wc -l
grep -r '"is_valid": false' dataset/with_syntax_check/*/meta.json | wc -l
```

