package AutomatonBasedSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percent :> Real {
        doc /* Ratio expressed from 0 to 100. */
        unit = "%";
    }

    attribute def TransitionCount :> Integer {
        doc /* Count of completed state transitions. */
    }

    attribute def EventRate :> Real {
        doc /* Events processed per second. */
        unit = "1/s";
    }

    attribute def Millisecond :> Real {
        doc /* Time duration in milliseconds. */
        unit = "ms";
    }

    enum def AutomatonMode {
        enum idle;
        enum acceptingInput;
        enum evaluatingTransition;
        enum executingOutput;
        enum faulted;
        enum shutdown;
    }

    enum def InputSymbol {
        enum start;
        enum stop;
        enum tick;
        enum reset;
        enum commandA;
        enum commandB;
        enum faultDetected;
    }

    enum def OutputSymbol {
        enum noOutput;
        enum accepted;
        enum rejected;
        enum actionA;
        enum actionB;
        enum faultReported;
        enum stopped;
    }

    item def InputEvent {
        attribute symbol : InputSymbol;
        attribute timestamp : Time;
        attribute sequenceNumber : Integer;
        attribute valid : Boolean;
    }

    item def OutputEvent {
        attribute symbol : OutputSymbol;
        attribute timestamp : Time;
        attribute originatingSequenceNumber : Integer;
        attribute accepted : Boolean;
    }

    item def StateVector {
        attribute mode : AutomatonMode;
        attribute currentStateId : Integer;
        attribute previousStateId : Integer;
        attribute transitionCounter : TransitionCount;
        attribute healthy : Boolean;
    }

    item def DiagnosticMessage {
        attribute faultCode : Integer;
        attribute severity : Integer;
        attribute descriptionCode : Integer;
        attribute timestamp : Time;
    }

    port def InputEventPort {
        in item event : InputEvent;
    }

    port def OutputEventPort {
        out item event : OutputEvent;
    }

    port def StateTelemetryPort {
        out item state : StateVector;
    }

    port def DiagnosticPort {
        out item message : DiagnosticMessage;
    }

    port def ClockPort {
        in item tick : InputEvent;
    }

    part def EventQueue {
        attribute capacity : Integer = 256;
        attribute queuedEvents : Integer;
        attribute utilization : Percent;

        port eventIn : InputEventPort;
        port eventOut : InputEventPort;

        action enqueue {
            in item received : InputEvent;
            out queued : Boolean;
        }

        action dequeue {
            out item next : InputEvent;
            out available : Boolean;
        }

        requirement queueCapacityRequirement {
            doc /* The event queue shall store at least 128 input events without loss. */
            require constraint { capacity >= 128 }
        }

        requirement queueUtilizationRequirement {
            doc /* The queue utilization shall remain within representable percentage limits. */
            require constraint { utilization >= 0.0 and utilization <= 100.0 }
        }
    }

    part def TransitionTable {
        attribute numberOfStates : Integer = 6;
        attribute numberOfSymbols : Integer = 7;
        attribute deterministic : Boolean = true;

        action resolveTransition {
            in currentStateId : Integer;
            in symbol : InputSymbol;
            out nextStateId : Integer;
            out output : OutputSymbol;
            out transitionDefined : Boolean;
        }

        requirement determinismRequirement {
            doc /* For each valid pair of current state and input symbol, the transition table shall resolve no more than one next state. */
            require constraint { deterministic == true }
        }
    }

    part def StateRegister {
        attribute state : StateVector;

        port telemetry : StateTelemetryPort;

        action initialize {
            out item initializedState : StateVector;
        }

        action update {
            in nextStateId : Integer;
            in nextMode : AutomatonMode;
            out item updatedState : StateVector;
        }

        action markFaulted {
            in faultCode : Integer;
            out item faultState : StateVector;
        }
    }

    part def OutputController {
        attribute emittedEvents : Integer;
        attribute maximumLatency : Millisecond = 25.0;

        port output : OutputEventPort;

        action emitOutput {
            in symbol : OutputSymbol;
            in originatingSequenceNumber : Integer;
            out item event : OutputEvent;
        }

        requirement outputLatencyRequirement {
            doc /* The output controller shall emit a resolved output event within 25 milliseconds of transition resolution. */
            require constraint { maximumLatency <= 25.0 }
        }
    }

    part def HealthMonitor {
        attribute heartbeatTimeout : Millisecond = 1000.0;
        attribute activeFaultCode : Integer = 0;
        attribute healthy : Boolean = true;

        port diagnostics : DiagnosticPort;

        action evaluateHealth {
            in item currentState : StateVector;
            in queuedEvents : Integer;
            out healthy : Boolean;
            out faultCode : Integer;
        }

        action reportFault {
            in faultCode : Integer;
            out item diagnostic : DiagnosticMessage;
        }

        requirement healthTimeoutRequirement {
            doc /* The health monitor shall declare a fault if no clock tick is observed within the heartbeat timeout. */
            require constraint { heartbeatTimeout <= 1000.0 }
        }
    }

    part def AutomatonController {
        doc /* Primary function: receive discrete input events, evaluate deterministic state transitions, update internal state, and emit corresponding output events. */

        attribute processingRate : EventRate;
        attribute transitionLatency : Millisecond;
        attribute availability : Percent;
        attribute currentMode : AutomatonMode;

        port externalInput : InputEventPort;
        port clock : ClockPort;
        port externalOutput : OutputEventPort;
        port telemetry : StateTelemetryPort;
        port diagnostics : DiagnosticPort;

        part queue : EventQueue;
        part table : TransitionTable;
        part register : StateRegister;
        part outputController : OutputController;
        part healthMonitor : HealthMonitor;

        connect externalInput.event to queue.eventIn.event;
        connect clock.tick to queue.eventIn.event;
        connect register.telemetry.state to telemetry.state;
        connect outputController.output.event to externalOutput.event;
        connect healthMonitor.diagnostics.message to diagnostics.message;

        action processOneEvent {
            in item event : InputEvent;
            out item resultingState : StateVector;
            out item resultingOutput : OutputEvent;

            first startProcessing;
            then validateInput;
            then resolveNextState;
            then commitState;
            then publishOutput;
            then finishProcessing;

            action startProcessing;
            action validateInput {
                in item event : InputEvent;
                out valid : Boolean;
            }
            action resolveNextState {
                in currentStateId : Integer;
                in symbol : InputSymbol;
                out nextStateId : Integer;
                out output : OutputSymbol;
                out transitionDefined : Boolean;
            }
            action commitState {
                in nextStateId : Integer;
                out item resultingState : StateVector;
            }
            action publishOutput {
                in symbol : OutputSymbol;
                out item resultingOutput : OutputEvent;
            }
            action finishProcessing;
        }

        action runCycle {
            out cycleComplete : Boolean;

            first readQueue;
            then decide;
            if decide.available then processOneEvent;
            else remainIdle;
            then evaluateHealth;
            then completeCycle;

            action readQueue {
                out item nextEvent : InputEvent;
                out available : Boolean;
            }
            action decide {
                in available : Boolean;
            }
            action remainIdle;
            action evaluateHealth;
            action completeCycle {
                out cycleComplete : Boolean;
            }
        }

        state automatonBehavior {
            entry action register.initialize;

            state idle;
            state acceptingInput;
            state evaluatingTransition;
            state executingOutput;
            state faulted;
            state shutdown;

            initial then idle;

            transition idle_to_accepting
                first idle
                accept InputEvent via externalInput
                if event.valid == true
                then acceptingInput;

            transition accepting_to_evaluating
                first acceptingInput
                do queue.enqueue
                then evaluatingTransition;

            transition evaluating_to_output
                first evaluatingTransition
                do table.resolveTransition
                then executingOutput;

            transition output_to_idle
                first executingOutput
                do outputController.emitOutput
                then idle;

            transition any_to_faulted_by_fault_symbol
                first idle
                accept InputEvent via externalInput
                if event.symbol == InputSymbol::faultDetected
                do register.markFaulted
                then faulted;

            transition evaluating_to_faulted_when_undefined
                first evaluatingTransition
                if false
                do healthMonitor.reportFault
                then faulted;

            transition faulted_to_idle_on_reset
                first faulted
                accept InputEvent via externalInput
                if event.symbol == InputSymbol::reset
                do register.initialize
                then idle;

            transition idle_to_shutdown_on_stop
                first idle
                accept InputEvent via externalInput
                if event.symbol == InputSymbol::stop
                then shutdown;
        }

        requirement primaryFunctionRequirement {
            doc /* The automaton controller shall transform validated discrete input events into deterministic state updates and output events. */
        }

        requirement transitionLatencyRequirement {
            doc /* The automaton controller shall complete event transition processing within 50 milliseconds. */
            require constraint { transitionLatency <= 50.0 }
        }

        requirement processingRateRequirement {
            doc /* The automaton controller shall process at least 20 input events per second during nominal operation. */
            require constraint { processingRate >= 20.0 }
        }

        requirement availabilityRequirement {
            doc /* The automaton controller shall maintain at least 99 percent operational availability while not faulted or shut down. */
            require constraint { availability >= 99.0 }
        }
    }

    part def OperatorInterface {
        port commandOutput : InputEventPort;
        port eventInput : OutputEventPort;
        port stateInput : StateTelemetryPort;
        port diagnosticInput : DiagnosticPort;

        action submitCommand {
            in symbol : InputSymbol;
            out item command : InputEvent;
        }

        action displayState {
            in item state : StateVector;
        }

        action displayOutput {
            in item event : OutputEvent;
        }

        action displayDiagnostic {
            in item message : DiagnosticMessage;
        }
    }

    part def AutomatonSystem {
        doc /* The system is based on a finite automaton. Its primary high-level function is to coordinate discrete event-driven behavior by accepting input symbols, selecting deterministic transitions, updating the active state, and producing output symbols for downstream use. */

        attribute nominalVoltage : ElectricPotential = 24.0 [V];
        attribute maximumPower : Power = 60.0 [W];
        attribute startupTime : Millisecond = 500.0;

        part automaton : AutomatonController;
        part operatorInterface : OperatorInterface;

        port input : InputEventPort;
        port output : OutputEventPort;
        port stateTelemetry : StateTelemetryPort;
        port diagnosticOutput : DiagnosticPort;

        connect input.event to automaton.externalInput.event;
        connect operatorInterface.commandOutput.event to automaton.externalInput.event;
        connect automaton.externalOutput.event to output.event;
        connect automaton.externalOutput.event to operatorInterface.eventInput.event;
        connect automaton.telemetry.state to stateTelemetry.state;
        connect automaton.telemetry.state to operatorInterface.stateInput.state;
        connect automaton.diagnostics.message to diagnosticOutput.message;
        connect automaton.diagnostics.message to operatorInterface.diagnosticInput.message;

        action startSystem {
            out started : Boolean;

            first energize;
            then initializeAutomaton;
            then verifyHealth;
            then enterIdle;

            action energize;
            action initializeAutomaton;
            action verifyHealth {
                out healthy : Boolean;
            }
            action enterIdle {
                out started : Boolean;
            }
        }

        action stopSystem {
            out stopped : Boolean;

            first requestStop;
            then drainQueue;
            then emitStopped;
            then removePower;

            action requestStop;
            action drainQueue;
            action emitStopped;
            action removePower {
                out stopped : Boolean;
            }
        }

        requirement systemPurposeRequirement {
            doc /* The system shall provide high-level automaton-based control by mapping input symbols and current state to deterministic output symbols and next state. */
        }

        requirement startupRequirement {
            doc /* The system shall complete startup and enter idle mode within 500 milliseconds after power is applied. */
            require constraint { startupTime <= 500.0 }
        }

        requirement powerRequirement {
            doc /* The system shall consume no more than 60 watts during nominal processing. */
            require constraint { maximumPower <= 60.0 [W] }
        }

        requirement voltageRequirement {
            doc /* The system shall operate from a 24 volt nominal supply. */
            require constraint { nominalVoltage == 24.0 [V] }
        }
    }

    requirement def AutomatonSystemRequirement {
        doc /* Requirements for an event-driven automaton system. */

        requirement deterministicBehavior {
            doc /* For a given current state and input symbol, the system shall select exactly one next state and one output symbol when the transition is defined. */
        }

        requirement observableState {
            doc /* The system shall publish the active state, previous state, transition count, and health status as telemetry. */
        }

        requirement faultHandling {
            doc /* The system shall enter a faulted state when a fault input is received or health monitoring detects an unrecoverable condition. */
        }

        requirement resetCapability {
            doc /* The system shall return from the faulted state to the initialized idle state after receiving a valid reset input. */
        }
    }

    satisfy AutomatonSystem::systemPurposeRequirement by AutomatonSystem::automaton;
    satisfy AutomatonSystemRequirement::deterministicBehavior by AutomatonController::table;
    satisfy AutomatonSystemRequirement::observableState by AutomatonController::register;
    satisfy AutomatonSystemRequirement::faultHandling by AutomatonController::healthMonitor;
    satisfy AutomatonSystemRequirement::resetCapability by AutomatonController::automatonBehavior;
}