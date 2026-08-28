package TeleroboticSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def AngleValue :> ISQ::PlaneAngleValue;
    attribute def ForceValue :> ISQ::ForceValue;
    attribute def TorqueValue :> ISQ::TorqueValue;
    attribute def LengthValue :> ISQ::LengthValue;
    attribute def DataRateValue :> Real;
    attribute def ConnectionStatusKind;

    attribute def SignalWeakened;
    attribute def SignalRestored;
    attribute def SignalLost;
    attribute def ProximityWarningSignal;
    attribute def EmergencyStopSignal;
    attribute def ResetSignal;
    attribute def GraspDetectedSignal;
    attribute def OpenCommandSignal;
    attribute def CloseCommandSignal;

    attribute def VideoFrame;
    attribute def VideoStream {
        attribute videoData : VideoFrame;
    }
    attribute def ForceTorqueReading {
        attribute force : ForceValue;
        attribute torque : TorqueValue;
    }
    attribute def PoseReading {
        attribute position : LengthValue[3];
        attribute orientation : AngleValue[4];
    }
    attribute def ProximityReading {
        attribute distance : LengthValue;
    }
    attribute def JointCommand {
        attribute targetAngles : AngleValue[6];
    }
    attribute def GripperCommand {
        attribute targetOpening : LengthValue;
        attribute forceLimit : ForceValue;
    }
    attribute def OperatorCommand {
        attribute targetPose : PoseReading;
        attribute gripperCommand : GripperCommand;
    }
    attribute def RobotStatus {
        attribute jointAngles : AngleValue[6];
        attribute endEffectorWrench : ForceTorqueReading;
        attribute pose : PoseReading;
        attribute proximity : ProximityReading;
        attribute emergencyStop : Boolean;
    }
    attribute def ConnectionStatus {
        attribute status : ConnectionStatusKind;
        attribute dataRate : DataRateValue;
    }

    action def RenderVideo { in video : VideoStream; }
    action def ProvideForceFeedback { in status : RobotStatus; }
    action def GenerateOperatorCommand { out command : OperatorCommand; }
    action def PlanTrajectory {
        in command : OperatorCommand;
        in status : RobotStatus;
        out jointCommand : JointCommand;
        out gripperCommand : GripperCommand;
    }
    action def ExecuteJointTrajectory { in command : JointCommand; }
    action def ControlGripper {
        in command : GripperCommand;
        out wrench : ForceTorqueReading;
    }
    action def SenseJointAngles { out angles : AngleValue[6]; }
    action def SenseRobotStatus {
        in jointAngles : AngleValue[6];
        in wrench : ForceTorqueReading;
        out status : RobotStatus;
    }
    action def StreamVideo { out video : VideoStream; }
    action def MonitorConnection { in status : ConnectionStatus; }
    action def ReduceDataRate;
    action def AttemptReconnect;
    action def AlertOperator;
    action def ActivateEmergencyStop;

    state def ConnectionStates;
    state def SafetyMonitorStates;
    state def GripperStates;

    part def Joint {
        attribute currentAngle : AngleValue;
    }

    part def DisplayScreen {
        port videoIn { in video : VideoStream; }
        perform action renderVideo : RenderVideo;
    }

    part def HapticController {
        attribute degreesOfFreedom : Integer = 6;
        port commandOut { out command : OperatorCommand; }
        port feedbackIn { in status : RobotStatus; }
        perform action generateOperatorCommand : GenerateOperatorCommand;
        perform action provideForceFeedback : ProvideForceFeedback;
    }

    part def SixJointArm {
        port jointCommandIn { in command : JointCommand; }
        port jointAnglesOut { out angles : AngleValue[6]; }
        part joints[6] : Joint;
        perform action executeJointTrajectory : ExecuteJointTrajectory;
        perform action senseJointAngles : SenseJointAngles;
    }

    part def Gripper {
        port gripperCommandIn { in command : GripperCommand; }
        port wrenchOut { out wrench : ForceTorqueReading; }
        attribute forceSensed : ForceValue;
        attribute isClosed : Boolean;
        perform action controlGripper : ControlGripper;
        exhibit state gripperStates : GripperStates {
            entry; then open;
            state open;
            accept CloseCommandSignal then closing;
            state closing {
                do action controlGripper;
            }
            accept GraspDetectedSignal then holding;
            state holding;
            accept OpenCommandSignal then opening;
            state opening;
            accept when isClosed == false then open;
        }
    }

    part def VisionSystem {
        port videoOut { out video : VideoStream; }
        perform action streamVideo : StreamVideo;
    }

    part def SensorArray {
        port jointAnglesIn { in angles : AngleValue[6]; }
        port wrenchIn { in wrench : ForceTorqueReading; }
        port statusOut { out status : RobotStatus; }
        perform action senseRobotStatus : SenseRobotStatus;
    }

    part def RobotController {
        port commandIn { in command : OperatorCommand; }
        port statusIn { in status : RobotStatus; }
        port jointCommandOut { out jointCommand : JointCommand; }
        port gripperCommandOut { out gripperCommand : GripperCommand; }
        port emergencyStopOut { out stop : Boolean; }
        attribute safetyViolation : Boolean;
        perform action planTrajectory : PlanTrajectory;
        perform action alertOperator : AlertOperator;
        perform action activateEmergencyStop : ActivateEmergencyStop;
        exhibit state safetyMonitor : SafetyMonitorStates {
            entry; then normal;
            state normal;
            accept ProximityWarningSignal then warning;
            state warning {
                do action alertOperator;
            }
            accept EmergencyStopSignal then stopped;
            state stopped {
                do action activateEmergencyStop;
            }
            accept ResetSignal then normal;
        }
    }

    part def OperatorStation {
        part display : DisplayScreen;
        part hapticController : HapticController;
        port commandOut { out command : OperatorCommand; }
        port videoIn { in video : VideoStream; }
        port statusIn { in status : RobotStatus; }
        port emergencyStopIn { in stop : Boolean; }
        bind commandOut = hapticController.commandOut;
        bind videoIn = display.videoIn;
        bind statusIn = hapticController.feedbackIn;
    }

    part def RemoteRobot {
        part arm : SixJointArm;
        part gripper : Gripper;
        part vision : VisionSystem;
        part sensors : SensorArray;
        part controller : RobotController;
        port commandIn { in command : OperatorCommand; }
        port statusOut { out status : RobotStatus; }
        port videoOut { out video : VideoStream; }
        port emergencyStopOut { out stop : Boolean; }
        bind commandIn = controller.commandIn;
        bind statusOut = sensors.statusOut;
        bind videoOut = vision.videoOut;
        bind emergencyStopOut = controller.emergencyStopOut;
        connect controller.jointCommandOut to arm.jointCommandIn;
        connect controller.gripperCommandOut to gripper.gripperCommandIn;
        connect arm.jointAnglesOut to sensors.jointAnglesIn;
        connect gripper.wrenchOut to sensors.wrenchIn;
        connect sensors.statusOut to controller.statusIn;
    }

    part def CommunicationSystem {
        port operatorCommandIn { in command : OperatorCommand; }
        port operatorCommandOut { out command : OperatorCommand; }
        port robotStatusIn { in status : RobotStatus; }
        port robotVideoIn { in video : VideoStream; }
        port robotStatusOut { out status : RobotStatus; }
        port robotVideoOut { out video : VideoStream; }
        attribute connectionStatus : ConnectionStatus;
        attribute signalWeak : Boolean;
        attribute signalLost : Boolean;
        attribute signalStrong : Boolean;
        attribute signalRestored : Boolean;
        perform action monitorConnection : MonitorConnection;
        perform action reduceDataRate : ReduceDataRate;
        perform action attemptReconnect : AttemptReconnect;
        exhibit state connectionState : ConnectionStates {
            entry; then connected;
            state connected {
                do action monitorConnection;
            }
            accept SignalWeakened then degraded;
            state degraded {
                do action reduceDataRate;
            }
            accept SignalRestored then connected;
            accept SignalLost then disconnected;
            state disconnected {
                do action attemptReconnect;
            }
            accept SignalRestored then connected;
        }
        flow commandFlow of OperatorCommand
            from operatorCommandIn.command to operatorCommandOut.command;
        flow statusFlow of RobotStatus
            from robotStatusIn.status to robotStatusOut.status;
        flow videoFlow of VideoStream
            from robotVideoIn.video to robotVideoOut.video;
    }

    requirement def TeleroboticSystemRequirements {
        doc /* The telerobotic system shall allow a human operator to control a robotic arm in a remote or hazardous environment, mirroring operator actions and providing rich sensory feedback. */

        requirement operatorControl {
            doc /* The operator station shall provide a six-degree-of-freedom input device to intuitively guide the robot arm and gripper. */
        }
        requirement forceFeedback {
            doc /* The input device shall provide force feedback proportional to forces and torques sensed by the robot gripper. */
        }
        requirement videoDisplay {
            doc /* The operator station shall display a live video feed from the robot's depth-sensing vision system. */
        }
        requirement armDexterity {
            doc /* The remote robot shall include a six-jointed robotic manipulator arm providing dexterity similar to a human arm. */
        }
        requirement gripperControl {
            doc /* The gripper shall open, close, securely hold objects, and measure applied force using integrated force sensors. */
        }
        requirement sensorFeedback {
            doc /* The sensor array shall provide end-effector forces and torques, position and orientation, and proximity to nearby objects. */
        }
        requirement safetyMonitoring {
            doc /* The robot controller shall continuously monitor for safety violations and trigger an emergency stop if necessary. */
        }
        requirement robustCommunication {
            doc /* The communication system shall provide an encrypted bidirectional link, reduce data rate when the signal weakens, and attempt reconnection if the link is lost. */
        }
    }

    part teleroboticSystem : TeleroboticSystemRequirements {
        part operatorStation : OperatorStation;
        part remoteRobot : RemoteRobot;
        part comm : CommunicationSystem;

        connect operatorStation.commandOut to comm.operatorCommandIn;
        connect comm.operatorCommandOut to remoteRobot.commandIn;
        connect remoteRobot.videoOut to comm.robotVideoIn;
        connect remoteRobot.statusOut to comm.robotStatusIn;
        connect comm.robotVideoOut to operatorStation.videoIn;
        connect comm.robotStatusOut to operatorStation.statusIn;
        connect remoteRobot.emergencyStopOut to operatorStation.emergencyStopIn;

        satisfy operatorControl by operatorStation.hapticController;
        satisfy forceFeedback by operatorStation.hapticController;
        satisfy videoDisplay by operatorStation.display;
        satisfy armDexterity by remoteRobot.arm;
        satisfy gripperControl by remoteRobot.gripper;
        satisfy sensorFeedback by remoteRobot.sensors;
        satisfy safetyMonitoring by remoteRobot.controller;
        satisfy robustCommunication by comm;
    }
}
