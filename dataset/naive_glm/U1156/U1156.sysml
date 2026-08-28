package IndustrialRoboticWorkCell {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def AngleDeg :> Real;
    value def AngularVelocityDegPerSec :> Real;
    value def AngularAccelerationDegPerSec2 :> Real;
    value def ForceN :> Real;
    value def TorqueNm :> Real;
    value def VoltageV :> Real;
    value def CurrentA :> Real;
    value def PowerW :> Real;
    value def DistanceM :> Real;
    value def SpeedMps :> Real;
    value def MassKg :> Real;
    value def FrequencyHz :> Real;
    value def TimeSec :> Real;
    value def AccuracyMm :> Real;
    value def ConfidencePct :> Real;

    // ===== Item Definitions =====
    item def ElectricalPower {
        attribute voltage : VoltageV;
        attribute current : CurrentA;
    }

    item def JointCommand {
        attribute targetAngle : AngleDeg;
        attribute targetSpeed : AngularVelocityDegPerSec;
    }

    item def EncoderFeedback {
        attribute currentAngle : AngleDeg;
        attribute currentSpeed : AngularVelocityDegPerSec;
    }

    item def ImageData {
        attribute width : Integer;
        attribute height : Integer;
        attribute frameRate : FrequencyHz;
    }

    item def ProximityData {
        attribute distance : DistanceM;
        attribute detected : Boolean;
    }

    item def TrajectoryPoint {
        attribute timestamp : TimeSec;
        attribute jointAngles : AngleDeg[4];
        attribute jointSpeeds : AngularVelocityDegPerSec[4];
    }

    item def PathData {
        attribute collisionFree : Boolean;
        attribute estimatedDuration : TimeSec;
        attribute waypointCount : Integer;
    }

    item def Workpiece {
        attribute id : String;
        attribute mass : MassKg;
        attribute width : DistanceM;
        attribute height : DistanceM;
        attribute depth : DistanceM;
    }

    item def GripForceCommand {
        attribute targetForce : ForceN;
        attribute release : Boolean;
    }

    item def ForceReading {
        attribute measuredForce : ForceN;
    }

    item def SafetyStatus {
        attribute safe : Boolean;
        attribute maxForce : ForceN;
        attribute maxSpeed : AngularVelocityDegPerSec;
    }

    item def EmergencyStopSignal {
        attribute triggered : Boolean;
        attribute reason : String;
    }

    item def ObjectDetection {
        attribute workpieceId : String;
        attribute positionX : DistanceM;
        attribute positionY : DistanceM;
        attribute positionZ : DistanceM;
        attribute confidence : ConfidencePct;
    }

    item def CommMessage {
        attribute payload : String;
        attribute timestamp : TimeSec;
        attribute sourceId : String;
    }

    // ===== Port Definitions =====
    port def PowerInPort {
        in power : ElectricalPower;
    }

    port def PowerOutPort {
        out power : ElectricalPower;
    }

    port def MotorCommandPort {
        out command : JointCommand;
    }

    port def EncoderFeedbackPort {
        out feedback : EncoderFeedback;
    }

    port def ImagePort {
        out image : ImageData;
    }

    port def ProximityPort {
        out detection : ProximityData;
    }

    port def TrajectoryOutPort {
        out trajectory : TrajectoryPoint;
    }

    port def PathOutPort {
        out path : PathData;
    }

    port def GripCommandPort {
        out cmd : GripForceCommand;
    }

    port def ForceFeedbackPort {
        out reading : ForceReading;
    }

    port def SafetyOutPort {
        out status : SafetyStatus;
        out eStop : EmergencyStopSignal;
    }

    port def CommDataPort {
        inout message : CommMessage;
    }

    port def DetectionPort {
        out detection : ObjectDetection;
    }

    // ===== Action Definitions =====
    action def EnterManualMode;
    action def EnterAutomaticMode;
    action def SenseEnvironment;
    action def PlanPath;
    action def ExecuteTrajectory;
    action def GraspWorkpiece;
    action def TransportWorkpiece;
    action def ReleaseWorkpiece;
    action def EnterEmergencyState;
    action def ResetSystem;

    // ===== Part Definitions =====

    part def Motor {
        attribute ratedTorque : TorqueNm;
        attribute maxSpeed : AngularVelocityDegPerSec;
        attribute supplyVoltage : VoltageV;
        port powerIn : PowerInPort;
        port commandIn : MotorCommandPort;
        port feedbackOut : EncoderFeedbackPort;
    }

    part def Encoder {
        attribute resolution : Integer;
        attribute currentAngle : AngleDeg;
        attribute currentSpeed : AngularVelocityDegPerSec;
        port feedbackOut : EncoderFeedbackPort;
    }

    part def Joint {
        attribute name : String;
        attribute minAngle : AngleDeg;
        attribute maxAngle : AngleDeg;
        part motor : Motor;
        part encoder : Encoder;
        port commandIn : MotorCommandPort;
        port feedbackOut : EncoderFeedbackPort;
        connect commandIn to motor.commandIn;
        connect encoder.feedbackOut to feedbackOut;
    }

    part def GripperFinger {
        attribute position : DistanceM;
        attribute maxStroke : DistanceM;
        part actuator : Motor;
    }

    part def Gripper {
        attribute maxGripForce : ForceN;
        attribute fingerWidth : DistanceM;
        part leftFinger : GripperFinger;
        part rightFinger : GripperFinger;
        part forceSensor {
            attribute maxForce : ForceN;
            attribute currentForce : ForceN;
            port forceOut : ForceFeedbackPort;
        }
        port gripCommand : GripCommandPort;
        port forceFeedback : ForceFeedbackPort;
        connect gripCommand to leftFinger.actuator.commandIn;
        connect gripCommand to rightFinger.actuator.commandIn;
        connect forceSensor.forceOut to forceFeedback;
    }

    part def RoboticArm {
        attribute reach : DistanceM;
        attribute payload : MassKg;
        attribute repeatability : AccuracyMm;
        part baseJoint : Joint { attribute name : String = "base"; }
        part shoulderJoint : Joint { attribute name : String = "shoulder"; }
        part elbowJoint : Joint { attribute name : String = "elbow"; }
        part wristJoint : Joint { attribute name : String = "wrist"; }
        part endEffector : Gripper;
        port jointCommands : MotorCommandPort[4];
        port jointFeedbacks : EncoderFeedbackPort[4];
        port gripCommand : GripCommandPort;
        port forceFeedback : ForceFeedbackPort;
        connect jointCommands[0] to baseJoint.commandIn;
        connect jointCommands[1] to shoulderJoint.commandIn;
        connect jointCommands[2] to elbowJoint.commandIn;
        connect jointCommands[3] to wristJoint.commandIn;
        connect baseJoint.feedbackOut to jointFeedbacks[0];
        connect shoulderJoint.feedbackOut to jointFeedbacks[1];
        connect elbowJoint.feedbackOut to jointFeedbacks[2];
        connect wristJoint.feedbackOut to jointFeedbacks[3];
        connect gripCommand to endEffector.gripCommand;
        connect endEffector.forceFeedback to forceFeedback;
    }

    part def Camera {
        attribute resolutionWidth : Integer;
        attribute resolutionHeight : Integer;
        attribute frameRate : FrequencyHz;
        port imageOut : ImagePort;
    }

    part def ImageProcessor {
        attribute processingTime : TimeSec;
        attribute modelVersion : String;
        port imageIn : ImagePort;
        port detectionOut : DetectionPort;
    }

    part def ProximitySensor {
        attribute sensorId : Integer;
        attribute maxRange : DistanceM;
        attribute minRange : DistanceM;
        port detectionOut : ProximityPort;
    }

    part def PerceptionSystem {
        part camera : Camera;
        part imageProcessor : ImageProcessor;
        part proximitySensors : ProximitySensor[4];
        port imageOut : ImagePort;
        port detectionOut : DetectionPort;
        port proximityOut : ProximityPort[4];
        connect camera.imageOut to imageProcessor.imageIn;
        connect imageProcessor.detectionOut to detectionOut;
        connect proximitySensors.detectionOut to proximityOut;
    }

    part def MotionPlanner {
        attribute planningTimeout : TimeSec;
        attribute maxIterations : Integer;
        attribute algorithm : String;
        port pathOut : PathOutPort;
        port detectionIn : DetectionPort;
        port proximityIn : ProximityPort[4];
    }

    part def TrajectoryGenerator {
        attribute samplingRate : FrequencyHz;
        attribute maxVelocity : AngularVelocityDegPerSec;
        attribute maxAcceleration : AngularAccelerationDegPerSec2;
        port pathIn : PathOutPort;
        port trajectoryOut : TrajectoryOutPort;
    }

    part def JointController {
        attribute controlRate : FrequencyHz;
        attribute pidKp : Real;
        attribute pidKi : Real;
        attribute pidKd : Real;
        port trajectoryIn : TrajectoryOutPort;
        port jointCommandsOut : MotorCommandPort[4];
        port jointFeedbackIn : EncoderFeedbackPort[4];
    }

    part def SafetyController {
        attribute maxForceLimit : ForceN = 50.0;
        attribute maxSpeedLimit : AngularVelocityDegPerSec = 180.0;
        attribute emergencyStopActive : Boolean = false;
        port forceIn : ForceFeedbackPort;
        port encoderIn : EncoderFeedbackPort[4];
        port proximityIn : ProximityPort[4];
        port safetyOut : SafetyOutPort;
    }

    part def ControlModule {
        part motionPlanner : MotionPlanner;
        part trajectoryGenerator : TrajectoryGenerator;
        part jointController : JointController;
        part safetyController : SafetyController;
        port detectionIn : DetectionPort;
        port proximityIn : ProximityPort[4];
        port jointCommandsOut : MotorCommandPort[4];
        port jointFeedbackIn : EncoderFeedbackPort[4];
        port gripCommandOut : GripCommandPort;
        port forceFeedbackIn : ForceFeedbackPort;
        port safetyOut : SafetyOutPort;
        connect detectionIn to motionPlanner.detectionIn;
        connect proximityIn to motionPlanner.proximityIn;
        connect motionPlanner.pathOut to trajectoryGenerator.pathIn;
        connect trajectoryGenerator.trajectoryOut to jointController.trajectoryIn;
        connect jointController.jointCommandsOut to jointCommandsOut;
        connect jointFeedbackIn to jointController.jointFeedbackIn;
        connect forceFeedbackIn to safetyController.forceIn;
        connect jointFeedbackIn to safetyController.encoderIn;
        connect proximityIn to safetyController.proximityIn;
        connect safetyController.safetyOut to safetyOut;
    }

    part def PowerSupply {
        attribute inputVoltage : VoltageV;
        attribute outputVoltage : VoltageV;
        attribute maxPower : PowerW;
        attribute efficiency : Real;
        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;
    }

    part def CommunicationInterface {
        attribute protocol : String;
        attribute baudRate : FrequencyHz;
        attribute nodeId : String;
        port commPort : CommDataPort;
    }

    // ===== State Machine =====
    state def OperationalMode {
        entry action EnterAutomaticMode;
        state manual {
            entry action EnterManualMode;
        }
        state automatic {
            entry action EnterAutomaticMode;
            state sensing {
                entry action SenseEnvironment;
            }
            state planning {
                entry action PlanPath;
            }
            state executing {
                entry action ExecuteTrajectory;
            }
            state grasping {
                entry action GraspWorkpiece;
            }
            state transporting {
                entry action TransportWorkpiece;
            }
            state releasing {
                entry action ReleaseWorkpiece;
            }
            transition sensing to planning;
            transition planning to executing;
            transition executing to grasping;
            transition grasping to transporting;
            transition transporting to releasing;
            transition releasing to sensing;
        }
        state emergency {
            entry action EnterEmergencyState;
        }
        transition manual to automatic;
        transition automatic to manual;
        transition manual to emergency;
        transition automatic to emergency;
        transition emergency to manual;
    }

    // ===== Main Work Cell =====
    part def RoboticWorkCell {
        attribute systemId : String;
        attribute repeatabilityAccuracy : AccuracyMm = 0.1;
        attribute maxCycleTime : TimeSec;
        attribute modeSwitch : Boolean;
        attribute safetyViolation : Boolean;
        attribute resetCommand : Boolean;

        part arm : RoboticArm;
        part perception : PerceptionSystem;
        part controller : ControlModule;
        part powerSupply : PowerSupply;
        part commInterface : CommunicationInterface;

        port externalComm : CommDataPort;
        port mainPower : PowerInPort;

        connect mainPower to powerSupply.powerIn;
        connect powerSupply.powerOut to arm.baseJoint.motor.powerIn;
        connect powerSupply.powerOut to arm.shoulderJoint.motor.powerIn;
        connect powerSupply.powerOut to arm.elbowJoint.motor.powerIn;
        connect powerSupply.powerOut to arm.wristJoint.motor.powerIn;
        connect powerSupply.powerOut to arm.endEffector.leftFinger.actuator.powerIn;
        connect powerSupply.powerOut to arm.endEffector.rightFinger.actuator.powerIn;

        connect perception.detectionOut to controller.detectionIn;
        connect perception.proximityOut to controller.proximityIn;

        connect controller.jointCommandsOut to arm.jointCommands;
        connect arm.jointFeedbacks to controller.jointFeedbackIn;

        connect controller.gripCommandOut to arm.gripCommand;
        connect arm.forceFeedback to controller.forceFeedbackIn;

        connect commInterface.commPort to externalComm;

        exhibit OperationalMode;
    }

    // ===== Requirements =====
    requirement def PickAndPlaceRequirement {
        subject workCell : RoboticWorkCell;
        objective {
            "The work cell shall autonomously perform high-precision pick-and-place operations on various workpieces within a structured industrial environment."
        }
    }

    requirement def PrecisionRequirement {
        subject workCell : RoboticWorkCell;
        attribute requiredAccuracy : AccuracyMm = 0.1;
        objective {
            "The system shall achieve sub-millimeter repeatability accuracy of 0.1 mm or better across repeated cycles."
        }
    }

    requirement def SafetyRequirement {
        subject workCell : RoboticWorkCell;
        attribute maxAllowableForce : ForceN = 50.0;
        attribute maxAllowableSpeed : AngularVelocityDegPerSec = 180.0;
        objective {
            "The safety controller shall continuously monitor forces and speeds and trigger an immediate emergency stop when predefined safety limits are exceeded."
        }
    }

    requirement def PerceptionRequirement {
        subject workCell : RoboticWorkCell;
        attribute minDetectionRange : DistanceM = 0.5;
        attribute proximitySensorCount : Integer = 4;
        objective {
            "The perception system shall visually identify workpieces and their locations using a high-definition camera and image processor, and shall detect nearby obstacles using four proximity sensors to prevent collisions."
        }
    }

    requirement def CommunicationRequirement {
        subject workCell : RoboticWorkCell;
        objective {
            "The industrial communication interface shall handle data exchange between the robot internal components and external control systems."
        }
    }

    requirement def PowerRequirement {
        subject workCell : RoboticWorkCell;
        objective {
            "The central power supply unit shall provide stable electrical power to all subsystems including motors, sensors, controllers, and communication interfaces."
        }
    }

    requirement def MultiAxisRequirement {
        subject workCell : RoboticWorkCell;
        attribute jointCount : Integer = 4;
        objective {
            "The robotic arm shall be a four-axis manipulator with motorized base, shoulder, elbow, and wrist joints, each driven by a dedicated motor and equipped with a high-resolution encoder."
        }
    }

    requirement def GripperRequirement {
        subject workCell : RoboticWorkCell;
        attribute fingerCount : Integer = 2;
        objective {
            "The end effector shall be a two-fingered gripper with dedicated actuators and a force sensor to grasp objects and carefully control gripping strength."
        }
    }

    requirement def ControlModuleRequirement {
        subject workCell : RoboticWorkCell;
        objective {
            "The central control module shall contain a motion planner for collision-free path calculation, a trajectory generator for smooth time-based movement sequences, a joint controller for precise motor commands, and a dedicated safety controller for continuous force and speed monitoring."
        }
    }

    requirement def OperationalModeRequirement {
        subject workCell : RoboticWorkCell;
        objective {
            "The system shall support manual, automatic, and emergency operational modes, with automated tasks consisting of sensing the environment, planning and executing a path, grasping with measured force, transporting, and releasing the workpiece."
        }
    }

    requirement pickAndPlaceReq :> PickAndPlaceRequirement;
    requirement precisionReq :> PrecisionRequirement;
    requirement safetyReq :> SafetyRequirement;
    requirement perceptionReq :> PerceptionRequirement;
    requirement communicationReq :> CommunicationRequirement;
    requirement powerReq :> PowerRequirement;
    requirement multiAxisReq :> MultiAxisRequirement;
    requirement gripperReq :> GripperRequirement;
    requirement controlModuleReq :> ControlModuleRequirement;
    requirement operationalModeReq :> OperationalModeRequirement;
}
