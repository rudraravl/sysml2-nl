package MagneticFieldSensorSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def MagneticFluxDensityValue :> ScalarValues::Real;
	attribute def ResistanceValue :> ScalarValues::Real;
	attribute def VoltageValue :> ScalarValues::Real;
	attribute def CurrentValue :> ScalarValues::Real;

	item def MagneticField {
		attribute fluxDensity : MagneticFluxDensityValue;
	}

	item def AnalogSignal {
		attribute voltage : VoltageValue;
	}

	item def DigitalReading {
		attribute rawValue : Integer;
	}

	item def CalibrationData {
		attribute offset : Real;
		attribute gain : Real;
		attribute linearizationCoefficients : Real[*];
	}

	item def MeasurementResult {
		attribute fieldStrength : MagneticFluxDensityValue;
		attribute timestamp : Integer;
		attribute quality : Real;
	}

	attribute def PowerOnSignal;
	attribute def InitCompleteSignal;
	attribute def SelfTestPassSignal;
	attribute def SelfTestFailSignal;
	attribute def CalibrationCompleteSignal;
	attribute def MeasurementTriggerSignal;
	attribute def MeasurementCompleteSignal;
	attribute def ShutdownSignal;

	port def BiasPowerPort {
		out attribute voltage : VoltageValue;
		out attribute current : CurrentValue;
	}

	port def AnalogSignalOutPort {
		out item signal : AnalogSignal;
	}

	port def AnalogSignalInPort {
		in item signal : AnalogSignal;
	}

	port def DigitalSignalOutPort {
		out item signal : DigitalReading;
	}

	port def DigitalSignalInPort {
		in item signal : DigitalReading;
	}

	port def DataOutputPort {
		out item result : MeasurementResult;
	}

	action def InitializeSystem;

	action def MeasureField {
		in item field : MagneticField;
		in attribute biasVoltage : VoltageValue;
		in attribute biasCurrent : CurrentValue;
		out item signal : AnalogSignal;
	}

	action def AmplifyAndFilter {
		in item inputSignal : AnalogSignal;
		out item outputSignal : AnalogSignal;
	}

	action def CompensateForTemperature {
		in item inputSignal : AnalogSignal;
		in attribute temperature : TemperatureValue;
		out item outputSignal : AnalogSignal;
	}

	action def ConvertToDigital {
		in item analogSignal : AnalogSignal;
		out item digitalSignal : DigitalReading;
	}

	action def ProcessMeasurement {
		in item digitalSignal : DigitalReading;
		in ref item calibration : CalibrationData;
		out item result : MeasurementResult;
	}

	action def PerformSelfTest;

	action def PerformCalibration {
		out ref item calibrationData : CalibrationData;
	}

	action def SenseTemperature {
		out attribute temperature : TemperatureValue;
	}

	action def MeasurementCycle {
		in item field : MagneticField;
		in attribute biasVoltage : VoltageValue;
		in attribute biasCurrent : CurrentValue;
		in ref item calibration : CalibrationData;
		out item result : MeasurementResult;

		action senseTemp : SenseTemperature;
		action measure : MeasureField {
			in item field = MeasurementCycle::field;
			in attribute biasVoltage = MeasurementCycle::biasVoltage;
			in attribute biasCurrent = MeasurementCycle::biasCurrent;
		}
		action amplify : AmplifyAndFilter;
		action compensate : CompensateForTemperature;
		action convert : ConvertToDigital;
		action process : ProcessMeasurement {
			in ref item calibration = MeasurementCycle::calibration;
			out item result = MeasurementCycle::result;
		}
		
		flow measure.signal to amplify.inputSignal;
		flow amplify.outputSignal to compensate.inputSignal;
		flow senseTemp.temperature to compensate.temperature;
		flow compensate.outputSignal to convert.analogSignal;
		flow convert.digitalSignal to process.digitalSignal;
	}

	part def MagnetoresistiveElement {
		attribute baseResistance : ResistanceValue;
		attribute sensitivity : Real;
		attribute currentResistance : ResistanceValue;

		port biasInput : ~BiasPowerPort;
		port signalOutput : AnalogSignalOutPort;

		perform action measureField : MeasureField;
	}

	part def BiasingCircuit {
		attribute outputVoltage : VoltageValue;
		attribute outputCurrent : CurrentValue;

		port powerOutput : BiasPowerPort;
		
		bind powerOutput.voltage = outputVoltage;
		bind powerOutput.current = outputCurrent;
	}

	part def SignalConditioner {
		attribute gain : Real;
		attribute filterCutoff : Real;

		port signalInput : AnalogSignalInPort;
		port signalOutput : AnalogSignalOutPort;

		perform action amplifyAndFilter : AmplifyAndFilter;
		bind amplifyAndFilter.inputSignal = signalInput.signal;
		bind amplifyAndFilter.outputSignal = signalOutput.signal;
	}

	part def TemperatureCompensator {
		attribute temperatureCoefficient : Real;
		attribute referenceTemperature : TemperatureValue;
		attribute currentTemperature : TemperatureValue;

		port signalInput : AnalogSignalInPort;
		port signalOutput : AnalogSignalOutPort;

		perform action compensateForTemperature : CompensateForTemperature;
		perform action senseTemperature : SenseTemperature;
		bind compensateForTemperature.inputSignal = signalInput.signal;
		bind compensateForTemperature.outputSignal = signalOutput.signal;
		bind compensateForTemperature.temperature = senseTemperature.temperature;
		bind senseTemperature.temperature = currentTemperature;
	}

	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute samplingRate : Real;

		port analogInput : AnalogSignalInPort;
		port digitalOutput : DigitalSignalOutPort;

		perform action convertToDigital : ConvertToDigital;
		bind convertToDigital.analogSignal = analogInput.signal;
		bind convertToDigital.digitalSignal = digitalOutput.signal;
	}

	part def DataProcessor {
		ref item calibrationData : CalibrationData;

		port digitalInput : DigitalSignalInPort;
		port dataOutput : DataOutputPort;

		perform action processMeasurement : ProcessMeasurement;
		bind processMeasurement.digitalSignal = digitalInput.signal;
		bind processMeasurement.calibration = calibrationData;
		bind processMeasurement.result = dataOutput.result;
	}

	part def MagneticFieldSensor {
		ref item magneticField : MagneticField;
		ref item calibrationData : CalibrationData;

		port outputPort : DataOutputPort;

		part magnetoresistiveElement : MagnetoresistiveElement;
		part biasingCircuit : BiasingCircuit;
		part signalConditioner : SignalConditioner;
		part temperatureCompensator : TemperatureCompensator;
		part adc : AnalogToDigitalConverter;
		part dataProcessor : DataProcessor;

		bind dataProcessor.calibrationData = calibrationData;

		flow biasingCircuit.powerOutput to magnetoresistiveElement.biasInput;
		flow magnetoresistiveElement.signalOutput to signalConditioner.signalInput;
		flow signalConditioner.signalOutput to temperatureCompensator.signalInput;
		flow temperatureCompensator.signalOutput to adc.analogInput;
		flow adc.digitalOutput to dataProcessor.digitalInput;
		flow dataProcessor.dataOutput to outputPort;

		exhibit state sensorStates : SensorStates;
	}

	state def SensorStates;

	state sensorStates : SensorStates {
		in sensor : MagneticFieldSensor;

		entry; then poweredOff;

		state poweredOff;
		accept PowerOnSignal
			then initializing;

		state initializing {
			entry action initialize : InitializeSystem;
		}
		accept InitCompleteSignal
			then selfTest;

		state selfTest {
			entry action performSelfTest : PerformSelfTest;
		}
		accept SelfTestPassSignal
			then calibrating;
		accept SelfTestFailSignal
			then poweredOff;

		state calibrating {
			entry action performCalibration : PerformCalibration {
				out ref item calibrationData = sensor.calibrationData;
			}
		}
		accept CalibrationCompleteSignal
			then ready;

		state ready;
		accept MeasurementTriggerSignal
			then activeMeasurement;
		accept ShutdownSignal
			then poweredOff;

		state activeMeasurement {
			entry action measurementCycle : MeasurementCycle {
				in item field = sensor.magneticField;
				in attribute biasVoltage = sensor.biasingCircuit.outputVoltage;
				in attribute biasCurrent = sensor.biasingCircuit.outputCurrent;
				in ref item calibration = sensor.calibrationData;
				out item result = sensor.outputPort.result;
			}
		}
		accept MeasurementCompleteSignal
			then ready;
	}

	package Requirements {
		requirement def MeasurementAccuracy {
			attribute requiredAccuracy : MagneticFluxDensityValue = 0.001;
			doc /* The sensor system shall measure magnetic field strength with an accuracy of at least 0.001 T. */
		}

		requirement def TemperatureCompensation {
			attribute minOperatingTemp : TemperatureValue = 233.15;
			attribute maxOperatingTemp : TemperatureValue = 358.15;
			doc /* The system shall compensate for temperature variations from -40C to +85C to maintain measurement accuracy. */
		}

		requirement def SignalIntegrity {
			attribute minGain : Real = 100.0;
			doc /* The signal conditioner shall amplify the sensor signal by at least 100x and filter noise. */
		}

		requirement def StartupSequence {
			doc /* The system shall perform initialization, self-test, and calibration before entering measurement mode. */
		}

		requirement def ContinuousMeasurement {
			doc /* The system shall continuously cycle between ready and active measurement states during operation. */
		}
	}
}
