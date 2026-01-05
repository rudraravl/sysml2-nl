package DigitalDataSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def BitRate :> Real;
	attribute def DataSize :> Real;
	attribute def ErrorRate :> Real;
	
	item def DigitalDataPacket {
		attribute sequenceId : Integer;
		attribute timestamp : TimeValue;
		attribute payloadSize : DataSize;
		attribute payload : String;
		attribute checksumValue : Integer;
		attribute priority : Integer;
	}
	
	item def ProcessedDataRecord {
		attribute originalPacket : DigitalDataPacket;
		attribute processingTimestamp : TimeValue;
		attribute validationStatus : Boolean;
		attribute transformedPayload : String;
	}
	
	attribute def SystemMetrics {
		attribute totalPacketsReceived : Integer;
		attribute totalPacketsProcessed : Integer;
		attribute totalPacketsTransmitted : Integer;
		attribute currentErrorRate : ErrorRate;
		attribute averageThroughput : BitRate;
	}
	
	port def DigitalInputPort {
		in item dataIn : DigitalDataPacket;
	}
	
	port def DigitalOutputPort {
		out item dataOut : DigitalDataPacket;
	}
	
	port def ProcessedDataPort {
		out item processedOut : ProcessedDataRecord;
	}
	
	port def ControlPort {
		in attribute enableSignal : Boolean;
		in attribute resetSignal : Boolean;
		out attribute statusMetrics : SystemMetrics;
	}
	
	action def ReceiveDigitalData {
		in incomingPacket : DigitalDataPacket;
		out receivedPacket : DigitalDataPacket;
		out receptionTime : TimeValue;
	}
	
	action def ValidateDataIntegrity {
		in packet : DigitalDataPacket;
		out isValid : Boolean;
		out validatedPacket : DigitalDataPacket;
		out computedChecksum : Integer;
	}
	
	action def TransformData {
		in validPacket : DigitalDataPacket;
		out transformedRecord : ProcessedDataRecord;
	}
	
	action def StoreProcessedData {
		in record : ProcessedDataRecord;
		out storageSuccess : Boolean;
		out storageLocation : Integer;
	}
	
	action def TransmitData {
		in packet : DigitalDataPacket;
		out transmissionSuccess : Boolean;
		out transmissionTime : TimeValue;
	}
	
	action def UpdateMetrics {
		in packetsReceived : Integer;
		in packetsProcessed : Integer;
		in packetsTransmitted : Integer;
		out metrics : SystemMetrics;
	}
	
	part def DataReceptionUnit {
		port input : DigitalInputPort;
		port output : DigitalOutputPort;
		
		attribute receptionBuffer : DigitalDataPacket[*];
		attribute bufferCapacity : Integer := 100;
		
		perform action receiveData : ReceiveDigitalData;
	}
	
	part def DataValidationUnit {
		port input : DigitalInputPort;
		port output : DigitalOutputPort;
		
		attribute validationAlgorithm : String := "CRC32";
		attribute validationThreshold : Real := 0.99;
		
		perform action validateData : ValidateDataIntegrity;
	}
	
	part def DataTransformationUnit {
		port input : DigitalInputPort;
		port output : ProcessedDataPort;
		
		attribute transformationRules : String[*];
		attribute processingQueue : DigitalDataPacket[*];
		
		perform action transformData : TransformData;
	}
	
	part def DataStorageUnit {
		port input : ProcessedDataPort;
		
		attribute storedRecords : ProcessedDataRecord[*];
		attribute storageCapacity : DataSize := 1000000.0;
		attribute currentUsage : DataSize := 0.0;
		
		perform action storeData : StoreProcessedData;
	}
	
	part def DataTransmissionUnit {
		port input : DigitalInputPort;
		port output : DigitalOutputPort;
		
		attribute transmissionRate : BitRate := 1000000.0;
		attribute transmissionQueue : DigitalDataPacket[*];
		
		perform action transmitData : TransmitData;
	}
	
	part def SystemMonitor {
		port control : ControlPort;
		
		attribute metrics : SystemMetrics;
		attribute monitoringInterval : TimeValue;
		
		perform action updateMetrics : UpdateMetrics;
	}
	
	action processDigitalDataFlow {
		in inputPacket : DigitalDataPacket;
		out finalMetrics : SystemMetrics;
		
		first start;
		then merge continueProcessing;
		
		then action receive : ReceiveDigitalData {
			in incomingPacket = inputPacket;
			out receivedPacket : DigitalDataPacket;
			out receptionTime : TimeValue;
		}
		
		then action validate : ValidateDataIntegrity {
			in packet = receive.receivedPacket;
			out isValid : Boolean;
			out validatedPacket : DigitalDataPacket;
			out computedChecksum : Integer;
		}
		
		then decide;
			if validate.isValid then transform;
			if !validate.isValid then logError;
		
		action transform : TransformData {
			in validPacket = validate.validatedPacket;
			out transformedRecord : ProcessedDataRecord;
		}
		then store;
		
		action store : StoreProcessedData {
			in record = transform.transformedRecord;
			out storageSuccess : Boolean;
			out storageLocation : Integer;
		}
		then transmit;
		
		action transmit : TransmitData {
			in packet = validate.validatedPacket;
			out transmissionSuccess : Boolean;
			out transmissionTime : TimeValue;
		}
		then updateStatusAction;
		
		action logError {
			then updateErrorStatusAction;
		}
		
		action updateStatusAction : UpdateMetrics {
			in packetsReceived : Integer;
			in packetsProcessed : Integer;
			in packetsTransmitted : Integer;
			out metrics : SystemMetrics;
		}
		then continueProcessing;
		
		action updateErrorStatusAction : UpdateMetrics {
			in packetsReceived : Integer;
			in packetsProcessed : Integer;
			in packetsTransmitted : Integer;
			out metrics : SystemMetrics;
		}
		then continueProcessing;
	}
	
	state def DigitalDataProcessingStates {
		entry; then idle;
		
		state idle;
		accept enableSignal;
		then operational;
		
		state operational;
		
		accept resetSignal;
		then idle;
	}
	
	part def DigitalDataProcessingSystem {
		doc /* 
		 * A digital data processing system that receives digital data packets,
		 * validates their integrity, transforms them according to processing rules,
		 * stores the processed records, and transmits the validated data to downstream systems.
		 */
		
		port externalInput : DigitalInputPort;
		port externalOutput : DigitalOutputPort;
		port systemControl : ControlPort;
		
		attribute systemMetrics : SystemMetrics;
		attribute operationalState : String;
		
		part receptionUnit : DataReceptionUnit;
		part validationUnit : DataValidationUnit;
		part transformationUnit : DataTransformationUnit;
		part storageUnit : DataStorageUnit;
		part transmissionUnit : DataTransmissionUnit;
		part monitor : SystemMonitor;
		
		connection externalToReception connect externalInput to receptionUnit.input;
		connection receptionToValidation connect receptionUnit.output to validationUnit.input;
		connection validationToTransformation connect validationUnit.output to transformationUnit.input;
		connection transformationToStorage connect transformationUnit.output to storageUnit.input;
		connection validationToTransmission connect validationUnit.output to transmissionUnit.input;
		connection transmissionToExternal connect transmissionUnit.output to externalOutput;
		connection monitorControl connect systemControl to monitor.control;
		
		perform action processDigitalDataFlow;
		
		state lifecycle : DigitalDataProcessingStates;
	}
	
	requirement def FunctionalRequirement {
		doc /* Base functional requirement for digital data processing system. */
		subject system : DigitalDataProcessingSystem;
	}
	
	requirement def PerformanceRequirement {
		doc /* Base performance requirement for digital data processing system. */
		subject system : DigitalDataProcessingSystem;
	}
	
	requirement def ReliabilityRequirement {
		doc /* Base reliability requirement for digital data processing system. */
		subject system : DigitalDataProcessingSystem;
	}
	
	requirement <'FR-001'> dataReceptionRequirement : FunctionalRequirement {
		doc /* The system shall receive digital data packets from external sources continuously. */
		subject system : DigitalDataProcessingSystem;
		
		require constraint {
			system.receptionUnit.bufferCapacity >= 100
		}
	}
	
	requirement <'FR-002'> dataValidationRequirement : FunctionalRequirement {
		doc /* The system shall validate the integrity of each received data packet using checksum verification. */
		subject system : DigitalDataProcessingSystem;
		
		require constraint {
			system.validationUnit.validationThreshold >= 0.99
		}
	}
	
	requirement <'FR-003'> dataTransformationRequirement : FunctionalRequirement {
		doc /* The system shall transform validated data packets according to configured processing rules. */
		subject system : DigitalDataProcessingSystem;
	}
	
	requirement <'FR-004'> dataStorageRequirement : FunctionalRequirement {
		doc /* The system shall store processed data records in persistent storage for retrieval and analysis. */
		subject system : DigitalDataProcessingSystem;
		
		require constraint {
			system.storageUnit.currentUsage <= system.storageUnit.storageCapacity
		}
	}
	
	requirement <'FR-005'> dataTransmissionRequirement : FunctionalRequirement {
		doc /* The system shall transmit validated data packets to downstream systems. */
		subject system : DigitalDataProcessingSystem;
		
		require constraint {
			system.transmissionUnit.transmissionRate >= 1000000.0
		}
	}
	
	requirement <'PR-001'> throughputRequirement : PerformanceRequirement {
		doc /* The system shall process at least 1000 data packets per second. */
		subject system : DigitalDataProcessingSystem;
	}
	
	requirement <'PR-002'> latencyRequirement : PerformanceRequirement {
		doc /* The system shall process each data packet within 100 milliseconds from reception to transmission. */
		subject system : DigitalDataProcessingSystem;
	}
	
	requirement <'RR-001'> errorRateRequirement : ReliabilityRequirement {
		doc /* The system shall maintain a data error rate below 0.01 percent. */
		subject system : DigitalDataProcessingSystem;
		
		require constraint {
			system.systemMetrics.currentErrorRate < 0.0001
		}
	}
	
	requirement <'RR-002'> availabilityRequirement : ReliabilityRequirement {
		doc /* The system shall maintain 99.9 percent operational availability. */
		subject system : DigitalDataProcessingSystem;
	}
	
	requirement systemMissionRequirement {
		doc /* 
		 * The digital data processing system shall provide reliable, high-performance
		 * processing of digital data packets through continuous reception, validation,
		 * transformation, storage, and transmission operations while maintaining
		 * comprehensive system monitoring and error handling capabilities.
		 */
		
		require dataReceptionRequirement;
		require dataValidationRequirement;
		require dataTransformationRequirement;
		require dataStorageRequirement;
		require dataTransmissionRequirement;
		require throughputRequirement;
		require latencyRequirement;
		require errorRateRequirement;
		require availabilityRequirement;
	}
	
	part digitalSystem : DigitalDataProcessingSystem;
}
