package TelemanipulatorSystemModel {

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def Percentage :> ScalarValues::Real;
    attribute def Latency :> ISQ::time;
    attribute def ForceMagnitude :> ISQ::force;
    attribute def TorqueMagnitude :> ISQ::torque;
    attribute def PositionError :> ISQ::length;
    attribute def VelocityMagnitude :> ISQ::speed;
    attribute def ElectricPotential :> ISQ::electricPotential;
    attribute def ElectricCurrent :> ISQ::electricCurrent;
    attribute def DataRate :> ScalarValues::Real;
    attribute def GripperAperture :> ISQ::length;

    enum def ManipulatorMode {
        enum idle;
        enum initializing;
        enum teleoperated;
        enum autonomousHold;
        enum faulted;
        enum emergencyStop;
        enum shutdown;
    }

    enum def CommandPriority {
        enum routine;
        enum safetyCritical;
        enum emergency;
    }

    item def OperatorMotionCommand {
        attribute priority : CommandPriority;
        attribute commandedPoseX : ISQ::length;
        attribute commandedPoseY : ISQ::length;
        attribute commandedPoseZ : ISQ::length;
        attribute commandedRoll : ISQ::planeAngle;
        attribute commandedPitch : ISQ::planeAngle;
        attribute commandedYaw : ISQ::planeAngle;
        attribute commandedGrip : GripperAperture;
        attribute timestamp : ISQ::time;
    }

    item def HapticForceFeedback {
        attribute forceX : ForceMagnitude;
        attribute forceY : ForceMagnitude;
        attribute forceZ : ForceMagnitude;
        attribute torqueX : TorqueMagnitude;
        attribute torqueY : TorqueMagnitude;
        attribute torqueZ : TorqueMagnitude;
        attribute contactConfidence : Percentage;
    }

    item def VideoStream {
        attribute frameRate : ScalarValues::Real;
        attribute resolutionWidth : ScalarValues::Integer;
        attribute resolutionHeight : ScalarValues::Integer;
        attribute compressionLatency : Latency;
        attribute dataRate : DataRate;
    }

    item def ManipulatorTelemetry {
        attribute measuredPoseX : ISQ::length;
        attribute measuredPoseY : ISQ::length;
        attribute measuredPoseZ : ISQ::length;
        attribute measuredRoll : ISQ::planeAngle;
        attribute measuredPitch : ISQ::planeAngle;
        attribute measuredYaw : ISQ::planeAngle;
        attribute jointTemperatureMax : ISQ::thermodynamicTemperature;
        attribute controllerHealth : Percentage;
        attribute contactForceMagnitude : ForceMagnitude;
    }

    item def PowerFlow {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
        attribute availableEnergy : ISQ::energy;
    }

    item def SafetyEvent {
        attribute emergencyStopRequested : Boolean;
        attribute collisionDetected : Boolean;
        attribute workspaceBoundaryExceeded : Boolean;
        attribute communicationLost : Boolean;
        attribute severity : CommandPriority;
    }

    port def MotionCommandPort {
        in item command : OperatorMotionCommand;
    }

    port def HapticFeedbackPort {
        out item feedback : HapticForceFeedback;
    }

    port def VideoOutputPort {
        out item stream : VideoStream;
    }

    port def TelemetryPort {
        out item telemetry : ManipulatorTelemetry;
    }

    port def PowerInputPort {
        in item power : PowerFlow;
    }

    port def SafetyPort {
        inout item safetyEvent : SafetyEvent;
    }

    port def ToolInterfacePort {
        in item command : OperatorMotionCommand;
        out item telemetry : ManipulatorTelemetry;
        out item feedback : HapticForceFeedback;
    }

    action def CaptureOperatorIntent {
        in item rawMotion : OperatorMotionCommand;
        out item filteredMotion : OperatorMotionCommand;

        attribute tremorFilterCutoff : ScalarValues::Real = 8.0;
        attribute scaleFactor : ScalarValues::Real = 0.20;
    }

    action def TransformMasterToSlaveMotion {
        in item operatorCommand : OperatorMotionCommand;
        out item manipulatorCommand : OperatorMotionCommand;

        attribute coordinateTransformLatency : Latency = 0.004 [SI::s];
        attribute motionScaleRatio : ScalarValues::Real = 0.20;
    }

    action def RegulateManipulatorMotion {
        in item requestedMotion : OperatorMotionCommand;
        out item measuredTelemetry : ManipulatorTelemetry;
        out item hapticReaction : HapticForceFeedback;

        attribute closedLoopUpdatePeriod : Latency = 0.002 [SI::s];
        attribute maximumAllowedPositionError : PositionError = 0.0015 [SI::m];
        attribute maximumEndEffectorSpeed : VelocityMagnitude = 0.25 [SI::m / SI::s];
    }

    action def RenderRemoteScene {
        in item telemetry : ManipulatorTelemetry;
        out item video : VideoStream;

        attribute nominalFrameRate : ScalarValues::Real = 60.0;
        attribute maximumSceneLatency : Latency = 0.080 [SI::s];
    }

    action def EnforceSafetyLimits {
        in item telemetry : ManipulatorTelemetry;
        in item command : OperatorMotionCommand;
        out item event : SafetyEvent;

        attribute workspaceRadiusLimit : ISQ::length = 0.75 [SI::m];
        attribute maximumContactForce : ForceMagnitude = 45.0 [SI::N];
        attribute communicationTimeout : Latency = 0.150 [SI::s];
    }

    action def PerformTelemanipulation {
        in item operatorInput : OperatorMotionCommand;
        out item remoteTelemetry : ManipulatorTelemetry;
        out item forceFeedback : HapticForceFeedback;
        out item sceneVideo : VideoStream;

        first start;

        then action capture : CaptureOperatorIntent {
            in rawMotion = operatorInput;
        }

        then action transform : TransformMasterToSlaveMotion {
            in operatorCommand = capture.filteredMotion;
        }

        then fork;

            action regulate : RegulateManipulatorMotion {
                in requestedMotion = transform.manipulatorCommand;
            }

            action safety : EnforceSafetyLimits {
                in command = transform.manipulatorCommand;
                in telemetry = regulate.measuredTelemetry;
            }

        then join;

        then action render : RenderRemoteScene {
            in telemetry = regulate.measuredTelemetry;
        }

        then done;

        bind remoteTelemetry = regulate.measuredTelemetry;
        bind forceFeedback = regulate.hapticReaction;
        bind sceneVideo = render.video;
    }

    part def OperatorConsole {
        attribute displayBrightness : ScalarValues::Real = 450.0;
        attribute hapticWorkspaceDiameter : ISQ::length = 0.30 [SI::m];
        attribute commandedMotionResolution : ISQ::length = 0.0002 [SI::m];

        port motionOut : MotionCommandPort;
        port hapticIn : HapticFeedbackPort;
        port videoIn : VideoOutputPort;
        port telemetryIn : TelemetryPort;
        port safety : SafetyPort;

        part masterController {
            attribute degreesOfFreedom : ScalarValues::Integer = 7;
            attribute inputSamplingPeriod : Latency = 0.001 [SI::s];
            attribute gripCommandRange : GripperAperture = 0.090 [SI::m];
        }

        part hapticDisplay {
            attribute maximumFeedbackForce : ForceMagnitude = 12.0 [SI::N];
            attribute maximumFeedbackTorque : TorqueMagnitude = 1.2 [SI::N * SI::m];
            attribute feedbackBandwidth : ScalarValues::Real = 120.0;
        }

        part visualDisplay {
            attribute widthPixels : ScalarValues::Integer = 3840;
            attribute heightPixels : ScalarValues::Integer = 2160;
            attribute nominalRefreshRate : ScalarValues::Real = 60.0;
        }
    }

    part def CommunicationLink {
        attribute commandLatency : Latency = 0.020 [SI::s];
        attribute feedbackLatency : Latency = 0.020 [SI::s];
        attribute videoLatency : Latency = 0.060 [SI::s];
        attribute packetLossRate : Percentage = 0.1;
        attribute encrypted : Boolean = true;

        port operatorCommandSide : MotionCommandPort;
        port manipulatorCommandSide : MotionCommandPort;
        port manipulatorFeedbackSide : HapticFeedbackPort;
        port operatorFeedbackSide : HapticFeedbackPort;
        port manipulatorVideoSide : VideoOutputPort;
        port operatorVideoSide : VideoOutputPort;
        port manipulatorTelemetrySide : TelemetryPort;
        port operatorTelemetrySide : TelemetryPort;
        port safetyA : SafetyPort;
        port safetyB : SafetyPort;
    }

    part def RemoteManipulator {
        attribute reachableRadius : ISQ::length = 0.85 [SI::m];
        attribute payloadCapacity : ISQ::mass = 5.0 [SI::kg];
        attribute poseRepeatability : PositionError = 0.0008 [SI::m];
        attribute endEffectorSpeedLimit : VelocityMagnitude = 0.25 [SI::m / SI::s];

        port commandIn : MotionCommandPort;
        port hapticOut : HapticFeedbackPort;
        port telemetryOut : TelemetryPort;
        port powerIn : PowerInputPort;
        port safety : SafetyPort;
        port toolInterface : ToolInterfacePort;

        part base {
            attribute mass : ISQ::mass = 42.0 [SI::kg];
            attribute mountingStiffness : ScalarValues::Real = 1.0e7;
        }

        part shoulderJoint {
            attribute jointRange : ISQ::planeAngle = 3.14 [SI::rad];
            attribute torqueLimit : TorqueMagnitude = 160.0 [SI::N * SI::m];
            attribute encoderResolution : ISQ::planeAngle = 0.00001 [SI::rad];
        }

        part elbowJoint {
            attribute jointRange : ISQ::planeAngle = 2.70 [SI::rad];
            attribute torqueLimit : TorqueMagnitude = 120.0 [SI::N * SI::m];
            attribute encoderResolution : ISQ::planeAngle = 0.00001 [SI::rad];
        }

        part wristAssembly {
            attribute degreesOfFreedom : ScalarValues::Integer = 3;
            attribute torqueLimit : TorqueMagnitude = 28.0 [SI::N * SI::m];
            attribute angularVelocityLimit : ScalarValues::Real = 2.0;
        }

        part gripper {
            attribute maximumAperture : GripperAperture = 0.090 [SI::m];
            attribute minimumAperture : GripperAperture = 0.000 [SI::m];
            attribute gripForceLimit : ForceMagnitude = 80.0 [SI::N];
        }

        part forceTorqueSensor {
            attribute forceRange : ForceMagnitude = 200.0 [SI::N];
            attribute torqueRange : TorqueMagnitude = 20.0 [SI::N * SI::m];
            attribute measurementPeriod : Latency = 0.001 [SI::s];
        }

        part controller {
            attribute servoLoopPeriod : Latency = 0.001 [SI::s];
            attribute safetyLoopPeriod : Latency = 0.002 [SI::s];
            attribute nominalHealth : Percentage = 100.0;
        }
    }

    part def RemotePerceptionUnit {
        attribute cameraBaseline : ISQ::length = 0.065 [SI::m];
        attribute illuminationPower : ISQ::power = 25.0 [SI::W];
        attribute depthRange : ISQ::length = 2.0 [SI::m];

        port videoOut : VideoOutputPort;
        port telemetryOut : TelemetryPort;
        port powerIn : PowerInputPort;
        port safety : SafetyPort;

        part leftCamera {
            attribute widthPixels : ScalarValues::Integer = 1920;
            attribute heightPixels : ScalarValues::Integer = 1080;
            attribute frameRate : ScalarValues::Real = 60.0;
        }

        part rightCamera {
            attribute widthPixels : ScalarValues::Integer = 1920;
            attribute heightPixels : ScalarValues::Integer = 1080;
            attribute frameRate : ScalarValues::Real = 60.0;
        }

        part illuminator {
            attribute luminousFlux : ScalarValues::Real = 3200.0;
            attribute dimmable : Boolean = true;
        }
    }

    part def SafetySupervisor {
        attribute maximumPermittedLatency : Latency = 0.120 [SI::s];
        attribute emergencyStopReactionTime : Latency = 0.030 [SI::s];
        attribute enabled : Boolean = true;

        port operatorSafety : SafetyPort;
        port linkSafety : SafetyPort;
        port manipulatorSafety : SafetyPort;
        port perceptionSafety : SafetyPort;

        state safetyState : ManipulatorMode {
            entry action initializeSafetyMonitors;
            state idle;
            state initializing;
            state teleoperated;
            state autonomousHold;
            state faulted;
            state emergencyStop;
            state shutdown;

            transition first idle;
            transition idle_to_initializing
                first idle
                then initializing;

            transition initializing_to_teleoperated
                first initializing
                then teleoperated;

            transition teleoperated_to_autonomousHold
                first teleoperated
                accept SafetyEvent
                if communicationLost
                then autonomousHold;

            transition teleoperated_to_faulted
                first teleoperated
                accept SafetyEvent
                if collisionDetected or workspaceBoundaryExceeded
                then faulted;

            transition any_to_emergencyStop
                first teleoperated
                accept SafetyEvent
                if emergencyStopRequested
                then emergencyStop;

            transition hold_to_teleoperated
                first autonomousHold
                then teleoperated;

            transition faulted_to_shutdown
                first faulted
                then shutdown;

            transition emergencyStop_to_shutdown
                first emergencyStop
                then shutdown;
        }
    }

    part def PowerSubsystem {
        attribute nominalVoltage : ElectricPotential = 48.0 [SI::V];
        attribute continuousCurrentLimit : ElectricCurrent = 35.0 [SI::A];
        attribute backupEnergyCapacity : ISQ::energy = 120000.0 [SI::J];

        port manipulatorPower : PowerInputPort;
        port perceptionPower : PowerInputPort;
    }

    part def TelemanipulatorSystem {
        doc
        /* The primary function of the Telemanipulator System is to enable a human operator to manipulate objects in a remote, hazardous, inaccessible, or precision workspace by translating operator hand and grip motions into controlled remote manipulator motion while returning visual, telemetry, and force feedback to preserve situational awareness and safe contact interaction. */

        attribute currentMode : ManipulatorMode = ManipulatorMode::idle;
        attribute maximumEndToEndCommandLatency : Latency = 0.100 [SI::s];
        attribute maximumRoundTripHapticLatency : Latency = 0.080 [SI::s];
        attribute nominalAvailability : Percentage = 99.5;

        port operatorCommand : MotionCommandPort;
        port operatorHapticFeedback : HapticFeedbackPort;
        port operatorVideoFeedback : VideoOutputPort;
        port operatorTelemetryFeedback : TelemetryPort;
        port externalSafety : SafetyPort;

        part console : OperatorConsole;
        part link : CommunicationLink;
        part manipulator : RemoteManipulator;
        part perception : RemotePerceptionUnit;
        part supervisor : SafetySupervisor;
        part power : PowerSubsystem;

        connect console.motionOut to link.operatorCommandSide;
        connect link.manipulatorCommandSide to manipulator.commandIn;

        connect manipulator.hapticOut to link.manipulatorFeedbackSide;
        connect link.operatorFeedbackSide to console.hapticIn;

        connect perception.videoOut to link.manipulatorVideoSide;
        connect link.operatorVideoSide to console.videoIn;

        connect manipulator.telemetryOut to link.manipulatorTelemetrySide;
        connect link.operatorTelemetrySide to console.telemetryIn;

        connect power.manipulatorPower to manipulator.powerIn;
        connect power.perceptionPower to perception.powerIn;

        connect console.safety to supervisor.operatorSafety;
        connect link.safetyA to supervisor.linkSafety;
        connect manipulator.safety to supervisor.manipulatorSafety;
        connect perception.safety to supervisor.perceptionSafety;
        connect externalSafety to supervisor.operatorSafety;

        perform action telemanipulate : PerformTelemanipulation {
            in operatorInput = operatorCommand.command;
            out remoteTelemetry = operatorTelemetryFeedback.telemetry;
            out forceFeedback = operatorHapticFeedback.feedback;
            out sceneVideo = operatorVideoFeedback.stream;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : TelemanipulatorSystem;

        doc
        /* The system shall allow a human operator to remotely manipulate objects by converting operator motion commands into coordinated remote manipulator motion and by providing visual, telemetry, and haptic feedback. */

        require constraint {
            system.maximumEndToEndCommandLatency <= 0.100 [SI::s]
        }

        require constraint {
            system.maximumRoundTripHapticLatency <= 0.080 [SI::s]
        }
    }

    requirement def RemoteManipulationAccuracyRequirement {
        subject manipulator : RemoteManipulator;

        doc
        /* The remote manipulator shall position its end effector with sufficient accuracy for precise contact tasks. */

        require constraint {
            manipulator.poseRepeatability <= 0.001 [SI::m]
        }

        require constraint {
            manipulator.endEffectorSpeedLimit <= 0.25 [SI::m / SI::s]
        }
    }

    requirement def OperatorFeedbackRequirement {
        subject console : OperatorConsole;

        doc
        /* The operator console shall present continuous visual and force feedback sufficient for closed-loop teleoperation. */

        require constraint {
            console.hapticDisplay.maximumFeedbackForce >= 10.0 [SI::N]
        }

        require constraint {
            console.visualDisplay.nominalRefreshRate >= 60.0
        }
    }

    requirement def SafetyRequirement {
        subject supervisor : SafetySupervisor;

        doc
        /* The safety supervisor shall command hold, fault, or emergency stop modes when communication loss, workspace violation, collision, or emergency stop events occur. */

        require constraint {
            supervisor.emergencyStopReactionTime <= 0.030 [SI::s]
        }

        require constraint {
            supervisor.maximumPermittedLatency <= 0.120 [SI::s]
        }
    }

    requirement def PerceptionRequirement {
        subject perception : RemotePerceptionUnit;

        doc
        /* The perception unit shall provide stereoscopic visual information from the remote workspace for operator situational awareness. */

        require constraint {
            perception.leftCamera.frameRate >= 60.0
        }

        require constraint {
            perception.rightCamera.frameRate >= 60.0
        }

        require constraint {
            perception.depthRange >= 2.0 [SI::m]
        }
    }

    satisfy PrimaryFunctionRequirement by TelemanipulatorSystem;
    satisfy RemoteManipulationAccuracyRequirement by RemoteManipulator;
    satisfy OperatorFeedbackRequirement by OperatorConsole;
    satisfy SafetyRequirement by SafetySupervisor;
    satisfy PerceptionRequirement by RemotePerceptionUnit;

}