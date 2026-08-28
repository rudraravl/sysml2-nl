package IndustrialRobotSystem {

    import ScalarValues::*;

    unit mm;
    unit kg;
    unit s;
    unit N;
    unit deg;
    unit deg_per_s = deg / s;

    value type Length :> Real { unit mm; }
    value type Mass :> Real { unit kg; }
    value type Duration :> Real { unit s; }
    value type Force :> Real { unit N; }
    value type Angle :> Real { unit deg; }
    value type AngularSpeed :> Real { unit deg_per_s; }

    enum def GripperCommandKind {
        literal open;
        literal close;
    }

    enum def TaskStatus {
        literal idle;
        literal executing;
        literal completed;
        literal error;
    }

    item def Workpiece {
        attribute mass : Mass;
        attribute width : Length;
        attribute height : Length;
        attribute detected : Boolean = false;
    }

    item def WorkpiecePose {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
    }

    item def JointCommand {
        attribute jointId : Integer;
        attribute targetAngle : Angle;
        attribute speed : AngularSpeed;
    }

    item def GripperCommand {
        attribute command : GripperCommandKind;
        attribute force : Force;
    }

    item def TaskStart;
    item def TaskDone;
    item def TaskError;
    item def Reset;

    port def VisionDataPort {
        out pose : WorkpiecePose;
        out workpieceDetected : Boolean;
    }

    port def JointCommandPort {
        out commands : JointCommand[6];
    }

    port def GripperCommandPort {
        out command : GripperCommand;
    }

    port def StatusPort {
        out status : TaskStatus;
    }

    part def MotorizedJoint {
        attribute jointId : Integer;
        attribute currentAngle : Angle = 0.0;
        attribute maxSpeed : AngularSpeed = 180.0;
        port cmdIn : ~JointCommandPort;
        action move(in target : Angle, in speed : AngularSpeed) {
            /* drive motor to target angle */
        }
    }

    part def RobotLink {
        attribute length : Length;
        attribute mass : Mass;
    }

    part def Gripper {
        attribute maxForce : Force = 120.0;
        attribute isOpen : Boolean = true;
        attribute currentForce : Force = 0.0;
        port cmdIn : ~GripperCommandPort;
        action open() {
            /* open gripper jaws */
        }
        action close(in force : Force) {
            /* close gripper jaws with specified force */
        }
        action applyForce(in force : Force) {
            /* regulate grip force */
        }
    }

    part def SixAxisRobotArm {
        attribute reach : Length = 1200.0;
        attribute positioningAccuracy : Length = 0.3;
        attribute payloadCapacity : Mass = 12.0;
        attribute jointCount : Integer = 6;

        part baseJoint : MotorizedJoint { :>> jointId = 1; }
        part shoulderJoint : MotorizedJoint { :>> jointId = 2; }
        part elbowJoint : MotorizedJoint { :>> jointId = 3; }
        part wristJoint1 : MotorizedJoint { :>> jointId = 4; }
        part wristJoint2 : MotorizedJoint { :>> jointId = 5; }
        part wristJoint3 : MotorizedJoint { :>> jointId = 6; }

        part baseLink : RobotLink { :>> length = 0.0; :>> mass = 15.0; }
        part shoulderLink : RobotLink { :>> length = 600.0; :>> mass = 12.0; }
        part elbowLink : RobotLink { :>> length = 400.0; :>> mass = 8.0; }
        part wristLink : RobotLink { :>> length = 200.0; :>> mass = 3.0; }

        part endEffector : Gripper;

        port jointCmdPort : ~JointCommandPort;
        port gripperCmdPort : ~GripperCommandPort;

        action distributeCommands(in cmds : JointCommand[6]) {
            /* route each command to the corresponding joint */
        }
    }

    part def Camera {
        attribute resolution : Real = 12.0;
        attribute frameRate : Real = 30.0;
        attribute fieldOfView : Angle = 60.0;
        port visionOut : VisionDataPort;
        action capture() : WorkpiecePose {
            /* capture image and extract pose */
        }
    }

    part def VisionSystem {
        part camera : Camera;
        port visionOut : VisionDataPort;
        action scanWorkspace() {
            /* scan the work table area */
        }
        action identifyWorkpiece() : Workpiece {
            /* detect and classify workpiece */
        }
        action determinePose() : WorkpiecePose {
            /* compute precise location and orientation */
        }
    }

    part def WorkTable {
        attribute width : Length = 1500.0;
        attribute depth : Length = 1000.0;
        attribute height : Length = 800.0;
        item workpieces[*] : Workpiece;
    }

    part def SafetyFence {
        attribute height : Length = 2000.0;
        attribute perimeter : Length = 8000.0;
        attribute panelCount : Integer = 8;
    }

    part def WorkCell {
        attribute cellWidth : Length = 4000.0;
        attribute cellDepth : Length = 3000.0;
        part table : WorkTable;
        part fence : SafetyFence;
        part robot : SixAxisRobotArm;
        part vision : VisionSystem;
    }

    action def PlanMotion {
        in targetPose : WorkpiecePose;
        in currentJointAngles : Angle[6];
        out jointCommands : JointCommand[6];
        out gripperCommand : GripperCommand;
        /* compute inverse kinematics and trajectory */
    }

    action def ExecutePickAndPlace {
        in targetPose : WorkpiecePose;
        in destinationPose : WorkpiecePose;
        out status : TaskStatus;
        action moveToAboveTarget {
            /* move arm above the target workpiece */
        }
        action lowerToPick {
            /* descend to grasp height */
        }
        action closeGripper(in force : Force) {
            /* close gripper and apply force */
        }
        action liftWorkpiece {
            /* raise the picked workpiece */
        }
        action moveToDestination {
            /* translate to destination position */
        }
        action placeWorkpiece {
            /* lower and release at destination */
        }
        action openGripper {
            /* open gripper to release workpiece */
        }
        action retractToReady {
            /* return to ready position */
        }
        then moveToAboveTarget;
        then lowerToPick;
        then closeGripper;
        then liftWorkpiece;
        then moveToDestination;
        then placeWorkpiece;
        then openGripper;
        then retractToReady;
    }

    state def RobotControllerStates {
        entry; then idle;

        state idle {
            entry { /* waiting for task assignment */ }
            transition idle_to_executing
                first idle
                accept TaskStart
                then executing;
        }

        state executing {
            entry { /* begin pick-and-place sequence */ }
            do ExecutePickAndPlace;
            transition executing_to_completed
                first executing
                accept TaskDone
                then completed;
            transition executing_to_error
                first executing
                accept TaskError
                then error;
        }

        state completed {
            entry { /* signal task completion to operator */ }
            transition completed_to_idle
                first completed
                accept Reset
                then idle;
        }

        state error {
            entry { /* signal error and halt motion */ }
            transition error_to_idle
                first error
                accept Reset
                then idle;
        }
    }

    part def RobotController {
        attribute cycleTime : Duration = 28.0;
        attribute currentStatus : TaskStatus = TaskStatus::idle;
        port visionIn : ~VisionDataPort;
        port jointCmdOut : JointCommandPort;
        port gripperCmdOut : GripperCommandPort;
        port statusOut : StatusPort;

        exhibit state controllerStates : RobotControllerStates;

        action processVisionData(in pose : WorkpiecePose) {
            /* interpret vision data for task planning */
        }
        action planMotion : PlanMotion;
        action executeTask : ExecutePickAndPlace;
        action sendJointCommands(out cmds : JointCommand[6]) {
            /* transmit joint commands to arm */
        }
        action sendGripperCommand(out cmd : GripperCommand) {
            /* transmit gripper command */
        }
    }

    part def IndustrialRobotSystem {
        attribute systemId : String = "IRS-001";
        part workCell : WorkCell;
        part controller : RobotController;

        connect workCell.vision.visionOut to controller.visionIn;
        connect controller.jointCmdOut to workCell.robot.jointCmdPort;
        connect controller.gripperCmdOut to workCell.robot.gripperCmdPort;
    }

    requirement def RobotArmRequirements {
        subject arm : SixAxisRobotArm;

        requirement ReachRequirement {
            subject :>> arm;
            constraint { arm.reach >= 1200.0 }
        }

        requirement AccuracyRequirement {
            subject :>> arm;
            constraint { arm.positioningAccuracy <= 0.3 }
        }

        requirement PayloadRequirement {
            subject :>> arm;
            constraint { arm.payloadCapacity >= 12.0 }
        }

        requirement AxisCountRequirement {
            subject :>> arm;
            constraint { arm.jointCount == 6 }
        }
    }

    requirement def GripperRequirements {
        subject gripper : Gripper;

        requirement GripperFunctionRequirement {
            subject :>> gripper;
            constraint { gripper.maxForce > 0.0 }
        }
    }

    requirement def SystemPerformanceRequirements {
        subject system : IndustrialRobotSystem;

        requirement CycleTimeRequirement {
            subject :>> system;
            constraint { system.controller.cycleTime <= 28.0 }
        }
    }

    requirement def WorkCellSafetyRequirements {
        subject cell : WorkCell;

        requirement FenceHeightRequirement {
            subject :>> cell;
            constraint { cell.fence.height >= 2000.0 }
        }
    }

    requirement def VisionSystemRequirements {
        subject vision : VisionSystem;

        requirement PoseDetectionRequirement {
            subject :>> vision;
            constraint { vision.camera.resolution >= 5.0 }
        }
    }

}
