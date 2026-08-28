package AlexaVoiceAssistantSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        item def AudioSignal;
        item def WakeWordDetected;
        item def Text {
            attribute content : String;
        }
        item def Intent {
            attribute name : String;
            attribute slots : String [0..*];
        }
        item def CloudRequest {
            attribute intent : Intent;
            attribute deviceId : String;
        }
        item def CloudResponse {
            attribute outputSpeech : Text;
            attribute reprompt : Text;
        }
        item def SynthesizedAudio;
        item def SmartHomeCommand {
            attribute device : String;
            attribute actionName : String;
        }

        port def AudioOutPort { out audio : AudioSignal; }
        port def AudioInPort { in audio : AudioSignal; }
        port def WakeWordOutPort { out detected : WakeWordDetected; }
        port def TextOutPort { out text : Text; }
        port def TextInPort { in text : Text; }
        port def IntentOutPort { out intent : Intent; }
        port def IntentInPort { in intent : Intent; }
        port def CloudRequestOutPort { out request : CloudRequest; }
        port def CloudRequestInPort { in request : CloudRequest; }
        port def CloudResponseOutPort { out resp : CloudResponse; }
        port def CloudResponseInPort { in resp : CloudResponse; }
        port def SynthesizedAudioOutPort { out audio : SynthesizedAudio; }
        port def SynthesizedAudioInPort { in audio : SynthesizedAudio; }
        port def SmartHomeCommandOutPort { out command : SmartHomeCommand; }

        action def DetectWakeWord {
            in audio : AudioSignal;
            out detected : WakeWordDetected;
        }
        action def RecognizeSpeech {
            in audio : AudioSignal;
            out text : Text;
        }
        action def UnderstandIntent {
            in text : Text;
            out intent : Intent;
        }
        action def SendCloudRequest {
            in intent : Intent;
            out request : CloudRequest;
        }
        action def ProcessCloudRequest {
            in request : CloudRequest;
            out resp : CloudResponse;
        }
        action def SynthesizeSpeech {
            in resp : CloudResponse;
            out audio : SynthesizedAudio;
        }
        action def PlayAudio {
            in audio : SynthesizedAudio;
        }
        action def ControlSmartHome {
            in intent : Intent;
            out command : SmartHomeCommand;
        }

        part def Microphone {
            port audioOut : AudioOutPort;
        }

        part def MicrophoneArray {
            attribute microphoneCount : Integer = 7;
            part microphones : Microphone[7];
            port combinedAudioOut : AudioOutPort;
        }

        part def SpeakerUnit {
            port audioIn : SynthesizedAudioInPort;
            attribute maxVolume : Real;
            perform action play : PlayAudio;
        }

        part def WakeWordEngine {
            port audioIn : AudioInPort;
            port detectedOut : WakeWordOutPort;
            perform action detect : DetectWakeWord;
        }

        part def ASREngine {
            port audioIn : AudioInPort;
            port textOut : TextOutPort;
            perform action recognize : RecognizeSpeech;
        }

        part def NLUEngine {
            port textIn : TextInPort;
            port intentOut : IntentOutPort;
            perform action understand : UnderstandIntent;
        }

        part def NetworkInterface {
            port intentIn : IntentInPort;
            port requestOut : CloudRequestOutPort;
            port responseIn : CloudResponseInPort;
            port responseOut : CloudResponseOutPort;
            perform action transmit : SendCloudRequest;
        }

        part def TTSEngine {
            port responseIn : CloudResponseInPort;
            port audioOut : SynthesizedAudioOutPort;
            perform action synthesize : SynthesizeSpeech;
        }

        part def SmartHomeController {
            port intentIn : IntentInPort;
            port commandOut : SmartHomeCommandOutPort;
            perform action control : ControlSmartHome;
        }

        part def AlexaVoiceService {
            port requestIn : CloudRequestInPort;
            port responseOut : CloudResponseOutPort;
            perform action process : ProcessCloudRequest;
        }

        requirement def VoiceAssistantRequirements {
            requirement WakeWordDetection {
                doc /* The system shall continuously monitor audio and detect the wake word. */
            }
            requirement SpeechRecognition {
                doc /* The system shall convert spoken commands into text. */
            }
            requirement CloudProcessing {
                doc /* The system shall communicate with the cloud to process intents. */
            }
            requirement AudioResponse {
                doc /* The system shall synthesize and play audio responses. */
            }
            requirement SmartHomeControl {
                doc /* The system shall control smart home devices via voice commands. */
            }
        }

        part def SmartSpeaker {
            attribute wakeWord : String = "Alexa";
            attribute isMuted : Boolean = false;

            part microphoneArray : MicrophoneArray;
            part speakerUnit : SpeakerUnit;
            part wakeWordEngine : WakeWordEngine;
            part asrEngine : ASREngine;
            part nluEngine : NLUEngine;
            part networkInterface : NetworkInterface;
            part ttsEngine : TTSEngine;
            part smartHomeController : SmartHomeController;

            port cloudRequestOut : CloudRequestOutPort;
            port cloudResponseIn : CloudResponseInPort;
            port smartHomeCommandOut : SmartHomeCommandOutPort;

            connect microphoneArray.combinedAudioOut to wakeWordEngine.audioIn;
            connect microphoneArray.combinedAudioOut to asrEngine.audioIn;
            connect asrEngine.textOut to nluEngine.textIn;
            connect nluEngine.intentOut to networkInterface.intentIn;
            connect networkInterface.requestOut to cloudRequestOut;
            connect cloudResponseIn to networkInterface.responseIn;
            connect networkInterface.responseOut to ttsEngine.responseIn;
            connect ttsEngine.audioOut to speakerUnit.audioIn;
            connect nluEngine.intentOut to smartHomeController.intentIn;
            connect smartHomeController.commandOut to smartHomeCommandOut;

            state speakerStates {
                action detectWakeWord;
                action recognizeSpeech;
                action understandIntent;
                action sendCloudRequest;
                action synthesizeSpeech;
                action playAudio;

                entry; then idle;
                state idle {
                    do detectWakeWord;
                }
                accept detected : WakeWordDetected
                    then active;
                state active {
                    entry; then listening;
                    state listening {
                        do recognizeSpeech;
                    }
                    transition first listening then processing;
                    state processing {
                        do understandIntent;
                    }
                    transition first processing then communicating;
                    state communicating {
                        do sendCloudRequest;
                        accept cloudResp : CloudResponse
                            then responding;
                    }
                    state responding {
                        do synthesizeSpeech;
                        do playAudio;
                    }
                    transition first responding then done;
                }
                transition first active then idle;
            }

            satisfy VoiceAssistantRequirements;
        }

        part def AlexaSystemContext {
            part alexaSpeaker : SmartSpeaker;
            part alexaVoiceService : AlexaVoiceService;
            connect alexaSpeaker.cloudRequestOut to alexaVoiceService.requestIn;
            connect alexaVoiceService.responseOut to alexaSpeaker.cloudResponseIn;
        }
    }

    package Usages {
        private import Definitions::*;
        part alexaSystem : AlexaSystemContext;
    }
}
