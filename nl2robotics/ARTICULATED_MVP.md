# Articulated robotics MVP

The executable closed-loop profile is a functional research MVP for articulated
robots, not a one-joint demo. A single grounded requirement IR drives the
Modelica controller, OpenUSD plant, coupling contract, runtime, temporal
properties, alignment report, and claim gate.

## Demonstrated capability

| Dimension | Supported in the executable profile |
|---|---|
| Topology | One fixed-base serial or branching articulation tree |
| Scale | One or more joints and rigid links |
| Joint types | Revolute and prismatic, mixed in one robot |
| Axes | Principal X, Y, and Z axes |
| Geometry | Box executed end to end; sphere, cylinder, and capsule supported by planning and semantic validation |
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

`RHY201` remains the minimal one-joint regression oracle. `RHY202` is the broad
integration oracle: a two-link serial articulation with a Y-axis revolute
shoulder and X-axis prismatic extension, six FMI/USD signal mappings, two
actuators, and four runtime properties.

## Intentional next research extensions

The MVP does not claim arbitrary robotics. Floating/mobile bases, closed-chain
kinematics, contact-task properties, trajectory controllers, coupled
operational-space control, and PI/PID state semantics are separate extensions.
They can be added without changing the shared mapping or evidence architecture.
