package TerabotS {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    value def SpeedValue :> Real { unit = "m/s"; }
    value def MassValue :> Real { unit = "kg"; }
    value def LengthValue :> Real { unit = "m"; }
    value def VoltageValue :> Real { unit = "V"; }

    item def ObstacleData;
    item def ImageData;
    item def PathPlan;
    item def MotionCommand;
    item def ArmCommand;
    item def MissionPlan;
    item def BatteryStatus;
    item def OperatorCommand;
    item def Power;

    package Requirements {
        requirement def MaxSpeedRequirement {
            doc /* The Terabot-S mobile platform shall travel at speeds up to 3.5 m/s. */
            attribute maxSpeed : SpeedValue = 3.5;
        }
        requirement def PayloadCapacityRequirement {
            doc /* The Manipulator Arm shall lift payloads up to 8 kg. */
            attribute maxPayload : MassValue = 8.0;
        }
        requirement def ArmReachRequirement {
            doc /* The Manipulator Arm shall have a reach of 1 meter. */
            attribute maxReach : LengthValue = 1.0;
        }
        requirement def LidarRangeRequirement {
            doc /* The Lidar Sensor shall detect obstacles up to 50 meters away. */
            attribute maxRange : LengthValue = 50.0;
        }
        requirement def BatteryVoltageRequirement {
            doc /* The system shall be powered by a 48-volt battery pack. */
            attribute nominalVoltage : VoltageValue = 48.0;
        }
        requirement def AutonomousOperationRequirement {
            doc /* The robot shall operate in autonomous mode, following a mission plan. */
        }
        requirement def TeleoperationRequirement {
            doc /* The robot shall support direct human control via teleoperation mode. */
        }
        requirement def AutoRechargeRequirement {
            doc /* The robot shall automatically return to a charging station when battery is low. */
        }
    }

    part def MobilePlatform {
        attribute maxSpeed : SpeedValue = 3.5;
        port motionInput {
            in item command : MotionCommand;
        }
        port powerPort {
            in item power : Power;
        }
        perform action executeMotion {
            in item command : MotionCommand = motionInput.command;
        }
    }

    part def ManipulatorArm {
        attribute maxPayload : MassValue = 8.0;
        attribute maxReach : LengthValue = 1.0;
        attribute jointCount : Integer = 6;
        port armInput {
            in item command : ArmCommand;
        }
        port powerPort {
            in item power : Power;
        }
        perform action executeManipulation {
            in item command : ArmCommand = armInput.command;
        }
    }

    part def LidarSensor {
        attribute maxRange : LengthValue = 50.0;
        port dataOut {
            out item obstacleData : ObstacleData;
        }
        port powerPort {
            in item power : Power;
        }
        perform action scanEnvironment {
            out item obstacleData : ObstacleData = dataOut.obstacleData;
        }
    }

    part def VisionSystem {
        port dataOut {
            out item imageData : ImageData;
        }
        port powerPort {
            in item power : Power;
        }
        perform action captureImage {
            out item imageData : ImageData = dataOut.imageData;
        }
    }

    part def NavigationUnit {
        port lidarIn {
            in item obstacleData : ObstacleData;
        }
        port visionIn {
            in item imageData : ImageData;
        }
        port cmdIn {
            in item missionPlan : MissionPlan;
        }
        port pathOut {
            out item pathPlan : PathPlan;
        }
        port powerPort {
            in item power : Power;
        }
        perform action planPath {
            in item obstacleData : ObstacleData = lidarIn.obstacleData;
            in item imageData : ImageData = visionIn.imageData;
            in item missionPlan : MissionPlan = cmdIn.missionPlan;
            out item pathPlan : PathPlan = pathOut.pathPlan;
        }
    }

    part def ProcessingUnit {
        port operatorIn {
            in item operatorCommand : OperatorCommand;
        }
        port navOut {
            out item missionPlan : MissionPlan;
        }
        port armOut {
            out item armCommand : ArmCommand;
        }
        port batteryIn {
            in item batteryStatus : BatteryStatus;
        }
        port powerPort {
            in item power : Power;
        }
        perform action makeDecisions {
            in item operatorCommand : OperatorCommand = operatorIn.operatorCommand;
            in item batteryStatus : BatteryStatus = batteryIn.batteryStatus;
            out item missionPlan : MissionPlan = navOut.missionPlan;
            out item armCommand : ArmCommand = armOut.armCommand;
        }
    }

    part def BatteryPack {
        attribute nominalVoltage : VoltageValue = 48.0;
        port statusOut {
            out item batteryStatus : BatteryStatus;
        }
        port powerOut {
            out item power : Power;
        }
        perform action monitorCharge {
            out item batteryStatus : BatteryStatus = statusOut.batteryStatus;
        }
    }

    attribute def SigPowerOn;
    attribute def SigPowerOff;
    attribute def SigStartAuto;
    attribute def SigStartTeleop;
    attribute def SigStop;
    attribute def SigLowBattery;
    attribute def SigCharged;
    attribute def SigDocked;

    action def senseEnvironment {
        out item lidarData : ObstacleData;
        out item imageData : ImageData;
        first start;
        then action acquireLidar;
        then action acquireVision;
        then done;
    }
    action def receiveOperatorInput {
        out item operatorCommand : OperatorCommand;
        first start;
        then action pollInterface;
        then done;
    }
    action def navigateToStation {
        out item pathPlan : PathPlan;
        first start;
        then action locateStation;
        then action followReturnPath;
        then done;
    }
    action def dockAndCharge {
        in item power : Power;
        first start;
        then action engageDock;
        then action chargeBattery;
        then done;
    }

    part def TerabotS {
        part mobilePlatform : MobilePlatform;
        part manipulatorArm : ManipulatorArm;
        part lidarSensor : LidarSensor;
        part visionSystem : VisionSystem;
        part processingUnit : ProcessingUnit;
        part navigationUnit : NavigationUnit;
        part batteryPack : BatteryPack;

        connect lidarSensor.dataOut to navigationUnit.lidarIn;
        connect visionSystem.dataOut to navigationUnit.visionIn;
        connect processingUnit.navOut to navigationUnit.cmdIn;
        connect processingUnit.armOut to manipulatorArm.armInput;
        connect navigationUnit.pathOut to mobilePlatform.motionInput;
        connect batteryPack.statusOut to processingUnit.batteryIn;

        connect batteryPack.powerOut to processingUnit.powerPort;
        connect batteryPack.powerOut to mobilePlatform.powerPort;
        connect batteryPack.powerOut to manipulatorArm.powerPort;
        connect batteryPack.powerOut to lidarSensor.powerPort;
        connect batteryPack.powerOut to visionSystem.powerPort;
        connect batteryPack.powerOut to navigationUnit.powerPort;

        state operatingModes {
            entry; then off;
            state off;
            accept SigPowerOn then standby;
            state standby;
            accept SigStartAuto then autonomous;
            accept SigStartTeleop then teleoperation;
            accept SigPowerOff then off;

            state autonomous {
                entry; then senseEnvironment;
                action senseEnvironment;
                accept SigLowBattery then returnToCharge;
                accept SigStop then standby;
            }

            state teleoperation {
                entry; then receiveOperatorInput;
                action receiveOperatorInput;
                accept SigLowBattery then returnToCharge;
                accept SigStop then standby;
            }

            state returnToCharge {
                entry; then navigateToStation;
                action navigateToStation;
                accept SigDocked then charging;
            }

            state charging {
                entry; then dockAndCharge;
                action dockAndCharge;
                accept SigCharged then standby;
            }
        }

        requirement maxSpeedReq : Requirements::MaxSpeedRequirement;
        requirement payloadCapacityReq : Requirements::PayloadCapacityRequirement;
        requirement armReachReq : Requirements::ArmReachRequirement;
        requirement lidarRangeReq : Requirements::LidarRangeRequirement;
        requirement batteryVoltageReq : Requirements::BatteryVoltageRequirement;
        requirement autonomousOpReq : Requirements::AutonomousOperationRequirement;
        requirement teleopReq : Requirements::TeleoperationRequirement;
        requirement autoRechargeReq : Requirements::AutoRechargeRequirement;

        satisfy maxSpeedReq by mobilePlatform.maxSpeed;
        satisfy payloadCapacityReq by manipulatorArm.maxPayload;
        satisfy armReachReq by manipulatorArm.maxReach;
        satisfy lidarRangeReq by lidarSensor.maxRange;
        satisfy batteryVoltageReq by batteryPack.nominalVoltage;
    }
}
