package RoboticsGlossarySystemModel {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def Percent {
    :> ScalarValues::Real;
    unit = "%";
  }

  attribute def Confidence {
    :> ScalarValues::Real;
    unit = "%";
  }

  attribute def BatteryStateOfCharge {
    :> ScalarValues::Real;
    unit = "%";
  }

  attribute def Pose2D {
    attribute x : LengthValue;
    attribute y : LengthValue;
    attribute yaw : PlaneAngleValue;
  }

  attribute def Pose3D {
    attribute x : LengthValue;
    attribute y : LengthValue;
    attribute z : LengthValue;
    attribute roll : PlaneAngleValue;
    attribute pitch : PlaneAngleValue;
    attribute yaw : PlaneAngleValue;
  }

  attribute def Twist2D {
    attribute linearVelocity : SpeedValue;
    attribute angularVelocity : AngularVelocityValue;
  }

  attribute def MapResolution {
    :> LengthValue;
  }

  item def PowerFlow {
    attribute voltage : ElectricPotentialValue;
    attribute current : ElectricCurrentValue;
    attribute availableEnergy : EnergyValue;
  }

  item def MotionCommand {
    attribute targetVelocity : Twist2D;
    attribute priority : ScalarValues::Integer;
    attribute emergencyStop : ScalarValues::Boolean;
  }

  item def SensorFrame {
    attribute timestamp : TimeValue;
    attribute sensorPose : Pose3D;
    attribute confidence : Confidence;
  }

  item def LidarScan :> SensorFrame {
    attribute rangeMinimum : LengthValue;
    attribute rangeMaximum : LengthValue;
    attribute angularResolution : PlaneAngleValue;
    attribute sampleCount : ScalarValues::Integer;
  }

  item def CameraImage :> SensorFrame {
    attribute widthPixels : ScalarValues::Integer;
    attribute heightPixels : ScalarValues::Integer;
    attribute frameRate : FrequencyValue;
  }

  item def InertialMeasurement :> SensorFrame {
    attribute accelerationX : AccelerationValue;
    attribute accelerationY : AccelerationValue;
    attribute angularRateZ : AngularVelocityValue;
  }

  item def WheelOdometry :> SensorFrame {
    attribute estimatedPose : Pose2D;
    attribute wheelSlipEstimate : Percent;
  }

  item def EnvironmentMap {
    attribute resolution : MapResolution;
    attribute occupiedCellCount : ScalarValues::Integer;
    attribute freeCellCount : ScalarValues::Integer;
    attribute lastUpdated : TimeValue;
  }

  item def LocalizationEstimate {
    attribute pose : Pose2D;
    attribute covarianceTrace : ScalarValues::Real;
    attribute confidence : Confidence;
  }

  item def NavigationGoal {
    attribute desiredPose : Pose2D;
    attribute toleranceRadius : LengthValue;
    attribute toleranceYaw : PlaneAngleValue;
  }

  item def PlannedPath {
    attribute waypointCount : ScalarValues::Integer;
    attribute totalLength : LengthValue;
    attribute expectedDuration : TimeValue;
  }

  item def DiagnosticReport {
    attribute batteryState : BatteryStateOfCharge;
    attribute thermalMargin : TemperatureValue;
    attribute faultCode : ScalarValues::Integer;
    attribute safeToMove : ScalarValues::Boolean;
  }

  port def PowerInputPort {
    in item power : PowerFlow;
  }

  port def PowerOutputPort {
    out item power : PowerFlow;
  }

  port def MotionCommandPort {
    in item command : MotionCommand;
  }

  port def ActuatorDrivePort {
    out item command : MotionCommand;
  }

  port def LidarDataPort {
    out item scan : LidarScan;
  }

  port def CameraDataPort {
    out item image : CameraImage;
  }

  port def ImuDataPort {
    out item measurement : InertialMeasurement;
  }

  port def OdometryPort {
    out item odometry : WheelOdometry;
  }

  port def MapPort {
    out item map : EnvironmentMap;
  }

  port def LocalizationPort {
    out item estimate : LocalizationEstimate;
  }

  port def GoalPort {
    in item goal : NavigationGoal;
  }

  port def PathPort {
    out item path : PlannedPath;
  }

  port def DiagnosticPort {
    out item report : DiagnosticReport;
  }

  port def OperatorInterfacePort {
    in item goal : NavigationGoal;
    out item report : DiagnosticReport;
  }

  part def MobileRobotPlatform {
    attribute mass : MassValue;
    attribute footprintLength : LengthValue;
    attribute footprintWidth : LengthValue;
    attribute maximumSpeed : SpeedValue;
    attribute maximumPayload : MassValue;

    port powerIn : PowerInputPort;
    port driveIn : MotionCommandPort;
    port odometryOut : OdometryPort;

    part leftWheelMotor {
      attribute ratedPower : PowerValue;
      attribute wheelRadius : LengthValue;
      port driveIn : MotionCommandPort;
    }

    part rightWheelMotor {
      attribute ratedPower : PowerValue;
      attribute wheelRadius : LengthValue;
      port driveIn : MotionCommandPort;
    }

    part chassis {
      attribute groundClearance : LengthValue;
      attribute materialDensity : DensityValue;
    }

    connection leftDriveConnection connect driveIn to leftWheelMotor.driveIn;
    connection rightDriveConnection connect driveIn to rightWheelMotor.driveIn;
  }

  part def SensorSuite {
    port powerIn : PowerInputPort;
    port lidarOut : LidarDataPort;
    port cameraOut : CameraDataPort;
    port imuOut : ImuDataPort;

    part lidar {
      attribute horizontalFieldOfView : PlaneAngleValue;
      attribute maxRange : LengthValue;
      attribute scanRate : FrequencyValue;
      port dataOut : LidarDataPort;
    }

    part stereoCamera {
      attribute baseline : LengthValue;
      attribute horizontalFieldOfView : PlaneAngleValue;
      attribute nominalFrameRate : FrequencyValue;
      port imageOut : CameraDataPort;
    }

    part imu {
      attribute gyroBiasStability : AngularVelocityValue;
      attribute accelNoiseDensity : AccelerationValue;
      port measurementOut : ImuDataPort;
    }

    connection lidarDataConnection connect lidar.dataOut to lidarOut;
    connection cameraDataConnection connect stereoCamera.imageOut to cameraOut;
    connection imuDataConnection connect imu.measurementOut to imuOut;
  }

  part def PowerSubsystem {
    attribute nominalVoltage : ElectricPotentialValue;
    attribute capacity : EnergyValue;
    attribute minimumOperationalSoc : BatteryStateOfCharge;
    attribute maximumChargeCurrent : ElectricCurrentValue;

    port powerOut : PowerOutputPort;
    port diagnosticsOut : DiagnosticPort;

    part batteryPack {
      attribute stateOfCharge : BatteryStateOfCharge;
      attribute packVoltage : ElectricPotentialValue;
      attribute usableEnergy : EnergyValue;
    }

    part powerDistributionUnit {
      attribute conversionEfficiency : Percent;
      attribute regulatedVoltage : ElectricPotentialValue;
    }
  }

  part def ComputeAndControlSubsystem {
    port powerIn : PowerInputPort;
    port lidarIn : LidarDataPort;
    port cameraIn : CameraDataPort;
    port imuIn : ImuDataPort;
    port odometryIn : OdometryPort;
    port goalIn : GoalPort;
    port commandOut : ActuatorDrivePort;
    port mapOut : MapPort;
    port localizationOut : LocalizationPort;
    port pathOut : PathPort;
    port diagnosticsOut : DiagnosticPort;

    part perceptionModule {
      attribute obstacleDetectionLatency : TimeValue;
      attribute minimumObstacleConfidence : Confidence;
      port lidarIn : LidarDataPort;
      port cameraIn : CameraDataPort;
      port mapOut : MapPort;
    }

    part localizationModule {
      attribute updateRate : FrequencyValue;
      attribute maximumPoseError : LengthValue;
      port imuIn : ImuDataPort;
      port odometryIn : OdometryPort;
      port mapIn : MapPort;
      port localizationOut : LocalizationPort;
    }

    part navigationPlanner {
      attribute replanningPeriod : TimeValue;
      attribute obstacleClearance : LengthValue;
      port goalIn : GoalPort;
      port localizationIn : LocalizationPort;
      port mapIn : MapPort;
      port pathOut : PathPort;
    }

    part motionController {
      attribute controlLoopRate : FrequencyValue;
      attribute velocityLimit : SpeedValue;
      attribute accelerationLimit : AccelerationValue;
      port pathIn : PathPort;
      port localizationIn : LocalizationPort;
      port commandOut : ActuatorDrivePort;
    }

    part healthMonitor {
      attribute heartbeatPeriod : TimeValue;
      attribute maximumAllowedTemperature : TemperatureValue;
      port diagnosticsOut : DiagnosticPort;
    }

    connection perceptionLidar connect lidarIn to perceptionModule.lidarIn;
    connection perceptionCamera connect cameraIn to perceptionModule.cameraIn;
    connection perceptionMap connect perceptionModule.mapOut to mapOut;
    connection localizationImu connect imuIn to localizationModule.imuIn;
    connection localizationOdometry connect odometryIn to localizationModule.odometryIn;
    connection mapToLocalization connect perceptionModule.mapOut to localizationModule.mapIn;
    connection localizationEstimate connect localizationModule.localizationOut to localizationOut;
    connection goalToPlanner connect goalIn to navigationPlanner.goalIn;
    connection mapToPlanner connect perceptionModule.mapOut to navigationPlanner.mapIn;
    connection localizationToPlanner connect localizationModule.localizationOut to navigationPlanner.localizationIn;
    connection plannedPath connect navigationPlanner.pathOut to pathOut;
    connection pathToController connect navigationPlanner.pathOut to motionController.pathIn;
    connection localizationToController connect localizationModule.localizationOut to motionController.localizationIn;
    connection commandToDrive connect motionController.commandOut to commandOut;
    connection healthOutput connect healthMonitor.diagnosticsOut to diagnosticsOut;
  }

  part def OperatorConsole {
    port interface : OperatorInterfacePort;
    port goalOut : GoalPort;
    port diagnosticsIn : DiagnosticPort;

    attribute operatorCommandTimeout : TimeValue;
    attribute displayRefreshRate : FrequencyValue;

    connection operatorGoalConnection connect interface.goal to goalOut.goal;
    connection diagnosticDisplayConnection connect diagnosticsIn.report to interface.report;
  }

  action def BuildMap {
    in item lidarScan : LidarScan;
    in item cameraImage : CameraImage;
    out item map : EnvironmentMap;
  }

  action def EstimatePose {
    in item imu : InertialMeasurement;
    in item odometry : WheelOdometry;
    in item map : EnvironmentMap;
    out item estimate : LocalizationEstimate;
  }

  action def PlanPath {
    in item goal : NavigationGoal;
    in item map : EnvironmentMap;
    in item estimate : LocalizationEstimate;
    out item path : PlannedPath;
  }

  action def TrackPath {
    in item path : PlannedPath;
    in item estimate : LocalizationEstimate;
    out item command : MotionCommand;
  }

  action def StopRobot {
    out item command : MotionCommand;
  }

  action def PerformAutonomousNavigation {
    in item operatorGoal : NavigationGoal;
    in item lidarScan : LidarScan;
    in item cameraImage : CameraImage;
    in item imu : InertialMeasurement;
    in item odometry : WheelOdometry;
    out item driveCommand : MotionCommand;
    out item localization : LocalizationEstimate;
    out item worldModel : EnvironmentMap;
    out item plannedRoute : PlannedPath;

    action mapAction : BuildMap {
      in lidarScan = operatorGoal@PerformAutonomousNavigation.lidarScan;
      in cameraImage = operatorGoal@PerformAutonomousNavigation.cameraImage;
    }

    action poseAction : EstimatePose {
      in imu = operatorGoal@PerformAutonomousNavigation.imu;
      in odometry = operatorGoal@PerformAutonomousNavigation.odometry;
      in map = mapAction.map;
    }

    action planAction : PlanPath {
      in goal = operatorGoal;
      in map = mapAction.map;
      in estimate = poseAction.estimate;
    }

    action trackAction : TrackPath {
      in path = planAction.path;
      in estimate = poseAction.estimate;
    }

    bind worldModel = mapAction.map;
    bind localization = poseAction.estimate;
    bind plannedRoute = planAction.path;
    bind driveCommand = trackAction.command;
  }

  state def RobotOperationalState {
    in item diagnostics : DiagnosticReport;
    in item goal : NavigationGoal;
    out item command : MotionCommand;

    state initializing;
    state idle;
    state mapping;
    state localizing;
    state planning;
    state moving;
    state obstacleAvoidance;
    state charging;
    state fault;
    state emergencyStopped;

    transition first initial then initializing;

    transition initializationComplete
      first initializing
      then idle;

    transition goalReceived
      first idle
      accept goal
      then mapping;

    transition mapReady
      first mapping
      then localizing;

    transition poseReady
      first localizing
      then planning;

    transition pathReady
      first planning
      then moving;

    transition dynamicObstacleDetected
      first moving
      then obstacleAvoidance;

    transition obstacleCleared
      first obstacleAvoidance
      then planning;

    transition goalReached
      first moving
      then idle;

    transition lowBattery
      first idle
      if diagnostics.batteryState < 20 [%]
      then charging;

    transition charged
      first charging
      if diagnostics.batteryState > 90 [%]
      then idle;

    transition faultDetected
      first idle
      if diagnostics.safeToMove == false
      then fault;

    transition motionFaultDetected
      first moving
      if diagnostics.safeToMove == false
      then fault;

    transition emergencyStopRequested
      first moving
      if command.emergencyStop == true
      then emergencyStopped;

    transition resetFromEmergencyStop
      first emergencyStopped
      then idle;
  }

  requirement def HighLevelPrimaryFunctionRequirement {
    doc /* The robotic system shall autonomously perceive its operating environment, localize itself, plan a collision-free route to an operator-specified goal, and control its mobile base to reach that goal while monitoring health and preserving safe operation. */
  }

  requirement def PerceptionRequirement {
    doc /* The sensor suite and perception module shall convert lidar, camera, and inertial data into an environment map suitable for navigation. */
  }

  requirement def LocalizationRequirement {
    doc /* The system shall estimate the robot pose in the mapped environment with bounded error during autonomous motion. */
  }

  requirement def NavigationRequirement {
    doc /* The planner shall generate a feasible path from the current pose to the goal while maintaining clearance from mapped obstacles. */
  }

  requirement def MotionControlRequirement {
    doc /* The controller shall translate planned paths into wheel-drive commands that respect velocity and acceleration limits. */
  }

  requirement def SafetyRequirement {
    doc /* The robot shall enter a stopped or fault state when diagnostics indicate unsafe motion, emergency stop is requested, or battery state is below the operational threshold. */
  }

  requirement def RoboticsGlossaryCoverageRequirement {
    doc /* The model shall define and use glossary concepts for robot, actuator, sensor, perception, localization, mapping, planning, control, autonomy, odometry, pose, path, obstacle, payload, power, diagnostics, and safety. */
  }

  part def AutonomousGlossaryRobot {
    attribute primaryFunction : ScalarValues::String = "Autonomous mobile manipulation support through sensing, mapping, localization, planning, motion control, diagnostics, and safe goal-directed navigation.";
    attribute autonomyLevel : ScalarValues::Integer = 3;
    attribute nominalOperatingSpeed : SpeedValue = 1.2 [m/s];
    attribute minimumObstacleClearance : LengthValue = 0.35 [m];
    attribute mapResolution : MapResolution = 0.05 [m];
    attribute nominalMissionDuration : TimeValue = 7200 [s];

    port operatorInterface : OperatorInterfacePort;

    part powerSubsystem : PowerSubsystem {
      attribute nominalVoltage = 48 [V];
      attribute capacity = 1800000 [J];
      attribute minimumOperationalSoc = 20 [%];
      attribute maximumChargeCurrent = 20 [A];
    }

    part sensorSuite : SensorSuite;

    part computeAndControl : ComputeAndControlSubsystem;

    part mobileBase : MobileRobotPlatform {
      attribute mass = 72 [kg];
      attribute footprintLength = 0.9 [m];
      attribute footprintWidth = 0.62 [m];
      attribute maximumSpeed = 1.8 [m/s];
      attribute maximumPayload = 25 [kg];
    }

    part operatorConsole : OperatorConsole {
      attribute operatorCommandTimeout = 10 [s];
      attribute displayRefreshRate = 30 [Hz];
    }

    connection mainPowerToSensors connect powerSubsystem.powerOut to sensorSuite.powerIn;
    connection mainPowerToCompute connect powerSubsystem.powerOut to computeAndControl.powerIn;
    connection mainPowerToBase connect powerSubsystem.powerOut to mobileBase.powerIn;

    connection lidarToCompute connect sensorSuite.lidarOut to computeAndControl.lidarIn;
    connection cameraToCompute connect sensorSuite.cameraOut to computeAndControl.cameraIn;
    connection imuToCompute connect sensorSuite.imuOut to computeAndControl.imuIn;
    connection odometryToCompute connect mobileBase.odometryOut to computeAndControl.odometryIn;

    connection operatorExternalInterface connect operatorInterface to operatorConsole.interface;
    connection operatorGoalToCompute connect operatorConsole.goalOut to computeAndControl.goalIn;
    connection computeDiagnosticsToOperator connect computeAndControl.diagnosticsOut to operatorConsole.diagnosticsIn;

    connection commandToBase connect computeAndControl.commandOut to mobileBase.driveIn;

    perform autonomousNavigation : PerformAutonomousNavigation;
    exhibit state behavior operationalState : RobotOperationalState;

    satisfy HighLevelPrimaryFunctionRequirement by AutonomousGlossaryRobot;
    satisfy PerceptionRequirement by sensorSuite;
    satisfy PerceptionRequirement by computeAndControl.perceptionModule;
    satisfy LocalizationRequirement by computeAndControl.localizationModule;
    satisfy NavigationRequirement by computeAndControl.navigationPlanner;
    satisfy MotionControlRequirement by computeAndControl.motionController;
    satisfy SafetyRequirement by computeAndControl.healthMonitor;
    satisfy SafetyRequirement by powerSubsystem;
    satisfy RoboticsGlossaryCoverageRequirement by AutonomousGlossaryRobot;
  }

  package RoboticsGlossary {
    attribute def Robot {
      attribute definition : ScalarValues::String = "A programmable machine that senses, computes, and acts in the physical world.";
    }

    attribute def Sensor {
      attribute definition : ScalarValues::String = "A device that measures physical or environmental quantities and converts them into data.";
    }

    attribute def Actuator {
      attribute definition : ScalarValues::String = "A device that converts control commands and energy into physical motion.";
    }

    attribute def Perception {
      attribute definition : ScalarValues::String = "The process of interpreting sensor data to detect objects, obstacles, and environmental structure.";
    }

    attribute def Localization {
      attribute definition : ScalarValues::String = "The process of estimating the robot pose relative to a map or reference frame.";
    }

    attribute def Mapping {
      attribute definition : ScalarValues::String = "The process of constructing or updating a representation of the environment.";
    }

    attribute def Planning {
      attribute definition : ScalarValues::String = "The process of selecting a feasible sequence of motions or waypoints to achieve a goal.";
    }

    attribute def Control {
      attribute definition : ScalarValues::String = "The process of generating actuator commands that drive the robot toward desired states.";
    }

    attribute def Autonomy {
      attribute definition : ScalarValues::String = "The capability to perform tasks with limited direct human intervention.";
    }

    attribute def Odometry {
      attribute definition : ScalarValues::String = "An estimate of motion derived from wheel, inertial, or proprioceptive measurements.";
    }

    attribute def Pose {
      attribute definition : ScalarValues::String = "The position and orientation of a body in a reference frame.";
    }

    attribute def Path {
      attribute definition : ScalarValues::String = "An ordered geometric route intended for robot traversal.";
    }

    attribute def Obstacle {
      attribute definition : ScalarValues::String = "A region or object that constrains safe robot motion.";
    }

    attribute def Safety {
      attribute definition : ScalarValues::String = "The capability to prevent unacceptable risk to people, equipment, and the environment.";
    }
  }

}