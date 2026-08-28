package EnvironmentalSensingUnit {
	private import ISQ::*;
	private import ScalarValues::*;
	
	item def RawData {
		attribute value : Real;
		attribute unit : String;
		attribute timestamp : Integer;
	}
	
	item def ProcessedMeasurement {
		attribute value : Real;
		attribute unit : String;
		attribute timestamp : Integer;
		attribute qualityScore : Real;
	}
	
	part def Sensor {
		attribute operatingRangeMin : Real;
		attribute operatingRangeMax : Real;
		attribute calibrationFactor : Real := 1.0;
		out port rawOut : RawData;
		action takeMeasurement {
			out raw : RawData;
		}
	}
	
	part def TemperatureSensor :> Sensor {
		redef operatingRangeMin = 200.0;
		redef operatingRangeMax = 400.0;
		redef calibrationFactor = 1.02;
	}
	
	part def PressureSensor :> Sensor {
		redef operatingRangeMin = 50000.0;
		redef operatingRangeMax = 150000.0;
		redef calibrationFactor = 0.98;
	}
	
	part def SignalProcessor {
		in port rawIn : RawData;
		out port processedOut : ProcessedMeasurement;
		action filterData {
			in raw : RawData;
			out processed : ProcessedMeasurement;
		}
	}
	
	part def DataLogger {
		in port processedIn : ProcessedMeasurement;
		attribute buffer : ProcessedMeasurement[0..*];
		action logData {
			in measurement : ProcessedMeasurement;
		}
	}
	
	attribute def Activate;
	attribute def MeasurementComplete;
	attribute def Fault;
	attribute def Reset;
	
	part def EnvironmentalSensingUnit {
		part tempSensor : TemperatureSensor;
		part pressSensor : PressureSensor;
		part processor : SignalProcessor;
		part logger : DataLogger;
		
		connect tempSensor.rawOut to processor.rawIn;
		connect pressSensor.rawOut to processor.rawIn;
		connect processor.processedOut to logger.processedIn;
		
		state unitStates {
			entry; then idle;
			
			state idle;
			accept Activate
				then measuring;
				
			state measuring {
				do tempSensor.takeMeasurement;
				do pressSensor.takeMeasurement;
			}
			accept MeasurementComplete
				then processing;
			accept Fault
				then error;
				
			state processing {
				do processor.filterData;
			}
			then logging;
			
			state logging {
				do logger.logData;
			}
			then idle;
			
			state error;
			accept Reset
				then idle;
		}
	}
	
	requirement def EnvironmentalSensingRequirements {
		subject sensingUnit : EnvironmentalSensingUnit;
		
		requirement tempSensorCalibration {
			subject tempSensor : TemperatureSensor;
			constraint { tempSensor.calibrationFactor > 0.0 }
		}
		
		requirement dataLoggerBuffer {
			subject logger : DataLogger;
			constraint { logger.buffer.size() > 0 }
		}
	}
}
