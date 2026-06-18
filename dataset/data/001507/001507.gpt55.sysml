package MultiFunctionStructureModel {

  import ScalarValues::*;

  attribute def Voltage_V :> Real {
    doc "Voltage measured in volts.";
  }

  attribute def Current_A :> Real {
    doc "Current measured in amperes.";
  }

  attribute def Power_W :> Real {
    doc "Power measured in watts.";
  }

  attribute def Energy_Wh :> Real {
    doc "Energy measured in watt-hours.";
  }

  attribute def Temperature_degC :> Real {
    doc "Temperature measured in degrees Celsius.";
  }

  attribute def Duration_s :> Real {
    doc "Duration measured in seconds.";
  }

  attribute def Frequency_Hz :> Real {
    doc "Frequency measured in hertz.";
  }

  attribute def DataRate_Mbps :> Real {
    doc "Data rate measured in megabits per second.";
  }

  attribute def Distance_m :> Real {
    doc "Distance measured in meters.";
  }

  attribute def Percent :> Real {
    doc "Percentage value from 0 to 100.";
  }

  attribute def ReliabilityFraction :> Real {
    doc "Reliability value from 0.0 to 1.0.";
  }

  enum def SystemMode {
    enum off;
    enum standby;
    enum initializing;
    enum normalService;
    enum degradedService;
    enum maintenance;
    enum safe;
    enum shutdown;
  }

  enum def FunctionPriority {
    enum critical;
    enum high;
    enum nominal;
    enum low;
  }

  enum def HealthLevel {
    enum healthy;
    enum warning;
    enum degraded;
    enum failed;
  }

  enum def CommandKind {
    enum configure;
    enum startService;
    enum stopService;
    enum queryStatus;
    enum resetFault;
    enum updatePolicy;
  }

  enum def AlertSeverity {
    enum advisory;
    enum caution;
    enum warning;
    enum emergency;
  }

  item def ElectricalSupply {
    attribute voltage: Voltage_V;
    attribute currentLimit: Current_A;
    attribute availablePower: Power_W;
    attribute storedEnergy: Energy_Wh;
  }

  item def PowerStatus {
    attribute busVoltage: Voltage_V;
    attribute loadCurrent: Current_A;
    attribute consumedPower: Power_W;
    attribute reserveEnergy: Energy_Wh;
    attribute health: HealthLevel;
  }

  item def ThermalStatus {
    attribute controllerTemperature: Temperature_degC;
    attribute powerStageTemperature: Temperature_degC;
    attribute ambientTemperature: Temperature_degC;
    attribute coolingDemand: Percent;
    attribute health: HealthLevel;
  }

  item def EnvironmentalStimulus {
    attribute rangeToFeature: Distance_m;
    attribute ambientTemperature: Temperature_degC;
    attribute illuminationLevel: Percent;
    attribute signalQuality: Percent;
    attribute sampleTime: Duration_s;
  }

  item def SensorObservation {
    attribute observationId: Integer;
    attribute confidence: Percent;
    attribute measuredRange: Distance_m;
    attribute measuredTemperature: Temperature_degC;
    attribute signalQuality: Percent;
    attribute acquisitionLatency: Duration_s;
  }

  item def FusedSituation {
    attribute situationId: Integer;
    attribute confidence: Percent;
    attribute estimatedRange: Distance_m;
    attribute estimatedTemperature: Temperature_degC;
    attribute uncertainty: Percent;
    attribute fusionLatency: Duration_s;
  }

  item def UserCommand {
    attribute commandId: Integer;
    attribute kind: CommandKind;
    attribute requestedMode: SystemMode;
    attribute priority: FunctionPriority;
    attribute maximumResponseTime: Duration_s;
  }

  item def FunctionPolicy {
    attribute commandAuthority: Percent;
    attribute energySavingTarget: Percent;
    attribute thermalMarginRequired: Temperature_degC;
    attribute minimumReliability: ReliabilityFraction;
  }

  item def ControlDecision {
    attribute decisionId: Integer;
    attribute targetMode: SystemMode;
    attribute computeConfidence: Percent;
    attribute priority: FunctionPriority;
    attribute requiredPower: Power_W;
    attribute validityDuration: Duration_s;
  }

  item def ActuatorCommand {
    attribute commandId: Integer;
    attribute driveLevel: Percent;
    attribute duration: Duration_s;
    attribute priority: FunctionPriority;
  }

  item def ActuatorFeedback {
    attribute commandId: Integer;
    attribute achievedLevel: Percent;
    attribute responseTime: Duration_s;
    attribute health: HealthLevel;
  }

  item def NetworkPacket {
    attribute packetId: Integer;
    attribute payloadSizeBytes: Integer;
    attribute priority: FunctionPriority;
    attribute transferLatency: Duration_s;
    attribute integrityCheckPassed: Boolean;
  }

  item def MissionProduct {
    attribute productId: Integer;
    attribute serviceMode: SystemMode;
    attribute confidence: Percent;
    attribute latency: Duration_s;
    attribute completeness: Percent;
  }

  item def Alert {
    attribute alertId: Integer;
    attribute severity: AlertSeverity;
    attribute relatedFunction: String;
    attribute detectionLatency: Duration_s;
    attribute acknowledged: Boolean;
  }

  port def DcPowerInputPort {
    in item supply: ElectricalSupply;
    out item status: PowerStatus;
  }

  port def DcPowerOutputPort {
    out item supply: ElectricalSupply;
    in item status: PowerStatus;
  }

  port def ThermalPort {
    in item thermalStatus: ThermalStatus;
    out item coolingRequest: ThermalStatus;
  }

  port def EnvironmentPort {
    in item stimulus: EnvironmentalStimulus;
  }

  port def SensorDataPort {
    out item observation: SensorObservation;
  }

  port def FusedDataPort {
    in item observation: SensorObservation;
    out item fusedSituation: FusedSituation;
  }

  port def CommandPort {
    in item command: UserCommand;
    out item response: MissionProduct;
    out item alert: Alert;
  }

  port def PolicyPort {
    in item policy: FunctionPolicy;
  }

  port def DecisionPort {
    in item fusedSituation: FusedSituation;
    in item command: UserCommand;
    out item decision: ControlDecision;
  }

  port def ActuationPort {
    out item actuatorCommand: ActuatorCommand;
    in item actuatorFeedback: ActuatorFeedback;
  }

  port def NetworkPort {
    in item inboundPacket: NetworkPacket;
    out item outboundPacket: NetworkPacket;
  }

  port def HealthPort {
    out item alert: Alert;
    out item powerStatus: PowerStatus;
    out item thermalStatus: ThermalStatus;
  }

  port def ServicePort {
    in item command: UserCommand;
    in item policy: FunctionPolicy;
    out item product: MissionProduct;
    out item alert: Alert;
  }

  action def RegulatePower {
    in item inputSupply: ElectricalSupply;
    out item regulatedSupply: ElectricalSupply;
    out item status: PowerStatus;
  }

  action def AcquireEnvironmentalInputs {
    in item stimulus: EnvironmentalStimulus;
    out item observation: SensorObservation;
  }

  action def FuseObservations {
    in item observation: SensorObservation;
    out item fusedSituation: FusedSituation;
  }

  action def InterpretUserCommand {
    in item command: UserCommand;
    in item policy: FunctionPolicy;
    out item acceptedCommand: UserCommand;
  }

  action def ComputeControlDecision {
    in item acceptedCommand: UserCommand;
    in item fusedSituation: FusedSituation;
    in item powerStatus: PowerStatus;
    in item thermalStatus: ThermalStatus;
    out item decision: ControlDecision;
  }

  action def DispatchActuation {
    in item decision: ControlDecision;
    out item actuatorCommand: ActuatorCommand;
    in item actuatorFeedback: ActuatorFeedback;
  }

  action def PublishServiceProduct {
    in item decision: ControlDecision;
    in item fusedSituation: FusedSituation;
    in item actuatorFeedback: ActuatorFeedback;
    out item product: MissionProduct;
  }

  action def MonitorSystemHealth {
    in item powerStatus: PowerStatus;
    in item thermalStatus: ThermalStatus;
    in item actuatorFeedback: ActuatorFeedback;
    out item alert: Alert;
  }

  action def CoordinateMultiFunctionService {
    doc "Primary high-level function: coordinate multiple integrated system functions so that external commands, environmental inputs, policy constraints, power availability, thermal condition, communication, and actuation feedback are transformed into a verified service product and timely alerts.";

    in item externalCommand: UserCommand;
    in item servicePolicy: FunctionPolicy;
    in item environmentalInput: EnvironmentalStimulus;
    in item externalPower: ElectricalSupply;
    in item actuatorFeedback: ActuatorFeedback;

    out item serviceProduct: MissionProduct;
    out item generatedAlert: Alert;

    action regulatePower: RegulatePower;
    action acquireInputs: AcquireEnvironmentalInputs;
    action fuseInputs: FuseObservations;
    action interpretCommand: InterpretUserCommand;
    action computeDecision: ComputeControlDecision;
    action dispatchActuation: DispatchActuation;
    action publishProduct: PublishServiceProduct;
    action monitorHealth: MonitorSystemHealth;

    flow externalPower to regulatePower.inputSupply;
    flow environmentalInput to acquireInputs.stimulus;
    flow acquireInputs.observation to fuseInputs.observation;
    flow externalCommand to interpretCommand.command;
    flow servicePolicy to interpretCommand.policy;
    flow interpretCommand.acceptedCommand to computeDecision.acceptedCommand;
    flow fuseInputs.fusedSituation to computeDecision.fusedSituation;
    flow regulatePower.status to computeDecision.powerStatus;
    flow computeDecision.decision to dispatchActuation.decision;
    flow actuatorFeedback to dispatchActuation.actuatorFeedback;
    flow computeDecision.decision to publishProduct.decision;
    flow fuseInputs.fusedSituation to publishProduct.fusedSituation;
    flow actuatorFeedback to publishProduct.actuatorFeedback;
    flow regulatePower.status to monitorHealth.powerStatus;
    flow actuatorFeedback to monitorHealth.actuatorFeedback;
    flow publishProduct.product to serviceProduct;
    flow monitorHealth.alert to generatedAlert;
  }

  state def MultiFunctionLifecycle {
    entry action initializeTelemetry;
    exit action storeFinalStatus;

    state off;
    state standby;
    state initializing;
    state normalService;
    state degradedService;
    state maintenance;
    state safe;
    state shutdown;

    transition initial then off;
    transition powerApplied first off then standby;
    transition beginInitialization first standby then initializing;
    transition initializationComplete first initializing then normalService;
    transition minorFaultDetected first normalService then degradedService;
    transition faultCleared first degradedService then normalService;
    transition maintenanceRequested first standby then maintenance;
    transition maintenanceComplete first maintenance then standby;
    transition criticalFaultDetected first normalService then safe;
    transition criticalFaultDetectedFromDegraded first degradedService then safe;
    transition resetAfterSafe first safe then standby;
    transition stopRequested first normalService then shutdown;
    transition stopRequestedFromStandby first standby then shutdown;
    transition shutdownComplete first shutdown then off;
  }

  part def PowerManagementFunction {
    attribute nominalInputVoltage: Voltage_V = 48.0;
    attribute regulatedBusVoltage: Voltage_V = 24.0;
    attribute maximumContinuousPower: Power_W = 1500.0;
    attribute energyReserve: Energy_Wh = 250.0;
    attribute conversionEfficiency: Percent = 94.0;

    port supplyIn: DcPowerInputPort;
    port sensorPowerOut: DcPowerOutputPort;
    port computePowerOut: DcPowerOutputPort;
    port communicationPowerOut: DcPowerOutputPort;
    port actuationPowerOut: DcPowerOutputPort;
    port thermalPowerOut: DcPowerOutputPort;
    port healthOut: HealthPort;

    perform action powerRegulation: RegulatePower;
  }

  part def SensingFunction {
    attribute sampleRate: Frequency_Hz = 50.0;
    attribute detectionRange: Distance_m = 120.0;
    attribute nominalPower: Power_W = 90.0;
    attribute observationConfidenceThreshold: Percent = 80.0;

    port environmentIn: EnvironmentPort;
    port powerIn: DcPowerInputPort;
    port observationOut: SensorDataPort;
    port healthOut: HealthPort;

    perform action acquisition: AcquireEnvironmentalInputs;
  }

  part def FusionFunction {
    attribute fusionCycleTime: Duration_s = 0.050;
    attribute minimumConfidence: Percent = 85.0;
    attribute nominalPower: Power_W = 120.0;

    port observationIn: FusedDataPort;
    port powerIn: DcPowerInputPort;
    port healthOut: HealthPort;

    perform action fusion: FuseObservations;
  }

  part def ControlComputationFunction {
    attribute processorClock: Frequency_Hz = 1200000000.0;
    attribute controlCycleTime: Duration_s = 0.100;
    attribute nominalPower: Power_W = 250.0;
    attribute minimumReliability: ReliabilityFraction = 0.995;

    port decisionInOut: DecisionPort;
    port powerIn: DcPowerInputPort;
    port healthOut: HealthPort;

    perform action decisionComputation: ComputeControlDecision;
  }

  part def CommunicationFunction {
    attribute wiredDataRate: DataRate_Mbps = 1000.0;
    attribute wirelessDataRate: DataRate_Mbps = 150.0;
    attribute maximumPacketLatency: Duration_s = 0.020;
    attribute nominalPower: Power_W = 80.0;

    port networkA: NetworkPort;
    port networkB: NetworkPort;
    port serviceCommand: CommandPort;
    port powerIn: DcPowerInputPort;
    port healthOut: HealthPort;
  }

  part def HumanInterfaceFunction {
    attribute displayRefreshRate: Frequency_Hz = 60.0;
    attribute commandDebounceTime: Duration_s = 0.150;
    attribute nominalPower: Power_W = 40.0;

    port operatorService: ServicePort;
    port commandOut: CommandPort;
    port powerIn: DcPowerInputPort;
    port healthOut: HealthPort;

    perform action commandInterpretation: InterpretUserCommand;
  }

  part def ActuationFunction {
    attribute maximumDrivePower: Power_W = 700.0;
    attribute responseTimeLimit: Duration_s = 0.250;
    attribute positioningAccuracy: Percent = 98.0;

    port actuation: ActuationPort;
    port powerIn: DcPowerInputPort;
    port healthOut: HealthPort;

    perform action actuationDispatch: DispatchActuation;
  }

  part def ThermalManagementFunction {
    attribute maximumControllerTemperature: Temperature_degC = 75.0;
    attribute maximumPowerStageTemperature: Temperature_degC = 90.0;
    attribute nominalCoolingPower: Power_W = 160.0;
    attribute thermalControlPeriod: Duration_s = 1.0;

    port thermalInOut: ThermalPort;
    port powerIn: DcPowerInputPort;
    port healthOut: HealthPort;
  }

  part def SafetySupervisionFunction {
    attribute faultDetectionInterval: Duration_s = 0.050;
    attribute safeTransitionLimit: Duration_s = 0.500;
    attribute minimumSafePowerReserve: Energy_Wh = 25.0;
    attribute requiredDiagnosticCoverage: Percent = 97.0;

    port powerHealthIn: HealthPort;
    port sensingHealthIn: HealthPort;
    port computeHealthIn: HealthPort;
    port communicationHealthIn: HealthPort;
    port actuationHealthIn: HealthPort;
    port thermalHealthIn: HealthPort;
    port alertOut: HealthPort;

    perform action healthMonitoring: MonitorSystemHealth;
  }

  part def ServicePublicationFunction {
    attribute publicationPeriod: Duration_s = 0.100;
    attribute minimumCompleteness: Percent = 95.0;
    attribute maximumServiceLatency: Duration_s = 0.500;

    port serviceOut: ServicePort;
    port powerIn: DcPowerInputPort;
    port healthOut: HealthPort;

    perform action productPublication: PublishServiceProduct;
  }

  part def MultiFunctionDataBackbone {
    attribute internalDataRate: DataRate_Mbps = 2000.0;
    attribute deterministicCycleTime: Duration_s = 0.010;
    attribute packetIntegrityTarget: ReliabilityFraction = 0.99999;

    port sensorNetwork: NetworkPort;
    port fusionNetwork: NetworkPort;
    port computeNetwork: NetworkPort;
    port communicationNetwork: NetworkPort;
    port operatorNetwork: NetworkPort;
    port actuationNetwork: NetworkPort;
    port safetyNetwork: NetworkPort;
    port publicationNetwork: NetworkPort;
  }

  part def MultiFunctionStructure {
    doc "A reusable structure that integrates several coordinated functions over shared power, data, health, and service interfaces.";

    attribute installedMassEstimate_kg: Real = 48.0;
    attribute designLife_h: Real = 35000.0;
    attribute nominalOperatingVoltage: Voltage_V = 48.0;
    attribute peakPowerLimit: Power_W = 1500.0;
    attribute normalAmbientMinimum: Temperature_degC = -20.0;
    attribute normalAmbientMaximum: Temperature_degC = 55.0;

    port externalPowerIn: DcPowerInputPort;
    port externalEnvironmentIn: EnvironmentPort;
    port operatorService: ServicePort;
    port externalActuation: ActuationPort;
    port externalNetwork: NetworkPort;
    port systemHealth: HealthPort;

    part powerManagement: PowerManagementFunction;
    part sensing: SensingFunction;
    part fusion: FusionFunction;
    part computation: ControlComputationFunction;
    part communication: CommunicationFunction;
    part humanInterface: HumanInterfaceFunction;
    part actuation: ActuationFunction;
    part thermalManagement: ThermalManagementFunction;
    part safetySupervision: SafetySupervisionFunction;
    part publication: ServicePublicationFunction;
    part dataBackbone: MultiFunctionDataBackbone;

    connect externalPowerIn to powerManagement.supplyIn;
    connect externalEnvironmentIn to sensing.environmentIn;
    connect operatorService to humanInterface.operatorService;
    connect externalActuation to actuation.actuation;
    connect externalNetwork to communication.networkA;
    connect systemHealth to safetySupervision.alertOut;

    connect powerManagement.sensorPowerOut to sensing.powerIn;
    connect powerManagement.computePowerOut to fusion.powerIn;
    connect powerManagement.computePowerOut to computation.powerIn;
    connect powerManagement.communicationPowerOut to communication.powerIn;
    connect powerManagement.communicationPowerOut to humanInterface.powerIn;
    connect powerManagement.actuationPowerOut to actuation.powerIn;
    connect powerManagement.thermalPowerOut to thermalManagement.powerIn;
    connect powerManagement.computePowerOut to publication.powerIn;

    connect sensing.observationOut to fusion.observationIn;
    connect communication.serviceCommand to humanInterface.commandOut;
    connect computation.decisionInOut to fusion.observationIn;
    connect computation.decisionInOut to communication.serviceCommand;
    connect actuation.healthOut to safetySupervision.actuationHealthIn;
    connect sensing.healthOut to safetySupervision.sensingHealthIn;
    connect fusion.healthOut to safetySupervision.computeHealthIn;
    connect computation.healthOut to safetySupervision.computeHealthIn;
    connect communication.healthOut to safetySupervision.communicationHealthIn;
    connect thermalManagement.healthOut to safetySupervision.thermalHealthIn;
    connect powerManagement.healthOut to safetySupervision.powerHealthIn;
    connect publication.serviceOut to operatorService;

    connect dataBackbone.sensorNetwork to sensing.healthOut;
    connect dataBackbone.fusionNetwork to fusion.healthOut;
    connect dataBackbone.computeNetwork to computation.healthOut;
    connect dataBackbone.communicationNetwork to communication.networkB;
    connect dataBackbone.operatorNetwork to humanInterface.healthOut;
    connect dataBackbone.actuationNetwork to actuation.healthOut;
    connect dataBackbone.safetyNetwork to safetySupervision.alertOut;
    connect dataBackbone.publicationNetwork to publication.healthOut;
  }

  part def IntegratedMultiFunctionSystem :> MultiFunctionStructure {
    doc "System based on the multi-function structure. Its primary function is to coordinate sensing, fusion, computation, communications, human interaction, actuation, power management, thermal management, safety supervision, and publication to deliver an integrated service response.";

    attribute targetAvailability: ReliabilityFraction = 0.997;
    attribute maximumEndToEndLatency: Duration_s = 0.500;
    attribute minimumServiceConfidence: Percent = 90.0;
    attribute minimumServiceCompleteness: Percent = 95.0;
    attribute degradedModePowerLimit: Power_W = 900.0;
    attribute safeModePowerLimit: Power_W = 300.0;

    exhibit state lifecycle: MultiFunctionLifecycle;

    perform action primaryFunction: CoordinateMultiFunctionService;
  }

  requirement def PrimaryFunctionRequirement {
    doc "The system shall provide a high-level multi-function service by coordinating power, sensing, data fusion, command interpretation, computation, communication, actuation, thermal management, safety supervision, and product publication to transform external commands and environmental inputs into a verified service product and alerts.";
    subject system: IntegratedMultiFunctionSystem;

    require constraint serviceConfidence {
      system.minimumServiceConfidence >= 90.0
    }

    require constraint serviceCompleteness {
      system.minimumServiceCompleteness >= 95.0
    }

    require constraint endToEndLatency {
      system.maximumEndToEndLatency <= 0.500
    }

    require constraint serviceAvailability {
      system.targetAvailability >= 0.997
    }
  }

  requirement def PowerDistributionRequirement {
    doc "The system shall distribute regulated electrical power to all internal functions while maintaining normal-service peak load at or below the defined peak power limit.";
    subject system: IntegratedMultiFunctionSystem;

    require constraint peakPowerLimit {
      system.peakPowerLimit <= 1500.0
    }

    require constraint nominalVoltage {
      system.nominalOperatingVoltage == 48.0
    }
  }

  requirement def SafetySupervisionRequirement {
    doc "The system shall detect critical faults and transition to the safe state within the specified safe transition time.";
    subject supervisor: SafetySupervisionFunction;

    require constraint faultDetectionTiming {
      supervisor.faultDetectionInterval <= 0.050
    }

    require constraint safeTransitionTiming {
      supervisor.safeTransitionLimit <= 0.500
    }

    require constraint diagnosticCoverage {
      supervisor.requiredDiagnosticCoverage >= 97.0
    }
  }

  requirement def ThermalProtectionRequirement {
    doc "The thermal management function shall maintain controller and power-stage temperatures within specified operating limits during normal service.";
    subject thermal: ThermalManagementFunction;

    require constraint controllerTemperatureLimit {
      thermal.maximumControllerTemperature <= 75.0
    }

    require constraint powerStageTemperatureLimit {
      thermal.maximumPowerStageTemperature <= 90.0
    }
  }

  requirement def CommunicationRequirement {
    doc "The communication function shall support deterministic internal and external message exchange with bounded latency.";
    subject communication: CommunicationFunction;

    require constraint wiredRate {
      communication.wiredDataRate >= 1000.0
    }

    require constraint packetLatency {
      communication.maximumPacketLatency <= 0.020
    }
  }

  requirement def ActuationRequirement {
    doc "The actuation function shall execute computed control decisions within the response time limit and report feedback for service verification.";
    subject actuation: ActuationFunction;

    require constraint responseLimit {
      actuation.responseTimeLimit <= 0.250
    }

    require constraint accuracy {
      actuation.positioningAccuracy >= 98.0
    }
  }

  part integratedMultiFunctionSystem: IntegratedMultiFunctionSystem {
    satisfy PrimaryFunctionRequirement by primaryFunction;
    satisfy PowerDistributionRequirement by powerManagement;
    satisfy SafetySupervisionRequirement by safetySupervision;
    satisfy ThermalProtectionRequirement by thermalManagement;
    satisfy CommunicationRequirement by communication;
    satisfy ActuationRequirement by actuation;
  }

}
