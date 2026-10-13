# Modelica controls and A0–A4 ladder

The committed `runs/title_mod/` contains the two completed PACE shards: 500
requirement cells, 1,381 generated Modelica programs, and the per-attempt
prompts, compiler diagnostics, verdicts, and token counts. `s0` is the shared
first draw; `c1/c2` are diagnostic repairs, `b1/b2` are bare repairs, and
`r1/r2` are independent redraws. Normalization skips have a cell but no draft.
Compiler caches and build intermediates are excluded.

## Recompute the control results

From the repository root, with Python 3.9 or newer (standard library only):

```sh
python3 ecir2027/reproduce_title_mod.py > /tmp/title-mod-reproduction.json
```

The checked-in `runs/title_mod/reproduction.json` is the output of this command.
It reports the first draw (226/500, 45.2%), its −4.0 percentage-point difference
from the archived A0 records (246/500, 49.2%), and the control rates:

| Arm | One extra attempt | Two extra attempts |
|---|---:|---:|
| Diagnostic repair | 69.2% | 78.6% |
| Bare repair | 59.6% | 65.0% |
| Independent redraws | 66.8% | 75.2% |

The paired exact McNemar results include discordant counts and raw p-values.
Both correction conventions are explicitly labeled: Holm over all six
Modelica comparisons, and Holm over three comparisons within each budget.
If a paper table's family includes other languages, its Holm correction must
also include those languages' raw p-values; a Modelica-only correction cannot
substitute for that family.

Usage totals, means per requirement, and medians per requirement provide the
call/token inputs for the Modelica cost table. These use all 500 requirements
as the denominator, including normalization skips. The 274 unsuccessful
requirements comprise 208 actual failing drafts and 66 normalization skips.
The median of two compiler errors is computed over the 208 failing drafts;
diagnostic repair clears 167 unsuccessful requirements.

`runs/title_mod/source.sha256` records hashes from the PACE source before
transfer. Verify them from the repository root:

```sh
shasum -a 256 -c ecir2027/runs/title_mod/source.sha256
```

The report also contains hashes of every requirement-level JSON and Modelica
artifact. These are saved observations, not new model samples. Regeneration
requires the dependencies, model credentials, and OpenModelica backend used
by `modelica_title_arms.py`; stochastic model generation does not guarantee
the same numerical outcomes.

## Run the A0–A4 ladder

`generate.py` remains a single-call probe generator. The ladder runs through
`nl2robotics.experiments.run_cli`, `PipelineExperimentExecutor`, and
`nl2robotics.modelica.moe.generate_modelica_moe`.

| Condition | Retrieval | Expert synthesis | Compiler repair | Runtime repair |
|---|---|---|---|---|
| A0 | No | No | No | No |
| A1 | Yes | No | No | No |
| A2 | Yes | Yes | No | No |
| A3 | Yes | Yes | Yes | No |
| A4 | Yes | Yes | Yes | Yes |

The launcher uses the committed 500 Modelica IDs and full corpus manifest,
five retrieval hits, two repairs, one repetition, and seed 20260830:

```sh
PYTHON=python3 bash scripts/run_glm_ablation.sh --dry-run
OUTPUT_DIR=outputs/glm52-ablation-v1 bash scripts/run_glm_ablation.sh
```

The dry run freezes and prints 2,500 cells without calling models. Execution
requires the repository dependencies, `OPENROUTER_API_KEY`, and an available
Modelica backend (`MODELICA_BACKEND=local` by default in the launcher). Model
roster and transport configuration come from the existing shared pipeline;
the generated protocol records them. The launcher and separate repair-stage
behavior were recovered from the PACE `robotics-generalized-ablation` working
tree and integrated while preserving the repository's newer B0 and best-of-N
behavior. This exposes the ladder implementation; it does not claim a fresh
run recreates archived stochastic samples exactly.

## Outstanding raw probes

The programs referenced by `runs/scored/compile.jsonl` under
`R1b/mod/A1alt/outputs/*.mo` and `R2mod/mod/random/outputs/*.mo` were not found
in the inspected PACE locations. They are not included in this addition.
The title-control programs belong to different experiments and cannot replace
them. The committed probe verdicts therefore still lack their original raw
programs.
