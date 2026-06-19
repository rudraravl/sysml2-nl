package EngineKnockManagementModel {
  import ScalarValues::*;

  attribute def EngineSpeed {
    attribute value : Real;
    attribute unit : String = "rpm";
  }

  attribute def Frequency {
    attribute value : Real;
    attribute unit : String = "kHz";
  }

  attribute def Acceleration {
    attribute value : Real;
    attribute unit : String = "g";
  }

  attribute def CrankAngle {
    attribute value : Real;
    attribute unit : String = "degCA";
  }

  attribute def Pressure {
    attribute value : Real;
    attribute unit : String = "bar";
  }

  attribute def Temperature {
    attribute value : Real;
    attribute unit : String = "degC";
  }

  attribute def TimeDuration {
    attribute value : Real;
    attribute unit : String = "ms";
  }

  attribute def Voltage {
    attribute value : Real;
    attribute unit : String = "V";
  }

  attribute def Current {
    attribute value : Real;
    attribute unit : String = "A";
  }

  attribute def Torque {
    attribute value : Real;
    attribute unit : String = "N.m";
  }

  attribute def FuelMass {
    attribute value : Real;
    attribute unit : String = "mg";
  }

  attribute def LambdaRatio {
    attribute value : Real;
    attribute unit : String = "ratio";
  }

  attribute def KnockIndex {
    attribute value : Real;
    attribute unit : String = "normalized";
  }

  enum def KnockSeverityKind {
    enum noKnock;
    enum traceKnock;
    enum lightKnock;
    enum moderateKnock;
    enum severeKnock;
  }

  enum def ControllerHealthKind {
    enum nominal;
    enum degraded;
    enum failed;
  }

  enum def FuelGradeKind {
    enum regular87;
    enum midgrade89;
    enum premium91;
    enum premium93;
  }

  item def CombustionVibration {
    attribute cylinderNumber : Integer;
    attribute crankWindowStart : CrankAngle;
    attribute crankWindowEnd : CrankAngle;
    attribute peakAcceleration : Acceleration;
    attribute dominantFrequency : Frequency;
  }

  item def KnockSensorSample {
    attribute sensorId : Integer;
    attribute cylinderNumber : Integer;
    attribute sampleTime : TimeDuration;
    attribute bandPassedAcceleration : Acceleration;
    attribute dominantFrequency : Frequency;
    attribute engineSpeed : EngineSpeed;
  }

  item def CrankPositionSample {
    attribute crankAngle : CrankAngle;
    attribute engineSpeed : EngineSpeed;
    attribute valid : Boolean;
  }

  item def ManifoldCondition {
    attribute manifoldPressure : Pressure;
    attribute intakeAirTemperature : Temperature;
    attribute lambda : LambdaRatio;
  }

  item def KnockAssessment {
    attribute cylinderNumber : Integer;
    attribute knockIndex : KnockIndex;
    attribute severity : KnockSeverityKind;
    attribute confidence : Real;
  }

  item def IgnitionTimingCommand {
    attribute cylinderNumber : Integer;
    attribute sparkAdvance : CrankAngle;
    attribute retardFromBase : CrankAngle;
    attribute dwellTime : TimeDuration;
  }

  item def FuelCommand {
    attribute cylinderNumber : Integer;
    attribute injectionMass : FuelMass;
    attribute enrichmentLambda : LambdaRatio;
  }

  item def TorqueReport {
    attribute deliveredTorque : Torque;
    attribute requestedTorque : Torque;
    attribute torqueReductionActive : Boolean;
  }

  item def ElectricalPower {
    attribute supplyVoltage : Voltage;
    attribute availableCurrent : Current;
  }

  item def DiagnosticStatus {
    attribute health : ControllerHealthKind;
    attribute activeKnockCylinder : Integer;
    attribute maximumObservedKnockIndex : KnockIndex;
    attribute limpHomeActive : Boolean;
  }

  item def DriverInformation {
    attribute messageCode : Integer;
    attribute knockMitigationActive : Boolean;
    attribute serviceRequired : Boolean;
  }

  port def VibrationOutputPort {
    out item vibration : CombustionVibration;
  }

  port def VibrationInputPort {
    in item vibration : CombustionVibration;
  }

  port def KnockSampleOutputPort {
    out item sample : KnockSensorSample;
  }

  port def KnockSampleInputPort {
    in item sample : KnockSensorSample;
  }

  port def CrankPositionOutputPort {
    out item crankPosition : CrankPositionSample;
  }

  port def CrankPositionInputPort {
    in item crankPosition : CrankPositionSample;
  }

  port def ManifoldConditionOutputPort {
    out item condition : ManifoldCondition;
  }

  port def ManifoldConditionInputPort {
    in item condition : ManifoldCondition;
  }

  port def IgnitionTimingCommandOutputPort {
    out item command : IgnitionTimingCommand;
  }

  port def IgnitionTimingCommandInputPort {
    in item command : IgnitionTimingCommand;
  }

  port def FuelCommandOutputPort {
    out item command : FuelCommand;
  }

  port def FuelCommandInputPort {
    in item command : FuelCommand;
  }

  port def TorqueReportOutputPort {
    out item report : TorqueReport;
  }

  port def TorqueReportInputPort {
    in item report : TorqueReport;
  }

  port def ElectricalPowerOutputPort {
    out item power : ElectricalPower;
  }

  port def ElectricalPowerInputPort {
    in item power : ElectricalPower;
  }

  port def DiagnosticStatusOutputPort {
    out item status : DiagnosticStatus;
  }

  port def DiagnosticStatusInputPort {
    in item status : DiagnosticStatus;
  }

  port def DriverInformationOutputPort {
    out item information : DriverInformation;
  }

  port def DriverInformationInputPort {
    in item information : DriverInformation;
  }

  action def SenseBlockVibration {
    in item vibration : CombustionVibration;
    out item sample : KnockSensorSample;
    attribute nominalSensorResonance : Frequency {
      :>> value = 6.8;
      :>> unit = "kHz";
    }
  }

  action def BandPassFilterKnockSignal {
    in item rawSample : KnockSensorSample;
    out item filteredSample : KnockSensorSample;
    attribute lowerCutoff : Frequency {
      :>> value = 5.0;
      :>> unit = "kHz";
    }
    attribute upperCutoff : Frequency {
      :>> value = 9.0;
      :>> unit = "kHz";
    }
  }

  action def ComputeKnockIndex {
    in item filteredSample : KnockSensorSample;
    in item crankPosition : CrankPositionSample;
    out item assessment : KnockAssessment;
    attribute normalCombustionLimit : KnockIndex {
      :>> value = 0.20;
      :>> unit = "normalized";
    }
    attribute severeKnockLimit : KnockIndex {
      :>> value = 0.75;
      :>> unit = "normalized";
    }
  }

  action def ComputeKnockMitigation {
    in item assessment : KnockAssessment;
    in item manifoldCondition : ManifoldCondition;
    out item ignitionCommand : IgnitionTimingCommand;
    out item fuelCommand : FuelCommand;
    attribute maximumSparkRetard : CrankAngle {
      :>> value = 12.0;
      :>> unit = "degCA";
    }
    attribute enrichmentLimit : LambdaRatio {
      :>> value = 0.92;
      :>> unit = "ratio";
    }
  }

  action def RestorePerformanceAfterKnock {
    in item assessment : KnockAssessment;
    out item ignitionCommand : IgnitionTimingCommand;
    attribute advanceRecoveryRate : CrankAngle {
      :>> value = 0.5;
      :>> unit = "degCA";
    }
  }

  action def PublishDiagnostics {
    in item assessment : KnockAssessment;
    in item torqueReport : TorqueReport;
    out item status : DiagnosticStatus;
    out item driverInformation : DriverInformation;
  }

  action def PrimaryKnockManagementFunction {
    doc /* Primary function: continuously detect abnormal engine knock from combustion vibration and crank position, classify severity by cylinder, and command spark retard or mixture enrichment to protect the engine while preserving torque and drivability. */
    in item sensedKnockSample : KnockSensorSample;
    in item crankPosition : CrankPositionSample;
    in item manifoldCondition : ManifoldCondition;
    out item ignitionCommand : IgnitionTimingCommand;
    out item fuelCommand : FuelCommand;
    out item diagnosticStatus : DiagnosticStatus;
  }

  state def EngineCombustionStates {
    entry; then stopped;
    state stopped;
    state cranking;
    state normalCombustion;
    state traceKnockCombustion;
    state protectedCombustion;
    state shutdown;
    transition startCrank first stopped then cranking;
    transition achieveIdle first cranking then normalCombustion;
    transition traceKnockDetected first normalCombustion then traceKnockCombustion;
    transition mitigationApplied first traceKnockCombustion then protectedCombustion;
    transition knockCleared first protectedCombustion then normalCombustion;
    transition stopRequested first normalCombustion then shutdown;
  }

  state def KnockControllerOperatingStates {
    entry; then powerOff;
    state powerOff;
    state selfTest;
    state monitoring;
    state classifyingKnock;
    state mitigatingKnock;
    state recoveringTiming;
    state degradedOperation;
    state faultLatched;
    transition powerApplied first powerOff then selfTest;
    transition selfTestPassed first selfTest then monitoring;
    transition sampleWindowComplete first monitoring then classifyingKnock;
    transition noKnockFound first classifyingKnock then monitoring;
    transition knockFound first classifyingKnock then mitigatingKnock;
    transition knockSuppressed first mitigatingKnock then recoveringTiming;
    transition baseTimingRestored first recoveringTiming then monitoring;
    transition sensorDegraded first monitoring then degradedOperation;
    transition unrecoverableFault first degradedOperation then faultLatched;
  }

  part def SparkIgnitionEngine {
    attribute numberOfCylinders : Integer = 4;
    attribute compressionRatio : Real = 10.5;
    attribute fuelGrade : FuelGradeKind = FuelGradeKind::regular87;
    attribute coolantTemperature : Temperature {
      :>> value = 92.0;
      :>> unit = "degC";
    }
    attribute nominalIdleSpeed : EngineSpeed {
      :>> value = 750.0;
      :>> unit = "rpm";
    }
    port vibrationOut : VibrationOutputPort;
    port crankPositionOut : CrankPositionOutputPort;
    port manifoldConditionOut : ManifoldConditionOutputPort;
    port ignitionTimingIn : IgnitionTimingCommandInputPort;
    port fuelCommandIn : FuelCommandInputPort;
    port torqueReportOut : TorqueReportOutputPort;
    state combustionState : EngineCombustionStates;
  }

  part def PiezoelectricKnockSensor {
    attribute sensorId : Integer;
    attribute mountedCylinderPairA : Integer;
    attribute mountedCylinderPairB : Integer;
    attribute sensitivity : Real = 26.0;
    attribute sensitivityUnit : String = "mV/g";
    attribute resonantFrequency : Frequency {
      :>> value = 6.8;
      :>> unit = "kHz";
    }
    port vibrationIn : VibrationInputPort;
    port powerIn : ElectricalPowerInputPort;
    port sampleOut : KnockSampleOutputPort;
    action sense : SenseBlockVibration;
  }

  part def CrankshaftPositionSensor {
    attribute teethOnReluctorWheel : Integer = 60;
    attribute missingTeeth : Integer = 2;
    attribute angularResolution : CrankAngle {
      :>> value = 6.0;
      :>> unit = "degCA";
    }
    port powerIn : ElectricalPowerInputPort;
    port crankPositionOut : CrankPositionOutputPort;
  }

  part def ManifoldSensorSet {
    attribute pressureRange : Pressure {
      :>> value = 2.5;
      :>> unit = "bar";
    }
    attribute temperatureRange : Temperature {
      :>> value = 150.0;
      :>> unit = "degC";
    }
    port powerIn : ElectricalPowerInputPort;
    port conditionOut : ManifoldConditionOutputPort;
  }

  part def IgnitionCoilDriver {
    attribute maximumRetardAuthority : CrankAngle {
      :>> value = 15.0;
      :>> unit = "degCA";
    }
    attribute minimumDwellTime : TimeDuration {
      :>> value = 1.8;
      :>> unit = "ms";
    }
    port powerIn : ElectricalPowerInputPort;
    port commandIn : IgnitionTimingCommandInputPort;
    port timingOut : IgnitionTimingCommandOutputPort;
  }

  part def FuelInjectorDriver {
    attribute minimumPulseFuelMass : FuelMass {
      :>> value = 1.0;
      :>> unit = "mg";
    }
    attribute maximumPulseFuelMass : FuelMass {
      :>> value = 65.0;
      :>> unit = "mg";
    }
    port powerIn : ElectricalPowerInputPort;
    port commandIn : FuelCommandInputPort;
    port fuelOut : FuelCommandOutputPort;
  }

  part def KnockControlUnit {
    attribute processorClock : Frequency {
      :>> value = 160000.0;
      :>> unit = "kHz";
    }
    attribute controlLoopPeriod : TimeDuration {
      :>> value = 1.0;
      :>> unit = "ms";
    }
    attribute maximumKnockMitigationLatency : TimeDuration {
      :>> value = 8.0;
      :>> unit = "ms";
    }
    attribute allowableSteadyKnockIndex : KnockIndex {
      :>> value = 0.20;
      :>> unit = "normalized";
    }
    attribute failSafeSparkRetard : CrankAngle {
      :>> value = 8.0;
      :>> unit = "degCA";
    }
    port powerIn : ElectricalPowerInputPort;
    port knockSampleIn1 : KnockSampleInputPort;
    port knockSampleIn2 : KnockSampleInputPort;
    port crankPositionIn : CrankPositionInputPort;
    port manifoldConditionIn : ManifoldConditionInputPort;
    port torqueReportIn : TorqueReportInputPort;
    port ignitionCommandOut : IgnitionTimingCommandOutputPort;
    port fuelCommandOut : FuelCommandOutputPort;
    port diagnosticStatusOut : DiagnosticStatusOutputPort;
    port driverInformationOut : DriverInformationOutputPort;
    action primaryFunction : PrimaryKnockManagementFunction;
    action filterBank1 : BandPassFilterKnockSignal;
    action filterBank2 : BandPassFilterKnockSignal;
    action computeIndex : ComputeKnockIndex;
    action computeMitigation : ComputeKnockMitigation;
    action restorePerformance : RestorePerformanceAfterKnock;
    action publishDiagnostics : PublishDiagnostics;
    state operatingState : KnockControllerOperatingStates;
  }

  part def VehicleElectricalPowerSupply {
    attribute nominalVoltage : Voltage {
      :>> value = 12.0;
      :>> unit = "V";
    }
    attribute maximumCurrent : Current {
      :>> value = 20.0;
      :>> unit = "A";
    }
    port powerOut1 : ElectricalPowerOutputPort;
    port powerOut2 : ElectricalPowerOutputPort;
    port powerOut3 : ElectricalPowerOutputPort;
    port powerOut4 : ElectricalPowerOutputPort;
    port powerOut5 : ElectricalPowerOutputPort;
    port powerOut6 : ElectricalPowerOutputPort;
  }

  part def DiagnosticGateway {
    attribute diagnosticMessagePeriod : TimeDuration {
      :>> value = 100.0;
      :>> unit = "ms";
    }
    port statusIn : DiagnosticStatusInputPort;
    port driverInformationIn : DriverInformationInputPort;
  }

  part def EngineKnockManagementSystem {
    doc /* High-level system purpose: protect a spark-ignition engine from damaging knock by sensing block vibration, estimating knock severity per cylinder, and adjusting ignition timing and fuel delivery in real time. */
    attribute protectedCylinderCount : Integer = 4;
    attribute designServiceLife : TimeDuration {
      :>> value = 600000000.0;
      :>> unit = "ms";
    }

    part engine : SparkIgnitionEngine;
    part knockSensorBank1 : PiezoelectricKnockSensor {
      :>> sensorId = 1;
      :>> mountedCylinderPairA = 1;
      :>> mountedCylinderPairB = 4;
    }
    part knockSensorBank2 : PiezoelectricKnockSensor {
      :>> sensorId = 2;
      :>> mountedCylinderPairA = 2;
      :>> mountedCylinderPairB = 3;
    }
    part crankSensor : CrankshaftPositionSensor;
    part manifoldSensors : ManifoldSensorSet;
    part controller : KnockControlUnit;
    part ignitionDriver : IgnitionCoilDriver;
    part injectorDriver : FuelInjectorDriver;
    part powerSupply : VehicleElectricalPowerSupply;
    part diagnosticGateway : DiagnosticGateway;

    connect engine.vibrationOut to knockSensorBank1.vibrationIn;
    connect engine.vibrationOut to knockSensorBank2.vibrationIn;
    connect knockSensorBank1.sampleOut to controller.knockSampleIn1;
    connect knockSensorBank2.sampleOut to controller.knockSampleIn2;
    connect crankSensor.crankPositionOut to controller.crankPositionIn;
    connect manifoldSensors.conditionOut to controller.manifoldConditionIn;
    connect engine.torqueReportOut to controller.torqueReportIn;
    connect controller.ignitionCommandOut to ignitionDriver.commandIn;
    connect ignitionDriver.timingOut to engine.ignitionTimingIn;
    connect controller.fuelCommandOut to injectorDriver.commandIn;
    connect injectorDriver.fuelOut to engine.fuelCommandIn;
    connect controller.diagnosticStatusOut to diagnosticGateway.statusIn;
    connect controller.driverInformationOut to diagnosticGateway.driverInformationIn;
    connect powerSupply.powerOut1 to controller.powerIn;
    connect powerSupply.powerOut2 to knockSensorBank1.powerIn;
    connect powerSupply.powerOut3 to knockSensorBank2.powerIn;
    connect powerSupply.powerOut4 to crankSensor.powerIn;
    connect powerSupply.powerOut5 to manifoldSensors.powerIn;
    connect powerSupply.powerOut6 to ignitionDriver.powerIn;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall continuously manage engine knock by detecting abnormal combustion vibration, identifying affected cylinders, and commanding mitigation at a high level through ignition retard and fuel enrichment. */
    subject system : EngineKnockManagementSystem;
    require constraint {
      system.protectedCylinderCount == 4
    }
  }

  requirement def KnockDetectionLatencyRequirement {
    doc /* The controller shall complete knock detection and mitigation command generation within 10 ms from the end of the crank-angle sensing window. */
    subject controller : KnockControlUnit;
    require constraint {
      controller.maximumKnockMitigationLatency.value <= 10.0
    }
  }

  requirement def KnockLimitRequirement {
    doc /* During steady operation after mitigation, the managed normalized knock index shall not exceed 0.20 for any protected cylinder. */
    subject controller : KnockControlUnit;
    require constraint {
      controller.allowableSteadyKnockIndex.value <= 0.20
    }
  }

  requirement def SparkRetardAuthorityRequirement {
    doc /* The ignition path shall provide sufficient spark retard authority to suppress severe knock without exceeding calibrated engine protection limits. */
    subject ignitionDriver : IgnitionCoilDriver;
    require constraint {
      ignitionDriver.maximumRetardAuthority.value >= 12.0
    }
  }

  requirement def FailSafeRequirement {
    doc /* If knock sensing becomes degraded, the controller shall enter degraded operation and apply fail-safe spark retard to protect the engine. */
    subject controller : KnockControlUnit;
    require constraint {
      controller.failSafeSparkRetard.value >= 8.0
    }
  }

  part engineKnockManagementSystem : EngineKnockManagementSystem;

  requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
    subject system = engineKnockManagementSystem;
  }

  requirement knockDetectionLatencyRequirement : KnockDetectionLatencyRequirement {
    subject controller = engineKnockManagementSystem.controller;
  }

  requirement knockLimitRequirement : KnockLimitRequirement {
    subject controller = engineKnockManagementSystem.controller;
  }

  requirement sparkRetardAuthorityRequirement : SparkRetardAuthorityRequirement {
    subject ignitionDriver = engineKnockManagementSystem.ignitionDriver;
  }

  requirement failSafeRequirement : FailSafeRequirement {
    subject controller = engineKnockManagementSystem.controller;
  }
}
