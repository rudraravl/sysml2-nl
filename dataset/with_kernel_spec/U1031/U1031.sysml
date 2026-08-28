package DataProcessingSystemModel {
	private import ScalarValues::*;
	private import ISQ::*;

	item def DataPacket {
		attribute id : String;
		attribute payload : String;
		attribute checksum : Integer;
	}

	item def ProcessedRecord {
		attribute packetId : String;
		attribute transformedPayload : String;
		attribute timestamp : Integer;
	}

	attribute def ControlStatus {
		attribute throughput : Real;
		attribute errorRate : Real;
		attribute packetsProcessed : Integer;
	}

	attribute def EnableSignal;
	attribute def ResetSignal;

	port def DataInPort {
		in item packet : DataPacket;
	}

	port def DataOutPort {
		out item packet : DataPacket;
	}

	port def RecordInPort {
		in item record : ProcessedRecord;
	}

	port def RecordOutPort {
		out item record : ProcessedRecord;
	}

	port def ControlPort {
		in attribute enable : EnableSignal;
		in attribute reset : ResetSignal;
		out attribute status : ControlStatus;
	}

	action def ReceiveData {
		in item packet : DataPacket;
		out item bufferedPacket : DataPacket;
	}

	action def ValidateData {
		in item packet : DataPacket;
		out item validPacket : DataPacket;
		out item invalidPacket : DataPacket;
	}

	action def TransformData {
		in item packet : DataPacket;
		out item record : ProcessedRecord;
	}

	action def StoreData {
		in item record : ProcessedRecord;
	}

	action def TransmitData {
		in item packet : DataPacket;
	}

	action def MonitorSystem {
		out attribute status : ControlStatus;
	}

	part def DataReceptionUnit {
		port dataIn : DataInPort;
		port dataOut : DataOutPort;
		perform action receive : ReceiveData;
	}

	part def DataValidationUnit {
		port dataIn : DataInPort;
		port validDataOut : DataOutPort;
		port discardOut : DataOutPort;
		perform action validate : ValidateData;
	}

	part def DataTransformationUnit {
		port dataIn : DataInPort;
		port recordOut : RecordOutPort;
		perform action transform : TransformData;
	}

	part def DataStorageUnit {
		port recordIn : RecordInPort;
		perform action store : StoreData;
	}

	part def DataTransmissionUnit {
		port dataIn : DataInPort;
		port dataOut : DataOutPort;
		perform action transmit : TransmitData;
	}

	part def SystemMonitor {
		port control : ControlPort;
		perform action monitor : MonitorSystem;
	}

	part def DataProcessingSystem {
		port systemIn : DataInPort;
		port systemOut : DataOutPort;
		port systemControl : ControlPort;

		part receptionUnit : DataReceptionUnit;
		part validationUnit : DataValidationUnit;
		part transformationUnit : DataTransformationUnit;
		part storageUnit : DataStorageUnit;
		part transmissionUnit : DataTransmissionUnit;
		part monitor : SystemMonitor;

		connection sysInFlow connect systemIn to receptionUnit.dataIn;
		connection dataFlow1 connect receptionUnit.dataOut to validationUnit.dataIn;
		connection dataFlow2 connect validationUnit.validDataOut to transformationUnit.dataIn;
		connection dataFlow3 connect validationUnit.validDataOut to transmissionUnit.dataIn;
		connection recordFlow connect transformationUnit.recordOut to storageUnit.recordIn;
		connection sysOutFlow connect transmissionUnit.dataOut to systemOut;
		connection controlFlow connect systemControl to monitor.control;

		exhibit state systemStates {
			entry; then idle;
			state idle;
			accept enable : EnableSignal via systemControl
				then operational;
			state operational {
				do monitor.monitor;
			}
			accept reset : ResetSignal via systemControl
				then idle;
		}
	}

	requirement def ReliabilityRequirement {
		doc /* The system must reliably process and forward data packets without loss. */
		attribute minReliability : Real = 0.99;
	}

	requirement def IntegrityRequirement {
		doc /* The system must discard corrupted data packets detected by checksum validation. */
	}

	requirement def EfficiencyRequirement {
		doc /* The system must process data streams efficiently with minimal latency. */
		attribute maxLatency : Real = 0.1;
	}

	requirement def MonitoringRequirement {
		doc /* The system monitor shall continuously track throughput, error rates, and total packets processed. */
		attribute minThroughput : Real = 1000.0;
		attribute maxErrorRate : Real = 0.01;
	}
}
