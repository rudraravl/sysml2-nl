package ZDNet {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def TrustScore :> Real;
    attribute def ThreatLevel :> Integer;
    attribute def PacketSize :> Real;
    attribute def SessionId :> String;
    attribute def CredentialToken :> String;
    attribute def RuleId :> String;

    item def AccessRequest {
        attribute requestId : String;
        attribute sourceIp : String;
        attribute destIp : String;
        attribute requestedService : String;
        attribute timestamp : String;
    }
    item def NetworkPacket {
        attribute packetId : String;
        attribute payload : String;
        attribute size : PacketSize;
        attribute sourceIp : String;
        attribute destIp : String;
    }
    item def Credential {
        attribute username : String;
        attribute token : CredentialToken;
        attribute mfaCode : String;
    }
    item def ThreatIntelligenceRecord {
        attribute signatureId : String;
        attribute description : String;
        attribute severity : ThreatLevel;
    }
    item def PolicyRule {
        attribute ruleId : RuleId;
        attribute minTrustScore : TrustScore;
        attribute maxThreatLevel : ThreatLevel;
        attribute allowedServices : String;
    }
    item def AccessDecision {
        attribute decision : DecisionKind;
        attribute grantedPrivilege : String;
        attribute reason : String;
    }
    enum def DecisionKind {
        enum grant;
        enum deny;
        enum challenge;
    }
    item def AuditLogEntry {
        attribute requestId : String;
        attribute timestamp : String;
        attribute decision : DecisionKind;
        attribute trustScore : TrustScore;
        attribute threatLevel : ThreatLevel;
        attribute details : String;
    }
    item def VerifiedIdentity {
        attribute userId : String;
        attribute sessionId : SessionId;
        attribute valid : Boolean;
    }
    item def ThreatReport {
        attribute packetId : String;
        attribute threatDetected : Boolean;
        attribute detectedSignature : String;
        attribute threatLevel : ThreatLevel;
    }

    port def CredentialPort {
        in credential : Credential;
        out verifiedIdentity : VerifiedIdentity;
    }
    port def PacketInspectionPort {
        in packet : NetworkPacket;
        out threatReport : ThreatReport;
    }
    port def PolicyEvaluationPort {
        in identity : VerifiedIdentity;
        in threatReport : ThreatReport;
        in request : AccessRequest;
        out policyDecision : AccessDecision;
    }
    port def ZonePolicyPort {
        in sourceZone : String;
        in destZone : String;
        out allowed : Boolean;
    }
    port def AuditPort {
        in logEntry : AuditLogEntry;
    }

    part def SecurityZone {
        attribute zoneName : String;
        attribute trustLevel : TrustScore;
        port zonePolicyPort : ZonePolicyPort;
    }
    part def InternalZone :> SecurityZone {
        attribute :>> zoneName = "Internal";
        attribute :>> trustLevel = 75.0;
    }
    part def ExternalZone :> SecurityZone {
        attribute :>> zoneName = "External";
        attribute :>> trustLevel = 0.0;
    }
    part def DMZZone :> SecurityZone {
        attribute :>> zoneName = "DMZ";
        attribute :>> trustLevel = 25.0;
    }
    part def QuarantineZone :> SecurityZone {
        attribute :>> zoneName = "Quarantine";
        attribute :>> trustLevel = 0.0;
    }

    part def MicroSegmentationController {
        attribute enforcedRules : PolicyRule[*];
        port zonePolicyPort : ZonePolicyPort;
        action enforceZonePolicy {
            in sourceZone : String;
            in destZone : String;
            out allowed : Boolean;
        }
    }

    part def IdentityVerifier {
        port credentialPort : CredentialPort;
        attribute activeSessions : VerifiedIdentity[*];
        action verifyIdentity {
            in cred : Credential;
            out identity : VerifiedIdentity;
        }
    }

    part def ThreatIntelligenceDB {
        attribute records : ThreatIntelligenceRecord[*];
        action querySignature {
            in signatureId : String;
            out record : ThreatIntelligenceRecord;
        }
    }

    part def ThreatAnalyzer {
        port packetInspectionPort : PacketInspectionPort;
        part threatIntelDB : ThreatIntelligenceDB;
        action analyzePacket {
            in pkt : NetworkPacket;
            out report : ThreatReport;
        }
    }

    part def PolicyEngine {
        attribute policyRules : PolicyRule[*];
        port policyEvaluationPort : PolicyEvaluationPort;
        action calculateTrustScore {
            in identity : VerifiedIdentity;
            in request : AccessRequest;
            out score : TrustScore;
        }
        action evaluateRequest {
            in identity : VerifiedIdentity;
            in threatReport : ThreatReport;
            in request : AccessRequest;
            out decision : AccessDecision;
        }
    }

    part def AccessController {
        port credentialPort : CredentialPort;
        port packetInspectionPort : PacketInspectionPort;
        port policyEvaluationPort : PolicyEvaluationPort;
        port auditPort : AuditPort;
        attribute activeGrants : AccessDecision[*];
        action grantAccess {
            in request : AccessRequest;
            in decision : AccessDecision;
        }
        action revokeAccess {
            in requestId : String;
        }
    }

    part def AuditLogger {
        port auditPort : AuditPort;
        attribute logEntries : AuditLogEntry[*];
        action recordLog {
            in logRecord : AuditLogEntry;
        }
    }

    state def VerificationProcess {
        attribute identityValid : Boolean;
        attribute threatDetected : Boolean;
        attribute threatLevelHigh : Boolean;
        attribute decisionGrant : Boolean;
        attribute decisionDeny : Boolean;
        attribute decisionChallenge : Boolean;

        state authenticating;
        state scanningTraffic;
        state consultingPolicy;
        state grantingAccess;
        state denyingAccess;
        state challengingUser;
        state loggingResult;

        transition initial to authenticating;
        transition from authenticating to scanningTraffic when identityValid;
        transition from authenticating to denyingAccess when not identityValid;
        transition from scanningTraffic to consultingPolicy when not threatDetected;
        transition from scanningTraffic to denyingAccess when threatDetected and threatLevelHigh;
        transition from scanningTraffic to challengingUser when threatDetected and not threatLevelHigh;
        transition from consultingPolicy to grantingAccess when decisionGrant;
        transition from consultingPolicy to denyingAccess when decisionDeny;
        transition from consultingPolicy to challengingUser when decisionChallenge;
        transition from challengingUser to authenticating;
        transition from grantingAccess to loggingResult;
        transition from denyingAccess to loggingResult;
        transition from loggingResult then done;
    }

    part def ZDNetSystem {
        part internalZone : InternalZone;
        part externalZone : ExternalZone;
        part dmzZone : DMZZone;
        part quarantineZone : QuarantineZone;

        part microSegmentationController : MicroSegmentationController;

        part identityVerifier : IdentityVerifier;
        part threatAnalyzer : ThreatAnalyzer {
            part :>> threatIntelDB : ThreatIntelligenceDB;
        }
        part policyEngine : PolicyEngine;
        part accessController : AccessController;
        part auditLogger : AuditLogger;

        connect accessController.credentialPort to identityVerifier.credentialPort;
        connect accessController.packetInspectionPort to threatAnalyzer.packetInspectionPort;
        connect accessController.policyEvaluationPort to policyEngine.policyEvaluationPort;

        connect internalZone.zonePolicyPort to microSegmentationController.zonePolicyPort;
        connect externalZone.zonePolicyPort to microSegmentationController.zonePolicyPort;
        connect dmzZone.zonePolicyPort to microSegmentationController.zonePolicyPort;
        connect quarantineZone.zonePolicyPort to microSegmentationController.zonePolicyPort;

        connect accessController.auditPort to auditLogger.auditPort;

        behavior verificationBehavior : VerificationProcess;
    }

    part zdNet : ZDNetSystem;

    requirement def VerifyEveryRequest {
        doc /* Every access request must be verified before granting access */
        subject zdNet : ZDNetSystem;
        predicate {
            zdNet.accessController.policyEvaluationPort.policyDecision.decision != DecisionKind::grant
            implies zdNet.identityVerifier.credentialPort.verifiedIdentity.valid;
        }
    }
    requirement def LeastPrivilegeAccess {
        doc /* Access shall be granted with the least privilege necessary */
        subject zdNet : ZDNetSystem;
        predicate {
            zdNet.policyEngine.policyEvaluationPort.policyDecision.grantedPrivilege != "";
        }
    }
    requirement def ThreatDetection {
        doc /* All network packets shall be inspected for malicious signatures */
        subject zdNet : ZDNetSystem;
        predicate {
            zdNet.threatAnalyzer.packetInspectionPort.threatReport.packetId != "";
        }
    }
    requirement def ZoneIsolation {
        doc /* Communication between zones shall be enforced by micro-segmentation */
        subject zdNet : ZDNetSystem;
        predicate {
            zdNet.microSegmentationController.zonePolicyPort.allowed == false
            implies true;
        }
    }
    requirement def AuditLogging {
        doc /* All access decisions shall be logged for auditing */
        subject zdNet : ZDNetSystem;
        predicate {
            zdNet.auditLogger.auditPort.logEntry.requestId != "";
        }
    }
    requirement def QuarantineSuspiciousActivity {
        doc /* Suspicious activity shall be redirected to the quarantine zone */
        subject zdNet : ZDNetSystem;
        predicate {
            zdNet.threatAnalyzer.packetInspectionPort.threatReport.threatDetected == true
            implies zdNet.quarantineZone.zoneName == "Quarantine";
        }
    }

    requirement zDNetRequirements {
        requirement req1 : VerifyEveryRequest;
        requirement req2 : LeastPrivilegeAccess;
        requirement req3 : ThreatDetection;
        requirement req4 : ZoneIsolation;
        requirement req5 : AuditLogging;
        requirement req6 : QuarantineSuspiciousActivity;
    }

    action def ZDNetVerificationSequence {
        in request : AccessRequest;
        in credential : Credential;
        in packet : NetworkPacket;
        out decision : AccessDecision;
        out logEntry : AuditLogEntry;

        action authenticate {
            in cred : Credential;
            out identity : VerifiedIdentity;
        }
        action scan {
            in pkt : NetworkPacket;
            out report : ThreatReport;
        }
        action evaluate {
            in identity : VerifiedIdentity;
            in threatReport : ThreatReport;
            in request : AccessRequest;
            out policyDecision : AccessDecision;
        }
    }
}
