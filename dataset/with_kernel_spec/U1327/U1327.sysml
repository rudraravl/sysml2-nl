package 'Bose QuietComfort ANC Headphones' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import ISQ::*;

	item def AmbientNoise {
		attribute amplitude : Real;
		attribute frequency : Real;
	}
	item def LeakedNoise {
		attribute amplitude : Real;
		attribute frequency : Real;
	}
	item def AudioStream {
		attribute amplitude : Real;
		attribute frequency : Real;
	}
	item def AntiNoiseSignal {
		attribute amplitude : Real;
		attribute frequency : Real;
	}
	item def CorrectionSignal {
		attribute amplitude : Real;
		attribute frequency : Real;
	}
	item def CombinedAudioSignal {
		attribute amplitude : Real;
		attribute frequency : Real;
	}
	item def ElectricalPower {
		attribute voltage : Real;
		attribute current : Real;
	}

	port def AudioOutPort {
		out audio : AudioStream;
	}
	port def AudioInPort {
		in audio : AudioStream;
	}
	port def AmbientNoiseOutPort {
		out noise : AmbientNoise;
	}
	port def AmbientNoiseInPort {
		in noise : AmbientNoise;
	}
	port def LeakedNoiseOutPort {
		out noise : LeakedNoise;
	}
	port def LeakedNoiseInPort {
		in noise : LeakedNoise;
	}
	port def CombinedSignalOutPort {
		out signal : CombinedAudioSignal;
	}
	port def CombinedSignalInPort {
		in signal : CombinedAudioSignal;
	}
	port def PowerOutPort {
		out power : ElectricalPower;
	}
	port def PowerInPort {
		in power : ElectricalPower;
	}

	attribute def PowerOn;
	attribute def PowerOff;
	attribute def ActivateANC;
	attribute def DeactivateANC;
	attribute def ActivateTransparency;
	attribute def DeactivateTransparency;
	attribute def PlayMusic;
	attribute def StopMusic;

	action def ProcessNoise {
		in audio : AudioStream;
		in feedforward : AmbientNoise;
		in feedback : LeakedNoise;
		out antiNoise : AntiNoiseSignal;
		out combined : CombinedAudioSignal;
	}

	part def BluetoothReceiver {
		port audioOut : AudioOutPort;
		port powerIn : PowerInPort;
	}

	part def FeedforwardMicrophone {
		port noiseOut : AmbientNoiseOutPort;
		port powerIn : PowerInPort;
	}

	part def FeedbackMicrophone {
		port noiseOut : LeakedNoiseOutPort;
		port powerIn : PowerInPort;
	}

	part def DigitalSignalProcessor {
		port audioIn : AudioInPort;
		port feedforwardIn : AmbientNoiseInPort;
		port feedbackIn : LeakedNoiseInPort;
		port signalOut : CombinedSignalOutPort;
		port powerIn : PowerInPort;

		exhibit state dspStates {
			entry; then off;
			state off;
			transition first off accept PowerOn then idle;
			state idle;
			transition first idle accept ActivateANC then anc;
			transition first idle accept ActivateTransparency then transparency;
			state anc {
				entry; then ancNoMusic;
				state ancNoMusic;
				transition first ancNoMusic accept PlayMusic then ancWithMusic;
				state ancWithMusic;
				transition first ancWithMusic accept StopMusic then ancNoMusic;
			}
			state transparency;
			transition first anc accept DeactivateANC then idle;
			transition first transparency accept DeactivateTransparency then idle;
			transition first idle accept PowerOff then off;
			transition first anc accept PowerOff then off;
			transition first transparency accept PowerOff then off;
		}
	}

	part def SpeakerDriver {
		port signalIn : CombinedSignalInPort;
		port powerIn : PowerInPort;
	}

	part def LithiumIonBattery {
		port powerOut : PowerOutPort;
		attribute chargeLevel : Real;
	}

	part def EarCup {
		part feedforwardMic : FeedforwardMicrophone;
		part feedbackMic : FeedbackMicrophone;
		part speaker : SpeakerDriver;
	}

	part def Headphones {
		part leftEarCup : EarCup;
		part rightEarCup : EarCup;
		part bluetoothReceiver : BluetoothReceiver;
		part dsp : DigitalSignalProcessor;
		part battery : LithiumIonBattery;

		flow audioFlow of AudioStream
			from bluetoothReceiver.audioOut.audio to dsp.audioIn.audio;

		flow leftFeedforwardFlow of AmbientNoise
			from leftEarCup.feedforwardMic.noiseOut.noise to dsp.feedforwardIn.noise;
		flow rightFeedforwardFlow of AmbientNoise
			from rightEarCup.feedforwardMic.noiseOut.noise to dsp.feedforwardIn.noise;

		flow leftFeedbackFlow of LeakedNoise
			from leftEarCup.feedbackMic.noiseOut.noise to dsp.feedbackIn.noise;
		flow rightFeedbackFlow of LeakedNoise
			from rightEarCup.feedbackMic.noiseOut.noise to dsp.feedbackIn.noise;

		flow leftCombinedSignalFlow of CombinedAudioSignal
			from dsp.signalOut.signal to leftEarCup.speaker.signalIn.signal;
		flow rightCombinedSignalFlow of CombinedAudioSignal
			from dsp.signalOut.signal to rightEarCup.speaker.signalIn.signal;

		flow powerToReceiver of ElectricalPower
			from battery.powerOut.power to bluetoothReceiver.powerIn.power;
		flow powerToDSP of ElectricalPower
			from battery.powerOut.power to dsp.powerIn.power;
		flow powerToLeftFeedforward of ElectricalPower
			from battery.powerOut.power to leftEarCup.feedforwardMic.powerIn.power;
		flow powerToRightFeedforward of ElectricalPower
			from battery.powerOut.power to rightEarCup.feedforwardMic.powerIn.power;
		flow powerToLeftFeedback of ElectricalPower
			from battery.powerOut.power to leftEarCup.feedbackMic.powerIn.power;
		flow powerToRightFeedback of ElectricalPower
			from battery.powerOut.power to rightEarCup.feedbackMic.powerIn.power;
		flow powerToLeftSpeaker of ElectricalPower
			from battery.powerOut.power to leftEarCup.speaker.powerIn.power;
		flow powerToRightSpeaker of ElectricalPower
			from battery.powerOut.power to rightEarCup.speaker.powerIn.power;

		exhibit state headphoneStates {
			entry; then off;
			state off;
			transition first off accept PowerOn then idle;
			state idle;
			transition first idle accept ActivateANC then anc;
			transition first idle accept ActivateTransparency then transparency;
			state anc {
				entry; then ancNoMusic;
				state ancNoMusic;
				transition first ancNoMusic accept PlayMusic then ancWithMusic;
				state ancWithMusic;
				transition first ancWithMusic accept StopMusic then ancNoMusic;
			}
			state transparency;
			transition first anc accept DeactivateANC then idle;
			transition first transparency accept DeactivateTransparency then idle;
			transition first idle accept PowerOff then off;
			transition first anc accept PowerOff then off;
			transition first transparency accept PowerOff then off;
		}
	}

	part headphones : Headphones;

	requirement def ActiveNoiseCancellationRequirement {
		subject headphones : Headphones;
		doc /* The headphones shall actively eliminate ambient environmental noise using dual-microphone technology, achieving at least 20 dB of noise reduction across the 20 Hz to 1 kHz frequency range. */
	}

	requirement def DualMicrophoneRequirement {
		subject headphones : Headphones;
		doc /* The system shall utilize an external feedforward microphone and an internal feedback microphone for noise cancellation on each ear cup. */
	}

	requirement def DSPProcessingRequirement {
		subject headphones : Headphones;
		doc /* A central Digital Signal Processor shall analyze noise in real-time and generate an anti-noise signal that destructively interferes with ambient noise. */
	}

	requirement def PowerRequirement {
		subject headphones : Headphones;
		doc /* The active system shall be powered by an internal rechargeable Lithium-Ion battery providing at least 20 hours of playback with ANC enabled. */
	}

	requirement def OperatingModesRequirement {
		subject headphones : Headphones;
		doc /* The system shall support user-selectable operating modes: off, idle, active noise cancellation with or without music, and transparency mode. */
	}

	requirement def AudioQualityRequirement {
		subject headphones : Headphones;
		doc /* The speaker driver shall reproduce audio signals with a frequency response of 20 Hz to 20 kHz. */
	}

	requirement ancReq : ActiveNoiseCancellationRequirement {
		subject :>> headphones = headphones;
	}
	requirement dualMicReq : DualMicrophoneRequirement {
		subject :>> headphones = headphones;
	}
	requirement dspReq : DSPProcessingRequirement {
		subject :>> headphones = headphones;
	}
	requirement powerReq : PowerRequirement {
		subject :>> headphones = headphones;
	}
	requirement modesReq : OperatingModesRequirement {
		subject :>> headphones = headphones;
	}
	requirement audioReq : AudioQualityRequirement {
		subject :>> headphones = headphones;
	}
}
