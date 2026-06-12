package RoboticsOutlineModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent :> Real;
    attribute def ConfidenceScore :> Real;
    attribute def MapResolution :> Real;
    attribute def DataRate :> Real;
    attribute def Torque :> Real;
    attribute def AngularVelocity :> Real;
    attribute def LinearVelocity :> Real;
    attribute def ElectricCharge :> Real;

    item def ImageFrame {
        attribute width : Integer;
        attribute height : Integer;
        attribute frameRate : Frequency;
        attribute timestamp : Time;
    }

    item def PointCloud {
        attribute pointCount : Integer;
        attribute range : Length;
        attribute timestamp : Time;
    }

    item def RobotPose {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
        attribute roll : PlaneAngle;
        attribute pitch : PlaneAngle;
        attribute yaw : PlaneAngle;
        attribute covariance : Real[6, 6];
    }

    item def MotionCommand {
        attribute targetLinearSpeed : LinearVelocity;
        attribute targetAngularSpeed : AngularVelocity;
        attribute maxAcceleration : Acceleration;
        attribute priority : Integer;
    }

    item def ManipulationCommand {
        attribute targetPose : RobotPose;
        attribute gripperOpening : Length;
        attribute gripForce : Force;
    }

    item def DiagnosticReport {
        attribute batteryStateOfCharge : Percent;
        attribute localizationConfidence : ConfidenceScore;
        attribute actuatorTemperatureMax : Temperature;
        attribute faultCode : Integer;
        attribute safeToOperate : Boolean;
    }

    item def OccupancyGridMap {
        attribute width : Length;
        attribute height : Length;
        attribute resolution : MapResolution;
        attribute occupiedCellCount : Integer;
        attribute timestamp : Time;
    }

    port def PowerPort {
        out item power : Power;
    }

    port def CommandPort {
        in item motionCommand : MotionCommand;
        in item manipulationCommand : ManipulationCommand;
    }

    port def TelemetryPort {
        out item pose : RobotPose;
        out item diagnostics : DiagnosticReport;
        out item localMap : OccupancyGridMap;
    }

    port def VisionPort {
        out item frame : ImageFrame;
    }

    port def DepthPort {
        out item cloud : PointCloud;
    }

    port def PosePort {
        out item pose : RobotPose;
    }

    port def MotorControlPort {
        in item command : MotionCommand;
        out item actualPose : RobotPose;
    }

    port def ManipulatorControlPort {
        in item command : ManipulationCommand;
        out item actualEndEffectorPose : RobotPose;
    }

    part def BatteryPack {
        attribute nominalVoltage : ElectricPotential = 48 [V];
        attribute capacity : ElectricCharge = 40 [A*h];
        attribute maxContinuousPower : Power = 1800 [W];
        attribute stateOfCharge : Percent;
        attribute temperature : Temperature;

        port powerOut : PowerPort;

        state def BatteryState {
            entry; then Idle;

            state Idle;
            state Discharging;
            state LowEnergy;
            state Faulted;

            transition Idle_to_Discharging
                first Idle
                accept when stateOfCharge > 20.0
                then Discharging;

            transition Discharging_to_LowEnergy
                first Discharging
                accept when stateOfCharge <= 20.0
                then LowEnergy;

            transition Any_to_Faulted
                first Discharging
                accept when temperature > 60 [degC]
                then Faulted;
        }

        exhibit state batteryBehavior : BatteryState;
    }

    part def StereoCamera {
        attribute horizontalFieldOfView : PlaneAngle = 90 [deg];
        attribute frameRate : Frequency = 30 [Hz];
        attribute imageWidth : Integer = 1920;
        attribute imageHeight : Integer = 1080;
        attribute powerDraw : Power = 12 [W];

        port powerIn : PowerPort;
        port imageOut : VisionPort;
    }

    part def LidarScanner {
        attribute scanRate : Frequency = 10 [Hz];
        attribute maxRange : Length = 30 [m];
        attribute angularResolution : PlaneAngle = 0.25 [deg];
        attribute powerDraw : Power = 18 [W];

        port powerIn : PowerPort;
        port cloudOut : DepthPort;
    }

    part def InertialNavigationUnit {
        attribute updateRate : Frequency = 200 [Hz];
        attribute gyroBiasStability : AngularVelocity = 0.5 [deg / h];
        attribute accelerationNoise : Acceleration = 0.03 [m / s^2];

        port powerIn : PowerPort;
        port poseOut : PosePort;
    }

    part def PerceptionComputer {
        attribute processorPower : Power = 65 [W];
        attribute mapResolution : MapResolution = 0.05;
        attribute objectDetectionConfidenceThreshold : ConfidenceScore = 0.80;

        port powerIn : PowerPort;
        port cameraIn : VisionPort;
        port lidarIn : DepthPort;
        port inertialPoseIn : PosePort;
        port telemetryOut : TelemetryPort;

        action def FuseSensorData {
            in item image : ImageFrame;
            in item cloud : PointCloud;
            in item inertialPose : RobotPose;
            out item fusedPose : RobotPose;
            out item localMap : OccupancyGridMap;
        }

        action def DetectObstacles {
            in item localMap : OccupancyGridMap;
            out item nearestObstacleDistance : Length;
            out item pathClear : Boolean;
        }

        perform action fusion : FuseSensorData;
        perform action obstacleDetection : DetectObstacles;
    }

    part def NavigationController {
        attribute replanningRate : Frequency = 5 [Hz];
        attribute nominalSpeed : LinearVelocity = 1.2 [m / s];
        attribute minimumObstacleClearance : Length = 0.6 [m];

        port commandIn : CommandPort;
        port telemetryIn : TelemetryPort;
        port motorOut : MotorControlPort;

        state def NavigationStateMachine {
            entry; then AwaitingCommand;

            state AwaitingCommand;
            state PlanningPath;
            state ExecutingMotion;
            state AvoidingObstacle;
            state HoldingPosition;
            state EmergencyStop;

            transition AwaitingCommand_to_PlanningPath
                first AwaitingCommand
                accept MotionCommand
                then PlanningPath;

            transition PlanningPath_to_ExecutingMotion
                first PlanningPath
                accept when true
                then ExecutingMotion;

            transition ExecutingMotion_to_AvoidingObstacle
                first ExecutingMotion
                accept when minimumObstacleClearance < 0.6 [m]
                then AvoidingObstacle;

            transition AvoidingObstacle_to_PlanningPath
                first AvoidingObstacle
                accept when true
                then PlanningPath;

            transition ExecutingMotion_to_HoldingPosition
                first ExecutingMotion
                accept when false
                then HoldingPosition;

            transition Any_to_EmergencyStop
                first ExecutingMotion
                accept when false
                then EmergencyStop;
        }

        exhibit state navigationBehavior : NavigationStateMachine;
    }

    part def DifferentialDriveBase {
        attribute wheelRadius : Length = 0.125 [m];
        attribute trackWidth : Length = 0.58 [m];
        attribute maximumSpeed : LinearVelocity = 2.0 [m / s];
        attribute maximumPayloadMass : Mass = 25 [kg];

        port powerIn : PowerPort;
        port controlIn : MotorControlPort;

        part leftMotor {
            attribute ratedPower : Power = 450 [W];
            attribute peakTorque : Torque = 18;
            attribute maxAngularVelocity : AngularVelocity = 35 [rad / s];
        }

        part rightMotor {
            attribute ratedPower : Power = 450 [W];
            attribute peakTorque : Torque = 18;
            attribute maxAngularVelocity : AngularVelocity = 35 [rad / s];
        }
    }

    part def RoboticArm {
        attribute degreeOfFreedom : Integer = 6;
        attribute reach : Length = 0.85 [m];
        attribute repeatability : Length = 0.002 [m];
        attribute payloadCapacity : Mass = 5 [kg];

        port powerIn : PowerPort;
        port controlIn : ManipulatorControlPort;

        part shoulderJoint {
            attribute range : PlaneAngle = 180 [deg];
            attribute peakTorque : Torque = 42;
        }

        part elbowJoint {
            attribute range : PlaneAngle = 160 [deg];
            attribute peakTorque : Torque = 35;
        }

        part wristAssembly {
            attribute range : PlaneAngle = 270 [deg];
            attribute peakTorque : Torque = 12;
        }

        part parallelGripper {
            attribute maxOpening : Length = 0.12 [m];
            attribute maxGripForce : Force = 120 [N];
        }

        state def ManipulatorStateMachine {
            entry; then Stowed;

            state Stowed;
            state Reaching;
            state Grasping;
            state Carrying;
            state Releasing;
            state Faulted;

            transition Stowed_to_Reaching
                first Stowed
                accept ManipulationCommand
                then Reaching;

            transition Reaching_to_Grasping
                first Reaching
                accept when true
                then Grasping;

            transition Grasping_to_Carrying
                first Grasping
                accept when true
                then Carrying;

            transition Carrying_to_Releasing
                first Carrying
                accept ManipulationCommand
                then Releasing;

            transition Releasing_to_Stowed
                first Releasing
                accept when true
                then Stowed;

            transition Any_to_Faulted
                first Reaching
                accept when false
                then Faulted;
        }

        exhibit state manipulatorBehavior : ManipulatorStateMachine;
    }

    part def MissionSupervisor {
        attribute missionUpdateRate : Frequency = 2 [Hz];
        attribute minimumBatteryForMission : Percent = 30.0;
        attribute requiredLocalizationConfidence : ConfidenceScore = 0.75;

        port operatorCommandIn : CommandPort;
        port robotTelemetryOut : TelemetryPort;
        port navigationCommandOut : CommandPort;
        port manipulationCommandOut : CommandPort;

        action def EvaluateMissionReadiness {
            in item diagnostics : DiagnosticReport;
            out item ready : Boolean;
            out item reasonCode : Integer;
        }

        action def CoordinateMobileManipulation {
            in item motionCommand : MotionCommand;
            in item manipulationCommand : ManipulationCommand;
            out item sequencedMotionCommand : MotionCommand;
            out item sequencedManipulationCommand : ManipulationCommand;
        }

        state def MissionStateMachine {
            entry; then Startup;

            state Startup;
            state SelfTest;
            state Ready;
            state Navigating;
            state Manipulating;
            state ReturningToDock;
            state SafeShutdown;

            transition Startup_to_SelfTest
                first Startup
                accept when true
                then SelfTest;

            transition SelfTest_to_Ready
                first SelfTest
                accept when true
                then Ready;

            transition Ready_to_Navigating
                first Ready
                accept MotionCommand
                then Navigating;

            transition Navigating_to_Manipulating
                first Navigating
                accept ManipulationCommand
                then Manipulating;

            transition Manipulating_to_Ready
                first Manipulating
                accept when true
                then Ready;

            transition Ready_to_ReturningToDock
                first Ready
                accept when minimumBatteryForMission < 30.0
                then ReturningToDock;

            transition ReturningToDock_to_SafeShutdown
                first ReturningToDock
                accept when true
                then SafeShutdown;
        }

        exhibit state missionBehavior : MissionStateMachine;
        perform action readinessCheck : EvaluateMissionReadiness;
        perform action coordination : CoordinateMobileManipulation;
    }

    part def AutonomousMobileManipulator {
        attribute systemMass : Mass = 72 [kg];
        attribute primaryFunction : String = "Autonomously perceive a workspace, navigate to task locations, manipulate objects, and report operational status while maintaining safety constraints.";
        attribute operatingDuration : Time = 4 [h];
        attribute ratedIndoorSpeed : LinearVelocity = 1.2 [m / s];

        port operatorCommand : CommandPort;
        port operatorTelemetry : TelemetryPort;

        part battery : BatteryPack;
        part camera : StereoCamera;
        part lidar : LidarScanner;
        part imu : InertialNavigationUnit;
        part perception : PerceptionComputer;
        part navigation : NavigationController;
        part base : DifferentialDriveBase;
        part arm : RoboticArm;
        part supervisor : MissionSupervisor;

        connect battery.powerOut to camera.powerIn;
        connect battery.powerOut to lidar.powerIn;
        connect battery.powerOut to imu.powerIn;
        connect battery.powerOut to perception.powerIn;
        connect battery.powerOut to base.powerIn;
        connect battery.powerOut to arm.powerIn;

        connect camera.imageOut to perception.cameraIn;
        connect lidar.cloudOut to perception.lidarIn;
        connect imu.poseOut to perception.inertialPoseIn;

        connect perception.telemetryOut to navigation.telemetryIn;
        connect supervisor.navigationCommandOut to navigation.commandIn;
        connect navigation.motorOut to base.controlIn;

        connect supervisor.manipulationCommandOut to arm.controlIn;
        connect operatorCommand to supervisor.operatorCommandIn;
        connect supervisor.robotTelemetryOut to operatorTelemetry;

        requirement def PrimaryFunctionRequirement {
            doc /* The robotic system shall autonomously perform mobile manipulation by sensing the environment, building a local map, navigating to assigned locations, manipulating objects, and reporting status to an operator. */
        }

        requirement def SafeNavigationRequirement {
            doc /* The robotic system shall maintain at least 0.6 m clearance from detected obstacles during autonomous motion under nominal indoor operating conditions. */
        }

        requirement def EnduranceRequirement {
            doc /* The robotic system shall operate for at least 4 hours on a fully charged battery during mixed navigation, perception, and manipulation duty cycles. */
        }

        requirement def ManipulationRequirement {
            doc /* The robotic arm shall position the end effector within 0.01 m of the commanded target pose while carrying payloads up to 5 kg. */
        }

        requirement def TelemetryRequirement {
            doc /* The robotic system shall publish pose, diagnostic, and local map telemetry at least once per second during all active mission states. */
        }

        satisfy PrimaryFunctionRequirement by supervisor;
        satisfy PrimaryFunctionRequirement by perception;
        satisfy PrimaryFunctionRequirement by navigation;
        satisfy PrimaryFunctionRequirement by arm;
        satisfy SafeNavigationRequirement by navigation;
        satisfy SafeNavigationRequirement by lidar;
        satisfy EnduranceRequirement by battery;
        satisfy ManipulationRequirement by arm;
        satisfy TelemetryRequirement by perception;
        satisfy TelemetryRequirement by supervisor;
    }
}