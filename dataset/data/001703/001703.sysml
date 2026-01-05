package 'Google Assistant System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	item def VoiceInput {
		attribute audioData : String;
		attribute timestamp : DurationValue;
		attribute languageCode : String;
	}
	
	item def TranscribedText {
		attribute text : String;
		attribute confidence : Real;
	}
	
	item def UserIntent {
		attribute intentType : String;
		attribute entities : String;
		attribute confidenceScore : Real;
	}
	
	item def QueryResponse {
		attribute responseText : String;
		attribute actionType : String;
		attribute contextData : String;
	}
	
	item def VoiceOutput {
		attribute audioData : String;
		attribute responseText : String;
	}
	
	item def DeviceCommand {
		attribute deviceId : String;
		attribute commandType : String;
		attribute parameters : String;
	}
	
	port def AudioInputPort {
		in item voiceIn : VoiceInput;
	}
	
	port def AudioOutputPort {
		out item voiceOut : VoiceOutput;
	}
	
	port def TextPort {
		in item textIn : TranscribedText;
		out item textOut : String;
	}
	
	port def IntentPort {
		in item intentIn : UserIntent;
		out item intentOut : UserIntent;
	}
	
	port def ResponsePort {
		in item responseIn : QueryResponse;
		out item responseOut : QueryResponse;
	}
	
	port def DeviceControlPort {
		out item commandOut : DeviceCommand;
	}
	
	action def CaptureAudio {
		in voiceData : VoiceInput;
		out rawAudio : String;
	}
	
	action def TranscribeSpeech {
		in audioInput : String;
		out transcription : TranscribedText;
	}
	
	action def UnderstandIntent {
		in textInput : TranscribedText;
		out intent : UserIntent;
	}
	
	action def ProcessQuery {
		in userIntent : UserIntent;
		out response : QueryResponse;
	}
	
	action def GenerateResponse {
		in queryResponse : QueryResponse;
		out responseText : String;
	}
	
	action def SynthesizeSpeech {
		in textInput : String;
		out audioOutput : VoiceOutput;
	}
	
	action def ControlDevice {
		in command : QueryResponse;
		out deviceCommand : DeviceCommand;
	}
	
	part def VoiceInterface {
		port audioIn : AudioInputPort;
		port audioOut : AudioOutputPort;
		
		part microphone {
			perform action capture : CaptureAudio;
		}
		
		part speaker {
			perform action playback;
		}
	}
	
	part def SpeechRecognitionEngine {
		port audioInputPort;
		port textOutputPort;
		
		perform action transcribe : TranscribeSpeech;
	}
	
	part def NaturalLanguageUnderstanding {
		port textInputPort;
		port intentOutputPort;
		
		perform action understand : UnderstandIntent;
	}
	
	part def KnowledgeEngine {
		port intentInputPort;
		port responseOutputPort;
		
		attribute knowledgeBase : String;
		
		perform action process : ProcessQuery;
	}
	
	part def ResponseGenerator {
		port responseInputPort;
		port textOutputPort;
		
		perform action generate : GenerateResponse;
	}
	
	part def TextToSpeechEngine {
		port textInputPort;
		port audioOutputPort;
		
		perform action synthesize : SynthesizeSpeech;
	}
	
	part def SmartHomeController {
		port commandInputPort;
		port deviceOutputPort : DeviceControlPort;
		
		perform action control : ControlDevice;
	}
	
	part def ContextManager {
		attribute conversationHistory : String[*];
		attribute userPreferences : String;
		attribute sessionId : String;
	}
	
	state def AssistantOperationalState {
		entry; then idle;
		
		state idle {
			doc /* Waiting for user activation */
		}
		
		accept wakeWordDetected;
		transition idle_to_listening
			first idle
			accept wakeWordDetected
			then listening;
		
		state listening {
			entry; then captureAudio;
			state captureAudio;
			then processAudio;
			state processAudio;
		}
		
		accept audioComplete;
		transition listening_to_understanding
			first listening
			accept audioComplete
			then understanding;
		
		state understanding {
			entry; then transcribeAudio;
			state transcribeAudio;
			then analyzeIntent;
			state analyzeIntent;
		}
		
		accept intentRecognized;
		transition understanding_to_processing
			first understanding
			accept intentRecognized
			then processing;
		
		state processing {
			entry; then queryKnowledge;
			state queryKnowledge;
			then formulateResponse;
			state formulateResponse;
		}
		
		accept responseReady;
		transition processing_to_responding
			first processing
			accept responseReady
			then responding;
		
		state responding {
			entry; then synthesizeAudio;
			state synthesizeAudio;
			then deliverResponse;
			state deliverResponse;
		}
		
		accept responseComplete;
		transition responding_to_idle
			first responding
			accept responseComplete
			then idle;
		
		state executing {
			entry; then executeAction;
			state executeAction;
		}
		
		accept actionRequired;
		accept actionComplete;
		transition processing_to_executing
			first processing
			accept actionRequired
			then executing;
		
		transition executing_to_responding
			first executing
			accept actionComplete
			then responding;
	}
	
	action def AssistUserInteraction {
		first start;
		then merge awaitActivation;
		
		action awaitActivation;
		
		then action captureVoice : CaptureAudio {
			out voiceData;
			out rawAudio;
		}
		
		then action transcribeUserSpeech : TranscribeSpeech {
			in audioInput = captureVoice.rawAudio;
			out transcription;
		}
		
		then decide;
			if transcribeUserSpeech.transcription.confidence >= 0.8 then understandUserIntent;
			if transcribeUserSpeech.transcription.confidence < 0.8 then requestRepeat;
		
		action understandUserIntent : UnderstandIntent {
			in textInput = transcribeUserSpeech.transcription;
			out intent;
		}
		then processUserQuery;
		
		action processUserQuery : ProcessQuery {
			in userIntent = understandUserIntent.intent;
			out response;
		}
		
		then decide;
			if processUserQuery.response.actionType == "device_control" then executeDeviceControl;
			if processUserQuery.response.actionType != "device_control" then generateTextResponse;
		
		action executeDeviceControl : ControlDevice {
			in command = processUserQuery.response;
			out deviceCommand;
		}
		then generateTextResponse;
		
		action generateTextResponse : GenerateResponse {
			in queryResponse = processUserQuery.response;
			out responseText;
		}
		
		then action synthesizeVoiceResponse : SynthesizeSpeech {
			in textInput = generateTextResponse.responseText;
			out audioOutput;
		}
		
		then action deliverVoiceResponse {
			in voiceData = synthesizeVoiceResponse.audioOutput;
		}
		
		then awaitActivation;
		
		action requestRepeat {
			out clarificationPrompt;
		}
		then awaitActivation;
	}
	
	part def GoogleAssistantSystem {
		part voiceInterface : VoiceInterface;
		
		part speechRecognition : SpeechRecognitionEngine;
		
		part nlu : NaturalLanguageUnderstanding;
		
		part knowledge : KnowledgeEngine;
		
		part responseGenerator : ResponseGenerator;
		
		part tts : TextToSpeechEngine;
		
		part smartHomeController : SmartHomeController;
		
		part contextManager : ContextManager;
		
		connection voiceToRecognition connect voiceInterface.audioIn to speechRecognition.audioInputPort;
		connection recognitionToNlu connect speechRecognition.textOutputPort to nlu.textInputPort;
		connection nluToKnowledge connect nlu.intentOutputPort to knowledge.intentInputPort;
		connection knowledgeToGenerator connect knowledge.responseOutputPort to responseGenerator.responseInputPort;
		connection generatorToTts connect responseGenerator.textOutputPort to tts.textInputPort;
		connection ttsToVoice connect tts.audioOutputPort to voiceInterface.audioOut;
		connection knowledgeToSmartHome connect knowledge.responseOutputPort to smartHomeController.commandInputPort;
		
		exhibit state operationalState : AssistantOperationalState;
		
		perform action assistantBehavior : AssistUserInteraction;
	}
	
	requirement def VoiceAssistantRequirement {
		doc /* The Google Assistant system shall provide intelligent voice-activated assistance to users. */
		
		require speechAccuracyRequirement;
		require responseTimeRequirement;
		require functionalCapabilityRequirement;
	}
	
	requirement <'GA-REQ-001'> speechAccuracyRequirement {
		doc /* Speech recognition accuracy shall be at least 95% for clear audio input in supported languages. */
		
		subject googleAssistant.speechRecognition;
	}
	
	requirement <'GA-REQ-002'> responseTimeRequirement {
		doc /* The system shall respond to user queries within 2 seconds under normal operating conditions. */
		
		subject googleAssistant;
	}
	
	requirement <'GA-REQ-003'> functionalCapabilityRequirement {
		doc /* The system shall support voice query processing, smart home device control, and conversational responses. */
		
		subject googleAssistant;
	}
	
	requirement primaryFunction : VoiceAssistantRequirement {
		doc /* 
		The Google Assistant system provides intelligent voice-activated assistance to users.
		It captures voice input through a microphone interface, transcribes speech to text using
		advanced speech recognition, understands user intent through natural language processing,
		processes queries using a knowledge engine, controls smart home devices when requested,
		generates appropriate responses, synthesizes speech output, and delivers spoken responses
		to users. The system maintains conversation context and user preferences to provide
		personalized assistance across multiple interaction sessions.
		*/
	}
	
	part googleAssistant : GoogleAssistantSystem;
	
	satisfy primaryFunction by googleAssistant;
}
