# GPT-5.4 Ablation Study (Isolated)

Compares three pipeline configurations on `nl2sysml/dataset.json` (U1–U20) using the SysML v2 compiler as the objective metric. Does **not** modify `agent_rag_moe.py` or write to `result_rag_moe/`.

## Conditions

| ID | Folder | Setup |
|----|--------|--------|
| A | `results/baseline_no_rag/` | `openai/gpt-5.4`, empty context, no compiler repair |
| B | `results/rag_gpt54/` | `openai/gpt-5.4` + lexical `_rag_context`, no repair |
| C | `results/moe_full/` | Full `generate_sysml_moe()` (all experts incl. GPT-5.4) + compiler refinement |

## Prerequisites

1. **API keys** in repo-root `.env`:
   - `OPENROUTER_API_KEY` (conditions A and B; also used by MOE OpenRouter experts)
   - `GEMINI_API_KEY` (condition C — Gemini expert)

2. **SysML compiler** built and discoverable. See [COMPILER_FEEDBACK.md](../COMPILER_FEEDBACK.md) and [sysml2-compiler/README.md](../../sysml2-compiler/README.md).

   ```bash
   SYSML_COMPILER_ENABLED=true
   ```

   The study aborts if `is_compiler_available()` is false.

## Run

From repository root:

```bash
# Full study (A → B → C on all 20 prompts; condition C is slow)
python nl2sysml/ablation_gpt54/run_study.py --conditions all

# Single condition or subset
python nl2sysml/ablation_gpt54/run_study.py --conditions baseline
python nl2sysml/ablation_gpt54/run_study.py --conditions rag --ids U1,U2

# Resume after interruption
python nl2sysml/ablation_gpt54/run_study.py --conditions moe --resume

# Re-aggregate metrics from existing outputs
python nl2sysml/ablation_gpt54/run_study.py --summary-only

# Plan without API calls
python nl2sysml/ablation_gpt54/run_study.py --dry-run --conditions all
```

## Outputs

Per prompt: `{ID}.sysml`, `{ID}_meta.json` (compiler metrics). Condition C also saves `{ID}_prompt_record.json`.

Corpus summary:

- `results/summary.json` — structured metrics + pairwise deltas
- `results/summary.md` — markdown table for papers/slides

## Metrics

**Per prompt:** `is_valid`, `error_count`, syntax/semantic error counts, `empty_output`, retrieval/refinement metadata.

**Corpus:** valid rate, mean/median errors, syntax/semantic failure rates, pairwise Δ (B−A, C−B, C−A). For C only: mean errors before refinement, refinement gain, fixed-by-refinement rate.

## Cost note

- A + B: ~20 OpenRouter calls each.
- C: ~20 × (4 experts + 1 combiner + up to 2 refinement passes) — dominates runtime and cost.

Results under `results/` are gitignored.

## Latest run (dataset.json U1–U20)

After a full run, inspect:

- `results/summary.md` — corpus comparison table
- `results/summary.json` — full per-prompt metrics
- `results/moe_run.log` — MOE execution log (if run via nohup)

**Note:** If `GEMINI_API_KEY` is invalid, condition C still runs with the other three OpenRouter experts plus the Claude combiner; fix the key and re-run `--conditions moe --resume` to include Gemini candidates.
