package 'KukaManufacturingCell' {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def StartProduction;
    attribute def PauseCommand;
    attribute def ResumeCommand;
    attribute def EmergencyStopSignal;
    attribute def ResetSignal;
    attribute def WorkpieceDetected;
    attribute def TargetReached;
    attribute def PartGrasped;
    attribute def AssemblyPointReached;
    attribute def PartPlaced;
    attribute def HomeReached;
    attribute def SafetyViolationSignal;

    item def Workpiece {
        attribute position : ISQ::length;
        attribute dimensions : ISQ::length;
        attribute mass : ISQ::mass;
    }

    action def DetectWorkpiece { out workpiece : Workpiece; }
    action def MoveToTarget { in target : Workpiece; }
    action def GraspWorkpiece { in workpiece : Workpiece; }
    action def MoveToAssemblyPoint { in target : Workpiece; }
    action def ReleaseWorkpiece { in workpiece : Workpiece; }
    action def ReturnHome;
    action def HaltAllMotion;
    action def MonitorSafety;

    port def MotionCommandPort {
        out target : Workpiece;
    }
    port def GripperCommandPort {
        out command : Boolean;
    }
    port def VisionDataPort {
        out data : Workpiece;
    }
    port def SafetyStatusPort {
        out violation : SafetyViolationSignal;
    }
    port def PowerPort {
        out power : ISQ::power;
    }

    part def ManipulatorArm {
        attribute reach : ISQ::length = 2.0 [m];
        attribute payload : ISQ::mass = 16.0 [kg];
        attribute repeatability : ISQ::length = 0.03 [mm];
        port powerIn : PowerPort;
        port cmdIn : MotionCommandPort;
        port feedbackOut : MotionCommandPort;
        perform action moveToTarget : MoveToTarget;
        perform action returnHome : ReturnHome;
    }

    part def PneumaticGripper {
        attribute gripForce : ISQ::force;
        port powerIn : PowerPort;
        port cmdIn : GripperCommandPort;
        perform action grasp : GraspWorkpiece;
        perform action release : ReleaseWorkpiece;
    }

    part def VisionSystem {
        port powerIn : PowerPort;
        port dataOut : VisionDataPort;
        perform action detect : DetectWorkpiece;
    }

    part def RobotController {
        port powerIn : PowerPort;
        port visionDataIn : VisionDataPort;
        port armCmdOut : MotionCommandPort;
        port gripperCmdOut : GripperCommandPort;
        port safetyIn : SafetyStatusPort;
        port armFeedbackIn : MotionCommandPort;
    }

    part def SafetyController {
        attribute restrictedZoneEntered : Boolean;
        attribute emergencyStopTriggered : Boolean;
        port powerIn : PowerPort;
        port safetyOut : SafetyStatusPort;
        perform action monitorSafety : MonitorSafety;
    }

    part def PowerDistributionUnit {
        attribute inputVoltage : ScalarValues::Real;
        port powerOut : PowerPort;
    }

    state def CellStates;

    part def ManufacturingCell {
        part manipulatorArm : ManipulatorArm;
        part gripper : PneumaticGripper;
        part visionSystem : VisionSystem;
        part robotController : RobotController;
        part safetyController : SafetyController;
        part pdu : PowerDistributionUnit;

        connect pdu.powerOut to manipulatorArm.powerIn;
        connect pdu.powerOut to robotController.powerIn;
        connect pdu.powerOut to visionSystem.powerIn;
        connect pdu.powerOut to safetyController.powerIn;
        connect pdu.powerOut to gripper.powerIn;
        connect visionSystem.dataOut to robotController.visionDataIn;
        connect robotController.armCmdOut to manipulatorArm.cmdIn;
        connect robotController.gripperCmdOut to gripper.cmdIn;
        connect safetyController.safetyOut to robotController.safetyIn;
        connect manipulatorArm.feedbackOut to robotController.armFeedbackIn;

        exhibit state cellStates : CellStates;
    }

    state cellStates : CellStates {
        action detectWorkpiece : DetectWorkpiece;
        action moveToTargetAction : MoveToTarget;
        action graspWorkpiece : GraspWorkpiece;
        action moveToAssemblyAction : MoveToAssemblyPoint;
        action releaseWorkpiece : ReleaseWorkpiece;
        action returnHomeAction : ReturnHome;
        action haltAllMotion : HaltAllMotion;

        entry; then Standby;

        state Standby;
        accept EmergencyStopSignal then EmergencyStopped;
        accept StartProduction then Automatic;

        state Automatic {
            entry; then Detecting;

            state Detecting {
                do detectWorkpiece;
            }
            accept WorkpieceDetected then MovingToPick;

            state MovingToPick {
                do moveToTargetAction;
            }
            accept TargetReached then Picking;

            state Picking {
                do graspWorkpiece;
            }
            accept PartGrasped then MovingToPlace;

            state MovingToPlace {
                do moveToAssemblyAction;
            }
            accept AssemblyPointReached then Placing;

            state Placing {
                do releaseWorkpiece;
            }
            accept PartPlaced then ReturningHome;

            state ReturningHome {
                do returnHomeAction;
            }
            accept HomeReached then Detecting;

            accept PauseCommand then Paused;
            accept EmergencyStopSignal then EmergencyStopped;
        }

        state Paused;
        accept EmergencyStopSignal then EmergencyStopped;
        accept ResumeCommand then Automatic;

        state EmergencyStopped {
            do haltAllMotion;
        }
        accept ResetSignal then Standby;
    }

    requirement def ReachRequirement {
        doc /* The manipulator arm shall have a reach greater than 2 meters. */
        attribute minReach : ISQ::length;
        assert constraint { minReach > 2.0 [m] }
    }

    requirement def PayloadRequirement {
        doc /* The manipulator arm shall handle payloads up to 16 kilograms. */
        attribute maxPayload : ISQ::mass;
        assert constraint { maxPayload <= 16.0 [kg] }
    }

    requirement def RepeatabilityRequirement {
        doc /* The manipulator arm shall achieve a repeatability of 0.03 millimeters. */
        attribute maxRepeatability : ISQ::length;
        assert constraint { maxRepeatability <= 0.03 [mm] }
    }

    requirement def SafetyRequirement {
        doc /* The cell shall immediately halt all motion upon a safety violation. */
    }
}
