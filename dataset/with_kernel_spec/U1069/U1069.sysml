package GynoidDomesticAssistant {
    private import ScalarValues::*;

    // ---- Value types ----
    attribute def Distance :> Real;
    attribute def Force :> Real;
    attribute def Angle :> Real;
    attribute def Pressure :> Real;
    attribute def BatteryCharge :> Real;
    attribute def SoundLevel :> Real;
    attribute def Voltage :> Real;
    attribute def Current :> Real;
    attribute def Torque :> Real;

    // ---- Enumerations ----
    enum def OperationalStateKind {
        poweredOff;
        booting;
        ready;
        navigating;
        manipulating;
        returning;
        charging;
        error;
    }
    enum def JointKind {
        hip;
        knee;
        ankle;
        shoulder;
        elbow;
        wrist;
        finger;
    }
    enum def SafetyStatusKind {
        safe;
        caution;
        unsafe;
    }
    enum def TaskStatusKind {
        pending;
        inProgress;
        completed;
        failed;
    }

    // ---- Signal items for state machine events ----
    item def PowerOn;
    item def BootComplete;
    item def LowBatteryAlert;
    item def ArrivalAtTarget;
    item def GraspSuccessful;
    item def GraspFailed;
    item def ArrivalAtUser;
    item def ChargeComplete;
    item def RecoverySuccessful;
    item def CriticalFailure;
    item def Shutdown;

    // ---- Data item definitions ----
    item def VoiceCommand {
        attribute transcript : String;
        attribute intent : String;
        attribute targetObject : String;
        attribute targetLocation : String;
    }
    item def SpeechResponse {
        attribute text : String;
    }
    item def VisionData {
        attribute depthMap : String;
        attribute detectedObjects : String[*];
        attribute obstaclePresent : Boolean;
    }
    item def AudioInput {
        attribute waveform : String;
        attribute soundLevel : SoundLevel;
    }
    item def NavigationPlan {
        attribute waypoints : String[*];
        attribute estimatedDistance : Distance;
    }
    item def ManipulationPlan {
        attribute targetObject : String;
        attribute graspForceLimit : Force;
    }
    item def BatteryStatus {
        attribute chargeLevel : BatteryCharge;
        attribute voltage : Voltage;
    }
    item def SafetyAlert {
        attribute status : SafetyStatusKind;
        attribute description : String;
    }
    item def TactileData {
        attribute pressure : Pressure;
        attribute contactDetected : Boolean;
    }
    item def BalanceData {
        attribute angularVelocity : Angle;
        attribute linearAcceleration : Real;
        attribute stable : Boolean;
    }

    // ---- Port definitions ----
    port def PowerOut {
        out voltage : Voltage;
        out current : Current;
    }
    port def PowerIn {
        in voltage : Voltage;
        in current : Current;
    }
    port def VisionDataOut {
        out visionData : VisionData;
    }
    port def VisionDataIn {
        in visionData : VisionData;
    }
    port def AudioOut {
        out audioInput : AudioInput;
    }
    port def CommandOut {
        out command : VoiceCommand;
    }
    port def CommandIn {
        in command : VoiceCommand;
    }
    port def SpeechOut {
        out response : SpeechResponse;
    }
    port def SpeechIn {
        in response : SpeechResponse;
    }
    port def BalanceOut {
        out balanceData : BalanceData;
    }
    port def BalanceIn {
        in balanceData : BalanceData;
    }
    port def TactileOut {
        out tactileData : TactileData;
    }
    port def TactileIn {
        in tactileData : TactileData;
    }
    port def BatteryStatusOut {
        out status : BatteryStatus;
    }
    port def BatteryStatusIn {
        in status : BatteryStatus;
    }
    port def SafetyOut {
        out alert : SafetyAlert;
    }
    port def SafetyIn {
        in alert : SafetyAlert;
    }
    port def MotorCmdOut {
        out targetAngle : Angle;
        out targetForce : Force;
    }
    port def MotorCmdIn {
        in targetAngle : Angle;
        in targetForce : Force;
    }
    port def NavCmdOut {
        out plan : NavigationPlan;
    }
    port def NavCmdIn {
        in plan : NavigationPlan;
    }
    port def ManipCmdOut {
        out plan : ManipulationPlan;
    }
    port def ManipCmdIn {
        in plan : ManipulationPlan;
    }

    // ---- Action definitions ----
    action def initializeSystems;
    action def observeEnvironment;
    action def processVoiceCommand;
    action def executeNavigation;
    action def executeManipulation;
    action def returnToUser;
    action def chargeBattery;
    action def assessError;
    action def monitorCharge;
    action def distributePower;
    action def captureImage;
    action def senseDepth;
    action def processVision;
    action def captureAudio;
    action def playAudio;
    action def processAudio;
    action def synthesizeSpeech;
    action def actuate;
    action def walk;
    action def measureAngularVelocity;
    action def measureAcceleration;
    action def maintainBalance;
    action def sensePressure;
    action def grasp;
    action def performTask;
    action def monitorSafety;
    action def processCommand;

    // ---- Part definitions ----
    part def Battery {
        attribute chargeLevel : BatteryCharge = 100.0;
        attribute nominalVoltage : Voltage = 48.0;
        port powerOut : PowerOut;
        port statusOut : BatteryStatusOut;
        perform action monitorCharge;
    }

    part def PowerDistributionModule {
        port powerIn : PowerIn;
        port powerOut : PowerOut[7];
        port batteryStatusIn : BatteryStatusIn;
        perform action distributePower;
    }

    part def StereoCamera {
        attribute resolution : String = "1920x1080";
        port powerIn : PowerIn;
        port visionDataOut : VisionDataOut;
        perform action captureImage;
    }

    part def DepthSensor {
        attribute maxRange : Distance = 5.0;
        port powerIn : PowerIn;
        port visionDataOut : VisionDataOut;
        perform action senseDepth;
    }

    part def VisionSystem {
        part leftCamera : StereoCamera;
        part rightCamera : StereoCamera;
        part depthSensor : DepthSensor;
        port visionDataOut : VisionDataOut;
        port powerIn : PowerIn;
        perform action processVision;
    }

    part def MicrophoneArray {
        attribute numberOfMicrophones : Integer = 4;
        port powerIn : PowerIn;
        port audioOut : AudioOut;
        perform action captureAudio;
    }

    part def Speaker {
        attribute maxOutputLevel : SoundLevel = 80;
        port powerIn : PowerIn;
        port speechOut : SpeechOut;
        perform action playAudio;
    }

    part def AudioSystem {
        part microphoneArray : MicrophoneArray;
        part speaker : Speaker;
        port audioOut : AudioOut;
        port commandOut : CommandOut;
        port speechIn : SpeechIn;
        port powerIn : PowerIn;
        perform action processAudio;
        perform action synthesizeSpeech;
    }

    part def MotorizedJoint {
        attribute jointKind : JointKind;
        attribute currentAngle : Angle;
        attribute maxForce : Force;
        port motorCmdIn : MotorCmdIn;
        port powerIn : PowerIn;
        perform action actuate;
    }

    part def Leg {
        part hipJoint : MotorizedJoint { :>> jointKind = JointKind::hip; }
        part kneeJoint : MotorizedJoint { :>> jointKind = JointKind::knee; }
        part ankleJoint : MotorizedJoint { :>> jointKind = JointKind::ankle; }
        port powerIn : PowerIn;
    }

    part def BipedalLocomotionSystem {
        part leftLeg : Leg;
        part rightLeg : Leg;
        port navCmdIn : NavCmdIn;
        port motorCmdIn : MotorCmdIn[2];
        port powerIn : PowerIn;
        perform action walk;
    }

    part def Gyroscope {
        port powerIn : PowerIn;
        port balanceOut : BalanceOut;
        perform action measureAngularVelocity;
    }

    part def Accelerometer {
        port powerIn : PowerIn;
        port balanceOut : BalanceOut;
        perform action measureAcceleration;
    }

    part def BalanceController {
        part gyroscope : Gyroscope;
        part accelerometer : Accelerometer;
        port balanceOut : BalanceOut;
        port motorCmdOut : MotorCmdOut[2];
        port powerIn : PowerIn;
        attribute stable : Boolean = true;
        perform action maintainBalance;
    }

    part def TactileSensor {
        attribute pressureThreshold : Pressure = 50000;
        port tactileOut : TactileOut;
        port powerIn : PowerIn;
        perform action sensePressure;
    }

    part def Finger {
        part joints : MotorizedJoint[3] { :>> jointKind = JointKind::finger; }
        part tactileSensor : TactileSensor;
        port tactileOut : TactileOut;
        port powerIn : PowerIn;
    }

    part def Hand {
        part fingers : Finger[5];
        port tactileOut : TactileOut;
        port motorCmdIn : MotorCmdIn;
        port powerIn : PowerIn;
        attribute maxGraspForce : Force = 20;
        perform action grasp;
    }

    part def Arm {
        part shoulderJoint : MotorizedJoint { :>> jointKind = JointKind::shoulder; }
        part elbowJoint : MotorizedJoint { :>> jointKind = JointKind::elbow; }
        part wristJoint : MotorizedJoint { :>> jointKind = JointKind::wrist; }
        part hand : Hand;
        port motorCmdIn : MotorCmdIn;
        port tactileOut : TactileOut;
        port powerIn : PowerIn;
    }

    part def ManipulationSystem {
        part leftArm : Arm;
        part rightArm : Arm;
        port manipCmdIn : ManipCmdIn;
        port tactileOut : TactileOut[2];
        port powerIn : PowerIn;
        perform action performTask;
    }

    part def SafetyController {
        port safetyOut : SafetyOut;
        port visionDataIn : VisionDataIn;
        port tactileIn : TactileIn;
        attribute maxAppliedForce : Force = 30;
        attribute collisionDetectionEnabled : Boolean = true;
        port powerIn : PowerIn;
        perform action monitorSafety;
    }

    part def CognitiveCore {
        port visionDataIn : VisionDataIn;
        port commandIn : CommandIn;
        port speechOut : SpeechOut;
        port balanceIn : BalanceIn;
        port tactileIn : TactileIn;
        port batteryStatusIn : BatteryStatusIn;
        port safetyIn : SafetyIn;
        port navCmdOut : NavCmdOut;
        port manipCmdOut : ManipCmdOut;
        attribute currentMap : String;
        attribute currentTask : VoiceCommand;
        attribute taskStatus : TaskStatusKind = TaskStatusKind::pending;
        port powerIn : PowerIn;
        perform action processCommand;
    }

    // ---- State machine definition ----
    state def GynoidOperationalStates {
        entry; then PoweredOff;
        state PoweredOff;
        transition first PoweredOff accept PowerOn then Booting;
        state Booting {
            do action initializeSystems;
            entry; then Initializing;
            state Initializing;
            transition first Initializing accept BootComplete then Ready;
        }
        state Ready;
        transition first Ready accept command : VoiceCommand then Navigating;
        transition first Ready accept LowBatteryAlert then Charging;
        state Navigating {
            do action executeNavigation;
            entry; then MovingToTarget;
            state MovingToTarget;
            transition first MovingToTarget accept ArrivalAtTarget then Manipulating;
            transition first MovingToTarget accept alert : SafetyAlert then ErrorRecovery;
        }
        state Manipulating {
            do action executeManipulation;
            entry; then GraspingObject;
            state GraspingObject;
            transition first GraspingObject accept GraspSuccessful then Returning;
            transition first GraspingObject accept GraspFailed then ErrorRecovery;
        }
        state Returning {
            do action returnToUser;
            entry; then MovingToUser;
            state MovingToUser;
            transition first MovingToUser accept ArrivalAtUser then Ready;
        }
        state Charging;
        transition first Charging accept ChargeComplete then Ready;
        state ErrorRecovery {
            do action assessError;
            entry; then Assessing;
            state Assessing;
            transition first Assessing accept RecoverySuccessful then Ready;
            transition first Assessing accept CriticalFailure then PoweredOff;
        }
        accept Shutdown then done;
    }

    // ---- Requirements ----
    requirement def DomesticAssistanceCapability {
        doc /* The gynoid shall execute voice commands from household occupants. */
        subject gynoid : Gynoid;
    }
    requirement def SafetyRequirement {
        doc /* The gynoid shall not apply more than 30 N of force during manipulation and shall detect and avoid collisions. */
        subject gynoid : Gynoid;
    }
    requirement def AutonomyRequirement {
        doc /* The gynoid shall operate for at least 4 hours on a full charge and navigate autonomously within a home environment. */
        subject gynoid : Gynoid;
    }
    requirement def InteractionRequirement {
        doc /* The gynoid shall understand spoken commands and generate clear synthesized speech responses. */
        subject gynoid : Gynoid;
    }

    // ---- Main Gynoid part definition ----
    part def Gynoid {
        part battery : Battery;
        part powerDistributionModule : PowerDistributionModule;
        part cognitiveCore : CognitiveCore;
        part visionSystem : VisionSystem;
        part audioSystem : AudioSystem;
        part bipedalLocomotionSystem : BipedalLocomotionSystem;
        part balanceController : BalanceController;
        part manipulationSystem : ManipulationSystem;
        part safetyController : SafetyController;
        attribute name : String = "Gynoid-01";
        attribute operationalState : OperationalStateKind = OperationalStateKind::poweredOff;

        connect battery.powerOut to powerDistributionModule.powerIn;
        connect battery.statusOut to powerDistributionModule.batteryStatusIn;
        connect powerDistributionModule.powerOut[1] to cognitiveCore.powerIn;
        connect powerDistributionModule.powerOut[2] to visionSystem.powerIn;
        connect powerDistributionModule.powerOut[3] to audioSystem.powerIn;
        connect powerDistributionModule.powerOut[4] to bipedalLocomotionSystem.powerIn;
        connect powerDistributionModule.powerOut[5] to balanceController.powerIn;
        connect powerDistributionModule.powerOut[6] to manipulationSystem.powerIn;
        connect powerDistributionModule.powerOut[7] to safetyController.powerIn;

        connect visionSystem.visionDataOut to cognitiveCore.visionDataIn;
        connect visionSystem.visionDataOut to safetyController.visionDataIn;

        connect audioSystem.commandOut to cognitiveCore.commandIn;
        connect cognitiveCore.speechOut to audioSystem.speechIn;

        connect balanceController.balanceOut to cognitiveCore.balanceIn;

        connect battery.statusOut to cognitiveCore.batteryStatusIn;

        connect manipulationSystem.tactileOut[1] to cognitiveCore.tactileIn;
        connect manipulationSystem.tactileOut[2] to safetyController.tactileIn;

        connect safetyController.safetyOut to cognitiveCore.safetyIn;

        connect cognitiveCore.navCmdOut to bipedalLocomotionSystem.navCmdIn;
        connect cognitiveCore.manipCmdOut to manipulationSystem.manipCmdIn;

        connect balanceController.motorCmdOut[1] to bipedalLocomotionSystem.motorCmdIn[1];
        connect balanceController.motorCmdOut[2] to bipedalLocomotionSystem.motorCmdIn[2];

        exhibit operationalStates : GynoidOperationalStates;

        satisfy DomesticAssistanceCapability;
        satisfy SafetyRequirement;
        satisfy AutonomyRequirement;
        satisfy InteractionRequirement;
    }

    // ---- Gynoid instance ----
    part domesticAssistantGynoid : Gynoid {
        :>> name = "Aria";

        :>> battery {
            :>> chargeLevel = 92.0;
        }

        :>> visionSystem {
            :>> leftCamera {
                :>> resolution = "1920x1080";
            }
            :>> rightCamera {
                :>> resolution = "1920x1080";
            }
            :>> depthSensor {
                :>> maxRange = 5.0;
            }
        }

        :>> audioSystem {
            :>> microphoneArray {
                :>> numberOfMicrophones = 4;
            }
            :>> speaker {
                :>> maxOutputLevel = 75;
            }
        }

        :>> bipedalLocomotionSystem {
            :>> leftLeg {
                :>> hipJoint { :>> maxForce = 120; }
                :>> kneeJoint { :>> maxForce = 100; }
                :>> ankleJoint { :>> maxForce = 80; }
            }
            :>> rightLeg {
                :>> hipJoint { :>> maxForce = 120; }
                :>> kneeJoint { :>> maxForce = 100; }
                :>> ankleJoint { :>> maxForce = 80; }
            }
        }

        :>> manipulationSystem {
            :>> leftArm {
                :>> shoulderJoint { :>> maxForce = 60; }
                :>> elbowJoint { :>> maxForce = 50; }
                :>> wristJoint { :>> maxForce = 30; }
                :>> hand { :>> maxGraspForce = 15; }
            }
            :>> rightArm {
                :>> shoulderJoint { :>> maxForce = 60; }
                :>> elbowJoint { :>> maxForce = 50; }
                :>> wristJoint { :>> maxForce = 30; }
                :>> hand { :>> maxGraspForce = 15; }
            }
        }

        :>> safetyController {
            :>> maxAppliedForce = 25;
            :>> collisionDetectionEnabled = true;
        }
    }
}
