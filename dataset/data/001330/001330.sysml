package AccessControlSystem {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;
    private import Time::*;

    attribute def CredentialID;
    attribute def UserName;
    attribute def ZoneIdentifier;
    
    enum def AccessDecision {
        granted;
        denied;
    }
    
    enum def LockState {
        locked;
        unlocked;
    }
    
    attribute def ResponseTimeValue :> ISQ::DurationValue;
    attribute def AccessLevelValue :> ScalarValues::Integer;
    
    item def Credential {
        attribute credentialID : CredentialID;
        attribute userName : UserName;
        attribute accessLevel : AccessLevelValue;
    }
    
    item def AccessAttempt {
        attribute credential : Credential;
        attribute targetZone : ZoneIdentifier;
        attribute timestamp : ISQ::DurationValue;
    }
    
    item def AuthorizationResult {
        attribute decision : AccessDecision;
        attribute credential : Credential;
        attribute zone : ZoneIdentifier;
        attribute timestamp : ISQ::DurationValue;
    }
    
    item def LockControlSignal {
        attribute command : LockState;
        attribute zone : ZoneIdentifier;
    }
    
    item def AuditEntry {
        attribute userName : UserName;
        attribute credentialID : CredentialID;
        attribute zone : ZoneIdentifier;
        attribute decision : AccessDecision;
        attribute timestamp : ISQ::DurationValue;
    }
    
    port def CredentialInputPort {
        in item credentialData : Credential;
    }
    
    port def AuthorizationPort {
        in item accessAttempt : AccessAttempt;
        out item authResult : AuthorizationResult;
    }
    
    port def LockControlPort {
        in item lockSignal : LockControlSignal;
    }
    
    port def AuditLogPort {
        out item auditEntry : AuditEntry;
    }
    
    part def CredentialScanner {
        attribute scannerID : ScalarValues::String;
        port credentialOutput : CredentialInputPort;
        
        event occurrence credentialScanned;
        event occurrence credentialTransmitted;
        
        action def ScanCredential {
            out scannedCredential : Credential;
        }
    }
    
    part def AccessControlProcessor {
        attribute processorID : ScalarValues::String;
        attribute authorizedCredentials : CredentialID[0..*];
        attribute zoneAccessLevels : AccessLevelValue[0..*];
        attribute maxResponseTime : ResponseTimeValue;
        
        port authorizationInterface : AuthorizationPort;
        port auditInterface : AuditLogPort;
        
        event occurrence attemptReceived;
        event occurrence authorizationCompleted;
        event occurrence auditRecordGenerated;
        
        action def ValidateCredential {
            in credential : Credential;
            out isValid : ScalarValues::Boolean;
        }
        
        action def CheckAuthorization {
            in credential : Credential;
            in targetZone : ZoneIdentifier;
            out authorized : ScalarValues::Boolean;
        }
        
        action def CreateAuditEntry {
            in attempt : AccessAttempt;
            in decision : AccessDecision;
            out entry : AuditEntry;
        }
        
        state authorizationStateMachine {
            entry; then idle;
            
            state idle;
            transition idle_to_processing
                first idle
                accept attemptReceived
                then processing;
            
            state processing;
            transition processing_to_checkAccess
                first processing
                then checkAccess;
            
            state checkAccess;
            transition checkAccess_to_grant
                first checkAccess
                then grant;
            transition checkAccess_to_reject
                first checkAccess
                then reject;
            
            state grant;
            transition grant_to_sendGrantResponse
                first grant
                then sendGrantResponse;
            
            state reject;
            transition reject_to_sendRejectResponse
                first reject
                then sendRejectResponse;
            
            state sendGrantResponse;
            transition sendGrantResponse_to_idle
                first sendGrantResponse
                then idle;
            
            state sendRejectResponse;
            transition sendRejectResponse_to_idle
                first sendRejectResponse
                then idle;
        }
    }
    
    part def ElectronicDoorLock {
        attribute lockID : ScalarValues::String;
        attribute currentState : LockState;
        attribute autoLockDelay : ISQ::DurationValue;
        
        port lockControl : LockControlPort;
        
        event occurrence unlockReceived;
        event occurrence lockReceived;
        event occurrence autoLockTriggered;
        
        state doorLockStateMachine {
            entry; then locked;
            
            state locked;
            transition locked_to_unlocking
                first locked
                accept unlockReceived
                then unlocking;
            
            state unlocking;
            transition unlocking_to_unlocked
                first unlocking
                then unlocked;
            
            state unlocked;
            transition unlocked_to_locking_auto
                first unlocked
                accept autoLockTriggered
                then locking;
            transition unlocked_to_locking_manual
                first unlocked
                accept lockReceived
                then locking;
            
            state locking;
            transition locking_to_locked
                first locking
                then locked;
        }
    }
    
    part def SecureAccessZone {
        attribute zoneID : ZoneIdentifier;
        attribute requiredAccessLevel : AccessLevelValue;
        
        part scanner : CredentialScanner;
        part doorLock : ElectronicDoorLock;
    }
    
    part def AuditDatabase {
        attribute databaseID : ScalarValues::String;
        attribute auditRecords : AuditEntry[0..*];
        
        port auditInput : AuditLogPort;
        
        action def StoreAuditRecord {
            in record : AuditEntry;
        }
        
        action def RetrieveAuditRecords {
            in startTime : ISQ::DurationValue;
            in endTime : ISQ::DurationValue;
            out records : AuditEntry[0..*];
        }
    }
    
    part accessControlSystem {
        part processor : AccessControlProcessor;
        
        part auditDB : AuditDatabase;
        
        part entranceZone : SecureAccessZone;
        
        part restrictedZone : SecureAccessZone;
        
        part highSecurityZone : SecureAccessZone;
    }
    
    action def ProcessAccessControl {
        first start;
        then merge awaitCredential;
        
        action awaitCredential;
        then scanCredential;
        
        action scanCredential {
            out credential : Credential;
        }
        then transmitAttempt;
        
        action transmitAttempt {
            in credential = scanCredential.credential;
            out attempt : AccessAttempt;
        }
        then validateCredential;
        
        action validateCredential {
            in credential = transmitAttempt.attempt.credential;
            out isValid : ScalarValues::Boolean;
        }
        then decide;
            if validateCredential.isValid then authorizeAccess;
            if !validateCredential.isValid then denyAccess;
        
        action authorizeAccess {
            in credential = transmitAttempt.attempt.credential;
            in targetZone = transmitAttempt.attempt.targetZone;
            out authorized : ScalarValues::Boolean;
        }
        then decide;
            if authorizeAccess.authorized then grantAccess;
            if !authorizeAccess.authorized then denyAccess;
        
        action grantAccess {
            action unlockDoor;
            action logGrantEvent;
        }
        then awaitCredential;
        
        action denyAccess {
            action logDenyEvent;
        }
        then awaitCredential;
    }
    
    occurrence def AccessControlInteraction {
        ref part ctrl :>> accessControlSystem.processor;
        ref part zone :>> accessControlSystem.entranceZone;
        ref part audit :>> accessControlSystem.auditDB;
        
        message credentialScanned of Credential
            from zone.scanner.credentialScanned to zone.scanner.credentialTransmitted;
        
        then message accessAttemptMessage of AccessAttempt
            from zone.scanner.credentialTransmitted to ctrl.attemptReceived;
        
        then message authorizationResultMessage of AuthorizationResult
            from ctrl.authorizationCompleted to zone.doorLock.unlockReceived;
        
        then message auditLogMessage of AuditEntry
            from ctrl.auditRecordGenerated to audit.auditInput;
    }
    
    requirement <'REQ-ACS-001'> primaryAccessControlFunction {
        doc /* The access control system shall authenticate user credentials 
             * and authorize access to secure zones based on credential validation 
             * and zone-specific access level requirements, controlling electronic 
             * door locks accordingly.
             */
        subject system :> accessControlSystem;
    }
    
    requirement <'REQ-ACS-002'> credentialValidation {
        doc /* The system shall validate presented credentials against a database 
             * of authorized credentials before granting access.
             */
        subject processor :> accessControlSystem.processor;
    }
    
    requirement <'REQ-ACS-003'> zoneAuthorization {
        doc /* The system shall verify that validated credentials have sufficient 
             * access level for the requested secure zone.
             */
        subject processor :> accessControlSystem.processor;
    }
    
    requirement <'REQ-ACS-004'> responseTime {
        doc /* The system shall complete authorization processing and respond 
             * within 1.5 seconds of credential presentation.
             */
        subject processor :> accessControlSystem.processor;
    }
    
    requirement <'REQ-ACS-005'> auditLogging {
        doc /* The system shall log all access attempts including user identity, 
             * zone identifier, timestamp, and authorization decision.
             */
        subject auditDB :> accessControlSystem.auditDB;
    }
    
    requirement <'REQ-ACS-006'> automaticLocking {
        doc /* Electronic door locks shall automatically return to locked state 
             * after a configurable delay period when unlocked.
             */
        subject lock :> accessControlSystem.entranceZone.doorLock;
    }
    
    requirement <'REQ-ACS-007'> multiZoneSupport {
        doc /* The system shall support multiple secure zones with independent 
             * access level requirements.
             */
        subject system :> accessControlSystem;
    }
    
    satisfy primaryAccessControlFunction by accessControlSystem;
    satisfy credentialValidation by accessControlSystem.processor;
    satisfy zoneAuthorization by accessControlSystem.processor;
    satisfy responseTime by accessControlSystem.processor;
    satisfy auditLogging by accessControlSystem.auditDB;
    satisfy automaticLocking by accessControlSystem.entranceZone.doorLock;
    satisfy multiZoneSupport by accessControlSystem;
}
