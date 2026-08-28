package EthicalAIGovernanceSystem {
    import ScalarValues::*;

    item def DecisionRequest {
        attribute id : String;
        attribute payload : String;
        attribute protectedAttributes : String[*];
    }

    item def DecisionResponse {
        attribute id : String;
        attribute outcome : String;
        attribute explanation : String;
        attribute risk : RiskLevel;
    }

    enum def RiskLevel {
        literal LOW;
        literal MEDIUM;
        literal HIGH;
    }

    unit def score;
    unit def bias;
    unit def confidence;

    value type RiskScore :> Real {
        unit score;
        constraint { 0.0 <= self and self <= 1.0 }
    }

    value type ConfidenceLevel :> Real {
        unit confidence;
        constraint { 0.0 <= self and self <= 1.0 }
    }

    value type BiasMetric :> Real {
        unit bias;
        constraint { 0.0 <= self and self <= 1.0 }
    }

    item def BiasReport {
        attribute historicalBias : BiasMetric;
        attribute algorithmicBias : BiasMetric;
    }

    item def FairnessReport {
        attribute ageImpact : BiasMetric;
        attribute raceImpact : BiasMetric;
        attribute genderImpact : BiasMetric;
        attribute overallScore : RiskScore;
    }

    item def ComplianceReport {
        attribute regulatoryFramework : String;
        attribute isCompliant : Boolean;
    }

    item def AuditEntry {
        attribute timestamp : String;
        attribute actionDescription : String;
        attribute hash : String;
    }

    port def RequestInPort {
        in item request : DecisionRequest;
    }

    port def ResponseOutPort {
        out item response : DecisionResponse;
    }

    port def BiasReportOutPort {
        out item report : BiasReport;
    }

    port def FairnessReportOutPort {
        out item report : FairnessReport;
    }

    port def TransparencyOutPort {
        out item explanation : String;
    }

    port def ReviewBoardPort {
        in item flaggedRequest : DecisionRequest;
        out item adjudicatedResponse : DecisionResponse;
    }

    port def ComplianceReportOutPort {
        out item report : ComplianceReport;
    }

    port def AuditEntryInPort {
        in item entry : AuditEntry;
    }

    port def LoggingStatusOutPort {
        out item status : String;
    }

    requirement def EthicalRequirement {
        doc /* Base requirement for ethical AI governance */
    }

    requirement def ReqFairness :> EthicalRequirement {
        doc /* Ensure AI decisions do not unfairly impact protected groups */
    }

    requirement def ReqTransparency :> EthicalRequirement {
        doc /* Generate human-understandable explanations for AI decisions */
    }

    requirement def ReqAccountability :> EthicalRequirement {
        doc /* Maintain an encrypted, unchangeable audit trail of all decisions */
    }

    requirement def ReqCompliance :> EthicalRequirement {
        doc /* Ensure decisions comply with legal regulations like EU AI Act */
    }

    requirement def ReqHumanOversight :> EthicalRequirement {
        doc /* Route high-risk, low-confidence, or ethically ambiguous decisions to human review */
    }

    part def BiasDetectionEngine {
        port requestData : RequestInPort;
        port biasReportOut : BiasReportOutPort;
        
        action detectBias {
            in data : DecisionRequest;
            out report : BiasReport;
        }
        
        satisfy ReqFairness;
    }

    part def FairnessValidator {
        port validateData : RequestInPort;
        port fairnessReportOut : FairnessReportOutPort;
        
        action validateFairness {
            in data : DecisionRequest;
            out report : FairnessReport;
        }
        
        satisfy ReqFairness;
    }

    part def TransparencyModule {
        port explainData : RequestInPort;
        port explanationOut : TransparencyOutPort;
        
        action generateExplanation {
            in data : DecisionRequest;
            out expl : String;
        }
        
        satisfy ReqTransparency;
    }

    part def EthicalReviewBoard {
        port reviewBoardPort : ReviewBoardPort;
        
        action adjudicate {
            in req : DecisionRequest;
            out resp : DecisionResponse;
        }
        
        satisfy ReqHumanOversight;
    }

    part def ComplianceMonitor {
        port monitorData : RequestInPort;
        port complianceReportOut : ComplianceReportOutPort;
        
        action checkCompliance {
            in data : DecisionRequest;
            out report : ComplianceReport;
        }
        
        satisfy ReqCompliance;
    }

    part def AuditTrailManager {
        port logEntryIn : AuditEntryInPort;
        port loggingStatusOut : LoggingStatusOutPort;
        
        action logAudit {
            in entry : AuditEntry;
            out status : String;
        }
        
        satisfy ReqAccountability;
    }

    part def EthicalAIGovernanceSystem {
        port inBoundary : RequestInPort;
        port outBoundary : ResponseOutPort;
        
        part biasEngine : BiasDetectionEngine;
        part fairnessVal : FairnessValidator;
        part transparencyMod : TransparencyModule;
        part reviewBoard : EthicalReviewBoard;
        part complianceMon : ComplianceMonitor;
        part auditMgr : AuditTrailManager;
        
        connection reqToBias connect inBoundary.request to biasEngine.requestData.request;
        connection reqToFairness connect inBoundary.request to fairnessVal.validateData.request;
        connection reqToTransparency connect inBoundary.request to transparencyMod.explainData.request;
        connection reqToCompliance connect inBoundary.request to complianceMon.monitorData.request;
        connection reqToReviewBoard connect inBoundary.request to reviewBoard.reviewBoardPort.flaggedRequest;
        connection reviewBoardToOut connect reviewBoard.reviewBoardPort.adjudicatedResponse to outBoundary.response;
        
        attribute currentRisk : RiskLevel;
        attribute currentConfidence : ConfidenceLevel;
        
        state machine GovernanceStateMachine {
            state idle;
            state analyzing {
                entry {
                    biasEngine.detectBias();
                    fairnessVal.validateFairness();
                    transparencyMod.generateExplanation();
                    complianceMon.checkCompliance();
                }
            };
            state evaluating;
            state reviewing {
                entry {
                    reviewBoard.adjudicate();
                }
            };
            state auditing {
                entry {
                    auditMgr.logAudit();
                }
            };
            state outputting;
            
            transition from idle to analyzing 
                accept inBoundary.request;
                
            transition from analyzing to evaluating;
                
            transition from evaluating to reviewing 
                when (currentRisk == RiskLevel::HIGH or currentConfidence < 0.8);
                
            transition from evaluating to auditing 
                when (currentRisk != RiskLevel::HIGH and currentConfidence >= 0.8);
                
            transition from reviewing to auditing;
                
            transition from auditing to outputting;
                
            transition from outputting to idle;
        }
        
        satisfy ReqFairness;
        satisfy ReqTransparency;
        satisfy ReqAccountability;
        satisfy ReqCompliance;
        satisfy ReqHumanOversight;
    }
}
