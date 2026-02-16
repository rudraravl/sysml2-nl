package 'OccupancySensingUnit' {
	private import ScalarValues::*;
	private import SI::*;
	private import ISQ::*;
	
	attribute def OccupancyLevel :> Real;
	
	attribute def OccupantCount :> Integer;
	
	attribute def ConfidenceLevel :> Real;
	
	item def OccupancyMeasurement {
		attribute timestamp: String;
		attribute level: OccupancyLevel;
		attribute count: OccupantCount;
		attribute confidence: ConfidenceLevel;
	}
	
	item def MonitoredSpace {
		attribute spaceId: String;
		attribute area: AreaValue;
		attribute capacity: Integer;
	}
	
	port def SensorDataPort {
		out item measurement: OccupancyMeasurement;
	}
	
	port def PowerSupplyPort {
		in attribute voltage: VoltageValue;
		in attribute current: ElectricCurrentValue;
	}
	
	port def ControlPort {
		in attribute enable: Boolean;
		in attribute sensitivity: Real;
		out attribute status: Integer;
	}
	
	part def OccupancySensor {
		attribute sensorId: String;
		attribute accuracy: Real;
		attribute responseTime: DurationValue;
		attribute operatingVoltage: VoltageValue;
		attribute detectionRange: LengthValue;
		attribute samplingRate: FrequencyValue;
		
		port dataOutput: SensorDataPort;
		port powerInput: PowerSupplyPort;
		port control: ControlPort;
		
		part monitoredSpace: MonitoredSpace[1];
		
		attribute currentMeasurement: OccupancyMeasurement;
	}
	
	part def SignalProcessor {
		attribute processingFrequency: FrequencyValue;
		attribute filterEnabled: Boolean;
		
		port rawDataInput: SensorDataPort;
		port processedDataOutput: SensorDataPort;
		
		action processSignal {
			in rawData: OccupancyMeasurement;
			out processedData: OccupancyMeasurement;
		}
	}
	
	part def DataStorage {
		attribute capacity: Integer;
		attribute recordInterval: DurationValue;
		
		port dataInput: SensorDataPort;
		
		part measurements: OccupancyMeasurement[0..*];
		
		action storeData {
			in measurement: OccupancyMeasurement;
			out stored: Boolean;
		}
	}
	
	action def InitializeSensor {
		in sensor: OccupancySensor;
		out initialized: Boolean;
	}
	
	action def PerformMeasurement {
		in space: MonitoredSpace;
		out measurement: OccupancyMeasurement;
	}
	
	action def ProcessData {
		in rawMeasurement: OccupancyMeasurement;
		out filteredMeasurement: OccupancyMeasurement;
	}
	
	action def StoreReading {
		in measurement: OccupancyMeasurement;
		out success: Boolean;
	}
	
	action def MeasurementCycle {
		in item space: MonitoredSpace;
		out item finalMeasurement: OccupancyMeasurement;
		
		action init: InitializeSensor {
			in sensor;
			out initialized;
		}
		
		then action measure: PerformMeasurement {
			in space = MeasurementCycle::space;
			out rawMeasurement: OccupancyMeasurement;
		}
		
		flow from measure.rawMeasurement to process.rawMeasurement;
		
		then action process: ProcessData {
			in rawMeasurement;
			out filteredMeasurement;
		}
		
		flow from process.filteredMeasurement to store.measurement;
		
		then action store: StoreReading {
			in measurement;
			out success;
		}
		
		bind process.filteredMeasurement = finalMeasurement;
		
		then done;
	}
	
	part def SensingUnit {
		attribute unitId: String;
		attribute installationDate: String;
		attribute calibrationDate: String;
		
		part sensor: OccupancySensor[1] {
			attribute :>> sensorId = "OCC-001";
			attribute :>> accuracy = 0.97;
			attribute :>> responseTime = 1.5[s];
			attribute :>> operatingVoltage = 5.0[V];
			attribute :>> detectionRange = 8.0[m];
			attribute :>> samplingRate = 2.0[Hz];
			
			part :>> monitoredSpace {
				attribute :>> spaceId = "ROOM-A";
				attribute :>> area = 40.0[m^2];
				attribute :>> capacity = 30;
			}
		}
		
		part processor: SignalProcessor[1] {
			attribute :>> processingFrequency = 5.0[Hz];
			attribute :>> filterEnabled = true;
		}
		
		part storage: DataStorage[1] {
			attribute :>> capacity = 5000;
			attribute :>> recordInterval = 1.0[s];
		}
		
		connect sensor.dataOutput to processor.rawDataInput;
		connect processor.processedDataOutput to storage.dataInput;
		
		perform action measurementOperation: MeasurementCycle {
			in space = sensor.monitoredSpace;
			out finalMeasurement;
		}
		
		exhibit state operationalStates {
			entry; then idle;
			
			state idle;
			
			transition idle_to_active
				first idle
				accept MeasurementCycle
				then active;
			
			state active {
				entry action startMeasurement: PerformMeasurement;
			}
			
			transition active_to_processing
				first active
				then processing;
			
			state processing {
				entry action processData: ProcessData;
			}
			
			transition processing_to_reporting
				first processing
				then reporting;
			
			state reporting;
			
			transition reporting_to_idle
				first reporting
				then idle;
			
			transition error_transition
				first active
				then error;
			
			state error;
			
			transition error_to_idle
				first error
				then idle;
		}
	}
	
	requirement def OccupancySensingRequirements {
		doc /* The sensing unit shall accurately measure occupancy in the monitored space. */
		
		subject unit: SensingUnit;
		
		require accuracyRequirement {
			doc /* Measurement accuracy shall be at least 95%. */
			assume constraint { unit.sensor.accuracy >= 0.95 }
		}
		
		require responseTimeRequirement {
			doc /* Response time shall not exceed 2 seconds. */
			assume constraint { unit.sensor.responseTime <= 2.0[s] }
		}
		
		require operatingVoltageRequirement {
			doc /* Operating voltage shall be between 3.3V and 5.5V. */
			assume constraint { 
				unit.sensor.operatingVoltage >= 3.3[V] and 
				unit.sensor.operatingVoltage <= 5.5[V] 
			}
		}
		
		require samplingRateRequirement {
			doc /* Sampling rate shall be at least 1 Hz. */
			assume constraint { unit.sensor.samplingRate >= 1.0[Hz] }
		}
	}
	
	verification verifySensingUnit: OccupancySensingRequirements {
		subject testUnit: SensingUnit;
	}
	
	part sensingSystem: SensingUnit {
		attribute :>> unitId = "UNIT-001";
		attribute :>> installationDate = "2024-01-10";
		attribute :>> calibrationDate = "2024-01-09";
		
		perform action :>> measurementOperation;
	}
	
	individual def TestUnit :> SensingUnit;
	individual def TestSpace :> MonitoredSpace;
	
	individual testSystem: TestUnit :> sensingSystem {
		timeslice normalOperation {
			perform action :>> measurementOperation {
				in individual :>> space: TestSpace {
					:>> spaceId = "TEST-ROOM";
					:>> area = 35.0[m^2];
					:>> capacity = 25;
				}
				out individual :>> finalMeasurement {
					:>> timestamp = "2024-03-15T14:30:00Z";
					:>> level = 0.6;
					:>> count = 15;
					:>> confidence = 0.98;
				}
			}
		}
		
		then timeslice highOccupancy {
			perform action :>> measurementOperation {
				in individual :>> space: TestSpace {
					:>> spaceId = "TEST-ROOM";
					:>> area = 35.0[m^2];
					:>> capacity = 25;
				}
				out individual :>> finalMeasurement {
					:>> timestamp = "2024-03-15T14:31:00Z";
					:>> level = 0.92;
					:>> count = 23;
					:>> confidence = 0.96;
				}
			}
		}
	}
}
