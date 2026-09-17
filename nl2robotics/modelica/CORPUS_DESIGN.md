# Modelica RAG Corpus Design

## Purpose

This corpus supplies executable few-shot examples for the standalone robotics
dynamics and control profile. It is a retrieval corpus, not the evaluation
benchmark. Its design favors semantic coverage, compiler validity, executable
behavior, explicit provenance, and controlled corpus-size experiments.

## Composition

The corpus contains 1,500 NL-to-Modelica retrieval pairs backed by 500 unique
executable semantic cases. Each of ten capability families has 50 executable
cases and 150 NL formulations:

| Capability family | Executable cases | Retrieval pairs |
|---|---:|---:|
| Joint mechanics | 50 | 150 |
| Electric actuation | 50 | 150 |
| Feedback control | 50 | 150 |
| Coupled transmissions | 50 | 150 |
| Hybrid safety | 50 | 150 |
| Mobile and aerial dynamics | 50 | 150 |
| Sensing and estimation | 50 | 150 |
| Fluid power | 50 | 150 |
| Trajectory generation | 50 | 150 |
| Multibody kinematics | 50 | 150 |

The 24-example `core` tier contains the initial hand-authored equations and
Modelica Standard Library compositions. The 76-example `expanded` tier adds
new mechanisms, controllers, domains, and difficulty levels. Every item has a
unique requirement and unique normalized Modelica artifact. Four deterministic
operating variants per source case change a non-setpoint physical or response
parameter by -10%, -3%, +3%, or +10%. Coupled mobile geometry is scaled in a
way that preserves the requested turn rate. The original property contract is
retained for every variant.

## Ablation Subsets

- `core24`: frozen original corpus; six represented families, four each.
- `balanced50`: five examples from every one of the ten families.
- `full100`: ten executable semantic cases from every one of the ten families.
- `full300`: the legacy three-formulation pool for the original 100 cases.
- `semantic500`: one NL formulation for every executable case.
- `full1500`: three NL formulations per executable case; the default RAG pool.

Subset membership is stored explicitly in `corpus_subsets.json`. It is not
computed by slicing directory order. The default retrieval setting is five
examples per prompt for direct comparability with the SysML pipeline. Retrieval
allows only one result per semantic case and lineage, so paraphrases expand
lexical coverage without filling a prompt with duplicate code.

## Validation Contract

Every pair must pass all of the following before inclusion:

1. Manifest and provenance audit.
2. OpenModelica model check.
3. Native code generation and compilation.
4. DASSL simulation under fixed settings.
5. At least one structured trace property.
6. Duplicate-code and evaluation-isolation audit.

The corpus builders are deterministic. `build_expanded_corpus.py` regenerates
M025-M100, while `build_retrieval_corpus.py` regenerates M101-M500, all lexical
variants, and the named subsets. The core M001-M024 artifacts remain directly
authored. The current exhaustive gate is 500/500 successful check/build,
simulation, and temporal-property evaluations.

## Leakage Boundary

`evaluation_tasks.json` contains ten code-free smoke tasks, one per capability
family, with IDs outside the RAG manifest. The retriever loads only manifest entries in its selected named
subset. Before a paper-scale experiment, the evaluation set should be expanded
and frozen, then checked for semantic and structural near-duplicates against
all retrieval examples.

The audit reports exact-code duplicates as an error and reports high-overlap
pairs for review. It also exposes 94 structural lineages separately from the
500 semantic cases. Retrieval admits at most one result per lineage, so
controlled operating variants cannot crowd a few-shot prompt.
