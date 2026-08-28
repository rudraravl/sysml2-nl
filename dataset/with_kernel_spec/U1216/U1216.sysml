package 'Voice-Activated Smart Speaker System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	item def WakeWord {
		attribute word : String;
	}

	item def VoiceCommand {
		attribute audioData : String;
		attribute duration : Real;
	}

	item def CloudRequest {
		attribute commandText : String;
		attribute deviceId : String;
	}

	item def CloudResponse {
		attribute responseText : String;
		attribute intent : String;
		attribute targetDevice : String;
		attribute actionType : String;
	}

	item def SynthesizedAudio {
		attribute audioStream : String;
	}

	item def SmartHomeCommand {
		attribute deviceId : String;
		attribute command : String;
		attribute value : Real;
	}

	item def VisualCue {
		attribute color : String;
		attribute pattern : String;
	}

	item def AmbientNoise {
		attribute level : Real;
	}

	action def CaptureAudio {
		in noise : AmbientNoise;
		out audio : VoiceCommand;
	}

	action def DetectWakeWord {
		in audio : VoiceCommand;
		out detected : WakeWord;
	}

	action def RecordCommand {
		in audio : VoiceCommand;
		out command : VoiceCommand;
	}

	action def SendRequest {
		in command : VoiceCommand;
		out request : CloudRequest;
	}

	action def ProcessNaturalLanguage {
		in request : CloudRequest;
		out response : CloudResponse;
	}

	action def SynthesizeSpeech {
		in response : CloudResponse;
		out audio : SynthesizedAudio;
	}

	action def PlayAudio {
		in audio : SynthesizedAudio;
	}

	action def SendDeviceCommand {
		in response : CloudResponse;
		out command : SmartHomeCommand;
	}

	action def DisplayCue {
		in cue : VisualCue;
	}

	part def MicrophoneArray {
		port audioOut;
		port noiseIn;
		perform action captureAudio : CaptureAudio;
	}

	part def VoiceProcessor {
		port audioIn;
		port wakeOut;
		port commandOut;
		attribute wakeWord : String = "Hey Speaker";
		perform action detectWakeWord : DetectWakeWord;
		perform action recordCommand : RecordCommand;
	}

	part def NetworkInterface {
		port requestIn;
		port requestOut;
		port responseIn;
		port responseOut;
		perform action sendRequest : SendRequest;
	}

	part def CloudService {
		port requestIn;
		port responseOut;
		perform action processNaturalLanguage : ProcessNaturalLanguage;
	}

	part def AudioSynthesizer {
		port textIn;
		port audioOut;
		perform action synthesizeSpeech : SynthesizeSpeech;
	}

	part def SpeakerUnit {
		port audioIn;
		perform action playAudio : PlayAudio;
	}

	part def SmartHomeHub {
		port commandIn;
		port deviceOut;
		perform action sendDeviceCommand : SendDeviceCommand;
	}

	part def LEDIndicator {
		port cueIn;
		perform action displayCue : DisplayCue;
	}

	part def SmartSpeaker {
		part micArray : MicrophoneArray;
		part voiceProc : VoiceProcessor;
		part network : NetworkInterface;
		part cloud : CloudService;
		part synthesizer : AudioSynthesizer;
		part speaker : SpeakerUnit;
		part hub : SmartHomeHub;
		part led : LEDIndicator;

		connect micArray.audioOut to voiceProc.audioIn;
		connect voiceProc.commandOut to network.requestIn;
		connect network.requestOut to cloud.requestIn;
		connect cloud.responseOut to network.responseIn;
		connect network.responseOut to synthesizer.textIn;
		connect network.responseOut to hub.commandIn;
		connect synthesizer.audioOut to speaker.audioIn;

		state speakerStates {
			entry; then idle;

			state idle {
				do send new VisualCue(color = "blue", pattern = "solid") to led;
			}

			transition idle_to_listening
				first idle
				accept WakeWord via voiceProc.wakeOut
				do send new VisualCue(color = "green", pattern = "pulsing") to led
				then listening;

			state listening;

			transition listening_to_processing
				first listening
				accept VoiceCommand via voiceProc.commandOut
				do send new VisualCue(color = "yellow", pattern = "spinning") to led
				then processing;

			state processing;

			transition processing_to_responding
				first processing
				accept CloudResponse via network.responseOut
				then responding;

			state responding;

			transition responding_to_idle
				first responding
				accept after 1 [SI::s]
				do send new VisualCue(color = "blue", pattern = "solid") to led
				then idle;
		}
	}

	requirement def ResponseTimeRequirement {
		doc /* The system shall process voice commands and provide a response within 2.5 seconds. */
		attribute maxResponseTime : Real = 2.5;
		subject speaker : SmartSpeaker;
	}

	requirement def VoiceRecognitionAccuracyRequirement {
		doc /* The system shall achieve at least 95% voice recognition accuracy in environments with ambient noise up to 70 dB. */
		attribute minAccuracy : Real = 0.95;
		attribute maxNoiseLevel : Real = 70;
		subject speaker : SmartSpeaker;
	}

	requirement def NetworkReliabilityRequirement {
		doc /* The system shall maintain network connectivity with 99.9% uptime for cloud service communication. */
		attribute minUptime : Real = 99.9;
		subject speaker : SmartSpeaker;
	}

	part smartSpeaker : SmartSpeaker;

	requirement respTimeReq : ResponseTimeRequirement {
		subject :>> speaker = smartSpeaker;
	}

	requirement accReq : VoiceRecognitionAccuracyRequirement {
		subject :>> speaker = smartSpeaker;
	}

	requirement netReq : NetworkReliabilityRequirement {
		subject :>> speaker = smartSpeaker;
	}
}
