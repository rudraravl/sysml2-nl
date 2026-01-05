package EthicsOfArtificialIntelligence {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    enum def EthicalPrinciple {
        transparency;
        fairness;
        accountability;
        privacy;
        beneficence;
        nonMaleficence;
        autonomy;
    }
    
    enum def DecisionRiskLevel {
        low;
        medium;
        high;
        critical;
    }
    
    enum def BiasCategory {
        none;
        selection;
        confirmation;
        algorithmic;
        historical;
    }
    
    enum def ComplianceStatus {
        compliant;
        nonCompliant;
        underReview;
        exempt;
    }
    
    attribute def ConfidenceScore :> Real {
        assert constraint { 0.0 <= self and self <= 1.0 }
    }
    
    attribute def FairnessMetric :> Real {
        assert constraint { 0.0 <= self and self <= 1.0 }
    }
    
    attribute def TransparencyIndex :> Real {
        assert constraint { 0.0 <= self and self <= 1.0 }
    }
    
    attribute def BiasScore :> Real {
        assert constraint { 0.0 <= self and self <= 1.0 }
    }
    
    item def InputRequest {
        attribute requestId : String;
        attribute timestamp : Real;
        attribute userContext : String;
        attribute sensitiveData : Boolean;
        attribute impactScope : Integer;
    }
    
    item def EthicalAssessment {
        attribute assessmentId : String;
        attribute principlesEvaluated : EthicalPrinciple[1..*];
        attribute overallScore : ConfidenceScore;
        attribute riskLevel : DecisionRiskLevel;
        attribute biasDetected : BiasCategory;
        attribute recommendedAction : String;
    }
    
    item def AIDecision {
        attribute decisionId : String;
        attribute outcome : String;
        attribute confidence : ConfidenceScore;
        attribute explanation : String;
        attribute ethicalJustification : String;
        attribute humanReviewRequired : Boolean;
    }
    
    item def AuditLog {
        attribute logId : String;
        attribute timestamp : Real;
        attribute decisionReference : String;
        attribute ethicalAssessmentReference : String;
        attribute complianceStatus : ComplianceStatus;
        attribute reviewerNotes : String;
    }
    
    port def RequestInputPort {
        in item request : InputRequest;
    }
    
    port def DecisionOutputPort {
        out item decision : AIDecision;
    }
    
    port def AuditOutputPort {
        out item audit : AuditLog;
    }
    
    port def HumanReviewPort {
        in item reviewRequest : AIDecision;
        out item reviewApproval : Boolean;
    }
    
    port def CompliancePort {
        out item complianceReport : ComplianceStatus;
    }
    
    action def AnalyzeRequest {
        in item request : InputRequest;
        out riskLevel : DecisionRiskLevel;
        out requiresEthicalReview : Boolean;
        
        first start;
        then action evaluateImpact {
            out computedRisk : DecisionRiskLevel;
        }
        then action assignRisk {
            out riskLevel = evaluateImpact.computedRisk;
        }
        then action checkSensitivity {
            out requiresEthicalReview : Boolean;
        }
        then done;
    }
    
    action def EvaluateEthicalPrinciples {
        in item request : InputRequest;
        in riskLevel : DecisionRiskLevel;
        out item assessment : EthicalAssessment;
        
        first start;
        then action assessTransparency {
            out transparencyScore : TransparencyIndex;
        }
        then action assessFairness {
            out fairnessScore : FairnessMetric;
        }
        then action detectBias {
            out biasScore : BiasScore;
            out biasCategory : BiasCategory;
        }
        then action synthesizeAssessment {
            out item assessment : EthicalAssessment;
        }
        then done;
    }
    
    action def GenerateDecision {
        in item request : InputRequest;
        in item assessment : EthicalAssessment;
        out item decision : AIDecision;
        
        first start;
        then action computeOutcome {
            out outcome : String;
            out confidence : ConfidenceScore;
        }
        then action generateExplanation {
            out explanation : String;
            out justification : String;
        }
        then action determineReviewNeed {
            out needsReview : Boolean;
        }
        then action assembleDecision {
            out item decision : AIDecision;
        }
        then done;
    }
    
    action def RequestHumanReview {
        in item decision : AIDecision;
        out approved : Boolean;
        out revisedDecision : AIDecision;
        
        first start;
        then action submitForReview {
            out reviewSubmitted : Boolean;
        }
        then action awaitReviewDecision {
            out approved : Boolean;
        }
        then decide;
            if awaitReviewDecision.approved then acceptDecision;
            else reviseDecision;
        
        action acceptDecision {
            out revisedDecision : AIDecision;
        }
        then merge;
        
        action reviseDecision {
            out revisedDecision : AIDecision;
        }
        then merge;
        
        then done;
    }
    
    action def LogDecisionAudit {
        in item decision : AIDecision;
        in item assessment : EthicalAssessment;
        in complianceStatus : ComplianceStatus;
        out item audit : AuditLog;
        
        first start;
        then action createAuditRecord {
            out item audit : AuditLog;
        }
        then done;
    }
    
    state def EthicalAIStateMachine {
        entry; then idle;
        
        state idle;
        transition idle_to_receiving
            first idle
            then receiving;
        
        state receiving {
            entry; then acceptRequest;
            state acceptRequest;
        }
        transition receiving_to_analyzing
            first receiving
            then analyzing;
        
        state analyzing {
            entry; then performAnalysis;
            state performAnalysis;
        }
        transition analyzing_to_evaluating
            first analyzing
            then evaluating;
        
        state evaluating {
            entry; then assessEthics;
            state assessEthics;
        }
        transition evaluating_to_deciding
            first evaluating
            accept at decisionPoint;
            if highRisk then reviewing;
            else deciding;
        
        state reviewing {
            entry; then awaitHumanInput;
            state awaitHumanInput;
        }
        transition reviewing_to_deciding
            first reviewing
            then deciding;
        
        state deciding {
            entry; then makeDecision;
            state makeDecision;
        }
        transition deciding_to_auditing
            first deciding
            then auditing;
        
        state auditing {
            entry; then logAudit;
            state logAudit;
        }
        transition auditing_to_outputting
            first auditing
            then outputting;
        
        state outputting {
            entry; then sendDecision;
            state sendDecision;
        }
        transition outputting_to_idle
            first outputting
            then idle;
        
        accept at decisionPoint;
    }
    
    part def EthicalReviewBoard {
        attribute boardId : String;
        attribute reviewThreshold : ConfidenceScore;
        attribute principlesEnforced : EthicalPrinciple[*];
        
        port reviewPort : HumanReviewPort;
        
        perform action conductReview : RequestHumanReview;
    }
    
    part def BiasDetectionEngine {
        attribute detectionSensitivity : BiasScore;
        attribute monitoredCategories : BiasCategory[*];
        attribute alertThreshold : BiasScore;
        
        perform action detectBias {
            in item data : InputRequest;
            out biasScore : BiasScore;
            out category : BiasCategory;
        }
    }
    
    part def TransparencyModule {
        attribute minTransparencyLevel : TransparencyIndex;
        attribute explanationDepth : Integer;
        
        perform action generateExplanation {
            in item decision : AIDecision;
            out explanation : String;
            out transparencyScore : TransparencyIndex;
        }
    }
    
    part def FairnessValidator {
        attribute fairnessThreshold : FairnessMetric;
        attribute protectedAttributes : String[*];
        
        perform action validateFairness {
            in item request : InputRequest;
            in item decision : AIDecision;
            out fairnessScore : FairnessMetric;
            out violations : String[*];
        }
    }
    
    part def ComplianceMonitor {
        attribute regulatoryFramework : String;
        attribute complianceThreshold : Real;
        
        port compliancePort : CompliancePort;
        
        perform action checkCompliance {
            in item assessment : EthicalAssessment;
            in item decision : AIDecision;
            out status : ComplianceStatus;
        }
    }
    
    part def AuditTrailManager {
        attribute retentionPeriod : Real;
        attribute encryptionEnabled : Boolean;
        
        port auditPort : AuditOutputPort;
        
        perform action recordAudit : LogDecisionAudit;
    }
    
    part def EthicalAIGovernanceSystem {
        doc /*
         * An AI governance system that ensures all automated decisions comply with
         * established ethical principles. The system evaluates each request against
         * multiple ethical frameworks including transparency, fairness, accountability,
         * and privacy. It detects potential biases, assesses risk levels, generates
         * explainable decisions, and routes high-risk or ethically questionable
         * decisions to human review. All decisions are logged with comprehensive
         * audit trails to ensure accountability and regulatory compliance.
         */
        
        attribute systemId : String;
        attribute activeEthicalFramework : EthicalPrinciple[*];
        attribute overallTransparency : TransparencyIndex;
        attribute overallFairness : FairnessMetric;
        attribute systemConfidence : ConfidenceScore;
        
        port requestInput : RequestInputPort;
        port decisionOutput : DecisionOutputPort;
        
        part biasDetector : BiasDetectionEngine {
            attribute :>> detectionSensitivity = 0.85;
            attribute :>> monitoredCategories = (
                BiasCategory::selection,
                BiasCategory::confirmation,
                BiasCategory::algorithmic,
                BiasCategory::historical
            );
            attribute :>> alertThreshold = 0.3;
        }
        
        part transparencyEngine : TransparencyModule {
            attribute :>> minTransparencyLevel = 0.75;
            attribute :>> explanationDepth = 3;
        }
        
        part fairnessChecker : FairnessValidator {
            attribute :>> fairnessThreshold = 0.80;
            attribute :>> protectedAttributes = ("age", "gender", "race", "religion", "disability");
        }
        
        part reviewBoard : EthicalReviewBoard {
            attribute :>> boardId = "ERB-001";
            attribute :>> reviewThreshold = 0.70;
            attribute :>> principlesEnforced = (
                EthicalPrinciple::transparency,
                EthicalPrinciple::fairness,
                EthicalPrinciple::accountability,
                EthicalPrinciple::privacy
            );
        }
        
        part complianceMonitor : ComplianceMonitor {
            attribute :>> regulatoryFramework = "EU AI Act + IEEE 7000";
            attribute :>> complianceThreshold = 0.95;
        }
        
        part auditManager : AuditTrailManager {
            attribute :>> retentionPeriod = 7776000.0;
            attribute :>> encryptionEnabled = true;
        }
        
        connection biasToFairness connect biasDetector to fairnessChecker;
        connection fairnessToReview connect fairnessChecker to reviewBoard;
        connection reviewToCompliance connect reviewBoard to complianceMonitor;
        connection complianceToAudit connect complianceMonitor to auditManager;
        
        perform action ethicalDecisionWorkflow : EthicalDecisionWorkflow;
        
        exhibit state ethicalStateMachine : EthicalAIStateMachine;
    }
    
    action def EthicalDecisionWorkflow {
        in item inputRequest : InputRequest;
        out item finalDecision : AIDecision;
        out item auditRecord : AuditLog;
        
        first start;
        then merge continueProcessing;
        
        then action analyzeRequest : AnalyzeRequest {
            in item request = inputRequest;
            out riskLevel : DecisionRiskLevel;
            out requiresEthicalReview : Boolean;
        }
        
        then decide ethicalReviewCheck;
            if analyzeRequest.requiresEthicalReview then performEthicalEvaluation;
            else generateDirectDecision;
        
        action performEthicalEvaluation : EvaluateEthicalPrinciples {
            in item request = inputRequest;
            in riskLevel = analyzeRequest.riskLevel;
            out item assessment : EthicalAssessment;
        }
        then generateEthicalDecision;
        
        action generateDirectDecision : GenerateDecision {
            in item request = inputRequest;
            in item assessment : EthicalAssessment;
            out item decision : AIDecision;
        }
        then merge decisionMerge;
        
        action generateEthicalDecision : GenerateDecision {
            in item request = inputRequest;
            in item assessment = performEthicalEvaluation.assessment;
            out item decision : AIDecision;
        }
        then decisionMerge;
        
        then decide humanReviewCheck;
            if generateEthicalDecision.decision.humanReviewRequired then requestReview;
            else finalizeDecision;
        
        action requestReview : RequestHumanReview {
            in item decision : AIDecision;
            out approved : Boolean;
            out revisedDecision : AIDecision;
        }
        then finalizeDecision;
        
        action finalizeDecision {
            out item decision : AIDecision;
        }
        
        then action checkCompliance {
            in item assessment : EthicalAssessment;
            in item decision : AIDecision;
            out status : ComplianceStatus;
        }
        
        then action logAudit : LogDecisionAudit {
            in item decision : AIDecision;
            in item assessment : EthicalAssessment;
            in complianceStatus : ComplianceStatus;
            out item audit : AuditLog;
        }
        
        then assign finalDecision = finalizeDecision.decision;
        then assign auditRecord = logAudit.audit;
        
        then continueProcessing;
        then done;
    }
    
    package EthicalAIRequirements {
        requirement <'REQ-ETH-001'> ethicalComplianceRequirement {
            doc /*
             * The AI governance system shall evaluate all decisions against
             * established ethical principles including transparency, fairness,
             * accountability, and privacy.
             */
            subject system : EthicalAIGovernanceSystem;
        }
        
        requirement <'REQ-ETH-002'> transparencyRequirement {
            doc /*
             * The system shall maintain a minimum transparency index of 0.75
             * for all decisions and provide explainable justifications.
             */
            subject system : EthicalAIGovernanceSystem;
            
            require constraint {
                system.overallTransparency >= 0.75
            }
        }
        
        requirement <'REQ-ETH-003'> fairnessRequirement {
            doc /*
             * The system shall ensure fairness across all protected attributes
             * with a minimum fairness metric of 0.80.
             */
            subject system : EthicalAIGovernanceSystem;
            
            require constraint {
                system.overallFairness >= 0.80
            }
        }
        
        requirement <'REQ-ETH-004'> biasDetectionRequirement {
            doc /*
             * The system shall detect and flag potential biases with a
             * sensitivity of at least 0.85 across all monitored categories.
             */
            subject detector : BiasDetectionEngine;
            
            require constraint {
                detector.detectionSensitivity >= 0.85 and
                detector.alertThreshold <= 0.3
            }
        }
        
        requirement <'REQ-ETH-005'> humanOversightRequirement {
            doc /*
             * The system shall route high-risk decisions, decisions with detected
             * bias, or decisions below confidence threshold to human review.
             */
            subject system : EthicalAIGovernanceSystem;
            
            assume constraint {
                system.reviewBoard.reviewThreshold <= 0.70
            }
        }
        
        requirement <'REQ-ETH-006'> auditTrailRequirement {
            doc /*
             * The system shall maintain comprehensive encrypted audit logs for
             * all decisions with a retention period of at least 90 days.
             */
            subject manager : AuditTrailManager;
            
            require constraint {
                manager.retentionPeriod >= 7776000.0 and
                manager.encryptionEnabled == true
            }
        }
        
        requirement <'REQ-ETH-007'> regulatoryComplianceRequirement {
            doc /*
             * The system shall comply with applicable regulatory frameworks
             * with a compliance threshold of at least 0.95.
             */
            subject monitor : ComplianceMonitor;
            
            require constraint {
                monitor.complianceThreshold >= 0.95
            }
        }
    }
    
    part ethicalAISystem : EthicalAIGovernanceSystem {
        attribute :>> systemId = "ETHICAL-AI-GOV-001";
        attribute :>> activeEthicalFramework = (
            EthicalPrinciple::transparency,
            EthicalPrinciple::fairness,
            EthicalPrinciple::accountability,
            EthicalPrinciple::privacy,
            EthicalPrinciple::beneficence,
            EthicalPrinciple::nonMaleficence
        );
        attribute :>> overallTransparency = 0.87;
        attribute :>> overallFairness = 0.89;
        attribute :>> systemConfidence = 0.92;
    }
    
    satisfy EthicalAIRequirements::ethicalComplianceRequirement by ethicalAISystem;
    satisfy EthicalAIRequirements::transparencyRequirement by ethicalAISystem;
    satisfy EthicalAIRequirements::fairnessRequirement by ethicalAISystem;
    satisfy EthicalAIRequirements::biasDetectionRequirement by ethicalAISystem.biasDetector;
    satisfy EthicalAIRequirements::humanOversightRequirement by ethicalAISystem;
    satisfy EthicalAIRequirements::auditTrailRequirement by ethicalAISystem.auditManager;
    satisfy EthicalAIRequirements::regulatoryComplianceRequirement by ethicalAISystem.complianceMonitor;
}
