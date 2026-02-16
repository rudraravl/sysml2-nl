package BioethicsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import ModelingMetadata::*;
    private import RiskMetadata::*;
    private import RiskLevelEnum::*;

    attribute def EthicalPrincipleType {
        attribute autonomy : String;
        attribute beneficence : String;
        attribute nonMaleficence : String;
        attribute justice : String;
    }

    attribute def ReviewStatus {
        attribute pending : String;
        attribute underReview : String;
        attribute approved : String;
        attribute conditionallyApproved : String;
        attribute rejected : String;
    }

    attribute def RiskAssessmentScore :> Real;
    attribute def ComplianceScore :> Real;
    attribute def EthicalScore :> Real;

    item def ResearchProtocol {
        attribute protocolId : String;
        attribute title : String;
        attribute principalInvestigator : String;
        attribute institution : String;
        attribute participantCount : Integer;
        attribute studyDuration : ISQ::DurationValue;
        attribute riskCategory : String;
        attribute involvesVulnerablePopulations : Boolean;
    }

    item def ConsentForm {
        attribute formId : String;
        attribute version : String;
        attribute formLanguage : String;
        attribute readabilityScore : Real;
        attribute includesWithdrawalRights : Boolean;
        attribute includesRiskDisclosure : Boolean;
        attribute includesBenefitDisclosure : Boolean;
    }

    item def EthicalReviewDecision {
        attribute decisionId : String;
        attribute reviewDate : String;
        attribute decisionStatus : String;
        attribute ethicalScore : EthicalScore;
        attribute conditions : String[*];
        attribute requiredModifications : String[*];
        attribute reviewerComments : String;
    }

    item def ComplianceReport {
        attribute reportId : String;
        attribute generatedDate : String;
        attribute complianceScore : ComplianceScore;
        attribute violations : String[*];
        attribute recommendations : String[*];
    }

    port def ProtocolSubmissionPort {
        in item submittedProtocol : ResearchProtocol;
        in item consentDocuments : ConsentForm[*];
    }

    port def ReviewDecisionPort {
        out item reviewDecision : EthicalReviewDecision;
    }

    port def ComplianceReportPort {
        out item complianceReport : ComplianceReport;
    }

    port def DataPrivacyPort {
        in item protocolData : ResearchProtocol;
        out item privacyAssessment : String;
    }

    action def AssessEthicalRisk {
        in protocol : ResearchProtocol;
        out riskScore : RiskAssessmentScore;
    }

    action def ValidateInformedConsent {
        in consentForm : ConsentForm;
        out isValid : Boolean;
        out validationIssues : String[*];
    }

    action def EvaluateEthicalPrinciples {
        in protocol : ResearchProtocol;
        out autonomyScore : EthicalScore;
        out beneficenceScore : EthicalScore;
        out nonMaleficenceScore : EthicalScore;
        out justiceScore : EthicalScore;
    }

    action def GenerateReviewDecision {
        in riskScore : RiskAssessmentScore;
        in ethicalScores : EthicalScore[4];
        in consentValid : Boolean;
        out decision : EthicalReviewDecision;
    }

    action def MonitorOngoingCompliance {
        in protocol : ResearchProtocol;
        in reviewDecision : EthicalReviewDecision;
        out complianceReport : ComplianceReport;
    }

    part def InstitutionalReviewBoard {
        attribute boardId : String;
        attribute memberCount : Integer;
        attribute meetingSchedule : String;
        attribute accreditationStatus : String;

        port submissionPort : ProtocolSubmissionPort;
        port decisionPort : ReviewDecisionPort;

        action conductEthicalReview {
            in submittedProtocol : ResearchProtocol;
            in consentForms : ConsentForm[*];
            out finalDecision : EthicalReviewDecision;

            private attribute riskAssessment : RiskAssessmentScore;
            private attribute consentValidation : Boolean;
            private attribute ethicalEvaluation : EthicalScore[4];

            first start;
            
            then action assessRisk : AssessEthicalRisk {
                in protocol = submittedProtocol;
                out riskScore;
            }
            
            then assign riskAssessment := assessRisk.riskScore;
            
            then action validateConsent : ValidateInformedConsent {
                in consentForm = consentForms#(1);
                out isValid;
                out validationIssues;
            }
            
            then assign consentValidation := validateConsent.isValid;
            
            then action evaluatePrinciples : EvaluateEthicalPrinciples {
                in protocol = submittedProtocol;
                out autonomyScore;
                out beneficenceScore;
                out nonMaleficenceScore;
                out justiceScore;
            }
            
            then assign ethicalEvaluation := (
                evaluatePrinciples.autonomyScore,
                evaluatePrinciples.beneficenceScore,
                evaluatePrinciples.nonMaleficenceScore,
                evaluatePrinciples.justiceScore
            );
            
            then decide;
                if consentValidation and riskAssessment < 7.0 then approveProtocol;
                if not consentValidation or riskAssessment >= 7.0 then reviewWithConditions;
            
            action approveProtocol : GenerateReviewDecision {
                in riskScore = riskAssessment;
                in ethicalScores = ethicalEvaluation;
                in consentValid = consentValidation;
                out decision;
            }
            then assign finalDecision := approveProtocol.decision;
            then done;
            
            action reviewWithConditions : GenerateReviewDecision {
                in riskScore = riskAssessment;
                in ethicalScores = ethicalEvaluation;
                in consentValid = consentValidation;
                out decision;
            }
            then assign finalDecision := reviewWithConditions.decision;
            then done;
        }
    }

    part def ConsentManagementSystem {
        attribute systemId : String;
        attribute activeConsentForms : Integer;
        attribute languagesSupported : String[*];

        action manageConsent {
            in consentForm : ConsentForm;
            out validatedConsent : ConsentForm;
            out validationStatus : Boolean;

            first start;
            
            then action checkReadability {
                in form : ConsentForm = consentForm;
                out readabilityAcceptable : Boolean;
            }
            
            then action verifyRequiredElements {
                in form : ConsentForm = consentForm;
                out allElementsPresent : Boolean;
            }
            
            then action assessComprehensibility {
                in form : ConsentForm = consentForm;
                out comprehensible : Boolean;
            }
            
            then decide;
                if checkReadability.readabilityAcceptable and 
                   verifyRequiredElements.allElementsPresent and 
                   assessComprehensibility.comprehensible 
                then approveConsent;
                else requestRevision;
            
            action approveConsent {
                out approved : Boolean;
            }
            then assign validationStatus := true;
            then done;
            
            action requestRevision {
                out revisionNeeded : Boolean;
            }
            then assign validationStatus := false;
            then done;
        }
    }

    part def ComplianceMonitoringSystem {
        attribute monitorId : String;
        attribute auditFrequency : ISQ::FrequencyValue;
        attribute activeProtocols : Integer;

        port compliancePort : ComplianceReportPort;

        action performComplianceAudit {
            in protocol : ResearchProtocol;
            in reviewDecision : EthicalReviewDecision;
            out auditReport : ComplianceReport;

            first start;
            
            then action checkProtocolAdherence {
                in currentProtocol : ResearchProtocol = protocol;
                in approvedProtocol : EthicalReviewDecision = reviewDecision;
                out adherenceScore : ComplianceScore;
            }
            
            then action verifyConsentProcess {
                in currentProtocol : ResearchProtocol = protocol;
                out consentProcessCompliant : Boolean;
            }
            
            then action reviewDataProtection {
                in currentProtocol : ResearchProtocol = protocol;
                out dataProtectionCompliant : Boolean;
            }
            
            then action assessAdverseEvents {
                in currentProtocol : ResearchProtocol = protocol;
                out adverseEventsReported : Boolean;
            }
            
            then action compileReport : MonitorOngoingCompliance {
                in protocol = protocol;
                in reviewDecision = reviewDecision;
                out complianceReport;
            }
            
            then assign auditReport := compileReport.complianceReport;
            then done;
        }
    }

    part def DataPrivacyModule {
        attribute moduleId : String;
        attribute encryptionStandard : String;
        attribute anonymizationLevel : String;

        port privacyPort : DataPrivacyPort;

        action protectParticipantData {
            in rawData : String;
            out protectedData : String;

            first start;
            
            then action deidentifyData {
                in inputData : String = rawData;
                out deidentifiedData : String;
            }
            
            then action encryptData {
                in inputData : String = deidentifyData.deidentifiedData;
                out encryptedData : String;
            }
            
            then action applyAccessControls {
                in inputData : String = encryptData.encryptedData;
                out securedData : String;
            }
            
            then assign protectedData := applyAccessControls.securedData;
            then done;
        }
    }

    part def ParticipantAdvocacyOffice {
        attribute officeId : String;
        attribute advocateCount : Integer;
        attribute hotlineNumber : String;

        action supportParticipants {
            in participantConcern : String;
            out resolution : String;

            first start;
            
            then action receiveConcern {
                in concern : String = participantConcern;
                out documentedConcern : String;
            }
            
            then action investigateConcern {
                in concern : String = receiveConcern.documentedConcern;
                out findings : String;
            }
            
            then action resolveIssue {
                in findings : String = investigateConcern.findings;
                out resolutionPlan : String;
            }
            
            then assign resolution := resolveIssue.resolutionPlan;
            then done;
        }
    }

    requirement def EthicalOversightRequirement {
        doc /* All research involving human subjects must undergo ethical review. */
        
        require constraint protocolReviewMandatory {
            doc /* Every research protocol must be reviewed before initiation. */
        }
        
        require constraint continuousMonitoring {
            doc /* Approved protocols must be monitored throughout their duration. */
        }
    }

    requirement def InformedConsentRequirement {
        doc /* Valid informed consent must be obtained from all participants. */
        
        require constraint voluntaryParticipation {
            doc /* Participation must be voluntary without coercion. */
        }
        
        require constraint comprehensiveDisclosure {
            doc /* All risks, benefits, and alternatives must be disclosed. */
        }
        
        require constraint withdrawalRights {
            doc /* Participants must be informed of their right to withdraw. */
        }
    }

    requirement def DataProtectionRequirement {
        doc /* Participant data must be protected according to privacy regulations. */
        
        require constraint dataMinimization {
            doc /* Only necessary data should be collected. */
        }
        
        require constraint secureStorage {
            doc /* Data must be stored securely with encryption. */
        }
        
        require constraint accessControl {
            doc /* Access to participant data must be restricted and logged. */
        }
    }

    requirement def ParticipantSafetyRequirement {
        doc /* Participant safety and wellbeing must be prioritized. */
        
        @StatusInfo {
            status = StatusKind::tbd;
            risk {
                totalRisk = high;
                technicalRisk = medium;
                scheduleRisk = low;
                costRisk = medium;
            }
            originator = "Chief Ethics Officer";
            owner = "IRB Chair";
        }
        
        require constraint adverseEventReporting {
            doc /* All adverse events must be reported promptly. */
        }
        
        require constraint riskMinimization {
            doc /* Risks to participants must be minimized. */
        }
    }

    part def BioethicsOversightSystem {
        part irb : InstitutionalReviewBoard;
        part consentSystem : ConsentManagementSystem;
        part complianceMonitor : ComplianceMonitoringSystem;
        part dataPrivacy : DataPrivacyModule;
        part participantAdvocacy : ParticipantAdvocacyOffice;
    }

    part bioethicsOversightSystem : BioethicsOversightSystem {
        doc /* 
        The Bioethics Oversight System provides comprehensive ethical governance 
        for research involving human subjects. Its primary function is to ensure 
        that all research activities uphold fundamental ethical principles including 
        respect for persons, beneficence, and justice. The system reviews research 
        protocols, validates informed consent processes, monitors ongoing compliance, 
        protects participant data privacy, and advocates for participant rights and 
        safety throughout the research lifecycle.
        */
        
        part irb : InstitutionalReviewBoard {
            attribute boardId = "IRB-2024-001";
            attribute memberCount = 15;
            attribute meetingSchedule = "bi-weekly";
            attribute accreditationStatus = "AAHRPP-accredited";
        }
        
        part consentSystem : ConsentManagementSystem {
            attribute systemId = "CMS-2024";
            attribute activeConsentForms = 0;
            attribute languagesSupported = ("English", "Spanish", "Mandarin", "French");
        }
        
        part complianceMonitor : ComplianceMonitoringSystem {
            attribute monitorId = "COMP-2024";
            attribute auditFrequency = 4.0 [SI::Hz];
            attribute activeProtocols = 0;
        }
        
        part dataPrivacy : DataPrivacyModule {
            attribute moduleId = "DPM-2024";
            attribute encryptionStandard = "AES-256";
            attribute anonymizationLevel = "high";
        }
        
        part participantAdvocacy : ParticipantAdvocacyOffice {
            attribute officeId = "PAO-2024";
            attribute advocateCount = 5;
            attribute hotlineNumber = "1-800-ETHICS";
        }
        
        connection irbToConsent 
            connect irb.submissionPort to consentSystem;
        
        connection irbToCompliance 
            connect irb.decisionPort to complianceMonitor.compliancePort;
        
        connection privacyToIrb 
            connect dataPrivacy.privacyPort to irb;
        
        action provideEthicalOversight {
            doc /* 
            Primary system function: Provide comprehensive ethical oversight ensuring 
            research integrity, participant protection, and regulatory compliance through 
            protocol review, consent validation, continuous monitoring, and advocacy.
            */
            
            first start;
            then merge continuousOversight;
            
            then action receiveSubmission {
                out newProtocol : ResearchProtocol;
                out consentDocs : ConsentForm[*];
            }
            
            then action reviewProtocol {
                in protocol : ResearchProtocol = receiveSubmission.newProtocol;
                in consents : ConsentForm[*] = receiveSubmission.consentDocs;
                out decision : EthicalReviewDecision;
                
                perform irb.conductEthicalReview;
            }
            
            then decide;
                if reviewProtocol.decision.decisionStatus == "approved" then initiateMonitoring;
                if reviewProtocol.decision.decisionStatus == "conditionallyApproved" then requestModifications;
                if reviewProtocol.decision.decisionStatus == "rejected" then notifyRejection;
            
            action initiateMonitoring {
                in protocol : ResearchProtocol = receiveSubmission.newProtocol;
                in decision : EthicalReviewDecision = reviewProtocol.decision;
                out monitoring : ComplianceReport;
                
                perform complianceMonitor.performComplianceAudit;
            }
            
            then action protectData {
                in protocol : ResearchProtocol = receiveSubmission.newProtocol;
                out secured : String;
                
                perform dataPrivacy.protectParticipantData;
            }
            
            then continuousOversight;
            
            action requestModifications {
                in decision : EthicalReviewDecision = reviewProtocol.decision;
                out modificationRequest : String;
            }
            then continuousOversight;
            
            action notifyRejection {
                in decision : EthicalReviewDecision = reviewProtocol.decision;
                out rejectionNotice : String;
            }
            then done;
        }
        
        satisfy requirement ethicalOversightReq : EthicalOversightRequirement by irb;
        satisfy requirement informedConsentReq : InformedConsentRequirement by consentSystem;
        satisfy requirement dataProtectionReq : DataProtectionRequirement by dataPrivacy;
        satisfy requirement participantSafetyReq : ParticipantSafetyRequirement by participantAdvocacy;
    }
}
