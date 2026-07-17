package TelemanipulatorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def OperatorCommand;
    attribute def VisualFeedback;
    attribute def HapticFeedback;
    attribute def SystemStart;
    attribute def SystemStop;
    attribute def EmergencyStop;

    value def Position3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }

    value def Orientation3D {
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }

    value def ForceVector {
        attribute fx : ForceValue;
        attribute fy : ForceValue;
        attribute fz : ForceValue;
    }

    value def TorqueVector {
        attribute tx : TorqueValue;
        attribute ty : TorqueValue;
        attribute tz : TorqueValue;
    }

    item def MotionCommand {
        attribute targetPosition : Position3D;
        attribute targetOrientation : Orientation3D;
        attribute gripperOpening : LengthValue;
    }

    item def ForceFeedbackData {
        attribute contactForce : ForceVector;
        attribute contactTorque : TorqueVector;
    }

    port def CommandPort {
        out motionCmd : MotionCommand;
    }

    port def FeedbackPort {
        in forceFeedback : ForceFeedbackData;
        in visualFeedback : VisualFeedback;
    }

    port def ControlPort {
        in motionCmd : MotionCommand;
    }

    port def SensorPort {
        out forceFeedback : ForceFeedbackData;
        out visualFeedback : VisualFeedback;
    }

    part def MasterStation {
        port commandOut : CommandPort;
        port feedbackIn : FeedbackPort;

        part inputDevice {
            out operatorPosition : Position3D;
            out operatorOrientation : Orientation3D;
            out gripperControl : LengthValue;
        }

        part hapticDisplay {
            in reflectedForce : ForceVector;
            in reflectedTorque : TorqueVector;
        }

        part visualDisplay {
            in videoStream : VisualFeedback;
        }
    }

    part def SlaveManipulator {
        port controlIn : ControlPort;
        port sensorOut : SensorPort;

        part roboticArm {
            in commandedPosition : Position3D;
            in commandedOrientation : Orientation3D;
            out actualPosition : Position3D;
            out actualOrientation : Orientation3D;
        }

        part endEffector {
            in gripperCommand : LengthValue;
            out gripperState : LengthValue;
            out graspForce : ForceValue;
        }

        part forceTorqueSensor {
            out measuredForce : ForceVector;
            out measuredTorque : TorqueVector;
        }

        part camera {
            out videoOutput : VisualFeedback;
        }
    }

    port def MotionCommandPort {
        out cmd : MotionCommand;
    }

    port def MotionCommandInPort conjugates MotionCommandPort {
        in cmd : MotionCommand;
    }

    part def CommunicationChannel {
        attribute transmissionDelay : TimeValue;
        attribute bandwidth : ISQ::FrequencyValue;

        port masterSide : MotionCommandInPort;
        port slaveSide : MotionCommandPort;
    }

    action def CaptureOperatorMotion {
        out position : Position3D;
        out orientation : Orientation3D;
        out gripperCmd : LengthValue;
    }

    action def GenerateMotionCommand {
        in position : Position3D;
        in orientation : Orientation3D;
        in gripperCmd : LengthValue;
        out command : MotionCommand;
    }

    action def TransmitCommand {
        in command : MotionCommand;
        in delay : TimeValue;
        out transmittedCommand : MotionCommand;
    }

    action def ExecuteMotion {
        in command : MotionCommand;
        out achievedPosition : Position3D;
        out achievedOrientation : Orientation3D;
        out gripperState : LengthValue;
    }

    action def MeasureInteractionForces {
        out contactForce : ForceVector;
        out contactTorque : TorqueVector;
    }

    action def CaptureVisualData {
        out videoFrame : VisualFeedback;
    }

    action def TransmitFeedback {
        in forceData : ForceFeedbackData;
        in visualData : VisualFeedback;
        in delay : TimeValue;
        out transmittedForce : ForceFeedbackData;
        out transmittedVisual : VisualFeedback;
    }

    action def RenderHapticFeedback {
        in forceData : ForceFeedbackData;
    }

    action def DisplayVisualFeedback {
        in visualData : VisualFeedback;
    }

    action def TeleoperationCycle {
        in systemActive : Boolean;
        out cycleComplete : Boolean;

        first start;
        then merge controlLoop;

        then action captureMotion : CaptureOperatorMotion {
            out position : Position3D;
            out orientation : Orientation3D;
            out gripperCmd : LengthValue;
        }

        then action generateCmd : GenerateMotionCommand {
            in position = captureMotion.position;
            in orientation = captureMotion.orientation;
            in gripperCmd = captureMotion.gripperCmd;
            out command : MotionCommand;
        }

        then action transmitCmd : TransmitCommand {
            in command = generateCmd.command;
            in delay : TimeValue;
            out transmittedCommand : MotionCommand;
        }

        then action executeMotion : ExecuteMotion {
            in command = transmitCmd.transmittedCommand;
            out achievedPosition : Position3D;
            out achievedOrientation : Orientation3D;
            out gripperState : LengthValue;
        }

        then action measureForces : MeasureInteractionForces {
            out contactForce : ForceVector;
            out contactTorque : TorqueVector;
        }

        then action captureVideo : CaptureVisualData {
            out videoFrame : VisualFeedback;
        }

        then action transmitFb : TransmitFeedback {
            in forceData : ForceFeedbackData;
            in visualData : VisualFeedback;
            in delay : TimeValue;
            out transmittedForce : ForceFeedbackData;
            out transmittedVisual : VisualFeedback;
        }

        then action renderHaptic : RenderHapticFeedback {
            in forceData = transmitFb.transmittedForce;
        }

        then action displayVisual : DisplayVisualFeedback {
            in visualData = transmitFb.transmittedVisual;
        }

        then decide;
            if systemActive then controlLoop;
            if not systemActive then terminate;

        action terminate;
        then done;
    }

    state machine def TelemanipulatorStateMachine {
        initial state Offline;
        state Standby;
        state Active;
        state Emergency;

        transition offlineToStandby from Offline to Standby
            accept systemStart : SystemStart;

        transition standbyToActive from Standby to Active
            accept operatorReady : OperatorCommand;

        transition activeToStandby from Active to Standby
            accept systemStop : SystemStop;

        transition standbyToOffline from Standby to Offline
            accept systemShutdown : SystemStop;

        transition activeToEmergency from Active to Emergency
            accept emergencyTrigger : EmergencyStop;

        transition emergencyToStandby from Emergency to Standby
            accept emergencyReset : SystemStart;

        state Active {
            do perform teleop : TeleoperationCycle {
                in systemActive : Boolean;
                out cycleComplete : Boolean;
            }
        }
    }

    part def Telemanipulator {
        attribute maxReach : LengthValue;
        attribute maxPayload : MassValue;
        attribute communicationLatency : TimeValue;

        part master : MasterStation;
        part slave : SlaveManipulator;
        part commChannel : CommunicationChannel;

        connect master.commandOut to commChannel.masterSide;
        connect commChannel.slaveSide to slave.controlIn;
        connect slave.sensorOut to master.feedbackIn;

        exhibit stateMachine : TelemanipulatorStateMachine;

        perform action operate : TeleoperationCycle {
            in systemActive : Boolean;
            out cycleComplete : Boolean;
        }
    }

    requirement def PrimaryTelemanipulationFunction {
        doc /* The telemanipulator system shall enable a human operator to perform 
               precise manipulation tasks at a remote or hazardous location by 
               translating operator hand motions to slave manipulator motions while 
               providing real-time visual and force feedback to create an immersive 
               sense of presence and control. */

        subject telemanipulatorSystem : Telemanipulator;

        require constraint motionFidelity {
            doc /* The slave manipulator shall replicate master station commanded 
                   positions and orientations with accuracy better than 2 millimeters 
                   and 0.5 degrees respectively. */
        }

        require constraint forceFidelity {
            doc /* Force feedback shall reflect slave-environment interaction forces 
                   with accuracy within 5 percent of measured values. */
        }

        require constraint latencyBound {
            doc /* Total system latency from operator motion to haptic feedback 
                   shall not exceed 50 milliseconds to maintain stable bilateral control. */
        }
    }

    requirement def SafetyRequirement {
        doc /* The telemanipulator system shall incorporate safety mechanisms to 
               protect both the operator and the remote environment from harm due 
               to system failures or unexpected conditions. */

        subject telemanipulatorSystem : Telemanipulator;

        require constraint emergencyStopResponse {
            doc /* The system shall halt all slave manipulator motion within 
                   100 milliseconds of emergency stop activation. */
        }

        require constraint forceLimit {
            doc /* The slave manipulator shall not exert forces exceeding rated 
                   capacity to prevent damage to the environment or workpiece. */
        }
    }

    part telemanipulatorSystem : Telemanipulator {
        :>> maxReach = 1.5[m];
        :>> maxPayload = 10.0[kg];
        :>> communicationLatency = 20.0[ms];
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import TelemanipulatorSystem::*;
}
