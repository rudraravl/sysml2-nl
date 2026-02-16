package 'Automated Medication Dispensing System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import RiskMetadata::*;
    private import RiskLevelEnum::*;
    private import ModelingMetadata::*;

    attribute def MedicationID;
    attribute def PatientID;
    attribute def PrescriptionID;
    attribute def ErrorCode;

    attribute def PrescriptionData {
        attribute patientID : PatientID;
        attribute medicationID : MedicationID;
        attribute prescriptionID : PrescriptionID;
        attribute dosage : ISQ::MassValue;
        attribute frequency : ISQ::TimeValue;
        attribute duration : ISQ::TimeValue;
    }

    attribute def InventoryRecord {
        attribute medicationID : MedicationID;
        attribute quantityAvailable : ISQ::MassValue;
        attribute expirationDate : ISQ::TimeValue;
        attribute storageTemp : ISQ::ThermodynamicTemperatureValue;
    }

    attribute def DispensingRecord {
        attribute prescriptionID : PrescriptionID;
        attribute patientID : PatientID;
        attribute medicationID : MedicationID;
        attribute dispensedDosage : ISQ::MassValue;
        attribute timestamp : ISQ::TimeValue;
        attribute verificationStatus : Boolean;
    }

    port def AuthenticationPort {
        in attribute credentialsIn : PatientID;
        out attribute authenticationResult : Boolean;
    }

    port def PrescriptionPort {
        in attribute prescriptionRequest : PrescriptionID;
        out attribute prescriptionData : PrescriptionData;
    }

    port def InventoryPort {
        in attribute medicationQuery : MedicationID;
        out attribute inventoryStatus : InventoryRecord;
    }

    port def DispensingPort {
        out attribute medication : MedicationID;
        out attribute dosage : ISQ::MassValue;
    }

    port def AlertPort {
        out attribute errorCode : ErrorCode;
        out attribute alertMessage : String;
    }

    part def UserInterface {
        attribute currentPatientID : PatientID;
        attribute displayStatus : String;
        port authPort : AuthenticationPort;
        port prescriptionPort : PrescriptionPort;
        port alertPort : AlertPort;
    }

    part def DatabaseServer {
        attribute prescriptionDatabase : PrescriptionData[*];
        attribute patientRecords : PatientID[*];
        port dataPort : PrescriptionPort;
        port authPort : AuthenticationPort;
    }

    part def InventoryManagementUnit {
        attribute inventoryRecords : InventoryRecord[*];
        attribute lowStockThreshold : ISQ::MassValue;
        port inventoryPort : InventoryPort;
        port alertPort : AlertPort;
    }

    part def DispensingMechanism {
        attribute currentMedication : MedicationID;
        attribute dispensedAmount : ISQ::MassValue;
        port controlPort : DispensingPort;
        port inventoryPort : InventoryPort;
    }

    part def VerificationModule {
        attribute verificationLog : DispensingRecord[*];
        attribute barcodeScanner : Boolean;
        port verificationPort : PrescriptionPort;
    }

    part def SafetyMonitor {
        attribute activeAlerts : ErrorCode[*];
        attribute currentSystemStatus : String;
        port monitorPort : AlertPort;
    }

    action def AuthenticateUser {
        in credentials : PatientID;
        out authenticated : Boolean;
        out errorCode : ErrorCode;
    }

    action def RetrievePrescription {
        in prescriptionID : PrescriptionID;
        in patientID : PatientID;
        out prescriptionData : PrescriptionData;
        out prescriptionValid : Boolean;
    }

    action def CheckInventory {
        in medicationID : MedicationID;
        in requiredDosage : ISQ::MassValue;
        out available : Boolean;
        out inventoryRecord : InventoryRecord;
    }

    action def VerifyMedication {
        in prescriptionData : PrescriptionData;
        in inventoryRecord : InventoryRecord;
        out verified : Boolean;
        out errorCode : ErrorCode;
    }

    action def DispenseMedication {
        in medicationID : MedicationID;
        in dosage : ISQ::MassValue;
        out dispensed : Boolean;
        out actualDosage : ISQ::MassValue;
    }

    action def UpdateInventory {
        in medicationID : MedicationID;
        in dispensedAmount : ISQ::MassValue;
        out updatedRecord : InventoryRecord;
    }

    action def LogTransaction {
        in dispensingRecord : DispensingRecord;
        out logged : Boolean;
    }

    action def ProcessMedicationRequest {
        in patientID : PatientID;
        in prescriptionID : PrescriptionID;
        out dispensingRecord : DispensingRecord;
        out success : Boolean;

        first start;
        then action authenticate : AuthenticateUser {
            in credentials = patientID;
            out authenticated;
            out errorCode;
        }

        then decide;
            if !authenticate.authenticated then authenticationFailed;
            if authenticate.authenticated then retrievePrescription;

        action authenticationFailed {
            out error = authenticate.errorCode;
        }
        then done;

        action retrievePrescription : RetrievePrescription {
            in prescriptionID = prescriptionID;
            in patientID = patientID;
            out prescriptionData;
            out prescriptionValid;
        }

        then decide;
            if !retrievePrescription.prescriptionValid then prescriptionError;
            if retrievePrescription.prescriptionValid then checkInventory;

        action prescriptionError;
        then done;

        action checkInventory : CheckInventory {
            in medicationID = retrievePrescription.prescriptionData.medicationID;
            in requiredDosage = retrievePrescription.prescriptionData.dosage;
            out available;
            out inventoryRecord;
        }

        then decide;
            if !checkInventory.available then inventoryError;
            if checkInventory.available then verifyMedication;

        action inventoryError;
        then done;

        action verifyMedication : VerifyMedication {
            in prescriptionData = retrievePrescription.prescriptionData;
            in inventoryRecord = checkInventory.inventoryRecord;
            out verified;
            out errorCode;
        }

        then decide;
            if !verifyMedication.verified then verificationError;
            if verifyMedication.verified then dispenseMedication;

        action verificationError {
            out error = verifyMedication.errorCode;
        }
        then done;

        action dispenseMedication : DispenseMedication {
            in medicationID = retrievePrescription.prescriptionData.medicationID;
            in dosage = retrievePrescription.prescriptionData.dosage;
            out dispensed;
            out actualDosage;
        }

        then action updateInventory : UpdateInventory {
            in medicationID = retrievePrescription.prescriptionData.medicationID;
            in dispensedAmount = dispenseMedication.actualDosage;
            out updatedRecord;
        }

        then action logTransaction : LogTransaction {
            in dispensingRecord;
            out logged;
        }

        then assign success := true;
        then done;
    }

    part def AutomatedMedicationDispensingSystem {
        doc /* 
            An Automated Medication Dispensing System is a computerized drug storage 
            and distribution system used in healthcare facilities. Its primary function 
            is to securely store medications, verify prescriptions, and accurately 
            dispense the correct medication and dosage to patients while maintaining 
            comprehensive audit trails and inventory management.
        */

        attribute systemInventoryThreshold : ISQ::MassValue;
        attribute maxConcurrentRequests : Integer;

        part userInterface : UserInterface {
            attribute :>> currentPatientID : PatientID;
            attribute :>> displayStatus : String;
        }

        part database : DatabaseServer {
            attribute :>> prescriptionDatabase : PrescriptionData[*];
            attribute :>> patientRecords : PatientID[*];
        }

        part inventoryManager : InventoryManagementUnit {
            attribute :>> inventoryRecords : InventoryRecord[*];
            attribute :>> lowStockThreshold : ISQ::MassValue;
        }

        part dispensingUnit : DispensingMechanism {
            attribute :>> currentMedication : MedicationID;
            attribute :>> dispensedAmount : ISQ::MassValue;
        }

        part verificationModule : VerificationModule {
            attribute :>> verificationLog : DispensingRecord[*];
            attribute :>> barcodeScanner : Boolean;
        }

        part safetyMonitor : SafetyMonitor {
            attribute :>> activeAlerts : ErrorCode[*];
            attribute :>> currentSystemStatus : String;
        }

        connection authConnection connect userInterface.authPort to database.authPort;
        connection prescriptionConnection connect userInterface.prescriptionPort to database.dataPort;
        connection verificationConnection connect verificationModule.verificationPort to database.dataPort;
        connection inventoryQueryConnection connect dispensingUnit.inventoryPort to inventoryManager.inventoryPort;
        connection dispensingControlConnection connect userInterface.prescriptionPort to dispensingUnit.controlPort;
        connection alertConnection1 connect inventoryManager.alertPort to safetyMonitor.monitorPort;
        connection alertConnection2 connect userInterface.alertPort to safetyMonitor.monitorPort;

        perform action medicationDispensing : ProcessMedicationRequest {
            in patientID;
            in prescriptionID;
            out dispensingRecord;
            out success;
        }
    }

    part automatedMedicationDispensingSystem : AutomatedMedicationDispensingSystem;

    requirement <'REQ-MDS-001'> primaryFunction {
        doc /* 
            The Automated Medication Dispensing System shall securely store, 
            verify, and accurately dispense medications to patients based on 
            validated prescriptions while maintaining complete audit trails.
        */

        subject automatedMedicationDispensingSystem;

        require accurateDispensing;
        require prescriptionVerification;
        require inventoryTracking;
        require auditTrail;
    }

    requirement <'REQ-MDS-002'> accurateDispensing {
        doc /* 
            The system shall dispense medications with 99.9% accuracy, 
            ensuring the correct medication and dosage are provided.
        */

        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = high;
                technicalRisk = medium;
                scheduleRisk = low;
                costRisk = medium;
            }
            owner = "Pharmacy Operations";
        }
    }

    requirement <'REQ-MDS-003'> prescriptionVerification {
        doc /* 
            The system shall verify all prescriptions against patient records 
            and medication databases before dispensing, with multi-factor 
            authentication required for controlled substances.
        */

        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = high;
                technicalRisk = high;
                scheduleRisk = low;
                costRisk = low;
            }
            owner = "Clinical Safety";
        }
    }

    requirement <'REQ-MDS-004'> inventoryTracking {
        doc /* 
            The system shall maintain real-time inventory tracking with 
            automatic alerts when medication quantities fall below defined 
            thresholds or approach expiration dates.
        */
    }

    requirement <'REQ-MDS-005'> auditTrail {
        doc /* 
            The system shall maintain a complete, tamper-proof audit trail 
            of all dispensing activities, including user authentication, 
            prescription verification, and medication dispensing events.
        */

        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = medium;
                technicalRisk = low;
                scheduleRisk = low;
                costRisk = low;
            }
            owner = "Compliance Officer";
        }
    }

    requirement <'REQ-MDS-006'> responseTime {
        doc /* 
            The system shall complete the entire medication dispensing 
            process from authentication to dispensing within 60 seconds 
            for 95% of transactions.
        */
    }

    requirement <'REQ-MDS-007'> dataIntegrity {
        doc /* 
            The system shall ensure data integrity through redundant storage, 
            automatic backups every 15 minutes, and encryption of all 
            patient and prescription data.
        */

        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = high;
                technicalRisk = medium;
                scheduleRisk = medium;
                costRisk = high;
            }
            owner = "IT Security";
        }
    }
}
