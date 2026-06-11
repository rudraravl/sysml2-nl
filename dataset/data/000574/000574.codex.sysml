package CouncilOfEuropeMedicalProductCounterfeitingModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Probability : Real {
        :>> unit = one;
    }

    attribute def RiskScore : Real {
        :>> unit = one;
    }

    attribute def Count : Integer {
        :>> unit = one;
    }

    attribute def DurationHours : Real {
        :>> unit = h;
    }

    attribute def MassMilligram : Real {
        :>> unit = mg;
    }

    attribute def TemperatureCelsius : Real {
        :>> unit = degC;
    }

    enum def ProductCategory {
        enum medicinalProduct;
        enum medicalDevice;
        enum activeSubstance;
        enum excipient;
        enum accessory;
        enum packaging;
        enum document;
    }

    enum def CaseStatus {
        enum reported;
        enum triaged;
        enum investigated;
        enum evidenceSecured;
        enum prosecutionPrepared;
        enum closed;
    }

    enum def VerificationResult {
        enum authentic;
        enum suspectedCounterfeit;
        enum confirmedCounterfeit;
        enum inconclusive;
    }

    enum def EnforcementAction {
        enum quarantine;
        enum recall;
        enum seizure;
        enum borderDetention;
        enum publicAlert;
        enum prosecutionReferral;
    }

    item def MedicalProduct {
        attribute productIdentifier : String;
        attribute category : ProductCategory;
        attribute batchNumber : String;
        attribute manufacturerName : String;
        attribute marketAuthorizationNumber : String;
        attribute declaredActiveIngredientMass : MassMilligram;
        attribute requiredStorageTemperature : TemperatureCelsius;
    }

    item def ProductPackage {
        attribute packageIdentifier : String;
        attribute tamperEvidencePresent : Boolean;
        attribute serializationCode : String;
        attribute leafletLanguage : String;
    }

    item def AuthenticityEvidence {
        attribute evidenceIdentifier : String;
        attribute chainOfCustodyReference : String;
        attribute packagingMismatchDetected : Boolean;
        attribute chemicalMismatchDetected : Boolean;
        attribute documentIrregularityDetected : Boolean;
        attribute assessedCounterfeitProbability : Probability;
        attribute assessedPublicHealthRisk : RiskScore;
    }

    item def CaseReport {
        attribute reportIdentifier : String;
        attribute reportingParty : String;
        attribute suspectedOffenceDescription : String;
        attribute status : CaseStatus;
        attribute reportedProductCount : Count;
        attribute initialRiskScore : RiskScore;
    }

    item def AlertNotice {
        attribute alertIdentifier : String;
        attribute affectedBatchNumber : String;
        attribute publicHealthAdvice : String;
        attribute recallRequired : Boolean;
        attribute targetAudience : String;
    }

    item def MutualAssistanceRequest {
        attribute requestIdentifier : String;
        attribute requestingState : String;
        attribute requestedState : String;
        attribute legalBasis : String;
        attribute requestedAction : EnforcementAction;
        attribute responseDueIn : DurationHours;
    }

    item def ProsecutionFile {
        attribute fileIdentifier : String;
        attribute allegedOffence : String;
        attribute suspectIdentityKnown : Boolean;
        attribute evidenceCompletenessScore : RiskScore;
        attribute crossBorderElementsPresent : Boolean;
    }

    port def ProductIntakePort {
        in item product : MedicalProduct;
        in item package : ProductPackage;
    }

    port def ReportPort {
        in item report : CaseReport;
    }

    port def EvidencePort {
        in item evidence : AuthenticityEvidence;
        out item evidenceOut : AuthenticityEvidence;
    }

    port def AlertPort {
        out item alert : AlertNotice;
    }

    port def CooperationPort {
        out item request : MutualAssistanceRequest;
        in item response : MutualAssistanceRequest;
    }

    port def ProsecutionPort {
        out item prosecutionFile : ProsecutionFile;
    }

    action def ReceiveSuspicion {
        in item incomingReport : CaseReport;
        out item acceptedReport : CaseReport;
    }

    action def VerifyMedicalProduct {
        in item product : MedicalProduct;
        in item package : ProductPackage;
        out item evidence : AuthenticityEvidence;
        out result : VerificationResult;
    }

    action def AssessPublicHealthRisk {
        in item evidence : AuthenticityEvidence;
        in affectedProductCount : Count;
        out risk : RiskScore;
    }

    action def ApplyProtectiveMeasure {
        in actionType : EnforcementAction;
        in item evidence : AuthenticityEvidence;
        out measureRecorded : Boolean;
    }

    action def NotifyPublicAndAuthorities {
        in item evidence : AuthenticityEvidence;
        in risk : RiskScore;
        out item alert : AlertNotice;
    }

    action def RequestInternationalCooperation {
        in item evidence : AuthenticityEvidence;
        out item request : MutualAssistanceRequest;
    }

    action def PrepareProsecution {
        in item report : CaseReport;
        in item evidence : AuthenticityEvidence;
        out item prosecutionFile : ProsecutionFile;
    }

    state def CounterfeitCaseLifecycle {
        entry action ReceiveSuspicion;

        state awaitingReport;
        state triaging;
        state samplingAndVerification;
        state riskAssessment;
        state protectiveMeasures;
        state internationalCooperation;
        state prosecutionPreparation;
        state closure;

        transition first awaitingReport then triaging
            accept CaseReport;

        transition first triaging then samplingAndVerification
            if initialRiskScore >= 0.25;

        transition first triaging then closure
            if initialRiskScore < 0.25;

        transition first samplingAndVerification then riskAssessment
            if result == VerificationResult::suspectedCounterfeit or result == VerificationResult::confirmedCounterfeit;

        transition first samplingAndVerification then closure
            if result == VerificationResult::authentic;

        transition first riskAssessment then protectiveMeasures
            if risk >= 0.40;

        transition first riskAssessment then prosecutionPreparation
            if risk < 0.40;

        transition first protectiveMeasures then internationalCooperation
            if evidence.chainOfCustodyReference != "";

        transition first internationalCooperation then prosecutionPreparation;

        transition first prosecutionPreparation then closure;
    }

    part def NationalMedicinesAuthority {
        port reports : ReportPort;
        port intake : ProductIntakePort;
        port evidenceExchange : EvidencePort;
        port alerts : AlertPort;

        perform action receiveSuspicion : ReceiveSuspicion;
        perform action verifyProduct : VerifyMedicalProduct;
        perform action assessRisk : AssessPublicHealthRisk;
        perform action notify : NotifyPublicAndAuthorities;

        attribute maximumInitialTriageTime : DurationHours = 24[h];
        attribute minimumAlertRiskThreshold : RiskScore = 0.60;
    }

    part def LawEnforcementAuthority {
        port evidenceInput : EvidencePort;
        port prosecutionOutput : ProsecutionPort;

        perform action protectiveMeasure : ApplyProtectiveMeasure;
        perform action prepareProsecution : PrepareProsecution;

        attribute evidenceRetentionPeriod : DurationHours = 87600[h];
        attribute seizureAuthorityEnabled : Boolean = true;
    }

    part def CustomsBorderAuthority {
        port intake : ProductIntakePort;
        port evidenceOutput : EvidencePort;

        perform action borderVerification : VerifyMedicalProduct;

        attribute detainedShipmentCount : Count;
        attribute inspectionSamplingRatio : Probability = 0.15;
    }

    part def AccreditedLaboratory {
        port sampleInput : ProductIntakePort;
        port analyticalEvidence : EvidencePort;

        perform action analyticalVerification : VerifyMedicalProduct;

        attribute assayUncertainty : Probability = 0.03;
        attribute maximumAnalysisTime : DurationHours = 72[h];
    }

    part def PublicHealthAlertService {
        port alertInput : AlertPort;

        attribute maximumPublicationTime : DurationHours = 6[h];
        attribute multilingualPublicationRequired : Boolean = true;
    }

    part def InternationalCooperationOffice {
        port cooperation : CooperationPort;
        port evidenceInput : EvidencePort;

        perform action requestCooperation : RequestInternationalCooperation;

        attribute defaultResponseDeadline : DurationHours = 168[h];
        attribute conventionLegalBasis : String = "Council of Europe Convention on the Counterfeiting of Medical Products and Similar Crimes involving Threats to Public Health";
    }

    part def JudicialAuthority {
        port prosecutionInput : ProsecutionPort;

        attribute criminalizationAppliesToManufacturing : Boolean = true;
        attribute criminalizationAppliesToSupplying : Boolean = true;
        attribute criminalizationAppliesToDocumentForgery : Boolean = true;
        attribute victimProtectionRequired : Boolean = true;
    }

    part def SecureCaseRepository {
        port evidenceStore : EvidencePort;
        port prosecutionStore : ProsecutionPort;

        attribute auditLoggingEnabled : Boolean = true;
        attribute accessControlRequired : Boolean = true;
        attribute caseRecordRetention : DurationHours = 87600[h];
    }

    part def MedicalProductCounterfeitingProtectionSystem {
        doc /* High-level primary function: prevent, detect, investigate, and support prosecution of counterfeiting of medical products and similar crimes that threaten public health, while enabling protective measures, public alerts, victim protection, and international cooperation under the Council of Europe convention. */

        part medicinesAuthority : NationalMedicinesAuthority;
        part lawEnforcement : LawEnforcementAuthority;
        part customs : CustomsBorderAuthority;
        part laboratory : AccreditedLaboratory;
        part alertService : PublicHealthAlertService;
        part cooperationOffice : InternationalCooperationOffice;
        part judiciary : JudicialAuthority;
        part repository : SecureCaseRepository;

        port externalReports : ReportPort;
        port borderProductInput : ProductIntakePort;
        port suspectProductInput : ProductIntakePort;
        port outboundAlerts : AlertPort;
        port internationalRequests : CooperationPort;
        port prosecutionSubmissions : ProsecutionPort;

        connection reportFlow connect externalReports to medicinesAuthority.reports;
        connection authorityProductFlow connect suspectProductInput to medicinesAuthority.intake;
        connection borderProductFlow connect borderProductInput to customs.intake;
        connection customsEvidenceFlow connect customs.evidenceOutput to medicinesAuthority.evidenceExchange;
        connection labSampleFlow connect medicinesAuthority.intake to laboratory.sampleInput;
        connection labEvidenceFlow connect laboratory.analyticalEvidence to medicinesAuthority.evidenceExchange;
        connection authorityEvidenceToLawEnforcement connect medicinesAuthority.evidenceExchange to lawEnforcement.evidenceInput;
        connection evidenceArchiveFlow connect medicinesAuthority.evidenceExchange to repository.evidenceStore;
        connection lawEnforcementProsecutionFlow connect lawEnforcement.prosecutionOutput to repository.prosecutionStore;
        connection prosecutionSubmissionFlow connect lawEnforcement.prosecutionOutput to prosecutionSubmissions;
        connection judiciarySubmissionFlow connect prosecutionSubmissions to judiciary.prosecutionInput;
        connection publicAlertFlow connect medicinesAuthority.alerts to alertService.alertInput;
        connection externalAlertFlow connect medicinesAuthority.alerts to outboundAlerts;
        connection cooperationEvidenceFlow connect medicinesAuthority.evidenceExchange to cooperationOffice.evidenceInput;
        connection internationalCooperationFlow connect cooperationOffice.cooperation to internationalRequests;

        exhibit state caseLifecycle : CounterfeitCaseLifecycle;
    }

    requirement def ConventionPurposeRequirement {
        doc /* The system shall protect public health by preventing and combating counterfeiting of medical products and similar crimes through criminalization, prevention, investigation, prosecution support, cooperation, and protection of victims. */
    }

    requirement def CriminalizationRequirement {
        doc /* The system shall support identification of intentional manufacturing, supplying, offering to supply, trafficking, falsification of documents, and unauthorized manufacture or supply of medical products as prosecutable offences. */
    }

    requirement def AuthenticityVerificationRequirement {
        doc /* The system shall verify suspect medical products by evaluating product identity, packaging, serialization, documentation, and laboratory evidence. */
    }

    requirement def PublicHealthProtectionRequirement {
        doc /* The system shall initiate quarantine, recall, seizure, detention, or public alert measures when assessed public health risk exceeds the defined operational threshold. */
    }

    requirement def InternationalCooperationRequirement {
        doc /* The system shall prepare and exchange mutual assistance requests with other states when a suspected offence has cross-border elements. */
    }

    requirement def EvidenceIntegrityRequirement {
        doc /* The system shall maintain chain of custody, audit logging, access control, and long-term retention for evidence and prosecution records. */
    }

    requirement def VictimProtectionRequirement {
        doc /* The system shall preserve information needed to identify harmed persons, communicate public health advice, and support victim protection measures. */
    }

    requirement def TimelinessRequirement {
        doc /* The system shall complete initial triage within 24 hours, laboratory analysis within 72 hours, and urgent public alert publication within 6 hours after alert authorization. */
    }

    satisfy ConventionPurposeRequirement by MedicalProductCounterfeitingProtectionSystem;
    satisfy CriminalizationRequirement by JudicialAuthority;
    satisfy AuthenticityVerificationRequirement by NationalMedicinesAuthority;
    satisfy AuthenticityVerificationRequirement by AccreditedLaboratory;
    satisfy PublicHealthProtectionRequirement by NationalMedicinesAuthority;
    satisfy PublicHealthProtectionRequirement by LawEnforcementAuthority;
    satisfy InternationalCooperationRequirement by InternationalCooperationOffice;
    satisfy EvidenceIntegrityRequirement by SecureCaseRepository;
    satisfy VictimProtectionRequirement by PublicHealthAlertService;
    satisfy TimelinessRequirement by NationalMedicinesAuthority;
    satisfy TimelinessRequirement by AccreditedLaboratory;
    satisfy TimelinessRequirement by PublicHealthAlertService;
}