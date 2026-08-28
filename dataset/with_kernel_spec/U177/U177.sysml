package DigitalInclinometer {
	private import ScalarValues::*;
	private import ISQ::*;
	private import ISQ::LengthValue;
	private import ISQ::AngleValue;

	attribute def VoltageValue :> Real;
	attribute def ConfidenceValue :> Real;
	attribute def ToleranceValue :> AngleValue;

	attribute def PowerOnSignal;
	attribute def CalibrationCommand {
		attribute offset : AngleValue;
		attribute scale : Real;
	}
	attribute def StartMeasurementSignal;

	item def MeasurementData {
		attribute angle : AngleValue;
		attribute isLevel : Boolean;
		attribute confidence : ConfidenceValue;
	}

	port def PowerPort {
		in voltage : VoltageValue;
	}
	port def CalibrationPort {
		in command : CalibrationCommand;
	}
	port def MeasurementOutputPort {
		out measurement : MeasurementData;
	}

	part def BubbleVial {
		attribute length : LengthValue;
		attribute bubblePosition : LengthValue;
	}

	part def OpticalSensor {
		attribute resolution : LengthValue;
		out position : LengthValue;
		action detectPosition {
			in vial : BubbleVial;
			out pos : LengthValue;
			assign pos := vial.bubblePosition;
		}
	}

	part def SignalConditioner {
		in rawSignal : LengthValue;
		out conditionedSignal : LengthValue;
		action condition {
			in raw : LengthValue;
			out conditioned : LengthValue;
			assign conditioned := raw;
		}
	}

	part def AnalogDigitalConverter {
		in analogSignal : LengthValue;
		out digitalSignal : Integer;
		action convert {
			in analog : LengthValue;
			out digital : Integer;
			assign digital := 0;
		}
	}

	part def ProcessingUnit {
		in digitalPosition : Integer;
		in vialLength : LengthValue;
		in calibrationOffset : AngleValue;
		in calibrationScale : Real;
		in tolerance : ToleranceValue;
		out measurement : MeasurementData;

		attribute currentAngle : AngleValue;
		attribute currentIsLevel : Boolean;
		attribute currentConfidence : ConfidenceValue;

		calc def calculateAngle {
			in pos : Integer;
			in length : LengthValue;
			in offset : AngleValue;
			in scale : Real;
			return angle : AngleValue;
		}

		calc def evaluateLevel {
			in angle : AngleValue;
			in tol : ToleranceValue;
			return isLevel : Boolean;
		}

		calc def calculateConfidence {
			in pos : Integer;
			return confidence : ConfidenceValue;
		}

		action processMeasurement {
			in pos : Integer;
			in length : LengthValue;
			in offset : AngleValue;
			in scale : Real;
			in tol : ToleranceValue;
			out result : MeasurementData;
			assign currentAngle := calculateAngle(pos, length, offset, scale);
			assign currentIsLevel := evaluateLevel(currentAngle, tol);
			assign currentConfidence := calculateConfidence(pos);
			assign result.angle := currentAngle;
			assign result.isLevel := currentIsLevel;
			assign result.confidence := currentConfidence;
		}
	}

	part def PowerSupply {
		in inputVoltage : VoltageValue;
		out regulatedVoltage : VoltageValue;
		attribute nominalOutput : VoltageValue := 3.3;
		action regulate {
			in inV : VoltageValue;
			out outV : VoltageValue;
			assign outV := nominalOutput;
		}
	}

	part def Housing {
		attribute material : String := "Anodized Aluminum";
		attribute ipRating : String := "IP68";
	}

	part def InclinometerUnit {
		port powerIn : PowerPort;
		port calibIn : CalibrationPort;
		port dataOut : MeasurementOutputPort;

		part housing : Housing;
		part powerSupply : PowerSupply;
		part bubbleVial : BubbleVial;
		part opticalSensor : OpticalSensor;
		part signalConditioner : SignalConditioner;
		part adc : AnalogDigitalConverter;
		part processingUnit : ProcessingUnit;

		attribute tolerance : ToleranceValue := 0.01;

		connect powerIn to powerSupply;
		connect powerSupply to opticalSensor;
		connect powerSupply to signalConditioner;
		connect powerSupply to adc;
		connect powerSupply to processingUnit;
		connect opticalSensor to signalConditioner;
		connect signalConditioner to adc;
		connect adc to processingUnit;
		connect calibIn to processingUnit;
		connect processingUnit to dataOut;

		exhibit state lifecycle {
			entry; then off;
			state off;
			accept PowerOnSignal
				then calibrating;
			state calibrating {
				entry action performCalibration {
					assign processingUnit.calibrationOffset := 0;
					assign processingUnit.calibrationScale := 1.0;
				}
			}
			accept CalibrationCommand
				then ready;
			state ready;
			accept StartMeasurementSignal
				then measuring;
			state measuring {
				do opticalSensor.detectPosition { in vial = bubbleVial; }
			}
			then processing;
			state processing {
				do processingUnit.processMeasurement {
					in pos = adc.digitalSignal;
					in length = bubbleVial.length;
					in offset = processingUnit.calibrationOffset;
					in scale = processingUnit.calibrationScale;
					in tol = tolerance;
					out result = processingUnit.measurement;
				}
			}
			then transmitting;
			state transmitting {
				do action transmitData {
					out data : MeasurementData;
					assign data.angle := processingUnit.currentAngle;
					assign data.isLevel := processingUnit.currentIsLevel;
					assign data.confidence := processingUnit.currentConfidence;
				}
			}
			then ready;
		}
	}

	requirement def AccuracyRequirement {
		attribute maxError : AngleValue := 0.01;
		subject inclinometer : InclinometerUnit;
		require {
			inclinometer.processingUnit.currentAngle <= maxError
			implies inclinometer.processingUnit.currentIsLevel == true;
		}
	}

	requirement def EnvironmentalProtectionRequirement {
		subject enclosure : Housing;
		require { enclosure.material == "Anodized Aluminum"; }
		require { enclosure.ipRating == "IP68"; }
	}

	requirement def LifecycleRequirement {
		subject inclinometer : InclinometerUnit;
		require {
			inclinometer.lifecycle.off.oclIsStateActive() or
			inclinometer.lifecycle.calibrating.oclIsStateActive() or
			inclinometer.lifecycle.ready.oclIsStateActive() or
			inclinometer.lifecycle.measuring.oclIsStateActive() or
			inclinometer.lifecycle.processing.oclIsStateActive() or
			inclinometer.lifecycle.transmitting.oclIsStateActive();
		}
	}

	part inclinometer : InclinometerUnit {
		satisfy AccuracyRequirement { subject inclinometer = inclinometer; }
		satisfy EnvironmentalProtectionRequirement { subject enclosure = housing; }
		satisfy LifecycleRequirement { subject inclinometer = inclinometer; }
	}
}
