package Robonaut {
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Power :> Real { unit 'W'; }
    value type Energy :> Real { unit 'J'; }
    value type BatteryCapacity :> Real { unit 'Ah'; }
    value type Force :> Real { unit 'N'; }
    value type Torque :> Real { unit 'N·m'; }
    value type Mass :> Real { unit 'kg'; }
    value type Distance :> Real { unit 'm'; }
    value type Angle :> Real { unit 'rad'; }
    value type AngularVelocity :> Real { unit 'rad/s'; }
    value type LinearVelocity :> Real { unit 'm/s'; }
    value type Temperature :> Real { unit 'K'; }
    value type Duration :> Real { unit 's'; }
    value type Percentage :> Real { unit '%'; }

    // ===== Item Definitions =====
    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def ImageData {
        attribute width : Integer;
        attribute height : Integer;
    }

    item def DepthData {
        attribute range : Distance;
    }

    item def SceneMap {
        attribute objects : String[*];
    }

    item def JointCommand {
        attribute targetAngle : Angle;
        attribute targetVelocity : AngularVelocity;
    }

    item def GraspCommand {
        attribute graspForce : Force;
    }

    item def ControlCommand {
        attribute priority : Integer;
    }

    item def VisionData {
        attribute leftImage : ImageData;
        attribute rightImage : ImageData;
        attribute depth : DepthData;
    }

    item def TelemetryData {
        attribute status : String;
        attribute batteryLevel : Percentage;
        attribute timestamp : Duration;
    }

    // ===== Port Definitions =====
    port def PowerOut {
        out power : ElectricalPower;
    }

    port def PowerIn {
        in power : ElectricalPower;
    }

    port def DataOut {
        out data : ANY[*];
    }

    port def DataIn {
        in data : ANY[*];
    }

    // ===== Requirement Definitions =====
    requirement def RobonautSystemRequirement {
        doc /* The Robonaut shall be a mobile humanoid robot system for dexterous manipulation in human environments. */
        attribute systemName : String = "Robonaut";
    }

    requirement def MobilityRequirement {
        doc /* The Robonaut shall be mounted on a four-wheeled mobility base for workspace traversal. */
        attribute wheelCount : Integer = 4;
        attribute maxSpeed : LinearVelocity = 1.5 [m/s];
    }

    requirement def ManipulationRequirement {
        doc /* The Robonaut shall coordinate two arms with five-fingered hands for two-handed manipulation. */
        attribute armCount : Integer = 2;
        attribute fingerCountPerHand : Integer = 5;
    }

    requirement def VisionRequirement {
        doc /* The Robonaut shall perceive its environment in 3D using stereo cameras and a depth sensor. */
    }

    requirement def PowerRequirement {
        doc /* The Robonaut shall be powered by a self-contained high-capacity battery distributing electricity to all components. */
        attribute minCapacity : BatteryCapacity = 50 [Ah];
        attribute nominalVoltage : Voltage = 48 [V];
    }

    requirement def TelemetryRequirement {
        doc /* The Robonaut shall send telemetry data including status and battery level to a monitoring system. */
    }

    requirement def ManipulationSequenceRequirement {
        doc /* The Robonaut shall follow the sequence: perceive, plan, move, grasp, manipulate, release. */
    }

    // ===== Part Definitions =====

    part def Wheel {
        attribute radius : Distance = 0.15 [m];
        attribute maxSpeed : LinearVelocity = 2.0 [m/s];
        port powerIn : PowerIn;
        port cmdIn : DataIn;
    }

    part def MobilityBase {
        attribute maxSpeed : LinearVelocity = 1.5 [m/s];
        part wheels : Wheel[4];
        port powerIn : PowerIn;
        port cmdIn : DataIn;

        connection connect powerIn to wheels.powerIn;
        connection connect cmdIn to wheels.cmdIn;
    }

    part def Joint {
        attribute minAngle : Angle = -3.14 [rad];
        attribute maxAngle : Angle = 3.14 [rad];
        attribute maxTorque : Torque = 60 [N·m];
        port cmdIn : DataIn;
        port powerIn : PowerIn;
    }

    part def Finger {
        attribute id : Integer;
        attribute maxForce : Force = 30 [N];
        port cmdIn : DataIn;
        port powerIn : PowerIn;
    }

    part def Hand {
        attribute maxGraspForce : Force = 100 [N];
        part fingers : Finger[5] {
            :>> id = sequence(1, 5);
        }
        port cmdIn : DataIn;
        port powerIn : PowerIn;

        connection connect powerIn to fingers.powerIn;
        connection connect cmdIn to fingers.cmdIn;
    }

    part def Arm {
        attribute side : String;
        attribute reach : Distance = 0.8 [m];
        attribute payloadCapacity : Mass = 10 [kg];
        part shoulder : Joint;
        part elbow : Joint;
        part hand : Hand;
        port cmdIn : DataIn;
        port powerIn : PowerIn;

        connection connect powerIn to shoulder.powerIn;
        connection connect powerIn to elbow.powerIn;
        connection connect powerIn to hand.powerIn;
        connection connect cmdIn to shoulder.cmdIn;
        connection connect cmdIn to elbow.cmdIn;
        connection connect cmdIn to hand.cmdIn;
    }

    part def StereoCameras {
        attribute baseline : Distance = 0.12 [m];
        port imageOut : DataOut;
        port powerIn : PowerIn;
    }

    part def DepthSensor {
        attribute maxRange : Distance = 5.0 [m];
        port depthOut : DataOut;
        port powerIn : PowerIn;
    }

    part def Head {
        part stereoCameras : StereoCameras;
        part depthSensor : DepthSensor;
        port imageOut : DataOut;
        port depthOut : DataOut;
        port powerIn : PowerIn;

        connection connect powerIn to stereoCameras.powerIn;
        connection connect powerIn to depthSensor.powerIn;
        connection connect stereoCameras.imageOut to imageOut;
        connection connect depthSensor.depthOut to depthOut;
    }

    part def Torso {
        attribute mass : Mass = 15 [kg];
        port powerIn : PowerIn;
        port cmdIn : DataIn;
    }

    part def ControlComputer {
        attribute clockSpeed : Real = 2.0;
        port imageIn : DataIn;
        port depthIn : DataIn;
        port cmdOut : DataOut;
        port telemetryOut : DataOut;
        port powerIn : PowerIn;
    }

    part def BatterySystem {
        attribute capacity : BatteryCapacity = 60 [Ah];
        attribute nominalVoltage : Voltage = 48 [V];
        attribute chargeLevel : Percentage = 100 [%];
        port powerOut : PowerOut;
    }

    part def MonitoringSystem {
        port telemetryIn : DataIn;
    }

    part def UpperBody {
        part head : Head;
        part torso : Torso;
        part leftArm : Arm { :>> side = "left"; }
        part rightArm : Arm { :>> side = "right"; }
        part controlComputer : ControlComputer;
        port powerIn : PowerIn;
        port cmdOut : DataOut;
        port telemetryOut : DataOut;

        connection connect powerIn to head.powerIn;
        connection connect powerIn to torso.powerIn;
        connection connect powerIn to leftArm.powerIn;
        connection connect powerIn to rightArm.powerIn;
        connection connect powerIn to controlComputer.powerIn;

        connection connect head.imageOut to controlComputer.imageIn;
        connection connect head.depthOut to controlComputer.depthIn;

        connection connect controlComputer.cmdOut to torso.cmdIn;
        connection connect controlComputer.cmdOut to leftArm.cmdIn;
        connection connect controlComputer.cmdOut to rightArm.cmdIn;
        connection connect controlComputer.cmdOut to cmdOut;
        connection connect controlComputer.telemetryOut to telemetryOut;
    }

    part def Robonaut {
        attribute systemName : String = "Robonaut";
        part mobilityBase : MobilityBase;
        part upperBody : UpperBody;
        part batterySystem : BatterySystem;
        part monitoringSystem : MonitoringSystem;

        connection connect batterySystem.powerOut to upperBody.powerIn;
        connection connect batterySystem.powerOut to mobilityBase.powerIn;
        connection connect upperBody.cmdOut to mobilityBase.cmdIn;
        connection connect upperBody.telemetryOut to monitoringSystem.telemetryIn;

        exhibit RobonautOperation;
    }

    // ===== Requirement Usages and Satisfaction =====
    requirement r1 : RobonautSystemRequirement;
    requirement r2 : MobilityRequirement;
    requirement r3 : ManipulationRequirement;
    requirement r4 : VisionRequirement;
    requirement r5 : PowerRequirement;
    requirement r6 : TelemetryRequirement;
    requirement r7 : ManipulationSequenceRequirement;

    part robonaut : Robonaut;

    satisfy r1 by robonaut;
    satisfy r2 by robonaut;
    satisfy r3 by robonaut;
    satisfy r4 by robonaut;
    satisfy r5 by robonaut;
    satisfy r6 by robonaut;
    satisfy r7 by robonaut;

    // ===== State Machine Definition =====
    state def RobonautOperation {
        entry; then perceiving;

        state perceiving {
            entry /* Acquire stereo images and depth data, build 3D scene map, identify target object. */;
            do /* Process vision data and detect objects. */;
        }
        transition from perceiving to planning
            when /* target object identified */;

        state planning {
            entry /* Plan motion trajectories for both arms and grasp strategy. */;
        }
        transition from planning to moving
            when /* trajectory plan complete */;

        state moving {
            entry /* Move arms along planned trajectories to approach the target object. */;
            do /* Continuously monitor joint positions. */;
        }
        transition from moving to grasping
            when /* arms within reach of object */;

        state grasping {
            entry /* Close fingers with required force to grasp the object. */;
        }
        transition from grasping to manipulating
            when /* grasp confirmed */;

        state manipulating {
            entry /* Perform the manipulation task using one or both hands. */;
            do /* Send telemetry data including status and battery level. */;
        }
        transition from manipulating to releasing
            when /* manipulation task complete */;

        state releasing {
            entry /* Open fingers and release the object. */;
        }
        transition from releasing to perceiving
            when /* object released and arms retracted */;
    }

    // ===== Action Definition =====
    action def PerformManipulationTask {
        in targetObject : String;
        in requiredForce : Force;
        out success : Boolean;

        action perceiveEnvironment {
            out visionData : VisionData;
            out sceneMap : SceneMap;
        }

        action planMotion {
            in visionData : VisionData;
            in sceneMap : SceneMap;
            out leftArmCommands : JointCommand[*];
            out rightArmCommands : JointCommand[*];
            out graspCommand : GraspCommand;
        }

        action approachObject {
            in leftArmCommands : JointCommand[*];
            in rightArmCommands : JointCommand[*];
        }

        action graspObject {
            in graspCommand : GraspCommand;
        }

        action manipulate {
            in requiredForce : Force;
            out telemetry : TelemetryData;
        }

        action releaseObject;

        flow perceiveEnvironment.visionData to planMotion.visionData;
        flow perceiveEnvironment.sceneMap to planMotion.sceneMap;
        flow planMotion.leftArmCommands to approachObject.leftArmCommands;
        flow planMotion.rightArmCommands to approachObject.rightArmCommands;
        flow planMotion.graspCommand to graspObject.graspCommand;
        flow graspObject to manipulate;
        flow manipulate to releaseObject;
        flow releaseObject to success;
    }
}
