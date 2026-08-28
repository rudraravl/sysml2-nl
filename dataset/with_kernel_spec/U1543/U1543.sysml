package DextreSPDM {
    private import ScalarValues::*;
    private import Quantities::*;
    private import MeasurementReferences::*;
    private import ISQ::*;
    private import SI::*;

    enum def OperatingMode {
        enum teleoperated;
        enum autonomous;
        enum standby;
    }
    enum def HealthStatus {
        enum nominal;
        enum degraded;
        enum fault;
    }

    port def PowerIF {
        out voltage :> ISQ::electricPotential;
        out current :> ISQ::electricCurrent;
    }
    port def ControlIF {
        in command : ScalarValues::String;
        out status : ScalarValues::String;
    }
    port def VideoIF {
        out stream : ScalarValues::String;
    }
    port def TelemetryIF {
        out systemStatus : ScalarValues::String;
    }
    port def GraspIF {
        out graspForce :> ISQ::force;
    }
    port def SensorDataIF {
        out forceValue :> ISQ::force;
        out distanceValue :> ISQ::length;
    }
    port def ArmMountIF;
    port def ToolAccessIF {
        out toolStatus : ScalarValues::String;
    }

    item def OrbitalReplacementUnit {
        attribute mass :> ISQ::mass;
        port graspPoint : ~GraspIF;
    }
    item def MaintenanceTool {
        attribute mass :> ISQ::mass;
        port graspPoint : ~GraspIF;
    }

    part def Dextre;

    part def CentralBody {
        port leftArmMount : ArmMountIF;
        port rightArmMount : ArmMountIF;
    }
    part def CoreElectronics {
        port powerIn : ~PowerIF;
        port controlIn : ControlIF;
    }
    part def ToolStorageUnit {
        attribute bayCount : ScalarValues::Natural = 4;
    }
    part def ToolBay {
        item stowedTool : MaintenanceTool[0..1];
        port toolAccess : ToolAccessIF;
    }
    part def RoboticArm {
        attribute length :> ISQ::length = 3.5 [SI::m];
        attribute maxPayload :> ISQ::mass = 600 [SI::kg];
        part joints : Joint[7];
        part endEffector : EndEffector;
        port powerIn : ~PowerIF;
        port ctrlIn : ControlIF;
        port armMount : ArmMountIF;
    }
    part def Joint {
        attribute jointAngle :> ISQ::planeAngle;
        part jointMotor : Motor;
    }
    part def Motor {
        attribute torque :> ISQ::torque;
    }
    part def EndEffector {
        attribute maxGraspingForce :> ISQ::force = 300 [SI::N];
        part forceSensor : ForceSensor;
        part proximitySensor : ProximitySensor;
        part gripper : Gripper;
        port gripperIF : GraspIF;
        port sensorDataOut : SensorDataIF;
        perform action graspObject {
            first start;
            then action senseProximity;
            then action alignGripper;
            then action applyGripForce;
            then done;
        }
    }
    part def ForceSensor {
        attribute measuredForce :> ISQ::force;
    }
    part def ProximitySensor {
        attribute measuredDistance :> ISQ::length;
    }
    part def Gripper {
        attribute gripForce :> ISQ::force;
    }
    part def VisionSystem {
        attribute alignmentPrecision :> ISQ::length = 0.5 [SI::mm];
        part cameras : Camera[4];
        part ledLights : LEDLight[8];
        port powerIn : ~PowerIF;
        port ctrlIn : ControlIF;
        port videoOut : VideoIF;
    }
    part def Camera {
        attribute resolution : ScalarValues::String = "1920x1080";
    }
    part def LEDLight {
        attribute luminosity :> ISQ::luminousIntensity;
    }
    part def CentralComputer {
        attribute currentMode : OperatingMode = OperatingMode::standby;
        attribute systemHealth : HealthStatus = HealthStatus::nominal;
        port powerIn : ~PowerIF;
        port leftArmCtrl : ~ControlIF;
        port rightArmCtrl : ~ControlIF;
        port visionCtrl : ~ControlIF;
        port videoIn : ~VideoIF;
        port commandIn : ControlIF;
        port telemetryOut : TelemetryIF;
        port sensorDataIn : ~SensorDataIF;
        perform action processCommands {
            first start;
            then action receiveCommand;
            then action coordinateArms;
            then action monitorHealth;
            then done;
        }
        state machine OperationModeStateMachine {
            state Standby;
            state Teleoperated;
            state Autonomous;
            transition t1 from Standby to Teleoperated;
            transition t2 from Standby to Autonomous;
            transition t3 from Teleoperated to Standby;
            transition t4 from Autonomous to Standby;
            transition t5 from Teleoperated to Autonomous;
            transition t6 from Autonomous to Teleoperated;
        }
    }
    part def PowerSystem {
        port issPowerIn : ~PowerIF;
        port armPowerOut : PowerIF;
        port compPowerOut : PowerIF;
        port visionPowerOut : PowerIF;
        perform action convertAndDistributePower {
            first start;
            then action convertPower;
            then action distributePower;
            then done;
        }
    }

    part dextre : Dextre {
        part centralBody : CentralBody {
            part coreElectronics : CoreElectronics;
            part toolStorageUnit : ToolStorageUnit {
                part toolBays : ToolBay[4];
            }
        }
        part leftArm : RoboticArm;
        part rightArm : RoboticArm;
        part visionSystem : VisionSystem;
        part centralComputer : CentralComputer;
        part powerSystem : PowerSystem;

        connect powerSystem.armPowerOut to leftArm.powerIn;
        connect powerSystem.armPowerOut to rightArm.powerIn;
        connect powerSystem.compPowerOut to centralComputer.powerIn;
        connect powerSystem.compPowerOut to centralBody.coreElectronics.powerIn;
        connect powerSystem.visionPowerOut to visionSystem.powerIn;

        connect centralComputer.leftArmCtrl to leftArm.ctrlIn;
        connect centralComputer.rightArmCtrl to rightArm.ctrlIn;
        connect centralComputer.visionCtrl to visionSystem.ctrlIn;
        connect visionSystem.videoOut to centralComputer.videoIn;

        connect leftArm.endEffector.sensorDataOut to centralComputer.sensorDataIn;
        connect rightArm.endEffector.sensorDataOut to centralComputer.sensorDataIn;

        connect centralBody.leftArmMount to leftArm.armMount;
        connect centralBody.rightArmMount to rightArm.armMount;
    }

    requirement def DextreRequirements {
        doc /* System requirements for Dextre SPDM */
        subject spdm : Dextre;
        req armLengthReq {
            text "Each robotic arm shall be approximately 3.5 meters in length.";
            subject spdm;
        }
        req payloadReq {
            text "Each arm shall handle payloads up to 600 kg.";
            subject spdm;
        }
        req graspForceReq {
            text "End effectors shall securely grasp objects with a force up to 300 N.";
            subject spdm;
        }
        req visionPrecisionReq {
            text "Vision system shall enable sub-millimeter alignment precision.";
            subject spdm;
        }
        req toolStorageReq {
            text "Tool storage unit shall contain four bays for specialized tools.";
            subject spdm;
        }
        req jointCountReq {
            text "Each arm shall have seven joints for maximum flexibility.";
            subject spdm;
        }
        req bimanualCoordinationReq {
            text "The central computer shall coordinate both arms for complex bimanual tasks.";
            subject spdm;
        }
        req operatingModeReq {
            text "The system shall support teleoperated, autonomous, and standby modes.";
            subject spdm;
        }
    }
}
