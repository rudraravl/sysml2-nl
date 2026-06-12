package VoiceUserInterfaceModel {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    attribute def Probability :> Real {
        constraint range { 0.0 <= self <= 1.0; }
    }

    attribute def ConfidenceScore :> Probability;
    attribute def DecibelSPL :> Real;
    attribute def Hertz :> Real;
    attribute def Millisecond :> Real;
    attribute def WordCount :> Integer;

    item def AcousticWave {
        attribute soundPressureLevel : DecibelSPL;
        attribute sampleRate : Hertz;
        attribute duration : Millisecond;
        attribute languageHint : String;
    }

    item def WakePhrase {
        attribute phrase : String;
        attribute confidence : ConfidenceScore;
    }

    item def SpeechSegment {
        attribute audio : AcousticWave;
        attribute startOffset : Millisecond;
        attribute endOffset : Millisecond;
        attribute noiseEstimate : DecibelSPL;
    }

    item def Transcript {
        attribute text : String;
        attribute wordCount : WordCount;
        attribute confidence : ConfidenceScore;
        attribute locale : String;
    }

    item def Intent {
        attribute name : String;
        attribute confidence : ConfidenceScore;
        attribute requiresAuthentication : Boolean;
    }

    item def DialogContext {
        attribute sessionId : String;
        attribute activeUserId : String;
        attribute turnNumber : Integer;
        attribute locale : String;
        attribute privacyModeEnabled : Boolean;
    }

    item def ServiceRequest {
        attribute intentName : String;
        attribute userId : String;
        attribute payload : String;
        attribute deadline : Millisecond;
    }

    item def ServiceResult {
        attribute success : Boolean;
        attribute resultPayload : String;
        attribute errorCode : String;
    }

    item def ResponseText {
        attribute text : String;
        attribute locale : String;
        attribute shouldSpeak : Boolean;
    }

    item def SynthesizedSpeech {
        attribute audio : AcousticWave;
        attribute spokenText : String;
        attribute voiceName : String;
    }

    item def PrivacyEvent {
        attribute eventName : String;
        attribute reason : String;
    }

    port def AcousticInputPort {
        in item acousticInput : AcousticWave;
    }

    port def AudioOutputPort {
        out item audioOutput : SynthesizedSpeech;
    }

    port def TranscriptPort {
        out item transcript : Transcript;
    }

    port def IntentPort {
        out item intent : Intent;
    }

    port def DialogPort {
        in item interpretedIntent : Intent;
        inout item context : DialogContext;
        out item serviceRequest : ServiceRequest;
        out item responseText : ResponseText;
    }

    port def ServicePort {
        in item request : ServiceRequest;
        out item result : ServiceResult;
    }

    port def PrivacyPort {
        in item privacyCommand : PrivacyEvent;
        out item privacyStatus : PrivacyEvent;
    }

    part def MicrophoneArray {
        attribute microphoneCount : Integer = 4;
        attribute sampleRate : Hertz = 16000.0;
        attribute maxInputLevel : DecibelSPL = 120.0;
        port soundIn : AcousticInputPort;
        port speechOut {
            out item segment : SpeechSegment;
        }
    }

    part def WakeWordDetector {
        attribute wakeThreshold : ConfidenceScore = 0.86;
        port audioIn {
            in item segment : SpeechSegment;
        }
        port wakeOut {
            out item wakePhrase : WakePhrase;
        }
    }

    part def SpeechRecognizer {
        attribute minimumConfidence : ConfidenceScore = 0.72;
        attribute maximumRecognitionLatency : Millisecond = 900.0;
        port audioIn {
            in item segment : SpeechSegment;
        }
        port transcriptOut : TranscriptPort;
    }

    part def NaturalLanguageUnderstanding {
        attribute minimumIntentConfidence : ConfidenceScore = 0.70;
        port transcriptIn {
            in item transcript : Transcript;
        }
        port intentOut : IntentPort;
    }

    part def DialogManager {
        attribute maxTurnsBeforeClarification : Integer = 3;
        port dialog : DialogPort;
        port serviceResultIn {
            in item result : ServiceResult;
        }
    }

    part def ApplicationServiceAdapter {
        attribute defaultTimeout : Millisecond = 2000.0;
        port service : ServicePort;
    }

    part def ResponseGenerator {
        port resultIn {
            in item result : ServiceResult;
        }
        port contextIn {
            in item context : DialogContext;
        }
        port responseOut {
            out item response : ResponseText;
        }
    }

    part def TextToSpeechSynthesizer {
        attribute voiceName : String = "clear-neutral";
        attribute maximumSynthesisLatency : Millisecond = 700.0;
        port textIn {
            in item response : ResponseText;
        }
        port speechOut : AudioOutputPort;
    }

    part def Speaker {
        attribute nominalOutputLevel : DecibelSPL = 65.0;
        port audioIn {
            in item speech : SynthesizedSpeech;
        }
        port soundOut : AudioOutputPort;
    }

    part def PrivacyController {
        attribute localProcessingEnabled : Boolean = true;
        attribute recordingIndicatorRequired : Boolean = true;
        port privacy : PrivacyPort;
    }

    action def CaptureSpeech {
        in item acousticInput : AcousticWave;
        out item segment : SpeechSegment;
    }

    action def DetectWakePhrase {
        in item segment : SpeechSegment;
        out item wakePhrase : WakePhrase;
    }

    action def RecognizeSpeech {
        in item segment : SpeechSegment;
        out item transcript : Transcript;
    }

    action def InterpretIntent {
        in item transcript : Transcript;
        out item intent : Intent;
    }

    action def ManageDialog {
        in item intent : Intent;
        inout item context : DialogContext;
        out item request : ServiceRequest;
        out item response : ResponseText;
    }

    action def ExecuteServiceCommand {
        in item request : ServiceRequest;
        out item result : ServiceResult;
    }

    action def GenerateSpokenResponse {
        in item result : ServiceResult;
        in item context : DialogContext;
        out item response : ResponseText;
    }

    action def SynthesizeSpeech {
        in item response : ResponseText;
        out item speech : SynthesizedSpeech;
    }

    state def VoiceInteractionStates {
        state idle;
        state listening;
        state capturingSpeech;
        state recognizingSpeech;
        state understandingIntent;
        state fulfillingRequest;
        state speakingResponse;
        state errorRecovery;
        state privacyLocked;

        transition initial then idle;

        transition idle_to_listening
            first idle
            accept WakePhrase
            then listening;

        transition listening_to_capture
            first listening
            then capturingSpeech;

        transition capture_to_recognize
            first capturingSpeech
            then recognizingSpeech;

        transition recognize_to_understand
            first recognizingSpeech
            if transcript.confidence >= 0.72
            then understandingIntent;

        transition recognize_to_error
            first recognizingSpeech
            if transcript.confidence < 0.72
            then errorRecovery;

        transition understand_to_fulfill
            first understandingIntent
            if intent.confidence >= 0.70
            then fulfillingRequest;

        transition understand_to_error
            first understandingIntent
            if intent.confidence < 0.70
            then errorRecovery;

        transition fulfill_to_speak
            first fulfillingRequest
            then speakingResponse;

        transition speak_to_idle
            first speakingResponse
            then idle;

        transition any_to_privacy_locked
            accept PrivacyEvent
            if privacyCommand.eventName == "mute"
            then privacyLocked;

        transition privacy_locked_to_idle
            first privacyLocked
            accept PrivacyEvent
            if privacyCommand.eventName == "unmute"
            then idle;

        transition error_to_speak
            first errorRecovery
            then speakingResponse;
    }

    part def VoiceUserInterfaceSystem {
        doc /* Primary function: provide a voice-first interface that captures spoken user requests, detects activation, converts speech to text, determines user intent, executes supported commands, and returns an audible natural-language response. */

        attribute supportedLocale : String = "en-US";
        attribute endToEndLatencyTarget : Millisecond = 3000.0;
        attribute minimumWakeWordConfidence : ConfidenceScore = 0.86;
        attribute minimumIntentConfidence : ConfidenceScore = 0.70;

        port userSpeechIn : AcousticInputPort;
        port spokenResponseOut : AudioOutputPort;
        port externalService : ServicePort;
        port privacyControl : PrivacyPort;

        part microphoneArray : MicrophoneArray;
        part wakeWordDetector : WakeWordDetector;
        part speechRecognizer : SpeechRecognizer;
        part languageUnderstanding : NaturalLanguageUnderstanding;
        part dialogManager : DialogManager;
        part serviceAdapter : ApplicationServiceAdapter;
        part responseGenerator : ResponseGenerator;
        part speechSynthesizer : TextToSpeechSynthesizer;
        part speaker : Speaker;
        part privacyController : PrivacyController;

        connect userSpeechIn.acousticInput to microphoneArray.soundIn.acousticInput;
        connect microphoneArray.speechOut.segment to wakeWordDetector.audioIn.segment;
        connect microphoneArray.speechOut.segment to speechRecognizer.audioIn.segment;
        connect speechRecognizer.transcriptOut.transcript to languageUnderstanding.transcriptIn.transcript;
        connect languageUnderstanding.intentOut.intent to dialogManager.dialog.interpretedIntent;
        connect dialogManager.dialog.serviceRequest to serviceAdapter.service.request;
        connect serviceAdapter.service.result to dialogManager.serviceResultIn.result;
        connect serviceAdapter.service.result to responseGenerator.resultIn.result;
        connect dialogManager.dialog.context to responseGenerator.contextIn.context;
        connect responseGenerator.responseOut.response to speechSynthesizer.textIn.response;
        connect speechSynthesizer.speechOut.audioOutput to speaker.audioIn.speech;
        connect speaker.soundOut.audioOutput to spokenResponseOut.audioOutput;
        connect externalService.request to serviceAdapter.service.request;
        connect serviceAdapter.service.result to externalService.result;
        connect privacyControl.privacyCommand to privacyController.privacy.privacyCommand;

        perform action CaptureSpeech;
        perform action DetectWakePhrase;
        perform action RecognizeSpeech;
        perform action InterpretIntent;
        perform action ManageDialog;
        perform action ExecuteServiceCommand;
        perform action GenerateSpokenResponse;
        perform action SynthesizeSpeech;

        exhibit state VoiceInteractionStates;
    }

    requirement def HighLevelVoiceFunction {
        subject vui : VoiceUserInterfaceSystem;
        require constraint {
            vui.endToEndLatencyTarget <= 3000.0
        }
    }

    requirement def WakeWordActivation {
        subject vui : VoiceUserInterfaceSystem;
        require constraint {
            vui.minimumWakeWordConfidence >= 0.85
        }
    }

    requirement def IntentUnderstandingQuality {
        subject vui : VoiceUserInterfaceSystem;
        require constraint {
            vui.minimumIntentConfidence >= 0.70
        }
    }

    requirement def AudibleResponseRequirement {
        subject vui : VoiceUserInterfaceSystem;
        require constraint {
            vui.speechSynthesizer.maximumSynthesisLatency <= 700.0
        }
    }

    requirement def PrivacyMuteRequirement {
        subject vui : VoiceUserInterfaceSystem;
        require constraint {
            vui.privacyController.recordingIndicatorRequired == true
        }
    }

    requirement highLevelFunction : HighLevelVoiceFunction {
        doc /* The system shall provide a voice user interface that enables a user to issue spoken commands and receive spoken responses without visual interaction. */
    }

    requirement activationRequirement : WakeWordActivation {
        doc /* The system shall transition from idle to listening only when the detected wake phrase confidence meets or exceeds the configured threshold. */
    }

    requirement understandingRequirement : IntentUnderstandingQuality {
        doc /* The system shall request clarification or enter error recovery when intent confidence is below the configured threshold. */
    }

    requirement responseRequirement : AudibleResponseRequirement {
        doc /* The system shall synthesize a spoken response within the configured synthesis latency target after response text is available. */
    }

    requirement privacyRequirement : PrivacyMuteRequirement {
        doc /* The system shall support a privacy locked state that prevents speech capture and indicates recording status while muted. */
    }

    part voiceAssistant : VoiceUserInterfaceSystem;
}