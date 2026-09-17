# RHY203 branching local verification

Date: 2026-08-26

RHY203 exercised the broad articulated profile with a real OpenModelica FMI 2.0
Co-Simulation controller, a validated OpenUSD branching articulation, and
Newton Physics 1.5.0 on an ARM64 CPU. This is local Newton evidence, not
DeltaAI CUDA or Isaac/PhysX evidence.

## Coverage and preflight

- Three simultaneously controlled joints in one branching articulation tree.
- Revolute X, revolute Z, and prismatic Y joints.
- Cylinder, capsule, and sphere rigid-link collision geometry.
- Six FMU feedback inputs, three effort outputs, and nine resolved FMI/USD
  mappings.
- All 21 active controller probes passed, including per-channel sign, damping,
  saturation, and cross-channel isolation.

## Three-run Newton result

- `success=true`
- 3/3 repetitions, each with 300 communication steps and two physics substeps
- all nine limit, target, and final-velocity properties passed
- repeatability passed with maximum absolute trace delta `0.0`
- post-execution alignment: 58/58 satisfied, score `1.0`, coverage `1.0`
- final left shoulder: `0.2619698346 rad`, `0.0006036087 rad/s`
- final right shoulder: `-0.2094393522 rad`, `-0.0000011292 rad/s`
- final tool slide: `0.0500494130 m`, `0.0001749400 m/s`
- `claim_eligible_h2=true`
- `claim_eligible_newton_h2=true`
- `claim_eligible_deltaai_h2=false`
- `claim_eligible_isaac_h2=false`

Local evidence is under
`outputs/RHY203-newton-branching-converged-20260826/`. The main report is
`newton-report.json`; its immutable prepared input is under
`outputs/RHY203-oracle-smoke-20260826c/hybrid/execution-input.json`.

The false DeltaAI flag is expected: the local machine is ARM64 macOS CPU. The
unchanged claim gate requires the final rerun on Linux ARM64 with a real H100
CUDA device.
