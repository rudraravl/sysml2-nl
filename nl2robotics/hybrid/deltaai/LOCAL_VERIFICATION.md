# Newton H2 Local Verification

Date: 2026-08-23

This rehearsal exercised the same `RHY201` bundle and runner intended for
DeltaAI, using ARM64 OpenModelica 1.27.0, FMPy 0.3.29, Newton Physics 1.5.0,
Warp 1.16.0, and CPU execution on an ARM64 macOS host. The controller FMU ran
inside the pinned ARM64 Linux FMI sidecar.

## Preflight

- FMI 2.0 Co-Simulation export passed.
- The FMU exposed two Real inputs and one Real output with the required units.
- All seven active PD-controller conformance probes passed.
- OpenUSD validation found one scene, two rigid bodies, two collisions, two
  joints, and one articulation with no semantic errors.
- All three contract mappings resolved to `/World/Shoulder` with identity unit
  conversions and the grounded 5 N.m effort bound.

## Three-run Featherstone gate

- All 3 repetitions completed 300 communication steps and 600 physics steps.
- Final shoulder position was `0.5235997438430786 rad`.
- Joint-limit property passed with robustness `0.9947815696385245`.
- Final-target property passed with robustness `0.05235890931505016`.
- Trace repeatability passed with maximum absolute delta `0.0`.
- Post-execution alignment satisfied all 23 grounded questions with score `1.0`.

One MuJoCo-Warp sensitivity run also completed 300 steps and passed both
properties. It was not treated as a headline result because a one-run check
does not satisfy the frozen three-run repeatability gate.

This validates the end-to-end software path and real Newton execution. It does
not validate CUDA or DeltaAI performance: `claim_eligible_deltaai_h2` remains
false until the same bundle passes on Linux ARM64 with an H100/GH200 CUDA
device.
