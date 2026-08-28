package 'Autonomous Bin Picking System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def StartCycle;
    item def ScanComplete;
    item def PlanComplete;
    item def ApproachComplete;
    item def GraspConfirmed;
    item def LiftComplete;
    item def TransportComplete;
    item def ReleaseComplete;

    item def PointCloud;
    item def Workpiece;
    item def Trajectory;
    item def GraspPose;
    item def ForceCommand {
        attribute targetPose : GraspPose;
        attribute gripForce : ForceValue;
    }
    item def Trigger;
    item def PlanRequest;
    item def SystemStatus {
        attribute isMoving : Boolean;
        attribute isGrasped : Boolean;
    }

    attribute def CycleTime :> TimeValue;
    attribute def SuccessRate :> Real;
    attribute def PayloadCapacity :> MassValue;
    attribute def MaxGripForce :> ForceValue;

    requirement def PerformanceRequirements {
        doc /* The system shall complete the full pick-and-place cycle in under 4 seconds with over 95 percent success rate. */
        attribute maxCycleTime : CycleTime = 4 [SI::s];
        attribute minSuccessRate : SuccessRate = 0.95;
    }

    requirement def RobustnessRequirements {
        doc /* The system shall handle partially hidden objects and changing light conditions. */
        attribute handlePartialOcclusion : Boolean = true;
        attribute handleVariableLighting : Boolean = true;
    }

    requirement def SafetyRequirements {
        doc /* The system shall prevent object damage and collisions during operation. */
        attribute preventObjectDamage : Boolean = true;
        attribute preventCollisions : Boolean = true;
    }

    part def DepthCamera {
        attribute resolution : Real;
        port triggerIn {
            in trigger : Trigger;
        }
        port scanOut {
            out pointCloud : PointCloud;
        }
        action scan {
            in trigger : Trigger;
            out pointCloud : PointCloud;
        }
    }

    part def MotionPlanner {
        port scanIn {
            in pointCloud : PointCloud;
        }
        port planRequestIn {
            in planRequest : PlanRequest;
        }
        port trajectoryOut {
            out trajectory : Trajectory;
        }
        port forceCmdOut {
            out forceCmd : ForceCommand;
        }
        action planGrasp {
            in pointCloud : PointCloud;
            out trajectory : Trajectory;
            out forceCmd : ForceCommand;
        }
    }

    part def RobotArm {
        attribute axes : Integer = 6;
        attribute payloadCapacity : PayloadCapacity;
        port trajectoryIn {
            in trajectory : Trajectory;
        }
        port armStatusOut {
            out armStatus : SystemStatus;
        }
        action move {
            in trajectory : Trajectory;
            out status : SystemStatus;
        }
    }

    part def AdaptiveGripper {
        attribute maxForce : MaxGripForce;
        port forceCmdIn {
            in forceCmd : ForceCommand;
        }
        port gripStatusOut {
            out gripStatus : SystemStatus;
        }
        action grip {
            in forceCmd : ForceCommand;
            out status : SystemStatus;
        }
        action release {
            out status : SystemStatus;
        }
    }

    part def SystemController {
        port cameraCmdOut {
            out trigger : Trigger;
        }
        port plannerCmdOut {
            out planRequest : PlanRequest;
        }
        port armStatusIn {
            in armStatus : SystemStatus;
        }
        port gripperStatusIn {
            in gripStatus : SystemStatus;
        }
        state def ControllerStates {
            entry; then Idle;
            state Idle;
            transition Idle to Scanning accept StartCycle;
            state Scanning;
            transition Scanning to Planning accept ScanComplete;
            state Planning;
            transition Planning to Moving accept PlanComplete;
            state Moving;
            transition Moving to Gripping accept ApproachComplete;
            state Gripping;
            transition Gripping to Lifting accept GraspConfirmed;
            state Lifting;
            transition Lifting to Transporting accept LiftComplete;
            state Transporting;
            transition Transporting to Releasing accept TransportComplete;
            state Releasing;
            transition Releasing to Idle accept ReleaseComplete;
        }
        exhibit ControllerStates;
    }

    part def BinPickingSystem {
        attribute cycleTime : CycleTime;
        attribute successRate : SuccessRate;

        part controller : SystemController;
        part camera : DepthCamera;
        part planner : MotionPlanner;
        part arm : RobotArm;
        part gripper : AdaptiveGripper;

        flow triggerFlow of Trigger
            from controller.cameraCmdOut.trigger to camera.triggerIn.trigger;
        flow pointCloudFlow of PointCloud
            from camera.scanOut.pointCloud to planner.scanIn.pointCloud;
        flow planRequestFlow of PlanRequest
            from controller.plannerCmdOut.planRequest to planner.planRequestIn.planRequest;
        flow trajectoryFlow of Trajectory
            from planner.trajectoryOut.trajectory to arm.trajectoryIn.trajectory;
        flow forceCmdFlow of ForceCommand
            from planner.forceCmdOut.forceCmd to gripper.forceCmdIn.forceCmd;
        flow armStatusFlow of SystemStatus
            from arm.armStatusOut.armStatus to controller.armStatusIn.armStatus;
        flow gripStatusFlow of SystemStatus
            from gripper.gripStatusOut.gripStatus to controller.gripperStatusIn.gripStatus;

        requirement perfReq : PerformanceRequirements;
        requirement robustnessReq : RobustnessRequirements;
        requirement safetyReq : SafetyRequirements;

        satisfy perfReq by controller;
        satisfy robustnessReq by planner;
        satisfy safetyReq by arm;

        action def OperationalCycle {
            first start;
            then action scanScene {
                out pointCloud : PointCloud;
            }
            then action planGraspAction {
                in pointCloud : PointCloud;
                out trajectory : Trajectory;
                out forceCmd : ForceCommand;
            }
            then action moveArm {
                in trajectory : Trajectory;
            }
            then action gripObject {
                in forceCmd : ForceCommand;
            }
            then action liftObject;
            then action transportObject;
            then action releaseObject;
            then done;
        }

        perform OperationalCycle;
    }
}
