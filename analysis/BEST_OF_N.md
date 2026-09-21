# Best-of-N sampling baseline

> "How does the harness compare to best-of-6 sampling from GLM-5.2, scored by the same compiler?"

FORGE spends several model calls per requirement (experts + combiner + repair rounds); the naive
arm spends one. Best-of-N is the compute-matched control: draw N independent one-shot samples of the
**naive baseline**, let the **same compiler** the harness uses pick one, and stop. No retrieval, no
experts, no combiner, no repair loop, no feedback of any kind.

Each script is the naive arm with its single generation call replaced by N, and nothing else. The
prompt, model, temperature, post-processing and downstream scoring are the naive arm's own, so
naive -> BoN isolates *sampling*, and BoN -> FORGE isolates *the design* at (roughly) matched calls.

| domain | script | samples | selector | writes | pairs with |
|---|---|---|---|---|---|
| SysML | `nl2sysml/best_of_n_generate.py` | `naive_glm_generate.py`'s call | SysML compiler (jar) | `dataset/best_of_6/` | `dataset/naive_glm`, `dataset/with_kernel_spec` |
| Solidity | `nl2solidity/best_of_n/run_best_of_n.py` | ablation arm **A0** | `solc` | `nl2solidity/dataset/best_of_n/BoN6/` | ablation `A0`..`A5` (same first 500 seeds) |
| Modelica | `python -m nl2robotics.experiments.run_best_of_n` | condition **B0** | OpenModelica | `<output-dir>/<task>/rich/BoN6/` | `B0`, `FULL` |

## Selection rules (compiler only, deterministic, no oracle)

Nothing downstream of the compiler (Foundry, Slither, alignment, FMU export/execution, traces) ever
influences the choice. Those run on the winner afterwards, exactly as they do for the other arms.

* **SysML**: compiles cleanly > compiler actually scored it > fewest **de-duplicated** errors > lowest
  index. (The parser jar reports each syntax error twice, see `recompute_sysml_stats.py`; raw counts are
  stored too.) Empty and timed-out candidates rank last, since an empty file has "0 errors".
* **Solidity**: compiles cleanly > fewest `solc` errors > lowest index.
* **Modelica**: maximise `Layer1CandidateResult.quality` = `(compiled, checked, -error_count)`, the
  ordering FORGE's own compile-repair loop uses to keep an attempt, then lowest index.

## Running it

**SysML** (needs java + the parser jar; prompts come from `dataset/with_kernel_spec/<ID>/<ID>.txt`, the
same set the naive arm used):

```bash
python nl2sysml/best_of_n_generate.py --dry-run --limit 10          # sanity
sbatch nl2sysml/pace/best_of_n.sbatch                               # 5 shards; BON_N / BON_SHARDS override
```

**Solidity** (same node setup, toolchain and eval set as the ablation; measures the winner with Foundry,
Slither and the aligner, zero repair passes, so every A0..A5 metric exists for BoN too):

```bash
python nl2solidity/best_of_n/run_best_of_n.py --shards 5 --shard 0 --dry-run
sbatch nl2solidity/best_of_n/pace/best_of_n.sbatch                  # ABLATION_N=500, 5 shards by default
```

**Modelica**: freeze the protocol once (no model calls), then submit. The header of
`nl2robotics/experiments/pace/best_of_n.sbatch` has the exact freeze command.

```bash
sbatch nl2robotics/experiments/pace/best_of_n.sbatch                # 16 shards; see the header
```

All three resume when you resubmit the identical command. Set `--account` / `--partition` first
(`gts-CHANGEME` placeholders in each sbatch).

## What lands on disk

Naive-compatible output plus a `best_of_n` block that lists every candidate's compile result
(`selected_index`, `n_valid`, `any_valid`, `n_distinct`, per-candidate errors), and every candidate's
source (`candidates/cand-k.*`, or `attempts[]` in Modelica's `generation.json`). Because the samples are
independent, this gives you more than the headline number for free:

* **mean per-sample validity** (average over candidates) is the naive rate measured with N times the data;
* **any-of-k for k <= N**, from the first k candidates, is an unbiased best-of-k. Run `--n 12` once and
  read off best-of-1 ... best-of-12 to show where sampling saturates against FORGE's call count.

Check `n_distinct` before believing a result: if the six samples are mostly identical, the sampler was
not diverse and the baseline is weaker than it looks.

## Comparing

```bash
# Solidity: BoN6 vs full pipeline (A5), and what sampling alone buys over one-shot (A0)
python nl2solidity/analyze_naive_vs_full.py \
  --naive-dir nl2solidity/dataset/best_of_n/BoN6 --full-dir nl2solidity/dataset/ablation/A5
python nl2solidity/analyze_naive_vs_full.py \
  --naive-dir nl2solidity/dataset/ablation/A0 --full-dir nl2solidity/dataset/best_of_n/BoN6

# Modelica: BoN6 as the "naive" side
python nl2robotics/modelica/analyze_naive_vs_full.py \
  --naive-root outputs/robotics-corpus-bon6 --naive-condition BoN6 \
  --full-root nl2robotics/robotics-corpus-full-v1

# SysML: first-error breakdown takes --naive-dir
python nl2sysml/first_error_breakdown.py --naive-dir dataset/best_of_6
```

**SysML has no paired-stats script that accepts a different naive directory yet.**
`recompute_sysml_stats.py`, `compare_naive_vs_pipeline.py` and the notebook hard-code
`dataset/naive_glm`, and the former also needs the naive-specific `kernel_results_naive.json`. For the
compiler comparison the reviewer asked about, the compile rate and de-duplicated error count are in
each `meta.json`; a small paired script over `best_of_6` vs `with_kernel_spec` is the missing piece.

## Caveats to state alongside the numbers

* **Compute matching is approximate.** N=6 is the low end of FORGE's call count (4 experts + combiner
  is already 5, before compiler repair, property-test authoring, execution repair and alignment). Use
  `--n` to match a measured average, or run a larger N and read off best-of-k.
* **The selector is the compiler only.** FORGE's later stages also use execution feedback (Foundry,
  FMU runtime). A baseline that selected on those would be stronger; this one is what the question asks
  for. Solidity and Modelica *measure* those stages on the winner, so they report the same funnel.
* **FORGE's ensemble is heterogeneous** (Qwen, GLM, DeepSeek, Llama); BoN samples GLM-5.2 only.
* **Same decoding as the naive arm** (temperature 0.2 via the shared transport), by design.
* **SysML**: compile timeout is 120 s per candidate (naive used 60 s), and sampling uses FORGE's
  hardened OpenRouter transport rather than the naive script's bare one (retries on 429/5xx). Same
  model, prompt and temperature.
* **Modelica transport**: the existing B0 protocol recorded `attempts: 3`; the transport has since been
  hardened. Temperature, token limit and provider routing are unchanged.
* **Modelica needs docker** (FMU execution and, by default, OpenModelica). If PACE has none, the
  runtime preflight stops the job before any model call.

## Testing

Offline only (fake LLM, no network); none of this was run against a live API.

```bash
.venv/bin/python -m pytest nl2sysml/test_best_of_n_sysml.py nl2solidity/best_of_n/test_best_of_n_solidity.py -q
.venv/bin/python -m unittest nl2robotics.experiments.test_best_of_n
```

* SysML and Solidity tests run against the **real compiler** (java jar / `solc`); the Solidity end-to-end
  test drives the real generator and `batch_generate` with only the HTTP layer faked.
* Modelica tests use a fake compiler: they exercise the real `AblationRunner`, orchestrator, fidelity
  audit and metrics, but **not real OpenModelica / Docker**.
* Not exercised offline: the spec-aligner stage of Solidity measure-all mode (a fake LLM cannot produce
  its JSON); Foundry and Slither did run.
