package GeneralizedAutomationLanguageModel {
    import ScalarValues::*;
    import SI::*;

    doc /* Generalized Automation Language System: a runtime platform whose primary function is to interpret generalized automation policies and coordinate heterogeneous sensors, services, and actuators through a safe execution lifecycle. */

    attribute def TimeMs :> Real {
        unit = "ms";
    }

    attribute def FrequencyHz :> Real {
        unit = "Hz";
    }

    attribute def Percent :> Real {
        unit = "%";
    }

    attribute def TemperatureC :> Real {
        unit = "degC";
    }

    attribute def EnergyKWh :> Real {
        unit = "kWh";
    }

    attribute def PriorityLevel :> Integer;

    enum def ExecutionMode {
        enum manual;
        enum supervised;
        enum autonomous;
        enum degraded;
        enum emergencyStop;
    }

    enum def RuleStatus {
        enum drafted;
        enum validated;
        enum enabled;
        enum suspended;
        enum faulted;
        enum retired;
    }

    enum def EventSeverity {
        enum informational;
        enum advisory;
        enum warning;
        enum critical;
    }

    item def AutomationProgram {
        attribute programId : String;
        attribute languageVersion : String;
        attribute author : String;
        attribute checksum : String;
    }

    item def AutomationRule {
        attribute ruleId : String;
        attribute priority : PriorityLevel;
        attribute status : RuleStatus;
        attribute triggerExpression : String;
        attribute conditionExpression : String;
        attribute actionExpression : String;
        attribute maximumLatency : TimeMs;
    }

    item def SensorEvent {
        attribute sourceId : String;
        attribute eventName : String;
        attribute severity : EventSeverity;
        attribute observedAt : TimeMs;
        attribute value : Real;
    }

    item def ActuatorCommand {
        attribute targetId : String;
        attribute commandName : String;
        attribute parameterName : String;
        attribute parameterValue : Real;
        attribute issuedAt : TimeMs;
        attribute expiresAfter : TimeMs;
    }

    item def ServiceRequest {
        attribute serviceId : String;
        attribute operation : String;
        attribute payloadSchema : String;
        attribute timeout : TimeMs;
    }

    item def TelemetryRecord {
        attribute componentId : String;
        attribute metricName : String;
        attribute metricValue : Real;
        attribute recordedAt : TimeMs;
    }

    item def SafetyDecision {
        attribute permitted : Boolean;
        attribute reasonCode : String;
        attribute mitigationAction : String;
    }

    item def ExecutionReport {
        attribute correlationId : String;
        attribute accepted : Boolean;
        attribute completed : Boolean;
        attribute latency : TimeMs;
        attribute diagnosticMessage : String;
    }

    port def ProgramInputPort {
        in program : AutomationProgram;
        in rule : AutomationRule;
    }

    port def EventInputPort {
        in event : SensorEvent;
    }

    port def CommandOutputPort {
        out command : ActuatorCommand;
    }

    port def ServicePort {
        out request : ServiceRequest;
        in report : ExecutionReport;
    }

    port def TelemetryPort {
        out telemetry : TelemetryRecord;
    }

    port def SafetyPort {
        out proposedCommand : ActuatorCommand;
        in decision : SafetyDecision;
    }

    port def ManagementPort {
        in requestedMode : ExecutionMode;
        out currentMode : ExecutionMode;
        out report : ExecutionReport;
    }

    action def ParseAutomationProgram {
        in program : AutomationProgram;
        out parsedRules : AutomationRule;
        out parseReport : ExecutionReport;
    }

    action def ValidateRuleSemantics {
        in rule : AutomationRule;
        out validatedRule : AutomationRule;
        out validationReport : ExecutionReport;
    }

    action def MatchEventToRule {
        in event : SensorEvent;
        in rule : AutomationRule;
        out triggered : Boolean;
    }

    action def EvaluateRuleCondition {
        in event : SensorEvent;
        in rule : AutomationRule;
        out conditionSatisfied : Boolean;
    }

    action def ProduceCommand {
        in event : SensorEvent;
        in rule : AutomationRule;
        out command : ActuatorCommand;
    }

    action def AuthorizeCommand {
        in command : ActuatorCommand;
        out decision : SafetyDecision;
    }

    action def DispatchCommand {
        in command : ActuatorCommand;
        out report : ExecutionReport;
    }

    action def RecordTelemetry {
        in report : ExecutionReport;
        out telemetry : TelemetryRecord;
    }

    state def AutomationRuntimeState {
        entry action initializeRuntime;

        state Offline;
        state LoadingProgram;
        state ValidatingProgram;
        state Ready;
        state Monitoring;
        state Planning;
        state SafetyChecking;
        state Dispatching;
        state DegradedOperation;
        state EmergencyStopped;
        state FaultRecovery;

        transition initial then Offline;
        transition Offline to LoadingProgram
            accept programReceived;
        transition LoadingProgram to ValidatingProgram
            accept programParsed;
        transition ValidatingProgram to Ready
            accept programValid;
        transition ValidatingProgram to FaultRecovery
            accept programInvalid;
        transition Ready to Monitoring
            accept enableAutonomy;
        transition Monitoring to Planning
            accept ruleTriggered;
        transition Planning to SafetyChecking
            accept commandPlanned;
        transition SafetyChecking to Dispatching
            accept commandPermitted;
        transition SafetyChecking to Monitoring
            accept commandDenied;
        transition Dispatching to Monitoring
            accept commandCompleted;
        transition Monitoring to DegradedOperation
            accept connectorUnavailable;
        transition DegradedOperation to Monitoring
            accept redundancyRestored;
        transition Monitoring to EmergencyStopped
            accept emergencyStopRequested;
        transition Dispatching to EmergencyStopped
            accept unsafeExecutionDetected;
        transition EmergencyStopped to FaultRecovery
            accept resetAuthorized;
        transition FaultRecovery to Ready
            accept recoveryComplete;
    }

    part def GalProgramRepository {
        attribute storedProgramCount : Integer;
        attribute retainedHistoryDays : Integer;
        attribute maximumProgramSizeMb : Real;
        port programIn : ProgramInputPort;
        port telemetryOut : TelemetryPort;

        action storeProgram : ParseAutomationProgram;
    }

    part def GalInterpreter {
        attribute supportedLanguageVersion : String = "GAL-2.0";
        attribute parseThroughput : FrequencyHz;
        attribute averageParseLatency : TimeMs;
        port programIn : ProgramInputPort;
        port telemetryOut : TelemetryPort;

        action parse : ParseAutomationProgram;
    }

    part def SemanticValidator {
        attribute maximumRulesPerProgram : Integer = 5000;
        attribute validationTimeout : TimeMs;
        port ruleIn : ProgramInputPort;
        port telemetryOut : TelemetryPort;

        action validate : ValidateRuleSemantics;
    }

    part def EventNormalizer {
        attribute acceptedEventRate : FrequencyHz;
        attribute normalizationLatency : TimeMs;
        port rawEventIn : EventInputPort;
        port normalizedEventOut : EventInputPort;
        port telemetryOut : TelemetryPort;
    }

    part def RuleEngine {
        attribute activeRuleCount : Integer;
        attribute evaluationRate : FrequencyHz;
        attribute targetEvaluationLatency : TimeMs;
        port eventIn : EventInputPort;
        port ruleIn : ProgramInputPort;
        port commandOut : CommandOutputPort;
        port telemetryOut : TelemetryPort;

        action match : MatchEventToRule;
        action evaluate : EvaluateRuleCondition;
        action produce : ProduceCommand;
    }

    part def SafetySupervisor {
        attribute maximumPermittedRisk : Percent;
        attribute emergencyStopLatency : TimeMs;
        attribute safeStateCommandName : String = "enterSafeState";
        port safetyIn : SafetyPort;
        port commandOut : CommandOutputPort;
        port telemetryOut : TelemetryPort;

        action authorize : AuthorizeCommand;
    }

    part def Scheduler {
        attribute schedulingQuantum : TimeMs;
        attribute maximumConcurrentActions : Integer;
        attribute queueDepth : Integer;
        port commandIn : CommandOutputPort;
        port commandOut : CommandOutputPort;
        port telemetryOut : TelemetryPort;
    }

    part def ConnectorHub {
        attribute connectedDeviceCount : Integer;
        attribute connectedServiceCount : Integer;
        attribute commandDispatchLatency : TimeMs;
        port commandIn : CommandOutputPort;
        port service : ServicePort;
        port telemetryOut : TelemetryPort;

        action dispatch : DispatchCommand;
    }

    part def TelemetryCollector {
        attribute samplingRate : FrequencyHz;
        attribute retentionDays : Integer;
        attribute energyUsedToday : EnergyKWh;
        port telemetryIn : TelemetryPort;
        port management : ManagementPort;

        action record : RecordTelemetry;
    }

    part def OperationsConsole {
        attribute operatorSessionCount : Integer;
        attribute selectedMode : ExecutionMode;
        port management : ManagementPort;
        port programOut : ProgramInputPort;
    }

    part def GeneralizedAutomationSystem {
        attribute systemId : String = "GAL-Automation-System";
        attribute currentMode : ExecutionMode;
        attribute availabilityTarget : Percent = 99.95;
        attribute nominalControlLoopLatency : TimeMs = 250.0;
        attribute peakEventRate : FrequencyHz = 1000.0;

        port programIngress : ProgramInputPort;
        port eventIngress : EventInputPort;
        port commandEgress : CommandOutputPort;
        port serviceIntegration : ServicePort;
        port telemetryEgress : TelemetryPort;
        port management : ManagementPort;

        part repository : GalProgramRepository;
        part interpreter : GalInterpreter;
        part validator : SemanticValidator;
        part normalizer : EventNormalizer;
        part ruleEngine : RuleEngine;
        part supervisor : SafetySupervisor;
        part scheduler : Scheduler;
        part connectorHub : ConnectorHub;
        part telemetry : TelemetryCollector;
        part console : OperationsConsole;

        state runtime : AutomationRuntimeState;

        connect programIngress to repository.programIn;
        connect repository.programIn to interpreter.programIn;
        connect interpreter.programIn to validator.ruleIn;
        connect validator.ruleIn to ruleEngine.ruleIn;

        connect eventIngress to normalizer.rawEventIn;
        connect normalizer.normalizedEventOut to ruleEngine.eventIn;

        connect ruleEngine.commandOut to supervisor.safetyIn;
        connect supervisor.commandOut to scheduler.commandIn;
        connect scheduler.commandOut to connectorHub.commandIn;
        connect connectorHub.commandIn to commandEgress;
        connect connectorHub.service to serviceIntegration;

        connect repository.telemetryOut to telemetry.telemetryIn;
        connect interpreter.telemetryOut to telemetry.telemetryIn;
        connect validator.telemetryOut to telemetry.telemetryIn;
        connect normalizer.telemetryOut to telemetry.telemetryIn;
        connect ruleEngine.telemetryOut to telemetry.telemetryIn;
        connect supervisor.telemetryOut to telemetry.telemetryIn;
        connect scheduler.telemetryOut to telemetry.telemetryIn;
        connect connectorHub.telemetryOut to telemetry.telemetryIn;
        connect telemetry.management to management;
        connect telemetry.management to console.management;
        connect console.programOut to programIngress;
        connect telemetryEgress to telemetry.telemetryIn;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : GeneralizedAutomationSystem;
        doc /* The system shall provide a generalized automation runtime that accepts automation programs expressed in a Generalized Automation Language, validates them, evaluates rules against normalized events, and dispatches safe commands to heterogeneous devices and services. */
    }

    requirement def LanguageValidationRequirement {
        subject interpreter : GalInterpreter;
        subject validator : SemanticValidator;
        doc /* The system shall parse and semantically validate each automation program before any rule from that program is enabled for autonomous execution. */
    }

    requirement def EventDrivenExecutionRequirement {
        subject engine : RuleEngine;
        doc /* The rule engine shall evaluate enabled automation rules when normalized events arrive and shall produce actuator commands only when the trigger and condition expressions are satisfied. */
    }

    requirement def SafetyAuthorizationRequirement {
        subject supervisor : SafetySupervisor;
        doc /* Every command produced by the rule engine shall be authorized by the safety supervisor before dispatch to an actuator or external service. */
    }

    requirement def LatencyRequirement {
        subject system : GeneralizedAutomationSystem;
        attribute maximumEndToEndLatency : TimeMs = 500.0;
        doc /* For nominal operation, the elapsed time from receiving a normalized event to dispatching an authorized command shall not exceed the maximum end-to-end latency. */
    }

    requirement def EmergencyStopRequirement {
        subject supervisor : SafetySupervisor;
        attribute maximumStopLatency : TimeMs = 100.0;
        doc /* The system shall transition to emergency stopped mode and issue safe-state commands within the maximum stop latency when unsafe execution is detected. */
    }

    requirement def ObservabilityRequirement {
        subject telemetry : TelemetryCollector;
        doc /* The system shall emit telemetry for program ingestion, rule validation, event evaluation, safety authorization, command dispatch, and fault recovery. */
    }

    satisfy PrimaryFunctionRequirement by GeneralizedAutomationSystem;
    satisfy LanguageValidationRequirement by GalInterpreter;
    satisfy LanguageValidationRequirement by SemanticValidator;
    satisfy EventDrivenExecutionRequirement by RuleEngine;
    satisfy SafetyAuthorizationRequirement by SafetySupervisor;
    satisfy LatencyRequirement by GeneralizedAutomationSystem;
    satisfy EmergencyStopRequirement by SafetySupervisor;
    satisfy ObservabilityRequirement by TelemetryCollector;
}