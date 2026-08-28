package DataSecuritySystem {
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		private import ScalarValues::*;

		item def RawData {
			attribute classification : Integer;
			attribute content : String;
		}

		item def ThreatReport {
			attribute isThreat : Boolean;
			attribute severity : Integer;
			attribute threatType : String;
		}

		item def AccessRequest {
			attribute userId : String;
			attribute clearance : Integer;
			attribute dataClassification : Integer;
		}

		item def AccessDecision {
			attribute granted : Boolean;
			attribute userId : String;
		}

		item def SecuredData {
			attribute ciphertext : String;
			attribute algorithm : String;
			attribute hashValue : String;
		}

		item def AuditRecord {
			attribute eventType : String;
			attribute description : String;
		}

		port def RawDataPort {
			in rawData : RawData;
		}

		port def ThreatReportPort {
			out threatReport : ThreatReport;
		}

		port def AccessRequestPort {
			in accessRequest : AccessRequest;
		}

		port def AccessDecisionPort {
			out accessDecision : AccessDecision;
		}

		port def SecuredDataPort {
			out securedData : SecuredData;
		}

		port def AuditPort {
			out auditRecord : AuditRecord;
		}

		part def ThreatAnalysisEngine {
			port rawDataPort : RawDataPort;
			port threatReportPort : ThreatReportPort;
			port auditPort : AuditPort;
			exhibit state threatAnalysisBehavior {
				entry; then scanning;
				state scanning;
				transition threatDetected
					first scanning
					accept data : RawData via rawDataPort
					if data.content == "malicious"
					do send new ThreatReport(true, 5, "malware") via threatReportPort
					then scanning;
				transition cleanData
					first scanning
					accept data : RawData via rawDataPort
					if data.content != "malicious"
					do send new ThreatReport(false, 0, "none") via threatReportPort
					then scanning;
			}
		}

		part def AccessControlManager {
			port accessRequestPort : AccessRequestPort;
			port accessDecisionPort : AccessDecisionPort;
			port auditPort : AuditPort;
			exhibit state accessControlBehavior {
				entry; then waiting;
				state waiting;
				transition grantAccess
					first waiting
					accept req : AccessRequest via accessRequestPort
					if req.clearance >= req.dataClassification
					do send new AccessDecision(true, req.userId) via accessDecisionPort
					then waiting;
				transition denyAccess
					first waiting
					accept req : AccessRequest via accessRequestPort
					if req.clearance < req.dataClassification
					do send new AccessDecision(false, req.userId) via accessDecisionPort
					then waiting;
			}
		}

		part def CryptographicProcessor {
			port threatReportPort : ~ThreatReportPort;
			port accessDecisionPort : ~AccessDecisionPort;
			port securedDataPort : SecuredDataPort;
			port auditPort : AuditPort;
			exhibit state cryptoBehavior {
				entry; then waitForThreatReport;
				state waitForThreatReport;
				transition threatBlocked
					first waitForThreatReport
					accept report : ThreatReport via threatReportPort
					if report.isThreat == true
					do send new AuditRecord("threatBlocked", "threat detected, processing halted") via auditPort
					then waitForThreatReport;
				transition threatCleared
					first waitForThreatReport
					accept report : ThreatReport via threatReportPort
					if report.isThreat == false
					then waitForAccessDecision;
				state waitForAccessDecision;
				transition accessDenied
					first waitForAccessDecision
					accept decision : AccessDecision via accessDecisionPort
					if decision.granted == false
					do send new AuditRecord("accessDenied", "access denied, processing halted") via auditPort
					then waitForThreatReport;
				transition accessGranted
					first waitForAccessDecision
					accept decision : AccessDecision via accessDecisionPort
					if decision.granted == true
					do send new AuditRecord("encryptionSuccess", "data encrypted successfully") via auditPort
					then encrypting;
				state encrypting;
				transition outputSecuredData
					first encrypting
					do send new SecuredData("encrypted_content", "AES-256", "a1b2c3d4e5f6") via securedDataPort
					then waitForThreatReport;
			}
		}

		part def AuditingSubsystem {
			port auditPort : ~AuditPort;
			exhibit state auditingBehavior {
				entry; then listening;
				state listening;
				transition recordEvent
					first listening
					accept record : AuditRecord via auditPort
					then listening;
			}
		}

		part def DataSecuritySystem {
			port rawDataPort : RawDataPort;
			port accessRequestPort : AccessRequestPort;
			port securedDataPort : SecuredDataPort;
		}

		requirement def SecurityProcessingRequirement {
			doc "The system shall process raw data through threat analysis, access control, and encryption before releasing secured data.";
		}

		requirement def ThreatDetectionRequirement {
			doc "The threat engine shall inspect incoming data, flag malicious content with severity and type, and halt further processing.";
		}

		requirement def AccessControlRequirement {
			doc "The access manager shall authenticate user identity and enforce clearance-level policies for data classification.";
		}

		requirement def EncryptionRequirement {
			doc "The crypto processor shall encrypt authorized data using a specified algorithm and generate an integrity hash.";
		}

		requirement def AuditingRequirement {
			doc "The audit subsystem shall record every significant security event including threats, access denials, and successful encryptions.";
		}
	}

	package Usages {
		private import Definitions::*;

		requirement securityProcessingReq : SecurityProcessingRequirement;
		requirement threatDetectionReq : ThreatDetectionRequirement;
		requirement accessControlReq : AccessControlRequirement;
		requirement encryptionReq : EncryptionRequirement;
		requirement auditingReq : AuditingRequirement;

		part securitySystem : DataSecuritySystem {
			port rawDataPort : RawDataPort;
			port accessRequestPort : AccessRequestPort;
			port securedDataPort : SecuredDataPort;

			part threatAnalysisEngine : ThreatAnalysisEngine {
				port rawDataPort : RawDataPort;
				port threatReportPort : ThreatReportPort;
				port auditPort : AuditPort;
			}

			part accessControlManager : AccessControlManager {
				port accessRequestPort : AccessRequestPort;
				port accessDecisionPort : AccessDecisionPort;
				port auditPort : AuditPort;
			}

			part cryptographicProcessor : CryptographicProcessor {
				port threatReportPort : ~ThreatReportPort;
				port accessDecisionPort : ~AccessDecisionPort;
				port securedDataPort : SecuredDataPort;
				port auditPort : AuditPort;
			}

			part auditingSubsystem : AuditingSubsystem {
				port auditPort : ~AuditPort;
			}

			bind rawDataPort = threatAnalysisEngine.rawDataPort;
			bind accessRequestPort = accessControlManager.accessRequestPort;
			bind securedDataPort = cryptographicProcessor.securedDataPort;

			connect threatAnalysisEngine.threatReportPort to cryptographicProcessor.threatReportPort;
			connect accessControlManager.accessDecisionPort to cryptographicProcessor.accessDecisionPort;
			connect threatAnalysisEngine.auditPort to auditingSubsystem.auditPort;
			connect accessControlManager.auditPort to auditingSubsystem.auditPort;
			connect cryptographicProcessor.auditPort to auditingSubsystem.auditPort;

			flow rawDataFlow of RawData
				from rawDataPort.rawData to threatAnalysisEngine.rawDataPort.rawData;
			flow accessRequestFlow of AccessRequest
				from accessRequestPort.accessRequest to accessControlManager.accessRequestPort.accessRequest;
			flow threatReportFlow of ThreatReport
				from threatAnalysisEngine.threatReportPort.threatReport to cryptographicProcessor.threatReportPort.threatReport;
			flow accessDecisionFlow of AccessDecision
				from accessControlManager.accessDecisionPort.accessDecision to cryptographicProcessor.accessDecisionPort.accessDecision;
			flow securedDataFlow of SecuredData
				from cryptographicProcessor.securedDataPort.securedData to securedDataPort.securedData;
			flow threatAuditFlow of AuditRecord
				from threatAnalysisEngine.auditPort.auditRecord to auditingSubsystem.auditPort.auditRecord;
			flow accessAuditFlow of AuditRecord
				from accessControlManager.auditPort.auditRecord to auditingSubsystem.auditPort.auditRecord;
			flow cryptoAuditFlow of AuditRecord
				from cryptographicProcessor.auditPort.auditRecord to auditingSubsystem.auditPort.auditRecord;

			satisfy securityProcessingReq by securitySystem;
			satisfy threatDetectionReq by threatAnalysisEngine;
			satisfy accessControlReq by accessControlManager;
			satisfy encryptionReq by cryptographicProcessor;
			satisfy auditingReq by auditingSubsystem;
		}
	}
}
