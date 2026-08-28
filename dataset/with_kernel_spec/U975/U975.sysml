package IndustrialRobotSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def Length :> ISQ::length;
    attribute def Mass :> ISQ::mass;
    attribute def Force :> ISQ::force;
    attribute def Duration :> ISQ::duration;
    attribute def JointAngle :> ScalarValues::Real;

    attribute def TaskStart;
    attribute def TaskCompleted;
    attribute def TaskError;

    attribute def GripperCommand {
        attribute openClose : Boolean;
        attribute force : Force;
    }

    attribute def JointCommand {
        attribute targetAngle : JointAngle;
    }

    attribute def VisionData {
        attribute workpieceId : String;
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
        attribute orientation : ScalarValues::Real;
    }

    port def JointCmdPort {
        out cmd : JointCommand;
    }

    port def GripperCmdPort {
        out cmd : GripperCommand;
    }

    port def VisionDataPort {
        out data : VisionData;
    }

    port def ControllerStatusPort {
        out status : String;
    }

    state def RobotControllerStates {
        entry; then idle;
        state idle;
        transition idle_to_executing
            first idle
            accept TaskStart
            then executing;
        state executing {
            entry; then moveAboveTarget;
            state moveAboveTarget;
            state lowerToPick;
            state closeGripper;
            state liftWorkpiece;
            state moveToDestination;
            state lowerToPlace;
            state openGripper;
            state retractToReady;
            transition t1 first moveAboveTarget then lowerToPick;
            transition t2 first lowerToPick then closeGripper;
            transition t3 first closeGripper then liftWorkpiece;
            transition t4 first liftWorkpiece then moveToDestination;
            transition t5 first moveToDestination then lowerToPlace;
            transition t6 first lowerToPlace then openGripper;
            transition t7 first openGripper then retractToReady;
            transition t8 first retractToReady then done;
        }
        state taskCompleted;
        transition executing_to_completed
            first executing
            then taskCompleted;
        transition completed_to_idle
            first taskCompleted
            then idle;
        transition idle_to_error
            first idle
            accept TaskError
            then error;
        transition executing_to_error
            first executing
            accept TaskError
            then error;
        state error;
        transition error_to_idle
            first error
            accept TaskStart
            then idle;
    }

    part def MotorizedJoint {
        port jointPort : ~JointCmdPort;
        attribute currentAngle : JointAngle;
        perform action actuate;
    }

    part def RobotLink {
        attribute length : Length;
    }

    part def Gripper {
        port cmdPort : ~GripperCmdPort;
        attribute isOpen : Boolean;
        attribute appliedForce : Force;
        perform action open;
        perform action close;
        perform action applyForce;
    }

    part def RobotArm {
        attribute maxReach : Length = 1200 [mm];
        attribute positioningAccuracy : Length = 0.3 [mm];
        attribute payloadCapacity : Mass = 12 [kg];

        port baseCmdPort : ~JointCmdPort;
        port shoulderCmdPort : ~JointCmdPort;
        port elbowCmdPort : ~JointCmdPort;
        port wrist1CmdPort : ~JointCmdPort;
        port wrist2CmdPort : ~JointCmdPort;
        port wrist3CmdPort : ~JointCmdPort;
        port gripperCmdPort : ~GripperCmdPort;

        part base : MotorizedJoint;
        part link1 : RobotLink;
        part shoulder : MotorizedJoint;
        part link2 : RobotLink;
        part elbow : MotorizedJoint;
        part link3 : RobotLink;
        part wrist1 : MotorizedJoint;
        part wrist2 : MotorizedJoint;
        part wrist3 : MotorizedJoint;
        part endEffector : Gripper;

        connection j1 connect baseCmdPort to base.jointPort;
        connection j2 connect shoulderCmdPort to shoulder.jointPort;
        connection j3 connect elbowCmdPort to elbow.jointPort;
        connection j4 connect wrist1CmdPort to wrist1.jointPort;
        connection j5 connect wrist2CmdPort to wrist2.jointPort;
        connection j6 connect wrist3CmdPort to wrist3.jointPort;
        connection gConn connect gripperCmdPort to endEffector.cmdPort;

        perform action moveArm;
    }

    part def WorkTable {
        attribute width : Length = 1000 [mm];
        attribute height : Length = 800 [mm];
    }

    part def SafetyFence {
        attribute height : Length = 2000 [mm];
    }

    part def WorkCell {
        part table : WorkTable;
        part fence : SafetyFence;
    }

    part def Camera {
        port dataPort : VisionDataPort;
        perform action scanWorkspace;
    }

    part def RobotController {
        port baseCmdOut : JointCmdPort;
        port shoulderCmdOut : JointCmdPort;
        port elbowCmdOut : JointCmdPort;
        port wrist1CmdOut : JointCmdPort;
        port wrist2CmdOut : JointCmdPort;
        port wrist3CmdOut : JointCmdPort;
        port gripperCmdOut : GripperCmdPort;
        port visionIn : ~VisionDataPort;
        port statusOut : ControllerStatusPort;

        perform action processVision;
        perform action planMotion;
        perform action executePickAndPlace;

        exhibit state behaviorStates : RobotControllerStates;
    }

    requirement def AccuracyRequirement {
        attribute requiredAccuracy : Length = 0.3 [mm];
        subject arm : RobotArm;
        constraint { arm.positioningAccuracy <= requiredAccuracy }
    }

    requirement def PayloadRequirement {
        attribute requiredPayload : Mass = 12 [kg];
        subject arm : RobotArm;
        constraint { arm.payloadCapacity >= requiredPayload }
    }

    requirement def ReachRequirement {
        attribute requiredReach : Length = 1200 [mm];
        subject arm : RobotArm;
        constraint { arm.maxReach >= requiredReach }
    }

    requirement def CycleTimeRequirement {
        attribute requiredCycleTime : Duration = 28 [s];
        subject system : RobotSystem;
        constraint { system.cycleTime <= requiredCycleTime }
    }

    requirement accReq : AccuracyRequirement;
    requirement payReq : PayloadRequirement;
    requirement reachReq : ReachRequirement;
    requirement cycleReq : CycleTimeRequirement;

    part def RobotSystem {
        attribute cycleTime : Duration = 28 [s];
        part arm : RobotArm;
        part cell : WorkCell;
        part vision : Camera;
        part controller : RobotController;

        connection baseConn connect controller.baseCmdOut to arm.baseCmdPort;
        connection shoulderConn connect controller.shoulderCmdOut to arm.shoulderCmdPort;
        connection elbowConn connect controller.elbowCmdOut to arm.elbowCmdPort;
        connection wrist1Conn connect controller.wrist1CmdOut to arm.wrist1CmdPort;
        connection wrist2Conn connect controller.wrist2CmdOut to arm.wrist2CmdPort;
        connection wrist3Conn connect controller.wrist3CmdOut to arm.wrist3CmdPort;
        connection gripperConn connect controller.gripperCmdOut to arm.gripperCmdPort;
        connection visionConn connect vision.dataPort to controller.visionIn;

        satisfy accReq by arm;
        satisfy payReq by arm;
        satisfy reachReq by arm;
        satisfy cycleReq by RobotSystem;
    }
}
