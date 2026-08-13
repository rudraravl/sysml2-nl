# Modelica RAG Corpus Design

## Purpose

This corpus supplies executable few-shot examples for the standalone robotics
dynamics and control profile. It is a retrieval corpus, not the evaluation
benchmark. Its design favors semantic coverage, compiler validity, executable
behavior, explicit provenance, and controlled corpus-size experiments.

## Composition

The corpus contains 100 NL-to-Modelica pairs. Each of ten capability families
has exactly ten entries:

| Capability family | Count |
|---|---:|
| Joint mechanics | 10 |
| Electric actuation | 10 |
| Feedback control | 10 |
| Coupled transmissions | 10 |
| Hybrid safety | 10 |
| Mobile and aerial dynamics | 10 |
| Sensing and estimation | 10 |
| Fluid power | 10 |
| Trajectory generation | 10 |
| Multibody kinematics | 10 |

The 24-example `core` tier contains the initial hand-authored equations and
Modelica Standard Library compositions. The 76-example `expanded` tier adds
new mechanisms, controllers, domains, and difficulty levels. Every item has a
unique requirement and unique normalized Modelica artifact.

## Ablation Subsets

- `core24`: frozen original corpus; six represented families, four each.
- `balanced50`: five examples from every one of the ten families.
- `full100`: ten examples from every one of the ten families.

Subset membership is stored explicitly in `corpus_subsets.json`. It is not
computed by slicing directory order. The default retrieval setting is five
examples per prompt for direct comparability with the SysML pipeline.

## Validation Contract

Every pair must pass all of the following before inclusion:

1. Manifest and provenance audit.
2. OpenModelica model check.
3. Native code generation and compilation.
4. DASSL simulation under fixed settings.
5. At least one structured trace property.
6. Duplicate-code and evaluation-isolation audit.

The corpus builder is deterministic and regenerates M025-M100 plus the named
subset file. The core M001-M024 artifacts remain directly authored.

## Leakage Boundary

`evaluation_tasks.json` contains ten code-free smoke tasks, one per capability
family, with IDs outside the RAG manifest. The retriever loads only manifest entries in its selected named
subset. Before a paper-scale experiment, the evaluation set should be expanded
and frozen, then checked for semantic and structural near-duplicates against
all retrieval examples.

The current audit reports seven code-token Jaccard pairs at or above 0.90 out
of 4,950 possible pairs. They are related archetypes such as emergency-stop
and faulted-joint dynamics or quintic and minimum-jerk trajectories. They are
reported rather than silently discarded because related patterns are useful
for RAG; corpus-size results should still be interpreted with this overlap in
mind.
