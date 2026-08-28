package ThermocoupleTemperatureMeasurementSystem {
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		private import ISQ::*;
		private import ScalarValues::*;

		alias Temperature for ISQ::ThermodynamicTemperatureValue;
		alias Voltage for ISQ::ElectricPotentialDifferenceValue;
		alias DigitalValue for ScalarValues::Integer;

		attribute def NISTCalibrationTable;
		attribute def StartMeasurement;
		attribute def MeasurementComplete;
		attribute def ErrorDetected;
		attribute def Reset;

		port def VoltagePort {
			attribute voltage : Voltage;
		}
		port def TemperaturePort {
			attribute temperature : Temperature;
		}
		port def DigitalPort {
			attribute digitalValue : DigitalValue;
		}

		part def ChromelWire;
		part def AlumelWire;
		part def HotJunction;
		part def ColdJunction;

		part def ThermocoupleSensor {
			part chromelWire : ChromelWire;
			part alumelWire : AlumelWire;
			part hotJunction : HotJunction;
			part coldJunction : ColdJunction;
			port rawVoltagePort : VoltagePort;
		}

		part def ColdJunctionCompensator {
			port rawVoltagePort : VoltagePort;
			port ambientTemperaturePort : TemperaturePort;
			port compensatedVoltagePort : VoltagePort;
		}

		part def SignalAmplifier {
			port inputVoltagePort : VoltagePort;
			port amplifiedVoltagePort : VoltagePort;
		}

		part def AnalogToDigitalConverter {
			port analogInputPort : VoltagePort;
			port digitalOutputPort : DigitalPort;
		}

		part def TemperatureCalculator {
			port digitalInputPort : DigitalPort;
			port referenceTemperaturePort : TemperaturePort;
			attribute calibrationTable : NISTCalibrationTable;
			port temperatureOutputPort : TemperaturePort;
		}

		action def 'Generate Seebeck Voltage' {
			out rawVoltage : Voltage;
		}
		action def 'Compensate Cold Junction' {
			in rawVoltage : Voltage;
			out compensatedVoltage : Voltage;
			out ambientTemperature : Temperature;
		}
		action def 'Amplify Signal' {
			in inputVoltage : Voltage;
			out amplifiedVoltage : Voltage;
		}
		action def 'Convert to Digital' {
			in analogInput : Voltage;
			out digitalOutput : DigitalValue;
		}
		action def 'Calculate Temperature' {
			in digitalInput : DigitalValue;
			in referenceTemperature : Temperature;
			in calibrationTable : NISTCalibrationTable;
			out temperatureReading : Temperature;
		}
		action def 'Measure Temperature' {
			out temperatureReading : Temperature;
		}

		state machine def MeasurementStateMachine {
			state idle;
			state measuring;
			state fault;
			transition startMeasure from idle to measuring;
			transition completeMeasure from measuring to idle;
			transition detectError from measuring to fault;
			transition resetSystem from fault to idle;
		}

		part def TemperatureMeasurementSystem {
			part thermocouple : ThermocoupleSensor;
			part coldJunctionCompensator : ColdJunctionCompensator;
			part signalAmplifier : SignalAmplifier;
			part adc : AnalogToDigitalConverter;
			part temperatureCalculator : TemperatureCalculator;
			port temperatureOutput : TemperaturePort;

			connection thermocoupleToCompensator
				connect thermocouple.rawVoltagePort to coldJunctionCompensator.rawVoltagePort;
			connection compensatorToAmplifier
				connect coldJunctionCompensator.compensatedVoltagePort to signalAmplifier.inputVoltagePort;
			connection amplifierToAdc
				connect signalAmplifier.amplifiedVoltagePort to adc.analogInputPort;
			connection adcToCalculator
				connect adc.digitalOutputPort to temperatureCalculator.digitalInputPort;
			connection compensatorToCalculatorTemp
				connect coldJunctionCompensator.ambientTemperaturePort to temperatureCalculator.referenceTemperaturePort;
			connection calculatorToOutput
				connect temperatureCalculator.temperatureOutputPort to temperatureOutput;

			perform action measureTemperature : 'Measure Temperature' {
				out temperatureReading : Temperature;
				action generateVoltage : 'Generate Seebeck Voltage';
				flow generateVoltage.rawVoltage to compensate.rawVoltage;
				action compensate : 'Compensate Cold Junction';
				flow compensate.compensatedVoltage to amplify.inputVoltage;
				action amplify : 'Amplify Signal';
				flow amplify.amplifiedVoltage to convert.analogInput;
				action convert : 'Convert to Digital';
				flow convert.digitalOutput to calculate.digitalInput;
				flow compensate.ambientTemperature to calculate.referenceTemperature;
				action calculate : 'Calculate Temperature';
				bind calculate.calibrationTable = temperatureCalculator.calibrationTable;
				bind temperatureReading = calculate.temperatureReading;
				first start;
				then generateVoltage;
				then compensate;
				then amplify;
				then convert;
				then calculate;
			}

			state machine measurementState : MeasurementStateMachine;
		}

		requirement def AccurateTemperatureMeasurement {
			doc /* The system shall provide accurate temperature measurements using a Type K thermocouple and cold junction compensation. */
		}
		requirement def ColdJunctionCompensation {
			doc /* The system shall measure ambient temperature at the connection point and adjust raw thermocouple voltage for cold junction variations. */
		}
		requirement def SignalConditioning {
			doc /* The system shall amplify the millivolt thermocouple signal, convert it to digital, and compute temperature using NIST calibration data. */
		}
		requirement def OperationalStates {
			doc /* The system shall support idle, measuring, and fault states with appropriate transitions. */
		}
	}

	package Usages {
		requirement accurateTemp : AccurateTemperatureMeasurement;
		requirement coldJunctionComp : ColdJunctionCompensation;
		requirement signalCond : SignalConditioning;
		requirement opStates : OperationalStates;
		part 'temperature measurement system' : TemperatureMeasurementSystem;
	}
}
