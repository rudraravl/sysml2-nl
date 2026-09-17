# Robotics Ablations

The five frozen stagewise conditions are:

| ID | Condition | RAG | MoE | Tool repair | Alignment | Contract |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| B0 | Direct frontier | no | no | no | no | no |
| B1 | RAG | yes | no | no | no | no |
| B2 | RAG + MoE | yes | yes | no | no | no |
| B3 | Tool-grounded | yes | yes | yes | no | yes |
| FULL | Complete pipeline | yes | yes | yes | yes | yes |

The frozen B0 one-shot baseline is `z-ai/glm-5.2` through OpenRouter, which is
also the MoE combiner. B1 uses the same model with RAG so the B0-to-B1 contrast
changes retrieval rather than model identity. GLM-5.2 is also the support model
used for normalized IR, semantic alignment, and runtime repair. MoE compiler
repair uses the same frozen GLM combiner. The paper-facing runner restricts all
LLM roles to the frozen open-model roster and records the selected model and
provider in the protocol. Every condition is evaluated by the same native
compilation, FMU execution, trace, and behavior harness.

`AblationRunner` blocks by task and repetition, then randomizes condition order
within each block using the recorded `--randomization-seed`. One normalized and
validated requirement IR is persisted per block and reused by every paired
condition. Every eligible cell has a configuration fingerprint and independent
`run.json`; interrupted experiments resume without mixing model settings,
prompts, normalization, or run order.

Before either a dry run or a real run, `study-protocol.json` freezes the Git
state, prompt and manifest hashes, applicable retrieval-corpus tree hashes,
condition definitions, model roster, runtime/validator provenance, exclusion
rules, randomized order, and exact cell fingerprints. Reusing that output
directory with different frozen inputs fails closed.

Corpus and execution-targeted held-out runs use a seeded randomized task order
instead of their manifest row order. Task/repetition blocks remain intact, and
multi-worker corpus shards are category-stratified.

The concrete executor maps legacy profile tasks to their original paths. All
paper-facing `capability` tasks use the Modelica-only compile/FMU/behavior/spec
path and never invoke OpenUSD generation or validation. Run a small frozen
slice with:

```bash
python3 -m nl2robotics.experiments.run_cli \
  --profile modelica --task-id RBM001 \
  --condition B0 --condition FULL --variant rich \
  --output-dir outputs/robotics-ablation-pilot
```

`RBH005` is recorded as external infrastructure until its generated bundle is
executed through the Isaac handoff; it is never counted as a model failure. On
the GPU host, add `--isaac-python /opt/isaacsim/python.sh` (plus the frozen H2
device, solver, controller backend, and repetition options when needed). The
executor then runs the handoff and merges the real Isaac report into the same
cell before metrics are extracted.

Newton studies use a study manifest and the same in-process, fail-closed runner:

```bash
python3 -m nl2robotics.experiments.run_cli \
  --benchmark-manifest nl2robotics/studies/articulated_manifest.json \
  --profile hybrid --condition FULL --variant rich \
  --newton-handoff --newton-device cpu \
  --newton-controller-backend docker --newton-repetitions 3 \
  --output-dir outputs/articulated-full-pilot
```

On DeltaAI use `--newton-device cuda:0 --newton-controller-backend local`.
Newton evidence remains labeled as Newton, and DeltaAI eligibility still
depends on genuine Linux ARM64 H100 CUDA provenance from each executed run.

The metric layer separates infrastructure failures from generated-artifact
failures, reports binary rates with seeded bootstrap confidence intervals,
continuous summaries, failure-stage distributions, and exact paired McNemar
tests. Attempt-zero artifact validity is retained separately from repaired final
validity. Every run also contains a condition-fidelity audit proving which RAG,
MoE, tool-repair, contract, and alignment controls were active. A missing frozen
MoE expert makes the cell infrastructure-ineligible and forces an identical
rerun; it is never compared as a smaller accidental ensemble. Provider usage
limits stop the batch without writing a false failed cell.

FMU runtime failures also retain a stable failure class and the native failure
time when available. `runtime_survival_fraction` reports the fraction of the
grounded requested horizon completed by every FMU execution attempt (successful
runs equal 1.0). It is a secondary progress metric, never a substitute for FMU
execution, finite-trace, behavior, or end-to-end pass rates.

Compare that progress on paired runtime-eligible cells with:

```bash
python3 -m nl2robotics.experiments.cli outputs/robotics-ablations \
  --pair B0 FULL --metric runtime_survival_fraction
```

The report includes the paired mean/median effect, seeded bootstrap confidence
interval, improved/tied/regressed counts, and an exact paired sign test.

For capability ablations, B0 is the compiler/execution baseline: one raw-NL
generation call, native Modelica compilation, FMI export, FMU initialization,
simulation, and finite-trace validation. Because B0 is not shown the pipeline's
internal FMU variable ABI, interface-, property-, and semantic-alignment fields
are unevaluated rather than false. Use artifact validity, FMU export, runtime
execution, and finite-trace survival for paired B0-to-FULL comparisons; report
FULL's stricter interface, behavior, and specification results separately.
`configured_pipeline_success` records whether each condition completed its own
enabled stages. `end_to_end` is intentionally unavailable when semantic
alignment is disabled, so the headline full-funnel comparison cannot become a
tautology.

Summarize archived capability comparisons with a common outcome metric:

```bash
python3 -m nl2robotics.experiments.cli outputs/robotics-ablations \
  --pair B0 FULL --metric all_properties_pass \
  --output outputs/robotics-ablations/summary.json
```

Do not launch the full 15 x 5 x 3 grid first. Start with one rich-prompt repeat,
inspect failures, then repeat a representative subset and add prompt variants.

The frozen broad capability study is exposed directly to this runner without
copying its manifest or fabricating extra prompt variants. Its paper grid is 13
families x 5 conditions x 3 repetitions. Each cell attempts the full broad
execution funnel and records the maximum stage reached:

```bash
python3 -m nl2robotics.experiments.run_cli \
  --benchmark-manifest nl2robotics/studies/capability_manifest.json \
  --profile capability --variant rich \
  --condition B0 --condition B1 --condition B2 --condition B3 --condition FULL \
  --repetitions 3 --output-dir outputs/capability-paper-v1 --dry-run
```

Remove `--dry-run` only after inspecting a small selected slice. B1 through FULL
use the frozen family-preferred RAG routes; B0 remains direct generation.
Capability `FULL` also executes both semantic-alignment stages; B3 and FULL are
therefore behaviorally distinct rather than label-only variants. Integrated FMU
execution is reported separately from strict Newton H2 execution. In the two
tool-repair conditions, FMU export, interface, initialization, execution, or
trace-survival failures may trigger the frozen bounded runtime-repair loop.
Each candidate must preserve the top-level model identity, recompile, retain
the required FMU interface, advance farther through real execution, and (for
FULL) pass pre-execution alignment again. Deterministically evaluated behavioral
violations may trigger the same bounded, monotonic repair loop. Qualitative
requirements without an implemented evaluator remain unevaluable experimental
outcomes and never trigger repair.
