package CochlearImplantSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		attribute def SoundDetected;
		attribute def SilenceDetected;
		attribute def Exit;

		item def Sound {
			attribute frequency : FrequencyValue;
			attribute intensity : PressureValue;
			attribute timestamp : TimeValue;
		}

		item def EncodedStimulusPattern {
			attribute channelCount : Integer;
			attribute pulseRate : FrequencyValue;
			attribute amplitude : ElectricCurrentValue;
			attribute pulseDuration : TimeValue;
		}

		item def WirelessSignal {
			attribute carrierFrequency : FrequencyValue;
			item payload : EncodedStimulusPattern;
		}

		item def ElectrodeStimulus {
			attribute electrodeNumber : Integer;
			attribute currentAmplitude : ElectricCurrentValue;
			attribute pulseWidth : TimeValue;
		}

		port def SoundOutPort {
			out item sound : Sound;
		}

		port def SoundInPort {
			in item sound : Sound;
		}

		port def EncodedOutPort {
			out item pattern : EncodedStimulusPattern;
		}

		port def EncodedInPort {
			in item pattern : EncodedStimulusPattern;
		}

		port def WirelessTxPort {
			out item signal : WirelessSignal;
		}

		port def WirelessRxPort {
			in item signal : WirelessSignal;
		}

		port def StimulusOutPort {
			out item pulse : ElectrodeStimulus;
		}

		port def StimulusInPort {
			in item pulse : ElectrodeStimulus;
		}

		action def CaptureAmbientSound {
			out sound : Sound;
		}

		action def AnalyzeAndEncode {
			in sound : Sound;
			out pattern : EncodedStimulusPattern;
		}

		action def ModulateAndTransmit {
			in pattern : EncodedStimulusPattern;
			out signal : WirelessSignal;
		}

		action def DemodulateAndForward {
			in signal : WirelessSignal;
			out pattern : EncodedStimulusPattern;
		}

		action def DecodeAndGeneratePulses {
			in pattern : EncodedStimulusPattern;
			out pulse : ElectrodeStimulus;
		}

		action def DeliverToNerve {
			in pulse : ElectrodeStimulus;
		}

		action def MonitorSoundLevel {
			out level : PressureValue;
		}

		part def Microphone {
			port soundOut : SoundOutPort;
			perform action capture : CaptureAmbientSound {
				out sound = soundOut.sound;
			}
		}

		part def SpeechProcessor {
			port soundIn : SoundInPort;
			port encodedOut : EncodedOutPort;
			perform action analyze : AnalyzeAndEncode {
				in sound = soundIn.sound;
				out pattern = encodedOut.pattern;
			}
		}

		part def ExternalTransmitter {
			port encodedIn : EncodedInPort;
			port wirelessOut : WirelessTxPort;
			perform action transmit : ModulateAndTransmit {
				in pattern = encodedIn.pattern;
				out signal = wirelessOut.signal;
			}
		}

		part def InternalReceiver {
			port wirelessIn : WirelessRxPort;
			port encodedOut : EncodedOutPort;
			perform action receive : DemodulateAndForward {
				in signal = wirelessIn.signal;
				out pattern = encodedOut.pattern;
			}
		}

		part def CurrentStimulator {
			port encodedIn : EncodedInPort;
			port stimulusOut : StimulusOutPort;
			perform action generate : DecodeAndGeneratePulses {
				in pattern = encodedIn.pattern;
				out pulse = stimulusOut.pulse;
			}
		}

		part def ElectrodeArray {
			port stimulusIn : StimulusInPort;
			attribute numberOfContacts : Integer = 22;
			perform action deliver : DeliverToNerve {
				in pulse = stimulusIn.pulse;
			}
		}

		part def ExternalUnit {
			port wirelessOut : WirelessTxPort;

			part microphone : Microphone;
			part speechProcessor : SpeechProcessor;
			part transmitter : ExternalTransmitter;

			flow of sound : Sound
				from microphone.soundOut.sound to speechProcessor.soundIn.sound;
			flow of pattern : EncodedStimulusPattern
				from speechProcessor.encodedOut.pattern to transmitter.encodedIn.pattern;
			flow of signal : WirelessSignal
				from transmitter.wirelessOut.signal to wirelessOut.signal;
		}

		part def InternalUnit {
			port wirelessIn : WirelessRxPort;

			part receiver : InternalReceiver;
			part stimulator : CurrentStimulator;
			part electrodeArray : ElectrodeArray;

			flow of signal : WirelessSignal
				from wirelessIn.signal to receiver.wirelessIn.signal;
			flow of pattern : EncodedStimulusPattern
				from receiver.encodedOut.pattern to stimulator.encodedIn.pattern;
			flow of pulse : ElectrodeStimulus
				from stimulator.stimulusOut.pulse to electrodeArray.stimulusIn.pulse;
		}

		state def ExternalUnitStates {
			attribute soundThreshold : PressureValue = 30.0;
			attribute currentLevel : PressureValue;

			entry; then Standby;

			state Standby {
				do action MonitorSoundLevel;
			}

			transition StandbyToActive
				first Standby
				accept detected : SoundDetected
				if currentLevel > soundThreshold
				then Active;

			state Active {
				entry action CaptureAmbientSound;
				state Capturing {
					do action CaptureAmbientSound;
				}
				transition first Capturing then Processing;
				state Processing {
					do action AnalyzeAndEncode;
				}
				transition first Processing then Transmitting;
				state Transmitting {
					do action ModulateAndTransmit;
				}
				transition first Transmitting then Capturing;
			}

			transition ActiveToStandby
				first Active
				accept silence : SilenceDetected
				if currentLevel <= soundThreshold
				then Standby;

			transition ExitFromStandby
				first Standby
				accept exitSignal : Exit
				then done;

			transition ExitFromActive
				first Active
				accept exitSignal : Exit
				then done;
		}

		state def InternalUnitStates {
			entry; then Receiving;

			state Receiving;

			transition ReceivingToStimulating
				first Receiving
				accept signal : WirelessSignal
				do action DemodulateAndForward
				then Stimulating;

			state Stimulating {
				entry action DecodeAndGeneratePulses;
				exit action DeliverToNerve;
			}

			transition StimulatingToReceiving
				first Stimulating
				then Receiving;

			transition ExitFromReceiving
				first Receiving
				accept exitSignal : Exit
				then done;

			transition ExitFromStimulating
				first Stimulating
				accept exitSignal : Exit
				then done;
		}

		requirement def HearingRestorationRequirement {
			doc /* The system shall restore functional hearing by bypassing damaged inner ear structures and directly stimulating the auditory nerve with electrical signals representing environmental sounds. */
		}

		requirement def SoundProcessingRequirement {
			doc /* The speech processor shall analyze ambient sound, filter it, and convert it into an encoded stimulus pattern representing different frequencies and intensities. */
		}

		requirement def WirelessTransmissionRequirement {
			doc /* The external transmitter shall wirelessly transmit encoded stimulus patterns through the skin to the internal receiver. */
		}

		requirement def ElectricalStimulationRequirement {
			doc /* The current stimulator shall generate precise, low-level electrical pulses based on the decoded stimulus pattern, with amplitudes between 0.1 mA and 1.75 mA. */
		}

		requirement def PowerSavingRequirement {
			doc /* The system shall enter a power-saving standby mode when no sound is detected above a predefined threshold. */
		}

		requirement def RealTimePerceptionRequirement {
			doc /* The system shall continuously cycle through capturing, processing, and stimulating to provide real-time perception of sound. */
		}
	}

	package Usages {
		private import Definitions::*;

		part cochlearImplantSystem {
			part externalUnit : ExternalUnit;
			part internalUnit : InternalUnit;

			flow of signal : WirelessSignal
				from externalUnit.wirelessOut.signal
				to internalUnit.wirelessIn.signal;

			exhibit state externalStates : ExternalUnitStates;
			exhibit state internalStates : InternalUnitStates;

			satisfy HearingRestorationRequirement;
			satisfy SoundProcessingRequirement;
			satisfy WirelessTransmissionRequirement;
			satisfy ElectricalStimulationRequirement;
			satisfy PowerSavingRequirement;
			satisfy RealTimePerceptionRequirement;
		}
	}
}
