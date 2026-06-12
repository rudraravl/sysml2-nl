package AutomatedThreatModel {

    import ScalarValues::*;
    import SI::*;

    attribute def ThreatScore {
        :> ScalarValues::Real;
    }

    attribute def Confidence {
        :> ScalarValues::Real;
    }

    attribute def EventRate {
        :> ScalarValues::Real;
        unit = "events/s";
    }

    attribute def DataVolume {
        :> ScalarValues::Real;
        unit = "GB";
    }

    attribute def Latency {
        :> ScalarValues::Real;
        unit = "s";
    }

    attribute def Identifier {
        :> ScalarValues::String;
    }

    item def TelemetryEvent {
        attribute eventId : Identifier;
        attribute sourceAddress : Identifier;
        attribute destinationAddress : Identifier;
        attribute protocol : Identifier;
        attribute payloadSize : DataVolume;
        attribute observedAt : Time;
    }

    item def ThreatIndicator {
        attribute indicatorId : Identifier;
        attribute indicatorType : Identifier;
        attribute value : Identifier;
        attribute confidence : Confidence;
        attribute severity : ThreatScore;
    }

    item def ThreatAssessment {
        attribute assessmentId : Identifier;
        attribute score : ThreatScore;
        attribute confidence : Confidence;
        attribute recommendedAction : Identifier;
        attribute generatedAt : Time;
    }

    item def ContainmentCommand {
        attribute commandId : Identifier;
        attribute targetId : Identifier;
        attribute action : Identifier;
        attribute expiresIn : Latency;
    }

    item def AnalystNotification {
        attribute notificationId : Identifier;
        attribute summary : Identifier;
        attribute severity : ThreatScore;
        attribute requiresApproval : Boolean;
    }

    port def TelemetryInputPort {
        in item telemetry : TelemetryEvent;
    }

    port def IndicatorInputPort {
        in item indicator : ThreatIndicator;
    }

    port def AssessmentPort {
        out item assessment : ThreatAssessment;
    }

    port def CommandPort {
        out item command : ContainmentCommand;
    }

    port def NotificationPort {
        out item notification : AnalystNotification;
    }

    port def AuditPort {
        out item auditRecord : Identifier;
    }

    part def AutomatedThreatResponseSystem {
        doc /* Primary function: continuously ingest operational telemetry, identify automated threat behavior, assess risk, initiate bounded containment, and notify human analysts while preserving an auditable decision trail. */

        attribute maximumIngestionRate : EventRate = 25000.0;
        attribute maximumAssessmentLatency : Latency = 5.0;
        attribute automaticContainmentThreshold : ThreatScore = 0.85;
        attribute analystReviewThreshold : ThreatScore = 0.60;

        port telemetryIn : TelemetryInputPort;
        port indicatorIn : IndicatorInputPort;
        port assessmentOut : AssessmentPort;
        port commandOut : CommandPort;
        port notificationOut : NotificationPort;
        port auditOut : AuditPort;

        part collector : TelemetryCollector;
        part normalizer : EventNormalizer;
        part detector : ThreatDetectionEngine;
        part scorer : RiskScoringEngine;
        part policy : ResponsePolicyEngine;
        part containment : ContainmentController;
        part notifier : AnalystNotificationService;
        part audit : AuditLogger;

        connect telemetryIn.telemetry to collector.rawTelemetry;
        connect collector.collectedTelemetry to normalizer.rawTelemetry;
        connect normalizer.normalizedTelemetry to detector.normalizedTelemetry;
        connect indicatorIn.indicator to detector.indicatorFeed;
        connect detector.detectedIndicator to scorer.threatIndicator;
        connect scorer.assessment to policy.assessment;
        connect policy.containmentCommand to containment.commandRequest;
        connect policy.analystNotification to notifier.notificationRequest;
        connect containment.issuedCommand to commandOut.command;
        connect scorer.assessment to assessmentOut.assessment;
        connect notifier.notification to notificationOut.notification;
        connect audit.auditRecord to auditOut.auditRecord;

        perform action continuousThreatResponse;
    }

    part def TelemetryCollector {
        port rawTelemetry {
            in item telemetry : TelemetryEvent;
        }

        port collectedTelemetry {
            out item telemetry : TelemetryEvent;
        }

        attribute bufferCapacity : DataVolume = 64.0;
        attribute sustainedRate : EventRate = 25000.0;

        action collectTelemetry {
            in item incoming : TelemetryEvent;
            out item collected : TelemetryEvent;
        }
    }

    part def EventNormalizer {
        port rawTelemetry {
            in item telemetry : TelemetryEvent;
        }

        port normalizedTelemetry {
            out item telemetry : TelemetryEvent;
        }

        attribute normalizationLatency : Latency = 0.25;

        action normalizeEvent {
            in item raw : TelemetryEvent;
            out item normalized : TelemetryEvent;
        }
    }

    part def ThreatDetectionEngine {
        port normalizedTelemetry {
            in item telemetry : TelemetryEvent;
        }

        port indicatorFeed {
            in item indicator : ThreatIndicator;
        }

        port detectedIndicator {
            out item indicator : ThreatIndicator;
        }

        attribute modelVersion : Identifier = "behavioral-detection-4.2";
        attribute minimumConfidence : Confidence = 0.70;

        action correlateBehavior {
            in item telemetry : TelemetryEvent;
            in item knownIndicator : ThreatIndicator;
            out item detected : ThreatIndicator;
        }
    }

    part def RiskScoringEngine {
        port threatIndicator {
            in item indicator : ThreatIndicator;
        }

        port assessment {
            out item assessment : ThreatAssessment;
        }

        attribute scoringLatency : Latency = 1.0;

        action scoreThreat {
            in item indicator : ThreatIndicator;
            out item assessment : ThreatAssessment;
        }
    }

    part def ResponsePolicyEngine {
        port assessment {
            in item assessment : ThreatAssessment;
        }

        port containmentCommand {
            out item command : ContainmentCommand;
        }

        port analystNotification {
            out item notification : AnalystNotification;
        }

        attribute autoContainmentThreshold : ThreatScore = 0.85;
        attribute reviewThreshold : ThreatScore = 0.60;

        action selectResponse {
            in item assessment : ThreatAssessment;
            out item command : ContainmentCommand;
            out item notification : AnalystNotification;
        }
    }

    part def ContainmentController {
        port commandRequest {
            in item command : ContainmentCommand;
        }

        port issuedCommand {
            out item command : ContainmentCommand;
        }

        attribute maximumCommandLifetime : Latency = 900.0;

        action issueContainment {
            in item requested : ContainmentCommand;
            out item issued : ContainmentCommand;
        }
    }

    part def AnalystNotificationService {
        port notificationRequest {
            in item notification : AnalystNotification;
        }

        port notification {
            out item notification : AnalystNotification;
        }

        attribute deliveryLatencyTarget : Latency = 2.0;

        action sendNotification {
            in item requested : AnalystNotification;
            out item sent : AnalystNotification;
        }
    }

    part def AuditLogger {
        port auditRecord {
            out item auditRecord : Identifier;
        }

        attribute retentionPeriodDays : Integer = 365;

        action recordDecision {
            in item assessment : ThreatAssessment;
            in item command : ContainmentCommand;
            out item auditRecord : Identifier;
        }
    }

    action def ContinuousThreatResponse {
        in item telemetry : TelemetryEvent;
        in item externalIndicator : ThreatIndicator;
        out item assessment : ThreatAssessment;
        out item command : ContainmentCommand;
        out item notification : AnalystNotification;

        first start;
        then ingest;
        then normalize;
        then detect;
        then score;
        then decide;

        if assessment.score >= 0.85 then contain;
        if assessment.score >= 0.60 then notify;
        then log;
        then done;

        action start;
        action ingest;
        action normalize;
        action detect;
        action score;
        action decide;
        action contain;
        action notify;
        action log;
        action done;
    }

    state def ThreatResponseLifecycle {
        state idle;
        state monitoring;
        state suspiciousActivityDetected;
        state threatConfirmed;
        state containmentPending;
        state contained;
        state analystReview;
        state closed;

        transition idle_to_monitoring
            first idle
            then monitoring;

        transition monitoring_to_suspicious
            first monitoring
            accept event : TelemetryEvent
            then suspiciousActivityDetected;

        transition suspicious_to_confirmed
            first suspiciousActivityDetected
            if eventConfidence >= 0.70
            then threatConfirmed;

        transition confirmed_to_containment
            first threatConfirmed
            if threatScore >= 0.85
            then containmentPending;

        transition containment_to_contained
            first containmentPending
            then contained;

        transition confirmed_to_review
            first threatConfirmed
            if threatScore >= 0.60 and threatScore < 0.85
            then analystReview;

        transition review_to_closed
            first analystReview
            then closed;

        transition contained_to_closed
            first contained
            then closed;

        attribute eventConfidence : Confidence;
        attribute threatScore : ThreatScore;
    }

    requirement def DetectAutomatedThreats {
        doc /* The system shall detect automated threat behavior by correlating telemetry events with behavioral patterns and threat indicators. */
        subject system : AutomatedThreatResponseSystem;
        require constraint {
            system.detector.minimumConfidence >= 0.70
        }
    }

    requirement def AssessRiskWithinLatency {
        doc /* The system shall generate a threat assessment within the maximum allowed assessment latency after receiving normalized telemetry. */
        subject system : AutomatedThreatResponseSystem;
        require constraint {
            system.maximumAssessmentLatency <= 5.0
        }
    }

    requirement def ContainHighSeverityThreats {
        doc /* The system shall automatically issue a containment command for confirmed threats with score greater than or equal to the automatic containment threshold. */
        subject system : AutomatedThreatResponseSystem;
        require constraint {
            system.automaticContainmentThreshold == 0.85
        }
    }

    requirement def NotifyAnalystsForReview {
        doc /* The system shall notify analysts when a threat requires review or when automated containment has been initiated. */
        subject system : AutomatedThreatResponseSystem;
        require constraint {
            system.analystReviewThreshold <= system.automaticContainmentThreshold
        }
    }

    requirement def PreserveAuditTrail {
        doc /* The system shall preserve an audit record for each threat assessment and response decision. */
        subject system : AutomatedThreatResponseSystem;
        require constraint {
            system.audit.retentionPeriodDays >= 365
        }
    }

    part automatedThreatResponseSystem : AutomatedThreatResponseSystem {
        perform continuousThreatResponse : ContinuousThreatResponse;
        exhibit ThreatResponseLifecycle;
    }

    satisfy DetectAutomatedThreats by automatedThreatResponseSystem.detector;
    satisfy AssessRiskWithinLatency by automatedThreatResponseSystem.scorer;
    satisfy ContainHighSeverityThreats by automatedThreatResponseSystem.policy;
    satisfy NotifyAnalystsForReview by automatedThreatResponseSystem.notifier;
    satisfy PreserveAuditTrail by automatedThreatResponseSystem.audit;
}