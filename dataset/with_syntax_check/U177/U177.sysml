package 'Bubble Sensor Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;
	
	attribute def AngleValue :> ISQ::DimensionOneValue {
		attribute :>> num : Real;
		attribute :>> mRef : AngleUnit;
	}
	
	attribute def AngleUnit :> SI::DerivedUnit;
	
	attribute def DegreeUnit :> AngleUnit;
	
	attribute def InclinationAngle :> AngleValue;
	
	attribute def FlowRateValue :> ISQ::DimensionOneValue {
		attribute :>> num : Real;
		attribute :>> mRef : FlowRateUnit;
	}
	
	attribute def FlowRateUnit :> SI::DerivedUnit;
	
	item def BubblePosition {
		attribute horizontalOffset : LengthValue;
		attribute verticalOffset : LengthValue;
	}
	
	item def InclinationReading {
		attribute angle : InclinationAngle;
		attribute isLevel : Boolean;
		attribute confidence : Real;
	}
	
	port def SensorOutputPort {
		out item reading : InclinationReading;
	}
	
	port def CalibrationInputPort {
		in item zeroReference : InclinationAngle;
	}
	
	port def PowerSupplyPort {
		in item voltage : ISQ::ElectricPotentialValue;
	}
	
	part def BubbleVial {
		attribute vialLength : LengthValue;
		attribute vialRadius : LengthValue;
		attribute fluidDensity : Real;
		part bubble {
			attribute currentPosition : BubblePosition;
			attribute diameter : LengthValue;
		}
		part graduatedScale {
			attribute markingInterval : LengthValue;
			attribute numberOfMarks : Integer;
		}
	}
	
	part def OpticalSensor {
		attribute wavelength : LengthValue;
		attribute detectionAccuracy : LengthValue;
		attribute samplingRate : Real;
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute conversionRate : Real;
	}
	
	part def SignalConditioner {
		attribute amplificationGain : Real;
		attribute filterFrequency : Real;
		attribute noiseReduction : Real;
	}
	
	action def DetectBubblePosition {
		in vial : BubbleVial;
		in sensor : OpticalSensor;
		out position : BubblePosition;
	}
	
	action def CalculateInclination {
		in bubblePos : BubblePosition;
		in vialLength : LengthValue;
		in calibrationOffset : InclinationAngle;
		out inclination : InclinationAngle;
	}
	
	action def EvaluateLevelStatus {
		in inclination : InclinationAngle;
		in levelTolerance : InclinationAngle;
		out isLevel : Boolean;
		out confidence : Real;
	}
	
	action def GenerateInclinationReading {
		in inclination : InclinationAngle;
		in levelStatus : Boolean;
		in confidenceValue : Real;
		out reading : InclinationReading;
	}
	
	action def PerformInclinationMeasurement {
		in item vial : BubbleVial;
		in item sensor : OpticalSensor;
		in item calibration : InclinationAngle;
		in item tolerance : InclinationAngle;
		out item finalReading : InclinationReading;
		
		action detectBubble : DetectBubblePosition {
			in vial;
			in sensor;
			out position;
		}
		then flow from detectBubble.position to calculateAngle.bubblePos;
		
		action calculateAngle : CalculateInclination {
			in bubblePos;
			in vialLength = vial.vialLength;
			in calibrationOffset = calibration;
			out inclination;
		}
		then flow from calculateAngle.inclination to evaluateLevel.inclination;
		
		action evaluateLevel : EvaluateLevelStatus {
			in inclination;
			in levelTolerance = tolerance;
			out isLevel;
			out confidence;
		}
		then fork;
		
		flow from calculateAngle.inclination to generateOutput.inclination;
		flow from evaluateLevel.isLevel to generateOutput.levelStatus;
		flow from evaluateLevel.confidence to generateOutput.confidenceValue;
		
		then join outputJoin;
		
		action generateOutput : GenerateInclinationReading {
			in inclination;
			in levelStatus;
			in confidenceValue;
			out reading;
		}
		
		bind generateOutput.reading = finalReading;
	}
	
	state def BubbleSensorOperationalStates {
		entry; then powerOn;
		
		state powerOn;
		
		transition powerOn_to_calibrating
			first powerOn
			then calibrating;
		
		state calibrating;
		
		transition calibrating_to_ready
			first calibrating
			then ready;
		
		state ready;
		
		transition ready_to_measuring
			first ready
			then measuring;
		
		state measuring {
			entry action executeMeasurement : PerformInclinationMeasurement;
		}
		
		transition measuring_to_processing
			first measuring
			then processing;
		
		state processing;
		
		transition processing_to_transmitting
			first processing
			then transmitting;
		
		state transmitting;
		
		transition transmitting_to_ready
			first transmitting
			then ready;
		
		transition ready_to_recalibrating
			first ready
			then calibrating;
		
		state error;
		
		transition measuring_to_error
			first measuring
			then error;
		
		transition error_to_ready
			first error
			then ready;
	}
	
	part def BubbleSensor {
		attribute operationalMode : String;
		attribute measurementAccuracy : InclinationAngle;
		attribute levelTolerance : InclinationAngle;
		attribute zeroCalibration : InclinationAngle;
		attribute supplyVoltage : ISQ::ElectricPotentialValue;
		
		part vial : BubbleVial {
			attribute :>> vialLength = 100.0[mm];
			attribute :>> vialRadius = 5.0[mm];
			attribute :>> fluidDensity = 0.85;
			
			part :>> bubble {
				attribute :>> diameter = 8.0[mm];
			}
			
			part :>> graduatedScale {
				attribute :>> markingInterval = 2.0[mm];
				attribute :>> numberOfMarks = 50;
			}
		}
		
		part opticalSensor : OpticalSensor {
			attribute :>> wavelength = 850.0[nm];
			attribute :>> detectionAccuracy = 0.01[mm];
			attribute :>> samplingRate = 100.0;
		}
		
		part adc : AnalogToDigitalConverter {
			attribute :>> resolution = 16;
			attribute :>> conversionRate = 1000.0;
		}
		
		part signalConditioner : SignalConditioner {
			attribute :>> amplificationGain = 10.0;
			attribute :>> filterFrequency = 50.0;
			attribute :>> noiseReduction = 0.95;
		}
		
		port dataOutput : SensorOutputPort;
		port calibrationInput : CalibrationInputPort;
		port powerInput : PowerSupplyPort;
		
		perform action measurementAction : PerformInclinationMeasurement {
			in item :>> vial = BubbleSensor::vial;
			in item :>> sensor = opticalSensor;
			in item :>> calibration = zeroCalibration;
			in item :>> tolerance = levelTolerance;
			out item :>> finalReading;
		}
		
		exhibit state operationalStateMachine : BubbleSensorOperationalStates;
	}
	
	part def SensingUnit {
		attribute unitSerialNumber : String;
		attribute operatingTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute maxOperatingTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute minOperatingTemperature : ISQ::ThermodynamicTemperatureValue;
		
		part sensor : BubbleSensor {
			attribute :>> measurementAccuracy = 0.05[degree];
			attribute :>> levelTolerance = 0.1[degree];
			attribute :>> zeroCalibration = 0.0[degree];
			attribute :>> supplyVoltage = 5.0[V];
		}
		
		part housingEnclosure {
			attribute material : String;
			attribute protectionClass : String;
			attribute mountingType : String;
		}
		
		part powerSupply {
			attribute inputVoltage : ISQ::ElectricPotentialValue;
			attribute outputVoltage : ISQ::ElectricPotentialValue;
			attribute efficiency : Real;
		}
		
		port externalDataOutput : SensorOutputPort;
		port externalCalibrationInput : CalibrationInputPort;
		port externalPowerInput : PowerSupplyPort;
		
		connection sensorDataConnection
			connect sensor.dataOutput to externalDataOutput;
		
		connection calibrationConnection
			connect externalCalibrationInput to sensor.calibrationInput;
	}
	
	requirement def AccuracyRequirement {
		doc /* The sensing unit shall measure inclination angle with accuracy within specified tolerance. */
		
		subject unit : SensingUnit;
		
		attribute maxAccuracyError : Real;
		
		require constraint {
			unit.sensor.measurementAccuracy.num <= maxAccuracyError
		}
	}
	
	requirement def OperatingRangeRequirement {
		doc /* The sensing unit shall operate within specified inclination measurement range. */
		
		subject unit : SensingUnit;
		
		attribute maxMeasurableAngle : Real;
		
		require constraint {
			unit.sensor.measurementAction.finalReading.angle.num >= -maxMeasurableAngle and
			unit.sensor.measurementAction.finalReading.angle.num <= maxMeasurableAngle
		}
	}
	
	requirement def TemperatureRangeRequirement {
		doc /* The sensing unit shall operate within specified temperature range. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.operatingTemperature.num >= unit.minOperatingTemperature.num and
			unit.operatingTemperature.num <= unit.maxOperatingTemperature.num
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall complete measurement within specified response time. */
		
		subject unit : SensingUnit;
		
		attribute maxResponseTime : ISQ::TimeValue;
	}
	
	attribute degree : DegreeUnit;
	
	part sensingUnitInstance : SensingUnit {
		attribute :>> unitSerialNumber = "BSU-2025-001";
		attribute :>> operatingTemperature = 298.15[K];
		attribute :>> maxOperatingTemperature = 333.15[K];
		attribute :>> minOperatingTemperature = 253.15[K];
		
		part :>> sensor {
			attribute :>> measurementAccuracy = 0.03[degree];
			attribute :>> levelTolerance = 0.08[degree];
			attribute :>> zeroCalibration = 0.0[degree];
			attribute :>> supplyVoltage = 5.0[V];
			
			part :>> vial {
				attribute :>> vialLength = 120.0[mm];
				attribute :>> vialRadius = 6.0[mm];
				attribute :>> fluidDensity = 0.88;
				
				part :>> bubble {
					attribute :>> diameter = 10.0[mm];
				}
				
				part :>> graduatedScale {
					attribute :>> markingInterval = 1.5[mm];
					attribute :>> numberOfMarks = 80;
				}
			}
			
			part :>> opticalSensor {
				attribute :>> wavelength = 940.0[nm];
				attribute :>> detectionAccuracy = 0.005[mm];
				attribute :>> samplingRate = 200.0;
			}
			
			part :>> adc {
				attribute :>> resolution = 24;
				attribute :>> conversionRate = 2000.0;
			}
			
			part :>> signalConditioner {
				attribute :>> amplificationGain = 15.0;
				attribute :>> filterFrequency = 60.0;
				attribute :>> noiseReduction = 0.98;
			}
		}
		
		part :>> housingEnclosure {
			attribute :>> material = "Anodized Aluminum";
			attribute :>> protectionClass = "IP68";
			attribute :>> mountingType = "Surface Mount";
		}
		
		part :>> powerSupply {
			attribute :>> inputVoltage = 12.0[V];
			attribute :>> outputVoltage = 5.0[V];
			attribute :>> efficiency = 0.92;
		}
		
		satisfy accuracyReq : AccuracyRequirement {
			subject unit = sensingUnitInstance;
			attribute :>> maxAccuracyError = 0.05;
		}
		
		satisfy rangeReq : OperatingRangeRequirement {
			subject unit = sensingUnitInstance;
			attribute :>> maxMeasurableAngle = 90.0;
		}
		
		satisfy tempReq : TemperatureRangeRequirement {
			subject unit = sensingUnitInstance;
		}
		
		satisfy responseReq : ResponseTimeRequirement {
			subject unit = sensingUnitInstance;
			attribute :>> maxResponseTime = 0.5[s];
		}
	}
}
