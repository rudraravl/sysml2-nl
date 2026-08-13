# Modelica Layer 1 Design

## Research Question

Can the existing NL-to-formal-artifact method improve the rate at which a
frontier model produces compiler-checked, natively buildable Modelica robotics
models?

## Frozen Boundary

Input: one natural-language robotics dynamics or control requirement.

Output: one self-contained Modelica artifact that passes OpenModelica
`checkModel` and `buildModel` under the pinned toolchain. `buildModel` generates
and compiles the native executable but does not run it.

Layer 1 includes:

1. BM25-style retrieval from a leakage-audited 100-example corpus.
2. Four independent experts using the SysML MoE model roster.
3. Reliability-rated synthesis by the SysML MoE combiner.
4. OpenModelica model checking and native build.
5. Up to two compiler-grounded repairs by the combiner.
6. Monotonic retention of the best candidate.

Layer 1 excludes simulation, trace generation, STL monitoring, spec-mismatch
scoring, FMU export, OpenUSD, and USD+FMU coupling.

## Acceptance and Repair

A candidate passes only if the compiler backend is available, `checkModel`
succeeds, `buildModel` succeeds, and the expected executable exists. The repair
quality tuple is:

```text
(built, checked, -compiler_error_count)
```

This gives full builds highest priority, then successful checks, then measurable
error reduction. A worse repair cannot replace the current best candidate.
Malformed output without a top-level model is converted to a source diagnostic
and can be repaired. Missing compiler infrastructure stops immediately and is
never presented to an LLM as a code defect.

## Held-Out Experiment

The ten smoke tasks in `evaluation_tasks.json` contain no reference code and
cannot enter retrieval. They cover one task from each capability family.

The evaluator runs three conditions:

| Condition | Single model | RAG | MoE | Compiler repair |
|---|---:|---:|---:|---:|
| `baseline` | yes | no | no | no |
| `rag` | yes | yes | no | no |
| `full` | no | yes | yes | up to 2 |

The full report records both its initial combined candidate and final retained
candidate. This exposes the pre-repair MoE build rate and the repair gain without
paying for another nondeterministic MoE generation.

Primary metric: final native-build success rate.

Supporting metrics: initial build rate, compiler-repair success count, repair
attempts, compiler time, expert soft failures, and per-category outcomes.

This ten-task split is a functional smoke benchmark, not enough for a headline
paper result. The paper experiment should freeze a larger held-out set before
running models and report uncertainty across tasks and repeated generations.
