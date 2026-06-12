package SituatedRoboticsSystemModel {

  import ScalarValues::*;
  import ISQ::*;

  attribute def Distance :> Real {
    unit = "m";
  }

  attribute def Speed :> Real {
    unit = "m/s";
  }

  attribute def Acceleration :> Real {
    unit = "m/s^2";
  }

  attribute def Angle :> Real {
    unit = "rad";
  }

  attribute def TimeDuration :> Real {
    unit = "s";
  }

  attribute def ElectricPotential :> Real {
    unit = "V";
  }

  attribute def ElectricCurrent :> Real {
    unit = "A";
  }

  attribute def Energy :> Real {
    unit = "Wh";
  }

  attribute def Percentage :> Real {
    unit = "%";
  }

  attribute def Confidence :> Real {
    unit = "1";
  }

  enum def RobotMode {
    enum standby;
    enum perceive;
    enum localize;
    enum plan;
    enum navigate;
    enum manipulate;
    enum interact;
    enum recharge;
    enum fault;
  }

  enum def TerrainClass {
    enum flatFloor;
    enum ramp;
    enum doorway;
    enum clutteredArea;
    enum unknown;
  }

  item def OccupancyGrid {
    attribute resolution : Distance;
    attribute width : Integer;
    attribute height : Integer;
    attribute originX : Distance;
    attribute originY : Distance;
    attribute occupiedProbability[0..*] : Percentage;
  }

  item def Pose2D {
    attribute x : Distance;
    attribute y : Distance;
    attribute yaw : Angle;
    attribute covarianceTrace : Real;
  }

  item def VelocityCommand {
    attribute linear : Speed;
    attribute angular : Real;
  }

  item def SensorFrame {
    attribute timestamp : TimeDuration;
    attribute frameId : String;
    attribute confidence : Confidence;
  }

  item def LidarScan :> SensorFrame {
    attribute range[0..*] : Distance;
    attribute bearing[0..*] : Angle;
    attribute minimumRange : Distance;
    attribute maximumRange : Distance;
  }

  item def CameraImage :> SensorFrame {
    attribute widthPixels : Integer;
    attribute heightPixels : Integer;
    attribute colorEncoding : String;
  }

  item def SemanticObservation :> SensorFrame {
    attribute objectLabel : String;
    attribute objectConfidence : Confidence;
    attribute relativeX : Distance;
    attribute relativeY : Distance;
  }

  item def BatteryStatus {
    attribute voltage : ElectricPotential;
    attribute current : ElectricCurrent;
    attribute remainingEnergy : Energy;
    attribute stateOfCharge : Percentage;
  }

  item def TaskRequest {
    attribute requestId : String;
    attribute goalLabel : String;
    attribute goalX : Distance;
    attribute goalY : Distance;
    attribute requiresManipulation : Boolean;
  }

  item def TaskReport {
    attribute requestId : String;
    attribute completed : Boolean;
    attribute finalMode : RobotMode;
    attribute message : String;
  }

  item def SafetyEvent {
    attribute eventId : String;
    attribute severity : Integer;
    attribute stoppingDistance : Distance;
    attribute description : String;
  }

  port def PowerPort {
    out batteryStatus : BatteryStatus;
    in chargePower : ElectricCurrent;
  }

  port def MotionPort {
    in command : VelocityCommand;
    out measuredPose : Pose2D;
  }

  port def PerceptionPort {
    out lidar : LidarScan;
    out image : CameraImage;
    out semanticObservation : SemanticObservation;
  }

  port def MapPort {
    in observations : SemanticObservation;
    out localMap : OccupancyGrid;
  }

  port def TaskPort {
    in request : TaskRequest;
    out report : TaskReport;
  }

  port def SafetyPort {
    in monitoredPose : Pose2D;
    in monitoredVelocity : VelocityCommand;
    out safetyEvent : SafetyEvent;
  }

  part def SituatedServiceRobot {
    doc /* A situated robotic system whose primary function is to perceive its local environment, understand task context, navigate safely through human-scale spaces, and perform requested service actions while continuously adapting behavior to changing surroundings. */

    attribute maximumSpeed : Speed = 1.2;
    attribute nominalSpeed : Speed = 0.7;
    attribute maximumPayloadMass : Real = 5.0;
    attribute minimumObstacleClearance : Distance = 0.35;
    attribute localizationErrorLimit : Distance = 0.15;
    attribute minimumOperationalCharge : Percentage = 20.0;
    attribute currentMode : RobotMode = RobotMode::standby;

    port taskInterface : TaskPort;
    port safetyInterface : SafetyPort;
    port powerInterface : PowerPort;

    part body {
      attribute width : Distance = 0.48;
      attribute length : Distance = 0.62;
      attribute height : Distance = 1.15;
      attribute mass : Real = 42.0;
    }

    part battery {
      attribute capacity : Energy = 960.0;
      attribute nominalVoltage : ElectricPotential = 48.0;
      attribute stateOfCharge : Percentage = 85.0;
      port power : PowerPort;
    }

    part perceptionSubsystem {
      attribute updatePeriod : TimeDuration = 0.05;
      port perceptionOut : PerceptionPort;

      part lidar {
        attribute horizontalFieldOfView : Angle = 6.28318;
        attribute maximumRange : Distance = 18.0;
        attribute angularResolution : Angle = 0.00436;
      }

      part stereoCamera {
        attribute horizontalFieldOfView : Angle = 1.57;
        attribute verticalFieldOfView : Angle = 0.95;
        attribute frameRateHz : Real = 30.0;
      }

      part semanticRecognizer {
        attribute minimumDetectionConfidence : Confidence = 0.70;
        attribute trackedObjectMemory : TimeDuration = 3.0;
      }
    }

    part localizationSubsystem {
      attribute poseUpdatePeriod : TimeDuration = 0.02;
      attribute maximumAllowedDrift : Distance = 0.12;
      port mapAccess : MapPort;
      port motionFeedback : MotionPort;

      part poseEstimator {
        attribute lidarWeight : Real = 0.55;
        attribute visualWeight : Real = 0.25;
        attribute odometryWeight : Real = 0.20;
      }

      part localMapper {
        attribute gridResolution : Distance = 0.05;
        attribute gridWidth : Integer = 400;
        attribute gridHeight : Integer = 400;
      }
    }

    part deliberationSubsystem {
      attribute replanningPeriod : TimeDuration = 0.25;
      attribute planningHorizon : Distance = 12.0;
      port taskIn : TaskPort;
      port mapIn : MapPort;
      port commandOut : MotionPort;

      part taskInterpreter {
        attribute acceptedGoalRadius : Distance = 0.25;
      }

      part behaviorPlanner {
        attribute obstaclePredictionHorizon : TimeDuration = 4.0;
        attribute socialDistance : Distance = 1.0;
      }

      part pathPlanner {
        attribute nominalClearance : Distance = 0.45;
        attribute maximumCurvature : Real = 1.8;
      }
    }

    part mobilitySubsystem {
      attribute wheelRadius : Distance = 0.12;
      attribute wheelBase : Distance = 0.44;
      attribute maximumAcceleration : Acceleration = 0.8;
      port motion : MotionPort;

      part leftDrive {
        attribute maximumWheelSpeed : Real = 12.0;
      }

      part rightDrive {
        attribute maximumWheelSpeed : Real = 12.0;
      }

      part motorController {
        attribute controlPeriod : TimeDuration = 0.01;
      }
    }

    part manipulationSubsystem {
      attribute reach : Distance = 0.75;
      attribute gripperOpening : Distance = 0.09;
      attribute maximumLiftMass : Real = 5.0;

      part arm {
        attribute jointCount : Integer = 6;
        attribute maximumEndEffectorSpeed : Speed = 0.35;
      }

      part gripper {
        attribute maximumGripForce : Real = 80.0;
      }
    }

    part humanInteractionSubsystem {
      attribute responseLatencyLimit : TimeDuration = 1.0;

      part speechInterface {
        attribute supportedLanguages : Integer = 2;
      }

      part display {
        attribute diagonalSize : Distance = 0.18;
      }

      part statusLight {
        attribute visibleRange : Distance = 10.0;
      }
    }

    part safetySupervisor {
      attribute emergencyStopLatency : TimeDuration = 0.08;
      attribute protectiveStopDistance : Distance = 0.40;
      attribute maximumSafeSpeedNearHuman : Speed = 0.4;
      port safety : SafetyPort;
    }

    connect battery.power to powerInterface;
    connect perceptionSubsystem.perceptionOut to localizationSubsystem.mapAccess;
    connect localizationSubsystem.motionFeedback to mobilitySubsystem.motion;
    connect deliberationSubsystem.commandOut to mobilitySubsystem.motion;
    connect deliberationSubsystem.taskIn to taskInterface;
    connect localizationSubsystem.mapAccess to deliberationSubsystem.mapIn;
    connect mobilitySubsystem.motion to safetySupervisor.safety;
    connect safetySupervisor.safety to safetyInterface;

    action def ExecuteSituatedServiceTask {
      in task : TaskRequest;
      in currentPose : Pose2D;
      in map : OccupancyGrid;
      out report : TaskReport;

      first start;
      then interpretTask;
      then perceiveScene;
      then estimateSituation;
      then planContextAwareMotion;
      then moveToGoal;
      if task.requiresManipulation then performManipulation;
      then verifyOutcome;
      then publishReport;
      then done;

      action interpretTask {
        in task : TaskRequest;
      }

      action perceiveScene {
        out observations : SemanticObservation;
      }

      action estimateSituation {
        in observations : SemanticObservation;
        in map : OccupancyGrid;
        out terrain : TerrainClass;
      }

      action planContextAwareMotion {
        in currentPose : Pose2D;
        in map : OccupancyGrid;
        out command : VelocityCommand;
      }

      action moveToGoal {
        in command : VelocityCommand;
        out arrived : Boolean;
      }

      action performManipulation {
        out graspComplete : Boolean;
      }

      action verifyOutcome {
        out success : Boolean;
      }

      action publishReport {
        out report : TaskReport;
      }
    }

    state def OperationalStateMachine {
      entry action initializeRobot;

      state Standby;
      state Perceiving;
      state Localizing;
      state Planning;
      state Navigating;
      state Manipulating;
      state Interacting;
      state Recharging;
      state FaultHandling;

      initial then Standby;

      transition Standby_to_Perceiving
        first Standby
        accept TaskRequest
        then Perceiving;

      transition Perceiving_to_Localizing
        first Perceiving
        if perceptionSubsystem.semanticRecognizer.minimumDetectionConfidence >= 0.70
        then Localizing;

      transition Localizing_to_Planning
        first Localizing
        if localizationSubsystem.maximumAllowedDrift <= localizationErrorLimit
        then Planning;

      transition Planning_to_Navigating
        first Planning
        then Navigating;

      transition Navigating_to_Manipulating
        first Navigating
        if taskInterface.request.requiresManipulation
        then Manipulating;

      transition Navigating_to_Interacting
        first Navigating
        if not taskInterface.request.requiresManipulation
        then Interacting;

      transition Manipulating_to_Interacting
        first Manipulating
        then Interacting;

      transition Interacting_to_Standby
        first Interacting
        then Standby;

      transition Any_to_Recharging
        first Standby
        if battery.stateOfCharge < minimumOperationalCharge
        then Recharging;

      transition Recharging_to_Standby
        first Recharging
        if battery.stateOfCharge >= 90.0
        then Standby;

      transition Any_to_FaultHandling
        first Navigating
        accept SafetyEvent
        then FaultHandling;

      transition FaultHandling_to_Standby
        first FaultHandling
        if safetySupervisor.protectiveStopDistance >= minimumObstacleClearance
        then Standby;
    }
  }

  part def OperatingEnvironment {
    attribute areaWidth : Distance = 40.0;
    attribute areaLength : Distance = 60.0;
    attribute maximumHumanDensity : Real = 0.15;

    part staticStructure {
      attribute doorwayWidth : Distance = 0.90;
      attribute corridorWidth : Distance = 1.80;
    }

    part dynamicActors {
      attribute averageWalkingSpeed : Speed = 1.3;
      attribute minimumPersonalSpace : Distance = 0.8;
    }

    part serviceObjects {
      attribute pickupHeightMinimum : Distance = 0.35;
      attribute pickupHeightMaximum : Distance = 1.10;
      attribute maximumObjectMass : Real = 5.0;
    }

    port mapService : MapPort;
  }

  part situatedRobotSystem {
    part robot : SituatedServiceRobot;
    part environment : OperatingEnvironment;

    connect environment.mapService to robot.localizationSubsystem.mapAccess;
    connect environment.mapService to robot.deliberationSubsystem.mapIn;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The situated robot shall perform service tasks by sensing the surrounding environment, localizing itself, interpreting contextual cues, planning motion, navigating safely, and interacting with people or objects at the requested goal location. */

    subject robot : SituatedServiceRobot;

    require constraint {
      robot.maximumSpeed <= 1.2 and
      robot.minimumObstacleClearance >= 0.35 and
      robot.localizationErrorLimit <= 0.15
    }
  }

  requirement def SituatedAwarenessRequirement {
    subject robot : SituatedServiceRobot;

    require constraint {
      robot.perceptionSubsystem.updatePeriod <= 0.10 and
      robot.localizationSubsystem.poseUpdatePeriod <= 0.05 and
      robot.deliberationSubsystem.replanningPeriod <= 0.50
    }
  }

  requirement def HumanSafeNavigationRequirement {
    subject robot : SituatedServiceRobot;

    require constraint {
      robot.safetySupervisor.maximumSafeSpeedNearHuman <= 0.4 and
      robot.safetySupervisor.emergencyStopLatency <= 0.10 and
      robot.safetySupervisor.protectiveStopDistance >= 0.40
    }
  }

  requirement def EnergyAutonomyRequirement {
    subject robot : SituatedServiceRobot;

    require constraint {
      robot.battery.capacity >= 900.0 and
      robot.minimumOperationalCharge >= 20.0
    }
  }

  requirement def ManipulationCapabilityRequirement {
    subject robot : SituatedServiceRobot;

    require constraint {
      robot.manipulationSubsystem.reach >= 0.70 and
      robot.manipulationSubsystem.maximumLiftMass >= 5.0
    }
  }

  satisfy PrimaryFunctionRequirement by situatedRobotSystem.robot;
  satisfy SituatedAwarenessRequirement by situatedRobotSystem.robot;
  satisfy HumanSafeNavigationRequirement by situatedRobotSystem.robot;
  satisfy EnergyAutonomyRequirement by situatedRobotSystem.robot;
  satisfy ManipulationCapabilityRequirement by situatedRobotSystem.robot;

}