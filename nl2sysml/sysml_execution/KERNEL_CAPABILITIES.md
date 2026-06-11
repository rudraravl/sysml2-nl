# SysML Jupyter kernel — Layer 2 capabilities

This documents what the OMG Java SysML kernel (`org.omg.sysml.jupyter.kernel.ISysML`) supports for the execution harness, based on local spike runs and observed production behavior.

## Confirmed (parse / load)

| Pattern | Kernel behavior |
|---------|-----------------|
| Full model + `package ExecutionHarness` append | Loads all packages; stdout lists package names and UUIDs |
| `action def`, composite `action` usages, `flow`, `first`/`then`, `accept` | Parsed if syntactically valid |
| Input values inside performed actions (`in pin = value;`) | Accepted at parse time |
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
| Generic part/state execution probe | Not supported; harness emits a typed structural part probe only |

## Verification levels

The result fields deliberately separate what the kernel actually demonstrated:

| Level | Meaning |
|-------|---------|
| `syntax_compiled` | Untouched model compiled in the kernel |
| `structural_harness_compiled` | Model plus generated structural harness compiled |
| `input_harness_compiled` | Model plus harness compiled with injected input values |
| `behavior_observed` | Kernel emitted an explicit action/state/constraint result |

`input_harness_compiled` is not called simulation. The current reference kernel normally
does not emit runtime traces, so `behavior_observed` is expected to remain false.

## Layer 2 strategy in this repo

Until the kernel or SysML API Services exposes evaluation/simulation:

1. **Baseline compilation** — compile the untouched candidate separately from the harness.
2. **Structural reachability** — harness must reference candidate parts/actions and compile without `ERROR:`.
3. **Input injection** — provide type-aware preset values only for constructible input pins.
4. **Fail closed** — never infer behavioral verification from clean harness compilation.
5. **ANALYSIS_TOOL** — models with `metadata ToolExecution` only: external tool is not invoked.

## Preset fallback vectors

For underspecified action inputs, callers may set `try_preset_vectors=True` or pass
`--try-preset-vectors`. The orchestrator tries bounded preset values until the kernel
accepts the model plus harness. Results are labeled `vector_source=preset_fallback` and
`semantic_validity=unknown`; acceptance does not prove the values are valid engineering inputs.

Preset fallback is only attempted for typed scalar/quantity-like input pins. Structured inputs
(for example `CartInput`) and untyped inputs are reported as
`inputs_detected_but_not_constructible`; the runner does not pretend a scalar preset is valid
for them. The harness reproduces candidate imports so imported action types remain resolvable.

The corpus runner probes every typed action usage with required inputs. Models without those
targets still receive the strongest available structural/state harness, but their result is
explicitly labeled as not being an input-vector test. State-machine advancement and event
injection remain unsupported by the current headless kernel.

Re-run probes after kernel upgrades:

```bash
python -m nl2sysml.sysml_execution.kernel_spike
```

Run a resumable pilot:

```bash
./nl2sysml/sysml_execution/run_corpus.sh --limit 20
```

Run or resume the full corpus:

```bash
./nl2sysml/sysml_execution/run_corpus.sh
```

The schema-v3 run writes to `results/sysml_execution_corpus_v3/` and resumes existing results.
Important outputs:

- `summary.csv`: one row per model
- `targets.csv`: one row per tested action target
- `audit.json`: defensible experiment totals
- `<model_id>.json`: baseline output plus complete harness/target outputs
- `run.log`: live console output
