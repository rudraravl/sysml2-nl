package DesignAutomationConferenceSystemModel {

	import ScalarValues::*;
	import ISQ::*;
	import SI::*;

	attribute def PersonCount :> Integer;
	attribute def SubmissionCount :> Integer;
	attribute def SessionCount :> Integer;
	attribute def BoothCount :> Integer;
	attribute def DurationMinutes :> Real;
	attribute def DurationHours :> Real;
	attribute def AreaSquareMeters :> Real;
	attribute def DataRateMbps :> Real;
	attribute def MoneyUSD :> Real;
	attribute def Percent :> Real;
	attribute def ScoreValue :> Real;
	attribute def PriorityLevel :> Integer;

	enum def SubmissionStatus {
		enum draft;
		enum submitted;
		enum compliant;
		enum assignedForReview;
		enum reviewed;
		enum accepted;
		enum rejected;
		enum withdrawn;
	}

	enum def AttendeeRole {
		enum author;
		enum reviewer;
		enum programChair;
		enum exhibitor;
		enum sponsor;
		enum attendee;
		enum operationsStaff;
		enum keynoteSpeaker;
	}

	enum def SessionTrack {
		enum electronicDesignAutomation;
		enum embeddedSystems;
		enum artificialIntelligenceForDesign;
		enum verificationAndTest;
		enum semiconductorManufacturing;
		enum securityAndPrivacy;
		enum automotiveAndCyberPhysicalSystems;
		enum designInfrastructure;
		enum educationAndWorkforce;
		enum exhibitionTheater;
	}

	enum def ConferencePhase {
		enum conceptPlanning;
		enum callForContributions;
		enum reviewAndSelection;
		enum programAssembly;
		enum registrationAndExhibitionSetup;
		enum liveConferenceExecution;
		enum postConferenceAnalytics;
		enum closed;
	}

	item def Person {
		attribute personId: String;
		attribute fullName: String;
		attribute affiliation: String;
		attribute emailAddress: String;
		attribute role: AttendeeRole;
	}

	item def PaperSubmission {
		attribute submissionId: String;
		attribute title: String;
		attribute abstractText: String;
		attribute authorCount: PersonCount;
		attribute pageCount: Integer;
		attribute topicTrack: SessionTrack;
		attribute status: SubmissionStatus;
		attribute submittedAtUtc: String;
	}

	item def Review {
		attribute reviewId: String;
		attribute submissionId: String;
		attribute reviewerId: String;
		attribute technicalMerit: ScoreValue;
		attribute novelty: ScoreValue;
		attribute relevanceToDAC: ScoreValue;
		attribute clarity: ScoreValue;
		attribute confidence: ScoreValue;
		attribute overallRecommendation: ScoreValue;
		attribute conflictChecked: Boolean;
	}

	item def AcceptedContribution {
		attribute contributionId: String;
		attribute submissionId: String;
		attribute title: String;
		attribute track: SessionTrack;
		attribute presenterId: String;
		attribute presentationDuration: DurationMinutes;
	}

	item def TechnicalSession {
		attribute sessionId: String;
		attribute sessionTitle: String;
		attribute track: SessionTrack;
		attribute roomName: String;
		attribute startTimeUtc: String;
		attribute plannedDuration: DurationMinutes;
		attribute seatCapacity: PersonCount;
		attribute contributionCount: SubmissionCount;
	}

	item def ExhibitionBooth {
		attribute boothId: String;
		attribute exhibitorName: String;
		attribute area: AreaSquareMeters;
		attribute powerRequiredWatts: Real;
		attribute networkBandwidthRequired: DataRateMbps;
		attribute priority: PriorityLevel;
	}

	item def RegistrationRecord {
		attribute registrationId: String;
		attribute attendeeId: String;
		attribute role: AttendeeRole;
		attribute feePaid: MoneyUSD;
		attribute checkedIn: Boolean;
		attribute badgePrinted: Boolean;
	}

	item def ConferenceProgram {
		attribute programId: String;
		attribute sessionCount: SessionCount;
		attribute acceptedPaperCount: SubmissionCount;
		attribute keynoteCount: SessionCount;
		attribute tutorialCount: SessionCount;
		attribute exhibitionBoothCount: BoothCount;
		attribute totalPlannedDuration: DurationHours;
	}

	item def BadgeCredential {
		attribute badgeId: String;
		attribute attendeeId: String;
		attribute accessLevel: AttendeeRole;
		attribute issuedAtUtc: String;
		attribute valid: Boolean;
	}

	item def VenueTelemetry {
		attribute timestampUtc: String;
		attribute roomName: String;
		attribute occupancy: PersonCount;
		attribute temperatureCelsius: Real;
		attribute networkUtilization: Percent;
	}

	item def ConferenceOutcomeReport {
		attribute reportId: String;
		attribute attendanceTotal: PersonCount;
		attribute paperAcceptanceRate: Percent;
		attribute exhibitorSatisfaction: ScoreValue;
		attribute attendeeSatisfaction: ScoreValue;
		attribute sessionUtilization: Percent;
		attribute generatedAtUtc: String;
	}

	port def SubmissionPortalPort {
		in item incomingSubmission: PaperSubmission;
		out item submissionReceipt: PaperSubmission;
	}

	port def ReviewExchangePort {
		out item assignedSubmission: PaperSubmission;
		in item completedReview: Review;
	}

	port def ProgramPublicationPort {
		in item publishableProgram: ConferenceProgram;
		out item publicSession: TechnicalSession;
	}

	port def RegistrationServicePort {
		in item registrationRequest: RegistrationRecord;
		out item issuedBadge: BadgeCredential;
	}

	port def ExhibitionServicePort {
		in item boothRequest: ExhibitionBooth;
		out item confirmedBooth: ExhibitionBooth;
	}

	port def VenueOperationsPort {
		in item plannedSession: TechnicalSession;
		out item liveTelemetry: VenueTelemetry;
	}

	port def AnalyticsPort {
		in item telemetry: VenueTelemetry;
		in item programSnapshot: ConferenceProgram;
		out item outcomeReport: ConferenceOutcomeReport;
	}

	part def CallForPapersManager {
		attribute maximumPageCount: Integer = 8;
		attribute submissionDeadlineUtc: String = "2026-01-23T23:59:59Z";
		attribute expectedSubmissions: SubmissionCount = 2800;
		port authorInterface: SubmissionPortalPort;
		port programCommitteeInterface: ReviewExchangePort;

		action validateSubmission {
			in item submission: PaperSubmission;
			out item validatedSubmission: PaperSubmission;
			attribute maximumAllowedPages: Integer = 8;
		}

		action detectAuthorConflicts {
			in item submission: PaperSubmission;
			out item conflictFreeSubmission: PaperSubmission;
		}
	}

	part def PeerReviewEngine {
		attribute minimumReviewsPerSubmission: Integer = 4;
		attribute maximumReviewerLoad: SubmissionCount = 18;
		attribute conflictThreshold: Percent = 0.0;
		port reviewAssignments: ReviewExchangePort;

		action assignReviewers {
			in item compliantSubmission: PaperSubmission;
			out item assignedSubmission: PaperSubmission;
		}

		action aggregateScores {
			in item review: Review;
			out item rankedSubmission: PaperSubmission;
		}
	}

	part def ProgramCommitteeWorkbench {
		attribute targetAcceptanceRate: Percent = 22.0;
		attribute plannedTechnicalSessions: SessionCount = 180;
		attribute plannedKeynotes: SessionCount = 6;
		port reviewInput: ReviewExchangePort;
		port programOutput: ProgramPublicationPort;

		action selectAcceptedContributions {
			in item rankedSubmission: PaperSubmission;
			out item acceptedContribution: AcceptedContribution;
		}

		action assembleTechnicalProgram {
			in item contribution: AcceptedContribution;
			out item program: ConferenceProgram;
		}
	}

	part def ScheduleOptimizer {
		attribute minimumTransitionTime: DurationMinutes = 15.0;
		attribute maximumParallelSessions: SessionCount = 24;
		attribute averageSessionLength: DurationMinutes = 90.0;
		port programInput: ProgramPublicationPort;
		port venueOutput: VenueOperationsPort;

		action allocateRoomsAndTimes {
			in item program: ConferenceProgram;
			out item scheduledSession: TechnicalSession;
		}

		action minimizeTopicConflicts {
			in item scheduledSession: TechnicalSession;
			out item optimizedSession: TechnicalSession;
		}
	}

	part def RegistrationAndBadgeService {
		attribute expectedAttendance: PersonCount = 8500;
		attribute standardRegistrationFee: MoneyUSD = 995.00;
		attribute studentRegistrationFee: MoneyUSD = 295.00;
		attribute badgePrintTime: DurationMinutes = 0.5;
		port attendeeRegistration: RegistrationServicePort;

		action registerAttendee {
			in item request: RegistrationRecord;
			out item acceptedRecord: RegistrationRecord;
		}

		action issueBadgeCredential {
			in item acceptedRecord: RegistrationRecord;
			out item badge: BadgeCredential;
		}
	}

	part def ExhibitionAutomationService {
		attribute exhibitionArea: AreaSquareMeters = 18500.0;
		attribute maximumBooths: BoothCount = 320;
		attribute minimumBoothArea: AreaSquareMeters = 9.0;
		attribute standardBoothFee: MoneyUSD = 6200.00;
		port exhibitorPortal: ExhibitionServicePort;
		port programPublicity: ProgramPublicationPort;

		action assignBooth {
			in item boothRequest: ExhibitionBooth;
			out item confirmedBooth: ExhibitionBooth;
		}

		action publishExhibitorDemoSchedule {
			in item confirmedBooth: ExhibitionBooth;
			out item demoSession: TechnicalSession;
		}
	}

	part def MobileAndWebExperience {
		attribute maximumConcurrentUsers: PersonCount = 12000;
		attribute targetResponseTime: DurationMinutes = 0.033;
		attribute scheduleRefreshPeriod: DurationMinutes = 5.0;
		port programFeed: ProgramPublicationPort;
		port registrationFeed: RegistrationServicePort;

		action personalizeAgenda {
			in item publicSession: TechnicalSession;
			out item personalizedSession: TechnicalSession;
		}

		action notifyAttendee {
			in item personalizedSession: TechnicalSession;
			out item notification: TechnicalSession;
		}
	}

	part def VenueOperationsController {
		attribute largestRoomCapacity: PersonCount = 3200;
		attribute totalMeetingRooms: SessionCount = 64;
		attribute baselineNetworkBandwidth: DataRateMbps = 40000.0;
		attribute telemetryPeriod: DurationMinutes = 1.0;
		port scheduleInput: VenueOperationsPort;
		port telemetryOutput: AnalyticsPort;

		action configureRoom {
			in item plannedSession: TechnicalSession;
			out item roomReadySession: TechnicalSession;
		}

		action collectTelemetry {
			in item roomReadySession: TechnicalSession;
			out item telemetry: VenueTelemetry;
		}
	}

	part def AnalyticsAndReportingService {
		attribute reportGenerationTimeLimit: DurationMinutes = 10.0;
		attribute targetSurveyResponseRate: Percent = 35.0;
		port analyticsInput: AnalyticsPort;

		action computeConferenceMetrics {
			in item telemetry: VenueTelemetry;
			in item programSnapshot: ConferenceProgram;
			out item outcomeReport: ConferenceOutcomeReport;
		}

		action publishExecutiveSummary {
			in item outcomeReport: ConferenceOutcomeReport;
			out item publishedReport: ConferenceOutcomeReport;
		}
	}

	part def DACAutomationPlatform {
		attribute systemName: String = "Design Automation Conference Integrated Automation Platform";
		attribute primaryFunction: String = "Plan, select, schedule, deliver, and analyze a Design Automation Conference by automating the technical program, exhibition, registration, venue operations, attendee experience, and post-conference reporting.";
		attribute supportedAttendance: PersonCount = 8500;
		attribute supportedSubmissions: SubmissionCount = 2800;
		attribute supportedExhibitionBooths: BoothCount = 320;
		attribute programAvailabilityTarget: Percent = 99.9;
		attribute liveConferenceDuration: DurationHours = 40.0;

		port publicSubmissionPortal: SubmissionPortalPort;
		port publicRegistrationPortal: RegistrationServicePort;
		port publicExhibitorPortal: ExhibitionServicePort;
		port publicProgramPortal: ProgramPublicationPort;
		port venueInterface: VenueOperationsPort;
		port analyticsInterface: AnalyticsPort;

		part cfpManager: CallForPapersManager;
		part reviewEngine: PeerReviewEngine;
		part committeeWorkbench: ProgramCommitteeWorkbench;
		part scheduleOptimizer: ScheduleOptimizer;
		part registrationService: RegistrationAndBadgeService;
		part exhibitionService: ExhibitionAutomationService;
		part attendeeExperience: MobileAndWebExperience;
		part venueController: VenueOperationsController;
		part analyticsService: AnalyticsAndReportingService;

		connect publicSubmissionPortal to cfpManager.authorInterface;
		connect cfpManager.programCommitteeInterface to reviewEngine.reviewAssignments;
		connect reviewEngine.reviewAssignments to committeeWorkbench.reviewInput;
		connect committeeWorkbench.programOutput to scheduleOptimizer.programInput;
		connect scheduleOptimizer.venueOutput to venueController.scheduleInput;
		connect publicRegistrationPortal to registrationService.attendeeRegistration;
		connect publicExhibitorPortal to exhibitionService.exhibitorPortal;
		connect exhibitionService.programPublicity to committeeWorkbench.programOutput;
		connect attendeeExperience.programFeed to committeeWorkbench.programOutput;
		connect attendeeExperience.registrationFeed to registrationService.attendeeRegistration;
		connect venueInterface to venueController.scheduleInput;
		connect venueController.telemetryOutput to analyticsService.analyticsInput;
		connect analyticsInterface to analyticsService.analyticsInput;
		connect publicProgramPortal to committeeWorkbench.programOutput;

		action operateDACAutomationPlatform {
			in item submission: PaperSubmission;
			in item registration: RegistrationRecord;
			in item boothRequest: ExhibitionBooth;
			out item finalProgram: ConferenceProgram;
			out item attendeeBadge: BadgeCredential;
			out item confirmedBooth: ExhibitionBooth;
			out item outcomeReport: ConferenceOutcomeReport;

			first start;
			then receiveAndValidateSubmissions;
			then assignPeerReviews;
			then selectProgram;
			then optimizeSchedule;
			then registerAndBadgeAttendees;
			then allocateExhibition;
			then executeLiveConference;
			then analyzeAndReport;
			then done;

			action receiveAndValidateSubmissions {
				in item submission: PaperSubmission;
				out item compliantSubmission: PaperSubmission;
			}

			action assignPeerReviews {
				in item compliantSubmission: PaperSubmission;
				out item reviewedSubmission: PaperSubmission;
			}

			action selectProgram {
				in item reviewedSubmission: PaperSubmission;
				out item finalProgram: ConferenceProgram;
			}

			action optimizeSchedule {
				in item finalProgram: ConferenceProgram;
				out item scheduledSession: TechnicalSession;
			}

			action registerAndBadgeAttendees {
				in item registration: RegistrationRecord;
				out item attendeeBadge: BadgeCredential;
			}

			action allocateExhibition {
				in item boothRequest: ExhibitionBooth;
				out item confirmedBooth: ExhibitionBooth;
			}

			action executeLiveConference {
				in item scheduledSession: TechnicalSession;
				out item telemetry: VenueTelemetry;
			}

			action analyzeAndReport {
				in item telemetry: VenueTelemetry;
				in item finalProgram: ConferenceProgram;
				out item outcomeReport: ConferenceOutcomeReport;
			}
		}

		state lifecycle {
			state planning;
			state callForContributions;
			state reviewing;
			state programAssembly;
			state registrationOpen;
			state conferenceLive;
			state analyticsReporting;
			state closed;

			initial then planning;

			transition planning_to_callForContributions
				first planning
				then callForContributions;

			transition callForContributions_to_reviewing
				first callForContributions
				then reviewing;

			transition reviewing_to_programAssembly
				first reviewing
				then programAssembly;

			transition programAssembly_to_registrationOpen
				first programAssembly
				then registrationOpen;

			transition registrationOpen_to_conferenceLive
				first registrationOpen
				then conferenceLive;

			transition conferenceLive_to_analyticsReporting
				first conferenceLive
				then analyticsReporting;

			transition analyticsReporting_to_closed
				first analyticsReporting
				then closed;
		}
	}

	requirement def PrimaryFunctionRequirement {
		doc /* The system shall provide a high-level integrated automation capability for a Design Automation Conference, coordinating technical paper intake, peer review, program selection, session scheduling, exhibition logistics, attendee registration, venue execution, and conference outcome reporting. */
		subject platform: DACAutomationPlatform;
		require constraint {
			platform.supportedSubmissions >= 2500 and
			platform.supportedAttendance >= 8000 and
			platform.supportedExhibitionBooths >= 300 and
			platform.programAvailabilityTarget >= 99.5
		}
	}

	requirement def PaperReviewIntegrityRequirement {
		doc /* Each eligible technical submission shall be reviewed by multiple conflict-free reviewers before acceptance decisions are made. */
		subject reviewer: PeerReviewEngine;
		require constraint {
			reviewer.minimumReviewsPerSubmission >= 3 and
			reviewer.conflictThreshold == 0.0
		}
	}

	requirement def ConferenceScheduleRequirement {
		doc /* The conference schedule shall support many parallel sessions while preserving attendee transition time between rooms. */
		subject scheduler: ScheduleOptimizer;
		require constraint {
			scheduler.maximumParallelSessions >= 20 and
			scheduler.minimumTransitionTime >= 10.0
		}
	}

	requirement def ExhibitionCapacityRequirement {
		doc /* The exhibition service shall allocate sufficient booth capacity and floor area for a major DAC exhibition. */
		subject exhibition: ExhibitionAutomationService;
		require constraint {
			exhibition.maximumBooths >= 300 and
			exhibition.exhibitionArea >= 18000.0
		}
	}

	requirement def RegistrationThroughputRequirement {
		doc /* The registration service shall support the expected DAC attendance and issue badges quickly enough for live conference check-in. */
		subject registration: RegistrationAndBadgeService;
		require constraint {
			registration.expectedAttendance >= 8000 and
			registration.badgePrintTime <= 1.0
		}
	}

	requirement def VenueOperationsRequirement {
		doc /* Venue operations shall provide adequate room capacity, networking, and telemetry for live conference execution. */
		subject venue: VenueOperationsController;
		require constraint {
			venue.largestRoomCapacity >= 3000 and
			venue.baselineNetworkBandwidth >= 40000.0 and
			venue.telemetryPeriod <= 1.0
		}
	}

	requirement def AnalyticsReportingRequirement {
		doc /* The analytics service shall generate a post-conference outcome report within the specified time limit. */
		subject analytics: AnalyticsAndReportingService;
		require constraint {
			analytics.reportGenerationTimeLimit <= 10.0 and
			analytics.targetSurveyResponseRate >= 30.0
		}
	}

	part dacConferenceAutomationSystem: DACAutomationPlatform;

	requirement primaryFunctionRequirement: PrimaryFunctionRequirement {
		subject platform = dacConferenceAutomationSystem;
	}

	requirement paperReviewIntegrityRequirement: PaperReviewIntegrityRequirement {
		subject reviewer = dacConferenceAutomationSystem.reviewEngine;
	}

	requirement conferenceScheduleRequirement: ConferenceScheduleRequirement {
		subject scheduler = dacConferenceAutomationSystem.scheduleOptimizer;
	}

	requirement exhibitionCapacityRequirement: ExhibitionCapacityRequirement {
		subject exhibition = dacConferenceAutomationSystem.exhibitionService;
	}

	requirement registrationThroughputRequirement: RegistrationThroughputRequirement {
		subject registration = dacConferenceAutomationSystem.registrationService;
	}

	requirement venueOperationsRequirement: VenueOperationsRequirement {
		subject venue = dacConferenceAutomationSystem.venueController;
	}

	requirement analyticsReportingRequirement: AnalyticsReportingRequirement {
		subject analytics = dacConferenceAutomationSystem.analyticsService;
	}

	satisfy primaryFunctionRequirement by dacConferenceAutomationSystem;
	satisfy paperReviewIntegrityRequirement by dacConferenceAutomationSystem.reviewEngine;
	satisfy conferenceScheduleRequirement by dacConferenceAutomationSystem.scheduleOptimizer;
	satisfy exhibitionCapacityRequirement by dacConferenceAutomationSystem.exhibitionService;
	satisfy registrationThroughputRequirement by dacConferenceAutomationSystem.registrationService;
	satisfy venueOperationsRequirement by dacConferenceAutomationSystem.venueController;
	satisfy analyticsReportingRequirement by dacConferenceAutomationSystem.analyticsService;
}
