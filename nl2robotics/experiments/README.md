# Robotics Ablations

The five frozen stagewise conditions are:

| ID | Condition | RAG | MoE | Tool repair | Alignment | Contract |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| B0 | Direct frontier | no | no | no | no | no |
| B1 | RAG | yes | no | no | no | no |
| B2 | RAG + MoE | yes | yes | no | no | no |
| B3 | Tool-grounded | yes | yes | yes | no | yes |
| FULL | Complete pipeline | yes | yes | yes | yes | yes |

`AblationRunner` executes a supplied generation adapter in deterministic task,
condition, and repetition order. Every cell has a configuration fingerprint and
an independent `run.json`, so interrupted experiments resume without mixing
model settings or prompts.

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

The metric layer separates infrastructure failures from generated-artifact
failures, reports binary rates with seeded bootstrap confidence intervals,
continuous summaries, failure-stage distributions, and exact paired McNemar
tests. Summarize archived runs with:

```bash
python3 -m nl2robotics.experiments.cli outputs/robotics-ablations \
  --pair B0 FULL --metric end_to_end \
  --output outputs/robotics-ablations/summary.json
```

Do not launch the full 15 x 5 x 3 grid first. Start with one rich-prompt repeat,
inspect failures, then repeat a representative subset and add prompt variants.
