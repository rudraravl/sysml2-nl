# Unified Robotics Orchestrator

This package turns one natural-language robotics request into a reproducible
Modelica behavioral execution bundle. Legacy H1/H2 utilities remain available
for archived auxiliary studies:

1. one constrained LLM call extracts a shared requirement IR;
2. exact source excerpts are checked for every normalized fact;
3. deterministic code freezes names, units, ownership, mappings, and time;
4. the paper-facing RAG/MoE profile generates and natively compiles Modelica;
5. the paper-facing route exports an FMI 2.0 Co-Simulation FMU, verifies model
   identity plus grounded output/parameter values and units, executes it, checks
   its finite trace, evaluates external property monitors, and aligns the
   Modelica artifact with the grounded specification; the legacy portable H1
   runtime exports and executes the FMU, validates the real
   cross-profile contract, authors and independently verifies USD playback, and
   evaluates trace properties; or
6. the H2 path exports a controller FMU, validates a dynamic effort-controlled
   OpenUSD articulation and bidirectional contract, and freezes a hash-checked
   bundle for the Newton Physics or Isaac Sim execution handoff.

Unknown timing or interface facts stop before generation. The planner does not
invent values to make an underspecified request executable.

```bash
python3 -m nl2robotics.orchestrator.cli \
  --request request.txt \
  --output-dir outputs/robotics-run \
  --execution-mode modelica_capability \
  --mode moe \
  --backend docker
```

For the articulated Isaac/PhysX profile, add:

```bash
  --execution-mode isaac_closed_loop
```

For the open-source Newton Physics profile, use
`--execution-mode newton_closed_loop` instead.

An H2 preparation exits successfully with `ready_for_gpu=true`, while
`passed=false` and `failure_stage=gpu_execution_pending` remain until the real
three-run Isaac evidence gate completes. Preparation is never reported as an
executed H2 result.

Use `--mode single --model gpt-5.4 --provider codex` for a lower-cost smoke run.
Success means both source artifacts passed their validators and the complete H1
bundle passed; syntax-only success is never promoted to end-to-end success.

The default `modelica_capability` route covers broad robotics requests without
forcing them into the articulated H2 subset:

```bash
python3 -m nl2robotics.orchestrator.cli \
  --request request.txt --output-dir outputs/broad-run \
  --execution-mode modelica_capability --subset full1500
```

This path accepts mobile/floating, aerial, legged, marine, sensing, contact,
trajectory, multi-DOF, closed-chain, fluid-power, electromechanical, and soft
robotics requirements. It validates one Modelica artifact, executes its
integrated behavior as a real FMU, evaluates the runtime trace, and writes a
Modelica/specification report plus a stage trace. OpenUSD is not generated or
validated on this paper-facing route, and broad FMU execution is never reported
as Newton, PhysX, CUDA, or GPU evidence.

Checked local profile smoke tests are available without model calls:

```bash
python3 -m nl2robotics.orchestrator.oracle_smoke RHY001 \
  --output-dir outputs/RHY001-smoke --backend docker
python3 -m nl2robotics.orchestrator.oracle_smoke RHY101 \
  --output-dir outputs/RHY101-preparation-smoke --backend docker
python3 -m nl2robotics.orchestrator.oracle_smoke RHY202 \
  --output-dir outputs/RHY202-preparation-smoke --backend docker
python3 -m nl2robotics.orchestrator.oracle_smoke RHY203 \
  --output-dir outputs/RHY203-preparation-smoke --backend docker
```
