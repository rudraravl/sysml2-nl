package 'Sensing Unit Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import ScalarFunctions::*;
	
	attribute def SensorReading {
		attribute numericValue : Real;
		attribute unit : String;
		attribute timestamp : Real;
		attribute quality : Real;
	}
	
	attribute def TemperatureReading :> SensorReading {
		attribute :>> unit = "K";
	}
	
	attribute def PressureReading :> SensorReading {
		attribute :>> unit = "Pa";
	}
	
	item def PhysicalQuantity;
	item def TemperatureQuantity :> PhysicalQuantity;
	item def PressureQuantity :> PhysicalQuantity;
	
	port def SensorPort {
		out item reading : SensorReading;
	}
	
	port def DataPort {
		in item sensorData : SensorReading;
	}
	
	part def Sensor {
		attribute sensorId : String;
		attribute calibrationFactor : Real default 1.0;
		attribute minRange : Real;
		attribute maxRange : Real;
		port sensorOutput : SensorPort;
		
		action sense {
			in item physicalInput : PhysicalQuantity;
			out item measurement : SensorReading;
		}
	}
	
	part def TemperatureSensor :> Sensor {
		attribute :>> minRange = -40.0;
		attribute :>> maxRange = 125.0;
		port :>> sensorOutput {
			out item :>> reading : TemperatureReading;
		}
		
		action :>> sense {
			in item :>> physicalInput : TemperatureQuantity;
			out item :>> measurement : TemperatureReading;
		}
	}
	
	part def PressureSensor :> Sensor {
		attribute :>> minRange = 0.0;
		attribute :>> maxRange = 1000.0;
		port :>> sensorOutput {
			out item :>> reading : PressureReading;
		}
		
		action :>> sense {
			in item :>> physicalInput : PressureQuantity;
			out item :>> measurement : PressureReading;
		}
	}
	
	part def SignalProcessor {
		port dataInput : DataPort;
		attribute processedValue : Real;
		
		action processSignal {
			in item rawData : SensorReading;
			out item filteredData : SensorReading;
		}
	}
	
	part def DataLogger {
		port dataInput : DataPort;
		attribute logBuffer : SensorReading[100];
		attribute logIndex : Integer default 0;
		
		action logData {
			in item dataToLog : SensorReading;
		}
	}
	
	connection def SensorDataConnection {
		end source : SensorPort;
		end target : DataPort;
	}
	
	action def SensorActivationEvent;
	action def DataReadyEvent;
	action def ProcessingCompleteEvent;
	action def LoggingCompleteEvent;
	action def SensorErrorEvent;
	action def ErrorClearedEvent;
	
	part def SensingUnit {
		attribute unitId : String;
		attribute operationalStatus : String default "idle";
		
		part sensors : Sensor[1..*];
		part processor : SignalProcessor[1];
		part logger : DataLogger[1];
		
		connection sensorToProcessor : SensorDataConnection[1..*]
			connect source references sensors.sensorOutput
			to target references processor.dataInput;
			
		connection processorToLogger : SensorDataConnection[1]
			connect source references processor.dataInput
			to target references logger.dataInput;
		
		action measureQuantity {
			in item environmentalInput : PhysicalQuantity;
			out item processedMeasurement : SensorReading;
			
			action acquireData {
				in item inputQuantity : PhysicalQuantity;
				out item rawReading : SensorReading;
			}
			then action filterData {
				in item rawInput : SensorReading;
				out item filteredReading : SensorReading;
			}
			then action storeData {
				in item dataToStore : SensorReading;
			}
			
			bind acquireData.inputQuantity = environmentalInput;
			flow from acquireData.rawReading to filterData.rawInput;
			flow from filterData.filteredReading to storeData.dataToStore;
			bind filterData.filteredReading = processedMeasurement;
		}
		
		state sensingStateMachine {
			entry; then idle;
			
			state idle;
			transition idle_to_measuring
				first idle
				accept at SensorActivationEvent
				then measuring;
			
			state measuring {
				entry action startMeasurement;
				do action continuousMeasurement;
				exit action stopMeasurement;
			}
			transition measuring_to_processing
				first measuring
				accept at DataReadyEvent
				then processing;
			
			state processing {
				do action processData;
			}
			transition processing_to_logging
				first processing
				accept at ProcessingCompleteEvent
				then logging;
			
			state logging {
				do action logMeasurement;
			}
			transition logging_to_idle
				first logging
				accept at LoggingCompleteEvent
				then idle;
			
			transition measuring_to_error
				first measuring
				accept at SensorErrorEvent
				then error;
			
			state error {
				entry action handleError;
			}
			transition error_to_idle
				first error
				accept at ErrorClearedEvent
				then idle;
		}
	}
	
	part environmentalSensingUnit : SensingUnit {
		attribute :>> unitId = "ENV-001";
		
		part tempSensor : TemperatureSensor :>> sensors {
			attribute :>> sensorId = "TEMP-001";
			attribute :>> calibrationFactor = 0.98;
		}
		
		part pressureSensor : PressureSensor :>> sensors {
			attribute :>> sensorId = "PRES-001";
			attribute :>> calibrationFactor = 1.02;
		}
		
		part :>> processor {
			attribute :>> processedValue = 0.0;
		}
		
		part :>> logger {
			attribute :>> logIndex = 0;
		}
	}
	
	requirement def SensingAccuracyRequirement {
		doc /* The sensing unit shall measure the physical quantity with specified accuracy. */
		subject sensingUnit : SensingUnit;
		assume constraint { sensingUnit.sensors.calibrationFactor > 0.0 }
		require constraint { 
			sensingUnit.sensors.calibrationFactor >= 0.95 and 
			sensingUnit.sensors.calibrationFactor <= 1.05
		}
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* Each sensor shall operate within its specified measurement range. */
		subject sensor : Sensor;
		require constraint {
			sensor.minRange < sensor.maxRange
		}
	}
	
	requirement def DataLoggingRequirement {
		doc /* The sensing unit shall log all measurements for traceability. */
		subject sensingUnit : SensingUnit;
		require constraint {
			sensingUnit.logger.logIndex >= 0
		}
	}
	
	requirement sensingSystemRequirements {
		requirement accuracyReq : SensingAccuracyRequirement {
			subject testUnit = environmentalSensingUnit;
		}
		
		requirement rangeReq : MeasurementRangeRequirement {
			subject testSensor = environmentalSensingUnit.tempSensor;
		}
		
		requirement loggingReq : DataLoggingRequirement {
			subject testUnit = environmentalSensingUnit;
		}
	}
	
	individual def TestTemperatureInput :> TemperatureQuantity;
	individual def TestPressureInput :> PressureQuantity;
	
	individual testSensingUnit : SensingUnit :> environmentalSensingUnit {
		timeslice measurement1 {
			perform action :>> measureQuantity {
				in individual :>> environmentalInput : TestTemperatureInput;
				out :>> processedMeasurement {
					:>> numericValue = 25.3;
					:>> timestamp = 1000.0;
					:>> quality = 0.95;
				}
			}
		}
		then timeslice measurement2 {
			perform action :>> measureQuantity {
				in individual :>> environmentalInput : TestPressureInput;
				out :>> processedMeasurement {
					:>> numericValue = 101.325;
					:>> timestamp = 2000.0;
					:>> quality = 0.98;
				}
			}
		}
	}
}
