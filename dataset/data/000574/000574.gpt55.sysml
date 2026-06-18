package CouncilOfEuropeMEDICRIMEConventionModel {
    private import ScalarValues::*;

    unit def percent;
    unit def item;
    unit def day;
    unit def hour;
    unit def degreeCelsius;
    unit def kilometre;
    unit def euro;

    attribute def Text :> String;
    attribute def ProductIdentifier :> String;
    attribute def BatchNumber :> String;
    attribute def SerialNumber :> String;
    attribute def OrganizationIdentifier :> String;
    attribute def CaseIdentifier :> String;
    attribute def CountryCode :> String;
    attribute def DateTimeStamp :> String;

    attribute def QuantityEach :> Integer {
        attribute unitSymbol : Text = "item";
    }

    attribute def DurationHours :> Real {
        attribute unitSymbol : Text = "h";
    }

    attribute def DurationDays :> Real {
        attribute unitSymbol : Text = "d";
    }

    attribute def TemperatureCelsius :> Real {
        attribute unitSymbol : Text = "degC";
    }

    attribute def DistanceKilometres :> Real {
        attribute unitSymbol : Text = "km";
    }

    attribute def MonetaryValueEuro :> Real {
        attribute unitSymbol : Text = "EUR";
    }

    attribute def RiskScorePercent :> Real {
        attribute unitSymbol : Text = "%";
        constraint validRiskScore {
            0.0 <= self and self <= 100.0
        }
    }

    enum def ProductKind {
        enum medicinalProduct;
        enum activeSubstance;
        enum excipient;
        enum medicalDevice;
        enum deviceAccessory;
        enum veterinaryMedicalProduct;
    }

    enum def SupplyChainRoleKind {
        enum manufacturer;
        enum importer;
        enum wholesaler;
        enum distributor;
        enum pharmacy;
        enum hospital;
        enum onlineSeller;
        enum carrier;
        enum customsPoint;
    }

    enum def AuthenticationDecisionKind {
        enum genuine;
        enum notFound;
        enum duplicateIdentifier;
        enum tamperEvidenceDetected;
        enum temperatureExcursionDetected;
        enum counterfeitSuspected;
        enum counterfeitConfirmed;
        enum inconclusive;
    }

    enum def CasePriorityKind {
        enum routine;
        enum elevated;
        enum urgentPublicHealthThreat;
        enum crossBorderOrganizedCrime;
    }

    enum def LegalOutcomeKind {
        enum noOffenceEstablished;
        enum administrativeMeasure;
        enum criminalInvestigationOpened;
        enum prosecutionFiled;
        enum conviction;
        enum acquittal;
        enum internationalAssistancePending;
    }

    item def MedicalProduct {
        attribute productId : ProductIdentifier;
        attribute batch : BatchNumber;
        attribute serial : SerialNumber;
        attribute productKind : ProductKind;
        attribute manufacturerId : OrganizationIdentifier;
        attribute marketingAuthorizationHolderId : OrganizationIdentifier;
        attribute countryOfOrigin : CountryCode;
        attribute expiryDate : DateTimeStamp;
        attribute unitCount : QuantityEach;
        attribute requiredStorageMinimum : TemperatureCelsius;
        attribute requiredStorageMaximum : TemperatureCelsius;
        attribute authorizedForMarket : Boolean;
    }

    item def MedicalProductPackage {
        attribute packageId : ProductIdentifier;
        attribute packageSerial : SerialNumber;
        attribute tamperSealPresent : Boolean;
        attribute tamperSealIntact : Boolean;
        attribute safetyFeatureCode : Text;
        attribute leafletLanguageCode : CountryCode;
        item containedProduct : MedicalProduct;
    }

    item def AuthenticationQuery {
        attribute queryId : Text;
        attribute requestingOrganization : OrganizationIdentifier;
        attribute requesterRole : SupplyChainRoleKind;
        attribute queryTime : DateTimeStamp;
        attribute observedProductId : ProductIdentifier;
        attribute observedBatch : BatchNumber;
        attribute observedSerial : SerialNumber;
        attribute observedPackageCode : Text;
        attribute observedTemperature : TemperatureCelsius;
    }

    item def AuthenticationResponse {
        attribute responseId : Text;
        attribute decision : AuthenticationDecisionKind;
        attribute decisionTime : DateTimeStamp;
        attribute confidence : RiskScorePercent;
        attribute recommendedQuarantine : Boolean;
        attribute recommendedReportToAuthority : Boolean;
        attribute explanatoryFinding : Text;
    }

    item def SuspectProductReport {
        attribute reportId : Text;
        attribute reportingOrganization : OrganizationIdentifier;
        attribute reportingRole : SupplyChainRoleKind;
        attribute reportTime : DateTimeStamp;
        attribute locationCountry : CountryCode;
        attribute locationDescription : Text;
        attribute groundsForSuspicion : Text;
        attribute immediatePublicHealthRisk : RiskScorePercent;
        item suspectPackage : MedicalProductPackage;
        item authenticationResponse : AuthenticationResponse;
    }

    item def InspectionResult {
        attribute inspectionId : Text;
        attribute inspectorOrganization : OrganizationIdentifier;
        attribute inspectionTime : DateTimeStamp;
        attribute siteOrganization : OrganizationIdentifier;
        attribute inspectedRole : SupplyChainRoleKind;
        attribute nonCompliantUnitsFound : QuantityEach;
        attribute documentsIrregular : Boolean;
        attribute onlineOfferDetected : Boolean;
        attribute recommendedEnforcementAction : Text;
    }

    item def LaboratoryTestRequest {
        attribute requestId : Text;
        attribute requestedByAuthority : OrganizationIdentifier;
        attribute requestTime : DateTimeStamp;
        attribute requiredTurnaround : DurationHours;
        attribute suspectedCompositionDeviation : Text;
        item samplePackage : MedicalProductPackage;
    }

    item def LaboratoryTestResult {
        attribute resultId : Text;
        attribute laboratoryOrganization : OrganizationIdentifier;
        attribute resultTime : DateTimeStamp;
        attribute activeIngredientIdentityMatches : Boolean;
        attribute activeIngredientQuantityMatches : Boolean;
        attribute sterileWhenRequired : Boolean;
        attribute packagingAuthentic : Boolean;
        attribute counterfeitConfirmed : Boolean;
        attribute healthHazardScore : RiskScorePercent;
        attribute analyticalSummary : Text;
    }

    item def PublicHealthAlert {
        attribute alertId : Text;
        attribute issuingAuthority : OrganizationIdentifier;
        attribute issueTime : DateTimeStamp;
        attribute affectedCountries : Text;
        attribute affectedBatches : Text;
        attribute recommendedPatientAction : Text;
        attribute recommendedProfessionalAction : Text;
        attribute urgency : CasePriorityKind;
    }

    item def RecallOrder {
        attribute recallId : Text;
        attribute issuingAuthority : OrganizationIdentifier;
        attribute issueTime : DateTimeStamp;
        attribute mandatory : Boolean;
        attribute affectedProductIds : Text;
        attribute affectedBatches : Text;
        attribute returnDeadline : DurationDays;
        attribute destructionAuthorized : Boolean;
    }

    item def EvidencePackage {
        attribute evidenceId : Text;
        attribute collectedBy : OrganizationIdentifier;
        attribute collectionTime : DateTimeStamp;
        attribute chainOfCustodyRecord : Text;
        attribute storageTemperature : TemperatureCelsius;
        attribute sealed : Boolean;
        attribute admissibleForCriminalProceeding : Boolean;
        item seizedPackage : MedicalProductPackage;
        item labResult : LaboratoryTestResult;
    }

    item def CriminalCaseFile {
        attribute caseId : CaseIdentifier;
        attribute openingAuthority : OrganizationIdentifier;
        attribute openingTime : DateTimeStamp;
        attribute priority : CasePriorityKind;
        attribute suspectedOffences : Text;
        attribute crossBorderElementsPresent : Boolean;
        attribute estimatedIllegalRevenue : MonetaryValueEuro;
        attribute outcome : LegalOutcomeKind;
        item evidence : EvidencePackage;
    }

    item def InternationalCooperationRequest {
        attribute requestId : Text;
        attribute requestingCountry : CountryCode;
        attribute requestedCountry : CountryCode;
        attribute requestTime : DateTimeStamp;
        attribute legalBasis : Text;
        attribute requestedAction : Text;
        attribute urgentPublicHealthThreat : Boolean;
        attribute responseDueIn : DurationHours;
        item relatedCase : CriminalCaseFile;
    }

    item def VictimSupportReferral {
        attribute referralId : Text;
        attribute referringAuthority : OrganizationIdentifier;
        attribute referralTime : DateTimeStamp;
        attribute patientIdentifierPseudonym : Text;
        attribute suspectedExposureProductId : ProductIdentifier;
        attribute clinicalRiskSummary : Text;
        attribute informedOfRights : Boolean;
        attribute medicalFollowUpRequired : Boolean;
    }

    port def VerificationPort {
        inout item query : AuthenticationQuery;
        inout item response : AuthenticationResponse;
    }

    port def ProductCustodyPort {
        inout item package : MedicalProductPackage;
        inout item recall : RecallOrder;
    }

    port def ReportingPort {
        inout item suspectReport : SuspectProductReport;
        inout item inspectionResult : InspectionResult;
    }

    port def LaboratoryPort {
        inout item testRequest : LaboratoryTestRequest;
        inout item testResult : LaboratoryTestResult;
    }

    port def AlertPort {
        inout item alert : PublicHealthAlert;
        inout item recall : RecallOrder;
    }

    port def EvidencePort {
        inout item evidence : EvidencePackage;
        inout item caseFile : CriminalCaseFile;
    }

    port def CooperationPort {
        inout item cooperationRequest : InternationalCooperationRequest;
        inout item caseFile : CriminalCaseFile;
        inout item alert : PublicHealthAlert;
    }

    port def VictimSupportPort {
        inout item referral : VictimSupportReferral;
        inout item alert : PublicHealthAlert;
    }

    part def LegalFramework {
        attribute conventionName : Text = "Council of Europe Convention on the counterfeiting of medical products and similar crimes involving threats to public health";
        attribute shortName : Text = "MEDICRIME Convention";
        attribute primaryFunction : Text = "Prevent and combat threats to public health by criminalising counterfeiting and similar crimes involving medical products, enabling detection and reporting, coordinating investigation and prosecution, supporting international cooperation, and protecting victims.";
        attribute counterfeitingOffenceDefined : Boolean = true;
        attribute supplyingCounterfeitOffenceDefined : Boolean = true;
        attribute falsificationOfDocumentsOffenceDefined : Boolean = true;
        attribute aidingAndAbettingLiabilityDefined : Boolean = true;
        attribute corporateLiabilityDefined : Boolean = true;
        attribute victimProtectionRequired : Boolean = true;
        attribute internationalCooperationRequired : Boolean = true;
        attribute publicHealthProtectionObjective : Boolean = true;
    }

    part def TraceabilityRegistry {
        attribute registryOperator : OrganizationIdentifier;
        attribute targetLookupTime : DurationHours = 0.01;
        attribute maximumDuplicateSerialRisk : RiskScorePercent = 1.0;
        attribute registeredProductRecords : QuantityEach;
        port manufacturerVerification : VerificationPort;
        port distributorVerification : VerificationPort;
        port pharmacyVerification : VerificationPort;
        port customsVerification : VerificationPort;
    }

    part def Manufacturer {
        attribute organizationId : OrganizationIdentifier;
        attribute role : SupplyChainRoleKind = SupplyChainRoleKind::manufacturer;
        attribute authorizedManufacturer : Boolean = true;
        port productOut : ProductCustodyPort;
        port verification : VerificationPort;
        port reportOut : ReportingPort;
    }

    part def Distributor {
        attribute organizationId : OrganizationIdentifier;
        attribute role : SupplyChainRoleKind = SupplyChainRoleKind::distributor;
        attribute authorizedDistributor : Boolean = true;
        attribute maximumTransportTemperature : TemperatureCelsius = 8.0;
        port productIn : ProductCustodyPort;
        port productOut : ProductCustodyPort;
        port verification : VerificationPort;
        port reportOut : ReportingPort;
    }

    part def PharmacyOrHospital {
        attribute organizationId : OrganizationIdentifier;
        attribute role : SupplyChainRoleKind = SupplyChainRoleKind::pharmacy;
        attribute dispensesToPatients : Boolean = true;
        port productIn : ProductCustodyPort;
        port verification : VerificationPort;
        port reportOut : ReportingPort;
        port victimSupport : VictimSupportPort;
        port alertIn : AlertPort;
    }

    part def CustomsAuthority {
        attribute organizationId : OrganizationIdentifier;
        attribute jurisdictionCountry : CountryCode;
        attribute borderInspectionRadius : DistanceKilometres = 0.0;
        port detainedProduct : ProductCustodyPort;
        port verification : VerificationPort;
        port reportOut : ReportingPort;
        port evidenceOut : EvidencePort;
        port cooperation : CooperationPort;
    }

    part def HealthAuthority {
        attribute organizationId : OrganizationIdentifier;
        attribute jurisdictionCountry : CountryCode;
        attribute maximumInitialTriageTime : DurationHours = 24.0;
        attribute maximumPublicAlertTimeAfterConfirmation : DurationHours = 4.0;
        port reportIn : ReportingPort;
        port laboratory : LaboratoryPort;
        port alertOut : AlertPort;
        port evidenceOut : EvidencePort;
        port cooperation : CooperationPort;
        port victimSupport : VictimSupportPort;
    }

    part def AccreditedLaboratory {
        attribute organizationId : OrganizationIdentifier;
        attribute accreditedForMedicines : Boolean = true;
        attribute accreditedForMedicalDevices : Boolean = true;
        attribute targetAnalysisTime : DurationHours = 48.0;
        port test : LaboratoryPort;
        port evidenceOut : EvidencePort;
    }

    part def LawEnforcementAgency {
        attribute organizationId : OrganizationIdentifier;
        attribute specializedMedicalProductCrimeUnit : Boolean = true;
        attribute maximumCaseOpeningTime : DurationHours = 24.0;
        port evidenceIn : EvidencePort;
        port cooperation : CooperationPort;
    }

    part def ProsecutorialAuthority {
        attribute organizationId : OrganizationIdentifier;
        attribute criminalProceedingCompetence : Boolean = true;
        port caseIn : EvidencePort;
        port cooperation : CooperationPort;
    }

    part def InternationalCooperationHub {
        attribute organizationId : OrganizationIdentifier;
        attribute operatesTwentyFourSeven : Boolean = true;
        attribute maximumUrgentRoutingTime : DurationHours = 2.0;
        port nationalCooperation : CooperationPort;
        port foreignCooperation : CooperationPort;
        port alerts : AlertPort;
    }

    part def PublicAlertService {
        attribute organizationId : OrganizationIdentifier;
        attribute supportsPatients : Boolean = true;
        attribute supportsProfessionals : Boolean = true;
        attribute maximumPublicationDelay : DurationHours = 1.0;
        port alertIn : AlertPort;
        port alertOut : AlertPort;
    }

    part def VictimSupportService {
        attribute organizationId : OrganizationIdentifier;
        attribute providesInformationOnRights : Boolean = true;
        attribute providesMedicalReferral : Boolean = true;
        attribute preservesConfidentiality : Boolean = true;
        port support : VictimSupportPort;
    }

    part def RiskAnalyticsService {
        attribute organizationId : OrganizationIdentifier;
        attribute highRiskThreshold : RiskScorePercent = 70.0;
        attribute urgentRiskThreshold : RiskScorePercent = 90.0;
        port reports : ReportingPort;
        port alerts : AlertPort;
        port cooperation : CooperationPort;
    }

    action def AuthenticateMedicalProduct {
        in item authenticationQuery : AuthenticationQuery;
        out item authenticationResponse : AuthenticationResponse;

        action receiveQuery;
        action compareIdentifierWithRegistry;
        action checkDuplicateSerialUse;
        action evaluateTamperSeal;
        action evaluateTemperatureExcursion;
        action classifyAuthenticationDecision;
        action recommendQuarantineAndReporting;

        first receiveQuery;
        then compareIdentifierWithRegistry;
        then checkDuplicateSerialUse;
        then evaluateTamperSeal;
        then evaluateTemperatureExcursion;
        then classifyAuthenticationDecision;
        then recommendQuarantineAndReporting;
    }

    action def TriageSuspectProductReport {
        in item suspectReport : SuspectProductReport;
        out attribute priority : CasePriorityKind;
        out item laboratoryRequest : LaboratoryTestRequest;

        action receiveReport;
        action validateReporterAndLocation;
        action scoreImmediatePublicHealthRisk;
        action determineCrossBorderIndicators;
        action assignPriority;
        action requestLaboratoryTesting;

        first receiveReport;
        then validateReporterAndLocation;
        then scoreImmediatePublicHealthRisk;
        then determineCrossBorderIndicators;
        then assignPriority;
        then requestLaboratoryTesting;
    }

    action def AnalyzeSampleForCounterfeit {
        in item laboratoryRequest : LaboratoryTestRequest;
        out item laboratoryResult : LaboratoryTestResult;
        out item evidence : EvidencePackage;

        action receiveSealedSample;
        action verifyChainOfCustody;
        action testIdentityAndStrength;
        action inspectPackagingAndDocuments;
        action assessSterilityAndSafety;
        action concludeCounterfeitStatus;
        action sealEvidencePackage;

        first receiveSealedSample;
        then verifyChainOfCustody;
        then testIdentityAndStrength;
        then inspectPackagingAndDocuments;
        then assessSterilityAndSafety;
        then concludeCounterfeitStatus;
        then sealEvidencePackage;
    }

    action def CoordinateEnforcementResponse {
        in item laboratoryResult : LaboratoryTestResult;
        in item suspectReport : SuspectProductReport;
        out item alert : PublicHealthAlert;
        out item recall : RecallOrder;
        out item caseFile : CriminalCaseFile;
        out item victimReferral : VictimSupportReferral;

        action determineThreatToPublicHealth;
        action initiateRecallIfNeeded;
        action issuePublicHealthAlert;
        action preserveEvidence;
        action openCriminalCase;
        action notifyVictimSupport;
        action routeToLawEnforcementAndProsecutor;

        first determineThreatToPublicHealth;
        then initiateRecallIfNeeded;
        then issuePublicHealthAlert;
        then preserveEvidence;
        then openCriminalCase;
        then notifyVictimSupport;
        then routeToLawEnforcementAndProsecutor;
    }

    action def RequestInternationalCooperation {
        in item caseFile : CriminalCaseFile;
        out item cooperationRequest : InternationalCooperationRequest;

        action identifyForeignElements;
        action selectRequestedState;
        action defineRequestedAction;
        action assertConventionLegalBasis;
        action transmitUrgentRequest;
        action trackResponseDeadline;

        first identifyForeignElements;
        then selectRequestedState;
        then defineRequestedAction;
        then assertConventionLegalBasis;
        then transmitUrgentRequest;
        then trackResponseDeadline;
    }

    action def OperateMEDICRIMEProtectionSystem {
        in item productPackage : MedicalProductPackage;
        in item authenticationQuery : AuthenticationQuery;
        out item authenticationResponse : AuthenticationResponse;
        out item alert : PublicHealthAlert;
        out item caseFile : CriminalCaseFile;

        action authenticate : AuthenticateMedicalProduct;
        action triage : TriageSuspectProductReport;
        action analyze : AnalyzeSampleForCounterfeit;
        action coordinate : CoordinateEnforcementResponse;
        action cooperate : RequestInternationalCooperation;

        first authenticate;
        then triage;
        then analyze;
        then coordinate;
        then cooperate;
    }

    state def ProductControlStateMachine {
        in item controlledPackage : MedicalProductPackage;

        state Registered;
        state ReleasedToSupplyChain;
        state VerifiedAtCheckpoint;
        state SuspicionRaised;
        state Quarantined;
        state LaboratoryAnalysis;
        state CounterfeitExcluded;
        state CounterfeitConfirmed;
        state RecallOrdered;
        state EvidenceRetained;
        state DestroyedUnderAuthority;
        state ReturnedToLawfulSupply;

        transition initial then Registered;
        transition dispatchFromManufacturer first Registered then ReleasedToSupplyChain accept dispatch;
        transition successfulVerification first ReleasedToSupplyChain then VerifiedAtCheckpoint accept genuineAuthentication;
        transition suspiciousAuthentication first ReleasedToSupplyChain then SuspicionRaised accept counterfeitSuspected;
        transition quarantineSuspect first SuspicionRaised then Quarantined accept quarantineOrder;
        transition submitToLaboratory first Quarantined then LaboratoryAnalysis accept laboratoryRequest;
        transition excludeCounterfeit first LaboratoryAnalysis then CounterfeitExcluded accept negativeLaboratoryResult;
        transition returnLawfulProduct first CounterfeitExcluded then ReturnedToLawfulSupply accept authorityRelease;
        transition confirmCounterfeit first LaboratoryAnalysis then CounterfeitConfirmed accept positiveLaboratoryResult;
        transition orderRecall first CounterfeitConfirmed then RecallOrdered accept recallOrder;
        transition retainAsEvidence first RecallOrdered then EvidenceRetained accept evidenceSeizure;
        transition destroyAfterProceeding first EvidenceRetained then DestroyedUnderAuthority accept destructionAuthorization;
    }

    state def CriminalCaseStateMachine {
        in item caseFile : CriminalCaseFile;

        state NotOpened;
        state PreliminaryAssessment;
        state CriminalInvestigation;
        state CrossBorderAssistance;
        state ProsecutorialReview;
        state ProsecutionFiled;
        state CourtProceeding;
        state Judgment;
        state VictimRightsFollowUp;
        state Closed;

        transition initial then NotOpened;
        transition openAssessment first NotOpened then PreliminaryAssessment accept authorityReferral;
        transition startInvestigation first PreliminaryAssessment then CriminalInvestigation accept evidenceAdmissible;
        transition requestForeignAssistance first CriminalInvestigation then CrossBorderAssistance accept crossBorderElement;
        transition sendToProsecutor first CriminalInvestigation then ProsecutorialReview accept investigationComplete;
        transition sendToProsecutorAfterAssistance first CrossBorderAssistance then ProsecutorialReview accept assistanceResponse;
        transition fileCharges first ProsecutorialReview then ProsecutionFiled accept sufficientEvidence;
        transition beginTrial first ProsecutionFiled then CourtProceeding accept indictmentAccepted;
        transition decideCase first CourtProceeding then Judgment accept judgmentIssued;
        transition supportVictims first Judgment then VictimRightsFollowUp accept victimNotificationRequired;
        transition closeCase first VictimRightsFollowUp then Closed accept rightsInformationProvided;
    }

    part def MEDICRIMEProtectionSystem {
        attribute systemName : Text = "MEDICRIME Convention Counterfeit Medical Product Protection System";
        attribute primaryFunction : Text = "At a high level, the system protects public health by preventing, detecting, reporting, investigating, prosecuting, and coordinating action against counterfeit medical products and similar crimes while ensuring alerts, recalls, evidence preservation, victim support, and international cooperation.";
        attribute maximumSuspectReportTriageTime : DurationHours = 24.0;
        attribute maximumUrgentInternationalCooperationRoutingTime : DurationHours = 2.0;
        attribute minimumAuthenticationConfidenceForGenuineDecision : RiskScorePercent = 95.0;

        part legalFramework : LegalFramework;
        part traceabilityRegistry : TraceabilityRegistry;
        part manufacturer : Manufacturer;
        part distributor : Distributor;
        part pharmacyOrHospital : PharmacyOrHospital;
        part customsAuthority : CustomsAuthority;
        part healthAuthority : HealthAuthority;
        part accreditedLaboratory : AccreditedLaboratory;
        part lawEnforcementAgency : LawEnforcementAgency;
        part prosecutorialAuthority : ProsecutorialAuthority;
        part internationalCooperationHub : InternationalCooperationHub;
        part publicAlertService : PublicAlertService;
        part victimSupportService : VictimSupportService;
        part riskAnalyticsService : RiskAnalyticsService;

        port productEntry : ProductCustodyPort;
        port publicAlerts : AlertPort;
        port foreignCooperation : CooperationPort;

        connect manufacturer.productOut to distributor.productIn;
        connect distributor.productOut to pharmacyOrHospital.productIn;
        connect customsAuthority.detainedProduct to healthAuthority.reportIn;
        connect manufacturer.verification to traceabilityRegistry.manufacturerVerification;
        connect distributor.verification to traceabilityRegistry.distributorVerification;
        connect pharmacyOrHospital.verification to traceabilityRegistry.pharmacyVerification;
        connect customsAuthority.verification to traceabilityRegistry.customsVerification;
        connect manufacturer.reportOut to healthAuthority.reportIn;
        connect distributor.reportOut to healthAuthority.reportIn;
        connect pharmacyOrHospital.reportOut to healthAuthority.reportIn;
        connect customsAuthority.reportOut to healthAuthority.reportIn;
        connect healthAuthority.laboratory to accreditedLaboratory.test;
        connect accreditedLaboratory.evidenceOut to healthAuthority.evidenceOut;
        connect healthAuthority.evidenceOut to lawEnforcementAgency.evidenceIn;
        connect lawEnforcementAgency.evidenceIn to prosecutorialAuthority.caseIn;
        connect healthAuthority.alertOut to publicAlertService.alertIn;
        connect publicAlertService.alertOut to pharmacyOrHospital.alertIn;
        connect publicAlertService.alertOut to publicAlerts;
        connect healthAuthority.victimSupport to victimSupportService.support;
        connect pharmacyOrHospital.victimSupport to victimSupportService.support;
        connect healthAuthority.cooperation to internationalCooperationHub.nationalCooperation;
        connect lawEnforcementAgency.cooperation to internationalCooperationHub.nationalCooperation;
        connect prosecutorialAuthority.cooperation to internationalCooperationHub.nationalCooperation;
        connect customsAuthority.cooperation to internationalCooperationHub.nationalCooperation;
        connect internationalCooperationHub.foreignCooperation to foreignCooperation;
        connect riskAnalyticsService.reports to healthAuthority.reportIn;
        connect riskAnalyticsService.alerts to publicAlertService.alertIn;
        connect riskAnalyticsService.cooperation to internationalCooperationHub.nationalCooperation;

        perform action operation : OperateMEDICRIMEProtectionSystem;
        exhibit state productControl : ProductControlStateMachine;
        exhibit state criminalCaseControl : CriminalCaseStateMachine;
    }

    requirement def PrimaryPublicHealthProtectionRequirement {
        subject system : MEDICRIMEProtectionSystem;
        require constraint {
            system.legalFramework.publicHealthProtectionObjective == true
        }
    }

    requirement def CriminalisationRequirement {
        subject system : MEDICRIMEProtectionSystem;
        require constraint {
            system.legalFramework.counterfeitingOffenceDefined == true and
            system.legalFramework.supplyingCounterfeitOffenceDefined == true and
            system.legalFramework.falsificationOfDocumentsOffenceDefined == true and
            system.legalFramework.aidingAndAbettingLiabilityDefined == true and
            system.legalFramework.corporateLiabilityDefined == true
        }
    }

    requirement def DetectionAndReportingRequirement {
        subject system : MEDICRIMEProtectionSystem;
        require constraint {
            system.maximumSuspectReportTriageTime <= 24.0
        }
    }

    requirement def AuthenticationConfidenceRequirement {
        subject system : MEDICRIMEProtectionSystem;
        require constraint {
            system.minimumAuthenticationConfidenceForGenuineDecision >= 95.0
        }
    }

    requirement def VictimProtectionRequirement {
        subject system : MEDICRIMEProtectionSystem;
        require constraint {
            system.legalFramework.victimProtectionRequired == true and
            system.victimSupportService.providesInformationOnRights == true and
            system.victimSupportService.providesMedicalReferral == true
        }
    }

    requirement def InternationalCooperationRequirement {
        subject system : MEDICRIMEProtectionSystem;
        require constraint {
            system.legalFramework.internationalCooperationRequired == true and
            system.internationalCooperationHub.operatesTwentyFourSeven == true and
            system.maximumUrgentInternationalCooperationRoutingTime <= 2.0
        }
    }

    requirement def EvidenceIntegrityRequirement {
        subject evidence : EvidencePackage;
        require constraint {
            evidence.sealed == true and
            evidence.admissibleForCriminalProceeding == true
        }
    }

    requirement def PublicAlertTimelinessRequirement {
        subject system : MEDICRIMEProtectionSystem;
        require constraint {
            system.healthAuthority.maximumPublicAlertTimeAfterConfirmation <= 4.0 and
            system.publicAlertService.maximumPublicationDelay <= 1.0
        }
    }

    part medicrimeSystem : MEDICRIMEProtectionSystem {
        attribute systemName : Text = "National implementation model for the Council of Europe MEDICRIME Convention";
        attribute maximumSuspectReportTriageTime : DurationHours = 24.0;
        attribute maximumUrgentInternationalCooperationRoutingTime : DurationHours = 2.0;
        attribute minimumAuthenticationConfidenceForGenuineDecision : RiskScorePercent = 95.0;

        part legalFramework {
            attribute conventionName : Text = "Council of Europe MEDICRIME Convention";
            attribute shortName : Text = "MEDICRIME";
            attribute counterfeitingOffenceDefined : Boolean = true;
            attribute supplyingCounterfeitOffenceDefined : Boolean = true;
            attribute falsificationOfDocumentsOffenceDefined : Boolean = true;
            attribute aidingAndAbettingLiabilityDefined : Boolean = true;
            attribute corporateLiabilityDefined : Boolean = true;
            attribute victimProtectionRequired : Boolean = true;
            attribute internationalCooperationRequired : Boolean = true;
            attribute publicHealthProtectionObjective : Boolean = true;
        }

        part traceabilityRegistry {
            attribute registryOperator : OrganizationIdentifier = "NATIONAL_MEDICINES_VERIFICATION_ORG";
            attribute registeredProductRecords : QuantityEach = 250000000;
        }

        part manufacturer {
            attribute organizationId : OrganizationIdentifier = "AUTH_MANUFACTURER_001";
        }

        part distributor {
            attribute organizationId : OrganizationIdentifier = "AUTH_DISTRIBUTOR_014";
            attribute maximumTransportTemperature : TemperatureCelsius = 8.0;
        }

        part pharmacyOrHospital {
            attribute organizationId : OrganizationIdentifier = "HOSPITAL_PHARMACY_022";
        }

        part customsAuthority {
            attribute organizationId : OrganizationIdentifier = "CUSTOMS_MEDICAL_PRODUCTS_UNIT";
            attribute jurisdictionCountry : CountryCode = "NAT";
        }

        part healthAuthority {
            attribute organizationId : OrganizationIdentifier = "NATIONAL_HEALTH_AUTHORITY";
            attribute jurisdictionCountry : CountryCode = "NAT";
        }

        part accreditedLaboratory {
            attribute organizationId : OrganizationIdentifier = "OFFICIAL_MEDICINES_CONTROL_LAB";
        }

        part lawEnforcementAgency {
            attribute organizationId : OrganizationIdentifier = "SPECIALIZED_MEDICAL_CRIME_POLICE_UNIT";
        }

        part prosecutorialAuthority {
            attribute organizationId : OrganizationIdentifier = "NATIONAL_PUBLIC_PROSECUTOR_MEDICRIME_DESK";
        }

        part internationalCooperationHub {
            attribute organizationId : OrganizationIdentifier = "MEDICRIME_24_7_CONTACT_POINT";
        }

        part publicAlertService {
            attribute organizationId : OrganizationIdentifier = "PUBLIC_HEALTH_ALERT_PORTAL";
        }

        part victimSupportService {
            attribute organizationId : OrganizationIdentifier = "PATIENT_RIGHTS_AND_MEDICAL_FOLLOW_UP_SERVICE";
        }

        part riskAnalyticsService {
            attribute organizationId : OrganizationIdentifier = "COUNTERFEIT_MEDICAL_PRODUCT_RISK_ANALYTICS";
            attribute highRiskThreshold : RiskScorePercent = 70.0;
            attribute urgentRiskThreshold : RiskScorePercent = 90.0;
        }
    }

    requirement primaryPublicHealthProtection : PrimaryPublicHealthProtectionRequirement {
        subject system = medicrimeSystem;
    }

    requirement criminalisation : CriminalisationRequirement {
        subject system = medicrimeSystem;
    }

    requirement detectionAndReporting : DetectionAndReportingRequirement {
        subject system = medicrimeSystem;
    }

    requirement authenticationConfidence : AuthenticationConfidenceRequirement {
        subject system = medicrimeSystem;
    }

    requirement victimProtection : VictimProtectionRequirement {
        subject system = medicrimeSystem;
    }

    requirement internationalCooperation : InternationalCooperationRequirement {
        subject system = medicrimeSystem;
    }

    requirement publicAlertTimeliness : PublicAlertTimelinessRequirement {
        subject system = medicrimeSystem;
    }
}
