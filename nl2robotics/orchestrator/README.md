# Unified Robotics Orchestrator

This package turns one natural-language robotics request into a reproducible H1
execution bundle or an H2 GPU-ready execution bundle:

1. one constrained LLM call extracts a shared requirement IR;
2. exact source excerpts are checked for every normalized fact;
3. deterministic code freezes names, paths, units, ownership, mappings, and time;
4. the existing RAG/MoE profiles generate and validate Modelica and OpenUSD;
5. the portable H1 runtime exports and executes the FMU, validates the real
   cross-profile contract, authors and independently verifies USD playback, and
   evaluates trace properties; or
6. the H2 path exports a controller FMU, validates a dynamic effort-controlled
   OpenUSD articulation and bidirectional contract, and freezes a hash-checked
   bundle for the Isaac Sim handoff.

Unknown timing or interface facts stop before generation. The planner does not
invent values to make an underspecified request executable.

```bash
python3 -m nl2robotics.orchestrator.cli \
  --request request.txt \
  --output-dir outputs/robotics-run \
  --mode moe \
  --backend docker
```

For the implemented one-DOF Isaac profile, add:

```bash
  --execution-mode isaac_closed_loop
```

An H2 preparation exits successfully with `ready_for_gpu=true`, while
`passed=false` and `failure_stage=gpu_execution_pending` remain until the real
three-run Isaac evidence gate completes. Preparation is never reported as an
executed H2 result.

Use `--mode single --model gpt-5.4 --provider codex` for a lower-cost smoke run.
Success means both source artifacts passed their validators and the complete H1
bundle passed; syntax-only success is never promoted to end-to-end success.

Checked local profile smoke tests are available without model calls:

```bash
python3 -m nl2robotics.orchestrator.oracle_smoke RHY001 \
  --output-dir outputs/RHY001-smoke --backend docker
python3 -m nl2robotics.orchestrator.oracle_smoke RHY101 \
  --output-dir outputs/RHY101-preparation-smoke --backend docker
```
