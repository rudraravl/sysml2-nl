# Naive-vs-full analysis

Paired comparison of the single-model baseline against the full pipeline, for the
two domains that had no standalone script (SysML's lives in
`nl2sysml/comparison_results.ipynb`).

| Domain | Script | Naive | Full |
|---|---|---|---|
| Solidity | `nl2solidity/analyze_naive_vs_full.py` | `nl2solidity/dataset/naive_glm` (solc-only until scored with `score_naive_glm.py`) | `nl2solidity/dataset/with_kernel_spec` |
| Modelica | `nl2robotics/modelica/analyze_naive_vs_full.py` | condition `B0` (`modelica_naive/`) | condition `FULL` (`robotics-corpus-full-glm52-v1/`) |

Those two scripts compare only the complete pipeline against naive: ablation arms and the
human-authored Solidity reference corpus (`dataset/data`) are not inputs. The ablation ladders
have their own scripts (below). Both scripts read only the cached `meta.json` / `run.json` the generators wrote. They call
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

## Ablation ladders

All three ablation scripts run the same metrics and statistics as their domain's naive-vs-full
analysis, once per ablation level. They share a driver, `analysis/ablation.py` (CLI, comparison
pairs, ladder table, effect tables, plots); each domain script supplies only its loader and
metric definitions, so they cannot drift apart.

| Domain | Script | Arms | Default data | Default output |
|---|---|---|---|---|
| Solidity | `nl2solidity/ablation/analyze_ablation.py` | A0 one-shot … A5 full | `nl2solidity/dataset/ablation`, else the local `ablation/solidity_ablation/ablation` | `nl2solidity/dataset/analysis_results/ablation/` |
| SysML | `nl2sysml/analyze_ablation.py` | A1 GLM+RAG … A4 (discovered from the data) | `dataset/sysml-ablation` (newest study dir, up to two levels down) | `dataset/analysis_results/sysml_ablation/` |
| Modelica | `nl2robotics/modelica/analyze_ablation.py` | A0 direct … A4 (from `study-protocol.json`) | `nl2robotics/glm52-ablation-corpus-v2` | `nl2robotics/analysis_results/modelica_ablation/` |

```bash
python nl2solidity/ablation/analyze_ablation.py
python nl2sysml/analyze_ablation.py
python nl2robotics/modelica/analyze_ablation.py
python <script> --root <dir>            # e.g. a PACE copy
python <script> --mode step             # or cumulative; --compare A2:A4 for one pair; --no-plots
```

**Comparisons.** *Step* (each arm vs the one below: what a stage adds) and *cumulative* (each arm
vs the first arm: what the pipeline has bought so far). Each gets `comparison.md/json` and PNGs
in `<from>_to_<to>/`. `ablation_summary.md/json` puts every metric down the ladder on the tasks
common to all arms, then the step and cumulative effects side by side. Both scripts take seconds
and read only cached results, so no SLURM job is needed.

**Solidity** reuses the metric definitions of `analyze_naive_vs_full.py`, so on identical corpora
A0→A5 reproduces naive-vs-full number for number.

**Modelica** reads one `run.json` per cell (`<task>/<variant>/<arm>/repeat-NN/`) plus
`study-protocol.json`. Arms A0 direct GLM-5.2, A1 +RAG, A2 +MoE, A3 +compiler repair, A4
+execution repair; there is no alignment or validated-contract stage, so the ladder stops short
of the FULL condition. The per-cell record holds no model text or diagnostic counts, so the
always-on metrics are Modelica-compile rate (final and before repair); FMU-export, FMU-execution
and valid-trace rates are added automatically once any cell reaches those stages. **In the run
as analysed no cell ever did**: every compiled model in every arm failed the `modelica_identity`
gate (generated model name ≠ planned `RobotTask_<id>_R00`), so nothing downstream was evaluated
and A3→A4 (execution repair) is uninformative by construction. The summary computes this from the
stage funnel (and recomputes reachability, because the harness's own `reached` flag over-reports
stages after the first failure), so it stays correct if the study is rerun. Tests:
`.venv/bin/python -m pytest nl2robotics/modelica/test_ablation_analysis.py`.

**SysML** metrics mirror `comparison_results.ipynb`: compiler-valid, syntax-/semantic-clean,
compiler errors, kernel pass, kernel errors and Standard Modeling Rule compliance, plus
pre-repair validity and end-to-end pass. Spec-alignment similarity is absent: the ablation
harness ran with `specification_alignment = false`. There is no one-shot arm, so cumulative
comparisons are against retrieval-only (A1), not naive. The current study (rich-500,
`dataset/sysml-ablation/outputs/sysml-ablation-rich500-20260922-0acc72e0`) runs 500 tasks per
arm, complete in every arm, on the same long descriptions (median ~300 words) the full-pipeline
corpus used for those tasks. It is still a separate run under its own protocol (2 compiler + 2
execution repairs, no specification alignment), so this analysis is deliberately
**standalone**: it is not paired with `with_kernel_spec` or `naive_glm`. The earlier partial
short-seed-prompt study (1,574 tasks, A4 stopped at 861) is superseded and kept only as raw data
in `dataset/sysml-ablation-old`. Cells the harness marks as
infrastructure-excluded (e.g. an exhausted API credit) are dropped and a pair vanishes from any
comparison where either side is missing; a task where the model produced nothing counts as a
failure for rates and has no error count. The summary includes a
coverage table showing whether each arm's completed subset is representative, and a protocol
check that the arms differ only in the condition under test. Tests:
`.venv/bin/python -m pytest nl2sysml/test_analyze_ablation.py`.

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
* **Ablation:** later arms repair against the checkers that score them (Solidity: A3 solc, A4
  Foundry, A5 Slither and the aligner; SysML: A3 compiler, A4 kernel), so gains on those metrics
  are expected by construction. Holm is applied within each comparison's table, not across
  comparisons. In the Solidity ladder table the Slither rows use only seeds where *every* arm
  compiles, so they are comparable across arms but much smaller than the other rows.
* **Modelica** pairs only what both conditions are scored on. Behaviour,
  properties, IR and contract exist for FULL alone and are reported descriptively.
  Cells that never reached a stage count as failures (intent-to-treat); pairs
  where either side is an infrastructure failure are excluded, per the study
  protocol.
* The Modelica report lists every configuration key that differs between the two
  runs (models, backend, protocol hash). Those are potential confounds.
