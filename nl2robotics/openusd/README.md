# OpenUSD Robotics Profile

This profile generates portable textual OpenUSD stages using `UsdPhysics` core
schemas. It includes a balanced 300-pair retrieval corpus, the same rated MoE
used by the SysML and Modelica profiles, strict `usdchecker` validation, a
pinned OpenUSD 26.8 semantic validator, and bounded guarded repair.

## Setup

Build the semantic runtime once. The explicit platform is required on Apple
Silicon because the official Linux Python wheel is x86_64:

```bash
docker build --platform linux/amd64 \
  -t nl2robotics-openusd-runtime:0.1 \
  nl2robotics/openusd/runtime
```

## Commands

Retrieve focused examples:

```bash
python3 -m nl2robotics.openusd.cli retrieve \
  "two-link arm with revolute shoulder and elbow" -k 5
```

Validate one stage:

```bash
python3 -m nl2robotics.openusd.cli validate scene.usda \
  --output-dir results/openusd-validation
```

Validate all 100 unique semantic stages (the 300 retrieval pairs reuse these
artifacts through explicit lineage metadata):

```bash
python3 -m nl2robotics.openusd.validate_corpus \
  --output-dir results/openusd-semantic100
```

Generate through RAG, rated MoE synthesis, and grounded repair:

```bash
python3 -m nl2robotics.openusd.cli generate \
  "Create a two-link robot arm with collision geometry and limited revolute joints" \
  --mode moe -k 5 --max-repairs 2 \
  --output-dir results/openusd-generation
```

Core validity means the stage passes strict USD compliance and the profile's
robotics-semantic checks. It does not imply execution in a physics engine.
Isaac/PhysX loading and simulation are separate named extension stages.

The corpus exposes `core20`, `semantic100`, and `full300` subsets. Retrieval is
lineage-aware, so alternate phrasings and controlled sampling-rate variants of
one archetype cannot occupy the complete few-shot context.
