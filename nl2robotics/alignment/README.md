# Robotics Semantic Alignment

This stage compares grounded natural-language requirements against Modelica,
OpenUSD, cross-profile contract, and runtime evidence.

## Method

1. Validate the requirement IR and its exact source excerpts.
2. Instantiate concrete questions only for stated facts.
3. Mark every grounded NL-side answer as required.
4. Answer with compiler, FMU, USD, contract, and property evidence first.
5. Optionally ask a twin-blind LLM judge only about residual artifact facts.
6. Score `satisfied`, `violated`, `unknown`, or `not_applicable`.
7. Exclude unknowns from the semantic score and report evidence coverage
   separately.

`bank.json` is the versioned review surface for 17 question families, weights,
evidence authorities, and repair owners. The runtime instantiates a focused
subset from the grounded IR; it never asks the entire bank or converts an
unstated fact into a mismatch. Deterministic adapters cover timing, body mass
and collision dimensions, joint topology/axis/limits, FMU parameter values and
units, dynamics ownership, controller interfaces, actuator mappings, sensors,
gravity, cross-profile interfaces, and executed temporal properties. Exact
controller-law classification remains an optional non-blocking artifact-text
judgment.

An LLM-only mismatch is diagnostic. It cannot block acceptance or trigger
repair. Only a deterministic violation can block, and the repair plan routes it
to its declared owner. Automatic repair is allowed only when exactly one
Modelica or OpenUSD owner has grounded defects. The candidate then reruns
profile validation, FMU export, contract checks, execution, properties, and
alignment, and replaces the baseline only on strict monotonic improvement with
no previously passed stage regressing. Cross-profile and runtime-only failures
remain diagnostic.

The authoritative orchestrator writes `alignment.json` after hybrid execution.
Archived evidence can be reevaluated without generation using
`python3 -m nl2robotics.alignment.cli`.
Use `--alignment-mode deterministic` to run without judge calls, or the default
`hybrid` mode to add the residual LLM evidence pass.
`--max-semantic-repairs 0` disables the guarded repair attempt; the default is
one attempt.

Run the frozen retrieval and corpus-size evaluation with:

```bash
python3 -m nl2robotics.retrieval_eval \
  --output outputs/robotics-rag-retrieval-eval.json
```
