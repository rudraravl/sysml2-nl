package VaimosPrimaryFunctionModel {

  import ScalarValues::*;

  attribute def MassKg :> Real { unit = "kg"; }
  attribute def DistanceM :> Real { unit = "m"; }
  attribute def SpeedMps :> Real { unit = "m/s"; }
  attribute def PowerW :> Real { unit = "W"; }
  attribute def EnergyWh :> Real { unit = "Wh"; }
  attribute def VoltageV :> Real { unit = "V"; }
  attribute def CurrentA :> Real { unit = "A"; }
  attribute def TimeS :> Real { unit = "s"; }
  attribute def Percent :> Real { unit = "%"; }
  attribute def TemperatureC :> Real { unit = "degC"; }
  attribute def AngleDeg :> Real { unit = "deg"; }

  enum def MissionMode {
    enum idle;
    enum planning;
    enum navigating;
    enum inspecting;
    enum returning;
    enum charging;
    enum faulted;
  }

  enum def HealthLevel {
    enum nominal;
    enum degraded;
    enum critical;
  }

  item def MissionPlan {
    attribute missionId : String;
    attribute targetAreaName : String;
    attribute maxMissionDuration : TimeS;
    attribute requiredCoverage : Percent;
    attribute returnToBaseRequired : Boolean;
  }

  item def RoutePlan {
    attribute routeId : String;
    attribute totalDistance : DistanceM;
    attribute estimatedTravelTime : TimeS;
    attribute waypointCount : Integer;
  }

  item def PoseEstimate {
    attribute x : DistanceM;
    attribute y : DistanceM;
    attribute heading : AngleDeg;
    attribute confidence : Percent;
  }

  item def VelocityCommand {
    attribute linearSpeed : SpeedMps;
    attribute turnRate : AngleDeg;
  }

  item def SensorFrame {
    attribute frameId : String;
    attribute captureTime : TimeS;
    attribute obstacleRange : DistanceM;
    attribute ambientTemperature : TemperatureC;
  }

  item def InspectionRecord {
    attribute recordId : String;
    attribute locationX : DistanceM;
    attribute locationY : DistanceM;
    attribute anomalyDetected : Boolean;
    attribute confidence : Percent;
  }

  item def TelemetryPacket {
    attribute operatingMode : MissionMode;
    attribute batteryStateOfCharge : Percent;
    attribute currentSpeed : SpeedMps;
    attribute health : HealthLevel;
  }

  item def ElectricalPower {
    attribute voltage : VoltageV;
    attribute current : CurrentA;
    attribute availablePower : PowerW;
  }

  port def MissionCommandPort {
    in item missionPlan : MissionPlan;
    out item telemetry : TelemetryPacket;
  }

  port def RoutePort {
    out item route : RoutePlan;
  }

  port def PosePort {
    out item pose : PoseEstimate;
  }

  port def MotionCommandPort {
    in item command : VelocityCommand;
  }

  port def SensorPort {
    out item frame : SensorFrame;
  }

  port def InspectionDataPort {
    out item record : InspectionRecord;
  }

  port def PowerPort {
    out item power : ElectricalPower;
  }

  part def BatteryPack {
    attribute nominalVoltage : VoltageV = 48.0;
    attribute usableEnergy : EnergyWh = 2400.0;
    attribute stateOfCharge : Percent = 100.0;
    attribute maxContinuousPower : PowerW = 1800.0;

    port powerOut : PowerPort;
  }

  part def MobilityBase {
    attribute mass : MassKg = 85.0;
    attribute maxSpeed : SpeedMps = 2.5;
    attribute minimumTurningRadius : DistanceM = 0.7;
    attribute commandedSpeed : SpeedMps;

    port motionCommand : MotionCommandPort;
    port tractionPowerIn : PowerPort;
  }

  part def PerceptionSuite {
    attribute lidarRange : DistanceM = 80.0;
    attribute cameraHorizontalFieldOfView : AngleDeg = 120.0;
    attribute frameRateHz : Real = 20.0;

    port sensorOut : SensorPort;
    port perceptionPowerIn : PowerPort;
  }

  part def LocalizationUnit {
    attribute nominalPositionError : DistanceM = 0.15;
    attribute updatePeriod : TimeS = 0.05;

    port sensorIn : SensorPort;
    port poseOut : PosePort;
    port localizationPowerIn : PowerPort;
  }

  part def NavigationComputer {
    attribute planningHorizon : DistanceM = 30.0;
    attribute replanningPeriod : TimeS = 1.0;
    attribute obstacleClearance : DistanceM = 0.6;

    port missionIn : MissionCommandPort;
    port poseIn : PosePort;
    port sensorIn : SensorPort;
    port routeOut : RoutePort;
    port motionOut : MotionCommandPort;
    port navigationPowerIn : PowerPort;
  }

  part def InspectionPayload {
    attribute sampleSpacing : DistanceM = 1.0;
    attribute minimumAnomalyConfidence : Percent = 85.0;
    attribute storageCapacityRecords : Integer = 100000;

    port sensorIn : SensorPort;
    port poseIn : PosePort;
    port inspectionOut : InspectionDataPort;
    port payloadPowerIn : PowerPort;
  }

  part def CommunicationsUnit {
    attribute nominalRange : DistanceM = 1000.0;
    attribute telemetryPeriod : TimeS = 2.0;
    attribute commandLatencyLimit : TimeS = 1.5;

    port operatorLink : MissionCommandPort;
    port inspectionIn : InspectionDataPort;
    port commsPowerIn : PowerPort;
  }

  part def Vaimos {
    attribute systemName : String = "VAIMOS";
    attribute primaryFunction : String = "Autonomously plan, navigate, inspect, and report conditions across a defined area while maintaining safe mobility and returning to base when mission or energy constraints require.";
    attribute nominalMissionDuration : TimeS = 7200.0;
    attribute maximumOperatingSpeed : SpeedMps = 2.0;
    attribute minimumBatteryReserve : Percent = 20.0;
    attribute mode : MissionMode = MissionMode::idle;

    port operatorInterface : MissionCommandPort;

    part battery : BatteryPack;
    part mobility : MobilityBase;
    part perception : PerceptionSuite;
    part localization : LocalizationUnit;
    part navigation : NavigationComputer;
    part payload : InspectionPayload;
    part communications : CommunicationsUnit;

    connect operatorInterface to communications.operatorLink;
    connect communications.operatorLink to navigation.missionIn;

    connect battery.powerOut to mobility.tractionPowerIn;
    connect battery.powerOut to perception.perceptionPowerIn;
    connect battery.powerOut to localization.localizationPowerIn;
    connect battery.powerOut to navigation.navigationPowerIn;
    connect battery.powerOut to payload.payloadPowerIn;
    connect battery.powerOut to communications.commsPowerIn;

    connect perception.sensorOut to localization.sensorIn;
    connect perception.sensorOut to navigation.sensorIn;
    connect perception.sensorOut to payload.sensorIn;

    connect localization.poseOut to navigation.poseIn;
    connect localization.poseOut to payload.poseIn;

    connect navigation.motionOut to mobility.motionCommand;
    connect payload.inspectionOut to communications.inspectionIn;
  }

  action def ExecuteVaimosMission {
    in item mission : MissionPlan;
    out item finalTelemetry : TelemetryPacket;

    first start;
    then validateMission;
    then generateRoute;
    then traverseRoute;
    then collectInspectionData;
    then transmitResults;
    then returnToBase;
    then shutdownMission;

    action validateMission {
      in item requestedMission : MissionPlan = mission;
    }

    action generateRoute {
      out item plannedRoute : RoutePlan;
    }

    action traverseRoute {
      in item activeRoute : RoutePlan;
      out item currentPose : PoseEstimate;
    }

    action collectInspectionData {
      in item pose : PoseEstimate;
      out item inspection : InspectionRecord;
    }

    action transmitResults {
      in item inspection : InspectionRecord;
      out item telemetry : TelemetryPacket;
    }

    action returnToBase {
      out item returnTelemetry : TelemetryPacket;
    }

    action shutdownMission {
      out item completedTelemetry : TelemetryPacket = finalTelemetry;
    }
  }

  state def VaimosOperationalStates {
    state idle;
    state missionPlanning;
    state autonomousNavigation;
    state areaInspection;
    state returnToBase;
    state charging;
    state faultResponse;

    entry action initializeTelemetry;
    exit action persistMissionLog;

    transition idle_to_planning
      first idle
      accept MissionPlan
      then missionPlanning;

    transition planning_to_navigation
      first missionPlanning
      if routeFeasible
      then autonomousNavigation;

    transition navigation_to_inspection
      first autonomousNavigation
      if reachedInspectionArea
      then areaInspection;

    transition inspection_to_return
      first areaInspection
      if missionComplete or batteryReserveLow
      then returnToBase;

    transition return_to_charging
      first returnToBase
      if dockedAtBase
      then charging;

    transition charging_to_idle
      first charging
      if batteryReady
      then idle;

    transition any_to_fault
      first idle
      then faultResponse
      if criticalFaultDetected;

    transition recover_fault
      first faultResponse
      if operatorClearedFault
      then idle;
  }

  requirement def PrimaryFunctionRequirement {
    subject vaimos : Vaimos;

    doc /* The Vaimos shall autonomously execute an area inspection mission by accepting a mission plan, generating a route, navigating safely, collecting inspection records, transmitting telemetry and findings, and returning to base when complete or when energy reserve is low. */

    require constraint {
      vaimos.nominalMissionDuration >= 3600.0
    }
  }

  requirement def SafeNavigationRequirement {
    subject vaimos : Vaimos;

    doc /* The Vaimos shall preserve obstacle clearance while navigating the planned route. */

    require constraint {
      vaimos.navigation.obstacleClearance >= 0.5
    }
  }

  requirement def EnergyReserveRequirement {
    subject vaimos : Vaimos;

    doc /* The Vaimos shall begin return-to-base behavior before battery state of charge falls below the configured reserve threshold. */

    require constraint {
      vaimos.minimumBatteryReserve >= 20.0
    }
  }

  requirement def TelemetryRequirement {
    subject vaimos : Vaimos;

    doc /* The Vaimos shall report operating mode, battery state of charge, speed, and health to the operator interface during mission execution. */

    require constraint {
      vaimos.communications.telemetryPeriod <= 2.0
    }
  }

  requirement def InspectionCoverageRequirement {
    subject vaimos : Vaimos;

    doc /* The Vaimos shall collect inspection data at regular spatial intervals sufficient to support area condition assessment. */

    require constraint {
      vaimos.payload.sampleSpacing <= 1.0
    }
  }

  part vaimosSystem : Vaimos;

}