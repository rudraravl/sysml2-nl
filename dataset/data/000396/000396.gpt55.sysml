package ModelRobotPrimaryTaskSystem {
  import ScalarValues::*;
  import SI::*;

  attribute def Distance :> Real;
  attribute def Angle :> Real;
  attribute def Speed :> Real;
  attribute def Acceleration :> Real;
  attribute def TimeDuration :> Real;
  attribute def Mass :> Real;
  attribute def Force :> Real;
  attribute def Power :> Real;
  attribute def Energy :> Real;
  attribute def Voltage :> Real;
  attribute def Current :> Real;
  attribute def Temperature :> Real;
  attribute def Probability :> Real;
  attribute def DataRate :> Real;

  enum def RobotMode {
    enum poweredOff;
    enum booting;
    enum ready;
    enum executingPrimaryTask;
    enum charging;
    enum paused;
    enum faulted;
    enum emergencyStopped;
  }

  enum def TaskPhase {
    enum notAssigned;
    enum planning;
    enum navigatingToPickup;
    enum acquiringObject;
    enum transportingObject;
    enum placingObject;
    enum verifyingPlacement;
    enum complete;
    enum failed;
  }

  enum def HealthLevel {
    enum nominal;
    enum degraded;
    enum critical;
  }

  enum def GripperState {
    enum open;
    enum closing;
    enum closedWithObject;
    enum closedEmpty;
    enum releasing;
  }

  item def ElectricalPowerFlow {
    attribute voltage : Voltage = 48.0 [V];
    attribute current : Current = 0.0 [A];
    attribute power : Power = 0.0 [W];
  }

  item def ControlCommand {
    attribute commandId : Integer;
    attribute issuedTime : TimeDuration;
    attribute targetMode : RobotMode;
    attribute priority : Integer;
  }

  item def MotionCommand {
    attribute targetX : Distance = 0.0 [m];
    attribute targetY : Distance = 0.0 [m];
    attribute targetYaw : Angle = 0.0 [rad];
    attribute maxSpeed : Speed = 1.0 [m/s];
    attribute maxAcceleration : Acceleration = 0.8 [m/s^2];
  }

  item def MotionStatus {
    attribute currentX : Distance = 0.0 [m];
    attribute currentY : Distance = 0.0 [m];
    attribute currentYaw : Angle = 0.0 [rad];
    attribute speed : Speed = 0.0 [m/s];
    attribute localizationConfidence : Probability = 0.99;
  }

  item def ManipulationCommand {
    attribute objectMassEstimate : Mass = 1.0 [kg];
    attribute graspWidth : Distance = 0.08 [m];
    attribute approachHeight : Distance = 0.20 [m];
    attribute gripForce : Force = 45.0 [N];
  }

  item def ManipulationStatus {
    attribute gripperState : GripperState = GripperState::open;
    attribute measuredGripForce : Force = 0.0 [N];
    attribute objectSecured : Boolean = false;
  }

  item def PerceptionFrame {
    attribute frameId : Integer;
    attribute timestamp : TimeDuration;
    attribute detectedObjectX : Distance = 0.0 [m];
    attribute detectedObjectY : Distance = 0.0 [m];
    attribute objectConfidence : Probability = 0.0;
    attribute obstacleClearance : Distance = 5.0 [m];
  }

  item def TaskReport {
    attribute taskId : Integer;
    attribute phase : TaskPhase = TaskPhase::notAssigned;
    attribute success : Boolean = false;
    attribute completionTime : TimeDuration = 0.0 [s];
    attribute placementError : Distance = 0.0 [m];
  }

  item def DiagnosticReport {
    attribute health : HealthLevel = HealthLevel::nominal;
    attribute batteryStateOfCharge : Probability = 1.0;
    attribute cpuTemperature : Temperature = 35.0 [degC];
    attribute activeFaultCode : Integer = 0;
  }

  item def EmergencyStopSignal {
    attribute asserted : Boolean = false;
    attribute sourceId : Integer;
  }

  port def ElectricalPowerPort {
    in item powerIn : ElectricalPowerFlow;
    out item powerOut : ElectricalPowerFlow;
  }

  port def ControlPort {
    in item commandIn : ControlCommand;
    out item reportOut : TaskReport;
    out item diagnosticOut : DiagnosticReport;
  }

  port def MotionPort {
    in item commandIn : MotionCommand;
    out item statusOut : MotionStatus;
  }

  port def ManipulationPort {
    in item commandIn : ManipulationCommand;
    out item statusOut : ManipulationStatus;
  }

  port def PerceptionPort {
    out item frameOut : PerceptionFrame;
  }

  port def SafetyPort {
    in item emergencyStopIn : EmergencyStopSignal;
    out item diagnosticOut : DiagnosticReport;
  }

  port def DataPort {
    in item controlIn : ControlCommand;
    out item reportOut : TaskReport;
    out item diagnosticsOut : DiagnosticReport;
  }

  port def ChargingPort {
    in item chargingPower : ElectricalPowerFlow;
    out item chargingStatus : DiagnosticReport;
  }

  connection def PowerCable {
    end source : ElectricalPowerPort;
    end load : ElectricalPowerPort;
  }

  connection def ControlLink {
    end controller : ControlPort;
    end controlled : ControlPort;
  }

  connection def MotionLink {
    end controller : MotionPort;
    end base : MotionPort;
  }

  connection def ManipulationLink {
    end controller : ManipulationPort;
    end manipulator : ManipulationPort;
  }

  connection def PerceptionLink {
    end sensor : PerceptionPort;
    end controller : PerceptionPort;
  }

  connection def SafetyLink {
    end source : SafetyPort;
    end sink : SafetyPort;
  }

  part def BatteryPack {
    attribute nominalVoltage : Voltage = 48.0 [V];
    attribute capacity : Energy = 1200.0 [W*h];
    attribute maxContinuousPower : Power = 1400.0 [W];
    attribute stateOfCharge : Probability = 1.0;
    attribute minimumOperationalStateOfCharge : Probability = 0.15;
    attribute mass : Mass = 8.5 [kg];

    port power : ElectricalPowerPort;
    port charge : ChargingPort;
    port diagnostics : ControlPort;
  }

  part def PowerDistributionUnit {
    attribute inputVoltage : Voltage = 48.0 [V];
    attribute logicBusVoltage : Voltage = 24.0 [V];
    attribute actuatorBusVoltage : Voltage = 48.0 [V];
    attribute conversionEfficiency : Probability = 0.94;
    attribute maximumOutputPower : Power = 1300.0 [W];

    port batteryInput : ElectricalPowerPort;
    port controllerOutput : ElectricalPowerPort;
    port driveOutput : ElectricalPowerPort;
    port manipulatorOutput : ElectricalPowerPort;
    port sensorOutput : ElectricalPowerPort;
    port diagnostics : ControlPort;
  }

  part def MobileBase {
    attribute wheelBase : Distance = 0.62 [m];
    attribute trackWidth : Distance = 0.54 [m];
    attribute maxSpeed : Speed = 1.25 [m/s];
    attribute maxAcceleration : Acceleration = 1.0 [m/s^2];
    attribute maximumSlope : Angle = 0.17 [rad];
    attribute positionError : Distance = 0.02 [m];

    port power : ElectricalPowerPort;
    port motion : MotionPort;
    port safety : SafetyPort;
  }

  part def SixAxisManipulator {
    attribute reach : Distance = 0.75 [m];
    attribute payloadCapacity : Mass = 3.0 [kg];
    attribute repeatability : Distance = 0.0015 [m];
    attribute jointSpeedLimit : Speed = 1.2 [rad/s];
    attribute nominalPower : Power = 280.0 [W];

    port power : ElectricalPowerPort;
    port manipulation : ManipulationPort;
    port safety : SafetyPort;
  }

  part def AdaptiveGripper {
    attribute maxOpening : Distance = 0.12 [m];
    attribute minOpening : Distance = 0.0 [m];
    attribute maximumGripForce : Force = 120.0 [N];
    attribute minimumDetectableObjectMass : Mass = 0.05 [kg];
    attribute state : GripperState = GripperState::open;

    port power : ElectricalPowerPort;
    port manipulation : ManipulationPort;
    port safety : SafetyPort;
  }

  part def PerceptionSuite {
    attribute lidarRange : Distance = 12.0 [m];
    attribute cameraRange : Distance = 6.0 [m];
    attribute minimumObjectConfidence : Probability = 0.92;
    attribute updateRate : DataRate = 30.0 [Hz];
    attribute minimumObstacleClearance : Distance = 0.30 [m];

    port power : ElectricalPowerPort;
    port perception : PerceptionPort;
    port diagnostics : ControlPort;
  }

  part def SafetyController {
    attribute stopReactionTime : TimeDuration = 0.08 [s];
    attribute safeStoppingDistance : Distance = 0.25 [m];
    attribute estopLatched : Boolean = false;

    port robotSafety : SafetyPort;
    port baseSafety : SafetyPort;
    port armSafety : SafetyPort;
    port gripperSafety : SafetyPort;
    port operatorSafety : SafetyPort;
    port diagnostics : ControlPort;
  }

  part def AutonomyComputer {
    attribute processorPower : Power = 65.0 [W];
    attribute controlCycle : TimeDuration = 0.02 [s];
    attribute navigationUpdatePeriod : TimeDuration = 0.05 [s];
    attribute manipulationUpdatePeriod : TimeDuration = 0.01 [s];
    attribute taskSuccessProbabilityEstimate : Probability = 0.98;
    attribute maximumCpuTemperature : Temperature = 85.0 [degC];

    port power : ElectricalPowerPort;
    port operatorInterface : ControlPort;
    port baseControl : MotionPort;
    port armControl : ManipulationPort;
    port perceptionInput : PerceptionPort;
    port safety : SafetyPort;
  }

  part def OperatorStation {
    attribute commandRange : Distance = 50.0 [m];
    attribute commandLatency : TimeDuration = 0.10 [s];
    attribute displayUpdatePeriod : TimeDuration = 0.25 [s];

    port data : DataPort;
    port safety : SafetyPort;
  }

  part def ChargingDock {
    attribute outputVoltage : Voltage = 48.0 [V];
    attribute maximumChargingPower : Power = 600.0 [W];
    attribute dockingTolerance : Distance = 0.04 [m];

    port chargePower : ChargingPort;
    port safety : SafetyPort;
  }

  part def PickupStation {
    attribute pickupX : Distance = 2.0 [m];
    attribute pickupY : Distance = 1.5 [m];
    attribute pickupHeight : Distance = 0.85 [m];
    attribute objectMass : Mass = 1.2 [kg];
    attribute objectWidth : Distance = 0.07 [m];
  }

  part def DropoffStation {
    attribute dropoffX : Distance = 8.0 [m];
    attribute dropoffY : Distance = 3.0 [m];
    attribute dropoffHeight : Distance = 0.85 [m];
    attribute placementTolerance : Distance = 0.03 [m];
  }

  action def BootRobot {
    out ready : Boolean;
    action energizeController;
    action loadConfiguration;
    action verifySensors;
    action verifyActuators;
    action enableSafety;
    first energizeController then loadConfiguration;
    then verifySensors;
    then verifyActuators;
    then enableSafety;
    then done;
  }

  action def PlanPrimaryTask {
    in pickupX : Distance;
    in pickupY : Distance;
    in dropoffX : Distance;
    in dropoffY : Distance;
    out estimatedDuration : TimeDuration;
    out plannedPathLength : Distance;

    action fuseMap;
    action validateObject;
    action computeRouteToPickup;
    action computeRouteToDropoff;
    action reserveSafeCorridor;

    first fuseMap then validateObject;
    then computeRouteToPickup;
    then computeRouteToDropoff;
    then reserveSafeCorridor;
    then done;
  }

  action def NavigateToPose {
    in targetX : Distance;
    in targetY : Distance;
    in targetYaw : Angle;
    in allowablePositionError : Distance;
    out arrived : Boolean;

    action localize;
    action generateTrajectory;
    action commandDrive;
    action monitorObstacles;
    action verifyArrival;

    first localize then generateTrajectory;
    then commandDrive;
    then monitorObstacles;
    then verifyArrival;
    then done;
  }

  action def AcquireObject {
    in objectMass : Mass;
    in objectWidth : Distance;
    in pickupHeight : Distance;
    out secured : Boolean;

    action perceiveObjectPose;
    action moveArmToPreGrasp;
    action openGripper;
    action approachObject;
    action closeGripper;
    action liftObject;
    action verifyGrip;

    first perceiveObjectPose then moveArmToPreGrasp;
    then openGripper;
    then approachObject;
    then closeGripper;
    then liftObject;
    then verifyGrip;
    then done;
  }

  action def PlaceObject {
    in dropoffHeight : Distance;
    in placementTolerance : Distance;
    out placed : Boolean;
    out placementError : Distance;

    action moveArmToPlacePose;
    action lowerObject;
    action releaseGripper;
    action retractArm;
    action verifyPlacement;

    first moveArmToPlacePose then lowerObject;
    then releaseGripper;
    then retractArm;
    then verifyPlacement;
    then done;
  }

  action def ExecutePrimaryPickAndPlaceTask {
    in taskId : Integer;
    in pickupX : Distance;
    in pickupY : Distance;
    in pickupHeight : Distance;
    in dropoffX : Distance;
    in dropoffY : Distance;
    in dropoffHeight : Distance;
    in objectMass : Mass;
    in objectWidth : Distance;
    out report : TaskReport;

    action planTask : PlanPrimaryTask;
    action navigateToPickup : NavigateToPose;
    action acquire : AcquireObject;
    action navigateToDropoff : NavigateToPose;
    action place : PlaceObject;
    action verifyAndReport;

    first planTask then navigateToPickup;
    then acquire;
    then navigateToDropoff;
    then place;
    then verifyAndReport;
    then done;
  }

  state def ModelRobotOperationalStateMachine {
    attribute mode : RobotMode = RobotMode::poweredOff;
    attribute taskPhase : TaskPhase = TaskPhase::notAssigned;

    state PoweredOff;
    state Booting;
    state Ready;
    state ExecutingPrimaryTask;
    state Charging;
    state Paused;
    state Faulted;
    state EmergencyStopped;

    entry then PoweredOff;

    transition powerOn
      first PoweredOff
      accept ControlCommand
      then Booting;

    transition bootComplete
      first Booting
      then Ready;

    transition startPrimaryTask
      first Ready
      accept ControlCommand
      then ExecutingPrimaryTask;

    transition taskComplete
      first ExecutingPrimaryTask
      then Ready;

    transition lowBatteryCharge
      first Ready
      then Charging;

    transition chargeComplete
      first Charging
      then Ready;

    transition pauseRequested
      first ExecutingPrimaryTask
      accept ControlCommand
      then Paused;

    transition resumeRequested
      first Paused
      accept ControlCommand
      then ExecutingPrimaryTask;

    transition faultDetectedFromReady
      first Ready
      then Faulted;

    transition faultDetectedFromTask
      first ExecutingPrimaryTask
      then Faulted;

    transition faultCleared
      first Faulted
      then Ready;

    transition emergencyStopFromAnyTask
      first ExecutingPrimaryTask
      accept EmergencyStopSignal
      then EmergencyStopped;

    transition emergencyStopFromReady
      first Ready
      accept EmergencyStopSignal
      then EmergencyStopped;

    transition resetEmergencyStop
      first EmergencyStopped
      accept ControlCommand
      then Ready;
  }

  part def ModelRobot {
    attribute modelName : String = "Model robot";
    attribute totalMass : Mass = 42.0 [kg];
    attribute maximumPayload : Mass = 3.0 [kg];
    attribute footprintLength : Distance = 0.90 [m];
    attribute footprintWidth : Distance = 0.65 [m];
    attribute heightWithArmStowed : Distance = 1.10 [m];
    attribute primaryTaskCompletionProbability : Probability = 0.98;
    attribute nominalTaskDuration : TimeDuration = 85.0 [s];
    attribute maximumTaskDuration : TimeDuration = 120.0 [s];
    attribute placementAccuracy : Distance = 0.025 [m];
    attribute minimumObstacleClearance : Distance = 0.30 [m];
    attribute operatingMode : RobotMode = RobotMode::poweredOff;

    part battery : BatteryPack;
    part powerDistribution : PowerDistributionUnit;
    part autonomyComputer : AutonomyComputer;
    part mobileBase : MobileBase;
    part manipulator : SixAxisManipulator;
    part gripper : AdaptiveGripper;
    part perceptionSuite : PerceptionSuite;
    part safetyController : SafetyController;

    port operatorControl : ControlPort;
    port charging : ChargingPort;
    port safety : SafetyPort;
    port taskData : DataPort;

    connection batteryToPdu : PowerCable connect battery.power to powerDistribution.batteryInput;
    connection pduToComputer : PowerCable connect powerDistribution.controllerOutput to autonomyComputer.power;
    connection pduToBase : PowerCable connect powerDistribution.driveOutput to mobileBase.power;
    connection pduToManipulator : PowerCable connect powerDistribution.manipulatorOutput to manipulator.power;
    connection pduToGripper : PowerCable connect powerDistribution.manipulatorOutput to gripper.power;
    connection pduToPerception : PowerCable connect powerDistribution.sensorOutput to perceptionSuite.power;

    connection computerToBase : MotionLink connect autonomyComputer.baseControl to mobileBase.motion;
    connection computerToArm : ManipulationLink connect autonomyComputer.armControl to manipulator.manipulation;
    connection armToGripper : ManipulationLink connect manipulator.manipulation to gripper.manipulation;
    connection perceptionToComputer : PerceptionLink connect perceptionSuite.perception to autonomyComputer.perceptionInput;

    connection robotSafetyToController : SafetyLink connect safety to safetyController.robotSafety;
    connection safetyToBase : SafetyLink connect safetyController.baseSafety to mobileBase.safety;
    connection safetyToArm : SafetyLink connect safetyController.armSafety to manipulator.safety;
    connection safetyToGripper : SafetyLink connect safetyController.gripperSafety to gripper.safety;
    connection computerSafety : SafetyLink connect autonomyComputer.safety to safetyController.robotSafety;

    connection operatorToComputer : ControlLink connect operatorControl to autonomyComputer.operatorInterface;
    connection chargeToBattery : PowerCable connect charging to battery.charge;

    perform action boot : BootRobot;
    perform action primaryTask : ExecutePrimaryPickAndPlaceTask;
    exhibit state operationalStates : ModelRobotOperationalStateMachine;
  }

  part def RoboticWorkcell {
    attribute workcellLength : Distance = 10.0 [m];
    attribute workcellWidth : Distance = 5.0 [m];
    attribute allowedRobotSpeed : Speed = 1.25 [m/s];
    attribute requiredClearance : Distance = 0.30 [m];
    attribute requiredTaskSuccessProbability : Probability = 0.95;

    part robot : ModelRobot;
    part operatorStation : OperatorStation;
    part chargingDock : ChargingDock;
    part pickupStation : PickupStation;
    part dropoffStation : DropoffStation;

    port externalSafety : SafetyPort;

    connection operatorDataToRobot : ControlLink connect operatorStation.data to robot.operatorControl;
    connection operatorSafetyToRobot : SafetyLink connect operatorStation.safety to robot.safety;
    connection dockToRobotCharging : PowerCable connect chargingDock.chargePower to robot.charging;
    connection externalSafetyToRobot : SafetyLink connect externalSafety to robot.safety;
  }

  constraint def PayloadWithinRobotCapacity {
    in objectMass : Mass;
    in robotPayloadCapacity : Mass;
    constraint { objectMass <= robotPayloadCapacity }
  }

  constraint def PlacementAccuracyWithinTolerance {
    in placementAccuracy : Distance;
    in requiredTolerance : Distance;
    constraint { placementAccuracy <= requiredTolerance }
  }

  constraint def TaskCompletedWithinTime {
    in actualDuration : TimeDuration;
    in maximumDuration : TimeDuration;
    constraint { actualDuration <= maximumDuration }
  }

  constraint def SafeObstacleClearanceMaintained {
    in measuredClearance : Distance;
    in requiredClearance : Distance;
    constraint { measuredClearance >= requiredClearance }
  }

  constraint def SufficientBatteryForPrimaryTask {
    in stateOfCharge : Probability;
    in minimumRequiredStateOfCharge : Probability;
    constraint { stateOfCharge >= minimumRequiredStateOfCharge }
  }

  requirement def PrimaryTaskUseModelRobotRequirement {
    subject workcell : RoboticWorkcell;
    require constraint {
      workcell.robot.modelName == "Model robot"
    }
  }

  requirement def PickAndPlaceTaskRequirement {
    subject workcell : RoboticWorkcell;
    require constraint {
      workcell.robot.primaryTaskCompletionProbability >= workcell.requiredTaskSuccessProbability
    }
  }

  requirement def PayloadRequirement {
    subject workcell : RoboticWorkcell;
    require constraint {
      workcell.pickupStation.objectMass <= workcell.robot.maximumPayload
    }
  }

  requirement def PlacementRequirement {
    subject workcell : RoboticWorkcell;
    require constraint {
      workcell.robot.placementAccuracy <= workcell.dropoffStation.placementTolerance
    }
  }

  requirement def TaskDurationRequirement {
    subject workcell : RoboticWorkcell;
    require constraint {
      workcell.robot.nominalTaskDuration <= workcell.robot.maximumTaskDuration
    }
  }

  requirement def ClearanceRequirement {
    subject workcell : RoboticWorkcell;
    require constraint {
      workcell.robot.minimumObstacleClearance >= workcell.requiredClearance
    }
  }

  requirement def BatteryRequirement {
    subject workcell : RoboticWorkcell;
    require constraint {
      workcell.robot.battery.stateOfCharge >= workcell.robot.battery.minimumOperationalStateOfCharge
    }
  }

  requirement def EmergencyStopRequirement {
    subject workcell : RoboticWorkcell;
    require constraint {
      workcell.robot.safetyController.stopReactionTime <= 0.10 [s]
    }
  }

  requirement def NavigationSpeedRequirement {
    subject workcell : RoboticWorkcell;
    require constraint {
      workcell.robot.mobileBase.maxSpeed <= workcell.allowedRobotSpeed
    }
  }

  requirement def PerceptionConfidenceRequirement {
    subject workcell : RoboticWorkcell;
    require constraint {
      workcell.robot.perceptionSuite.minimumObjectConfidence >= 0.90
    }
  }

  part modelRobotWorkcell : RoboticWorkcell {
    attribute redefines workcellLength = 10.0 [m];
    attribute redefines workcellWidth = 5.0 [m];
    attribute redefines allowedRobotSpeed = 1.25 [m/s];
    attribute redefines requiredClearance = 0.30 [m];
    attribute redefines requiredTaskSuccessProbability = 0.95;

    part redefines robot {
      attribute redefines modelName = "Model robot";
      attribute redefines totalMass = 42.0 [kg];
      attribute redefines maximumPayload = 3.0 [kg];
      attribute redefines primaryTaskCompletionProbability = 0.98;
      attribute redefines nominalTaskDuration = 85.0 [s];
      attribute redefines maximumTaskDuration = 120.0 [s];
      attribute redefines placementAccuracy = 0.025 [m];

      part redefines battery {
        attribute redefines stateOfCharge = 0.86;
        attribute redefines capacity = 1200.0 [W*h];
      }

      part redefines mobileBase {
        attribute redefines maxSpeed = 1.25 [m/s];
      }

      part redefines perceptionSuite {
        attribute redefines minimumObjectConfidence = 0.92;
      }

      part redefines safetyController {
        attribute redefines stopReactionTime = 0.08 [s];
      }
    }

    part redefines pickupStation {
      attribute redefines pickupX = 2.0 [m];
      attribute redefines pickupY = 1.5 [m];
      attribute redefines pickupHeight = 0.85 [m];
      attribute redefines objectMass = 1.2 [kg];
      attribute redefines objectWidth = 0.07 [m];
    }

    part redefines dropoffStation {
      attribute redefines dropoffX = 8.0 [m];
      attribute redefines dropoffY = 3.0 [m];
      attribute redefines dropoffHeight = 0.85 [m];
      attribute redefines placementTolerance = 0.03 [m];
    }
  }

  requirement primaryTaskUsesModelRobot : PrimaryTaskUseModelRobotRequirement {
    subject workcell = modelRobotWorkcell;
  }

  requirement primaryPickAndPlace : PickAndPlaceTaskRequirement {
    subject workcell = modelRobotWorkcell;
  }

  requirement payloadSatisfied : PayloadRequirement {
    subject workcell = modelRobotWorkcell;
  }

  requirement placementSatisfied : PlacementRequirement {
    subject workcell = modelRobotWorkcell;
  }

  requirement durationSatisfied : TaskDurationRequirement {
    subject workcell = modelRobotWorkcell;
  }

  requirement clearanceSatisfied : ClearanceRequirement {
    subject workcell = modelRobotWorkcell;
  }

  requirement batterySatisfied : BatteryRequirement {
    subject workcell = modelRobotWorkcell;
  }

  requirement emergencyStopSatisfied : EmergencyStopRequirement {
    subject workcell = modelRobotWorkcell;
  }

  requirement navigationSpeedSatisfied : NavigationSpeedRequirement {
    subject workcell = modelRobotWorkcell;
  }

  requirement perceptionSatisfied : PerceptionConfidenceRequirement {
    subject workcell = modelRobotWorkcell;
  }

  satisfy primaryTaskUsesModelRobot by modelRobotWorkcell.robot;
  satisfy primaryPickAndPlace by modelRobotWorkcell.robot.primaryTask;
  satisfy payloadSatisfied by modelRobotWorkcell.robot.manipulator;
  satisfy placementSatisfied by modelRobotWorkcell.robot.gripper;
  satisfy durationSatisfied by modelRobotWorkcell.robot.autonomyComputer;
  satisfy clearanceSatisfied by modelRobotWorkcell.robot.perceptionSuite;
  satisfy batterySatisfied by modelRobotWorkcell.robot.battery;
  satisfy emergencyStopSatisfied by modelRobotWorkcell.robot.safetyController;
  satisfy navigationSpeedSatisfied by modelRobotWorkcell.robot.mobileBase;
  satisfy perceptionSatisfied by modelRobotWorkcell.robot.perceptionSuite;
}
