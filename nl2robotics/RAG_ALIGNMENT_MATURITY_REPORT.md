# Robotics RAG and Semantic Alignment Maturity Report

Date: 2026-08-18

## Scope

This pass replaces prototype-scale retrieval and broad LLM mismatch judgments
with reviewable corpora, lineage-aware retrieval, structured evidence, and
perturbation-tested semantic checks. It does not claim Isaac H2 execution;
that remains gated on the external GPU runtime.

## RAG corpus

The legacy SysML retriever scans up to 300 NL/code pairs from a larger local
pool. Each robotics profile now exposes the same 300-pair retrieval scale:

| Profile | Retrieval pairs | Unique executable artifacts | Families | Balance |
| --- | ---: | ---: | ---: | ---: |
| Modelica | 300 | 100 | 10 | 30 pairs/family |
| OpenUSD | 300 | 100 | 10 | 30 pairs/family |

Each executable semantic case has three NL formulations. Manifest fields
`semantic_case_id`, `lineage_id`, and `variant_type` make this relationship
explicit. Modelica has 100 distinct executable models, including three
controller-only FMI interface cases with typed observation inputs, effort
outputs, saturation, and unit conversion. OpenUSD has 20 base
embodiment archetypes expanded into 100 distinct, validated sampling-rate
scenarios. This is intentionally reported as 100 semantic stages, not as 100
independent robot mechanisms.

The shared BM25 retriever normalizes common robotics terms and units and allows
only one result per semantic case and lineage. A frozen 40-query evaluation
currently reports:

- Modelica top-1 family accuracy: 100%; recall@5: 100%.
- OpenUSD top-1 family accuracy: 95%; recall@5: 100%.
- Unique semantic cases in every top-five result: 100%.

The frozen subset ablation separates semantic coverage from raw pair count.
Modelica top-1 accuracy rises from 35% (`core24`) to 80% (`balanced50`) and
100% (`full100`); the two paraphrase variants preserve 100% at `full300`.
OpenUSD remains at 95% top-1 and 100% recall@5 for `core20`, `semantic100`,
and `full300`. Thus the OpenUSD expansion adds controlled parameter and wording
coverage, but this family-level evaluation does not establish a quality gain
from those extra pairs.

All 100 Modelica artifacts passed OpenModelica compilation, FMI execution, and
their temporal properties. All 100 OpenUSD artifacts passed the pinned OpenUSD
parser and robotics-semantic validator.

The audit also removed a semantic near-leak between the first OpenUSD retrieval
case and RHY101: the retrieval case had reused the oracle's distinctive mass,
axis, limits, and target despite having a different file hash. It is now a
separate 1.5 kg X-axis effort-controlled articulation with different limits and
no authored drive. The H2 query still retrieves it first because of relevant
execution semantics, not because it duplicates the evaluation task.

## Semantic alignment

The versioned `alignment/bank.json` defines 17 question families, weights,
evidence authorities, and repair owners. Questions are instantiated only from
facts with exact NL evidence. Unstated facts become unknowns and never lower
the semantic score.

Deterministic evidence now covers:

- timing and cross-profile units;
- entity presence, mass, and collision dimensions;
- joint type, topology, axis, and limits;
- FMU parameter values and unit conversion;
- dynamics ownership and controller input/output presence;
- actuator and sensor mappings;
- gravity settings;
- FMI/OpenUSD interface bindings; and
- executed temporal properties.

Controller-law classification is now deterministic: seven active FMU probes
test equilibrium, signed position response, signed velocity damping, and both
saturation limits. LLM-only answers remain diagnostic and cannot block
acceptance or trigger repair.

The RHY101 preparation answers 20 of 22 questions deterministically with only
its two runtime properties pending (87.7551% weighted evidence coverage). Once
runtime-property evidence is attached, it answers all 22 questions with 100%
coverage and zero violations. The portable RHY003 run answers all 15 questions
deterministically (100% coverage). The geometry
adapter found a genuine half-scale RHY101 link defect that the previous bank
missed; the oracle and immutable GPU bundle were corrected and revalidated.

Perturbation tests independently alter timing, mass, geometry, joint axis,
joint limits, FMU parameters, ownership, interface units, gravity, controller
causality, sensor placement, and runtime properties. Each mutation is detected
by its intended question family, while LLM-only findings remain non-blocking.

## Reproducible evidence

- `outputs/modelica-semantic100-validation-20260818/summary.json`
- `outputs/openusd-semantic100-validation-20260818/summary.json`
- `outputs/robotics-rag-retrieval-eval-20260818.json`
- `outputs/RHY003-authoritative-orchestrator-20260818/result.json`
- `outputs/RHY101-reference-v2/alignment.json`
- `outputs/RHY101-isaac-input-v3/execution-input.json`

## Remaining research limits

The retrieval evaluation measures in-domain family recall, not generated-model
quality. The 300-pair versus 100-semantic-case distinction must remain explicit
in the paper. The five current hybrid benchmark tasks instantiate 15 of 17 bank
families; sensor families are unit-tested but still need a held-out benchmark
task. Generated-output ablations and the three-run Isaac H2 experiment are
still required before making comparative or simulator-backed claims.
