package 'Fish Counting System' {
	private import ScalarValues::*;

	doc
	/*
	 * Automated fish counting system for continuously monitoring fish migration
	 * in waterways such as rivers or fish ladders. Provides accurate, real-time
	 * data on fish populations for ecological research and fishery management.
	 */

	attribute def Length :> Real;
	attribute def Temperature :> Real;
	attribute def Voltage :> Real;
	attribute def Count :> Integer;
	attribute def Confidence :> Real;
	attribute def Rate :> Integer;
	attribute def Duration :> Integer;

	enum def TravelDirection {
		upstream;
		downstream;
	}

	item def RawDetectionSignal {
		attribute detectedSize : Length[1];
		attribute direction : TravelDirection[1];
		attribute timestamp : String[1];
		attribute signalAmplitude : Real[1];
	}

	item def ValidatedFishDetection {
		attribute fishSize : Length[1];
		attribute direction : TravelDirection[1];
		attribute timestamp : String[1];
		attribute confidence : Confidence[1];
	}

	item def CountUpdate {
		attribute upstreamCount : Count[1];
		attribute downstreamCount : Count[1];
		attribute netCount : Count[1];
		attribute timestamp : String[1];
	}

	item def LoggedRecord {
		attribute upstreamCount : Count[1];
		attribute downstreamCount : Count[1];
		attribute netCount : Count[1];
		attribute timestamp : String[1];
		attribute recordId : Integer[1];
	}

	action def ValidateSignal {
		in raw : RawDetectionSignal;
		out validated : ValidatedFishDetection;
	}

	action def ProcessDetection {
		in detection : ValidatedFishDetection;
		out update : CountUpdate;
	}

	action def LogRecord {
		in update : CountUpdate;
		out record : LoggedRecord;
	}

	state def SensorStates {
		state Idle;
		state Detecting;
		transition initial to Idle;
		transition Idle to Detecting;
		transition Detecting to Idle;
	}

	state def ProcessorStates {
		state Waiting;
		state Analyzing;
		state Filtering;
		transition initial to Waiting;
		transition Waiting to Analyzing;
		transition Analyzing to Filtering;
		transition Filtering to Waiting;
	}

	state def CountingStates {
		state Idle;
		state Incrementing;
		state Emitting;
		transition initial to Idle;
		transition Idle to Incrementing;
		transition Incrementing to Emitting;
		transition Emitting to Idle;
	}

	state def DisplayStates {
		state Off;
		state On;
		state Updating;
		transition initial to Off;
		transition Off to On;
		transition On to Updating;
		transition Updating to On;
	}

	state def LoggingStates {
		state Idle;
		state Recording;
		state Exporting;
		transition initial to Idle;
		transition Idle to Recording;
		transition Recording to Idle;
		transition Idle to Exporting;
		transition Exporting to Idle;
	}

	state def PowerStates {
		state Off;
		state On;
		transition initial to Off;
		transition Off to On;
	}

	state def SystemStates {
		state Unpowered;
		state Operational;
		state Standby;
		transition initial to Unpowered;
		transition Unpowered to Operational;
		transition Operational to Standby;
		transition Standby to Operational;
	}

	part def OpticalSensor {
		doc
		/*
		 * Underwater optical sensor that detects fish as they pass.
		 * Sensitive enough to identify objects as small as five centimeters
		 * and can determine estimated size and direction of travel.
		 */
		attribute minDetectableSize : Length[1] = 5;
		attribute operatingTempMin : Temperature[1] = -20;
		attribute operatingTempMax : Temperature[1] = 50;
		attribute waterproofRating : String[1] = "IP68";
		port powerIn {
			in power : Voltage;
		}
		port detectionOut {
			out rawSignal : RawDetectionSignal;
		}
		exhibit SensorStates;
	}

	part def SignalProcessor {
		doc
		/*
		 * Analyzes raw detection signals to distinguish actual fish
		 * from debris or water turbulence, ensuring count accuracy.
		 */
		port powerIn {
			in power : Voltage;
		}
		port rawIn {
			in rawSignal : RawDetectionSignal;
		}
		port validatedOut {
			out validatedDetection : ValidatedFishDetection;
		}
		perform validateSignal : ValidateSignal;
		exhibit ProcessorStates;
	}

	part def CountingModule {
		doc
		/*
		 * Maintains separate running totals for upstream and downstream
		 * fish passage, as well as a net count. Handles up to 300 fish/min.
		 */
		attribute maxProcessingRate : Rate[1] = 300;
		attribute upstreamCount : Count = 0;
		attribute downstreamCount : Count = 0;
		attribute netCount : Count = 0;
		port powerIn {
			in power : Voltage;
		}
		port detectionIn {
			in validatedDetection : ValidatedFishDetection;
		}
		port countOut {
			out countUpdate : CountUpdate;
		}
		assert constraint netCountConstraint {
			netCount == upstreamCount - downstreamCount
		}
		perform processDetection : ProcessDetection;
		exhibit CountingStates;
	}

	part def DisplayController {
		doc
		/*
		 * Provides real-time, on-site readout of upstream, downstream,
		 * and net totals.
		 */
		attribute refreshRate : Real[1] = 1.0;
		port powerIn {
			in power : Voltage;
		}
		port countIn {
			in countUpdate : CountUpdate;
		}
		exhibit DisplayStates;
	}

	part def DataLogger {
		doc
		/*
		 * Records each count with a timestamp. Storage capacity designed
		 * to hold over a year's worth of data, exportable for analysis.
		 */
		attribute storageCapacityDays : Duration[1] = 400;
		attribute recordCount : Integer = 0;
		port powerIn {
			in power : Voltage;
		}
		port countIn {
			in countUpdate : CountUpdate;
		}
		port exportPort {
			out loggedRecord : LoggedRecord;
		}
		perform logRecord : LogRecord;
		exhibit LoggingStates;
	}

	part def PowerSupply {
		doc
		/*
		 * Converts standard electrical input into low-voltage DC
		 * required by all electronic components.
		 */
		attribute inputVoltage : Voltage[1] = 120;
		attribute outputVoltage : Voltage[1] = 12;
		attribute outputType : String[1] = "DC";
		port powerOut {
			out power : Voltage;
		}
		exhibit PowerStates;
	}

	requirement def DetectionSensitivityRequirement {
		doc
		/*
		 * The optical sensor must detect objects as small as five centimeters.
		 */
		subject sensor : OpticalSensor;
		attribute requiredMinSize : Length[1] = 5;
		assert constraint minSizeConstraint {
			sensor.minDetectableSize <= requiredMinSize
		}
	}

	requirement def ProcessingRateRequirement {
		doc
		/*
		 * The counting module must handle up to 300 fish per minute.
		 */
		subject counter : CountingModule;
		attribute requiredRate : Rate[1] = 300;
		assert constraint rateConstraint {
			counter.maxProcessingRate >= requiredRate
		}
	}

	requirement def StorageCapacityRequirement {
		doc
		/*
		 * The data logger must hold over a year's worth of data.
		 */
		subject logger : DataLogger;
		attribute minStorageDays : Duration[1] = 365;
		assert constraint storageConstraint {
			logger.storageCapacityDays >= minStorageDays
		}
	}

	requirement def EnvironmentalRobustnessRequirement {
		doc
		/*
		 * The system must operate reliably in a wide range of outdoor temperatures.
		 */
		subject sensor : OpticalSensor;
		attribute requiredMinTemp : Temperature[1] = -20;
		attribute requiredMaxTemp : Temperature[1] = 50;
		assert constraint tempConstraint {
			sensor.operatingTempMin <= requiredMinTemp
			and sensor.operatingTempMax >= requiredMaxTemp
		}
	}

	requirement def WaterproofRequirement {
		doc
		/*
		 * Sensor components must be waterproof for underwater operation.
		 */
		subject sensor : OpticalSensor;
		attribute requiredRating : String[1] = "IP68";
		assert constraint waterproofConstraint {
			sensor.waterproofRating == requiredRating
		}
	}

	requirement def PowerConversionRequirement {
		doc
		/*
		 * The power supply must convert standard electrical input to
		 * low-voltage DC for all components.
		 */
		subject supply : PowerSupply;
		attribute requiredOutput : Voltage[1] = 12;
		attribute requiredType : String[1] = "DC";
		assert constraint powerConstraint {
			supply.outputVoltage == requiredOutput
			and supply.outputType == requiredType
		}
	}

	requirement detectionSensitivityReq : DetectionSensitivityRequirement;
	requirement processingRateReq : ProcessingRateRequirement;
	requirement storageCapacityReq : StorageCapacityRequirement;
	requirement environmentalRobustnessReq : EnvironmentalRobustnessRequirement;
	requirement waterproofReq : WaterproofRequirement;
	requirement powerConversionReq : PowerConversionRequirement;

	part def FishCountingSystem {
		part opticalSensor : OpticalSensor;
		part signalProcessor : SignalProcessor;
		part countingModule : CountingModule;
		part displayController : DisplayController;
		part dataLogger : DataLogger;
		part powerSupply : PowerSupply;

		interface powerToSensor connect powerSupply.powerOut to opticalSensor.powerIn {
			flow powerFlow of Voltage
				from powerSupply.powerOut.power to opticalSensor.powerIn.power;
		}
		interface powerToProcessor connect powerSupply.powerOut to signalProcessor.powerIn {
			flow powerFlow of Voltage
				from powerSupply.powerOut.power to signalProcessor.powerIn.power;
		}
		interface powerToCounter connect powerSupply.powerOut to countingModule.powerIn {
			flow powerFlow of Voltage
				from powerSupply.powerOut.power to countingModule.powerIn.power;
		}
		interface powerToDisplay connect powerSupply.powerOut to displayController.powerIn {
			flow powerFlow of Voltage
				from powerSupply.powerOut.power to displayController.powerIn.power;
		}
		interface powerToLogger connect powerSupply.powerOut to dataLogger.powerIn {
			flow powerFlow of Voltage
				from powerSupply.powerOut.power to dataLogger.powerIn.power;
		}

		interface rawSignalInterface connect opticalSensor.detectionOut to signalProcessor.rawIn {
			flow rawSignalFlow of RawDetectionSignal
				from opticalSensor.detectionOut.rawSignal to signalProcessor.rawIn.rawSignal;
		}

		interface validatedDetectionInterface connect signalProcessor.validatedOut to countingModule.detectionIn {
			flow validatedDetectionFlow of ValidatedFishDetection
				from signalProcessor.validatedOut.validatedDetection to countingModule.detectionIn.validatedDetection;
		}

		interface countToDisplayInterface connect countingModule.countOut to displayController.countIn {
			flow countToDisplayFlow of CountUpdate
				from countingModule.countOut.countUpdate to displayController.countIn.countUpdate;
		}

		interface countToLoggerInterface connect countingModule.countOut to dataLogger.countIn {
			flow countToLoggerFlow of CountUpdate
				from countingModule.countOut.countUpdate to dataLogger.countIn.countUpdate;
		}

		satisfy detectionSensitivityReq by opticalSensor;
		satisfy processingRateReq by countingModule;
		satisfy storageCapacityReq by dataLogger;
		satisfy environmentalRobustnessReq by opticalSensor;
		satisfy waterproofReq by opticalSensor;
		satisfy powerConversionReq by powerSupply;

		exhibit SystemStates;
	}
}
