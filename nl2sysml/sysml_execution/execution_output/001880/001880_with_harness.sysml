package TransistorAmplifierSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def OperatingRegion {
		attribute isCutoff : Boolean;
		attribute isActive : Boolean;
		attribute isSaturated : Boolean;
	}
	
	item def ElectricalSignal {
		attribute voltage : ISQ::VoltageValue;
		attribute current : ISQ::ElectricCurrentValue;
		attribute frequency : ISQ::FrequencyValue;
	}
	
	port def ElectricalTerminal {
		attribute voltage : ISQ::VoltageValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	part def Transistor {
		port base : ElectricalTerminal;
		port collector : ElectricalTerminal;
		port emitter : ElectricalTerminal;
		
		attribute baseEmitterVoltage : ISQ::VoltageValue;
		attribute collectorEmitterVoltage : ISQ::VoltageValue;
		attribute baseCurrent : ISQ::ElectricCurrentValue;
		attribute collectorCurrent : ISQ::ElectricCurrentValue;
		attribute emitterCurrent : ISQ::ElectricCurrentValue;
		attribute currentGain : Real;
		attribute operatingRegion : OperatingRegion;
		
		perform action amplify;
		exhibit state behavior : TransistorStateMachine;
	}
	
	part def BiasCircuit {
		port vcc : ElectricalTerminal;
		port output : ElectricalTerminal;
		port ground : ElectricalTerminal;
		
		attribute resistor1Value : ISQ::ResistanceValue;
		attribute resistor2Value : ISQ::ResistanceValue;
		attribute biasVoltage : ISQ::VoltageValue;
		
		perform action establishBias;
	}
	
	part def CollectorLoad {
		port vcc : ElectricalTerminal;
		port output : ElectricalTerminal;
		
		attribute resistance : ISQ::ResistanceValue;
		attribute voltageDrop : ISQ::VoltageValue;
	}
	
	part def EmitterResistor {
		port input : ElectricalTerminal;
		port ground : ElectricalTerminal;
		
		attribute resistance : ISQ::ResistanceValue;
		attribute stabilizationFactor : Real;
	}
	
	part def CouplingCapacitor {
		port input : ElectricalTerminal;
		port output : ElectricalTerminal;
		
		attribute capacitance : ISQ::CapacitanceValue;
		attribute blocksDC : Boolean;
	}
	
	part def PowerSupply {
		port vcc : ElectricalTerminal;
		port ground : ElectricalTerminal;
		
		attribute supplyVoltage : ISQ::VoltageValue;
		attribute maxCurrent : ISQ::ElectricCurrentValue;
		
		perform action provideVoltage;
	}
	
	part def SignalSource {
		port output : ElectricalTerminal;
		port ground : ElectricalTerminal;
		
		attribute amplitude : ISQ::VoltageValue;
		attribute frequency : ISQ::FrequencyValue;
		
		perform action generateSignal;
	}
	
	part def OutputLoad {
		port input : ElectricalTerminal;
		port ground : ElectricalTerminal;
		
		attribute impedance : ISQ::ResistanceValue;
	}
	
	action def DetermineOperatingPoint {
		in vbe : ISQ::VoltageValue;
		in vce : ISQ::VoltageValue;
		in ib : ISQ::ElectricCurrentValue;
		out region : OperatingRegion;
	}
	
	action def AmplifySignal {
		in inputSignal : ElectricalSignal;
		in biasPoint : ISQ::VoltageValue;
		in beta : Real;
		out amplifiedSignal : ElectricalSignal;
		
		first start;
		then merge amplificationLoop;
		
		then action checkBias : DetermineOperatingPoint {
			in vbe;
			in vce;
			in ib;
			out region;
		}
		
		then decide;
			if checkBias.region.isActive then performAmplification;
			if checkBias.region.isCutoff then noOutput;
			if checkBias.region.isSaturated then saturatedOutput;
		
		action performAmplification {
			in signal = inputSignal;
			in gain = beta;
			out result : ElectricalSignal;
		}
		then assign amplifiedSignal := performAmplification.result;
		then amplificationLoop;
		
		action noOutput {
			out result : ElectricalSignal;
		}
		then amplificationLoop;
		
		action saturatedOutput {
			out result : ElectricalSignal;
		}
		then amplificationLoop;
	}
	
	state def TransistorStateMachine {
		entry; then cutoff;
		
		state cutoff {
			entry action assignBaseCurrent {
				out bc : ISQ::ElectricCurrentValue = 0.0 [ISQ::A];
			}
			entry action assignCollectorCurrent {
				out cc : ISQ::ElectricCurrentValue = 0.0 [ISQ::A];
			}
		}
		
		transition cutoffToActive
			first cutoff
			accept at baseSignalApplied
			then active;
		
		state active {
			entry action computeCollectorCurrent;
			do action amplify;
		}
		
		transition activeToSaturated
			first active
			accept at excessiveBaseCurrent
			then saturated;
		
		state saturated {
			entry action setCollectorEmitterVoltage {
				out vce : ISQ::VoltageValue = 0.2 [ISQ::V];
			}
		}
		
		transition saturatedToActive
			first saturated
			accept at baseCurrentReduced
			then active;
		
		transition activeToCutoff
			first active
			accept at baseSignalRemoved
			then cutoff;
	}
	
	part commonEmitterAmplifier {
		part inputSource : SignalSource {
			attribute :>> amplitude = 0.01 [ISQ::V];
			attribute :>> frequency = 1000.0 [ISQ::Hz];
		}
		
		part inputCoupling : CouplingCapacitor {
			attribute :>> capacitance = 10.0e-6 [ISQ::F];
			attribute :>> blocksDC = true;
		}
		
		part biasNetwork : BiasCircuit {
			attribute :>> resistor1Value = 10000.0 [ISQ::Ω];
			attribute :>> resistor2Value = 2200.0 [ISQ::Ω];
			attribute :>> biasVoltage = 1.8 [ISQ::V];
		}
		
		part npnTransistor : Transistor {
			attribute :>> currentGain = 100.0;
		}
		
		part collectorResistor : CollectorLoad {
			attribute :>> resistance = 4700.0 [ISQ::Ω];
		}
		
		part emitterResistor : EmitterResistor {
			attribute :>> resistance = 1000.0 [ISQ::Ω];
			attribute :>> stabilizationFactor = 0.9;
		}
		
		part outputCoupling : CouplingCapacitor {
			attribute :>> capacitance = 10.0e-6 [ISQ::F];
			attribute :>> blocksDC = true;
		}
		
		part dcSupply : PowerSupply {
			attribute :>> supplyVoltage = 12.0 [ISQ::V];
			attribute :>> maxCurrent = 0.1 [ISQ::A];
		}
		
		part speaker : OutputLoad {
			attribute :>> impedance = 8.0 [ISQ::Ω];
		}
		
		connect inputSource.output to inputCoupling.input;
		connect inputCoupling.output to biasNetwork.output;
		connect biasNetwork.output to npnTransistor.base;
		connect dcSupply.vcc to biasNetwork.vcc;
		connect dcSupply.vcc to collectorResistor.vcc;
		connect collectorResistor.output to npnTransistor.collector;
		connect npnTransistor.collector to outputCoupling.input;
		connect outputCoupling.output to speaker.input;
		connect npnTransistor.emitter to emitterResistor.input;
		connect emitterResistor.ground to dcSupply.ground;
		connect biasNetwork.ground to dcSupply.ground;
		connect inputSource.ground to dcSupply.ground;
		connect speaker.ground to dcSupply.ground;
		
		perform action amplifyAudio : AmplifySignal;
	}
	
	requirement def PrimaryFunction {
		doc /* The transistor amplifier system shall amplify small AC input signals 
		     to produce larger output signals suitable for driving a load, while 
		     maintaining signal fidelity and operating within the active region. */
	}
	
	requirement def VoltageGainRequirement {
		doc /* The amplifier shall provide a minimum voltage gain of 50. */
		
		subject amp : Transistor;
		
		require constraint {
			amp.currentGain * 4.7 >= 50.0
		}
	}
	
	requirement def BiasStabilityRequirement {
		doc /* The bias network shall maintain the transistor in the active region 
		     across temperature variations of -20°C to +60°C. */
		
		subject bias : BiasCircuit;
		
		require constraint {
			bias.biasVoltage >= 1.5 [ISQ::V] and bias.biasVoltage <= 2.0 [ISQ::V]
		}
	}
	
	requirement def PowerSupplyRequirement {
		doc /* The system shall operate from a 12V DC power supply with current 
		     consumption not exceeding 100mA. */
		
		subject supply : PowerSupply;
		
		require constraint {
			supply.supplyVoltage == 12.0 [ISQ::V] and supply.maxCurrent <= 0.1 [ISQ::A]
		}
	}
	
	requirement def FrequencyResponseRequirement {
		doc /* The amplifier shall maintain gain within ±3dB across the audio 
		     frequency range of 20Hz to 20kHz. */
	}
	
	requirement transistorAmplifierRequirements {
		doc /* The transistor-based amplifier system shall meet all functional 
		     and performance requirements for audio signal amplification. */
		
		subject commonEmitterAmplifier;
		
		require primaryFuncReq : PrimaryFunction;
		require gainReqConstraint : VoltageGainRequirement;
		require biasReqConstraint : BiasStabilityRequirement;
		require powerReqConstraint : PowerSupplyRequirement;
		require freqReqConstraint : FrequencyResponseRequirement;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import TransistorAmplifierSystem::*;

    part testSubject : Transistor {
        exhibit state behavior : TransistorStateMachine;
    }

    action orchestrator {
        attribute testVbe : ISQ::VoltageValue;
        attribute testVce : ISQ::VoltageValue;
        attribute testIb : ISQ::ElectricCurrentValue;
        action actionProbe : DetermineOperatingPoint {
            in vbe = testVbe;
            in vce = testVce;
            in ib = testIb;
        }
        first actionProbe;
    }
}
