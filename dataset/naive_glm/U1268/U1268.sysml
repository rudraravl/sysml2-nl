package ZDNet {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Units ----
    unit def byte;
    unit def ms;
    unit def scoreUnit;

    // ---- Enumerations ----
    enum def ZoneType {
        internal;
        external;
        dmz;
        quarantine;
    }

    enum def AccessDecision {
        grant;
        deny;
        challenge;
    }

    enum def ThreatLevel {
        none;
        low;
        medium;
        high;
        critical;
    }

    enum def SessionState {
        unauthenticated;
        authenticated;
        challenged;
        revoked;
    }

    // ---- Value types ----
    value def TrustScore :> Real {
        unit scoreUnit;
        constraint { self >= 0.0 and self <= 1.0 }
    }

    value def ConfidenceLevel :> Real {
        constraint { self >= 0.0 and self <= 1.0 }
    }

    value def PacketSize :> Integer {
        unit byte;
    }

    value def Latency :> Real {
        unit ms;
    }

    value def Timestamp :> Real;

    // ---- Item definitions ----
    item def Credential {
        attribute principalId : String;
        attribute secretHash : String;
        attribute mfaToken : String;
    }

    item def AccessRequest {
        attribute requestId : String;
        attribute userId : String;
        attribute deviceId : String;
        attribute sourceZone : ZoneType;
        attribute targetZone : ZoneType;
        attribute requestedResource : String;
        attribute requestedPrivilege : String;
        attribute timestamp : Timestamp;
        attribute credential : Credential;
    }

    item def NetworkPacket {
        attribute packetId : String;
        attribute sourceIp : String;
        attribute destIp : String;
        attribute payload : String;
        attribute size : PacketSize;
        attribute timestamp : Timestamp;
    }

    item def IdentityVerificationResult {
        attribute requestId : String;
        attribute verified : Boolean;
        attribute sessionValid : Boolean;
        attribute trustScore : TrustScore;
        attribute state : SessionState;
    }

    item def ThreatAnalysisResult {
        attribute requestId : String;
        attribute threatLevel : ThreatLevel;
        attribute maliciousSignatureDetected : Boolean;
        attribute anomalyDetected : Boolean;
        attribute confidence : ConfidenceLevel;
        attribute matchedSignature : String;
    }

    item def PolicyDecision {
        attribute requestId : String;
        attribute decision : AccessDecision;
        attribute leastPrivilegeScope : String;
        attribute justification : String;
        attribute trustScore : TrustScore;
        attribute threatLevel : ThreatLevel;
    }

    item def AuditLogEntry {
        attribute entryId : String;
        attribute requestId : String;
        attribute timestamp : Timestamp;
        attribute decision : AccessDecision;
        attribute details : String;
    }

    // ---- Port definitions ----
    port def RequestInPort {
        in accessRequest : AccessRequest;
    }

    port def RequestOutPort {
        out accessRequest : AccessRequest;
    }

    port def PacketInPort {
        in packet : NetworkPacket;
    }

    port def IdentityResultOutPort {
        out result : IdentityVerificationResult;
    }

    port def IdentityResultInPort {
        in result : IdentityVerificationResult;
    }

    port def ThreatResultOutPort {
        out result : ThreatAnalysisResult;
    }

    port def ThreatResultInPort {
        in result : ThreatAnalysisResult;
    }

    port def DecisionOutPort {
        out decision : PolicyDecision;
    }

    port def DecisionInPort {
        in decision : PolicyDecision;
    }

    port def AuditOutPort {
        out logEntry : AuditLogEntry;
    }

    port def AuditInPort {
        in logEntry : AuditLogEntry;
    }

    port def ZoneControlPort {
        in accessRequest : AccessRequest;
        out forwarded : AccessRequest;
    }

    // ---- Requirements ----
    requirement def NeverTrustAlwaysVerify {
        doc { Every access request must be treated as a potential threat until proven otherwise. }
        subject system : ZDNetSystem;
        objective { All requests are verified before access is granted. }
    }

    requirement def ZoneIsolationRequirement {
        doc { The network must be divided into distinct security zones with enforced boundaries. }
        subject controller : MicroSegmentationController;
        attribute requiredZoneCount : Integer = 4;
        constraint { requiredZoneCount >= 4 }
    }

    requirement def ContinuousVerificationRequirement {
        doc { Verification must be continuous and multi-step, including identity, threat, and policy evaluation. }
        subject verifier : IdentityVerifier;
    }

    requirement def LeastPrivilegeRequirement {
        doc { Granted access must use the least privilege necessary. }
        subject accessController : AccessController;
    }

    requirement def AuditLoggingRequirement {
        doc { All access decisions must be logged for auditing and security analysis. }
        subject logger : AuditLogger;
    }

    requirement def ThreatDetectionRequirement {
        doc { All network packets must be inspected for malicious signatures and anomalous behavior. }
        subject analyzer : ThreatAnalyzer;
    }

    // ---- Security Zones ----
    part def SecurityZone {
        attribute zoneType : ZoneType;
        attribute isolationLevel : Real;
        attribute description : String;
        port requestIn : RequestInPort;
        port requestOut : RequestOutPort;
        port controlPort : ZoneControlPort;
    }

    part def InternalZone :> SecurityZone {
        redefines zoneType = ZoneType::internal;
        redefines isolationLevel = 0.2;
        redefines description = "Trusted internal zone";
    }

    part def ExternalZone :> SecurityZone {
        redefines zoneType = ZoneType::external;
        redefines isolationLevel = 1.0;
        redefines description = "Untrusted external zone (internet)";
    }

    part def DMZZone :> SecurityZone {
        redefines zoneType = ZoneType::dmz;
        redefines isolationLevel = 0.7;
        redefines description = "Demilitarized zone for public-facing servers";
    }

    part def QuarantineZone :> SecurityZone {
        redefines zoneType = ZoneType::quarantine;
        redefines isolationLevel = 1.0;
        redefines description = "Fully isolated quarantine zone for suspicious activity";
    }

    // ---- Threat Intelligence Database ----
    part def ThreatIntelligenceDB {
        attribute signatureCount : Integer;
        attribute lastUpdated : Timestamp;
        attribute signatures : String[*];

        action lookupSignature(in signature : String) : Boolean;
        action recordThreat(in threat : String);
        action updateDatabase(in newSignatures : String[*]);
    }

    // ---- Identity Verifier ----
    part def IdentityVerifier {
        port requestIn : RequestInPort;
        port resultOut : IdentityResultOutPort;
        attribute activeSessions : Integer;
        attribute maxSessions : Integer = 10000;

        action authenticate(in cred : Credential, in req : AccessRequest) : IdentityVerificationResult;
        action computeTrustScore(in req : AccessRequest, in credValid : Boolean) : TrustScore;
        action validateSession(in userId : String) : Boolean;

        state verificationBehavior {
            entry { /* log verification start */ }
            state idle;
            state authenticating;
            state computingTrust;
            state validatingSession;
            state emittingResult;

            transition idle -> authenticating on requestIn.accessRequest;
            transition authenticating -> validatingSession;
            transition validatingSession -> computingTrust;
            transition computingTrust -> emittingResult;
            transition emittingResult -> idle;
        }
    }

    // ---- Threat Analyzer ----
    part def ThreatAnalyzer {
        port packetIn : PacketInPort;
        port requestIn : RequestInPort;
        port resultOut : ThreatResultOutPort;
        ref threatDB : ThreatIntelligenceDB;
        attribute anomalyThreshold : Real = 0.8;

        action inspectPacket(in pkt : NetworkPacket) : ThreatAnalysisResult;
        action detectAnomaly(in pkt : NetworkPacket) : Boolean;
        action queryThreatDB(in signature : String) : Boolean;

        state scanningBehavior {
            state idle;
            state inspecting;
            state analyzing;
            state queryingDB;
            state reporting;

            transition idle -> inspecting on packetIn.packet;
            transition inspecting -> queryingDB;
            transition queryingDB -> analyzing;
            transition analyzing -> reporting;
            transition reporting -> idle;
        }
    }

    // ---- Policy Engine ----
    part def PolicyEngine {
        port identityIn : IdentityResultInPort;
        port threatIn : ThreatResultInPort;
        port requestIn : RequestInPort;
        port decisionOut : DecisionOutPort;

        attribute rules : String[*];
        attribute minTrustForGrant : TrustScore = 0.7;
        attribute maxThreatForGrant : ThreatLevel = ThreatLevel::low;

        action evaluate(in identity : IdentityVerificationResult, in threat : ThreatAnalysisResult, in req : AccessRequest) : PolicyDecision;
        action applyRules(in req : AccessRequest, in trust : TrustScore, in threat : ThreatLevel) : AccessDecision;
        action computeLeastPrivilege(in req : AccessRequest) : String;

        state evaluationBehavior {
            state idle;
            state gatheringIdentity;
            state gatheringThreat;
            state evaluating;
            state deciding;
            state emitting;

            transition idle -> gatheringIdentity on requestIn.accessRequest;
            transition gatheringIdentity -> gatheringThreat on identityIn.result;
            transition gatheringThreat -> evaluating on threatIn.result;
            transition evaluating -> deciding;
            transition deciding -> emitting;
            transition emitting -> idle;
        }
    }

    // ---- Access Controller ----
    part def AccessController {
        port decisionIn : DecisionInPort;
        port requestIn : RequestInPort;
        port auditOut : AuditOutPort;
        port accessOut : RequestOutPort;

        attribute activeGrants : Integer;
        attribute revokedSessions : Integer;

        action grantAccess(in req : AccessRequest, in decision : PolicyDecision);
        action revokeAccess(in req : AccessRequest);
        action issueChallenge(in req : AccessRequest);
        action logDecision(in req : AccessRequest, in decision : PolicyDecision);

        state gatekeeperBehavior {
            state idle;
            state awaitingDecision;
            state granting;
            state denying;
            state challenging;
            state logging;
            state forwarding;

            transition idle -> awaitingDecision on requestIn.accessRequest;
            transition awaitingDecision -> granting if decisionIn.decision.decision == AccessDecision::grant;
            transition awaitingDecision -> denying if decisionIn.decision.decision == AccessDecision::deny;
            transition awaitingDecision -> challenging if decisionIn.decision.decision == AccessDecision::challenge;
            transition granting -> logging;
            transition denying -> logging;
            transition challenging -> logging;
            transition logging -> forwarding;
            transition forwarding -> idle;
        }
    }

    // ---- Audit Logger ----
    part def AuditLogger {
        port auditIn : AuditInPort;
        attribute logEntries : AuditLogEntry[*];
        attribute maxEntries : Integer = 1000000;

        action recordEntry(in entry : AuditLogEntry);
        action queryLogs(in requestId : String) : AuditLogEntry[*];

        state loggingBehavior {
            state idle;
            state recording;
            transition idle -> recording on auditIn.logEntry;
            transition recording -> idle;
        }
    }

    // ---- Micro-Segmentation Controller ----
    part def MicroSegmentationController {
        attribute enforcedRules : String[*];
        ref zones : SecurityZone[4];
        attribute quarantineActive : Boolean = false;

        port requestIn : RequestInPort;
        port requestOut : RequestOutPort;

        action enforceRules(in req : AccessRequest) : Boolean;
        action updateRules(in rule : String);
        action isolateZone(in zone : ZoneType);
        action routeToQuarantine(in req : AccessRequest);

        state enforcementBehavior {
            state idle;
            state evaluating;
            state enforcing;
            state isolating;
            state forwarding;

            transition idle -> evaluating on requestIn.accessRequest;
            transition evaluating -> enforcing;
            transition enforcing -> forwarding if quarantineActive == false;
            transition enforcing -> isolating if quarantineActive == true;
            transition isolating -> idle;
            transition forwarding -> idle;
        }
    }

    // ---- Top-level ZDNet System ----
    part def ZDNetSystem {
        requirement r1 : NeverTrustAlwaysVerify;
        requirement r2 : ZoneIsolationRequirement;
        requirement r3 : ContinuousVerificationRequirement;
        requirement r4 : LeastPrivilegeRequirement;
        requirement r5 : AuditLoggingRequirement;
        requirement r6 : ThreatDetectionRequirement;

        satisfy r1 by self;
        satisfy r2 by microSegController;
        satisfy r3 by identityVerifier;
        satisfy r4 by accessController;
        satisfy r5 by auditLogger;
        satisfy r6 by threatAnalyzer;

        part internalZone : InternalZone;
        part externalZone : ExternalZone;
        part dmzZone : DMZZone;
        part quarantineZone : QuarantineZone;

        part microSegController : MicroSegmentationController {
            redefines zones = (internalZone, externalZone, dmzZone, quarantineZone);
        }

        part identityVerifier : IdentityVerifier;
        part threatAnalyzer : ThreatAnalyzer {
            part threatDB : ThreatIntelligenceDB;
        }
        part policyEngine : PolicyEngine;
        part accessController : AccessController;
        part auditLogger : AuditLogger;

        // Connections: request flow from external zone through the pipeline
        connection extToController connect externalZone.requestOut to microSegController.requestIn;
        connection controllerToVerifier connect microSegController.requestOut to identityVerifier.requestIn;
        connection controllerToAnalyzer connect microSegController.requestOut to threatAnalyzer.requestIn;
        connection controllerToPolicy connect microSegController.requestOut to policyEngine.requestIn;

        // Identity result to policy engine
        connection verifierToPolicy connect identityVerifier.resultOut to policyEngine.identityIn;

        // Threat result to policy engine
        connection analyzerToPolicy connect threatAnalyzer.resultOut to policyEngine.threatIn;

        // Policy decision to access controller
        connection policyToAccess connect policyEngine.decisionOut to accessController.decisionIn;

        // Request to access controller (parallel to decision)
        connection controllerToAccess connect microSegController.requestOut to accessController.requestIn;

        // Access controller grants/forwards to target zone
        connection accessToInternal connect accessController.accessOut to internalZone.requestIn;
        connection accessToDMZ connect accessController.accessOut to dmzZone.requestIn;
        connection accessToQuarantine connect accessController.accessOut to quarantineZone.requestIn;

        // Audit logging
        connection accessToAudit connect accessController.auditOut to auditLogger.auditIn;

        // Packet inspection path: external zone packets to threat analyzer
        connection extPacketToAnalyzer connect externalZone.requestOut to threatAnalyzer.packetIn;

        // Quarantine routing for suspicious activity
        connection controllerToQuarantine connect microSegController.requestOut to quarantineZone.requestIn;
    }
}
