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
