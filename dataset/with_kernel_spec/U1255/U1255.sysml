package 'Voice User Interface System' {

    private import ScalarValues::*;

    // ===== Value Types =====
    attribute def Confidence :> Real;
    attribute def ConfidenceThreshold :> Real;

    // ===== Event Signals =====
    attribute def SpeechDetected;
    attribute def SpeechEnded;
    attribute def TranscriptionComplete;
    attribute def NLUComplete;
    attribute def ConfidenceLow;
    attribute def ConfidenceHigh;
    attribute def ClarificationComplete;
    attribute def ExecutionComplete;
    attribute def ResponseGenerated;
    attribute def PlaybackComplete;

    // ===== Item Definitions =====
    item def AudioStream {
        attribute sampleRate : Integer;
        attribute amplitude : Real;
    }

    item def TextCommand {
        attribute text : String;
        attribute confidence : Confidence;
    }

    item def Intent {
        attribute name : String;
    }

    item def Parameter {
        attribute name : String;
        attribute value : String;
    }

    item def IntentWithParameters {
        attribute intent : Intent;
        attribute parameters : Parameter[0..*];
        attribute confidence : Confidence;
    }

    item def ApplicationCommand {
        attribute serviceId : String;
        attribute payload : String;
    }

    item def ApplicationResult {
        attribute status : String;
        attribute data : String;
    }

    item def TextResponse {
        attribute text : String;
    }

    item def SynthesizedAudio :> AudioStream {
        attribute voiceProfile : String;
    }

    // ===== Port Definitions =====
    port def AudioOutPort {
        out item audio : AudioStream;
    }

    port def TextCommandOutPort {
        out item textCommand : TextCommand;
    }

    port def IntentOutPort {
        out item intent : IntentWithParameters;
    }

    port def ResponseOutPort {
        out item response : TextResponse;
    }

    port def AppCommandOutPort {
        out item command : ApplicationCommand;
    }

    port def AppResultOutPort {
        out item result : ApplicationResult;
    }

    port def PlaybackCompleteInPort {
        in item playbackComplete : PlaybackComplete;
    }

    // ===== Part Definitions =====
    part def Microphone {
        attribute noiseReductionEnabled : Boolean = true;
        attribute noiseReductionLevel : Real = 0.8;
        port audioOut : AudioOutPort;
        port speechSignalOut {
            out item speechDetected : SpeechDetected;
            out item speechEnded : SpeechEnded;
        }
    }

    part def SpeechRecognitionEngine {
        port audioIn : ~AudioOutPort;
        port textOut : TextCommandOutPort;
        attribute transcriptionModel : String = "default";
    }

    part def NLUEngine {
        port textIn : ~TextCommandOutPort;
        port intentOut : IntentOutPort;
        attribute modelVersion : String = "nlu-v1";
    }

    part def DialogueController {
        port intentIn : ~IntentOutPort;
        port responseOut : ResponseOutPort;
        port appCommandOut : AppCommandOutPort;
        port appResultIn : ~AppResultOutPort;
        port clarificationOut : ResponseOutPort;
        port playbackCompleteIn : PlaybackCompleteInPort;
        attribute conversationHistory : String;
        attribute confidenceThreshold : ConfidenceThreshold = 0.75;
    }

    part def ApplicationInterface {
        port appCommandIn : ~AppCommandOutPort;
        port appResultOut : AppResultOutPort;
        attribute connectedServices : String[0..*];
    }

    part def TextToSpeechEngine {
        port responseIn : ~ResponseOutPort;
        port audioOut : AudioOutPort;
        attribute voiceProfile : String = "natural-female";
    }

    part def Speaker {
        port audioIn : ~AudioOutPort;
        port playbackCompleteOut {
            out item playbackComplete : PlaybackComplete;
        }
        attribute volumeLevel : Real = 0.7;
    }

    // ===== VUI System Assembly =====
    part def VUISystem {
        attribute systemConfidenceThreshold : ConfidenceThreshold = 0.75;

        part microphone : Microphone;
        part speechRecognition : SpeechRecognitionEngine;
        part nlu : NLUEngine;
        part dialogueController : DialogueController;
        part applicationInterface : ApplicationInterface;
        part textToSpeech : TextToSpeechEngine;
        part speaker : Speaker;

        flow audioCaptureFlow of AudioStream
            from microphone.audioOut.audio to speechRecognition.audioIn.audio;
        flow textTranscriptionFlow of TextCommand
            from speechRecognition.textOut.textCommand to nlu.textIn.textCommand;
        flow intentExtractionFlow of IntentWithParameters
            from nlu.intentOut.intent to dialogueController.intentIn.intent;
        flow appCommandFlow of ApplicationCommand
            from dialogueController.appCommandOut.command to applicationInterface.appCommandIn.command;
        flow appResultFlow of ApplicationResult
            from applicationInterface.appResultOut.result to dialogueController.appResultIn.result;
        flow responseTextFlow of TextResponse
            from dialogueController.responseOut.response to textToSpeech.responseIn.response;
        flow clarificationTextFlow of TextResponse
            from dialogueController.clarificationOut.response to textToSpeech.responseIn.response;
        flow audioPlaybackFlow of SynthesizedAudio
            from textToSpeech.audioOut.audio to speaker.audioIn.audio;
        flow playbackCompleteFlow of PlaybackComplete
            from speaker.playbackCompleteOut.playbackComplete to dialogueController.playbackCompleteIn.playbackComplete;

        state operationalState : VUIOperationalStateMachine;
    }

    // ===== VUI System Instance =====
    part vuiSystemInstance : VUISystem;

    // ===== State Machine =====
    state def VUIOperationalStateMachine {
        attribute currentConfidence : Confidence;

        entry; then idle;

        state idle;
        accept speechDetected : SpeechDetected
            then listening;

        state listening;
        accept speechEnded : SpeechEnded
            then processing;

        state processing {
            entry; then transcribing;

            state transcribing;
            accept TranscriptionComplete
                then analyzing;

            state analyzing;
            accept NLUComplete
                then confidenceCheck;

            state confidenceCheck;
            transition
                first confidenceCheck
                accept ConfidenceLow
                then askingClarification;
            transition
                first confidenceCheck
                accept ConfidenceHigh
                then executing;

            state askingClarification;
            accept ClarificationComplete
                then idle;

            state executing;
            accept ExecutionComplete
                then generatingResponse;

            state generatingResponse;
            accept ResponseGenerated
                then providingFeedback;

            state providingFeedback;
            accept PlaybackComplete
                then idle;
        }
    }

    // ===== Interaction Occurrence =====
    occurrence def VUIInteraction {
        ref part vuiSystem :>> vuiSystemInstance;

        message audioCaptureMessage of AudioStream
            from vuiSystem.microphone.audioOut.audio to vuiSystem.speechRecognition.audioIn.audio;
        then message textTranscriptionMessage of TextCommand
            from vuiSystem.speechRecognition.textOut.textCommand to vuiSystem.nlu.textIn.textCommand;
        then message intentExtractionMessage of IntentWithParameters
            from vuiSystem.nlu.intentOut.intent to vuiSystem.dialogueController.intentIn.intent;
        then message appCommandMessage of ApplicationCommand
            from vuiSystem.dialogueController.appCommandOut.command to vuiSystem.applicationInterface.appCommandIn.command;
        then message appResultMessage of ApplicationResult
            from vuiSystem.applicationInterface.appResultOut.result to vuiSystem.dialogueController.appResultIn.result;
        then message responseMessage of TextResponse
            from vuiSystem.dialogueController.responseOut.response to vuiSystem.textToSpeech.responseIn.response;
        then message audioResponseMessage of SynthesizedAudio
            from vuiSystem.textToSpeech.audioOut.audio to vuiSystem.speaker.audioIn.audio;
    }

    // ===== Requirements =====
    requirement def HandsFreeInteractionRequirement {
        doc /* The system shall provide a hands-free experience by allowing interaction through natural spoken language. */
        subject vuiSystem : VUISystem;
    }

    requirement def NoiseReductionRequirement {
        doc /* The microphone shall have noise reduction enabled to improve audio capture quality. */
        subject microphone : Microphone;
        constraint { microphone.noiseReductionEnabled == true }
    }

    requirement def SpeechRecognitionConfidenceRequirement {
        doc /* The speech recognition engine shall produce a confidence score for each transcription. */
        subject engine : SpeechRecognitionEngine;
        constraint { engine.textOut.textCommand.confidence >= 0.0 }
    }

    requirement def NLUIntentExtractionRequirement {
        doc /* The NLU engine shall extract user intent and parameters from transcribed text. */
        subject nluEngine : NLUEngine;
        constraint { nluEngine.intentOut.intent.intent.name != "" }
    }

    requirement def DialogueContextRequirement {
        doc /* The dialogue controller shall maintain conversation history for contextual understanding. */
        subject controller : DialogueController;
        constraint { controller.conversationHistory != "" }
    }

    requirement def ConfidenceThresholdRequirement {
        doc /* The system shall not execute a command if the confidence score is below 75%. Instead, it must request clarification from the user. */
        subject vuiSystem : VUISystem;
        constraint { vuiSystem.systemConfidenceThreshold == 0.75 }
    }

    requirement def SpokenFeedbackRequirement {
        doc /* The system shall provide spoken feedback to the user through a speaker after processing is complete. */
        subject vuiSystem : VUISystem;
        constraint { vuiSystem.textToSpeech.audioOut.audio == vuiSystem.speaker.audioIn.audio }
    }

    requirement def AudioPlaybackRequirement {
        doc /* The speaker shall play synthesized audio generated by the text-to-speech engine. */
        subject speaker : Speaker;
        constraint { speaker.volumeLevel > 0.0 }
    }
}
