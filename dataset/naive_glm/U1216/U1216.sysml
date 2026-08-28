package SmartSpeakerSystem {

    import ScalarValues::*;

    // ============================================================
    // UNITS
    // ============================================================
    unit s;
    unit dB;
    unit Hz;
    unit bps;
    unit W;
    unit percent;

    // ============================================================
    // VALUE TYPES
    // ============================================================
    value type TimeValue > Real {
        unit s;
    }

    value type LatencyValue > Real {
        unit s;
    }

    value type SoundLevelValue > Real {
        unit dB;
    }

    value type FrequencyValue > Real {
        unit Hz;
    }

    value type DataRateValue > Real {
        unit bps;
    }

    value type PowerValue > Real {
        unit W;
    }

    value type AccuracyValue > Real {
        unit percent;
    }

    value type ConfidenceValue > Real {
        unit percent;
    }

    value type SignalStrengthValue > Real {
        unit percent;
    }

    // ============================================================
    // ENUMERATIONS
    // ============================================================
    enum def SpeakerStateEnum {
        literal idle;
        literal listening;
        literal processing;
        literal responding;
    }

    enum def IntentTypeEnum {
        literal query;
        literal mediaPlayback;
        literal smartHomeControl;
        literal other;
    }

    enum def LEDColorEnum {
        literal off;
        literal blue;
        literal cyan;
        literal orange;
        literal green;
        literal red;
    }

    // ============================================================
    // ITEM DEFINITIONS
    // ============================================================
    item def AcousticAudio {
        attribute level : SoundLevelValue;
        attribute duration : TimeValue;
    }

    item def DigitizedAudio {
        attribute sampleRate : FrequencyValue;
        attribute bitDepth : Integer;
        attribute duration : TimeValue;
    }

    item def WakeWordEvent {
        attribute keyword : String;
        attribute confidence : ConfidenceValue;
    }

    item def VoiceCommand {
        attribute capturedAudio : DigitizedAudio;
        attribute timestamp : TimeValue;
        attribute transcription : String;
    }

    item def NLPRequest {
        attribute command : VoiceCommand;
    }

    item def Intent {
        attribute intentType : IntentTypeEnum;
        attribute target : String;
        attribute parameters : String;
    }

    item def TextResponse {
        attribute content : String;
    }

    item def SmartHomeCommand {
        attribute target : String;
        attribute action : String;
    }

    item def NLPResponse {
        attribute intent : Intent;
        attribute textResponse : TextResponse;
        attribute smartHomeCommand : SmartHomeCommand;
    }

    item def SynthesizedSpeech {
        attribute audio : DigitizedAudio;
        attribute duration : TimeValue;
    }

    item def StatusUpdate {
        attribute state : SpeakerStateEnum;
        attribute ledColor : LEDColorEnum;
    }

    // ============================================================
    // PORT DEFINITIONS
    // ============================================================
    port def AcousticOutPort {
        out audio : AcousticAudio;
    }

    port def AcousticInPort {
        in audio : AcousticAudio;
    }

    port def WakeWordEventOutPort {
        out event : WakeWordEvent;
    }

    port def WakeWordEventInPort {
        in event : WakeWordEvent;
    }

    port def CommandOutPort {
        out command : VoiceCommand;
    }

    port def CommandInPort {
        in command : VoiceCommand;
    }

    port def RequestOutPort {
        out request : NLPRequest;
    }

    port def RequestInPort {
        in request : NLPRequest;
    }

    port def ResponseOutPort {
        out response : NLPResponse;
    }

    port def ResponseInPort {
        in response : NLPResponse;
    }

    port def TextOutPort {
        out text : TextResponse;
    }

    port def TextInPort {
        in text : TextResponse;
    }

    port def SpeechOutPort {
        out speech : SynthesizedSpeech;
    }

    port def SpeechInPort {
        in speech : SynthesizedSpeech;
    }

    port def HomeControlOutPort {
        out command : SmartHomeCommand;
    }

    port def HomeControlInPort {
        in command : SmartHomeCommand;
    }

    port def StatusOutPort {
        out status : StatusUpdate;
    }

    port def StatusInPort {
        in status : StatusUpdate;
    }

    // ============================================================
    // CONNECTION DEFINITIONS
    // ============================================================
    connection def AcousticLink {
        end source : AcousticOutPort;
        end target : AcousticInPort;
    }

    connection def CloudLink {
        end source : RequestOutPort;
        end target : RequestInPort;
    }

    connection def CloudResponseLink {
        end source : ResponseOutPort;
        end target : ResponseInPort;
    }

    connection def DeviceControlLink {
        end source : HomeControlOutPort;
        end target : HomeControlInPort;
    }

    // ============================================================
    // ACTION DEFINITIONS
    // ============================================================
    action def DetectWakeWord {
        in audio : DigitizedAudio;
        out event : WakeWordEvent;
    }

    action def CaptureCommand {
        in audio : DigitizedAudio;
        out command : VoiceCommand;
    }

    action def InterpretIntent {
        in command : VoiceCommand;
        out intent : Intent;
        out textResponse : TextResponse;
        out smartHomeCommand : SmartHomeCommand;
    }

    action def SynthesizeSpeechAction {
        in text : TextResponse;
        out speech : SynthesizedSpeech;
    }

    action def PlaybackAction {
        in speech : SynthesizedSpeech;
    }

    action def SendControlAction {
        in command : SmartHomeCommand;
    }

    action def UpdateLEDAction {
        in status : StatusUpdate;
    }

    // ============================================================
    // PART DEFINITIONS (COMPONENTS)
    // ============================================================
    part def MicrophoneArray {
        attribute elementCount : Integer = 6;
        attribute beamformingEnabled : Boolean = true;
        attribute noiseReductionEnabled : Boolean = true;
        attribute operatingLevel : SoundLevelValue;
        port audioOut : AcousticOutPort;

        action CaptureAudio {
            out audio = audioOut.audio;
        }
    }

    part def VoiceProcessingUnit {
        attribute alwaysOn : Boolean = true;
        attribute wakeWord : String = "Assistant";
        attribute confidenceThreshold : ConfidenceValue = 85;
        attribute recognitionAccuracy : AccuracyValue;
        attribute noiseReductionLevel : SoundLevelValue;
        port audioIn : AcousticInPort;
        port wakeWordOut : WakeWordEventOutPort;
        port commandOut : CommandOutPort;

        action detectWakeWord : DetectWakeWord {
            in audio = audioIn.audio;
            out event = wakeWordOut.event;
        }

        action captureCommand : CaptureCommand {
            in audio = audioIn.audio;
            out command = commandOut.command;
        }
    }

    part def NetworkInterface {
        attribute protocol : String = "Wi-Fi";
        attribute maxDataRate : DataRateValue;
        attribute signalStrength : SignalStrengthValue;
        attribute connected : Boolean = true;
        attribute reconnectionTime : TimeValue;
        port commandIn : CommandInPort;
        port requestOut : RequestOutPort;
        port responseIn : ResponseInPort;
        port textOut : TextOutPort;
        port homeControlOut : HomeControlOutPort;

        action TransmitRequest {
            in command = commandIn.command;
            out request = requestOut.request;
        }

        action ReceiveResponse {
            in response = responseIn.response;
            out text = textOut.text;
            out command = homeControlOut.command;
        }
    }

    part def CloudService {
        attribute serviceName : String = "CloudNLP";
        attribute processingLatency : LatencyValue;
        attribute availability : AccuracyValue;
        port requestIn : RequestInPort;
        port responseOut : ResponseOutPort;

        action interpretIntent : InterpretIntent {
            in command = requestIn.request.command;
            out intent = responseOut.response.intent;
            out textResponse = responseOut.response.textResponse;
            out smartHomeCommand = responseOut.response.smartHomeCommand;
        }
    }

    part def AudioSynthesizer {
        attribute engineType : String = "NeuralTTS";
        attribute voiceModel : String;
        attribute maxDuration : TimeValue;
        port textIn : TextInPort;
        port speechOut : SpeechOutPort;

        action synthesize : SynthesizeSpeechAction {
            in text = textIn.text;
            out speech = speechOut.speech;
        }
    }

    part def SpeakerUnit {
        attribute powerOutput : PowerValue;
        attribute frequencyRangeMin : FrequencyValue;
        attribute frequencyRangeMax : FrequencyValue;
        attribute impedance : Real;
        port speechIn : SpeechInPort;

        action playback : PlaybackAction {
            in speech = speechIn.speech;
        }
    }

    part def SmartHomeHub {
        attribute protocol : String = "Zigbee";
        attribute pairedDeviceCount : Integer;
        port commandIn : HomeControlInPort;
        port controlOut : HomeControlOutPort;

        action sendControl : SendControlAction {
            in command = commandIn.command;
            out command = controlOut.command;
        }
    }

    part def LEDIndicator {
        attribute currentColor : LEDColorEnum;
        attribute brightness : Real;
        attribute supportedColors : LEDColorEnum;
        port statusIn : StatusInPort;

        action updateLED : UpdateLEDAction {
            in status = statusIn.status;
        }
    }

    part def SmartHomeDevice {
        attribute deviceType : String;
        attribute deviceName : String;
        attribute online : Boolean = true;
        port controlIn : HomeControlInPort;

        action ExecuteCommand {
            in command = controlIn.command;
        }
    }

    // ============================================================
    // REQUIREMENT DEFINITIONS
    // ============================================================
    requirement def ResponseTimeRequirement {
        doc /* The system shall respond to user commands within 2.5 seconds end-to-end. */;
        attribute maxResponseTime : LatencyValue = 2.5;
        subject speaker : SmartSpeaker;
        objective {
            speaker.endToEndLatency <= maxResponseTime;
        }
    }

    requirement def RecognitionAccuracyRequirement {
        doc /* The system shall achieve high voice recognition accuracy even in noisy environments. */;
        attribute minAccuracy : AccuracyValue = 95;
        subject speaker : SmartSpeaker;
        objective {
            speaker.recognitionAccuracy >= minAccuracy;
        }
    }

    requirement def NetworkReliabilityRequirement {
        doc /* The system shall maintain reliable network connectivity for cloud communication. */;
        attribute minSignalStrength : SignalStrengthValue = 80;
        attribute maxReconnectionTime : TimeValue = 10;
        subject speaker : SmartSpeaker;
        objective {
            speaker.network.signalStrength >= minSignalStrength;
            speaker.network.reconnectionTime <= maxReconnectionTime;
        }
    }

    requirement def WakeWordDetectionRequirement {
        doc /* The voice processing unit shall continuously listen for the wake word at all times. */;
        subject vpu : VoiceProcessingUnit;
        objective {
            vpu.alwaysOn == true;
        }
    }

    requirement def NoiseReductionRequirement {
        doc /* The microphone array shall filter ambient background noise to ensure clarity. */;
        subject micArray : MicrophoneArray;
        objective {
            micArray.noiseReductionEnabled == true;
            micArray.beamformingEnabled == true;
        }
    }

    requirement def CloudNLPLatencyRequirement {
        doc /* The cloud service shall process and return intent within 1.5 seconds. */;
        attribute maxCloudLatency : LatencyValue = 1.5;
        subject cloud : CloudService;
        objective {
            cloud.processingLatency <= maxCloudLatency;
        }
    }

    requirement def AudioQualityRequirement {
        doc /* The speaker unit shall provide high-quality audio playback for responses. */;
        attribute minPowerOutput : PowerValue = 20;
        subject speakerUnit : SpeakerUnit;
        objective {
            speakerUnit.powerOutput >= minPowerOutput;
        }
    }

    // ============================================================
    // REQUIREMENT USAGES
    // ============================================================
    requirement responseTimeReq : ResponseTimeRequirement;
    requirement recognitionAccReq : RecognitionAccuracyRequirement;
    requirement networkRelReq : NetworkReliabilityRequirement;
    requirement wakeWordReq : WakeWordDetectionRequirement;
    requirement noiseReductionReq : NoiseReductionRequirement;
    requirement cloudLatencyReq : CloudNLPLatencyRequirement;
    requirement audioQualityReq : AudioQualityRequirement;

    // ============================================================
    // SMART SPEAKER (SYSTEM PART WITH STATE MACHINE)
    // ============================================================
    part def SmartSpeaker {
        attribute currentState : SpeakerStateEnum = idle;
        attribute endToEndLatency : LatencyValue;
        attribute recognitionAccuracy : AccuracyValue;
        attribute firmwareVersion : String = "1.0.0";

        // External ports for cloud and smart home communication
        port cloudRequestOut : RequestOutPort;
        port cloudResponseIn : ResponseInPort;
        port deviceControlOut : HomeControlOutPort;

        // Sub-components
        part micArray : MicrophoneArray {
            attribute elementCount = 6;
            attribute beamformingEnabled = true;
            attribute noiseReductionEnabled = true;
        }

        part voiceProcessor : VoiceProcessingUnit {
            attribute alwaysOn = true;
            attribute wakeWord = "Assistant";
            attribute confidenceThreshold = 85;
        }

        part network : NetworkInterface {
            attribute protocol = "Wi-Fi";
            attribute connected = true;
        }

        part synthesizer : AudioSynthesizer {
            attribute engineType = "NeuralTTS";
        }

        part speakerUnit : SpeakerUnit {
            attribute powerOutput = 30;
        }

        part homeHub : SmartHomeHub {
            attribute protocol = "Zigbee";
            attribute pairedDeviceCount = 8;
        }

        part led : LEDIndicator {
            attribute currentColor = off;
            attribute brightness = 0.5;
        }

        // Internal connections
        connect micArray.audioOut to voiceProcessor.audioIn : AcousticLink;
        connect voiceProcessor.commandOut to network.commandIn;
        connect network.textOut to synthesizer.textIn;
        connect synthesizer.speechOut to speakerUnit.speechIn;
        connect network.homeControlOut to homeHub.commandIn;
        connect network.requestOut to cloudRequestOut;
        connect cloudResponseIn to network.responseIn;
        connect homeHub.controlOut to deviceControlOut;

        // State machine
        state idle {
            entry {
                led.currentColor = off;
            }
            do action voiceProcessor.detectWakeWord;
        }

        state listening {
            entry {
                led.currentColor = blue;
            }
            do action voiceProcessor.captureCommand;
        }

        state processing {
            entry {
                led.currentColor = orange;
            }
            do action network.TransmitRequest;
        }

        state responding {
            entry {
                led.currentColor = green;
            }
            do action speakerUnit.playback;
            do action homeHub.sendControl;
        }

        transition idle to listening when voiceProcessor.wakeWordOut;
        transition listening to processing when voiceProcessor.commandOut;
        transition processing to responding when network.responseIn;
        transition responding to idle when speakerUnit.playback;

        // Satisfy requirements
        satisfy responseTimeReq;
        satisfy recognitionAccReq;
        satisfy networkRelReq;
        satisfy wakeWordReq;
        satisfy noiseReductionReq;
        satisfy audioQualityReq;
    }

    // ============================================================
    // SYSTEM CONTEXT (EXTERNAL CONNECTIONS)
    // ============================================================
    part def SystemContext {
        attribute systemName : String = "SmartSpeakerDeployment";

        part smartSpeaker : SmartSpeaker {
            attribute firmwareVersion = "1.0.0";
        }

        part cloud : CloudService {
            attribute serviceName = "CloudNLP";
            attribute processingLatency = 1.2;
            attribute availability = 99;
        }

        part livingRoomLight : SmartHomeDevice {
            attribute deviceType = "light";
            attribute deviceName = "Living Room Light";
            attribute online = true;
        }

        part homeThermostat : SmartHomeDevice {
            attribute deviceType = "thermostat";
            attribute deviceName = "Home Thermostat";
            attribute online = true;
        }

        part bedroomLight : SmartHomeDevice {
            attribute deviceType = "light";
            attribute deviceName = "Bedroom Light";
            attribute online = true;
        }

        // External connections
        connect smartSpeaker.cloudRequestOut to cloud.requestIn : CloudLink;
        connect cloud.responseOut to smartSpeaker.cloudResponseIn : CloudResponseLink;
        connect smartSpeaker.deviceControlOut to livingRoomLight.controlIn : DeviceControlLink;
        connect smartSpeaker.deviceControlOut to homeThermostat.controlIn : DeviceControlLink;
        connect smartSpeaker.deviceControlOut to bedroomLight.controlIn : DeviceControlLink;

        // Satisfy cloud latency requirement
        satisfy cloudLatencyReq;
    }
}
