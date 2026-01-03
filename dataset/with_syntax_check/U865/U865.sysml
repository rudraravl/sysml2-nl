package ScintillatorDetectionSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PhotonYield :> ScalarValues::Real;
	attribute def DecayConstant :> ScalarValues::Real;
	attribute def QuantumEfficiency :> ScalarValues::Real;
	
	item def IonizingRadiation {
		attribute particleType : String;
		attribute kineticEnergy :> ISQ::energy;
		attribute incidentAngle :> ScalarValues::Real;
	}
	
	item def ScintillationPhotons {
		attribute photonCount :> ScalarValues::Real;
		attribute wavelength :> ISQ::length;
		attribute emissionTime :> ISQ::time;
		attribute intensity :> ISQ::power;
	}
	
	item def ElectricalPulse {
		attribute amplitude :> ISQ::voltage;
		attribute pulseWidth :> ISQ::time;
		attribute riseTime :> ISQ::time;
	}
	
	item def MeasurementData {
		attribute depositedEnergy :> ISQ::energy;
		attribute timestamp :> ISQ::time;
		attribute pulseHeight :> ISQ::voltage;
	}
	
	port def RadiationPort {
		in item radiation : IonizingRadiation;
	}
	
	port def OpticalPort {
		out item photons : ScintillationPhotons;
	}
	
	port def PhotonInputPort {
		in item photons : ScintillationPhotons;
	}
	
	port def ElectricalPort {
		out item pulse : ElectricalPulse;
	}
	
	port def SignalInputPort {
		in item pulse : ElectricalPulse;
	}
	
	port def DataPort {
		out item data : MeasurementData;
	}
	
	part def ScintillatorCrystal {
		attribute material : String;
		attribute volume :> ISQ::volume;
		attribute lightYield :> PhotonYield;
		attribute decayTime :> ISQ::time;
		
		port radiationInput : RadiationPort;
		port opticalOutput : OpticalPort;
		
		perform action scintillate : ScintillationAction;
	}
	
	part def PhotomultiplierTube {
		attribute photocathodeArea :> ISQ::area;
		attribute quantumEfficiency :> QuantumEfficiency;
		attribute gainFactor :> ScalarValues::Real;
		attribute dynodesCount : ScalarValues::Integer;
		
		port photonInput : PhotonInputPort;
		port electricalOutput : ElectricalPort;
		
		perform action convertPhotons : PhotoelectricConversion;
	}
	
	part def SignalAnalyzer {
		attribute baselineVoltage :> ISQ::voltage;
		attribute triggerThreshold :> ISQ::voltage;
		attribute integrationWindow :> ISQ::time;
		
		port signalInput : SignalInputPort;
		port dataOutput : DataPort;
		
		perform action analyzeSignal : SignalAnalysis;
	}
	
	action def ScintillationAction {
		in radiation : IonizingRadiation;
		out photons : ScintillationPhotons;
		
		first start;
		then action depositEnergy {
			in incidentParticle : IonizingRadiation = radiation;
			out excitedMolecules : ScalarValues::Real;
		}
		then action deexcitation {
			in excitedStates : ScalarValues::Real = depositEnergy.excitedMolecules;
			out emittedPhotons : ScalarValues::Real;
		}
		then action formPhotonBurst {
			in photonNumber : ScalarValues::Real = deexcitation.emittedPhotons;
			out photonBurst : ScintillationPhotons;
		}
		then assign photons := formPhotonBurst.photonBurst;
		then done;
	}
	
	action def PhotoelectricConversion {
		in photons : ScintillationPhotons;
		out pulse : ElectricalPulse;
		
		first start;
		then action photocathodeInteraction {
			in incidentPhotons : ScintillationPhotons = photons;
			out photoelectrons : ScalarValues::Real;
		}
		then action dynodeMultiplication {
			in initialElectrons : ScalarValues::Real = photocathodeInteraction.photoelectrons;
			out amplifiedElectrons : ScalarValues::Real;
		}
		then action anodeCollection {
			in electrons : ScalarValues::Real = dynodeMultiplication.amplifiedElectrons;
			out electricalPulse : ElectricalPulse;
		}
		then assign pulse := anodeCollection.electricalPulse;
		then done;
	}
	
	action def SignalAnalysis {
		in pulse : ElectricalPulse;
		out data : MeasurementData;
		
		first start;
		then action baselineSubtraction {
			in rawPulse : ElectricalPulse = pulse;
			out correctedPulse : ElectricalPulse;
		}
		then action pulseIntegration {
			in inputPulse : ElectricalPulse = baselineSubtraction.correctedPulse;
			out integratedCharge : ScalarValues::Real;
		}
		then action energyCalibration {
			in charge : ScalarValues::Real = pulseIntegration.integratedCharge;
			out measuredEnergy : ISQ::energy;
		}
		then action formatData {
			in energy : ISQ::energy = energyCalibration.measuredEnergy;
			out measurement : MeasurementData;
		}
		then assign data := formatData.measurement;
		then done;
	}
	
	state def ScintillatorOperationalStates {
		entry; then ready;
		
		state ready;
		transition ready_to_active
			first ready
			accept at ScintillatorDetectionSystem::scintillatorSystem::crystal::radiationInput
			then active;
		
		state active {
			entry; then excitation;
			
			state excitation;
			transition excitation_to_emission
				first excitation
				if true
				then emission;
			
			state emission;
			transition emission_to_decay
				first emission
				if true
				then decay;
			
			state decay;
			transition decay_to_complete
				first decay
				if true
				then complete;
			
			state complete;
		}
		
		transition active_to_ready
			first active.complete
			then ready;
	}
	
	requirement def <'REQ-SYS-001'> PrimaryFunctionRequirement {
		doc /* The scintillator detection system shall convert incident ionizing radiation 
		     into measurable electrical signals proportional to the deposited energy. */
		
		subject detectionSystem : ScintillatorSystem;
		
		require constraint energyProportionality {
			doc /* Output signal amplitude shall be proportional to incident radiation energy. */
		}
	}
	
	requirement def <'REQ-SCINT-001'> ScintillatorPerformanceRequirement {
		doc /* The scintillator crystal shall produce sufficient light output with 
		     appropriate decay time for accurate energy measurement. */
		
		subject crystal : ScintillatorCrystal;
		
		require constraint minimumLightYield {
			crystal.lightYield >= 0.08
		}
		
		require constraint maximumDecayTime {
			crystal.decayTime <= 300.0e-9[SI::s]
		}
	}
	
	requirement def <'REQ-PMT-001'> PhotodetectorRequirement {
		doc /* The photomultiplier tube shall efficiently convert scintillation photons 
		     to electrical pulses with adequate gain. */
		
		subject pmt : PhotomultiplierTube;
		
		require constraint minimumQuantumEfficiency {
			pmt.quantumEfficiency >= 0.20
		}
		
		require constraint minimumGain {
			pmt.gainFactor >= 1.0e5
		}
	}
	
	requirement def <'REQ-ANAL-001'> SignalProcessingRequirement {
		doc /* The signal analyzer shall accurately measure pulse characteristics 
		     and convert them to energy values. */
		
		subject analyzer : SignalAnalyzer;
		
		require constraint triggerSensitivity {
			analyzer.triggerThreshold <= 0.010[SI::V]
		}
		
		require constraint integrationAccuracy {
			analyzer.integrationWindow >= 1.0e-6[SI::s]
		}
	}
	
	part def ScintillatorSystem {
		part crystal : ScintillatorCrystal;
		part pmt : PhotomultiplierTube;
		part analyzer : SignalAnalyzer;
		
		connect crystal.opticalOutput to pmt.photonInput;
		connect pmt.electricalOutput to analyzer.signalInput;
		
		perform action detectAndMeasure : RadiationDetectionSequence;
	}
	
	action def RadiationDetectionSequence {
		first start;
		then action receiveRadiation {
			out radiation : IonizingRadiation;
		}
		then action scintillate : ScintillationAction {
			in radiation = receiveRadiation.radiation;
			out photons : ScintillationPhotons;
		}
		then action convertToElectrical : PhotoelectricConversion {
			in photons = scintillate.photons;
			out pulse : ElectricalPulse;
		}
		then action analyze : SignalAnalysis {
			in pulse = convertToElectrical.pulse;
			out data : MeasurementData;
		}
		then done;
	}
	
	part scintillatorSystem : ScintillatorSystem {
		part crystal : ScintillatorCrystal {
			attribute :>> material = "Sodium Iodide (NaI:Tl)";
			attribute :>> volume = 0.000125[SI::m^3];
			attribute :>> lightYield = 0.11;
			attribute :>> decayTime = 230.0e-9[SI::s];
		}
		
		part pmt : PhotomultiplierTube {
			attribute :>> photocathodeArea = 0.005[SI::m^2];
			attribute :>> quantumEfficiency = 0.24;
			attribute :>> gainFactor = 5.0e5;
			attribute :>> dynodesCount = 10;
		}
		
		part analyzer : SignalAnalyzer {
			attribute :>> baselineVoltage = 0.0[SI::V];
			attribute :>> triggerThreshold = 0.005[SI::V];
			attribute :>> integrationWindow = 2.0e-6[SI::s];
		}
		
		perform action detectAndMeasure[*] ordered references RadiationDetectionSequence;
		
		part crystal {
			perform detectAndMeasure.scintillate;
		}
		
		part pmt {
			perform detectAndMeasure.convertToElectrical;
		}
		
		part analyzer {
			perform detectAndMeasure.analyze;
		}
	}
	
	requirement systemMissionRequirement {
		doc /* The scintillator detection system shall detect ionizing radiation events 
		     and measure their energy for radiation monitoring and spectroscopy applications. */
		
		assume constraint radiationEnvironment {
			doc /* System operates in environment with ionizing radiation present. */
		}
		
		require constraint req1 : PrimaryFunctionRequirement;
		require constraint req2 : ScintillatorPerformanceRequirement;
		require constraint req3 : PhotodetectorRequirement;
		require constraint req4 : SignalProcessingRequirement;
	}
}
