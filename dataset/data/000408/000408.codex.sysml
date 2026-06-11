package JugglingRobotSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value def MassValue :> ISQ::mass {
        unit = SI::kg;
    }

    value def LengthValue :> ISQ::length {
        unit = SI::m;
    }

    value def TimeValue :> ISQ::time {
        unit = SI::s;
    }

    value def VelocityValue :> ISQ::speed {
        unit = SI::m / SI::s;
    }

    value def AccelerationValue :> ISQ::acceleration {
        unit = SI::m / SI::s^2;
    }

    value def AngleValue :> ISQ::planeAngle {
        unit = SI::rad;
    }

    value def AngularVelocityValue :> ISQ::angularVelocity {
        unit = SI::rad / SI::s;
    }

    value def ForceValue :> ISQ::force {
        unit = SI::N;
    }

    value def TorqueValue :> ISQ::torque {
        unit = SI::N * SI::m;
    }

    value def PowerValue :> ISQ::power {
        unit = SI::W;
    }

    value def EnergyValue :> ISQ::energy {
        unit = SI::J;
    }

    value def FrequencyValue :> ISQ::frequency {
        unit = SI::Hz;
    }

    value def ProbabilityValue :> ScalarValues::Real {
        range = "0.0..1.0";
    }

    value def PercentValue :> ScalarValues::Real {
        range = "0.0..100.0";
    }

    value def CountValue :> ScalarValues::Integer;

    value def Position3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }

    value def Velocity3D {
        attribute vx : VelocityValue;
        attribute vy : VelocityValue;
        attribute vz : VelocityValue;
    }

    value def Acceleration3D {
        attribute ax : AccelerationValue;
        attribute ay : AccelerationValue;
        attribute az : AccelerationValue;
    }

    value def Pose3D {
        attribute position : Position3D;
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }

    value def BallTrajectory {
        attribute initialPosition : Position3D;
        attribute initialVelocity : Velocity3D;
        attribute catchPosition : Position3D;
        attribute flightTime : TimeValue;
        attribute apexHeight : LengthValue;
        attribute predictedLandingTime : TimeValue;
    }

    value def JointState {
        attribute angle : AngleValue;
        attribute angularVelocity : AngularVelocityValue;
        attribute torque : TorqueValue;
    }

    value def ArmCommand {
        attribute shoulder : JointState;
        attribute elbow : JointState;
        attribute wrist : JointState;
        attribute gripperOpenPercent : PercentValue;
        attribute executionTime : TimeValue;
    }

    value def JugglingPattern {
        attribute numberOfBalls : CountValue;
        attribute siteswapPeriod : CountValue;
        attribute throwHeight : LengthValue;
        attribute beatFrequency : FrequencyValue;
        attribute dwellTime : TimeValue;
        attribute handCrossingEnabled : Boolean;
    }

    value def HealthStatus {
        attribute batteryPercent : PercentValue;
        attribute cpuLoadPercent : PercentValue;
        attribute motorTemperatureMax : ScalarValues::Real;
        attribute visionFrameRate : FrequencyValue;
        attribute trackingConfidence : ProbabilityValue;
        attribute emergencyStopActive : Boolean;
    }

    item def JugglingBall {
        attribute mass : MassValue = 0.120 [SI::kg];
        attribute diameter : LengthValue = 0.067 [SI::m];
        attribute surfaceFrictionCoefficient : ScalarValues::Real = 0.62;
        attribute colorId : ScalarValues::String;
        attribute pose : Pose3D;
        attribute velocity : Velocity3D;
    }

    item def ImageFrame {
        attribute timestamp : TimeValue;
        attribute widthPixels : CountValue = 1920;
        attribute heightPixels : CountValue = 1080;
        attribute frameRate : FrequencyValue = 120 [SI::Hz];
    }

    item def TrajectoryEstimate {
        attribute ballId : CountValue;
        attribute trajectory : BallTrajectory;
        attribute confidence : ProbabilityValue;
    }

    item def MotionPlan {
        attribute leftArmCommand : ArmCommand;
        attribute rightArmCommand : ArmCommand;
        attribute validUntil : TimeValue;
        attribute expectedCatchMargin : TimeValue;
    }

    item def PowerFlow {
        attribute voltage : ScalarValues::Real;
        attribute current : ScalarValues::Real;
        attribute power : PowerValue;
    }

    item def ControlSignal {
        attribute cycleTime : TimeValue;
        attribute sequenceNumber : CountValue;
    }

    port def CameraDataPort {
        out item frame : ImageFrame;
    }

    port def TrajectoryPort {
        out item estimate : TrajectoryEstimate;
    }

    port def MotionPlanPort {
        out item plan : MotionPlan;
    }

    port def ArmCommandPort {
        in item command : ArmCommand;
    }

    port def BallTransferPort {
        inout item ball : JugglingBall;
    }

    port def PowerPort {
        inout item power : PowerFlow;
    }

    port def HealthPort {
        out item status : HealthStatus;
    }

    port def ControlPort {
        inout item signal : ControlSignal;
    }

    action def CaptureStereoImages {
        out item leftFrame : ImageFrame;
        out item rightFrame : ImageFrame;
    }

    action def DetectBalls {
        in item leftFrame : ImageFrame;
        in item rightFrame : ImageFrame;
        out item trackedBall1 : TrajectoryEstimate;
        out item trackedBall2 : TrajectoryEstimate;
        out item trackedBall3 : TrajectoryEstimate;
    }

    action def PredictBallTrajectories {
        in item trackedBall1 : TrajectoryEstimate;
        in item trackedBall2 : TrajectoryEstimate;
        in item trackedBall3 : TrajectoryEstimate;
        out item predictedBall1 : TrajectoryEstimate;
        out item predictedBall2 : TrajectoryEstimate;
        out item predictedBall3 : TrajectoryEstimate;
    }

    action def SelectNextCatchAndThrow {
        in attribute pattern : JugglingPattern;
        in item predictedBall1 : TrajectoryEstimate;
        in item predictedBall2 : TrajectoryEstimate;
        in item predictedBall3 : TrajectoryEstimate;
        out item selectedPlan : MotionPlan;
    }

    action def ExecuteArmMotion {
        in item selectedPlan : MotionPlan;
        out item releasedBall : JugglingBall;
    }

    action def StabilizeBase {
        in item selectedPlan : MotionPlan;
        out attribute baseCorrection : Acceleration3D;
    }

    action def MonitorSafety {
        in item health : HealthStatus;
        out attribute continueOperation : Boolean;
    }

    action def PerformJugglingCycle {
        in attribute desiredPattern : JugglingPattern;
        out item cycleHealth : HealthStatus;

        action capture : CaptureStereoImages;
        action detect : DetectBalls;
        action predict : PredictBallTrajectories;
        action select : SelectNextCatchAndThrow;
        action stabilize : StabilizeBase;
        action execute : ExecuteArmMotion;
        action monitor : MonitorSafety;

        flow capture.leftFrame to detect.leftFrame;
        flow capture.rightFrame to detect.rightFrame;
        flow detect.trackedBall1 to predict.trackedBall1;
        flow detect.trackedBall2 to predict.trackedBall2;
        flow detect.trackedBall3 to predict.trackedBall3;
        flow desiredPattern to select.pattern;
        flow predict.predictedBall1 to select.predictedBall1;
        flow predict.predictedBall2 to select.predictedBall2;
        flow predict.predictedBall3 to select.predictedBall3;
        flow select.selectedPlan to stabilize.selectedPlan;
        flow select.selectedPlan to execute.selectedPlan;
    }

    part def StereoVisionSubsystem {
        attribute baseline : LengthValue = 0.280 [SI::m];
        attribute frameRate : FrequencyValue = 120 [SI::Hz];
        attribute detectionLatency : TimeValue = 0.008 [SI::s];
        attribute horizontalFieldOfView : AngleValue = 1.396 [SI::rad];
        attribute verticalFieldOfView : AngleValue = 0.873 [SI::rad];

        port leftCamera : CameraDataPort;
        port rightCamera : CameraDataPort;
        port trajectoryOut : TrajectoryPort;
        port power : PowerPort;
        port health : HealthPort;

        perform action captureImages : CaptureStereoImages;
        perform action detectBalls : DetectBalls;
        perform action predictTrajectories : PredictBallTrajectories;
    }

    part def MotionPlanningComputer {
        attribute controlRate : FrequencyValue = 500 [SI::Hz];
        attribute maximumPlanningLatency : TimeValue = 0.004 [SI::s];
        attribute catchTimeTolerance : TimeValue = 0.015 [SI::s];
        attribute throwVelocityTolerance : VelocityValue = 0.080 [SI::m / SI::s];

        port trajectoryIn : TrajectoryPort;
        port motionPlanOut : MotionPlanPort;
        port health : HealthPort;
        port power : PowerPort;

        perform action selectNextCatchAndThrow : SelectNextCatchAndThrow;
    }

    part def RobotArm {
        attribute armSide : ScalarValues::String;
        attribute link1Length : LengthValue = 0.320 [SI::m];
        attribute link2Length : LengthValue = 0.280 [SI::m];
        attribute wristToPalmLength : LengthValue = 0.115 [SI::m];
        attribute maximumReach : LengthValue = 0.715 [SI::m];
        attribute maximumJointTorque : TorqueValue = 18.0 [SI::N * SI::m];
        attribute maximumTipSpeed : VelocityValue = 4.5 [SI::m / SI::s];
        attribute positioningAccuracy : LengthValue = 0.006 [SI::m];

        port commandIn : ArmCommandPort;
        port ballPort : BallTransferPort;
        port power : PowerPort;
        port health : HealthPort;
        port control : ControlPort;

        part shoulderActuator {
            attribute ratedTorque : TorqueValue = 18.0 [SI::N * SI::m];
            attribute peakAngularVelocity : AngularVelocityValue = 12.0 [SI::rad / SI::s];
            attribute jointState : JointState;
        }

        part elbowActuator {
            attribute ratedTorque : TorqueValue = 14.0 [SI::N * SI::m];
            attribute peakAngularVelocity : AngularVelocityValue = 14.0 [SI::rad / SI::s];
            attribute jointState : JointState;
        }

        part wristActuator {
            attribute ratedTorque : TorqueValue = 6.0 [SI::N * SI::m];
            attribute peakAngularVelocity : AngularVelocityValue = 22.0 [SI::rad / SI::s];
            attribute jointState : JointState;
        }

        part softCatchingPaddle {
            attribute padDiameter : LengthValue = 0.135 [SI::m];
            attribute padCompliance : ScalarValues::Real = 0.78;
            attribute maximumCatchImpulse : ScalarValues::Real = 2.8;
            port ballContact : BallTransferPort;
        }

        perform action executeMotion : ExecuteArmMotion;
    }

    part def DualArmJugglingMechanism {
        attribute armSeparation : LengthValue = 0.420 [SI::m];
        attribute nominalThrowHeight : LengthValue = 1.100 [SI::m];
        attribute nominalBeatFrequency : FrequencyValue = 2.4 [SI::Hz];
        attribute maximumBallsSupported : CountValue = 5;

        port leftCommand : ArmCommandPort;
        port rightCommand : ArmCommandPort;
        port ballExchange : BallTransferPort;
        port power : PowerPort;
        port health : HealthPort;
        port control : ControlPort;

        part leftArm : RobotArm {
            attribute armSide = "left";
        }

        part rightArm : RobotArm {
            attribute armSide = "right";
        }

        connect leftCommand to leftArm.commandIn;
        connect rightCommand to rightArm.commandIn;
        connect ballExchange to leftArm.ballPort;
        connect ballExchange to rightArm.ballPort;
        connect power to leftArm.power;
        connect power to rightArm.power;
        connect control to leftArm.control;
        connect control to rightArm.control;
    }

    part def BallMagazine {
        attribute capacity : CountValue = 6;
        attribute loadedBallCount : CountValue = 3;
        attribute releaseHeight : LengthValue = 0.850 [SI::m];

        port ballOut : BallTransferPort;
        port power : PowerPort;

        part ball1 : JugglingBall {
            attribute colorId = "red";
        }

        part ball2 : JugglingBall {
            attribute colorId = "green";
        }

        part ball3 : JugglingBall {
            attribute colorId = "blue";
        }
    }

    part def MobileStabilizedBase {
        attribute baseMass : MassValue = 38.0 [SI::kg];
        attribute footprintLength : LengthValue = 0.820 [SI::m];
        attribute footprintWidth : LengthValue = 0.620 [SI::m];
        attribute maximumBaseAcceleration : AccelerationValue = 1.5 [SI::m / SI::s^2];
        attribute levelingAccuracy : AngleValue = 0.010 [SI::rad];

        port power : PowerPort;
        port control : ControlPort;
        port health : HealthPort;

        part inertialMeasurementUnit {
            attribute updateRate : FrequencyValue = 1000 [SI::Hz];
            attribute angularNoise : AngularVelocityValue = 0.002 [SI::rad / SI::s];
        }

        part reactionWheelAssembly {
            attribute maximumCorrectionTorque : TorqueValue = 9.0 [SI::N * SI::m];
            attribute maximumStoredEnergy : EnergyValue = 800 [SI::J];
        }

        perform action stabilizeBase : StabilizeBase;
    }

    part def PowerSubsystem {
        attribute batteryEnergy : EnergyValue = 720000 [SI::J];
        attribute nominalVoltage : ScalarValues::Real = 48.0;
        attribute maximumContinuousPower : PowerValue = 950 [SI::W];
        attribute reserveEnergy : EnergyValue = 90000 [SI::J];

        port powerBus : PowerPort;
        port health : HealthPort;

        part batteryPack {
            attribute mass : MassValue = 4.8 [SI::kg];
            attribute capacityEnergy : EnergyValue = 720000 [SI::J];
            attribute stateOfCharge : PercentValue = 100.0;
        }

        part powerDistributionUnit {
            attribute overloadTripPower : PowerValue = 1200 [SI::W];
            attribute conversionEfficiency : PercentValue = 94.0;
        }
    }

    part def SafetySubsystem {
        attribute minimumHumanDistance : LengthValue = 1.500 [SI::m];
        attribute maximumPermittedBallSpeed : VelocityValue = 7.0 [SI::m / SI::s];
        attribute emergencyStopLatency : TimeValue = 0.030 [SI::s];
        attribute protectiveStopActive : Boolean = false;

        port healthIn : HealthPort;
        port controlOut : ControlPort;
        port power : PowerPort;

        perform action monitorSafety : MonitorSafety;
    }

    part def OperatorInterface {
        attribute selectedMode : ScalarValues::String = "threeBallCascade";
        attribute commandedBallCount : CountValue = 3;
        attribute startButtonPressed : Boolean = false;
        attribute stopButtonPressed : Boolean = false;

        port control : ControlPort;
        port healthIn : HealthPort;
        port power : PowerPort;
    }

    part def JugglingRobot {
        attribute name : ScalarValues::String = "JR-3 Cascade Juggling Robot";
        attribute totalMass : MassValue = 64.0 [SI::kg];
        attribute primaryPattern : JugglingPattern;
        attribute sustainedJugglingDuration : TimeValue = 300 [SI::s];
        attribute nominalCatchProbability : ProbabilityValue = 0.995;

        port externalPower : PowerPort;
        port operatorControl : ControlPort;
        port healthOut : HealthPort;

        part vision : StereoVisionSubsystem;
        part planner : MotionPlanningComputer;
        part jugglingMechanism : DualArmJugglingMechanism;
        part ballMagazine : BallMagazine;
        part stabilizedBase : MobileStabilizedBase;
        part powerSubsystem : PowerSubsystem;
        part safetySubsystem : SafetySubsystem;
        part operatorInterface : OperatorInterface;

        connect externalPower to powerSubsystem.powerBus;
        connect powerSubsystem.powerBus to vision.power;
        connect powerSubsystem.powerBus to planner.power;
        connect powerSubsystem.powerBus to jugglingMechanism.power;
        connect powerSubsystem.powerBus to ballMagazine.power;
        connect powerSubsystem.powerBus to stabilizedBase.power;
        connect powerSubsystem.powerBus to safetySubsystem.power;
        connect powerSubsystem.powerBus to operatorInterface.power;

        connect vision.trajectoryOut to planner.trajectoryIn;
        connect planner.motionPlanOut to jugglingMechanism.leftCommand;
        connect planner.motionPlanOut to jugglingMechanism.rightCommand;
        connect ballMagazine.ballOut to jugglingMechanism.ballExchange;

        connect operatorControl to operatorInterface.control;
        connect operatorInterface.control to safetySubsystem.controlOut;
        connect safetySubsystem.controlOut to jugglingMechanism.control;
        connect safetySubsystem.controlOut to stabilizedBase.control;

        connect vision.health to healthOut;
        connect planner.health to healthOut;
        connect jugglingMechanism.health to healthOut;
        connect stabilizedBase.health to healthOut;
        connect powerSubsystem.health to healthOut;
        connect safetySubsystem.healthIn to healthOut;

        perform action jugglingCycle : PerformJugglingCycle;
    }

    part def JugglingRobotSystem {
        attribute systemName : ScalarValues::String = "Autonomous Robotic Juggling Demonstrator";
        attribute operationalEnvironment : ScalarValues::String = "indoor laboratory or public demonstration stage";
        attribute allowedAmbientIlluminationMin : ScalarValues::Real = 300.0;
        attribute allowedAmbientIlluminationMax : ScalarValues::Real = 5000.0;

        part robot : JugglingRobot;

        part operatingZone {
            attribute length : LengthValue = 4.0 [SI::m];
            attribute width : LengthValue = 4.0 [SI::m];
            attribute ceilingHeight : LengthValue = 3.0 [SI::m];
            attribute restrictedHumanRadius : LengthValue = 1.5 [SI::m];
        }

        part threeBallCascadePattern {
            attribute numberOfBalls : CountValue = 3;
            attribute siteswapPeriod : CountValue = 2;
            attribute throwHeight : LengthValue = 1.10 [SI::m];
            attribute beatFrequency : FrequencyValue = 2.4 [SI::Hz];
            attribute dwellTime : TimeValue = 0.140 [SI::s];
            attribute handCrossingEnabled : Boolean = false;
        }
    }

    state def JugglingOperationalStateMachine {
        entry action initializeControllers;
        exit action logSessionSummary;

        state Off;
        state Booting;
        state CalibratingVision;
        state LoadingBalls;
        state Ready;
        state Juggling;
        state Recovering;
        state ProtectiveStop;
        state Shutdown;

        transition first Off then Booting
            accept PowerOn;

        transition Booting then CalibratingVision
            accept BootComplete;

        transition CalibratingVision then LoadingBalls
            accept CalibrationValid;

        transition LoadingBalls then Ready
            accept BallsLoaded
            if loadedBallCount >= 3;

        transition Ready then Juggling
            accept StartJuggling;

        transition Juggling then Recovering
            accept BallTrackingLost
            if trackingConfidence < 0.85;

        transition Recovering then Juggling
            accept TrajectoryRecovered
            if trackingConfidence >= 0.95;

        transition Juggling then Ready
            accept PatternComplete;

        transition Ready then Shutdown
            accept OperatorShutdown;

        transition Booting then ProtectiveStop
            accept FaultDetected;

        transition CalibratingVision then ProtectiveStop
            accept FaultDetected;

        transition LoadingBalls then ProtectiveStop
            accept FaultDetected;

        transition Ready then ProtectiveStop
            accept FaultDetected;

        transition Juggling then ProtectiveStop
            accept EmergencyStop;

        transition Recovering then ProtectiveStop
            accept EmergencyStop;

        transition ProtectiveStop then Shutdown
            accept ResetAndPowerDown;
    }

    requirement def PrimaryJugglingTaskRequirement {
        subject robot : JugglingRobot;
        require constraint {
            robot.primaryPattern.numberOfBalls >= 3 and
            robot.sustainedJugglingDuration >= 300 [SI::s]
        }
    }

    requirement def CatchReliabilityRequirement {
        subject robot : JugglingRobot;
        require constraint {
            robot.nominalCatchProbability >= 0.995
        }
    }

    requirement def ThrowHeightRequirement {
        subject mechanism : DualArmJugglingMechanism;
        require constraint {
            mechanism.nominalThrowHeight >= 0.90 [SI::m] and
            mechanism.nominalThrowHeight <= 1.30 [SI::m]
        }
    }

    requirement def VisionLatencyRequirement {
        subject vision : StereoVisionSubsystem;
        require constraint {
            vision.detectionLatency <= 0.010 [SI::s] and
            vision.frameRate >= 100 [SI::Hz]
        }
    }

    requirement def PlanningLatencyRequirement {
        subject planner : MotionPlanningComputer;
        require constraint {
            planner.maximumPlanningLatency <= 0.005 [SI::s] and
            planner.controlRate >= 400 [SI::Hz]
        }
    }

    requirement def ArmReachRequirement {
        subject arm : RobotArm;
        require constraint {
            arm.maximumReach >= 0.650 [SI::m] and
            arm.positioningAccuracy <= 0.010 [SI::m]
        }
    }

    requirement def SafetyDistanceRequirement {
        subject safety : SafetySubsystem;
        require constraint {
            safety.minimumHumanDistance >= 1.500 [SI::m] and
            safety.emergencyStopLatency <= 0.050 [SI::s]
        }
    }

    requirement def BallSpeedSafetyRequirement {
        subject safety : SafetySubsystem;
        require constraint {
            safety.maximumPermittedBallSpeed <= 7.0 [SI::m / SI::s]
        }
    }

    requirement def PowerEnduranceRequirement {
        subject power : PowerSubsystem;
        require constraint {
            power.batteryEnergy >= 600000 [SI::J] and
            power.maximumContinuousPower >= 800 [SI::W]
        }
    }

    requirement def BaseStabilityRequirement {
        subject base : MobileStabilizedBase;
        require constraint {
            base.levelingAccuracy <= 0.015 [SI::rad] and
            base.maximumBaseAcceleration >= 1.0 [SI::m / SI::s^2]
        }
    }

    satisfy PrimaryJugglingTaskRequirement by JugglingRobotSystem::robot;
    satisfy CatchReliabilityRequirement by JugglingRobotSystem::robot;
    satisfy ThrowHeightRequirement by JugglingRobotSystem::robot::jugglingMechanism;
    satisfy VisionLatencyRequirement by JugglingRobotSystem::robot::vision;
    satisfy PlanningLatencyRequirement by JugglingRobotSystem::robot::planner;
    satisfy SafetyDistanceRequirement by JugglingRobotSystem::robot::safetySubsystem;
    satisfy PowerEnduranceRequirement by JugglingRobotSystem::robot::powerSubsystem;
    satisfy BaseStabilityRequirement by JugglingRobotSystem::robot::stabilizedBase;

}