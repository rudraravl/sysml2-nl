package AutomatonBasedSystemModel {
    import ScalarValues::*;

    attribute def Voltage {
        attribute value : Real;
        attribute unit : String = "V";
    }

    attribute def ElectricCurrent {
        attribute value : Real;
        attribute unit : String = "A";
    }

    attribute def ElectricPower {
        attribute value : Real;
        attribute unit : String = "W";
    }

    attribute def Duration {
        attribute value : Real;
        attribute unit : String = "s";
    }

    attribute def Frequency {
        attribute value : Real;
        attribute unit : String = "Hz";
    }

    attribute def Probability {
        attribute value : Real;
        attribute unit : String = "1";
    }

    attribute def DataRate {
        attribute value : Real;
        attribute unit : String = "bit/s";
    }

    attribute def Temperature {
        attribute value : Real;
        attribute unit : String = "degC";
    }

    attribute def Count {
        attribute value : Integer;
        attribute unit : String = "count";
    }

    attribute def TimeStamp {
        attribute value : Real;
        attribute unit : String = "s";
    }

    enum def AutomatonStateKind {
        enum poweredOff;
        enum initializing;
        enum idle;
        enum monitoring;
        enum evaluating;
        enum commanding;
        enum verifying;
        enum safeHalt;
        enum fault;
    }

    enum def EventKind {
        enum powerApplied;
        enum initializationComplete;
        enum objectDetected;
        enum objectCleared;
        enum commandAcknowledged;
        enum timeoutExpired;
        enum operatorStart;
        enum operatorStop;
        enum emergencyStopPressed;
        enum diagnosticFailed;
        enum diagnosticPassed;
        enum resetRequested;
    }

    enum def CommandKind {
        enum noCommand;
        enum enableMonitoring;
        enum stopMotion;
        enum openGate;
        enum closeGate;
        enum holdGate;
        enum enterSafeHalt;
        enum clearFault;
        enum requestDiagnostic;
        enum publishStatus;
    }

    enum def HealthKind {
        enum nominal;
        enum degraded;
        enum unsafe;
        enum failed;
    }

    enum def SafetyIntegrityKind {
        enum standard;
        enum enhanced;
        enum failSafe;
    }

    item def DiscreteEvent {
        attribute kind : EventKind;
        attribute detectedAt : TimeStamp;
        attribute confidence : Probability;
        attribute sourceId : String;
    }

    item def ActuatorCommand {
        attribute kind : CommandKind;
        attribute issuedAt : TimeStamp;
        attribute commandId : Count;
        attribute targetId : String;
    }

    item def StateReport {
        attribute currentState : AutomatonStateKind;
        attribute previousState : AutomatonStateKind;
        attribute lastEvent : EventKind;
        attribute health : HealthKind;
        attribute reportTime : TimeStamp;
    }

    item def DiagnosticResult {
        attribute passed : Boolean;
        attribute measuredLatency : Duration;
        attribute measuredEventRate : Frequency;
        attribute controllerTemperature : Temperature;
        attribute health : HealthKind;
    }

    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute current : ElectricCurrent;
        attribute power : ElectricPower;
    }

    item def OperatorInstruction {
        attribute requestedEvent : EventKind;
        attribute operatorId : String;
        attribute requestTime : TimeStamp;
    }

    item def LoggedRecord {
        attribute stateBefore : AutomatonStateKind;
        attribute acceptedEvent : EventKind;
        attribute stateAfter : AutomatonStateKind;
        attribute emittedCommand : CommandKind;
        attribute recordTime : TimeStamp;
    }

    port def EventInPort {
        in item event : DiscreteEvent;
    }

    port def EventOutPort {
        out item event : DiscreteEvent;
    }

    port def CommandInPort {
        in item command : ActuatorCommand;
    }

    port def CommandOutPort {
        out item command : ActuatorCommand;
    }

    port def StateReportInPort {
        in item report : StateReport;
    }

    port def StateReportOutPort {
        out item report : StateReport;
    }

    port def DiagnosticOutPort {
        out item result : DiagnosticResult;
    }

    port def DiagnosticInPort {
        in item result : DiagnosticResult;
    }

    port def PowerInPort {
        in item energy : ElectricalEnergy;
    }

    port def PowerOutPort {
        out item energy : ElectricalEnergy;
    }

    port def OperatorInPort {
        in item instruction : OperatorInstruction;
    }

    port def LogInPort {
        in item record : LoggedRecord;
    }

    action def SenseDiscreteEnvironment {
        out item sensedEvent : DiscreteEvent;
        attribute samplePeriod : Duration;
        attribute minimumConfidence : Probability;
    }

    action def EvaluateAutomatonTransition {
        in item incomingEvent : DiscreteEvent;
        in currentState : AutomatonStateKind;
        out nextState : AutomatonStateKind;
        out item command : ActuatorCommand;
        attribute maximumEvaluationTime : Duration;
    }

    action def IssueControlCommand {
        in item command : ActuatorCommand;
        out item commandAcknowledgedEvent : DiscreteEvent;
        attribute maximumCommandLatency : Duration;
    }

    action def VerifyCommandEffect {
        in expectedState : AutomatonStateKind;
        in item verificationEvent : DiscreteEvent;
        out verificationPassed : Boolean;
        attribute verificationTimeout : Duration;
    }

    action def PublishState {
        in currentState : AutomatonStateKind;
        in previousState : AutomatonStateKind;
        in item lastEvent : DiscreteEvent;
        out item report : StateReport;
        attribute publishPeriod : Duration;
    }

    action def RecordTransition {
        in stateBefore : AutomatonStateKind;
        in item acceptedEvent : DiscreteEvent;
        in stateAfter : AutomatonStateKind;
        in item emittedCommand : ActuatorCommand;
        out item record : LoggedRecord;
    }

    action def PerformPrimaryAutomatonFunction {
        doc /* The primary function is to observe discrete external events, evaluate them with a deterministic finite automaton, transition to the proper operating state, and issue the high-level command that keeps the controlled process orderly and safe. */
        in item observedEvent : DiscreteEvent;
        in currentState : AutomatonStateKind;
        out nextState : AutomatonStateKind;
        out item emittedCommand : ActuatorCommand;

        action evaluate : EvaluateAutomatonTransition {
            in item incomingEvent = observedEvent;
            in currentState = currentState;
            out nextState = nextState;
            out item command = emittedCommand;
        }
    }

    state def AutomatonBehavior {
        attribute minimumEventConfidence : Probability;
        attribute commandTimeout : Duration;
        attribute verificationTimeout : Duration;

        state poweredOff;
        state initializing;
        state idle;
        state monitoring;
        state evaluating;
        state commanding;
        state verifying;
        state safeHalt;
        state fault;

        transition powerOn
            first poweredOff
            accept DiscreteEvent
            if event.kind == EventKind::powerApplied
            then initializing;

        transition initialized
            first initializing
            accept DiscreteEvent
            if event.kind == EventKind::initializationComplete
            then idle;

        transition startMonitoring
            first idle
            accept DiscreteEvent
            if event.kind == EventKind::operatorStart
            then monitoring;

        transition detectObject
            first monitoring
            accept DiscreteEvent
            if event.kind == EventKind::objectDetected and event.confidence.value >= minimumEventConfidence.value
            then evaluating;

        transition evaluateToCommand
            first evaluating
            then commanding;

        transition commandAcknowledged
            first commanding
            accept DiscreteEvent
            if event.kind == EventKind::commandAcknowledged
            then verifying;

        transition verificationComplete
            first verifying
            accept DiscreteEvent
            if event.kind == EventKind::objectCleared
            then monitoring;

        transition stopFromIdle
            first idle
            accept DiscreteEvent
            if event.kind == EventKind::operatorStop
            then safeHalt;

        transition stopFromMonitoring
            first monitoring
            accept DiscreteEvent
            if event.kind == EventKind::operatorStop
            then safeHalt;

        transition emergencyFromAnyMonitoringState
            first monitoring
            accept DiscreteEvent
            if event.kind == EventKind::emergencyStopPressed
            then safeHalt;

        transition emergencyFromCommanding
            first commanding
            accept DiscreteEvent
            if event.kind == EventKind::emergencyStopPressed
            then safeHalt;

        transition timeoutDuringCommand
            first commanding
            accept DiscreteEvent
            if event.kind == EventKind::timeoutExpired
            then fault;

        transition failedDiagnostic
            first initializing
            accept DiscreteEvent
            if event.kind == EventKind::diagnosticFailed
            then fault;

        transition resetFault
            first fault
            accept DiscreteEvent
            if event.kind == EventKind::resetRequested
            then initializing;

        transition restartAfterSafeHalt
            first safeHalt
            accept DiscreteEvent
            if event.kind == EventKind::resetRequested
            then initializing;
    }

    part def TransitionRule {
        attribute sourceState : AutomatonStateKind;
        attribute triggeringEvent : EventKind;
        attribute targetState : AutomatonStateKind;
        attribute emittedCommand : CommandKind;
        attribute maximumAllowedTransitionTime : Duration;
    }

    part def TransitionTable {
        part powerAppliedRule : TransitionRule {
            attribute sourceState = AutomatonStateKind::poweredOff;
            attribute triggeringEvent = EventKind::powerApplied;
            attribute targetState = AutomatonStateKind::initializing;
            attribute emittedCommand = CommandKind::requestDiagnostic;
        }

        part initializationCompleteRule : TransitionRule {
            attribute sourceState = AutomatonStateKind::initializing;
            attribute triggeringEvent = EventKind::initializationComplete;
            attribute targetState = AutomatonStateKind::idle;
            attribute emittedCommand = CommandKind::publishStatus;
        }

        part operatorStartRule : TransitionRule {
            attribute sourceState = AutomatonStateKind::idle;
            attribute triggeringEvent = EventKind::operatorStart;
            attribute targetState = AutomatonStateKind::monitoring;
            attribute emittedCommand = CommandKind::enableMonitoring;
        }

        part objectDetectedRule : TransitionRule {
            attribute sourceState = AutomatonStateKind::monitoring;
            attribute triggeringEvent = EventKind::objectDetected;
            attribute targetState = AutomatonStateKind::commanding;
            attribute emittedCommand = CommandKind::openGate;
        }

        part objectClearedRule : TransitionRule {
            attribute sourceState = AutomatonStateKind::verifying;
            attribute triggeringEvent = EventKind::objectCleared;
            attribute targetState = AutomatonStateKind::monitoring;
            attribute emittedCommand = CommandKind::closeGate;
        }

        part operatorStopRule : TransitionRule {
            attribute sourceState = AutomatonStateKind::monitoring;
            attribute triggeringEvent = EventKind::operatorStop;
            attribute targetState = AutomatonStateKind::safeHalt;
            attribute emittedCommand = CommandKind::stopMotion;
        }

        part emergencyStopRule : TransitionRule {
            attribute sourceState = AutomatonStateKind::commanding;
            attribute triggeringEvent = EventKind::emergencyStopPressed;
            attribute targetState = AutomatonStateKind::safeHalt;
            attribute emittedCommand = CommandKind::enterSafeHalt;
        }

        part timeoutRule : TransitionRule {
            attribute sourceState = AutomatonStateKind::commanding;
            attribute triggeringEvent = EventKind::timeoutExpired;
            attribute targetState = AutomatonStateKind::fault;
            attribute emittedCommand = CommandKind::stopMotion;
        }
    }

    part def EventSensorArray {
        port powerIn : PowerInPort;
        port eventOut : EventOutPort;
        port diagnosticOut : DiagnosticOutPort;

        attribute sampleRate : Frequency;
        attribute detectionConfidence : Probability;
        attribute selfTestInterval : Duration;
        attribute sensorHealth : HealthKind;

        perform action sense : SenseDiscreteEnvironment {
            out item sensedEvent = eventOut.event;
            attribute samplePeriod : Duration;
            attribute minimumConfidence : Probability;
        }
    }

    part def AutomatonController {
        port powerIn : PowerInPort;
        port eventIn : EventInPort;
        port commandOut : CommandOutPort;
        port stateOut : StateReportOutPort;
        port diagnosticIn : DiagnosticInPort;
        port operatorIn : OperatorInPort;

        part transitionTable : TransitionTable;

        attribute currentState : AutomatonStateKind;
        attribute previousState : AutomatonStateKind;
        attribute lastEventKind : EventKind;
        attribute safetyIntegrity : SafetyIntegrityKind;
        attribute processingClock : Frequency;
        attribute maximumEvaluationLatency : Duration;
        attribute minimumConfidenceAccepted : Probability;
        attribute controllerHealth : HealthKind;

        exhibit state behavior : AutomatonBehavior;

        perform action primaryFunction : PerformPrimaryAutomatonFunction {
            in item observedEvent = eventIn.event;
            in currentState = currentState;
            out nextState = currentState;
            out item emittedCommand = commandOut.command;
        }

        perform action publishState : PublishState {
            in currentState = currentState;
            in previousState = previousState;
            out item report = stateOut.report;
        }
    }

    part def ActuatorInterface {
        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
        port eventOut : EventOutPort;

        attribute commandLatency : Duration;
        attribute actuatorHealth : HealthKind;
        attribute commandedPositionOpen : Boolean;
        attribute actualPositionOpen : Boolean;

        perform action issueCommand : IssueControlCommand {
            in item command = commandIn.command;
            out item commandAcknowledgedEvent = eventOut.event;
        }
    }

    part def HumanMachineInterface {
        port powerIn : PowerInPort;
        port operatorOut : OperatorInPort;
        port stateIn : StateReportInPort;

        attribute displayRefreshPeriod : Duration;
        attribute operatorCommandDebounce : Duration;
        attribute hmiHealth : HealthKind;
    }

    part def PowerSupply {
        port powerOutToController : PowerOutPort;
        port powerOutToSensors : PowerOutPort;
        port powerOutToActuator : PowerOutPort;
        port powerOutToHmi : PowerOutPort;
        port powerOutToLogger : PowerOutPort;

        attribute nominalVoltage : Voltage;
        attribute maximumCurrent : ElectricCurrent;
        attribute nominalPower : ElectricPower;
        attribute holdUpTime : Duration;
        attribute powerHealth : HealthKind;
    }

    part def TransitionLogger {
        port powerIn : PowerInPort;
        port stateIn : StateReportInPort;
        port logIn : LogInPort;

        attribute storageCapacity : Count;
        attribute writeLatency : Duration;
        attribute logDataRate : DataRate;
        attribute loggerHealth : HealthKind;

        perform action record : RecordTransition {
            in stateBefore = stateIn.report.previousState;
            in stateAfter = stateIn.report.currentState;
            out item record = logIn.record;
        }
    }

    part def AutomatonControlledGateSystem {
        doc /* A system based on a deterministic finite automaton. Its high-level primary function is to convert sensed discrete events and operator requests into safe, deterministic gate-control commands through explicit states and transition rules. */

        port externalPowerIn : PowerInPort;
        port externalOperatorIn : OperatorInPort;
        port externalStateOut : StateReportOutPort;

        part powerSupply : PowerSupply {
            attribute nominalVoltage : Voltage {
                attribute value = 24.0;
                attribute unit = "V";
            }
            attribute maximumCurrent : ElectricCurrent {
                attribute value = 10.0;
                attribute unit = "A";
            }
            attribute nominalPower : ElectricPower {
                attribute value = 240.0;
                attribute unit = "W";
            }
            attribute holdUpTime : Duration {
                attribute value = 2.0;
                attribute unit = "s";
            }
            attribute powerHealth = HealthKind::nominal;
        }

        part sensors : EventSensorArray {
            attribute sampleRate : Frequency {
                attribute value = 100.0;
                attribute unit = "Hz";
            }
            attribute detectionConfidence : Probability {
                attribute value = 0.995;
                attribute unit = "1";
            }
            attribute selfTestInterval : Duration {
                attribute value = 10.0;
                attribute unit = "s";
            }
            attribute sensorHealth = HealthKind::nominal;
        }

        part controller : AutomatonController {
            attribute currentState = AutomatonStateKind::poweredOff;
            attribute previousState = AutomatonStateKind::poweredOff;
            attribute lastEventKind = EventKind::powerApplied;
            attribute safetyIntegrity = SafetyIntegrityKind::failSafe;
            attribute processingClock : Frequency {
                attribute value = 1000000.0;
                attribute unit = "Hz";
            }
            attribute maximumEvaluationLatency : Duration {
                attribute value = 0.010;
                attribute unit = "s";
            }
            attribute minimumConfidenceAccepted : Probability {
                attribute value = 0.980;
                attribute unit = "1";
            }
            attribute controllerHealth = HealthKind::nominal;
        }

        part actuatorInterface : ActuatorInterface {
            attribute commandLatency : Duration {
                attribute value = 0.050;
                attribute unit = "s";
            }
            attribute actuatorHealth = HealthKind::nominal;
            attribute commandedPositionOpen = false;
            attribute actualPositionOpen = false;
        }

        part hmi : HumanMachineInterface {
            attribute displayRefreshPeriod : Duration {
                attribute value = 0.250;
                attribute unit = "s";
            }
            attribute operatorCommandDebounce : Duration {
                attribute value = 0.100;
                attribute unit = "s";
            }
            attribute hmiHealth = HealthKind::nominal;
        }

        part logger : TransitionLogger {
            attribute storageCapacity : Count {
                attribute value = 1000000;
                attribute unit = "count";
            }
            attribute writeLatency : Duration {
                attribute value = 0.020;
                attribute unit = "s";
            }
            attribute logDataRate : DataRate {
                attribute value = 1000000.0;
                attribute unit = "bit/s";
            }
            attribute loggerHealth = HealthKind::nominal;
        }

        connection externalPowerToSupply connect externalPowerIn.energy to powerSupply.powerOutToController.energy;
        connection supplyToController connect powerSupply.powerOutToController.energy to controller.powerIn.energy;
        connection supplyToSensors connect powerSupply.powerOutToSensors.energy to sensors.powerIn.energy;
        connection supplyToActuator connect powerSupply.powerOutToActuator.energy to actuatorInterface.powerIn.energy;
        connection supplyToHmi connect powerSupply.powerOutToHmi.energy to hmi.powerIn.energy;
        connection supplyToLogger connect powerSupply.powerOutToLogger.energy to logger.powerIn.energy;

        connection sensorEventsToController connect sensors.eventOut.event to controller.eventIn.event;
        connection actuatorEventsToController connect actuatorInterface.eventOut.event to controller.eventIn.event;
        connection controllerCommandsToActuator connect controller.commandOut.command to actuatorInterface.commandIn.command;
        connection operatorInputToController connect externalOperatorIn.instruction to controller.operatorIn.instruction;
        connection hmiInputToController connect hmi.operatorOut.instruction to controller.operatorIn.instruction;
        connection controllerStateToHmi connect controller.stateOut.report to hmi.stateIn.report;
        connection controllerStateToExternal connect controller.stateOut.report to externalStateOut.report;
        connection controllerStateToLogger connect controller.stateOut.report to logger.stateIn.report;
        connection sensorDiagnosticsToController connect sensors.diagnosticOut.result to controller.diagnosticIn.result;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : AutomatonControlledGateSystem;
        doc /* The system shall use an explicit deterministic finite automaton as its organizing mechanism and shall perform the primary function of mapping sensed events and operator instructions to safe, deterministic control commands at a high level. */
        require constraint {
            system.controller.safetyIntegrity == SafetyIntegrityKind::failSafe
        }
    }

    requirement def DeterministicTransitionRequirement {
        subject controller : AutomatonController;
        doc /* For each accepted event and current state pair, the controller shall select no more than one next state and no more than one emitted command. */
        require constraint {
            controller.maximumEvaluationLatency.value <= 0.010
        }
    }

    requirement def EventConfidenceRequirement {
        subject controller : AutomatonController;
        doc /* The automaton shall ignore environmental events whose confidence is below the configured acceptance threshold. */
        require constraint {
            controller.minimumConfidenceAccepted.value >= 0.980
        }
    }

    requirement def SafeHaltRequirement {
        subject system : AutomatonControlledGateSystem;
        doc /* On emergency stop or unsafe fault detection, the system shall enter safe halt and command motion to stop. */
        require constraint {
            system.controller.safetyIntegrity == SafetyIntegrityKind::failSafe
        }
    }

    requirement def CommandLatencyRequirement {
        subject actuatorInterface : ActuatorInterface;
        doc /* The actuator interface shall acknowledge commands within the maximum latency allocated to the automaton control loop. */
        require constraint {
            actuatorInterface.commandLatency.value <= 0.050
        }
    }

    requirement def MonitoringRateRequirement {
        subject sensors : EventSensorArray;
        doc /* The sensor array shall sample the environment fast enough to support responsive automaton transitions. */
        require constraint {
            sensors.sampleRate.value >= 100.0
        }
    }

    requirement def StatePublicationRequirement {
        subject controller : AutomatonController;
        doc /* The controller shall publish its current state, previous state, last event, and health for observability of the automaton behavior. */
        require constraint {
            controller.controllerHealth != HealthKind::failed
        }
    }

    part automatonGateSystem : AutomatonControlledGateSystem;

    requirement primaryFunctionSatisfied : PrimaryFunctionRequirement {
        subject system = automatonGateSystem;
    }

    requirement deterministicTransitionsSatisfied : DeterministicTransitionRequirement {
        subject controller = automatonGateSystem.controller;
    }

    requirement eventConfidenceSatisfied : EventConfidenceRequirement {
        subject controller = automatonGateSystem.controller;
    }

    requirement safeHaltSatisfied : SafeHaltRequirement {
        subject system = automatonGateSystem;
    }

    requirement commandLatencySatisfied : CommandLatencyRequirement {
        subject actuatorInterface = automatonGateSystem.actuatorInterface;
    }

    requirement monitoringRateSatisfied : MonitoringRateRequirement {
        subject sensors = automatonGateSystem.sensors;
    }

    requirement statePublicationSatisfied : StatePublicationRequirement {
        subject controller = automatonGateSystem.controller;
    }
}
