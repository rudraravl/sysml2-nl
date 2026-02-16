package VoiceUserInterfaceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def ConfidenceScore :> Real;
    attribute def SampleRate :> Real;
    
    item def AudioStream {
        attribute sampleRate : SampleRate;
        attribute duration : Real;
        attribute amplitude : Real;
    }
    
    item def VoiceCommand {
        attribute transcription : String;
        attribute confidence : ConfidenceScore;
        attribute timestamp : Real;
    }
    
    item def Intent {
        attribute intentAction : String;
        attribute parameters : String[*];
        attribute confidence : ConfidenceScore;
    }
    
    item def SystemResponse {
        attribute responseMessage : String;
        attribute actionPerformed : String;
        attribute success : Boolean;
    }
    
    port def AudioInputPort {
        in item audioIn : AudioStream;
    }
    
    port def AudioOutputPort {
        out item audioOut : AudioStream;
    }
    
    port def CommandPort {
        out item command : VoiceCommand;
    }
    
    port def IntentPort {
        out item intent : Intent;
    }
    
    port def ResponsePort {
        in item response : SystemResponse;
    }
    
    part def Microphone {
        attribute sensitivity : Real;
        attribute noiseReduction : Boolean;
        port audioOutput : AudioOutputPort;
    }
    
    part def Speaker {
        attribute volume : Real;
        attribute maxAmplitude : Real;
        port audioInput : AudioInputPort;
    }
    
    part def SpeechRecognitionEngine {
        attribute recognitionAccuracy : ConfidenceScore;
        attribute supportedLanguages : String[*];
        port audioInput : AudioInputPort;
        port commandOutput : CommandPort;
    }
    
    part def NaturalLanguageUnderstanding {
        attribute vocabularySize : Integer;
        attribute contextWindow : Integer;
        port commandInput {
            in item cmd : VoiceCommand;
        }
        port intentOutput : IntentPort;
    }
    
    part def DialogueController {
        attribute conversationHistory : String[*];
        attribute maxHistoryLength : Integer;
        port intentInput {
            in item intent : Intent;
        }
        port responseOutput : ResponsePort;
    }
    
    part def TextToSpeechEngine {
        attribute voiceQuality : String;
        attribute speechRate : Real;
        port responseInput : ResponsePort;
        port audioOutput : AudioOutputPort;
    }
    
    part def ApplicationInterface {
        attribute connectedServices : String[*];
        port intentInput {
            in item intent : Intent;
        }
        port statusOutput {
            out item status : SystemResponse;
        }
    }
    
    action def CaptureAudio {
        in micSensitivity : Real;
        out capturedAudio : AudioStream;
    }
    
    action def RecognizeSpeech {
        in audioStream : AudioStream;
        out recognizedCommand : VoiceCommand;
    }
    
    action def UnderstandIntent {
        in voiceCommand : VoiceCommand;
        out parsedIntent : Intent;
    }
    
    action def ManageDialogue {
        in parsedIntent : Intent;
        out dialogueResponse : SystemResponse;
    }
    
    action def ExecuteAction {
        in dialogueResponse : SystemResponse;
        out executionResult : SystemResponse;
    }
    
    action def SynthesizeSpeech {
        in responseMessage : SystemResponse;
        out synthesizedAudio : AudioStream;
    }
    
    action def PlayAudio {
        in audioStream : AudioStream;
    }
    
    action def ProcessVoiceInteraction {
        first start;
        then action capture : CaptureAudio;
        then action recognize : RecognizeSpeech {
            in audioStream = capture.capturedAudio;
        }
        then decide;
            if recognize.recognizedCommand.confidence >= 0.75 then understand;
            if recognize.recognizedCommand.confidence < 0.75 then requestRepeat;
        action understand : UnderstandIntent {
            in voiceCommand = recognize.recognizedCommand;
        }
        then action manage : ManageDialogue {
            in parsedIntent = understand.parsedIntent;
        }
        then action execute : ExecuteAction {
            in dialogueResponse = manage.dialogueResponse;
        }
        then action synthesize : SynthesizeSpeech {
            in responseMessage = execute.executionResult;
        }
        then action play : PlayAudio {
            in audioStream = synthesize.synthesizedAudio;
        }
        then done;
        
        action requestRepeat : SynthesizeSpeech;
        then play;
    }
    
    state def VoiceInterfaceStateMachine {
        entry; then idle;
        
        state idle;
        
        accept at idle
            then listening;
        
        state listening {
            entry; do action captureAction : CaptureAudio;
        }
        
        accept at listening
            if captureAction.capturedAudio.amplitude > 0.1
            then processing;
        
        accept at listening
            if captureAction.capturedAudio.amplitude <= 0.1
            then idle;
        
        state processing {
            entry; 
            do action recognizeAction : RecognizeSpeech;
            do action understandAction : UnderstandIntent;
            do action manageAction : ManageDialogue;
        }
        
        accept at processing
            if understandAction.parsedIntent.confidence >= 0.75
            then executing;
        
        accept at processing
            if understandAction.parsedIntent.confidence < 0.75
            then responding;
        
        state executing {
            entry; do action executeAction : ExecuteAction;
        }
        
        accept at executing
            then responding;
        
        state responding {
            entry; 
            do action synthesizeAction : SynthesizeSpeech;
            do action playAction : PlayAudio;
        }
        
        accept at responding
            then idle;
    }
    
    part def VoiceUserInterface {
        attribute systemLanguage : String;
        attribute wakeWord : String;
        attribute sessionActive : Boolean;
        attribute responseLatency : Real;
        
        part microphone : Microphone {
            attribute :>> sensitivity = 0.8;
            attribute :>> noiseReduction = true;
        }
        
        part speaker : Speaker {
            attribute :>> volume = 0.7;
            attribute :>> maxAmplitude = 1.0;
        }
        
        part speechRecognizer : SpeechRecognitionEngine {
            attribute :>> recognitionAccuracy = 0.95;
            attribute :>> supportedLanguages = ("en-US", "es-ES", "fr-FR");
        }
        
        part nluEngine : NaturalLanguageUnderstanding {
            attribute :>> vocabularySize = 100000;
            attribute :>> contextWindow = 5;
        }
        
        part dialogueController : DialogueController {
            attribute :>> maxHistoryLength = 10;
        }
        
        part ttsEngine : TextToSpeechEngine {
            attribute :>> voiceQuality = "natural";
            attribute :>> speechRate = 1.0;
        }
        
        part appInterface : ApplicationInterface;
        
        connection audioCapture connect microphone.audioOutput to speechRecognizer.audioInput;
        connection commandFlow connect speechRecognizer.commandOutput to nluEngine.commandInput;
        connection intentFlow connect nluEngine.intentOutput to dialogueController.intentInput;
        connection responseFlow connect dialogueController.responseOutput to ttsEngine.responseInput;
        connection audioPlayback connect ttsEngine.audioOutput to speaker.audioInput;
        connection appControl connect dialogueController.responseOutput to appInterface.intentInput;
        
        perform action interaction[*] ordered references ProcessVoiceInteraction;
        
        exhibit state stateMachine : VoiceInterfaceStateMachine;
    }
    
    requirement <'VUI-REQ-001'> primaryFunction {
        doc /* The Voice User Interface system shall enable users to interact 
             * with applications and services through natural spoken language, 
             * converting speech to actionable commands and providing audible 
             * responses to create a hands-free user experience.
             */
        subject vuiSystem : VoiceUserInterface;
    }
    
    requirement <'VUI-REQ-002'> recognitionAccuracy {
        doc /* The speech recognition engine shall achieve a minimum accuracy 
             * of 90% for supported languages under normal operating conditions.
             */
        subject recognizer :>> VoiceUserInterface::speechRecognizer;
        assert constraint {
            recognizer.recognitionAccuracy >= 0.90
        }
    }
    
    requirement <'VUI-REQ-003'> responseLatency {
        doc /* The system shall provide an audible response within 2 seconds 
             * of the completion of user speech input.
             */
        subject vuiSystem : VoiceUserInterface;
        assert constraint {
            vuiSystem.responseLatency <= 2.0
        }
    }
    
    requirement <'VUI-REQ-004'> confidenceThreshold {
        doc /* The system shall request clarification when speech recognition 
             * or intent understanding confidence falls below 75%.
             */
        subject vuiSystem : VoiceUserInterface;
    }
    
    part voiceSystem : VoiceUserInterface {
        attribute :>> systemLanguage = "en-US";
        attribute :>> wakeWord = "Hey Assistant";
        attribute :>> sessionActive = false;
        attribute :>> responseLatency = 1.5;
    }
    
    satisfy primaryFunction by voiceSystem;
    satisfy recognitionAccuracy by voiceSystem.speechRecognizer;
    satisfy responseLatency by voiceSystem;
    satisfy confidenceThreshold by voiceSystem;
}
