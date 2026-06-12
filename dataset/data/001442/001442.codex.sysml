package HexapodSystemModel {

    import ScalarValues::*;
    import SI::*;

    attribute def LegId :> Integer;
    attribute def GaitPhase :> Real;
    attribute def BatteryStateOfCharge :> Real;
    attribute def TerrainSlope :> Real;
    attribute def StabilityMargin :> Real;
    attribute def JointAngle :> Real;
    attribute def JointTorque :> Real;
    attribute def MotorCurrent :> Real;
    attribute def ForceMagnitude :> Real;
    attribute def LinearSpeed :> Real;
    attribute def AngularRate :> Real;

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
        attribute power : Real;
    }

    item def MotionCommand {
        attribute desiredForwardSpeed : LinearSpeed;
        attribute desiredYawRate : AngularRate;
        attribute desiredBodyHeight : LengthValue;
        attribute gaitMode : GaitModeKind;
    }

    item def LegTrajectoryCommand {
        attribute legId : LegId;
        attribute phase : GaitPhase;
        attribute footTargetX : LengthValue;
        attribute footTargetY : LengthValue;
        attribute footTargetZ : LengthValue;
        attribute stanceForceTarget : ForceMagnitude;
    }

    item def JointCommand {
        attribute targetAngle : JointAngle;
        attribute targetVelocity : AngularRate;
        attribute feedForwardTorque : JointTorque;
    }

    item def JointState {
        attribute measuredAngle : JointAngle;
        attribute measuredVelocity : AngularRate;
        attribute measuredTorque : JointTorque;
        attribute motorCurrent : MotorCurrent;
    }

    item def FootContactState {
        attribute legId : LegId;
        attribute contactDetected : Boolean;
        attribute normalForce : ForceMagnitude;
        attribute slipDetected : Boolean;
    }

    item def BodyPoseEstimate {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
        attribute roll : JointAngle;
        attribute pitch : JointAngle;
        attribute yaw : JointAngle;
        attribute forwardSpeed : LinearSpeed;
        attribute yawRate : AngularRate;
    }

    item def TerrainEstimate {
        attribute slopeRoll : TerrainSlope;
        attribute slopePitch : TerrainSlope;
        attribute stepHeightAhead : LengthValue;
        attribute groundFirmness : Real;
    }

    item def HealthStatus {
        attribute batterySoc : BatteryStateOfCharge;
        attribute controllerTemperature : Real;
        attribute actuatorFaultPresent : Boolean;
        attribute sensorFaultPresent : Boolean;
        attribute safeToWalk : Boolean;
    }

    enum def GaitModeKind {
        enum idle;
        enum tripod;
        enum wave;
        enum turnInPlace;
        enum recovery;
    }

    enum def SupportPhaseKind {
        enum swing;
        enum stance;
    }

    enum def RobotModeKind {
        enum poweredOff;
        enum initializing;
        enum standing;
        enum walking;
        enum recovering;
        enum faulted;
        enum shuttingDown;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def PowerOutputPort {
        out item power : ElectricalPower;
    }

    port def CommandInputPort {
        in item command : MotionCommand;
    }

    port def TrajectoryOutputPort {
        out item trajectory : LegTrajectoryCommand;
    }

    port def TrajectoryInputPort {
        in item trajectory : LegTrajectoryCommand;
    }

    port def JointCommandPort {
        out item command : JointCommand;
    }

    port def JointFeedbackPort {
        in item state : JointState;
    }

    port def FootContactPort {
        out item contact : FootContactState;
    }

    port def PoseEstimatePort {
        out item pose : BodyPoseEstimate;
    }

    port def TerrainEstimatePort {
        out item terrain : TerrainEstimate;
    }

    port def HealthStatusPort {
        out item health : HealthStatus;
    }

    part def BatteryPack {
        attribute nominalVoltage : Real = 48.0;
        attribute capacityAh : Real = 18.0;
        attribute stateOfCharge : BatteryStateOfCharge;
        port powerOut : PowerOutputPort;
    }

    part def PowerDistributionUnit {
        port batteryPowerIn : PowerInputPort;
        port controllerPowerOut : PowerOutputPort;
        port actuatorPowerOut : PowerOutputPort;
        attribute busVoltage : Real = 48.0;
        attribute maxContinuousPower : Real = 1200.0;
    }

    part def InertialMeasurementUnit {
        port poseOut : PoseEstimatePort;
        attribute updateRateHz : Real = 400.0;
        attribute gyroBiasYaw : AngularRate;
    }

    part def FootContactSensor {
        attribute legId : LegId;
        port contactOut : FootContactPort;
        attribute minimumDetectableForce : ForceMagnitude = 2.0;
    }

    part def TerrainPerceptionSensor {
        port terrainOut : TerrainEstimatePort;
        attribute maximumStepDetectionHeight : LengthValue = 0.15;
        attribute perceptionRange : LengthValue = 1.5;
    }

    part def JointActuator {
        attribute jointName : String;
        attribute maximumTorque : JointTorque = 28.0;
        attribute maximumSpeed : AngularRate = 8.0;
        port powerIn : PowerInputPort;
        port commandIn : JointCommandPort;
        port feedbackOut : JointFeedbackPort;
    }

    part def ThreeDegreeLeg {
        attribute legId : LegId;
        attribute supportPhase : SupportPhaseKind;
        attribute footWorkspaceRadius : LengthValue = 0.32;
        attribute nominalStepLength : LengthValue = 0.18;

        port trajectoryIn : TrajectoryInputPort;
        port contactOut : FootContactPort;
        port powerIn : PowerInputPort;

        part hipYaw : JointActuator {
            jointName = "hipYaw";
            maximumTorque = 18.0;
        }

        part hipPitch : JointActuator {
            jointName = "hipPitch";
            maximumTorque = 28.0;
        }

        part kneePitch : JointActuator {
            jointName = "kneePitch";
            maximumTorque = 28.0;
        }

        part footSensor : FootContactSensor;

        connect powerIn.power to hipYaw.powerIn.power;
        connect powerIn.power to hipPitch.powerIn.power;
        connect powerIn.power to kneePitch.powerIn.power;
        connect footSensor.contactOut.contact to contactOut.contact;
    }

    part def Chassis {
        attribute bodyLength : LengthValue = 0.72;
        attribute bodyWidth : LengthValue = 0.38;
        attribute bodyMass : MassValue = 12.5;
        attribute payloadCapacity : MassValue = 4.0;
    }

    part def GaitController {
        port commandIn : CommandInputPort;
        port poseIn : PoseEstimatePort;
        port terrainIn : TerrainEstimatePort;
        port healthIn : HealthStatusPort;

        port frontLeftTrajectoryOut : TrajectoryOutputPort;
        port middleLeftTrajectoryOut : TrajectoryOutputPort;
        port rearLeftTrajectoryOut : TrajectoryOutputPort;
        port frontRightTrajectoryOut : TrajectoryOutputPort;
        port middleRightTrajectoryOut : TrajectoryOutputPort;
        port rearRightTrajectoryOut : TrajectoryOutputPort;

        attribute activeGait : GaitModeKind = GaitModeKind::idle;
        attribute dutyFactor : Real = 0.5;
        attribute gaitCycleTime : TimeValue = 0.8;
        attribute commandedSpeed : LinearSpeed;
        attribute stabilityMargin : StabilityMargin;
    }

    part def BalanceController {
        port poseIn : PoseEstimatePort;
        port terrainIn : TerrainEstimatePort;
        attribute targetBodyHeight : LengthValue = 0.28;
        attribute maximumAllowedRoll : JointAngle = 0.35;
        attribute maximumAllowedPitch : JointAngle = 0.35;
        attribute computedStabilityMargin : StabilityMargin;
    }

    part def HealthMonitor {
        port healthOut : HealthStatusPort;
        attribute minimumWalkingSoc : BatteryStateOfCharge = 0.15;
        attribute maximumControllerTemperature : Real = 80.0;
        attribute faultLatched : Boolean = false;
    }

    part def HexapodRobot {
        attribute primaryFunction : String = "Transport itself and a small payload over uneven ground by coordinating six articulated legs to maintain stable body motion.";
        attribute operatingMode : RobotModeKind = RobotModeKind::poweredOff;
        attribute nominalMass : MassValue = 18.0;
        attribute maximumForwardSpeed : LinearSpeed = 1.2;
        attribute minimumStaticStabilityMargin : StabilityMargin = 0.04;

        port operatorCommandIn : CommandInputPort;

        part chassis : Chassis;
        part battery : BatteryPack;
        part powerDistribution : PowerDistributionUnit;
        part imu : InertialMeasurementUnit;
        part terrainSensor : TerrainPerceptionSensor;
        part gaitController : GaitController;
        part balanceController : BalanceController;
        part healthMonitor : HealthMonitor;

        part frontLeftLeg : ThreeDegreeLeg {
            legId = 1;
            footSensor.legId = 1;
        }

        part middleLeftLeg : ThreeDegreeLeg {
            legId = 2;
            footSensor.legId = 2;
        }

        part rearLeftLeg : ThreeDegreeLeg {
            legId = 3;
            footSensor.legId = 3;
        }

        part frontRightLeg : ThreeDegreeLeg {
            legId = 4;
            footSensor.legId = 4;
        }

        part middleRightLeg : ThreeDegreeLeg {
            legId = 5;
            footSensor.legId = 5;
        }

        part rearRightLeg : ThreeDegreeLeg {
            legId = 6;
            footSensor.legId = 6;
        }

        connect battery.powerOut.power to powerDistribution.batteryPowerIn.power;
        connect powerDistribution.actuatorPowerOut.power to frontLeftLeg.powerIn.power;
        connect powerDistribution.actuatorPowerOut.power to middleLeftLeg.powerIn.power;
        connect powerDistribution.actuatorPowerOut.power to rearLeftLeg.powerIn.power;
        connect powerDistribution.actuatorPowerOut.power to frontRightLeg.powerIn.power;
        connect powerDistribution.actuatorPowerOut.power to middleRightLeg.powerIn.power;
        connect powerDistribution.actuatorPowerOut.power to rearRightLeg.powerIn.power;

        connect operatorCommandIn.command to gaitController.commandIn.command;
        connect imu.poseOut.pose to gaitController.poseIn.pose;
        connect imu.poseOut.pose to balanceController.poseIn.pose;
        connect terrainSensor.terrainOut.terrain to gaitController.terrainIn.terrain;
        connect terrainSensor.terrainOut.terrain to balanceController.terrainIn.terrain;
        connect healthMonitor.healthOut.health to gaitController.healthIn.health;

        connect gaitController.frontLeftTrajectoryOut.trajectory to frontLeftLeg.trajectoryIn.trajectory;
        connect gaitController.middleLeftTrajectoryOut.trajectory to middleLeftLeg.trajectoryIn.trajectory;
        connect gaitController.rearLeftTrajectoryOut.trajectory to rearLeftLeg.trajectoryIn.trajectory;
        connect gaitController.frontRightTrajectoryOut.trajectory to frontRightLeg.trajectoryIn.trajectory;
        connect gaitController.middleRightTrajectoryOut.trajectory to middleRightLeg.trajectoryIn.trajectory;
        connect gaitController.rearRightTrajectoryOut.trajectory to rearRightLeg.trajectoryIn.trajectory;
    }

    action def CoordinateSixLegWalking {
        in item command : MotionCommand;
        in item pose : BodyPoseEstimate;
        in item terrain : TerrainEstimate;
        in item health : HealthStatus;
        out item frontLeftTrajectory : LegTrajectoryCommand;
        out item middleLeftTrajectory : LegTrajectoryCommand;
        out item rearLeftTrajectory : LegTrajectoryCommand;
        out item frontRightTrajectory : LegTrajectoryCommand;
        out item middleRightTrajectory : LegTrajectoryCommand;
        out item rearRightTrajectory : LegTrajectoryCommand;

        attribute selectedGait : GaitModeKind;
        attribute requiredStabilityMargin : StabilityMargin = 0.04;
    }

    action def MaintainBodyStability {
        in item pose : BodyPoseEstimate;
        in item terrain : TerrainEstimate;
        out item correctedBodyPose : BodyPoseEstimate;

        attribute rollError : JointAngle;
        attribute pitchError : JointAngle;
        attribute correctionLimit : JointAngle = 0.25;
    }

    action def ExecuteLegTrajectory {
        in item trajectory : LegTrajectoryCommand;
        out item hipYawCommand : JointCommand;
        out item hipPitchCommand : JointCommand;
        out item kneePitchCommand : JointCommand;

        attribute inverseKinematicsValid : Boolean;
    }

    state def HexapodOperatingStateMachine {
        entry action initializePower;
        state poweredOff;
        state initializing;
        state standing;
        state walking;
        state recovering;
        state faulted;
        state shuttingDown;

        transition first poweredOff;
        transition poweredOff_to_initializing
            first poweredOff
            then initializing;

        transition initializing_to_standing
            first initializing
            then standing;

        transition standing_to_walking
            first standing
            then walking;

        transition walking_to_standing
            first walking
            then standing;

        transition walking_to_recovering
            first walking
            then recovering;

        transition recovering_to_standing
            first recovering
            then standing;

        transition any_to_faulted
            first standing
            then faulted;

        transition faulted_to_shuttingDown
            first faulted
            then shuttingDown;

        transition shuttingDown_to_poweredOff
            first shuttingDown
            then poweredOff;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The hexapod shall provide stable legged mobility over uneven terrain while transporting its body and supported payload under operator command. */
        subject robot : HexapodRobot;
        require constraint {
            robot.maximumForwardSpeed >= 1.0
        }
    }

    requirement def SixLegArchitectureRequirement {
        doc /* The hexapod shall include six independently actuated legs, each with three powered joints and foot contact sensing. */
        subject robot : HexapodRobot;
        require constraint {
            robot.frontLeftLeg.legId == 1 and
            robot.middleLeftLeg.legId == 2 and
            robot.rearLeftLeg.legId == 3 and
            robot.frontRightLeg.legId == 4 and
            robot.middleRightLeg.legId == 5 and
            robot.rearRightLeg.legId == 6
        }
    }

    requirement def StabilityRequirement {
        doc /* The control system shall maintain a positive stability margin during walking when no actuator or sensor fault is present. */
        subject robot : HexapodRobot;
        require constraint {
            robot.gaitController.stabilityMargin >= robot.minimumStaticStabilityMargin
        }
    }

    requirement def PayloadMobilityRequirement {
        doc /* The chassis shall support a useful payload while preserving controlled walking capability. */
        subject robot : HexapodRobot;
        require constraint {
            robot.chassis.payloadCapacity >= 3.0
        }
    }

    requirement def EnergyAvailabilityRequirement {
        doc /* The robot shall inhibit walking when battery state of charge is below the minimum walking threshold. */
        subject robot : HexapodRobot;
        require constraint {
            robot.healthMonitor.minimumWalkingSoc >= 0.10
        }
    }

    satisfy PrimaryFunctionRequirement by HexapodRobot;
    satisfy SixLegArchitectureRequirement by HexapodRobot;
    satisfy StabilityRequirement by GaitController;
    satisfy PayloadMobilityRequirement by Chassis;
    satisfy EnergyAvailabilityRequirement by HealthMonitor;

    part hexapodSystem : HexapodRobot;

}