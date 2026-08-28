package AlexaVoiceAssistant {
    public import ScalarValues::*;
    public import ScalarFunctions::*;
    
    // ===== Value Types with Units =====
    
    item def AudioSample {
        value amplitude: Real;
        value timestamp: TimeValue;
    }
    
    value type TimeValue :> Real {
        private import SI::s;
        unit s;
    }
    
    value type FrequencyValue :> Real {
        private import SI::Hz;
        unit Hz;
    }
    
    value type PowerValue :> Real {
        private import SI::W;
        unit W;
    }
    
    value type DecibelValue :> Real {
        unit dB;
    }
    
    value type DataRateValue :> Real {
        private import SI::bit;
        unit bit_per_s;
    }
    
    item def TextData {
        value content: String;
        value language: String;
    }
    
    item def IntentData {
        value intentName: String;
        value confidence: Real;
        value slots: String;
    }
    
    item def ResponseData {
        value responseText: String;
        value actionType: String;
        value targetDevice: String;
    }
    
    item def SmartHomeCommand {
        value deviceType: String;
        value deviceId: String;
        value action: String;
        value paramValue: Real;
    }
    
    // ===== Port Definitions =====
    
    port def AudioOutPort {
        out audioStream: AudioSample;
    }
    
    port def AudioInPort {
        in audioStream: AudioSample;
    }
    
    port def TextPort {
        out textData: TextData;
        in textResponse: TextData;
    }
    
    port def IntentPort {
        out intentData: IntentData;
    }
    
    port def NetworkPort {
        out requestPayload: TextData;
        in responsePayload: ResponseData;
    }
    
    port def SmartHomePort {
        out command: SmartHomeCommand;
    }
    
    port def ControlPort {
        out wakeSignal: Boolean;
        out processingComplete: Boolean;
    }
    
    // ===== Microphone Array =====
    
    part def Microphone {
        attribute id: Integer;
        attribute sensitivity: DecibelValue = -40 [dB];
        port audioOut: AudioOutPort;
        
        action def CaptureAudio {
            in audioInput: AudioSample;
            out capturedAudio: AudioSample;
        }
    }
    
    part def MicrophoneArray {
        attribute micCount: Integer = 7;
        part microphones: Microphone[7];
        port aggregatedAudioOut: AudioOutPort;
        
        action def Beamform {
            in rawInputs: AudioSample[7];
            out beamformedAudio: AudioSample;
        }
    }
    
    // ===== Speaker =====
    
    part def Speaker {
        attribute maxPower: PowerValue = 30 [W];
        attribute frequencyRange: FrequencyValue = 20000 [Hz];
        port audioIn: AudioInPort;
        
        action def PlayAudio {
            in audioInput: AudioSample;
        }
    }
    
    // ===== Wake Word Engine =====
    
    part def WakeWordEngine {
        attribute wakeWord: String = "Alexa";
        attribute detectionThreshold: Real = 0.85;
        port audioIn: AudioInPort;
        port controlOut: ControlPort;
        
        action def DetectWakeWord {
            in audioStream: AudioSample;
            out wakeDetected: Boolean;
        }
    }
    
    // ===== ASR Engine =====
    
    part def ASREngine {
        port audioIn: AudioInPort;
        port textOut: TextPort;
        
        action def RecognizeSpeech {
            in audioInput: AudioSample;
            out recognizedText: TextData;
        }
    }
    
    // ===== NLU Unit =====
    
    part def NLUUnit {
        port textIn: TextPort;
        port intentOut: IntentPort;
        
        action def UnderstandNaturalLanguage {
            in inputText: TextData;
            out extractedIntent: IntentData;
        }
    }
    
    // ===== Network Interface =====
    
    part def NetworkInterface {
        attribute bandwidth: DataRateValue = 1000000 [bit_per_s];
        attribute connectionStatus: String = "connected";
        port cloudPort: NetworkPort;
        
        action def TransmitRequest {
            in request: TextData;
            out response: ResponseData;
        }
    }
    
    // ===== Cloud Alexa Voice Service =====
    
    part def AlexaVoiceService {
        attribute serviceName: String = "AlexaVoiceService";
        port networkIn: NetworkPort;
        port smartHomeOut: SmartHomePort;
        
        action def ProcessRequest {
            in intent: IntentData;
            out response: ResponseData;
        }
        
        action def ExecuteSkill {
            in skillId: String;
            out result: ResponseData;
        }
        
        action def QueryKnowledgeBase {
            in query: String;
            out answer: ResponseData;
        }
    }
    
    // ===== TTS Engine =====
    
    part def TTSEngine {
        attribute voiceProfile: String = "NaturalAlexa";
        port textIn: TextPort;
        port audioOut: AudioOutPort;
        
        action def SynthesizeSpeech {
            in inputText: TextData;
            out synthesizedAudio: AudioSample;
        }
    }
    
    // ===== Smart Home Controller =====
    
    part def SmartHomeController {
        port commandIn: SmartHomePort;
        port deviceControlOut: SmartHomePort;
        
        action def ControlDevice {
            in command: SmartHomeCommand;
            out deviceCommand: SmartHomeCommand;
        }
    }
    
    // ===== Smart Home Devices =====
    
    part def SmartLight {
        attribute deviceId: String;
        attribute state: String = "off";
        attribute brightness: Real = 0.0;
        port commandIn: SmartHomePort;
        
        action def SetBrightness {
            in level: Real;
        }
    }
    
    part def Thermostat {
        attribute deviceId: String;
        attribute currentTemp: Real = 22.0;
        attribute targetTemp: Real = 22.0;
        port commandIn: SmartHomePort;
        
        action def SetTemperature {
            in target: Real;
        }
    }
    
    // ===== Smart Speaker (Top-level) =====
    
    part def SmartSpeaker {
        part micArray: MicrophoneArray {
            part microphones redefines microphones = [
                Microphone{ id = 1; },
                Microphone{ id = 2; },
                Microphone{ id = 3; },
                Microphone{ id = 4; },
                Microphone{ id = 5; },
                Microphone{ id = 6; },
                Microphone{ id = 7; }
            ];
        }
        
        part speaker: Speaker;
        part wakeWordEngine: WakeWordEngine;
        part asrEngine: ASREngine;
        part nluUnit: NLUUnit;
        part networkInterface: NetworkInterface;
        part ttsEngine: TTSEngine;
        part smartHomeController: SmartHomeController;
        part smartLight: SmartLight;
        part thermostat: Thermostat;
        
        connection micToWake connect micArray.aggregatedAudioOut to wakeWordEngine.audioIn;
        connection micToASR connect micArray.aggregatedAudioOut to asrEngine.audioIn;
        connection asrToNLU connect asrEngine.textOut to nluUnit.textIn;
        connection nluToNetwork connect nluUnit.intentOut to networkInterface.cloudPort;
        connection networkToCloud connect networkInterface.cloudPort to alexaVoiceService.networkIn;
        connection cloudToSmartHome connect alexaVoiceService.smartHomeOut to smartHomeController.commandIn;
        connection smartHomeToLight connect smartHomeController.deviceControlOut to smartLight.commandIn;
        connection smartHomeToThermostat connect smartHomeController.deviceControlOut to thermostat.commandIn;
        connection ttsToSpeaker connect ttsEngine.audioOut to speaker.audioIn;
        connection wakeControl connect wakeWordEngine.controlOut to asrEngine.audioIn;
    }
    
    part alexaVoiceService: AlexaVoiceService;
    
    part smartSpeaker: SmartSpeaker;
    
    // ===== State Machine Behavior =====
    
    state def AlexaStates {
        entry; exit;
        
        state idle {
            entry action { 
                // Low-power mode, wake word engine active
            }
            do action {
                // Continuously monitor audio feed for wake word
            }
        }
        
        state active {
            entry action {
                // Transition from low-power to full processing
            }
            
            parallel listening {
                entry action {
                    // Capture user's spoken command via microphone array
                }
                do action {
                    // Beamform audio and feed to ASR
                }
            }
            
            parallel processing {
                entry action {
                    // Run ASR and NLU
                }
                do action {
                    // Convert speech to text, extract intent
                }
            }
            
            parallel communicating {
                entry action {
                    // Send intent to cloud Alexa Voice Service
                }
                do action {
                    // Cloud processes request, queries knowledge bases, executes skills
                }
            }
            
            parallel responding {
                entry action {
                    // Receive cloud response, run TTS
                }
                do action {
                    // Synthesize speech and play through speaker
                }
            }
            
            transition from listening to processing;
            transition from processing to communicating;
            transition from communicating to responding;
        }
        
        transition from idle to active when wakeWordEngine.controlOut.wakeSignal == true;
        transition from active to idle when wakeWordEngine.controlOut.processingComplete == true;
    }
    
    // ===== Requirements =====
    
    requirement def WakeWordDetectionRequirement {
        doc /* The system shall continuously listen for the wake word "Alexa" using a dedicated wake word engine. */
        subject smartSpeaker;
        objective detectionAccuracy: Real = 0.95;
    }
    
    requirement def MicrophoneArrayRequirement {
        doc /* The device shall include a multi-microphone array with seven microphones for noise-robust voice capture. */
        subject smartSpeaker.micArray;
        objective microphoneCount: Integer = 7;
    }
    
    requirement def SpeechRecognitionRequirement {
        doc /* The ASR engine shall convert spoken natural language commands into text with high accuracy. */
        subject smartSpeaker.asrEngine;
        objective recognitionAccuracy: Real = 0.90;
    }
    
    requirement def NaturalLanguageUnderstandingRequirement {
        doc /* The NLU unit shall identify the user's core intent and extract relevant details from recognized text. */
        subject smartSpeaker.nluUnit;
        objective intentConfidence: Real = 0.85;
    }
    
    requirement def CloudProcessingRequirement {
        doc /* The system shall communicate with the cloud-based Alexa Voice Service to process intents, query knowledge bases, and execute skills. */
        subject alexaVoiceService;
        objective responseLatency: TimeValue = 2.0 [s];
    }
    
    requirement def TextToSpeechRequirement {
        doc /* The TTS engine shall synthesize natural, life-like voice audio from the cloud response text. */
        subject smartSpeaker.ttsEngine;
        objective naturalnessScore: Real = 0.90;
    }
    
    requirement def SmartHomeControlRequirement {
        doc /* The system shall act as a smart home hub, controlling compatible devices like lights and thermostats via voice commands. */
        subject smartSpeaker.smartHomeController;
        objective supportedDevices: Integer = 100;
    }
    
    requirement def StateManagementRequirement {
        doc /* The device shall operate in an idle low-power state while listening for the wake word and transition to an active state upon wake word detection. */
        subject smartSpeaker;
        objective idlePower: PowerValue = 2.0 [W];
    }
    
    requirement def SpeakerRequirement {
        doc /* The device shall include a high-quality speaker unit for delivering audio responses, music, and other content. */
        subject smartSpeaker.speaker;
        objective maxOutputPower: PowerValue = 30 [W];
    }
    
    requirement def NetworkConnectivityRequirement {
        doc /* The device shall maintain network connectivity to communicate with the cloud-based Alexa Voice Service. */
        subject smartSpeaker.networkInterface;
        objective minBandwidth: DataRateValue = 500000 [bit_per_s];
    }
    
    // ===== Requirement Satisfaction =====
    
    requirement wakeWordReq : WakeWordDetectionRequirement {
        satisfy smartSpeaker.wakeWordEngine;
    }
    
    requirement micArrayReq : MicrophoneArrayRequirement {
        satisfy smartSpeaker.micArray;
    }
    
    requirement asrReq : SpeechRecognitionRequirement {
        satisfy smartSpeaker.asrEngine;
    }
    
    requirement nluReq : NaturalLanguageUnderstandingRequirement {
        satisfy smartSpeaker.nluUnit;
    }
    
    requirement cloudReq : CloudProcessingRequirement {
        satisfy alexaVoiceService;
    }
    
    requirement ttsReq : TextToSpeechRequirement {
        satisfy smartSpeaker.ttsEngine;
    }
    
    requirement smartHomeReq : SmartHomeControlRequirement {
        satisfy smartSpeaker.smartHomeController;
    }
    
    requirement stateReq : StateManagementRequirement {
        satisfy smartSpeaker;
    }
    
    requirement speakerReq : SpeakerRequirement {
        satisfy smartSpeaker.speaker;
    }
    
    requirement networkReq : NetworkConnectivityRequirement {
        satisfy smartSpeaker.networkInterface;
    }
}
