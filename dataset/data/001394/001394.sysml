package 'Data Security System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def EncryptionKey {
        attribute keyLength : Integer;
        attribute algorithm : String;
        attribute expirationTime : ISQ::TimeValue;
    }
    
    attribute def SecurityClassification {
        attribute level : Integer;
        attribute category : String;
    }
    
    attribute def ThreatIndicator {
        attribute severity : Integer;
        attribute threatType : String;
        attribute confidence : Real;
    }
    
    attribute def UserIdentity {
        attribute userId : String;
        attribute role : String;
        attribute clearanceLevel : Integer;
    }
    
    item def DataPayload {
        attribute content : String;
        attribute size : Real;
        attribute classification : SecurityClassification;
        attribute timestamp : ISQ::TimeValue;
        attribute isEncrypted : Boolean;
    }
    
    item def EncryptedData {
        attribute ciphertext : String;
        attribute encryptionMetadata : EncryptionKey;
        attribute integrityHash : String;
    }
    
    item def AuditRecord {
        attribute eventType : String;
        attribute timestamp : ISQ::TimeValue;
        attribute userId : String;
        attribute outcome : String;
        attribute details : String;
    }
    
    port def DataInputPort {
        in item incomingData : DataPayload;
    }
    
    port def DataOutputPort {
        out item securedData : EncryptedData;
    }
    
    port def ThreatMonitorPort {
        out attribute threatDetected : Boolean;
        out attribute threatInfo : ThreatIndicator;
    }
    
    port def AuditPort {
        out item auditLog : AuditRecord;
    }
    
    port def PolicyPort {
        in attribute securityPolicy : SecurityClassification;
        in attribute encryptionPolicy : EncryptionKey;
    }
    
    part def ThreatAnalysisEngine {
        port monitoringPort : ThreatMonitorPort;
        
        attribute threatDatabase : ThreatIndicator[*];
        attribute scanInterval : ISQ::TimeValue;
        
        action def ScanForThreats {
            in data : DataPayload;
            out threatFound : Boolean;
            out threat : ThreatIndicator;
        }
        
        action analyzeThreat {
            in inputData : DataPayload;
            out isThreat : Boolean;
            out threatDetails : ThreatIndicator;
            
            first start;
            then action performScan : ScanForThreats {
                in data = inputData;
                out threatFound;
                out threat;
            }
            then decide;
                if performScan.threatFound then classifyThreat;
                if !performScan.threatFound then markSafe;
            
            action classifyThreat {
                then assign isThreat := true;
                then assign threatDetails := performScan.threat;
            }
            
            action markSafe {
                then assign isThreat := false;
                then assign threatDetails := ThreatIndicator {
                    severity = 0;
                    threatType = "None";
                    confidence = 1.0;
                };
            }
            then done;
        }
    }
    
    part def CryptographicProcessor {
        attribute activeKey : EncryptionKey;
        attribute keyRotationInterval : ISQ::TimeValue;
        
        action def EncryptPayload {
            in plainData : DataPayload;
            in key : EncryptionKey;
            out encrypted : EncryptedData;
        }
        
        action def DecryptPayload {
            in encrypted : EncryptedData;
            in key : EncryptionKey;
            out plainData : DataPayload;
        }
        
        action def GenerateIntegrityHash {
            in data : DataPayload;
            out hash : String;
        }
        
        action performEncryption {
            in rawData : DataPayload;
            in encryptionConfig : EncryptionKey;
            out secureData : EncryptedData;
            
            first start;
            then action validateKey {
                in key = encryptionConfig;
            }
            then action computeHash : GenerateIntegrityHash {
                in data = rawData;
                out hash;
            }
            then action encrypt : EncryptPayload {
                in plainData = rawData;
                in key = encryptionConfig;
                out encrypted;
            }
            then action attachIntegrity {
                then assign secureData := EncryptedData {
                    ciphertext = encrypt.encrypted.ciphertext;
                    encryptionMetadata = encryptionConfig;
                    integrityHash = computeHash.hash;
                };
            }
            then done;
        }
    }
    
    part def AccessControlManager {
        attribute authorizedUsers : UserIdentity[*];
        attribute accessPolicies : SecurityClassification[*];
        
        action def AuthenticateUser {
            in credentials : UserIdentity;
            out isAuthenticated : Boolean;
        }
        
        action def AuthorizeAccess {
            in user : UserIdentity;
            in dataClassification : SecurityClassification;
            out isAuthorized : Boolean;
        }
        
        action enforceAccessControl {
            in userCredentials : UserIdentity;
            in requestedData : DataPayload;
            out accessGranted : Boolean;
            
            first start;
            then action authenticate : AuthenticateUser {
                in credentials = userCredentials;
                out isAuthenticated;
            }
            then decide;
                if authenticate.isAuthenticated then checkAuthorization;
                if !authenticate.isAuthenticated then denyAccess;
            
            action checkAuthorization : AuthorizeAccess {
                in user = userCredentials;
                in dataClassification = requestedData.classification;
                out isAuthorized;
            }
            then decide;
                if checkAuthorization.isAuthorized then grantAccess;
                if !checkAuthorization.isAuthorized then denyAccess;
            
            action grantAccess {
                then assign accessGranted := true;
            }
            
            action denyAccess {
                then assign accessGranted := false;
            }
            then done;
        }
    }
    
    part def AuditingSubsystem {
        attribute logRepository : AuditRecord[*];
        attribute retentionPeriod : ISQ::TimeValue;
        
        action def CreateAuditEntry {
            in eventType : String;
            in timestamp : ISQ::TimeValue;
            in userId : String;
            in outcome : String;
            in details : String;
            out record : AuditRecord;
        }
        
        action logSecurityEvent {
            in event : String;
            in time : ISQ::TimeValue;
            in user : String;
            in result : String;
            in additionalInfo : String;
            
            first start;
            then action createEntry : CreateAuditEntry {
                in eventType = event;
                in timestamp = time;
                in userId = user;
                in outcome = result;
                in details = additionalInfo;
                out record;
            }
            then action storeRecord {
                then assign logRepository := logRepository->including(createEntry.record);
            }
            then done;
        }
    }
    
    part def DataSecuritySystem {
        port dataInput : DataInputPort;
        port dataOutput : DataOutputPort;
        port threatMonitor : ThreatMonitorPort;
        port auditOutput : AuditPort;
        port policyControl : PolicyPort;
        
        part threatEngine : ThreatAnalysisEngine;
        part cryptoProcessor : CryptographicProcessor;
        part accessControl : AccessControlManager;
        part auditSystem : AuditingSubsystem;
    }
    
    part dataSecuritySystem : DataSecuritySystem {
        doc /*
            The Data Security System provides comprehensive protection for sensitive information
            through integrated threat detection, cryptographic processing, access control, and
            audit logging. The system continuously monitors incoming data for security threats,
            applies strong encryption to protect confidentiality and integrity, enforces
            role-based access control policies, and maintains detailed audit trails of all
            security-relevant events to ensure compliance and enable forensic analysis.
        */
        
        perform action secureDataProcessing {
            doc /*
                Primary security function: Continuously process incoming data through a
                multi-layered security pipeline that detects threats, enforces access policies,
                applies cryptographic protection, and logs all security events to ensure
                comprehensive data protection throughout the system lifecycle.
            */
            
            in externalData : DataPayload;
            in userContext : UserIdentity;
            out protectedData : EncryptedData;
            
            first start;
            then merge continuousProcessing;
            
            then action receiveInput {
                in rawData = externalData;
                in user = userContext;
            }
            
            then action threatAnalysis {
                action scanData : threatEngine.analyzeThreat {
                    in inputData = receiveInput.rawData;
                    out isThreat;
                    out threatDetails;
                }
            }
            
            then action accessValidation {
                action validateUser : accessControl.enforceAccessControl {
                    in userCredentials = receiveInput.user;
                    in requestedData = receiveInput.rawData;
                    out accessGranted;
                }
            }
            
            then decide securityDecision;
                if threatAnalysis.scanData.isThreat then handleThreatDetection;
                if !threatAnalysis.scanData.isThreat && 
                   accessValidation.validateUser.accessGranted then proceedWithEncryption;
                if !threatAnalysis.scanData.isThreat && 
                   !accessValidation.validateUser.accessGranted then handleAccessDenial;
            
            action handleThreatDetection {
                action logThreat : auditSystem.logSecurityEvent {
                    in event = "Threat Detected";
                    in time = 0.0[SI::s];
                    in user = receiveInput.user.userId;
                    in result = "Blocked";
                    in additionalInfo = threatAnalysis.scanData.threatDetails.threatType;
                }
                then action blockData;
                then done;
            }
            
            action handleAccessDenial {
                action logDenial : auditSystem.logSecurityEvent {
                    in event = "Access Denied";
                    in time = 0.0[SI::s];
                    in user = receiveInput.user.userId;
                    in result = "Denied";
                    in additionalInfo = "Insufficient clearance level";
                }
                then done;
            }
            
            action proceedWithEncryption {
                action encryptData : cryptoProcessor.performEncryption {
                    in rawData = receiveInput.rawData;
                    in encryptionConfig = EncryptionKey {
                        keyLength = 256;
                        algorithm = "AES-256-GCM";
                        expirationTime = 86400.0[SI::s];
                    };
                    out secureData;
                }
                
                then action logSuccess : auditSystem.logSecurityEvent {
                    in event = "Data Encrypted";
                    in time = 0.0[SI::s];
                    in user = receiveInput.user.userId;
                    in result = "Success";
                    in additionalInfo = "Data successfully encrypted and secured";
                }
                
                then action deliverSecuredData {
                    then assign protectedData := encryptData.secureData;
                }
            }
            
            then continuousProcessing;
        }
    }
    
    requirement def SecurityRequirement {
        doc /* Base requirement for data security system capabilities */
        subject system : DataSecuritySystem;
    }
    
    requirement <'SEC-REQ-001'> dataConfidentiality : SecurityRequirement {
        doc /* 
            The system shall encrypt all sensitive data using approved cryptographic
            algorithms with minimum 256-bit key length to ensure confidentiality.
        */
        
        require constraint {
            dataSecuritySystem.cryptoProcessor.activeKey.keyLength >= 256
        }
    }
    
    requirement <'SEC-REQ-002'> continuousThreatMonitoring : SecurityRequirement {
        doc /*
            The system shall continuously monitor all incoming data for security threats
            and block any data identified as malicious.
        */
    }
    
    requirement <'SEC-REQ-003'> roleBasedAccessControl : SecurityRequirement {
        doc /*
            The system shall enforce role-based access control ensuring users can only
            access data for which they have sufficient clearance level.
        */
    }
    
    requirement <'SEC-REQ-004'> comprehensiveAuditing : SecurityRequirement {
        doc /*
            The system shall log all security-relevant events including threat detections,
            access control decisions, and encryption operations for audit and compliance.
        */
        
        require constraint {
            dataSecuritySystem.auditSystem.logRepository->size() > 0
        }
    }
    
    requirement <'SEC-REQ-005'> dataIntegrity : SecurityRequirement {
        doc /*
            The system shall generate and verify cryptographic integrity hashes for all
            encrypted data to detect unauthorized modifications.
        */
    }
    
    requirement <'SEC-MAIN'> comprehensiveDataProtection {
        doc /*
            The Data Security System shall provide end-to-end protection for sensitive
            information through integrated threat detection, strong encryption, strict
            access control, and comprehensive audit logging to ensure confidentiality,
            integrity, and accountability.
        */
        
        require dataConfidentiality;
        require continuousThreatMonitoring;
        require roleBasedAccessControl;
        require comprehensiveAuditing;
        require dataIntegrity;
    }
}
