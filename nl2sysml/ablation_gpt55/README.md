# GPT-5.5 Ablation Studies

Isolated experiments under `nl2sysml/ablation_gpt55/`. Does not modify `agent_rag_moe.py` or write to `result_rag_moe/`.

## Stage A — Baseline on `nl_seed.jsonl`

**GPT-5.5 only**: default system prompt + NL description. No RAG, no MOE, no compiler repair.

From repository root:

```bash
python nl2sysml/ablation_gpt55/batch_nl_seed.py --dry-run
python nl2sysml/ablation_gpt55/batch_nl_seed.py
python nl2sysml/ablation_gpt55/batch_nl_seed.py --num-entries 100
python nl2sysml/ablation_gpt55/batch_nl_seed.py --start-from 25   # resume
python nl2sysml/ablation_gpt55/batch_nl_seed.py --no-resume      # overwrite
```

Outputs (gitignored):

- `results/baseline_nl_seed/{U###}/{U###}.sysml`
- `results/baseline_nl_seed/{U###}/{U###}.txt`
- `results/baseline_nl_seed/{U###}/meta.json`
- `results/baseline_nl_seed/{U###}/{U###}_prompt.json`
- `results/baseline_nl_seed/generation.log`

Requires only `OPENROUTER_API_KEY` in repo-root `.env`.

Override model:

```bash
GPT55_MODEL=openai/gpt-5.5 python nl2sysml/ablation_gpt55/batch_nl_seed.py
```

## Executable-rule study (`dataset.json`)

Runs GPT-5.5 **with RAG** on the 20 prompts in `nl2sysml/dataset.json`, then checks compiler validity and five `Executable` rules from the SysML 2 Rule Verification Guide:

- `ACCEPTEVENTOUTPUT`
- `MESSAGEFLOWNEEDED`
- `MESSAGESIGNATURE`
- `STMINTEGRITY`
- `SUBMACHINESTR`

```bash
python nl2sysml/ablation_gpt55/run_study.py --dry-run
python nl2sysml/ablation_gpt55/run_study.py
python nl2sysml/ablation_gpt55/run_study.py --ids U1,U9
python nl2sysml/ablation_gpt55/run_study.py --resume
python nl2sysml/ablation_gpt55/run_study.py --summary-only
```

Outputs:

- `generated/{ID}.sysml`, `generated/{ID}_prompt.json`
- `result.csv`, `index.html`

Requires `OPENROUTER_API_KEY` and SysML compiler setup per `nl2sysml/COMPILER_FEEDBACK.md`.

## Layout

| File | Role |
|------|------|
| `config.py` | Paths, model id, shared constants |
| `generators.py` | `generate_baseline()` (Stage A), `generate_with_rag()` (rule study) |
| `batch_nl_seed.py` | Batch CLI for `nl_seed.jsonl` baseline |
| `run_study.py` | Executable-rule evaluation on `dataset.json` |
| `executable_rules.py` | Text-first rule checker |
| `report.py` | HTML report from `result.csv` |

## Codex CLI GPT-5.5 baseline

Runs Codex as a single-shot completion over generated dataset prompts:

```bash
python nl2sysml/ablation_gpt55/batch_codex_gpt55.py --dry-run --limit 3
python nl2sysml/ablation_gpt55/batch_codex_gpt55.py --limit 10
python nl2sysml/ablation_gpt55/batch_codex_gpt55.py
```

For each sample from `dataset/data/000387` onward, the script reads
`gen_prompt.txt` and writes:

- `dataset/data/<ID>/<ID>.codex.sysml`
- `dataset/data/<ID>/<ID>.codex.log`

The Codex invocation uses `--sandbox read-only`, `--ignore-rules`,
`--ignore-user-config`, `--ephemeral`, and `--skip-git-repo-check`, with an
empty temporary working directory. The prompt explicitly tells Codex not to use
tools, inspect files, or run commands.

The current Codex CLI on this machine does not expose `--ask-for-approval`; do
not include `--ask-for-approval never` unless `codex exec --help` shows it in
your installed version.
