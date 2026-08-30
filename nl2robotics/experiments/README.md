# Robotics Ablations

The five frozen stagewise conditions are:

| ID | Condition | RAG | MoE | Tool repair | Alignment | Contract |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| B0 | Direct frontier | no | no | no | no | no |
| B1 | RAG | yes | no | no | no | no |
| B2 | RAG + MoE | yes | yes | no | no | no |
| B3 | Tool-grounded | yes | yes | yes | no | yes |
| FULL | Complete pipeline | yes | yes | yes | yes | yes |

`AblationRunner` blocks by task and repetition, then randomizes condition order
within each block using the recorded `--randomization-seed`. One normalized and
validated requirement IR is persisted per block and reused by every paired
condition. Every eligible cell has a configuration fingerprint and independent
`run.json`; interrupted experiments resume without mixing model settings,
prompts, normalization, or run order.

Before either a dry run or a real run, `study-protocol.json` freezes the Git
state, prompt and manifest hashes, full Modelica/OpenUSD corpus tree hashes,
condition definitions, model roster, runtime/validator provenance, exclusion
rules, randomized order, and exact cell fingerprints. Reusing that output
directory with different frozen inputs fails closed.

The concrete executor maps each condition to the real Modelica, OpenUSD, H1,
or H2 preparation path. Run a small frozen slice with:

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
limits stop the batch without writing a false failed cell. Summarize archived
runs with:

```bash
python3 -m nl2robotics.experiments.cli outputs/robotics-ablations \
  --pair B0 FULL --metric end_to_end \
  --output outputs/robotics-ablations/summary.json
```

Do not launch the full 15 x 5 x 3 grid first. Start with one rich-prompt repeat,
inspect failures, then repeat a representative subset and add prompt variants.

The frozen broad capability study is exposed directly to this runner without
copying its manifest or fabricating extra prompt variants. Its paper grid is 13
families x 5 conditions x 3 repetitions and remains capped at capability tier 2:

```bash
python3 -m nl2robotics.experiments.run_cli \
  --benchmark-manifest nl2robotics/studies/capability_manifest.json \
  --profile capability --variant rich \
  --condition B0 --condition B1 --condition B2 --condition B3 --condition FULL \
  --repetitions 3 --output-dir outputs/capability-paper-v1 --dry-run
```

Remove `--dry-run` only after inspecting a small selected slice. B1 through FULL
use the frozen family-preferred RAG routes; B0 remains direct generation.
Capability `FULL` also executes the artifact-alignment stage; B3 and FULL are
therefore behaviorally distinct rather than label-only variants.
