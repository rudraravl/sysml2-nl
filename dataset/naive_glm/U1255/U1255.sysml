package VoiceUserInterface {
    import ScalarValues::*;

    // ===== Value Types =====
    value type Percent {
        unit '%';
    }

    value type SampleRateHz {
        unit 'Hz';
    }

    value type DurationSec {
        unit 's';
    }

    value type Decibel {
        unit 'dB';
    }

    // ===== Items =====
    item def AudioSignal {
        attribute sampleRate : SampleRateHz = 16000 [Hz];
        attribute bitDepth : Integer = 16;
        attribute channels : Integer = 1;
        attribute duration : DurationSec;
    }

    item def RawAudio :> AudioSignal;
    item def CleanedAudio :> AudioSignal;
    item def SynthesizedAudio :> AudioSignal;

    item def Transcription {
        attribute text : String;
        attribute confidence : Real;
    }

    item def Intent {
        attribute name : String;
        attribute parameters : String;
        attribute confidence : Real;
    }

    item def Response {
        attribute text : String;
        attribute requiresClarification : Boolean = false;
    }

    item def ServiceCommand {
        attribute service : String;
        attribute action : String;
        attribute payload : String;
    }

    // ===== Port Definitions =====
    port def AudioOut {
        out signal : AudioSignal;
    }

    port def AudioIn {
        in signal : AudioSignal;
    }

    port def TranscriptionOut {
        out result : Transcription;
    }

    port def TranscriptionIn {
        in result : Transcription;
    }

    port def IntentOut {
        out intent : Intent;
    }

    port def IntentIn {
        in intent : Intent;
    }

    port def ResponseOut {
        out response : Response;
    }

    port def ResponseIn {
        in response : Response;
    }

    port def CommandOut {
        out command : ServiceCommand;
    }

    // ===== Microphone =====
    part def Microphone {
        port audioOut : AudioOut;
        attribute noiseReductionEnabled : Boolean = true;
        attribute sensitivity : Decibel = -40 [dB];

        action def CaptureAudio {
            in sound : RawAudio;
            out cleaned : CleanedAudio;
        }

        perform capture : CaptureAudio;
    }

    // ===== Speech Recognition Engine =====
    part def SpeechRecognitionEngine {
        port audioIn : AudioIn;
        port transcriptionOut : TranscriptionOut;
        attribute languageModel : String = "en-US";
        attribute minReliability : Percent = 50 [%];

        action def Transcribe {
            in audio : CleanedAudio;
            out result : Transcription;
        }

        perform transcribe : Transcribe;
    }

    // ===== Natural Language Understanding Engine =====
    part def NaturalLanguageUnderstandingEngine {
        port transcriptionIn : TranscriptionIn;
        port intentOut : IntentOut;
        attribute modelVersion : String = "nlu-v2";

        action def Interpret {
            in transcription : Transcription;
            out intent : Intent;
        }

        perform interpret : Interpret;
    }

    // ===== Dialogue Controller =====
    part def DialogueController {
        port intentIn : IntentIn;
        port transcriptionIn : TranscriptionIn;
        port commandOut : IntentOut;
        port responseOut : ResponseOut;
        attribute conversationHistory : String;
        attribute contextMemory : String;
        attribute confidenceThreshold : Real = 75.0;

        action def EvaluateConfidence {
            in intent : Intent;
            out proceed : Boolean;
        }

        action def FormulateResponse {
            in intent : Intent;
            in serviceResult : String;
            out response : Response;
        }

        action def RequestClarification {
            in intent : Intent;
            out response : Response;
        }

        perform evaluate : EvaluateConfidence;
        perform formulate : FormulateResponse;
        perform clarify : RequestClarification;
    }

    // ===== Application Interface =====
    part def ApplicationInterface {
        port intentIn : IntentIn;
        port commandOut : CommandOut;
        attribute connectedServices : String;

        action def InvokeService {
            in intent : Intent;
            out command : ServiceCommand;
        }

        perform invoke : InvokeService;
    }

    // ===== Text-to-Speech Engine =====
    part def TextToSpeechEngine {
        port responseIn : ResponseIn;
        port audioOut : AudioOut;
        attribute voiceProfile : String = "natural-female";
        attribute speed : Real = 1.0;

        action def Synthesize {
            in text : Response;
            out audio : SynthesizedAudio;
        }

        perform synthesize : Synthesize;
    }

    // ===== Speaker =====
    part def Speaker {
        port audioIn : AudioIn;
        attribute volumeLevel : Percent = 70 [%];

        action def PlayAudio {
            in audio : SynthesizedAudio;
        }

        perform play : PlayAudio;
    }

    // ===== State Machine =====
    state def VUIOperationalStates {
        attribute confidenceThreshold : Real = 75.0;

        state idle {
            entry { /* await user wake word or speech detection */ }
        }

        state listening {
            entry { /* microphone actively capturing audio */ }
        }

        state processing {
            entry { /* ASR -> NLU -> Dialogue -> App Interface */ }
        }

        state clarifying {
            entry { /* generate clarification question and play via TTS */ }
        }

        transition t_detect from idle to listening when speechDetected;
        transition t_end_speech from listening to processing when endOfSpeech;
        transition t_clarify from processing to clarifying when confidenceBelowThreshold;
        transition t_execute from processing to idle when commandExecuted;
        transition t_resume from clarifying to idle when clarificationComplete;
    }

    // ===== Main VUI System =====
    part def VUISystem {
        attribute systemConfidenceThreshold : Real = 75.0;
        attribute systemName : String = "Smart Assistant";

        part microphone : Microphone;
        part speechRecognition : SpeechRecognitionEngine;
        part nlu : NaturalLanguageUnderstandingEngine;
        part dialogueController : DialogueController;
        part applicationInterface : ApplicationInterface;
        part tts : TextToSpeechEngine;
        part speaker : Speaker;

        perform operationalState : VUIOperationalStates;

        // Pipeline connections
        connect microphone.audioOut to speechRecognition.audioIn;
        connect speechRecognition.transcriptionOut to nlu.transcriptionIn;
        connect speechRecognition.transcriptionOut to dialogueController.transcriptionIn;
        connect nlu.intentOut to dialogueController.intentIn;
        connect dialogueController.commandOut to applicationInterface.intentIn;
        connect dialogueController.responseOut to tts.responseIn;
        connect tts.audioOut to speaker.audioIn;
    }

    // ===== Requirements =====
    requirement def ReqCaptureUserVoice {
        doc { The VUI shall capture the user's voice using a microphone equipped with noise reduction. }
    }

    requirement def ReqTranscribeSpeech {
        doc { The Speech Recognition Engine shall transcribe audio into a text-based command and calculate a confidence score. }
    }

    requirement def ReqDetermineIntent {
        doc { The NLU engine shall analyze the transcription to determine the user's intent and extract parameters. }
    }

    requirement def ReqManageDialogue {
        doc { The Dialogue Controller shall manage conversation flow based on intent and conversation history. }
    }

    requirement def ReqExecuteViaApplicationInterface {
        doc { The Application Interface shall communicate with external services to perform the requested task. }
    }

    requirement def ReqSynthesizeVoice {
        doc { The TTS engine shall synthesize a natural-sounding voice from the response text. }
    }

    requirement def ReqPlayAudioFeedback {
        doc { The Speaker shall play the synthesized audio back to the user. }
    }

    requirement def ReqHandleLowConfidence {
        doc { If the system confidence in understanding the command is below 75%, the system shall not execute the command and shall ask the user for clarification before returning to idle. }
        attribute minConfidence : Real = 75.0;
    }

    requirement def ReqIdleState {
        doc { The system shall be in an idle state when no speech is detected. }
    }

    requirement def ReqListeningState {
        doc { The system shall enter a listening state upon detecting speech. }
    }

    requirement def ReqProcessingState {
        doc { The system shall enter a processing state to transcribe, understand, and act on the user command. }
    }

    requirement def ReqClarificationState {
        doc { The system shall enter a clarifying state when confidence is below threshold and return to idle after clarification. }
    }

    // ===== Satisfactions =====
    satisfaction ReqCaptureUserVoice by microphone;
    satisfaction ReqTranscribeSpeech by speechRecognition;
    satisfaction ReqDetermineIntent by nlu;
    satisfaction ReqManageDialogue by dialogueController;
    satisfaction ReqExecuteViaApplicationInterface by applicationInterface;
    satisfaction ReqSynthesizeVoice by tts;
    satisfaction ReqPlayAudioFeedback by speaker;
    satisfaction ReqHandleLowConfidence by dialogueController;
    satisfaction ReqIdleState by operationalState;
    satisfaction ReqListeningState by operationalState;
    satisfaction ReqProcessingState by operationalState;
    satisfaction ReqClarificationState by operationalState;
}
