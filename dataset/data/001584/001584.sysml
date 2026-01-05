package 'Smart Speaker System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def WakeWord;
    attribute def VoiceCommand;
    attribute def TextResponse;
    attribute def DeviceControlCommand;

    item def AudioSignal {
        attribute frequency : FrequencyValue;
        attribute amplitude : Real;
        attribute duration : TimeValue;
    }

    item def NetworkData {
        attribute payload : String;
        attribute timestamp : TimeValue;
    }

    attribute def SoundPressureLevel :> Real;

    port def AudioInputPort {
        in item audioIn : AudioSignal;
    }

    port def AudioOutputPort {
        out item audioOut : AudioSignal;
    }

    port def NetworkPort {
        in item dataIn : NetworkData;
        out item dataOut : NetworkData;
    }

    port def ControlPort {
        out item controlSignal : DeviceControlCommand;
    }

    part def MicrophoneArray {
        port audioOutput : AudioOutputPort;

        action captureAudio {
            out capturedSignal : AudioSignal;
        }
    }

    part def SpeakerUnit {
        port audioInput : AudioInputPort;
        attribute maxSPL : SoundPressureLevel;

        action emitAudio {
            in audioSignal : AudioSignal;
        }
    }

    part def VoiceProcessingUnit {
        port audioIn : AudioInputPort;
        port networkOut : NetworkPort;

        action detectWakeWord {
            in audioStream : AudioSignal;
            out wakeDetected : Boolean;
        }

        action recognizeSpeech {
            in audioStream : AudioSignal;
            out recognizedCommand : VoiceCommand;
        }

        action cancelNoise {
            in rawAudio : AudioSignal;
            out cleanAudio : AudioSignal;
        }
    }

    part def CloudInterface {
        port networkIn : NetworkPort;
        port networkOut : NetworkPort;

        action processNaturalLanguage {
            in voiceCommand : VoiceCommand;
            out intent : String;
            out parameters : String[*];
        }

        action generateResponse {
            in intent : String;
            in parameters : String[*];
            out textResponse : TextResponse;
        }

        action retrieveContent {
            in request : String;
            out content : NetworkData;
        }
    }

    part def AudioSynthesizer {
        port textIn : NetworkPort;
        port audioOut : AudioOutputPort;

        action synthesizeSpeech {
            in textResponse : TextResponse;
            out speechAudio : AudioSignal;
        }

        action enhanceAudio {
            in rawAudio : AudioSignal;
            out enhancedAudio : AudioSignal;
        }
    }

    part def SmartHomeHub {
        port controlOut : ControlPort;

        action executeDeviceControl {
            in command : String;
            out controlSignal : DeviceControlCommand;
        }
    }

    part def SmartSpeaker {
        part micArray : MicrophoneArray;
        part speaker : SpeakerUnit {
            :>> maxSPL = 90.0;
        }
        part voiceProc : VoiceProcessingUnit;
        part cloudInterface : CloudInterface;
        part audioSynth : AudioSynthesizer;
        part homeHub : SmartHomeHub;

        connection micToVoiceProc
            connect micArray.audioOutput to voiceProc.audioIn;

        connection voiceProcToCloud
            connect voiceProc.networkOut to cloudInterface.networkIn;

        connection cloudToSynth
            connect cloudInterface.networkOut to audioSynth.textIn;

        connection synthToSpeaker
            connect audioSynth.audioOut to speaker.audioInput;
    }

    part smartSpeaker : SmartSpeaker {
        perform action handleVoiceInteraction[*] ordered
            references voiceInteractionBehavior;
    }

    action def VoiceInteractionBehavior {
        in wakeWord : WakeWord;
        out audioResponse : AudioSignal;
        out deviceControl : DeviceControlCommand;
    }

    action voiceInteractionBehavior : VoiceInteractionBehavior {
        first start;

        then action continuousListening {
            action captureAmbient {
                out ambientAudio : AudioSignal;
            }
            then action cleanAudio {
                in rawAudio : AudioSignal = captureAmbient.ambientAudio;
                out cleanedAudio : AudioSignal;
            }
            then action detectWake {
                in audioStream : AudioSignal = cleanAudio.cleanedAudio;
                out wakeDetected : Boolean;
            }
            then decide;
                if detectWake.wakeDetected then captureUserCommand;
                if not detectWake.wakeDetected then continuousListening;
        }

        action captureUserCommand {
            action recordSpeech {
                out userAudio : AudioSignal;
            }
            then action recognizeCommand {
                in audioStream : AudioSignal = recordSpeech.userAudio;
                out command : VoiceCommand;
            }
        }

        then action sendToCloud {
            in voiceCommand : VoiceCommand = captureUserCommand.recognizeCommand.command;
            out cloudRequest : NetworkData;
        }

        then action processInCloud {
            action parseIntent {
                in voiceCommand : VoiceCommand = sendToCloud.voiceCommand;
                out intent : String;
                out parameters : String[*];
            }
            then decide;
                if parseIntent.intent == "play_media" then handleMediaPlayback;
                if parseIntent.intent == "control_device" then handleDeviceControl;
                if parseIntent.intent == "answer_query" then handleQuery;

            action handleMediaPlayback {
                in request : String = parseIntent.intent;
                out mediaContent : NetworkData;
            }
            then generateResponse;

            action handleDeviceControl {
                in deviceCommand : String = parseIntent.intent;
                in targetDevice : String = parseIntent.parameters[1];
                out controlSignal : DeviceControlCommand;
            }
            then action executeControl {
                in signal : DeviceControlCommand = handleDeviceControl.controlSignal;
            }
            then generateResponse;

            action handleQuery {
                in query : String = parseIntent.intent;
                out answer : String;
            }
            then generateResponse;

            action generateResponse {
                out textResponse : TextResponse;
            }
        }

        then action synthesizeAndDeliver {
            action convertToSpeech {
                in textResponse : TextResponse = processInCloud.generateResponse.textResponse;
                out speechSignal : AudioSignal;
            }
            then action enhanceQuality {
                in rawAudio : AudioSignal = convertToSpeech.speechSignal;
                out enhancedAudio : AudioSignal;
            }
            then action playAudio {
                in audioToPlay : AudioSignal = enhanceQuality.enhancedAudio;
            }
        }

        then continuousListening;
    }

    attribute def TimeoutEvent;
    attribute def PlaybackCompleteEvent;

    state def SmartSpeakerStateMachine {
        entry; then idle;

        state idle {
            entry action monitorAmbientAudio;
        }

        transition idle_to_listening
            first idle
            accept wakeWordDetected : WakeWord
            then listening;

        state listening {
            entry action activateListeningIndicator;
            do action captureUserSpeech;
        }

        transition listening_to_processing
            first listening
            accept commandCaptured : VoiceCommand
            then processing;

        transition listening_to_idle_timeout
            first listening
            accept timeoutEvent : TimeoutEvent
            then idle;

        state processing {
            entry action showProcessingIndicator;
            do action sendToCloudAndAwaitResponse;
        }

        transition processing_to_responding
            first processing
            accept responseReceived : TextResponse
            then responding;

        state responding {
            entry action deactivateProcessingIndicator;
            do action synthesizeAndPlayResponse;
        }

        transition responding_to_idle
            first responding
            accept playbackCompleteEvent : PlaybackCompleteEvent
            then idle;
    }

    requirement def VoiceRecognitionAccuracyRequirement {
        doc /* The system shall recognize voice commands with at least 95% accuracy in ambient noise up to 60 dB. */

        subject speaker : SmartSpeaker;

        require constraint accuracyConstraint {
            doc /* Recognition accuracy >= 95% */
        }
    }

    requirement def ResponseLatencyRequirement {
        doc /* The system shall provide an audio response within 2.5 seconds of command completion. */

        subject speaker : SmartSpeaker;

        require constraint latencyConstraint {
            doc /* Response time <= 2.5 seconds */
        }
    }

    requirement def AudioOutputQualityRequirement {
        doc /* The system shall output audio with frequency response 100 Hz to 18 kHz at minimum 85 dB SPL. */

        subject speaker : SmartSpeaker;

        require constraint frequencyResponseConstraint {
            doc /* Frequency range: 100 Hz to 18 kHz */
        }

        require constraint soundPressureConstraint {
            doc /* SPL >= 85 dB at 1 meter */
        }
    }

    requirement def NetworkReliabilityRequirement {
        doc /* The system shall maintain network connectivity with less than 2% packet loss and reconnect within 5 seconds of disconnection. */

        subject speaker : SmartSpeaker;

        require constraint packetLossConstraint {
            doc /* Packet loss < 2% */
        }

        require constraint reconnectionConstraint {
            doc /* Reconnection time <= 5 seconds */
        }
    }

    requirement def WakeWordDetectionRequirement {
        doc /* The system shall detect the wake word from up to 5 meters distance with 98% accuracy. */

        subject speaker : SmartSpeaker;

        require constraint detectionRangeConstraint {
            doc /* Detection range >= 5 meters */
        }

        require constraint detectionAccuracyConstraint {
            doc /* Wake word detection accuracy >= 98% */
        }
    }

    requirement primaryMissionRequirement {
        doc /* The smart speaker system shall provide voice-activated assistance by continuously listening for a wake word, capturing and interpreting natural language voice commands, interfacing with cloud services to process requests, and delivering synthesized audio responses or executing smart home device controls. */

        subject speaker : SmartSpeaker;

        assume constraint userProvidesValidCommand {
            doc /* User speaks a clear voice command after wake word activation */
        }

        assume constraint networkConnectivityAvailable {
            doc /* Internet connectivity is available for cloud processing */
        }

        assume constraint ambientNoiseWithinLimits {
            doc /* Ambient noise does not exceed 70 dB SPL */
        }

        require voiceRecognitionReq : VoiceRecognitionAccuracyRequirement;
        require responseLatencyReq : ResponseLatencyRequirement;
        require audioOutputReq : AudioOutputQualityRequirement;
        require networkReliabilityReq : NetworkReliabilityRequirement;
        require wakeWordDetectionReq : WakeWordDetectionRequirement;
    }
}
