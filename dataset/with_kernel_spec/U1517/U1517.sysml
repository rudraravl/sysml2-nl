package 'CommonEmitterAmplifier' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		alias Voltage for ISQ::ElectricPotentialValue;
		alias Current for ISQ::ElectricCurrentValue;
		alias Resistance for ISQ::ElectricResistanceValue;
		alias Capacitance for ISQ::CapacitanceValue;
		alias Frequency for ISQ::FrequencyValue;

		item def ElectricalSignal {
			attribute voltage : Voltage;
			attribute current : Current;
			attribute isAC : Boolean;
		}

		item def DCPower {
			attribute voltage : Voltage;
			attribute current : Current;
		}

		port def SignalPort {
			out item signal : ElectricalSignal;
		}

		port def PowerPort {
			out item power : DCPower;
		}

		part def Transistor {
			port basePort : ~SignalPort;
			port collectorPort : ~SignalPort;
			port collectorOutPort : SignalPort;
			port emitterPort : SignalPort;
			
			exhibit state 'transistor states' {
				entry; then cutoff;
				state cutoff;
				accept when basePort.signal.voltage >= 0.7
					then active;
				state active;
				accept when basePort.signal.voltage >= 0.8
					then saturated;
				accept when basePort.signal.voltage < 0.7
					then cutoff;
				state saturated;
				accept when basePort.signal.voltage < 0.8
					then active;
			}
		}

		part def PowerSupply {
			attribute outputVoltage : Voltage = 12;
			port powerOutPort : PowerPort;
			port groundPort : PowerPort;
		}

		part def BiasCircuit {
			attribute resistor1Value : Resistance;
			attribute resistor2Value : Resistance;
			port biasOutPort : SignalPort;
			port powerInPort : ~PowerPort;
			port groundPort : ~PowerPort;
		}

		part def SignalSource {
			attribute amplitude : Voltage;
			attribute frequency : Frequency;
			port signalOutPort : SignalPort;
		}

		part def CouplingCapacitor {
			attribute capacitance : Capacitance;
			port inputPort : ~SignalPort;
			port outputPort : SignalPort;
		}

		part def CollectorResistor {
			attribute resistance : Resistance;
			port powerInPort : ~PowerPort;
			port signalOutPort : SignalPort;
		}

		part def EmitterResistor {
			attribute resistance : Resistance;
			port inputPort : ~SignalPort;
			port groundPort : ~PowerPort;
		}

		part def OutputLoad {
			attribute impedance : Resistance = 8;
			port inputPort : ~SignalPort;
			port groundPort : ~PowerPort;
		}

		part def AmplifierCircuit {
			port inputPort : ~SignalPort;
			port outputPort : SignalPort;
			port powerInPort : ~PowerPort;
		}

		action def 'Amplify Signal' {
			in inputSignal : ElectricalSignal;
			in dcPower : DCPower;
			out outputSignal : ElectricalSignal;
		}

		requirement def 'Amplification Requirement' {
			doc /* The amplifier shall increase the voltage of the input AC signal. */
			subject amplifier : AmplifierCircuit;
		}

		requirement def 'Thermal Stability Requirement' {
			doc /* The amplifier shall maintain stable gain across operating temperature range. */
			subject amplifier : AmplifierCircuit;
		}

		requirement def 'DC Isolation Requirement' {
			doc /* Coupling capacitors shall block DC bias while passing AC audio signals. */
			subject amplifier : AmplifierCircuit;
		}

		requirement def 'Active Region Requirement' {
			doc /* The transistor shall be biased in the active region for linear amplification. */
			subject amplifier : AmplifierCircuit;
		}
	}

	package Usages {
		private import Definitions::*;

		part amplifierCircuit : AmplifierCircuit {
			part powerSupply : PowerSupply {
				attribute :>> outputVoltage = 12;
			}

			part signalSource : SignalSource {
				attribute :>> amplitude = 0.01;
				attribute :>> frequency = 1000;
			}

			part inputCapacitor : CouplingCapacitor {
				attribute :>> capacitance = 10e-6;
			}

			part outputCapacitor : CouplingCapacitor {
				attribute :>> capacitance = 10e-6;
			}

			part biasCircuit : BiasCircuit {
				attribute :>> resistor1Value = 47000;
				attribute :>> resistor2Value = 10000;
			}

			part transistor : Transistor;

			part collectorResistor : CollectorResistor {
				attribute :>> resistance = 4000;
			}

			part emitterResistor : EmitterResistor {
				attribute :>> resistance = 1000;
			}

			part outputLoad : OutputLoad {
				attribute :>> impedance = 8;
			}

			flow of power : DCPower
				from powerSupply.powerOutPort.power to biasCircuit.powerInPort.power;

			flow of power : DCPower
				from powerSupply.powerOutPort.power to collectorResistor.powerInPort.power;

			flow of power : DCPower
				from powerSupply.groundPort.power to biasCircuit.groundPort.power;

			flow of power : DCPower
				from powerSupply.groundPort.power to emitterResistor.groundPort.power;

			flow of power : DCPower
				from powerSupply.groundPort.power to outputLoad.groundPort.power;

			flow of signal : ElectricalSignal
				from signalSource.signalOutPort.signal to inputCapacitor.inputPort.signal;

			flow of signal : ElectricalSignal
				from inputCapacitor.outputPort.signal to transistor.basePort.signal;

			flow of signal : ElectricalSignal
				from biasCircuit.biasOutPort.signal to transistor.basePort.signal;

			flow of signal : ElectricalSignal
				from collectorResistor.signalOutPort.signal to transistor.collectorPort.signal;

			flow of signal : ElectricalSignal
				from transistor.collectorOutPort.signal to outputCapacitor.inputPort.signal;

			flow of signal : ElectricalSignal
				from transistor.emitterPort.signal to emitterResistor.inputPort.signal;

			flow of signal : ElectricalSignal
				from outputCapacitor.outputPort.signal to outputLoad.inputPort.signal;

			perform action amplifySignal : 'Amplify Signal' {
				in inputSignal = inputCapacitor.outputPort.signal;
				in dcPower = powerSupply.powerOutPort.power;
				out outputSignal = transistor.collectorOutPort.signal;
			}
		}

		requirement amplificationReq : 'Amplification Requirement' {
			subject :>> amplifier = amplifierCircuit;
		}

		requirement thermalStabilityReq : 'Thermal Stability Requirement' {
			subject :>> amplifier = amplifierCircuit;
		}

		requirement dcIsolationReq : 'DC Isolation Requirement' {
			subject :>> amplifier = amplifierCircuit;
		}

		requirement activeRegionReq : 'Active Region Requirement' {
			subject :>> amplifier = amplifierCircuit;
		}

		satisfy amplificationReq by amplifierCircuit.amplifySignal;
		satisfy thermalStabilityReq by amplifierCircuit.emitterResistor;
		satisfy dcIsolationReq by amplifierCircuit.inputCapacitor;
		satisfy dcIsolationReq by amplifierCircuit.outputCapacitor;
		satisfy activeRegionReq by amplifierCircuit.biasCircuit;
	}
}
