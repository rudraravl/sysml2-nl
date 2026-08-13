# Modelica Robotics Profile

This package is the research-grade MVP for a second, independently functional
NL-to-formal-artifact domain. It targets robot plant dynamics and closed-loop
control. OpenUSD embodiment and USD+FMU coupling are complementary later
profiles and are not required for this pipeline to run.

## Frozen Layer 1

The active research pipeline currently ends at a buildable artifact:

1. Retrieve relevant, executable NL-to-Modelica examples.
2. Ask the same four experts used by the SysML pipeline for independent
   self-contained candidates.
3. Give the rated candidates to the same Claude combiner for one synthesis.
4. Run OpenModelica `checkModel` and `buildModel`; do not execute the artifact.
5. Repair with the combiner from grounded compiler diagnostics, up to two times.
6. Keep a repair only when build status, check status, or error count improves.

Layer 1 passes only when OpenModelica checks the model and produces a native
simulation executable. Compiler availability is mandatory: infrastructure
failure stops the sample and never triggers an LLM repair. Simulation, CSV
traces, and temporal properties belong to Layer 2 and do not affect Layer 1
acceptance. See `LAYER1_DESIGN.md` for the frozen contract and experiment.

The default `moe` mode deliberately copies the SysML generation design while
changing only the domain prompt, RAG corpus, and compiler backend. Its experts
are `openai/gpt-5.5`,
`anthropic/claude-sonnet-4.5`, `openai/gpt-5.4`, and
`meta-llama/llama-4-maverick`; `anthropic/claude-sonnet-4.5` is the combiner.
Individual expert failures are recorded and tolerated, while a combiner
failure stops the sample. The complete prompts, retrieved IDs, candidates,
ratings, diagnostics, and repair attempts are written to `report.json`.

The previous single-model generator remains available as `--mode single` for
controlled ablation experiments. It is not the default pipeline.

The Layer 1 quality tuple orders candidates by successful build, successful
model check, and fewer compiler errors. This lets partial repairs make measured
progress without allowing a later regression to replace the best candidate.

## Example Methodology

The retrieval corpus contains 100 team-authored, executable examples balanced
across ten capability families with ten examples each. The original 24 form a
frozen core tier; 76 expanded examples broaden the domain and difficulty:

- joint mechanics
- electric actuation and multi-domain dynamics
- feedback control
- coupled transmissions
- hybrid safety behavior
- mobile and aerial dynamics
- sensing and estimation
- fluid power
- trajectory generation
- multibody kinematics

Every manifest entry records its split, category, difficulty, tags,
requirement, provenance, corpus tier, archetype, simulation configuration, and behavioral property.
Every example is self-contained and has been checked, compiled, simulated, and
property-tested with OpenModelica 1.27.0.

Three explicit subsets support corpus-size ablations without relying on file
order: `core24`, `balanced50`, and `full100`. The 50- and 100-example subsets
are exactly balanced across all ten categories. Generation retrieves the top
five examples by default, matching the existing SysML pipeline's few-shot
count while keeping the candidate pool domain-specific.

The official OpenModelica image does not bundle the Modelica Standard Library.
On first use, the runner installs MSL 4.1.0 through OpenModelica's package
manager and stores it in a persistent cache. Set `OPENMODELICA_LIBRARY_CACHE`
to choose a cache directory; the default is under the system temporary folder.

`evaluation_tasks.json` contains ten code-free smoke-evaluation prompts, one
for each capability family. The
retriever reads only `split=rag` entries from `manifest.json`, so evaluation
tasks cannot be returned as few-shot examples. A paper-scale benchmark should
expand the evaluation set and freeze both sets before headline experiments.
`audit_corpus.py` rejects duplicate requirements, duplicate normalized code,
invalid subset membership, category imbalance, and RAG/evaluation ID overlap;
it also reports high-overlap pairs for review.

## Deferred Layer 2

The repository retains an experimental simulation and structured STL fragment:

- `always`: `G[a,b](lower <= signal <= upper)`
- `eventually`: `F[a,b](lower <= signal <= upper)`
- `final`: a terminal-value predicate used for concise endpoint requirements

Properties produce pass/fail and signed robustness. This code is not invoked by
Layer 1 generation or evaluation and will be hardened separately.

## Commands

For a clean-machine handoff, follow `LAYER1_QUICKSTART.md`. It includes the
no-cost preflight, one-task model smoke test, and resumable held-out experiment.

Retrieve examples:

```bash
python3 -m nl2robotics.modelica.cli retrieve \
  "DC motor driving a geared joint with position feedback" \
  --subset full100 -k 5
```

Check and build one candidate without executing it:

```bash
python3 -m nl2robotics.modelica.cli compile candidate.mo \
  --backend docker --output-dir results/build
```

Generate with the SysML-equivalent MoE, then check, build, and optionally repair:

```bash
python3 -m nl2robotics.modelica.cli generate \
  "Model a damped one-axis joint driven to one radian" \
  --mode moe --backend docker \
  --subset full100 -k 5 --output-dir results/run-001
```

`LLM_BACKEND=cli` uses Codex for GPT experts and Claude Code for Claude. The
Llama expert still uses OpenRouter, exactly as in the SysML MoE. With
`LLM_BACKEND=api`, all configured non-Gemini experts use OpenRouter.

Run the single-model ablation through one authenticated local CLI:

```bash
python3 -m nl2robotics.modelica.cli generate \
  "Model a damped one-axis joint driven to one radian" \
  --mode single --provider codex --model gpt-5.4 --backend docker \
  --subset full100 -k 5 --output-dir results/single-001
```

Run the held-out Layer 1 experiment. The conditions are direct single-model,
single-model RAG, and full RAG+MoE+compiler repair:

```bash
python3 -m nl2robotics.modelica.evaluate_layer1 \
  --conditions baseline rag full --llm-backend cli --backend docker \
  --output-dir results/layer1
```

The full condition records initial and final build success, so compiler-repair
gain is measured without generating a redundant second MoE sample.

Validate the complete retrieval corpus through the compile-only Layer 1 path:

```bash
python3 -m nl2robotics.modelica.validate_layer1 \
  --subset full100 --backend docker --output-dir modelica-layer1-validation
```

Audit corpus composition and duplication:

```bash
python3 -m nl2robotics.modelica.audit_corpus
```

The separate `cli run` and `validate_examples` commands still exercise the
experimental simulation/property code, but they are outside the frozen Layer 1
experiment.

## Reproducibility Boundary

Layer 1 fixes the corpus subset, retrieval count, expert and combiner IDs,
ratings, maximum repairs, OpenModelica image, Modelica Standard Library version,
and build command. Reports retain prompts, retrieved IDs, every expert output,
compiler diagnostics, candidate history, and acceptance decisions.

This MVP does not claim geometry, contact-rich simulation, perception, motion
planning, OpenUSD execution, or FMU-to-USD coupling. The frozen Layer 1 claim is
NL-to-compiler-checked, natively buildable Modelica for robotics dynamics and
control.
