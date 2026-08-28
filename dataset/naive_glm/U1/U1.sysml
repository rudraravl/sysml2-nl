package RoboticWorkCell {
    import ScalarValues::*;

    // ===== Value Definitions =====
    value def Force :> Real { unit 'N'; }
    value def Distance :> Real { unit 'm'; }
    value def Angle :> Real { unit 'rad'; }
    value def ElectricCurrent :> Real { unit 'A'; }
    value def Voltage :> Real { unit 'V'; }
    value def Duration :> Real { unit 's'; }
    value def Mass :> Real { unit 'kg'; }
    value def LinearVelocity :> Real { unit 'm/s'; }
    value def AngularVelocity :> Real { unit 'rad/s'; }
    value def Frequency :> Real { unit 'Hz'; }

    value def CartesianPosition {
        attribute x : Distance;
        attribute y : Distance;
        attribute z : Distance;
    }

    value def Orientation {
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
    }

    value def Pose {
        attribute position : CartesianPosition;
        attribute orientation : Orientation;
    }

    // ===== Enumerations =====
    enum def GripperAction { open; close; hold; }
    enum def ExecutionStatus { pending; executing; arrived; failed; complete; }
    enum def ErrorType { invalidPath; gripFailure; obstacleDetected; communicationLoss; powerFault; }

    // ===== Item Definitions =====
    item def Workpiece {
        attribute id : String;
        attribute mass : Mass;
        attribute fragilityThreshold : Force;
        attribute targetPose : Pose;
    }

    item def TaskCommand {
        attribute workpieceId : String;
        attribute targetPose : Pose;
        attribute priority : Integer;
    }

    item def ResetCommand {
        attribute resetType : String;
    }

    item def VisionData {
        attribute workpiecePose : Pose;
        attribute obstacleDetected : Boolean;
        attribute confidence : Real;
        attribute timestamp : Duration;
    }

    item def JointConfiguration {
        attribute joints : Angle[6];
    }

    item def Trajectory {
        attribute waypoints : Pose[*];
        attribute jointPath : JointConfiguration[*];
        attribute estimatedDuration : Duration;
        attribute safe : Boolean;
    }

    item def GripCommand {
        attribute targetForce : Force;
        attribute action : GripperAction;
    }

    item def GripStatus {
        attribute gripForce : Force;
        attribute secured : Boolean;
    }

    item def ExecutionFeedback {
        attribute status : ExecutionStatus;
        attribute message : String;
    }

    item def ErrorReport {
        attribute errorType : ErrorType;
        attribute description : String;
        attribute timestamp : Duration;
    }

    // ===== Port Definitions =====
    port def CommandPort {
        in item commands : TaskCommand[*];
        in item reset : ResetCommand[*];
        out item status : String[*];
        out item errors : ErrorReport[*];
    }

    port def VisionDataPort {
        out item visionData : VisionData[*];
    }

    port def TrajectoryPort {
        in item trajectory : Trajectory[*];
        out item feedback : ExecutionFeedback[*];
    }

    port def GripCommandPort {
        in item gripCommand : GripCommand[*];
        out item gripStatus : GripStatus[*];
    }

    port def PowerPort {
        out attribute voltage : Voltage;
        out attribute current : ElectricCurrent;
    }

    port def MechanicalInterfacePort {
        out attribute endEffectorPose : Pose;
        in attribute loadMass : Mass;
    }

    port def WorkpieceFlowPort {
        in item incomingWorkpieces : Workpiece[*];
        out item outgoingWorkpieces : Workpiece[*];
    }

    // ===== Requirements =====
    requirement def PickAndPlaceRequirement {
        subject workCell : WorkCell;
        objective {
            The workCell shall autonomously grasp a workpiece from the input conveyor,
            move it to a specified target location, and release it onto the output conveyor.
        }
    }

    requirement def SafeHandlingRequirement {
        subject gripper : Gripper;
        attribute maxGripForce : Force = 50 [N];
        objective {
            The gripper shall apply a controlled grip force not exceeding maxGripForce
            to prevent damage to fragile workpieces.
        }
    }

    requirement def TrajectorySafetyRequirement {
        subject controller : MotionController;
        objective {
            The controller shall plan a collision-free trajectory based on
            three-dimensional vision sensor data before commanding arm motion.
        }
    }

    requirement def CycleTimeRequirement {
        subject workCell : WorkCell;
        attribute maxCycleTime : Duration = 30 [s];
        objective {
            The workCell shall complete a single pick-and-place cycle within
            maxCycleTime under nominal operating conditions.
        }
    }

    requirement def ErrorHandlingRequirement {
        subject workCell : WorkCell;
        objective {
            The workCell shall enter an error state upon detection of an invalid path,
            obstacle collision, or failed grip, and shall remain in error until
            a manual reset command is received.
        }
    }

    requirement def VisionRangeRequirement {
        subject sensor : VisionSensor3D;
        attribute minRange : Distance = 0.1 [m];
        attribute maxRange : Distance = 2.0 [m];
        objective {
            The sensor shall detect workpieces and obstacles within the range
            from minRange to maxRange with a confidence of at least 0.9.
        }
    }

    requirement def PayloadRequirement {
        subject arm : RoboticArm;
        attribute minPayload : Mass = 5 [kg];
        objective {
            The arm shall support a payload of at least minPayload at full reach.
        }
    }

    requirement def PowerStabilityRequirement {
        subject supply : PowerSupply;
        attribute nominalVoltage : Voltage = 48 [V];
        attribute tolerance : Voltage = 1 [V];
        objective {
            The supply shall maintain output voltage within tolerance of nominalVoltage
            under all load conditions up to maximum current.
        }
    }

    // ===== Part Definitions =====

    part def ForceSensor {
        attribute measurementRange : Force = 100 [N];
        attribute accuracy : Force = 0.1 [N];
        attribute samplingRate : Frequency = 1000 [Hz];
        attribute calibrated : Boolean = true;
        out attribute measuredForce : Force;

        exhibit action def Calibrate {
            out zeroOffset : Force;
        }

        exhibit action def MeasureForce {
            in appliedLoad : Mass;
            out forceReading : Force;
        }
    }

    part def Gripper {
        attribute fingerCount : Integer = 2;
        attribute maxOpening : Distance = 0.1 [m];
        attribute minOpening : Distance = 0.0 [m];
        attribute currentOpening : Distance;
        attribute currentForce : Force;
        attribute maxGripForce : Force = 50 [N];

        port gripCommandPort : GripCommandPort;
        port mechanicalPort : ~MechanicalInterfacePort;
        port powerPort : ~PowerPort;

        part forceSensor : ForceSensor;

        satisfy SafeHandlingRequirement;

        exhibit action def OpenFingers {
            out targetOpening : Distance = 0.1 [m];
        }

        exhibit action def CloseFingers {
            in targetForce : Force;
            out currentOpening : Distance;
        }

        exhibit action def HoldPosition {
            in force : Force;
        }

        exhibit action def MonitorForce {
            out measuredForce : Force;
        }

        exhibit state def GripperStateMachine {
            entry; then Open;

            state Open {
                entry do OpenFingers;
            }

            state Closing {
                entry do CloseFingers;
                do MonitorForce;
            }

            state Gripped {
                entry do HoldPosition;
                do MonitorForce;
            }

            state Releasing {
                entry do OpenFingers;
            }

            transition from Open to Closing
                accept GripCommand [action == GripperAction::close];

            transition from Closing to Gripped
                [forceSensor.measuredForce >= gripCommandPort.gripCommand.targetForce];

            transition from Gripped to Releasing
                accept GripCommand [action == GripperAction::open];

            transition from Releasing to Open
                [currentOpening >= maxOpening];
        }
    }

    part def RoboticArm {
        attribute jointCount : Integer = 6;
        attribute maxReach : Distance = 1.5 [m];
        attribute payloadCapacity : Mass = 10 [kg];
        attribute maxJointVelocity : AngularVelocity = 3.14 [rad/s];
        attribute currentJointConfig : JointConfiguration;
        attribute currentEndEffectorPose : Pose;

        port controlPort : TrajectoryPort;
        port endEffectorPort : MechanicalInterfacePort;
        port powerPort : ~PowerPort;

        satisfy PayloadRequirement;

        exhibit action def ExecuteTrajectory {
            in trajectory : Trajectory;
            out endEffectorPose : Pose;
        }

        exhibit action def MonitorJoints {
            out jointConfig : JointConfiguration;
        }

        exhibit action def HoldPosition {
            out jointConfig : JointConfiguration;
        }

        exhibit action def Stabilize {
            out settled : Boolean;
        }

        exhibit state def ArmStateMachine {
            entry; then Idle;

            state Idle {
                entry do HoldPosition;
            }

            state Moving {
                entry do ExecuteTrajectory;
                do MonitorJoints;
            }

            state AtTarget {
                entry do Stabilize;
            }

            transition from Idle to Moving
                accept Trajectory;

            transition from Moving to AtTarget
                [controlPort.feedback.status == ExecutionStatus::arrived];

            transition from Moving to Idle
                [controlPort.feedback.status == ExecutionStatus::failed];

            transition from AtTarget to Idle
                [controlPort.feedback.status == ExecutionStatus::complete];
        }
    }

    part def MotionController {
        attribute planningAlgorithm : String = "RRT-Connect";
        attribute controlLoopRate : Frequency = 250 [Hz];
        attribute currentTrajectory : Trajectory;
        attribute trajectoryReady : Boolean = false;
        attribute armAtTarget : Boolean = false;
        attribute armFailed : Boolean = false;
        attribute gripSecured : Boolean = false;
        attribute gripReleased : Boolean = false;
        attribute lastError : ErrorType;

        port commandPort : CommandPort;
        port visionPort : ~VisionDataPort;
        port armControlPort : ~TrajectoryPort;
        port gripControlPort : ~GripCommandPort;
        port powerPort : ~PowerPort;

        satisfy TrajectorySafetyRequirement;

        exhibit action def WaitForCommand;
        exhibit action def RequestVisionData;
        exhibit action def PlanTrajectory {
            in visionData : VisionData;
            in targetPose : Pose;
            in currentPose : Pose;
            out trajectory : Trajectory;
        }
        exhibit action def SendTrajectoryToArm;
        exhibit action def SendGripCommand;
        exhibit action def SendTargetTrajectory;
        exhibit action def SendReleaseCommand;
        exhibit action def LogError {
            in errorType : ErrorType;
            out errorReport : ErrorReport;
        }
        exhibit action def WaitForReset;

        exhibit state def ControllerStateMachine {
            entry; then Idle;

            state Idle {
                entry do WaitForCommand;
            }

            state Sensing {
                entry do RequestVisionData;
            }

            state Planning {
                entry do PlanTrajectory;
            }

            state ExecutingApproach {
                entry do SendTrajectoryToArm;
            }

            state Gripping {
                entry do SendGripCommand;
            }

            state ExecutingTarget {
                entry do SendTargetTrajectory;
            }

            state Releasing {
                entry do SendReleaseCommand;
            }

            state Error {
                entry do LogError;
                do WaitForReset;
            }

            transition from Idle to Sensing
                accept TaskCommand;

            transition from Sensing to Planning
                accept VisionData;

            transition from Planning to ExecutingApproach
                [currentTrajectory.safe == true];

            transition from Planning to Error {
                [currentTrajectory.safe == false];
                do LogError;
            }

            transition from ExecutingApproach to Gripping
                [armAtTarget == true];

            transition from ExecutingApproach to Error
                [armFailed == true];

            transition from Gripping to ExecutingTarget
                [gripSecured == true];

            transition from Gripping to Error
                [gripSecured == false and armAtTarget == true];

            transition from ExecutingTarget to Releasing
                [armAtTarget == true];

            transition from ExecutingTarget to Error
                [armFailed == true];

            transition from Releasing to Idle
                [gripReleased == true];

            transition from Error to Idle
                accept ResetCommand;
        }
    }

    part def VisionSensor3D {
        attribute fieldOfView : Angle = 1.047 [rad];
        attribute resolution : String = "1920x1080";
        attribute minRange : Distance = 0.1 [m];
        attribute maxRange : Distance = 2.0 [m];
        attribute frameRate : Frequency = 30 [Hz];
        attribute calibrated : Boolean = true;

        port dataPort : VisionDataPort;
        port powerPort : ~PowerPort;

        satisfy VisionRangeRequirement;

        exhibit action def AcquireScene {
            out visionData : VisionData;
        }

        exhibit action def DetectWorkpiece {
            in scene : VisionData;
            out workpiecePose : Pose;
            out confidence : Real;
        }

        exhibit action def DetectObstacles {
            in scene : VisionData;
            out obstacleDetected : Boolean;
        }

        exhibit state def VisionStateMachine {
            entry; then Standby;

            state Standby;
            state Acquiring {
                entry do AcquireScene;
                do DetectWorkpiece;
                do DetectObstacles;
            }

            transition from Standby to Acquiring
                accept TaskCommand;

            transition from Acquiring to Standby
                accept VisionData;
        }
    }

    part def Conveyor {
        attribute beltSpeed : LinearVelocity = 0.2 [m/s];
        attribute length : Distance = 2.0 [m];
        attribute width : Distance = 0.3 [m];
        attribute running : Boolean = false;
        attribute workpiecePresent : Boolean = false;

        port workpiecePort : WorkpieceFlowPort;
        port powerPort : ~PowerPort;

        exhibit action def Transfer {
            in workpiece : Workpiece;
            out movedWorkpiece : Workpiece;
        }

        exhibit action def StartBelt;
        exhibit action def StopBelt;

        exhibit state def ConveyorStateMachine {
            entry; then Stopped;

            state Stopped {
                entry do StopBelt;
            }

            state Running {
                entry do StartBelt;
                do Transfer;
            }

            transition from Stopped to Running
                [workpiecePort.incomingWorkpieces->notEmpty()];

            transition from Running to Stopped
                [workpiecePort.incomingWorkpieces->isEmpty()];
        }
    }

    part def PowerSupply {
        attribute outputVoltage : Voltage = 48 [V];
        attribute maxCurrent : ElectricCurrent = 50 [A];
        attribute efficiency : Real = 0.92;
        attribute active : Boolean = true;
        attribute overload : Boolean = false;

        port outputPower : PowerPort;

        satisfy PowerStabilityRequirement;

        exhibit action def SupplyPower {
            out voltage : Voltage = 48 [V];
            out current : ElectricCurrent;
        }

        exhibit action def Shutdown;

        exhibit state def PowerSupplyStateMachine {
            entry; then On;

            state On {
                do SupplyPower;
            }

            state Off {
                entry do Shutdown;
            }

            state Faulted {
                entry do Shutdown;
            }

            transition from On to Off
                [active == false];

            transition from On to Faulted
                [overload == true];

            transition from Off to On
                [active == true];

            transition from Faulted to On
                accept ResetCommand;
        }
    }

    // ===== Work Cell Assembly =====
    part def WorkCell {
        attribute cellId : String;
        attribute location : String;
        attribute operational : Boolean = true;

        port externalCommandPort : ~CommandPort;

        satisfy PickAndPlaceRequirement;
        satisfy CycleTimeRequirement;
        satisfy ErrorHandlingRequirement;

        part powerSupply : PowerSupply;
        part controller : MotionController;
        part visionSensor : VisionSensor3D;
        part arm : RoboticArm;
        part gripper : Gripper;
        part inputConveyor : Conveyor;
        part outputConveyor : Conveyor;

        // Power distribution
        connection between powerSupply.outputPower and controller.powerPort;
        connection between powerSupply.outputPower and arm.powerPort;
        connection between powerSupply.outputPower and gripper.powerPort;
        connection between powerSupply.outputPower and visionSensor.powerPort;
        connection between powerSupply.outputPower and inputConveyor.powerPort;
        connection between powerSupply.outputPower and outputConveyor.powerPort;

        // Control and data connections
        connection between controller.armControlPort and arm.controlPort;
        connection between controller.gripControlPort and gripper.gripCommandPort;
        connection between visionSensor.dataPort and controller.visionPort;
        connection between arm.endEffectorPort and gripper.mechanicalPort;

        // External command interface
        connection between externalCommandPort and controller.commandPort;

        // Workpiece flow
        connection between inputConveyor.workpiecePort and outputConveyor.workpiecePort;

        exhibit state def WorkCellStateMachine {
            entry; then Offline;

            state Offline;
            state Initializing;
            state Operational;
            state EmergencyStop;

            transition from Offline to Initializing
                [powerSupply.active == true];

            transition from Initializing to Operational
                [controller.commandPort.status == "ready"];

            transition from Operational to EmergencyStop
                accept ErrorReport;

            transition from EmergencyStop to Offline
                accept ResetCommand;

            transition from Operational to Offline
                [powerSupply.active == false];
        }
    }
}
