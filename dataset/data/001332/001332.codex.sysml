package AdaptableRoboticsModel {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  enum def MissionMode {
    enum idle;
    enum mapping;
    enum transport;
    enum inspection;
    enum assistance;
    enum recovery;
  }

  enum def TerrainClass {
    enum smoothFloor;
    enum unevenGround;
    enum stairs;
    enum ramp;
    enum cluttered;
    enum unknown;
  }

  enum def HealthState {
    enum nominal;
    enum degraded;
    enum faulted;
    enum safeStop;
  }

  attribute def Percentage :> Real;
  attribute def Speed_mps :> Real;
  attribute def Distance_m :> Real;
  attribute def Mass_kg :> Real;
  attribute def Energy_Wh :> Real;
  attribute def Power_W :> Real;
  attribute def Force_N :> Real;
  attribute def Time_s :> Real;
  attribute def Angle_deg :> Real;

  item def MissionCommand {
    attribute requestedMode : MissionMode;
    attribute destinationX_m : Distance_m;
    attribute destinationY_m : Distance_m;
    attribute payloadRequest_kg : Mass_kg;
    attribute priority : Integer;
  }

  item def RobotStatus {
    attribute activeMode : MissionMode;
    attribute health : HealthState;
    attribute batteryStateOfCharge_pct : Percentage;
    attribute estimatedRemainingRuntime_s : Time_s;
    attribute currentSpeed_mps : Speed_mps;
    attribute localizationConfidence_pct : Percentage;
  }

  item def WorldModel {
    attribute mappedArea_m2 : Real;
    attribute obstacleCount : Integer;
    attribute dominantTerrain : TerrainClass;
    attribute confidence_pct : Percentage;
  }

  item def MotionCommand {
    attribute targetLinearSpeed_mps : Speed_mps;
    attribute targetAngularRate_degps : Real;
    attribute targetPostureAngle_deg : Angle_deg;
  }

  item def SensorFrame {
    attribute timestamp_s : Time_s;
    attribute rangeResolution_m : Distance_m;
    attribute fieldOfView_deg : Angle_deg;
    attribute confidence_pct : Percentage;
  }

  item def PayloadItem {
    attribute mass_kg : Mass_kg;
    attribute fragile : Boolean;
    attribute secured : Boolean;
  }

  item def ElectricalPower {
    attribute voltage_V : Real;
    attribute current_A : Real;
    attribute availablePower_W : Power_W;
  }

  port def CommandPort {
    in item command : MissionCommand;
  }

  port def StatusPort {
    out item status : RobotStatus;
  }

  port def WorldModelPort {
    out item model : WorldModel;
  }

  port def MotionControlPort {
    out item command : MotionCommand;
  }

  port def SensorPort {
    out item frame : SensorFrame;
  }

  port def PowerPort {
    inout item power : ElectricalPower;
  }

  port def PayloadPort {
    inout item payload : PayloadItem;
  }

  port def SafetyPort {
    out item stopRequest : Boolean;
    in item resetRequest : Boolean;
  }

  part def AdaptiveRobotSystem {
    doc /* Primary function: autonomously reconfigure sensing, mobility, manipulation, and mission behavior to perform transport, inspection, mapping, and assistance tasks across changing environments while maintaining safety and operational continuity. */

    attribute maximumPayload_kg : Mass_kg = 18.0;
    attribute maximumSpeed_mps : Speed_mps = 2.2;
    attribute minimumRuntime_s : Time_s = 14400.0;
    attribute obstacleClearance_m : Distance_m = 0.18;
    attribute localizationAccuracy_m : Distance_m = 0.05;
    attribute systemAvailability_pct : Percentage = 98.0;

    port operatorCommand : CommandPort;
    port robotStatus : StatusPort;
    port emergencyStop : SafetyPort;

    part autonomy : AdaptiveAutonomyController;
    part perception : MultiModalPerceptionSuite;
    part mobility : ReconfigurableMobilityPlatform;
    part manipulator : ModularManipulator;
    part power : SmartPowerSystem;
    part payloadBay : AdaptivePayloadBay;
    part safety : SafetySupervisor;
    part communications : HumanRobotInterface;

    connect operatorCommand to communications.operatorCommandIn;
    connect communications.validatedCommandOut to autonomy.commandIn;

    connect perception.worldModelOut to autonomy.worldModelIn;
    connect autonomy.motionCommandOut to mobility.motionCommandIn;
    connect autonomy.manipulationCommandOut to manipulator.taskCommandIn;

    connect power.powerOut to autonomy.powerIn;
    connect power.powerOut to perception.powerIn;
    connect power.powerOut to mobility.powerIn;
    connect power.powerOut to manipulator.powerIn;
    connect power.powerOut to communications.powerIn;

    connect payloadBay.payloadInterface to manipulator.payloadInterface;
    connect autonomy.payloadRequestOut to payloadBay.payloadCommandIn;

    connect safety.stopOut to mobility.safetyIn;
    connect safety.stopOut to manipulator.safetyIn;
    connect safety.stopOut to autonomy.safetyIn;
    connect emergencyStop to safety.externalSafetyIn;

    connect autonomy.statusOut to communications.robotStatusIn;
    connect communications.robotStatusOut to robotStatus;
  }

  part def HumanRobotInterface {
    port operatorCommandIn : CommandPort;
    port validatedCommandOut : CommandPort;
    port robotStatusIn : StatusPort;
    port robotStatusOut : StatusPort;
    port powerIn : PowerPort;

    attribute wirelessRange_m : Distance_m = 300.0;
    attribute commandValidationLatency_s : Time_s = 0.2;
  }

  part def AdaptiveAutonomyController {
    port commandIn : CommandPort;
    port worldModelIn : WorldModelPort;
    port motionCommandOut : MotionControlPort;
    port manipulationCommandOut : CommandPort;
    port payloadRequestOut : CommandPort;
    port statusOut : StatusPort;
    port powerIn : PowerPort;
    port safetyIn : SafetyPort;

    attribute activeMode : MissionMode = MissionMode::idle;
    attribute replanningPeriod_s : Time_s = 1.0;
    attribute minimumLocalizationConfidence_pct : Percentage = 85.0;
    attribute minimumBatteryForMission_pct : Percentage = 20.0;

    action performMission : PerformAdaptiveMission;
    state controllerState : AdaptiveMissionStateMachine;
  }

  part def MultiModalPerceptionSuite {
    port worldModelOut : WorldModelPort;
    port lidarOut : SensorPort;
    port cameraOut : SensorPort;
    port tactileOut : SensorPort;
    port powerIn : PowerPort;

    part lidar : LidarSensor;
    part stereoCamera : StereoVisionSensor;
    part tactileSkin : TactileSensorArray;
    part fusionComputer : SensorFusionComputer;

    connect lidar.scanOut to fusionComputer.lidarIn;
    connect stereoCamera.imageOut to fusionComputer.cameraIn;
    connect tactileSkin.contactOut to fusionComputer.tactileIn;
    connect fusionComputer.worldModelOut to worldModelOut;

    attribute perceptionUpdateRate_Hz : Real = 20.0;
  }

  part def LidarSensor {
    port scanOut : SensorPort;
    attribute range_m : Distance_m = 40.0;
    attribute angularResolution_deg : Angle_deg = 0.25;
    attribute powerDraw_W : Power_W = 18.0;
  }

  part def StereoVisionSensor {
    port imageOut : SensorPort;
    attribute frameRate_Hz : Real = 30.0;
    attribute depthRange_m : Distance_m = 15.0;
    attribute powerDraw_W : Power_W = 22.0;
  }

  part def TactileSensorArray {
    port contactOut : SensorPort;
    attribute contactResolution_N : Force_N = 0.5;
    attribute coveredSurface_pct : Percentage = 72.0;
  }

  part def SensorFusionComputer {
    port lidarIn : SensorPort;
    port cameraIn : SensorPort;
    port tactileIn : SensorPort;
    port worldModelOut : WorldModelPort;

    attribute fusionLatency_s : Time_s = 0.08;
    attribute minimumConfidence_pct : Percentage = 90.0;
  }

  part def ReconfigurableMobilityPlatform {
    port motionCommandIn : MotionControlPort;
    port powerIn : PowerPort;
    port safetyIn : SafetyPort;

    part leftWheelModule : WheelLegModule;
    part rightWheelModule : WheelLegModule;
    part postureController : BodyPostureController;

    attribute wheelModeSpeed_mps : Speed_mps = 2.2;
    attribute legModeStepHeight_m : Distance_m = 0.28;
    attribute maximumClimbAngle_deg : Angle_deg = 32.0;
    attribute minimumTurningRadius_m : Distance_m = 0.0;
  }

  part def WheelLegModule {
    attribute wheelDiameter_m : Distance_m = 0.24;
    attribute maxDriveTorque_Nm : Real = 55.0;
    attribute legExtension_m : Distance_m = 0.35;
    attribute reconfigurationTime_s : Time_s = 3.0;
  }

  part def BodyPostureController {
    attribute pitchLimit_deg : Angle_deg = 18.0;
    attribute rollLimit_deg : Angle_deg = 15.0;
    attribute stabilizationBandwidth_Hz : Real = 12.0;
  }

  part def ModularManipulator {
    port taskCommandIn : CommandPort;
    port payloadInterface : PayloadPort;
    port powerIn : PowerPort;
    port safetyIn : SafetyPort;

    part arm : SixAxisArm;
    part gripper : AdaptiveGripper;

    attribute reach_m : Distance_m = 1.1;
    attribute repeatability_m : Distance_m = 0.003;
    attribute maximumLift_kg : Mass_kg = 8.0;
  }

  part def SixAxisArm {
    attribute jointCount : Integer = 6;
    attribute maximumTipSpeed_mps : Speed_mps = 1.0;
    attribute continuousPayload_kg : Mass_kg = 6.0;
  }

  part def AdaptiveGripper {
    attribute fingerCount : Integer = 3;
    attribute gripForce_N : Force_N = 120.0;
    attribute objectWidthRange_m : Distance_m = 0.18;
  }

  part def SmartPowerSystem {
    port powerOut : PowerPort;

    part battery : BatteryPack;
    part powerManager : PowerManagementUnit;

    connect battery.powerBus to powerManager.batteryIn;
    connect powerManager.regulatedPowerOut to powerOut;

    attribute reserveEnergy_pct : Percentage = 15.0;
  }

  part def BatteryPack {
    port powerBus : PowerPort;
    attribute storedEnergy_Wh : Energy_Wh = 1800.0;
    attribute nominalVoltage_V : Real = 48.0;
    attribute maxDischargePower_W : Power_W = 2200.0;
    attribute mass_kg : Mass_kg = 12.5;
  }

  part def PowerManagementUnit {
    port batteryIn : PowerPort;
    port regulatedPowerOut : PowerPort;
    attribute conversionEfficiency_pct : Percentage = 94.0;
    attribute peakPowerDuration_s : Time_s = 20.0;
  }

  part def AdaptivePayloadBay {
    port payloadInterface : PayloadPort;
    port payloadCommandIn : CommandPort;

    attribute bayVolume_m3 : Real = 0.08;
    attribute maximumPayload_kg : Mass_kg = 18.0;
    attribute restraintActivationTime_s : Time_s = 1.5;
    attribute payloadSecured : Boolean = false;
  }

  part def SafetySupervisor {
    port externalSafetyIn : SafetyPort;
    port stopOut : SafetyPort;

    attribute obstacleStopDistance_m : Distance_m = 0.35;
    attribute maximumAllowedContactForce_N : Force_N = 80.0;
    attribute watchdogTimeout_s : Time_s = 0.5;
    attribute emergencyStopLatency_s : Time_s = 0.05;
  }

  action def PerformAdaptiveMission {
    in item mission : MissionCommand;
    in item environment : WorldModel;
    out item robotStatus : RobotStatus;

    action assessMission;
    action selectConfiguration;
    action planRoute;
    action executeMotion;
    action manipulatePayload;
    action reportStatus;

    first assessMission then selectConfiguration;
    then planRoute;
    then executeMotion;
    then manipulatePayload;
    then reportStatus;
  }

  action def ReconfigureForTerrain {
    in item terrain : TerrainClass;
    out item motionCommand : MotionCommand;

    action estimateTraversability;
    action chooseWheelLegMode;
    action adjustBodyPosture;
    action limitVelocity;

    first estimateTraversability then chooseWheelLegMode;
    then adjustBodyPosture;
    then limitVelocity;
  }

  state def AdaptiveMissionStateMachine {
    entry; then Idle;

    state Idle;
    state Planning;
    state Reconfiguring;
    state Executing;
    state Manipulating;
    state Recovering;
    state Charging;
    state SafeStopped;

    transition Idle_to_Planning
      first Idle
      accept MissionCommand
      then Planning;

    transition Planning_to_Reconfiguring
      first Planning
      if worldModelConfidenceAboveThreshold
      then Reconfiguring;

    transition Reconfiguring_to_Executing
      first Reconfiguring
      if configurationReady
      then Executing;

    transition Executing_to_Manipulating
      first Executing
      if payloadInteractionRequired
      then Manipulating;

    transition Manipulating_to_Executing
      first Manipulating
      if manipulationComplete
      then Executing;

    transition Executing_to_Planning
      first Executing
      if routeBlocked
      then Planning;

    transition Executing_to_Charging
      first Executing
      if batteryBelowReserve
      then Charging;

    transition Planning_to_Recovering
      first Planning
      if localizationConfidenceLow
      then Recovering;

    transition Recovering_to_Planning
      first Recovering
      if localizationRecovered
      then Planning;

    transition Any_to_SafeStopped
      first Idle
      accept Boolean
      then SafeStopped;

    transition SafeStopped_to_Idle
      first SafeStopped
      accept Boolean
      then Idle;
  }

  constraint def BatteryReserveConstraint {
    in currentSoc_pct : Percentage;
    in reserveSoc_pct : Percentage;
    currentSoc_pct >= reserveSoc_pct
  }

  constraint def PayloadCapacityConstraint {
    in payloadMass_kg : Mass_kg;
    in capacity_kg : Mass_kg;
    payloadMass_kg <= capacity_kg
  }

  constraint def SafeSpeedConstraint {
    in commandedSpeed_mps : Speed_mps;
    in maximumSpeed_mps : Speed_mps;
    commandedSpeed_mps <= maximumSpeed_mps
  }

  constraint def LocalizationConfidenceConstraint {
    in confidence_pct : Percentage;
    in minimumConfidence_pct : Percentage;
    confidence_pct >= minimumConfidence_pct
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The adaptable robotic system shall autonomously perform transport, inspection, mapping, and assistance missions by adapting its mobility, sensing, manipulation, and planning configuration to the current task and terrain. */
    subject robot : AdaptiveRobotSystem;
  }

  requirement def TerrainAdaptationRequirement {
    doc /* The robot shall reconfigure between wheel-dominant and leg-assisted mobility within 3 seconds when terrain changes from smooth floor to uneven ground, stairs, ramps, cluttered, or unknown terrain. */
    subject robot : AdaptiveRobotSystem;

    require constraint {
      robot.mobility.leftWheelModule.reconfigurationTime_s <= 3.0 and
      robot.mobility.rightWheelModule.reconfigurationTime_s <= 3.0
    }
  }

  requirement def PayloadRequirement {
    doc /* The robot shall transport a secured payload of at least 18 kg while maintaining autonomous navigation and status reporting. */
    subject robot : AdaptiveRobotSystem;

    require constraint {
      robot.maximumPayload_kg >= 18.0 and
      robot.payloadBay.maximumPayload_kg >= 18.0
    }
  }

  requirement def RuntimeRequirement {
    doc /* The robot shall operate for at least 4 hours during mixed mobility, perception, communication, and manipulation tasks before requiring recharge. */
    subject robot : AdaptiveRobotSystem;

    require constraint {
      robot.minimumRuntime_s >= 14400.0
    }
  }

  requirement def SafetyRequirement {
    doc /* The robot shall enter a safe stopped condition within 0.05 seconds of an emergency stop request and shall prevent commanded motion when contact force or obstacle distance exceeds safety limits. */
    subject robot : AdaptiveRobotSystem;

    require constraint {
      robot.safety.emergencyStopLatency_s <= 0.05 and
      robot.safety.maximumAllowedContactForce_N <= 80.0 and
      robot.safety.obstacleStopDistance_m >= 0.35
    }
  }

  requirement def LocalizationRequirement {
    doc /* The robot shall maintain localization accuracy within 0.05 m during autonomous mission execution when perception confidence is nominal. */
    subject robot : AdaptiveRobotSystem;

    require constraint {
      robot.localizationAccuracy_m <= 0.05 and
      robot.autonomy.minimumLocalizationConfidence_pct >= 85.0
    }
  }

  requirement def AvailabilityRequirement {
    doc /* The robot shall provide at least 98 percent operational availability across planned missions through degraded-mode recovery, power reserve management, and fault-safe behavior. */
    subject robot : AdaptiveRobotSystem;

    require constraint {
      robot.systemAvailability_pct >= 98.0
    }
  }

  satisfy PrimaryFunctionRequirement by AdaptiveRobotSystem;
  satisfy TerrainAdaptationRequirement by ReconfigurableMobilityPlatform;
  satisfy PayloadRequirement by AdaptivePayloadBay;
  satisfy RuntimeRequirement by SmartPowerSystem;
  satisfy SafetyRequirement by SafetySupervisor;
  satisfy LocalizationRequirement by MultiModalPerceptionSuite;
  satisfy AvailabilityRequirement by AdaptiveAutonomyController;

  part adaptableRobot : AdaptiveRobotSystem;

}