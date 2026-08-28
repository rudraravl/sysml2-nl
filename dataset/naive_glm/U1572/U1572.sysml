package TelemanipulatorSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value types with units ----------
    value def Length_mm :> Real { unit 'mm'; }
    value def Length_m :> Real { unit 'm'; }
    value def Mass_kg :> Real {> Mass; unit 'kg'; }
    value def Force_N :> Real {> Force; unit 'N'; }
    value def Torque_Nm :> Real {> Torque; unit 'N·m'; }
    value def Time_ms :> Real {> TimeValue; unit 'ms'; }
    value def Frequency_Hz :> Real {> Frequency; unit 'Hz'; }
    value def Angle_deg :> Real { unit 'deg'; }

    // ---------- Item definitions ----------
    item def Pose {
        attribute x : Length_mm;
        attribute y : Length_mm;
        attribute z : Length_mm;
        attribute roll : Angle_deg;
        attribute pitch : Angle_deg;
        attribute yaw : Angle_deg;
    }

    item def GripperCommand {
        attribute openClose : Real; // 0 closed .. 1 open
    }

    item def MotionCommand {
        attribute targetPose : Pose;
        attribute gripper : GripperCommand;
    }

    item def Wrench {
        attribute fx : Force_N;
        attribute fy : Force_N;
        attribute fz : Force_N;
        attribute tx : Torque_Nm;
        attribute ty : Torque_Nm;
        attribute tz : Torque_Nm;
    }

    item def VideoFrame {
        attribute frameId : Integer;
        attribute timestamp : Time_ms;
        attribute encoding : String;
    }

    item def Telemetry {
        attribute measuredPose : Pose;
        attribute measuredWrench : Wrench;
        attribute gripperPosition : Real;
        attribute timestamp : Time_ms;
    }

    // ---------- Port definitions ----------
    port def MotionCmdPort {
        out motionCmd : MotionCommand;
    }

    port def TelemetryPort {
        out telemetry : Telemetry;
    }

    port def VideoPort {
        out video : VideoFrame;
    }

    port def HapticPort {
        out wrench : Wrench;
    }

    port def OperatorInputPort {
        out pose : Pose;
        out gripperCmd : GripperCommand;
    }

    port def DisplayPort {
        in video : VideoFrame;
    }

    // ---------- Master Station ----------
    part def MasterStation {
        attribute maxHapticForce : Force_N = 20.0;
        attribute maxHapticTorque : Torque_Nm = 1.5;

        port operatorIn : OperatorInputPort;
        port displayIn : VideoPort;
        port hapticIn : TelemetryPort;
        port cmdOut : MotionCmdPort;

        part handController : HandController {
            port operatorIn : OperatorInputPort;
            port hapticIn : HapticPort;
            port cmdOut : MotionCmdPort;

            attribute samplingRate : Frequency_Hz = 1000.0;

            action captureOperatorInput {
                in operatorPose : Pose;
                in operatorGripper : GripperCommand;
                out cmd : MotionCommand;
            }

            action renderHaptics {
                in wrench : Wrench;
            }
        }

        part visualDisplay : VisualDisplay {
            port videoIn : VideoPort;
            attribute refreshRate : Frequency_Hz = 60.0;

            action renderVideo {
                in frame : VideoFrame;
            }
        }

        part hapticController : HapticController {
            port telemetryIn : TelemetryPort;
            port hapticOut : HapticPort;

            attribute forceScale : Real = 1.0;

            action computeHapticFeedback {
                in telemetry : Telemetry;
                out wrench : Wrench;
            }
        }

        part masterController : MasterController {
            port operatorIn : OperatorInputPort;
            port telemetryIn : TelemetryPort;
            port cmdOut : MotionCmdPort;

            attribute maxDelay : Time_ms = 20.0;

            action generateMotionCommand {
                in pose : Pose;
                in gripper : GripperCommand;
                in telemetry : Telemetry;
                out cmd : MotionCommand;
            }
        }

        connection operatorToController connect operatorIn to masterController.operatorIn;
        connection telemetryToController connect hapticIn to masterController.telemetryIn;
        connection telemetryToHaptic connect hapticIn to hapticController.telemetryIn;
        connection controllerToCmd connect masterController.cmdOut to cmdOut;
        connection hapticToHand connect hapticController.hapticOut to handController.hapticIn;
        connection operatorToHand connect operatorIn to handController.operatorIn;
        connection handToCmd connect handController.cmdOut to cmdOut;
        connection videoToDisplay connect displayIn to visualDisplay.videoIn;
    }

    part def HandController {
        port operatorIn : OperatorInputPort;
        port hapticIn : HapticPort;
        port cmdOut : MotionCmdPort;
        attribute samplingRate : Frequency_Hz = 1000.0;
    }

    part def VisualDisplay {
        port videoIn : VideoPort;
        attribute refreshRate : Frequency_Hz = 60.0;
    }

    part def HapticController {
        port telemetryIn : TelemetryPort;
        port hapticOut : HapticPort;
        attribute forceScale : Real = 1.0;
    }

    part def MasterController {
        port operatorIn : OperatorInputPort;
        port telemetryIn : TelemetryPort;
        port cmdOut : MotionCmdPort;
        attribute maxDelay : Time_ms = 20.0;
    }

    // ---------- Slave Manipulator ----------
    part def SlaveManipulator {
        attribute reach : Length_m = 1.5;
        attribute maxPayload : Mass_kg = 10.0;
        attribute maxContactForce : Force_N = 80.0;
        attribute maxContactTorque : Torque_Nm = 5.0;

        port cmdIn : MotionCmdPort;
        port telemetryOut : TelemetryPort;
        port videoOut : VideoPort;

        part arm : RoboticArm {
            port cmdIn : MotionCmdPort;
            port telemetryOut : TelemetryPort;
            attribute reach : Length_m = 1.5;
            attribute maxPayload : Mass_kg = 10.0;

            action executeMotion {
                in cmd : MotionCommand;
                out measuredPose : Pose;
            }

            action enforceForceLimits {
                in wrench : Wrench;
                out limitedWrench : Wrench;
            }
        }

        part gripper : Gripper {
            attribute maxOpening : Length_mm = 80.0;
            attribute maxGripForce : Force_N = 40.0;

            action actuateGripper {
                in cmd : GripperCommand;
                out position : Real;
            }
        }

        part forceTorqueSensor : ForceTorqueSensor {
            port wrenchOut : HapticPort;
            attribute measurementRange : Force_N = 120.0;
            attribute samplingRate : Frequency_Hz = 1000.0;

            action measureWrench {
                out wrench : Wrench;
            }
        }

        part camera : Camera {
            port videoOut : VideoPort;
            attribute resolution : String = "1920x1080";
            attribute frameRate : Frequency_Hz = 30.0;

            action captureFrame {
                out frame : VideoFrame;
            }
        }

        part slaveController : SlaveController {
            port cmdIn : MotionCmdPort;
            port telemetryOut : TelemetryPort;
            attribute controlRate : Frequency_Hz = 500.0;

            action planTrajectory {
                in cmd : MotionCommand;
                out jointTargets : Pose;
            }

            action assembleTelemetry {
                in pose : Pose;
                in wrench : Wrench;
                in gripperPos : Real;
                out telemetry : Telemetry;
            }
        }

        connection cmdToController connect cmdIn to slaveController.cmdIn;
        connection controllerToArm connect slaveController.cmdIn to arm.cmdIn;
        connection armTelemetry connect arm.telemetryOut to slaveController.telemetryOut;
        connection sensorToController connect forceTorqueSensor.wrenchOut to slaveController.telemetryOut;
        connection controllerTelemetryOut connect slaveController.telemetryOut to telemetryOut;
        connection cameraVideo connect camera.videoOut to videoOut;
    }

    part def RoboticArm {
        port cmdIn : MotionCmdPort;
        port telemetryOut : TelemetryPort;
        attribute reach : Length_m = 1.5;
        attribute maxPayload : Mass_kg = 10.0;
    }

    part def Gripper {
        attribute maxOpening : Length_mm = 80.0;
        attribute maxGripForce : Force_N = 40.0;
    }

    part def ForceTorqueSensor {
        port wrenchOut : HapticPort;
        attribute measurementRange : Force_N = 120.0;
        attribute samplingRate : Frequency_Hz = 1000.0;
    }

    part def Camera {
        port videoOut : VideoPort;
        attribute resolution : String = "1920x1080";
        attribute frameRate : Frequency_Hz = 30.0;
    }

    part def SlaveController {
        port cmdIn : MotionCmdPort;
        port telemetryOut : TelemetryPort;
        attribute controlRate : Frequency_Hz = 500.0;
    }

    // ---------- Communication Channel ----------
    part def CommunicationChannel {
        attribute maxLatency : Time_ms = 20.0;
        attribute bandwidthMbps : Real = 100.0;
        attribute packetLoss : Real = 0.001;

        port masterCmdIn : MotionCmdPort;
        port slaveCmdOut : MotionCmdPort;
        port slaveTelemetryIn : TelemetryPort;
        port masterTelemetryOut : TelemetryPort;
        port slaveVideoIn : VideoPort;
        port masterVideoOut : VideoPort;

        action transmitMotionCommand {
            in cmd : MotionCommand;
            out delayedCmd : MotionCommand;
        }

        action transmitTelemetry {
            in telemetry : Telemetry;
            out delayedTelemetry : Telemetry;
        }

        action transmitVideo {
            in frame : VideoFrame;
            out delayedFrame : VideoFrame;
        }
    }

    // ---------- Operator ----------
    part def Operator {
        port handOut : OperatorInputPort;
        port eyeIn : VideoPort;
        port handHapticIn : HapticPort;

        action observeScene {
            in frame : VideoFrame;
        }

        action moveHand {
            out pose : Pose;
            out gripper : GripperCommand;
        }

        action feelForces {
            in wrench : Wrench;
        }
    }

    // ---------- Environment ----------
    part def RemoteEnvironment {
        attribute description : String;
        part objects : Object[*];

        item def Object {
            attribute mass : Mass_kg;
            attribute location : Pose;
        }
    }

    // ---------- System ----------
    part def TelemanipulatorSystem {
        attribute systemReach : Length_m = 1.5;
        attribute systemPayload : Mass_kg = 10.0;
        attribute maxLatency : Time_ms = 20.0;
        attribute maxContactForce : Force_N = 80.0;

        part operator : Operator;
        part masterStation : MasterStation;
        part slaveManipulator : SlaveManipulator;
        part communicationChannel : CommunicationChannel;
        part remoteEnvironment : RemoteEnvironment;

        connection operatorToMaster connect operator.handOut to masterStation.operatorIn;
        connection videoToOperator connect masterStation.displayIn to operator.eyeIn;
        connection hapticToOperator connect masterStation.hapticIn to operator.handHapticIn;

        connection masterToChannel connect masterStation.cmdOut to communicationChannel.masterCmdIn;
        connection channelToSlave connect communicationChannel.slaveCmdOut to slaveManipulator.cmdIn;

        connection slaveTelemetryToChannel connect slaveManipulator.telemetryOut to communicationChannel.slaveTelemetryIn;
        connection channelTelemetryToMaster connect communicationChannel.masterTelemetryOut to masterStation.hapticIn;

        connection slaveVideoToChannel connect slaveManipulator.videoOut to communicationChannel.slaveVideoIn;
        connection channelVideoToMaster connect communicationChannel.masterVideoOut to masterStation.displayIn;

        // ---------- System state machine ----------
        state def TelemanipulatorStateMachine {
            state Offline;
            state Standby;
            state Active;
            state Emergency;

            transition off_to_standby
                from Offline to Standby
                when operator.requestsInitialization;

            transition standby_to_active
                from Standby to Active
                when operator.engagesTeleoperation;

            transition active_to_standby
                from Active to Standby
                when operator.disengagesTeleoperation;

            transition any_to_emergency
                from {Standby, Active} to Emergency
                when operator.triggersEmergencyStop or slaveManipulator.forceLimitExceeded;

            transition emergency_to_offline
                from Emergency to Offline
                when operator.acknowledgesEmergency;

            entry Offline {
                action powerOffSystems;
            }
            entry Standby {
                action initializeCalibration;
                action verifyCommunication;
            }
            entry Active {
                action startControlLoop;
            }
            entry Emergency {
                action haltAllMotion;
                action retractGripper;
            }
        }

        attribute stateMachine : TelemanipulatorStateMachine;

        // ---------- Continuous control loop action ----------
        action def ControlLoop {
            in operatorPose : Pose;
            in operatorGripper : GripperCommand;
            in slaveTelemetry : Telemetry;
            in slaveVideo : VideoFrame;
            out motionCmd : MotionCommand;
            out hapticWrench : Wrench;
            out displayFrame : VideoFrame;

            action captureInput {
                out pose : Pose;
                out gripper : GripperCommand;
            }

            action generateCommand {
                in pose : Pose;
                in gripper : GripperCommand;
                in telemetry : Telemetry;
                out cmd : MotionCommand;
            }

            action transmitCommand {
                in cmd : MotionCommand;
                out slaveCmd : MotionCommand;
            }

            action executeSlave {
                in cmd : MotionCommand;
                out measuredPose : Pose;
                out measuredWrench : Wrench;
                out frame : VideoFrame;
            }

            action transmitFeedback {
                in pose : Pose;
                in wrench : Wrench;
                in frame : VideoFrame;
                out delayedTelemetry : Telemetry;
                out delayedFrame : VideoFrame;
            }

            action renderFeedback {
                in telemetry : Telemetry;
                in frame : VideoFrame;
                out haptic : Wrench;
                out display : VideoFrame;
            }

            flow captureInput.pose -> generateCommand.pose;
            flow captureInput.gripper -> generateCommand.gripper;
            flow slaveTelemetry -> generateCommand.telemetry;
            flow generateCommand.cmd -> transmitCommand.cmd;
            flow transmitCommand.slaveCmd -> executeSlave.cmd;
            flow executeSlave.measuredPose -> transmitFeedback.pose;
            flow executeSlave.measuredWrench -> transmitFeedback.wrench;
            flow executeSlave.frame -> transmitFeedback.frame;
            flow transmitFeedback.delayedTelemetry -> renderFeedback.telemetry;
            flow transmitFeedback.delayedFrame -> renderFeedback.frame;
            flow renderFeedback.haptic -> hapticWrench;
            flow renderFeedback.display -> displayFrame;
        }
    }

    // ---------- Requirements ----------
    requirement def TelepresenceRequirement {
        subject system : TelemanipulatorSystem;
        requirement {
            system shall provide bidirectional teleoperation between operator and slave manipulator.
        }
    }

    requirement def ReachRequirement {
        subject slave : SlaveManipulator;
        attribute requiredReach : Length_m = 1.5;
        requirement {
            slave.reach shall be equal to requiredReach.
        }
    }

    requirement def PayloadRequirement {
        subject slave : SlaveManipulator;
        attribute requiredPayload : Mass_kg = 10.0;
        requirement {
            slave.maxPayload shall be greater than or equal to requiredPayload.
        }
    }

    requirement def LatencyRequirement {
        subject channel : CommunicationChannel;
        attribute maxAllowedLatency : Time_ms = 20.0;
        requirement {
            channel.maxLatency shall be less than or equal to maxAllowedLatency.
        }
    }

    requirement def ForceSafetyRequirement {
        subject slave : SlaveManipulator;
        attribute maxSafeForce : Force_N = 80.0;
        requirement {
            slave.maxContactForce shall be less than or equal to maxSafeForce.
        }
    }

    requirement def HapticFidelityRequirement {
        subject master : MasterStation;
        requirement {
            master shall render contact forces and torques measured at the slave wrist to the operator's hand.
        }
    }

    requirement def VisualFeedbackRequirement {
        subject master : MasterStation;
        requirement {
            master shall display live video captured by the slave camera.
        }
    }

    requirement def EmergencyStopRequirement {
        subject system : TelemanipulatorSystem;
        requirement {
            system shall enter Emergency state and halt all motion immediately upon emergency trigger or force limit violation.
        }
    }

    requirement def OperationalStatesRequirement {
        subject system : TelemanipulatorSystem;
        requirement {
            system shall support Offline, Standby, Active, and Emergency operational states.
        }
    }

    requirement def ClosedLoopStabilityRequirement {
        subject system : TelemanipulatorSystem;
        requirement {
            system shall maintain stable closed-loop control under the specified maximum latency.
        }
    }

    // ---------- Requirement satisfaction ----------
    satisfaction telepresenceSatisfies by TelemanipulatorSystem satisfies TelepresenceRequirement;
    satisfaction reachSatisfies by SlaveManipulator satisfies ReachRequirement;
    satisfaction payloadSatisfies by SlaveManipulator satisfies PayloadRequirement;
    satisfaction latencySatisfies by CommunicationChannel satisfies LatencyRequirement;
    satisfaction forceSatisfies by SlaveManipulator satisfies ForceSafetyRequirement;
    satisfaction hapticSatisfies by MasterStation satisfies HapticFidelityRequirement;
    satisfaction visualSatisfies by MasterStation satisfies VisualFeedbackRequirement;
    satisfaction emergencySatisfies by TelemanipulatorSystem satisfies EmergencyStopRequirement;
    satisfaction statesSatisfies by TelemanipulatorSystem satisfies OperationalStatesRequirement;
    satisfaction stabilitySatisfies by TelemanipulatorSystem satisfies ClosedLoopStabilityRequirement;

}
