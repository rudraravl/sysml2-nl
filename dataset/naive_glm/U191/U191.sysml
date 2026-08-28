package MEDICRIME_System {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    def UrgencyLevel :> String {
        enum { low, medium, high, critical }
    }

    def ProductCategory :> String {
        enum { medicine, vaccine, medicalDevice, supplement }
    }

    def AuthenticityResult :> String {
        enum { genuine, counterfeit, inconclusive }
    }

    def CaseStatus :> String {
        enum { submitted, validated, verifying, analyzed, decided, investigating, responding, coordinating, resolved, closed }
    }

    value TimeHours :> Real { unit "h" }
    value ConfidenceScore :> Real { unit "1" }
    value RiskLevel :> Integer { unit "1" }

    // ===== Item Definitions =====
    item def SuspectProduct {
        attribute productId : String;
        attribute name : String;
        attribute category : ProductCategory;
        attribute batchNumber : String;
        attribute originCountry : String;
        attribute reportedRegions : String[0..*];
    }

    item def ProductReport {
        attribute reportId : String;
        attribute reporterId : String;
        attribute reporterType : String;
        attribute product : SuspectProduct;
        attribute description : String;
        attribute urgency : UrgencyLevel;
        attribute submissionTime : DateTime;
        attribute location : String;
    }

    item def LabAnalysisRequest {
        attribute requestId : String;
        attribute reportRef : String;
        attribute product : SuspectProduct;
        attribute requestedTests : String[0..*];
    }

    item def LabAnalysisResult {
        attribute resultId : String;
        attribute requestId : String;
        attribute authenticity : AuthenticityResult;
        attribute compositionNotes : String;
        attribute hazardNotes : String;
        attribute confidence : ConfidenceScore;
    }

    item def RiskAssessment {
        attribute assessmentId : String;
        attribute reportRef : String;
        attribute riskLevel : RiskLevel;
        attribute affectedPopulation : String;
        attribute rationale : String;
    }

    item def CaseDecision {
        attribute decisionId : String;
        attribute reportRef : String;
        attribute authenticity : AuthenticityResult;
        attribute risk : RiskAssessment;
        attribute decision : String;
        attribute timestamp : DateTime;
    }

    item def InvestigationCase {
        attribute caseId : String;
        attribute reportRef : String;
        attribute assignedUnit : String;
        attribute status : CaseStatus;
        attribute openedAt : DateTime;
        attribute charges : String[0..*];
    }

    item def SeizureOrder {
        attribute orderRef : String;
        attribute caseRef : String;
        attribute product : SuspectProduct;
        attribute authorizedAgencies : String[0..*];
        attribute issuedAt : DateTime;
        attribute validUntil : DateTime;
    }

    item def PublicAlert {
        attribute alertId : String;
        attribute caseRef : String;
        attribute product : SuspectProduct;
        attribute riskSummary : String;
        attribute affectedRegions : String[0..*];
        attribute issuedAt : DateTime;
        attribute severity : UrgencyLevel;
    }

    item def InternationalNotification {
        attribute notificationId : String;
        attribute caseRef : String;
        attribute recipientCountries : String[0..*];
        attribute recipientBodies : String[0..*];
        attribute sharedDetails : String;
        attribute sentAt : DateTime;
    }

    item def EvidenceItem {
        attribute evidenceId : String;
        attribute caseRef : String;
        attribute description : String;
        attribute custodian : String;
        attribute collectedAt : DateTime;
        attribute hash : String;
    }

    item def ChainOfCustodyRecord {
        attribute recordId : String;
        attribute caseRef : String;
        attribute evidence : EvidenceItem[1..*];
        attribute transfers : String[0..*];
        attribute sealed : Boolean;
    }

    // ===== Port Definitions =====
    port def ReportSubmissionPort {
        out productReports : ProductReport;
    }

    port def ReportReceptionPort {
        in productReports : ProductReport;
    }

    port def LabRequestPort {
        out labRequests : LabAnalysisRequest;
        in labResults : LabAnalysisResult;
    }

    port def LabServicePort {
        in labRequests : LabAnalysisRequest;
        out labResults : LabAnalysisResult;
    }

    port def DecisionPort {
        out decisions : CaseDecision;
    }

    port def InvestigationPort {
        out investigationCases : InvestigationCase;
        out seizureOrders : SeizureOrder;
    }

    port def EnforcementPort {
        in investigationCases : InvestigationCase;
        in seizureOrders : SeizureOrder;
    }

    port def HealthAlertPort {
        out publicAlerts : PublicAlert;
    }

    port def HealthReceptionPort {
        in riskAssessments : RiskAssessment;
        in decisions : CaseDecision;
    }

    port def InternationalPort {
        out notifications : InternationalNotification;
    }

    port def InternationalReceptionPort {
        in notifications : InternationalNotification;
    }

    port def EvidencePort {
        out chainRecords : ChainOfCustodyRecord;
    }

    // ===== Parts =====
    part def PublicPortal {
        port reportOut : ReportSubmissionPort;
        attribute submittedReports : ProductReport[0..*];
        operation submitReport(report : ProductReport) {
            /* receive report from public or professional */
        }
    }

    part def ForensicLaboratory {
        port labService : LabServicePort;
        attribute pendingRequests : LabAnalysisRequest[0..*];
        attribute completedResults : LabAnalysisResult[0..*];
        operation analyze(request : LabAnalysisRequest) : LabAnalysisResult {
            /* perform chemical and physical analysis */
        }
    }

    part def LawEnforcementUnit {
        port enforcement : EnforcementPort;
        attribute activeCases : InvestigationCase[0..*];
        attribute activeOrders : SeizureOrder[0..*];
        operation pursueCharges(case : InvestigationCase) {
            /* pursue criminal charges under MEDICRIME */
        }
        operation executeSeizure(order : SeizureOrder) {
            /* confiscate counterfeit goods */
        }
    }

    part def CustomsAuthority {
        port enforcement : EnforcementPort;
        attribute executedOrders : SeizureOrder[0..*];
        operation confiscate(order : SeizureOrder) {
            /* intercept and confiscate goods at borders */
        }
    }

    part def PublicHealthAgency {
        port healthReception : HealthReceptionPort;
        port alertOut : HealthAlertPort;
        attribute issuedAlerts : PublicAlert[0..*];
        operation assessDanger(decision : CaseDecision) : RiskAssessment {
            /* assess danger to public */
        }
        operation issueAlert(product : SuspectProduct, regions : String[0..*]) : PublicAlert {
            /* issue public alert */
        }
    }

    part def InternationalCooperationHub {
        port intlReception : InternationalReceptionPort;
        port intlOut : InternationalPort;
        attribute partnerCountries : String[0..*];
        attribute sentNotifications : InternationalNotification[0..*];
        operation notifyPartners(caseRef : String, details : String) : InternationalNotification {
            /* share case details with partner countries and bodies */
        }
    }

    part def NationalCompetentAuthority {
        port reportIn : ReportReceptionPort;
        port labPort : LabRequestPort;
        port decisionOut : DecisionPort;
        port investigationOut : InvestigationPort;
        port healthOut : HealthAlertPort;
        port intlOut : InternationalPort;
        port evidenceOut : EvidencePort;

        attribute receivedReports : ProductReport[0..*];
        attribute validatedReports : ProductReport[0..*];
        attribute activeCases : InvestigationCase[0..*];
        attribute chainRecords : ChainOfCustodyRecord[0..*];

        state NCAProcessing {
            entry; then Monitoring;
            state Monitoring;
            transition Monitoring->Validating
                when reportIn.productReports->notEmpty();
            state Validating {
                entry validateReport();
                do validateReport();
            }
            transition Validating->Verifying
                when isValidated;
            transition Validating->Monitoring
                when not isCredible;
            state Verifying {
                entry sendToLab();
            }
            transition Verifying->Analyzing
                when labPort.labResults->notEmpty();
            state Analyzing {
                entry performRiskAssessment();
            }
            transition Analyzing->Deciding
                when riskAssessmentComplete;
            state Deciding {
                entry makeDecision();
            }
            transition Deciding->Investigating
                when decision.authenticity == AuthenticityResult::counterfeit;
            transition Deciding->Closed
                when decision.authenticity == AuthenticityResult::genuine;
            state Investigating {
                entry openCase();
                entry issueSeizureOrder();
            }
            transition Investigating->Responding;
            state Responding {
                entry issuePublicAlert();
            }
            transition Responding->Coordinating;
            state Coordinating {
                entry notifyInternational();
            }
            transition Coordinating->Resolved;
            state Resolved;
            transition Resolved->Closed;
            state Closed;
        }

        operation validateReport() {
            /* validate report credibility */
        }
        operation sendToLab() {
            /* send suspect product to forensic lab */
        }
        operation performRiskAssessment() {
            /* perform initial risk assessment */
        }
        operation makeDecision() {
            /* decide based on lab findings and risk */
        }
        operation openCase() {
            /* open formal investigation case */
        }
        operation issueSeizureOrder() {
            /* issue seizure order */
        }
        operation issuePublicAlert() {
            /* trigger public health alert */
        }
        operation notifyInternational() {
            /* notify international partners */
        }
    }

    part def MEDICRIMEFramework {
        part publicPortal : PublicPortal;
        part nca : NationalCompetentAuthority;
        part forensicLab : ForensicLaboratory;
        part lawEnforcement : LawEnforcementUnit;
        part customs : CustomsAuthority;
        part publicHealth : PublicHealthAgency;
        part intlHub : InternationalCooperationHub;

        connection publicPortal.reportOut.productReports to nca.reportIn.productReports;
        connection nca.labPort.labRequests to forensicLab.labService.labRequests;
        connection forensicLab.labService.labResults to nca.labPort.labResults;
        connection nca.decisionOut.decisions to publicHealth.healthReception.decisions;
        connection nca.investigationOut.investigationCases to lawEnforcement.enforcement.investigationCases;
        connection nca.investigationOut.seizureOrders to lawEnforcement.enforcement.seizureOrders;
        connection nca.investigationOut.seizureOrders to customs.enforcement.seizureOrders;
        connection publicHealth.alertOut.publicAlerts to nca.healthOut.publicAlerts;
        connection nca.intlOut.notifications to intlHub.intlReception.notifications;
        connection nca.evidenceOut.chainRecords to lawEnforcement.enforcement;
    }

    // ===== Requirements =====
    requirement def ProcessingTimeRequirement {
        attribute maxHours : TimeHours = 2;
        subject report : ProductReport;
        objective {
            doc /* High-urgency reports must be processed within two hours */
            assert report.urgency == UrgencyLevel::high implies
                processingDuration(report) <= maxHours
        }
    }

    requirement def ChainOfCustodyRequirement {
        subject evidence : EvidenceItem;
        objective {
            doc /* Maintain complete and secure chain of custody for all evidence */
            assert evidence.hash->notEmpty() and chainSealed(evidence)
        }
    }

    requirement def ReportValidationRequirement {
        subject report : ProductReport;
        objective {
            doc /* NCA must validate every submitted report */
            assert validated(report)
        }
    }

    requirement def ForensicVerificationRequirement {
        subject product : SuspectProduct;
        objective {
            doc /* Suspect products must be sent to forensic lab for authenticity analysis */
            assert analyzed(product)
        }
    }

    requirement def CounterfeitResponseRequirement {
        subject decision : CaseDecision;
        objective {
            doc /* Counterfeit products trigger investigation, seizure, public alert, and international notification */
            assert decision.authenticity == AuthenticityResult::counterfeit implies
                investigationOpened(decision) and seizureOrdered(decision) and
                alertIssued(decision) and partnersNotified(decision)
        }
    }

    requirement def InternationalNotificationRequirement {
        subject notification : InternationalNotification;
        objective {
            doc /* NCA must notify partner countries and international bodies about counterfeit threats */
            assert notification.recipientCountries->notEmpty() and
                notification.recipientBodies->notEmpty()
        }
    }

    requirement def PublicAlertRequirement {
        subject alert : PublicAlert;
        objective {
            doc /* Public alerts must specify product, risks, and affected regions */
            assert alert.product->notEmpty() and alert.riskSummary->notEmpty() and
                alert.affectedRegions->notEmpty()
        }
    }

    requirement MEDICRIMEConventionImplementation {
        subject framework : MEDICRIMEFramework;
        satisfy ProcessingTimeRequirement;
        satisfy ChainOfCustodyRequirement;
        satisfy ReportValidationRequirement;
        satisfy ForensicVerificationRequirement;
        satisfy CounterfeitResponseRequirement;
        satisfy InternationalNotificationRequirement;
        satisfy PublicAlertRequirement;
        objective {
            doc /* Implement Council of Europe MEDICRIME Convention for combating counterfeit medical products */
        }
    }

}
