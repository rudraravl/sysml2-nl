# SysML Jupyter kernel — harness capabilities

This documents what the OMG Java SysML kernel (`org.omg.sysml.jupyter.kernel.ISysML`) supports for the execution harness, and how the Python bridge interacts with it.

## Headless execution path

Appending `package ExecutionHarness { ... }` to a candidate `.sysml` file and running it through the pipeline triggers real kernel evaluation — not parse-only loading.

### 1. Python bridge (communication)

- The candidate model and generated `ExecutionHarness` are concatenated into a single payload (`build_consolidated_payload`).
- [`sysml_runtime_bridge.py`](sysml_runtime_bridge.py) ships that payload headlessly via `jupyter_client` over ZeroMQ to the Jupyter SysML kernel (`client.execute(...)`).
- The `.sysml` text is a passive blueprint; execution happens inside the kernel after the payload is received.

### 2. Kernel internal evaluation

1. **Compilation and mapping** — The kernel translates SysML definitions into underlying KerML constructs and establishes initial states and active values in memory.
2. **Action container** — The harness target action (e.g. a probe of `'Provide Power'` or the composite `'provide power'`) is spun up as a live execution container.
3. **Asynchronous signal routing** — `send` does not push a signal into an input pin. It broadcasts a typed payload (e.g. `EngineStart`) into the execution space's event pool.
4. **Accept unblocking** — Internal `accept` blocks listening for that signal type catch the broadcast and unblock control flow.
5. **Logic progression** — The engine evaluates succession (`first` / `then`), internal transitions, and behavioral logic — advancing, dead-ending, or erroring as modeled.
6. **Scheduling** — `first` / `then` succession instructs the engine on chronological ordering of actions and triggers. Without succession, declared actions may compile but are not driven through an observable execution schedule.

### 3. Kernel output

- Execution is headless (no UI). When the run completes, the kernel returns structured messages to Python (stream, execute_result, execute_reply over Jupyter channels).
- For behavioral models, the response can include a **Discrete Execution Trace** — a sequential log of state changes, action boundaries, and event lifecycles that fired during the run.
- The orchestrator currently collects stdout/stderr lines into `ExecutionResult.trace`; richer JSON trace parsing is not yet implemented in the Python MVP.

## Confirmed patterns

| Pattern | Kernel behavior |
|---------|-----------------|
| Full model + `package ExecutionHarness` append | Loads all packages; may list package names and UUIDs |
| `action probe : 'ActionDef' { in pin = value; }` | **Compiles** — validated input binding pattern |
| `action def Probe { perform action x : 'ActionDef'; }` | **Compiles** — perform without inline assign block |
| `part testSubject : 'PartDef';` | **Compiles** — structural instantiation |
| `assert constraint name { subject.attr <= limit }` | **Compiles** when body is a boolean expression |
| `private import 'Root'::Definitions::*` | Parsed when root package and nested packages exist |
| `send <payload> to <target>` | **Executes** — broadcasts typed payload to the event pool |
| `accept <param>: <SignalType>` inside target action | **Executes** — listens for matching broadcast and unblocks flow |
| `first A;` / `first A then B;` | **Executes** — schedules chronological action and trigger order |

### Example: behavioral harness for 000200

A complete behavioral probe for models with accept/send control flow typically:

- Declares typed payload fixtures (`attribute testFuelCmd : FuelCmd;`, `attribute testStartSignal : EngineStart;`, …)
- Instantiates the target action with input bindings
- Uses `send` to inject signals into the execution event pool
- Uses `first` / `then` to schedule probe startup and trigger order

```sysml
action orchestrator {
    attribute testFuelCmd : FuelCmd;
    attribute testStartSignal : EngineStart;
    attribute testStopSignal : EngineOff;

    action provide_powerProbe : 'Provide Power' {
        in fuelCmd = testFuelCmd;
    }

    action triggerStart send testStartSignal to provide_powerProbe;
    action triggerStop send testStopSignal to provide_powerProbe;

    first provide_powerProbe;
    first triggerStart then triggerStop;
}
```

## Known limitations

| Pattern | Behavior |
|---------|----------|
| `perform` with inline `{ assign ... }` inside action def | **Parse error** — do not use |
| `attribute :>> attr = value` on default-valued attribute | **Error**: "Cannot override a binding feature value" |
| Constraint satisfaction reporting | No structured pass/fail in stdout (constraints must be expressed as assertable boolean bodies) |

## Current Python MVP gaps

The kernel supports headless send/accept and succession-driven execution. The **harness generator** ([`harness_builder.py`](harness_builder.py)) does not yet emit full behavioral harnesses for all extracted patterns:

| Capability | Kernel | Current generator |
|------------|--------|-------------------|
| Typed input binding (`in pin = fixture`) | Yes | Yes (auto via `vector_planner`) |
| `send` / `accept` triggering | Yes | Not generated — TODO stubs only |
| `first` / `then` succession | Yes | Not generated |
| Discrete execution trace consumption | Yes (in kernel output) | Not parsed — `trace` is raw stdout lines |
| Success criterion in orchestrator | Full execution possible | **Compile-only** — `success` = no `ERROR:` lines in output |

Until the generator emits `send`, payload fixtures for signal types, and `first`/`then` succession, a minimal probe (input binding only) may **compile** without driving observable behavioral execution.

## Re-run kernel spikes

```bash
python -m nl2sysml.sysml_execution.kernel_spike
```
