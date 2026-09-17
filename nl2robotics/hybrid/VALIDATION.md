# Portable Hybrid Acceptance

Date: 2026-08-17

The H1 portable hybrid profile was accepted on two structurally different
oracle tasks using the pinned OpenModelica, FMI, and OpenUSD runtimes.

| Task | Joint | FMU samples | Contract | Properties | USD inspection | Final USD |
|---|---|---:|---|---|---|---|
| RHY001 | Revolute Y | 151 | Pass | 2/2 | Pass | Pass |
| RHY002 | Prismatic Z | 151 | Pass | 2/2 | Pass | Pass |

## RHY001 evidence

- FMI output: `jointAngle`, value reference 5, unit radians.
- USD target: `/World/Link` through `/World/Shoulder`.
- Conversion: radians to degrees, scale `57.29577951308232`.
- Authored samples: 151 `xformOp:rotateY` values.
- Maximum time-code error: 0.
- Maximum value round-trip error: `1.896711701476761e-6` degrees.
- Declared float playback tolerance: `1e-5` degrees.
- Joint-limit and final-target temporal properties passed.

## RHY002 evidence

- FMI output: `liftPosition`, value reference 5, unit meters.
- USD target: `/World/Carriage` through `/World/LiftJoint`.
- Conversion: meters to meters, scale 1.
- Authored samples: 151 `xformOp:translate:joint` values.
- Maximum time-code error: 0.
- Maximum value round-trip error: 0.
- Travel-limit and final-target temporal properties passed.

For both tasks, the animated stage passed strict `usdchecker` syntax validation
and structured `pxr.Usd`/`UsdPhysics` semantic validation after authoring. Each
bundle records SHA-256 hashes for the source, FMU, traces, and animated stage.

## Claim boundary

These results establish reproducible FMU-owned kinematic playback, interface
mapping, synchronization, conversion, and artifact consistency. They do not
establish contact-rich USD physics or bidirectional co-simulation. Those claims
belong to the Isaac-backed H2 profile and must be evaluated separately.
