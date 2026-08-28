package 'Tilt Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def VoltageValue :> Real;
	attribute def AngleValue :> Real;
	attribute def TemperatureValue :> Real;
	attribute def DurationValue :> Real;
	attribute def QualityValue :> Real;

	attribute def PowerOnSignal;
	attribute def PowerOffSignal;
	attribute def MeasureRequestSignal;
	attribute def MeasurementCompleteSignal;
	attribute def ErrorSignal;
	attribute def ResetSignal;

	item def RawSensorData {
		attribute pitchVoltage : VoltageValue;
		attribute rollVoltage : VoltageValue;
		attribute temperature : TemperatureValue;
	}

	item def CalibrationCoefficients {
		attribute pitchSlope : Real;
		attribute pitchOffset : Real;
		attribute rollSlope : Real;
		attribute rollOffset : Real;
	}

	item def TiltMeasurement {
		attribute pitch : AngleValue;
		attribute roll : AngleValue;
		attribute timestamp : DurationValue;
		attribute quality : QualityValue;
	}

	action def AcquireRawData {
		out raw : RawSensorData;
	}

	action def ConvertToAngles {
		in raw : RawSensorData;
		out pitchEst : AngleValue;
		out rollEst : AngleValue;
	}

	action def ApplyCalibration {
		in pitchEst : AngleValue;
		in rollEst : AngleValue;
		in temp : TemperatureValue;
		in coefficients : CalibrationCoefficients;
		out pitchCal : AngleValue;
		out rollCal : AngleValue;
	}

	action def SmoothData {
		in pitchCal : AngleValue;
		in rollCal : AngleValue;
		out pitchFilt : AngleValue;
		out rollFilt : AngleValue;
	}

	action def ValidateAndPackage {
		in pitchFilt : AngleValue;
		in rollFilt : AngleValue;
		out measurement : TiltMeasurement;
	}

	action def ProcessMeasurement {
		in raw : RawSensorData;
		in coefficients : CalibrationCoefficients;
		out measurement : TiltMeasurement;

		action convert : ConvertToAngles {
			in raw = ProcessMeasurement::raw;
			out pitchEst;
			out rollEst;
		}

		action calibrate : ApplyCalibration {
			in pitchEst;
			in rollEst;
			in temp = ProcessMeasurement::raw.temperature;
			in coefficients = ProcessMeasurement::coefficients;
			out pitchCal;
			out rollCal;
		}

		action smooth : SmoothData {
			in pitchCal;
			in rollCal;
			out pitchFilt;
			out rollFilt;
		}

		action validate : ValidateAndPackage {
			in pitchFilt;
			in rollFilt;
			out measurement = ProcessMeasurement::measurement;
		}

		flow from convert.pitchEst to calibrate.pitchEst;
		flow from convert.rollEst to calibrate.rollEst;
		succession first convert then calibrate;

		flow from calibrate.pitchCal to smooth.pitchCal;
		flow from calibrate.rollCal to smooth.rollCal;
		succession first calibrate then smooth;

		flow from smooth.pitchFilt to validate.pitchFilt;
		flow from smooth.rollFilt to validate.rollFilt;
		succession first smooth then validate;
	}

	action def MeasureTilt {
		in coefficients : CalibrationCoefficients;
		out measurement : TiltMeasurement;

		action acquire : AcquireRawData {
			out raw;
		}

		action process : ProcessMeasurement {
			in raw;
			in coefficients = MeasureTilt::coefficients;
			out measurement = MeasureTilt::measurement;
		}

		flow from acquire.raw to process.raw;
		succession first acquire then process;
	}

	action def InitializeSensor;
	action def InitializeProcessor;

	action def InitializeSystem {
		action initSensor : InitializeSensor;
		action initProcessor : InitializeProcessor;
		succession first initSensor then initProcessor;
	}

	part def TiltSensor {
		port powerIn : VoltageValue;
		port rawOut : RawSensorData;
		perform action acquire : AcquireRawData;
	}

	part def SignalProcessor {
		port rawIn : RawSensorData;
		port measurementOut : TiltMeasurement;
		port commandIn : MeasureRequestSignal;
		port statusOut : MeasurementCompleteSignal;
		attribute calibration : CalibrationCoefficients;
		perform action process : ProcessMeasurement;
	}

	state def TiltSensingUnitStates {
		in sensor : TiltSensor;
		in processor : SignalProcessor;
		out measurementOut : TiltMeasurement;

		entry; then off;

		state off;
		accept PowerOnSignal then initializing;

		state initializing {
			entry action init : InitializeSystem;
		}
		succession first initializing then standby;

		state standby;
		accept MeasureRequestSignal then measuring;
		accept PowerOffSignal then off;
		accept ErrorSignal then error;

		state measuring {
			entry action measure : MeasureTilt {
				in coefficients = processor.calibration;
				out measurement = measurementOut;
			}
		}
		succession first measuring then standby;

		state error;
		accept ResetSignal then initializing;
		accept PowerOffSignal then off;
	}

	part def TiltSensingUnit {
		attribute pitch : AngleValue;
		attribute roll : AngleValue;
		attribute measurementError : AngleValue;
		attribute responseTime : DurationValue;
		attribute operatingTemp : TemperatureValue;

		port powerIn : VoltageValue;
		port commandIn : MeasureRequestSignal;
		port measurementOut : TiltMeasurement;
		port statusOut : MeasurementCompleteSignal;

		part tiltSensor : TiltSensor;
		part signalProcessor : SignalProcessor;

		connect powerIn to tiltSensor.powerIn;
		connect tiltSensor.rawOut to signalProcessor.rawIn;
		connect signalProcessor.measurementOut to measurementOut;
		connect commandIn to signalProcessor.commandIn;
		connect signalProcessor.statusOut to statusOut;

		exhibit state unitStates : TiltSensingUnitStates {
			in sensor = tiltSensor;
			in processor = signalProcessor;
			out measurementOut = TiltSensingUnit::measurementOut;
		}
	}

	requirement def AccuracyRequirement {
		subject tiltUnit : TiltSensingUnit;
		doc /* The unit shall measure pitch and roll angles with an accuracy of within 0.5 degrees. */
		constraint { tiltUnit.measurementError < 0.5 }
	}

	requirement def MeasurementRangeRequirement {
		subject tiltUnit : TiltSensingUnit;
		doc /* The unit shall measure pitch and roll angles in the range of -90 to +90 degrees. */
		constraint { tiltUnit.pitch >= -90 and tiltUnit.pitch <= 90 }
		constraint { tiltUnit.roll >= -90 and tiltUnit.roll <= 90 }
	}

	requirement def ResponseTimeRequirement {
		subject tiltUnit : TiltSensingUnit;
		doc /* The unit shall provide a measurement within 0.1 seconds of receiving a request. */
		constraint { tiltUnit.responseTime < 0.1 }
	}

	requirement def TemperatureRangeRequirement {
		subject tiltUnit : TiltSensingUnit;
		doc /* The unit shall operate reliably from -40 to +85 degrees Celsius. */
		constraint { tiltUnit.operatingTemp >= -40 and tiltUnit.operatingTemp <= 85 }
	}
}
