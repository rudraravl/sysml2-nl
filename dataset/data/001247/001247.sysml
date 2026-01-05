package 'Shock Data Logger System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def EventID;
	attribute def TimestampValue;
	attribute def ThresholdLevel;
	
	item def AccelerationReading {
		attribute xAxis : AccelerationValue;
		attribute yAxis : AccelerationValue;
		attribute zAxis : AccelerationValue;
		attribute timestamp : TimestampValue;
		attribute resultantMagnitude : AccelerationValue;
	}
	
	item def ShockEventRecord {
		attribute eventID : EventID;
		attribute peakAcceleration : AccelerationValue;
		attribute eventDuration : DurationValue;
		attribute eventTimestamp : TimestampValue;
		attribute accelerationProfile : AccelerationReading[*] ordered;
	}
	
	port def SensorPort {
		out reading : AccelerationReading;
	}
	
	port def MemoryPort {
		in eventRecord : ShockEventRecord;
	}
	
	port def PowerSupplyPort {
		in voltage : ISQ::ElectricPotentialDifferenceValue;
	}
	
	port def DataInterfacePort {
		out storedEvents : ShockEventRecord[*];
		in configThreshold : ThresholdLevel;
	}
	
	part def TriaxialAccelerometer {
		port sensorOutput : SensorPort;
		attribute samplingFrequency : ISQ::FrequencyValue;
		attribute measurementRange : AccelerationValue;
	}
	
	action def ComputeMagnitude {
		in xComponent : AccelerationValue;
		in yComponent : AccelerationValue;
		in zComponent : AccelerationValue;
		out magnitude : AccelerationValue;
	}
	
	action def EvaluateThreshold {
		in magnitude : AccelerationValue;
		in threshold : ThresholdLevel;
		out exceedsThreshold : Boolean;
	}
	
	action def BuildEventRecord {
		in readings : AccelerationReading[*];
		out event : ShockEventRecord;
	}
	
	action def AnalyzeAcceleration {
		in rawReading : AccelerationReading;
		out detectedEvent : ShockEventRecord;
	}
	
	part def SignalProcessor {
		port sensorInput : ~SensorPort;
		port memoryOutput : MemoryPort;
		attribute detectionThreshold : ThresholdLevel;
	}
	
	action def WriteEvent {
		in event : ShockEventRecord;
		out writeSuccess : Boolean;
	}
	
	action def QueryEvents {
		in startTime : TimestampValue;
		in endTime : TimestampValue;
		out matchingEvents : ShockEventRecord[*];
	}
	
	part def NonVolatileMemory {
		port dataInput : ~MemoryPort;
		attribute storageCapacity : ISQ::InformationCapacityValue;
		attribute recordedEvents : ShockEventRecord[*] ordered;
	}
	
	part def BatteryPowerUnit {
		port powerOutput : PowerSupplyPort;
		attribute remainingCapacity : ISQ::EnergyValue;
		
		state batteryStates {
			entry; then fullCharge;
			
			state fullCharge;
			transition fullToNormal
				first fullCharge
				accept dischargingEvent
				then normalOperation;
			
			state normalOperation;
			transition normalToLow
				first normalOperation
				accept lowBatteryEvent
				then lowPowerState;
			
			state lowPowerState;
			transition lowToCritical
				first lowPowerState
				accept criticalBatteryEvent
				then criticalState;
			
			state criticalState;
		}
	}
	
	action def DownloadEvents {
		in eventList : ShockEventRecord[*];
		out transferComplete : Boolean;
	}
	
	action def UpdateConfiguration {
		out newThreshold : ThresholdLevel;
		out newSamplingRate : ISQ::FrequencyValue;
	}
	
	part def CommunicationModule {
		port dataPort : DataInterfacePort;
	}
	
	part def ShockDataLoggerDevice {
		part sensor : TriaxialAccelerometer;
		part processor : SignalProcessor;
		part memory : NonVolatileMemory;
		part power : BatteryPowerUnit;
		part comms : CommunicationModule;
		
		port externalPowerInput : PowerSupplyPort;
		port externalDataInterface : DataInterfacePort;
		
		connection sensorToProcessor connect 
			sensor.sensorOutput to processor.sensorInput;
		
		connection processorToMemory connect 
			processor.memoryOutput to memory.dataInput;
		
		connection powerConnection connect 
			externalPowerInput to power.powerOutput;
		
		connection commsConnection connect 
			comms.dataPort to externalDataInterface;
		
		perform action monitorAndRecordShocks {
			first start;
			then merge continuousOperation;
			
			action systemInitialization {
				action powerUpSequence;
				then action sensorCalibration;
				then action loadSettings;
			}
			
			then continuousOperation;
			
			action acquireData {
				out currentReading : AccelerationReading;
			}
			
			then decide;
				if acquireData.currentReading.resultantMagnitude >= processor.detectionThreshold 
					then recordShockEvent;
				if acquireData.currentReading.resultantMagnitude < processor.detectionThreshold 
					then continuousOperation;
			
			action recordShockEvent {
				action captureHighResolutionData {
					out eventReadings : AccelerationReading[*];
				}
				then action processEventData {
					in rawData : AccelerationReading[*];
					out processedEvent : ShockEventRecord;
				}
				then action storeInMemory {
					in event : ShockEventRecord;
				}
				then action notifySystem {
					in event : ShockEventRecord;
				}
			}
			
			then continuousOperation;
			
			accept systemShutdown;
			then action shutdownSequence {
				action finalizeRecords;
				then action enterSleepMode;
			}
			then done;
		}
	}
	
	requirement <'REQ-SDL-001'> shockDetectionCapability {
		doc /* The shock data logger shall detect and record shock events when 
		       the resultant acceleration magnitude exceeds the configured threshold 
		       value across any combination of the three orthogonal axes. */
		
		subject device : ShockDataLoggerDevice;
		
		require constraint {
			device.processor.detectionThreshold > 0.0
		}
	}
	
	requirement <'REQ-SDL-002'> eventStorageCapacity {
		doc /* The shock data logger shall provide non-volatile storage capacity 
		       sufficient to retain at least 2000 complete shock event records 
		       including full acceleration profiles. */
		
		subject device : ShockDataLoggerDevice;
		
		require constraint {
			device.memory.storageCapacity >= 2000.0
		}
	}
	
	requirement <'REQ-SDL-003'> dataAcquisitionRate {
		doc /* The shock data logger shall continuously sample acceleration data 
		       at a minimum rate of 1000 Hz during normal monitoring and increase 
		       to 10000 Hz when a shock event is detected. */
		
		subject device : ShockDataLoggerDevice;
		
		require constraint {
			device.sensor.samplingFrequency >= 1000.0
		}
	}
	
	requirement <'REQ-SDL-004'> operationalDuration {
		doc /* The shock data logger shall operate continuously for a minimum 
		       of 30 days on internal battery power under typical monitoring 
		       conditions with up to 10 shock events per day. */
		
		subject device : ShockDataLoggerDevice;
	}
	
	requirement <'REQ-SDL-005'> dataRetrievalCapability {
		doc /* The shock data logger shall provide the capability to retrieve 
		       stored shock event records through the communication interface 
		       for post-event analysis and reporting. */
		
		subject device : ShockDataLoggerDevice;
	}
	
	requirement primaryMissionRequirement {
		doc /* The shock data logger system shall continuously monitor the 
		       three-dimensional acceleration environment, automatically detect 
		       shock events exceeding configurable thresholds, capture detailed 
		       time-history acceleration profiles during events, store event 
		       records with timestamps in non-volatile memory, and provide 
		       reliable data retrieval capabilities for subsequent engineering 
		       analysis, equipment health assessment, and transportation 
		       damage investigation. */
		
		assume constraint {
			doc /* The system operates within environmental conditions of 
			       -40°C to +85°C temperature range, 0% to 95% relative 
			       humidity non-condensing, and acceleration measurement 
			       range of ±200g. */
		}
		
		require shockDetectionCapability;
		require eventStorageCapacity;
		require dataAcquisitionRate;
		require operationalDuration;
		require dataRetrievalCapability;
	}
}
