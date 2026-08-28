package 'Google Assistant Model' {
	private import ScalarValues::*;
	
	item def RawAudio {
		attribute amplitude : Real;
		attribute duration : Real;
	}
	item def TranscribedText {
		attribute text : String;
	}
	item def Intent {
		attribute intentType : String;
		attribute parameters : String;
	}
	item def KnowledgeResult {
		attribute content : String;
	}
	item def ResponseText {
		attribute text : String;
	}
	item def SpokenAudio {
		attribute amplitude : Real;
		attribute duration : Real;
	}
	item def SmartHomeCommand {
		attribute deviceId : String;
		attribute commandType : String;
		attribute targetTemperature : Real;
	}
	item def DeviceStatus {
		attribute status : String;
	}
	item def ContextData {
		attribute history : String;
		attribute preferences : String;
	}
	
	item def WakeWordDetected;
	item def TranscriptionComplete;
	item def IntentAnalyzed;
	item def ResultGenerated;
	item def ResponseDelivered;
	
	part def VoiceInterface {
		port micPort {
			out audioOut : RawAudio;
		}
		port speakerPort {
			in audioIn : SpokenAudio;
		}
		action captureAudio {
			out audio : RawAudio;
		}
		action playAudio {
			in audio : SpokenAudio;
		}
	}
	
	part def SpeechRecognitionEngine {
		port audioInPort {
			in audio : RawAudio;
		}
		port textOutPort {
			out text : TranscribedText;
		}
		action transcribeSpeech {
			in audio : RawAudio;
			out text : TranscribedText;
		}
	}
	
	part def NaturalLanguageUnderstanding {
		port textInPort {
			in text : TranscribedText;
		}
		port intentOutPort {
			out intent : Intent;
		}
		port contextInPort {
			in context : ContextData;
		}
		action analyzeText {
			in text : TranscribedText;
			in context : ContextData;
			out intent : Intent;
		}
	}
	
	part def KnowledgeEngine {
		port intentInPort {
			in intent : Intent;
		}
		port contextInPort {
			in context : ContextData;
		}
		port resultOutPort {
			out result : KnowledgeResult;
		}
		port commandOutPort {
			out command : SmartHomeCommand;
		}
		port statusInPort {
			in status : DeviceStatus;
		}
		action processRequest {
			in intent : Intent;
			in context : ContextData;
			out result : KnowledgeResult;
			out command : SmartHomeCommand;
		}
	}
	
	part def SmartHomeController {
		port commandInPort {
			in command : SmartHomeCommand;
		}
		port statusOutPort {
			out status : DeviceStatus;
		}
		action executeCommand {
			in command : SmartHomeCommand;
			out status : DeviceStatus;
		}
	}
	
	part def ResponseGenerator {
		port resultInPort {
			in result : KnowledgeResult;
		}
		port textOutPort {
			out text : ResponseText;
		}
		action generateResponse {
			in result : KnowledgeResult;
			out text : ResponseText;
		}
	}
	
	part def TextToSpeechEngine {
		port textInPort {
			in text : ResponseText;
		}
		port audioOutPort {
			out audio : SpokenAudio;
		}
		action synthesizeSpeech {
			in text : ResponseText;
			out audio : SpokenAudio;
		}
	}
	
	part def ContextManager {
		port contextOutPort {
			out context : ContextData;
		}
		action updateContext {
			in history : String;
			in preferences : String;
			out context : ContextData;
		}
	}
	
	state def assistantLifecycle {
		state idle;
		state listening;
		state understanding;
		state processing;
		state responding;
		
		transition t1 first idle then listening;
		transition t2 first listening then understanding;
		transition t3 first understanding then processing;
		transition t4 first processing then responding;
		transition t5 first responding then idle;
	}
	
	part def GoogleAssistant {
		part voiceInterface : VoiceInterface;
		part speechRecognition : SpeechRecognitionEngine;
		part nlu : NaturalLanguageUnderstanding;
		part knowledgeEngine : KnowledgeEngine;
		part smartHomeController : SmartHomeController;
		part responseGenerator : ResponseGenerator;
		part ttsEngine : TextToSpeechEngine;
		part contextManager : ContextManager;
		
		flow audioToSR of RawAudio 
			from voiceInterface.micPort.audioOut to speechRecognition.audioInPort.audio;
		flow textToNLU of TranscribedText 
			from speechRecognition.textOutPort.text to nlu.textInPort.text;
		flow intentToKE of Intent 
			from nlu.intentOutPort.intent to knowledgeEngine.intentInPort.intent;
		flow commandToSHC of SmartHomeCommand 
			from knowledgeEngine.commandOutPort.command to smartHomeController.commandInPort.command;
		flow statusToKE of DeviceStatus 
			from smartHomeController.statusOutPort.status to knowledgeEngine.statusInPort.status;
		flow resultToRG of KnowledgeResult 
			from knowledgeEngine.resultOutPort.result to responseGenerator.resultInPort.result;
		flow textToTTS of ResponseText 
			from responseGenerator.textOutPort.text to ttsEngine.textInPort.text;
		flow audioToVI of SpokenAudio 
			from ttsEngine.audioOutPort.audio to voiceInterface.speakerPort.audioIn;
		flow contextToNLU of ContextData 
			from contextManager.contextOutPort.context to nlu.contextInPort.context;
		flow contextToKE of ContextData 
			from contextManager.contextOutPort.context to knowledgeEngine.contextInPort.context;
		
		exhibit assistantLifecycle;
	}
	
	requirement def ShallUnderstandCommands {
		subject assistant : GoogleAssistant;
		objective {
			doc /* The Google Assistant shall understand and respond to user commands. */
		}
	}
	requirement def ShallAnswerQuestions {
		subject assistant : GoogleAssistant;
		objective {
			doc /* The Google Assistant shall answer informational questions using the Knowledge Engine. */
		}
	}
	requirement def ShallControlSmartHome {
		subject assistant : GoogleAssistant;
		objective {
			doc /* The Google Assistant shall control smart home devices via the Smart Home Controller. */
		}
	}
	requirement def ShallManageContext {
		subject assistant : GoogleAssistant;
		objective {
			doc /* The Google Assistant shall maintain conversation history and user preferences via the Context Manager. */
		}
	}
	
	part googleAssistantInstance : GoogleAssistant;
	
	requirement reqUnderstand : ShallUnderstandCommands;
	requirement reqAnswer : ShallAnswerQuestions;
	requirement reqControl : ShallControlSmartHome;
	requirement reqContext : ShallManageContext;
	
	satisfy reqUnderstand by googleAssistantInstance;
	satisfy reqAnswer by googleAssistantInstance;
	satisfy reqControl by googleAssistantInstance;
	satisfy reqContext by googleAssistantInstance;
}
