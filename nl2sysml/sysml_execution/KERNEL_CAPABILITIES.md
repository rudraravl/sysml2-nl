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
| `private import 'Root'::*` | Parsed for flat packages; exposes all definitions in the root namespace |
| `send <payload> to <target>` | **Executes** — broadcasts typed payload to the event pool |
| `accept <param>: <SignalType>` inside target action | **Executes** — listens for matching broadcast and unblocks flow |
| `first A;` / `then B;` / `then C;` | **Executes** — each succession step is its own statement |
| `send` / `accept` / `first`/`then` succession | **Generated** — full behavioral harness emitted for action-probe models (e.g. 000200) |

### Example: behavioral harness for 000200

A complete behavioral probe for models with accept/send control flow typically:

- Declares typed payload fixtures (`attribute testFuelCmd : FuelCmd;`, `attribute testStartSignal : EngineStart;`, …)
- Instantiates the target action with input bindings
- Uses `send` to inject signals into the execution event pool
- Uses `first` / `then` to schedule probe startup and trigger order

`simulation_vectors` can override trigger payload members via `:>>` redefinition syntax (keyed by trigger param name, then payload type):

```sysml
attribute testEngineStart : EngineStart { :>> voltage = 12.0; }
```

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
    then triggerStart;
    then triggerStop;
}
```

## Two-pass payload resolution

The harness generator uses a two-pass strategy to handle models where accept signal types are referenced but never defined (e.g., `accept StartCalibration` with no corresponding `attribute def StartCalibration`).

**Pass 1 — Extraction** (`collect_state_machine_accept_payloads` in `extractor.py`): scan every transition in every extracted state machine and collect the payload type names of all `accept` edges. This includes off-path transitions (e.g. `AcknowledgeAlarm` on an alarm branch) because the kernel's AST parser requires type definitions for every accept signal in the source, not just the ones reached at runtime.

**Pass 2 — Semantic resolution** (`resolve_payload_types` in `vector_planner.py`): for each collected payload name, check whether a definition exists in the extracted topology (attribute def, item def, enum def, primitive, or known external value type). Payloads with no definition are classified as `missing`.

**Mock injection** (`inject_mock_defs_into_root_package`): `attribute def T;` stubs are inserted immediately after the root package's opening brace in the consolidated payload. This happens before the `ExecutionHarness` package, so the kernel's sequential parser can resolve every accept type before encountering the harness. Types already defined anywhere in the candidate are skipped.

### Import strategy

Harnesses now emit a single `private import RootPackage::*;` line instead of separate `::Definitions::*` and `::Usages::*` lines. This works for both flat single-package models (like `EsophagealDopplerMonitoringSystem`) and nested models (like `'3a-Function-based Behavior-1'`), since the wildcard import resolves transitively through nested packages.

## State machine patterns (unconfirmed — pending kernel validation)

State machines reuse the same `accept`/`send` mechanics as actions, but the `accept` is
bound to a `transition` instead of sitting bare in an action body, and driving one
requires sending to the *instance that exhibits it* (a bare `send X;` has no state
machine to dispatch into). The generator ([`harness_builder.py`](harness_builder.py))
now emits these patterns, but — unlike the "Confirmed patterns" above — they have not
yet been run against a live kernel in this environment (`jupyter_client` unavailable).
Re-run `python -m nl2sysml.sysml_execution.kernel_spike` once a kernel is reachable and
promote rows below into "Confirmed patterns" as they're verified.

| Pattern | Expected kernel behavior | Spike |
|---------|--------------------------|-------|
| `part testSubject : 'PartDef' { exhibit state <usage> : 'SMDef'; }` | Instantiates the part; exhibited behaviors start automatically in the background | `state_machine_targeted_send` |
| `send <payload> to testSubject.<usage>;` (dot-notation targeting the exhibited SM) | Routes signal into the specific state machine instance; avoids broadcast ambiguity when a part exhibits multiple behaviors | `state_machine_targeted_send` |
| `accept Signal [attr > value]` (guard on a transition) | Only fires when the guard evaluates true against the instance's current attribute value | `state_machine_part_override` |
| `part testSubject : 'PartDef' { :>> attr = value; exhibit state <usage> : 'SMDef'; }` | Overrides a non-default-valued structural attribute on the instance so a guard is satisfied before the triggering signal is sent | `state_machine_part_override` |
| Orchestrator with probe + part subject (no `first` on the part) | Part behaviors run concurrently; orchestrator sequences only its own probe and `send` actions | `fork_action_and_state_machine` |

### Example: state-machine harness (with two-pass mock injection)

For a model like 000600 where `StartCalibration` / `StopMonitoring` / `AcknowledgeAlarm` have no definitions, the generator:

1. Injects mock stubs into the root package (inside `EsophagealDopplerMonitoringSystem { … }`):

```sysml
    attribute def StartCalibration;
    attribute def StopMonitoring;
    attribute def AcknowledgeAlarm;
```

2. Emits the harness with dot-notation sends and a combined succession chain:

```sysml
package ExecutionHarness {
    private import EsophagealDopplerMonitoringSystem::*;

    part testSubject : EsophagealDopplerSystem {
        exhibit state operationalStates : SystemOperationalStates;
    }

    action orchestrator {
        attribute testPatientHeight : LengthValue;
        attribute testPatientWeight : MassValue;
        attribute testPatientAge : TimeValue;
        action estimateDiameterProbe : EstimateAorticDiameter {
            in patientHeight = testPatientHeight;
            in patientWeight = testPatientWeight;
            in patientAge = testPatientAge;
        }
        attribute testStartCalibration : StartCalibration;
        attribute testStopMonitoring : StopMonitoring;
        action triggerStartCalibration send testStartCalibration to testSubject.operationalStates;
        action triggerStopMonitoring send testStopMonitoring to testSubject.operationalStates;
        first estimateDiameterProbe;
        then triggerStartCalibration;
        then triggerStopMonitoring;
    }
}
```

The guard override (`:>> attr = value`) is computed via `satisfying_value_for_guard`; the trigger order comes from walking the state graph from `entry` via `ordered_transition_path`. The test subject is not scheduled in the orchestrator — exhibited behaviors start automatically.

## Known limitations

| Pattern | Behavior |
|---------|----------|
| `perform` with inline `{ assign ... }` inside action def | **Parse error** — do not use |
| `attribute :>> attr = value` on default-valued attribute | **Error**: "Cannot override a binding feature value" |
| Constraint satisfaction reporting | No structured pass/fail in stdout (constraints must be expressed as assertable boolean bodies) |
| `if`-guarded transitions | Not driveable; harness only sequences `accept`-triggered edges |
| Off-path accept transitions (e.g. alarm branch) | Mock defs injected for parser resolution, but no `send` generated (only path transitions get sends) |

## Current Python MVP gaps

| Capability | Kernel | Current generator |
|------------|--------|-------------------|
| Typed input binding (`in pin = fixture`) | Yes | Yes (auto via `vector_planner`) |
| `send` / `accept` triggering for action probes | Yes | Yes — full sends and succession chain generated |
| `send` to state machine (dot-notation target) | Yes (expected) | Yes — `send X to instance.usage` generated |
| Root-package mock injection for undefined accept types | N/A | Yes — `attribute def T;` injected before harness |
| `first` / `then` succession | Yes | Yes — single combined chain across probe and SM triggers |
| Discrete execution trace consumption | Yes (in kernel output) | Not parsed — `trace` is raw stdout lines |
| Success criterion in orchestrator | Full execution possible | **Compile-only** — `success` = no `ERROR:` lines in output |
| State machine targeted send / guard overrides / concurrent part + orchestrator | Unconfirmed (see "State machine patterns" above) | Generated, not yet kernel-validated |

## Re-run kernel spikes

```bash
python -m nl2sysml.sysml_execution.kernel_spike
```
