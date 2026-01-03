package MedicalIdentificationTagSystem {
	private import ScalarValues::*;
	private import SI::*;
	private import ISQ::*;
	
	attribute def PatientID :> String;
	attribute def BloodType :> String;
	attribute def AllergyInfo :> String;
	attribute def MedicalCondition :> String;
	attribute def EmergencyContactInfo :> String;
	attribute def MedicationName :> String;
	
	item def MedicalData {
		attribute patientID : PatientID;
		attribute bloodType : BloodType;
		attribute allergies : AllergyInfo[0..*];
		attribute conditions : MedicalCondition[0..*];
		attribute medications : MedicationName[0..*];
		attribute emergencyContact : EmergencyContactInfo;
		attribute lastUpdated : String;
	}
	
	item def ScanRequest {
		attribute requestID : String;
		attribute timestamp : String;
	}
	
	item def DataResponse {
		attribute medicalData : MedicalData;
		attribute responseID : String;
		attribute transmissionStatus : String;
	}
	
	port def RFIDPort {
		in item scanSignal : ScanRequest;
		out item medicalDataOut : DataResponse;
	}
	
	port def ScannerPort {
		out item scanCommand : ScanRequest;
		in item receivedData : DataResponse;
	}
	
	part def RFIDChip {
		port rfidInterface : RFIDPort;
		attribute chipID : String;
		attribute operatingFrequency : ISQ::frequency;
		attribute transmitPower : ISQ::power;
		
		perform action respondToScan {
			in request : ScanRequest;
			out response : DataResponse;
		}
	}
	
	part def SecureMemory {
		attribute storageCapacity : Real;
		attribute encryptionEnabled : Boolean;
		attribute storedData : MedicalData;
		
		perform action storeData {
			in data : MedicalData;
		}
		
		perform action retrieveData {
			out data : MedicalData;
		}
	}
	
	part def BatteryPower {
		attribute batteryLevel : Real;
		attribute voltage : ISQ::voltage;
		attribute capacity : ISQ::energy;
		
		perform action providePower {
			out powerOutput : ISQ::power;
		}
	}
	
	part def Antenna {
		attribute antennaGain : Real;
		attribute operatingRange : ISQ::length;
		
		perform action transmitSignal {
			in dataPacket : DataResponse;
		}
		
		perform action receiveSignal {
			out scanRequest : ScanRequest;
		}
	}
	
	part def MedicalIDTag {
		port tagInterface : RFIDPort;
		
		part rfid : RFIDChip {
			attribute :>> chipID = "TAG-MED-001";
			attribute :>> operatingFrequency = 13.56;
			attribute :>> transmitPower = 0.1;
		}
		
		part memory : SecureMemory {
			attribute :>> storageCapacity = 2048.0;
			attribute :>> encryptionEnabled = true;
		}
		
		part battery : BatteryPower {
			attribute :>> batteryLevel = 95.0;
			attribute :>> voltage = 3.0;
			attribute :>> capacity = 500.0;
		}
		
		part antenna : Antenna {
			attribute :>> antennaGain = 2.0;
			attribute :>> operatingRange = 0.1;
		}
		
		connection rfidToMemory connect rfid to memory;
		connection batteryToRFID connect battery to rfid;
		connection rfidToAntenna connect rfid to antenna;
		
		bind tagInterface = rfid.rfidInterface;
	}
	
	part def MedicalScanner {
		port scannerInterface : ScannerPort;
		attribute scanRange : ISQ::length;
		attribute readFrequency : ISQ::frequency;
		
		perform action initiateScan {
			out scanRequest : ScanRequest;
		}
		
		perform action processResponse {
			in dataResponse : DataResponse;
		}
		
		perform action displayInformation {
			in medicalInfo : MedicalData;
		}
	}
	
	part medicalIDSystem {
		part tag : MedicalIDTag {
			part :>> memory {
				attribute :>> storedData.patientID = "PT-2024-5678";
				attribute :>> storedData.bloodType = "A+";
				attribute :>> storedData.allergies = ("Penicillin", "Latex");
				attribute :>> storedData.conditions = ("Type 2 Diabetes", "Hypertension");
				attribute :>> storedData.medications = ("Metformin", "Lisinopril");
				attribute :>> storedData.emergencyContact = "Dr. Smith: +1-555-0100";
				attribute :>> storedData.lastUpdated = "2024-01-15";
			}
		}
		
		part scanner : MedicalScanner {
			attribute :>> scanRange = 0.15;
			attribute :>> readFrequency = 13.56;
		}
		
		connection tagToScanner connect tag.tagInterface to scanner.scannerInterface;
	}
	
	action def InitiateScan {
		out scanSignal : ScanRequest;
		
		first start;
		then assign scanSignal.requestID := "SCAN-REQ-001";
		then assign scanSignal.timestamp := "2024-01-15T10:30:00Z";
		then done;
	}
	
	action def RetrieveMedicalData {
		in storedInfo : MedicalData;
		out retrievedData : MedicalData;
		
		first start;
		then assign retrievedData := storedInfo;
		then done;
	}
	
	action def TransmitResponse {
		in medicalInfo : MedicalData;
		in requestID : String;
		out response : DataResponse;
		
		first start;
		then assign response.medicalData := medicalInfo;
		then assign response.responseID := requestID;
		then assign response.transmissionStatus := "Success";
		then done;
	}
	
	action def ValidateTransmission {
		in receivedResponse : DataResponse;
		out isValid : Boolean;
		
		first start;
		then decide;
			if receivedResponse.transmissionStatus == "Success" then validAction;
			if receivedResponse.transmissionStatus != "Success" then invalidAction;
		action validAction {
			then assign isValid := true;
		}
		action invalidAction {
			then assign isValid := false;
		}
		then done;
	}
	
	action def MedicalTagOperation {
		first start;
		then merge waitForScan;
		
		then action scanInit : InitiateScan {
			out scanRequest : ScanRequest;
		}
		
		then action retrieveData : RetrieveMedicalData {
			in storedInfo : MedicalData;
			out medicalInfo : MedicalData;
		}
		
		then action transmit : TransmitResponse {
			in medicalInfo = retrieveData.retrievedData;
			in requestID = scanInit.scanSignal.requestID;
			out dataResponse : DataResponse;
		}
		
		then action validate : ValidateTransmission {
			in receivedResponse = transmit.response;
			out validationResult : Boolean;
		}
		
		then decide;
			if validate.isValid then displayData;
			if not validate.isValid then retransmit;
		
		action displayData {
			in finalData : MedicalData = transmit.response.medicalData;
		}
		then done;
		
		action retransmit;
		then waitForScan;
	}
	
	state def TagOperationalStates {
		in part batteryRef : BatteryPower;
		
		entry; then idle;
		
		state idle {
			entry assign batteryRef.batteryLevel := 95.0;
		}
		
		transition idle_to_scanning
			first idle
			accept ScanRequest
			then scanning;
		
		state scanning {
			entry action detectScan;
			do action activateRFID;
		}
		
		transition scanning_to_dataRetrieval
			first scanning
			then dataRetrieval;
		
		state dataRetrieval {
			entry action accessMemory : SecureMemory::retrieveData;
			do action prepareData;
		}
		
		transition dataRetrieval_to_transmitting
			first dataRetrieval
			then transmitting;
		
		state transmitting {
			do action sendData : Antenna::transmitSignal;
		}
		
		transition transmitting_to_idle
			first transmitting
			then idle;
		
		transition low_battery
			first idle
			if batteryRef.batteryLevel < 15.0
			then lowPowerMode;
		
		state lowPowerMode {
			entry assign batteryRef.batteryLevel := 10.0;
		}
		
		transition lowPower_to_idle
			first lowPowerMode
			if batteryRef.batteryLevel >= 15.0
			then idle;
	}
	
	part tagWithBehavior : MedicalIDTag {
		perform action operation : MedicalTagOperation;
		
		exhibit state operationalStates : TagOperationalStates {
			in part batteryRef = tagWithBehavior.battery;
		}
	}
	
	requirement def DataIntegrityRequirement {
		doc /* The medical identification tag shall maintain data integrity with 99.99% accuracy. */
		
		subject tagMemory : SecureMemory;
		
		require constraint {
			tagMemory.encryptionEnabled == true
		}
	}
	
	requirement def ReadRangeRequirement {
		doc /* The medical identification tag shall be readable from a minimum distance of 10 cm. */
		
		subject scanner : MedicalScanner;
		
		require constraint {
			scanner.scanRange >= 0.1
		}
	}
	
	requirement def DataSecurityRequirement {
		doc /* All medical data stored on the tag shall be encrypted to protect patient privacy. */
		
		subject memory : SecureMemory;
		
		require constraint {
			memory.encryptionEnabled == true
		}
	}
	
	requirement def BatteryLifeRequirement {
		doc /* The tag battery shall maintain operational capability for minimum 5 years under normal usage. */
		
		subject power : BatteryPower;
		
		require constraint {
			power.batteryLevel > 0.0
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The tag shall respond to a valid scan request within 500 milliseconds. */
		
		subject tag : MedicalIDTag;
	}
	
	requirement <'MED-TAG-001'> primaryFunctionRequirement {
		doc /* The medical identification tag system shall provide immediate access to critical patient medical information for emergency responders through RFID scanning technology. */
		
		subject system : MedicalIDTag;
		
		assume constraint validReader {
			doc /* A compatible RFID scanner operating at 13.56 MHz is available and functional. */
		}
		
		require dataIntegrityReq : DataIntegrityRequirement;
		require readRangeReq : ReadRangeRequirement;
		require dataSecurityReq : DataSecurityRequirement;
		require batteryLifeReq : BatteryLifeRequirement;
		require responseTimeReq : ResponseTimeRequirement;
	}
	
	occurrence def EmergencyResponseScenario {
		ref part emergencyScanner : MedicalScanner;
		ref part patientTag : MedicalIDTag;
		
		message scanRequestMessage of scanReq : ScanRequest
			from emergencyScanner.scannerInterface.scanCommand
			to patientTag.tagInterface.scanSignal;
		
		then message dataResponseMessage of dataResp : DataResponse
			from patientTag.tagInterface.medicalDataOut
			to emergencyScanner.scannerInterface.receivedData;
	}
}
