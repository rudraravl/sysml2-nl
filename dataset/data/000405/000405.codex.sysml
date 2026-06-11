package CimonBasedAssistantSystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;
    import USCustomaryUnits::*;

    attribute def ConfidenceLevel : Real {
        constraint range {
            0.0 <= this <= 1.0
        }
    }

    attribute def BatteryStateOfCharge : Real {
        constraint range {
            0.0 <= this <= 100.0
        }
        unit = "%";
    }

    attribute def DataRate : Real {
        unit = "Mbit/s";
    }

    attribute def SoundPressureLevel : Real {
        unit = "dB";
    }

    attribute def LuminousFlux : Real {
        unit = "lm";
    }

    item def VoiceCommand {
        attribute utterance : String;
        attribute speakerId : String;
        attribute recognizedIntent : String;
        attribute recognitionConfidence : ConfidenceLevel;
        attribute timeStamp : Time;
    }

    item def SpokenResponse {
        attribute phrase : String;
        attribute languageCode : String;
        attribute emotionalTone : String;
        attribute speechRate : Real;
    }

    item def CrewBiometricCue {
        attribute crewMemberId : String;
        attribute estimatedStress : ConfidenceLevel;
        attribute estimatedEngagement : ConfidenceLevel;
        attribute faceVisible : Boolean;
        attribute voiceStressDetected : Boolean;
    }

    item def VisualFrame {
        attribute widthPixels : Integer;
        attribute heightPixels : Integer;
        attribute frameRate : Real;
        attribute sceneBrightness : Real;
    }

    item def ProcedureStep {
        attribute procedureId : String;
        attribute stepId : String;
        attribute instructionText : String;
        attribute expectedConfirmation : String;
        attribute safetyCritical : Boolean;
    }

    item def NavigationCommand {
        attribute targetZone : String;
        attribute desiredDistanceFromCrew : LengthValue;
        attribute maximumVelocity : SpeedValue;
        attribute maintainFaceOrientation : Boolean;
    }

    item def TelemetryPacket {
        attribute batterySoc : BatteryStateOfCharge;
        attribute internalTemperature : TemperatureValue;
        attribute wirelessSignalQuality : ConfidenceLevel;
        attribute localizationConfidence : ConfidenceLevel;
        attribute currentMode : String;
    }

    item def GroundMessage {
        attribute messageId : String;
        attribute priority : Integer;
        attribute text : String;
        attribute requiresCrewAcknowledgement : Boolean;
    }

    port def AudioInputPort {
        in item voice : VoiceCommand;
    }

    port def AudioOutputPort {
        out item speech : SpokenResponse;
    }

    port def VisionInputPort {
        in item frame : VisualFrame;
        out item biometricCue : CrewBiometricCue;
    }

    port def ProcedureServicePort {
        in item requestedStep : ProcedureStep;
        out item guidedStep : ProcedureStep;
    }

    port def MobilityControlPort {
        out item motionCommand : NavigationCommand;
    }

    port def TelemetryPort {
        out item telemetry : TelemetryPacket;
        in item message : GroundMessage;
    }

    port def PowerPort {
        in item supplyVoltage : VoltageValue;
        out item loadCurrent : CurrentValue;
    }

    part def CimonDerivedCrewAssistant {
        attribute primaryFunction : String =
            "Provide an autonomous, voice-driven, free-floating companion that assists crew with procedures, contextual information, communication support, and well-being awareness in a crewed spacecraft environment.";

        attribute nominalMass : MassValue = 5.0 [kg];
        attribute outerDiameter : LengthValue = 0.32 [m];
        attribute maximumFreeFlightSpeed : SpeedValue = 0.20 [m / s];
        attribute minimumOperatingSoc : BatteryStateOfCharge = 20.0;
        attribute nominalOperatingSoc : BatteryStateOfCharge = 80.0;
        attribute acousticOutputLimit : SoundPressureLevel = 72.0;
        attribute cameraHorizontalFieldOfView : AngleValue = 120.0 [deg];
        attribute encryptedDataRate : DataRate = 25.0;

        port audioIn : AudioInputPort;
        port audioOut : AudioOutputPort;
        port vision : VisionInputPort;
        port procedureService : ProcedureServicePort;
        port mobility : MobilityControlPort;
        port groundLink : TelemetryPort;
        port power : PowerPort;

        part conversationalAi : ConversationalAiCore;
        part perceptionSuite : CrewAndScenePerceptionSuite;
        part procedureAssistant : ProcedureGuidanceManager;
        part freeFloatingMobility : MicrogravityMobilityController;
        part wellBeingMonitor : CrewWellBeingMonitor;
        part communicationsGateway : SpaceGroundCommunicationGateway;
        part powerSystem : RechargeablePowerSubsystem;
        part safetySupervisor : AssistantSafetySupervisor;

        connect audioIn to conversationalAi.voiceCommandPort;
        connect conversationalAi.responsePort to audioOut;
        connect vision to perceptionSuite.visionPort;
        connect perceptionSuite.biometricPort to wellBeingMonitor.biometricCuePort;
        connect conversationalAi.intentPort to procedureAssistant.intentPort;
        connect procedureAssistant.stepPort to procedureService;
        connect conversationalAi.navigationRequestPort to freeFloatingMobility.navigationRequestPort;
        connect freeFloatingMobility.motionPort to mobility;
        connect groundLink to communicationsGateway.telemetryPort;
        connect power to powerSystem.externalPowerPort;
        connect powerSystem.statusPort to safetySupervisor.powerStatusPort;
        connect perceptionSuite.sceneStatusPort to safetySupervisor.sceneStatusPort;
        connect safetySupervisor.motionLimitPort to freeFloatingMobility.safetyLimitPort;

        action performPrimaryMission {
            first startSession;
            then identifyCrewMember;
            then interpretCrewIntent;
            then selectAssistanceMode;
            then provideContextualSupport;
            then monitorCrewState;
            then reportTelemetry;

            action startSession {
                out item greeting : SpokenResponse;
            }

            action identifyCrewMember {
                in item frame : VisualFrame;
                in item command : VoiceCommand;
                out attribute crewIdentityConfidence : ConfidenceLevel;
            }

            action interpretCrewIntent {
                in item command : VoiceCommand;
                out attribute procedureRequested : Boolean;
                out attribute communicationRequested : Boolean;
                out attribute wellBeingSupportRequested : Boolean;
            }

            action selectAssistanceMode {
                in attribute procedureRequested : Boolean;
                in attribute communicationRequested : Boolean;
                in attribute wellBeingSupportRequested : Boolean;
                out attribute selectedMode : String;
            }

            action provideContextualSupport {
                in attribute selectedMode : String;
                out item response : SpokenResponse;
                out item step : ProcedureStep;
                out item navigation : NavigationCommand;
            }

            action monitorCrewState {
                in item cue : CrewBiometricCue;
                out attribute alertNeeded : Boolean;
            }

            action reportTelemetry {
                out item packet : TelemetryPacket;
            }
        }

        state def AssistantOperatingStateMachine {
            state off;
            state booting;
            state standby;
            state listening;
            state assistingProcedure;
            state companionDialogue;
            state relayingGroundMessage;
            state navigating;
            state charging;
            state safeHold;
            state fault;

            initial then off;

            transition off_to_booting
                first off
                accept PowerApplied
                then booting;

            transition booting_to_standby
                first booting
                accept SelfTestPassed
                then standby;

            transition booting_to_fault
                first booting
                accept SelfTestFailed
                then fault;

            transition standby_to_listening
                first standby
                accept WakeWordDetected
                then listening;

            transition listening_to_assistingProcedure
                first listening
                accept ProcedureIntentRecognized
                then assistingProcedure;

            transition listening_to_companionDialogue
                first listening
                accept ConversationIntentRecognized
                then companionDialogue;

            transition listening_to_relayingGroundMessage
                first listening
                accept GroundMessageReceived
                then relayingGroundMessage;

            transition assistingProcedure_to_navigating
                first assistingProcedure
                accept RepositionRequested
                then navigating;

            transition navigating_to_assistingProcedure
                first navigating
                accept TargetPoseReached
                then assistingProcedure;

            transition companionDialogue_to_standby
                first companionDialogue
                accept DialogueComplete
                then standby;

            transition assistingProcedure_to_standby
                first assistingProcedure
                accept ProcedureComplete
                then standby;

            transition relayingGroundMessage_to_standby
                first relayingGroundMessage
                accept MessageAcknowledged
                then standby;

            transition standby_to_charging
                first standby
                accept DockingPowerAvailable
                then charging;

            transition charging_to_standby
                first charging
                accept BatteryCharged
                then standby;

            transition any_to_safeHold
                first standby
                accept LowBatteryOrUnsafeProximity
                then safeHold;

            transition safeHold_to_standby
                first safeHold
                accept HazardCleared
                then standby;

            transition any_to_fault
                first standby
                accept CriticalFaultDetected
                then fault;
        }
    }

    part def ConversationalAiCore {
        attribute supportedLanguages : Integer = 2;
        attribute minimumIntentConfidence : ConfidenceLevel = 0.82;
        attribute localKnowledgeAvailable : Boolean = true;
        attribute privacyFilteringEnabled : Boolean = true;

        port voiceCommandPort : AudioInputPort;
        port responsePort : AudioOutputPort;

        port intentPort {
            out item command : VoiceCommand;
        }

        port navigationRequestPort {
            out item request : NavigationCommand;
        }

        action recognizeIntent {
            in item command : VoiceCommand;
            out attribute intentName : String;
            out attribute confidence : ConfidenceLevel;
        }

        action generateResponse {
            in attribute intentName : String;
            out item response : SpokenResponse;
        }
    }

    part def CrewAndScenePerceptionSuite {
        attribute cameraCount : Integer = 3;
        attribute microphoneCount : Integer = 7;
        attribute minimumFaceDetectionConfidence : ConfidenceLevel = 0.75;
        attribute minimumObstacleDistance : LengthValue = 0.30 [m];

        port visionPort : VisionInputPort;

        port biometricPort {
            out item cue : CrewBiometricCue;
        }

        port sceneStatusPort {
            out attribute nearestObstacleDistance : LengthValue;
            out attribute crewFaceTracked : Boolean;
            out attribute localizationConfidence : ConfidenceLevel;
        }

        action detectCrewFace {
            in item frame : VisualFrame;
            out attribute crewMemberId : String;
            out attribute confidence : ConfidenceLevel;
        }

        action estimateSceneSafety {
            in item frame : VisualFrame;
            out attribute nearestObstacleDistance : LengthValue;
            out attribute motionAllowed : Boolean;
        }
    }

    part def ProcedureGuidanceManager {
        attribute maximumActiveProcedureSteps : Integer = 1;
        attribute confirmationRequiredForCriticalSteps : Boolean = true;
        attribute procedureLibraryRevision : String = "ISS-CIMON-DERIVED-OPS-4";

        port intentPort {
            in item command : VoiceCommand;
        }

        port stepPort : ProcedureServicePort;

        action retrieveNextStep {
            in item command : VoiceCommand;
            out item step : ProcedureStep;
        }

        action verifyCrewConfirmation {
            in item command : VoiceCommand;
            in item step : ProcedureStep;
            out attribute confirmed : Boolean;
        }
    }

    part def MicrogravityMobilityController {
        attribute thrusterCount : Integer = 14;
        attribute nominalHoldDistanceFromCrew : LengthValue = 1.20 [m];
        attribute maximumAngularRate : Real = 15.0;
        attribute positionHoldTolerance : LengthValue = 0.08 [m];

        port navigationRequestPort {
            in item request : NavigationCommand;
        }

        port motionPort : MobilityControlPort;

        port safetyLimitPort {
            in attribute maximumAllowedSpeed : SpeedValue;
            in attribute motionInhibited : Boolean;
        }

        action holdRelativePose {
            in item request : NavigationCommand;
            out item command : NavigationCommand;
        }

        action stopMotion {
            out item command : NavigationCommand;
        }
    }

    part def CrewWellBeingMonitor {
        attribute stressAlertThreshold : ConfidenceLevel = 0.78;
        attribute disengagementThreshold : ConfidenceLevel = 0.65;
        attribute storesMedicalData : Boolean = false;

        port biometricCuePort {
            in item cue : CrewBiometricCue;
        }

        action evaluateCrewWellBeing {
            in item cue : CrewBiometricCue;
            out attribute recommendCheckIn : Boolean;
            out item supportiveResponse : SpokenResponse;
        }
    }

    part def SpaceGroundCommunicationGateway {
        attribute encryptionEnabled : Boolean = true;
        attribute maximumBufferedMessages : Integer = 50;
        attribute nominalLatency : TimeValue = 0.8 [s];

        port telemetryPort : TelemetryPort;

        action packageTelemetry {
            in item packet : TelemetryPacket;
            out item outboundPacket : TelemetryPacket;
        }

        action relayMessageToCrew {
            in item message : GroundMessage;
            out item response : SpokenResponse;
        }
    }

    part def RechargeablePowerSubsystem {
        attribute cellCount : Integer = 4;
        attribute nominalCapacity : EnergyValue = 90.0 [W * h];
        attribute nominalVoltage : VoltageValue = 14.8 [V];
        attribute maximumChargeCurrent : CurrentValue = 3.0 [A];

        port externalPowerPort : PowerPort;

        port statusPort {
            out attribute stateOfCharge : BatteryStateOfCharge;
            out attribute internalTemperature : TemperatureValue;
            out attribute powerAvailable : Boolean;
        }

        action estimateRemainingOperationTime {
            in attribute stateOfCharge : BatteryStateOfCharge;
            out attribute remainingTime : TimeValue;
        }
    }

    part def AssistantSafetySupervisor {
        attribute minimumAllowedObstacleDistance : LengthValue = 0.25 [m];
        attribute lowBatteryThreshold : BatteryStateOfCharge = 20.0;
        attribute safeHoldSpeedLimit : SpeedValue = 0.0 [m / s];

        port powerStatusPort {
            in attribute stateOfCharge : BatteryStateOfCharge;
            in attribute internalTemperature : TemperatureValue;
            in attribute powerAvailable : Boolean;
        }

        port sceneStatusPort {
            in attribute nearestObstacleDistance : LengthValue;
            in attribute crewFaceTracked : Boolean;
            in attribute localizationConfidence : ConfidenceLevel;
        }

        port motionLimitPort {
            out attribute maximumAllowedSpeed : SpeedValue;
            out attribute motionInhibited : Boolean;
        }

        action determineSafetyLimits {
            in attribute stateOfCharge : BatteryStateOfCharge;
            in attribute nearestObstacleDistance : LengthValue;
            in attribute localizationConfidence : ConfidenceLevel;
            out attribute motionInhibited : Boolean;
            out attribute maximumAllowedSpeed : SpeedValue;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject assistant : CimonDerivedCrewAssistant;

        doc
        /*
         The assistant shall provide autonomous high-level crew support by understanding spoken crew intent,
         presenting contextual procedural guidance, maintaining a safe free-floating position, relaying selected
         space-to-ground messages, and responding conversationally as a companion.
        */

        require constraint {
            assistant.conversationalAi.minimumIntentConfidence >= 0.80 and
            assistant.freeFloatingMobility.nominalHoldDistanceFromCrew >= 0.75 [m] and
            assistant.powerSystem.nominalCapacity >= 60.0 [W * h]
        }
    }

    requirement def SafeCrewInteractionRequirement {
        subject assistant : CimonDerivedCrewAssistant;

        doc
        /*
         The assistant shall inhibit free-flight motion whenever the estimated nearest obstacle distance is below
         the configured safety threshold, localization confidence is insufficient, or battery state of charge is low.
        */

        require constraint {
            assistant.safetySupervisor.minimumAllowedObstacleDistance >= 0.20 [m] and
            assistant.minimumOperatingSoc >= 15.0
        }
    }

    requirement def VoiceInteractionRequirement {
        subject assistant : CimonDerivedCrewAssistant;

        doc
        /*
         The assistant shall accept spoken crew commands and produce spoken responses for routine crew assistance
         without requiring physical controls during nominal operation.
        */

        require constraint {
            assistant.conversationalAi.supportedLanguages >= 1 and
            assistant.acousticOutputLimit <= 75.0
        }
    }

    requirement def ProcedureGuidanceRequirement {
        subject assistant : CimonDerivedCrewAssistant;

        doc
        /*
         The assistant shall guide a crew member through one active procedure step at a time and require explicit
         confirmation before advancing past safety-critical steps.
        */

        require constraint {
            assistant.procedureAssistant.maximumActiveProcedureSteps == 1 and
            assistant.procedureAssistant.confirmationRequiredForCriticalSteps == true
        }
    }

    requirement def PrivacyRequirement {
        subject assistant : CimonDerivedCrewAssistant;

        doc
        /*
         The assistant shall filter private conversational content before generating routine telemetry and shall not
         store medical data as part of well-being monitoring.
        */

        require constraint {
            assistant.conversationalAi.privacyFilteringEnabled == true and
            assistant.wellBeingMonitor.storesMedicalData == false
        }
    }

    part cimonBasedSystem : CimonDerivedCrewAssistant {
        attribute primaryFunction =
            "Act as a Cimon-inspired intelligent mobile companion that supports spacecraft crew through conversational assistance, procedural guidance, contextual awareness, safe positioning, and selected communications support.";
    }

    satisfy PrimaryFunctionRequirement by cimonBasedSystem;
    satisfy SafeCrewInteractionRequirement by cimonBasedSystem;
    satisfy VoiceInteractionRequirement by cimonBasedSystem;
    satisfy ProcedureGuidanceRequirement by cimonBasedSystem;
    satisfy PrivacyRequirement by cimonBasedSystem;
}