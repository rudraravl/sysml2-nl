# End-to-End Robotics Pipeline Plan

> The original one-joint milestone in this plan has been superseded by the
> articulated research MVP in `ARTICULATED_MVP.md`.

## Implementation Status (2026-08-17)

The portable path is now complete from one NL request:

- grounded shared-IR normalization with exact source evidence;
- deterministic Modelica/FMU names, OpenUSD paths, units, ownership, timing,
  properties, and cross-profile contract generation;
- existing RAG/MoE or lower-cost single-model generation for both profiles;
- OpenModelica build and FMI 2.0 Co-Simulation export;
- pinned OpenUSD parsing and robotics-semantic validation;
- real FMU execution, initial-state enforcement, unit conversion, synchronized
  tracing, USD playback authoring, independent sample inspection, and temporal
  property evaluation; and
- one-command immutable evidence bundles with failure-stage reporting.

RHY001 through RHY004 cover revolute, prismatic, non-integer USD float limits,
and degree-to-USD conversion, and all pass the unified H1 path end to end. The
H2 contract, sampled-data
master, incremental FMI sidecar, deterministic reference backend, and RHY101
controller oracle are implemented. RHY101 has passed 300 exchanges and its
temporal properties with a real exported FMU. The Isaac 6.0.x articulation
adapter, immutable simulator-input bundle, and three-run evidence gate are also
implemented. The shared normalizer, planner, and orchestrator now prepare H2
from the same NL entry point and distinguish GPU readiness from execution. This
remains a non-Isaac integration result until RHY101 is run on supported Linux
RTX infrastructure. Evidence-grounded cross-profile alignment
is wired into the orchestrator. A leakage-audited 15-task development benchmark
with 45 prompt variants passes every locally available oracle level, and the
stagewise ablation runner and statistical summaries are implemented. Real model
experiments and the external Isaac run remain pending.

## 1. Objective

Build a research-grade natural-language-to-robotics pipeline with three
measurable profiles:

1. **Modelica/FMI** for continuous, discrete, and hybrid dynamics, control, and
   actuation.
2. **OpenUSD/UsdPhysics** for robot embodiment, geometry, joints, rigid-body
   properties, sensors, and environment composition.
3. **USD+FMU hybrid** for executable coupling between generated FMUs and a USD
   robot scene.

The system must produce artifacts that are not merely plausible text. Each
artifact must pass the strongest available deterministic checks, execute when
its profile is executable, expose evidence for semantic scoring, and retain a
previous candidate when a repair makes the artifact worse.

The primary paper question is:

> Does a domain-profiled generation pipeline combining retrieval, mixture of
> experts, formal-tool feedback, cross-artifact contracts, and guarded semantic
> repair improve executable correctness and specification fidelity over direct
> frontier-model generation for complementary robotics representations?

## 2. Research Position

### 2.1 What the paper should claim

The method is a reusable architecture for translating natural language into
tool-checked, executable formal artifacts. A domain adapter supplies:

- a retrieval corpus,
- a generator prompt and output contract,
- a parser/compiler/validator,
- an execution adapter,
- observable evidence,
- domain-specific semantic questions and properties, and
- a guarded repair policy.

Robotics is a strong second domain because no single artifact captures both
dynamic behavior and physical embodiment. Successful generation therefore
requires cross-representation consistency, not only language syntax.

### 2.2 What the paper should not claim

- OpenUSD is not itself a physics solver.
- A valid USD file is not necessarily a physically meaningful robot.
- Writing FMU output values into USD time samples is not bidirectional
  co-simulation.
- A Modelica plant and a USD physics plant must not both integrate the same
  dynamics in one experiment.
- Isaac-specific Robot, Sensor, and PhysX schemas are extension-profile
  semantics, not portable OpenUSD core semantics.
- LLM agreement alone is not evidence that an artifact executes correctly.

## 3. Frozen Profile Responsibilities

| Concern | Modelica/FMI | OpenUSD/UsdPhysics | Hybrid contract |
|---|---|---|---|
| Differential equations | Owns | Does not own | Declares ownership |
| Controller logic | Owns | May receive commands | Maps commands |
| Actuator dynamics | Owns when requested | Applies resulting effort/target | Maps units/direction |
| Rigid-body simulation | Owns in Modelica-only tasks | Named engine owns in USD/hybrid tasks | Prevents duplicate ownership |
| Geometry/materials | Abstract or omitted | Owns | Maps component identity |
| Links/joints/articulation | Abstract mechanics | Owns embodiment | Maps joint identity |
| Sensors | Signal equations or estimator | Placement and simulator sensor schema | Maps observations |
| Environment/contact | Simplified equations | Owns scene and contact geometry | Maps feedback signals |
| Temporal requirements | Emits trace signals | Emits scene/physics trace signals | Defines common clock |

Every benchmark task declares one owner for each physical state. The contract
validator rejects ambiguous or duplicated state ownership.

## 4. Two Hybrid Execution Modes

### 4.1 H1: Portable FMU-owned kinematic execution

Purpose: establish a completely reproducible vertical path without requiring a
GPU physics simulator.

1. Modelica owns and integrates plant dynamics.
2. OpenModelica exports an FMI 2.0 Co-Simulation FMU.
3. An FMI master executes the FMU at fixed communication points.
4. FMU outputs such as joint position are converted to declared USD units.
5. Values are authored as USD time samples on a kinematic articulation.
6. The run emits a synchronized trace and an animated USD stage.

This is an executable FMU plus standards-based USD playback. It proves artifact
generation, interface mapping, timing, units, and observable behavior. It does
not prove contact-rich USD physics.

### 4.2 H2: Isaac-backed closed-loop co-simulation

Purpose: provide the stronger headline experiment.

1. The FMU owns controller and/or actuator dynamics.
2. Isaac Sim with a pinned physics engine owns rigid-body plant dynamics.
3. At communication time `t`, the master reads joint and sensor state from the
   simulator and sets declared FMU inputs.
4. The master advances the FMU by `dt` and reads commands such as effort,
   position target, or velocity target.
5. Commands are applied to named USD articulation joints.
6. The physics engine advances by `dt`.
7. Both sides are recorded in one trace with timestamps and provenance.

The initial master uses fixed-step sampled-data sequential coupling. At each
step it samples simulator state, advances the controller FMU with those held
inputs, applies the returned command, and advances physics using zero-order
hold. The trace records pre-step observations, FMU inputs and outputs, applied
commands, and post-step state. This is not described as Jacobi coupling and it
does not invent an extra feedback-delay claim. Algebraic-loop solving and
adaptive co-simulation are outside the MVP unless experiments require them.

### 4.3 Why both modes are necessary

H1 prevents the project from depending entirely on proprietary/GPU
infrastructure and is sufficient for continuous integration. H2 supports the
paper's physical-behavior claim. Results must report the execution mode
explicitly rather than pooling them.

## 5. Shared Robotics Contract

The two generators receive the same normalized requirement representation and
must emit artifacts that satisfy one machine-readable contract.

### 5.1 Requirement IR

The requirement IR contains only facts grounded in the NL prompt:

```json
{
  "task_id": "RHY-001",
  "execution_mode": "isaac_closed_loop",
  "entities": [],
  "joints": [],
  "dynamics": [],
  "controllers": [],
  "actuators": [],
  "sensors": [],
  "environment": [],
  "interfaces": [],
  "properties": [],
  "assumptions": [],
  "unknowns": []
}
```

Unknown or underspecified facts remain unknown. The normalizer must not invent
dimensions, masses, gains, sensor types, or requirements merely to fill a
schema.

### 5.2 Interface mapping

Each mapping records:

- semantic component and signal IDs,
- FMU variable name and value reference,
- FMU causality (`input`, `output`, or `parameter`),
- USD prim path and joint name,
- command/observation kind,
- source unit and target unit,
- direction,
- ownership,
- update rate and interpolation/hold policy,
- initialization value, and
- allowed numeric range when specified.

Example:

```json
{
  "id": "elbow_command",
  "owner": "fmu_controller",
  "fmu_variable": "elbowTorque",
  "fmu_causality": "output",
  "usd_prim": "/World/Robot/elbow_joint",
  "usd_quantity": "joint_effort",
  "source_unit": "N.m",
  "target_unit": "N.m",
  "direction": "fmu_to_usd",
  "sample_period": 0.008333333333333333,
  "hold": "zero_order"
}
```

### 5.3 Contract validation

The contract passes only when:

- every referenced FMU variable exists,
- causality matches direction,
- every referenced USD prim and joint exists,
- units are compatible and conversions are explicit,
- one side owns each state,
- command modes do not conflict,
- sample periods are positive and commensurate with the master clock,
- all required mappings are present,
- no required NL entity disappears from both artifacts, and
- initial conditions are compatible within a declared tolerance.

## 6. Artifact Bundle

Every run writes one immutable directory:

```text
run/
  request.txt
  requirement_ir.json
  retrieval.json
  generation.json
  modelica/
    model.mo
    compiler.json
    model.fmu
    fmu_manifest.json
  openusd/
    robot.usda
    scene.usda
    validation.json
  hybrid/
    contract.json
    execution_config.json
    animated.usda
    trace.csv
    execution.json
  alignment/
    questions.json
    evidence.json
    comparison.json
  result.json
```

All reports include tool versions, model IDs, prompt hashes, random seed where
supported, simulator/solver configuration, and failure stage. Large binaries
and generated scenes remain experiment artifacts rather than source files.

## 7. Work Packages

### WP0: Freeze protocol and interfaces

Tasks:

- approve the profile responsibility table,
- choose the H2 plant/controller partition,
- freeze the requirement IR and hybrid contract schemas,
- select the named simulator and physics backend,
- freeze units, axes, naming, and timing conventions,
- identify the machine that will run Isaac Sim, and
- write paper claim boundaries before implementation.

Acceptance gate:

- one oracle hybrid task can be represented without ambiguity,
- no state is owned by both Modelica and the simulator,
- every output metric can be computed from recorded evidence.

### WP1: Modelica to FMU

Existing foundation:

- 100 balanced RAG examples,
- compiler-checked MoE generation,
- native OpenModelica build,
- guarded compiler repair, and
- 10 code-free smoke tasks.

Remaining tasks:

- export FMI 2.0 Co-Simulation FMUs using `buildModelFMU`,
- parse `modelDescription.xml`,
- validate variable names, causalities, types, starts, and units,
- execute FMUs with a pinned FMI runtime,
- support time-varying inputs and selected outputs,
- emit deterministic traces,
- distinguish export, instantiate, initialize, step, and terminate failures,
- add FMU interface requirements to generation prompts, and
- build controller-only/actuator-only hybrid examples that do not duplicate the
  USD plant.

Acceptance gate:

- at least three Modelica examples export, instantiate, execute, and reproduce
  expected trace properties through the FMU rather than the original Modelica
  executable,
- generated FMU metadata matches the declared contract,
- a deliberately broken interface fails before execution.

### WP2: OpenUSD profile

Generation strategy:

- Generate textual `.usda` for transparent inspection and repair.
- Use primitive geometry for self-contained benchmark scenes.
- Use composition references for approved realistic assets; do not ask the LLM
  to fabricate mesh vertex data.
- Keep portable `UsdPhysics` in the core artifact.
- Add Isaac Robot/Sensor/PhysX schemas only in a named extension layer.

Initial capability families:

1. stage metadata, units, and axes,
2. primitive geometry and transforms,
3. rigid bodies, mass, inertia, and collision,
4. revolute, prismatic, fixed, and spherical joints,
5. joint limits and drives,
6. articulation roots and link topology,
7. physics materials and contact configuration,
8. environments, obstacles, and ground planes,
9. portable sensor placement metadata, and
10. Isaac-specific robot and sensor extensions.

Validation ladder:

1. file parse and stage composition,
2. `usdchecker`,
3. schema/API traversal with `pxr`,
4. custom robotics semantic checks,
5. named-simulator load,
6. stable simulation for the declared horizon, and
7. property satisfaction over the resulting trace.

Semantic checks include:

- resolvable prim paths and references,
- explicit `metersPerUnit`, `kilogramsPerUnit`, `upAxis`, and time rate,
- positive mass and physically plausible inertia,
- collision geometry on dynamic links,
- valid joint body relationships and acyclic articulation topology,
- compatible joint axes, frames, and limits,
- exactly one applicable command mode per driven joint,
- expected articulation root,
- sensors attached to existing bodies,
- required physics scene and gravity, and
- absence of unsupported extension schemas in the portable profile.

Acceptance gate:

- at least 20 hand-reviewed seed examples pass levels 1-4,
- at least five scenes load and run in the named simulator,
- injected topology, unit, path, and joint errors are detected,
- the generator produces one unseen valid scene with at most two grounded
  repairs.

### WP3: OpenUSD retrieval corpus

Build the corpus in explicit semantic and lexical tiers:

- `core20`: two hand-reviewed examples per capability family,
- `semantic100`: ten executable stages per family after validator validation,
- `full300`: legacy three-formulation pool for the first 100 stages,
- `semantic500`: 50 executable stages per family after validator validation,
- `full1500`: three NL formulations per executable stage for retrieval.

Every retrieval example must have:

- a unique NL requirement,
- a valid USD artifact,
- structured semantic annotations,
- declared capability tags,
- provenance and license metadata,
- validator results,
- simulator status when applicable, and
- at least one positive and one negative property where meaningful.

The corpus and evaluation set must be separate. Near-duplicate NL and scene
structures are reported, and referenced third-party assets are never copied
without an explicit compatible license.

Acceptance gate:

- each named subset is balanced and deterministic,
- all files pass the subset's declared validation level,
- retrieval returns relevant mechanics/scene patterns rather than only lexical
  matches,
- no evaluation ID or oracle artifact can enter retrieval.

### WP4: Portable hybrid vertical slice

First task: a single revolute arm whose Modelica plant produces joint angle and
angular velocity and whose USD articulation is explicitly kinematic.

Tasks:

- export and run the FMU,
- validate the contract,
- convert radians to USD-facing angular representation where necessary,
- author time samples,
- produce an animated stage,
- record synchronized traces,
- evaluate final position, limit, and settling properties, and
- package one end-to-end command.

Acceptance gate:

- a clean checkout can generate or consume the oracle artifacts and reproduce
  the same pass/fail results without Isaac Sim,
- USD playback numerically matches FMU output within tolerance,
- contract mutation tests fail for wrong units, paths, or signal direction.

### WP5: Isaac-backed hybrid vertical slice

First task: a controller FMU drives a one-degree-of-freedom USD rigid-body arm.
Isaac Sim owns the arm dynamics; the FMU owns the controller.

Tasks:

- load the generated USD stage headlessly,
- discover articulation joints by stable name,
- initialize FMU and physics state consistently,
- exchange state and command signals at fixed steps,
- apply one command type per joint,
- record FMU and simulator values on one clock,
- detect NaN, divergence, invalid contacts, and step failures,
- evaluate STL properties, and
- save simulator, engine, solver, and timestep configuration.

Acceptance gate:

- deterministic success across at least three repeated oracle runs,
- command and feedback traces prove both directions of data exchange,
- the same FMU can be tested against at least two parameter settings,
- a missing or incorrect mapping fails before the physics loop,
- the report never labels H1 playback as H2 closed-loop execution.

Implementation status: the adapter, preflight bundle, exact DOF mapping,
provenance capture, repeated-run harness, and CI test doubles are complete.
The external three-run Isaac execution remains pending because the development
machine is Apple Silicon and cannot host the supported simulator.

### WP6: Semantic alignment and repair

Question families:

- entity and component presence,
- dynamic variables and equations,
- control behavior,
- geometry and transform facts,
- link/joint topology,
- mass, material, collision, and limits,
- actuator and command modes,
- sensor type and placement,
- environment and interaction,
- timing and initial conditions,
- safety and temporal behavior, and
- cross-profile interface consistency.

Selection process:

1. extract grounded facts and unknowns into the requirement IR,
2. instantiate only templates relevant to present entities and relationships,
3. add task-specific concrete questions,
4. reject questions that require facts absent from the NL,
5. answer against NL, Modelica evidence, USD evidence, and runtime traces,
6. score `satisfied`, `violated`, `unknown`, or `not_applicable`, and
7. route high-confidence violations to the owning artifact.

Repair rules:

- compiler/parser errors may trigger local syntax repair,
- deterministic semantic violations may trigger targeted repair,
- unknown or ambiguous questions do not incur a destructive penalty,
- a repair may modify only its declared ownership region,
- Modelica repair cannot silently change USD identity or contract mappings,
- USD repair cannot silently change FMU semantics,
- cross-profile changes require contract revalidation,
- every repair reruns all lower-level checks,
- a candidate replaces the current best only on a monotonic quality tuple, and
- maximum repairs remain small and fixed before experiments.

Suggested quality ordering:

```text
(infrastructure_available,
 parses,
 compiles_or_composes,
 contract_valid,
 executes,
 deterministic_property_passes,
 grounded_semantic_score,
 -error_count,
 -unsupported_claim_count)
```

Acceptance gate:

- seeded mismatches route to the correct artifact,
- ambiguity does not remove valid content,
- no repair can replace an executable candidate with a non-executable one,
- repeated scoring with cached questions is deterministic.

Implementation status: complete for focused question instantiation, formal
evidence answering, optional twin-blind artifact judging, weighted scoring,
unknown exclusion, deterministic blocking, and owner-scoped repair. The
single-owner repair loop reruns all profile and execution checks and accepts a
candidate only on strict monotonic improvement without stage regression.

### WP7: Benchmark construction

Build benchmark tasks from oracle artifact bundles, then author natural-language
requirements from the oracle facts. This gives deterministic ground truth while
keeping oracle code out of retrieval and model prompts.

Task groups:

- 30 Modelica-only tasks,
- 30 OpenUSD-only tasks,
- 30 hybrid tasks.

Each group should be balanced across easy, medium, and compositional difficulty.
The 90-task set is the paper target; a frozen 15-task development set and
30-task pilot precede it.

Prompt variants:

- precise/rich,
- concise but sufficient,
- deliberately underspecified with labeled unknowns.

The underspecified variant tests calibration and non-invention; it must not be
scored as if omitted details were required.

Oracle annotations include:

- required and forbidden entities,
- numeric parameters with tolerances,
- topology and interface facts,
- expected validator level,
- simulation horizon and inputs,
- temporal properties,
- permitted assumptions, and
- unsupported/unknown facts.

Acceptance gate:

- two reviewers agree on the IR and properties before generation,
- automated leakage and near-duplicate audits pass,
- every oracle artifact passes its target execution level,
- evaluation prompts are frozen and versioned before headline runs.

Implementation status: a balanced 15-task development set is frozen with five
Modelica, five OpenUSD, and five hybrid tasks. All 15 pass their locally
available oracle level; H2 is prepared but awaits real Isaac execution. The
30-task pilot and independent annotation review remain future experimental work.

### WP8: Experiments and ablations

Primary conditions:

| ID | Condition | RAG | MoE | Tool repair | Alignment | Contract |
|---|---|---:|---:|---:|---:|---:|
| B0 | Direct frontier model | no | no | no | no | minimal evaluation only |
| B1 | RAG | yes | no | no | no | minimal evaluation only |
| B2 | RAG + MoE | yes | yes | no | no | generated |
| B3 | Tool-grounded pipeline | yes | yes | yes | no | validated |
| FULL | Complete pipeline | yes | yes | yes | yes | validated |

Focused ablations:

- corpus size: 20 vs 50 vs 100,
- one expert vs full MoE,
- no repair vs guarded repair,
- unguarded vs guarded repair on a small diagnostic subset,
- generic questions vs focused question selection,
- Modelica-only vs OpenUSD-only vs hybrid profile,
- H1 playback vs H2 closed-loop execution, and
- rich vs concise vs underspecified NL.

Do not run a large combinatorial grid. Stagewise ablations answer the research
questions with fewer calls and clearer attribution.

Implementation status: conditions, resumable fingerprinted records, metric
extraction, infrastructure separation, seeded bootstrap intervals, failure
distributions, and exact paired McNemar comparisons are implemented. Generation
runs remain pending so they can use one frozen model configuration and budget.

### WP9: Metrics and statistical protocol

Primary binary metrics:

- Modelica native-build rate,
- FMU export rate,
- FMU execution rate,
- USD parse/composition rate,
- USD robotics-semantic validity rate,
- named-simulator load rate,
- stable simulation rate,
- hybrid contract validity rate,
- end-to-end execution rate, and
- all-required-properties pass rate.

Semantic metrics:

- required-fact precision, recall, and F1,
- forbidden-fact violation rate,
- unknown-fact invention rate,
- cross-profile consistency F1,
- weighted specification alignment with unknowns excluded from penalties, and
- repair regression rate.

Continuous metrics:

- STL robustness,
- trajectory error against oracle envelopes,
- initial-condition discrepancy,
- unit-conversion error,
- runtime, token use, and estimated cost,
- number of repairs, and
- failure-stage distribution.

Reporting:

- paired comparisons use the same tasks and model configuration,
- report bootstrap confidence intervals over tasks,
- use McNemar or an exact paired test for paired binary outcomes where suitable,
- report mean/median and confidence intervals for continuous metrics,
- show per-capability results rather than only aggregate accuracy,
- keep failed infrastructure separate from generated-code failures,
- repeat a representative subset to quantify generation variance.

## 8. Implementation Shape

Planned modules:

```text
nl2robotics/
  contracts/
    requirement_ir.py
    hybrid_contract.py
    units.py
  modelica/
    ...existing Layer 1...
    fmu_export.py
    fmu_runtime.py
  openusd/
    corpus.py
    pipeline.py
    moe.py
    validator.py
    semantic.py
    examples/
  hybrid/
    portable.py
    isaac_adapter.py
    master.py
    trace.py
  alignment/
    questions.py
    evidence.py
    compare.py
    repair.py
  benchmark/
    manifest.py
    evaluate.py
    statistics.py
```

Design constraints:

- keep simulator adapters behind a small interface,
- use structured parsers/APIs rather than regex for USD and FMU metadata,
- keep deterministic orchestration separate from LLM calls,
- keep portable OpenUSD checks runnable without Isaac Sim,
- make each stage return structured status and evidence,
- fail honestly when a backend is unavailable,
- avoid a general workflow framework until two concrete adapters require it.

## 9. Dependency Graph and Parallel Work

```text
WP0 contract
  |-- WP1 FMU export/runtime -----------------|
  |-- WP2 OpenUSD validator/generator --------|--> WP4 portable hybrid
  |-- WP3 OpenUSD corpus (after validator) ---|          |
  |-- Isaac compute provisioning -------------|----------|--> WP5 closed loop
  |-- Benchmark oracle design ---------------------------|--> WP7 freeze
                                                           |
WP4 + WP5 evidence APIs --> WP6 alignment/repair ---------|--> WP8 experiments
```

Recommended parallel ownership:

- Track A: FMU export/runtime and Modelica hybrid examples.
- Track B: OpenUSD validator, seed corpus, and generator.
- Track C: contract/IR, benchmark oracles, and semantic questions.
- Track D: Isaac environment and closed-loop adapter once hardware is secured.

Corpus expansion waits for its validator. Headline generation waits for the
benchmark freeze. Alignment repair waits for deterministic evidence APIs.

## 10. Aggressive Milestones

### M0: Decisions and oracle bundle

Target: one focused work session.

- freeze schemas and ownership,
- hand-author one valid Modelica controller/plant, USD scene, and contract,
- confirm Isaac execution access.

### M1: FMU proof

Target: one to two focused days.

- export, inspect, instantiate, and execute three FMUs,
- verify trace properties.

### M2: OpenUSD core

Target: two to four focused days.

- core validator,
- 20 reviewed examples,
- retrieval and generation,
- unseen valid scene.

### M3: Portable end to end

Target: one to two focused days after M1/M2.

- NL to Modelica/FMUs and OpenUSD,
- contract validation,
- FMU-driven animated USD,
- trace properties.

### M4: Isaac closed loop

Target: two to five focused days after compute is available.

- controller FMU to USD physics,
- state feedback,
- deterministic trace and STL evaluation.

### M5: Alignment and guarded repair

Target: two to four focused days after evidence APIs stabilize.

- focused questions,
- evidence comparison,
- ownership-routed repair,
- regression tests.

### M6: Corpus and pilot

Target: three to five focused days.

- expand OpenUSD corpus to 50 and then 100 only if validation remains clean,
- freeze 30-task pilot,
- run stagewise ablations,
- fix systematic failures without changing frozen evaluation answers.

### M7: Headline experiment

- freeze 90 tasks and all configurations,
- run the selected conditions,
- compute uncertainty and failure taxonomy,
- archive prompts, artifacts, versions, and costs.

These are engineering estimates, not promises. Isaac provisioning and
simulator-specific debugging are the largest schedule risks.

## 11. Decisions Needed From The Professor

1. Is the headline hybrid expected to be H1 FMU-driven kinematic USD, H2
   bidirectional Isaac closed loop, or both? Recommendation: both, reported
   separately, with H2 as the stronger result.
2. In H2, should Modelica own controller/actuator behavior while Isaac owns the
   rigid-body plant? Recommendation: yes, to avoid duplicate dynamics.
3. Is Isaac Sim with its pinned default PhysX backend the approved named
   simulator? Recommendation: yes unless the group already has a different
   supported environment.
4. What Linux RTX workstation or cloud resource can run Isaac Sim? This is an
   immediate infrastructure dependency because the current Apple Silicon Mac
   cannot run the supported Isaac Sim stack locally.
5. Are Isaac-specific Robot and Sensor schemas required for the headline set or
   a secondary extension experiment? Recommendation: portable UsdPhysics is
   mandatory; Isaac schemas are a clearly labeled extension.
6. Is a 90-task final benchmark acceptable, with a 30-task pilot first?
7. Which model and budget are frozen for baseline and full-pipeline runs?

## 12. Critical Risks and Mitigations

| Risk | Consequence | Mitigation |
|---|---|---|
| No supported Isaac machine | No physics-backed hybrid result | Secure remote Linux RTX compute during WP0; H1 remains portable fallback |
| Duplicate plant dynamics | Scientifically invalid hybrid | Contract-level ownership check; controller-FMU/physics-plant partition |
| Valid USD but invalid robot | Inflated success rate | Layered semantic and simulator validation |
| Generated meshes dominate failures | Irrelevant complexity | Primitive geometry or references to licensed assets |
| Corpus quantity outruns quality | Weak RAG and leakage | 20/50/100 gated tiers |
| Question bank over-penalizes ambiguity | Destructive repair | Tri-state/NA answers, grounded selection, monotonic retention |
| Repairs alter unrelated semantics | Regression | Ownership-scoped repair and full revalidation |
| Simulator-specific result presented as portable | Overclaim | Separate core and Isaac extension profiles in every report |
| Expensive ablation grid | Budget/time exhaustion | Stagewise conditions and repeated representative subset |
| Evaluation leakage | Invalid paper results | Oracle isolation, similarity audit, frozen manifests |
| Nondeterministic generation/scoring | Unclear gains | Cached questions, artifact hashes, repeated subset, paired tasks |

## 13. Definition of End-to-End Done

The robotics pipeline is complete when a clean experiment run can:

1. accept one NL robotics requirement,
2. extract a grounded requirement IR,
3. retrieve profile-relevant examples,
4. generate and compile Modelica,
5. export and inspect a valid FMU,
6. generate and semantically validate OpenUSD,
7. construct and validate the shared contract,
8. execute H1 and, on supported infrastructure, H2,
9. record synchronized evidence and traces,
10. evaluate deterministic and semantic properties,
11. perform bounded guarded repair when justified,
12. retain the best fully validated candidate,
13. report exact failure stage without fake success, and
14. reproduce benchmark metrics from archived artifacts.

## 14. Immediate Execution Order

1. Get professor answers to the seven decisions above, especially Isaac access
   and H2 ownership.
2. Freeze `requirement_ir.json` and `contract.json` schemas using one oracle
   revolute-arm bundle.
3. Implement and prove Modelica to FMI 2.0 Co-Simulation export and execution.
4. Implement OpenUSD parsing plus robotics-semantic validation.
5. Hand-author and validate `core20`; then wire OpenUSD RAG/MoE generation.
6. Complete H1 using the oracle bundle, then replace each oracle artifact with a
   generated artifact one stage at a time.
7. Run the completed H2 master against a pinned Isaac Sim backend and complete
   three repeated RHY101 oracle runs with archived simulator provenance.
8. Add evidence-based alignment and repair only after both execution paths emit
   stable structured evidence.
9. Freeze and run the pilot before expanding the corpus or benchmark further.

## 15. Technical Basis

- OpenModelica's `buildModelFMU` supports FMI 2.0 Model Exchange and
  Co-Simulation export:
  https://build.openmodelica.org/Documentation/OpenModelica.Scripting.buildModelFMU.html
- FMI Co-Simulation defines communication-point data exchange while the FMU
  advances with its internal simulation method; the master algorithm remains a
  system responsibility:
  https://fmi-standard.org/docs/main/
- OpenUSD `UsdPhysics` represents rigid bodies, joints, drives, articulations,
  and kinematic articulations:
  https://openusd.org/release/api/usd_physics_page_front.html
- `usdchecker` provides baseline USD compliance/interchange validation but does
  not replace robotics-semantic or simulator checks:
  https://openusd.org/release/toolset.html
- Isaac Sim parses USD Physics into a selected physics backend, advances it per
  simulation step, and writes updated state back to USD:
  https://docs.isaacsim.omniverse.nvidia.com/latest/physics/index.html
- Isaac Sim's supported installation requires Windows or Ubuntu with suitable
  NVIDIA RTX hardware; its container is Linux-only:
  https://docs.isaacsim.omniverse.nvidia.com/latest/installation/requirements.html
- FMPy supports FMI 1/2/3, Model Exchange and Co-Simulation, and provides Python
  and command-line execution:
  https://github.com/CATIA-Systems/FMPy
