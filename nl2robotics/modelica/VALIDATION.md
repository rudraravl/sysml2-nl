# Validation Record

Date: 2026-08-13

- Backend: official `openmodelica/openmodelica:v1.27.0-ompython` Docker image
- Modelica Standard Library: 4.1.0
- Solver: DASSL
- Host: Apple Silicon macOS through Docker Desktop
- Corpus entries: 100 across 10 balanced capability families
- Corpus tiers: 24 core, 76 expanded
- Ablation subsets: 24, 50, and 100 examples
- Code-free smoke evaluation tasks: 10, one per capability family
- Compile-only Layer 1 checks and native builds passed: 100/100
- Compile-only Layer 1 corpus runtime: 217.338 seconds
- Compile-only path confirmed to contain no `simulate` call
- Broken-model diagnostic test: unresolved variable correctly reported
- OpenModelica simulation checks passed: 100/100
- Native compilation and simulation passed: 100/100
- Declared trace properties passed: 100/100
- Compiler diagnostics: 0
- Modelica-profile Python unit tests: 17/17
- MoE parity tests: 4/4
- Full repository Python tests: 55/55
- Deterministic MoE-to-OpenModelica integration: passed
- Integration backend stages: check, compile, simulate, and trace property passed
- Total corpus runtime after setup: 202.108 seconds
- Median runtime per example: 2.010 seconds
- Maximum runtime for one example: 2.348 seconds
- Duplicate requirements: 0
- Duplicate normalized Modelica artifacts: 0
- RAG/evaluation ID overlap: 0
- High-overlap pairs reported for review: 7 of 4,950 possible pairs

Reproduction command:

```bash
python3 -m nl2robotics.modelica.validate_layer1 \
  --subset semantic500 --backend docker --output-dir modelica-layer1-validation
```

The generated compiler artifacts are intentionally not tracked. The validator
writes a machine-readable `summary.json` into the selected output directory.
