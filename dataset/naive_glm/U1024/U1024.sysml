package DataPrivacyManagementSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value Types ----------
    value type ConsentId > String;
    value type DataSubjectId > String;
    value type DataRecordId > String;
    value type RequestId > String;
    value type UserId > String;
    value type KeyId > String;
    value type PolicyId > String;
    value type Purpose > String;
    value type DataCategory > String;

    value type DurationHours > Real {
        unit 'h';
    }
    value type DurationDays > Real {
        unit 'd';
    }
    value type KeyStrengthBits > Integer {
        unit 'bit';
    }
    value type RecordCount > Integer;
    value type Timestamp > DateTime;

    enumeration AccessDecision {
        granted;
        denied;
    }

    enumeration ConsentStatus {
        active;
        revoked;
        expired;
        pending;
    }

    enumeration EncryptionAlgorithm {
        AES256;
        RSA4096;
        ChaCha20;
    }

    enumeration RetentionAction {
        delete;
        archive;
        retain;
    }

    enumeration AnonymizationMethod {
        kAnonymity;
        differentialPrivacy;
        pseudonymization;
        generalization;
    }

    // ---------- Item Definitions ----------
    item def PersonalData {
        attribute recordId : DataRecordId;
        attribute subjectId : DataSubjectId;
        attribute category : DataCategory;
        attribute content : String;
        attribute createdAt : Timestamp;
    }

    item def EncryptedData {
        attribute recordId : DataRecordId;
        attribute ciphertext : String;
        attribute keyId : KeyId;
        attribute algorithm : EncryptionAlgorithm;
        attribute encryptedAt : Timestamp;
    }

    item def ConsentRecord {
        attribute consentId : ConsentId;
        attribute subjectId : DataSubjectId;
        attribute purpose : Purpose;
        attribute category : DataCategory;
        attribute status : ConsentStatus;
        attribute grantedAt : Timestamp;
        attribute expiresAt : Timestamp;
    }

    item def AccessRequest {
        attribute requestId : RequestId;
        attribute requesterId : UserId;
        attribute subjectId : DataSubjectId;
        attribute category : DataCategory;
        attribute purpose : Purpose;
        attribute requestedAt : Timestamp;
    }

    item def AccessResponse {
        attribute requestId : RequestId;
        attribute decision : AccessDecision;
        attribute reason : String;
        attribute respondedAt : Timestamp;
    }

    item def AuditEntry {
        attribute entryId : String;
        attribute action : String;
        attribute actorId : UserId;
        attribute targetRecordId : DataRecordId;
        attribute outcome : String;
        attribute timestamp : Timestamp;
        attribute hash : String;
    }

    item def RetentionPolicy {
        attribute policyId : PolicyId;
        attribute category : DataCategory;
        attribute retentionPeriod : DurationDays;
        attribute action : RetentionAction;
    }

    item def AnonymizedData {
        attribute recordId : DataRecordId;
        attribute method : AnonymizationMethod;
        attribute sanitizedContent : String;
        attribute processedAt : Timestamp;
    }

    item def EncryptionKey {
        attribute keyId : KeyId;
        attribute algorithm : EncryptionAlgorithm;
        attribute strength : KeyStrengthBits;
        attribute createdAt : Timestamp;
        attribute rotatedAt : Timestamp;
        attribute active : Boolean;
    }

    // ---------- Port Definitions ----------
    port def ConsentQueryPort {
        out consentRecords : ConsentRecord[*];
        in querySubjectId : DataSubjectId;
        in queryPurpose : Purpose;
        in queryCategory : DataCategory;
        out validConsent : Boolean;
    }

    port def AccessRequestPort {
        in accessRequest : AccessRequest;
        out accessResponse : AccessResponse;
    }

    port def EncryptionPort {
        in plaintext : PersonalData;
        out encrypted : EncryptedData;
        in ciphertext : EncryptedData;
        out decrypted : PersonalData;
    }

    port def DataStorePort {
        in store : EncryptedData;
        in retrieveRecordId : DataRecordId;
        out retrieved : EncryptedData;
        in deleteRecordId : DataRecordId;
        out deletionConfirmed : Boolean;
    }

    port def AuditPort {
        in logEntry : AuditEntry;
        out entryAccepted : Boolean;
    }

    port def RetentionPort {
        in policy : RetentionPolicy;
        in evaluateRecordId : DataRecordId;
        out actionTriggered : RetentionAction;
    }

    port def AnonymizationPort {
        in personalData : PersonalData;
        in method : AnonymizationMethod;
        out anonymized : AnonymizedData;
    }

    port def KeyManagementPort {
        out currentKey : EncryptionKey;
        in rotateKeyId : KeyId;
        out rotatedKey : EncryptionKey;
    }

    // ---------- Interfaces ----------
    interface def ConsentQueryInterface {
        end provider : ConsentQueryPort;
        end consumer : ConsentQueryPort;
    }

    interface def AccessRequestInterface {
        end responder : AccessRequestPort;
        end requester : AccessRequestPort;
    }

    interface def EncryptionInterface {
        end service : EncryptionPort;
        end client : EncryptionPort;
    }

    interface def DataStoreInterface {
        end store : DataStorePort;
        end client : DataStorePort;
    }

    interface def AuditInterface {
        end logger : AuditPort;
        end source : AuditPort;
    }

    interface def RetentionInterface {
        end manager : RetentionPort;
        end client : RetentionPort;
    }

    interface def AnonymizationInterface {
        end engine : AnonymizationPort;
        end client : AnonymizationPort;
    }

    interface def KeyManagementInterface {
        end service : KeyManagementPort;
        end client : KeyManagementPort;
    }

    // ---------- Part Definitions ----------
    part def ConsentManager {
        attribute registry : ConsentRecord[*];
        port consentQuery : ConsentQueryPort;

        action def ValidateConsent {
            in subjectId : DataSubjectId;
            in purpose : Purpose;
            in category : DataCategory;
            out isValid : Boolean;
        }

        action def RevokeConsent {
            in consentId : ConsentId;
            out revoked : Boolean;
        }

        action def TrackExpiration {
            in currentTime : Timestamp;
            out expiredConsents : ConsentId[*];
        }

        action def GrantConsent {
            in subjectId : DataSubjectId;
            in purpose : Purpose;
            in category : DataCategory;
            in duration : DurationDays;
            out newConsent : ConsentRecord;
        }

        state def ConsentManagerBehavior {
            entry;
            do GrantConsent;
            state Active {
                entry;
                do ValidateConsent;
                transition Active to Revoked
                    when consentQuery.validConsent == false;
            }
            state Revoked {
                entry;
                do RevokeConsent;
            }
            state Expired {
                entry;
                do TrackExpiration;
            }
            transition Active to Expired
                when TrackExpiration.expiredConsents->size() > 0;
            transition Revoked to final;
            transition Expired to final;
        }

        exhibit ConsentManagerBehavior;
    }

    part def AccessControlEngine {
        port accessRequestPort : AccessRequestPort;
        port consentQueryPort : ConsentQueryPort;
        port auditPort : AuditPort;
        port encryptionPort : EncryptionPort;

        attribute policies : PolicyId[*];

        action def EvaluateRequest {
            in request : AccessRequest;
            out response : AccessResponse;
        }

        action def CheckConsent {
            in request : AccessRequest;
            out consentValid : Boolean;
        }

        action def EnforcePolicies {
            in request : AccessRequest;
            in consentValid : Boolean;
            out decision : AccessDecision;
        }

        action def LogAccessAttempt {
            in request : AccessRequest;
            in response : AccessResponse;
        }

        state def AccessControlBehavior {
            state Idle {
                entry;
                transition Idle to Evaluating
                    when accessRequestPort.accessRequest->notEmpty();
            }
            state Evaluating {
                entry;
                do EvaluateRequest;
                transition Evaluating to Idle
                    when accessRequestPort.accessResponse->notEmpty();
            }
        }

        exhibit AccessControlBehavior;
    }

    part def EncryptionService {
        port encryptionPort : EncryptionPort;
        port keyManagementPort : KeyManagementPort;
        port auditPort : AuditPort;

        attribute keys : EncryptionKey[*];
        attribute currentKeyId : KeyId;
        attribute rotationInterval : DurationDays = 90 [d];

        action def EncryptData {
            in plaintext : PersonalData;
            out encrypted : EncryptedData;
        }

        action def DecryptData {
            in ciphertext : EncryptedData;
            out decrypted : PersonalData;
        }

        action def GenerateKey {
            in algorithm : EncryptionAlgorithm;
            in strength : KeyStrengthBits;
            out key : EncryptionKey;
        }

        action def RotateKey {
            in oldKeyId : KeyId;
            out newKey : EncryptionKey;
        }

        state def EncryptionServiceBehavior {
            state Operational {
                entry;
                do EncryptData;
                transition Operational to KeyRotation
                    when keyManagementPort.rotateKeyId->notEmpty();
            }
            state KeyRotation {
                entry;
                do RotateKey;
                transition KeyRotation to Operational
                    when keyManagementPort.rotatedKey->notEmpty();
            }
        }

        exhibit EncryptionServiceBehavior;
    }

    part def SecureDataStore {
        port dataStorePort : DataStorePort;
        port auditPort : AuditPort;

        attribute storedRecords : EncryptedData[*];
        attribute capacity : RecordCount = 1000000;

        action def StoreRecord {
            in encrypted : EncryptedData;
            out stored : Boolean;
        }

        action def RetrieveRecord {
            in recordId : DataRecordId;
            out retrieved : EncryptedData;
        }

        action def DeleteRecord {
            in recordId : DataRecordId;
            out deleted : Boolean;
        }

        state def DataStoreBehavior {
            state Available {
                entry;
                transition Available to Storing
                    when dataStorePort.store->notEmpty();
                transition Available to Retrieving
                    when dataStorePort.retrieveRecordId->notEmpty();
                transition Available to Deleting
                    when dataStorePort.deleteRecordId->notEmpty();
            }
            state Storing {
                entry;
                do StoreRecord;
                transition Storing to Available
                    when dataStorePort.store->isEmpty();
            }
            state Retrieving {
                entry;
                do RetrieveRecord;
                transition Retrieving to Available
                    when dataStorePort.retrieved->notEmpty();
            }
            state Deleting {
                entry;
                do DeleteRecord;
                transition Deleting to Available
                    when dataStorePort.deletionConfirmed == true;
            }
        }

        exhibit DataStoreBehavior;
    }

    part def AuditLogger {
        port auditPort : AuditPort;

        attribute logEntries : AuditEntry[*];
        attribute previousHash : String = "0x0000";

        action def LogEntry {
            in entry : AuditEntry;
            out accepted : Boolean;
        }

        action def GenerateReport {
            in startTime : Timestamp;
            in endTime : Timestamp;
            out report : String;
        }

        action def DetectAnomaly {
            in recentEntries : AuditEntry[*];
            out anomalyDetected : Boolean;
        }

        state def AuditLoggerBehavior {
            state Listening {
                entry;
                transition Listening to Recording
                    when auditPort.logEntry->notEmpty();
            }
            state Recording {
                entry;
                do LogEntry;
                transition Recording to Listening
                    when auditPort.entryAccepted == true;
            }
        }

        exhibit AuditLoggerBehavior;
    }

    part def RetentionManager {
        port retentionPort : RetentionPort;
        port dataStorePort : DataStorePort;
        port auditPort : AuditPort;

        attribute policies : RetentionPolicy[*];

        action def EnforcePolicy {
            in policy : RetentionPolicy;
            in recordId : DataRecordId;
            out action : RetentionAction;
        }

        action def SecureDelete {
            in recordId : DataRecordId;
            out deleted : Boolean;
        }

        action def Archive {
            in recordId : DataRecordId;
            out archived : Boolean;
        }

        state def RetentionManagerBehavior {
            state Monitoring {
                entry;
                transition Monitoring to Enforcing
                    when retentionPort.policy->notEmpty();
            }
            state Enforcing {
                entry;
                do EnforcePolicy;
                transition Enforcing to Monitoring
                    when retentionPort.actionTriggered->isEmpty();
                transition Enforcing to Deleting
                    when retentionPort.actionTriggered == RetentionAction::delete;
                transition Enforcing to Archiving
                    when retentionPort.actionTriggered == RetentionAction::archive;
            }
            state Deleting {
                entry;
                do SecureDelete;
                transition Deleting to Monitoring
                    when dataStorePort.deletionConfirmed == true;
            }
            state Archiving {
                entry;
                do Archive;
                transition Archiving to Monitoring
                    when dataStorePort.store->isEmpty();
            }
        }

        exhibit RetentionManagerBehavior;
    }

    part def AnonymizationEngine {
        port anonymizationPort : AnonymizationPort;
        port auditPort : AuditPort;

        action def StripIdentifiers {
            in data : PersonalData;
            in method : AnonymizationMethod;
            out anonymized : AnonymizedData;
        }

        action def ValidateAnonymization {
            in anonymized : AnonymizedData;
            out isValid : Boolean;
        }

        state def AnonymizationBehavior {
            state Idle {
                entry;
                transition Idle to Processing
                    when anonymizationPort.personalData->notEmpty();
            }
            state Processing {
                entry;
                do StripIdentifiers;
                transition Processing to Validating
                    when anonymizationPort.anonymized->notEmpty();
            }
            state Validating {
                entry;
                do ValidateAnonymization;
                transition Validating to Idle
                    when ValidateAnonymization.isValid == true;
            }
        }

        exhibit AnonymizationBehavior;
    }

    // ---------- Top-Level System ----------
    part def DataPrivacyManagementSystem {

        port externalAccessPort : AccessRequestPort;
        port externalAuditReportPort : AuditPort;

        part consentManager : ConsentManager {
            port consentQuery : ConsentQueryPort;
        }
        part accessControlEngine : AccessControlEngine {
            port accessRequestPort : AccessRequestPort;
            port consentQueryPort : ConsentQueryPort;
            port auditPort : AuditPort;
            port encryptionPort : EncryptionPort;
        }
        part encryptionService : EncryptionService {
            port encryptionPort : EncryptionPort;
            port keyManagementPort : KeyManagementPort;
            port auditPort : AuditPort;
        }
        part secureDataStore : SecureDataStore {
            port dataStorePort : DataStorePort;
            port auditPort : AuditPort;
        }
        part auditLogger : AuditLogger {
            port auditPort : AuditPort;
        }
        part retentionManager : RetentionManager {
            port retentionPort : RetentionPort;
            port dataStorePort : DataStorePort;
            port auditPort : AuditPort;
        }
        part anonymizationEngine : AnonymizationEngine {
            port anonymizationPort : AnonymizationPort;
            port auditPort : AuditPort;
        }

        // Connections
        connection consentManager.consentQuery to accessControlEngine.consentQueryPort satisfies ConsentQueryInterface;
        connection accessControlEngine.encryptionPort to encryptionService.encryptionPort satisfies EncryptionInterface;
        connection encryptionService.encryptionPort to secureDataStore.dataStorePort satisfies DataStoreInterface;
        connection accessControlEngine.auditPort to auditLogger.auditPort satisfies AuditInterface;
        connection encryptionService.auditPort to auditLogger.auditPort satisfies AuditInterface;
        connection secureDataStore.auditPort to auditLogger.auditPort satisfies AuditInterface;
        connection retentionManager.auditPort to auditLogger.auditPort satisfies AuditInterface;
        connection anonymizationEngine.auditPort to auditLogger.auditPort satisfies AuditInterface;
        connection retentionManager.dataStorePort to secureDataStore.dataStorePort satisfies DataStoreInterface;
        connection externalAccessPort to accessControlEngine.accessRequestPort satisfies AccessRequestInterface;
        connection externalAuditReportPort to auditLogger.auditPort satisfies AuditInterface;

        action def ProcessAccessRequest {
            in request : AccessRequest;
            out response : AccessResponse;
        }

        action def ProcessRetentionEvaluation {
            in policy : RetentionPolicy;
            out action : RetentionAction;
        }

        action def ProcessAnonymization {
            in data : PersonalData;
            in method : AnonymizationMethod;
            out anonymized : AnonymizedData;
        }

        state def SystemOperation {
            state Operational {
                entry;
                do ProcessAccessRequest;
                transition Operational to Maintenance
                    when encryptionService.keyManagementPort.rotateKeyId->notEmpty();
            }
            state Maintenance {
                entry;
                do ProcessRetentionEvaluation;
                transition Maintenance to Operational
                    when retentionManager.retentionPort.actionTriggered->isEmpty();
            }
        }

        exhibit SystemOperation;
    }

    // ---------- Requirements ----------
    requirement def PrivacyComplianceRequirement {
        doc /* The system shall ensure that personal data is only accessed when valid consent exists. */
        subject system : DataPrivacyManagementSystem;
        objective {
            satisfy accessControlEngine.consentQueryPort.validConsent == true
            when accessControlEngine.accessRequestPort.accessRequest->notEmpty();
        }
    }

    requirement def EncryptionRequirement {
        doc /* All personal data shall be encrypted before storage using AES256 or stronger. */
        subject system : DataPrivacyManagementSystem;
        objective {
            satisfy encryptionService.encryptionPort.encrypted.algorithm == EncryptionAlgorithm::AES256
            or encryptionService.encryptionPort.encrypted.algorithm == EncryptionAlgorithm::RSA4096;
        }
    }

    requirement def KeyRotationRequirement {
        doc /* Encryption keys shall be rotated at least every 90 days. */
        subject system : DataPrivacyManagementSystem;
        objective {
            satisfy encryptionService.rotationInterval <= 90 [d];
        }
    }

    requirement def AuditTrailRequirement {
        doc /* The system shall log all access attempts, consent changes, and data modifications in a tamper-evident trail. */
        subject system : DataPrivacyManagementSystem;
        objective {
            satisfy auditLogger.auditPort.entryAccepted == true
            when auditLogger.auditPort.logEntry->notEmpty();
        }
    }

    requirement def RetentionEnforcementRequirement {
        doc /* The system shall enforce retention policies and securely delete or archive expired data. */
        subject system : DataPrivacyManagementSystem;
        objective {
            satisfy retentionManager.retentionPort.actionTriggered == RetentionAction::delete
            or retentionManager.retentionPort.actionTriggered == RetentionAction::archive;
        }
    }

    requirement def AnonymizationRequirement {
        doc /* The anonymization engine shall strip personal identifiers when individual identity is not required. */
        subject system : DataPrivacyManagementSystem;
        objective {
            satisfy anonymizationEngine.anonymizationPort.anonymized.method == AnonymizationMethod::kAnonymity
            or anonymizationEngine.anonymizationPort.anonymized.method == AnonymizationMethod::differentialPrivacy
            or anonymizationEngine.anonymizationPort.anonymized.method == AnonymizationMethod::pseudonymization
            or anonymizationEngine.anonymizationPort.anonymized.method == AnonymizationMethod::generalization;
        }
    }

    requirement def ConsentRevocationRequirement {
        doc /* The Consent Manager shall allow revocation of consent and propagate the revocation to access control. */
        subject system : DataPrivacyManagementSystem;
        objective {
            satisfy consentManager.consentQuery.validConsent == false
            when consentManager.consentQuery.querySubjectId->notEmpty();
        }
    }

    requirement def SecureStorageRequirement {
        doc /* The Secure Data Store shall only accept encrypted data and shall support retrieval and deletion. */
        subject system : DataPrivacyManagementSystem;
        objective {
            satisfy secureDataStore.dataStorePort.store->notEmpty()
            implies secureDataStore.dataStorePort.store.encrypted.algorithm->notEmpty();
        }
    }

    requirement package DataPrivacyRequirements {
        requirement privacyCompliance : PrivacyComplianceRequirement;
        requirement encryption : EncryptionRequirement;
        requirement keyRotation : KeyRotationRequirement;
        requirement auditTrail : AuditTrailRequirement;
        requirement retentionEnforcement : RetentionEnforcementRequirement;
        requirement anonymization : AnonymizationRequirement;
        requirement consentRevocation : ConsentRevocationRequirement;
        requirement secureStorage : SecureStorageRequirement;
    }

    // ---------- Satisfaction ----------
    satisfaction privacyCompliance by DataPrivacyManagementSystem::accessControlEngine;
    satisfaction encryption by DataPrivacyManagementSystem::encryptionService;
    satisfaction keyRotation by DataPrivacyManagementSystem::encryptionService;
    satisfaction auditTrail by DataPrivacyManagementSystem::auditLogger;
    satisfaction retentionEnforcement by DataPrivacyManagementSystem::retentionManager;
    satisfaction anonymization by DataPrivacyManagementSystem::anonymizationEngine;
    satisfaction consentRevocation by DataPrivacyManagementSystem::consentManager;
    satisfaction secureStorage by DataPrivacyManagementSystem::secureDataStore;

}
