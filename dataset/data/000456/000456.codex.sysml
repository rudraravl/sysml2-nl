package HongKongInternationalMedicalHealthcareFairModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def HKD;
    attribute def SquareMeter;
    attribute def PersonCount;
    attribute def BoothCount;
    attribute def SessionCount;
    attribute def LeadCount;
    attribute def DeviceCount;
    attribute def Percent;
    attribute def Hour;
    attribute def Minute;

    enum def VisitorCategory {
        exhibitor;
        buyer;
        clinician;
        distributor;
        investor;
        regulator;
        media;
        publicHealthDelegate;
    }

    enum def BoothStatus {
        reserved;
        underConstruction;
        inspectionPending;
        approved;
        operating;
        closed;
    }

    enum def CredentialStatus {
        pending;
        approved;
        rejected;
        expired;
    }

    enum def MedicalDeviceRiskClass {
        lowRisk;
        mediumRisk;
        highRisk;
        diagnosticOnly;
        digitalHealth;
    }

    item def RegistrationData {
        attribute legalName : String;
        attribute organization : String;
        attribute countryOrRegion : String;
        attribute category : VisitorCategory;
        attribute credentialStatus : CredentialStatus;
        attribute badgeIdentifier : String;
    }

    item def Badge {
        attribute badgeIdentifier : String;
        attribute holderName : String;
        attribute category : VisitorCategory;
        attribute validFrom : String;
        attribute validUntil : String;
    }

    item def BoothAssignment {
        attribute hall : String;
        attribute boothNumber : String;
        attribute area : SquareMeter;
        attribute status : BoothStatus;
    }

    item def MedicalProductProfile {
        attribute productName : String;
        attribute manufacturerName : String;
        attribute riskClass : MedicalDeviceRiskClass;
        attribute intendedUse : String;
        attribute marketAuthorizationRegion : String;
        attribute sterile : Boolean;
        attribute demonstrationApproved : Boolean;
    }

    item def LeadRecord {
        attribute leadIdentifier : String;
        attribute buyerOrganization : String;
        attribute exhibitorOrganization : String;
        attribute productInterest : String;
        attribute consentGranted : Boolean;
        attribute priorityScore : Percent;
    }

    item def SeminarBooking {
        attribute sessionIdentifier : String;
        attribute topic : String;
        attribute speakerOrganization : String;
        attribute capacity : PersonCount;
        attribute enrolled : PersonCount;
    }

    item def HealthSafetyAlert {
        attribute alertIdentifier : String;
        attribute severity : String;
        attribute location : String;
        attribute instruction : String;
        attribute active : Boolean;
    }

    item def AnalyticsReport {
        attribute totalVisitors : PersonCount;
        attribute totalExhibitors : PersonCount;
        attribute activeBooths : BoothCount;
        attribute qualifiedLeads : LeadCount;
        attribute seminarAttendanceRate : Percent;
        attribute crossBorderBuyerRatio : Percent;
    }

    port def RegistrationPort {
        in registrationRequest : RegistrationData;
        out issuedBadge : Badge;
        out credentialDecision : CredentialStatus;
    }

    port def AccessControlPort {
        in presentedBadge : Badge;
        out entryAuthorized : Boolean;
        out occupancyDelta : PersonCount;
    }

    port def BoothServicePort {
        in boothRequest : BoothAssignment;
        in productProfile : MedicalProductProfile;
        out boothApproval : BoothStatus;
    }

    port def MatchmakingPort {
        in buyerProfile : RegistrationData;
        in exhibitorProduct : MedicalProductProfile;
        out leadRecord : LeadRecord;
    }

    port def SeminarPort {
        in bookingRequest : SeminarBooking;
        out bookingConfirmation : SeminarBooking;
        out sessionCapacityAvailable : Boolean;
    }

    port def SafetyPort {
        in sensorOccupancy : PersonCount;
        in incidentReport : HealthSafetyAlert;
        out safetyAlert : HealthSafetyAlert;
        out evacuationRequired : Boolean;
    }

    port def AnalyticsPort {
        in attendanceEvent : PersonCount;
        in leadEvent : LeadRecord;
        in boothStatusEvent : BoothStatus;
        out fairReport : AnalyticsReport;
    }

    port def PaymentPort {
        in invoiceAmount : HKD;
        out paymentAccepted : Boolean;
        out receiptIdentifier : String;
    }

    action def ValidateCredential {
        in applicant : RegistrationData;
        out result : CredentialStatus;

        first start;
        then verifyIdentity;
        then verifyProfessionalOrBusinessPurpose;
        then checkSanctionsAndDataConsent;
        then decide;
        then done;

        action verifyIdentity;
        action verifyProfessionalOrBusinessPurpose;
        action checkSanctionsAndDataConsent;
        action decide;
    }

    action def IssueBadge {
        in approvedRegistration : RegistrationData;
        out badge : Badge;

        first receiveApprovedRegistration;
        then encodeBadgeIdentifier;
        then printBadge;
        then activateAccessRights;
        then complete;

        action receiveApprovedRegistration;
        action encodeBadgeIdentifier;
        action printBadge;
        action activateAccessRights;
    }

    action def QualifyMedicalProductForDisplay {
        in profile : MedicalProductProfile;
        out displayApproved : Boolean;

        first receiveProductProfile;
        then checkIntendedUseDisclosure;
        then checkDemonstrationSafety;
        then checkRegulatoryClaims;
        then recordDecision;
        then complete;

        action receiveProductProfile;
        action checkIntendedUseDisclosure;
        action checkDemonstrationSafety;
        action checkRegulatoryClaims;
        action recordDecision;
    }

    action def MatchBuyerToExhibitor {
        in buyer : RegistrationData;
        in product : MedicalProductProfile;
        out lead : LeadRecord;

        first normalizeBuyerNeed;
        then compareClinicalAndCommercialFit;
        then computePriorityScore;
        then requestConsent;
        then publishLead;
        then done;

        action normalizeBuyerNeed;
        action compareClinicalAndCommercialFit;
        action computePriorityScore;
        action requestConsent;
        action publishLead;
    }

    action def MonitorVenueSafety {
        in occupancy : PersonCount;
        in incident : HealthSafetyAlert;
        out alert : HealthSafetyAlert;
        out evacuation : Boolean;

        first readOccupancy;
        then evaluateCrowding;
        then evaluateIncidentSeverity;
        then selectResponse;
        then notifyOperations;
        then complete;

        action readOccupancy;
        action evaluateCrowding;
        action evaluateIncidentSeverity;
        action selectResponse;
        action notifyOperations;
    }

    state def FairLifecycle {
        entry action initializeFairSystems;
        exit action archiveFairRecords;

        state Planning;
        state ExhibitorOnboarding;
        state BoothBuildOut;
        state OpenToTradeVisitors;
        state PublicHealthProgramActive;
        state Closing;
        state PostFairAnalytics;

        transition first Planning;
        transition Planning_to_ExhibitorOnboarding
            first Planning
            then ExhibitorOnboarding;

        transition ExhibitorOnboarding_to_BoothBuildOut
            first ExhibitorOnboarding
            then BoothBuildOut;

        transition BoothBuildOut_to_OpenToTradeVisitors
            first BoothBuildOut
            then OpenToTradeVisitors;

        transition OpenToTradeVisitors_to_PublicHealthProgramActive
            first OpenToTradeVisitors
            then PublicHealthProgramActive;

        transition PublicHealthProgramActive_to_Closing
            first PublicHealthProgramActive
            then Closing;

        transition Closing_to_PostFairAnalytics
            first Closing
            then PostFairAnalytics;

        transition terminate
            first PostFairAnalytics;
    }

    state def RegistrationLifecycle {
        state Draft;
        state Submitted;
        state Screening;
        state Approved;
        state Rejected;
        state BadgeIssued;
        state CheckedIn;
        state Expired;

        transition first Draft;
        transition submit first Draft then Submitted;
        transition screen first Submitted then Screening;
        transition approve first Screening then Approved;
        transition reject first Screening then Rejected;
        transition issue first Approved then BadgeIssued;
        transition checkIn first BadgeIssued then CheckedIn;
        transition expire first CheckedIn then Expired;
    }

    part def Venue {
        attribute name : String = "Hong Kong Convention and Exhibition Centre";
        attribute grossArea : SquareMeter = 35000;
        attribute maximumOccupancy : PersonCount = 28000;
        attribute currentOccupancy : PersonCount = 0;

        port access : AccessControlPort;
        port safety : SafetyPort;

        part exhibitionHallA {
            attribute hallName : String = "Medical Devices and Equipment";
            attribute area : SquareMeter = 11000;
            attribute boothCapacity : BoothCount = 420;
        }

        part exhibitionHallB {
            attribute hallName : String = "Digital Health and Telemedicine";
            attribute area : SquareMeter = 6500;
            attribute boothCapacity : BoothCount = 210;
        }

        part exhibitionHallC {
            attribute hallName : String = "Rehabilitation, Elderly Care, and Wellness";
            attribute area : SquareMeter = 7200;
            attribute boothCapacity : BoothCount = 260;
        }

        part seminarZone {
            attribute roomCount : SessionCount = 8;
            attribute totalSeatCapacity : PersonCount = 1600;
        }

        part triageAndFirstAidPoint {
            attribute staffed : Boolean = true;
            attribute responseTarget : Minute = 3;
        }
    }

    part def RegistrationSubsystem {
        attribute dailyCredentialCapacity : PersonCount = 12000;
        attribute averageCredentialReviewTime : Minute = 4;

        port registration : RegistrationPort;
        port payment : PaymentPort;

        perform credentialValidation : ValidateCredential;
        perform badgeIssuance : IssueBadge;

        state registrationState : RegistrationLifecycle;
    }

    part def ExhibitorOperationsSubsystem {
        attribute targetExhibitors : PersonCount = 900;
        attribute totalBoothArea : SquareMeter = 24500;
        attribute minimumAisleWidth : SquareMeter = 3;

        port boothService : BoothServicePort;
        port analytics : AnalyticsPort;

        perform productQualification : QualifyMedicalProductForDisplay;

        part boothPlanner {
            attribute assignedBooths : BoothCount = 0;
            attribute maximumBooths : BoothCount = 890;
        }

        part complianceDesk {
            attribute productProfilesReviewed : DeviceCount = 0;
            attribute reviewServiceLevel : Hour = 24;
        }

        part logisticsDesk {
            attribute loadingBaySlotsPerDay : PersonCount = 180;
            attribute coldChainStorageAvailable : Boolean = true;
        }
    }

    part def VisitorExperienceSubsystem {
        attribute expectedTradeVisitors : PersonCount = 18000;
        attribute expectedPublicVisitors : PersonCount = 6000;
        attribute supportedLanguages : String = "English, Cantonese, Putonghua";

        port access : AccessControlPort;
        port seminar : SeminarPort;
        port matchmaking : MatchmakingPort;

        perform buyerMatching : MatchBuyerToExhibitor;

        part mobileGuide {
            attribute indoorNavigationEnabled : Boolean = true;
            attribute exhibitorSearchEnabled : Boolean = true;
            attribute appointmentBookingEnabled : Boolean = true;
        }

        part helpDesk {
            attribute staffedCounters : PersonCount = 18;
            attribute averageQueueTarget : Minute = 6;
        }

        part translationSupport {
            attribute simultaneousInterpretationRooms : SessionCount = 5;
            attribute remoteCaptioningEnabled : Boolean = true;
        }
    }

    part def SeminarAndConferenceSubsystem {
        attribute plannedSessions : SessionCount = 72;
        attribute clinicalEducationHours : Hour = 96;
        attribute maximumTotalAttendance : PersonCount = 9200;

        port seminar : SeminarPort;
        port analytics : AnalyticsPort;

        part medicalInnovationForum {
            attribute topic : String = "AI-assisted diagnostics and connected care";
            attribute capacity : PersonCount = 450;
        }

        part publicHealthProcurementForum {
            attribute topic : String = "Hospital procurement, infection control, and resilient supply chains";
            attribute capacity : PersonCount = 350;
        }

        part rehabilitationTechnologyForum {
            attribute topic : String = "Ageing population support and home rehabilitation";
            attribute capacity : PersonCount = 280;
        }
    }

    part def HealthSafetySubsystem {
        attribute crowdingWarningThreshold : Percent = 85;
        attribute evacuationThreshold : Percent = 95;
        attribute firstAidResponseTarget : Minute = 3;

        port safety : SafetyPort;
        port analytics : AnalyticsPort;

        perform safetyMonitoring : MonitorVenueSafety;

        part occupancySensors {
            attribute sensorCount : DeviceCount = 160;
            attribute updateInterval : Minute = 1;
        }

        part airQualityMonitoring {
            attribute sensorCount : DeviceCount = 44;
            attribute particulateAlertEnabled : Boolean = true;
        }

        part incidentCommandDesk {
            attribute staffed : Boolean = true;
            attribute directEmergencyServicesLink : Boolean = true;
        }
    }

    part def BusinessMatchmakingSubsystem {
        attribute scheduledMeetingsTarget : PersonCount = 3500;
        attribute qualifiedLeadTarget : LeadCount = 12000;
        attribute consentRequired : Boolean = true;

        port matchmaking : MatchmakingPort;
        port analytics : AnalyticsPort;

        perform matchingAction : MatchBuyerToExhibitor;

        part buyerNeedProfiler {
            attribute categoriesTracked : PersonCount = 34;
            attribute crossBorderBuyerSupport : Boolean = true;
        }

        part exhibitorProductIndex {
            attribute indexedProducts : DeviceCount = 5200;
            attribute regulatoryClaimsChecked : Boolean = true;
        }
    }

    part def AnalyticsAndReportingSubsystem {
        attribute reportingInterval : Minute = 15;
        attribute dataRetentionMonths : PersonCount = 36;
        attribute personalDataMinimizationEnabled : Boolean = true;

        port analytics : AnalyticsPort;

        part attendanceDashboard {
            attribute realTimeOccupancyEnabled : Boolean = true;
            attribute hallLevelBreakdownEnabled : Boolean = true;
        }

        part tradeOutcomeDashboard {
            attribute leadScoringEnabled : Boolean = true;
            attribute exportableReportsEnabled : Boolean = true;
        }

        part complianceAuditLog {
            attribute immutableEventLogEnabled : Boolean = true;
            attribute accessRestricted : Boolean = true;
        }
    }

    part def HongKongInternationalMedicalHealthcareFairSystem {
        doc
        /* Primary high-level function:
           The system organizes and operates an international medical and healthcare trade fair in Hong Kong by bringing together exhibitors, buyers, clinicians, regulators, investors, and public health delegates; it enables credentialed access, compliant product display, seminar participation, business matchmaking, visitor guidance, venue safety, and trade-performance reporting. */

        attribute fairName : String = "Hong Kong International Medical and Healthcare Fair";
        attribute hostCity : String = "Hong Kong";
        attribute primaryFunction : String = "Operate a trusted medical and healthcare marketplace that connects qualified participants, showcases compliant healthcare solutions, and supports safe knowledge exchange and business matching.";
        attribute plannedExhibitors : PersonCount = 900;
        attribute plannedVisitors : PersonCount = 24000;
        attribute plannedBooths : BoothCount = 890;
        attribute plannedMedicalProducts : DeviceCount = 5200;
        attribute plannedSeminars : SessionCount = 72;
        attribute targetQualifiedLeads : LeadCount = 12000;

        port publicRegistration : RegistrationPort;
        port publicAccess : AccessControlPort;
        port exhibitorBoothService : BoothServicePort;
        port buyerMatchmaking : MatchmakingPort;
        port seminarBooking : SeminarPort;
        port fairSafety : SafetyPort;
        port fairAnalytics : AnalyticsPort;
        port fairPayment : PaymentPort;

        part venue : Venue;
        part registrationSubsystem : RegistrationSubsystem;
        part exhibitorOperations : ExhibitorOperationsSubsystem;
        part visitorExperience : VisitorExperienceSubsystem;
        part seminarAndConference : SeminarAndConferenceSubsystem;
        part healthSafety : HealthSafetySubsystem;
        part businessMatchmaking : BusinessMatchmakingSubsystem;
        part analyticsAndReporting : AnalyticsAndReportingSubsystem;

        state lifecycle : FairLifecycle;

        connect publicRegistration to registrationSubsystem.registration;
        connect fairPayment to registrationSubsystem.payment;
        connect publicAccess to venue.access;
        connect publicAccess to visitorExperience.access;
        connect exhibitorBoothService to exhibitorOperations.boothService;
        connect buyerMatchmaking to visitorExperience.matchmaking;
        connect buyerMatchmaking to businessMatchmaking.matchmaking;
        connect seminarBooking to visitorExperience.seminar;
        connect seminarBooking to seminarAndConference.seminar;
        connect fairSafety to venue.safety;
        connect fairSafety to healthSafety.safety;
        connect fairAnalytics to analyticsAndReporting.analytics;
        connect exhibitorOperations.analytics to analyticsAndReporting.analytics;
        connect seminarAndConference.analytics to analyticsAndReporting.analytics;
        connect healthSafety.analytics to analyticsAndReporting.analytics;
        connect businessMatchmaking.analytics to analyticsAndReporting.analytics;
    }

    requirement def FairPrimaryFunctionRequirement {
        subject fairSystem : HongKongInternationalMedicalHealthcareFairSystem;

        require constraint {
            fairSystem.plannedExhibitors >= 700 and
            fairSystem.plannedVisitors >= 15000 and
            fairSystem.plannedMedicalProducts >= 3000
        }

        doc
        /* The fair system shall provide the primary high-level function of operating an international medical and healthcare marketplace in Hong Kong, supporting compliant exhibition, credentialed attendance, professional education, buyer-supplier matching, safe venue operation, and measurable trade outcomes. */
    }

    requirement def CredentialedAccessRequirement {
        subject registrationSubsystem : RegistrationSubsystem;
        subject venue : Venue;

        require constraint {
            registrationSubsystem.dailyCredentialCapacity >= 10000 and
            venue.maximumOccupancy >= 25000
        }

        doc
        /* The system shall register and credential exhibitors, buyers, clinicians, regulators, investors, media, and public health delegates before granting access to controlled fair areas. */
    }

    requirement def CompliantProductDisplayRequirement {
        subject exhibitorOperations : ExhibitorOperationsSubsystem;

        require constraint {
            exhibitorOperations.targetExhibitors >= 800 and
            exhibitorOperations.complianceDesk.reviewServiceLevel <= 24
        }

        doc
        /* The system shall review medical product profiles and approve only displays and demonstrations with declared intended use, risk class, demonstration controls, and market-authorization context. */
    }

    requirement def BusinessMatchingRequirement {
        subject matchmaking : BusinessMatchmakingSubsystem;

        require constraint {
            matchmaking.scheduledMeetingsTarget >= 3000 and
            matchmaking.qualifiedLeadTarget >= 10000 and
            matchmaking.consentRequired == true
        }

        doc
        /* The system shall match qualified buyers with relevant exhibitors and create consent-based lead records for follow-up business engagement. */
    }

    requirement def SeminarKnowledgeExchangeRequirement {
        subject seminars : SeminarAndConferenceSubsystem;

        require constraint {
            seminars.plannedSessions >= 60 and
            seminars.maximumTotalAttendance >= 8000
        }

        doc
        /* The system shall support professional seminars on medical innovation, digital health, procurement, infection control, elderly care, rehabilitation, and public health topics. */
    }

    requirement def VenueSafetyRequirement {
        subject safety : HealthSafetySubsystem;
        subject venue : Venue;

        require constraint {
            safety.crowdingWarningThreshold < safety.evacuationThreshold and
            safety.firstAidResponseTarget <= 3 and
            venue.currentOccupancy <= venue.maximumOccupancy
        }

        doc
        /* The system shall continuously monitor occupancy and health-safety incidents and issue alerts or evacuation instructions when operational thresholds are exceeded. */
    }

    requirement def AnalyticsReportingRequirement {
        subject analytics : AnalyticsAndReportingSubsystem;

        require constraint {
            analytics.reportingInterval <= 15 and
            analytics.personalDataMinimizationEnabled == true
        }

        doc
        /* The system shall produce operational and trade-performance analytics while minimizing personal data exposure and maintaining auditable event records. */
    }

    satisfy FairPrimaryFunctionRequirement by HongKongInternationalMedicalHealthcareFairSystem;
    satisfy CredentialedAccessRequirement by RegistrationSubsystem;
    satisfy CompliantProductDisplayRequirement by ExhibitorOperationsSubsystem;
    satisfy BusinessMatchingRequirement by BusinessMatchmakingSubsystem;
    satisfy SeminarKnowledgeExchangeRequirement by SeminarAndConferenceSubsystem;
    satisfy VenueSafetyRequirement by HealthSafetySubsystem;
    satisfy AnalyticsReportingRequirement by AnalyticsAndReportingSubsystem;
}