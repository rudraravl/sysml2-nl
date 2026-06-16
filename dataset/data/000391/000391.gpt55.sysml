package BangBangRoboticSystemModel {

  private import ScalarValues::*;

  attribute def Distance :> Real {
    attribute unit: String = "m";
  }

  attribute def Angle :> Real {
    attribute unit: String = "rad";
  }

  attribute def Time :> Real {
    attribute unit: String = "s";
  }

  attribute def Speed :> Real {
    attribute unit: String = "m/s";
  }

  attribute def AngularSpeed :> Real {
    attribute unit: String = "rad/s";
  }

  attribute def Acceleration :> Real {
    attribute unit: String = "m/s^2";
  }

  attribute def Voltage :> Real {
    attribute unit: String = "V";
  }

  attribute def Current :> Real {
    attribute unit: String = "A";
  }

  attribute def ElectricalPower :> Real {
    attribute unit: String = "W";
  }

  attribute def Energy :> Real {
    attribute unit: String = "Wh";
  }

  attribute def Torque :> Real {
    attribute unit: String = "N*m";
  }

  attribute def Force :> Real {
    attribute unit: String = "N";
  }

  attribute def Mass :> Real {
    attribute unit: String = "kg";
  }

  attribute def DutyCycle :> Real {
    attribute unit: "1";
  }

  attribute def EncoderCount :> Integer {
    attribute unit: String = "count";
  }

  attribute def Probability :> Real {
    attribute unit: String = "1";
  }

  enum def PolarityKind {
    enum positive;
    enum negative;
    enum zero;
  }

  enum def MissionPhaseKind {
    enum idle;
    enum initializing;
    enum navigatingToPickup;
    enum acquiringPayload;
    enum navigatingToDropoff;
    enum releasingPayload;
    enum complete;
    enum faulted;
  }

  enum def ControllerModeKind {
    enum disabled;
    enum bangBangTranslation;
    enum bangBangRotation;
    enum bangBangBrake;
    enum emergencyStop;
  }

  enum def PayloadStateKind {
    enum absent;
    enum detected;
    enum gripped;
    enum released;
  }

  item def DCPower {
    attribute voltage: Voltage;
    attribute current: Current;
    attribute power: ElectricalPower;
  }

  item def LogicPower {
    attribute voltage: Voltage;
    attribute current: Current;
  }

  item def MotorCommand {
    attribute polarity: PolarityKind;
    attribute duty: DutyCycle;
    attribute enable: Boolean;
  }

  item def MotorStatus {
    attribute shaftSpeed: AngularSpeed;
    attribute phaseCurrent: Current;
    attribute estimatedTorque: Torque;
    attribute driverTemperature: Real;
    attribute driverFault: Boolean;
  }

  item def WheelTorque {
    attribute torque: Torque;
    attribute angularSpeed: AngularSpeed;
  }

  item def EncoderFrame {
    attribute leftTicks: EncoderCount;
    attribute rightTicks: EncoderCount;
    attribute samplePeriod: Time;
  }

  item def Pose2D {
    attribute x: Distance;
    attribute y: Distance;
    attribute yaw: Angle;
  }

  item def Velocity2D {
    attribute forwardSpeed: Speed;
    attribute yawRate: AngularSpeed;
  }

  item def TargetPose {
    attribute goal: Pose2D;
    attribute positionTolerance: Distance;
    attribute headingTolerance: Angle;
  }

  item def RangeScan {
    attribute frontClearance: Distance;
    attribute leftClearance: Distance;
    attribute rightClearance: Distance;
    attribute rearClearance: Distance;
    attribute obstacleDetected: Boolean;
  }

  item def PayloadPackage {
    attribute packageMass: Mass;
    attribute packageWidth: Distance;
    attribute packageDepth: Distance;
    attribute packageHeight: Distance;
    attribute fragile: Boolean;
  }

  item def GripperCommand {
    attribute close: Boolean;
    attribute holdingForce: Force;
  }

  item def GripperStatus {
    attribute payloadState: PayloadStateKind;
    attribute measuredGripForce: Force;
    attribute jawOpening: Distance;
  }

  item def MissionCommand {
    attribute pickupPose: Pose2D;
    attribute dropoffPose: Pose2D;
    attribute payload: PayloadPackage;
  }

  item def MissionReport {
    attribute phase: MissionPhaseKind;
    attribute success: Boolean;
    attribute elapsedTime: Time;
    attribute finalPose: Pose2D;
    attribute faultText: String;
  }

  port def DCPowerSourcePort {
    out item power: DCPower;
  }

  port def DCPowerLoadPort {
    in item power: DCPower;
  }

  port def LogicPowerSourcePort {
    out item power: LogicPower;
  }

  port def LogicPowerLoadPort {
    in item power: LogicPower;
  }

  port def MotorCommandOutPort {
    out item command: MotorCommand;
  }

  port def MotorCommandInPort {
    in item command: MotorCommand;
  }

  port def MotorStatusOutPort {
    out item status: MotorStatus;
  }

  port def MotorStatusInPort {
    in item status: MotorStatus;
  }

  port def TorqueOutPort {
    out item torque: WheelTorque;
  }

  port def TorqueInPort {
    in item torque: WheelTorque;
  }

  port def EncoderOutPort {
    out item frame: EncoderFrame;
  }

  port def EncoderInPort {
    in item frame: EncoderFrame;
  }

  port def PoseOutPort {
    out item pose: Pose2D;
  }

  port def PoseInPort {
    in item pose: Pose2D;
  }

  port def TargetInPort {
    in item target: TargetPose;
  }

  port def RangeScanOutPort {
    out item scan: RangeScan;
  }

  port def RangeScanInPort {
    in item scan: RangeScan;
  }

  port def GripperCommandOutPort {
    out item command: GripperCommand;
  }

  port def GripperCommandInPort {
    in item command: GripperCommand;
  }

  port def GripperStatusOutPort {
    out item status: GripperStatus;
  }

  port def GripperStatusInPort {
    in item status: GripperStatus;
  }

  port def MissionCommandInPort {
    in item command: MissionCommand;
  }

  port def MissionReportOutPort {
    out item report: MissionReport;
  }

  constraint def BangBangDutyConstraint {
    in error: Real;
    in deadband: Real;
    in maxDuty: DutyCycle;
    out duty: DutyCycle;

    constraint law {
      (error > deadband and duty == maxDuty) or
      (error < -deadband and duty == -maxDuty) or
      (error <= deadband and error >= -deadband and duty == 0.0)
    }
  }

  constraint def MinimumClearanceConstraint {
    in clearance: Distance;
    in minimumClearance: Distance;

    constraint safeClearance {
      clearance >= minimumClearance
    }
  }

  constraint def BatteryEnduranceConstraint {
    in storedEnergy: Energy;
    in averagePower: ElectricalPower;
    in requiredDuration: Time;

    constraint sufficientEnergy {
      storedEnergy >= averagePower * requiredDuration
    }
  }

  action def EstimatePoseFromEncoders {
    in item encoderFrame: EncoderFrame;
    in wheelRadius: Distance;
    in wheelBase: Distance;
    in previousPose: Pose2D;
    out item estimatedPose: Pose2D;
    out item estimatedVelocity: Velocity2D;
  }

  action def ComputeBangBangMotorCommands {
    in item currentPose: Pose2D;
    in item target: TargetPose;
    in item rangeScan: RangeScan;
    in positionDeadband: Distance;
    in headingDeadband: Angle;
    in maximumDuty: DutyCycle;
    in minimumClearance: Distance;
    out item leftCommand: MotorCommand;
    out item rightCommand: MotorCommand;
    out mode: ControllerModeKind;

    constraint translationLaw : BangBangDutyConstraint {
      in error = target.goal.x - currentPose.x;
      in deadband = positionDeadband;
      in maxDuty = maximumDuty;
    }

    constraint obstacleRule : MinimumClearanceConstraint {
      in clearance = rangeScan.frontClearance;
      in minimumClearance = minimumClearance;
    }
  }

  action def GripPayload {
    in item payload: PayloadPackage;
    in requiredGripForce: Force;
    out item command: GripperCommand;
    out item status: GripperStatus;
  }

  action def ReleasePayload {
    out item command: GripperCommand;
    out item status: GripperStatus;
  }

  action def TransportPayloadByBangBangRobot {
    in item missionCommand: MissionCommand;
    out item report: MissionReport;

    action initialize;
    action navigateToPickup;
    action closeGripper;
    action navigateToDropoff;
    action openGripper;
    action finalize;

    first initialize then navigateToPickup;
    then navigateToPickup then closeGripper;
    then closeGripper then navigateToDropoff;
    then navigateToDropoff then openGripper;
    then openGripper then finalize;
  }

  state def BangBangControllerStateMachine {
    attribute positionError: Distance;
    attribute headingError: Angle;
    attribute frontClearance: Distance;
    attribute positionDeadband: Distance = 0.05;
    attribute headingDeadband: Angle = 0.04;
    attribute minimumClearance: Distance = 0.25;
    attribute commandedDuty: DutyCycle;
    attribute mode: ControllerModeKind;

    state disabled;
    state rotateFullLeft;
    state rotateFullRight;
    state driveFullForward;
    state driveFullReverse;
    state stoppedInDeadband;
    state emergencyStop;

    transition initial then disabled;

    transition enableRotationLeft
      first disabled
      then rotateFullLeft
      if headingError > headingDeadband and frontClearance >= minimumClearance;

    transition enableRotationRight
      first disabled
      then rotateFullRight
      if headingError < -headingDeadband and frontClearance >= minimumClearance;

    transition rotateLeftToForward
      first rotateFullLeft
      then driveFullForward
      if headingError <= headingDeadband and headingError >= -headingDeadband and positionError > positionDeadband and frontClearance >= minimumClearance;

    transition rotateRightToForward
      first rotateFullRight
      then driveFullForward
      if headingError <= headingDeadband and headingError >= -headingDeadband and positionError > positionDeadband and frontClearance >= minimumClearance;

    transition forwardToReverse
      first driveFullForward
      then driveFullReverse
      if positionError < -positionDeadband and frontClearance >= minimumClearance;

    transition reverseToForward
      first driveFullReverse
      then driveFullForward
      if positionError > positionDeadband and frontClearance >= minimumClearance;

    transition forwardToStopped
      first driveFullForward
      then stoppedInDeadband
      if positionError <= positionDeadband and positionError >= -positionDeadband;

    transition reverseToStopped
      first driveFullReverse
      then stoppedInDeadband
      if positionError <= positionDeadband and positionError >= -positionDeadband;

    transition obstacleFromForward
      first driveFullForward
      then emergencyStop
      if frontClearance < minimumClearance;

    transition obstacleFromRotateLeft
      first rotateFullLeft
      then emergencyStop
      if frontClearance < minimumClearance;

    transition obstacleFromRotateRight
      first rotateFullRight
      then emergencyStop
      if frontClearance < minimumClearance;

    transition clearEmergency
      first emergencyStop
      then stoppedInDeadband
      if frontClearance >= minimumClearance and positionError <= positionDeadband and positionError >= -positionDeadband;
  }

  state def PrimaryMissionStateMachine {
    attribute phase: MissionPhaseKind;
    attribute payloadState: PayloadStateKind;
    attribute atPickup: Boolean;
    attribute atDropoff: Boolean;
    attribute faultPresent: Boolean;

    state idle;
    state initializing;
    state navigatingToPickup;
    state acquiringPayload;
    state navigatingToDropoff;
    state releasingPayload;
    state complete;
    state faulted;

    transition initial then idle;

    transition startMission
      first idle
      then initializing;

    transition initialized
      first initializing
      then navigatingToPickup
      if not faultPresent;

    transition arrivalAtPickup
      first navigatingToPickup
      then acquiringPayload
      if atPickup and not faultPresent;

    transition payloadGripped
      first acquiringPayload
      then navigatingToDropoff
      if payloadState == PayloadStateKind::gripped and not faultPresent;

    transition arrivalAtDropoff
      first navigatingToDropoff
      then releasingPayload
      if atDropoff and not faultPresent;

    transition payloadReleased
      first releasingPayload
      then complete
      if payloadState == PayloadStateKind::released and not faultPresent;

    transition faultDuringInitialization
      first initializing
      then faulted
      if faultPresent;

    transition faultDuringPickupNavigation
      first navigatingToPickup
      then faulted
      if faultPresent;

    transition faultDuringAcquisition
      first acquiringPayload
      then faulted
      if faultPresent;

    transition faultDuringDropoffNavigation
      first navigatingToDropoff
      then faulted
      if faultPresent;

    transition faultDuringRelease
      first releasingPayload
      then faulted
      if faultPresent;
  }

  part def BatteryPack {
    attribute nominalVoltage: Voltage = 24.0;
    attribute capacity: Energy = 240.0;
    attribute maximumContinuousCurrent: Current = 20.0;
    attribute stateOfCharge: Probability = 1.0;

    port dcOut: DCPowerSourcePort;
  }

  part def PowerDistributionUnit {
    attribute inputVoltage: Voltage = 24.0;
    attribute logicVoltage: Voltage = 5.0;
    attribute motorRailCurrentLimit: Current = 18.0;
    attribute logicRailCurrentLimit: Current = 3.0;

    port dcIn: DCPowerLoadPort;
    port motorPowerOut: DCPowerSourcePort;
    port logicPowerOut: LogicPowerSourcePort;
  }

  part def BangBangController {
    attribute controlLawName: String = "bang-bang";
    attribute maximumDuty: DutyCycle = 1.0;
    attribute zeroDuty: DutyCycle = 0.0;
    attribute positionDeadband: Distance = 0.05;
    attribute headingDeadband: Angle = 0.04;
    attribute minimumClearance: Distance = 0.25;
    attribute commandPeriod: Time = 0.02;

    port logicPower: LogicPowerLoadPort;
    port currentPoseIn: PoseInPort;
    port targetIn: TargetInPort;
    port rangeIn: RangeScanInPort;
    port leftMotorCommandOut: MotorCommandOutPort;
    port rightMotorCommandOut: MotorCommandOutPort;
    port gripperCommandOut: GripperCommandOutPort;
    port gripperStatusIn: GripperStatusInPort;
    port missionCommandIn: MissionCommandInPort;
    port missionReportOut: MissionReportOutPort;

    perform action computeCommands: ComputeBangBangMotorCommands;
    exhibit state controllerStates: BangBangControllerStateMachine;
  }

  part def MotorDriver {
    attribute ratedVoltage: Voltage = 24.0;
    attribute peakCurrent: Current = 10.0;
    attribute switchingFrequency: Real = 20000.0;
    attribute commandLatency: Time = 0.002;

    port powerIn: DCPowerLoadPort;
    port commandIn: MotorCommandInPort;
    port statusOut: MotorStatusOutPort;
    port motorTorqueOut: TorqueOutPort;
  }

  part def DCMotor {
    attribute nominalVoltage: Voltage = 24.0;
    attribute stallTorque: Torque = 1.80;
    attribute noLoadSpeed: AngularSpeed = 52.0;
    attribute torqueConstant: Real = 0.075;
    attribute windingResistance: Real = 1.20;

    port torqueIn: TorqueInPort;
    port shaftOut: TorqueOutPort;
    port statusOut: MotorStatusOutPort;
  }

  part def Wheel {
    attribute radius: Distance = 0.075;
    attribute width: Distance = 0.035;
    attribute mass: Mass = 0.25;
    attribute maximumTractionForce: Force = 28.0;

    port axleTorqueIn: TorqueInPort;
  }

  part def DifferentialDriveBase {
    attribute wheelBase: Distance = 0.42;
    attribute trackWidth: Distance = 0.36;
    attribute maximumForwardSpeed: Speed = 1.20;
    attribute maximumYawRate: AngularSpeed = 3.0;
    attribute maximumAcceleration: Acceleration = 1.5;

    part leftWheel: Wheel;
    part rightWheel: Wheel;

    port leftTorqueIn: TorqueInPort;
    port rightTorqueIn: TorqueInPort;
  }

  part def WheelEncoderPair {
    attribute countsPerRevolution: EncoderCount = 2048;
    attribute samplePeriod: Time = 0.02;
    attribute leftCount: EncoderCount;
    attribute rightCount: EncoderCount;

    port encoderOut: EncoderOutPort;
    port logicPower: LogicPowerLoadPort;
  }

  part def PoseEstimator {
    attribute wheelRadius: Distance = 0.075;
    attribute wheelBase: Distance = 0.42;
    attribute updatePeriod: Time = 0.02;
    attribute estimatedPose: Pose2D;

    port encoderIn: EncoderInPort;
    port logicPower: LogicPowerLoadPort;
    port poseOut: PoseOutPort;

    perform action estimatePose: EstimatePoseFromEncoders;
  }

  part def RangeSensorArray {
    attribute maximumRange: Distance = 3.00;
    attribute minimumRange: Distance = 0.03;
    attribute updatePeriod: Time = 0.05;
    attribute angularCoverage: Angle = 3.14;

    port logicPower: LogicPowerLoadPort;
    port scanOut: RangeScanOutPort;
  }

  part def ParallelJawGripper {
    attribute maximumJawOpening: Distance = 0.12;
    attribute minimumJawOpening: Distance = 0.00;
    attribute maximumGripForce: Force = 45.0;
    attribute nominalGripForce: Force = 18.0;
    attribute payloadMassLimit: Mass = 2.0;
    attribute closeTime: Time = 0.80;
    attribute openTime: Time = 0.60;

    port powerIn: DCPowerLoadPort;
    port commandIn: GripperCommandInPort;
    port statusOut: GripperStatusOutPort;

    perform action grip: GripPayload;
    perform action release: ReleasePayload;
  }

  part def PayloadBay {
    attribute maximumPayloadMass: Mass = 2.0;
    attribute bedWidth: Distance = 0.22;
    attribute bedDepth: Distance = 0.18;
    attribute retentionLipHeight: Distance = 0.025;
  }

  part def SafetySupervisor {
    attribute hardStopClearance: Distance = 0.18;
    attribute watchdogTimeout: Time = 0.10;
    attribute maximumPermittedDuty: DutyCycle = 1.0;
    attribute emergencyStopActive: Boolean = false;

    port logicPower: LogicPowerLoadPort;
    port rangeIn: RangeScanInPort;
    port leftStatusIn: MotorStatusInPort;
    port rightStatusIn: MotorStatusInPort;
  }

  part def BangBangRobot {
    attribute robotMassWithoutPayload: Mass = 12.0;
    attribute maximumPayloadMass: Mass = 2.0;
    attribute nominalMissionSpeed: Speed = 1.20;
    attribute controlStrategy: String = "bang-bang";
    attribute primaryTaskName: String = "transport payload from pickup pose to dropoff pose";

    part battery: BatteryPack;
    part powerDistribution: PowerDistributionUnit;
    part controller: BangBangController;
    part leftDriver: MotorDriver;
    part rightDriver: MotorDriver;
    part leftMotor: DCMotor;
    part rightMotor: DCMotor;
    part driveBase: DifferentialDriveBase;
    part encoders: WheelEncoderPair;
    part poseEstimator: PoseEstimator;
    part rangeSensors: RangeSensorArray;
    part gripper: ParallelJawGripper;
    part payloadBay: PayloadBay;
    part safetySupervisor: SafetySupervisor;

    port missionCommandIn: MissionCommandInPort;
    port missionReportOut: MissionReportOutPort;

    connect battery.dcOut to powerDistribution.dcIn;
    connect powerDistribution.motorPowerOut to leftDriver.powerIn;
    connect powerDistribution.motorPowerOut to rightDriver.powerIn;
    connect powerDistribution.motorPowerOut to gripper.powerIn;
    connect powerDistribution.logicPowerOut to controller.logicPower;
    connect powerDistribution.logicPowerOut to encoders.logicPower;
    connect powerDistribution.logicPowerOut to poseEstimator.logicPower;
    connect powerDistribution.logicPowerOut to rangeSensors.logicPower;
    connect powerDistribution.logicPowerOut to safetySupervisor.logicPower;

    connect controller.leftMotorCommandOut to leftDriver.commandIn;
    connect controller.rightMotorCommandOut to rightDriver.commandIn;
    connect leftDriver.motorTorqueOut to leftMotor.torqueIn;
    connect rightDriver.motorTorqueOut to rightMotor.torqueIn;
    connect leftMotor.shaftOut to driveBase.leftTorqueIn;
    connect rightMotor.shaftOut to driveBase.rightTorqueIn;

    connect encoders.encoderOut to poseEstimator.encoderIn;
    connect poseEstimator.poseOut to controller.currentPoseIn;
    connect rangeSensors.scanOut to controller.rangeIn;
    connect rangeSensors.scanOut to safetySupervisor.rangeIn;

    connect leftDriver.statusOut to safetySupervisor.leftStatusIn;
    connect rightDriver.statusOut to safetySupervisor.rightStatusIn;

    connect controller.gripperCommandOut to gripper.commandIn;
    connect gripper.statusOut to controller.gripperStatusIn;

    connect missionCommandIn to controller.missionCommandIn;
    connect controller.missionReportOut to missionReportOut;

    perform action primaryBehavior: TransportPayloadByBangBangRobot;
    exhibit state missionStates: PrimaryMissionStateMachine;
  }

  part def TaskEnvironment {
    attribute floorLength: Distance = 8.0;
    attribute floorWidth: Distance = 5.0;
    attribute maximumFloorSlope: Angle = 0.05;
    attribute nominalFrictionCoefficient: Real = 0.75;

    item pickupPackage: PayloadPackage {
      attribute packageMass = 1.20;
      attribute packageWidth = 0.10;
      attribute packageDepth = 0.08;
      attribute packageHeight = 0.06;
      attribute fragile = false;
    }

    item pickupPose: Pose2D {
      attribute x = 1.00;
      attribute y = 1.00;
      attribute yaw = 0.00;
    }

    item dropoffPose: Pose2D {
      attribute x = 6.50;
      attribute y = 3.50;
      attribute yaw = 1.57;
    }
  }

  part def RoboticSystem {
    part bangBangRobot: BangBangRobot;
    part environment: TaskEnvironment;

    attribute requiredTaskCompletionTime: Time = 120.0;
    attribute requiredPositionAccuracy: Distance = 0.10;
    attribute requiredHeadingAccuracy: Angle = 0.10;
    attribute requiredMinimumObstacleClearance: Distance = 0.25;

    item nominalMission: MissionCommand {
      attribute pickupPose = environment.pickupPose;
      attribute dropoffPose = environment.dropoffPose;
      attribute payload = environment.pickupPackage;
    }

    connect bangBangRobot.missionCommandIn to bangBangRobot.controller.missionCommandIn;
    connect bangBangRobot.controller.missionReportOut to bangBangRobot.missionReportOut;

    perform action missionExecution: TransportPayloadByBangBangRobot;
  }

  requirement def PrimaryTaskRequirement {
    subject system: RoboticSystem;

    require constraint {
      system.bangBangRobot.primaryTaskName == "transport payload from pickup pose to dropoff pose"
    }
  }

  requirement def BangBangRobotRequirement {
    subject robot: BangBangRobot;

    require constraint {
      robot.controlStrategy == "bang-bang" and
      robot.controller.controlLawName == "bang-bang" and
      robot.controller.maximumDuty == 1.0 and
      robot.controller.zeroDuty == 0.0
    }
  }

  requirement def BangBangCommandRequirement {
    subject controller: BangBangController;

    require constraint {
      controller.maximumDuty == 1.0 and
      controller.positionDeadband <= 0.05 and
      controller.headingDeadband <= 0.04
    }
  }

  requirement def PositionAccuracyRequirement {
    subject system: RoboticSystem;

    require constraint {
      system.requiredPositionAccuracy <= 0.10 and
      system.requiredHeadingAccuracy <= 0.10
    }
  }

  requirement def SafetyClearanceRequirement {
    subject robot: BangBangRobot;

    require constraint {
      robot.controller.minimumClearance >= 0.25 and
      robot.safetySupervisor.hardStopClearance <= robot.controller.minimumClearance
    }
  }

  requirement def PayloadCapabilityRequirement {
    subject robot: BangBangRobot;

    require constraint {
      robot.gripper.payloadMassLimit >= robot.maximumPayloadMass and
      robot.payloadBay.maximumPayloadMass >= robot.maximumPayloadMass
    }
  }

  requirement def BatteryEnduranceRequirement {
    subject robot: BangBangRobot;

    require constraint endurance : BatteryEnduranceConstraint {
      in storedEnergy = robot.battery.capacity;
      in averagePower = 90.0;
      in requiredDuration = 120.0;
    }
  }

  requirement def EncoderFeedbackRequirement {
    subject robot: BangBangRobot;

    require constraint {
      robot.encoders.countsPerRevolution >= 2048 and
      robot.encoders.samplePeriod <= robot.controller.commandPeriod
    }
  }

  requirement def PrimaryMissionCompletionRequirement {
    subject system: RoboticSystem;

    require constraint {
      system.requiredTaskCompletionTime <= 120.0 and
      system.environment.pickupPackage.packageMass <= system.bangBangRobot.maximumPayloadMass
    }
  }

  part roboticSystem: RoboticSystem {
    satisfy primaryTask by bangBangRobot;
    satisfy bangBangUse by bangBangRobot;
    satisfy commandLaw by bangBangRobot.controller;
    satisfy accuracy by bangBangRobot.poseEstimator;
    satisfy clearance by bangBangRobot.safetySupervisor;
    satisfy payloadHandling by bangBangRobot.gripper;
    satisfy endurance by bangBangRobot.battery;
    satisfy feedback by bangBangRobot.encoders;
    satisfy missionCompletion by bangBangRobot;
  }

  requirement primaryTask : PrimaryTaskRequirement {
    subject system = roboticSystem;
  }

  requirement bangBangUse : BangBangRobotRequirement {
    subject robot = roboticSystem.bangBangRobot;
  }

  requirement commandLaw : BangBangCommandRequirement {
    subject controller = roboticSystem.bangBangRobot.controller;
  }

  requirement accuracy : PositionAccuracyRequirement {
    subject system = roboticSystem;
  }

  requirement clearance : SafetyClearanceRequirement {
    subject robot = roboticSystem.bangBangRobot;
  }

  requirement payloadHandling : PayloadCapabilityRequirement {
    subject robot = roboticSystem.bangBangRobot;
  }

  requirement endurance : BatteryEnduranceRequirement {
    subject robot = roboticSystem.bangBangRobot;
  }

  requirement feedback : EncoderFeedbackRequirement {
    subject robot = roboticSystem.bangBangRobot;
  }

  requirement missionCompletion : PrimaryMissionCompletionRequirement {
    subject system = roboticSystem;
  }

}
