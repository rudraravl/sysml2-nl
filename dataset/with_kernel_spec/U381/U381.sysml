package SensitiveSkinSystem {
	private import ScalarValues::*;

	attribute def Pressure :> Real {
		attribute unit : String = "Pa";
	}
	attribute def Temperature :> Real {
		attribute unit : String = "degC";
	}
	attribute def Force :> Real {
		attribute unit : String = "N";
	}
	attribute def ContactArea :> Real {
		attribute unit : String = "m2";
	}
	attribute def ResponseTime :> Real {
		attribute unit : String = "ms";
	}

	attribute def GridRow :> Integer;
	attribute def GridCol :> Integer;

	item def CellLocation {
		attribute row : GridRow;
		attribute col : GridCol;
	}

	item def RawTouchData {
		attribute location : CellLocation;
		attribute pressure : Pressure;
		attribute temperature : Temperature;
	}

	item def ProcessedTouchInfo {
		attribute contactMade : Boolean;
		attribute totalForce : Force;
		attribute contactArea : ContactArea;
		attribute surfaceTemperature : Temperature;
		attribute location : CellLocation;
	}

	enum def AlertLevel {
		none;
		warning;
		critical;
	}

	item def ResponseSignal {
		attribute alertLevel : AlertLevel;
		attribute location : CellLocation;
		attribute timestamp : Real;
	}

	attribute def PowerOn;
	attribute def PowerOff;
	attribute def TouchDetected;
	attribute def ThresholdExceeded;
	attribute def AlertAcknowledged;

	port def RawDataOut {
		out raw : RawTouchData;
	}

	port def RawDataIn {
		in raw : RawTouchData;
	}

	port def ProcessedDataOut {
		out processed : ProcessedTouchInfo;
	}

	port def ProcessedDataIn {
		in processed : ProcessedTouchInfo;
	}

	port def ResponseSignalOut {
		out signal : ResponseSignal;
	}

	port def PowerOut {
		out power : Real;
	}

	port def PowerIn {
		in power : Real;
	}

	part def TactileSensorCell {
		attribute location : CellLocation;
		attribute pressureReading : Pressure;
		attribute temperatureReading : Temperature;
		port rawOut : RawDataOut;
		action measure {
			out data : RawTouchData;
		}
	}

	part def SensorArray {
		part cells : TactileSensorCell[64];
		port arrayOut : RawDataOut;
		action aggregate {
			out data : RawTouchData;
		}
	}

	part def SignalProcessingUnit {
		port rawIn : RawDataIn;
		port processedOut : ProcessedDataOut;
		port powerIn : PowerIn;
		attribute noiseThreshold : Pressure = 0.5;
		action filterNoise {
			in raw : RawTouchData;
			out filtered : RawTouchData;
		}
		action analyzeTouch {
			in filtered : RawTouchData;
			out info : ProcessedTouchInfo;
		}
		action processTouch {
			in raw : RawTouchData;
			out info : ProcessedTouchInfo;
			action f : filterNoise {
				in raw = raw;
			}
			then a;
			action a : analyzeTouch {
				in filtered = f.filtered;
				out info = info;
			}
		}
	}

	part def ResponseController {
		port processedIn : ProcessedDataIn;
		port responseOut : ResponseSignalOut;
		port powerIn : PowerIn;
		attribute maxForceThreshold : Force = 50.0;
		attribute maxTemperatureThreshold : Temperature = 60.0;
		attribute alertLevel : AlertLevel = AlertLevel::none;
		action evaluateThresholds {
			in info : ProcessedTouchInfo;
			out signal : ResponseSignal;
		}
	}

	part def PowerSupply {
		port powerOut : PowerOut;
		attribute voltage : Real = 5.0;
		attribute maxCurrent : Real = 2.0;
	}

	part def SiliconeSubstrate {
		attribute material : String = "Flexible Silicone";
		attribute thickness : Real = 2.0;
		attribute minOperatingTemp : Temperature = -20.0;
		attribute maxOperatingTemp : Temperature = 100.0;
		part sensorArray : SensorArray;
	}

	state def SkinOperationalStates {
		in skinPart : SiliconeSubstrate;
		in procPart : SignalProcessingUnit;
		in ctrlPart : ResponseController;
		entry; then monitoring;

		state monitoring {
			doc /* Continuously monitoring sensor array for touch events. */
			do action pollSensors;
		}
		accept TouchDetected then processing;

		state processing {
			doc /* Signal processing unit filters and analyzes touch data. */
			do action runProcessing;
		}
		accept ThresholdExceeded then evaluating;

		state evaluating {
			doc /* Response controller evaluates thresholds. */
			do action runEvaluation;
		}
		accept ThresholdExceeded then alerting;
		accept AlertAcknowledged then monitoring;

		state alerting {
			doc /* Alert state: response signal has been generated. */
			do send new ResponseSignal to ctrlPart;
		}
		accept AlertAcknowledged then monitoring;

		accept PowerOff then off;
		state off;
	}

	part def SensitiveSkin {
		part substrate : SiliconeSubstrate;
		part processingUnit : SignalProcessingUnit;
		part controller : ResponseController;
		part power : PowerSupply;

		connect substrate.sensorArray.arrayOut to processingUnit.rawIn;
		connect processingUnit.processedOut to controller.processedIn;
		connect power.powerOut to processingUnit.powerIn;
		connect power.powerOut to controller.powerIn;

		exhibit skinStates : SkinOperationalStates {
			in skinPart = substrate;
			in procPart = processingUnit;
			in ctrlPart = controller;
		}
	}

	requirement def ResponseTimeRequirement {
		doc /* The system shall process a touch event and generate a response in under 20 milliseconds. */
		attribute maxResponseTime : Real = 20.0;
		subject skin : SensitiveSkin;
		requirement constraint {
			/* Response time must not exceed 20 ms. */
		}
	}

	requirement def OperatingTemperatureRequirement {
		doc /* The system shall operate reliably from -20 degC to 100 degC. */
		attribute minOperatingTemp : Real = -20.0;
		attribute maxOperatingTemp : Real = 100.0;
		subject skin : SensitiveSkin;
		requirement constraint {
			/* Operating temperature must remain within range. */
		}
	}

	requirement def SensorResolutionRequirement {
		doc /* The skin shall contain an 8x8 grid of 64 tactile sensor cells. */
		attribute rowCount : Integer = 8;
		attribute colCount : Integer = 8;
		attribute totalCells : Integer = 64;
		subject skin : SensitiveSkin;
		requirement constraint {
			/* Sensor array must contain exactly 64 cells. */
		}
	}

	requirement def DualMeasurementRequirement {
		doc /* Each sensor cell shall independently detect pressure and temperature. */
		subject cell : TactileSensorCell;
		requirement constraint {
			/* Each cell must measure both pressure and temperature. */
		}
	}

	requirement def SafetyThresholdRequirement {
		doc /* The controller shall generate a response signal when force or temperature exceeds thresholds. */
		attribute maxForce : Force = 50.0;
		attribute maxTemperature : Temperature = 60.0;
		subject controller : ResponseController;
		requirement constraint {
			/* Controller must alert when thresholds are exceeded. */
		}
	}

	requirement SensitiveSkinRequirements {
		doc /* Top-level requirements for the sensitive skin system. */
		requirement responseTime : ResponseTimeRequirement;
		requirement operatingTemp : OperatingTemperatureRequirement;
		requirement sensorResolution : SensorResolutionRequirement;
		requirement dualMeasurement : DualMeasurementRequirement;
		requirement safetyThreshold : SafetyThresholdRequirement;
	}

	satisfy SensitiveSkinRequirements::responseTime by SensitiveSkin;
	satisfy SensitiveSkinRequirements::operatingTemp by SensitiveSkin;
	satisfy SensitiveSkinRequirements::sensorResolution by SensitiveSkin::substrate::sensorArray;
	satisfy SensitiveSkinRequirements::dualMeasurement by TactileSensorCell;
	satisfy SensitiveSkinRequirements::safetyThreshold by ResponseController;
}
