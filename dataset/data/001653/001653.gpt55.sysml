package GeneralizedAutomationLanguageAutomationModel {

  import ScalarValues::*;
  import ISQBase::*;
  import SI::*;

  attribute def CycleTime :> ISQBase::time {
    :>> unit = SI::s;
  }

  attribute def ProcessingLatency :> ISQBase::time {
    :>> unit = SI::s;
  }

  attribute def TimeStamp :> ISQBase::time {
    :>> unit = SI::s;
  }

  attribute def SupplyVoltage :> ISQBase::electricPotential {
    :>> unit = SI::V;
  }

  attribute def PowerDraw :> ISQBase::power {
    :>> unit = SI::W;
  }

  attribute def Temperature :> ISQBase::thermodynamicTemperature {
    :>> unit = SI::K;
  }

  attribute def LengthPosition :> ISQBase::length {
    :>> unit = SI::m;
  }

  attribute def ConveyorVelocity :> ISQBase::speed {
    :>> unit = SI::m_per_s;
  }

  attribute def ForceLimit :> ISQBase::force {
    :>> unit = SI::N;
  }

  enum def RuntimeMode {
    enum idle;
    enum loading;
    enum validating;
    enum ready;
    enum running;
    enum paused;
    enum stopping;
    enum stopped;
    enum faulted;
    enum maintenance;
  }

  enum def ValidationResultKind {
    enum accepted;
    enum rejectedSyntax;
    enum rejectedTypeSafety;
    enum rejectedUnsafeAction;
    enum rejectedTiming;
  }

  enum def CommandPriority {
    enum routine;
    enum supervisory;
    enum safetyCritical;
    enum emergency;
  }

  enum def DeviceHealth {
    enum healthy;
    enum degraded;
    enum unavailable;
    enum faulted;
    enum inhibited;
  }

  enum def PowerState {
    enum deEnergized;
    enum energizing;
    enum energized;
    enum brownout;
    enum isolated;
  }

  enum def SafetyIntegrityState {
    enum safe;
    enum warning;
    enum protectiveStop;
    enum emergencyStop;
    enum unsafeFault;
  }

  enum def OperatorCommandKind {
    enum loadProgram;
    enum validateProgram;
    enum start;
    enum pause;
    enum resume;
    enum stop;
    enum resetFault;
    enum requestStatus;
    enum enterMaintenance;
    enum exitMaintenance;
  }

  enum def GALStatementKind {
    enum declaration;
    enum stateDefinition;
    enum eventRule;
    enum guardCondition;
    enum timedAction;
    enum deviceBinding;
    enum exceptionHandler;
    enum procedureCall;
  }

  item def GALStatement {
    attribute statementId : String;
    attribute kind : GALStatementKind;
    attribute lineNumber : Integer;
    attribute normalizedText : String;
  }

  item def GALProgram {
    attribute programId : String;
    attribute programName : String;
    attribute languageVersion : String;
    attribute revision : String;
    attribute sourceText : String;
    attribute checksumSha256 : String;
    attribute declaredCycleTime : CycleTime;
    attribute maximumReactionTime : ProcessingLatency;
    attribute authorizingRole : String;
    item statements : GALStatement[1..*];
  }

  item def GALValidationReport {
    attribute result : ValidationResultKind;
    attribute diagnosticCount : Integer;
    attribute worstCaseCycleTime : CycleTime;
    attribute worstCaseReactionTime : ProcessingLatency;
    attribute validatedAt : TimeStamp;
    attribute validationSummary : String;
  }

  item def RuntimeConfiguration {
    attribute controllerName : String;
    attribute deterministicCycleTime : CycleTime;
    attribute allowedJitter : ProcessingLatency;
    attribute networkTimeout : ProcessingLatency;
    attribute defaultSafeConveyorSpeed : ConveyorVelocity;
    attribute maximumActuatorForce : ForceLimit;
  }

  item def ExecutionPlan {
    attribute planId : String;
    attribute sourceProgramId : String;
    attribute compiledRevision : String;
    attribute deterministicCycleTime : CycleTime;
    attribute scheduledActionCount : Integer;
    attribute eventRuleCount : Integer;
    attribute validated : Boolean;
  }

  item def AutomationEvent {
    attribute eventId : String;
    attribute sourceDeviceId : String;
    attribute eventName : String;
    attribute priority : CommandPriority;
    attribute occurrenceTime : TimeStamp;
    attribute payloadText : String;
  }

  item def EventAcknowledgement {
    attribute eventId : String;
    attribute accepted : Boolean;
    attribute acknowledgementTime : TimeStamp;
    attribute reason : String;
  }

  item def OperatorCommand {
    attribute commandId : String;
    attribute kind : OperatorCommandKind;
    attribute issuedBy : String;
    attribute issuedAt : TimeStamp;
    attribute priority : CommandPriority;
  }

  item def SystemStatus {
    attribute mode : RuntimeMode;
    attribute safetyState : SafetyIntegrityState;
    attribute activeProgramId : String;
    attribute currentCycleTime : CycleTime;
    attribute observedLatency : ProcessingLatency;
    attribute healthy : Boolean;
    attribute statusMessage : String;
  }

  item def DeviceFeedback {
    attribute deviceId : String;
    attribute health : DeviceHealth;
    attribute position : LengthPosition;
    attribute velocity : ConveyorVelocity;
    attribute temperature : Temperature;
    attribute energized : Boolean;
    attribute measuredAt : TimeStamp;
  }

  item def FeedbackFrame {
    attribute frameId : String;
    attribute sampledAt : TimeStamp;
    attribute frameAge : ProcessingLatency;
    item deviceFeedback : DeviceFeedback[1..*];
  }

  item def DeviceCommand {
    attribute deviceId : String;
    attribute commandName : String;
    attribute targetPosition : LengthPosition;
    attribute targetVelocity : ConveyorVelocity;
    attribute forceLimit : ForceLimit;
    attribute enablePower : Boolean;
    attribute priority : CommandPriority;
  }

  item def ControlFrame {
    attribute frameId : String;
    attribute planId : String;
    attribute emittedAt : TimeStamp;
    attribute validFor : CycleTime;
    item commands : DeviceCommand[1..*];
  }

  item def SafetyDecision {
    attribute decisionId : String;
    attribute safetyState : SafetyIntegrityState;
    attribute allowMotion : Boolean;
    attribute requirePowerIsolation : Boolean;
    attribute maximumPermittedVelocity : ConveyorVelocity;
    attribute reason : String;
  }

  item def TelemetryRecord {
    attribute recordId : String;
    attribute recordedAt : TimeStamp;
    attribute mode : RuntimeMode;
    attribute cycleTime : CycleTime;
    attribute latency : ProcessingLatency;
    attribute powerDraw : PowerDraw;
    attribute temperature : Temperature;
    attribute message : String;
  }

  item def PowerFeed {
    attribute voltage : SupplyVoltage;
    attribute availablePower : PowerDraw;
    attribute state : PowerState;
  }

  port def ProgramInputPort {
    in item program : GALProgram;
    in item configuration : RuntimeConfiguration;
  }

  port def ProgramOutputPort {
    out item program : GALProgram;
    out item configuration : RuntimeConfiguration;
  }

  port def ValidationPort {
    out item report : GALValidationReport;
  }

  port def ExecutionPlanOutputPort {
    out item plan : ExecutionPlan;
  }

  port def ExecutionPlanInputPort {
    in item plan : ExecutionPlan;
  }

  port def OperatorPort {
    in item command : OperatorCommand;
    out item status : SystemStatus;
    out item validationReport : GALValidationReport;
  }

  port def InternalCommandPort {
    in item command : OperatorCommand;
    out item status : SystemStatus;
  }

  port def EventInputPort {
    in item event : AutomationEvent;
    out item acknowledgement : EventAcknowledgement;
  }

  port def RuntimeControlOutputPort {
    out item controlFrame : ControlFrame;
    out item status : SystemStatus;
  }

  port def RuntimeControlInputPort {
    in item controlFrame : ControlFrame;
    in item status : SystemStatus;
  }

  port def FieldbusControllerPort {
    out item controlFrame : ControlFrame;
    in item feedbackFrame : FeedbackFrame;
  }

  port def FieldbusDevicePort {
    in item controlFrame : ControlFrame;
    out item feedbackFrame : FeedbackFrame;
  }

  port def FeedbackInputPort {
    in item feedbackFrame : FeedbackFrame;
  }

  port def FeedbackOutputPort {
    out item feedbackFrame : FeedbackFrame;
  }

  port def SafetyDecisionOutputPort {
    out item decision : SafetyDecision;
  }

  port def SafetyDecisionInputPort {
    in item decision : SafetyDecision;
  }

  port def TelemetryPort {
    out item telemetry : TelemetryRecord;
  }

  port def TelemetryInputPort {
    in item telemetry : TelemetryRecord;
  }

  port def PowerSourcePort {
    out item feed : PowerFeed;
  }

  port def PowerLoadPort {
    in item feed : PowerFeed;
  }

  action def ParseGALProgram {
    in item program : GALProgram;
    out item normalizedStatements : GALStatement[1..*];
    out attribute parseSuccessful : Boolean;
  }

  action def ValidateGALSemantics {
    in item program : GALProgram;
    in item configuration : RuntimeConfiguration;
    out item report : GALValidationReport;
  }

  action def CompileGALToExecutionPlan {
    in item program : GALProgram;
    in item report : GALValidationReport;
    out item plan : ExecutionPlan;
  }

  action def EvaluateGALRules {
    in item plan : ExecutionPlan;
    in item feedback : FeedbackFrame;
    in item event : AutomationEvent;
    out item requestedControl : ControlFrame;
  }

  action def ApplyDeterministicSchedule {
    in item requestedControl : ControlFrame;
    in item configuration : RuntimeConfiguration;
    out item scheduledControl : ControlFrame;
  }

  action def EnforceSafetyEnvelope {
    in item scheduledControl : ControlFrame;
    in item feedback : FeedbackFrame;
    in item decision : SafetyDecision;
    out item safeControl : ControlFrame;
  }

  action def PublishDeviceCommands {
    in item safeControl : ControlFrame;
    out item emittedControl : ControlFrame;
  }

  action def CollectTelemetry {
    in item status : SystemStatus;
    in item feedback : FeedbackFrame;
    in item power : PowerFeed;
    out item telemetry : TelemetryRecord;
  }

  action def TransformGALProgramIntoCoordinatedAutomation {
    doc /* Primary function: receive a Generalized Automation Language program, validate its syntax, timing, device bindings, and safety constraints, compile it into a deterministic execution plan, and repeatedly transform events and field feedback into safe coordinated commands for the automated workcell. */
    in item program : GALProgram;
    in item configuration : RuntimeConfiguration;
    in item operatorCommand : OperatorCommand;
    in item deviceFeedback : FeedbackFrame;
    out item deviceControl : ControlFrame;
    out item systemStatus : SystemStatus;

    action parse : ParseGALProgram;
    action validate : ValidateGALSemantics;
    action compile : CompileGALToExecutionPlan;
    action evaluate : EvaluateGALRules;
    action schedule : ApplyDeterministicSchedule;
    action enforceSafety : EnforceSafetyEnvelope;
    action publish : PublishDeviceCommands;

    succession first parse then validate;
    succession validate then compile;
    succession compile then evaluate;
    succession evaluate then schedule;
    succession schedule then enforceSafety;
    succession enforceSafety then publish;
  }

  state def RuntimeLifecycle {
    entry action initializeRuntime;
    state idle;
    state loading;
    state validating;
    state ready;
    state running;
    state paused;
    state stopping;
    state stopped;
    state faulted;
    state maintenance;

    transition initialToIdle first start then idle;
    transition loadProgram first idle accept OperatorCommand then loading;
    transition validateProgram first loading then validating;
    transition validationAccepted first validating then ready;
    transition validationRejected first validating then faulted;
    transition startExecution first ready accept OperatorCommand then running;
    transition pauseExecution first running accept OperatorCommand then paused;
    transition resumeExecution first paused accept OperatorCommand then running;
    transition controlledStop first running accept OperatorCommand then stopping;
    transition stoppedFromStopping first stopping then stopped;
    transition resetStopped first stopped accept OperatorCommand then idle;
    transition runtimeFault first running accept AutomationEvent then faulted;
    transition faultReset first faulted accept OperatorCommand then idle;
    transition enterMaintenance first idle accept OperatorCommand then maintenance;
    transition exitMaintenance first maintenance accept OperatorCommand then idle;
  }

  state def SafetyLifecycle {
    entry action initializeSafetyMonitor;
    state safe;
    state warning;
    state protectiveStop;
    state emergencyStop;
    state unsafeFault;

    transition initialSafe first start then safe;
    transition warningDetected first safe accept AutomationEvent then warning;
    transition warningCleared first warning then safe;
    transition protectiveStopRequested first warning accept AutomationEvent then protectiveStop;
    transition emergencyStopRequested first safe accept AutomationEvent then emergencyStop;
    transition emergencyStopFromWarning first warning accept AutomationEvent then emergencyStop;
    transition unsafeFaultDetected first protectiveStop accept AutomationEvent then unsafeFault;
    transition resetProtectiveStop first protectiveStop accept OperatorCommand then safe;
    transition resetEmergencyStop first emergencyStop accept OperatorCommand then safe;
    transition resetUnsafeFault first unsafeFault accept OperatorCommand then safe;
  }

  part def GALProgramManager {
    attribute supportedLanguageVersion : String = "GAL-1.0";
    attribute maximumStatementCount : Integer = 5000;

    port programIn : ProgramInputPort;
    port validationOut : ValidationPort;
    port planOut : ExecutionPlanOutputPort;

    perform action parseProgram : ParseGALProgram;
    perform action validateProgram : ValidateGALSemantics;
    perform action compileProgram : CompileGALToExecutionPlan;
  }

  part def GALRuntimeEngine {
    attribute supportsGALExecution : Boolean = true;
    attribute activeMode : RuntimeMode = RuntimeMode::idle;
    attribute activeProgramId : String = "none";
    attribute lastCycleTime : CycleTime = 0.010 [SI::s];
    attribute maximumObservedLatency : ProcessingLatency = 0.000 [SI::s];

    port planIn : ExecutionPlanInputPort;
    port operatorCommandIn : InternalCommandPort;
    port eventIn : EventInputPort;
    port feedbackIn : FeedbackInputPort;
    port controlOut : RuntimeControlOutputPort;

    exhibit state lifecycle : RuntimeLifecycle;
    perform action evaluateRules : EvaluateGALRules;
  }

  part def DeterministicScheduler {
    attribute nominalCycleTime : CycleTime = 0.010 [SI::s];
    attribute allowedJitter : ProcessingLatency = 0.001 [SI::s];
    attribute timeBaseSynchronized : Boolean = true;

    port controlIn : RuntimeControlInputPort;
    port controlOut : RuntimeControlOutputPort;

    perform action scheduleCommands : ApplyDeterministicSchedule;
  }

  part def SafetySupervisor {
    attribute safetyState : SafetyIntegrityState = SafetyIntegrityState::safe;
    attribute maximumAllowedVelocity : ConveyorVelocity = 1.000 [SI::m_per_s];
    attribute maximumAllowedForce : ForceLimit = 250.000 [SI::N];
    attribute emergencyStopLatency : ProcessingLatency = 0.020 [SI::s];

    port feedbackIn : FeedbackInputPort;
    port scheduledControlIn : RuntimeControlInputPort;
    port safetyDecisionOut : SafetyDecisionOutputPort;
    port safeControlOut : RuntimeControlOutputPort;
    port eventIn : EventInputPort;

    exhibit state safetyLifecycle : SafetyLifecycle;
    perform action enforceSafety : EnforceSafetyEnvelope;
  }

  part def FieldbusGateway {
    attribute protocolName : String = "deterministic-industrial-ethernet";
    attribute cycleTime : CycleTime = 0.010 [SI::s];
    attribute communicationTimeout : ProcessingLatency = 0.030 [SI::s];

    port controllerSide : RuntimeControlInputPort;
    port fieldbus : FieldbusControllerPort;
    port feedbackOut : FeedbackOutputPort;

    perform action publishCommands : PublishDeviceCommands;
  }

  part def OperatorInterface {
    attribute panelName : String = "GAL supervisory console";
    attribute supportsProgramEditing : Boolean = true;
    attribute statusRefreshPeriod : CycleTime = 0.250 [SI::s];

    port operator : OperatorPort;
    port programOut : ProgramOutputPort;
    port commandOut : InternalCommandPort;
    port validationIn : ValidationPort;
    port statusIn : RuntimeControlInputPort;
  }

  part def TelemetryLogger {
    attribute retentionDays : Integer = 90;
    attribute samplingPeriod : CycleTime = 1.000 [SI::s];

    port statusIn : RuntimeControlInputPort;
    port feedbackIn : FeedbackInputPort;
    port powerIn : PowerLoadPort;
    port telemetryOut : TelemetryPort;

    perform action collectTelemetry : CollectTelemetry;
  }

  part def GALAutomationController {
    attribute controllerIdentifier : String = "GAL-CTRL-01";
    attribute nominalCyclePeriod : CycleTime = 0.010 [SI::s];
    attribute maximumCyclePeriod : CycleTime = 0.020 [SI::s];
    attribute maximumEndToEndLatency : ProcessingLatency = 0.050 [SI::s];
    attribute supplyVoltage : SupplyVoltage = 24.000 [SI::V];
    attribute peakPowerDraw : PowerDraw = 180.000 [SI::W];

    port operator : OperatorPort;
    port fieldbus : FieldbusControllerPort;
    port externalTelemetry : TelemetryPort;
    port power : PowerLoadPort;

    part hmi : OperatorInterface;
    part programManager : GALProgramManager;
    part runtime : GALRuntimeEngine;
    part scheduler : DeterministicScheduler;
    part safety : SafetySupervisor;
    part gateway : FieldbusGateway;
    part telemetryLogger : TelemetryLogger;

    connect operator to hmi.operator;
    connect hmi.programOut to programManager.programIn;
    connect hmi.commandOut to runtime.operatorCommandIn;
    connect programManager.validationOut to hmi.validationIn;
    connect programManager.planOut to runtime.planIn;
    connect runtime.controlOut to scheduler.controlIn;
    connect scheduler.controlOut to safety.scheduledControlIn;
    connect gateway.feedbackOut to runtime.feedbackIn;
    connect gateway.feedbackOut to safety.feedbackIn;
    connect safety.safeControlOut to gateway.controllerSide;
    connect gateway.fieldbus to fieldbus;
    connect runtime.controlOut to hmi.statusIn;
    connect runtime.controlOut to telemetryLogger.statusIn;
    connect gateway.feedbackOut to telemetryLogger.feedbackIn;
    connect power to telemetryLogger.powerIn;
    connect telemetryLogger.telemetryOut to externalTelemetry;
  }

  part def IndustrialPowerSupply {
    attribute inputVoltage : SupplyVoltage = 230.000 [SI::V];
    attribute outputVoltage : SupplyVoltage = 24.000 [SI::V];
    attribute maximumOutputPower : PowerDraw = 1000.000 [SI::W];
    attribute state : PowerState = PowerState::energized;

    port output : PowerSourcePort;
  }

  part def ConveyorModule {
    attribute moduleId : String;
    attribute length : LengthPosition = 2.000 [SI::m];
    attribute maximumVelocity : ConveyorVelocity = 1.500 [SI::m_per_s];
    attribute nominalVelocity : ConveyorVelocity = 0.750 [SI::m_per_s];
    attribute motorPower : PowerDraw = 250.000 [SI::W];

    port fieldbus : FieldbusDevicePort;
    port power : PowerLoadPort;
  }

  part def RoboticActuator {
    attribute actuatorId : String;
    attribute maximumReach : LengthPosition = 0.850 [SI::m];
    attribute maximumForce : ForceLimit = 200.000 [SI::N];
    attribute standbyPower : PowerDraw = 75.000 [SI::W];
    attribute operatingPower : PowerDraw = 420.000 [SI::W];

    port fieldbus : FieldbusDevicePort;
    port power : PowerLoadPort;
  }

  part def SensorArray {
    attribute arrayId : String;
    attribute sensorCount : Integer = 16;
    attribute samplePeriod : CycleTime = 0.005 [SI::s];
    attribute operatingTemperature : Temperature = 298.150 [SI::K];

    port fieldbus : FieldbusDevicePort;
    port power : PowerLoadPort;
  }

  part def EmergencyStopDevice {
    attribute deviceId : String = "ESTOP-01";
    attribute channelCount : Integer = 2;
    attribute maximumContactOpeningTime : ProcessingLatency = 0.010 [SI::s];

    port eventOut : EventInputPort;
    port power : PowerLoadPort;
  }

  part def AutomatedWorkcell {
    attribute workcellId : String = "GAL-CELL-01";
    attribute ambientTemperature : Temperature = 296.150 [SI::K];
    attribute installedDeviceCount : Integer = 5;

    port fieldbus : FieldbusDevicePort;
    port power : PowerLoadPort;
    port safetyEvent : EventInputPort;

    part inboundConveyor : ConveyorModule {
      attribute moduleId = "CONV-IN";
      attribute length = 2.500 [SI::m];
      attribute nominalVelocity = 0.600 [SI::m_per_s];
    }

    part outboundConveyor : ConveyorModule {
      attribute moduleId = "CONV-OUT";
      attribute length = 2.500 [SI::m];
      attribute nominalVelocity = 0.600 [SI::m_per_s];
    }

    part handlingRobot : RoboticActuator {
      attribute actuatorId = "ROBOT-01";
      attribute maximumReach = 0.900 [SI::m];
      attribute maximumForce = 180.000 [SI::N];
    }

    part inspectionSensors : SensorArray {
      attribute arrayId = "SENS-INSPECT";
      attribute sensorCount = 24;
      attribute samplePeriod = 0.004 [SI::s];
    }

    part emergencyStop : EmergencyStopDevice;

    connect fieldbus to inboundConveyor.fieldbus;
    connect fieldbus to outboundConveyor.fieldbus;
    connect fieldbus to handlingRobot.fieldbus;
    connect fieldbus to inspectionSensors.fieldbus;
    connect power to inboundConveyor.power;
    connect power to outboundConveyor.power;
    connect power to handlingRobot.power;
    connect power to inspectionSensors.power;
    connect power to emergencyStop.power;
    connect emergencyStop.eventOut to safetyEvent;
  }

  part def GeneralizedAutomationSystem {
    doc /* A system based on a Generalized Automation Language. Its high-level primary function is to convert generalized, device-independent automation intent into validated, deterministic, and safe execution across an industrial workcell. */

    attribute systemName : String = "Generalized Automation Language Automation System";
    attribute primaryFunctionEnabled : Boolean = true;
    attribute nominalCyclePeriod : CycleTime = 0.010 [SI::s];
    attribute maximumCyclePeriod : CycleTime = 0.020 [SI::s];
    attribute maximumReactionLatency : ProcessingLatency = 0.050 [SI::s];
    attribute installedPowerCapacity : PowerDraw = 1000.000 [SI::W];
    attribute controllerVoltage : SupplyVoltage = 24.000 [SI::V];

    port operatorAccess : OperatorPort;
    port telemetryOut : TelemetryPort;

    part powerSupply : IndustrialPowerSupply;
    part controller : GALAutomationController;
    part workcell : AutomatedWorkcell;

    perform action primaryFunction : TransformGALProgramIntoCoordinatedAutomation;

    connect operatorAccess to controller.operator;
    connect controller.fieldbus to workcell.fieldbus;
    connect controller.externalTelemetry to telemetryOut;
    connect powerSupply.output to controller.power;
    connect powerSupply.output to workcell.power;
    connect workcell.safetyEvent to controller.safety.eventIn;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall accept a Generalized Automation Language program and use it as the authoritative automation specification for coordinating workcell devices. */
    subject system : GeneralizedAutomationSystem;
    require constraint {
      system.primaryFunctionEnabled == true
    }
  }

  requirement def ProgramValidationRequirement {
    doc /* The system shall validate syntax, semantic consistency, device binding, timing, and safety constraints before a GAL program is executed. */
    subject controller : GALAutomationController;
    require constraint {
      controller.programManager.maximumStatementCount >= 1000
    }
  }

  requirement def DeterministicExecutionRequirement {
    doc /* The controller shall execute validated GAL automation plans with a deterministic nominal cycle period no greater than the configured maximum cycle period. */
    subject system : GeneralizedAutomationSystem;
    require constraint {
      system.nominalCyclePeriod <= system.maximumCyclePeriod
    }
  }

  requirement def ReactionLatencyRequirement {
    doc /* The system shall transform field feedback and automation events into safe device commands within the maximum reaction latency. */
    subject system : GeneralizedAutomationSystem;
    require constraint {
      system.maximumReactionLatency <= 0.050 [SI::s]
    }
  }

  requirement def SafetyEnvelopeRequirement {
    doc /* The safety supervisor shall inhibit unsafe motion, enforce velocity and force limits, and command protective stop or emergency stop when safety events require it. */
    subject controller : GALAutomationController;
    require constraint {
      controller.safety.emergencyStopLatency <= 0.020 [SI::s]
    }
  }

  requirement def TelemetryRequirement {
    doc /* The system shall publish runtime mode, active program identity, cycle timing, safety state, device feedback, power, and temperature telemetry for supervision and traceability. */
    subject controller : GALAutomationController;
    require constraint {
      controller.telemetryLogger.retentionDays >= 30
    }
  }

  requirement def PowerRequirement {
    doc /* The power supply shall provide sufficient 24 V control power for the controller and workcell control electronics. */
    subject system : GeneralizedAutomationSystem;
    require constraint {
      system.controllerVoltage == 24.000 [SI::V]
    }
  }

  requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
    subject system = generalizedAutomationSystem;
  }

  requirement programValidationRequirement : ProgramValidationRequirement {
    subject controller = generalizedAutomationSystem.controller;
  }

  requirement deterministicExecutionRequirement : DeterministicExecutionRequirement {
    subject system = generalizedAutomationSystem;
  }

  requirement reactionLatencyRequirement : ReactionLatencyRequirement {
    subject system = generalizedAutomationSystem;
  }

  requirement safetyEnvelopeRequirement : SafetyEnvelopeRequirement {
    subject controller = generalizedAutomationSystem.controller;
  }

  requirement telemetryRequirement : TelemetryRequirement {
    subject controller = generalizedAutomationSystem.controller;
  }

  requirement powerRequirement : PowerRequirement {
    subject system = generalizedAutomationSystem;
  }

  part generalizedAutomationSystem : GeneralizedAutomationSystem {
    attribute systemName = "GAL-Based Coordinated Automation System";
    attribute primaryFunctionEnabled = true;
    attribute nominalCyclePeriod = 0.010 [SI::s];
    attribute maximumCyclePeriod = 0.020 [SI::s];
    attribute maximumReactionLatency = 0.050 [SI::s];
    attribute installedPowerCapacity = 1000.000 [SI::W];
    attribute controllerVoltage = 24.000 [SI::V];
  }
}
