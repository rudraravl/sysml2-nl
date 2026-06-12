package DataPrivacySystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percentage {
        :> ScalarValues::Real;
        unit = "%";
    }

    attribute def Bytes {
        :> ScalarValues::Integer;
        unit = "B";
    }

    attribute def Milliseconds {
        :> ScalarValues::Real;
        unit = "ms";
    }

    attribute def Days {
        :> ScalarValues::Real;
        unit = "d";
    }

    item def PersonalData {
        attribute subjectId : String;
        attribute category : DataCategory;
        attribute sensitivity : SensitivityLevel;
        attribute size : Bytes;
        attribute originSystem : String;
        attribute createdAtEpochMs : Integer;
    }

    item def ConsentRecord {
        attribute subjectId : String;
        attribute purpose : ProcessingPurpose;
        attribute granted : Boolean;
        attribute validUntilEpochMs : Integer;
        attribute policyVersion : String;
    }

    item def PrivacyDecision {
        attribute allowed : Boolean;
        attribute reasonCode : String;
        attribute appliedPolicyVersion : String;
    }

    item def AuditEvent {
        attribute eventId : String;
        attribute actorId : String;
        attribute subjectId : String;
        attribute operation : PrivacyOperation;
        attribute decision : Boolean;
        attribute timestampEpochMs : Integer;
    }

    item def EncryptedData {
        attribute ciphertextSize : Bytes;
        attribute keyId : String;
        attribute algorithm : String;
    }

    item def AnonymizedData {
        attribute recordCount : Integer;
        attribute kAnonymityLevel : Integer;
        attribute residualRiskScore : Percentage;
    }

    enum def DataCategory {
        enum basicIdentity;
        enum contact;
        enum financial;
        enum health;
        enum location;
        enum biometric;
        enum behavioral;
    }

    enum def SensitivityLevel {
        enum low;
        enum moderate;
        enum high;
        enum restricted;
    }

    enum def ProcessingPurpose {
        enum accountService;
        enum securityMonitoring;
        enum analytics;
        enum personalization;
        enum legalCompliance;
        enum marketing;
    }

    enum def PrivacyOperation {
        enum collect;
        enum classify;
        enum validateConsent;
        enum encrypt;
        enum anonymize;
        enum share;
        enum delete;
        enum audit;
    }

    port def DataInPort {
        in item personalData : PersonalData;
    }

    port def DataOutPort {
        out item protectedData : EncryptedData;
        out item anonymizedData : AnonymizedData;
    }

    port def ConsentPort {
        in item consent : ConsentRecord;
        out item decision : PrivacyDecision;
    }

    port def AuditPort {
        out item auditEvent : AuditEvent;
    }

    port def PolicyPort {
        in item activePolicyVersion : String;
    }

    port def KeyManagementPort {
        out item keyRequest : String;
        in item keyId : String;
    }

    action def ClassifyData {
        in item rawData : PersonalData;
        out item classifiedData : PersonalData;
        attribute classificationLatency : Milliseconds;
    }

    action def ValidateConsent {
        in item data : PersonalData;
        in item consent : ConsentRecord;
        out item decision : PrivacyDecision;
        attribute validationLatency : Milliseconds;
    }

    action def EncryptPersonalData {
        in item data : PersonalData;
        in item keyId : String;
        out item encrypted : EncryptedData;
        attribute encryptionLatency : Milliseconds;
    }

    action def AnonymizeForAnalytics {
        in item data : PersonalData;
        out item anonymized : AnonymizedData;
        attribute minimumK : Integer = 10;
        attribute anonymizationLatency : Milliseconds;
    }

    action def RecordAuditEvent {
        in item data : PersonalData;
        in item decision : PrivacyDecision;
        out item event : AuditEvent;
    }

    action def DeleteExpiredData {
        in item data : PersonalData;
        out item deletionEvent : AuditEvent;
        attribute retentionLimit : Days;
    }

    state def PrivacyProcessingStateMachine {
        state idle;
        state receivingData;
        state classifying;
        state checkingConsent;
        state protectingData;
        state anonymizingData;
        state publishingApprovedData;
        state rejectingProcessing;
        state auditing;
        state completed;

        transition first idle;
        transition idle to receivingData;
        transition receivingData to classifying;
        transition classifying to checkingConsent;
        transition checkingConsent to protectingData if consentIsValid;
        transition checkingConsent to rejectingProcessing if consentIsInvalid;
        transition protectingData to anonymizingData if purposeIsAnalytics;
        transition protectingData to publishingApprovedData if purposeIsDirectService;
        transition anonymizingData to publishingApprovedData;
        transition publishingApprovedData to auditing;
        transition rejectingProcessing to auditing;
        transition auditing to completed;
        transition completed to idle;
    }

    part def ConsentRegistry {
        port consentInterface : ConsentPort;
        attribute storedConsentRecords : Integer;
        attribute consentLookupLatencyTarget : Milliseconds = 50.0;
        attribute consentValidityMinimum : Days = 1.0;

        action validate : ValidateConsent;
    }

    part def PrivacyPolicyEngine {
        port policyInput : PolicyPort;
        port consentQuery : ConsentPort;
        attribute activePolicyVersion : String = "privacy-policy-2026.1";
        attribute deniedHighRiskPurposes : ProcessingPurpose[1..*] = (ProcessingPurpose::marketing);
        attribute automatedDecisionAccuracyTarget : Percentage = 99.5;

        action classify : ClassifyData;
        action validateConsent : ValidateConsent;
    }

    part def EncryptionService {
        port keyManagement : KeyManagementPort;
        port protectedOutput : DataOutPort;
        attribute requiredAlgorithm : String = "AES-256-GCM";
        attribute keyRotationInterval : Days = 90.0;
        attribute maximumEncryptionLatency : Milliseconds = 100.0;

        action encrypt : EncryptPersonalData;
    }

    part def AnonymizationService {
        port anonymizedOutput : DataOutPort;
        attribute minimumKAnonymity : Integer = 10;
        attribute maximumResidualRisk : Percentage = 5.0;
        attribute maximumAnonymizationLatency : Milliseconds = 500.0;

        action anonymize : AnonymizeForAnalytics;
    }

    part def AuditLogger {
        port auditOutput : AuditPort;
        attribute immutableRetentionPeriod : Days = 2555.0;
        attribute auditCompletenessTarget : Percentage = 100.0;
        attribute maximumAuditLatency : Milliseconds = 25.0;

        action record : RecordAuditEvent;
    }

    part def RetentionManager {
        port auditOutput : AuditPort;
        attribute defaultRetentionPeriod : Days = 365.0;
        attribute restrictedDataRetentionPeriod : Days = 30.0;
        attribute deletionVerificationTarget : Percentage = 99.9;

        action deleteExpired : DeleteExpiredData;
    }

    part def PrivacyGateway {
        port dataInput : DataInPort;
        port consentInput : ConsentPort;
        port protectedOutput : DataOutPort;
        port auditOutput : AuditPort;

        part policyEngine : PrivacyPolicyEngine;
        part consentRegistry : ConsentRegistry;
        part encryptionService : EncryptionService;
        part anonymizationService : AnonymizationService;
        part auditLogger : AuditLogger;
        part retentionManager : RetentionManager;

        attribute maximumEndToEndLatency : Milliseconds = 750.0;
        attribute minimumConsentDecisionAccuracy : Percentage = 99.5;
        attribute minimumProtectedDataCoverage : Percentage = 100.0;

        perform action classifyData : ClassifyData;
        perform action validateConsent : ValidateConsent;
        perform action encryptApprovedData : EncryptPersonalData;
        perform action anonymizeAnalyticsData : AnonymizeForAnalytics;
        perform action auditDecision : RecordAuditEvent;

        exhibit state privacyProcessing : PrivacyProcessingStateMachine;

        connect dataInput.personalData to policyEngine.classify.rawData;
        connect consentInput.consent to consentRegistry.consentInterface.consent;
        connect consentRegistry.consentInterface.decision to policyEngine.consentQuery.decision;
        connect policyEngine.validateConsent.decision to consentInput.decision;
        connect encryptionService.protectedOutput.protectedData to protectedOutput.protectedData;
        connect anonymizationService.anonymizedOutput.anonymizedData to protectedOutput.anonymizedData;
        connect auditLogger.auditOutput.auditEvent to auditOutput.auditEvent;
        connect retentionManager.auditOutput.auditEvent to auditOutput.auditEvent;
    }

    part def DataPrivacySystem {
        doc /* 
         * The Data Privacy System receives personal data, determines whether each requested
         * processing activity is permitted, applies privacy controls such as classification,
         * consent validation, encryption, anonymization, retention enforcement, and immutable
         * audit logging, then releases only approved protected outputs.
         */

        port personalDataInput : DataInPort;
        port consentInterface : ConsentPort;
        port protectedDataOutput : DataOutPort;
        port auditInterface : AuditPort;

        part gateway : PrivacyGateway;

        attribute systemAvailabilityTarget : Percentage = 99.95;
        attribute personalDataProtectionCoverage : Percentage = 100.0;
        attribute highRiskProcessingBlockRate : Percentage = 100.0;
        attribute maximumPrivacyDecisionLatency : Milliseconds = 250.0;

        connect personalDataInput.personalData to gateway.dataInput.personalData;
        connect consentInterface.consent to gateway.consentInput.consent;
        connect gateway.consentInput.decision to consentInterface.decision;
        connect gateway.protectedOutput.protectedData to protectedDataOutput.protectedData;
        connect gateway.protectedOutput.anonymizedData to protectedDataOutput.anonymizedData;
        connect gateway.auditOutput.auditEvent to auditInterface.auditEvent;
    }

    requirement def ProtectPersonalDataRequirement {
        subject system : DataPrivacySystem;
        require constraint {
            system.personalDataProtectionCoverage >= 100.0
        }
    }

    requirement def ConsentBeforeProcessingRequirement {
        subject gateway : PrivacyGateway;
        require constraint {
            gateway.minimumConsentDecisionAccuracy >= 99.5
        }
    }

    requirement def EncryptionRequirement {
        subject encryptionService : EncryptionService;
        require constraint {
            encryptionService.requiredAlgorithm == "AES-256-GCM" and
            encryptionService.maximumEncryptionLatency <= 100.0
        }
    }

    requirement def AnonymizationRequirement {
        subject anonymizationService : AnonymizationService;
        require constraint {
            anonymizationService.minimumKAnonymity >= 10 and
            anonymizationService.maximumResidualRisk <= 5.0
        }
    }

    requirement def AuditabilityRequirement {
        subject auditLogger : AuditLogger;
        require constraint {
            auditLogger.auditCompletenessTarget == 100.0 and
            auditLogger.maximumAuditLatency <= 25.0
        }
    }

    requirement def RetentionRequirement {
        subject retentionManager : RetentionManager;
        require constraint {
            retentionManager.defaultRetentionPeriod <= 365.0 and
            retentionManager.restrictedDataRetentionPeriod <= 30.0
        }
    }

    requirement def HighLevelFunctionRequirement {
        subject system : DataPrivacySystem;
        doc /* The system shall provide privacy-preserving governance for personal data from intake through approved release or deletion. */
        require constraint {
            system.highRiskProcessingBlockRate == 100.0 and
            system.maximumPrivacyDecisionLatency <= 250.0
        }
    }

    part dataPrivacySystem : DataPrivacySystem;

    requirement protectPersonalData : ProtectPersonalDataRequirement {
        subject system = dataPrivacySystem;
    }

    requirement highLevelFunction : HighLevelFunctionRequirement {
        subject system = dataPrivacySystem;
    }

}