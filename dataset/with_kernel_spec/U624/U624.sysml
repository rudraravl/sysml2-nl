package 'Capacitance Probe System' {
	private import ISQ::*;
	private import ScalarValues::*;
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		attribute def Voltage :> ElectricPotentialValue;
		attribute def Current :> ElectricCurrentValue;
		attribute def Frequency :> FrequencyValue;
		attribute def Capacitance :> CapacitanceValue;
		attribute def Thickness :> LengthValue;
		attribute def DielectricConstant :> Real;

		attribute def PowerOn;
		attribute def PowerOff;
		attribute def StartMeasurement;
		attribute def StopMeasurement;
		attribute def InitComplete;
		attribute def RecalibrateSignal;

		attribute def PowerSignal {
			attribute voltage : Voltage;
			attribute current : Current;
		}
		attribute def ACExcitation {
			attribute frequency : Frequency;
			attribute amplitude : Voltage;
		}
		attribute def CapacitanceReading {
			attribute value : Capacitance;
		}
		attribute def MeasurementData {
			attribute thickness : Thickness;
			attribute dielectric : DielectricConstant;
			attribute proximity : Thickness;
		}

		port def PowerPort {
			ref attribute power : PowerSignal;
		}
		port def ExcitationPort {
			ref attribute excitation : ACExcitation;
		}
		port def CapacitancePort {
			ref attribute capacitance : CapacitanceReading;
		}
		port def DataPort {
			ref attribute data : MeasurementData;
		}

		action def 'Supply Power' {
			out power : PowerSignal;
		}
		action def 'Generate Signal' {
			in power : PowerSignal;
			out excitation : ACExcitation;
		}
		action def 'Measure Capacitance' {
			in excitation : ACExcitation;
			out capacitance : CapacitanceReading;
		}
		action def 'Validate Reading' {
			in capacitance : CapacitanceReading;
			out isValid : Boolean;
		}
		action def 'Process Data' {
			in capacitance : CapacitanceReading;
			out data : MeasurementData;
		}
		action def 'Recalibrate' {
			out signal : RecalibrateSignal;
		}
		action def 'Display Data' {
			in data : MeasurementData;
		}
		action def 'Initialize System';

		action def 'Continuous Measurement' {
			in power : PowerSignal;
			out data : MeasurementData;

			action 'generate signal' : 'Generate Signal' {
				in power = 'Continuous Measurement'::power;
				out excitation : ACExcitation;
			}
			flow 'generate signal'.excitation to 'measure capacitance'.excitation;

			action 'measure capacitance' : 'Measure Capacitance' {
				in excitation : ACExcitation;
				out capacitance : CapacitanceReading;
			}
			flow 'measure capacitance'.capacitance to 'validate reading'.capacitance;
			flow 'measure capacitance'.capacitance to 'process data'.capacitance;

			action 'validate reading' : 'Validate Reading' {
				in capacitance : CapacitanceReading;
				out isValid : Boolean;
			}

			action 'process data' : 'Process Data' {
				in capacitance : CapacitanceReading;
				out data : MeasurementData;
			}
			flow 'process data'.data to 'display data'.data;

			action 'display data' : 'Display Data' {
				in data : MeasurementData;
			}

			action 'recalibrate' : 'Recalibrate' {
				out signal : RecalibrateSignal;
			}

			first 'generate signal' then 'measure capacitance';
			first 'measure capacitance' then 'validate reading';
			first 'validate reading'
				if 'validate reading'.isValid
				then 'process data';
			first 'validate reading'
				if not 'validate reading'.isValid
				then 'recalibrate';
			first 'process data' then 'display data';
			first 'display data' then 'generate signal';
			first 'recalibrate' then 'generate signal';
		}

		state def 'System States' {
			entry; then Off;

			state Off;
			transition first Off
				accept PowerOn
				then Initializing;

			state Initializing {
				do action 'initialize system' : 'Initialize System';
			}
			transition first Initializing
				accept InitComplete
				then Standby;

			state Standby;
			transition first Standby
				accept StartMeasurement
				then Active;

			state Active {
				do action 'continuous measurement' : 'Continuous Measurement';
			}
			transition first Active
				accept StopMeasurement
				then Standby;

			transition first Initializing
				accept PowerOff
				then Off;
			transition first Standby
				accept PowerOff
				then Off;
			transition first Active
				accept PowerOff
				then Off;
		}

		part def PowerSupplyUnit {
			port powerOut : PowerPort;
			perform action 'supply power' : 'Supply Power';
		}
		part def OscillatorCircuit {
			port powerIn : PowerPort;
			port excitationOut : ExcitationPort;
			perform action 'generate signal' : 'Generate Signal';
		}
		part def ProbeSensor {
			port excitationIn : ExcitationPort;
			port capacitanceOut : CapacitancePort;
			perform action 'measure capacitance' : 'Measure Capacitance';
		}
		part def SignalProcessor {
			port powerIn : PowerPort;
			port capacitanceIn : CapacitancePort;
			port dataOut : DataPort;
			perform action 'validate reading' : 'Validate Reading';
			perform action 'process data' : 'Process Data';
			perform action 'recalibrate' : 'Recalibrate';
		}
		part def DisplayInterface {
			port dataIn : DataPort;
			perform action 'display data' : 'Display Data';
		}
		part def CapacitanceProbeSystem {
			part powerSupply : PowerSupplyUnit;
			part oscillator : OscillatorCircuit;
			part probe : ProbeSensor;
			part processor : SignalProcessor;
			part display : DisplayInterface;
			exhibit state 'system states' : 'System States';
		}

		requirement def 'Non-Contact Material Measurement' {
			doc /* The system shall determine a material's thickness, dielectric
			 * properties, or its proximity to the sensor without making
			 * physical contact. */
		}
	}

	package Usages {
		private import Definitions::*;

		part 'capacitance probe system' : CapacitanceProbeSystem {
			connect powerSupply.powerOut to oscillator.powerIn;
			connect powerSupply.powerOut to processor.powerIn;
			connect oscillator.excitationOut to probe.excitationIn;
			connect probe.capacitanceOut to processor.capacitanceIn;
			connect processor.dataOut to display.dataIn;
		}

		requirement 'non-contact measurement' : 'Non-Contact Material Measurement';
	}
}
