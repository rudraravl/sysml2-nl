# Robotics Development Benchmark

The frozen development set contains 15 tasks:

- 5 Modelica/FMI tasks;
- 5 OpenUSD/UsdPhysics tasks; and
- 5 hybrid tasks, including four portable H1 cases and one Isaac H2 case.

Every task has rich, concise, and deliberately underspecified prompt variants,
for 45 prompt-task cells. Omitted facts are labeled as unknown and are not
treated as requirements. Oracle artifacts are stored outside both retrieval
corpora and checked by hash to prevent exact artifact leakage.

Validate all hardware-independent oracle levels:

```bash
python3 -m nl2robotics.benchmark.validate \
  --output-dir outputs/robotics-development-benchmark \
  --modelica-backend docker
```

This command compiles and simulates the five Modelica oracles, evaluates their
properties, semantically validates five held-out USDA stages, executes four
portable hybrid bundles, and prepares the H2 bundle. It does not claim H2
execution until the prepared bundle runs in real Isaac Sim.

This is a development set, not the final paper benchmark. Freeze the pilot and
review annotations before expanding toward the planned 30-task pilot or
90-task final set.
