package 'Particle Detector System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ParticleType {
		attribute name : String;
		attribute charge : ElectricChargeValue;
		attribute mass : MassValue;
	}
	
	attribute def DetectionEvent {
		attribute particleType : ParticleType;
		attribute energy : EnergyValue;
		attribute position : LengthValue[3];
		attribute timestamp : TimeValue;
	}
	
	attribute def TriggerSignal;
	attribute def CalibrationData;
	attribute def HighVoltage;
	
	item def ParticleBeam {
		attribute intensity : FrequencyValue;
		attribute particleTypes : ParticleType[*];
	}
	
	item def ScintillationLight {
		attribute photonCount : Integer;
		attribute wavelength : LengthValue;
	}
	
	item def ElectricalPulse {
		attribute amplitude : ElectricPotentialValue;
		attribute duration : TimeValue;
	}
	
	item def DigitalSignal {
		attribute value : Integer;
		attribute channelId : Integer;
	}
	
	item def ProcessedData {
		attribute events : DetectionEvent[*];
		attribute totalCount : Integer;
	}
	
	port def ParticleInputPort {
		in item particleBeam : ParticleBeam;
	}
	
	port def LightOutputPort {
		out item scintLight : ScintillationLight;
	}
	
	port def LightInputPort {
		in item scintLight : ScintillationLight;
	}
	
	port def PulseOutputPort {
		out item pulse : ElectricalPulse;
	}
	
	port def PulseInputPort {
		in item pulse : ElectricalPulse;
	}
	
	port def DigitalOutputPort {
		out item signal : DigitalSignal;
	}
	
	port def DigitalInputPort {
		in item signal : DigitalSignal;
	}
	
	port def DataOutputPort {
		out item data : ProcessedData;
	}
	
	port def PowerInputPort {
		in item power : HighVoltage;
	}
	
	part def Scintillator {
		doc /* Converts incident particle energy into visible light photons. */
		attribute material : String;
		attribute thickness : LengthValue;
		attribute lightYield : Real;
		port particleIn : ParticleInputPort;
		port lightOut : LightOutputPort;
	}
	
	part def PhotomultiplierTube {
		doc /* Converts light photons into amplified electrical pulses. */
		attribute gain : Real;
		attribute quantumEfficiency : Real;
		port lightIn : LightInputPort;
		port hvIn : PowerInputPort;
		port pulseOut : PulseOutputPort;
	}
	
	part def SignalAmplifier {
		doc /* Amplifies and shapes electrical pulses for digitization. */
		attribute amplificationFactor : Real;
		attribute shapingTime : TimeValue;
		port pulseIn : PulseInputPort;
		port pulseOut : PulseOutputPort;
	}
	
	part def AnalogToDigitalConverter {
		doc /* Converts analog pulses to digital signals. */
		attribute resolution : Integer;
		attribute samplingRate : FrequencyValue;
		port analogIn : PulseInputPort;
		port digitalOut : DigitalOutputPort;
	}
	
	part def DataAcquisitionSystem {
		doc /* Processes digital signals and reconstructs particle events. */
		attribute bufferSize : Integer;
		attribute processingRate : FrequencyValue;
		port digitalIn : DigitalInputPort;
		port dataOut : DataOutputPort;
	}
	
	part def HighVoltagePowerSupply {
		doc /* Provides stable high voltage for photomultiplier operation. */
		attribute outputVoltage : ElectricPotentialValue;
		attribute currentLimit : ElectricCurrentValue;
		port hvOut : PowerInputPort;
	}
	
	part def CalibrationSource {
		doc /* Provides known particle source for detector calibration. */
		attribute sourceType : String;
		attribute activity : FrequencyValue;
		port particleOut : ParticleInputPort;
	}
	
	action def ConvertParticleToLight {
		in particle : ParticleBeam;
		out light : ScintillationLight;
	}
	
	action def AmplifyLight {
		in light : ScintillationLight;
		in hvPower : HighVoltage;
		out pulse : ElectricalPulse;
	}
	
	action def ShapeSignal {
		in pulse : ElectricalPulse;
		out shapedPulse : ElectricalPulse;
	}
	
	action def Digitize {
		in pulse : ElectricalPulse;
		out signal : DigitalSignal;
	}
	
	action def ReconstructEvent {
		in signal : DigitalSignal;
		out event : DetectionEvent;
	}
	
	action def ProcessData {
		in signals : DigitalSignal[*];
		out data : ProcessedData;
	}
	
	action def CalibrateDetector {
		in calibData : CalibrationData;
		out calibrationFactors : Real[*];
	}
	
	requirement def <'REQ-001'> DetectionEfficiencyRequirement {
		doc /* The particle detector shall achieve detection efficiency 
		       of at least 95% for particles within the specified energy range. */
		subject detector : ParticleDetectorSystem;
		require constraint {
			detector.detectionEfficiency >= 0.95
		}
	}
	
	requirement def <'REQ-002'> EnergyResolutionRequirement {
		doc /* The detector shall provide energy resolution better than 
		       5% FWHM at 1 MeV. */
		subject detector : ParticleDetectorSystem;
		require constraint {
			detector.energyResolution <= 0.05
		}
	}
	
	requirement def <'REQ-003'> TimeResolutionRequirement {
		doc /* The detector shall achieve time resolution better than 
		       1 nanosecond for event timestamping. */
		subject detector : ParticleDetectorSystem;
		require constraint {
			detector.timeResolution <= 1.0e-9 [SI::s]
		}
	}
	
	requirement def <'REQ-004'> DataAcquisitionRateRequirement {
		doc /* The system shall support continuous data acquisition 
		       at rates up to 1 MHz. */
		subject daq : DataAcquisitionSystem;
		require constraint {
			daq.processingRate >= 1.0e6 [SI::Hz]
		}
	}
	
	requirement def <'REQ-005'> SystemReliabilityRequirement {
		doc /* The detector system shall maintain operational stability 
		       for continuous operation periods of at least 72 hours. */
		subject detector : ParticleDetectorSystem;
	}
	
	part def ParticleDetectorSystem {
		doc /* A system designed to detect and measure properties of ionizing particles 
		       by converting particle energy into measurable electrical signals through 
		       scintillation, photomultiplication, and digital signal processing. */
		
		attribute detectionEfficiency : Real;
		attribute energyResolution : Real;
		attribute timeResolution : TimeValue;
		attribute operationalStatus : String;
		
		port beamInput : ParticleInputPort;
		port dataOutput : DataOutputPort;
		
		part scintillator : Scintillator {
			attribute material = "NaI(Tl)";
			attribute thickness = 25.0 [SI::mm];
			attribute lightYield = 38000.0;
		}
		
		part pmt : PhotomultiplierTube {
			attribute gain = 1.0e6;
			attribute quantumEfficiency = 0.25;
		}
		
		part amplifier : SignalAmplifier {
			attribute amplificationFactor = 10.0;
			attribute shapingTime = 1.0e-6 [SI::s];
		}
		
		part adc : AnalogToDigitalConverter {
			attribute resolution = 14;
			attribute samplingRate = 100.0e6 [SI::Hz];
		}
		
		part daq : DataAcquisitionSystem {
			attribute bufferSize = 8192;
			attribute processingRate = 2.0e6 [SI::Hz];
		}
		
		part hvps : HighVoltagePowerSupply {
			attribute outputVoltage = 1200.0 [SI::V];
			attribute currentLimit = 0.001 [SI::A];
		}
		
		part calibSource : CalibrationSource {
			attribute sourceType = "Cs-137";
			attribute activity = 1.0e3 [SI::Hz];
		}
		
		connection beamInput to scintillator.particleIn;
		connection scintillator.lightOut to pmt.lightIn;
		connection hvps.hvOut to pmt.hvIn;
		connection pmt.pulseOut to amplifier.pulseIn;
		connection amplifier.pulseOut to adc.analogIn;
		connection adc.digitalOut to daq.digitalIn;
		connection daq.dataOut to dataOutput;
		
		perform action detectionSequence : DetectionSequence;
	}
	
	action def DetectionSequence {
		doc /* Primary functional sequence for detecting and processing particle events. */
		
		first start;
		then merge continuousDetection;
		
		then action initialize {
			action powerUp;
			then action calibrate : CalibrateDetector;
			then action setReady;
		}
		
		then action waitForParticle;
		
		then action convertToLight : ConvertParticleToLight;
		
		then action amplifyLight : AmplifyLight;
		
		then action shapeSignal : ShapeSignal;
		
		then action digitize : Digitize;
		
		then action reconstructEvent : ReconstructEvent;
		
		then decide;
			if true then continuousDetection;
			else shutdown;
		
		action shutdown {
			action saveData : ProcessData;
			then action powerDown;
		}
		
		then done;
	}
	
	part particleDetectorSystem : ParticleDetectorSystem {
		satisfy DetectionEfficiencyRequirement by self;
		satisfy EnergyResolutionRequirement by self;
		satisfy TimeResolutionRequirement by self;
		satisfy DataAcquisitionRateRequirement by daq;
		satisfy SystemReliabilityRequirement by self;
	}
}
