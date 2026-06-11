# SysML Execution Harness Work Summary

## Overview

My assigned task was to finish setting up the SysML Jupyter kernel execution pipeline, determine how input parameters and simulation vectors could be supplied, run example models through the kernel, and record the resulting outputs.

The original goal was to test generated SysML models using automatically generated harnesses and simulation vectors. During implementation and testing, I confirmed that the current OMG SysML Jupyter kernel primarily provides parsing, semantic loading, and compilation validation. It accepts input assignments inside generated action harnesses, but it does not normally emit action execution traces, state-machine traces, constraint pass/fail results, or simulated outputs.

Because of this limitation, I changed the pipeline so it accurately records the strongest level of verification actually demonstrated instead of incorrectly calling successful compilation a behavioral simulation.

## Repository and Branch

- Repository: `CreatixChu/sysml2-nl`
- Branch: `input-vector-fallback`
- Branch pushed to GitHub.

Commits:

- `187e1bdd` — Add preset fallback simulation vectors
- `a4de9fe2` — Add resumable SysML corpus execution runner
- `08cede74` — Improve SysML corpus execution reporting

## Local Kernel Setup

I installed and configured the SysML Jupyter kernel locally. A GPU is not required because the kernel execution work is CPU-based parsing and semantic validation.

Local tools were installed outside the repository under a private tools directory:

- Miniforge: `<TOOLS_ROOT>/miniforge3`
- SysML Python environment: `<TOOLS_ROOT>/sysml-env`
- Java runtime: `<TOOLS_ROOT>/sysml-env/lib/jvm`
- Jupyter configuration: `<TOOLS_ROOT>/jupyter`

The kernel was successfully tested through `jupyter_client` using headless kernel sessions.

## Input Vector Investigation

The corpus does not provide known-valid simulation vectors for every model. Some action inputs, such as `fuelCmd` in model `000200`, exist without engineering bounds or documented valid values.

The agreed temporary approach was:

1. Detect required action input pins.
2. Try a bounded list of preset values.
3. Stop after the first value accepted by the kernel.
4. Clearly report that kernel acceptance does not establish engineering validity.

For future generated models, the recommended approach is to have the model-generating AI also generate:

- Input vectors
- Input types
- Units
- Bounds
- Assumptions
- Justification
- Expected outputs and tolerances

## Implemented Vector Behavior

The vector fallback system now:

- Detects required action inputs.
- Extracts input types from action definitions and usages.
- Tries type-aware scalar presets.
- Stops after the first kernel-accepted preset.
- Records every attempted vector.
- Records the selected vector.
- Labels preset semantic validity as `unknown`.
- Does not inject scalar values into structured or untyped inputs.

Examples:

- `fuelCmd` can receive scalar preset values.
- `Boolean` inputs receive Boolean presets.
- `String` inputs receive string presets.
- `Natural` inputs avoid negative presets.
- Structured inputs such as `CartInput` are marked `inputs_detected_but_not_constructible`.
- Untyped inputs are also marked non-constructible instead of receiving fake scalar values.

Important limitation: vector injection proves only that the model plus harness compiled with the assigned values. It does not prove the behavior executed or that the values are valid engineering inputs.

## Extraction Improvements

I improved the regex-based SysML extractor so the harness can identify more useful model structure:

- Action definitions
- Typed action usages
- Direct action input/output pins
- Input types
- Parts and part definitions
- Structural attributes
- State machines
- Accept triggers
- Constraints
- Imports

I also fixed extraction issues that caused incorrect vectors:

- Nested calculation inputs are no longer mistaken for direct action inputs.
- Pins declared on later nested actions are no longer absorbed into earlier actions.
- Quoted action and attribute names are handled.
- Candidate imports are reproduced in generated harnesses so imported action types resolve correctly.

## Harness Improvements

Every model receives the strongest available harness:

- Action models receive action input probes.
- Models with multiple action targets have each relevant target tested separately.
- Structural models receive typed structural part probes.
- State-machine models receive structural/state inventory reporting.
- Analysis-tool models are identified without pretending the external tool executed.

The harness does not pretend that all models accept vectors. Structural models generally do not have externally injectable action inputs, and the current kernel does not expose general state-machine event injection.

## Honest Verification Levels

The pipeline now separates four verification levels:

| Verification Level | Meaning |
|---|---|
| `syntax_compiled` | The untouched model compiled in the kernel |
| `structural_harness_compiled` | The model plus generated structural harness compiled |
| `input_harness_compiled` | The model plus harness compiled with injected values |
| `behavior_observed` | The kernel emitted an explicit action, state, or constraint result |

Successful harness compilation is no longer reported as behavioral verification.

If input values were injected but the kernel emitted no runtime trace, the result is recorded as:

- `verification_level=input_harness_compiled`
- `behavior_observed=false`
- `diagnostic_error_type=behavior_not_observed`

## Baseline Compilation

The corpus runner now compiles each untouched model separately before adding the harness.

This allows the results to distinguish:

- A model that was already invalid.
- A model that compiled until the harness was added.
- A model and harness that both compiled.

The audit reports `harness_regressions` when the original model compiles but the generated harness does not.

## Corpus Runner

I implemented a resumable schema-v3 corpus runner.

For each model, it:

1. Compiles the untouched model.
2. Extracts the model topology.
3. Finds action targets with required inputs.
4. Runs each action target independently.
5. Attempts type-aware preset vectors when possible.
6. Runs a structural/state harness when no injectable action target exists.
7. Saves full raw kernel outputs and summarized results.
8. Updates CSV, JSON, and audit outputs after every completed model.
9. Resumes completed schema-v3 models after interruption.

## Output Files

The final run writes to:

`results/sysml_execution_corpus_v3/`

Generated outputs:

- `summary.csv` — one row per model
- `targets.csv` — one row per tested action target
- `summary.json` — model-level summary data
- `targets.json` — action-target summary data
- `audit.json` — experiment-wide totals
- `<model_id>.json` — complete baseline, harness, target, vector, and raw kernel outputs
- `run.log` — live execution log

Generated corpus results are ignored by Git.
Model paths are stored as repository-relative paths, and local home/repository/tool paths are
redacted from `run.log`, so shared result files do not expose personal workspace paths.

## One-Command Execution

From the repository root, run or resume the full corpus with:

```bash
./nl2sysml/sysml_execution/run_corpus.sh
```

Run a smaller pilot:

```bash
./nl2sysml/sysml_execution/run_corpus.sh --limit 20
```

Monitor progress:

```bash
tail -f results/sysml_execution_corpus_v3/run.log
```

Open the model-level CSV:

```bash
open -a Numbers results/sysml_execution_corpus_v3/summary.csv
```

Open the action-target CSV:

```bash
open -a Numbers results/sysml_execution_corpus_v3/targets.csv
```

## Testing and Validation

Automated validation:

- `26` tests pass.
- `2` kernel-dependent tests are optional/skipped when the kernel is unavailable.
- Python compilation succeeds.
- Shell launch-script syntax succeeds.
- Git diff validation succeeds.

Real-kernel validation:

- Four-model representative smoke set:
  - `000002` — scalar/quantity multi-input actions
  - `000003` — structural-only model
  - `000082` — structured and untyped action inputs
  - `000200` — `fuelCmd` scalar fallback
- Twenty-model golden-set corpus run completed.
- Final real-kernel test of `000200` completed.

Four-model schema-v3 smoke results:

- All four original models compiled.
- All four generated harnesses compiled.
- Two models received injected input vectors.
- Seven action targets received injected vectors.
- Zero behavioral executions were observed.

Twenty-model golden-set results:

- Models completed: `20`
- Original models compiling: `16`
- Harnesses compiling: `15`
- Models with input injection: `2`
- Action targets with input injection: `3`
- Behaviors observed: `0`

These results confirm that the runner accurately distinguishes compilation, vector injection, and actual behavioral observation.

## Confirmed Kernel Capabilities

The current kernel successfully supports:

- Parsing and loading SysML models.
- Detecting syntax and semantic errors.
- Compiling a model with an appended harness.
- Resolving imported definitions when imports are reproduced.
- Accepting `perform action` harness syntax.
- Accepting input assignments such as `in fuelCmd = 0;`.
- Recording raw kernel messages and diagnostics.

## Kernel Capabilities Not Observed

The current headless kernel did not demonstrate:

- Actual action execution traces.
- State-machine advancement.
- State transition traces.
- Event injection for `accept` actions.
- Runtime item-flow propagation.
- Constraint pass/fail evaluation.
- Simulated outputs.

Therefore, the current pipeline should be described as a compilation, structural reachability, and input-injection experiment—not a general SysML behavioral simulator.

## Main Findings

1. Every model can receive a harness, but not every model has meaningful vector-injectable inputs.
2. Structural models can be structurally compiled and probed without simulation vectors.
3. Scalar action inputs can receive preset vectors.
4. Structured inputs require model-specific object construction and cannot safely receive scalar presets.
5. Untyped inputs cannot be safely populated automatically.
6. Kernel acceptance does not prove that a vector is a valid engineering value.
7. The current Jupyter kernel does not provide observable general-purpose behavioral simulation.
8. Baseline model compilation must be separated from harness compilation.
9. Results must explicitly separate input injection from behavioral observation.

## Recommended Next Steps

1. Run the complete schema-v3 corpus and retain the generated result directory.
2. Report compilation, harness, input-injection, and behavior-observation metrics separately.
3. Explore the SysML v2 API Cookbook/API Services for structured model querying.
4. Determine whether the API exposes runtime state advancement or event injection.
5. If true behavioral simulation is required, identify a separate execution/simulation engine.
6. Require future model-generating AI systems to emit explicit test contracts and valid vectors.

## Files Changed

Primary implementation files:

- `nl2sysml/sysml_execution/corpus_runner.py`
- `nl2sysml/sysml_execution/extractor.py`
- `nl2sysml/sysml_execution/harness_builder.py`
- `nl2sysml/sysml_execution/models.py`
- `nl2sysml/sysml_execution/orchestrator.py`
- `nl2sysml/sysml_execution/vector_fallback.py`
- `nl2sysml/sysml_execution/sysml_runtime_bridge.py`
- `nl2sysml/sysml_execution/run_corpus.sh`
- `nl2sysml/sysml_execution/test_execution.py`
- `nl2sysml/sysml_execution/KERNEL_CAPABILITIES.md`
- `.gitignore`

## Short Progress Report

I completed the local SysML Jupyter kernel setup and built a resumable corpus execution pipeline. The system now compiles each original model separately, generates the strongest available harness, injects type-aware preset vectors where possible, records complete kernel outputs, and produces model-level, target-level, and audit reports. Testing showed that the current kernel accepts input assignments and validates model/harness compilation but does not expose general behavioral simulation traces. The pipeline now reports that limitation honestly and is ready for the full corpus run.
