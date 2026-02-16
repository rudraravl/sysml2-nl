package 'Scintillation Counter System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PhotonCount :> ScalarValues::Natural;
	attribute def ElectronCount :> ScalarValues::Natural;
	attribute def PulseCount :> ScalarValues::Natural;
	
	item def IonizingParticle {
		attribute particleEnergy : ISQ::EnergyValue;
		attribute particleType : String;
	}
	
	item def ScintillationPhoton {
		attribute wavelength : ISQ::LengthValue;
		attribute emissionTime : ISQ::TimeValue;
	}
	
	item def ElectronPulse {
		attribute chargeCarriers : ElectronCount;
		attribute pulseTime : ISQ::TimeValue;
	}
	
	item def ElectricalSignal {
		attribute amplitude : ISQ::VoltageValue;
		attribute duration : ISQ::TimeValue;
	}
	
	item def CountData {
		attribute totalCounts : PulseCount;
		attribute countRate : ISQ::FrequencyValue;
		attribute timestamp : ISQ::TimeValue;
	}
	
	port def RadiationInputPort {
		in item radiation : IonizingParticle;
	}
	
	port def PhotonOutputPort {
		out item photons : ScintillationPhoton[*];
	}
	
	port def PhotonInputPort {
		in item photons : ScintillationPhoton[*];
	}
	
	port def ElectronOutputPort {
		out item electrons : ElectronPulse;
	}
	
	port def SignalOutputPort {
		out item signal : ElectricalSignal;
	}
	
	port def SignalInputPort {
		in item signal : ElectricalSignal;
	}
	
	port def DataOutputPort {
		out item data : CountData;
	}
	
	port def HighVoltagePort {
		in attribute voltage : ISQ::VoltageValue;
	}
	
	part def ScintillatorCrystal {
		doc /* Converts ionizing radiation into visible light photons through scintillation process. */
		
		attribute material : String;
		attribute lightYield : PhotonCount;
		attribute decayTime : ISQ::TimeValue;
		
		port radiationIn : RadiationInputPort;
		port photonOut : PhotonOutputPort;
		
		action scintillate {
			in item incidentParticle : IonizingParticle;
			out item emittedPhotons : ScintillationPhoton[*];
			
			first start;
			then action absorbRadiation {
				in item particle = incidentParticle;
			}
			then action exciteCrystalLattice;
			then action emitScintillationLight {
				out item photons = emittedPhotons;
			}
			then done;
		}
	}
	
	part def PhotomultiplierTube {
		doc /* Converts photons to electrons and amplifies the signal through dynode multiplication. */
		
		attribute gainFactor : Real;
		attribute quantumEfficiency : Real;
		attribute numberOfDynodes : Integer;
		
		port photonIn : PhotonInputPort;
		port hvIn : HighVoltagePort;
		port electronOut : ElectronOutputPort;
		
		action convertAndAmplify {
			in item inputPhotons : ScintillationPhoton[*];
			in attribute appliedVoltage : ISQ::VoltageValue;
			out item amplifiedElectrons : ElectronPulse;
			
			first start;
			then action photocathodeConversion {
				in item photons = inputPhotons;
				out attribute primaryElectrons : ElectronCount;
			}
			then action dynodeMultiplication {
				in attribute electrons = photocathodeConversion.primaryElectrons;
				in attribute voltage = appliedVoltage;
				out attribute multipliedElectrons : ElectronCount;
			}
			then action anodeCollection {
				in attribute electrons = dynodeMultiplication.multipliedElectrons;
				out item pulse = amplifiedElectrons;
			}
			then done;
		}
	}
	
	part def PreAmplifier {
		doc /* Amplifies weak signals from PMT to usable voltage levels. */
		
		attribute amplificationGain : Real;
		attribute inputImpedance : Real;
		
		port signalIn : SignalInputPort;
		port signalOut : SignalOutputPort;
		
		action amplifySignal {
			in item inputSignal : ElectricalSignal;
			out item outputSignal : ElectricalSignal;
			
			first start;
			then action impedanceMatch;
			then action applyGain {
				in item signal = inputSignal;
				out item amplified = outputSignal;
			}
			then done;
		}
	}
	
	part def PulseShaper {
		doc /* Shapes and filters pulses for optimal discrimination. */
		
		attribute shapingTime : ISQ::TimeValue;
		attribute filterType : String;
		
		port signalIn : SignalInputPort;
		port signalOut : SignalOutputPort;
		
		action shapePulse {
			in item rawSignal : ElectricalSignal;
			out item shapedSignal : ElectricalSignal;
			
			first start;
			then action filterNoise;
			then action optimizeRiseTime {
				in item signal = rawSignal;
				out item shaped = shapedSignal;
			}
			then done;
		}
	}
	
	part def Discriminator {
		doc /* Rejects pulses below threshold and converts analog to digital. */
		
		attribute threshold : ISQ::VoltageValue;
		attribute deadTime : ISQ::TimeValue;
		
		port signalIn : SignalInputPort;
		port pulseOut {
			out attribute validPulse : Boolean;
		}
		
		action discriminate {
			in item inputSignal : ElectricalSignal;
			in attribute thresholdLevel : ISQ::VoltageValue;
			out attribute accepted : Boolean;
			
			first start;
			then decide;
				if inputSignal.amplitude >= thresholdLevel then acceptPulse;
				if inputSignal.amplitude < thresholdLevel then rejectPulse;
			
			action acceptPulse {
				then assign accepted := true;
			}
			then done;
			
			action rejectPulse {
				then assign accepted := false;
			}
			then done;
		}
	}
	
	part def Counter {
		doc /* Counts valid pulses and calculates count rate. */
		
		attribute accumulatedCounts : PulseCount := 0;
		attribute measurementWindow : ISQ::TimeValue;
		
		port pulseIn {
			in attribute validPulse : Boolean;
		}
		port dataOut : DataOutputPort;
		
		action countPulses {
			in attribute pulseValid : Boolean;
			in attribute gateTime : ISQ::TimeValue;
			out item countData : CountData;
			
			private attribute runningCount : PulseCount := 0;
			
			first start;
			then merge continueCounting;
			
			then decide;
				if pulseValid == true then increment;
				if pulseValid == false then continueCounting;
			
			action increment;
			then assign runningCount := runningCount + 1;
			then continueCounting;
			
			then action calculateRate {
				in attribute totalCount = runningCount;
				in attribute window = gateTime;
				out item data = countData;
			}
			then done;
		}
	}
	
	part def HighVoltageSupply {
		doc /* Provides stable high voltage for photomultiplier tube operation. */
		
		attribute outputVoltage : ISQ::VoltageValue;
		attribute voltageStability : Real;
		attribute maxCurrent : ISQ::ElectricCurrentValue;
		
		port hvOut : HighVoltagePort;
		
		action supplyVoltage {
			out attribute voltage : ISQ::VoltageValue;
			
			first start;
			then action regulateVoltage {
				out attribute stabilized = voltage;
			}
			then done;
		}
	}
	
	part def ScintillationCounter {
		doc /* Complete radiation detection system that converts ionizing radiation 
		       into countable electrical pulses through scintillation, photomultiplication, 
		       and pulse processing. Primary function is to detect and quantify radiation 
		       events with high sensitivity and accuracy. */
		
		port radiationInput : RadiationInputPort;
		port measurementOutput : DataOutputPort;
		
		part scintillator : ScintillatorCrystal {
			attribute :>> material = "NaI(Tl)";
			attribute :>> lightYield = 38000;
			attribute :>> decayTime = 230.0[SI::ns];
		}
		
		part pmt : PhotomultiplierTube {
			attribute :>> gainFactor = 1.0e6;
			attribute :>> quantumEfficiency = 0.25;
			attribute :>> numberOfDynodes = 10;
		}
		
		part preamp : PreAmplifier {
			attribute :>> amplificationGain = 10.0;
		}
		
		part shaper : PulseShaper {
			attribute :>> shapingTime = 1.0[SI::us];
			attribute :>> filterType = "Gaussian";
		}
		
		part discriminator : Discriminator {
			attribute :>> threshold = 0.5[SI::V];
			attribute :>> deadTime = 100.0[SI::ns];
		}
		
		part counter : Counter {
			attribute :>> measurementWindow = 1.0[SI::s];
		}
		
		part hvSupply : HighVoltageSupply {
			attribute :>> outputVoltage = 1000.0[SI::V];
			attribute :>> voltageStability = 0.001;
		}
		
		connection radiationPath connect radiationInput to scintillator.radiationIn;
		connection opticalPath connect scintillator.photonOut to pmt.photonIn;
		connection powerPath connect hvSupply.hvOut to pmt.hvIn;
		connection electronPath connect pmt.electronOut to preamp.signalIn;
		connection amplifiedPath connect preamp.signalOut to shaper.signalIn;
		connection shapedPath connect shaper.signalOut to discriminator.signalIn;
		connection pulsePath connect discriminator.pulseOut to counter.pulseIn;
		connection dataPath connect counter.dataOut to measurementOutput;
		
		perform action detectAndCount {
			first start;
			then merge continuousOperation;
			
			then action scintillationProcess : ScintillatorCrystal::scintillate {
				in item incidentParticle;
				out item emittedPhotons;
			}
			
			flow scintillationProcess.emittedPhotons to pmtProcess.inputPhotons;
			
			then action pmtProcess : PhotomultiplierTube::convertAndAmplify {
				in item inputPhotons;
				in attribute appliedVoltage;
				out item amplifiedElectrons;
			}
			
			flow pmtProcess.amplifiedElectrons to preampProcess.inputSignal;
			
			then action preampProcess : PreAmplifier::amplifySignal {
				in item inputSignal;
				out item outputSignal;
			}
			
			flow preampProcess.outputSignal to shaperProcess.rawSignal;
			
			then action shaperProcess : PulseShaper::shapePulse {
				in item rawSignal;
				out item shapedSignal;
			}
			
			flow shaperProcess.shapedSignal to discriminatorProcess.inputSignal;
			
			then action discriminatorProcess : Discriminator::discriminate {
				in item inputSignal;
				in attribute thresholdLevel;
				out attribute accepted;
			}
			
			flow discriminatorProcess.accepted to counterProcess.pulseValid;
			
			then action counterProcess : Counter::countPulses {
				in attribute pulseValid;
				in attribute gateTime;
				out item countData;
			}
			
			then continuousOperation;
		}
	}
	
	requirement def DetectionEfficiencyRequirement {
		doc /* The scintillation counter shall achieve minimum detection efficiency 
		       for gamma radiation within specified energy range. */
		
		subject counter : ScintillationCounter;
		
		require constraint {
			counter.scintillator.lightYield >= 30000 and
			counter.pmt.quantumEfficiency >= 0.20
		}
	}
	
	requirement def EnergyResolutionRequirement {
		doc /* The system shall provide energy resolution sufficient for 
		       spectroscopic applications. */
		
		subject counter : ScintillationCounter;
		
		attribute maxResolution : Real = 0.08;
	}
	
	requirement def CountRateCapabilityRequirement {
		doc /* The system shall accurately measure count rates up to maximum 
		       specified value without significant dead time losses. */
		
		subject counter : ScintillationCounter;
		
		attribute maxCountRate : ISQ::FrequencyValue = 100000.0[SI::Hz];
	}
	
	requirement def VoltageStabilityRequirement {
		doc /* The high voltage supply shall maintain voltage stability to ensure 
		       consistent photomultiplier gain. */
		
		subject hvSupply : HighVoltageSupply;
		
		require constraint {
			hvSupply.voltageStability <= 0.01
		}
	}
	
	requirement def SystemPerformanceRequirement {
		doc /* Top-level performance requirements for scintillation counter system. */
		
		subject system : ScintillationCounter;
		
		require detectionEfficiency : DetectionEfficiencyRequirement;
		require energyResolution : EnergyResolutionRequirement;
		require countRateCapability : CountRateCapabilityRequirement;
		require voltageStability : VoltageStabilityRequirement;
	}
	
	part scintillationCounterSystem : ScintillationCounter {
		satisfy SystemPerformanceRequirement by scintillationCounterSystem;
	}
}
