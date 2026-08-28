package DataPrivacyManagementSystem {
    private import ScalarValues::*;

    package BaseTypes {
        private import ScalarValues::*;

        attribute def Days :> Integer;

        enum def AccessDecision { Grant; Deny; }
        enum def ConsentStatus { Valid; Revoked; Expired; }
        enum def LifecycleAction { Delete; Archive; }

        item def PersonalData {
            attribute dataId : String;
            attribute subjectId : String;
            attribute category : String;
            attribute payload : String;
        }

        item def EncryptedData {
            attribute recordId : String;
            attribute ciphertext : String;
            attribute category : String;
        }

        item def AnonymizedData {
            attribute datasetId : String;
            attribute category : String;
            attribute payload : String;
            attribute anonymized : Boolean;
        }

        item def ConsentRecord {
            attribute consentId : String;
            attribute subjectId : String;
            attribute purpose : String;
            attribute status : ConsentStatus;
            attribute validFrom : String;
            attribute validUntil : String;
        }

        item def AccessRequest {
            attribute requestId : String;
            attribute requesterId : String;
            attribute subjectId : String;
            attribute recordId : String;
            attribute purpose : String;
            attribute dataCategory : String;
        }

        item def AccessResponse {
            attribute requestId : String;
            attribute decision : AccessDecision;
            attribute reason : String;
        }

        item def EncryptRequest {
            attribute requestId : String;
            item plaintext : PersonalData;
        }

        item def EncryptionKey {
            attribute keyId : String;
            attribute algorithm : String;
            attribute keyMaterial : String;
            attribute createdAt : String;
            attribute rotationDueDays : Days;
        }

        item def LogEntry {
            attribute entryId : String;
            attribute timestamp : String;
            attribute actorId : String;
            attribute actionType : String;
            attribute outcome : String;
            attribute details : String;
        }

        item def RetentionPolicy {
            attribute policyId : String;
            attribute dataCategory : String;
            attribute retentionDays : Days;
            attribute lifecycleAction : LifecycleAction;
        }

        item def RetentionAlert {
            attribute alertId : String;
            attribute dataCategory : String;
            attribute recordId : String;
            attribute lifecycleAction : LifecycleAction;
        }
    }

    package Definitions {
        private import BaseTypes::*;

        port def ConsentPort {
            in ref request : AccessRequest;
            out ref status : ConsentStatus;
            out ref consentRecord : ConsentRecord;
        }

        port def AccessControlPort {
            in ref request : AccessRequest;
            out ref response : AccessResponse;
        }

        port def CryptoPort {
            in ref encryptRequest : EncryptRequest;
            out ref encryptedData : EncryptedData;
            in ref decryptRequest : AccessRequest;
            out ref decryptedData : PersonalData;
        }

        port def StoragePort {
            in ref storeCommand : EncryptedData;
            in ref retrieveCommand : String;
            out ref retrieveResponse : EncryptedData;
            in ref retentionCommand : RetentionAlert;
        }

        port def AuditPort {
            in ref logEntry : LogEntry;
        }

        port def ReportPort {
            in ref query : String;
            out ref report : String;
        }

        port def RetentionPort {
            in ref policy : RetentionPolicy;
            out ref alert : RetentionAlert;
        }

        port def AnonymizationPort {
            in ref request : PersonalData;
            out ref response : AnonymizedData;
        }

        part def ConsentManager {
            port consentIF : ConsentPort;
            port auditOut : ~AuditPort;
            item consents : ConsentRecord[0..*];

            state machine ConsentLifecycle {
                state Active;
                state Revoked;
                state Expired;
                transition from Active to Revoked;
                transition from Active to Expired;
                transition from Expired to Active;
            }

            perform action manageConsent {
                action validateConsent {
                    in ref request : AccessRequest;
                    out ref status : ConsentStatus;
                    out ref consentRecord : ConsentRecord;
                }
                action revokeConsent {
                    in ref consentId : String;
                }
                action registerConsent {
                    in ref record : ConsentRecord;
                }
                action logOutcome {
                    in ref request : AccessRequest;
                    in ref status : ConsentStatus;
                    out ref logEntry : LogEntry;
                }
                flow consentRequest from consentIF.request to validateConsent.request;
                flow consentStatus from validateConsent.status to consentIF.status;
                flow consentRecord from validateConsent.consentRecord to consentIF.consentRecord;
                flow logRequest from consentIF.request to logOutcome.request;
                flow logStatus from validateConsent.status to logOutcome.status;
                flow auditEntry from logOutcome.logEntry to auditOut.logEntry;
            }
        }

        part def AccessControlEngine {
            port accessIF : AccessControlPort;
            port consentIF : ~ConsentPort;
            port cryptoIF : ~CryptoPort;
            port anonIF : ~AnonymizationPort;
            port auditOut : ~AuditPort;

            state machine AccessEvaluationLifecycle {
                state Idle;
                state CheckingConsent;
                state EnforcingPolicy;
                state AuthorizedProcessing;
                state Responding;
                transition from Idle to CheckingConsent;
                transition from CheckingConsent to EnforcingPolicy;
                transition from EnforcingPolicy to AuthorizedProcessing;
                transition from EnforcingPolicy to Responding;
                transition from AuthorizedProcessing to Responding;
                transition from Responding to Idle;
            }

            perform action evaluateAccess {
                action checkConsent {
                    in ref request : AccessRequest;
                    out ref query : AccessRequest;
                }
                action enforcePolicy {
                    in ref request : AccessRequest;
                    in ref status : ConsentStatus;
                    in ref consentRecord : ConsentRecord;
                    out ref decision : AccessDecision;
                }
                action processAuthorizedData {
                    in ref request : AccessRequest;
                    in ref decision : AccessDecision;
                    in ref decryptedData : PersonalData;
                }
                action respond {
                    in ref request : AccessRequest;
                    in ref decision : AccessDecision;
                    out ref response : AccessResponse;
                }
                action logOutcome {
                    in ref request : AccessRequest;
                    in ref decision : AccessDecision;
                    out ref logEntry : LogEntry;
                }
                flow accessRequest from accessIF.request to checkConsent.request;
                flow consentQuery from checkConsent.query to consentIF.request;
                flow policyRequest from accessIF.request to enforcePolicy.request;
                flow consentStatus from consentIF.status to enforcePolicy.status;
                flow consentRecord from consentIF.consentRecord to enforcePolicy.consentRecord;
                flow authorizedRequest from accessIF.request to processAuthorizedData.request;
                flow authorizedDecision from enforcePolicy.decision to processAuthorizedData.decision;
                flow authorizedDecrypt from accessIF.request to cryptoIF.decryptRequest;
                flow decryptedData from cryptoIF.decryptedData to processAuthorizedData.decryptedData;
                flow analyticsData from cryptoIF.decryptedData to anonIF.request;
                flow responseRequest from accessIF.request to respond.request;
                flow policyDecision from enforcePolicy.decision to respond.decision;
                flow responseOut from respond.response to accessIF.response;
                flow logRequest from accessIF.request to logOutcome.request;
                flow logDecision from enforcePolicy.decision to logOutcome.decision;
                flow auditEntry from logOutcome.logEntry to auditOut.logEntry;
            }
        }

        part def EncryptionService {
            port cryptoIF : CryptoPort;
            port storageIF : ~StoragePort;
            port auditOut : ~AuditPort;
            item keys : EncryptionKey[0..*];

            state machine KeyLifecycle {
                state Active;
                state Retired;
                transition from Active to Retired;
            }

            perform action cryptoOperations {
                action encrypt {
                    in ref request : EncryptRequest;
                    out ref encryptedData : EncryptedData;
                }
                action decrypt {
                    in ref request : AccessRequest;
                    in ref retrievedData : EncryptedData;
                    out ref plaintext : PersonalData;
                }
                action rotateKey {
                    out ref newKey : EncryptionKey;
                }
                action logCrypto {
                    in ref key : EncryptionKey;
                    out ref logEntry : LogEntry;
                }
                flow encryptRequest from cryptoIF.encryptRequest to encrypt.request;
                flow encryptedForStorage from encrypt.encryptedData to storageIF.storeCommand;
                flow encryptedResponse from encrypt.encryptedData to cryptoIF.encryptedData;
                flow decryptRequest from cryptoIF.decryptRequest to decrypt.request;
                flow retrieveCommand from cryptoIF.decryptRequest.recordId to storageIF.retrieveCommand;
                flow retrievedEncrypted from storageIF.retrieveResponse to decrypt.retrievedData;
                flow decryptedData from decrypt.plaintext to cryptoIF.decryptedData;
                flow newKey from rotateKey.newKey to logCrypto.key;
                flow cryptoAudit from logCrypto.logEntry to auditOut.logEntry;
            }
        }

        part def SecureDataStore {
            port storageIF : StoragePort;
            port auditOut : ~AuditPort;
            item storedRecords : EncryptedData[0..*];

            state machine RetentionExecution {
                state Idle;
                state Storing;
                state Retrieving;
                state Deleting;
                state Archiving;
                transition from Idle to Storing;
                transition from Idle to Retrieving;
                transition from Idle to Deleting;
                transition from Idle to Archiving;
                transition from Storing to Idle;
                transition from Retrieving to Idle;
                transition from Deleting to Idle;
                transition from Archiving to Idle;
            }

            perform action storageOperations {
                action store {
                    in ref data : EncryptedData;
                }
                action retrieve {
                    in ref recordId : String;
                    out ref data : EncryptedData;
                }
                action executeRetention {
                    in ref command : RetentionAlert;
                }
                action logStorage {
                    in ref operation : String;
                    out ref logEntry : LogEntry;
                }
                flow storeCommand from storageIF.storeCommand to store.data;
                flow retrieveCommand from storageIF.retrieveCommand to retrieve.recordId;
                flow retrieveResponse from retrieve.data to storageIF.retrieveResponse;
                flow retentionCommand from storageIF.retentionCommand to executeRetention.command;
                flow storeLog from storageIF.storeCommand.recordId to logStorage.operation;
                flow storageAudit from logStorage.logEntry to auditOut.logEntry;
            }
        }

        part def AuditLogger {
            port auditIF : AuditPort;
            port reportIF : ReportPort;
            item logEntries : LogEntry[0..*];

            perform action auditOperations {
                action record {
                    in ref logEntry : LogEntry;
                }
                action generateReport {
                    in ref query : String;
                    out ref report : String;
                }
                flow incomingEntry from auditIF.logEntry to record.logEntry;
                flow reportQuery from reportIF.query to generateReport.query;
                flow reportOutput from generateReport.report to reportIF.report;
            }
        }

        part def RetentionManager {
            port retentionIF : RetentionPort;
            port storageIF : ~StoragePort;
            port auditOut : ~AuditPort;
            item policies : RetentionPolicy[0..*];

            state machine RetentionEnforcement {
                state Idle;
                state Evaluating;
                state Triggering;
                transition from Idle to Evaluating;
                transition from Evaluating to Triggering;
                transition from Triggering to Idle;
            }

            perform action retentionOperations {
                action enforcePolicy {
                    in ref policy : RetentionPolicy;
                    out ref alert : RetentionAlert;
                }
                action logRetention {
                    in ref alert : RetentionAlert;
                    out ref logEntry : LogEntry;
                }
                flow policyInput from retentionIF.policy to enforcePolicy.policy;
                flow retentionAlert from enforcePolicy.alert to retentionIF.alert;
                flow retentionAction from enforcePolicy.alert to storageIF.retentionCommand;
                flow retentionAuditInput from enforcePolicy.alert to logRetention.alert;
                flow retentionAudit from logRetention.logEntry to auditOut.logEntry;
            }
        }

        part def AnonymizationEngine {
            port anonIF : AnonymizationPort;
            port auditOut : ~AuditPort;

            perform action anonymizationOperations {
                action stripIdentifiers {
                    in ref data : PersonalData;
                    out ref anonymizedData : AnonymizedData;
                }
                action logAnonymization {
                    in ref data : PersonalData;
                    out ref logEntry : LogEntry;
                }
                flow anonymizationRequest from anonIF.request to stripIdentifiers.data;
                flow anonymizationResponse from stripIdentifiers.anonymizedData to anonIF.response;
                flow anonAuditInput from anonIF.request to logAnonymization.data;
                flow anonAudit from logAnonymization.logEntry to auditOut.logEntry;
            }
        }

        part def DataPrivacySystem {
            part consentManager : ConsentManager;
            part accessControl : AccessControlEngine;
            part encryptionService : EncryptionService;
            part secureDataStore : SecureDataStore;
            part auditLogger : AuditLogger;
            part retentionManager : RetentionManager;
            part anonymizationEngine : AnonymizationEngine;

            connect accessControl.consentIF to consentManager.consentIF;
            connect accessControl.cryptoIF to encryptionService.cryptoIF;
            connect encryptionService.storageIF to secureDataStore.storageIF;
            connect retentionManager.storageIF to secureDataStore.storageIF;
            connect accessControl.anonIF to anonymizationEngine.anonIF;
            connect consentManager.auditOut to auditLogger.auditIF;
            connect accessControl.auditOut to auditLogger.auditIF;
            connect encryptionService.auditOut to auditLogger.auditIF;
            connect secureDataStore.auditOut to auditLogger.auditIF;
            connect retentionManager.auditOut to auditLogger.auditIF;
            connect anonymizationEngine.auditOut to auditLogger.auditIF;
        }
    }

    package Requirements {
        private import BaseTypes::*;

        requirement def ConsentValidation {
            doc "All processing of personal data shall be preceded by valid, purpose-specific consent.";
        }

        requirement def AccessControlEvaluation {
            doc "Every access request shall be evaluated against consent and policy before approval or denial.";
        }

        requirement def EncryptionAtRest {
            doc "All personal data shall be encrypted before storage and decrypted only for authorized requests.";
        }

        requirement def AuditTraceability {
            doc "Every consent change, access attempt, and data modification shall be recorded in a tamper-evident audit trail.";
        }

        requirement def RetentionCompliance {
            doc "Personal data shall be retained only for the period defined by its retention policy and then deleted or archived.";
        }

        requirement def AnonymizationForAnalytics {
            doc "Personal identifiers shall be stripped from data used for analytics or research when individual identity is not required.";
        }
    }

    package Usages {
        private import Definitions::*;
        part dataPrivacySystem : DataPrivacySystem;
    }
}
