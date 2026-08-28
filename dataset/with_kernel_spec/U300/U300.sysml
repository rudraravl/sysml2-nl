package MedicalIdentificationSystem {
    private import ScalarValues::*;
    private import SI::*;

    // ---- Enumerations ----
    enum def BloodType {
        enum A_Positive;
        enum A_Negative;
        enum B_Positive;
        enum B_Negative;
        enum AB_Positive;
        enum AB_Negative;
        enum O_Positive;
        enum O_Negative;
    }

    enum def Allergy {
        enum Penicillin;
        enum Latex;
        enum Peanuts;
        enum Aspirin;
        enum None;
    }

    enum def MedicalCondition {
        enum Diabetes;
        enum Hypertension;
        enum Asthma;
        enum Epilepsy;
        enum HeartDisease;
        enum None;
    }

    // ---- Item definitions ----
    item def PatientID {
        attribute value : String;
    }

    item def EmergencyContact {
        attribute name : String;
        attribute phone : String;
        attribute relationship : String;
    }

    item def Medication {
        attribute name : String;
        attribute dosage : String;
    }

    item def MedicalRecord {
        attribute patientId : String;
        attribute bloodType : BloodType;
        attribute allergies : Allergy[0..*];
        attribute conditions : MedicalCondition[0..*];
        attribute medications : Medication[0..*];
        attribute emergencyContact : EmergencyContact[1];
    }

    item def ScanRequest {
        attribute frequency : Real;
    }

    item def EncryptedData {
        attribute encrypted : Boolean = true;
        attribute record : MedicalRecord;
    }

    item def ScanResponse {
        attribute data : EncryptedData;
        attribute valid : Boolean;
    }

    // ---- Port definition ----
    port def RFIDPort {
        in item scanRequest : ScanRequest;
        out item scanResponse : ScanResponse;
    }

    // ---- Component part definitions ----
    part def Battery {
        attribute capacity : Integer;
        attribute level : Real;
    }

    part def RFIDChip {
        port rfInterface : RFIDPort;
    }

    part def SecureMemory {
        attribute encrypted : Boolean = true;
        attribute storedRecord : MedicalRecord;
    }

    part def Antenna {
        attribute maxRange : Real = 0.15;
    }

    part def Display {
        attribute screenSize : String;
    }

    // ---- Action definitions ----
    action def EnterIdleMode;
    action def EnterLowPowerMode;
    action def RetrieveAndTransmit {
        out data : EncryptedData;
        out response : ScanResponse;
    }
    action def SendScanRequest {
        out request : ScanRequest;
    }
    action def ScanTag {
        in request : ScanRequest;
        out response : ScanResponse;
        out record : MedicalRecord;
    }
    action def ValidateResponse {
        in response : ScanResponse;
        out valid : Boolean;
        out record : MedicalRecord;
    }
    action def DisplayRecord {
        in record : MedicalRecord;
    }

    // ---- Tag state machine definition ----
    state def TagStateMachine {
        state idle {
            entry action enterIdle : EnterIdleMode;
        }
        state active {
            entry action retrieveAndTransmit : RetrieveAndTransmit;
        }
        state lowPower {
            entry action enterLowPower : EnterLowPowerMode;
        }
        transition idle_to_active from idle to active when scanRequestReceived;
        transition idle_to_lowPower from idle to lowPower when batteryLevelLow;
        transition active_to_idle from active to idle when transmitComplete;
        transition lowPower_to_idle from lowPower to idle when batteryLevelRestored;
    }

    // ---- Scanner state machine definition ----
    state def ScannerStateMachine {
        state standby;
        state scanning {
            entry action sendRequest : SendScanRequest;
        }
        state validating {
            entry action validate : ValidateResponse;
        }
        state displaying {
            entry action showRecord : DisplayRecord;
        }
        transition standby_to_scanning from standby to scanning when scanTriggered;
        transition scanning_to_validating from scanning to validating when responseReceived;
        transition validating_to_displaying from validating to displaying when validationSuccess;
        transition validating_to_standby from validating to standby when validationFailure;
        transition displaying_to_standby from displaying to standby when userDismiss;
    }

    // ---- Medical ID Tag ----
    part def MedicalIDTag {
        part rfidChip : RFIDChip;
        part memory : SecureMemory;
        part battery : Battery;
        part antenna : Antenna;

        port externalRFID : RFIDPort;

        attribute scanRequestReceived : Boolean;
        attribute batteryLevelLow : Boolean;
        attribute transmitComplete : Boolean;
        attribute batteryLevelRestored : Boolean;

        connect externalRFID to rfidChip.rfInterface;

        exhibit state behavior : TagStateMachine;
    }

    // ---- Medical Scanner ----
    part def MedicalScanner {
        part display : Display;
        part battery : Battery;

        port scannerRFID : ~RFIDPort;

        attribute maxScanRange : Real = 0.15;
        attribute scanFrequency : Real = 13.56e6;
        attribute scanTriggered : Boolean;
        attribute responseReceived : Boolean;
        attribute validationSuccess : Boolean;
        attribute validationFailure : Boolean;
        attribute userDismiss : Boolean;

        exhibit state behavior : ScannerStateMachine;
    }

    // ---- Emergency scan sequence ----
    action def EmergencyScanSequence {
        action sendRequest : SendScanRequest {
            out request;
        }
        then action scan : ScanTag {
            in request = sendRequest.request;
            out response;
            out record;
        }
        then action validate : ValidateResponse {
            in response = scan.response;
            out valid;
            out validatedRecord;
        }
        then if validate.valid {
            action display : DisplayRecord {
                in record = validate.validatedRecord;
            }
        }
        then done;
    }

    // ---- System ----
    part medicalIDSystem {
        part tag : MedicalIDTag;
        part scanner : MedicalScanner;

        connect tag.externalRFID to scanner.scannerRFID;
    }

    // ---- Requirements ----
    requirement def ReadRangeRequirement {
        doc /* The scanner shall be able to read tags from a distance of up to 15 cm. */
        attribute maxRange : Real = 0.15;
        subject scanner : MedicalScanner;
        require constraint { scanner.maxScanRange <= maxRange }
    }

    requirement def DataSecurityRequirement {
        doc /* The tag shall encrypt all stored patient data to protect privacy. */
        subject tag : MedicalIDTag;
        require constraint { tag.memory.encrypted == true }
    }

    requirement def LowPowerRequirement {
        doc /* The tag shall enter a low-power mode when battery level falls below 20%. */
        subject tag : MedicalIDTag;
        attribute threshold : Real = 20;
        require constraint { tag.battery.level < threshold }
    }

    requirement def QuickAccessRequirement {
        doc /* The system shall provide quick wireless access to patient health information using RFID technology. */
        subject system : medicalIDSystem;
    }

    requirement def DataValidationRequirement {
        doc /* The scanner shall validate received data before displaying the patient medical profile. */
        subject scanner : MedicalScanner;
        require constraint { scanner.validationSuccess == true }
    }

    // ---- Requirement satisfaction ----
    satisfaction readRangeSatisfaction : ReadRangeRequirement {
        subject = medicalIDSystem::scanner;
    }
    satisfaction dataSecuritySatisfaction : DataSecurityRequirement {
        subject = medicalIDSystem::tag;
    }
    satisfaction lowPowerSatisfaction : LowPowerRequirement {
        subject = medicalIDSystem::tag;
    }
    satisfaction quickAccessSatisfaction : QuickAccessRequirement {
        subject = medicalIDSystem;
    }
    satisfaction dataValidationSatisfaction : DataValidationRequirement {
        subject = medicalIDSystem::scanner;
    }
}
