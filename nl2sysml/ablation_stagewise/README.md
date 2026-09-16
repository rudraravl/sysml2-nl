# Frozen SysML stagewise ablations

This package implements the cumulative SysML v2 study requested for the paper:

| Arm | Generator feedback available during generation | Common final evaluation |
|---|---|---|
| A0 | One-shot GLM-5.2 (existing evidence; not launched here) | Must be audited separately with the same frozen evaluators |
| A1 | GLM-5.2 + RAG | Native compiler + SysML kernel harness |
| A2 | A1 retrieval + four-expert MoE + GLM-5.2 combiner | Native compiler + SysML kernel harness |
| A3 | A2 + at most two monotonic compiler-guided repairs | Native compiler + SysML kernel harness |
| A4 | A3 + at most two monotonic kernel-execution-guided repairs | Native compiler + SysML kernel harness |

The final compiler and kernel are run for **every** arm. The ablation changes
whether their diagnostics are exposed to the generation/repair model, not
whether outcomes are measured. A2 requires all four frozen expert candidates;
it never silently degrades into a smaller MoE. Specification alignment is not
part of A0--A4 and is disabled.

## Important interpretation

The current kernel orchestrator reports success when the generated harness and
candidate execute without `ERROR:` diagnostics. It preserves the raw trace,
but it does not yet convert that trace into general requirement-level behavioral
pass/fail judgments. Accordingly, report this metric as **kernel execution
success**, not full behavioral correctness.

## Local prerequisites

The study fails closed before making model calls unless all of these exist:

1. `OPENROUTER_API_KEY` in the environment or repository `.env`.
2. The `sysml2-compiler` submodule, its parser JAR/library, and Java.
3. `jupyter_client` and a working Jupyter kernelspec named `sysml`.

The official OMG SysML release documents Java 21+ and the prebuilt
`jupyter-sysml-kernel` package. The local qualification environment was
provisioned from the official `0.62.0` release archive after verifying its
published SHA-256; every run also fingerprints the installed kernel resources:

- <https://github.com/Systems-Modeling/SysML-v2-Release/tree/master/install/jupyter>
- <https://github.com/Systems-Modeling/SysML-v2-Pilot-Implementation/tree/master/org.omg.sysml.jupyter.kernel>

Typical preparation is:

```bash
git submodule update --init sysml2-compiler
python -m pip install -r requirements.txt
jupyter kernelspec list
java -version
```

Verify the entire local stack without sending a prompt to any model:

```bash
python -m nl2sysml.ablation_stagewise.run_study \
  --condition A1 \
  --output-dir /tmp/sysml-preflight \
  --task-id U1 \
  --env-file /absolute/path/to/source-worktree/.env \
  --preflight-only
```

Use the official installer for the SysML kernel rather than inventing a
kernelspec around `nl2sysml/MCSysMLv2.jar`; that JAR is a MontiCore CLI and is
not the OMG Jupyter execution kernel.

## Audit before launch

The corpus contains 1,574 unique prompts in six domains. Dry-run every shard
without provider calls:

```bash
python -m nl2sysml.ablation_stagewise.run_study \
  --condition A1 \
  --output-dir /tmp/sysml-a1-plan \
  --shard-count 4 \
  --shard-index 0 \
  --dry-run
```

The deterministic domain-stratified assignment covers every prompt exactly
once and differs by at most one sample per domain for 4, 5, or 6 workers.

## Launch locally

Commit and push the final study code first. Each condition has an independent
script, defaulting to four workers:

```bash
bash nl2sysml/ablation_stagewise/run_a1_rag.sh 4
bash nl2sysml/ablation_stagewise/run_a2_moe.sh 4
bash nl2sysml/ablation_stagewise/run_a3_compiler.sh 4
bash nl2sysml/ablation_stagewise/run_a4_execution.sh 4
```

Launch all four together (16 processes at four workers each):

```bash
bash nl2sysml/ablation_stagewise/run_all_local.sh 4
```

If credentials live in another worktree, point to that file without copying or
committing it:

```bash
export SYSML_ENV_FILE=/absolute/path/to/source-worktree/.env
```

The scripts use `caffeinate -dimsu` on macOS, checkpoint each prompt, preserve
all candidates/diagnostics/traces, and resume eligible completed cells. Provider
or native-runtime failures stop the affected shard and remain infrastructure
exclusions. Ordinary compiler/kernel failures are retained as experimental
outcomes. Use 4 workers first; 5--6 are supported but create 20--24 concurrent
processes and should only be used after observing memory and provider limits.
When the worktree-local `.venv` contains a `sysml` kernel, launchers prefer it
over any stale `SYSML_JUPYTER_PATH` value loaded later from a dotenv file. The
resolved path and kernel resource hashes are frozen in `protocol.json`.

Outputs default to `outputs/sysml-ablation-<UTC>-<commit>/<condition>/`.
After completion, `run_all_local.sh` produces adjacent paired comparisons and
exact two-sided McNemar tests in `paired-comparison.json`.

## Existing A0 evidence caveat

The fetched `origin/spec-mismatch-integration` branch contains 1,544 one-shot
GLM-5.2 artifacts under `dataset/naive_glm`, not all 1,574 seed IDs. Thirty IDs
are absent. Do not describe that archive as a complete 1,574-case A0 run unless
the missing generation evidence is recovered or rerun. For comparisons, use
the common paired subset and report missing/infrastructure cases separately.
