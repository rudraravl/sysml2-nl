# Task: Codex Batch Generation

Run Codex on a server to generate SysML v2 results for all generated dataset samples.

For each sample under `dataset/data/` starting at `000387`, read its `gen_prompt.txt` and call Codex to generate the corresponding SysML v2 output file:

```text
dataset/data/<ID>/<ID>.codex.sysml
```

The run should use `codex exec` in a constrained single-shot mode so Codex receives only the prompt content and returns SysML v2 textual notation.
