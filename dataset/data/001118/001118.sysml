package 'Level Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def LevelValue :> LengthValue;
	
	attribute def VoltageValue :> QuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VoltageUnit;
	}
	
	attribute def VoltageUnit :> MeasurementUnit;
	
	attribute def CurrentValue :> QuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : CurrentUnit;
	}
	
	attribute def CurrentUnit :> MeasurementUnit;
	
	port def LevelOutputPort {
		out levelReading : LevelValue;
		out measurementValid : Boolean;
		out timestamp : TimeValue;
	}
	
	port def PowerPort {
		in supplyVoltage : VoltageValue;
		in supplyCurrent : CurrentValue;
	}
	
	port def ControlPort {
		in calibrationCommand : Boolean;
		in resetCommand : Boolean;
		out statusCode : Integer;
	}
	
	part def LevelSensor {
		doc /* Ultrasonic level sensor that measures distance to liquid surface */
		
		attribute sensorId : String;
		attribute measurementRange : LevelValue;
		attribute accuracy : Real;
		attribute resolution : LevelValue;
		attribute responseTime : TimeValue;
		attribute operatingVoltage : VoltageValue;
		
		port powerIn : PowerPort;
		port dataOut : LevelOutputPort;
		port control : ControlPort;
		
		attribute currentMeasurement : LevelValue;
		attribute isCalibrated : Boolean;
		
		action def MeasureLevel {
			in referenceHeight : LevelValue;
			out measuredLevel : LevelValue;
			out valid : Boolean;
			
			first start;
			then action emitSignal {
				out signalEmitted : Boolean;
			}
			then action receiveEcho {
				in emitted : Boolean = emitSignal.signalEmitted;
				out echoTime : TimeValue;
			}
			then action calculateDistance {
				in timeOfFlight : TimeValue = receiveEcho.echoTime;
				out distance : LevelValue;
			}
			then action validateMeasurement {
				in level : LevelValue = calculateDistance.distance;
				out isValid : Boolean;
				out validatedLevel : LevelValue;
			}
			then done;
			
			flow from emitSignal.signalEmitted to receiveEcho.emitted;
			flow from receiveEcho.echoTime to calculateDistance.timeOfFlight;
			flow from calculateDistance.distance to validateMeasurement.level;
		}
		
		state sensorBehavior {
			entry; then initializing;
			
			state initializing {
				entry action performSelfTest;
			}
			
			transition initializing_to_ready
				first initializing
				accept when isCalibrated
				then ready;
			
			transition initializing_to_calibrating
				first initializing
				accept when not isCalibrated
				then calibrating;
			
			state calibrating {
				entry action runCalibration;
				do action adjustParameters;
			}
			
			transition calibrating_to_ready
				first calibrating
				accept CalibrationComplete
				then ready;
			
			state ready;
			
			transition ready_to_measuring
				first ready
				accept MeasurementTrigger
				then measuring;
			
			state measuring {
				do action continuousMeasure : MeasureLevel {
					in referenceHeight = 10.0[m];
				}
			}
			
			transition measuring_to_ready
				first measuring
				accept MeasurementComplete
				then ready;
			
			transition measuring_to_error
				first measuring
				accept when currentMeasurement.num > measurementRange.num
				then error;
			
			state error {
				entry action logError;
			}
			
			transition error_to_initializing
				first error
				accept ResetCommand
				then initializing;
		}
	}
	
	part def SignalConditioner {
		doc /* Conditions and filters raw sensor signals */
		
		attribute filterCutoffFrequency : Real;
		attribute amplificationGain : Real;
		attribute offsetCompensation : LevelValue;
		
		port rawInput : ~LevelOutputPort;
		port conditionedOutput : LevelOutputPort;
		
		action def ConditionSignal {
			in rawLevel : LevelValue;
			out conditionedLevel : LevelValue;
			
			first start;
			then action filterNoise {
				in noisySignal : LevelValue = rawLevel;
				out filteredSignal : LevelValue;
			}
			then action amplify {
				in inputSignal : LevelValue = filterNoise.filteredSignal;
				out amplifiedSignal : LevelValue;
			}
			then action compensateOffset {
				in signal : LevelValue = amplify.amplifiedSignal;
				out finalSignal : LevelValue;
			}
			then done;
			
			flow from filterNoise.filteredSignal to amplify.inputSignal;
			flow from amplify.amplifiedSignal to compensateOffset.signal;
		}
	}
	
	part def DataProcessor {
		doc /* Processes conditioned signals and applies calibration */
		
		attribute calibrationMatrix : Real[3];
		attribute temperatureCompensation : Boolean;
		attribute averagingWindow : Integer;
		
		port signalInput : ~LevelOutputPort;
		port processedOutput : LevelOutputPort;
		
		action def ProcessData {
			in conditionedLevel : LevelValue;
			in temperature : TemperatureValue;
			out processedLevel : LevelValue;
			out confidence : Real;
			
			first start;
			then action applyCalibration {
				in rawData : LevelValue = conditionedLevel;
				out calibratedData : LevelValue;
			}
			then action temperatureCorrection {
				in data : LevelValue = applyCalibration.calibratedData;
				in temp : TemperatureValue = temperature;
				out correctedData : LevelValue;
			}
			then action computeAverage {
				in instantData : LevelValue = temperatureCorrection.correctedData;
				out averagedData : LevelValue;
			}
			then action assessQuality {
				in finalData : LevelValue = computeAverage.averagedData;
				out qualityMetric : Real;
			}
			then done;
			
			flow from applyCalibration.calibratedData to temperatureCorrection.data;
			flow from temperatureCorrection.correctedData to computeAverage.instantData;
			flow from computeAverage.averagedData to assessQuality.finalData;
		}
	}
	
	part def PowerSupply {
		doc /* Provides regulated power to sensing unit components */
		
		attribute inputVoltage : VoltageValue;
		attribute outputVoltage : VoltageValue;
		attribute maxCurrent : CurrentValue;
		attribute efficiency : Real;
		
		port powerOut : ~PowerPort;
		
		attribute currentLoad : CurrentValue;
	}
	
	part def SensingUnit {
		doc /* Complete level sensing unit with sensor, conditioning, processing, and power */
		
		attribute unitId : String;
		attribute installationHeight : LevelValue;
		attribute operatingTemperatureMin : TemperatureValue;
		attribute operatingTemperatureMax : TemperatureValue;
		attribute tankCapacity : VolumeValue;
		
		part sensor : LevelSensor {
			attribute :>> sensorId = "LS-ULT-001";
			attribute :>> measurementRange = 10.0[m];
			attribute :>> accuracy = 0.005;
			attribute :>> resolution = 0.001[m];
			attribute :>> responseTime = 0.1[s];
			attribute :>> isCalibrated = true;
		}
		
		part conditioner : SignalConditioner {
			attribute :>> filterCutoffFrequency = 100.0;
			attribute :>> amplificationGain = 2.5;
			attribute :>> offsetCompensation = 0.002[m];
		}
		
		part processor : DataProcessor {
			attribute :>> calibrationMatrix = (1.0, 0.02, -0.001);
			attribute :>> temperatureCompensation = true;
			attribute :>> averagingWindow = 10;
		}
		
		part power : PowerSupply {
			attribute :>> inputVoltage = 230.0[V];
			attribute :>> outputVoltage = 24.0[V];
			attribute :>> efficiency = 0.85;
		}
		
		port systemOutput : LevelOutputPort;
		port systemControl : ControlPort;
		
		connection powerConnection 
			connect power.powerOut = sensor.powerIn;
		
		connection sensorToConditioner 
			connect sensor.dataOut = conditioner.rawInput;
		
		connection conditionerToProcessor 
			connect conditioner.conditionedOutput = processor.signalInput;
		
		binding systemOutputBinding 
			bind processor.processedOutput = systemOutput;
		
		binding systemControlBinding 
			bind sensor.control = systemControl;
		
		attribute currentLevel : LevelValue;
		attribute volumeRemaining : VolumeValue;
		
		action def PerformSensing {
			first start;
			then fork;
				then measureAction;
				then conditionAction;
				then processAction;
			
			action measureAction : sensor.MeasureLevel {
				in referenceHeight = installationHeight;
				out measuredLevel : LevelValue;
			}
			then joinNode;
			
			action conditionAction : conditioner.ConditionSignal {
				in rawLevel = measureAction.measuredLevel;
				out conditionedLevel : LevelValue;
			}
			then joinNode;
			
			action processAction : processor.ProcessData {
				in conditionedLevel = conditionAction.conditionedLevel;
				in temperature = 293.15[K];
				out processedLevel : LevelValue;
			}
			then joinNode;
			
			join joinNode;
			then action updateOutput {
				in finalLevel : LevelValue = processAction.processedLevel;
			}
			then done;
			
			flow from measureAction.measuredLevel to conditionAction.rawLevel;
			flow from conditionAction.conditionedLevel to processAction.conditionedLevel;
			flow from processAction.processedLevel to updateOutput.finalLevel;
		}
	}
	
	item def MeasurementTrigger;
	item def MeasurementComplete;
	item def CalibrationComplete;
	item def ResetCommand;
	
	attribute def VolumeValue :> QuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VolumeUnit;
	}
	
	attribute def VolumeUnit :> MeasurementUnit;
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The sensing unit shall measure level with accuracy better than 0.5% of full scale */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.sensor.accuracy <= 0.005
		}
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The sensing unit shall measure levels up to 10 meters */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.sensor.measurementRange.num >= 10.0
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall provide measurements within 200ms */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.sensor.responseTime.num <= 0.2
		}
	}
	
	requirement def PowerConsumptionRequirement {
		doc /* The sensing unit shall operate within specified power limits */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.power.currentLoad.num <= unit.power.maxCurrent.num
		}
	}
	
	part tankLevelSensingSystem : SensingUnit {
		attribute :>> unitId = "TLSS-100";
		attribute :>> installationHeight = 12.0[m];
		attribute :>> operatingTemperatureMin = 253.15[K];
		attribute :>> operatingTemperatureMax = 333.15[K];
		attribute :>> tankCapacity = 50.0[m^3];
		
		satisfy MeasurementAccuracyRequirement {
			subject unit = tankLevelSensingSystem;
		}
		
		satisfy MeasurementRangeRequirement {
			subject unit = tankLevelSensingSystem;
		}
		
		satisfy ResponseTimeRequirement {
			subject unit = tankLevelSensingSystem;
		}
		
		satisfy PowerConsumptionRequirement {
			subject unit = tankLevelSensingSystem;
		}
	}
}
