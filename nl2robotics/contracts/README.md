# Shared Robotics Contract

This package defines the deterministic boundary between the Modelica/FMI and
OpenUSD robotics profiles. It does not call an LLM and it does not simulate USD
physics.

## Why this boundary exists

The two generated artifacts use different identifiers, units, clocks, and
state ownership rules. A syntactically valid FMU and a syntactically valid USD
stage can still be impossible to couple. The contract therefore checks the
actual exported `modelDescription.xml` and actual OpenUSD scene evidence before
hybrid execution starts.

The portable `RHY001` oracle freezes H1:

- the FMI 2.0 Co-Simulation FMU owns and integrates joint dynamics;
- the USD stage owns geometry, mass, collision, and joint topology;
- the driven USD body is explicitly kinematic;
- the FMU `jointAngle` output is converted from radians to degrees;
- float-valued USD playback is checked within an explicit `1e-5` degree
  round-trip tolerance;
- samples use one 50 Hz master clock; and
- the eventual USD artifact is kinematic playback, not physics co-simulation.

OpenUSD specifies revolute limits in degrees. FMI exposes variable name, value
reference, type, causality, variability, and unit through
`modelDescription.xml`. The implementation resolves those fields instead of
trusting names supplied by a generator.

The `RHY101` oracle freezes the H2 boundary:

- USD physics owns dynamic joint position and velocity;
- a controller FMU consumes those observations and emits one effort command;
- simulator runtime position uses radians even though authored revolute limits
  use degrees;
- the validator checks FMI causality and the correct directional side of each
  unit conversion;
- a dynamic body is mandatory, and an effort-commanded joint cannot retain an
  authored position or velocity drive; and
- both feedback and command mappings must exist before execution begins.

Primary references:

- https://openusd.org/dev/api/class_usd_physics_revolute_joint.html
- https://openusd.org/dev/api/usd_physics_page_front.html
- https://fmi-standard.org/docs/2.0.4/

## Files

- `requirement_ir.py`: validates IDs, references, execution mode, and exact NL
  evidence excerpts.
- `units.py`: performs explicit dimensional compatibility and conversion.
- `hybrid_contract.py`: validates ownership, clock, FMI variables, USD paths,
  topology, axes, limits, masses, causality, and required mappings.
- `../hybrid/oracles/RHY001/`: one complete oracle request, normalized IR,
  Modelica plant, USD scene, properties, and contract.
- `../hybrid/oracles/RHY101/`: the one-joint closed-loop controller and dynamic
  USD oracle used to freeze the H2 interface.
- `../hybrid/oracles/RHY202/`: a mixed revolute/prismatic multi-joint oracle for
  generalized planning, mapping, controller conformance, and execution.
- `../hybrid/oracles/RHY203/`: a three-joint branching oracle spanning X/Y/Z
  axes and cylinder/capsule/sphere link geometry.

## Validation command

After exporting the oracle FMU:

```bash
python3 -m nl2robotics.contracts.cli \
  --ir nl2robotics/hybrid/oracles/RHY001/requirement_ir.json \
  --contract nl2robotics/hybrid/oracles/RHY001/contract.json \
  --fmu path/to/candidate.fmu \
  --usd nl2robotics/hybrid/oracles/RHY001/scene.usda \
  --output-dir path/to/contract-report
```

The report includes the resolved FMI value reference and numeric conversion,
plus the USD body/joint evidence used to accept the mapping.

The accepted contract can then be executed with the single H1 command described
in `../hybrid/README.md`.
