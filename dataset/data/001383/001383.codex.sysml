package CloudRoboticsSystemModel {

  import ScalarValues::*;
  import ISQ::*;

  attribute def Percent : Real {
    :>> range = "0..100";
    unit = "%";
  }

  attribute def Millisecond : Real {
    unit = "ms";
  }

  attribute def MegabitPerSecond : Real {
    unit = "Mbit/s";
  }

  attribute def Meter : Real {
    unit = "m";
  }

  attribute def MeterPerSecond : Real {
    unit = "m/s";
  }

  attribute def Watt : Real {
    unit = "W";
  }

  attribute def Celsius : Real {
    unit = "degC";
  }

  attribute def Count : Integer;

  item def SensorFrame {
    attribute timestamp : Integer;
    attribute robotId : String;
    attribute frameSequence : Count;
    attribute payloadSizeMb : Real;
  }

  item def RobotTelemetry {
    attribute robotId : String;
    attribute batteryStateOfCharge : Percent;
    attribute localizationConfidence : Percent;
    attribute motorTemperature : Celsius;
    attribute networkLatency : Millisecond;
    attribute currentSpeed : MeterPerSecond;
  }

  item def TaskRequest {
    attribute taskId : String;
    attribute priority : Integer;
    attribute targetZone : String;
    attribute requestedBy : String;
  }

  item def MotionPlan {
    attribute planId : String;
    attribute robotId : String;
    attribute maxSpeed : MeterPerSecond;
    attribute pathLength : Meter;
    attribute estimatedDurationMs : Millisecond;
    attribute obstacleAvoidanceEnabled : Boolean;
  }

  item def ControlCommand {
    attribute commandId : String;
    attribute robotId : String;
    attribute linearVelocity : MeterPerSecond;
    attribute angularVelocity : Real;
    attribute emergencyStop : Boolean;
  }

  item def CloudMapUpdate {
    attribute mapVersion : String;
    attribute coverageAreaSquareMeters : Real;
    attribute confidence : Percent;
  }

  port def TelemetryOutPort {
    out item telemetry : RobotTelemetry;
  }

  port def TelemetryInPort {
    in item telemetry : RobotTelemetry;
  }

  port def SensorDataOutPort {
    out item sensorFrame : SensorFrame;
  }

  port def SensorDataInPort {
    in item sensorFrame : SensorFrame;
  }

  port def TaskInPort {
    in item taskRequest : TaskRequest;
  }

  port def TaskOutPort {
    out item taskRequest : TaskRequest;
  }

  port def PlanOutPort {
    out item motionPlan : MotionPlan;
  }

  port def PlanInPort {
    in item motionPlan : MotionPlan;
  }

  port def CommandOutPort {
    out item controlCommand : ControlCommand;
  }

  port def CommandInPort {
    in item controlCommand : ControlCommand;
  }

  port def MapOutPort {
    out item mapUpdate : CloudMapUpdate;
  }

  port def MapInPort {
    in item mapUpdate : CloudMapUpdate;
  }

  part def EdgeRobot {
    attribute robotId : String;
    attribute batteryCapacityWh : Real;
    attribute nominalPowerDraw : Watt;
    attribute maximumSpeed : MeterPerSecond;
    attribute localSafetyReactionTime : Millisecond;
    attribute minimumSafeBattery : Percent = 15.0;

    port telemetryOut : TelemetryOutPort;
    port sensorDataOut : SensorDataOutPort;
    port planIn : PlanInPort;
    port commandIn : CommandInPort;
    port mapIn : MapInPort;

    part perceptionUnit : LocalPerceptionUnit;
    part mobilityBase : MobilityBase;
    part safetyController : SafetyController;
    part communicationClient : RobotCloudClient;

    connect perceptionUnit.sensorDataOut to sensorDataOut;
    connect communicationClient.telemetryOut to telemetryOut;
    connect planIn to communicationClient.planIn;
    connect commandIn to safetyController.commandIn;
    connect mapIn to perceptionUnit.mapIn;
    connect safetyController.safeCommandOut to mobilityBase.commandIn;
  }

  part def LocalPerceptionUnit {
    attribute cameraRange : Meter = 25.0;
    attribute lidarRange : Meter = 40.0;
    attribute localizationConfidence : Percent;

    port sensorDataOut : SensorDataOutPort;
    port mapIn : MapInPort;
  }

  part def MobilityBase {
    attribute wheelCount : Count = 4;
    attribute maximumPayloadKg : Real = 30.0;
    attribute currentSpeed : MeterPerSecond;

    port commandIn : CommandInPort;
  }

  part def SafetyController {
    attribute emergencyStopActive : Boolean;
    attribute obstacleDistance : Meter;
    attribute stopDistance : Meter = 0.75;

    port commandIn : CommandInPort;
    port safeCommandOut : CommandOutPort;
  }

  part def RobotCloudClient {
    attribute uplinkBandwidth : MegabitPerSecond;
    attribute downlinkBandwidth : MegabitPerSecond;
    attribute measuredLatency : Millisecond;

    port telemetryOut : TelemetryOutPort;
    port planIn : PlanInPort;
  }

  part def CloudRoboticsPlatform {
    attribute platformRegion : String;
    attribute maximumRobotFleetSize : Count = 500;
    attribute planningLatencyBudget : Millisecond = 250.0;
    attribute mapUpdateIntervalMs : Millisecond = 1000.0;

    port telemetryIn : TelemetryInPort;
    port sensorDataIn : SensorDataInPort;
    port taskIn : TaskInPort;
    port planOut : PlanOutPort;
    port commandOut : CommandOutPort;
    port mapOut : MapOutPort;

    part fleetManager : FleetManager;
    part cloudPerceptionService : CloudPerceptionService;
    part globalPlanner : GlobalMotionPlanner;
    part mapService : SharedMapService;
    part healthMonitor : FleetHealthMonitor;
    part taskAllocator : TaskAllocator;

    connect telemetryIn to healthMonitor.telemetryIn;
    connect telemetryIn to fleetManager.telemetryIn;
    connect sensorDataIn to cloudPerceptionService.sensorDataIn;
    connect cloudPerceptionService.mapObservationOut to mapService.mapObservationIn;
    connect mapService.mapOut to mapOut;
    connect taskIn to taskAllocator.taskIn;
    connect taskAllocator.assignedTaskOut to globalPlanner.taskIn;
    connect mapService.mapOut to globalPlanner.mapIn;
    connect globalPlanner.planOut to planOut;
    connect fleetManager.commandOut to commandOut;
  }

  part def FleetManager {
    attribute activeRobotCount : Count;
    attribute degradedRobotCount : Count;

    port telemetryIn : TelemetryInPort;
    port commandOut : CommandOutPort;
  }

  part def CloudPerceptionService {
    attribute averageInferenceLatency : Millisecond;
    attribute objectDetectionConfidence : Percent;

    port sensorDataIn : SensorDataInPort;
    port mapObservationOut : MapOutPort;
  }

  part def SharedMapService {
    attribute currentMapVersion : String;
    attribute mappedAreaSquareMeters : Real;
    attribute mapConfidence : Percent;

    port mapObservationIn : MapInPort;
    port mapOut : MapOutPort;
  }

  part def GlobalMotionPlanner {
    attribute averagePlanTime : Millisecond;
    attribute maximumPlanHorizon : Meter = 150.0;

    port taskIn : TaskInPort;
    port mapIn : MapInPort;
    port planOut : PlanOutPort;
  }

  part def FleetHealthMonitor {
    attribute alertCount : Count;
    attribute meanBatteryStateOfCharge : Percent;

    port telemetryIn : TelemetryInPort;
  }

  part def TaskAllocator {
    attribute queuedTaskCount : Count;
    attribute allocationCycleMs : Millisecond = 500.0;

    port taskIn : TaskInPort;
    port assignedTaskOut : TaskOutPort;
  }

  part def OperationsConsole {
    attribute operatorId : String;
    attribute displayRefreshRateHz : Real = 30.0;

    port taskOut : TaskOutPort;
    port telemetryIn : TelemetryInPort;
    port mapIn : MapInPort;
  }

  part def SecureNetwork {
    attribute nominalLatency : Millisecond = 80.0;
    attribute guaranteedBandwidth : MegabitPerSecond = 50.0;
    attribute packetLossPercent : Percent = 0.1;
  }

  part cloudRoboticsSystem {
    part robot1 : EdgeRobot {
      :>> robotId = "robot-alpha";
      :>> batteryCapacityWh = 850.0;
      :>> nominalPowerDraw = 180.0;
      :>> maximumSpeed = 1.8;
      :>> localSafetyReactionTime = 40.0;
    }

    part robot2 : EdgeRobot {
      :>> robotId = "robot-beta";
      :>> batteryCapacityWh = 850.0;
      :>> nominalPowerDraw = 175.0;
      :>> maximumSpeed = 1.6;
      :>> localSafetyReactionTime = 40.0;
    }

    part cloudPlatform : CloudRoboticsPlatform;
    part operationsConsole : OperationsConsole;
    part secureNetwork : SecureNetwork;

    connect robot1.telemetryOut to cloudPlatform.telemetryIn;
    connect robot2.telemetryOut to cloudPlatform.telemetryIn;
    connect robot1.sensorDataOut to cloudPlatform.sensorDataIn;
    connect robot2.sensorDataOut to cloudPlatform.sensorDataIn;
    connect operationsConsole.taskOut to cloudPlatform.taskIn;
    connect cloudPlatform.planOut to robot1.planIn;
    connect cloudPlatform.planOut to robot2.planIn;
    connect cloudPlatform.commandOut to robot1.commandIn;
    connect cloudPlatform.commandOut to robot2.commandIn;
    connect cloudPlatform.mapOut to robot1.mapIn;
    connect cloudPlatform.mapOut to robot2.mapIn;
    connect cloudPlatform.mapOut to operationsConsole.mapIn;
    connect robot1.telemetryOut to operationsConsole.telemetryIn;
    connect robot2.telemetryOut to operationsConsole.telemetryIn;
  }

  action def ExecuteCloudAssistedTask {
    in item task : TaskRequest;
    in item telemetry : RobotTelemetry;
    out item plan : MotionPlan;
    out item command : ControlCommand;

    action receiveTask;
    action evaluateFleetState;
    action updateSharedMap;
    action computeMotionPlan;
    action dispatchPlan;
    action monitorExecution;
    action issueCorrectiveCommand;

    flow receiveTask to evaluateFleetState;
    flow evaluateFleetState to updateSharedMap;
    flow updateSharedMap to computeMotionPlan;
    flow computeMotionPlan to dispatchPlan;
    flow dispatchPlan to monitorExecution;
    flow monitorExecution to issueCorrectiveCommand;
  }

  action def PerformLocalSafetyOverride {
    in item command : ControlCommand;
    out item safeCommand : ControlCommand;

    action inspectObstacleDistance;
    action compareStoppingThreshold;
    action passThroughCommand;
    action replaceWithEmergencyStop;

    flow inspectObstacleDistance to compareStoppingThreshold;
    flow compareStoppingThreshold to passThroughCommand;
    flow compareStoppingThreshold to replaceWithEmergencyStop;
  }

  state def RobotOperationalState {
    entry action initializeLocalPerception;
    exit action publishFinalTelemetry;

    state idle;
    state awaitingCloudPlan;
    state navigating;
    state localAvoidance;
    state charging;
    state faulted;
    state emergencyStopped;

    transition idle_to_awaitingCloudPlan
      first idle
      then awaitingCloudPlan
      accept TaskRequest;

    transition awaitingCloudPlan_to_navigating
      first awaitingCloudPlan
      then navigating
      accept MotionPlan;

    transition navigating_to_localAvoidance
      first navigating
      then localAvoidance
      if obstacleDistance < 0.75;

    transition localAvoidance_to_navigating
      first localAvoidance
      then navigating
      if obstacleDistance >= 0.75;

    transition navigating_to_charging
      first navigating
      then charging
      if batteryStateOfCharge < 15.0;

    transition charging_to_idle
      first charging
      then idle
      if batteryStateOfCharge > 90.0;

    transition any_to_emergencyStopped
      first idle
      then emergencyStopped
      accept emergencyStop;

    transition awaitingCloudPlan_to_faulted
      first awaitingCloudPlan
      then faulted
      if networkLatency > 1000.0;
  }

  state def CloudPlatformOperationalState {
    state normalOperation;
    state highLatencyMode;
    state degradedPlanning;
    state maintenanceMode;

    transition normal_to_highLatency
      first normalOperation
      then highLatencyMode
      if measuredFleetLatency > 250.0;

    transition highLatency_to_normal
      first highLatencyMode
      then normalOperation
      if measuredFleetLatency <= 150.0;

    transition normal_to_degradedPlanning
      first normalOperation
      then degradedPlanning
      if activePlannerInstances < 2;

    transition degradedPlanning_to_normal
      first degradedPlanning
      then normalOperation
      if activePlannerInstances >= 2;

    transition normal_to_maintenance
      first normalOperation
      then maintenanceMode
      accept maintenanceCommand;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : CloudRoboticsPlatform;

    doc
    /*
     The cloud robotics system shall coordinate a fleet of edge robots by collecting robot telemetry and sensor data, building a shared cloud map, assigning operator tasks, computing motion plans in the cloud, and dispatching safe control guidance to robots while preserving local safety authority on each robot.
    */

    require constraint {
      system.maximumRobotFleetSize >= 100
    }
  }

  requirement def LatencyRequirement {
    subject network : SecureNetwork;

    doc
    /*
     The secure network shall support cloud-assisted robot operation with nominal one-way latency no greater than 100 milliseconds.
    */

    require constraint {
      network.nominalLatency <= 100.0
    }
  }

  requirement def SafetyRequirement {
    subject robot : EdgeRobot;

    doc
    /*
     Each edge robot shall be able to execute a local safety stop without waiting for cloud authorization whenever an obstacle is detected inside the configured stop distance.
    */

    require constraint {
      robot.localSafetyReactionTime <= 50.0
    }
  }

  requirement def MappingRequirement {
    subject platform : CloudRoboticsPlatform;

    doc
    /*
     The cloud platform shall publish shared map updates to all connected robots at least once every second during normal operation.
    */

    require constraint {
      platform.mapUpdateIntervalMs <= 1000.0
    }
  }

  requirement def PlanningRequirement {
    subject platform : CloudRoboticsPlatform;

    doc
    /*
     The cloud platform shall compute and distribute a motion plan within the planning latency budget for assigned tasks under normal network conditions.
    */

    require constraint {
      platform.planningLatencyBudget <= 250.0
    }
  }

  requirement def AvailabilityRequirement {
    subject platform : CloudRoboticsPlatform;

    doc
    /*
     The cloud platform shall continue fleet coordination in degraded planning mode when at least one planner instance remains available.
    */

    require constraint {
      platform.maximumRobotFleetSize >= 1
    }
  }

  satisfy PrimaryFunctionRequirement by cloudRoboticsSystem.cloudPlatform;
  satisfy LatencyRequirement by cloudRoboticsSystem.secureNetwork;
  satisfy SafetyRequirement by cloudRoboticsSystem.robot1;
  satisfy SafetyRequirement by cloudRoboticsSystem.robot2;
  satisfy MappingRequirement by cloudRoboticsSystem.cloudPlatform;
  satisfy PlanningRequirement by cloudRoboticsSystem.cloudPlatform;
  satisfy AvailabilityRequirement by cloudRoboticsSystem.cloudPlatform;

}