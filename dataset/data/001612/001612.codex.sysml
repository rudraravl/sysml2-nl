package UniversalRoboticsCollaborativeRobotModel {
    import ScalarValues::*;
    import SI::*;

    attribute def Mass :> ISQ::mass;
    attribute def Length :> ISQ::length;
    attribute def Speed :> ISQ::speed;
    attribute def Force :> ISQ::force;
    attribute def Torque :> ISQ::torque;
    attribute def Power :> ISQ::power;
    attribute def Voltage :> ISQ::electricPotential;
    attribute def Current :> ISQ::electricCurrent;
    attribute def Angle :> ISQ::planeAngle;
    attribute def Time :> ISQ::time;

    item def RobotCommand {
        attribute commandId: String;
        attribute targetPose: Pose6D;
        attribute speedLimit: Speed;
        attribute forceLimit: Force;
        attribute blendRadius: Length;
    }

    item def SafetyEvent {
        attribute eventId: String;
        attribute severity: SafetySeverity;
        attribute detectedAt: Time;
    }

    item def Workpiece {
        attribute mass: Mass;
        attribute width: Length;
        attribute height: Length;
        attribute depth: Length;
        attribute graspForceRequired: Force;
    }

    item def EndEffectorStatus {
        attribute attached: Boolean;
        attribute payloadMass: Mass;
        attribute gripForce: Force;
    }

    item def JointTelemetry {
        attribute jointIndex: Integer;
        attribute position: Angle;
        attribute velocity: Speed;
        attribute torque: Torque;
        attribute temperatureCelsius: Real;
    }

    item def Pose6D {
        attribute x: Length;
        attribute y: Length;
        attribute z: Length;
        attribute rx: Angle;
        attribute ry: Angle;
        attribute rz: Angle;
    }

    enum def SafetySeverity {
        enum low;
        enum warning;
        enum protectiveStop;
        enum emergencyStop;
    }

    enum def RobotMode {
        enum poweredOff;
        enum booting;
        enum manualTeach;
        enum automatic;
        enum collaborativeReducedSpeed;
        enum protectiveStop;
        enum emergencyStop;
        enum faultRecovery;
    }

    port def CommandPort {
        in item command: RobotCommand;
        out item status: EndEffectorStatus;
    }

    port def TelemetryPort {
        out item jointTelemetry: JointTelemetry;
        out item toolStatus: EndEffectorStatus;
    }

    port def SafetyPort {
        in item safetyEvent: SafetyEvent;
        out item safetyState: SafetyEvent;
    }

    port def WorkpiecePort {
        inout item workpiece: Workpiece;
    }

    port def PowerPort {
        in attribute supplyVoltage: Voltage;
        in attribute supplyCurrent: Current;
        out attribute consumedPower: Power;
    }

    part def UniversalRoboticsCollaborativeRobot {
        attribute primaryFunction: String = "Safely manipulate workpieces in a shared human workspace by executing programmed motion, force-controlled interaction, and tool operations.";
        attribute maximumPayload: Mass = 12 [SI::kg];
        attribute reach: Length = 1300 [SI::mm];
        attribute repeatability: Length = 0.05 [SI::mm];
        attribute nominalSupplyVoltage: Voltage = 48 [SI::V];
        attribute maximumTcpSpeed: Speed = 1.5 [SI::m / SI::s];
        attribute reducedCollaborativeSpeed: Speed = 0.25 [SI::m / SI::s];
        attribute maximumToolForce: Force = 150 [SI::N];
        attribute mode: RobotMode;

        port commandInterface: CommandPort;
        port telemetryInterface: TelemetryPort;
        port safetyInterface: SafetyPort;
        port powerInterface: PowerPort;
        port toolWorkpieceInterface: WorkpiecePort;

        part controller: RobotController;
        part arm: SixAxisManipulator;
        part teachPendant: TeachPendant;
        part safetySystem: CollaborativeSafetySystem;
        part toolFlange: ToolFlange;
        part gripper: AdaptiveGripper;

        connect commandInterface to controller.commandInterface;
        connect telemetryInterface to controller.telemetryInterface;
        connect safetyInterface to safetySystem.safetyInterface;
        connect powerInterface to controller.powerInput;
        connect controller.motionOutput to arm.motionInput;
        connect controller.safetyInput to safetySystem.controllerSafetyOutput;
        connect arm.flangeInterface to toolFlange.robotSide;
        connect toolFlange.toolSide to gripper.mountInterface;
        connect gripper.workpieceInterface to toolWorkpieceInterface;
        connect teachPendant.operatorCommandInterface to controller.commandInterface;
    }

    part def RobotController {
        attribute cycleTime: Time = 2 [SI::ms];
        attribute programMemory: Integer = 256;
        attribute servoBusVoltage: Voltage = 48 [SI::V];

        port commandInterface: CommandPort;
        port telemetryInterface: TelemetryPort;
        port powerInput: PowerPort;
        port motionOutput: MotionPort;
        port safetyInput: SafetyPort;

        perform action executeProgram: ExecuteCollaborativeTask;
    }

    port def MotionPort {
        out item command: RobotCommand;
        in item feedback: JointTelemetry;
    }

    part def SixAxisManipulator {
        attribute numberOfAxes: Integer = 6;
        attribute armMass: Mass = 33 [SI::kg];

        port motionInput: MotionPort;
        port flangeInterface: MechanicalToolPort;

        part baseJoint: RobotJoint {
            attribute jointIndex = 1;
            attribute maximumTorque = 150 [SI::N * SI::m];
        }

        part shoulderJoint: RobotJoint {
            attribute jointIndex = 2;
            attribute maximumTorque = 150 [SI::N * SI::m];
        }

        part elbowJoint: RobotJoint {
            attribute jointIndex = 3;
            attribute maximumTorque = 75 [SI::N * SI::m];
        }

        part wrist1Joint: RobotJoint {
            attribute jointIndex = 4;
            attribute maximumTorque = 28 [SI::N * SI::m];
        }

        part wrist2Joint: RobotJoint {
            attribute jointIndex = 5;
            attribute maximumTorque = 28 [SI::N * SI::m];
        }

        part wrist3Joint: RobotJoint {
            attribute jointIndex = 6;
            attribute maximumTorque = 28 [SI::N * SI::m];
        }
    }

    part def RobotJoint {
        attribute jointIndex: Integer;
        attribute position: Angle;
        attribute velocityLimit: Speed = 180 [SI::deg / SI::s];
        attribute maximumTorque: Torque;
        attribute motorTemperatureCelsius: Real;
    }

    port def MechanicalToolPort {
        inout item payload: Workpiece;
        out item toolStatus: EndEffectorStatus;
    }

    part def ToolFlange {
        attribute boltCircleDiameter: Length = 50 [SI::mm];
        attribute maximumToolMass: Mass = 12 [SI::kg];

        port robotSide: MechanicalToolPort;
        port toolSide: MechanicalToolPort;

        connect robotSide to toolSide;
    }

    part def AdaptiveGripper {
        attribute maximumGripForce: Force = 120 [SI::N];
        attribute stroke: Length = 85 [SI::mm];
        attribute toolMass: Mass = 1.2 [SI::kg];

        port mountInterface: MechanicalToolPort;
        port workpieceInterface: WorkpiecePort;

        perform action grasp: GraspWorkpiece;
        perform action release: ReleaseWorkpiece;
    }

    part def TeachPendant {
        attribute displaySize: Length = 305 [SI::mm];
        attribute emergencyStopAvailable: Boolean = true;

        port operatorCommandInterface: CommandPort;
    }

    part def CollaborativeSafetySystem {
        attribute protectiveSeparationDistance: Length = 500 [SI::mm];
        attribute forceLimit: Force = 150 [SI::N];
        attribute reducedSpeedLimit: Speed = 0.25 [SI::m / SI::s];
        attribute emergencyStopResponseTime: Time = 120 [SI::ms];

        port safetyInterface: SafetyPort;
        port controllerSafetyOutput: SafetyPort;

        perform action monitorWorkspace: MonitorCollaborativeSafety;
    }

    action def ExecuteCollaborativeTask {
        in item command: RobotCommand;
        in item incomingWorkpiece: Workpiece;
        out item placedWorkpiece: Workpiece;

        action validateSafety: ValidateSafetyEnvelope;
        action planTrajectory: PlanCollisionFreeTrajectory;
        action moveToPick: MoveToolCenterPoint;
        action closeGripper: GraspWorkpiece;
        action moveToPlace: MoveToolCenterPoint;
        action openGripper: ReleaseWorkpiece;
        action publishTelemetry: PublishRobotTelemetry;

        first start;
        then validateSafety;
        then planTrajectory;
        then moveToPick;
        then closeGripper;
        then moveToPlace;
        then openGripper;
        then publishTelemetry;
        then done;
    }

    action def ValidateSafetyEnvelope {
        in item command: RobotCommand;
        out attribute accepted: Boolean;
    }

    action def PlanCollisionFreeTrajectory {
        in item command: RobotCommand;
        out item plannedCommand: RobotCommand;
    }

    action def MoveToolCenterPoint {
        in item targetCommand: RobotCommand;
        out item jointTelemetry: JointTelemetry;
    }

    action def GraspWorkpiece {
        in item workpiece: Workpiece;
        out item status: EndEffectorStatus;
    }

    action def ReleaseWorkpiece {
        in item workpiece: Workpiece;
        out item status: EndEffectorStatus;
    }

    action def PublishRobotTelemetry {
        in item jointTelemetry: JointTelemetry;
        in item toolStatus: EndEffectorStatus;
    }

    action def MonitorCollaborativeSafety {
        in item observedEvent: SafetyEvent;
        out item commandedSafetyState: SafetyEvent;
    }

    state def RobotOperatingStateMachine {
        entry action initializeController: ValidateSafetyEnvelope;

        state poweredOff;
        state booting;
        state idleManualTeach;
        state automaticExecution;
        state reducedSpeedCollaboration;
        state protectiveStopped;
        state emergencyStopped;
        state faultRecovery;

        transition initial then poweredOff;
        transition powerOn first poweredOff accept RobotCommand then booting;
        transition bootComplete first booting then idleManualTeach;
        transition startAutomatic first idleManualTeach accept RobotCommand then automaticExecution;
        transition humanNear first automaticExecution accept SafetyEvent then reducedSpeedCollaboration;
        transition humanClear first reducedSpeedCollaboration accept SafetyEvent then automaticExecution;
        transition safetyLimitExceeded first automaticExecution accept SafetyEvent then protectiveStopped;
        transition resetProtectiveStop first protectiveStopped accept RobotCommand then idleManualTeach;
        transition emergencyPressed first poweredOff accept SafetyEvent then emergencyStopped;
        transition emergencyDuringBoot first booting accept SafetyEvent then emergencyStopped;
        transition emergencyDuringManual first idleManualTeach accept SafetyEvent then emergencyStopped;
        transition emergencyDuringAuto first automaticExecution accept SafetyEvent then emergencyStopped;
        transition emergencyDuringReduced first reducedSpeedCollaboration accept SafetyEvent then emergencyStopped;
        transition releaseEmergency first emergencyStopped accept RobotCommand then faultRecovery;
        transition recoveryComplete first faultRecovery then idleManualTeach;
        transition shutdown first idleManualTeach accept RobotCommand then poweredOff;
    }

    requirement def PrimaryFunctionRequirement {
        subject robot: UniversalRoboticsCollaborativeRobot;

        require constraint {
            robot.maximumPayload >= 12 [SI::kg] and
            robot.reach >= 1300 [SI::mm] and
            robot.primaryFunction == "Safely manipulate workpieces in a shared human workspace by executing programmed motion, force-controlled interaction, and tool operations."
        }
    }

    requirement def CollaborativeSafetyRequirement {
        subject safety: CollaborativeSafetySystem;

        require constraint {
            safety.protectiveSeparationDistance >= 500 [SI::mm] and
            safety.emergencyStopResponseTime <= 120 [SI::ms] and
            safety.reducedSpeedLimit <= 0.25 [SI::m / SI::s]
        }
    }

    requirement def ManipulationPerformanceRequirement {
        subject robot: UniversalRoboticsCollaborativeRobot;

        require constraint {
            robot.repeatability <= 0.05 [SI::mm] and
            robot.maximumTcpSpeed >= 1.5 [SI::m / SI::s] and
            robot.maximumToolForce >= 150 [SI::N]
        }
    }

    requirement def ToolingRequirement {
        subject gripper: AdaptiveGripper;

        require constraint {
            gripper.maximumGripForce >= 120 [SI::N] and
            gripper.stroke >= 85 [SI::mm] and
            gripper.toolMass <= 1.2 [SI::kg]
        }
    }

    part universalRoboticsCobotSystem: UniversalRoboticsCollaborativeRobot {
        attribute mode = RobotMode::poweredOff;

        part sampleWorkpiece: Workpiece {
            attribute mass = 2.5 [SI::kg];
            attribute width = 120 [SI::mm];
            attribute height = 60 [SI::mm];
            attribute depth = 80 [SI::mm];
            attribute graspForceRequired = 40 [SI::N];
        }
    }

    satisfy PrimaryFunctionRequirement by universalRoboticsCobotSystem;
    satisfy CollaborativeSafetyRequirement by universalRoboticsCobotSystem.safetySystem;
    satisfy ManipulationPerformanceRequirement by universalRoboticsCobotSystem;
    satisfy ToolingRequirement by universalRoboticsCobotSystem.gripper;
}