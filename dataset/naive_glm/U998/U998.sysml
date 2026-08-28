package BioethicsOversightSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====
    package ValueTypes {
        value def RiskScore :> Real { doc /* Risk score from 0.0 to 10.0 */ }
        value def ReadabilityScore :> Real { doc /* Flesch reading ease score */ }
        value def EncryptionKeyLength :> Integer { doc /* Bits */ }
        attribute def EncryptionKeyLengthUnit :> Unit { shortName = "bit"; }
        value def EncryptionKeyLengthValue :> Real { ref :>> unit = EncryptionKeyLengthUnit::bit; }
        value def AuditFrequency :> Real { doc /* Audits per month */ }
        attribute def AuditFrequencyUnit :> Unit { shortName = "per_month"; }
        value def AuditFrequencyValue :> Real { ref :>> unit = AuditFrequencyUnit::per_month; }
        value def ParticipantCount :> Integer;
        value def ResponseTimeHours :> Real;
        attribute def HourUnit :> Unit { shortName = "h"; }
        value def ResponseTimeValue :> Real { ref :>> unit = HourUnit::h; }
        value def LanguageCount :> Integer;
    }

    // ===== Enumerations =====
    enum def ReviewDecisionType { options approved | modificationsRequired | rejected; }
    enum def EthicalPrinciple { options autonomy | beneficence | justice; }
    enum def AuditStatus { options scheduled | inProgress | completed | flagged; }
    enum def PrivacyTechnique { options deIdentification | encryption | accessControl; }
    enum def ConcernSeverity { options low | medium | high | critical; }
    enum def ProtocolStatus { options submitted | underReview | approved | active | suspended | closed; }

    // ===== Item Types =====
    item def ResearchProtocol {
        attribute protocolId : String;
        attribute title : String;
        attribute principalInvestigator : String;
        attribute riskLevel : RiskScore;
        attribute participantCount : ParticipantCount;
        attribute status : ProtocolStatus;
        attribute ethicalPrinciplesEvaluated : EthicalPrinciple[0..*];
    }

    item def ConsentForm {
        attribute formId : String;
        attribute associatedProtocolId : String;
        attribute readabilityScore : ReadabilityScore;
        attribute languagesAvailable : LanguageCount;
        attribute includesRiskDisclosure : Boolean;
        attribute includesBenefitDisclosure : Boolean;
        attribute includesRightToWithdraw : Boolean;
        attribute validated : Boolean;
    }

    item def ReviewDecision {
        attribute decisionId : String;
        attribute protocolId : String;
        attribute decisionType : ReviewDecisionType;
        attribute reviewDate : String;
        attribute reviewerComments : String;
        attribute conditions : String[0..*];
    }

    item def AuditReport {
        attribute reportId : String;
        attribute protocolId : String;
        attribute auditDate : String;
        attribute status : AuditStatus;
        attribute protocolAdherence : Boolean;
        attribute consentProcessFollowed : Boolean;
        attribute dataProtectionVerified : Boolean;
        attribute adverseEventsReported : Boolean;
        attribute findings : String[0..*];
    }

    item def PrivacyData {
        attribute dataId : String;
        attribute protocolId : String;
        attribute deIdentified : Boolean;
        attribute encrypted : Boolean;
        attribute keyLength : EncryptionKeyLengthValue;
        attribute accessControlApplied : Boolean;
        attribute authorizedPersonnel : String[0..*];
    }

    item def ParticipantConcern {
        attribute concernId : String;
        attribute protocolId : String;
        attribute description : String;
        attribute severity : ConcernSeverity;
        attribute submittedDate : String;
        attribute resolved : Boolean;
        attribute resolutionNotes : String;
    }

    item def AdvocacyCase {
        attribute caseId : String;
        attribute concernId : String;
        attribute assignedAdvocate : String;
        attribute investigationStatus : String;
        attribute outcome : String;
    }

    // ===== Port Definitions =====
    port def ProtocolSubmissionPort {
        out item protocols : ResearchProtocol[0..*];
        out item consentForms : ConsentForm[0..*];
    }

    port def ProtocolReviewPort {
        in item protocols : ResearchProtocol[0..*];
        in item consentForms : ConsentForm[0..*];
        out item decisions : ReviewDecision[0..*];
    }

    port def ConsentValidationPort {
        in item consentForms : ConsentForm[0..*];
        out item validatedForms : ConsentForm[0..*];
    }

    port def MonitoringPort {
        in item approvedProtocols : ResearchProtocol[0..*];
        out item auditReports : AuditReport[0..*];
    }

    port def PrivacyManagementPort {
        in item protocols : ResearchProtocol[0..*];
        out item privacyData : PrivacyData[0..*];
    }

    port def AdvocacyPort {
        in item concerns : ParticipantConcern[0..*];
        out item cases : AdvocacyCase[0..*];
    }

    port def DecisionFlowPort {
        in item decisions : ReviewDecision[0..*];
    }

    port def AuditReportPort {
        in item auditReports : AuditReport[0..*];
    }

    port def PrivacyDataPort {
        in item privacyData : PrivacyData[0..*];
    }

    port def ConcernSubmissionPort {
        out item concerns : ParticipantConcern[0..*];
    }

    // ===== Parts =====
    part def InstitutionalReviewBoard {
        attribute boardId : String;
        attribute boardName : String;
        attribute memberCount : Integer;
        attribute quorumRequired : Integer;

        port reviewInput : ProtocolReviewPort;
        port decisionOutput : DecisionFlowPort;
        port consentValidationRequest : ConsentValidationPort;

        attribute pendingProtocols : ResearchProtocol[0..*];
        attribute issuedDecisions : ReviewDecision[0..*];

        state reviewStateBehavior {
            entry action { /* Initialize review process */ }
            state awaitingSubmission {
                entry action { /* Ready to receive new protocols */ }
                transition to underReview
                    when reviewInput.protocols->size() > 0
                    do action { pendingProtocols := reviewInput.protocols; }
            }
            state underReview {
                entry action {
                    /* Assess risks, evaluate ethical principles, validate consent */
                }
                do action {
                    /* Evaluate each protocol against autonomy, beneficence, justice */
                    for p in pendingProtocols {
                        if p.riskLevel > 7.0 {
                            /* High risk requires full board review */
                        }
                    }
                }
                transition to consentValidation
                    when pendingProtocols->size() > 0;
            }
            state consentValidation {
                entry action {
                    /* Request consent form validation from Consent Management System */
                }
                transition to decisionIssuance
                    when reviewInput.consentForms->size() > 0;
            }
            state decisionIssuance {
                entry action {
                    /* Issue formal decision: approval, modifications, or rejection */
                    for p in pendingProtocols {
                        if p.riskLevel <= 5.0 and reviewInput.consentForms->validated {
                            issuedDecisions := issuedDecisions->including(
                                ReviewDecision {
                                    decisionId = "DEC-" + p.protocolId,
                                    protocolId = p.protocolId,
                                    decisionType = ReviewDecisionType::approved,
                                    reviewDate = "2025-01-15",
                                    reviewerComments = "Protocol meets ethical standards.",
                                }
                            );
                        } else if p.riskLevel > 5.0 and p.riskLevel <= 7.5 {
                            issuedDecisions := issuedDecisions->including(
                                ReviewDecision {
                                    decisionId = "DEC-" + p.protocolId,
                                    protocolId = p.protocolId,
                                    decisionType = ReviewDecisionType::modificationsRequired,
                                    reviewDate = "2025-01-15",
                                    reviewerComments = "Modifications required to reduce risk.",
                                    conditions = ("Reduce participant exposure", "Enhance consent clarity"),
                                }
                            );
                        } else {
                            issuedDecisions := issuedDecisions->including(
                                ReviewDecision {
                                    decisionId = "DEC-" + p.protocolId,
                                    protocolId = p.protocolId,
                                    decisionType = ReviewDecisionType::rejected,
                                    reviewDate = "2025-01-15",
                                    reviewerComments = "Risk level unacceptable.",
                                }
                            );
                        }
                    }
                }
                transition to awaitingSubmission
                    when issuedDecisions->size() >= pendingProtocols->size()
                    do action { pendingProtocols := (); }
            }
        }

        action conductReview {
            in submittedProtocols : ResearchProtocol[0..*];
            in submittedConsentForms : ConsentForm[0..*];
            out decisions : ReviewDecision[0..*];
            do action {
                /* Structured review: risk assessment, ethical principle evaluation, consent validation */
            }
        }
    }

    part def ConsentManagementSystem {
        attribute systemId : String;
        attribute minReadabilityScore : ReadabilityScore = 60.0;
        attribute requiredLanguages : LanguageCount = 2;

        port validationInput : ConsentValidationPort;
        port validationOutput : ConsentValidationPort;

        attribute processedForms : ConsentForm[0..*];

        action validateConsentForm {
            in form : ConsentForm;
            out validatedForm : ConsentForm;
            do action {
                /* Check readability, required disclosures, language availability */
                if form.readabilityScore >= minReadabilityScore
                    and form.includesRiskDisclosure
                    and form.includesBenefitDisclosure
                    and form.includesRightToWithdraw
                    and form.languagesAvailable >= requiredLanguages {
                    validatedForm := form {
                        validated = true,
                    };
                } else {
                    validatedForm := form {
                        validated = false,
                    };
                }
            }
        }

        action checkReadability {
            in form : ConsentForm;
            out score : ReadabilityScore;
            do action { /* Compute Flesch reading ease score */ }
        }

        action verifyRequiredDisclosures {
            in form : ConsentForm;
            out complete : Boolean;
            do action {
                complete := form.includesRiskDisclosure
                    and form.includesBenefitDisclosure
                    and form.includesRightToWithdraw;
            }
        }

        action verifyLanguageAvailability {
            in form : ConsentForm;
            out sufficient : Boolean;
            do action {
                sufficient := form.languagesAvailable >= requiredLanguages;
            }
        }
    }

    part def ComplianceMonitoringSystem {
        attribute systemId : String;
        attribute auditFrequency : AuditFrequencyValue = 1.0;
        attribute activeProtocols : ResearchProtocol[0..*];
        attribute auditReports : AuditReport[0..*];

        port monitoringInput : MonitoringPort;
        port monitoringOutput : AuditReportPort;

        state monitoringStateBehavior {
            entry action { /* Initialize monitoring */ }
            state idle {
                transition to schedulingAudits
                    when monitoringInput.approvedProtocols->size() > 0
                    do action { activeProtocols := monitoringInput.approvedProtocols; }
            }
            state schedulingAudits {
                entry action { /* Schedule regular audits for each active protocol */ }
                transition to conductingAudits;
            }
            state conductingAudits {
                entry action {
                    for p in activeProtocols {
                        auditReports := auditReports->including(
                            AuditReport {
                                reportId = "AUD-" + p.protocolId,
                                protocolId = p.protocolId,
                                auditDate = "2025-02-01",
                                status = AuditStatus::completed,
                                protocolAdherence = true,
                                consentProcessFollowed = true,
                                dataProtectionVerified = true,
                                adverseEventsReported = false,
                                findings = ("No deviations detected"),
                            }
                        );
                    }
                }
                transition to reporting
                    when auditReports->size() >= activeProtocols->size();
            }
            state reporting {
                entry action { /* Generate and distribute audit reports */ }
                transition to idle
                    do action { activeProtocols := (); }
            }
        }

        action performAudit {
            in protocol : ResearchProtocol;
            out report : AuditReport;
            do action {
                /* Verify protocol adherence, consent process, data protection, adverse event reporting */
            }
        }

        action verifyProtocolAdherence {
            in protocol : ResearchProtocol;
            out adherent : Boolean;
            do action { /* Check if study follows approved protocol */ }
        }

        action verifyConsentProcess {
            in protocol : ResearchProtocol;
            out followed : Boolean;
            do action { /* Check consent process is correctly followed */ }
        }

        action verifyDataProtection {
            in protocol : ResearchProtocol;
            out protected : Boolean;
            do action { /* Verify participant data is protected */ }
        }

        action checkAdverseEventReporting {
            in protocol : ResearchProtocol;
            out reported : Boolean;
            do action { /* Check unexpected negative outcomes are reported promptly */ }
        }
    }

    part def DataPrivacyModule {
        attribute moduleId : String;
        attribute defaultKeyLength : EncryptionKeyLengthValue = 256.0;
        attribute authorizedUsers : String[0..*];
        attribute protectedDataSets : PrivacyData[0..*];

        port privacyInput : PrivacyManagementPort;
        port privacyOutput : PrivacyDataPort;

        action deIdentifyData {
            in data : PrivacyData;
            out processed : PrivacyData;
            do action {
                /* Remove personal identifiers and anonymize data */
                processed := data { deIdentified = true; }
            }
        }

        action encryptData {
            in data : PrivacyData;
            out processed : PrivacyData;
            do action {
                /* Apply strong encryption to secure data */
                processed := data {
                    encrypted = true,
                    keyLength = defaultKeyLength,
                }
            }
        }

        action applyAccessControls {
            in data : PrivacyData;
            in authorizedPersonnel : String[0..*];
            out processed : PrivacyData;
            do action {
                /* Enforce strict access controls */
                processed := data {
                    accessControlApplied = true,
                    authorizedPersonnel = authorizedPersonnel,
                }
            }
        }

        action safeguardData {
            in protocols : ResearchProtocol[0..*];
            out privacyDataSets : PrivacyData[0..*];
            do action {
                for p in protocols {
                    var baseData : PrivacyData = PrivacyData {
                        dataId = "PRIV-" + p.protocolId,
                        protocolId = p.protocolId,
                        deIdentified = false,
                        encrypted = false,
                        keyLength = 0.0,
                        accessControlApplied = false,
                        authorizedPersonnel = (),
                    };
                    var deIdData : PrivacyData = deIdentifyData(baseData);
                    var encData : PrivacyData = encryptData(deIdData);
                    var finalData : PrivacyData = applyAccessControls(encData, authorizedUsers);
                    privacyDataSets := privacyDataSets->including(finalData);
                }
            }
        }
    }

    part def ParticipantAdvocacyOffice {
        attribute officeId : String;
        attribute officeName : String;
        attribute hotlineNumber : String;
        attribute advocates : String[0..*];
        attribute activeCases : AdvocacyCase[0..*];
        attribute maxResponseTime : ResponseTimeValue = 24.0;

        port concernInput : AdvocacyPort;
        port caseOutput : AdvocacyPort;

        state advocacyStateBehavior {
            entry action { /* Initialize advocacy office */ }
            state available {
                entry action { /* Hotline and support channels open */ }
                transition to receivingConcern
                    when concernInput.concerns->size() > 0;
            }
            state receivingConcern {
                entry action {
                    /* Receive participant concern via hotline or other channel */
                }
                transition to investigating;
            }
            state investigating {
                entry action {
                    for c in concernInput.concerns {
                        var advocate : String = advocates->first();
                        activeCases := activeCases->including(
                            AdvocacyCase {
                                caseId = "CASE-" + c.concernId,
                                concernId = c.concernId,
                                assignedAdvocate = advocate,
                                investigationStatus = "open",
                                outcome = "",
                            }
                        );
                    }
                }
                transition to resolving;
            }
            state resolving {
                entry action {
                    /* Investigate issue and ensure participant rights are protected */
                    for c in concernInput.concerns {
                        if c.severity == ConcernSeverity::critical {
                            /* Escalate immediately */
                        }
                    }
                }
                transition to available
                    do action { /* Close resolved cases */ }
            }
        }

        action receiveConcern {
            in concern : ParticipantConcern;
            out registered : ParticipantConcern;
            do action {
                registered := concern { resolved = false; }
            }
        }

        action assignAdvocate {
            in concern : ParticipantConcern;
            out advocacyCase : AdvocacyCase;
            do action {
                advocacyCase := AdvocacyCase {
                    caseId = "CASE-" + concern.concernId,
                    concernId = concern.concernId,
                    assignedAdvocate = advocates->first(),
                    investigationStatus = "assigned",
                    outcome = "",
                };
            }
        }

        action investigateIssue {
            in advocacyCase : AdvocacyCase;
            out resolvedCase : AdvocacyCase;
            do action {
                /* Investigate participant concern thoroughly */
                resolvedCase := advocacyCase {
                    investigationStatus = "resolved",
                    outcome = "Issue investigated and resolved.",
                };
            }
        }
    }

    // ===== Top-level System =====
    part def BioethicsOversightSystem {
        attribute systemName : String = "Bioethics Oversight System";
        attribute version : String = "1.0";

        part irb : InstitutionalReviewBoard {
            attribute boardName = "Central Institutional Review Board";
            attribute memberCount = 12;
            attribute quorumRequired = 7;
        }

        part consentManagement : ConsentManagementSystem {
            attribute systemId = "CMS-001";
            attribute minReadabilityScore = 60.0;
            attribute requiredLanguages = 2;
        }

        part complianceMonitoring : ComplianceMonitoringSystem {
            attribute systemId = "CMO-001";
            attribute auditFrequency = 1.0;
        }

        part dataPrivacy : DataPrivacyModule {
            attribute moduleId = "DPM-001";
            attribute defaultKeyLength = 256.0;
            attribute authorizedUsers = ("PI_001", "Coordinator_001", "IRB_Chair");
        }

        part advocacyOffice : ParticipantAdvocacyOffice {
            attribute officeName = "Participant Advocacy Office";
            attribute hotlineNumber = "1-800-555-0199";
            attribute advocates = ("Advocate_Alice", "Advocate_Bob", "Advocate_Carol");
            attribute maxResponseTime = 24.0;
        }

        // External researcher submission port
        port researcherSubmission : ProtocolSubmissionPort;
        port participantConcernSubmission : ConcernSubmissionPort;
        port systemDecisionOutput : DecisionFlowPort;
        port systemAuditOutput : AuditReportPort;
        port systemPrivacyOutput : PrivacyDataPort;
        port systemAdvocacyOutput : AdvocacyPort;

        connection def ProtocolToReview {
            end from : ProtocolSubmissionPort;
            end to : ProtocolReviewPort;
        }

        connection researcherToIRB : ProtocolToReview connect researcherSubmission to irb.reviewInput;

        connection def ConsentValidationFlow {
            end from : ConsentValidationPort;
            end to : ConsentValidationPort;
        }

        connection irbToConsent : ConsentValidationFlow connect irb.consentValidationRequest to consentManagement.validationInput;
        connection consentToIRB : ConsentValidationFlow connect consentManagement.validationOutput to irb.reviewInput;

        connection def ApprovedProtocolFlow {
            end from : DecisionFlowPort;
            end to : MonitoringPort;
        }

        connection irbToMonitoring : ApprovedProtocolFlow connect irb.decisionOutput to complianceMonitoring.monitoringInput;

        connection def PrivacyFlow {
            end from : PrivacyManagementPort;
            end to : PrivacyDataPort;
        }

        connection irbToPrivacy : PrivacyFlow connect dataPrivacy.privacyInput to dataPrivacy.privacyOutput;

        connection def ConcernFlow {
            end from : ConcernSubmissionPort;
            end to : AdvocacyPort;
        }

        connection participantToAdvocacy : ConcernFlow connect participantConcernSubmission to advocacyOffice.concernInput;

        connection irbDecisionOut : DecisionFlowPort connect irb.decisionOutput to systemDecisionOutput;
        connection monitoringOut : AuditReportPort connect complianceMonitoring.monitoringOutput to systemAuditOutput;
        connection privacyOut : PrivacyDataPort connect dataPrivacy.privacyOutput to systemPrivacyOutput;
        connection advocacyOut : AdvocacyPort connect advocacyOffice.caseOutput to systemAdvocacyOutput;
    }

    // ===== Requirements =====
    package Requirements {
        requirement def EthicalReviewRequirement {
            doc /* The IRB must formally review all research proposals involving human subjects. */
            attribute id : String = "REQ-001";
            subject irb : InstitutionalReviewBoard;
            predicate {
                irb.conductReview(submittedProtocols, submittedConsentForms, decisions)
                and decisions->size() > 0
            }
        }

        requirement def RiskAssessmentRequirement {
            doc /* The IRB must assess potential risks to participants for every protocol. */
            attribute id : String = "REQ-002";
            subject irb : InstitutionalReviewBoard;
            predicate {
                for all p in irb.pendingProtocols {
                    p.riskLevel >= 0.0 and p.riskLevel <= 10.0
                }
            }
        }

        requirement def EthicalPrincipleEvaluationRequirement {
            doc /* The IRB must evaluate studies against autonomy, beneficence, and justice. */
            attribute id : String = "REQ-003";
            subject irb : InstitutionalReviewBoard;
            predicate {
                EthicalPrinciple::autonomy in EthicalPrinciple
                and EthicalPrinciple::beneficence in EthicalPrinciple
                and EthicalPrinciple::justice in EthicalPrinciple
            }
        }

        requirement def ConsentValidationRequirement {
            doc /* The Consent Management System must validate all informed consent forms. */
            attribute id : String = "REQ-004";
            subject cms : ConsentManagementSystem;
            predicate {
                for all f in cms.processedForms {
                    f.readabilityScore >= cms.minReadabilityScore
                    and f.includesRiskDisclosure
                    and f.includesBenefitDisclosure
                    and f.includesRightToWithdraw
                    and f.languagesAvailable >= cms.requiredLanguages
                }
            }
        }

        requirement def ReadabilityRequirement {
            doc /* Consent forms must have a readability score of at least 60.0. */
            attribute id : String = "REQ-005";
            subject cms : ConsentManagementSystem;
            predicate { cms.minReadabilityScore >= 60.0; }
        }

        requirement def MultiLanguageRequirement {
            doc /* Consent forms must be available in at least 2 languages. */
            attribute id : String = "REQ-006";
            subject cms : ConsentManagementSystem;
            predicate { cms.requiredLanguages >= 2; }
        }

        requirement def ComplianceMonitoringRequirement {
            doc /* The Compliance Monitoring System must perform regular audits of active research projects. */
            attribute id : String = "REQ-007";
            subject cmo : ComplianceMonitoringSystem;
            predicate {
                cmo.auditFrequency > 0.0
                and cmo.auditReports->size() >= 0
            }
        }

        requirement def ProtocolAdherenceRequirement {
            doc /* Audits must verify researchers adhere to the approved protocol. */
            attribute id : String = "REQ-008";
            subject cmo : ComplianceMonitoringSystem;
            predicate {
                for all r in cmo.auditReports {
                    r.protocolAdherence == true
                }
            }
        }

        requirement def AdverseEventReportingRequirement {
            doc /* Unexpected negative outcomes must be reported promptly. */
            attribute id : String = "REQ-009";
            subject cmo : ComplianceMonitoringSystem;
            predicate {
                for all r in cmo.auditReports {
                    r.adverseEventsReported == true
                }
            }
        }

        requirement def DataPrivacyRequirement {
            doc /* The Data Privacy Module must safeguard sensitive participant information. */
            attribute id : String = "REQ-010";
            subject dpm : DataPrivacyModule;
            predicate {
                for all d in dpm.protectedDataSets {
                    d.deIdentified == true
                    and d.encrypted == true
                    and d.accessControlApplied == true
                }
            }
        }

        requirement def EncryptionRequirement {
            doc /* Data must be encrypted with a key length of at least 256 bits. */
            attribute id : String = "REQ-011";
            subject dpm : DataPrivacyModule;
            predicate { dpm.defaultKeyLength >= 256.0; }
        }

        requirement def AccessControlRequirement {
            doc /* Only authorized personnel may view participant information. */
            attribute id : String = "REQ-012";
            subject dpm : DataPrivacyModule;
            predicate {
                dpm.authorizedUsers->size() > 0
                and for all d in dpm.protectedDataSets {
                    d.authorizedPersonnel->size() > 0
                }
            }
        }

        requirement def ParticipantAdvocacyRequirement {
            doc /* The Participant Advocacy Office must provide a direct contact channel for participants. */
            attribute id : String = "REQ-013";
            subject pao : ParticipantAdvocacyOffice;
            predicate {
                pao.hotlineNumber != ""
                and pao.advocates->size() > 0
            }
        }

        requirement def AdvocacyResponseTimeRequirement {
            doc /* Participant concerns must be addressed within 24 hours. */
            attribute id : String = "REQ-014";
            subject pao : ParticipantAdvocacyOffice;
            predicate { pao.maxResponseTime <= 24.0; }
        }

        requirement def ConcernInvestigationRequirement {
            doc /* All participant concerns must be investigated by dedicated advocates. */
            attribute id : String = "REQ-015";
            subject pao : ParticipantAdvocacyOffice;
            predicate {
                for all c in pao.activeCases {
                    c.assignedAdvocate != ""
                    and c.investigationStatus != ""
                }
            }
        }

        requirement def SystemIntegrationRequirement {
            doc /* All system components must be interconnected to support the full ethical review lifecycle. */
            attribute id : String = "REQ-016";
            subject bos : BioethicsOversightSystem;
            predicate {
                bos.irb != null
                and bos.consentManagement != null
                and bos.complianceMonitoring != null
                and bos.dataPrivacy != null
                and bos.advocacyOffice != null
            }
        }
    }

    // ===== Requirement Satisfaction =====
    package RequirementSatisfaction {
        satisfaction ethReviewSat : Requirements::EthicalReviewRequirement {
            subject irbPart : BioethicsOversightSystem::irb;
        }
        satisfaction riskAssessSat : Requirements::RiskAssessmentRequirement {
            subject irbPart : BioethicsOversightSystem::irb;
        }
        satisfaction ethPrincipleSat : Requirements::EthicalPrincipleEvaluationRequirement {
            subject irbPart : BioethicsOversightSystem::irb;
        }
        satisfaction consentValSat : Requirements::ConsentValidationRequirement {
            subject cmsPart : BioethicsOversightSystem::consentManagement;
        }
        satisfaction readabilitySat : Requirements::ReadabilityRequirement {
            subject cmsPart : BioethicsOversightSystem::consentManagement;
        }
        satisfaction multiLangSat : Requirements::MultiLanguageRequirement {
            subject cmsPart : BioethicsOversightSystem::consentManagement;
        }
        satisfaction complianceMonSat : Requirements::ComplianceMonitoringRequirement {
            subject cmoPart : BioethicsOversightSystem::complianceMonitoring;
        }
        satisfaction protocolAdherenceSat : Requirements::ProtocolAdherenceRequirement {
            subject cmoPart : BioethicsOversightSystem::complianceMonitoring;
        }
        satisfaction adverseEventSat : Requirements::AdverseEventReportingRequirement {
            subject cmoPart : BioethicsOversightSystem::complianceMonitoring;
        }
        satisfaction dataPrivacySat : Requirements::DataPrivacyRequirement {
            subject dpmPart : BioethicsOversightSystem::dataPrivacy;
        }
        satisfaction encryptionSat : Requirements::EncryptionRequirement {
            subject dpmPart : BioethicsOversightSystem::dataPrivacy;
        }
        satisfaction accessControlSat : Requirements::AccessControlRequirement {
            subject dpmPart : BioethicsOversightSystem::dataPrivacy;
        }
        satisfaction advocacySat : Requirements::ParticipantAdvocacyRequirement {
            subject paoPart : BioethicsOversightSystem::advocacyOffice;
        }
        satisfaction responseTimeSat : Requirements::AdvocacyResponseTimeRequirement {
            subject paoPart : BioethicsOversightSystem::advocacyOffice;
        }
        satisfaction concernInvestigationSat : Requirements::ConcernInvestigationRequirement {
            subject paoPart : BioethicsOversightSystem::advocacyOffice;
        }
        satisfaction integrationSat : Requirements::SystemIntegrationRequirement {
            subject bosPart : BioethicsOversightSystem;
        }
    }
}
