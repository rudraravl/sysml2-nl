package TelemanipulatorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def Pose3D {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
    }

    attribute def GripperCmd {
        attribute openClose : Boolean;
    }

    item def MotionCommand {
        attribute endEffectorPose : Pose3D;
        attribute gripperCmd : GripperCmd;
    }

    item def VisualFeedback {
        attribute frameData : String;
    }

    item def HapticFeedback {
        attribute contactForce : Force;
        attribute contactTorque : Torque;
    }

    item def SlaveStatus {
        attribute currentPose : Pose3D;
        attribute measuredForce : Force;
        attribute measuredTorque : Torque;
        attribute gripperOpen : Boolean;
        attribute emergency : Boolean;
    }

    attribute def StartUpSignal;
    attribute def EngageSignal;
    attribute def DisengageSignal;
    attribute def ShutDownSignal;
    attribute def EmergencyStopSignal;
    attribute def ResetSignal;

    port def MasterCommandPort {
        out motionCommand : MotionCommand;
        in visualFeedback : VisualFeedback;
        in hapticFeedback : HapticFeedback;
        in slaveStatus : SlaveStatus;
    }

    port def SlaveCommandPort {
        in motionCommand : MotionCommand;
        out visualFeedback : VisualFeedback;
        out hapticFeedback : HapticFeedback;
        out slaveStatus : SlaveStatus;
    }

    port def ChannelForwardPort {
        in motionCommand : MotionCommand;
        out visualFeedback : VisualFeedback;
        out hapticFeedback : HapticFeedback;
        out slaveStatus : SlaveStatus;
    }

    port def ChannelReturnPort {
        out motionCommand : MotionCommand;
        in visualFeedback : VisualFeedback;
        in hapticFeedback : HapticFeedback;
        in slaveStatus : SlaveStatus;
    }

    action def CaptureOperatorMotion {
        out motionCommand : MotionCommand;
    }

    action def RenderVisualFeed {
        in visualFeedback : VisualFeedback;
    }

    action def RenderHapticFeedback {
        in hapticFeedback : HapticFeedback;
    }

    action def ExecuteMotion {
        in motionCommand : MotionCommand;
        out currentPose : Pose3D;
    }

    action def CaptureVision {
        out visualFeedback : VisualFeedback;
    }

    action def MeasureForceTorque {
        out hapticFeedback : HapticFeedback;
    }

    action def AssembleSlaveStatus {
        in currentPose : Pose3D;
        in hapticFeedback : HapticFeedback;
        in motionCommand : MotionCommand;
        out status : SlaveStatus;
    }

    action def TransmitCommand {
        in motionCommand : MotionCommand;
        out forwarded : MotionCommand;
    }

    action def TransmitFeedback {
        in visualFeedback : VisualFeedback;
        in hapticFeedback : HapticFeedback;
        in slaveStatus : SlaveStatus;
        out fbVisual : VisualFeedback;
        out fbHaptic : HapticFeedback;
        out fbStatus : SlaveStatus;
    }

    action def HaltAllMotion;

    action def TeleopControlLoop {
        first start;
        then merge loopMerge;
        then action capture : CaptureOperatorMotion;
        then action transmitCmd : TransmitCommand;
        then action execute : ExecuteMotion;
        then action vision : CaptureVision;
        then action ft : MeasureForceTorque;
        then action assemble : AssembleSlaveStatus;
        then action feedback : TransmitFeedback;
        then action renderVisual : RenderVisualFeed;
        then action renderHaptic : RenderHapticFeedback;
        then decide;
            if assemble.status.emergency then done;
            else loopMerge;

        flow capture.motionCommand to transmitCmd.motionCommand;
        flow transmitCmd.forwarded to execute.motionCommand;
        flow execute.currentPose to assemble.currentPose;
        flow ft.hapticFeedback to assemble.hapticFeedback;
        flow capture.motionCommand to assemble.motionCommand;
        flow vision.visualFeedback to feedback.visualFeedback;
        flow ft.hapticFeedback to feedback.hapticFeedback;
        flow assemble.status to feedback.slaveStatus;
        flow feedback.fbVisual to renderVisual.visualFeedback;
        flow feedback.fbHaptic to renderHaptic.hapticFeedback;
    }

    state def TelemanipulatorStates {
        entry; then Offline;
        state Offline;
        accept StartUpSignal then Standby;
        accept ShutDownSignal then done;
        state Standby;
        accept EngageSignal then Active;
        accept EmergencyStopSignal then Emergency;
        state Active {
            do action controlLoop : TeleopControlLoop;
        }
        accept DisengageSignal then Standby;
        accept EmergencyStopSignal then Emergency;
        state Emergency {
            do action haltAllMotion : HaltAllMotion;
        }
        accept ResetSignal then Offline;
    }

    part def InputDevice {
        attribute maxReach : Length = 1.5 [m];
        port cmdOut {
            out motionCommand : MotionCommand;
        }
        perform action captureMotion : CaptureOperatorMotion;
    }

    part def VisualDisplay {
        port videoIn {
            in visualFeedback : VisualFeedback;
        }
        perform action renderVisual : RenderVisualFeed;
    }

    part def HapticDisplay {
        attribute maxFeedbackForce : Force = 50 [N];
        port hapticIn {
            in hapticFeedback : HapticFeedback;
        }
        perform action renderHaptic : RenderHapticFeedback;
    }

    part def Gripper {
        attribute isOpen : Boolean;
    }

    part def Camera {
        port videoOut {
            out visualFeedback : VisualFeedback;
        }
        perform action captureVision : CaptureVision;
    }

    part def ForceTorqueSensor {
        attribute maxForce : Force = 50 [N];
        attribute maxTorque : Torque = 5 ['N·m'];
        port ftOut {
            out hapticFeedback : HapticFeedback;
        }
        perform action measureFT : MeasureForceTorque;
    }

    part def RoboticArm {
        attribute reach : Length = 1.5 [m];
        attribute payloadCapacity : Mass = 10 [kg];
        part gripper : Gripper;
        part camera : Camera;
        part forceTorqueSensor : ForceTorqueSensor;
        port motionIn {
            in motionCommand : MotionCommand;
        }
        port statusOut {
            out slaveStatus : SlaveStatus;
        }
        perform action executeMotion : ExecuteMotion;
    }

    part def MasterStation {
        part inputDevice : InputDevice;
        part visualDisplay : VisualDisplay;
        part hapticDisplay : HapticDisplay;
        port masterCmdPort : MasterCommandPort;
    }

    part def SlaveManipulator {
        part arm : RoboticArm;
        port slaveCmdPort : SlaveCommandPort;
    }

    part def CommunicationChannel {
        attribute latency : Duration = 5 [ms];
        port forwardPort : ChannelForwardPort;
        port returnPort : ChannelReturnPort;
        perform action transmitCmd : TransmitCommand;
        perform action transmitFb : TransmitFeedback;
    }

    requirement def ReachRequirement {
        doc /* The slave manipulator shall have a reach of at least 1.5 meters. */
        attribute requiredReach : Length = 1.5 [m];
    }

    requirement def PayloadRequirement {
        doc /* The slave manipulator shall handle payloads up to 10 kg. */
        attribute requiredPayload : Mass = 10 [kg];
    }

    requirement def LatencyRequirement {
        doc /* The communication delay shall be less than 10 milliseconds. */
        attribute maxLatency : Duration = 10 [ms];
    }

    requirement def ForceLimitRequirement {
        doc /* The slave manipulator shall limit contact force to 50 newtons. */
        attribute maxExertedForce : Force = 50 [N];
    }

    part telemanipulatorSystem {
        part masterStation : MasterStation;
        part slaveManipulator : SlaveManipulator;
        part communicationChannel : CommunicationChannel;

        connect masterStation.masterCmdPort.motionCommand to communicationChannel.forwardPort.motionCommand;
        connect communicationChannel.forwardPort.visualFeedback to masterStation.masterCmdPort.visualFeedback;
        connect communicationChannel.forwardPort.hapticFeedback to masterStation.masterCmdPort.hapticFeedback;
        connect communicationChannel.forwardPort.slaveStatus to masterStation.masterCmdPort.slaveStatus;

        connect communicationChannel.returnPort.motionCommand to slaveManipulator.slaveCmdPort.motionCommand;
        connect slaveManipulator.slaveCmdPort.visualFeedback to communicationChannel.returnPort.visualFeedback;
        connect slaveManipulator.slaveCmdPort.hapticFeedback to communicationChannel.returnPort.hapticFeedback;
        connect slaveManipulator.slaveCmdPort.slaveStatus to communicationChannel.returnPort.slaveStatus;

        exhibit state operationalStates : TelemanipulatorStates;

        satisfy reachReq : ReachRequirement;
        satisfy payloadReq : PayloadRequirement;
        satisfy latencyReq : LatencyRequirement;
        satisfy forceLimitReq : ForceLimitRequirement;
    }
}
