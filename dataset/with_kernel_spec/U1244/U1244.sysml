package AutonomousIndustrialRobotSystem {
    private import ISQ::*;
    private import ScalarValues::*;

    value def AngleValue :> ScalarValues::Real;
    value def AngularVelocityValue :> ScalarValues::Real;
    value def TorqueValue :> ScalarValues::Real;

    item def Position3D {
        attribute x : ISQ::length;
        attribute y : ISQ::length;
        attribute z : ISQ::length;
    }
    item def Orientation3D {
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }
    item def Pose3D {
        attribute position : Position3D;
        attribute orientation : Orientation3D;
    }
    item def MotionCommand {
        attribute targetPose : Pose3D;
        attribute speed : ISQ::speed;
        attribute acceleration : ISQ::acceleration;
    }
    item def GraspCommand {
        attribute graspForce : ISQ::force;
    }
    item def ReleaseCommand;
    item def VisionDetection {
        attribute workpieceID : String;
        attribute workpiecePose : Pose3D;
        attribute confidence : ScalarValues::Real;
    }
    item def JointCommand {
        attribute commandedAngle : AngleValue;
        attribute commandedVelocity : AngularVelocityValue;
    }
    item def JointFeedback {
        attribute actualAngle : AngleValue;
        attribute actualVelocity : AngularVelocityValue;
        attribute actualTorque : TorqueValue;
    }
    enum def SafetyMode {
        normal;
        reducedSpeed;
        protectiveStop;
        emergencyStop;
    }
    item def SafetyStatus {
        attribute mode : SafetyMode;
        attribute speedLimit : ISQ::speed;
        attribute forceLimit : ISQ::force;
    }
    enum def OperatingMode {
        manual;
        automatic;
        teaching;
    }
    attribute def StartSignal;
    attribute def StopSignal;
    attribute def EmergencyStopSignal;
    attribute def ProtectiveStopSignal;
    attribute def ResumeSignal;
    attribute def ResetSignal;
    attribute def TeachingSignal;
    attribute def CommandCompleted;
    attribute def WorkpieceDetected;
    attribute def ProximityWarning;

    port def MotionCommandPort {
        attribute command : MotionCommand;
    }
    port def VisionDataPort {
        attribute detection : VisionDetection;
    }
    port def SafetyStatusPort {
        attribute status : SafetyStatus;
    }
    port def GripperCommandPort {
        attribute command : GraspCommand;
        attribute releaseCommand : ReleaseCommand;
    }
    port def JointCommandPort {
        attribute command : JointCommand;
    }
    port def JointFeedbackPort {
        attribute feedback : JointFeedback;
    }
    port def ControllerFeedbackPort {
        attribute completed : CommandCompleted;
    }

    action def Move;
    action def Grasp;
    action def Release;
    action def CaptureImage;
    action def ProcessImage;
    action def PlanPath;
    action def ExecuteMotion;
    action def HaltMotion;
    action def LockJoints;
    action def AutomatedSequence {
        action captureAndProcess : CaptureImage;
        then action planPath : PlanPath;
        then action moveToPickup : Move;
        then action graspObject : Grasp;
        then action moveToDropoff : Move;
        then action releaseObject : Release;
    }

    part def RevoluteJoint {
        attribute currentAngle : AngleValue;
        attribute currentVelocity : AngularVelocityValue;
        attribute maxTorque : TorqueValue;
        port cmdPort : JointCommandPort;
        port fbPort : JointFeedbackPort;
        perform action applyTorque;
        exhibit state jointStates {
            entry action initial;
            state idle;
            state moving;
            transition initial then idle;
            transition idle_To_moving
                first idle
                accept cmd : JointCommand via cmdPort
                do applyTorque
                then moving;
            transition moving_To_idle
                first moving
                accept completed : CommandCompleted
                then idle;
        }
    }

    part def Gripper {
        attribute graspForce : ISQ::force;
        attribute maxGraspForce : ISQ::force;
        port cmdPort : GripperCommandPort;
        perform action grasp : Grasp;
        perform action release : Release;
        constraint { graspForce <= maxGraspForce }
        exhibit state gripperStates {
            entry action initial;
            state open;
            state closed;
            transition initial then open;
            transition open_To_closed
                first open
                accept g : GraspCommand via cmdPort
                do grasp
                then closed;
            transition closed_To_open
                first closed
                accept r : ReleaseCommand via cmdPort
                do release
                then open;
        }
    }

    part def RobotController {
        attribute operatingMode : OperatingMode;
        attribute commandQueue : MotionCommand [0..*];
        port visionPort : VisionDataPort;
        port motionPort : MotionCommandPort;
        port gripperPort : GripperCommandPort;
        port safetyPort : SafetyStatusPort;
        port feedbackPort : ControllerFeedbackPort;
        perform action planPath : PlanPath;
        perform action executeMotion : ExecuteMotion;
        exhibit state controllerStates {
            entry action initial;
            state idle;
            state planning;
            state executing;
            transition initial then idle;
            transition idle_To_planning
                first idle
                accept det : VisionDetection via visionPort
                do planPath
                then executing;
            transition executing_To_idle
                first executing
                accept complete : CommandCompleted via feedbackPort
                then idle;
        }
    }

    part def VisionSensor {
        port dataPort : VisionDataPort;
        perform action acquireAndProcessImage : CaptureImage;
        exhibit state visionStates {
            entry action initial;
            state standby;
            state processing;
            transition initial then standby;
            transition standby_To_processing
                first standby
                accept trigger : WorkpieceDetected
                do acquireAndProcessImage
                then standby;
        }
    }

    part def SafetyController {
        attribute currentSpeed : ISQ::speed;
        attribute currentForce : ISQ::force;
        port statusPort : SafetyStatusPort;
        perform action enforceLimits;
        perform action haltAndLockJoints;
        perform action resumeMotion;
        constraint { statusPort.status.speedLimit >= currentSpeed }
        exhibit state safetyStates {
            entry action initial;
            state normal;
            state reducedSpeed;
            state protectiveStop;
            state emergencyStop;
            transition initial then normal;
            transition normal_To_reducedSpeed
                first normal
                accept warn : ProximityWarning
                do enforceLimits
                then reducedSpeed;
            transition reducedSpeed_To_normal
                first reducedSpeed
                accept resume : ResumeSignal
                then normal;
            transition normal_To_protectiveStop
                first normal
                accept ps : ProtectiveStopSignal
                then protectiveStop;
            transition protectiveStop_To_normal
                first protectiveStop
                accept resume : ResumeSignal
                then normal;
            transition normal_To_emergencyStop
                first normal
                accept em : EmergencyStopSignal
                do haltAndLockJoints
                then emergencyStop;
            transition reducedSpeed_To_emergencyStop
                first reducedSpeed
                accept em : EmergencyStopSignal
                do haltAndLockJoints
                then emergencyStop;
            transition protectiveStop_To_emergencyStop
                first protectiveStop
                accept em : EmergencyStopSignal
                do haltAndLockJoints
                then emergencyStop;
            transition emergencyStop_To_normal
                first emergencyStop
                accept reset : ResetSignal
                do resumeMotion
                then normal;
        }
    }

    part def RobotArm {
        part base : RevoluteJoint;
        part shoulder : RevoluteJoint;
        part elbow : RevoluteJoint;
        part wrist1 : RevoluteJoint;
        part wrist2 : RevoluteJoint;
        part wrist3 : RevoluteJoint;
        part gripper : Gripper;
        port motionPort : MotionCommandPort;
        port gripperPort : GripperCommandPort;
        port feedbackPort : ControllerFeedbackPort;
        perform action moveToPose;
        perform action stopMotion;
        connect gripperPort to gripper.cmdPort;
        exhibit state armStates {
            entry action initial;
            state idle;
            state moving;
            state stopped;
            transition initial then idle;
            transition idle_To_moving
                first idle
                accept cmd : MotionCommand via motionPort
                do moveToPose
                then moving;
            transition moving_To_idle
                first moving
                accept complete : CommandCompleted
                then idle;
            transition moving_To_stopped
                first moving
                accept em : EmergencyStopSignal
                do stopMotion
                then stopped;
            transition stopped_To_idle
                first stopped
                accept reset : ResetSignal
                then idle;
        }
    }

    part def AutonomousWorkcell {
        part robotArm : RobotArm;
        part robotController : RobotController;
        part visionSensor : VisionSensor;
        part safetyController : SafetyController;
        perform action performPickPlaceSequence : AutomatedSequence;
        perform action haltAllAndLock;

        connect robotController.visionPort to visionSensor.dataPort;
        connect robotController.motionPort to robotArm.motionPort;
        connect robotController.gripperPort to robotArm.gripperPort;
        connect robotController.safetyPort to safetyController.statusPort;
        connect robotArm.feedbackPort to robotController.feedbackPort;

        exhibit state workcellStates parallel {
            state operatingStates {
                entry action initial;
                state initializing;
                state idle;
                state active {
                    do performPickPlaceSequence;
                }
                state manual;
                state teaching;
                transition initial then initializing;
                transition initializing_To_idle
                    first initializing
                    then idle;
                transition idle_To_active
                    first idle
                    accept start : StartSignal
                    then active;
                transition active_To_idle
                    first active
                    accept stop : StopSignal
                    then idle;
                transition active_To_manual
                    first active
                    accept teach : TeachingSignal
                    then manual;
                transition manual_To_idle
                    first manual
                    accept stop : StopSignal
                    then idle;
                transition active_To_teaching
                    first active
                    accept teach : TeachingSignal
                    then teaching;
                transition teaching_To_idle
                    first teaching
                    accept stop : StopSignal
                    then idle;
            }
            state safetyStates {
                entry action initial;
                state normal;
                state reducedSpeed;
                state protectiveStop;
                state emergencyStop {
                    entry haltAllAndLock;
                }
                transition initial then normal;
                transition normal_To_reducedSpeed
                    first normal
                    accept warn : ProximityWarning
                    then reducedSpeed;
                transition reducedSpeed_To_normal
                    first reducedSpeed
                    accept resume : ResumeSignal
                    then normal;
                transition normal_To_protectiveStop
                    first normal
                    accept ps : ProtectiveStopSignal
                    then protectiveStop;
                transition protectiveStop_To_normal
                    first protectiveStop
                    accept resume : ResumeSignal
                    then normal;
                transition normal_To_emergencyStop
                    first normal
                    accept em : EmergencyStopSignal
                    then emergencyStop;
                transition reducedSpeed_To_emergencyStop
                    first reducedSpeed
                    accept em : EmergencyStopSignal
                    then emergencyStop;
                transition protectiveStop_To_emergencyStop
                    first protectiveStop
                    accept em : EmergencyStopSignal
                    then emergencyStop;
                transition emergencyStop_To_normal
                    first emergencyStop
                    accept reset : ResetSignal
                    then normal;
            }
        }
    }

    part cell : AutonomousWorkcell;

    requirement def R1_Positioning {
        text = "The robot shall provide six-axis positioning using base, shoulder, elbow, wrist1, wrist2, and wrist3 revolute joints.";
    }
    requirement def R2_GraspForce {
        text = "The gripper shall grasp objects with a controlled force not exceeding its maxGraspForce.";
    }
    requirement def R3_Safety {
        text = "The safety controller shall enforce speed and force limits and shall stop motion and lock joints on emergency stop.";
    }

    requirement r1 : R1_Positioning;
    requirement r2 : R2_GraspForce;
    requirement r3 : R3_Safety;
    satisfy r1 by cell.robotArm;
    satisfy r2 by cell.robotArm.gripper;
    satisfy r3 by cell.safetyController;
}
