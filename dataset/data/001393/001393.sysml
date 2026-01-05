package 'Data Privacy System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def UserIdentifier;
	attribute def DataCategory;
	attribute def Purpose;
	attribute def Timestamp;
	attribute def EncryptionAlgorithm;
	
	attribute def ClassificationLevel {
		attribute levelName : String;
		attribute numericRank : Integer;
	}
	
	item def PersonalDataRecord {
		attribute subjectId : UserIdentifier;
		attribute category : DataCategory;
		attribute content : String;
		attribute classificationLevel : ClassificationLevel;
		attribute createdAt : Timestamp;
		attribute lastAccessedAt : Timestamp;
		attribute encryptionStatus : Boolean;
	}
	
	item def ConsentRecord {
		attribute subjectId : UserIdentifier;
		attribute dataCategory : DataCategory;
		attribute purpose : Purpose;
		attribute consentGranted : Boolean;
		attribute grantedAt : Timestamp;
		attribute expiresAt : Timestamp;
		attribute revocable : Boolean;
	}
	
	item def AccessRequest {
		attribute requestId : String;
		attribute requestorId : UserIdentifier;
		attribute targetSubjectId : UserIdentifier;
		attribute requestedCategory : DataCategory;
		attribute requestedPurpose : Purpose;
		attribute requestTimestamp : Timestamp;
	}
	
	item def AccessDecision {
		attribute requestId : String;
		attribute approved : Boolean;
		attribute reason : String;
		attribute decisionTimestamp : Timestamp;
		attribute grantedData : PersonalDataRecord;
	}
	
	item def AuditLogEntry {
		attribute entryId : String;
		attribute eventType : String;
		attribute actorId : UserIdentifier;
		attribute targetSubjectId : UserIdentifier;
		attribute dataCategory : DataCategory;
		attribute timestamp : Timestamp;
		attribute outcome : String;
		attribute details : String;
	}
	
	item def EncryptionKey {
		attribute keyId : String;
		attribute algorithm : EncryptionAlgorithm;
		attribute keyStrength : Integer;
		attribute createdAt : Timestamp;
		attribute expiresAt : Timestamp;
		attribute active : Boolean;
	}
	
	item def RetentionPolicy {
		attribute policyId : String;
		attribute dataCategory : DataCategory;
		attribute retentionPeriodDays : Integer;
		attribute autoDeleteEnabled : Boolean;
		attribute archiveBeforeDelete : Boolean;
	}
	
	port def ConsentManagementPort {
		in attribute consentRequest : ConsentRecord;
		out attribute consentConfirmation : Boolean;
		out attribute activeConsents : ConsentRecord[*];
	}
	
	port def DataAccessPort {
		in attribute accessRequest : AccessRequest;
		out attribute accessDecision : AccessDecision;
	}
	
	port def EncryptionPort {
		in attribute plainData : PersonalDataRecord;
		in attribute encryptionKey : EncryptionKey;
		out attribute encryptedData : PersonalDataRecord;
	}
	
	port def AuditPort {
		in attribute auditEvent : AuditLogEntry;
		out attribute auditConfirmation : Boolean;
	}
	
	port def StoragePort {
		in attribute dataToStore : PersonalDataRecord;
		out attribute storedData : PersonalDataRecord;
		in attribute retrievalRequest : UserIdentifier;
		out attribute retrievedData : PersonalDataRecord[*];
	}
	
	part def ConsentManager {
		attribute consentRegistry : ConsentRecord[*];
		port consentInterface : ConsentManagementPort;
		
		action def RegisterConsent {
			in newConsent : ConsentRecord;
			out registered : Boolean;
		}
		
		action def ValidateConsent {
			in subjectId : UserIdentifier;
			in category : DataCategory;
			in purpose : Purpose;
			out valid : Boolean;
			out matchingConsent : ConsentRecord;
		}
		
		action def RevokeConsent {
			in subjectId : UserIdentifier;
			in category : DataCategory;
			out revoked : Boolean;
		}
		
		action def CheckConsentExpiration {
			in currentTime : Timestamp;
			out expiredConsents : ConsentRecord[*];
		}
	}
	
	part def AccessControlEngine {
		attribute accessPolicies : String[*];
		port accessInterface : DataAccessPort;
		
		action def EvaluateAccessRequest {
			in req : AccessRequest;
			in cons : ConsentRecord;
			out decision : AccessDecision;
			
			first start;
			then action checkConsent {
				in request = req;
				in consent = cons;
				out consentValid : Boolean;
			}
			then decide;
				if checkConsent.consentValid then approveAccess;
				else denyAccess;
			
			action approveAccess {
				out approvedDecision : AccessDecision;
			}
			then merge finalDecision;
			
			action denyAccess {
				out deniedDecision : AccessDecision;
			}
			then finalDecision;
			then done;
		}
		
		action def EnforcePolicyCompliance {
			in request : AccessRequest;
			out compliant : Boolean;
		}
	}
	
	part def EncryptionService {
		attribute activeKeys : EncryptionKey[*];
		port encryptionInterface : EncryptionPort;
		
		action def EncryptData {
			in plainData : PersonalDataRecord;
			in key : EncryptionKey;
			out encryptedData : PersonalDataRecord;
		}
		
		action def DecryptData {
			in encryptedData : PersonalDataRecord;
			in key : EncryptionKey;
			out plainData : PersonalDataRecord;
		}
		
		action def RotateEncryptionKeys {
			in oldKey : EncryptionKey;
			out newKey : EncryptionKey;
		}
		
		action def ValidateKeyStrength {
			in key : EncryptionKey;
			out sufficient : Boolean;
		}
	}
	
	part def SecureDataStore {
		attribute storedRecords : PersonalDataRecord[*];
		port storageInterface : StoragePort;
		
		action def StoreEncryptedData {
			in data : PersonalDataRecord;
			out stored : Boolean;
		}
		
		action def RetrieveData {
			in subjectId : UserIdentifier;
			out records : PersonalDataRecord[*];
		}
		
		action def DeleteData {
			in subjectId : UserIdentifier;
			in category : DataCategory;
			out deleted : Boolean;
		}
		
		action def ArchiveData {
			in data : PersonalDataRecord;
			out archived : Boolean;
		}
	}
	
	part def AuditLogger {
		attribute auditLog : AuditLogEntry[*];
		port auditInterface : AuditPort;
		
		action def LogEvent {
			in event : AuditLogEntry;
			out logged : Boolean;
		}
		
		action def GenerateAuditReport {
			in startTime : Timestamp;
			in endTime : Timestamp;
			out report : AuditLogEntry[*];
		}
		
		action def DetectAnomalies {
			in recentEvents : AuditLogEntry[*];
			out anomalies : AuditLogEntry[*];
		}
	}
	
	part def RetentionManager {
		attribute policies : RetentionPolicy[*];
		
		action def ApplyRetentionPolicy {
			in data : PersonalDataRecord;
			in policy : RetentionPolicy;
			out actionType : String;
		}
		
		action def IdentifyExpiredData {
			in currentTime : Timestamp;
			out expiredRecords : PersonalDataRecord[*];
		}
		
		action def PurgeExpiredData {
			in records : PersonalDataRecord[*];
			out purgedCount : Integer;
		}
	}
	
	part def AnonymizationEngine {
		action def AnonymizeData {
			in identifiableData : PersonalDataRecord;
			out anonymizedData : PersonalDataRecord;
		}
		
		action def Pseudonymize {
			in data : PersonalDataRecord;
			out pseudonymizedData : PersonalDataRecord;
		}
		
		action def ValidateAnonymization {
			in data : PersonalDataRecord;
			out reidentificationRisk : Real;
		}
	}
	
	part def DataPrivacySystem {
		part consentMgr : ConsentManager;
		part accessCtrl : AccessControlEngine;
		part encryptionSvc : EncryptionService;
		part dataStore : SecureDataStore;
		part auditLog : AuditLogger;
		part retentionMgr : RetentionManager;
		part anonymizer : AnonymizationEngine;
		
		connection consentToAccess connect 
			consentMgr.consentInterface to accessCtrl.accessInterface;
		
		connection encryptionToStorage connect 
			encryptionSvc.encryptionInterface to dataStore.storageInterface;
		
		connection accessToAudit connect 
			accessCtrl to auditLog.auditInterface;
		
		connection storageToRetention connect 
			dataStore to retentionMgr;
		
		perform action manageDataPrivacy : ManageDataPrivacy;
	}
	
	action def ManageDataPrivacy {
		doc /* Primary function: Protect personal data through consent-based access control,
		       encryption, audit logging, retention management, and anonymization. */
		
		first start;
		then merge mainLoop;
		
		action mainLoop {
			first action receiveAccessRequest {
				out request : AccessRequest;
			}
			
			then action validateConsent : ConsentManager::ValidateConsent {
				in subjectId = receiveAccessRequest.request.targetSubjectId;
				in category = receiveAccessRequest.request.requestedCategory;
				in purpose = receiveAccessRequest.request.requestedPurpose;
				out valid : Boolean;
				out matchingConsent : ConsentRecord;
			}
			
			then decide consentCheck;
				if validateConsent.valid then processAuthorizedRequest;
				if !validateConsent.valid then denyAndLog;
			
			action processAuthorizedRequest {
				first action retrieveData : SecureDataStore::RetrieveData {
					in subjectId = receiveAccessRequest.request.targetSubjectId;
					out records : PersonalDataRecord[*];
				}
				
				then action decryptData : EncryptionService::DecryptData {
					in encryptedData = retrieveData.records->first();
					out plainData : PersonalDataRecord;
				}
				
				then action evaluateAccess : AccessControlEngine::EvaluateAccessRequest {
					in req = receiveAccessRequest.request;
					in cons = validateConsent.matchingConsent;
					out decision : AccessDecision;
				}
				
				then action logAccessEvent : AuditLogger::LogEvent {
					out logged : Boolean;
				}
			}
			then merge checkRetention;
			
			action denyAndLog {
				action logDenial : AuditLogger::LogEvent {
					out logged : Boolean;
				}
			}
			then merge checkRetention;
			
			action checkRetention {
				action identifyExpired : RetentionManager::IdentifyExpiredData {
					out expiredRecords : PersonalDataRecord[*];
				}
				
				then decide retentionAction;
					if identifyExpired.expiredRecords->size() > 0 then purgeData;
					else checkAnonymization;
				
				action purgeData : RetentionManager::PurgeExpiredData {
					in records = identifyExpired.expiredRecords;
					out purgedCount : Integer;
				}
				then merge checkAnonymization;
			}
			
			action checkAnonymization {
				action anonymize : AnonymizationEngine::AnonymizeData {
					out anonymizedData : PersonalDataRecord;
				}
			}
			then mainLoop;
		}
	}
	
	state def PrivacyLifecycle {
		entry; then idle;
		
		state idle {
			accept ConsentReceived;
			then validating;
		}
		
		state validating {
			do action validateRequest;
			accept ValidationComplete;
			then deciding;
		}
		
		state deciding;
		transition deciding to authorized if consentValid;
		transition deciding to denied if !consentValid;
		
		state authorized {
			entry; do action encryptAndStore;
			accept DataStored;
			then monitoring;
		}
		
		state denied {
			entry; do action logDenial;
			then idle;
		}
		
		state monitoring {
			do action checkRetentionPolicies;
			accept RetentionCheckComplete;
			then deciding retentionDecision;
		}
		
		state retentionDecision;
		transition retentionDecision to archiving if shouldArchive;
		transition retentionDecision to purging if shouldPurge;
		transition retentionDecision to idle if noAction;
		
		state archiving {
			do action archiveData;
			then idle;
		}
		
		state purging {
			do action purgeData;
			then idle;
		}
	}
	
	requirement def DataPrivacyRequirement {
		doc /* Requirements for protecting personal data and ensuring privacy compliance. */
		subject system : DataPrivacySystem;
	}
	
	requirement <'PRIV-001'> consentBasedAccess : DataPrivacyRequirement {
		doc /* All access to personal data shall require valid, unexpired consent from the data subject. */
	}
	
	requirement <'PRIV-002'> encryptionAtRest : DataPrivacyRequirement {
		doc /* All personal data at rest shall be encrypted using AES-256 or stronger encryption. */
	}
	
	requirement <'PRIV-003'> comprehensiveAuditing : DataPrivacyRequirement {
		doc /* All access attempts, whether successful or denied, shall be logged with complete audit trails. */
	}
	
	requirement <'PRIV-004'> dataRetention : DataPrivacyRequirement {
		doc /* Personal data shall not be retained beyond the period necessary for its stated purpose. */
	}
	
	requirement <'PRIV-005'> rightToErasure : DataPrivacyRequirement {
		doc /* Data subjects shall have the right to request complete deletion of their personal data. */
	}
	
	requirement <'PRIV-006'> minimumDataCollection : DataPrivacyRequirement {
		doc /* Only the minimum necessary personal data shall be collected for the specified purpose. */
	}
	
	requirement <'PRIV-007'> anonymizationCapability : DataPrivacyRequirement {
		doc /* The system shall support anonymization and pseudonymization of personal data. */
	}
	
	requirement dataPrivacyMission {
		doc /* The data privacy system shall protect personal information through consent management,
		       strong encryption, comprehensive audit logging, automated retention enforcement, and
		       data anonymization capabilities to ensure compliance with privacy regulations. */
		
		assume constraint userConsentInformed {
			doc /* Users must provide informed, explicit consent before personal data processing. */
		}
		
		require consentBasedAccess;
		require encryptionAtRest;
		require comprehensiveAuditing;
		require dataRetention;
		require rightToErasure;
		require minimumDataCollection;
		require anonymizationCapability;
	}
	
	part dataPrivacySystem : DataPrivacySystem;
}
