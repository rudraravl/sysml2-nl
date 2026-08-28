package RobonautSystem {
    private import ScalarValues::*;

    attribute def Voltage :> Real;
    attribute def Current :> Real;
    attribute def Force :> Real;
    attribute def Mass :> Real;
    attribute def Distance :> Real;
    attribute def Angle :> Real;

    item def ElectricPower;
    item def VisualData;
    item def ControlCommand;
    item def TelemetryData;
    item def TargetObject;

    port def PowerOutPort {
        out power : ElectricPower;
    }
    port def PowerInPort {
        in power : ElectricPower;
    }
    port def VisualOutPort {
        out visualData : VisualData;
    }
    port def VisualInPort {
        in visualData : VisualData;
    }
    port def CommandOutPort {
        out command : ControlCommand;
    }
    port def CommandInPort {
        in command : ControlCommand;
    }
    port def TelemetryOutPort {
        out telemetry : TelemetryData;
    }
    port def TelemetryInPort {
        in telemetry : TelemetryData;
    }
    port def StatusOutPort {
        out chargeLevel : Real;
    }
    port def StatusInPort {
        in chargeLevel : Real;
    }

    requirement def MobilityRequirement {
        doc /* The robot must be able to move on four wheels. */
        attribute minSpeed : Distance;
    }
    requirement def DexterityRequirement {
        doc /* The robot must have two five-fingered hands for dexterous manipulation. */
        attribute numFingers : Integer = 5;
    }
    requirement def ManipulationSequenceRequirement {
        doc /* The robot must follow a specific sequence for manipulation. */
    }

    part def BatterySystem {
        attribute capacity : Voltage;
        port powerOut : PowerOutPort;
        port statusOut : StatusOutPort;
    }

    part def Wheel {
        attribute radius : Distance;
    }

    part def MobilityBase {
        part wheels[4] : Wheel;
        port driveCommandPort : CommandInPort;
        port powerIn : PowerInPort;
    }

    part def StereoCamera {
        port visualOut : VisualOutPort;
        port powerIn : PowerInPort;
    }

    part def DepthSensor {
        port depthOut : VisualOutPort;
        port powerIn : PowerInPort;
    }

    part def Head {
        part stereoCameras : StereoCamera;
        part depthSensor : DepthSensor;
        port powerIn : PowerInPort;
    }

    part def Joint {
        attribute maxAngle : Angle;
        port controlPort : CommandInPort;
        port powerIn : PowerInPort;
    }

    part def Finger {
        attribute maxForce : Force;
        port controlPort : CommandInPort;
        port powerIn : PowerInPort;
    }

    part def Hand {
        part fingers[5] : Finger;
        port graspCommandPort : CommandInPort;
        port powerIn : PowerInPort;
    }

    part def Arm {
        part shoulderJoint : Joint;
        part elbowJoint : Joint;
        part hand : Hand;
        port controlPort : CommandInPort;
        port powerIn : PowerInPort;
    }

    part def Torso {
        port powerIn : PowerInPort;
        port controlPort : CommandInPort;
    }

    part def ControlComputer {
        port visualIn : VisualInPort;
        port commandOut : CommandOutPort;
        port telemetryOut : TelemetryOutPort;
        port powerIn : PowerInPort;
        port batteryStatusIn : StatusInPort;

        state machine ControlStates {
            initial init;
            state perceiving;
            state planning;
            state moving;
            state grasping;
            state manipulating;
            state releasing;
            transition init to perceiving;
            transition perceiving to planning;
            transition planning to moving;
            transition moving to grasping;
            transition grasping to manipulating;
            transition manipulating to releasing;
            transition releasing to perceiving;
        }
    }

    part def MonitoringSystem {
        port telemetryIn : TelemetryInPort;
    }

    part def Robonaut {
        part battery : BatterySystem;
        part mobilityBase : MobilityBase;
        part torso : Torso;
        part head : Head;
        part leftArm : Arm;
        part rightArm : Arm;
        part controlComputer : ControlComputer;
        part monitoringSystem : MonitoringSystem;

        connect battery.powerOut to mobilityBase.powerIn;
        connect battery.powerOut to torso.powerIn;
        connect battery.powerOut to head.powerIn;
        connect battery.powerOut to leftArm.powerIn;
        connect battery.powerOut to rightArm.powerIn;
        connect battery.powerOut to controlComputer.powerIn;

        connect head.stereoCameras.visualOut to controlComputer.visualIn;
        connect head.depthSensor.depthOut to controlComputer.visualIn;
        connect controlComputer.commandOut to torso.controlPort;
        connect controlComputer.commandOut to mobilityBase.driveCommandPort;
        connect controlComputer.commandOut to leftArm.controlPort;
        connect controlComputer.commandOut to rightArm.controlPort;

        connect battery.statusOut to controlComputer.batteryStatusIn;
        connect controlComputer.telemetryOut to monitoringSystem.telemetryIn;
    }

    action def ManipulationSequence {
        in target : TargetObject;
        first start;
        then action perceiveEnvironment;
        then action identifyTarget;
        then action planMotion;
        then action moveArms;
        then action graspObject;
        then action manipulateObject;
        then action releaseObject;
        then done;
    }

    requirement mobilityReq : MobilityRequirement {
        doc /* The Robonaut shall have a four-wheeled mobility base. */
    }
    requirement dexterityReq : DexterityRequirement {
        doc /* The Robonaut shall have two five-fingered hands. */
    }
    requirement manipulationSeqReq : ManipulationSequenceRequirement {
        doc /* The Robonaut shall follow a manipulation sequence. */
    }

    part robonaut : Robonaut;

    satisfy mobilityReq by robonaut;
    satisfy dexterityReq by robonaut;
    satisfy manipulationSeqReq by robonaut;
}
