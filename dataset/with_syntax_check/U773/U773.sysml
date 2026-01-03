package MicrophoneSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SoundPressureLevel :> ScalarValues::Real;
	attribute def SignalToNoiseRatio :> ScalarValues::Real;
	
	item def AcousticWave {
		attribute soundPressure :> ISQ::pressure;
		attribute frequency :> ISQ::frequency;
		attribute amplitude :> ScalarValues::Real;
	}
	
	item def ElectricalSignal {
		attribute voltage :> ISQ::voltage;
		attribute currentValue :> ISQ::electricCurrent;
		attribute frequency :> ISQ::frequency;
		attribute amplitude :> ScalarValues::Real;
	}
	
	item def DigitalAudioData {
		attribute sampleRate :> ISQ::frequency;
		attribute bitDepth : ScalarValues::Integer;
		attribute samples : ScalarValues::Real[*];
	}
	
	port def AcousticInputPort {
		in acousticWave : AcousticWave;
	}
	
	port def AnalogOutputPort {
		out electricalSignal : ElectricalSignal;
	}
	
	port def DigitalOutputPort {
		out digitalData : DigitalAudioData;
	}
	
	action def VibrateMemebrane {
		in acousticInput : AcousticWave;
		out mechanicalDisplacement :> ISQ::length;
	}
	
	action def TransduceToElectrical {
		in displacement :> ISQ::length;
		out rawSignal : ElectricalSignal;
	}
	
	action def AmplifySignal {
		in inputSignal : ElectricalSignal;
		in gainFactor : ScalarValues::Real;
		out amplifiedSignal : ElectricalSignal;
	}
	
	action def FilterSignal {
		in inputSignal : ElectricalSignal;
		in cutoffFrequency :> ISQ::frequency;
		out filteredSignal : ElectricalSignal;
	}
	
	action def ConvertToDigital {
		in analogSignal : ElectricalSignal;
		in sampleRate :> ISQ::frequency;
		in bitDepth : ScalarValues::Integer;
		out digitalOutput : DigitalAudioData;
	}
	
	action def CaptureAudio {
		in environmentalSound : AcousticWave;
		out processedAudio : DigitalAudioData;
		
		first start;
		then action vibrate : VibrateMemebrane {
			in acousticInput = environmentalSound;
			out mechanicalDisplacement;
		}
		then action transduce : TransduceToElectrical {
			in displacement = vibrate.mechanicalDisplacement;
			out rawSignal;
		}
		then action amplify : AmplifySignal {
			in inputSignal = transduce.rawSignal;
			in gainFactor = 40.0;
			out amplifiedSignal;
		}
		then action filterAction : FilterSignal {
			in inputSignal = amplify.amplifiedSignal;
			in cutoffFrequency = 20000.0 [SI::Hz];
			out filteredSignal;
		}
		then action digitize : ConvertToDigital {
			in analogSignal = filterAction.filteredSignal;
			in sampleRate = 48000.0 [SI::Hz];
			in bitDepth = 24;
			out digitalOutput;
		}
		then done;
	}
	
	state def MicrophoneOperatingState {
		entry; then idle;
		
		state idle;
		
		transition idle_to_active
			first idle
			accept acousticWave : AcousticWave
			then active;
		
		state active {
			entry action beginCapture;
			do action continuousCapture;
		}
		
		transition active_to_processing
			first active
			if continuousCapture.signalDetected
			then processing;
		
		state processing {
			do action performProcessing;
		}
		
		transition processing_to_outputting
			first processing
			then outputting;
		
		state outputting {
			do action deliverOutput;
		}
		
		transition outputting_to_idle
			first outputting
			then idle;
		
		action beginCapture;
		action continuousCapture {
			out signalDetected : ScalarValues::Boolean;
		}
		action performProcessing;
		action deliverOutput;
	}
	
	part def DiaphragmAssembly {
		attribute mass :> ISQ::mass;
		attribute tension :> ISQ::force;
		attribute naturalFrequency :> ISQ::frequency;
		
		port acousticIn : AcousticInputPort;
		
		perform action vibrate : VibrateMemebrane;
	}
	
	part def TransducerElement {
		attribute sensitivity : ScalarValues::Real;
		attribute impedance :> ISQ::electricalResistance;
		attribute polarizationVoltage :> ISQ::voltage;
		
		perform action transduce : TransduceToElectrical;
	}
	
	part def PreamplifierCircuit {
		attribute gain : ScalarValues::Real;
		attribute inputImpedance :> ISQ::electricalResistance;
		attribute outputImpedance :> ISQ::electricalResistance;
		attribute noiseFloor :> ISQ::voltage;
		
		port analogIn :> ~AnalogOutputPort;
		port analogOut : AnalogOutputPort;
		
		perform action amplify : AmplifySignal;
	}
	
	part def SignalConditioner {
		attribute highPassCutoff :> ISQ::frequency;
		attribute lowPassCutoff :> ISQ::frequency;
		
		port signalIn :> ~AnalogOutputPort;
		port signalOut : AnalogOutputPort;
		
		perform action filterAction : FilterSignal;
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution : ScalarValues::Integer;
		attribute samplingRate :> ISQ::frequency;
		attribute dynamicRange : ScalarValues::Real;
		
		port analogIn :> ~AnalogOutputPort;
		port digitalOut : DigitalOutputPort;
		
		perform action digitize : ConvertToDigital;
	}
	
	requirement def FrequencyResponseRequirement {
		doc /* The microphone shall capture audio across the specified frequency range. */
		
		attribute minFrequency :> ISQ::frequency;
		attribute maxFrequency :> ISQ::frequency;
		
		require constraint {
			minFrequency == 20.0 [SI::Hz] and
			maxFrequency == 20000.0 [SI::Hz]
		}
	}
	
	requirement def SensitivityRequirement {
		doc /* The microphone shall maintain minimum sensitivity level. */
		
		attribute minimumSensitivity : SoundPressureLevel;
		
		require constraint {
			minimumSensitivity >= -38.0
		}
	}
	
	requirement def SignalQualityRequirement {
		doc /* The output signal shall meet minimum quality standards. */
		
		attribute minimumSNR : SignalToNoiseRatio;
		attribute maximumTHD : ScalarValues::Real;
		
		require constraint {
			minimumSNR >= 70.0 and
			maximumTHD <= 0.005
		}
	}
	
	requirement def AudioCaptureRequirement {
		doc /* The microphone system shall convert acoustic sound waves into digital audio data. */
		
		subject mic : Microphone;
		
		require frequencyResponse : FrequencyResponseRequirement;
		require sensitivity : SensitivityRequirement;
		require signalQuality : SignalQualityRequirement;
	}
	
	part def Microphone {
		doc /* 
			A microphone system that converts acoustic sound waves into 
			digital audio data through mechanical vibration, electrical 
			transduction, amplification, filtering, and analog-to-digital conversion.
		*/
		
		attribute operatingVoltage :> ISQ::voltage;
		attribute powerConsumption :> ISQ::power;
		attribute maxSPL : SoundPressureLevel;
		
		port acousticInput : AcousticInputPort;
		port digitalOutput : DigitalOutputPort;
		
		part diaphragm : DiaphragmAssembly {
			:>> mass = 0.00015 [SI::kg];
			:>> tension = 0.8 [SI::N];
			:>> naturalFrequency = 10000.0 [SI::Hz];
			
			port :>> acousticIn connect acousticInput;
		}
		
		part transducer : TransducerElement {
			:>> sensitivity = 0.92;
			:>> impedance = 150.0 [SI::'Ω'];
			:>> polarizationVoltage = 48.0 [SI::V];
		}
		
		part preamp : PreamplifierCircuit {
			:>> gain = 40.0;
			:>> inputImpedance = 10000.0 [SI::'Ω'];
			:>> outputImpedance = 200.0 [SI::'Ω'];
			:>> noiseFloor = 0.000001 [SI::V];
		}
		
		part conditioner : SignalConditioner {
			:>> highPassCutoff = 20.0 [SI::Hz];
			:>> lowPassCutoff = 20000.0 [SI::Hz];
		}
		
		part adc : AnalogToDigitalConverter {
			:>> resolution = 24;
			:>> samplingRate = 48000.0 [SI::Hz];
			:>> dynamicRange = 120.0;
			
			port :>> digitalOut connect digitalOutput;
		}
		
		connect diaphragm to transducer;
		connect transducer to preamp.analogIn;
		connect preamp.analogOut to conditioner.signalIn;
		connect conditioner.signalOut to adc.analogIn;
		
		perform action capture : CaptureAudio;
		
		exhibit state operatingState : MicrophoneOperatingState;
		
		satisfy audioCaptureReq : AudioCaptureRequirement {
			subject mic = Microphone::microphoneInstance;
		}
	}
	
	part microphoneInstance : Microphone {
		:>> operatingVoltage = 48.0 [SI::V];
		:>> powerConsumption = 2.5 [SI::W];
		:>> maxSPL = 130.0;
	}
}
