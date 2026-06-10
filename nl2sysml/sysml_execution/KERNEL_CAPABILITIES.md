# SysML Jupyter kernel — Layer 2 capabilities

This documents what the OMG Java SysML kernel (`org.omg.sysml.jupyter.kernel.ISysML`) supports for the execution harness, based on local spike runs and observed production behavior.

## Confirmed (parse / load)

| Pattern | Kernel behavior |
|---------|-----------------|
| Full model + `package ExecutionHarness` append | Loads all packages; stdout lists package names and UUIDs |
| `action def`, composite `action` usages, `flow`, `first`/`then`, `accept` | Parsed if syntactically valid |
| `assign` inside action bodies | Accepted at parse time when types resolve |
| `perform action 'usage': 'ActionDef'` | Preferred harness pattern for composite actions (not `action run : 'usage'`) |
| `assert <constraintName>` | Parsed; **no** pass/fail output in stdout unless kernel adds evaluation later |
| `private import 'Root'::Usages::*` | Parsed when root package and nested packages exist |

## Not observed (simulation / runtime)

| Pattern | Current behavior |
|---------|------------------|
| `perform` on state machines / actions | No execution trace in `text/plain` output |
| `send` / triggering `accept` actions | No documented magic in headless execute; harness uses TODO comments |
| Item-flow value propagation (`wheelTorque1`, etc.) | Not verified at runtime |
| Constraint satisfaction reporting | No structured manifest in kernel stdout |

## Layer 2 strategy in this repo

Until the kernel or SysML API Services exposes evaluation/simulation:

1. **Structural reachability** — harness must reference the candidate composite action, bind `in` pins via `assign`, and compile without `ERROR:` (fail closed if probes cannot be generated).
2. **Fail closed** — models with `ACTION_COMPOSITE` / `PART_STATE` profiles get `success=false` when `probes_runnable` is false (e.g. missing `simulation_vectors` for required input pins).
3. **ANALYSIS_TOOL** — models with `metadata ToolExecution` only: `layer2_status=not_required` (external tool not invoked).

## Preset fallback vectors

For underspecified action inputs, callers may set `try_preset_vectors=True` or pass
`--try-preset-vectors`. The orchestrator tries bounded preset values until the kernel
accepts the model plus harness. Results are labeled `vector_source=preset_fallback` and
`semantic_validity=unknown`; acceptance does not prove the values are valid engineering inputs.

Re-run probes after kernel upgrades:

```bash
python -m nl2sysml.sysml_execution.kernel_spike
```
