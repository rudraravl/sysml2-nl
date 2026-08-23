# H2 Foundation Audit

Date: 2026-08-17

## Verdict

The existing H1 path is substantive and should be retained. It exports and
executes a real Co-Simulation FMU, validates the actual FMU and USD artifacts,
enforces ownership and units, independently checks authored playback samples,
evaluates temporal properties, and labels the result as kinematic playback.
Its current evidence is still pilot-scale, but the architecture matches the
claim.

The original H2 design could not safely be implemented on top of the H1
mapping assumptions. In particular, USD-to-FMU observations were checked
against the wrong side of the unit conversion, simulator radians were mixed
with authored USD degrees, dynamic ownership was not enforced, and the plan
called a sequential exchange "Jacobi" while also claiming an unexplained
one-step delay.

## Corrections

- Unit and causality checks now follow mapping direction.
- H1 playback angles remain degrees; H2 simulator joint state is SI radians.
- H2 requires both feedback and command mappings and one command mode per joint.
- H2 driven bodies must be dynamic, not kinematic.
- Effort-commanded joints reject authored position or velocity drives.
- The coupling order is frozen as sampled-data sequential with zero-order hold.
- Initial simulator observations are checked before controller initialization.
- A successful run requires temporal properties over post-step simulator state.
- Reference-physics reports are structurally unable to claim Isaac H2 evidence.

## Implemented Block

- Simulator-independent `ClosedLoopMaster` and narrow controller/physics APIs.
- Incremental FMI 2.0 controller adapters for local FMPy and a pinned container
  sidecar, keeping FMPy out of the future Isaac Python environment.
- Deterministic 1-DOF reference physics and PD controller test doubles.
- RHY101 grounded NL, requirement IR, Modelica controller, dynamic USDA, and
  bidirectional contract.
- Synchronized trace columns proving observations, FMU inputs, FMU outputs,
  applied commands, and post-step state.
- Mutation tests for unit direction, dynamic ownership, and command conflicts.
- A host-side bundle gate that exports the FMU, validates the USD/contract,
  freezes inputs, and hashes every artifact before simulator launch.
- An Isaac Sim 6.0.x articulation adapter using exact DOF paths, explicit
  PhysX timestep/device/solver configuration, and the existing sampled-data
  master.
- A three-run evidence harness that requires deterministic properties and
  numerical trace repeatability before an H2 result is claim-eligible.
- A profile-aware NL orchestrator that derives controller names,
  observation/command mappings, ownership, coupling, geometry layout, and the
  immutable GPU bundle rather than relying on a hand-authored H2 contract.
- A pinned API preflight that checks Isaac Sim 6.0.x and every experimental
  articulation/simulation method used by the runtime before launch.
- A physically explicit RHY101 fixed-base articulation with grounded geometry,
  authored joint frames, and a deliberately stated zero-gravity oracle scope.

## Verified Evidence

The RHY101 Modelica source exported as a real FMI 2.0 Co-Simulation FMU with
two Real inputs and one Real torque output. The real FMU completed 300
communication steps through the pinned FMPy 0.3.29 sidecar against reference
physics. Joint-limit and final-target properties passed. The reference backend
is deterministic across three test runs and is explicitly non-claim-eligible.

No Isaac-backed result is claimed. The adapter and evidence gate are now ready,
but this Apple Silicon machine cannot execute the supported simulator. The
remaining H2 evidence action is to run the prepared RHY101 bundle on a Linux
RTX machine with Isaac Sim 6.0.x. The report will reject the claim unless all
three runs pass and archive engine, solver, device, timestep, version, hashes,
properties, and repeatability evidence.

The generated H2 scope is intentionally one fixed-base revolute degree of
freedom with position/velocity feedback and effort command. Multi-joint scene
layout is not claimed merely because the sampled-data runtime can carry several
mappings.
