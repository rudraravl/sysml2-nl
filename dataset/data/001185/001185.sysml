package PhotomultiplierTubeSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PhotonCount :> Integer;
	attribute def ElectronCount :> Integer;
	attribute def GainFactor :> Real;
	attribute def QuantumEfficiency :> Real;
	
	item def Photon {
		attribute wavelength : LengthValue;
		attribute energy : EnergyValue;
	}
	
	item def Photoelectron {
		attribute kineticEnergy : EnergyValue;
	}
	
	item def SecondaryElectron {
		attribute kineticEnergy : EnergyValue;
	}
	
	item def ElectricalPulse {
		attribute current : ElectricCurrentValue;
		attribute voltage : ElectricPotentialValue;
		attribute duration : DurationValue;
	}
	
	port def OpticalInputPort {
		in item photonStream : Photon[*];
	}
	
	port def HighVoltageInputPort {
		in attribute biasVoltage : ElectricPotentialValue;
	}
	
	port def ElectricalOutputPort {
		out item signalPulse : ElectricalPulse;
	}
	
	part def Photocathode {
		port opticalIn : OpticalInputPort;
		port electronOut {
			out item photoelectrons : Photoelectron[*];
		}
		
		attribute quantumEfficiency : QuantumEfficiency := 0.25;
		attribute workFunction : EnergyValue := 4.5 [eV];
		attribute material : String := "bialkali";
		
		action convertPhotonsToElectrons {
			in photons : Photon[*];
			out electrons : Photoelectron[*];
			
			doc /* Converts incident photons to photoelectrons via photoelectric effect */
		}
	}
	
	part def Dynode {
		port electronIn {
			in item primaryElectrons : SecondaryElectron[*];
		}
		port electronOut {
			out item secondaryElectrons : SecondaryElectron[*];
		}
		port hvBias : HighVoltageInputPort;
		
		attribute secondaryEmissionRatio : GainFactor := 4.0;
		attribute surfaceMaterial : String := "BeO-Cs";
		
		action multiplyElectrons {
			in incomingElectrons : SecondaryElectron[*];
			in biasVoltage : ElectricPotentialValue;
			out amplifiedElectrons : SecondaryElectron[*];
			
			doc /* Amplifies electron count through secondary emission */
		}
	}
	
	part def DynodeChain {
		port electronIn {
			in item primaryElectrons : Photoelectron[*];
		}
		port electronOut {
			out item amplifiedElectrons : SecondaryElectron[*];
		}
		port hvSupply : HighVoltageInputPort;
		
		attribute numberOfStages : Integer := 10;
		attribute stageGain : GainFactor := 4.0;
		attribute totalGain : GainFactor := 1048576.0;
		attribute voltagePerStage : ElectricPotentialValue := 100 [V];
		
		part dynode1 : Dynode;
		part dynode2 : Dynode;
		part dynode3 : Dynode;
		part dynode4 : Dynode;
		part dynode5 : Dynode;
		part dynode6 : Dynode;
		part dynode7 : Dynode;
		part dynode8 : Dynode;
		part dynode9 : Dynode;
		part dynode10 : Dynode;
		
		connection d1_to_d2 connect dynode1.electronOut to dynode2.electronIn;
		connection d2_to_d3 connect dynode2.electronOut to dynode3.electronIn;
		connection d3_to_d4 connect dynode3.electronOut to dynode4.electronIn;
		connection d4_to_d5 connect dynode4.electronOut to dynode5.electronIn;
		connection d5_to_d6 connect dynode5.electronOut to dynode6.electronIn;
		connection d6_to_d7 connect dynode6.electronOut to dynode7.electronIn;
		connection d7_to_d8 connect dynode7.electronOut to dynode8.electronIn;
		connection d8_to_d9 connect dynode8.electronOut to dynode9.electronIn;
		connection d9_to_d10 connect dynode9.electronOut to dynode10.electronIn;
		
		action cascadeAmplification {
			in primaryElectrons : Photoelectron[*];
			in hvBias : ElectricPotentialValue;
			out amplifiedElectrons : SecondaryElectron[*];
			
			doc /* Performs cascade multiplication through dynode chain */
			
			private attribute currentStage : Integer := 1;
			private attribute electronMultiplier : GainFactor := 1.0;
			
			first start;
			then merge continueAmplification;
			
			action stageMultiplication {
				then assign electronMultiplier := electronMultiplier * stageGain;
				then assign currentStage := currentStage + 1;
			}
			
			then decide;
				if currentStage <= numberOfStages then stageMultiplication;
				if currentStage > numberOfStages then done;
			then continueAmplification;
		}
	}
	
	part def Anode {
		port electronIn {
			in item electrons : SecondaryElectron[*];
		}
		port signalOut : ElectricalOutputPort;
		
		attribute collectionEfficiency : Real := 0.95;
		attribute capacitance : CapacitanceValue := 5.0e-12 [F];
		
		action collectElectrons {
			in electronStream : SecondaryElectron[*];
			out currentPulse : ElectricalPulse;
			
			doc /* Collects amplified electrons and generates output current pulse */
		}
	}
	
	part def VacuumEnvelope {
		attribute pressure : PressureValue := 1.0e-6 [Pa];
		attribute material : String := "borosilicate glass";
		attribute windowMaterial : String := "UV-transmitting glass";
		
		doc /* Maintains high vacuum to prevent electron scattering */
	}
	
	part def HighVoltageSupply {
		port hvOutput : HighVoltageInputPort;
		
		attribute outputVoltage : ElectricPotentialValue := 1500 [V];
		attribute voltageStability : Real := 0.001;
		attribute maxCurrent : ElectricCurrentValue := 0.01 [A];
		attribute ripple : ElectricPotentialValue := 0.1 [V];
		
		action regulateVoltage {
			in setpoint : ElectricPotentialValue;
			out regulatedVoltage : ElectricPotentialValue;
			
			doc /* Maintains stable high voltage for dynode chain biasing */
		}
	}
	
	part def VoltageDivider {
		port hvIn : HighVoltageInputPort;
		port dynodeOutputs {
			out attribute stage1Voltage : ElectricPotentialValue;
			out attribute stage2Voltage : ElectricPotentialValue;
			out attribute stage3Voltage : ElectricPotentialValue;
			out attribute stage4Voltage : ElectricPotentialValue;
			out attribute stage5Voltage : ElectricPotentialValue;
			out attribute stage6Voltage : ElectricPotentialValue;
			out attribute stage7Voltage : ElectricPotentialValue;
			out attribute stage8Voltage : ElectricPotentialValue;
			out attribute stage9Voltage : ElectricPotentialValue;
			out attribute stage10Voltage : ElectricPotentialValue;
		}
		
		attribute resistorValue : ElectricResistanceValue := 100000 [ohm];
		
		doc /* Distributes high voltage across dynode stages */
	}
	
	signal def PhotonArrival;
	signal def NoPhotons;
	signal def ResetSignal;
	
	part def PhotomultiplierTube {
		doc /* 
		A photomultiplier tube converts weak optical signals into amplified 
		electrical pulses through photoemission and electron multiplication.
		*/
		
		port opticalInput : OpticalInputPort;
		port hvInput : HighVoltageInputPort;
		port electricalOutput : ElectricalOutputPort;
		
		attribute overallGain : GainFactor := 1.0e6;
		attribute darkCurrent : ElectricCurrentValue := 2.0e-9 [A];
		attribute riseTime : DurationValue := 2.5e-9 [s];
		attribute transitTime : DurationValue := 30.0e-9 [s];
		attribute spectralResponseMin : LengthValue := 300.0e-9 [m];
		attribute spectralResponseMax : LengthValue := 650.0e-9 [m];
		attribute maxAnodeCurrent : ElectricCurrentValue := 100.0e-6 [A];
		
		part photocathode : Photocathode;
		part dynodeChain : DynodeChain;
		part anode : Anode;
		part envelope : VacuumEnvelope;
		part voltageDivider : VoltageDivider;
		
		connection opticalPath connect opticalInput to photocathode.opticalIn;
		connection cathodeToChain connect photocathode.electronOut to dynodeChain.electronIn;
		connection chainToAnode connect dynodeChain.electronOut to anode.electronIn;
		connection anodeToOutput connect anode.signalOut to electricalOutput;
		connection hvToDivider connect hvInput to voltageDivider.hvIn;
		connection dividerToChain connect voltageDivider.dynodeOutputs to dynodeChain.hvSupply;
		
		exhibit state pmtOperatingStates {
			entry; then idle;
			
			state idle {
				doc /* PMT is powered but not detecting photons */
			}
			
			state detecting {
				doc /* PMT is actively converting photons to electrical signals */
			}
			
			state saturated {
				doc /* Anode current exceeds maximum safe operating level */
			}
			
			transition idle_to_detecting
				first idle
				accept photonEvent : PhotonArrival
				then detecting;
			
			transition detecting_to_idle
				first detecting
				accept noPhotonEvent : NoPhotons
				then idle;
			
			transition detecting_to_saturated
				first detecting
				if anode.signalOut.signalPulse.current > maxAnodeCurrent
				then saturated;
			
			transition saturated_to_idle
				first saturated
				accept resetEvent : ResetSignal
				then idle;
		}
		
		perform action detectAndAmplifyLight;
	}
	
	action def PhotoelectronEmission {
		in photons : Photon[*];
		in quantumEff : QuantumEfficiency;
		out photoelectrons : Photoelectron[*];
	}
	
	action def ElectronMultiplication {
		in primaryElectrons : Photoelectron[*];
		in gain : GainFactor;
		out amplifiedElectrons : SecondaryElectron[*];
	}
	
	action def SignalGeneration {
		in electrons : SecondaryElectron[*];
		out pulse : ElectricalPulse;
	}
	
	action detectAndAmplifyLight {
		doc /* 
		Primary function: Convert weak optical signals into amplified electrical 
		pulses suitable for measurement and analysis.
		*/
		
		in incidentPhotons : Photon[*];
		in biasVoltage : ElectricPotentialValue;
		out outputPulse : ElectricalPulse;
		
		first start;
		
		then action photoemission : PhotoelectronEmission {
			in photons = incidentPhotons;
			in quantumEff = 0.25;
			out photoelectrons : Photoelectron[*];
		}
		
		flow photoemission.photoelectrons to multiplication.primaryElectrons;
		
		then action multiplication : ElectronMultiplication {
			in primaryElectrons : Photoelectron[*];
			in gain = 1.0e6;
			out amplifiedElectrons : SecondaryElectron[*];
		}
		
		flow multiplication.amplifiedElectrons to signalGen.electrons;
		
		then action signalGen : SignalGeneration {
			in electrons : SecondaryElectron[*];
			out pulse : ElectricalPulse;
		}
		
		then done;
	}
	
	part pmtSystem : PhotomultiplierTube {
		attribute overallGain = 1.2e6;
		attribute darkCurrent = 1.5e-9 [A];
		attribute riseTime = 2.2e-9 [s];
		
		part hvSupply : HighVoltageSupply {
			attribute outputVoltage = 1500 [V];
			attribute voltageStability = 0.0005;
		}
		
		connection hvConnection connect hvSupply.hvOutput to hvInput;
		
		perform detectAndAmplifyLight {
			in incidentPhotons;
			in biasVoltage = hvSupply.outputVoltage;
			out outputPulse;
		}
	}
	
	requirement def SensitivityRequirement {
		doc /* PMT shall detect single photon events with specified quantum efficiency */
		
		subject pmt : PhotomultiplierTube;
		
		require constraint {
			pmt.photocathode.quantumEfficiency >= 0.20
		}
	}
	
	requirement def GainRequirement {
		doc /* PMT shall provide minimum electron multiplication gain */
		
		subject pmt : PhotomultiplierTube;
		
		require constraint {
			pmt.overallGain >= 1.0e5 and pmt.overallGain <= 1.0e7
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* PMT shall respond to optical pulses within specified time */
		
		subject pmt : PhotomultiplierTube;
		
		require constraint {
			pmt.riseTime <= 5.0e-9 [s]
		}
	}
	
	requirement def DarkCurrentRequirement {
		doc /* PMT dark current shall be minimized to reduce noise */
		
		subject pmt : PhotomultiplierTube;
		
		require constraint {
			pmt.darkCurrent <= 5.0e-9 [A]
		}
	}
	
	requirement def SpectralResponseRequirement {
		doc /* PMT shall operate over specified wavelength range */
		
		subject pmt : PhotomultiplierTube;
		
		require constraint {
			pmt.spectralResponseMin <= 350.0e-9 [m] and
			pmt.spectralResponseMax >= 600.0e-9 [m]
		}
	}
	
	requirement pmtSystemRequirements {
		doc /* Overall performance requirements for photomultiplier tube system */
		
		subject system : PhotomultiplierTube;
		
		require req1 : SensitivityRequirement;
		require req2 : GainRequirement;
		require req3 : ResponseTimeRequirement;
		require req4 : DarkCurrentRequirement;
		require req5 : SpectralResponseRequirement;
	}
}
