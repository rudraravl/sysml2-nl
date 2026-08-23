# Robotics Pipeline Research Readiness Audit

Date: 2026-08-22

## Verdict

The robotics implementation is a substantive research-grade MVP, not a mock
pipeline. H1 is locally executable end to end. H2 is now one coherent path from
grounded NL normalization through deterministic planning, profile generation,
real FMU export, real OpenUSD/contract validation, semantic alignment, and an
immutable GPU handoff bundle. The final Isaac/PhysX execution remains an
external evidence step and is deliberately not reported as passed locally.

The generated H2 claim is intentionally scoped to one fixed-base revolute DOF
with position/velocity feedback and effort command. The broader Modelica and
OpenUSD profiles cover more artifact families, but arbitrary multi-joint
closed-loop layout is not implied by the runtime's ability to carry multiple
signals.

## Material Findings And Corrections

1. H2 previously depended on a hand-authored oracle contract and was absent
   from the authoritative NL orchestrator. The normalizer and planner are now
   execution-mode aware and deterministically derive H2 ownership, interfaces,
   names, paths, clock, coupling, and profile obligations.
2. The requirement IR admitted missing record fields, booleans as numbers, and
   non-finite values. These now fail with structured diagnostics before code
   generation or contract math. The contract validator also handles malformed
   numeric metadata without crashing.
3. The 300-pair Modelica corpus had feedback-control plants but no actual
   controller-only FMI interface examples. Three core cases now teach typed
   observation inputs, effort outputs, PI/PD control, saturation, controller
   state, and unit conversion. All three compile and execute successfully.
4. The first OpenUSD RAG case was semantically too close to RHY101 despite a
   different file hash. It was replaced by a distinct 1.5 kg X-axis dynamic
   effort-control articulation with different limits and no authored drive.
5. Orchestrator summaries discarded evidence needed by the ablation metrics.
   Contract, FMU, execution, property, simulator, and repeatability outcomes now
   use one common result vocabulary for H1 and H2.
6. GPU preflight previously proved only that `isaacsim` imported. It now checks
   Isaac Sim 6.0.x and every experimental articulation, stage, and simulation
   API called by the adapter before an expensive run begins.
7. The H2 prompt confused `/World` with the articulation-root joint and left
   joint-frame layout implicit. It now freezes `/World/WorldAnchor`, discloses
   deterministic one-DOF geometry assumptions, and rejects unsupported H2
   topologies rather than silently inventing layouts.
8. The OpenUSD validator could mark syntax valid after a failed fallback parse.
   It now reports the computed syntax result.
9. Controller validation previously stopped at FMU interface metadata. H2
   preparation now executes seven PD-law and saturation probes and rejects a
   behaviorally wrong controller before GPU handoff.
10. The runtime did not enforce grounded effort limits or reapply effort at
    every physics substep. Bounds are now derived and checked end to end, and
    the zero-order-held effort is applied on every PhysX update.
11. Alignment previously stopped before simulator evidence existed. Isaac runs
    now produce a post-execution alignment report and require all grounded
    runtime properties before closing the semantic claim gate.

## Verified Evidence

- 115 robotics unit and integration tests pass.
- 155 repository-wide tests pass.
- Both 300-pair corpora pass balance, uniqueness, provenance, and subset audits.
- Retrieval remains 100% Modelica top-1/recall@5 and 95%/100% for OpenUSD.
- New Modelica FMI-controller cases M007-M009 compile, simulate, and pass their
  properties with pinned OpenModelica.
- Corrected OpenUSD lineage O001/O021/O041/O061/O081 passes `usdchecker` and the
  pinned robotics-semantic validator.
- The one-command RHY001 regression smoke exports and executes a real FMI 2.0
  Co-Simulation plant, passes the hybrid contract, and satisfies all 15
  grounded alignment questions with full evidence coverage.
- The one-command RHY101 orchestrator smoke exports a real FMI 2.0
  Co-Simulation controller, validates the dynamic OpenUSD stage, resolves all
  three bidirectional mappings, records zero blocking semantic violations, and
  writes a hash-checked bundle with `ready_for_gpu=true`.
- The same smoke correctly records `passed=false`,
  `claim_eligible_h2=false`, and `failure_stage=gpu_execution_pending`.
- The strengthened RHY101 preparation actively passes 7/7 controller probes.
  Its pre-GPU alignment satisfies 20/22 questions with only the two runtime
  properties unknown; archived reference-property evidence closes 22/22.

## Claim Boundary

| Claim | Status |
| --- | --- |
| Modelica and OpenUSD generation/validation profiles are implemented | Supported |
| Portable H1 NL-to-executed-FMU-to-USD playback is implemented | Supported |
| H2 NL-to-validated-GPU-bundle software path is implemented | Supported |
| H2 controller law, saturation, and runtime effort bounds are actively checked | Supported |
| Reference FMU/controller closed loop executes and passes properties | Supported |
| Generated H2 artifact quality improves over a frontier baseline | Not tested yet |
| Isaac/PhysX H2 executes successfully and repeatably | Pending GPU evidence |
| Arbitrary multi-joint NL-to-H2 generation is supported | Not claimed |

## Final Checklist

1. Run one real-model H1 generation and one real-model H2 preparation with the
   frozen configuration; archive prompts, model IDs, retrievals, repairs, and
   result bundles.
2. Copy the H2 `execution-input.json` bundle to the Linux x86_64 Isaac host and
   run `gpu_handoff --dry-run`; require every OS, NVIDIA, launcher, dependency,
   version, and API-surface check to pass.
3. Run the real H2 handoff for at least three repetitions with the frozen Isaac
   version, PhysX solver, device, timestep, and controller backend.
4. Require all temporal properties, simulator provenance, artifact hashes, and
   trace repeatability to pass before setting or reporting
   `claim_eligible_h2=true`.
5. Run the full B0/B1/B2/B3/FULL ablation grid only after the GPU configuration
   is frozen. Keep infrastructure failures separate from model failures and do
   not pool H1 playback with H2 physics execution.
