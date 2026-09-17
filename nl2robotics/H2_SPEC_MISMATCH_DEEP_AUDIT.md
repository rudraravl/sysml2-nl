# H2 Execution and Spec-Mismatch Deep Audit

> Historical audit of the frozen one-joint baseline. The current articulated
> MVP scope is documented in `ARTICULATED_MVP.md`.

Date: 2026-08-22

## Research verdict

The H2 implementation is a real, testable co-simulation pipeline for one
declared robotics profile: a fixed-base, one-DOF X- or Y-axis revolute plant in
OpenUSD/PhysX controlled by a Modelica FMI 2.0 Co-Simulation PD effort
controller. It is not an arbitrary-robotics executor, and unsupported topology,
controller, interface, or evidence configurations now fail before generation.

Within that profile, the pipeline now has a coherent evidence chain from
grounded NL facts through planning, generated artifacts, active controller
tests, sampled-data execution, temporal properties, and post-execution semantic
alignment. Real Isaac execution remains the only uncollected execution layer.

## Material gaps found and fixed

1. FMU metadata proved variable names and units but not the PD law. Preparation
   now executes seven fresh-instance probes covering equilibrium, both position
   directions, both velocity-damping directions, and both saturation limits.
2. The grounded effort limit was not enforced by the runtime. The planner now
   derives symmetric command bounds, the contract cross-checks them against the
   IR, and the master rejects an out-of-range command before the physics step.
3. Isaac effort was set once per communication interval even when the protocol
   requested multiple physics substeps. The adapter now reapplies the held
   effort at every PhysX update, implementing the declared zero-order hold.
4. Nonzero initial state was checked but never applied. The Isaac adapter now
   sets grounded position and velocity state after physics initialization and
   before the first observation.
5. The planner admitted ambiguous H2 inputs. It now requires exactly one PD
   controller, one effort actuator, one dynamics owner, one position input, one
   velocity input, one effort output, and one copy of each required parameter.
6. Impossible experiments could reach generation. Targets and stated initial
   positions must lie within joint limits, the run must contain an integer
   number of communication steps, and every property interval must contain a
   trace sample.
7. Initial-value consistency was absent from spec mismatch. It is now checked
   from grounded IR to contract mapping and by the deterministic interface
   question adapter.
8. Alignment was evaluated only before Isaac, leaving runtime properties
   unknown in the final result. The Isaac runner now reruns the same frozen
   question set with verified contract, controller-probe, and property evidence
   and writes `post-execution-alignment.json`.
9. A pre-GPU alignment pass could be confused with claim readiness. Reports now
   distinguish the artifact gate from semantic claim readiness: pending runtime
   properties do not trigger repair, but they prevent the semantic claim gate
   from closing.
10. Older execution bundles could omit the stronger preflight. Bundle schema
    1.1 requires successful contract and controller-conformance evidence before
    the GPU runner accepts a bundle.

## Verified local evidence

- Repository test suite: 155/155 passing.
- Robotics test suite: 115/115 passing.
- Static benchmark audit: 15 tasks, 45 prompt variants, zero issues.
- Modelica and OpenUSD retrieval corpora: 300 pairs each, zero audit errors.
- Frozen retrieval evaluation: Modelica 100% top-1 and recall@5; OpenUSD 95%
  top-1 and 100% recall@5.
- Real RHY101 OpenModelica export: FMI 2.0 Co-Simulation FMU with the expected
  two inputs, effort output, parameter values, and units.
- Active RHY101 controller conformance: 7/7 probes passed with zero numerical
  error.
- Adversarial real-FMU check: a controller preserving every required variable,
  parameter, causality, and unit but hard-coding zero torque compiled and passed
  the metadata contract, then was correctly rejected by conformance at 1/7
  probes. No GPU bundle was emitted.
- Real incremental FMU/reference-physics smoke: 300/300 exchanges completed;
  command bounds enforced; both temporal properties passed.
- Pre-simulation alignment: 20/22 satisfied, 0 violated, 2 runtime properties
  unknown, score 1.0, coverage 0.877551.
- With archived runtime-property evidence: 22/22 satisfied, 0 unknown or
  violated, score and coverage 1.0.

The reference-physics run remains `claim_eligible_h2=false`. It validates the
software protocol, not Isaac/PhysX behavior.

## Remaining external evidence

Run the schema-1.1 bundle on the Linux x86_64 Isaac Sim 6.0 host for at least
three repetitions. A claim-eligible result requires verified Isaac/PhysX
provenance, the frozen solver/device/timestep, successful temporal properties,
post-execution 22/22 deterministic alignment, and trace repeatability. Generated
artifact ablations and frontier-baseline comparisons remain experiments, not
implementation work.

The effort-update decision follows the Isaac Sim 6 Articulation API requirement
that `set_dof_efforts` be called at every update step:
https://docs.isaacsim.omniverse.nvidia.com/6.0.0/py/source/extensions/isaacsim.core.experimental.prims/docs/index.html
