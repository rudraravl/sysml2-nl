# RHY202 articulated local verification

Date: 2026-08-25

RHY202 exercised the generalized mixed-joint pipeline with a real OpenModelica
FMI 2.0 Co-Simulation controller, a validated OpenUSD articulation, and Newton
Physics 1.5.0 on an ARM64 CPU. It is local Newton evidence, not DeltaAI CUDA or
Isaac/PhysX evidence.

## Preflight

- Four Real FMU inputs and two effort outputs exported with the required units.
- Six semantic FMU/USD mappings resolved across `/World/Shoulder` (revolute Y)
  and `/World/Extension` (prismatic X).
- OpenUSD validation found three rigid bodies, three collision shapes, three
  joints including the world anchor, and one articulation.
- All 14 behavioral probes passed with zero numerical error. Each perturbed
  joint also left the other effort channel at equilibrium.

## Three-run Newton result

- `success=true`
- 3/3 repetitions, each with 250 communication steps and two physics substeps
- all four joint-limit and final-target properties passed
- repeatability passed with maximum absolute trace delta `0.0`
- post-execution alignment: 39/39 satisfied, score `1.0`, coverage `1.0`
- final shoulder position: `0.35999274253845215 rad`
- final extension position: `0.07760770618915558 m`
- `claim_eligible_h2=true`
- `claim_eligible_newton_h2=true`
- `claim_eligible_deltaai_h2=false`
- `claim_eligible_isaac_h2=false`

Local evidence is under `outputs/RHY202-newton-articulated-20260825/`. The main
report is `execution/newton-report.json`; the immutable input manifest is
`bundle/execution-input.json`.

## Regression suites

- generalized focused tests: 44/44 passed
- robotics subsystem: 135/135 passed
- full repository: 173/173 passed
