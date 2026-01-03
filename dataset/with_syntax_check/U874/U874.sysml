package 'Sensing Unit Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;
	private import Quantities::*;
	
	item def EnvironmentalCondition {
		attribute ambientTemperature : TemperatureValue;
		attribute humidity : Real;
	}
	
	item def RawSensorData {
		attribute voltage : Real;
		attribute timestamp : Real;
	}
	
	item def ProcessedMeasurement {
		attribute temperature : TemperatureValue;
		attribute timestamp : Real;
		attribute confidence : Real;
	}
	
	attribute def SensorStatus {
		attribute isCalibrated : Boolean;
		attribute lastCalibrationTime : Real;
		attribute errorCode : Integer;
	}
	
	port def SensorDataPort {
		out item rawData : RawSensorData;
	}
	
	port def MeasurementOutputPort {
		out item measurement : ProcessedMeasurement;
	}
	
	port def PowerInputPort {
		in attribute voltage : Real;
		in attribute current : Real;
	}
	
	port def CalibrationPort {
		in attribute calibrationCommand : String;
		out attribute calibrationStatus : SensorStatus;
	}
	
	action def SenseEnvironment {
		in item environment : EnvironmentalCondition;
		out item rawData : RawSensorData;
	}
	
	action def ConvertSignal {
		in item rawData : RawSensorData;
		out item measurement : ProcessedMeasurement;
	}
	
	action def ValidateMeasurement {
		in item measurement : ProcessedMeasurement;
		out item validatedMeasurement : ProcessedMeasurement;
		out attribute isValid : Boolean;
	}
	
	action def CalibrateNode {
		in attribute referenceTemperature : TemperatureValue;
		out attribute calibrationOffset : Real;
		out attribute status : SensorStatus;
	}
	
	state def SensorOperationalStates {
		entry; then idle;
		
		state idle;
		transition idle_to_sensing
			first idle
			then sensing;
		
		state sensing {
			entry action performSensing : SenseEnvironment;
		}
		transition sensing_to_processing
			first sensing
			then processing;
		
		state processing {
			entry action convertData : ConvertSignal;
			do action validateData : ValidateMeasurement;
		}
		transition processing_to_outputting
			first processing
			then outputting;
		
		state outputting;
		transition outputting_to_idle
			first outputting
			then idle;
		
		transition any_to_calibration
			first idle
			then calibration;
		
		state calibration {
			entry action performCalibration : CalibrateNode;
		}
		transition calibration_to_idle
			first calibration
			then idle;
		
		state error;
		transition error_to_idle
			first error
			then idle;
	}
	
	part def SensorNode {
		attribute nodeId : String;
		attribute sensorStatus : SensorStatus;
		attribute calibrationOffset : Real default = 0.0;
		attribute measurementRange : TemperatureValue[2];
		
		port sensorDataOut : SensorDataPort;
		port measurementOut : MeasurementOutputPort;
		port powerIn : PowerInputPort;
		port calibrationInterface : CalibrationPort;
		
		part sensingElement {
			attribute sensitivity : Real;
			attribute responseTime : Real;
			
			perform action sense : SenseEnvironment {
				in item environment;
				out item rawData;
			}
		}
		
		part signalProcessor {
			attribute gain : Real;
			attribute filterCutoffFrequency : Real;
			
			perform action convert : ConvertSignal {
				in item rawData;
				out item measurement;
			}
			
			perform action validate : ValidateMeasurement {
				in item measurement;
				out item validatedMeasurement;
				out attribute isValid;
			}
		}
		
		part dataBuffer {
			attribute bufferSize : Integer;
			attribute storedMeasurements : ProcessedMeasurement[0..100];
		}
		
		part powerManagement {
			attribute operatingVoltage : Real;
			attribute powerConsumption : Real;
		}
		
		exhibit state operationalBehavior : SensorOperationalStates;
	}
	
	part def SensingUnit {
		attribute unitId : String;
		attribute operatingTemperatureRange : TemperatureValue[2];
		
		part sensor : SensorNode[1] {
			attribute :>> nodeId = "TEMP_SENSOR_001";
			attribute :>> measurementRange = (233.15[K], 373.15[K]);
			
			part :>> sensingElement {
				attribute :>> sensitivity = 0.01;
				attribute :>> responseTime = 0.5;
			}
			
			part :>> signalProcessor {
				attribute :>> gain = 100.0;
				attribute :>> filterCutoffFrequency = 10.0;
			}
			
			part :>> powerManagement {
				attribute :>> operatingVoltage = 5.0;
				attribute :>> powerConsumption = 0.05;
			}
		}
		
		part enclosure {
			attribute material : String;
			attribute protectionRating : String;
		}
		
		part mountingBracket {
			attribute mountingType : String;
		}
		
		part powerSupply {
			port powerOut : PowerInputPort;
			attribute outputVoltage : Real;
		}
		
		part dataAcquisitionSystem {
			port dataIn : MeasurementOutputPort;
			attribute samplingRate : Real;
		}
		
		connection powerConnection 
			connect powerSupply.powerOut to sensor.powerIn;
		
		connection dataConnection
			connect sensor.measurementOut to dataAcquisitionSystem.dataIn;
	}
	
	action def PerformMeasurementCycle {
		in item environment : EnvironmentalCondition;
		out item finalMeasurement : ProcessedMeasurement;
		
		bind senseStep.environment = environment;
		
		action senseStep : SenseEnvironment {
			in item environment;
			out item rawData;
		}
		
		succession flow from senseStep.rawData to convertStep.rawData;
		
		action convertStep : ConvertSignal {
			in item rawData;
			out item measurement;
		}
		
		succession flow from convertStep.measurement to validateStep.measurement;
		
		action validateStep : ValidateMeasurement {
			in item measurement;
			out item validatedMeasurement;
			out attribute isValid;
		}
		
		bind validateStep.validatedMeasurement = finalMeasurement;
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The sensor shall measure temperature with an accuracy of ±0.5°C */
		
		subject sensor : SensorNode;
		
		require constraint {
			sensor.sensingElement.sensitivity <= 0.5
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensor shall respond to temperature changes within 1 second */
		
		subject sensor : SensorNode;
		
		require constraint {
			sensor.sensingElement.responseTime <= 1.0
		}
	}
	
	requirement def OperatingRangeRequirement {
		doc /* The sensing unit shall operate in temperature range -40°C to 100°C */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.sensor.measurementRange[1].num >= 233.15 and
			unit.sensor.measurementRange[2].num <= 373.15
		}
	}
	
	part sensingUnitInstance : SensingUnit {
		attribute :>> unitId = "UNIT_ALPHA_01";
		attribute :>> operatingTemperatureRange = (233.15[K], 373.15[K]);
		
		part :>> sensor {
			attribute :>> sensorStatus {
				attribute :>> isCalibrated = true;
				attribute :>> lastCalibrationTime = 0.0;
				attribute :>> errorCode = 0;
			}
		}
		
		part :>> enclosure {
			attribute :>> material = "Stainless Steel";
			attribute :>> protectionRating = "IP67";
		}
		
		part :>> mountingBracket {
			attribute :>> mountingType = "Wall Mount";
		}
		
		part :>> powerSupply {
			attribute :>> outputVoltage = 5.0;
		}
		
		part :>> dataAcquisitionSystem {
			attribute :>> samplingRate = 10.0;
		}
		
		perform action measurementCycle : PerformMeasurementCycle {
			in item environment : EnvironmentalCondition {
				attribute :>> ambientTemperature = 298.15[K];
				attribute :>> humidity = 45.0;
			}
			out item finalMeasurement;
		}
		
		satisfy measurementAccuracy : MeasurementAccuracyRequirement {
			subject testSensor = sensor;
		}
		
		satisfy responseTime : ResponseTimeRequirement {
			subject testSensor = sensor;
		}
		
		satisfy operatingRange : OperatingRangeRequirement {
			subject testUnit = sensingUnitInstance;
		}
	}
}
