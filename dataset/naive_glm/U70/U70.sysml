package HKMedicalFairManagement {
    import ScalarValues::*;
    import SI::*;
    import Time::*;

    // =========================================================================
    // Enumerations
    // =========================================================================

    enum def ExhibitorSector {
        diagnosticEquipment;
        pharmaceuticals;
        digitalHealth;
        medicalDevices;
        rehabilitation;
        wellness;
    }

    enum def VisitorRole {
        buyer;
        healthcarePractitioner;
        distributor;
        investor;
        researcher;
        policyMaker;
    }

    enum def BoothType {
        standard;
        premium;
        pavilion;
        island;
    }

    enum def BoothStatus {
        available;
        allocated;
        occupied;
        released;
    }

    enum def FairPhase {
        preparation;
        active;
        closing;
        archived;
    }

    enum def EmergencyLevel {
        minor;
        moderate;
        severe;
        critical;
    }

    enum def EventStatus {
        scheduled;
        inProgress;
        completed;
        cancelled;
    }

    enum def ParticipantType {
        exhibitor;
        visitor;
        staff;
        vip;
    }

    enum def SeminarTopic {
        cardiology;
        oncology;
        telemedicine;
        regulatory;
        investment;
        innovation;
        ai;
    }

    // =========================================================================
    // Value Types with Units
    // =========================================================================

    value type HKD :> Real {
        unit hkd;
    }

    value type SquareMeters :> Real {
        unit m2;
    }

    value type HourValue :> Real {
        unit h;
    }

    value type PeopleCount :> Integer;

    value type LeadCount :> Integer;

    value type RatingValue :> Real {
        unit percent;
    }

    value type PowerKilowatts :> Real {
        unit kW;
    }

    value type BandwidthMbps :> Real {
        unit Mbps;
    }

    // =========================================================================
    // Item Definitions
    // =========================================================================

    item def RegistrationForm {
        attribute applicantName : String;
        attribute contactEmail : String;
        attribute participantType : ParticipantType;
        attribute requestedBoothType : BoothType[0..1];
        attribute submittedAt : DateTime;
    }

    item def ExhibitorProfile {
        attribute companyName : String;
        attribute sector : ExhibitorSector;
        attribute productDescription : String;
        attribute targetMarkets : String[*];
        attribute boothPreference : BoothType;
        attribute staffHeadcount : PeopleCount;
    }

    item def VisitorProfile {
        attribute personName : String;
        attribute role : VisitorRole;
        attribute organization : String;
        attribute productInterests : ExhibitorSector[*];
        attribute preferredBooths : String[*];
    }

    item def Badge {
        attribute badgeId : String;
        attribute holderName : String;
        attribute participantType : ParticipantType;
        attribute validFrom : DateTime;
        attribute validUntil : DateTime;
    }

    item def LeadCard {
        attribute leadId : String;
        attribute visitorBadgeId : String;
        attribute visitorName : String;
        attribute visitorOrganization : String;
        attribute interestNote : String;
        attribute sectorInterest : ExhibitorSector;
        attribute capturedAt : DateTime;
    }

    item def MeetingRecommendation {
        attribute recommendationId : String;
        attribute exhibitorId : String;
        attribute visitorId : String;
        attribute matchScore : Real;
        attribute suggestedTime : DateTime;
        attribute suggestedBoothId : String;
    }

    item def Query {
        attribute question : String;
        attribute category : String;
    }

    item def Direction {
        attribute destination : String;
        attribute routeInstructions : String;
    }

    item def SeminarSchedule {
        attribute seminarId : String;
        attribute title : String;
        attribute topic : SeminarTopic;
        attribute startTime : DateTime;
        attribute endTime : DateTime;
        attribute venueName : String;
        attribute capacity : PeopleCount;
        attribute status : EventStatus;
    }

    item def DemoSchedule {
        attribute demoId : String;
        attribute exhibitorId : String;
        attribute boothId : String;
        attribute startTime : DateTime;
        attribute endTime : DateTime;
        attribute status : EventStatus;
    }

    item def FeedbackForm {
        attribute feedbackId : String;
        attribute participantType : ParticipantType;
        attribute rating : RatingValue;
        attribute comments : String;
        attribute submittedAt : DateTime;
    }

    item def AnalyticsReport {
        attribute reportId : String;
        attribute totalAttendance : PeopleCount;
        attribute totalLeads : LeadCount;
        attribute roiEstimate : HKD;
        attribute satisfactionRating : RatingValue;
        attribute topSectors : ExhibitorSector[*];
        attribute generatedAt : DateTime;
    }

    item def EmergencyNotice {
        attribute noticeId : String;
        attribute level : EmergencyLevel;
        attribute description : String;
        attribute affectedArea : String;
        attribute issuedAt : DateTime;
    }

    // =========================================================================
    // Port Definitions
    // =========================================================================

    port def RegistrationRequestPort {
        in item form : RegistrationForm;
        out item badge : Badge;
    }

    port def BoothUtilityPort {
        in item power : PowerKilowatts;
        in item networkBandwidth : BandwidthMbps;
    }

    port def VisitorInteractionPort {
        in item badge : Badge;
        in item interestNote : String;
        in item sectorInterest : ExhibitorSector;
        out item leadCard : LeadCard;
    }

    port def MatchingPort {
        in item recommendation : MeetingRecommendation;
    }

    port def QueryServicePort {
        in item query : Query;
        out item direction : Direction;
    }

    port def SeminarSchedulePort {
        in item schedule : SeminarSchedule;
    }

    port def DemoSchedulePort {
        in item schedule : DemoSchedule;
    }

    port def FeedbackPort {
        in item feedback : FeedbackForm;
    }

    port def EmergencyAlertPort {
        in item notice : EmergencyNotice;
    }

    // =========================================================================
    // Part Definitions
    // =========================================================================

    part def ExhibitionBooth {
        attribute boothId : String;
        attribute hallId : String;
        attribute boothType : BoothType;
        attribute area : SquareMeters;
        attribute status : BoothStatus;
        attribute rentalFee : HKD;
        attribute allocatedExhibitorId : String[0..1];
        attribute powerCapacity : PowerKilowatts;
        attribute networkCapacity : BandwidthMbps;

        port utilityPort : BoothUtilityPort;
        port visitorInteractionPort : VisitorInteractionPort;
        port demoSchedulePort : DemoSchedulePort;

        state machine boothLifecycle {
            state available;
            state allocated;
            state occupied;
            state released;

            transition available -> allocated when boothAssigned;
            transition allocated -> occupied when setupComplete;
            transition occupied -> released when teardownComplete;
            transition released -> available when resetComplete;
        }

        attribute boothAssigned : Boolean;
        attribute setupComplete : Boolean;
        attribute teardownComplete : Boolean;
        attribute resetComplete : Boolean;
    }

    part def ExhibitionHall {
        attribute hallId : String;
        attribute hallName : String;
        attribute location : String;
        attribute totalArea : SquareMeters;

        part booths : ExhibitionBooth[*];
    }

    part def Venue {
        attribute venueName : String;
        attribute address : String;
        attribute totalArea : SquareMeters;

        part halls : ExhibitionHall[3];
    }

    part def Exhibitor {
        attribute exhibitorId : String;
        attribute companyName : String;
        attribute sector : ExhibitorSector;
        attribute profile : ExhibitorProfile;
        attribute assignedBoothId : String;
        attribute collectedLeads : LeadCard[*];
        attribute leadCount : LeadCount;

        port registrationPort : ~RegistrationRequestPort;
        port matchingPort : MatchingPort;
        port interactionPort : ~VisitorInteractionPort;
        port demoSchedulePort : DemoSchedulePort;
        port feedbackPort : ~FeedbackPort;
        port emergencyAlertPort : EmergencyAlertPort;

        action def CollectLead {
            in visitorBadge : Badge;
            in interestNote : String;
            in sectorInterest : ExhibitorSector;
            out lead : LeadCard;
        }

        action def RequestDemoSlot {
            in preferredTime : DateTime;
            out demoSchedule : DemoSchedule;
        }

        action def SubmitFeedback {
            in rating : RatingValue;
            in comments : String;
            out feedback : FeedbackForm;
        }
    }

    part def Visitor {
        attribute visitorId : String;
        attribute personName : String;
        attribute role : VisitorRole;
        attribute profile : VisitorProfile;
        attribute badge : Badge[0..1];
        attribute boothsVisited : String[*];
        attribute receivedRecommendations : MeetingRecommendation[*];

        port registrationPort : ~RegistrationRequestPort;
        port matchingPort : MatchingPort;
        port interactionPort : VisitorInteractionPort;
        port queryPort : ~QueryServicePort;
        port feedbackPort : ~FeedbackPort;
        port emergencyAlertPort : EmergencyAlertPort;

        action def VisitBooth {
            in boothId : String;
            in interestNote : String;
        }

        action def RequestDirections {
            in destination : String;
            out direction : Direction;
        }

        action def SubmitFeedback {
            in rating : RatingValue;
            in comments : String;
            out feedback : FeedbackForm;
        }
    }

    part def RegistrationCenter {
        attribute centerId : String;
        attribute staffCount : PeopleCount;
        attribute dailyCapacity : PeopleCount;
        attribute totalRegistered : PeopleCount;

        port exhibitorRegPort : RegistrationRequestPort;
        port visitorRegPort : RegistrationRequestPort;

        action def ProcessRegistration {
            in form : RegistrationForm;
            out badge : Badge;
        }

        action def CheckIn {
            in badge : Badge;
            in profile : VisitorProfile;
            out confirmation : Boolean;
        }
    }

    part def BusinessMatchingCenter {
        attribute matchThreshold : Real;
        attribute algorithmVersion : String;
        attribute totalRecommendations : Integer;

        port exhibitorMatchPort : ~MatchingPort;
        port visitorMatchPort : ~MatchingPort;

        action def MatchProfiles {
            in exhibitorProfile : ExhibitorProfile;
            in visitorProfile : VisitorProfile;
            out matchScore : Real;
        }

        action def GenerateRecommendation {
            in exhibitor : ExhibitorProfile;
            in visitor : VisitorProfile;
            out recommendation : MeetingRecommendation;
        }

        action def ScheduleMeetings {
            in recommendations : MeetingRecommendation[*];
            out confirmed : MeetingRecommendation[*];
        }
    }

    part def SeminarVenue {
        attribute venueId : String;
        attribute venueName : String;
        attribute capacity : PeopleCount;
        attribute location : String;

        attribute schedule : SeminarSchedule[*];
        port schedulePort : SeminarSchedulePort;
    }

    part def EventCoordination {
        attribute unitId : String;
        attribute totalSeminars : Integer;
        attribute totalDemos : Integer;

        part seminarVenues : SeminarVenue[*];

        port seminarSchedulePort : ~SeminarSchedulePort;
        port demoSchedulePort : ~DemoSchedulePort;

        connect seminarSchedulePort to seminarVenues.schedulePort;

        action def OrganizeSeminars {
            in topics : SeminarTopic[*];
            in venues : SeminarVenue[*];
            out schedules : SeminarSchedule[*];
        }

        action def CoordinateDemo {
            in exhibitorId : String;
            in boothId : String;
            in preferredTime : DateTime;
            out demoSchedule : DemoSchedule;
        }
    }

    part def InformationDesk {
        attribute deskId : String;
        attribute location : String;
        attribute staffedHoursPerDay : HourValue;
        attribute queriesHandled : Integer;

        port queryServicePort : QueryServicePort;

        action def AnswerQuery {
            in query : Query;
            out direction : Direction;
        }

        action def ProvideAssistance {
            in visitorId : String;
            out assistance : String;
        }
    }

    part def EmergencyProtocol {
        attribute protocolId : String;
        attribute emergencyContact : String;
        attribute evacuationPlan : String;
        attribute activeLevel : EmergencyLevel;

        port alertPort : ~EmergencyAlertPort;

        state machine emergencyHandling {
            state idle;
            state assessing;
            state responding;
            state evacuating;
            state resolved;

            transition idle -> assessing when incidentDetected;
            transition assessing -> responding when levelDetermined;
            transition responding -> evacuating when evacuationRequired;
            transition responding -> resolved when situationUnderControl;
            transition evacuating -> resolved when areaCleared;
            transition resolved -> idle when resetComplete;
        }

        attribute incidentDetected : Boolean;
        attribute levelDetermined : Boolean;
        attribute evacuationRequired : Boolean;
        attribute situationUnderControl : Boolean;
        attribute areaCleared : Boolean;
        attribute resetComplete : Boolean;

        action def TriggerEmergency {
            in level : EmergencyLevel;
            in description : String;
            in area : String;
            out notice : EmergencyNotice;
        }

        action def Evacuate {
            in area : String;
            out evacuationComplete : Boolean;
        }

        action def NotifyAuthorities {
            in level : EmergencyLevel;
        }
    }

    part def AnalyticsSystem {
        attribute systemId : String;
        attribute collectedFeedback : FeedbackForm[*];
        attribute attendanceData : PeopleCount;
        attribute leadData : LeadCount;
        attribute lastReport : AnalyticsReport[0..1];

        port feedbackPort : FeedbackPort;

        action def CollectFeedback {
            in feedback : FeedbackForm;
        }

        action def GenerateAnalytics {
            in attendance : PeopleCount;
            in leads : LeadCount;
            in feedback : FeedbackForm[*];
            out report : AnalyticsReport;
        }

        action def PublishReport {
            in report : AnalyticsReport;
        }
    }

    // =========================================================================
    // State Machine Definitions
    // =========================================================================

    state def FairLifecycle {
        attribute openingComplete : Boolean;
        attribute closingComplete : Boolean;
        attribute reportPublished : Boolean;

        state preparation {
            entry action setupEvent;
        }
        state active {
            entry action openFair;
        }
        state closing {
            entry action closeFair;
        }
        state archived;

        transition preparation -> active when openingComplete;
        transition active -> closing when closingComplete;
        transition closing -> archived when reportPublished;
    }

    // =========================================================================
    // Requirements
    // =========================================================================

    requirement def ManageVenueRequirement {
        doc
            /* The system shall manage a physical venue with three exhibition halls
               divided into individual booths equipped with power and network utilities. */;
    }

    requirement def ManageExhibitorRequirement {
        doc
            /* The system shall register exhibitors, capture their product and target market
               profiles, allocate booths, and enable lead collection from interested visitors. */;
    }

    requirement def ManageVisitorRequirement {
        doc
            /* The system shall register visitors, capture professional role and product
               interest profiles, provide personalized recommendations, and support
               efficient navigation of the fair. */;
    }

    requirement def BusinessMatchingRequirement {
        doc
            /* The system shall provide a Business Matching Center that intelligently
               connects exhibitors with relevant visitors based on profile compatibility
               and suggests potential meetings and partnerships. */;
    }

    requirement def EventScheduleRequirement {
        doc
            /* The system shall organize a schedule of supplementary events including
               educational seminars in dedicated venues and live product demonstrations
               at exhibitor booths. */;
    }

    requirement def InformationDeskRequirement {
        doc
            /* The system shall provide multiple strategically placed Information Desks
               offering directions, query answering, and general assistance to visitors. */;
    }

    requirement def EmergencyProtocolRequirement {
        doc
            /* The system shall include protocols for handling emergencies during the fair
               with defined response levels and evacuation procedures. */;
    }

    requirement def FairLifecycleRequirement {
        doc
            /* The system shall progress through preparation, active, and closing phases,
               with post-event feedback collection and analytics reporting on attendance,
               business leads, and overall return on investment for stakeholders. */;
    }

    // =========================================================================
    // Top-Level Assembly
    // =========================================================================

    part def HKMedicalFair {
        attribute fairName : String;
        attribute edition : String;
        attribute startDate : DateTime;
        attribute endDate : DateTime;
        attribute phase : FairPhase;
        attribute expectedAttendance : PeopleCount;

        part venue : Venue;
        part registrationCenter : RegistrationCenter;
        part businessMatching : BusinessMatchingCenter;
        part eventCoordination : EventCoordination;
        part informationDesks : InformationDesk[4];
        part emergencyProtocol : EmergencyProtocol;
        part analyticsSystem : AnalyticsSystem;

        part exhibitors : Exhibitor[*];
        part visitors : Visitor[*];

        state machine lifecycle : FairLifecycle;

        // Registration flow
        connect registrationCenter.exhibitorRegPort to exhibitors.registrationPort;
        connect registrationCenter.visitorRegPort to visitors.registrationPort;

        // Business matching recommendations
        connect businessMatching.exhibitorMatchPort to exhibitors.matchingPort;
        connect businessMatching.visitorMatchPort to visitors.matchingPort;

        // Lead collection at exhibitor booths
        connect visitors.interactionPort to exhibitors.interactionPort;

        // Demonstration scheduling
        connect eventCoordination.demoSchedulePort to exhibitors.demoSchedulePort;

        // Information desk assistance
        connect informationDesks.queryServicePort to visitors.queryPort;

        // Feedback to analytics
        connect exhibitors.feedbackPort to analyticsSystem.feedbackPort;
        connect visitors.feedbackPort to analyticsSystem.feedbackPort;

        // Emergency alert broadcast
        connect emergencyProtocol.alertPort to visitors.emergencyAlertPort;
        connect emergencyProtocol.alertPort to exhibitors.emergencyAlertPort;

        satisfy ManageVenueRequirement;
        satisfy ManageExhibitorRequirement;
        satisfy ManageVisitorRequirement;
        satisfy BusinessMatchingRequirement;
        satisfy EventScheduleRequirement;
        satisfy InformationDeskRequirement;
        satisfy EmergencyProtocolRequirement;
        satisfy FairLifecycleRequirement;
    }
}
