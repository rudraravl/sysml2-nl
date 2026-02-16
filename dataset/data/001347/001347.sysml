package ASPDACConferenceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def ConferenceYear :> Integer;
    attribute def SessionCount :> Integer;
    attribute def AttendeeCount :> Integer;
    attribute def PaperCount :> Integer;

    attribute def PaperStatus :> String;
    attribute def RegistrationType :> String;
    attribute def ReviewScore :> Real;

    item def TechnicalPaper {
        attribute paperID : String;
        attribute title : String;
        attribute authors : String[1..*];
        attribute affiliation : String[1..*];
        attribute status : PaperStatus;
        attribute reviewScore : ReviewScore;
        attribute sessionAssignment : String;
        attribute submissionDate : String;
    }

    item def Attendee {
        attribute attendeeID : String;
        attribute name : String;
        attribute affiliation : String;
        attribute registrationType : RegistrationType;
        attribute registrationDate : String;
    }

    item def ConferenceSession {
        attribute sessionID : String;
        attribute sessionTitle : String;
        attribute sessionChair : String;
        attribute scheduledTime : String;
        attribute venue : String;
        attribute papers : TechnicalPaper[0..*];
    }

    item def ReviewAssignment {
        attribute paperID : String;
        attribute reviewerID : String;
        attribute assignmentDate : String;
    }

    item def SubmissionConfirmation {
        attribute confirmationID : String;
        attribute paperID : String;
        attribute timestamp : String;
    }

    item def RegistrationConfirmation {
        attribute confirmationID : String;
        attribute attendeeID : String;
        attribute timestamp : String;
    }

    port def SubmissionPort {
        in item paperSubmission : TechnicalPaper;
        out item submissionConfirmation : SubmissionConfirmation;
    }

    port def ReviewPort {
        in item paperForReview : TechnicalPaper;
        out item reviewResult : ReviewScore;
    }

    port def RegistrationPort {
        in item attendeeRegistration : Attendee;
        out item registrationConfirmation : RegistrationConfirmation;
    }

    port def PresentationPort {
        in item sessionSchedule : ConferenceSession;
        out item presentationMaterials : String;
    }

    port def NotificationPort {
        out item notification : String;
    }

    part def PaperManagementSystem {
        attribute totalSubmissions : Integer;
        attribute acceptedPapers : Integer;
        attribute rejectedPapers : Integer;
        attribute submissionDeadline : String;

        port submissionInterface : SubmissionPort;
        port reviewInterface : ReviewPort;
        port notificationOut : NotificationPort;

        perform action managePapers;
    }

    part def ReviewCommittee {
        attribute reviewerCount : Integer;
        attribute averageReviewTime : DurationValue;
        attribute minimumReviewsPerPaper : Integer;

        port reviewInput : ReviewPort;
        port notificationOut : NotificationPort;

        perform action conductReviews;
    }

    part def RegistrationSystem {
        attribute totalRegistrations : Integer;
        attribute earlyBirdCount : Integer;
        attribute regularCount : Integer;
        attribute registrationDeadline : String;

        port registrationInterface : RegistrationPort;
        port notificationOut : NotificationPort;

        perform action processRegistrations;
    }

    part def SessionScheduler {
        attribute totalSessions : Integer;
        attribute parallelTracks : Integer;
        attribute conferenceDays : Integer;

        port sessionInterface : PresentationPort;
        port notificationOut : NotificationPort;

        perform action scheduleSessions;
    }

    part def VenueManagement {
        attribute venueName : String;
        attribute roomCapacity : Integer[1..*];
        attribute availableRooms : Integer;
        attribute location : String;

        perform action manageVenue;
    }

    action def ReceivePaperSubmission {
        in paper : TechnicalPaper;
        out confirmationID : String;
    }

    action def AssignReviewers {
        in paper : TechnicalPaper;
        out assignedReviewers : String[3..5];
    }

    action def CollectReviews {
        in paper : TechnicalPaper;
        out averageScore : ReviewScore;
    }

    action def MakeAcceptanceDecision {
        in reviewScore : ReviewScore;
        out decision : PaperStatus;
    }

    action def NotifyAuthors {
        in paper : TechnicalPaper;
        in decision : PaperStatus;
    }

    action def CreateSessionSchedule {
        in acceptedPapers : TechnicalPaper[1..*];
        out sessions : ConferenceSession[1..*];
    }

    action def RegisterAttendee {
        in attendee : Attendee;
        out badge : String;
    }

    action def ConductConference {
        in sessions : ConferenceSession[1..*];
        in attendees : Attendee[1..*];
    }

    action def ManageASPDACConference {
        first start;
        then merge paperSubmissionPhase;

        action paperSubmissionPhase {
            action receivePapers : ReceivePaperSubmission {
                in paper : TechnicalPaper;
                out confirmationID : String;
            }
        }
        then reviewPhase;

        action reviewPhase {
            action assignReviewers : AssignReviewers {
                in paper : TechnicalPaper;
                out assignedReviewers : String[3..5];
            }
            then action collectReviews : CollectReviews {
                in paper : TechnicalPaper;
                out averageScore : ReviewScore;
            }
            then action makeDecision : MakeAcceptanceDecision {
                in reviewScore : ReviewScore;
                out decision : PaperStatus;
            }
            then action notifyAuthors : NotifyAuthors {
                in paper : TechnicalPaper;
                in decision : PaperStatus;
            }
        }
        then schedulePhase;

        action schedulePhase {
            action createSchedule : CreateSessionSchedule;
        }
        then registrationPhase;

        action registrationPhase {
            action registerAttendees : RegisterAttendee;
        }
        then conferenceExecution;

        action conferenceExecution : ConductConference;
        then done;
    }

    state def ConferenceLifecycle {
        entry; then planning;

        state planning {
            entry; then callForPapers;
            state callForPapers;
            accept at callForPapers then reviewing;
        }

        state reviewing {
            entry; then peerReview;
            state peerReview;
            accept at peerReview then programCreation;
        }

        state programCreation {
            entry; then scheduleBuilding;
            state scheduleBuilding;
            accept at scheduleBuilding then registration;
        }

        state registration {
            entry; then openRegistration;
            state openRegistration;
            accept at openRegistration then execution;
        }

        state execution {
            entry; then conferenceInProgress;
            state conferenceInProgress;
            accept at conferenceInProgress then postConference;
        }

        state postConference {
            entry; then archiving;
            state archiving;
            accept at archiving then done;
        }
    }

    part def ASPDACConferenceSystem {
        attribute conferenceYear : ConferenceYear;
        attribute conferenceName : String = "Asia and South Pacific Design Automation Conference";
        attribute focusArea : String = "Electronic Design Automation";
        attribute expectedAttendees : Integer;
        attribute expectedSubmissions : Integer;
        attribute acceptanceRate : Real;

        part paperMgmt : PaperManagementSystem {
            attribute :>> totalSubmissions : Integer;
            attribute :>> acceptedPapers : Integer;
            attribute :>> submissionDeadline = "2024-09-15";
        }

        part reviewCommittee : ReviewCommittee {
            attribute :>> reviewerCount : Integer;
            attribute :>> minimumReviewsPerPaper = 3;
        }

        part registrationSys : RegistrationSystem {
            attribute :>> totalRegistrations : Integer;
            attribute :>> registrationDeadline = "2024-12-01";
        }

        part sessionScheduler : SessionScheduler {
            attribute :>> totalSessions : Integer;
            attribute :>> parallelTracks : Integer;
            attribute :>> conferenceDays = 3;
        }

        part venueMgmt : VenueManagement {
            attribute :>> venueName : String;
            attribute :>> location = "Seoul, South Korea";
        }

        connection submissionFlow connect 
            paperMgmt.submissionInterface to reviewCommittee.reviewInput;

        perform action conferenceOperation : ManageASPDACConference;

        exhibit state conferenceState : ConferenceLifecycle;
    }

    requirement <'REQ-ASPDAC-001'> primaryMission {
        doc /* The ASPDAC Conference System shall facilitate the complete lifecycle 
             * of an international technical conference focused on design automation,
             * from paper submission through peer review, program creation, attendee
             * registration, and conference execution.
             */
        subject conference : ASPDACConferenceSystem;
    }

    requirement <'REQ-ASPDAC-002'> paperManagement {
        doc /* The system shall manage the submission, review, and acceptance of
             * technical papers in the field of electronic design automation.
             */
        subject paperSystem : PaperManagementSystem;

        assert constraint {
            paperSystem.acceptedPapers <= paperSystem.totalSubmissions
        }
    }

    requirement <'REQ-ASPDAC-003'> reviewQuality {
        doc /* Each submitted paper shall receive at least 3 independent reviews
             * from qualified reviewers in the technical program committee.
             */
        subject reviewSys : ReviewCommittee;

        assert constraint {
            reviewSys.reviewerCount >= 30 and
            reviewSys.minimumReviewsPerPaper >= 3
        }
    }

    requirement <'REQ-ASPDAC-004'> sessionOrganization {
        doc /* The system shall organize accepted papers into technical sessions
             * with appropriate themes and scheduling across multiple parallel tracks.
             */
        subject scheduler : SessionScheduler;

        assert constraint {
            scheduler.parallelTracks >= 3 and scheduler.parallelTracks <= 8
        }
    }

    requirement <'REQ-ASPDAC-005'> attendeeCapacity {
        doc /* The conference system shall support registration and management
             * of at least 500 attendees from academia and industry.
             */
        subject conference : ASPDACConferenceSystem;

        assert constraint {
            conference.expectedAttendees >= 500
        }
    }

    part aspdac2024 : ASPDACConferenceSystem {
        attribute :>> conferenceYear = 2024;
        attribute :>> expectedAttendees = 650;
        attribute :>> expectedSubmissions = 400;
        attribute :>> acceptanceRate = 0.28;

        part :>> paperMgmt {
            attribute :>> totalSubmissions = 400;
            attribute :>> acceptedPapers = 112;
            attribute :>> rejectedPapers = 288;
        }

        part :>> reviewCommittee {
            attribute :>> reviewerCount = 85;
        }

        part :>> registrationSys {
            attribute :>> totalRegistrations = 650;
            attribute :>> earlyBirdCount = 420;
            attribute :>> regularCount = 230;
        }

        part :>> sessionScheduler {
            attribute :>> totalSessions = 28;
            attribute :>> parallelTracks = 6;
        }

        part :>> venueMgmt {
            attribute :>> venueName = "International Convention Center";
            attribute :>> availableRooms = 12;
        }
    }

    satisfy primaryMission by aspdac2024;
    satisfy paperManagement by aspdac2024.paperMgmt;
    satisfy reviewQuality by aspdac2024.reviewCommittee;
    satisfy sessionOrganization by aspdac2024.sessionScheduler;
    satisfy attendeeCapacity by aspdac2024;
}
