package GoogleAssistant {
    import ISQ::*;
    
    // ===== Value Types =====
    value type SampleRate = Real { unit 'Hz'; }
    value type ConfidenceLevel = Real { unit '%' { min 0; max 100; } }
    value type AudioDuration = Real { unit 's'; }
    value type AudioAmplitude = Real { unit 'dB'; }
    value type Temperature = Real { unit 'degC'; }
    value type BrightnessLevel = Real { unit '%' { min 0; max 100; } }
    value type VolumeLevel = Real { unit '%' { min 0; max 100; } }
    
    // ===== Enumerations =====
    enum IntentType {
        weather_query;
        play_music;
        smart_home_command;
        general_question;
        follow_up;
    }
    
    enum DeviceType {
        light;
        thermostat;
        speaker;
        switch;
        unknown;
    }
    
    // ===== Item Definitions =====
    item def RawAudio {
        attribute samplingRate : SampleRate = 16000 [Hz];
        attribute duration : AudioDuration;
        attribute format : String = "PCM";
    }
    
    item def AudioResponse {
        attribute samplingRate : SampleRate = 22050 [Hz];
        attribute duration : AudioDuration;
        attribute format : String = "PCM";
    }
    
    item def TranscribedText {
        attribute content : String;
        attribute language : String = "en-US";
        attribute confidence : ConfidenceLevel;
    }
    
    item def Intent {
        attribute type : IntentType;
        attribute entities : String[*];
        attribute confidence : ConfidenceLevel;
    }
    
    item def SmartHomeCommand {
        attribute deviceId : String;
        attribute deviceType : DeviceType;
        attribute action : String;
        attribute params : String;
    }
    
    item def ResponseText {
        attribute content : String;
        attribute language : String = "en-US";
    }
    
    item def ContextData {
        attribute sessionId : String;
        attribute history : String[*];
        attribute userPreferences : String[*];
    }
    
    // ===== Port Definitions =====
    port def AudioInputPort {
        in rawAudio : RawAudio;
    }
    
    port def AudioOutputPort {
        out audioResponse : AudioResponse;
    }
    
    port def TextOutputPort {
        out text : TranscribedText;
    }
    
    port def TextInputPort {
        in text : TranscribedText;
    }
    
    port def IntentOutputPort {
        out intent : Intent;
    }
    
    port def IntentInputPort {
        in intent : Intent;
    }
    
    port def SmartHomeOutputPort {
        out command : SmartHomeCommand;
    }
    
    port def ResponseTextOutputPort {
        out response : ResponseText;
    }
    
    port def ResponseTextInputPort {
        in response : ResponseText;
    }
    
    port def ContextPort {
        in contextIn : ContextData;
        out contextOut : ContextData;
    }
    
    // ===== Part Definitions =====
    part def Microphone {
        attribute sensitivity : AudioAmplitude;
        port audioCapture : AudioInputPort;
    }
    
    part def Speaker {
        attribute volume : VolumeLevel = 50 [%];
        port audioPlay : AudioOutputPort;
    }
    
    part def VoiceInterface {
        part mic : Microphone {
            port audioCapture : AudioInputPort;
        }
        part speaker : Speaker {
            port audioPlay : AudioOutputPort;
        }
        
        attribute wakeWord : String = "Hey Google";
        attribute isActivated : Boolean = false;
        
        port micOut : AudioInputPort;
        port speakerIn : AudioOutputPort;
        
        action def captureAudio {
            in duration : AudioDuration;
            out captured : RawAudio;
        }
        
        action def playAudio {
            in audio : AudioResponse;
        }
        
        action def detectWakeWord {
            in audio : RawAudio;
            out detected : Boolean;
        }
    }
    
    part def SpeechRecognitionEngine {
        attribute modelVersion : String = "v3.2";
        attribute supportedLanguages : String[*] = {"en-US", "en-GB", "es-ES", "fr-FR", "de-DE"};
        
        port audioIn : AudioInputPort;
        port textOut : TextOutputPort;
        
        action def transcribe {
            in audio : RawAudio;
            out text : TranscribedText;
        }
    }
    
    part def NaturalLanguageUnderstanding {
        attribute modelVersion : String = "v2.5";
        attribute accuracyThreshold : ConfidenceLevel = 80 [%];
        
        port textIn : TextInputPort;
        port intentOut : IntentOutputPort;
        port contextRef : ContextPort;
        
        action def analyze {
            in text : TranscribedText;
            in context : ContextData;
            out intent : Intent;
        }
    }
    
    part def KnowledgeEngine {
        attribute knowledgeBaseVersion : String = "v2024.1";
        attribute queryCount : Integer = 0;
        
        port intentIn : IntentInputPort;
        port contextRef : ContextPort;
        port smartHomeOut : SmartHomeOutputPort;
        port responseOut : ResponseTextOutputPort;
        
        action def processIntent {
            in intent : Intent;
            in context : ContextData;
            out smartHomeCmd : SmartHomeCommand;
            out response : ResponseText;
        }
    }
    
    part def SmartHomeController {
        attribute pairedDevices : String[*];
        attribute connectionStatus : String = "connected";
        
        port commandIn : SmartHomeOutputPort;
        
        action def sendToDevice {
            in command : SmartHomeCommand;
        }
    }
    
    part def ResponseGenerator {
        attribute style : String = "natural";
        attribute maxResponseLength : Integer = 500;
        
        port responseIn : ResponseTextInputPort;
        port contextRef : ContextPort;
        port textOut : ResponseTextOutputPort;
        
        action def generate {
            in intent : Intent;
            in context : ContextData;
            out response : ResponseText;
        }
    }
    
    part def TextToSpeechEngine {
        attribute voiceModel : String = "en-US-Wavenet-D";
        attribute speed : Real = 1.0;
        
        port textIn : ResponseTextInputPort;
        port audioOut : AudioOutputPort;
        
        action def synthesize {
            in text : ResponseText;
            out audio : AudioResponse;
        }
    }
    
    part def ContextManager {
        attribute sessionId : String;
        attribute history : String[*];
        attribute userPreferences : String[*];
        attribute maxHistorySize : Integer = 100;
        
        port contextPort : ContextPort;
        
        action def updateContext {
            in interaction : String;
            out context : ContextData;
        }
    }
    
    // ===== State Machine for Assistant Lifecycle =====
    state def AssistantLifecycle {
        entry { /* initialize */ }
        
        state idle {
            entry { /* waiting for wake word */ }
            transition to listening
                when voiceInterface.mic.audioCapture.rawAudio != null;
        }
        
        state listening {
            entry { /* capturing command */ }
            do { voiceInterface.mic.audioCapture.captureAudio(); }
            transition to understanding
                when speechRecognition.textOut.text != null;
        }
        
        state understanding {
            entry { /* analyzing intent */ }
            do { naturalLanguageUnderstanding.analyze(); }
            transition to processing
                when naturalLanguageUnderstanding.intentOut.intent != null;
        }
        
        state processing {
            entry { /* formulating response */ }
            do { knowledgeEngine.processIntent(); }
            transition to responding
                when textToSpeech.audioOut.audioResponse != null;
        }
        
        state responding {
            entry { /* delivering answer */ }
            do { voiceInterface.speaker.audioPlay.playAudio(); }
            transition to idle
                when voiceInterface.speaker.audioPlay.audioResponse == null;
        }
    }
    
    // ===== Top-Level System =====
    part def GoogleAssistantSystem {
        part voiceInterface : VoiceInterface;
        part speechRecognition : SpeechRecognitionEngine;
        part naturalLanguageUnderstanding : NaturalLanguageUnderstanding;
        part knowledgeEngine : KnowledgeEngine;
        part smartHomeController : SmartHomeController;
        part responseGenerator : ResponseGenerator;
        part textToSpeech : TextToSpeechEngine;
        part contextManager : ContextManager;
        
        exhibit lifecycle : AssistantLifecycle;
        
        // Connections
        connection : voiceInterface.micOut to speechRecognition.audioIn;
        connection : speechRecognition.textOut to naturalLanguageUnderstanding.textIn;
        connection : naturalLanguageUnderstanding.intentOut to knowledgeEngine.intentIn;
        connection : knowledgeEngine.smartHomeOut to smartHomeController.commandIn;
        connection : knowledgeEngine.responseOut to textToSpeech.textIn;
        connection : textToSpeech.audioOut to voiceInterface.speakerIn;
        connection : contextManager.contextPort to naturalLanguageUnderstanding.contextRef;
        connection : contextManager.contextPort to knowledgeEngine.contextRef;
        connection : contextManager.contextPort to responseGenerator.contextRef;
    }
    
    // ===== Requirements =====
    requirement def WakeWordDetection {
        attribute targetWakeWord : String = "Hey Google";
        doc { The assistant shall be activated upon hearing the wake word. }
    }
    
    requirement def SpeechRecognitionAccuracy {
        attribute minAccuracy : ConfidenceLevel = 95 [%];
        doc { Speech recognition shall achieve at least 95% accuracy for supported languages. }
    }
    
    requirement def IntentClassification {
        attribute minConfidence : ConfidenceLevel = 80 [%];
        doc { Natural Language Understanding shall classify intent with at least 80% confidence. }
    }
    
    requirement def SmartHomeControl {
        doc { The system shall send appropriate commands to smart home devices when a smart home intent is detected. }
    }
    
    requirement def ResponseTime {
        attribute maxResponseTime : Real = 2.0 { unit 's'; }
        doc { The assistant shall respond within 2 seconds from end of user command. }
    }
    
    requirement def ContextRetention {
        attribute maxHistorySize : Integer = 100;
        doc { The Context Manager shall retain up to 100 interactions for follow-up conversations. }
    }
    
    requirement def GoogleAssistantRequirements {
        requirement wakeWord : WakeWordDetection;
        requirement recognition : SpeechRecognitionAccuracy;
        requirement intent : IntentClassification;
        requirement smartHome : SmartHomeControl;
        requirement latency : ResponseTime;
        requirement context : ContextRetention;
    }
    
    // Satisfies
    satisfy wakeWord by voiceInterface;
    satisfy recognition by speechRecognition;
    satisfy intent by naturalLanguageUnderstanding;
    satisfy smartHome by smartHomeController;
    satisfy latency by knowledgeEngine;
    satisfy context by contextManager;
}
