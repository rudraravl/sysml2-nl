package AutonomousMobileManipulator {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def TaskAssigned;
    attribute def StartStandby;
    attribute def StartAutonomous;
    attribute def StartManual;
    attribute def TaskComplete;
    attribute def TargetFound;
    attribute def PathReady;
    attribute def AtPosition;
    attribute def GraspSuccess;
    attribute def GraspFail;
    attribute def ForceIncreased;
    attribute def AtDropoff;
    attribute def ReleaseComplete;
    attribute def ObstacleDetected;
    attribute def ClearZone;
    attribute def EmergencyStop;
    attribute def FaultDetected;
    attribute def FaultCleared;
    attribute def ResetSystem;

    action def ScanEnvironment {
        out targetFound : Boolean;
    }
    action def PlanPath {
        out pathReady : Boolean;
    }
    action def MoveToTarget;
    action def GraspObject {
        in force : ForceValue;
        out success : Boolean;
    }
    action def PlanPathToDropoff;
    action def MoveToDropoff;
    action def ReleaseObject;
    action def MonitorSafetyZone {
        out obstacleDetected : Boolean;
    }
    action def TriggerEmergencyStop;

    state def RobotStates;

    part def Battery {
        attribute capacity : EnergyValue;
        attribute chargeLevel : Real;
        port powerOut;
    }
    part def MobileBase {
        attribute maxSpeed : SpeedValue = 1.5 [m/s];
        port powerIn;
        port controlIn;
    }
    part def ManipulatorArm {
        attribute numberOfJoints : Integer = 6;
        attribute reach : LengthValue = 1.2 [m];
        attribute maxPayload : MassValue = 15 [kg];
        port powerIn;
        port controlIn;
    }
    part def Gripper {
        attribute maxGraspForce : ForceValue = 50 [N];
        port powerIn;
        port controlIn;
    }
    part def VisionSystem {
        port powerIn;
        port dataOut;
    }
    part def SafetyController {
        attribute safetyZoneRadius : LengthValue = 2.0 [m];
        port powerIn;
        port sensorIn;
        port stopSignalOut;
    }
    part def MasterController {
        port powerIn;
        port visionDataIn;
        port safetySignalIn;
        port baseControlOut;
        port armControlOut;
        port gripperControlOut;
    }

    part def Robot {
        part battery : Battery;
        part mobileBase : MobileBase;
        part manipulatorArm : ManipulatorArm;
        part gripper : Gripper;
        part visionSystem : VisionSystem;
        part safetyController : SafetyController;
        part masterController : MasterController;

        connect battery.powerOut to mobileBase.powerIn;
        connect battery.powerOut to manipulatorArm.powerIn;
        connect battery.powerOut to gripper.powerIn;
        connect battery.powerOut to visionSystem.powerIn;
        connect battery.powerOut to safetyController.powerIn;
        connect battery.powerOut to masterController.powerIn;

        connect visionSystem.dataOut to masterController.visionDataIn;
        connect safetyController.stopSignalOut to masterController.safetySignalIn;
        connect masterController.baseControlOut to mobileBase.controlIn;
        connect masterController.armControlOut to manipulatorArm.controlIn;
        connect masterController.gripperControlOut to gripper.controlIn;

        action scanEnvironment : ScanEnvironment;
        action planPathAction : PlanPath;
        action moveToTargetAction : MoveToTarget;
        action graspObjectFirst : GraspObject;
        action graspObjectRetry : GraspObject;
        action planPathToDropoffAction : PlanPathToDropoff;
        action moveToDropoffAction : MoveToDropoff;
        action releaseObjectAction : ReleaseObject;
        action monitorSafetyZoneAction : MonitorSafetyZone;
        action triggerEmergencyStopAction : TriggerEmergencyStop;

        state robotStates : RobotStates parallel {
            state operationalModes {
                entry; then idle;
                state idle;
                accept TaskAssigned then standby;
                state standby;
                accept StartAutonomous then autonomous;
                accept StartManual then manual;
                state manual;
                accept StartStandby then standby;
                state autonomous {
                    entry; then scanning;
                    state scanning {
                        do scanEnvironment;
                    }
                    accept TargetFound then planning;
                    state planning {
                        do planPathAction;
                    }
                    accept PathReady then approaching;
                    state approaching {
                        do moveToTargetAction;
                    }
                    accept AtPosition then grasping;
                    state grasping {
                        do graspObjectFirst;
                    }
                    accept GraspSuccess then transporting;
                    accept GraspFail then retrying;
                    state retrying {
                        do graspObjectRetry;
                    }
                    accept ForceIncreased then grasping;
                    state transporting {
                        entry planPathToDropoffAction;
                        do moveToDropoffAction;
                    }
                    accept AtDropoff then releasing;
                    state releasing {
                        do releaseObjectAction;
                    }
                    accept ReleaseComplete then scanning;
                }
                accept TaskComplete then standby;
                accept FaultDetected then fault;
                state fault;
                accept ResetSystem then idle;
            }
            state safetyMonitoring {
                entry; then monitoring;
                state monitoring {
                    do monitorSafetyZoneAction;
                }
                accept ObstacleDetected then emergencyStopped;
                state emergencyStopped {
                    do triggerEmergencyStopAction;
                }
                accept ClearZone then monitoring;
            }
        }
    }

    requirement SpeedRequirement {
        text "The mobile base shall navigate at speeds up to 1.5 m/s.";
    }
    requirement ReachRequirement {
        text "The manipulator arm shall have a reach of 1.2 meters.";
    }
    requirement PayloadRequirement {
        text "The manipulator arm shall lift objects weighing up to 15 kilograms.";
    }
    requirement SafetyZoneRequirement {
        text "The safety controller shall monitor a 2-meter safety zone and trigger an emergency stop upon obstacle detection.";
    }
}
