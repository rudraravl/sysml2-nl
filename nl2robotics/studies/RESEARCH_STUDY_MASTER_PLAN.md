# Robotics pipeline research study master plan

Status: protocol draft before confirmatory data collection  
Date: 2026-08-29  
Implementation branch: `robotics-generalized-hybrid`  
Implementation commit at planning: `e67100061c786c8240ee2d2eaaaba00d9edfda21`

## 1. Paper claim

The paper should evaluate this claim:

> A capability-tiered pipeline improves the grounded generation and
> cross-representation consistency of complementary Modelica and OpenUSD
> robotics artifacts relative to direct frontier-model generation, while
> reporting stronger executable evidence only for profiles that genuinely pass
> FMU, physics, repeatability, and accelerator-provenance gates.

The paper must not claim that every broad robotics family already executes in
one universal simulator. Broad capability evidence and articulated CUDA
execution are reported separately.

## 2. Research questions and hypotheses

### Primary question

**RQ1.** Does the complete pipeline improve valid paired-artifact generation
over direct frontier generation across broad robotics requirements?

- **H1:** `FULL` has a higher task-level artifact-pair success rate than `B0`.
- Primary comparison: `B0` versus `FULL`.
- Primary endpoint: both Modelica and OpenUSD pass their real validators after
  only the operations allowed by the assigned condition.
- A task-condition succeeds when at least two of three frozen repetitions
  succeed. Raw repetition-level rates are also reported.

### Secondary questions

**RQ2.** Which pipeline stages contribute to the result?

- `B0`: direct frontier generation;
- `B1`: retrieval-augmented single-model generation;
- `B2`: retrieval plus the frozen mixture of experts;
- `B3`: tool-grounded generation and bounded validation repair; and
- `FULL`: the complete pipeline, including deterministic cross-artifact
  alignment and guarded owner-scoped repair.

**RQ3.** Does the generated pair preserve the grounded robotics requirements,
not merely compile?

- Report deterministic semantic score and evidence coverage separately.
- Report satisfied, violated, unknown, and not-applicable requirement counts.
- Report exact FMU/USD mapping completeness and unit/ownership consistency.
- Never treat an unknown as satisfied.

**RQ4.** Does mismatch detection find and localize real cross-artifact faults?

- Seed one controlled mutation at a time into otherwise validated pairs.
- Measure detection recall, false-positive rate on clean pairs, mismatch-family
  localization, and repair-owner localization.
- This is a deterministic, no-model-cost study.

**RQ5.** Can generated supported profiles actually execute?

- Generate the one-, two-, and three-joint articulated tasks under the frozen
  `FULL` condition.
- For bundles that pass preparation, execute three closed-loop repetitions on
  DeltaAI with the frozen Newton configuration.
- Report this as generated-artifact runtime confirmation, not as runtime
  coverage of all 13 families.

## 3. Experimental units

### Broad capability benchmark

- 13 paper-facing families.
- One rich, numerical, source-grounded task per family.
- Modelica RAG: frozen `full1500` corpus.
- OpenUSD RAG: frozen `full1500` corpus.
- Retrieval: `k=5`, four family-preferred hits plus one global fallback.
- Five ablation conditions.
- Three fresh generations per task and condition.
- Target grid: **13 x 5 x 3 = 195 cells**.
- Broad cells are capped at verification Tier 2 and cannot set H2 or DeltaAI
  claim flags.

`RCB002` has already been used for development. It must be labeled a
development case and excluded from confirmatory inference, or replaced by one
new frozen mobile-robotics case before the main run. The recommended minimal
action is to add one replacement mobile case and retain `RCB002` only for smoke
testing.

### Executable articulated benchmark

- Three structurally different tasks: single, serial, and branching.
- One, two, and three simultaneously controlled joints.
- Revolute and prismatic joints; X, Y, and Z axes.
- Each generated successful bundle receives three deterministic physics
  repetitions.
- Existing oracle runs remain integration/provenance evidence and are not mixed
  with generated-output accuracy.

## 4. Endpoints

### Primary endpoint

`artifact_pair_valid_final`:

```text
final Modelica compiles
AND final OpenUSD passes syntax and robotics-semantic validation
AND neither artifact was manually edited
```

### Required secondary endpoints

- `artifact_pair_valid_attempt_0`: true one-shot pair validity before repair;
- Modelica attempt-0 and final validity;
- OpenUSD attempt-0 and final validity;
- grounded semantic score;
- deterministic evidence coverage;
- blocking violation count;
- exact contract mapping completeness;
- requirement-family satisfaction counts;
- highest verification tier;
- repair attempts and accepted repairs;
- wall-clock latency;
- successful and failed model-call counts;
- failure stage;
- infrastructure availability; and
- generated-artifact CUDA/runtime outcomes for the articulated confirmation.

Artifact validity, semantic fidelity, and runtime execution must remain
separate columns. No composite headline score should hide which stage failed.

## 5. Required harness corrections before paper runs

These are study-validity changes, not expansion of the robotics pipeline.

1. **Freeze normalization for paired comparisons.** Normalize and validate one
   IR per task/repetition block, then give the same frozen IR to every
   condition. Re-normalizing separately by condition confounds artifact
   generation with different interpretations.
2. **Make `FULL` real for capability runs.** The current capability path returns
   before semantic alignment, so `B3` and `FULL` are behaviorally equivalent.
   Capability `FULL` must run deterministic artifact alignment and guarded,
   owner-scoped repair followed by complete revalidation.
3. **Assert condition fidelity.** Each run must prove whether RAG, MoE, repair,
   contract use, and alignment were actually invoked. A label alone is not
   evidence of an ablation.
4. **Record one-shot outcomes.** Extract attempt-zero validity before any repair
   in addition to final system success.
5. **Add semantic-fidelity metrics.** A compiling artifact that omits grounded
   requirements is not a semantic success.
6. **Use blocked run order.** Randomize condition order within each
   task/repetition using one recorded seed so service drift or quota timing is
   not confounded with `B0`-to-`FULL` order.
7. **Stop cleanly on usage limits.** Do not convert every remaining cell into an
   infrastructure failure. Stop, retain completed fingerprints, and resume.
8. **Treat missing MoE experts as infrastructure degradation.** A paper cell
   requires the frozen expert roster and combiner; otherwise rerun it rather
   than comparing a smaller accidental ensemble.
9. **Record full provenance.** Store Git commit, manifest and corpus hashes,
   condition configuration, model/provider strings, tool versions, prompts,
   raw responses, artifacts, repairs, timestamps, and hashes.
10. **Use task-clustered statistics.** Repetitions of one task are not 39
    independent benchmark tasks.

No confirmatory cell should run until these ten checks have automated tests and
the dry-run manifest passes.

## 6. Run phases and gates

### Phase 0 — Protocol and harness freeze

1. Implement the ten harness corrections.
2. Add the replacement held-out mobile case.
3. Freeze and hash benchmark manifests, corpora, conditions, prompts, model
   roster, validator versions, statistics seed, and exclusion rules.
4. Commit and push the preregistration before inspecting confirmatory outputs.

**Gate:** all repository tests pass; condition-fidelity tests pass; a dry run
lists the exact expected cells and fingerprints.

### Phase 1 — Development smoke

Use only development material: `RCB002` plus the checked articulated oracles.

1. Run direct and full conditions once.
2. Confirm every expected model call, validator, repair limit, and alignment
   stage is recorded.
3. Confirm interruption and resume behavior.
4. Fix only general infrastructure or harness defects.

**Gate:** evidence audit passes with no manual artifact changes. Development
outputs never enter confirmatory statistics.

### Phase 2 — Confirmatory broad generation

1. Run all `B0` and `FULL` cells first because they answer the primary question.
2. Run `B1`, `B2`, and `B3` to attribute component effects.
3. Use three repetitions and the frozen blocked order.
4. Audit each cell immediately and checkpoint after every cell.

**Gate:** all planned cells are either valid completed observations or explicit
infrastructure exclusions that are rerun under the identical fingerprint.

The full target is 195 cells. If an external quota makes that impossible by the
paper deadline, the prespecified minimum dataset is the 78 `B0`/`FULL` cells.
Intermediate conditions may then be reported as a clearly labeled exploratory
one-repeat component study; they must not be presented as equally powered
confirmatory comparisons.

### Phase 3 — Deterministic mismatch study

For every clean validated pair, seed one mutation at a time from the supported
families, such as:

- entity mass or geometry;
- joint type, axis, topology, or limits;
- FMU/USD interface variable, direction, unit, or ownership;
- controller parameter or actuator bound; and
- timing/environment configuration.

Retain the clean control and exact mutation manifest. Do not ask an LLM to
judge the seeded ground truth.

### Phase 4 — Generated executable confirmation

1. Generate `FULL` artifacts for the three articulated tasks.
2. Prepare and inspect FMU, OpenUSD, contract, mappings, and alignment locally.
3. Submit only successful frozen bundles to DeltaAI.
4. Require genuine CUDA provenance, three repetitions, all properties,
   repeatability, and zero blocking alignment violations.
5. Archive Slurm accounting and complete SHA-256 manifests.

Expected GPU use is far below one GPU-hour. The 195-cell Tier-2 study requires
no DeltaAI allocation.

### Phase 5 — Analysis and reporting

Run the frozen analysis once after the evidence audit. Do not change endpoint
definitions after viewing condition results.

## 7. Statistical analysis

### Primary analysis

- Collapse three repetitions to one task-level success per condition using the
  prespecified two-of-three rule.
- Compare `B0` with `FULL` using exact paired McNemar.
- Report paired absolute improvement, success counts, discordant pairs, exact
  p-value, and a task-clustered 95% bootstrap interval.
- Also report all 39 repetition-level outcomes descriptively.

### Secondary analysis

- Stagewise paired comparisons: `B0-B1`, `B1-B2`, `B2-B3`, and `B3-FULL`.
- Apply Holm correction across the four stagewise binary comparisons.
- For semantic score, coverage, repairs, and latency, aggregate repetitions
  within task and use paired differences with task-clustered bootstrap
  intervals; report medians as well as means.
- Family results are descriptive because one task per family does not support
  family-level inference.
- Report failure-stage distributions without converting infrastructure errors
  into model failures.

Effect sizes and uncertainty are primary; p-values are supporting evidence.

## 8. Failure, repair, and exclusion policy

- **Model failure:** malformed response, invalid IR, failed compilation,
  semantic invalidity, omitted requirements, broken mappings, or exhausted
  permitted repairs. Include it as failure.
- **Infrastructure failure:** unavailable provider, usage cap, validator crash,
  lost process, unavailable compiler, or missing required MoE expert. Exclude
  temporarily and rerun the same fingerprint.
- **Manual editing:** prohibited for all measured artifacts.
- **Repair:** only the assigned condition's automated bounded repair is allowed.
- **Post-freeze code defect:** document it, fix it generally, increment the
  study version, and rerun every affected condition symmetrically.
- **Prompt/corpus changes after outcomes:** prohibited for confirmatory data.
- **Selective reruns:** prohibited. Reruns require a recorded infrastructure
  reason or a versioned restart rule applied to all affected cells.

## 9. Resource and time budget

- Breadth smoke: approximately 13 single-model paired generations if the full
  smoke is retained; use development cases first.
- Main grid: 195 run cells, but substantially more model calls because each MoE
  artifact uses four experts plus one combiner. Plan for roughly 1,500 base
  model calls before optional repairs.
- GPU: only generated articulated confirmation; expected below one GPU-hour.
- Storage: retain raw outputs and hashes; package archives after auditing.
- Wall-clock target: one focused session for harness freeze, one for smoke,
  one to three days of resumable generation depending on quotas, and one to two
  focused sessions for analysis and figures.

Do not add prompt variants, more robot families, more corpora, or extra
simulators before the primary study completes. Those are extensions, not
requirements for this paper stage.

## 10. Required paper outputs

1. Benchmark/family and verification-tier table.
2. Ablation table with one-shot and final paired-artifact success.
3. Semantic score and evidence-coverage table.
4. Family-by-condition heatmap, explicitly descriptive.
5. Failure-stage chart.
6. Deterministic mismatch detection/localization table.
7. Generated articulated runtime table with DeltaAI provenance.
8. RAG corpus/retrieval audit in the appendix.
9. Exact configuration, manifests, code commit, and evidence archive links.
10. Limitations separating artifact breadth from runtime breadth.

## 11. Decisions to confirm with the professor

Only decisions that materially change the study should be raised:

1. Confirm the primary claim is broad paired-artifact generation with
   capability-tiered execution, not universal runtime execution.
2. Confirm whether all five ablation conditions are required for the first
   submission; recommendation: target all five, preserve `B0` versus `FULL` as
   the minimum confirmatory result.
3. Confirm the frozen model/MoE roster and external-service budget.
4. Confirm the submission deadline so the 195-cell target and the 78-cell
   prespecified floor can be scheduled without changing them after results.

## 12. Definition of study completion

The research phase is complete only when:

- the preregistered cells have auditable terminal records;
- all infrastructure exclusions are resolved or explicitly reported;
- primary and secondary metrics reproduce from archived artifacts;
- mismatch and runtime confirmations are complete;
- no claim exceeds its verification tier;
- the analysis, tables, figures, limitations, and evidence archive are frozen;
  and
- another researcher can rerun the analysis from the retained records without
  manually editing generated code.

