# Capability-tiered robotics pipeline

The robotics pipeline has a broad generation path and separately named
executable profiles. It does not force every robotics request into the
fixed-base PD articulation contract, and it does not promote artifact validity
to physics-execution evidence.

## Broad shared IR

`capability_tiered` normalization can preserve grounded requirements for:

- fixed, floating, mobile, aerial, legged, marine, multi-robot, and soft-body
  entities;
- serial, branching, multi-articulation, and closed-chain topology;
- revolute, continuous, prismatic, fixed, spherical/ball, free, distance, D6,
  planar, screw, gear, universal, mimic, tendon, and cable joints;
- principal or arbitrary joint axes and multi-DOF joints;
- primitive, mesh, convex, height-field, compound, and unspecified geometry;
- P/PI/PD/PID, feedforward, trajectory, state-feedback, impedance, admittance,
  computed-torque, operational-space, mobile, aerial, MPC, and custom control;
- joint, base, body, wheel, thrust, wrench, contact, IMU, encoder, camera,
  lidar, GPS, odometry, electrical, fluid-power, and deformation signals;
- sensors, estimators, environments, materials, friction, contact, obstacles,
  terrain, trajectories, and temporal or task-level properties.

The vocabulary is intentionally broader than any one runtime. Facts remain
grounded in exact source excerpts. Missing values remain unknown; the broad IR
does not invent masses, gains, transforms, meshes, or clocks to make a request
look executable.

## Verification ladder

| Tier | Meaning |
|---|---|
| 0 | Natural language was normalized with source evidence. |
| 1 | The broad shared IR passed structural and reference validation. |
| 2 | Both generated artifacts passed their Modelica and OpenUSD profile validators. |
| 3 | A profile-specific contract resolved and checked the real FMU/USD interfaces. |
| 4 | A profile-specific coupled runtime executed and its properties passed. |
| 5 | Execution also passed accelerator, backend, repeatability, and provenance gates. |

Every run records the highest tier actually reached. A difficult mobile,
contact, aerial, or sensing request can therefore participate in generation
and semantic-fidelity experiments even before its dedicated closed-loop adapter
exists. Its report remains tier 2 rather than being mislabeled as an H2 run.

## Implemented profiles

- `general_modelica_openusd`: broad complementary artifact generation and
  validation, tier-2 ceiling.
- `portable_fmu_kinematic`: real FMU execution plus verified USD playback.
- `articulated_joint_space_h2`: fixed-base acyclic revolute/prismatic trees,
  independent saturated PD effort control, Newton or Isaac adapter, and tier-5
  provenance when the external execution gate passes.

The router also identifies requested mobile, aerial, legged, marine, soft,
fluid-power, electromechanical, multi-robot, closed-chain, sensor, contact, and
trajectory/coupled-control profiles. Those currently use the general artifact
path and are explicitly marked as needing a dedicated runtime adapter for
tiers 3–5.

## Command

```bash
python3 -m nl2robotics.orchestrator.cli \
  --request request.txt \
  --execution-mode capability_tiered \
  --output-dir outputs/broad-robotics-run \
  --mode moe --subset full1500
```

The bundle contains the grounded IR, capability contract, profile-specific
generation requirements, Modelica and OpenUSD artifacts, validator reports,
`capability-report.json`, and `result.json`. Claim flags remain false unless a
separate strict executable profile produces the required runtime evidence.

## Paper use

Use a capability matrix rather than one universal pass rate. Stratify tasks by
domain and requested feature, report normalization/IR validity, artifact
validity, cross-artifact validity, execution, and provenance separately, and
compare ablation conditions at the strongest applicable tier. The real DeltaAI
Newton results are the strongest evidence cells; they do not define the
language or generation boundary of the system.
