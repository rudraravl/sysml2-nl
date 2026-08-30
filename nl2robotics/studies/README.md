# Articulated robotics study suite

This suite measures the executable fixed-base articulated profile across
structurally different tasks instead of treating a single arm as evidence of
breadth. Its three checked oracles cover one-, two-, and three-joint systems;
single, serial, and branching topologies; revolute and prismatic joints; X, Y,
and Z axes; every supported primitive shape; and up to three simultaneous FMU
control channels.

Audit the manifest and its artifacts without spending model or GPU budget:

```bash
python3 -m nl2robotics.studies.articulated
```

Prepare the broadest checked oracle through real OpenModelica and OpenUSD:

```bash
python3 -m nl2robotics.orchestrator.oracle_smoke RHY203 \
  --output-dir outputs/RHY203-preparation --backend docker
```

Run a generated rich-prompt pilot through the full pipeline and Newton:

```bash
python3 -m nl2robotics.experiments.run_cli \
  --benchmark-manifest nl2robotics/studies/articulated_manifest.json \
  --profile hybrid --condition FULL --variant rich --repetitions 1 \
  --newton-handoff --newton-device cpu \
  --newton-controller-backend docker --newton-repetitions 3 \
  --output-dir outputs/articulated-full-pilot
```

After the pilot is inspected, add `B0`, `B1`, `B2`, and `B3`, repeat across
prompt variants, and use the existing seeded bootstrap and paired McNemar
summaries. On DeltaAI, use `cuda:0` and the local FMI runtime inside the pinned
Apptainer environment.

The current study boundary is fixed-base acyclic trees with independent
joint-space PD effort control. It does not relabel mobile bases, closed chains,
contact tasks, or operational-space controllers as if they had been executed.

The complementary broad capability matrix contains 13 paper-facing families
covering articulated, mobile, aerial, legged, marine, contact, trajectory,
closed-chain, sensing, fluid-power, electromechanical, soft, and multi-robot
requests. Audit its profile and evidence-tier coverage with:

```bash
python3 -m nl2robotics.studies.capability_matrix
```

The retrieval corpus and the held-out evaluation benchmark are deliberately
different objects. Retrieval has 1,500 Modelica prompts and 1,500 OpenUSD
prompts, each backed by 500 semantic cases. The candidate paper benchmark adds
65 independent, code-free requests: four primary cases and one reserve in each
of the 13 families. The original `RCB001`--`RCB013` cases are development-only
and excluded from confirmatory inference. Audit balance, grounding, profile
coverage, and exact/near leakage against all 3,000 retrieval prompts with:

```bash
python3 -m nl2robotics.studies.paper_evaluation
```

Its status remains `candidate_pending_mentor_approval`; after protocol review,
freeze the manifest and its reported SHA-256 before any confirmatory model call.
The experiment CLI defaults to the 52 primary cases for a split-aware manifest;
reserves are only selected explicitly. Preview the primary `B0` versus `FULL`
grid without making model calls:

```bash
python3 -m nl2robotics.experiments.run_cli \
  --benchmark-manifest nl2robotics/studies/paper_evaluation_manifest.json \
  --profile capability --condition B0 --condition FULL --repetitions 3 \
  --output-dir outputs/paper-evaluation-v1 --dry-run
```

This produces 312 planned cells. Use `--benchmark-split reserve` only for a
prespecified replacement; `--benchmark-split all` is descriptive, not the
default confirmatory design.

Each case is a numerical, source-grounded system specification rather than a
one-line category label. Execute the economical tier-2 breadth smoke locally
with the frozen full-1500 retrieval corpora and checkpoint after every family:

```bash
python3 -m nl2robotics.studies.run_capability_smoke \
  --output-dir outputs/capability-breadth-smoke \
  --model gpt-5.4 --provider codex --backend auto --subset full1500
```

The runner is resumable by a manifest-and-configuration fingerprint. Use
repeatable `--case-id RCB003` arguments to run or rerun a subset. Every case
retains the raw process log, complete orchestrator bundle, and a strict-JSON
case record; `summary.json` is rewritten after every completed case. A provider
usage limit stops the batch cleanly so the same command can resume later.

Audit every JSON document and accepted artifact, recompute hashes, revalidate
the normalized IRs, and build one fail-closed aggregate with:

```bash
python3 -m nl2robotics.studies.audit_capability_smoke \
  --run-dir outputs/capability-breadth-smoke \
  --output outputs/capability-breadth-smoke/evidence-audit.json
```

The breadth smoke intentionally uses unrestricted semantic retrieval over both
full-1500 corpora. The paper ablation uses each family's three-category route
for four of five hits and reserves one global hit for cross-domain transfer.
The smoke runner can exercise that policy explicitly with
`--rag-routing family-preferred`; the option changes its checkpoint fingerprint.

Audit and preview the exact 195-cell paper grid without making model calls:

```bash
python3 -m nl2robotics.experiments.run_cli \
  --benchmark-manifest nl2robotics/studies/capability_manifest.json \
  --profile capability --variant rich \
  --condition B0 --condition B1 --condition B2 --condition B3 --condition FULL \
  --repetitions 3 --model gpt-5.4 --provider codex \
  --modelica-backend auto --modelica-subset full1500 \
  --output-dir outputs/capability-paper-v1 --dry-run
```

Capability cells remain capped at tier 2. Dedicated profile runtimes, closed-loop
execution, and genuine accelerator provenance are required before any higher
tier or H2 claim; broad artifacts are never relabeled as runtime evidence.
