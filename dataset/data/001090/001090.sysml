package HydrophoneSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SoundPressureLevel :> Real;
	
	attribute def FrequencyRange {
		attribute lowerBound : ISQ::FrequencyValue;
		attribute upperBound : ISQ::FrequencyValue;
	}
	
	attribute def SensitivityValue :> Real;
	
	item def AcousticWave {
		attribute frequency : ISQ::FrequencyValue;
		attribute pressureLevel : SoundPressureLevel;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def ElectricalSignal {
		attribute voltage : ISQ::VoltageValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	item def DigitalAudioData {
		attribute sampleRate : ISQ::FrequencyValue;
		attribute bitDepth : ScalarValues::Integer;
		attribute samples : ScalarValues::Real[*];
	}
	
	port def AcousticInputPort {
		in item acousticInput : AcousticWave;
	}
	
	port def ElectricalSignalPort {
		out item electricalOutput : ElectricalSignal;
	}
	
	port def DigitalDataPort {
		out item digitalOutput : DigitalAudioData;
	}
	
	port def PowerPort {
		in item powerInput : ElectricalSignal;
	}
	
	part def PiezoelectricElement {
		attribute sensitivity : SensitivityValue;
		attribute frequencyRange : FrequencyRange;
		
		port acousticIn : AcousticInputPort;
		port electricalOut : ElectricalSignalPort;
		
		perform action convertAcousticToElectrical {
			in acoustic : AcousticWave;
			out electrical : ElectricalSignal;
		}
	}
	
	part def Preamplifier {
		attribute gain : ScalarValues::Real;
		attribute noiseLevel : SoundPressureLevel;
		
		port signalIn : ElectricalSignalPort;
		port signalOut : ElectricalSignalPort;
		port powerIn : PowerPort;
		
		perform action amplifySignal {
			in inputSignal : ElectricalSignal;
			out amplifiedSignal : ElectricalSignal;
		}
	}
	
	part def AnalogDigitalConverter {
		attribute samplingRate : ISQ::FrequencyValue;
		attribute resolution : ScalarValues::Integer;
		
		port analogIn : ElectricalSignalPort;
		port digitalOut : DigitalDataPort;
		port powerIn : PowerPort;
		
		perform action digitizeSignal {
			in analog : ElectricalSignal;
			out digital : DigitalAudioData;
		}
	}
	
	part def SignalProcessor {
		attribute filterType : ScalarValues::String;
		
		port dataIn : DigitalDataPort;
		port dataOut : DigitalDataPort;
		port powerIn : PowerPort;
		
		perform action processData {
			in rawData : DigitalAudioData;
			out processedData : DigitalAudioData;
		}
	}
	
	part def DataRecorder {
		attribute storageCapacity : ScalarValues::Real;
		
		port dataIn : DigitalDataPort;
		port powerIn : PowerPort;
		
		perform action recordData {
			in data : DigitalAudioData;
		}
	}
	
	part def WaterproofHousing {
		attribute material : ScalarValues::String;
		attribute depthRating : ISQ::PressureValue;
	}
	
	part def PowerSupply {
		attribute outputVoltage : ISQ::VoltageValue;
		attribute capacity : ScalarValues::Real;
		
		port powerOut : PowerPort;
	}
	
	item def ActivationSignal;
	item def RecordingComplete;
	item def DeactivationSignal;
	
	state def HydrophoneStates {
		entry; then standby;
		
		state standby {
			entry assign status := "Standby";
		}
		
		transition standby_to_active
			first standby
			accept ActivationSignal
			then active;
		
		state active {
			entry assign status := "Active";
			do action monitorAcoustic;
		}
		
		state detecting {
			entry assign status := "Detecting";
			do action captureSignal;
		}
		
		transition active_to_detecting
			first active
			if signalPresent
			then detecting;
		
		state recording {
			entry assign status := "Recording";
			do action saveData;
		}
		
		transition detecting_to_recording
			first detecting
			if recordingEnabled
			then recording;
		
		transition recording_to_active
			first recording
			accept RecordingComplete
			then active;
		
		transition active_to_standby
			first active
			accept DeactivationSignal
			then standby;
		
		attribute status : ScalarValues::String;
		attribute signalPresent : ScalarValues::Boolean;
		attribute recordingEnabled : ScalarValues::Boolean;
	}
	
	action def CaptureUnderwaterSound {
		in underwaterAcoustic : AcousticWave;
		out capturedData : DigitalAudioData;
		
		first start;
		
		then action receiveAcoustic {
			in acoustic : AcousticWave = underwaterAcoustic;
			out receivedWave : AcousticWave;
		}
		
		then action transduce {
			in wave : AcousticWave = receiveAcoustic.receivedWave;
			out electricalSignal : ElectricalSignal;
		}
		
		then action amplify {
			in signal : ElectricalSignal = transduce.electricalSignal;
			out amplifiedSignal : ElectricalSignal;
		}
		
		then action digitize {
			in analogSignal : ElectricalSignal = amplify.amplifiedSignal;
			out digitalData : DigitalAudioData;
		}
		
		then action filter {
			in rawData : DigitalAudioData = digitize.digitalData;
			out filteredData : DigitalAudioData;
		}
		
		then assign capturedData := filter.filteredData;
		then done;
	}
	
	part def HydrophoneSystem;
	
	part hydrophoneSystem : HydrophoneSystem {
		attribute operatingDepth : ISQ::LengthValue;
		attribute maxOperatingPressure : ISQ::PressureValue;
		
		port acousticInterface : AcousticInputPort;
		port dataInterface : DigitalDataPort;
		port powerInterface : PowerPort;
		
		part transducer : PiezoelectricElement {
			attribute :>> sensitivity = -170.0;
			attribute :>> frequencyRange = FrequencyRange {
				lowerBound = 10.0 [Hz];
				upperBound = 100000.0 [Hz];
			}
		}
		
		part preamp : Preamplifier {
			attribute :>> gain = 40.0;
			attribute :>> noiseLevel = 50.0;
		}
		
		part adc : AnalogDigitalConverter {
			attribute :>> samplingRate = 192000.0 [Hz];
			attribute :>> resolution = 24;
		}
		
		part processor : SignalProcessor {
			attribute :>> filterType = "Bandpass";
		}
		
		part recorder : DataRecorder {
			attribute :>> storageCapacity = 256.0;
		}
		
		part housing : WaterproofHousing {
			attribute :>> material = "Titanium";
			attribute :>> depthRating = 6000.0 [Pa];
		}
		
		part power : PowerSupply {
			attribute :>> outputVoltage = 12.0 [V];
			attribute :>> capacity = 5000.0;
		}
		
		connect transducer.acousticIn to acousticInterface;
		connect transducer.electricalOut to preamp.signalIn;
		connect preamp.signalOut to adc.analogIn;
		connect adc.digitalOut to processor.dataIn;
		connect processor.dataOut to recorder.dataIn;
		connect processor.dataOut to dataInterface;
		
		connect power.powerOut to preamp.powerIn;
		connect power.powerOut to adc.powerIn;
		connect power.powerOut to processor.powerIn;
		connect power.powerOut to recorder.powerIn;
		connect power.powerOut to powerInterface;
		
		perform action captureSound : CaptureUnderwaterSound;
		
		exhibit state operatingState : HydrophoneStates;
	}
	
	requirement def <'REQ-001'> AcousticDetectionRequirement {
		doc /* The hydrophone system shall detect underwater acoustic signals 
		     and convert them into digital audio data for analysis. */
		
		subject system : HydrophoneSystem;
		
		require constraint frequencyRangeConstraint {
			doc /* The system shall operate across a wide frequency range. */
			system.transducer.frequencyRange.lowerBound <= 20.0 [Hz] and
			system.transducer.frequencyRange.upperBound >= 80000.0 [Hz]
		}
		
		require constraint sensitivityConstraint {
			doc /* The transducer sensitivity shall enable detection of low-level signals. */
			system.transducer.sensitivity <= -165.0
		}
	}
	
	requirement def <'REQ-002'> SignalProcessingRequirement {
		doc /* The system shall process acoustic signals with high fidelity. */
		
		subject system : HydrophoneSystem;
		
		require constraint samplingRateConstraint {
			doc /* ADC sampling rate shall support high-frequency detection. */
			system.adc.samplingRate >= 96000.0 [Hz]
		}
		
		require constraint resolutionConstraint {
			doc /* ADC resolution shall provide adequate dynamic range. */
			system.adc.resolution >= 16
		}
	}
	
	requirement def <'REQ-003'> EnvironmentalRequirement {
		doc /* The system shall operate reliably in underwater environments. */
		
		subject system : HydrophoneSystem;
		
		require constraint depthRatingConstraint {
			doc /* Housing shall withstand deep underwater pressures. */
			system.housing.depthRating >= 5000.0 [Pa]
		}
	}
	
	requirement <'SYS-001'> systemRequirements {
		doc /* Top-level requirements for the hydrophone system. */
		
		subject mainSystem : HydrophoneSystem;
		
		require acousticDetection : AcousticDetectionRequirement;
		require signalProcessing : SignalProcessingRequirement;
		require environmental : EnvironmentalRequirement;
	}
}
