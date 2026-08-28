package 'Digital Humidity Sensor System' {
	private import ScalarValues::*;
	private import ISQ::*;
	import Definitions::*;

	package Definitions {
		attribute def HumidityValue :> ScalarValues::Real;
		attribute def TemperatureValue :> ScalarValues::Real;
		attribute def VoltageValue :> ScalarValues::Real;
		attribute def ResistanceValue :> ScalarValues::Real;
		attribute def DigitalCount :> ScalarValues::Integer;

		item def RegulatedPower {
			attribute supplyVoltage : VoltageValue;
		}
		item def ResistanceMeasurement {
			attribute resistance : ResistanceValue;
		}
		item def AnalogSignal {
			attribute voltage : VoltageValue;
		}
		item def DigitalSample {
			attribute counts : DigitalCount;
		}
		item def TemperatureData {
			attribute temp : TemperatureValue;
		}
		item def HumidityReading {
			attribute humidity : HumidityValue;
			attribute compensated : Boolean := true;
		}

		attribute def PowerOnSignal;
		attribute def InitCompleteSignal;
		attribute def StabilizationDoneSignal;
		attribute def SenseCompleteSignal;
		attribute def ConvertCompleteSignal;
		attribute def ProcessCompleteSignal;
		attribute def ReportCompleteSignal;
		attribute def IntervalElapsedSignal;
		attribute def ShutdownSignal;

		action def 'Provide Power';
		action def 'Initialize Sensor';
		action def 'Stabilize Sensor';
		action def 'Sense Humidity' {
			out resistance : ResistanceValue;
		}
		action def 'Convert Resistance' {
			in resistance : ResistanceValue;
			out analogVoltage : VoltageValue;
		}
		action def 'Digitize Signal' {
			in analogVoltage : VoltageValue;
			out counts : DigitalCount;
		}
		action def 'Measure Temperature' {
			out temp : TemperatureValue;
		}
		action def 'Process Data' {
			in counts : DigitalCount;
			in temp : TemperatureValue;
			out humidity : HumidityValue;
		}
		action def 'Report Reading' {
			in humidity : HumidityValue;
		}
		action def 'Wait Interval';

		part def PowerRegulator {
			attribute outputVoltage : VoltageValue;
			port powerOutPort {
				out supply : RegulatedPower;
			}
			perform action 'provide power': 'Provide Power';
		}

		part def Humistor {
			attribute nominalResistance : ResistanceValue;
			port powerPort {
				in supply : RegulatedPower;
			}
			port resistancePort {
				out resistance : ResistanceValue;
			}
			perform action 'sense humidity': 'Sense Humidity';
		}

		part def VoltageDividerCircuit {
			attribute fixedResistor : ResistanceValue;
			port powerPort {
				in supply : RegulatedPower;
			}
			port resistanceInPort {
				in resistance : ResistanceValue;
			}
			port analogOutPort {
				out analogVoltage : VoltageValue;
			}
			perform action 'convert resistance': 'Convert Resistance';
		}

		part def ADC {
			attribute resolutionBits : Integer;
			port analogInPort {
				in analogVoltage : VoltageValue;
			}
			port digitalOutPort {
				out counts : DigitalCount;
			}
			perform action 'digitize signal': 'Digitize Signal';
		}

		part def TemperatureSensor {
			port tempOutPort {
				out temp : TemperatureData;
			}
			perform action 'measure temperature': 'Measure Temperature';
		}

		part def SignalProcessor {
			attribute calibrationCoefficients : Real[0..*];
			port digitalInPort {
				in counts : DigitalCount;
			}
			port tempInPort {
				in temp : TemperatureData;
			}
			port humidityOutPort {
				out humidity : HumidityReading;
			}
			perform action 'process data': 'Process Data';
			perform action 'report reading': 'Report Reading';
		}

		part def ExternalMonitor {
			port monitorInPort {
				in humidity : HumidityReading;
			}
		}

		part def HumiditySensorSystem {
			port commandPort {
				in powerOn : PowerOnSignal;
				in shutdown : ShutdownSignal;
			}
			port readingPort {
				out humidity : HumidityReading;
			}
			part powerRegulator : PowerRegulator;
			part humistor : Humistor;
			part voltageDivider : VoltageDividerCircuit;
			part adc : ADC;
			part tempSensor : TemperatureSensor;
			part signalProcessor : SignalProcessor;
			exhibit state 'sensor states': 'Sensor States';
		}

		state def 'Sensor States';
	}

	package Usages {
		private import Definitions::*;

		action 'provide power': 'Provide Power';
		action 'initialize sensor': 'Initialize Sensor';
		action 'stabilize sensor': 'Stabilize Sensor';
		action 'sense humidity': 'Sense Humidity';
		action 'convert resistance': 'Convert Resistance';
		action 'digitize signal': 'Digitize Signal';
		action 'measure temperature': 'Measure Temperature';
		action 'process data': 'Process Data';
		action 'report reading': 'Report Reading';
		action 'wait interval': 'Wait Interval';

		part sensorSystem : HumiditySensorSystem {
			part :>> powerRegulator : PowerRegulator {
				attribute :>> outputVoltage : VoltageValue := 5.0;
			}
			part :>> humistor : Humistor {
				attribute :>> nominalResistance : ResistanceValue := 100000.0;
			}
			part :>> voltageDivider : VoltageDividerCircuit {
				attribute :>> fixedResistor : ResistanceValue := 10000.0;
			}
			part :>> adc : ADC {
				attribute :>> resolutionBits : Integer := 12;
			}
			part :>> tempSensor : TemperatureSensor;
			part :>> signalProcessor : SignalProcessor {
				attribute :>> calibrationCoefficients : Real[0..*] = (1.0, -0.02, 0.0001);
			}

			flow powerToHumistor of RegulatedPower
				from powerRegulator.powerOutPort.supply to humistor.powerPort.supply;
			flow powerToDivider of RegulatedPower
				from powerRegulator.powerOutPort.supply to voltageDivider.powerPort.supply;
			flow resistanceFlow of ResistanceValue
				from humistor.resistancePort.resistance to voltageDivider.resistanceInPort.resistance;
			flow analogFlow of VoltageValue
				from voltageDivider.analogOutPort.analogVoltage to adc.analogInPort.analogVoltage;
			flow digitalFlow of DigitalCount
				from adc.digitalOutPort.counts to signalProcessor.digitalInPort.counts;
			flow tempFlow of TemperatureData
				from tempSensor.tempOutPort.temp to signalProcessor.tempInPort.temp;
			flow outputFlow of HumidityReading
				from signalProcessor.humidityOutPort.humidity to readingPort.humidity;
		}

		state 'sensor states': 'Sensor States' {
			entry; then powered;
			state powered {
				entry 'provide power';
				do 'initialize sensor';
			}
			accept InitCompleteSignal
				then stabilizing;
			state stabilizing {
				entry 'stabilize sensor';
			}
			accept StabilizationDoneSignal
				then sensing;
			state sensing {
				entry 'sense humidity';
			}
			accept SenseCompleteSignal
				then converting;
			state converting {
				entry 'convert resistance';
				do 'digitize signal';
			}
			accept ConvertCompleteSignal
				then processing;
			state processing {
				entry 'process data';
			}
			accept ProcessCompleteSignal
				then reporting;
			state reporting {
				entry 'report reading';
			}
			accept ReportCompleteSignal
				then waiting;
			state waiting {
				entry 'wait interval';
			}
			accept IntervalElapsedSignal
				then sensing;
			accept ShutdownSignal
				then powered;
		}

		part externalMonitor : ExternalMonitor;

		interface readingInterface connect sensorSystem.readingPort to externalMonitor.monitorInPort;
	}

	package Requirements {
		private import Definitions::*;
		private import Usages::*;

		requirement def HumidityAccuracyRequirement {
			doc /* The system shall report relative humidity within ±2 %RH after temperature compensation. */
			subject sensor : HumiditySensorSystem;
			attribute maxError : HumidityValue := 2.0;
			requirement {
				subject s :>> sensor;
				doc /* |reported.humidity - trueHumidity| <= maxError */
			}
		}

		requirement def StabilizationRequirement {
			doc /* The sensor shall stabilize within 5 seconds of power-up before sensing begins. */
			subject sensor : HumiditySensorSystem;
			attribute maxStabilizationTime : Real := 5.0;
			requirement {
				subject s :>> sensor;
			}
		}

		requirement def ContinuousSensingRequirement {
			doc /* The system shall continuously cycle through sense, convert, process, report, and wait. */
			subject sensor : HumiditySensorSystem;
			requirement {
				subject s :>> sensor;
			}
		}

		requirement def TemperatureCompensationRequirement {
			doc /* The humidity reading shall be compensated using ambient temperature data. */
			subject sensor : HumiditySensorSystem;
			requirement {
				subject s :>> sensor;
			}
		}

		requirement humAccuracyReq : HumidityAccuracyRequirement {
			subject :>> sensor :>> sensorSystem;
		}
		requirement stabReq : StabilizationRequirement {
			subject :>> sensor :>> sensorSystem;
		}
		requirement continuousReq : ContinuousSensingRequirement {
			subject :>> sensor :>> sensorSystem;
		}
		requirement tempCompReq : TemperatureCompensationRequirement {
			subject :>> sensor :>> sensorSystem;
		}
	}
}
