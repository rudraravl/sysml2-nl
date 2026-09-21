# Naive-vs-full analysis

Paired comparison of the single-model baseline against the full pipeline, for the
two domains that had no standalone script (SysML's lives in
`nl2sysml/comparison_results.ipynb`).

| Domain | Script | Naive | Full |
|---|---|---|---|
| Solidity | `nl2solidity/analyze_naive_vs_full.py` | `nl2solidity/dataset/naive_glm` (solc-only until scored with `score_naive_glm.py`) | `nl2solidity/dataset/with_kernel_spec` |
| Modelica | `nl2robotics/modelica/analyze_naive_vs_full.py` | condition `B0` (`modelica_naive/`) | condition `FULL` (`robotics-corpus-full-v1/`) |

Those two scripts compare only the complete pipeline against naive: ablation arms and the
human-authored Solidity reference corpus (`dataset/data`) are not inputs. The Solidity ablation
ladder has its own script (below). Both scripts read only the cached `meta.json` / `run.json` the generators wrote. They call
no compiler, Foundry, Slither, OpenModelica or LLM, so a run takes seconds and is
identical on a laptop and on PACE. Point them at PACE outputs with the directory
flags; nothing is hard-coded to a machine.

```bash
pip install -r analysis/requirements.txt   # numpy (+ matplotlib for PNGs)

# Solidity: first add Foundry / Slither / alignment results to the naive corpus (see below)
python nl2solidity/score_naive_glm.py --limit 3        # smoke test, then drop --limit
python nl2solidity/analyze_naive_vs_full.py            # needs dataset/naive_glm to exist
python nl2solidity/analyze_naive_vs_full.py --naive-dir <naive_glm> --full-dir <with_kernel_spec>

# Modelica
python nl2robotics/modelica/analyze_naive_vs_full.py                          # local defaults
python nl2robotics/modelica/analyze_naive_vs_full.py --naive-root <dir> --full-root <dir>
```

Each writes `comparison.md`, `comparison.json` and PNGs (`rates`, `effects`,
`continuous`, and `by_family` for Modelica) to `--out-dir`.

## Solidity naive corpus scoring and extra figures

`naive_glm_generate.py` only runs solc, so the naive `meta.json` files carry compile validity and
nothing else. `nl2solidity/score_naive_glm.py` measures the existing `.sol` files with the same
checkers the pipeline uses (Tier B property tests, Foundry fuzz, Slither, twin-blind aligner) at
zero repair passes, via ablation arm A0's measure-only profile, and merges `execution`, `security`,
`spec_alignment`, `quality` and `category` into each `meta.json` without touching the generated code or
the original `validation`. Resumable (skips samples with a `scoring` block), shardable
(`--shards N --shard k`) and needs `OPENROUTER_API_KEY`, `forge` and `slither`.

`analyze_naive_vs_full.py` also writes, next to `comparison.md`: `extras.json` (every computed number)
and `figures/*.png` + `*.pdf` (vector, for LaTeX). Figures that need the scored corpus are skipped until it exists.
Sections: paired compile outcome, why naive contracts fail solc (unresolved-import share), import
usage, structural size, quality gates, alignment thresholds, execution failure classes.

## Solidity ablation ladder

`nl2solidity/ablation/analyze_ablation.py` runs the same metrics and the same statistics for
each ablation level. It imports the metric definitions from `analyze_naive_vs_full.py`, so the
two cannot drift; on identical corpora, A0→A5 reproduces naive-vs-full number for number.

```bash
python nl2solidity/ablation/analyze_ablation.py                   # dataset/ablation, else the local copy
python nl2solidity/ablation/analyze_ablation.py --root <dir holding A0..A5>   # e.g. PACE
python nl2solidity/ablation/analyze_ablation.py --mode step       # or cumulative; --compare A2:A4 for one pair
```

Nine paired comparisons by default: **step** (A0→A1 … A4→A5, what each stage adds) and
**cumulative** (A0→A2 … A0→A5, what the pipeline has bought over one-shot by that stage).
Output in `dataset/analysis_results/ablation/`: `ablation_summary.md/json` (every metric down
the ladder, then step and cumulative effects side by side, plus `ladder_*.png`) and one
`A?_to_A?/` directory per comparison with the usual `comparison.md/json` and PNGs. It takes a
few seconds, so it runs anywhere; no SLURM job is needed.

## SysML naive-arm diagnostics

Two scripts in `nl2sysml/` back the "is the 0% naive compile rate real?" question. Output goes to
`dataset/analysis_results/sysml_first_error/` and `.../sysml_sanity/`.

```bash
python nl2sysml/first_error_breakdown.py                      # seconds; reads cached meta.json only
python nl2sysml/first_error_breakdown.py --recompile          # ~1 h; adds the `import` -> `private import` counterfactual
python nl2sysml/handwritten_sanity_check.py                   # ~15 min; human-authored corpus + controls + recompile check
```

`first_error_breakdown.py` classifies the earliest diagnostic of each naive output (de-duplicating the
jar's doubled syntax errors). `handwritten_sanity_check.py` pushes the 386 human-authored RAG-corpus
models (`dataset/data` 000001-000386) through the naive generator's own `_postprocess` -> `check_code`
path, applies deliberate defects to a known-good model, and recompiles a sample of stored naive outputs.

## Statistics (`paired_stats.py`)

Same procedure as the SysML notebook's power-analysis section. Proportions:
exact McNemar on discordant pairs, Cohen's *h*, Wilson CIs. Continuous values:
Wilcoxon signed-rank, rank-biserial *r*, Cohen's *d_z*, bootstrap CIs. Holm
correction across the whole table, plus power and n-for-80%-power. Effect sizes
are signed so **positive = full pipeline better**, including for lower-is-better
metrics. Validated against scipy (`wilcoxon`, `binomtest`).

## Reading the results

* **Solidity security metrics** are restricted to pairs where both contracts
  compile: Slither reports 0 findings for code it cannot analyse, so a
  worse-compiling baseline would otherwise look "safer".
* **Ablation:** later arms repair against the checkers that score them (A3 solc, A4 Foundry,
  A5 Slither and the aligner), so gains on those metrics are expected by construction. Holm is
  applied within each comparison's table, not across the nine comparisons. In the ladder table
  the Slither rows use only seeds where *every* arm compiles, so they are comparable across arms
  but much smaller than the other rows.
* **Modelica** pairs only what both conditions are scored on. Behaviour,
  properties, IR and contract exist for FULL alone and are reported descriptively.
  Cells that never reached a stage count as failures (intent-to-treat); pairs
  where either side is an infrastructure failure are excluded, per the study
  protocol.
* The Modelica report lists every configuration key that differs between the two
  runs (models, backend, protocol hash). Those are potential confounds.
