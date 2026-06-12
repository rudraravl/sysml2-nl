package MorphixChameleonSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Percentage :> Real {
    range = "0..100";
    unit = "%";
  }

  attribute def Length_mm :> Real {
    unit = "mm";
  }

  attribute def Mass_g :> Real {
    unit = "g";
  }

  attribute def Time_s :> Real {
    unit = "s";
  }

  attribute def Voltage_V :> Real {
    unit = "V";
  }

  attribute def Current_A :> Real {
    unit = "A";
  }

  attribute def Power_W :> Real {
    unit = "W";
  }

  attribute def Speed_mps :> Real {
    unit = "m/s";
  }

  attribute def Temperature_C :> Real {
    unit = "degC";
  }

  item def ElectricalEnergy {
    attribute voltage : Voltage_V;
    attribute current : Current_A;
    attribute power : Power_W;
  }

  item def MotionCommand {
    attribute requestedSpeed : Speed_mps;
    attribute requestedDirectionDegrees : Real;
    attribute requestedBodyMode : BodyModeKind;
  }

  item def TerrainObservation {
    attribute obstacleDistance : Length_mm;
    attribute surfaceInclineDegrees : Real;
    attribute surfaceGrip : Percentage;
    attribute ambientLight : Percentage;
  }

  item def UserCommand {
    attribute selectedMode : MissionModeKind;
    attribute requestedTransform : BodyModeKind;
    attribute requestedSpeed : Speed_mps;
  }

  item def StatusTelemetry {
    attribute batteryCharge : Percentage;
    attribute currentBodyMode : BodyModeKind;
    attribute currentMissionMode : MissionModeKind;
    attribute faultActive : Boolean;
    attribute bodyTemperature : Temperature_C;
  }

  enum def BodyModeKind {
    enum standard;
    enum lowProfile;
    enum highClearance;
    enum compactTurn;
    enum displayPose;
  }

  enum def MissionModeKind {
    enum standby;
    enum patrol;
    enum obstacleTraverse;
    enum demonstration;
    enum returnHome;
  }

  enum def FaultKind {
    enum none;
    enum lowBattery;
    enum actuatorJam;
    enum overTemperature;
    enum lostCommandLink;
  }

  port def PowerInputPort {
    in item energy : ElectricalEnergy;
  }

  port def PowerOutputPort {
    out item energy : ElectricalEnergy;
  }

  port def CommandInputPort {
    in item command : UserCommand;
  }

  port def MotionCommandPort {
    in item motionCommand : MotionCommand;
  }

  port def SensorOutputPort {
    out item observation : TerrainObservation;
  }

  port def TelemetryOutputPort {
    out item telemetry : StatusTelemetry;
  }

  port def MechanicalDrivePort {
    out item command : MotionCommand;
  }

  port def MorphingControlPort {
    in item requestedMode : BodyModeKind;
  }

  part def BatteryPack {
    attribute nominalVoltage : Voltage_V = 7.4;
    attribute capacity_mAh : Real = 2200.0;
    attribute stateOfCharge : Percentage;
    attribute maxContinuousCurrent : Current_A = 8.0;

    port powerOut : PowerOutputPort;
  }

  part def PowerDistributionUnit {
    attribute regulatedLogicVoltage : Voltage_V = 5.0;
    attribute regulatedServoVoltage : Voltage_V = 6.0;
    attribute maximumOutputPower : Power_W = 35.0;

    port batteryIn : PowerInputPort;
    port logicPowerOut : PowerOutputPort;
    port actuatorPowerOut : PowerOutputPort;
    port sensorPowerOut : PowerOutputPort;
  }

  part def OperatorInterface {
    attribute commandLinkRange : Length_mm = 30000.0;
    attribute commandLatency : Time_s = 0.08;

    port commandOut : CommandInputPort;
    port telemetryIn : TelemetryOutputPort;
  }

  part def TerrainSensorSuite {
    attribute forwardRange : Length_mm = 1200.0;
    attribute groundClearanceResolution : Length_mm = 2.0;
    attribute samplePeriod : Time_s = 0.05;

    port powerIn : PowerInputPort;
    port observationOut : SensorOutputPort;
  }

  part def CentralController {
    attribute processorClockMHz : Real = 160.0;
    attribute controlCyclePeriod : Time_s = 0.02;
    attribute activeFault : FaultKind = FaultKind::none;
    attribute missionMode : MissionModeKind = MissionModeKind::standby;

    port powerIn : PowerInputPort;
    port commandIn : CommandInputPort;
    port terrainIn : SensorOutputPort;
    port driveCommandOut : MechanicalDrivePort;
    port morphCommandOut : MorphingControlPort;
    port telemetryOut : TelemetryOutputPort;

    perform action interpretUserCommand;
    perform action evaluateTerrain;
    perform action selectBodyMode;
    perform action publishTelemetry;
  }

  part def MorphingBodyFrame {
    attribute mass : Mass_g = 820.0;
    attribute standardLength : Length_mm = 310.0;
    attribute lowProfileHeight : Length_mm = 55.0;
    attribute highClearanceHeight : Length_mm = 145.0;
    attribute currentMode : BodyModeKind = BodyModeKind::standard;
    attribute transformationTime : Time_s = 1.5;

    port powerIn : PowerInputPort;
    port modeRequestIn : MorphingControlPort;

    part leftMorphLinkage : MorphLinkage;
    part rightMorphLinkage : MorphLinkage;
    part dorsalShell : AdaptiveShell;
    part tailStabilizer : TailStabilizer;

    perform action transformToRequestedMode;
    perform action lockBodyGeometry;
  }

  part def MorphLinkage {
    attribute travel : Length_mm = 75.0;
    attribute maxTorqueNm : Real = 1.8;
    attribute positionError : Length_mm;
  }

  part def AdaptiveShell {
    attribute shellCompliance : Percentage = 35.0;
    attribute camouflageCoverage : Percentage = 80.0;
  }

  part def TailStabilizer {
    attribute extensionLength : Length_mm = 95.0;
    attribute maxDeflectionDegrees : Real = 40.0;
  }

  part def DriveSystem {
    attribute maximumSpeed : Speed_mps = 1.2;
    attribute minimumTurningRadius : Length_mm = 180.0;
    attribute climbingInclineDegrees : Real = 30.0;

    port powerIn : PowerInputPort;
    port driveCommandIn : MotionCommandPort;

    part leftTrack : TrackModule;
    part rightTrack : TrackModule;
    part frontClawWheel : ClawWheelModule;
    part rearClawWheel : ClawWheelModule;

    perform action executeDriveCommand;
    perform action stabilizeDuringTransformation;
  }

  part def TrackModule {
    attribute trackWidth : Length_mm = 38.0;
    attribute contactLength : Length_mm = 130.0;
    attribute commandedSpeed : Speed_mps;
  }

  part def ClawWheelModule {
    attribute diameter : Length_mm = 72.0;
    attribute clawCount : Integer = 8;
    attribute deployed : Boolean;
  }

  part def EnvironmentalAdaptationSystem {
    attribute colorMatchAccuracy : Percentage = 70.0;
    attribute shellPatternUpdateTime : Time_s = 0.8;

    port powerIn : PowerInputPort;
    port terrainIn : SensorOutputPort;

    part colorSensor : ColorSensor;
    part shellPatternActuator : ShellPatternActuator;

    perform action estimateBackgroundColor;
    perform action updateShellPattern;
  }

  part def ColorSensor {
    attribute spectralChannels : Integer = 6;
    attribute samplePeriod : Time_s = 0.10;
  }

  part def ShellPatternActuator {
    attribute activeSegments : Integer = 24;
    attribute segmentResponseTime : Time_s = 0.20;
  }

  part def MorphixChameleon {
    attribute systemMass : Mass_g = 1450.0;
    attribute nominalOperatingTime : Time_s = 2700.0;
    attribute primaryFunction : String = "Adapt body geometry and locomotion mode to traverse varied terrain while presenting chameleon-like environmental adaptation.";

    port operatorCommandIn : CommandInputPort;
    port telemetryOut : TelemetryOutputPort;

    part battery : BatteryPack;
    part powerDistribution : PowerDistributionUnit;
    part controller : CentralController;
    part terrainSensors : TerrainSensorSuite;
    part morphingBody : MorphingBodyFrame;
    part driveSystem : DriveSystem;
    part adaptationSystem : EnvironmentalAdaptationSystem;

    connect battery.powerOut to powerDistribution.batteryIn;
    connect powerDistribution.logicPowerOut to controller.powerIn;
    connect powerDistribution.sensorPowerOut to terrainSensors.powerIn;
    connect powerDistribution.sensorPowerOut to adaptationSystem.powerIn;
    connect powerDistribution.actuatorPowerOut to morphingBody.powerIn;
    connect powerDistribution.actuatorPowerOut to driveSystem.powerIn;

    connect operatorCommandIn to controller.commandIn;
    connect terrainSensors.observationOut to controller.terrainIn;
    connect terrainSensors.observationOut to adaptationSystem.terrainIn;
    connect controller.driveCommandOut to driveSystem.driveCommandIn;
    connect controller.morphCommandOut to morphingBody.modeRequestIn;
    connect controller.telemetryOut to telemetryOut;

    perform action provideAdaptiveTerrainMobility;
  }

  action def interpretUserCommand {
    in item command : UserCommand;
    out attribute missionMode : MissionModeKind;
    out attribute requestedSpeed : Speed_mps;
  }

  action def evaluateTerrain {
    in item observation : TerrainObservation;
    out attribute obstacleDetected : Boolean;
    out attribute recommendedBodyMode : BodyModeKind;
  }

  action def selectBodyMode {
    in attribute missionMode : MissionModeKind;
    in attribute recommendedBodyMode : BodyModeKind;
    out attribute selectedBodyMode : BodyModeKind;
  }

  action def publishTelemetry {
    in attribute batteryCharge : Percentage;
    in attribute currentBodyMode : BodyModeKind;
    in attribute currentMissionMode : MissionModeKind;
    in attribute activeFault : FaultKind;
    out item telemetry : StatusTelemetry;
  }

  action def transformToRequestedMode {
    in item requestedMode : BodyModeKind;
    out attribute currentMode : BodyModeKind;
  }

  action def lockBodyGeometry {
    in attribute currentMode : BodyModeKind;
    out attribute locked : Boolean;
  }

  action def executeDriveCommand {
    in item motionCommand : MotionCommand;
    out attribute leftTrackSpeed : Speed_mps;
    out attribute rightTrackSpeed : Speed_mps;
  }

  action def stabilizeDuringTransformation {
    in attribute bodyMode : BodyModeKind;
    out attribute stabilizerAngleDegrees : Real;
  }

  action def estimateBackgroundColor {
    in item observation : TerrainObservation;
    out attribute targetPatternIntensity : Percentage;
  }

  action def updateShellPattern {
    in attribute targetPatternIntensity : Percentage;
    out attribute achievedMatch : Percentage;
  }

  action def provideAdaptiveTerrainMobility {
    first start;
    then senseTerrain;
    then chooseConfiguration;
    then transformBody;
    then commandLocomotion;
    then updateAppearance;
    then reportStatus;
    then done;

    action start;
    action senseTerrain : evaluateTerrain;
    action chooseConfiguration : selectBodyMode;
    action transformBody : transformToRequestedMode;
    action commandLocomotion : executeDriveCommand;
    action updateAppearance : updateShellPattern;
    action reportStatus : publishTelemetry;
    action done;
  }

  state def MorphixOperatingStates {
    entry action publishTelemetry;

    state off;
    state initializing;
    state standby;
    state adaptiveTraverse;
    state morphing;
    state demonstration;
    state returnHome;
    state fault;

    transition initial then off;
    transition powerApplied first off then initializing;
    transition initializationComplete first initializing then standby;
    transition patrolRequested first standby then adaptiveTraverse;
    transition obstacleRequiresReconfiguration first adaptiveTraverse then morphing;
    transition transformationComplete first morphing then adaptiveTraverse;
    transition demonstrationRequested first standby then demonstration;
    transition returnRequested first adaptiveTraverse then returnHome;
    transition homeReached first returnHome then standby;
    transition faultDetected first standby then fault;
    transition traverseFaultDetected first adaptiveTraverse then fault;
    transition morphFaultDetected first morphing then fault;
    transition faultCleared first fault then standby;
    transition shutdownRequested first standby then off;
  }

  requirement def PrimaryFunctionRequirement {
    subject chameleon : MorphixChameleon;
    require constraint {
      chameleon.primaryFunction == "Adapt body geometry and locomotion mode to traverse varied terrain while presenting chameleon-like environmental adaptation."
    }
  }

  requirement def MobilityRequirement {
    subject chameleon : MorphixChameleon;
    require constraint {
      chameleon.driveSystem.maximumSpeed >= 1.0 and
      chameleon.driveSystem.climbingInclineDegrees >= 25.0
    }
  }

  requirement def TransformationRequirement {
    subject chameleon : MorphixChameleon;
    require constraint {
      chameleon.morphingBody.transformationTime <= 2.0 and
      chameleon.morphingBody.highClearanceHeight >= 120.0 and
      chameleon.morphingBody.lowProfileHeight <= 65.0
    }
  }

  requirement def EnduranceRequirement {
    subject chameleon : MorphixChameleon;
    require constraint {
      chameleon.nominalOperatingTime >= 2400.0
    }
  }

  requirement def TerrainSensingRequirement {
    subject chameleon : MorphixChameleon;
    require constraint {
      chameleon.terrainSensors.forwardRange >= 1000.0 and
      chameleon.terrainSensors.samplePeriod <= 0.10
    }
  }

  requirement def ChameleonAdaptationRequirement {
    subject chameleon : MorphixChameleon;
    require constraint {
      chameleon.adaptationSystem.colorMatchAccuracy >= 65.0 and
      chameleon.adaptationSystem.shellPatternUpdateTime <= 1.0
    }
  }

  requirement def SafetyFaultRequirement {
    subject chameleon : MorphixChameleon;
    require constraint {
      chameleon.controller.controlCyclePeriod <= 0.05
    }
  }

  part morphixChameleonSystem : MorphixChameleon;

  satisfy PrimaryFunctionRequirement by morphixChameleonSystem;
  satisfy MobilityRequirement by morphixChameleonSystem;
  satisfy TransformationRequirement by morphixChameleonSystem;
  satisfy EnduranceRequirement by morphixChameleonSystem;
  satisfy TerrainSensingRequirement by morphixChameleonSystem;
  satisfy ChameleonAdaptationRequirement by morphixChameleonSystem;
  satisfy SafetyFaultRequirement by morphixChameleonSystem;
}