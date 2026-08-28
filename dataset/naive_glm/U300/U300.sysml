package MedicalIDSystem {
    import ScalarValues::*;
    
    // ============== Unit Definitions ==============
    unit Hz;
    unit cm;
    unit percent;
    unit byte;
    unit milliwatt;
    unit millivolt;
    unit millisecond;
    
    // ============== Value Types ==============
    value type Frequency > Real {
        unit Hz;
    }
    
    value type Distance > Real {
        unit cm;
    }
    
    value type BatteryLevel > Real {
        unit percent;
    }
    
    value type DataSize > Integer {
        unit byte;
    }
    
    value type PowerOutput > Real {
        unit milliwatt;
    }
    
    value type Voltage > Real {
        unit millivolt;
    }
    
    value type Duration > Real {
        unit millisecond;
    }
    
    value type SignalStrength > Real;
    
    // ============== Enumerations ==============
    enumeration def BloodType {
        :A_POSITIVE;
        :A_NEGATIVE;
        :B_POSITIVE;
        :B_NEGATIVE;
        :AB_POSITIVE;
        :AB_NEGATIVE;
        :O_POSITIVE;
        :O_NEGATIVE;
    }
    
    enumeration def Allergy {
        :PENICILLIN;
        :LATEX;
        :PEANUTS;
        :SHELLFISH;
        :ASPIRIN;
        :IODINE;
        :SULFA;
        :NONE;
    }
    
    enumeration def MedicalCondition {
        :DIABETES;
        :HYPERTENSION;
        :ASTHMA;
        :EPILEPSY;
        :HEART_DISEASE;
        :PACEMAKER;
        :KIDNEY_DISEASE;
        :NONE;
    }
    
    enumeration def TagOperatingState {
        :IDLE;
        :ACTIVE;
        :TRANSMITTING;
        :LOW_POWER;
    }
    
    enumeration def ScannerOperatingState {
        :STANDBY;
        :SCANNING;
        :RECEIVING;
        :DISPLAYING;
        :ERROR;
    }
    
    enumeration def EncryptionStatus {
        :ENCRYPTED;
        :DECRYPTED;
        :FAILED;
    }
    
    // ============== Item Definitions ==============
    item def EmergencyContact {
        attribute name : String;
        attribute relationship : String;
        attribute phoneNumber : String;
    }
    
    item def Medication {
        attribute name : String;
        attribute dosage : String;
        attribute frequency : String;
    }
    
    item def PatientMedicalData {
        attribute patientId : String;
        attribute patientName : String;
        attribute dateOfBirth : String;
        attribute bloodType : BloodType;
        attribute allergies : Allergy[0..*];
        attribute conditions : MedicalCondition[0..*];
        attribute medications : Medication[0..*];
        attribute emergencyContacts : EmergencyContact[0..*];
        attribute encryptionStatus : EncryptionStatus = EncryptionStatus::ENCRYPTED;
    }
    
    item def ScanRequest {
        attribute requestId : String;
        attribute scannerId : String;
        attribute timestamp : String;
        attribute frequency : Frequency;
    }
    
    item def ScanResponse {
        attribute requestId : String;
        attribute tagId : String;
        attribute payload : PatientMedicalData;
        attribute checksum : String;
        attribute isValid : Boolean;
    }
    
    item def ValidationError {
        attribute errorCode : String;
        attribute description : String;
    }
    
    item def AuthenticationCredential {
        attribute userId : String;
        attribute accessCode : String;
        attribute role : String;
    }
    
    // ============== Port Definitions ==============
    port def RFIDCommunicationPort {
        attribute operatingFrequency : Frequency = 13.56 [Hz];
        in scanRequest : ScanRequest;
        out scanResponse : ScanResponse;
    }
    
    port def DisplayOutputPort {
        out medicalData : PatientMedicalData;
        out errorData : ValidationError;
        out statusMessage : String;
    }
    
    port def PowerInterfacePort {
        attribute voltage : Voltage;
        attribute current : Real;
    }
    
    // ============== Interface Definitions ==============
    interface def RFIDLink {
        end scannerSide : RFIDCommunicationPort;
        end tagSide : RFIDCommunicationPort;
    }
    
    // ============== Requirements ==============
    requirement def MedicalIDSystemRequirements {
        doc : The medical identification system shall provide emergency responders and medical staff quick, wireless access to a patient critical health information using RFID technology.
    }
    
    requirement def QuickAccessRequirement {
        doc : The system shall provide access to patient medical data within 1 second of scan initiation.
        constraint { responseTime <= 1000 [millisecond]; }
    }
    
    requirement def ReadRangeRequirement {
        doc : The scanner shall read tags from a distance of up to 15 cm.
        constraint { readDistance <= 15 [cm]; }
    }
    
    requirement def TagBatteryLifeRequirement {
        doc : The tag battery shall last at least 365 days in idle mode.
    }
    
    requirement def DataEncryptionRequirement {
        doc : All patient medical data stored on the tag shall be encrypted to protect patient privacy.
    }
    
    requirement def LowPowerModeRequirement {
        doc : The tag shall enter low-power mode when battery level drops below 10 percent.
        constraint { lowBatteryThreshold = 10 [percent]; }
    }
    
    requirement def TagActivationTimeRequirement {
        doc : The tag shall activate from idle state within 100 milliseconds of detecting a scan signal.
        constraint { activationTime <= 100 [millisecond]; }
    }
    
    requirement def DataValidationRequirement {
        doc : The scanner shall validate the integrity of received data before displaying it to the user.
    }
    
    requirement def AuthorizedAccessRequirement {
        doc : The scanner shall only be operable by authorized medical personnel.
    }
    
    // ============== Medical ID Tag ==============
    part def MedicalIDTag {
        port rfidPort : RFIDCommunicationPort;
        
        attribute tagId : String;
        attribute batteryLevel : BatteryLevel;
        attribute lowBatteryThreshold : BatteryLevel = 10 [percent];
        attribute operatingState : TagOperatingState = TagOperatingState::IDLE;
        attribute encryptionEnabled : Boolean = true;
        
        // --- RFID Chip Subcomponent ---
        part rfidChip {
            attribute operatingFrequency : Frequency = 13.56 [Hz];
            attribute transmitPower : PowerOutput;
            attribute isPowered : Boolean = false;
            attribute dataRate : Real;
            
            action processScanRequest {
                in request : ScanRequest;
                out response : ScanResponse;
            }
            
            action modulateSignal {
                in data : PatientMedicalData;
                out signal : SignalStrength;
            }
            
            action demodulateSignal {
                in signal : SignalStrength;
                out request : ScanRequest;
            }
        }
        
        // --- Secure Memory Subcomponent ---
        part secureMemory {
            attribute storageCapacity : DataSize = 4096 [byte];
            attribute isEncrypted : Boolean = true;
            attribute encryptionKey : String;
            attribute storedData : PatientMedicalData;
            
            action retrieveEncryptedData {
                out data : PatientMedicalData;
            }
            
            action writeEncryptedData {
                in data : PatientMedicalData;
            }
            
            action encrypt {
                in plaintext : PatientMedicalData;
                out ciphertext : PatientMedicalData;
            }
            
            action decrypt {
                in ciphertext : PatientMedicalData;
                out plaintext : PatientMedicalData;
            }
        }
        
        // --- Battery Subcomponent ---
        part battery {
            attribute capacity : Real;
            attribute voltage : Voltage;
            attribute chargeLevel : BatteryLevel = 100 [percent];
            
            action discharge {
                in rate : Real;
                out remainingLevel : BatteryLevel;
            }
            
            action monitorCharge {
                out level : BatteryLevel;
            }
        }
        
        // --- Antenna Subcomponent ---
        part antenna {
            attribute gain : Real;
            attribute impedance : Real;
            attribute resonantFrequency : Frequency = 13.56 [Hz];
            attribute bandwidth : Real;
            
            action transmitSignal {
                in data : ScanResponse;
            }
            
            action receiveSignal {
                out signal : SignalStrength;
            }
        }
        
        // --- Tag State Machine ---
        state def TagStateMachine {
            state idle {
                doc : Power-saving idle state, waiting for scanner signal.
                entry {
                    rfidChip.isPowered = false;
                }
                do {
                    battery.monitorCharge();
                }
            }
            
            state active {
                doc : Tag has detected a scan request and is processing.
                entry {
                    rfidChip.isPowered = true;
                }
                do {
                    secureMemory.retrieveEncryptedData();
                }
            }
            
            state transmitting {
                doc : Tag is wirelessly transmitting encrypted medical data to scanner.
                entry {
                    antenna.transmitSignal();
                }
            }
            
            state lowPower {
                doc : Low-power conservation mode when battery level is critically low.
                entry {
                    rfidChip.isPowered = false;
                }
                do {
                    battery.monitorCharge();
                }
            }
            
            transition idle -> active when rfidPort.scanRequest is received;
            transition active -> transmitting when secureMemory.retrieveEncryptedData is completed;
            transition transmitting -> idle when rfidPort.scanResponse is sent;
            transition idle -> lowPower when battery.chargeLevel <= lowBatteryThreshold;
            transition active -> lowPower when battery.chargeLevel <= lowBatteryThreshold;
            transition lowPower -> idle when battery.chargeLevel > lowBatteryThreshold;
        }
        
        // --- Tag Actions ---
        action activateFromIdle {
            in scanReq : ScanRequest;
            out activationConfirmed : Boolean;
        }
        
        action retrieveAndTransmitData {
            in scanReq : ScanRequest;
            out scanResp : ScanResponse;
        }
        
        action checkBatteryStatus {
            out level : BatteryLevel;
            out requiresLowPower : Boolean;
        }
        
        // --- Requirement Satisfaction ---
        satisfy TagBatteryLifeRequirement by battery;
        satisfy DataEncryptionRequirement by secureMemory;
        satisfy LowPowerModeRequirement by TagStateMachine;
        satisfy TagActivationTimeRequirement by TagStateMachine;
    }
    
    // ============== Medical Scanner ==============
    part def MedicalScanner {
        port rfidPort : RFIDCommunicationPort;
        port displayPort : DisplayOutputPort;
        
        attribute scannerId : String;
        attribute maxReadDistance : Distance = 15 [cm];
        attribute operatingState : ScannerOperatingState = ScannerOperatingState::STANDBY;
        attribute isAuthorized : Boolean = false;
        attribute batteryLevel : BatteryLevel;
        
        // --- RFID Reader Subcomponent ---
        part rfidReader {
            attribute operatingFrequency : Frequency = 13.56 [Hz];
            attribute powerOutput : PowerOutput;
            attribute readRange : Distance = 15 [cm];
            
            action sendScanRequest {
                out request : ScanRequest;
            }
            
            action receiveScanResponse {
                in response : ScanResponse;
            }
            
            action calibrateAntenna {
                out calibrationStatus : Boolean;
            }
        }
        
        // --- Processor Subcomponent ---
        part processor {
            attribute processingSpeed : Real;
            attribute decryptionKey : String;
            
            action validateTransmission {
                in response : ScanResponse;
                out isValid : Boolean;
                out error : ValidationError;
            }
            
            action decryptData {
                in encryptedData : PatientMedicalData;
                out decryptedData : PatientMedicalData;
            }
            
            action verifyChecksum {
                in response : ScanResponse;
                out isValid : Boolean;
            }
        }
        
        // --- Display Subcomponent ---
        part display {
            attribute screenWidth : Real;
            attribute screenHeight : Real;
            attribute isBacklit : Boolean = true;
            attribute brightnessLevel : Real;
            
            action displayMedicalProfile {
                in data : PatientMedicalData;
            }
            
            action displayError {
                in error : ValidationError;
            }
            
            action displayLowBatteryWarning {
            }
            
            action displayNoTagFound {
            }
        }
        
        // --- Scanner Battery Subcomponent ---
        part scannerBattery {
            attribute capacity : Real;
            attribute voltage : Voltage;
            attribute chargeLevel : BatteryLevel = 100 [percent];
            
            action discharge {
                in rate : Real;
                out remainingLevel : BatteryLevel;
            }
            
            action monitorCharge {
                out level : BatteryLevel;
            }
        }
        
        // --- User Interface Subcomponent ---
        part userInterface {
            attribute hasKeypad : Boolean = true;
            attribute hasScreen : Boolean = true;
            
            action initiateScan {
                out request : ScanRequest;
            }
            
            action authorizeUser {
                in credential : AuthenticationCredential;
                out authorized : Boolean;
            }
            
            action handleUserInput {
                in input : String;
                out command : String;
            }
        }
        
        // --- Scanner State Machine ---
        state def ScannerStateMachine {
            state standby {
                doc : Scanner is idle, waiting for user to initiate a scan.
                entry {
                    userInterface.handleUserInput();
                }
            }
            
            state scanning {
                doc : Scanner is actively sending a scan request to detect a nearby tag.
                entry {
                    rfidReader.sendScanRequest();
                }
                do {
                    rfidReader.calibrateAntenna();
                }
            }
            
            state receiving {
                doc : Scanner is receiving and processing the encrypted response from the tag.
                entry {
                    rfidReader.receiveScanResponse();
                }
                do {
                    processor.validateTransmission();
                    processor.decryptData();
                }
            }
            
            state displaying {
                doc : Scanner is displaying the validated patient medical profile to the user.
                entry {
                    display.displayMedicalProfile();
                }
            }
            
            state error {
                doc : Scanner has encountered an error during scanning or validation.
                entry {
                    display.displayError();
                }
            }
            
            transition standby -> scanning when userInterface.initiateScan is triggered;
            transition scanning -> receiving when rfidReader.receiveScanResponse is triggered;
            transition receiving -> displaying when processor.validateTransmission returns true;
            transition receiving -> error when processor.validateTransmission returns false;
            transition displaying -> standby when display.displayMedicalProfile is completed;
            transition error -> standby when display.displayError is completed;
            transition scanning -> standby when rfidReader.receiveScanResponse times out;
        }
        
        // --- Scanner Actions ---
        action performFullScan {
            in userCredential : AuthenticationCredential;
            out response : ScanResponse;
            out validationError : ValidationError;
        }
        
        action validateAndDecrypt {
            in response : ScanResponse;
            out medicalData : PatientMedicalData;
            out isValid : Boolean;
        }
        
        action showPatientProfile {
            in data : PatientMedicalData;
        }
        
        action showScanError {
            in error : ValidationError;
        }
        
        // --- Requirement Satisfaction ---
        satisfy ReadRangeRequirement by rfidReader;
        satisfy QuickAccessRequirement by ScannerStateMachine;
        satisfy DataValidationRequirement by processor;
        satisfy AuthorizedAccessRequirement by userInterface;
    }
    
    // ============== Top-Level System ==============
    part def MedicalIDSystem {
        attribute systemVersion : String = "1.0";
        attribute systemActive : Boolean = true;
        
        part medicalIDTag : MedicalIDTag {
            attribute tagId = "TAG-001";
        }
        
        part medicalScanner : MedicalScanner {
            attribute scannerId = "SCN-001";
        }
        
        interface rfidLink : RFIDLink {
            connect medicalScanner::rfidPort to medicalIDTag::rfidPort;
        }
        
        // System-level actions
        action initiateEmergencyScan {
            in credential : AuthenticationCredential;
            out medicalData : PatientMedicalData;
            out error : ValidationError;
        }
        
        // System-level requirement satisfaction
        satisfy MedicalIDSystemRequirements by MedicalIDSystem;
    }
    
    // ============== Test Scenarios ==============
    action def EmergencyScanScenario {
        doc : First responder scans a patient tag in an emergency situation.
        
        in responderCredential : AuthenticationCredential;
        out patientData : PatientMedicalData;
        
        local tag : MedicalIDTag;
        local scanner : MedicalScanner;
        
        action authorize : scanner.userInterface.authorizeUser {
            in credential = responderCredential;
            out authorized;
        }
        
        action scan : scanner.rfidReader.sendScanRequest {
            out request;
        }
        
        action tagActivates : tag.activateFromIdle {
            in scanReq = request;
            out activated;
        }
        
        action transmitData : tag.retrieveAndTransmitData {
            in scanReq = request;
            out scanResp;
        }
        
        action validateAndDisplay : scanner.validateAndDecrypt {
            in response = scanResp;
            out medicalData = patientData;
            out isValid;
        }
    }
}
