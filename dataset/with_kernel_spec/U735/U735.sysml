package IonizationChamberSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	
	item def Radiation;
	item def IonPair;
	
	attribute def RadiationIntensity {
		:>> value : Real;
	}
	
	attribute def VoltageValue :> ISQ::ElectricPotential;
	attribute def CurrentValue :> ISQ::ElectricCurrent;
	
	part def Argon;
	part def Electrode;
	part def Insulator;
	
	part def IonizationChamber {
		part gas : Argon;
		part anode : Electrode;
		part cathode : Electrode;
		part insulator : Insulator;
	}
	
	part def HighVoltageSupply;
	part def ChargeAmplifier;
	part def SignalProcessor;
	part def MeasurementSystem;
	
	requirement def DetectRadiation {
		doc /* The system shall detect and measure ionizing radiation. */
		subject : MeasurementSystem;
	}
	
	requirement def LinearResponse {
		doc /* The system response shall be linear and reliable over long periods. */
		subject : MeasurementSystem;
	}
	
	action def Ionize {
		in radiation : Radiation;
		out ionPairs : IonPair;
	}
	
	action def CollectCharge {
		in ionPairs : IonPair;
		in voltage : VoltageValue;
		out ionizationCurrent : CurrentValue;
	}
	
	action def Amplify {
		in ionizationCurrent : CurrentValue;
		out amplifiedVoltage : VoltageValue;
	}
	
	action def ProcessSignal {
		in amplifiedVoltage : VoltageValue;
		out radiationMeasurement : RadiationIntensity;
	}
	
	action def ProcessCycle {
		action ionize : Ionize;
		action collect : CollectCharge;
		action amplify : Amplify;
		action process : ProcessSignal;
		succession first ionize then collect;
		succession first collect then amplify;
		succession first amplify then process;
	}
	
	state def MeasurementState {
		entry; then Idle;
		state Idle;
		accept radiation : Radiation
		then Processing;
		state Processing {
			do action processCycle : ProcessCycle;
		}
		transition first Processing then Idle;
	}
	
	part system : MeasurementSystem {
		satisfy requirement req_detect : DetectRadiation by system;
		satisfy requirement req_linear : LinearResponse by system;
		
		part chamber : IonizationChamber {
			in item radiation : Radiation;
			in item voltage : VoltageValue;
			out item ionizationCurrent : CurrentValue;
		}
		
		part hvSupply : HighVoltageSupply {
			out item voltage : VoltageValue;
		}
		
		part amplifier : ChargeAmplifier {
			in item ionizationCurrent : CurrentValue;
			out item amplifiedVoltage : VoltageValue;
		}
		
		part processor : SignalProcessor {
			in item amplifiedVoltage : VoltageValue;
			out item radiationMeasurement : RadiationIntensity;
		}
		
		flow hvSupply.voltage to chamber.voltage;
		flow chamber.ionizationCurrent to amplifier.ionizationCurrent;
		flow amplifier.amplifiedVoltage to processor.amplifiedVoltage;
		
		perform state measurementState : MeasurementState;
	}
}
