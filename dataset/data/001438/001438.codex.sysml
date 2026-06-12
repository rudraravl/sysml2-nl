package GynoidAssistanceSystem {

    import ScalarValues::*;
    import ISQ::*;

    attribute def Percent :> Real {
        unit = "%";
    }

    attribute def Probability :> Real {
        unit = "1";
    }

    attribute def DataRate :> Real {
        unit = "Mb/s";
    }

    attribute def ProcessingRate :> Real {
        unit = "TOPS";
    }

    attribute def Force :> Real {
        unit = "N";
    }

    attribute def Torque :> Real {
        unit = "N*m";
    }

    attribute def EnergyCapacity :> Real {
        unit = "W*h";
    }

    attribute def Power :> Real {
        unit = "W";
    }

    attribute def Distance :> Real {
        unit = "m";
    }

    attribute def Speed :> Real {
        unit = "m/s";
    }

    attribute def TimeDuration :> Real {
        unit = "s";
    }

    attribute def Temperature :> Real {
        unit = "degC";
    }

    attribute def SoundPressureLevel :> Real {
        unit = "dB";
    }

    item def VoiceCommand {
        attribute transcript : String;
        attribute confidence : Probability;
        attribute languageTag : String;
    }

    item def SpokenResponse {
        attribute phrase : String;
        attribute urgency : Integer;
        attribute volume : SoundPressureLevel;
    }

    item def VisualSceneFrame {
        attribute frameId : String;
        attribute resolutionWidth : Integer;
        attribute resolutionHeight : Integer;
        attribute detectedHumanCount : Integer;
        attribute hazardProbability : Probability;
    }

    item def TactileContact {
        attribute contactForce : Force;
        attribute bodyRegion : String;
        attribute contactDuration : TimeDuration;
    }

    item def NavigationGoal {
        attribute targetLocationName : String;
        attribute targetDistance : Distance;
        attribute requestedArrivalTime : TimeDuration;
    }

    item def ManipulationRequest {
        attribute objectLabel : String;
        attribute expectedMass : Real;
        attribute destinationLabel : String;
        attribute fragile : Boolean;
    }

    item def HealthTelemetry {
        attribute batteryStateOfCharge : Percent;
        attribute processorTemperature : Temperature;
        attribute motorTemperature : Temperature;
        attribute faultCount : Integer;
        attribute uptime : TimeDuration;
    }

    item def SafetyEvent {
        attribute eventCode : String;
        attribute severity : Integer;
        attribute description : String;
        attribute stopRequired : Boolean;
    }

    port def AudioInteractionPort {
        in item command : VoiceCommand;
        out item response : SpokenResponse;
    }

    port def VisionPort {
        out item scene : VisualSceneFrame;
    }

    port def TactilePort {
        out item contact : TactileContact;
    }

    port def MobilityCommandPort {
        in item goal : NavigationGoal;
        out item event : SafetyEvent;
    }

    port def ManipulationCommandPort {
        in item request : ManipulationRequest;
        out item event : SafetyEvent;
    }

    port def TelemetryPort {
        out item telemetry : HealthTelemetry;
        out item event : SafetyEvent;
    }

    part def SensorSuite {
        attribute visualFieldOfView : Real = 130.0;
        attribute audioCaptureRange : Distance = 7.0 [m];
        attribute tactileSamplingRate : Real = 250.0;
        attribute proximityRange : Distance = 4.0 [m];

        port vision : VisionPort;
        port tactile : TactilePort;

        part stereoCameras {
            attribute horizontalResolution : Integer = 3840;
            attribute verticalResolution : Integer = 2160;
            attribute frameRate : Real = 60.0;
        }

        part microphoneArray {
            attribute microphoneCount : Integer = 8;
            attribute noiseSuppressionEnabled : Boolean = true;
        }

        part proximitySensors {
            attribute sensorCount : Integer = 24;
            attribute minimumDetectionDistance : Distance = 0.05 [m];
        }

        part skinPressureGrid {
            attribute taxelCount : Integer = 18000;
            attribute maximumMeasuredForce : Force = 300.0 [N];
        }
    }

    part def CognitiveCore {
        attribute naturalLanguageConfidenceThreshold : Probability = 0.86;
        attribute sceneUnderstandingRate : ProcessingRate = 60.0 [TOPS];
        attribute memoryRetentionDays : Integer = 30;
        attribute privacyFilterEnabled : Boolean = true;

        port audio : AudioInteractionPort;
        port telemetry : TelemetryPort;

        part intentRecognizer {
            attribute supportedLanguages : Integer = 12;
            attribute maximumUtteranceDuration : TimeDuration = 20.0 [s];
        }

        part taskPlanner {
            attribute maxConcurrentTasks : Integer = 5;
            attribute replanningInterval : TimeDuration = 0.5 [s];
        }

        part socialInteractionManager {
            attribute politenessLevel : Integer = 8;
            attribute personalSpaceDistance : Distance = 1.2 [m];
        }

        action interpretCommand {
            in item command : VoiceCommand;
            out item response : SpokenResponse;
        }

        action planAssistanceTask {
            in item command : VoiceCommand;
            in item scene : VisualSceneFrame;
            out item navigationGoal : NavigationGoal;
            out item manipulationRequest : ManipulationRequest;
        }
    }

    part def MobilitySubsystem {
        attribute nominalWalkingSpeed : Speed = 1.2 [m/s];
        attribute maximumWalkingSpeed : Speed = 2.2 [m/s];
        attribute minimumStableStepLength : Distance = 0.12 [m];
        attribute fallRecoveryTime : TimeDuration = 8.0 [s];

        port command : MobilityCommandPort;

        part pelvisActuator {
            attribute peakTorque : Torque = 180.0 [N*m];
        }

        part leftLeg {
            attribute hipTorque : Torque = 150.0 [N*m];
            attribute kneeTorque : Torque = 120.0 [N*m];
            attribute ankleTorque : Torque = 90.0 [N*m];
        }

        part rightLeg {
            attribute hipTorque : Torque = 150.0 [N*m];
            attribute kneeTorque : Torque = 120.0 [N*m];
            attribute ankleTorque : Torque = 90.0 [N*m];
        }

        part balanceController {
            attribute stabilizationLoopRate : Real = 1000.0;
            attribute maxRecoverableTilt : Real = 18.0;
        }

        action walkToGoal {
            in item goal : NavigationGoal;
            out item event : SafetyEvent;
        }

        action holdPosition {
            out item event : SafetyEvent;
        }
    }

    part def ManipulationSubsystem {
        attribute maximumPayload : Real = 8.0;
        attribute nominalGripForce : Force = 35.0 [N];
        attribute maximumGripForce : Force = 120.0 [N];
        attribute placementAccuracy : Distance = 0.01 [m];

        port command : ManipulationCommandPort;

        part leftArm {
            attribute shoulderTorque : Torque = 85.0 [N*m];
            attribute elbowTorque : Torque = 55.0 [N*m];
            attribute wristTorque : Torque = 18.0 [N*m];
        }

        part rightArm {
            attribute shoulderTorque : Torque = 85.0 [N*m];
            attribute elbowTorque : Torque = 55.0 [N*m];
            attribute wristTorque : Torque = 18.0 [N*m];
        }

        part leftHand {
            attribute fingerCount : Integer = 5;
            attribute fingertipTactileSensors : Integer = 120;
        }

        part rightHand {
            attribute fingerCount : Integer = 5;
            attribute fingertipTactileSensors : Integer = 120;
        }

        action graspObject {
            in item request : ManipulationRequest;
            out item event : SafetyEvent;
        }

        action deliverObject {
            in item request : ManipulationRequest;
            out item event : SafetyEvent;
        }
    }

    part def PowerSubsystem {
        attribute batteryCapacity : EnergyCapacity = 2500.0 [W*h];
        attribute nominalVoltage : Real = 72.0;
        attribute continuousPowerLimit : Power = 1200.0 [W];
        attribute reserveThreshold : Percent = 15.0 [%];

        port telemetry : TelemetryPort;

        part batteryPack {
            attribute cellCount : Integer = 240;
            attribute stateOfCharge : Percent = 100.0 [%];
            attribute maxSafeTemperature : Temperature = 55.0 [degC];
        }

        part powerDistributionUnit {
            attribute regulatedBusCount : Integer = 6;
            attribute faultIsolationTime : TimeDuration = 0.02 [s];
        }

        action enterPowerSave {
            out item event : SafetyEvent;
        }

        action shutdownNonessentialLoads {
            out item telemetry : HealthTelemetry;
        }
    }

    part def SafetySupervisor {
        attribute humanSeparationMinimum : Distance = 0.45 [m];
        attribute emergencyStopLatency : TimeDuration = 0.05 [s];
        attribute maxAllowedSkinTemperature : Temperature = 42.0 [degC];
        attribute maxUncommandedForce : Force = 20.0 [N];

        port telemetry : TelemetryPort;

        action evaluateSafety {
            in item scene : VisualSceneFrame;
            in item contact : TactileContact;
            in item telemetry : HealthTelemetry;
            out item event : SafetyEvent;
        }

        action commandEmergencyStop {
            out item event : SafetyEvent;
        }
    }

    part def GynoidAssistant {
        doc /* Primary high-level function: provide safe, socially aware, mobile humanoid assistance by perceiving people and surroundings, interpreting spoken requests, navigating human spaces, manipulating everyday objects, and responding through natural speech while continuously supervising safety, privacy, and power state. */

        attribute overallHeight : Distance = 1.68 [m];
        attribute operatingEndurance : TimeDuration = 14400.0 [s];
        attribute assistanceAvailability : Percent = 99.0 [%];
        attribute indoorOperatingTemperatureMin : Temperature = 5.0 [degC];
        attribute indoorOperatingTemperatureMax : Temperature = 40.0 [degC];

        port userAudio : AudioInteractionPort;
        port externalTelemetry : TelemetryPort;

        part sensors : SensorSuite;
        part cognition : CognitiveCore;
        part mobility : MobilitySubsystem;
        part manipulation : ManipulationSubsystem;
        part power : PowerSubsystem;
        part safety : SafetySupervisor;

        connect userAudio to cognition.audio;
        connect cognition.telemetry to externalTelemetry;
        connect power.telemetry to safety.telemetry;
        connect safety.telemetry to externalTelemetry;

        flow sensors.vision.scene to cognition.planAssistanceTask.scene;
        flow sensors.tactile.contact to safety.evaluateSafety.contact;
        flow cognition.planAssistanceTask.navigationGoal to mobility.command.goal;
        flow cognition.planAssistanceTask.manipulationRequest to manipulation.command.request;
        flow mobility.command.event to safety.evaluateSafety;
        flow manipulation.command.event to safety.evaluateSafety;
        flow power.telemetry.telemetry to safety.evaluateSafety.telemetry;

        state def OperationalStateMachine {
            state off;
            state booting;
            state ready;
            state listening;
            state planning;
            state navigating;
            state manipulating;
            state speaking;
            state charging;
            state safeStop;
            state faultRecovery;

            transition first off then booting;
            transition booting then ready
                accept after 12.0 [s];

            transition ready then listening
                accept VoiceCommand;

            transition listening then planning
                if cognition.intentRecognizer.confidence >= cognition.naturalLanguageConfidenceThreshold;

            transition listening then speaking
                if cognition.intentRecognizer.confidence < cognition.naturalLanguageConfidenceThreshold;

            transition planning then navigating
                if cognition.taskPlanner.maxConcurrentTasks > 0;

            transition navigating then manipulating
                accept NavigationGoal;

            transition manipulating then speaking
                accept ManipulationRequest;

            transition speaking then ready
                accept after 3.0 [s];

            transition ready then charging
                if power.batteryPack.stateOfCharge <= power.reserveThreshold;

            transition charging then ready
                if power.batteryPack.stateOfCharge >= 90.0 [%];

            transition ready then safeStop
                accept SafetyEvent
                if SafetyEvent::stopRequired == true;

            transition listening then safeStop
                accept SafetyEvent
                if SafetyEvent::severity >= 8;

            transition navigating then safeStop
                accept SafetyEvent
                if SafetyEvent::severity >= 6;

            transition manipulating then safeStop
                accept SafetyEvent
                if SafetyEvent::severity >= 6;

            transition safeStop then faultRecovery
                accept after 2.0 [s];

            transition faultRecovery then ready
                if safety.maxUncommandedForce <= 20.0 [N];

            transition faultRecovery then off
                if power.batteryPack.stateOfCharge <= 5.0 [%];
        }

        action performPrimaryAssistance {
            in item command : VoiceCommand;
            out item response : SpokenResponse;

            first start;
            then perceiveEnvironment;
            then understandRequest;
            then evaluateRisk;
            then planTask;
            then moveIfNeeded;
            then manipulateIfNeeded;
            then communicateResult;
            then done;

            action perceiveEnvironment {
                out item scene : VisualSceneFrame;
                out item contact : TactileContact;
            }

            action understandRequest {
                in item command : VoiceCommand;
                out item interpretedCommand : VoiceCommand;
            }

            action evaluateRisk {
                in item scene : VisualSceneFrame;
                in item contact : TactileContact;
                out item event : SafetyEvent;
            }

            action planTask {
                in item interpretedCommand : VoiceCommand;
                out item goal : NavigationGoal;
                out item request : ManipulationRequest;
            }

            action moveIfNeeded {
                in item goal : NavigationGoal;
                out item event : SafetyEvent;
            }

            action manipulateIfNeeded {
                in item request : ManipulationRequest;
                out item event : SafetyEvent;
            }

            action communicateResult {
                out item response : SpokenResponse;
            }
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The gynoid assistant shall provide high-level humanoid assistance by understanding spoken user intent, perceiving the surrounding environment, navigating safely through human spaces, manipulating everyday objects, and communicating task status using natural speech. */
        subject assistant : GynoidAssistant;
        require constraint {
            assistant.assistanceAvailability >= 95.0 [%]
        }
    }

    requirement def SafetyRequirement {
        doc /* The system shall continuously supervise physical interaction and stop motion before contact forces or proximity hazards can exceed configured safe limits. */
        subject assistant : GynoidAssistant;
        require constraint {
            assistant.safety.emergencyStopLatency <= 0.05 [s] and
            assistant.safety.humanSeparationMinimum >= 0.45 [m]
        }
    }

    requirement def MobilityRequirement {
        doc /* The system shall navigate normal indoor spaces at human-compatible speed while maintaining balance and obstacle avoidance. */
        subject assistant : GynoidAssistant;
        require constraint {
            assistant.mobility.nominalWalkingSpeed <= 1.5 [m/s] and
            assistant.mobility.fallRecoveryTime <= 10.0 [s]
        }
    }

    requirement def ManipulationRequirement {
        doc /* The system shall grasp, carry, and place common household or workplace objects without exceeding payload, grip, or placement limits. */
        subject assistant : GynoidAssistant;
        require constraint {
            assistant.manipulation.maximumPayload >= 5.0 and
            assistant.manipulation.placementAccuracy <= 0.02 [m]
        }
    }

    requirement def PowerRequirement {
        doc /* The system shall operate long enough for a normal assistance session and enter protective power modes before battery depletion. */
        subject assistant : GynoidAssistant;
        require constraint {
            assistant.power.batteryCapacity >= 2000.0 [W*h] and
            assistant.power.reserveThreshold >= 10.0 [%]
        }
    }

    requirement def PrivacyRequirement {
        doc /* The system shall filter personally sensitive perception data before retention or external reporting. */
        subject assistant : GynoidAssistant;
        require constraint {
            assistant.cognition.privacyFilterEnabled == true and
            assistant.cognition.memoryRetentionDays <= 30
        }
    }

    satisfy PrimaryFunctionRequirement by GynoidAssistant;
    satisfy SafetyRequirement by GynoidAssistant.safety;
    satisfy MobilityRequirement by GynoidAssistant.mobility;
    satisfy ManipulationRequirement by GynoidAssistant.manipulation;
    satisfy PowerRequirement by GynoidAssistant.power;
    satisfy PrivacyRequirement by GynoidAssistant.cognition;

    part gynoidAssistantInstance : GynoidAssistant {
        attribute overallHeight = 1.68 [m];
        attribute operatingEndurance = 14400.0 [s];
        attribute assistanceAvailability = 99.0 [%];
    }
}