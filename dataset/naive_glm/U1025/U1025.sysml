package DataSecuritySystem {
    import ScalarValues::*;
    import SI::*;

    // ===== Value Types =====
    value type DataSize :> Real { unit "byte"; }
    value type ThreatScore :> Real { unit "score"; }
    value type ClearanceLevel :> Integer { unit "level"; }
    value type SecurityClassification :> Integer { unit "class"; }
    value type Timestamp :> Real { unit "s"; }
    value type HashValue :> String;
    value type EncryptionKey :> String;
    value type AlgorithmName :> String;
    value type UserId :> String;
    value type RoleName :> String;
    value type EventId :> Integer { unit "id"; }

    // ===== Enumerations =====
    enum ThreatType { none, malware, phishing, injection, ransomware, trojan, unknown }
    enum ThreatSeverity { benign, low, medium, high, critical }
    enum AccessDecision { granted, denied, pending }
    enum ProcessingStatus { idle, scanning, authenticating, authorizing, encrypting, logging, completed, rejected }
    enum AuditEventType { dataReceived, threatDetected, accessGranted, accessDenied, encryptionCompleted, integrityHashGenerated, processHalted, processCompleted }

    // ===== Item Types =====
    item def RawData {
        attribute payload : String;
        attribute size : DataSize;
        attribute source : String;
        attribute submittedBy : UserId;
        attribute classification : SecurityClassification;
        attribute receivedAt : Timestamp;
    }

    item def ThreatAssessment {
        attribute threatType : ThreatType;
        attribute severity : ThreatSeverity;
        attribute score : ThreatScore;
        attribute description : String;
        attribute isThreatDetected : Boolean;
    }

    item def AccessRequest {
        attribute user : UserId;
        attribute role : RoleName;
        attribute clearance : ClearanceLevel;
        attribute requestedClassification : SecurityClassification;
        attribute authenticated : Boolean;
    }

    item def AccessResult {
        attribute decision : AccessDecision;
        attribute user : UserId;
        attribute reason : String;
        attribute timestamp : Timestamp;
    }

    item def EncryptedData {
        attribute ciphertext : String;
        attribute algorithm : AlgorithmName;
        attribute keyId : String;
        attribute integrityHash : HashValue;
        attribute originalSize : DataSize;
        attribute encryptedAt : Timestamp;
    }

    item def AuditRecord {
        attribute recordId : EventId;
        attribute eventType : AuditEventType;
        attribute user : UserId;
        attribute description : String;
        attribute timestamp : Timestamp;
        attribute severity : ThreatSeverity;
    }

    item def ThreatSignature {
        attribute signatureId : String;
        attribute threatType : ThreatType;
        attribute severity : ThreatSeverity;
        attribute pattern : String;
    }

    item def UserCredential {
        attribute user : UserId;
        attribute role : RoleName;
        attribute clearance : ClearanceLevel;
        attribute maxClassification : SecurityClassification;
        attribute passwordHash : String;
    }

    // ===== Port Definitions =====
    port def RawDataInputPort {
        in item data : RawData;
    }

    port def ThreatAssessmentPort {
        out item assessment : ThreatAssessment;
    }

    port def AccessRequestPort {
        in item request : AccessRequest;
        out item result : AccessResult;
    }

    port def EncryptedDataOutputPort {
        out item securedData : EncryptedData;
    }

    port def AuditPort {
        in item record : AuditRecord;
    }

    port def ThreatDBPort {
        out item signatures : ThreatSignature[*];
    }

    port def UserDBPort {
        out item credentials : UserCredential[*];
    }

    port def DataFlowPort {
        in item rawData : RawData;
        out item encryptedData : EncryptedData;
    }

    // ===== Requirements =====
    requirement def SecurityRequirement {
        doc "Base requirement for the Data Security System."
    }

    requirement ThreatDetectionRequirement : SecurityRequirement {
        doc "The system shall inspect all incoming data against a database of known threats."
        subject system : DataSecuritySystem
        objective {
            assert system.threatEngine.assessThreat(data).isThreatDetected == true
            when data contains known threat pattern
        }
    }

    requirement AccessControlRequirement : SecurityRequirement {
        doc "The system shall authenticate users and verify clearance levels before granting access."
        subject system : DataSecuritySystem
        objective {
            assert system.accessManager.evaluateAccess(request).decision == AccessDecision::granted
            when request.clearance >= request.requestedClassification
        }
    }

    requirement EncryptionRequirement : SecurityRequirement {
        doc "The system shall encrypt cleared data and generate an integrity hash."
        subject system : DataSecuritySystem
        objective {
            assert system.cryptoProcessor.encrypt(data).integrityHash != ""
            when data is clean and access is granted
        }
    }

    requirement AuditLoggingRequirement : SecurityRequirement {
        doc "The system shall log every significant security event."
        subject system : DataSecuritySystem
        objective {
            assert system.auditSubsystem.recordCount > 0
            after any security event
        }
    }

    requirement DataIntegrityRequirement : SecurityRequirement {
        doc "The integrity hash shall ensure data is not tampered with after encryption."
        subject system : DataSecuritySystem
        objective {
            assert verifyHash(data, data.integrityHash) == true
            for all encryptedData
        }
    }

    // ===== Parts: Threat Analysis Engine =====
    part def ThreatAnalysisEngine {
        port in dataInput : RawDataInputPort;
        port out assessmentOutput : ThreatAssessmentPort;
        port in threatDB : ThreatDBPort;

        attribute scanCount : Integer = 0;
        attribute threatsDetected : Integer = 0;

        action assessThreat(in data : RawData) : ThreatAssessment {
            // Scan data against known threat signatures
        }

        state ThreatEngineStateMachine {
            idle;
            scanning;
            flagging;
            done;

            transition idle_to_scanning
                from idle to scanning
                when dataInput.data is received;

            transition scanning_to_flagging
                from scanning to flagging
                when assessThreat(dataInput.data).isThreatDetected == true;

            transition scanning_to_done
                from scanning to done
                when assessThreat(dataInput.data).isThreatDetected == false;

            transition flagging_to_done
                from flagging to done;

            transition done_to_idle
                from done to idle;
        }
    }

    // ===== Parts: Access Control Manager =====
    part def AccessControlManager {
        port in accessRequestPort : AccessRequestPort;
        port in userDB : UserDBPort;

        attribute authenticatedUsers : Integer = 0;
        attribute deniedAccesses : Integer = 0;

        action authenticate(in request : AccessRequest) : Boolean {
            // Verify user identity against credential store
        }

        action checkClearance(in request : AccessRequest) : Boolean {
            // Verify clearance level is sufficient for data classification
        }

        action evaluateAccess(in request : AccessRequest) : AccessResult {
            // Combine authentication and clearance check
        }

        state AccessControlStateMachine {
            waiting;
            authenticating;
            authorizing;
            accessGranted;
            accessDenied;

            transition waiting_to_authenticating
                from waiting to authenticating
                when accessRequestPort.request is received;

            transition auth_to_authorizing
                from authenticating to authorizing
                when authenticate(accessRequestPort.request) == true;

            transition auth_to_denied
                from authenticating to accessDenied
                when authenticate(accessRequestPort.request) == false;

            transition authorizing_to_granted
                from authorizing to accessGranted
                when checkClearance(accessRequestPort.request) == true;

            transition authorizing_to_denied
                from authorizing to accessDenied
                when checkClearance(accessRequestPort.request) == false;

            transition granted_to_waiting
                from accessGranted to waiting;

            transition denied_to_waiting
                from accessDenied to waiting;
        }
    }

    // ===== Parts: Cryptographic Processor =====
    part def CryptographicProcessor {
        port in dataToEncrypt : RawDataInputPort;
        port out encryptedOutput : EncryptedDataOutputPort;

        attribute defaultAlgorithm : AlgorithmName = "AES-256-GCM";
        attribute keyRotationInterval : Timestamp = 3600;
        attribute encryptionsPerformed : Integer = 0;

        action encrypt(in data : RawData) : EncryptedData {
            // Encrypt data using specified algorithm and key
        }

        action generateIntegrityHash(in encrypted : EncryptedData) : HashValue {
            // Generate unique integrity hash for tamper detection
        }

        action rotateKey() : EncryptionKey {
            // Periodically rotate encryption keys
        }

        state CryptoStateMachine {
            standby;
            encrypting;
            hashing;
            completed;

            transition standby_to_encrypting
                from standby to encrypting
                when dataToEncrypt.data is received and dataToEncrypt.data is clean;

            transition encrypting_to_hashing
                from encrypting to hashing
                when encrypt(dataToEncrypt.data) is complete;

            transition hashing_to_completed
                from hashing to completed
                when generateIntegrityHash(encryptedOutput.securedData) is complete;

            transition completed_to_standby
                from completed to standby;
        }
    }

    // ===== Parts: Auditing Subsystem =====
    part def AuditingSubsystem {
        port in auditInput : AuditPort;

        attribute recordCount : Integer = 0;
        attribute maxRecords : Integer = 1000000;
        attribute retentionPeriod : Timestamp = 7776000;

        action logEvent(in event : AuditEventType, in user : UserId, in description : String, in severity : ThreatSeverity) : AuditRecord {
            // Create and store audit record
        }

        action retrieveRecords(in fromTime : Timestamp, in toTime : Timestamp) : AuditRecord[*] {
            // Retrieve audit records for forensic analysis
        }

        action purgeOldRecords() {
            // Remove records beyond retention period
        }

        state AuditStateMachine {
            listening;
            recording;
            stored;

            transition listening_to_recording
                from listening to recording
                when auditInput.record is received;

            transition recording_to_stored
                from recording to stored
                when logEvent is complete;

            transition stored_to_listening
                from stored to listening;
        }
    }

    // ===== Main System =====
    part def DataSecuritySystem {
        port in rawDataPort : RawDataInputPort;
        port in userRequestPort : AccessRequestPort;
        port out securedDataPort : EncryptedDataOutputPort;
        port in threatDBPort : ThreatDBPort;
        port in userDBPort : UserDBPort;

        part threatEngine : ThreatAnalysisEngine {
            port in dataInput : RawDataInputPort;
            port out assessmentOutput : ThreatAssessmentPort;
            port in threatDB : ThreatDBPort;
        }

        part accessManager : AccessControlManager {
            port in accessRequestPort : AccessRequestPort;
            port in userDB : UserDBPort;
        }

        part cryptoProcessor : CryptographicProcessor {
            port in dataToEncrypt : RawDataInputPort;
            port out encryptedOutput : EncryptedDataOutputPort;
        }

        part auditSubsystem : AuditingSubsystem {
            port in auditInput : AuditPort;
        }

        // Internal connections
        connection threatAssessmentFlow
            from threatEngine.assessmentOutput to cryptoProcessor.dataToEncrypt;

        connection accessResultFlow
            from accessManager.accessRequestPort to cryptoProcessor.dataToEncrypt;

        connection auditFromThreat
            from threatEngine.assessmentOutput to auditSubsystem.auditInput;

        connection auditFromAccess
            from accessManager.accessRequestPort to auditSubsystem.auditInput;

        connection auditFromCrypto
            from cryptoProcessor.encryptedOutput to auditSubsystem.auditInput;

        // External port bindings
        bind rawDataPort = threatEngine.dataInput;
        bind userRequestPort = accessManager.accessRequestPort;
        bind securedDataPort = cryptoProcessor.encryptedOutput;
        bind threatDBPort = threatEngine.threatDB;
        bind userDBPort = accessManager.userDB;

        // System-level orchestration action
        action processData(in data : RawData, in request : AccessRequest) : EncryptedData {
            // 1. Scan for threats
            var assessment : ThreatAssessment = threatEngine.assessThreat(data);
            // 2. Validate user access
            var accessResult : AccessResult = accessManager.evaluateAccess(request);
            // 3. If threat detected or access denied, halt and log
            if assessment.isThreatDetected or accessResult.decision == AccessDecision::denied {
                auditSubsystem.logEvent(AuditEventType::processHalted, request.user, "Processing halted due to threat or access denial", assessment.severity);
            }
            // 4. If clean and authorized, encrypt and log
            else {
                var encrypted : EncryptedData = cryptoProcessor.encrypt(data);
                cryptoProcessor.generateIntegrityHash(encrypted);
                auditSubsystem.logEvent(AuditEventType::encryptionCompleted, request.user, "Data encrypted successfully", ThreatSeverity::benign);
                auditSubsystem.logEvent(AuditEventType::processCompleted, request.user, "Security pipeline completed", ThreatSeverity::benign);
            }
        }

        // System-level state machine
        state SystemStateMachine {
            idle;
            receivingData;
            scanningThreats;
            verifyingAccess;
            decisionPoint;
            encryptingData;
            loggingResult;
            deliveringData;
            halted;

            transition idle_to_receiving
                from idle to receivingData
                when rawDataPort.data is received;

            transition receiving_to_scanning
                from receivingData to scanningThreats;

            transition scanning_to_verifying
                from scanningThreats to verifyingAccess;

            transition verifying_to_decision
                from verifyingAccess to decisionPoint;

            transition decision_to_encrypting
                from decisionPoint to encryptingData
                when threatEngine.assessThreat(rawDataPort.data).isThreatDetected == false
                and accessManager.evaluateAccess(userRequestPort.request).decision == AccessDecision::granted;

            transition decision_to_halted_threat
                from decisionPoint to halted
                when threatEngine.assessThreat(rawDataPort.data).isThreatDetected == true;

            transition decision_to_halted_access
                from decisionPoint to halted
                when accessManager.evaluateAccess(userRequestPort.request).decision == AccessDecision::denied;

            transition encrypting_to_logging
                from encryptingData to loggingResult;

            transition logging_to_delivering
                from loggingResult to deliveringData;

            transition delivering_to_idle
                from deliveringData to idle;

            transition halted_to_idle
                from halted to idle;
        }

        // Requirement satisfaction
        satisfy ThreatDetectionRequirement by threatEngine;
        satisfy AccessControlRequirement by accessManager;
        satisfy EncryptionRequirement by cryptoProcessor;
        satisfy AuditLoggingRequirement by auditSubsystem;
        satisfy DataIntegrityRequirement by cryptoProcessor;
    }
}
