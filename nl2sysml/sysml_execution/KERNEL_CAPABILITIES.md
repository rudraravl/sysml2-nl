# SysML Jupyter kernel — MVP harness capabilities

This documents what the OMG Java SysML kernel (`org.omg.sysml.jupyter.kernel.ISysML`) supports for the execution harness, based on local spike runs (June 2026).

## Confirmed (parse / load)

| Pattern | Kernel behavior |
|---------|-----------------|
| Full model + `package ExecutionHarness` append | Loads all packages; stdout lists package names and UUIDs |
| `action probe : 'ActionDef' { in pin = value; }` | **Compiles** — validated input binding pattern |
| `action def Probe { perform action x : 'ActionDef'; }` | **Compiles** — perform without inline assign block |
| `part testSubject : 'PartDef';` | **Compiles** — structural instantiation |
| `assert constraint name { subject.attr <= limit }` | **Compiles** when body is a boolean expression |
| `private import 'Root'::Definitions::*` | Parsed when root package and nested packages exist |

## Not observed (simulation / runtime)

| Pattern | Current behavior |
|---------|------------------|
| `perform` with inline `{ assign ... }` inside action def | **Parse error** — do not use |
| `attribute :>> attr = value` on default-valued attribute | **Error**: "Cannot override a binding feature value" |
| `perform` on state machines / stepping transitions | No execution trace in stdout |
| `send` / triggering `accept` actions | No documented headless API |
| Constraint satisfaction reporting | No structured pass/fail in stdout |

## MVP strategy

1. **Success = clean compile** — model + harness loads without `ERROR:` lines.
2. **Action probes** — bind `in` pins via `action probe : 'Type' { in pin = value; }`.
3. **Structural probes** — instantiate `part testSubject : 'PartDef';`; assert constraints only when boolean body is known.
4. **TODO(human)** — simulation vector generation, default-attr override, accept/send triggering, state-machine stepping.

Re-run spikes after kernel upgrades:

```bash
python -m nl2sysml.sysml_execution.kernel_spike
```
