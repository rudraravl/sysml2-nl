package TeleroboticSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // Value Types
    value type ForceValue :> Real { unit 'N'; }
    value type TorqueValue :> Real { unit 'Nm'; }
    value type AngleValue :> Real { unit 'deg'; }
    value type DistanceValue :> Real { unit 'm'; }
    value type DataRateValue :> Real { unit 'Mbps'; }
    value type SignalStrengthValue :> Real { unit 'dBm'; }
    
    // Item Types
    item def OperatorCommand {
        attribute jointAngles : Array(AngleValue, 6);
        attribute gripperCommand : Real; // 0 to 1
    }
    
    item def GripperCommand {
        attribute position : Real; // 0 to 1
    }
    
    item def VideoStream {
        attribute resolution : String;
        attribute frameRate : Real;
    }
    
    item def SensorFeedback {
        attribute endEffectorForce : ForceValue;
        attribute endEffectorTorque : TorqueValue;
        attribute position : Array(DistanceValue, 3);
        attribute orientation : Array(AngleValue, 3);
        attribute proximity : DistanceValue;
        attribute gripperForce : ForceValue;
    }
    
    item def JointTrajectory {
        attribute points : Array(AngleValue, 6);
        attribute velocities : Array(Real, 6);
    }
    
    // Port Definitions
    port def CommandOutPort {
        out command : OperatorCommand;
    }
    port def CommandInPort {
        in command : OperatorCommand;
    }
    port def FeedbackOutPort {
        out feedback : SensorFeedback;
    }
    port def FeedbackInPort {
        in feedback : SensorFeedback;
    }
    port def VideoOutPort {
        out video : VideoStream;
    }
    port def VideoInPort {
        in video : VideoStream;
    }
    port def TrajectoryOutPort {
        out trajectory : JointTrajectory;
    }
    port def TrajectoryInPort {
        in trajectory : JointTrajectory;
    }
    port def GripperCommandOutPort {
        out command : GripperCommand;
    }
    port def GripperCommandInPort {
        in command : GripperCommand;
    }
    port def GripperForceOutPort {
        out force : ForceValue;
    }
    port def GripperForceInPort {
        in force : ForceValue;
    }

    // Requirements
    requirement def TeleroboticRequirement {
        doc /* The system shall allow a human operator to control a robotic arm in a remote environment with sensory feedback. */
    }
    
    requirement def ForceFeedbackRequirement :> TeleroboticRequirement {
        doc /* The input device shall provide force feedback to the operator. */
    }
    
    requirement def CommunicationResilienceRequirement :> TeleroboticRequirement {
        doc /* The communication system shall reduce data rate if signal weakens and attempt reconnection if lost. */
    }

    // Parts
    part def InputDevice {
        attribute hasForceFeedback : Boolean = true;
        port commandOut : CommandOutPort;
        port feedbackIn : FeedbackInPort;
    }
    
    part def Display {
        port videoIn : VideoInPort;
    }
    
    part def OperatorStation {
        part display : Display;
        part controller : InputDevice;
        
        port commandOut : CommandOutPort;
        port feedbackIn : FeedbackInPort;
        port videoIn : VideoInPort;
        
        connection operatorToStationCommand connect controller.commandOut to commandOut;
        connection stationToOperatorFeedback connect feedbackIn to controller.feedbackIn;
        connection stationToDisplayVideo connect videoIn to display.videoIn;
    }

    part def Gripper {
        attribute isOpen : Boolean;
        port commandIn : GripperCommandInPort;
        port forceOut : GripperForceOutPort;
    }
    
    part def RoboticArm {
        part joints : Array(AngleValue, 6);
        part gripper : Gripper;
        
        port trajectoryIn : TrajectoryInPort;
        port gripperCommandIn : GripperCommandInPort;
        port gripperForceOut : GripperForceOutPort;
        
        connection armToGripperCommand connect gripperCommandIn to gripper.commandIn;
        connection gripperToArmForce connect gripper.forceOut to gripperForceOut;
    }
    
    part def VisionSystem {
        port videoOut : VideoOutPort;
    }
    
    part def SensorArray {
        port feedbackOut : FeedbackOutPort;
    }
    
    part def RobotController {
        port commandIn : CommandInPort;
        port sensorDataIn : FeedbackInPort;
        port feedbackOut : FeedbackOutPort;
        
        port trajectoryOut : TrajectoryOutPort;
        port gripperCommandOut : GripperCommandOutPort;
        port gripperForceIn : GripperForceInPort;
        
        attribute emergencyStop : Boolean = false;
        
        action def TranslateAndMonitor {
            in command : OperatorCommand;
            in sensorData : SensorFeedback;
            out trajectory : JointTrajectory;
            out gripperCommand : GripperCommand;
            out feedback : SensorFeedback;
            doc /* Translates commands into trajectories and monitors safety. */
        }
        
        action translateAndMonitor : TranslateAndMonitor {
            in command = commandIn.command;
            in sensorData = sensorDataIn.feedback;
            out trajectory = trajectoryOut.trajectory;
            out gripperCommand = gripperCommandOut.command;
            out feedback = feedbackOut.feedback;
        }
    }
    
    part def RemoteRobot {
        part arm : RoboticArm;
        part vision : VisionSystem;
        part sensorArray : SensorArray;
        part robotController : RobotController;
        
        port commandIn : CommandInPort;
        port feedbackOut : FeedbackOutPort;
        port videoOut : VideoOutPort;
        
        connection commToControllerCommand connect commandIn to robotController.commandIn;
        connection controllerToCommFeedback connect robotController.feedbackOut to feedbackOut;
        connection visionToCommVideo connect vision.videoOut to videoOut;
        connection sensorsToControllerFeedback connect sensorArray.feedbackOut to robotController.sensorDataIn;
        
        connection controllerToArmTrajectory connect robotController.trajectoryOut to arm.trajectoryIn;
        connection controllerToGripperCommand connect robotController.gripperCommandOut to arm.gripperCommandIn;
        connection armToControllerForce connect arm.gripperForceOut to robotController.gripperForceIn;
    }

    part def CommunicationSystem {
        attribute encrypted : Boolean = true;
        attribute bidirectional : Boolean = true;
        attribute currentDataRate : DataRateValue;
        attribute signalStrength : SignalStrengthValue;
        
        port operatorCommandIn : CommandInPort;
        port operatorFeedbackOut : FeedbackOutPort;
        port operatorVideoOut : VideoOutPort;
        
        port robotCommandOut : CommandOutPort;
        port robotFeedbackIn : FeedbackInPort;
        port robotVideoIn : VideoInPort;
        
        state def ConnectionState;
        
        state def Connected :> ConnectionState {
            entry action { currentDataRate = 10.0; }
        }
        
        state def Degraded :> ConnectionState {
            entry action { currentDataRate = 2.0; }
        }
        
        state def Disconnected :> ConnectionState {
            entry action { currentDataRate = 0.0; }
        }
        
        state machine connectionStateMachine {
            state connected : Connected;
            state degraded : Degraded;
            state disconnected : Disconnected;
            
            transition first to connected;
            transition connected to degraded when signalStrength < -70;
            transition degraded to connected when signalStrength >= -70;
            transition degraded to disconnected when signalStrength < -90;
            transition disconnected to connected when signalStrength >= -70;
        }
        
        action def Transmit {
            in operatorCommand : OperatorCommand;
            out robotCommand : OperatorCommand;
            in robotFeedback : SensorFeedback;
            out operatorFeedback : SensorFeedback;
            in robotVideo : VideoStream;
            out operatorVideo : VideoStream;
        }
        
        action transmit : Transmit {
            in operatorCommand = operatorCommandIn.command;
            out robotCommand = robotCommandOut.command;
            in robotFeedback = robotFeedbackIn.feedback;
            out operatorFeedback = operatorFeedbackOut.feedback;
            in robotVideo = robotVideoIn.video;
            out operatorVideo = operatorVideoOut.video;
        }
    }

    part def TeleroboticSystem {
        requirement forceFeedbackReq : ForceFeedbackRequirement;
        requirement commResilienceReq : CommunicationResilienceRequirement;
        
        part operatorStation : OperatorStation;
        part remoteRobot : RemoteRobot;
        part commSystem : CommunicationSystem;
        
        connection operatorToCommCommand connect operatorStation.commandOut to commSystem.operatorCommandIn;
        connection commToOperatorFeedback connect commSystem.operatorFeedbackOut to operatorStation.feedbackIn;
        connection commToOperatorVideo connect commSystem.operatorVideoOut to operatorStation.videoIn;
        
        connection commToRobotCommand connect commSystem.robotCommandOut to remoteRobot.commandIn;
        connection robotToCommFeedback connect remoteRobot.feedbackOut to commSystem.robotFeedbackIn;
        connection robotToCommVideo connect remoteRobot.videoOut to commSystem.robotVideoIn;
    }
}
