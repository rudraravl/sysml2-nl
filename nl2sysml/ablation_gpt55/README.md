# GPT-5.5 Executable Rule Ablation

This isolated study runs GPT-5.5 on the 20 prompts in `nl2sysml/dataset.json`,
checks compiler validity, and evaluates the five `Executable` rules from the
SysML 2 Rule Verification Guide:

- `ACCEPTEVENTOUTPUT`
- `MESSAGEFLOWNEEDED`
- `MESSAGESIGNATURE`
- `STMINTEGRITY`
- `SUBMACHINESTR`

The rule checker is a text-first static analyzer. It reports `pass`, `fail`,
`not_applicable`, and `unsupported`, with rationale fields in the CSV.

## Run

From repository root:

```bash
python nl2sysml/ablation_gpt55/run_study.py --dry-run
python nl2sysml/ablation_gpt55/run_study.py
```

Run a subset:

```bash
python nl2sysml/ablation_gpt55/run_study.py --ids U1,U9
```

Resume using existing generated files:

```bash
python nl2sysml/ablation_gpt55/run_study.py --resume
```

Rebuild HTML from the current CSV:

```bash
python nl2sysml/ablation_gpt55/run_study.py --summary-only
```

## Configuration

The default model is:

```text
openai/gpt-5.5
```

Override it with:

```bash
GPT55_MODEL=openai/gpt-5.5 python nl2sysml/ablation_gpt55/run_study.py
```

Required environment:

- `OPENROUTER_API_KEY` in repo-root `.env`
- SysML compiler environment configured as in `nl2sysml/COMPILER_FEEDBACK.md`

## Outputs

- `nl2sysml/ablation_gpt55/generated/{ID}.sysml`
- `nl2sysml/ablation_gpt55/generated/{ID}_prompt.json`
- `nl2sysml/ablation_gpt55/result.csv`
- `nl2sysml/ablation_gpt55/index.html`
