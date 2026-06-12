package DoosanRoboticsHighLevelSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  enum def RobotOperatingMode {
    enum idle;
    enum teaching;
    enum automatic;
    enum collaborative;
    enum fault;
    enum emergencyStop;
  }

  enum def SafetyZoneState {
    enum clear;
    enum monitored;
    enum reducedSpeed;
    enum protectiveStop;
  }

  enum def TaskResult {
    enum notStarted;
    enum running;
    enum completed;
    enum aborted;
    enum failed;
  }

  enum def GripperState {
    enum open;
    enum closed;
    enum gripping;
    enum released;
    enum error;
  }

  enum def WorkpieceClass {
    enum unknown;
    enum rawPart;
    enum finishedPart;
    enum rejectedPart;
  }

  attribute def MassValue :> ISQ::mass {
    unit = SI::kg;
  }

  attribute def LengthValue :> ISQ::length {
    unit = SI::m;
  }

  attribute def SpeedValue :> ISQ::speed {
    unit = SI::m / SI::s;
  }

  attribute def ForceValue :> ISQ::force {
    unit = SI::N;
  }

  attribute def TorqueValue :> ISQ::torque {
    unit = SI::N * SI::m;
  }

  attribute def PowerValue :> ISQ::power {
    unit = SI::W;
  }

  attribute def TimeValue :> ISQ::time {
    unit = SI::s;
  }

  attribute def AngleValue :> ISQ::planeAngle {
    unit = SI::rad;
  }

  item def Workpiece {
    attribute id : String;
    attribute class : WorkpieceClass;
    attribute mass : MassValue;
    attribute width : LengthValue;
    attribute height : LengthValue;
    attribute depth : LengthValue;
  }

  item def MotionCommand {
    attribute commandId : String;
    attribute targetPoseX : LengthValue;
    attribute targetPoseY : LengthValue;
    attribute targetPoseZ : LengthValue;
    attribute targetRoll : AngleValue;
    attribute targetPitch : AngleValue;
    attribute targetYaw : AngleValue;
    attribute commandedSpeed : SpeedValue;
    attribute commandedForceLimit : ForceValue;
  }

  item def RobotStatus {
    attribute mode : RobotOperatingMode;
    attribute safetyZone : SafetyZoneState;
    attribute currentSpeed : SpeedValue;
    attribute payloadMass : MassValue;
    attribute taskResult : TaskResult;
  }

  item def SafetySignal {
    attribute emergencyStopActive : Boolean;
    attribute protectiveStopRequested : Boolean;
    attribute humanDetectedInCollaborativeZone : Boolean;
    attribute resetRequested : Boolean;
  }

  item def GripperCommand {
    attribute openRequested : Boolean;
    attribute closeRequested : Boolean;
    attribute gripForce : ForceValue;
  }

  item def GripperFeedback {
    attribute state : GripperState;
    attribute measuredGripForce : ForceValue;
    attribute workpieceDetected : Boolean;
  }

  port def MotionCommandPort {
    out item command : MotionCommand;
  }

  port def MotionStatusPort {
    in item status : RobotStatus;
  }

  port def SafetyInputPort {
    in item signal : SafetySignal;
  }

  port def SafetyOutputPort {
    out item signal : SafetySignal;
  }

  port def WorkpieceInputPort {
    in item workpiece : Workpiece;
  }

  port def WorkpieceOutputPort {
    out item workpiece : Workpiece;
  }

  port def GripperControlPort {
    out item command : GripperCommand;
    in item feedback : GripperFeedback;
  }

  port def OperatorInterfacePort {
    out item command : MotionCommand;
    in item status : RobotStatus;
    in item safety : SafetySignal;
  }

  part def DoosanCollaborativeRobotCell {
    attribute cellName : String = "Doosan Robotics Collaborative Pick And Place Cell";
    attribute primaryFunction : String =
      "Automatically pick, transfer, and place workpieces using a Doosan collaborative robot while monitoring human presence and limiting motion to support safe shared-workspace operation.";
    attribute nominalPayloadCapacity : MassValue = 5 [SI::kg];
    attribute maximumReach : LengthValue = 0.9 [SI::m];
    attribute collaborativeSpeedLimit : SpeedValue = 0.25 [SI::m / SI::s];
    attribute automaticSpeedLimit : SpeedValue = 1.0 [SI::m / SI::s];
    attribute maximumEndEffectorForce : ForceValue = 140 [SI::N];
    attribute nominalCycleTime : TimeValue = 12 [SI::s];

    port operatorPanel : OperatorInterfacePort;
    port inboundParts : WorkpieceInputPort;
    port outboundParts : WorkpieceOutputPort;
    port rejectedParts : WorkpieceOutputPort;

    part robotController : RobotController;
    part robotArm : DoosanCollaborativeArm;
    part endEffector : AdaptiveElectricGripper;
    part safetySystem : CollaborativeSafetySystem;
    part visionSystem : WorkpieceVisionSystem;
    part infeedStation : InfeedFixture;
    part outfeedStation : OutfeedFixture;

    connect operatorPanel.command to robotController.operatorCommand;
    connect robotController.robotCommand to robotArm.motionCommand;
    connect robotArm.robotStatus to robotController.robotStatus;
    connect safetySystem.safetyOutput to robotController.safetyInput;
    connect safetySystem.safetyOutput to robotArm.safetyInput;
    connect robotController.gripperControl to endEffector.control;
    connect visionSystem.detectedWorkpiece to robotController.detectedWorkpiece;
    connect inboundParts to infeedStation.inbound;
    connect infeedStation.availableWorkpiece to robotController.availableWorkpiece;
    connect endEffector.heldWorkpiece to outfeedStation.placedWorkpiece;
    connect outfeedStation.outbound to outboundParts;

    perform action pickAndPlaceCycle : PickAndPlaceAction;
    exhibit state robotCellState : RobotCellStateMachine;
  }

  part def RobotController {
    attribute controlPeriod : TimeValue = 0.004 [SI::s];
    attribute activeMode : RobotOperatingMode = RobotOperatingMode::idle;
    attribute currentTaskResult : TaskResult = TaskResult::notStarted;

    port operatorCommand : MotionCommandPort;
    port robotCommand : MotionCommandPort;
    port robotStatus : MotionStatusPort;
    port safetyInput : SafetyInputPort;
    port gripperControl : GripperControlPort;
    port availableWorkpiece : WorkpieceInputPort;
    port detectedWorkpiece : WorkpieceInputPort;

    perform action planMotion : PlanCollisionAwareMotionAction;
    perform action coordinateGrip : CoordinateGripperAction;
  }

  part def DoosanCollaborativeArm {
    attribute manufacturer : String = "Doosan Robotics";
    attribute axisCount : Integer = 6;
    attribute payloadCapacity : MassValue = 5 [SI::kg];
    attribute reach : LengthValue = 0.9 [SI::m];
    attribute repeatability : LengthValue = 0.00005 [SI::m];
    attribute jointTorqueLimit : TorqueValue = 150 [SI::N * SI::m];
    attribute peakPower : PowerValue = 1500 [SI::W];

    port motionCommand : MotionCommandPort;
    port robotStatus : MotionStatusPort;
    port safetyInput : SafetyInputPort;

    part baseJoint : RobotJoint {
      attribute axisName = "J1 Base";
    }
    part shoulderJoint : RobotJoint {
      attribute axisName = "J2 Shoulder";
    }
    part elbowJoint : RobotJoint {
      attribute axisName = "J3 Elbow";
    }
    part wristJoint1 : RobotJoint {
      attribute axisName = "J4 Wrist Pitch";
    }
    part wristJoint2 : RobotJoint {
      attribute axisName = "J5 Wrist Yaw";
    }
    part wristJoint3 : RobotJoint {
      attribute axisName = "J6 Tool Flange";
    }

    perform action executeMotion : ExecuteRobotMotionAction;
  }

  part def RobotJoint {
    attribute axisName : String;
    attribute position : AngleValue;
    attribute velocity : ISQ::angularVelocity;
    attribute torque : TorqueValue;
    attribute temperature : ISQ::thermodynamicTemperature;
  }

  part def AdaptiveElectricGripper {
    attribute maximumGripForce : ForceValue = 140 [SI::N];
    attribute jawStroke : LengthValue = 0.085 [SI::m];
    attribute gripperMass : MassValue = 1.1 [SI::kg];

    port control : GripperControlPort;
    port heldWorkpiece : WorkpieceOutputPort;

    exhibit state gripperState : GripperStateMachine;
  }

  part def CollaborativeSafetySystem {
    attribute minimumHumanSeparationDistance : LengthValue = 0.5 [SI::m];
    attribute reducedSpeedLimit : SpeedValue = 0.25 [SI::m / SI::s];
    attribute emergencyStopReactionTime : TimeValue = 0.08 [SI::s];

    port safetyOutput : SafetyOutputPort;

    part emergencyStopButton : EmergencyStopDevice;
    part safetyScanner : AreaScanner;
    part forceMonitor : ForceTorqueMonitor;

    perform action evaluateSafety : EvaluateCollaborativeSafetyAction;
  }

  part def EmergencyStopDevice {
    attribute activated : Boolean = false;
    attribute resetRequired : Boolean = false;
  }

  part def AreaScanner {
    attribute detectionRange : LengthValue = 3.0 [SI::m];
    attribute humanDetected : Boolean;
    attribute zoneState : SafetyZoneState;
  }

  part def ForceTorqueMonitor {
    attribute measuredForce : ForceValue;
    attribute measuredTorque : TorqueValue;
    attribute contactDetected : Boolean;
  }

  part def WorkpieceVisionSystem {
    attribute fieldOfViewWidth : LengthValue = 0.7 [SI::m];
    attribute fieldOfViewDepth : LengthValue = 0.5 [SI::m];
    attribute detectionLatency : TimeValue = 0.05 [SI::s];

    port detectedWorkpiece : WorkpieceOutputPort;

    perform action locateWorkpiece : LocateWorkpieceAction;
  }

  part def InfeedFixture {
    attribute fixtureCapacity : Integer = 20;

    port inbound : WorkpieceInputPort;
    port availableWorkpiece : WorkpieceOutputPort;
  }

  part def OutfeedFixture {
    attribute fixtureCapacity : Integer = 20;

    port placedWorkpiece : WorkpieceInputPort;
    port outbound : WorkpieceOutputPort;
  }

  action def PickAndPlaceAction {
    in item sourceWorkpiece : Workpiece;
    out item placedWorkpiece : Workpiece;
    out attribute result : TaskResult;

    first start;
    then locatePart;
    then approachPart;
    then gripPart;
    then liftPart;
    then transferPart;
    then placePart;
    then releasePart;
    then complete;

    action locatePart : LocateWorkpieceAction;
    action approachPart : ExecuteRobotMotionAction;
    action gripPart : CoordinateGripperAction;
    action liftPart : ExecuteRobotMotionAction;
    action transferPart : ExecuteRobotMotionAction;
    action placePart : ExecuteRobotMotionAction;
    action releasePart : CoordinateGripperAction;
  }

  action def LocateWorkpieceAction {
    out item detected : Workpiece;
    out attribute confidence : Real;
  }

  action def PlanCollisionAwareMotionAction {
    in item target : MotionCommand;
    in item status : RobotStatus;
    out item plannedCommand : MotionCommand;
  }

  action def ExecuteRobotMotionAction {
    in item command : MotionCommand;
    in item safety : SafetySignal;
    out item status : RobotStatus;
  }

  action def CoordinateGripperAction {
    in item workpiece : Workpiece;
    in item command : GripperCommand;
    out item feedback : GripperFeedback;
  }

  action def EvaluateCollaborativeSafetyAction {
    in attribute humanDetected : Boolean;
    in attribute contactDetected : Boolean;
    in attribute emergencyStopPressed : Boolean;
    out item safetySignal : SafetySignal;
  }

  state def RobotCellStateMachine {
    entry; then idle;

    state idle;
    state teaching;
    state automaticProduction;
    state collaborativeReducedSpeed;
    state protectiveStop;
    state emergencyStop;
    state faultRecovery;

    transition idle_to_teaching
      first idle
      accept operatorTeachRequest
      then teaching;

    transition idle_to_automatic
      first idle
      accept startProduction
      then automaticProduction;

    transition automatic_to_collaborative
      first automaticProduction
      accept humanEnteredMonitoredZone
      then collaborativeReducedSpeed;

    transition collaborative_to_automatic
      first collaborativeReducedSpeed
      accept humanExitedMonitoredZone
      then automaticProduction;

    transition automatic_to_protectiveStop
      first automaticProduction
      accept protectiveStopRequested
      then protectiveStop;

    transition collaborative_to_protectiveStop
      first collaborativeReducedSpeed
      accept protectiveStopRequested
      then protectiveStop;

    transition any_to_emergencyStop
      first automaticProduction
      accept emergencyStopPressed
      then emergencyStop;

    transition protectiveStop_to_idle
      first protectiveStop
      accept resetAndAcknowledge
      then idle;

    transition emergencyStop_to_faultRecovery
      first emergencyStop
      accept emergencyReleased
      then faultRecovery;

    transition faultRecovery_to_idle
      first faultRecovery
      accept resetAndAcknowledge
      then idle;
  }

  state def GripperStateMachine {
    entry; then open;

    state open;
    state closing;
    state holding;
    state opening;
    state error;

    transition open_to_closing
      first open
      accept closeCommand
      then closing;

    transition closing_to_holding
      first closing
      accept workpieceDetected
      then holding;

    transition closing_to_error
      first closing
      accept gripTimeout
      then error;

    transition holding_to_opening
      first holding
      accept openCommand
      then opening;

    transition opening_to_open
      first opening
      accept jawsOpen
      then open;

    transition error_to_open
      first error
      accept resetCommand
      then open;
  }

  requirement def PrimaryFunctionRequirement {
    subject cell : DoosanCollaborativeRobotCell;

    doc /* The system shall use a Doosan Robotics collaborative robot arm to pick workpieces from an infeed fixture, transfer them through a monitored shared workspace, and place them on an outfeed fixture. */

    require constraint {
      cell.nominalPayloadCapacity >= 5 [SI::kg]
    }
  }

  requirement def CollaborativeSafetyRequirement {
    subject cell : DoosanCollaborativeRobotCell;

    doc /* The system shall reduce robot speed or stop motion when a human is detected in the collaborative workspace. */

    require constraint {
      cell.collaborativeSpeedLimit <= 0.25 [SI::m / SI::s]
    }
  }

  requirement def PayloadHandlingRequirement {
    subject cell : DoosanCollaborativeRobotCell;

    doc /* The system shall handle workpieces up to the configured robot payload while accounting for gripper mass. */

    require constraint {
      cell.nominalPayloadCapacity >= cell.endEffector.gripperMass
    }
  }

  requirement def CycleTimeRequirement {
    subject cell : DoosanCollaborativeRobotCell;

    doc /* The system shall complete a nominal pick-and-place cycle within the specified cycle time during automatic operation. */

    require constraint {
      cell.nominalCycleTime <= 12 [SI::s]
    }
  }

  requirement def EmergencyStopRequirement {
    subject cell : DoosanCollaborativeRobotCell;

    doc /* The system shall command emergency stop behavior within the specified reaction time after an emergency stop device is activated. */

    require constraint {
      cell.safetySystem.emergencyStopReactionTime <= 0.08 [SI::s]
    }
  }

  satisfy PrimaryFunctionRequirement by DoosanCollaborativeRobotCell;
  satisfy CollaborativeSafetyRequirement by CollaborativeSafetySystem;
  satisfy PayloadHandlingRequirement by DoosanCollaborativeArm;
  satisfy CycleTimeRequirement by PickAndPlaceAction;
  satisfy EmergencyStopRequirement by CollaborativeSafetySystem;

  part doosanPickAndPlaceCell : DoosanCollaborativeRobotCell {
    attribute cellName = "Doosan M-Series Collaborative Workpiece Transfer Cell";
    attribute nominalPayloadCapacity = 5 [SI::kg];
    attribute maximumReach = 0.9 [SI::m];
    attribute collaborativeSpeedLimit = 0.25 [SI::m / SI::s];
    attribute automaticSpeedLimit = 1.0 [SI::m / SI::s];
    attribute nominalCycleTime = 12 [SI::s];
  }
}