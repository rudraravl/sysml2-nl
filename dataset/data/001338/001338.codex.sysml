package AlexaVoiceAssistantSystem {

    import ScalarValues::*;
    import ISQ::*;

    item def AudioSignal {
        attribute sampleRate : FrequencyValue;
        attribute bitDepth : Integer;
        attribute channels : Integer;
        attribute duration : TimeValue;
    }

    item def WakeWordDetection {
        attribute detectedPhrase : String;
        attribute confidence : Real;
        attribute detectionTime : TimeValue;
    }

    item def VoiceCommand {
        attribute utteranceText : String;
        attribute languageCode : String;
        attribute confidence : Real;
        attribute timestamp : TimeValue;
    }

    item def IntentRequest {
        attribute intentName : String;
        attribute slots : String;
        attribute confidence : Real;
    }

    item def CloudResponse {
        attribute responseText : String;
        attribute responseType : ResponseKind;
        attribute requiresDeviceAction : Boolean;
    }

    item def AudioResponse {
        attribute encodedSpeech : String;
        attribute volumeLevel : Real;
        attribute duration : TimeValue;
    }

    item def SmartHomeCommand {
        attribute targetDeviceId : String;
        attribute operation : SmartHomeOperation;
        attribute parameter : String;
    }

    item def NetworkPacket {
        attribute protocol : NetworkProtocol;
        attribute payloadSize : DataSizeValue;
        attribute encrypted : Boolean;
    }

    item def UserProfileData {
        attribute accountId : String;
        attribute preferredLanguage : String;
        attribute defaultRegion : String;
        attribute consentForPersonalization : Boolean;
    }

    enum def ResponseKind {
        enum spokenAnswer;
        enum smartHomeAction;
        enum mediaPlayback;
        enum informationQuery;
        enum errorMessage;
    }

    enum def SmartHomeOperation {
        enum turnOn;
        enum turnOff;
        enum setBrightness;
        enum setTemperature;
        enum lock;
        enum unlock;
    }

    enum def NetworkProtocol {
        enum wifi;
        enum tls;
        enum https;
        enum mqtt;
        enum bluetooth;
    }

    enum def AlexaOperationalMode {
        enum idle;
        enum listening;
        enum processing;
        enum responding;
        enum errorRecovery;
    }

    port def AudioInputPort {
        in item sound : AudioSignal;
    }

    port def AudioOutputPort {
        out item speech : AudioResponse;
    }

    port def CloudServicePort {
        out item request : NetworkPacket;
        in item response : NetworkPacket;
    }

    port def SmartHomePort {
        out item command : SmartHomeCommand;
        in item status : String;
    }

    port def UserProfilePort {
        out item query : String;
        in item profile : UserProfileData;
    }

    port def PowerPort {
        in attribute supplyVoltage : ElectricPotentialValue;
        in attribute availablePower : PowerValue;
    }

    part def MicrophoneArray {
        attribute microphoneCount : Integer = 7;
        attribute nominalSampleRate : FrequencyValue = 16000 [Hz];
        attribute sensitivity : Real;
        port audioOut : AudioInputPort;
    }

    part def WakeWordEngine {
        attribute supportedWakeWord : String = "Alexa";
        attribute minimumConfidence : Real = 0.85;
        in item ambientAudio : AudioSignal;
        out item wakeWord : WakeWordDetection;

        action detectWakeWord {
            in item inputAudio : AudioSignal;
            out item result : WakeWordDetection;
        }
    }

    part def SpeechCaptureProcessor {
        attribute maxCaptureDuration : TimeValue = 8 [s];
        attribute noiseReductionEnabled : Boolean = true;
        in item microphoneAudio : AudioSignal;
        in item trigger : WakeWordDetection;
        out item capturedCommand : AudioSignal;

        action isolateUserSpeech {
            in item rawAudio : AudioSignal;
            out item cleanedAudio : AudioSignal;
        }
    }

    part def LocalDeviceController {
        attribute currentMode : AlexaOperationalMode = AlexaOperationalMode::idle;
        attribute deviceId : String;
        attribute firmwareVersion : String;
        port power : PowerPort;
        port audioInput : AudioInputPort;
        port speakerOutput : AudioOutputPort;
        port cloud : CloudServicePort;
        port smartHome : SmartHomePort;

        part microphones : MicrophoneArray;
        part wakeWordEngine : WakeWordEngine;
        part speechProcessor : SpeechCaptureProcessor;
        part speaker : SpeakerSubsystem;

        connect microphones.audioOut to audioInput;
        connect speaker.audioIn to speakerOutput;

        state def AlexaDeviceStateMachine {
            state idle;
            state listening;
            state sendingToCloud;
            state waitingForResponse;
            state speaking;
            state controllingDevice;
            state fault;

            transition first idle;

            transition idle_to_listening
                first idle
                then listening
                accept WakeWordDetection
                if wakeWord.confidence >= 0.85;

            transition listening_to_sending
                first listening
                then sendingToCloud
                accept VoiceCommand;

            transition sending_to_waiting
                first sendingToCloud
                then waitingForResponse;

            transition waiting_to_speaking
                first waitingForResponse
                then speaking
                accept CloudResponse
                if response.responseType == ResponseKind::spokenAnswer;

            transition waiting_to_control
                first waitingForResponse
                then controllingDevice
                accept CloudResponse
                if response.responseType == ResponseKind::smartHomeAction;

            transition speaking_to_idle
                first speaking
                then idle;

            transition control_to_idle
                first controllingDevice
                then idle;

            transition any_to_fault
                first idle
                then fault
                accept String
                if true;

            transition fault_to_idle
                first fault
                then idle;
        }

        action handleVoiceInteraction {
            in item sound : AudioSignal;
            out item spokenReply : AudioResponse;

            action receiveAudio;
            action detectActivation;
            action captureSpeech;
            action transmitCommand;
            action receiveCloudResponse;
            action renderSpeech;

            flow receiveAudio to detectActivation;
            flow detectActivation to captureSpeech;
            flow captureSpeech to transmitCommand;
            flow transmitCommand to receiveCloudResponse;
            flow receiveCloudResponse to renderSpeech;
        }
    }

    part def SpeakerSubsystem {
        attribute maxSoundPressureLevel : Real;
        attribute nominalImpedance : ResistanceValue = 4 [Ohm];
        port audioIn : AudioOutputPort;

        action playSpeech {
            in item responseAudio : AudioResponse;
        }
    }

    part def WiFiNetworkInterface {
        attribute macAddress : String;
        attribute supportedBand2GHz : Boolean = true;
        attribute supportedBand5GHz : Boolean = true;
        attribute linkSpeed : DataRateValue;
        port cloudConnection : CloudServicePort;
    }

    part def AlexaCloudService {
        attribute serviceRegion : String;
        attribute availabilityTarget : Real = 0.999;
        port deviceEndpoint : CloudServicePort;
        port userProfileEndpoint : UserProfilePort;
        port smartHomeEndpoint : SmartHomePort;

        part speechRecognition : AutomaticSpeechRecognitionService;
        part languageUnderstanding : NaturalLanguageUnderstandingService;
        part responsePlanner : ResponsePlanningService;
        part speechSynthesis : TextToSpeechService;
        part profileManager : UserProfileService;
        part smartHomeSkill : SmartHomeSkillService;

        action processVoiceCommand {
            in item commandAudio : AudioSignal;
            out item response : CloudResponse;

            action convertSpeechToText;
            action identifyIntent;
            action resolveUserContext;
            action selectFulfillment;
            action generateResponse;

            flow convertSpeechToText to identifyIntent;
            flow identifyIntent to resolveUserContext;
            flow resolveUserContext to selectFulfillment;
            flow selectFulfillment to generateResponse;
        }
    }

    part def AutomaticSpeechRecognitionService {
        attribute supportedLanguages : String;
        attribute targetWordErrorRate : Real;
        in item audio : AudioSignal;
        out item command : VoiceCommand;

        action transcribe {
            in item speechAudio : AudioSignal;
            out item textCommand : VoiceCommand;
        }
    }

    part def NaturalLanguageUnderstandingService {
        attribute intentCatalogVersion : String;
        in item command : VoiceCommand;
        out item intent : IntentRequest;

        action classifyIntent {
            in item textCommand : VoiceCommand;
            out item interpretedIntent : IntentRequest;
        }
    }

    part def ResponsePlanningService {
        attribute maxResponseLatency : TimeValue = 2500 [ms];
        in item intent : IntentRequest;
        out item response : CloudResponse;

        action planResponse {
            in item interpretedIntent : IntentRequest;
            out item plannedResponse : CloudResponse;
        }
    }

    part def TextToSpeechService {
        attribute voiceName : String = "Alexa";
        attribute defaultSpeechRate : Real = 1.0;
        in item response : CloudResponse;
        out item audio : AudioResponse;

        action synthesizeSpeech {
            in item textResponse : CloudResponse;
            out item spokenAudio : AudioResponse;
        }
    }

    part def UserProfileService {
        attribute dataRetentionDays : Integer = 365;
        port profileAccess : UserProfilePort;

        action retrieveProfile {
            in item accountId : String;
            out item profile : UserProfileData;
        }
    }

    part def SmartHomeSkillService {
        attribute supportedDeviceClasses : String = "lights, plugs, locks, thermostats";
        port smartHomeAccess : SmartHomePort;

        action translateIntentToDeviceCommand {
            in item intent : IntentRequest;
            out item command : SmartHomeCommand;
        }
    }

    part def SmartHomeDevice {
        attribute deviceId : String;
        attribute deviceName : String;
        attribute online : Boolean;
        port commandReceiver : SmartHomePort;

        action executeCommand {
            in item command : SmartHomeCommand;
            out item status : String;
        }
    }

    part def AlexaBasedAssistantSystem {
        attribute primaryFunction : String =
            "Provide a hands-free voice interface that listens for a wake word, interprets spoken user requests through cloud services, and responds by speaking information, controlling connected devices, or initiating supported digital services.";

        part device : LocalDeviceController;
        part networkInterface : WiFiNetworkInterface;
        part cloudService : AlexaCloudService;
        part livingRoomLight : SmartHomeDevice {
            attribute deviceId = "light-living-room-01";
            attribute deviceName = "Living Room Light";
        }
        part thermostat : SmartHomeDevice {
            attribute deviceId = "thermostat-hallway-01";
            attribute deviceName = "Hallway Thermostat";
        }

        connect device.cloud to networkInterface.cloudConnection;
        connect networkInterface.cloudConnection to cloudService.deviceEndpoint;
        connect cloudService.smartHomeEndpoint to livingRoomLight.commandReceiver;
        connect cloudService.smartHomeEndpoint to thermostat.commandReceiver;
        connect device.smartHome to livingRoomLight.commandReceiver;
        connect device.smartHome to thermostat.commandReceiver;
    }

    requirement def VoiceAssistantPrimaryFunctionRequirement {
        subject system : AlexaBasedAssistantSystem;

        require constraint {
            system.primaryFunction != "";
        }

        doc
        /*
         * The Alexa-based assistant system shall provide a hands-free voice assistant capability
         * that detects the "Alexa" wake word, captures a spoken user request, sends the request
         * securely to cloud services for speech recognition and intent interpretation, and returns
         * a spoken or action-oriented response.
         */
    }

    requirement def WakeWordDetectionRequirement {
        subject engine : WakeWordEngine;

        require constraint {
            engine.minimumConfidence >= 0.85;
        }

        doc
        /*
         * The wake word engine shall activate command capture only when the detected wake word
         * confidence is at least 0.85.
         */
    }

    requirement def SpeechCaptureRequirement {
        subject processor : SpeechCaptureProcessor;

        require constraint {
            processor.maxCaptureDuration <= 10 [s];
        }

        doc
        /*
         * The speech capture processor shall isolate the user's command audio after wake word
         * detection and limit capture duration to prevent unintended continuous recording.
         */
    }

    requirement def CloudLatencyRequirement {
        subject planner : ResponsePlanningService;

        require constraint {
            planner.maxResponseLatency <= 3000 [ms];
        }

        doc
        /*
         * Cloud response planning shall complete within three seconds for ordinary voice
         * interactions under nominal network conditions.
         */
    }

    requirement def SecureNetworkRequirement {
        subject packet : NetworkPacket;

        require constraint {
            packet.encrypted == true;
        }

        doc
        /*
         * Voice request and response packets exchanged between the device and cloud service
         * shall be encrypted in transit.
         */
    }

    requirement def SmartHomeControlRequirement {
        subject system : AlexaBasedAssistantSystem;

        doc
        /*
         * When a recognized user intent targets a supported smart home device, the system shall
         * translate the intent into a device command and route it to the addressed device.
         */
    }

    requirement def SpokenResponseRequirement {
        subject speaker : SpeakerSubsystem;

        doc
        /*
         * The speaker subsystem shall render cloud-generated speech responses clearly enough for
         * the nearby user to hear the answer or confirmation.
         */
    }

    satisfy VoiceAssistantPrimaryFunctionRequirement by AlexaBasedAssistantSystem;
    satisfy WakeWordDetectionRequirement by WakeWordEngine;
    satisfy SpeechCaptureRequirement by SpeechCaptureProcessor;
    satisfy CloudLatencyRequirement by ResponsePlanningService;
    satisfy SmartHomeControlRequirement by SmartHomeSkillService;
    satisfy SpokenResponseRequirement by SpeakerSubsystem;

}