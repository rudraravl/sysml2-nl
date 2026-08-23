# Hybrid Robotics Execution

## H1 portable playback

The portable H1 profile couples executable Modelica dynamics to an OpenUSD
robot embodiment without claiming a USD physics simulation.

## Execution semantics

1. OpenModelica checks the source and exports an FMI 2.0 Co-Simulation FMU.
2. The shared contract validates the real FMU interface and real USD topology.
3. The pinned FMI runtime advances the FMU at contract communication points.
4. Mapped outputs are converted into declared USD units.
5. The pinned OpenUSD runtime authors rotation samples on kinematic bodies.
6. A separate reader reopens the exported stage and compares every authored
   time/value sample against the FMU trace.
7. The animated stage is rerun through strict syntax and robotics-semantic
   validation.
8. Temporal properties are evaluated over the original FMU trace.

The FMU owns plant dynamics. OpenUSD owns embodiment and playback. This mode is
not described as bidirectional co-simulation or contact-rich physics.

## Oracle command

```bash
python3 -m nl2robotics.hybrid.cli \
  --modelica nl2robotics/hybrid/oracles/RHY001/model.mo \
  --usd nl2robotics/hybrid/oracles/RHY001/scene.usda \
  --ir nl2robotics/hybrid/oracles/RHY001/requirement_ir.json \
  --contract nl2robotics/hybrid/oracles/RHY001/contract.json \
  --output-dir outputs/RHY001 \
  --modelica-backend docker
```

## Evidence bundle

The run emits:

- the checked source and exported FMU;
- raw FMI trace and execution metadata;
- contract validation with resolved value references and conversions;
- synchronized FMU/USD CSV trace;
- source and animated USDA stages;
- authoring and independent inspection reports;
- final strict OpenUSD validation;
- temporal-property results; and
- SHA-256 hashes for all major artifacts.

The generated H2 profile deliberately supports exactly one fixed-base X- or
Y-axis revolute joint with position and velocity feedback, PD effort control,
and grounded properties. Broader Modelica and OpenUSD artifacts exist in the
profile corpora, but prismatic, multi-joint, and other controller topologies are
not H2 execution claims.

## H2 closed-loop core

The H2 core separates the coupling algorithm from the simulator API. The
master samples simulator state, converts it into FMU inputs, advances a real
FMI 2.0 controller, applies one command mode per joint, advances physics, and
records both directions in one trace. The contract rejects wrong causality,
units, paths, ownership, kinematic bodies, conflicting command modes, and
effort commands on joints with authored drives before the loop starts.
Effort bounds are derived from the grounded IR and enforced before physics. A
held effort is reapplied on every physics substep, and grounded initial position
and velocity are set before the first observation.

`RHY101` is the first closed-loop oracle. The following command uses a real
OpenModelica FMU and the pinned FMPy sidecar with deterministic reference
physics:

```bash
python3 -m nl2robotics.hybrid.closed_loop_cli \
  --modelica nl2robotics/hybrid/oracles/RHY101/model.mo \
  --usd nl2robotics/hybrid/oracles/RHY101/scene.usda \
  --ir nl2robotics/hybrid/oracles/RHY101/requirement_ir.json \
  --contract nl2robotics/hybrid/oracles/RHY101/contract.json \
  --output-dir outputs/RHY101-reference \
  --inertia 0.5 --damping 0.2
```

That command is an integration test of the master, contract, real FMU, trace,
and property evaluator. Its report always sets `claim_eligible_h2` to false.
Only a run whose backend metadata proves that pinned Isaac Sim actually
executed may use the `isaac_closed_loop` result label.

## H2 Isaac evidence gate

Isaac execution is split at a deliberate trust boundary. The ordinary host
first compiles the controller FMU, validates the real USD stage and contract,
executes seven controller-law conformance probes, copies immutable inputs, and
hashes every artifact in a schema-1.1 bundle:

```bash
python3 -m nl2robotics.hybrid.isaac_prepare \
  --modelica nl2robotics/hybrid/oracles/RHY101/model.mo \
  --usd nl2robotics/hybrid/oracles/RHY101/scene.usda \
  --ir nl2robotics/hybrid/oracles/RHY101/requirement_ir.json \
  --contract nl2robotics/hybrid/oracles/RHY101/contract.json \
  --output-dir outputs/RHY101-isaac-input-v4
```

On a Linux RTX machine with Isaac Sim 6.0.x, run the checked bundle through
Isaac's own Python launcher:

```bash
./python.sh -m nl2robotics.hybrid.isaac_cli \
  --bundle outputs/RHY101-isaac-input-v4/execution-input.json \
  --output-dir outputs/RHY101-isaac-evidence \
  --controller-backend docker \
  --device cpu --solver TGS --repetitions 3
```

The preferred handoff wraps preflight and the three-run gate in one command:

```bash
python3 -m nl2robotics.hybrid.gpu_handoff \
  --bundle outputs/RHY101-isaac-input-v4/execution-input.json \
  --output-dir outputs/RHY101-isaac-handoff \
  --isaac-python /opt/isaacsim/python.sh \
  --controller-backend local --device cpu --solver TGS --repetitions 3
```

See `GPU_RUNBOOK.md` for dependency and transfer details.

The runner resolves exact USD DOF paths, samples angle and velocity, advances
the FMU controller, applies torque, and steps PhysX twice per communication
interval. It records the Isaac version, solver, device, physics timestep,
stage hash, FMU provenance, synchronized traces, and temporal properties.

After simulation, the runner reevaluates the frozen grounded question set using
the actual property results and writes `post-execution-alignment.json`. The
top-level report sets `claim_eligible_h2` only when all three runs use the real
Isaac backend, all required properties and deterministic alignment checks pass,
and the traces agree within the frozen numerical tolerance. A missing
simulator, stale bundle, changed artifact, wrong joint path, failed property, or
non-repeatable trajectory remains an explicit failure rather than falling back
to reference physics.

## H2 Newton evidence on DeltaAI

DeltaAI's Grace/H100 nodes cannot run the Isaac/PhysX evidence path, but they
can run the same closed-loop contract with Newton Physics. `RHY201` names that
backend explicitly so its result is not confused with `RHY101` Isaac evidence.
The runner imports the UsdPhysics articulation by exact joint path, executes the
same FMU exchange order and zero-order hold, and records separate
`claim_eligible_newton_h2` and `claim_eligible_isaac_h2` flags.

The pinned ARM64 Apptainer workflow compiles the FMU on the Grace host, validates
OpenUSD in-container, executes Newton 1.5.0 through Warp CUDA on the H100, and
requires three deterministic traces plus passing properties and post-execution
alignment. See `deltaai/README.md` for the build and submit commands.
