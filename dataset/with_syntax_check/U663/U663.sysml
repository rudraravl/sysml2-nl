package ElectronMultiplierSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ElectronCount :> Real;
	attribute def GainFactor :> Real;
	
	item def IncidentElectron {
		attribute energy : EnergyValue;
		attribute arrivalTime : TimeValue;
	}
	
	item def ElectronPulse {
		attribute electronCount : ElectronCount;
		attribute timestamp : TimeValue;
	}
	
	item def OutputSignal {
		attribute current : ElectricCurrentValue;
		attribute voltage : ElectricPotentialValue;
		attribute gain : GainFactor;
	}
	
	attribute def DynodeVoltage :> ElectricPotentialValue;
	attribute def SecondaryEmissionCoefficient :> Real;
	
	port def ElectronInputPort {
		in item electron : IncidentElectron;
	}
	
	port def ElectronOutputPort {
		out item pulse : ElectronPulse;
	}
	
	port def SignalOutputPort {
		out item signal : OutputSignal;
	}
	
	port def PowerInputPort {
		in attribute voltage : DynodeVoltage;
	}
	
	part def Dynode {
		attribute stageNumber : Integer;
		attribute biasVoltage : DynodeVoltage;
		attribute secondaryEmissionCoeff : SecondaryEmissionCoefficient;
		
		port electronIn : ElectronInputPort;
		port electronOut : ElectronOutputPort;
		
		action multiplyElectrons {
			in incidentCount : ElectronCount;
			in coefficient : SecondaryEmissionCoefficient;
			out emittedCount : ElectronCount;
			
			first start;
			then assign emittedCount := incidentCount * coefficient;
			then done;
		}
	}
	
	part def VacuumEnclosure {
		attribute internalPressure : PressureValue;
		
		assert constraint vacuumLevel {
			doc /* Maintain high vacuum to prevent gas ionization and ensure proper secondary emission. */
			internalPressure < 1.0e-5[SI::Pa]
		}
	}
	
	part def HighVoltageSupply {
		attribute outputVoltage : DynodeVoltage;
		attribute maxVoltage : DynodeVoltage;
		attribute stability : Real;
		
		port hvOutput : PowerInputPort;
		
		action regulateVoltage {
			in setpoint : DynodeVoltage;
			out regulated : DynodeVoltage;
			
			first start;
			then decide;
				if setpoint <= maxVoltage then supply;
				else fault;
			action supply {
				assign regulated := setpoint;
			}
			then done;
			action fault;
			then done;
		}
	}
	
	part def Anode {
		attribute collectionEfficiency : Real;
		
		port electronIn : ElectronInputPort;
		port signalOut : SignalOutputPort;
		
		action collectAndConvert {
			in electronPulse : ElectronPulse;
			out outputSignal : OutputSignal;
			
			first start;
			then action calculateCurrent {
				in count : ElectronCount = electronPulse.electronCount;
				out current : ElectricCurrentValue;
				
				private attribute elementaryCharge : Real = 1.602176634e-19;
				private attribute pulseDuration : TimeValue = 10.0[SI::ns];
				assign current := (count * elementaryCharge / 1.0e-8)[SI::A];
			}
			then action formSignal {
				in current : ElectricCurrentValue = calculateCurrent.current;
				out signal : OutputSignal;
				
				assign signal.current := current;
				assign signal.voltage := 0.05[SI::V];
			}
			then assign outputSignal := formSignal.signal;
			then done;
		}
	}
	
	part def ElectronMultiplier {
		attribute numberOfStages : Integer;
		attribute overallGain : GainFactor;
		
		port electronInput : ElectronInputPort;
		port signalOutput : SignalOutputPort;
		port powerInput : PowerInputPort;
		
		part vacuumChamber : VacuumEnclosure {
			attribute :>> internalPressure = 5.0e-6[SI::Pa];
		}
		
		part hvSupply : HighVoltageSupply {
			attribute :>> outputVoltage = 2500.0[SI::V];
			attribute :>> maxVoltage = 3000.0[SI::V];
			attribute :>> stability = 0.01;
		}
		
		part dynode1 : Dynode {
			attribute :>> stageNumber = 1;
			attribute :>> secondaryEmissionCoeff = 4.5;
		}
		
		part dynode2 : Dynode {
			attribute :>> stageNumber = 2;
			attribute :>> secondaryEmissionCoeff = 4.5;
		}
		
		part dynode3 : Dynode {
			attribute :>> stageNumber = 3;
			attribute :>> secondaryEmissionCoeff = 4.5;
		}
		
		part dynode4 : Dynode {
			attribute :>> stageNumber = 4;
			attribute :>> secondaryEmissionCoeff = 4.5;
		}
		
		part dynode5 : Dynode {
			attribute :>> stageNumber = 5;
			attribute :>> secondaryEmissionCoeff = 4.5;
		}
		
		part dynode6 : Dynode {
			attribute :>> stageNumber = 6;
			attribute :>> secondaryEmissionCoeff = 4.5;
		}
		
		part dynode7 : Dynode {
			attribute :>> stageNumber = 7;
			attribute :>> secondaryEmissionCoeff = 4.5;
		}
		
		part dynode8 : Dynode {
			attribute :>> stageNumber = 8;
			attribute :>> secondaryEmissionCoeff = 4.5;
		}
		
		part dynode9 : Dynode {
			attribute :>> stageNumber = 9;
			attribute :>> secondaryEmissionCoeff = 4.5;
		}
		
		part dynode10 : Dynode {
			attribute :>> stageNumber = 10;
			attribute :>> secondaryEmissionCoeff = 4.5;
		}
		
		part collector : Anode {
			attribute :>> collectionEfficiency = 0.98;
		}
		
		connect hvSupply.hvOutput to powerInput;
		connect electronInput to dynode1.electronIn;
		connect dynode1.electronOut to dynode2.electronIn;
		connect dynode2.electronOut to dynode3.electronIn;
		connect dynode3.electronOut to dynode4.electronIn;
		connect dynode4.electronOut to dynode5.electronIn;
		connect dynode5.electronOut to dynode6.electronIn;
		connect dynode6.electronOut to dynode7.electronIn;
		connect dynode7.electronOut to dynode8.electronIn;
		connect dynode8.electronOut to dynode9.electronIn;
		connect dynode9.electronOut to dynode10.electronIn;
		connect dynode10.electronOut to collector.electronIn;
		connect collector.signalOut to signalOutput;
		
		perform action amplifyElectronSignal;
	}
	
	action def AmplifyElectronSignal {
		in incidentElectron : IncidentElectron;
		out amplifiedSignal : OutputSignal;
		
		first start;
		then action initializeDetection {
			in electron : IncidentElectron = incidentElectron;
			out initialPulse : ElectronPulse;
			
			assign initialPulse.electronCount := 1.0;
			assign initialPulse.timestamp := electron.arrivalTime;
		}
		then action cascadeAmplification {
			in inputPulse : ElectronPulse = initializeDetection.initialPulse;
			out amplifiedPulse : ElectronPulse;
			
			private attribute currentCount : ElectronCount := inputPulse.electronCount;
			private attribute stageGain : SecondaryEmissionCoefficient := 4.5;
			
			action stage1 {
				assign currentCount := currentCount * stageGain;
			}
			then action stage2 {
				assign currentCount := currentCount * stageGain;
			}
			then action stage3 {
				assign currentCount := currentCount * stageGain;
			}
			then action stage4 {
				assign currentCount := currentCount * stageGain;
			}
			then action stage5 {
				assign currentCount := currentCount * stageGain;
			}
			then action stage6 {
				assign currentCount := currentCount * stageGain;
			}
			then action stage7 {
				assign currentCount := currentCount * stageGain;
			}
			then action stage8 {
				assign currentCount := currentCount * stageGain;
			}
			then action stage9 {
				assign currentCount := currentCount * stageGain;
			}
			then action stage10 {
				assign currentCount := currentCount * stageGain;
			}
			then assign amplifiedPulse.electronCount := currentCount;
			then assign amplifiedPulse.timestamp := inputPulse.timestamp;
		}
		then action convertToSignal {
			in pulse : ElectronPulse = cascadeAmplification.amplifiedPulse;
			out signal : OutputSignal;
			
			private attribute elementaryCharge : Real = 1.602176634e-19;
			private attribute pulseDuration : TimeValue = 10.0[SI::ns];
			private attribute loadResistance : Real = 50.0;
			
			first start;
			then assign signal.current := (pulse.electronCount * elementaryCharge / 1.0e-8)[SI::A];
			then assign signal.voltage := 0.05[SI::V];
			then assign signal.gain := pulse.electronCount / 1.0;
			then done;
		}
		then assign amplifiedSignal := convertToSignal.signal;
		then done;
	}
	
	part electronMultiplierSystem : ElectronMultiplier {
		attribute :>> numberOfStages = 10;
		attribute :>> overallGain = 3486784.401;
		
		perform action amplifyElectronSignal : AmplifyElectronSignal;
		
		assert constraint minimumGain {
			overallGain >= 1.0e6
		}
		
		assert constraint operatingVacuum {
			vacuumChamber.internalPressure < 1.0e-5[SI::Pa]
		}
		
		assert constraint voltageStability {
			hvSupply.stability <= 0.02
		}
	}
	
	requirement <'EM-REQ-001'> highGainAmplification {
		doc /* The electron multiplier shall amplify single incident electrons 
		     to produce a measurable electrical signal with gain exceeding 10^6 
		     through cascaded secondary emission. */
		
		subject electronMultiplierSystem;
		
		require constraint {
			electronMultiplierSystem.overallGain >= 1.0e6
		}
	}
	
	requirement <'EM-REQ-002'> vacuumOperation {
		doc /* The electron multiplier shall operate in high vacuum environment 
		     with pressure below 10^-5 Pa to prevent gas discharge and ensure 
		     reliable secondary emission. */
		
		subject electronMultiplierSystem.vacuumChamber;
		
		require constraint {
			electronMultiplierSystem.vacuumChamber.internalPressure < 1.0e-5[SI::Pa]
		}
	}
	
	requirement <'EM-REQ-003'> stableHighVoltage {
		doc /* The high voltage supply shall provide stable bias voltage up to 3000V 
		     with stability better than 2% for consistent dynode operation. */
		
		subject electronMultiplierSystem.hvSupply;
		
		require constraint {
			electronMultiplierSystem.hvSupply.maxVoltage >= 3000.0[SI::V] and
			electronMultiplierSystem.hvSupply.stability <= 0.02
		}
	}
	
	requirement <'EM-REQ-004'> fastResponse {
		doc /* The electron multiplier shall produce output pulses with duration 
		     less than 20 nanoseconds to preserve timing information. */
		
		subject electronMultiplierSystem.collector;
	}
	
	requirement <'EM-SYS-001'> primaryFunction {
		doc /* The electron multiplier system shall detect and amplify individual 
		     incident electrons into measurable electrical pulses for applications 
		     in mass spectrometry, photon detection, and particle physics. */
		
		require highGainAmplification;
		require vacuumOperation;
		require stableHighVoltage;
		require fastResponse;
	}
}
