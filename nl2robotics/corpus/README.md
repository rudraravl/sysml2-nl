# Robotics pipeline input corpus

This directory contains the natural-language requests intended to be sent into
the robotics pipeline. It is separate from both the retrieval examples used by
RAG and the held-out paper evaluation set.

`pipeline_prompt_manifest.json` contains 1,560 grounded NL inputs, balanced as
120 inputs in each of 13 robotics families. The design is systematic:

- 5 embodiments per family;
- 4 compatible missions per embodiment;
- 20 semantic scenarios per family and 260 overall; and
- 6 controlled operating configurations per semantic scenario.

The six configurations vary control rate, duration, actuator bound,
disturbance, acceptance tolerance, difficulty, and NL presentation style.
Every row records `semantic_case_id`, `lineage_id`, and
`configuration_variant`. Only the 260 semantic scenarios are independent;
the 1,560 configurations must not be reported as 1,560 independent robots.

The six balanced NL styles are plant-first, scenario-first, control-first,
sensing-first, verification-first, and integration brief. Regardless of style,
every prompt identifies the embodiment, actuation, task, sensing, environment,
controller, disturbance, timing, observable requirements, and unknown-fact
policy. Prompts range from roughly 150 to 190 words.

Regenerate and audit the corpus deterministically:

```bash
python3 -m nl2robotics.corpus.pipeline_prompts --write
```

The audit checks exact reproducibility, IDs, uniqueness, family and difficulty
balance, six-member lineages, profile routing, minimum grounding, and leakage
against the 65 held-out evaluation prompts, 13 development prompts, and all
3,000 retrieval entries.

Preview one input without making model calls:

```bash
python3 -m nl2robotics.experiments.run_cli \
  --benchmark-manifest nl2robotics/corpus/pipeline_prompt_manifest.json \
  --profile capability --family aerial_robotics \
  --semantic-case-id RPS001 \
  --configuration-variant controlled_config_1 \
  --condition FULL --repetitions 1 \
  --output-dir outputs/robotics-corpus-v1 --dry-run
```

Omit the filters only when intentionally processing the full 1,560-input
catalog. Materializing this file does not mean the prompts have already been
sent to a model or that their Modelica/OpenUSD outputs have passed validation.
Those outcomes belong in the generated corpus produced by actual pipeline runs.

The full corpus now requires the complete broad execution funnel: artifact
validation, pre-execution semantic alignment, FMU export and execution, finite
trace validation, external behavior evaluation, and post-execution semantic
alignment. It does not claim Newton execution and does not require a GPU. Every
failure stage remains an experimental outcome. The runner randomizes task order
with the frozen seed and preflights OpenModelica plus the FMI runtime before any
model calls. For concurrent workers, first freeze and inspect one shared plan:

```bash
python3 -m nl2robotics.experiments.run_cli \
  --benchmark-manifest nl2robotics/corpus/pipeline_prompt_manifest.json \
  --profile capability --benchmark-split all --condition FULL --variant rich \
  --repetitions 1 --randomization-seed 20260830 --model gpt-5.4 \
  --modelica-backend docker --modelica-subset full1500 \
  --shard-count 4 --output-dir outputs/robotics-corpus-full-v1 --dry-run
```

Then launch shard indices `0` through `3` with that exact command, remove
`--dry-run`, and add the matching `--shard-index`. Shards share the frozen
protocol and write disjoint cell directories plus separate run-control and
summary files. Aggregate all completed records from the shared output root with
`python3 -m nl2robotics.experiments.cli outputs/robotics-corpus-full-v1`.
