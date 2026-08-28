package GynoidModel {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    attribute def Voltage :> Real { unit 'V'; }
    attribute def Current :> Real { unit 'A'; }
    attribute def Power :> Real { unit 'W'; }
    attribute def Energy :> Real { unit 'J'; }
    attribute def Charge :> Real { unit 'C'; }
    attribute def Force :> Real { unit 'N'; }
    attribute def Torque :> Real {> Real { unit 'N·m'; }
    attribute def Angle :> Real { unit 'rad'; }
    attribute def AngularVelocity :> Real { unit 'rad/s'; }
    attribute def LinearVelocity :> Real { unit 'm/s'; }
    attribute def Distance :> Real { unit 'm'; }
    attribute def Mass :> Real { unit 'kg'; }
    attribute def Pressure :> Real { unit 'Pa'; }
    attribute def Frequency :> Real { unit 'Hz'; }
    attribute def SoundPressureLevel :> Real { unit 'dB'; }
    attribute def Temperature :> Real { unit 'K'; }
    attribute def TimeValue :> Real { unit 's'; }

    // ===== Item Types =====

    item def ElectricPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def SensorData {
        attribute timestamp : TimeValue;
    }

    item def ImageData :> SensorData {
        attribute width : Integer;
        attribute height : Integer;
        attribute depthResolution : Integer;
    }

    item def DepthMap :> SensorData {
        attribute range : Distance;
        attribute resolution : Distance;
    }

    item def AudioData :> SensorData {
        attribute sampleRate : Frequency;
        attribute channels : Integer;
        attribute spl : SoundPressureLevel;
    }

    item def SpeechText {
        attribute text : String;
        attribute confidence : Real;
    }

    item def VoiceCommand {
        attribute commandText : String;
        attribute speakerId : String;
        attribute timestamp : TimeValue;
    }

    item def IMUData :> SensorData {
        attribute angularVelocityX : AngularVelocity;
        attribute angularVelocityY : AngularVelocity;
        attribute angularVelocityZ : AngularVelocity;
        attribute accelX : Real { unit 'm/s^2'; }
        attribute accelY : Real { unit 'm/s^2'; }
        attribute accelZ : Real { unit 'm/s^2'; }
    }

    item def TactileData :> SensorData {
        attribute pressure : Pressure;
        attribute locationId : Integer;
    }

    item def JointCommand {
        attribute targetAngle : Angle;
        attribute maxTorque : Torque;
        attribute velocity : AngularVelocity;
    }

    item def NavigationGoal {
        attribute targetX : Distance;
        attribute targetY : Distance;
        attribute targetOrientation : Angle;
    }

    item def WorldMap {
        attribute mapWidth : Distance;
        attribute mapHeight : Distance;
        attribute resolution : Distance;
        attribute lastUpdated : TimeValue;
    }

    item def ObjectDetection {
        attribute objectClass : String;
        attribute confidence : Real;
        attribute positionX : Distance;
        attribute positionY : Distance;
        attribute positionZ : Distance;
    }

    item def TaskPlan {
        attribute taskId : String;
        attribute steps : String[0..*];
        attribute priority : Integer;
    }

    item def SafetyStatus {
        attribute collisionRisk : Real;
        attribute forceExceeded : Boolean;
        attribute emergencyStop : Boolean;
    }

    // ===== Port Definitions =====

    port def PowerPort {
        out power : ElectricPower;
    }

    port def PowerInPort {
        in power : ElectricPower;
    }

    port def SensorDataPort {
        out data : SensorData;
    }

    port def SensorDataInPort {
        in data : SensorData;
    }

    port def ImageDataPort {
        out images : ImageData;
        out depth : DepthMap;
    }

    port def ImageDataInPort {
        in images : ImageData;
        in depth : DepthMap;
    }

    port def AudioDataPort {
        out audio : AudioData;
    }

    port def AudioDataInPort {
        in audio : AudioData;
    }

    port def SpeechOutputPort {
        out speech : SpeechText;
    }

    port def SpeechInputPort {
        in speech : SpeechText;
    }

    port def CommandPort {
        out command : JointCommand;
    }

    port def CommandInPort {
        in command : JointCommand;
    }

    port def NavigationPort {
        out goal : NavigationGoal;
    }

    port def NavigationInPort {
        in goal : NavigationGoal;
    }

    port def TactileDataPort {
        out tactile : TactileData;
    }

    port def TactileDataInPort {
        in tactile : TactileData;
    }

    port def MapDataPort {
        out map : WorldMap;
        out detections : ObjectDetection[0..*];
    }

    port def MapDataInPort {
        in map : WorldMap;
        in detections : ObjectDetection[0..*];
    }

    port def TaskPlanPort {
        out plan : TaskPlan;
    }

    port def TaskPlanInPort {
        in plan : TaskPlan;
    }

    port def SafetyPort {
        out status : SafetyStatus;
    }

    port def SafetyInPort {
        in status : SafetyStatus;
    }

    port def IMUPort {
        out imuData : IMUData;
    }

    port def IMUInPort {
        in imuData : IMUData;
    }

    // ===== Requirements =====

    requirement def DomesticAssistantRequirement {
        doc /* The gynoid shall function as an autonomous domestic assistant. */
    }

    requirement AutonomyRequirement :> DomesticAssistantRequirement {
        doc /* The robot shall operate autonomously for household tasks. */
        attribute minAutonomyHours : TimeValue = 4 [s * 3600];
    }

    requirement BatteryLifeRequirement :> DomesticAssistantRequirement {
        doc /* The battery shall provide at least 8 hours of operation under normal domestic use. */
        attribute minBatteryLife : TimeValue = 28800 [s];
        attribute minCapacity : Charge = 18000 [s * 3600 * 1];
    }

    requirement SafeForceRequirement :> DomesticAssistantRequirement {
        doc /* The robot shall limit applied force to safe levels for human interaction. */
        attribute maxContactForce : Force = 50.0;
        attribute maxGripForce : Force = 20.0;
    }

    requirement CollisionAvoidanceRequirement :> DomesticAssistantRequirement {
        doc /* The robot shall detect and avoid collisions with people and objects. */
        attribute minDetectionRange : Distance = 0.5;
        attribute maxReactionTime : TimeValue = 0.1;
    }

    requirement VoiceInteractionRequirement :> DomesticAssistantRequirement {
        doc /* The robot shall understand voice commands and respond with synthesized speech. */
        attribute minVoiceRecognitionAccuracy : Real = 0.95;
        attribute maxResponseLatency : TimeValue = 2.0;
    }

    requirement BipedalMobilityRequirement :> DomesticAssistantRequirement {
        doc /* The robot shall walk on two legs and navigate a home environment. */
        attribute maxWalkingSpeed : LinearVelocity = 1.2;
        attribute minStepHeight : Distance = 0.05;
    }

    requirement ManipulationRequirement :> DomesticAssistantRequirement {
        doc /* The robot shall grasp and manipulate household objects with dexterity. */
        attribute minFingerJoints : Integer = 3;
        attribute maxPayload : Mass = 5.0;
    }

    requirement BalanceRequirement :> DomesticAssistantRequirement {
        doc /* The balance controller shall maintain stability during all activities. */
        attribute maxTiltAngle : Angle = 0.1745;
        attribute controlLoopRate : Frequency = 200.0;
    }

    // ===== Parts: Power System =====

    part def Battery {
        port powerOut : PowerPort;
        attribute capacity : Charge = 18000 [s * 3600];
        attribute currentCharge : Charge;
        attribute nominalVoltage : Voltage = 24.0;
        attribute maxDischargeCurrent : Current = 30.0;
        attribute charging : Boolean = false;

        state def BatteryState {
            state Discharging {
                entry action { currentCharge = currentCharge - 0.001; }
            }
            state Charging {
                entry action { currentCharge = currentCharge + 0.002; }
            }
            transition Discharging to Charging when charging == true;
            transition Charging to Discharging when charging == false;
        }
    }

    part def PowerDistributionUnit {
        port powerIn : PowerInPort;
        port powerOutCognitive : PowerPort;
        port powerOutVision : PowerPort;
        port powerOutAudio : PowerPort;
        port powerOutLocomotion : PowerPort;
        port powerOutBalance : PowerPort;
        port powerOutManipulation : PowerPort;
        attribute totalPowerConsumption : Power;
        attribute efficiency : Real = 0.95;
    }

    // ===== Parts: Cognitive Core =====

    part def CognitiveCore {
        port powerIn : PowerInPort;
        port imageDataIn : ImageDataInPort;
        port audioDataIn : AudioDataInPort;
        port imuDataIn : IMUInPort;
        port tactileDataIn : TactileDataInPort;
        port mapDataIn : MapDataInPort;
        port safetyDataIn : SafetyInPort;
        port navigationOut : NavigationPort;
        port leftArmCommands : CommandPort;
        port rightArmCommands : CommandPort;
        port locomotionCommands : CommandPort;
        port speechOut : SpeechOutputPort;
        port taskPlanOut : TaskPlanPort;

        attribute processingFrequency : Frequency = 1000.0;
        attribute memorySize : Integer = 32; // GB
        attribute currentWorldMap : WorldMap;
        attribute currentTask : TaskPlan;

        action def ProcessPerception {
            in image : ImageData;
            in depth : DepthMap;
            in audio : AudioData;
            in imu : IMUData;
            in tactile : TactileData[0..*];
            out map : WorldMap;
            out detections : ObjectDetection[0..*];
        }

        action def PlanTask {
            in command : VoiceCommand;
            in map : WorldMap;
            out plan : TaskPlan;
        }

        action def ExecuteTask {
            in plan : TaskPlan;
            in map : WorldMap;
            out navGoal : NavigationGoal;
            out armCommands : JointCommand[0..*];
            out speech : SpeechText;
        }

        action def GenerateSpeech {
            in text : String;
            out speech : SpeechText;
        }

        state def CognitiveState {
            state Ready {
                doc /* Observing environment, waiting for commands. */
            }
            state ProcessingCommand {
                doc /* Processing a voice command and generating a task plan. */
            }
            state Navigating {
                doc /* Moving to a target location. */
            }
            state Manipulating {
                doc /* Performing manipulation tasks. */
            }
            state Returning {
                doc /* Returning to the user after task completion. */
            }
            state ErrorRecovery {
                doc /* Recovering from an error or safety event. */
            }
            transition Ready to ProcessingCommand when /* voice command received */ true;
            transition ProcessingCommand to Navigating when /* plan requires navigation */ true;
            transition Navigating to Manipulating when /* target reached */ true;
            transition Manipulating to Returning when /* object grasped */ true;
            transition Returning to Ready when /* task complete */ true;
            transition any to ErrorRecovery when /* safety event */ true;
            transition ErrorRecovery to Ready when /* recovered */ true;
        }
    }

    // ===== Parts: Vision System =====

    part def StereoCamera {
        port imageDataOut : ImageDataPort;
        attribute resolution : Integer = 1920;
        attribute frameRate : Frequency = 30.0;
        attribute baseline : Distance = 0.06;
        attribute fieldOfView : Angle = 1.0472;
    }

    part def DepthSensor {
        port depthOut : ImageDataPort;
        attribute maxRange : Distance = 5.0;
        attribute minRange : Distance = 0.3;
        attribute accuracy : Distance = 0.01;
        attribute frameRate : Frequency = 30.0;
    }

    part def VisionSystem {
        port powerIn : PowerInPort;
        port imageDataOut : ImageDataPort;
        part leftCamera : StereoCamera;
        part rightCamera : StereoCamera;
        part depthSensor : DepthSensor;

        action def CaptureImages {
            out leftImage : ImageData;
            out rightImage : ImageData;
            out depth : DepthMap;
        }

        action def DetectObjects {
            in leftImage : ImageData;
            in rightImage : ImageData;
            in depth : DepthMap;
            out detections : ObjectDetection[0..*];
        }

        action def UpdateMap {
            in detections : ObjectDetection[0..*];
            in depth : DepthMap;
            out map : WorldMap;
        }
    }

    // ===== Parts: Audio System =====

    part def MicrophoneArray {
        port audioOut : AudioDataPort;
        attribute numMicrophones : Integer = 6;
        attribute sampleRate : Frequency = 48000.0;
        attribute maxRange : Distance = 5.0;
        attribute noiseCancellation : Boolean = true;
    }

    part def Speaker {
        port speechIn : SpeechInputPort;
        attribute maxOutputLevel : SoundPressureLevel = 85.0;
        attribute frequencyRange : Frequency = 20000.0;
    }

    part def AudioSystem {
        port powerIn : PowerInPort;
        port audioDataOut : AudioDataPort;
        port speechIn : SpeechInputPort;
        part micArray : MicrophoneArray;
        part leftSpeaker : Speaker;
        part rightSpeaker : Speaker;

        action def CaptureAudio {
            out audio : AudioData;
        }

        action def RecognizeSpeech {
            in audio : AudioData;
            out command : VoiceCommand;
        }

        action def SynthesizeSpeech {
            in text : String;
            out audio : AudioData;
        }
    }

    // ===== Parts: Locomotion System =====

    part def Joint {
        port commandIn : CommandInPort;
        attribute currentAngle : Angle;
        attribute maxTorque : Torque;
        attribute maxVelocity : AngularVelocity;
        attribute gearRatio : Real = 100.0;
    }

    part def Leg {
        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
        part hipJoint : Joint {
            attribute maxTorque : Torque = 120.0;
            attribute rangeOfMotion : Angle = 2.0944;
        }
        part kneeJoint : Joint {
            attribute maxTorque : Torque = 100.0;
            attribute rangeOfMotion : Angle = 2.0944;
        }
        part ankleJoint : Joint {
            attribute maxTorque : Torque = 80.0;
            attribute rangeOfMotion : Angle = 1.5708;
        }
    }

    part def LocomotionSystem {
        port powerIn : PowerInPort;
        port navGoalIn : NavigationInPort;
        port commandOut : CommandPort;
        port imuDataOut : IMUPort;
        part leftLeg : Leg;
        part rightLeg : Leg;
        attribute maxWalkingSpeed : LinearVelocity = 1.2;
        attribute stepHeight : Distance = 0.08;
        attribute strideLength : Distance = 0.5;

        action def WalkToGoal {
            in goal : NavigationGoal;
            out jointCommands : JointCommand[0..*];
        }

        action def StabilizeGait {
            in imu : IMUData;
            out adjustments : JointCommand[0..*];
        }
    }

    // ===== Parts: Balance Controller =====

    part def Gyroscope {
        port imuOut : IMUPort;
        attribute range : AngularVelocity = 10.0;
        attribute bandwidth : Frequency = 200.0;
        attribute noiseDensity : Real = 0.001;
    }

    part def Accelerometer {
        port imuOut : IMUPort;
        attribute range : Real { unit 'm/s^2'; } = 19.6;
        attribute bandwidth : Frequency = 200.0;
    }

    part def BalanceController {
        port powerIn : PowerInPort;
        port imuDataIn : IMUInPort;
        port locomotionCommandsOut : CommandPort;
        port safetyOut : SafetyPort;
        part gyro : Gyroscope;
        part accel : Accelerometer;
        attribute controlLoopRate : Frequency = 200.0;
        attribute maxTiltAngle : Angle = 0.1745;
        attribute stabilizationGain : Real = 0.8;

        action def ComputeBalanceAdjustments {
            in imu : IMUData;
            out adjustments : JointCommand[0..*];
            out safety : SafetyStatus;
        }

        action def EmergencyStabilize {
            out adjustments : JointCommand[0..*];
            out safety : SafetyStatus;
        }
    }

    // ===== Parts: Manipulation System =====

    part def Finger {
        port commandIn : CommandInPort;
        port tactileOut : TactileDataPort;
        attribute numJoints : Integer = 3;
        attribute maxGripForce : Force = 15.0;
        part joints : Joint[3];
        part tactileSensors : TactileSensor[4];
    }

    part def TactileSensor {
        port tactileOut : TactileDataPort;
        attribute maxPressure : Pressure = 500000.0;
        attribute sensitivity : Pressure = 100.0;
        attribute spatialResolution : Distance = 0.002;
    }

    part def Hand {
        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
        port tactileOut : TactileDataPort;
        part thumb : Finger;
        part indexFinger : Finger;
        part middleFinger : Finger;
        part ringFinger : Finger;
        part littleFinger : Finger;
        attribute maxPayload : Mass = 5.0;
    }

    part def Arm {
        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
        port tactileOut : TactileDataPort;
        part shoulderJoint : Joint {
            attribute maxTorque : Torque = 60.0;
            attribute rangeOfMotion : Angle = 3.1416;
        }
        part elbowJoint : Joint {
            attribute maxTorque : Torque = 45.0;
            attribute rangeOfMotion : Angle = 2.6180;
        }
        part wristJoint : Joint {
            attribute maxTorque : Torque = 25.0;
            attribute rangeOfMotion : Angle = 3.1416;
        }
        part hand : Hand;
        attribute reachLength : Distance = 0.65;
    }

    part def ManipulationSystem {
        port powerIn : PowerInPort;
        port leftArmCommandsIn : CommandInPort;
        port rightArmCommandsIn : CommandInPort;
        port tactileDataOut : TactileDataPort;
        part leftArm : Arm;
        part rightArm : Arm;
        attribute maxGripForce : Force = 20.0;
        attribute precisionLevel : Real = 0.95;

        action def GraspObject {
            in target : ObjectDetection;
            in tactile : TactileData[0..*];
            out armCommands : JointCommand[0..*];
        }

        action def ReleaseObject {
            out armCommands : JointCommand[0..*];
        }

        action def ManipulateObject {
            in target : ObjectDetection;
            in tactile : TactileData[0..*];
            out armCommands : JointCommand[0..*];
        }
    }

    // ===== Top-Level Gynoid System =====

    part def Gynoid {
        doc /* A female-presenting humanoid robot designed as an autonomous domestic assistant. */

        port powerIn : PowerInPort;

        part battery : Battery {
            attribute nominalVoltage : Voltage = 24.0;
        }

        part pdu : PowerDistributionUnit;

        part cognitiveCore : CognitiveCore;

        part visionSystem : VisionSystem;

        part audioSystem : AudioSystem;

        part locomotionSystem : LocomotionSystem;

        part balanceController : BalanceController;

        part manipulationSystem : ManipulationSystem;

        // Power distribution connections
        connection battery.powerOut to pdu.powerIn;
        connection pdu.powerOutCognitive to cognitiveCore.powerIn;
        connection pdu.powerOutVision to visionSystem.powerIn;
        connection pdu.powerOutAudio to audioSystem.powerIn;
        connection pdu.powerOutLocomotion to locomotionSystem.powerIn;
        connection pdu.powerOutBalance to balanceController.powerIn;
        connection pdu.powerOutManipulation to manipulationSystem.powerIn;

        // Vision data to cognitive core
        connection visionSystem.imageDataOut to cognitiveCore.imageDataIn;

        // Audio data to cognitive core, speech from cognitive core to audio
        connection audioSystem.audioDataOut to cognitiveCore.audioDataIn;
        connection cognitiveCore.speechOut to audioSystem.speechIn;

        // IMU data from balance controller to cognitive core
        connection balanceController.imuDataIn to cognitiveCore.imuDataIn;

        // Balance controller safety to cognitive core
        connection balanceController.safetyOut to cognitiveCore.safetyDataIn;

        // Balance controller commands to locomotion
        connection balanceController.locomotionCommandsOut to locomotionSystem.commandIn;

        // Navigation goals from cognitive core to locomotion
        connection cognitiveCore.navigationOut to locomotionSystem.navGoalIn;

        // Arm commands from cognitive core to manipulation
        connection cognitiveCore.leftArmCommands to manipulationSystem.leftArmCommandsIn;
        connection cognitiveCore.rightArmCommands to manipulationSystem.rightArmCommandsIn;

        // Tactile data from manipulation to cognitive core
        connection manipulationSystem.tactileDataOut to cognitiveCore.tactileDataIn;

        // Map data from vision to cognitive core (for planning)
        connection visionSystem.imageDataOut to cognitiveCore.mapDataIn;

        // Task plan output
        connection cognitiveCore.taskPlanOut to /* internal planning bus */ cognitiveCore.taskPlanIn;

        // Requirements satisfaction
        satisfy AutonomyRequirement by cognitiveCore;
        satisfy BatteryLifeRequirement by battery;
        satisfy SafeForceRequirement by manipulationSystem;
        satisfy CollisionAvoidanceRequirement by visionSystem;
        satisfy VoiceInteractionRequirement by audioSystem;
        satisfy BipedalMobilityRequirement by locomotionSystem;
        satisfy ManipulationRequirement by manipulationSystem;
        satisfy BalanceRequirement by balanceController;

        // Main operational scenario action
        action def DomesticTaskScenario {
            doc /* Typical scenario: robot receives voice command, navigates to target, grasps object, returns to user. */
            in command : VoiceCommand;
            out result : String;

            action perceiveCommand : CognitiveCore::RecognizeSpeech {
                in audio = command;
            }

            action planTask : CognitiveCore::PlanTask {
                in command = perceiveCommand.command;
            }

            action navigateToTarget : LocomotionSystem::WalkToGoal {
                in goal = planTask.plan;
            }

            action graspObject : ManipulationSystem::GraspObject {
                in target = /* detected object */ perceiveCommand.command;
            }

            action navigateToUser : LocomotionSystem::WalkToGoal {
                in goal = /* user location */ planTask.plan;
            }

            action deliverObject : ManipulationSystem::ReleaseObject;

            then perceiveCommand;
            then planTask;
            then navigateToTarget;
            then graspObject;
            then navigateToUser;
            then deliverObject;
        }
    }

}
