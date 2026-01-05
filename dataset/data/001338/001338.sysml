package 'Amazon Alexa Voice Assistant System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def WakeWord;
	attribute def VoiceCommand;
	attribute def IntentType;
	attribute def ResponseText;
	
	item def AudioSignal {
		attribute frequency : ISQ::FrequencyValue;
		attribute amplitude : Real;
		attribute duration : ISQ::DurationValue;
		attribute content : String;
	}
	
	item def NetworkMessage {
		attribute payload : String;
		attribute timestamp : ISQ::TimeValue;
		attribute messageType : String;
	}
	
	item def UserIntent {
		attribute intentType : IntentType;
		attribute entities : String[*];
		attribute confidence : Real;
	}
	
	item def ServiceResponse {
		attribute responseType : String;
		attribute data : String;
		attribute audioContent : String;
	}
	
	port def MicrophonePort {
		out item audioOut : AudioSignal;
	}
	
	port def SpeakerPort {
		in item audioIn : AudioSignal;
	}
	
	port def NetworkPort {
		in item messageIn : NetworkMessage;
		out item messageOut : NetworkMessage;
	}
	
	port def ControlPort {
		out item controlSignal : String;
	}
	
	part def MicrophoneArray {
		attribute microphoneCount : Integer := 7;
		port audioOutput : MicrophonePort;
		
		action captureAudio {
			out capturedSignal : AudioSignal;
		}
	}
	
	part def SpeakerUnit {
		attribute maxPowerOutput : ISQ::PowerValue;
		port audioInput : SpeakerPort;
		
		action playAudio {
			in audioSignal : AudioSignal;
		}
	}
	
	part def WakeWordEngine {
		attribute wakeWordModel : WakeWord;
		attribute sensitivityThreshold : Real := 0.85;
		
		action detectWakeWord {
			in audioStream : AudioSignal;
			out isWakeWordDetected : Boolean;
			out detectionConfidence : Real;
		}
	}
	
	part def AutomaticSpeechRecognition {
		attribute languageModel : String := "en-US";
		
		action transcribeAudio {
			in voiceInput : AudioSignal;
			out transcribedText : String;
			out transcriptionConfidence : Real;
		}
	}
	
	part def NaturalLanguageUnderstanding {
		action extractIntent {
			in userUtterance : String;
			out intent : UserIntent;
		}
		
		action identifyEntities {
			in utterance : String;
			out entities : String[*];
		}
	}
	
	part def AlexaVoiceService {
		port networkInterface : NetworkPort;
		
		action processUserRequest {
			in userIntent : UserIntent;
			out serviceResponse : ServiceResponse;
		}
		
		action queryKnowledgeBase {
			in query : String;
			out answer : String;
		}
		
		action executeSkill {
			in skillIntent : UserIntent;
			out skillResult : ServiceResponse;
		}
	}
	
	part def TextToSpeechEngine {
		attribute voiceProfile : String := "Neural";
		
		action synthesizeSpeech {
			in textInput : String;
			out synthesizedAudio : AudioSignal;
		}
	}
	
	part def SmartHomeController {
		port controlInterface : ControlPort;
		
		action controlDevice {
			in deviceCommand : String;
			in deviceId : String;
		}
	}
	
	part def LocalProcessor {
		attribute processorSpeed : ISQ::FrequencyValue;
		attribute memoryCapacity : Real;
		
		action coordinateComponents {
			in audioInput : AudioSignal;
			out processedOutput : AudioSignal;
		}
	}
	
	part def AlexaEchoDevice {
		part microphones : MicrophoneArray;
		part speaker : SpeakerUnit;
		part wakeWordDetector : WakeWordEngine;
		part speechRecognizer : AutomaticSpeechRecognition;
		part nluEngine : NaturalLanguageUnderstanding;
		part cloudService : AlexaVoiceService;
		part ttsEngine : TextToSpeechEngine;
		part smartHomeHub : SmartHomeController;
		part localProcessor : LocalProcessor;
		
		connection micToWakeWord connect microphones.audioOutput to wakeWordDetector.detectWakeWord.audioStream;
		connection micToASR connect microphones.audioOutput to speechRecognizer.transcribeAudio.voiceInput;
		connection ttsToSpeaker connect ttsEngine.synthesizeSpeech.synthesizedAudio to speaker.audioInput;
		
		perform action handleVoiceInteraction references voiceInteractionFlow;
	}
	
	action def ListenForWakeWord {
		in audioStream : AudioSignal;
		out wakeWordDetected : Boolean;
		out confidence : Real;
	}
	
	action def RecognizeSpeech {
		in audioStream : AudioSignal;
		out transcription : String;
	}
	
	action def UnderstandIntent {
		in transcription : String;
		out userIntent : UserIntent;
	}
	
	action def ProcessInCloud {
		in userIntent : UserIntent;
		out cloudResponse : ServiceResponse;
	}
	
	action def SynthesizeResponse {
		in responseText : String;
		out responseAudio : AudioSignal;
	}
	
	action def PlayResponse {
		in responseAudio : AudioSignal;
	}
	
	action voiceInteractionFlow : HandleVoiceInteraction {
		first start;
		then merge idleListening;
		
		action listenForWake : ListenForWakeWord {
			in audioStream;
			out wakeWordDetected;
			out confidence;
		}
		
		then decide;
			if listenForWake.wakeWordDetected and listenForWake.confidence >= 0.85 then captureCommand;
			if not listenForWake.wakeWordDetected or listenForWake.confidence < 0.85 then idleListening;
		
		action captureCommand : RecognizeSpeech {
			in audioStream;
			out transcription;
		}
		
		then action understandCommand : UnderstandIntent {
			in transcription = captureCommand.transcription;
			out userIntent;
		}
		
		then action processRequest : ProcessInCloud {
			in userIntent = understandCommand.userIntent;
			out cloudResponse;
		}
		
		then action generateResponse : SynthesizeResponse {
			in responseText = processRequest.cloudResponse.audioContent;
			out responseAudio;
		}
		
		then action deliverResponse : PlayResponse {
			in responseAudio = generateResponse.responseAudio;
		}
		
		then idleListening;
	}
	
	action def HandleVoiceInteraction {
		in audioStream : AudioSignal;
	}
	
	state def AlexaOperationalStates {
		entry; then idle;
		
		state idle {
			doc /* Device is in low-power listening mode, monitoring for wake word. */
		}
		
		transition idleToActive
			first idle
			accept wakeWordEvent : WakeWord
			then active;
		
		state active {
			entry; then listening;
			
			state listening {
				doc /* Actively capturing user voice command. */
			}
			
			transition listeningToProcessing
				first listening
				then processing;
			
			state processing {
				doc /* Transcribing speech and understanding intent. */
			}
			
			transition processingToCloudQuery
				first processing
				then cloudQuery;
			
			state cloudQuery {
				doc /* Communicating with Alexa Voice Service in cloud. */
			}
			
			transition cloudQueryToResponding
				first cloudQuery
				then responding;
			
			state responding {
				doc /* Synthesizing and playing audio response to user. */
			}
		}
		
		transition activeToIdle
			first active
			then idle;
	}
	
	part alexaDevice : AlexaEchoDevice {
		exhibit state operationalStates : AlexaOperationalStates;
	}
	
	requirement def FunctionalRequirement;
	requirement def PerformanceRequirement;
	requirement def QualityRequirement;
	
	requirement <'ALEXA-REQ-001'> primaryVoiceAssistantFunction : FunctionalRequirement {
		doc /* 
		The Amazon Alexa system shall function as a cloud-connected voice-activated intelligent assistant 
		that continuously listens for a wake word, captures and interprets natural language voice commands, 
		processes user requests through cloud-based artificial intelligence services, and delivers spoken 
		responses while also enabling control of smart home devices and access to third-party skills.
		*/
		
		assume constraint networkConnectivity {
			doc /* The device has reliable internet connectivity with latency under 100ms. */
		}
		
		assume constraint ambientNoise {
			doc /* Ambient noise levels are below 70 dB to ensure accurate wake word detection. */
		}
		
		require wakeWordDetectionRequirement;
		require speechRecognitionRequirement;
		require responseTimeRequirement;
		require audioQualityRequirement;
	}
	
	requirement wakeWordDetectionRequirement : QualityRequirement {
		doc /* The system shall detect the wake word with at least 95% accuracy in typical home environments. */
	}
	
	requirement speechRecognitionRequirement : QualityRequirement {
		doc /* The system shall transcribe user speech with at least 90% word accuracy for supported languages. */
	}
	
	requirement responseTimeRequirement : PerformanceRequirement {
		doc /* The system shall provide an audible response within 2 seconds of completing user utterance under normal network conditions. */
	}
	
	requirement audioQualityRequirement : QualityRequirement {
		doc /* The system shall reproduce audio responses with frequency range 80 Hz to 15 kHz and signal-to-noise ratio above 80 dB. */
	}
	
	requirement smartHomeIntegrationRequirement : FunctionalRequirement {
		doc /* The system shall support voice control of compatible smart home devices through standardized protocols. */
	}
	
	satisfy primaryVoiceAssistantFunction by alexaDevice;
	satisfy wakeWordDetectionRequirement by alexaDevice.wakeWordDetector;
	satisfy speechRecognitionRequirement by alexaDevice.speechRecognizer;
	satisfy responseTimeRequirement by alexaDevice;
	satisfy audioQualityRequirement by alexaDevice.speaker;
	satisfy smartHomeIntegrationRequirement by alexaDevice.smartHomeHub;
}
