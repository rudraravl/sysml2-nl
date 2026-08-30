# Quick Start Guide - Running Single Samples

## Direct Command-Line Usage

Yes, `agent_rag_moe.py` still works the same way as before!

### Run with a Description String

```bash
cd /Users/rudraraval/College/sysml2-nl/nl2sysml
source ../.venv/bin/activate  # If using venv
python3 agent_rag_moe.py "Design a system based on an Air ioniser and describe its primary function at a high level."
```

This will:
- Generate SysML v2 code using the MoE pipeline
- Print the generated code to stdout
- Use compiler feedback (if enabled)

### Run from nl_seed.jsonl Entry

```bash
# Using the test script (recommended)
python3 test_single.py U140

# Or by entry number (1-indexed)
python3 test_single.py 1

# Without compiler checking (faster)
python3 test_single.py U140 --no-compiler
```

### Run Batch from dataset.json

If you run without arguments, it processes `dataset.json`:

```bash
python3 agent_rag_moe.py
# Processes all entries in nl2sysml/dataset.json
# Saves to nl2sysml/result_rag_moe/
```

## Examples

### Example 1: Simple Description
```bash
python3 agent_rag_moe.py "Create a vehicle system with engine, transmission, and wheels"
```

### Example 2: From nl_seed.jsonl
```bash
# Get entry by ID
python3 test_single.py U544

# Get entry by index
python3 test_single.py 5
```

### Example 3: Disable Compiler (Faster Testing)
```bash
# Via environment variable
SYSML_COMPILER_ENABLED=false python3 agent_rag_moe.py "Your description here"

# Via test script flag
python3 test_single.py U140 --no-compiler
```

## Output

### Direct Command (agent_rag_moe.py)
- Prints SysML code to stdout
- No files saved

### Test Script (test_single.py)
- Prints progress and results
- Saves to `result_rag_moe/{id}/{id}.sysml`, `{id}.txt`, `meta.json` (dataset-style)
- Shows validation status

## What Happens

1. **RAG Context**: Loads similar examples from dataset
2. **Expert Models**: Queries the current open-source Qwen, GLM, DeepSeek,
   and Llama expert set through OpenRouter
3. **Compiler Check**: Validates each candidate (if enabled)
4. **Refinement**: Iteratively fixes errors (if compiler enabled)
5. **Synthesis**: Combines candidates into final model
6. **Final Check**: Validates final output

## Troubleshooting

### "ModuleNotFoundError"
```bash
# Make sure venv is activated
source ../.venv/bin/activate
pip install -r ../requirements.txt
```

### "Empty output generated"
- Check API keys in `.env` file
- May be rate limited - wait and retry
- Check internet connection

### Takes too long
- Disable compiler: `--no-compiler` or `SYSML_COMPILER_ENABLED=false`
- Reduce expert models in `agent_rag_moe.py` (edit `EXPERT_MODELS`)

## Quick Reference

```bash
# Single description
python3 agent_rag_moe.py "Your description"

# From nl_seed.jsonl (by ID)
python3 test_single.py U140

# From nl_seed.jsonl (by index)
python3 test_single.py 1

# Without compiler
python3 test_single.py U140 --no-compiler

# Batch generation (50 entries)
python3 batch_generate.py
```
