# Articulated robotics MVP

The executable closed-loop profile is a functional research MVP for articulated
robots, not a one-joint demo. A single grounded requirement IR drives the
Modelica controller, OpenUSD plant, coupling contract, runtime, temporal
properties, alignment report, and claim gate.

## Demonstrated capability

| Dimension | Supported in the executable profile |
|---|---|
| Topology | One fixed-base serial or branching articulation tree |
| Scale | No hard-coded joint-count cap; verified with one, two, and three simultaneously controlled joints |
| Joint types | Revolute and prismatic, mixed in one robot |
| Axes | Principal X, Y, and Z axes |
| Geometry | Box, sphere, cylinder, and capsule executed end to end |
| Control | Independent saturated joint-space PD effort control in one FMU |
| Feedback | Position and velocity for every joint |
| Actuation | Torque for revolute joints, force for prismatic joints |
| Physics | Newton Physics or Isaac Sim/PhysX through the same master |
| Properties | `always`, `eventually`, and `final` bounds on observed states |
| Evidence | FMU metadata, USD semantics, active controller probes, traces, properties, repeatability, backend provenance, and semantic alignment |

The profile uses canonical simulator-boundary units: rad, rad/s, and N.m for
revolute joints; m, m/s, and N for prismatic joints. Source values such as
degrees are preserved in the IR and converted explicitly.

## End-to-end flow

1. Normalize natural language into evidence-grounded entities, topology,
   dynamics ownership, controller parameters, interfaces, timing, and
   properties.
2. Reject an incomplete request before generation; derive deterministic names,
   paths, units, command limits, joint frames, and the sampled-data protocol.
3. Generate and validate one FMI 2.0 Co-Simulation controller and one OpenUSD
   articulation.
4. Cross-check every FMU variable against its exact USD joint and semantic IR
   interface.
5. Actively probe every PD channel for sign, damping, saturation, and
   cross-channel isolation.
6. Run the FMU and physics backend in a zero-order-hold closed loop, evaluate
   temporal properties, repeat the run, and emit provenance-backed evidence.

The executable breadth suite is machine-audited rather than inferred from one
example. `RHY201` is the minimal one-joint regression. `RHY202` covers a serial
mixed revolute/prismatic mechanism. `RHY203` covers a branching three-joint
tree, all X/Y/Z axes, cylinder/capsule/sphere geometry, nine FMI/USD mappings,
three simultaneous PD channels, and position, velocity, limit, and convergence
properties. Together they cover all joint types, axes, and primitive shapes in
the current articulated profile. Run the audit with:

```bash
python3 -m nl2robotics.studies.articulated
```

## Intentional next research extensions

The current profile deliberately targets fixed-base acyclic articulation trees
with independent joint-space PD effort channels. Floating/mobile bases,
closed-chain constraints, contact-task specifications, trajectory control,
coupled operational-space control, and integral controller state are the next
profile extensions; the shared mapping, execution, and evidence architecture
does not depend on a one-joint assumption.
