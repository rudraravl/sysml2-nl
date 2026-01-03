package 'Daly Detector System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ParticleCount :> Real;
	attribute def DetectionEfficiency :> Real;
	
	attribute def Voltage :> ISQ::voltage {
		attribute magnitude : Real;
	}
	
	attribute def Current :> ISQ::electricCurrent {
		attribute magnitude : Real;
	}
	
	attribute def Gain :> Real;
	
	enum def OperationalMode {
		enum idle;
		enum active;
		enum calibration;
		enum fault;
	}
	
	item def Ion {
		attribute kineticEnergy : ISQ::energy;
		attribute mass : ISQ::mass;
		attribute charge : ISQ::electricCharge;
	}
	
	item def ElectronBurst {
		attribute electronCount : ParticleCount;
		attribute energy : ISQ::energy;
	}
	
	item def PhotonBurst {
		attribute photonCount : ParticleCount;
		attribute wavelength : ISQ::length;
	}
	
	item def ElectricalPulse {
		attribute amplitude : Voltage;
		attribute duration : ISQ::time;
		attribute riseTime : ISQ::time;
	}
	
	port def IonInputPort {
		in item ionStream : Ion;
	}
	
	port def SignalOutputPort {
		out item pulseStream : ElectricalPulse;
	}
	
	port def HighVoltagePort {
		in attribute hvBias : Voltage;
	}
	
	port def ControlPort {
		in attribute modeCommand : OperationalMode;
		out attribute statusReport : OperationalMode;
	}
	
	action def ConvertIonToElectrons {
		in ion : Ion;
		in dynodeVoltage : Voltage;
		out electrons : ElectronBurst;
	}
	
	action def GeneratePhotons {
		in electrons : ElectronBurst;
		out photons : PhotonBurst;
	}
	
	action def AmplifySignal {
		in photons : PhotonBurst;
		in pmtVoltage : Voltage;
		out pulse : ElectricalPulse;
	}
	
	action def ProcessPulse {
		in rawPulse : ElectricalPulse;
		out conditionedPulse : ElectricalPulse;
		out detectionCount : ParticleCount;
	}
	
	action def DetectIon {
		in inputIon : Ion;
		in dynodeBias : Voltage;
		in pmtBias : Voltage;
		out outputPulse : ElectricalPulse;
		out particleDetected : ParticleCount;
		
		first start;
		
		then action convertStep : ConvertIonToElectrons {
			in ion = inputIon;
			in dynodeVoltage = dynodeBias;
			out electrons;
		}
		
		flow convertStep.electrons to scintillateStep.electrons;
		
		action scintillateStep : GeneratePhotons {
			in electrons : ElectronBurst;
			out photons;
		}
		
		flow scintillateStep.photons to amplifyStep.photons;
		
		action amplifyStep : AmplifySignal {
			in photons : PhotonBurst;
			in pmtVoltage = pmtBias;
			out pulse;
		}
		
		then action processStep : ProcessPulse {
			in rawPulse = amplifyStep.pulse;
			out conditionedPulse;
			out detectionCount;
		}
		
		then assign outputPulse := processStep.conditionedPulse;
		then assign particleDetected := processStep.detectionCount;
		then done;
	}
	
	state def DetectorStateMachine {
		entry; then idle;
		
		state idle;
		state active;
		state calibrating;
		state fault;
		
		transition powerOn
			first idle
			accept at powerOn
			then active;
		
		transition startCalibration
			first idle
			accept at startCalibration
			then calibrating;
		
		transition calibrationComplete
			first calibrating
			accept at calibrationComplete
			then active;
		
		transition detectFault
			first active
			accept at detectFault
			then fault;
		
		transition recover
			first fault
			accept at recover
			then idle;
		
		transition shutdown
			first active
			accept at shutdown
			then idle;
	}
	
	part def ConversionDynode {
		doc /* High-voltage electrode that converts incident ions into secondary electrons */
		
		attribute operatingVoltage : Voltage;
		attribute conversionEfficiency : DetectionEfficiency;
		
		port ionIn : IonInputPort;
		port electronOut;
		port hvSupply : HighVoltagePort;
		
		perform action convert : ConvertIonToElectrons {
			in ion = ionIn.ionStream;
			in dynodeVoltage = hvSupply.hvBias;
			out electrons;
		}
	}
	
	part def Scintillator {
		doc /* Phosphor screen that converts electrons into photons */
		
		attribute scintillationYield : Real;
		attribute decayTime : ISQ::time;
		
		port electronIn;
		port photonOut;
		
		perform action scintillate : GeneratePhotons {
			in electrons;
			out photons;
		}
	}
	
	part def Photomultiplier {
		doc /* Photomultiplier tube that amplifies photon signal to measurable electrical pulse */
		
		attribute gain : Gain;
		attribute operatingVoltage : Voltage;
		attribute quantumEfficiency : DetectionEfficiency;
		
		port photonIn;
		port pulseOut;
		port hvSupply : HighVoltagePort;
		
		perform action amplify : AmplifySignal {
			in photons;
			in pmtVoltage = hvSupply.hvBias;
			out pulse;
		}
	}
	
	part def SignalProcessor {
		doc /* Electronics for pulse shaping, discrimination, and counting */
		
		attribute threshold : Voltage;
		attribute processingMode : OperationalMode;
		
		port pulseIn;
		port dataOut : SignalOutputPort;
		
		perform action process : ProcessPulse {
			in rawPulse;
			out conditionedPulse;
			out detectionCount;
		}
	}
	
	part def HighVoltageSupply {
		doc /* Provides stable high voltage bias for dynode and photomultiplier */
		
		attribute dynodeSetpoint : Voltage;
		attribute pmtSetpoint : Voltage;
		attribute voltageStability : Real;
		
		port dynodeOutput : HighVoltagePort;
		port pmtOutput : HighVoltagePort;
	}
	
	part def VacuumChamber {
		doc /* Maintains vacuum environment for detector operation */
		
		attribute pressure : ISQ::pressure;
		attribute volume : ISQ::volume;
	}
	
	part def DalyDetector {
		doc /* 
			Complete Daly detector assembly for high-sensitivity ion detection.
			Converts incident ions into amplified electrical pulses through
			secondary electron emission, scintillation, and photomultiplication.
		*/
		
		attribute systemGain : Gain;
		attribute detectionEfficiency : DetectionEfficiency;
		attribute backgroundNoise : Current;
		
		port ionInput : IonInputPort;
		port signalOutput : SignalOutputPort;
		port control : ControlPort;
		
		part dynode : ConversionDynode {
			attribute :>> operatingVoltage {
				attribute :>> magnitude = -20000.0;
			}
			attribute :>> conversionEfficiency = 0.95;
		}
		
		part scintillator : Scintillator {
			attribute :>> scintillationYield = 10000.0;
		}
		
		part pmt : Photomultiplier {
			attribute :>> gain = 1.0e6;
			attribute :>> quantumEfficiency = 0.25;
		}
		
		part processor : SignalProcessor {
			attribute :>> processingMode = OperationalMode::active;
		}
		
		part hvSupply : HighVoltageSupply {
			attribute :>> voltageStability = 0.001;
		}
		
		part vacuum : VacuumChamber;
		
		connection ionToDynode : FlowConnection connect 
			ionInput to dynode.ionIn;
		
		connection dynodeToScintillator : FlowConnection connect 
			dynode.electronOut to scintillator.electronIn;
		
		connection scintillatorToPMT : FlowConnection connect 
			scintillator.photonOut to pmt.photonIn;
		
		connection pmtToProcessor : FlowConnection connect 
			pmt.pulseOut to processor.pulseIn;
		
		connection processorToOutput : FlowConnection connect 
			processor.dataOut to signalOutput;
		
		connection hvToDynode : FlowConnection connect 
			hvSupply.dynodeOutput to dynode.hvSupply;
		
		connection hvToPMT : FlowConnection connect 
			hvSupply.pmtOutput to pmt.hvSupply;
		
		perform action detectOperation : DetectIon {
			in inputIon = ionInput.ionStream;
			in dynodeBias = hvSupply.dynodeSetpoint;
			in pmtBias = hvSupply.pmtSetpoint;
			out outputPulse;
			out particleDetected;
		}
		
		exhibit state lifecycle : DetectorStateMachine;
	}
	
	requirement <'DALY-REQ-001'> primaryFunction {
		doc /* 
			The Daly detector system shall convert incident ions into 
			amplified electrical pulses for particle detection and counting 
			with high sensitivity and low background noise.
		*/
		
		subject dalySystem : DalyDetector;
		
		require constraint {
			dalySystem.systemGain >= 1.0e5
		}
		
		require constraint {
			dalySystem.detectionEfficiency >= 0.90
		}
	}
	
	requirement <'DALY-REQ-002'> operationalPerformance {
		doc /* 
			The detector shall maintain stable operation with background 
			noise below 0.1 counts per second and detection efficiency 
			above 90% for ions with kinetic energy greater than 5 keV.
		*/
		
		subject dalySystem : DalyDetector;
	}
	
	requirement <'DALY-REQ-003'> voltageStability {
		doc /* 
			The high voltage supply shall maintain voltage stability 
			better than 0.1% to ensure consistent detector performance.
		*/
		
		subject dalySystem : DalyDetector;
		
		require constraint {
			dalySystem.hvSupply.voltageStability <= 0.001
		}
	}
	
	part dalyDetectorSystem : DalyDetector {
		doc /* 
			Instantiated Daly detector system configured for 
			high-sensitivity ion detection in mass spectrometry applications.
		*/
		
		attribute :>> systemGain = 1.0e6;
		attribute :>> detectionEfficiency = 0.95;
		
		satisfy primaryFunction;
		satisfy operationalPerformance;
		satisfy voltageStability;
	}
}
