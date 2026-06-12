package ICCADConferenceSystemModel {

    import ScalarValues::*;
    import SI::*;

    attribute def AttendeeCount :> ScalarValues::Integer;
    attribute def PaperCount :> ScalarValues::Integer;
    attribute def SessionCount :> ScalarValues::Integer;
    attribute def ReviewScore :> ScalarValues::Real;
    attribute def RegistrationFee :> ScalarValues::Real {
        unit = "$";
    }
    attribute def DurationMinutes :> ScalarValues::Real {
        unit = "min";
    }
    attribute def BandwidthMbps :> ScalarValues::Real {
        unit = "Mbit/s";
    }
    attribute def StorageGB :> ScalarValues::Real {
        unit = "GB";
    }

    item def Manuscript {
        attribute paperId : ScalarValues::String;
        attribute title : ScalarValues::String;
        attribute abstractText : ScalarValues::String;
        attribute pageCount : ScalarValues::Integer;
        attribute isCameraReady : ScalarValues::Boolean;
    }

    item def Review {
        attribute reviewerId : ScalarValues::String;
        attribute technicalScore : ReviewScore;
        attribute originalityScore : ReviewScore;
        attribute clarityScore : ReviewScore;
        attribute confidenceScore : ReviewScore;
        attribute recommendation : ScalarValues::String;
    }

    item def Decision {
        attribute paperId : ScalarValues::String;
        attribute accepted : ScalarValues::Boolean;
        attribute presentationType : ScalarValues::String;
        attribute notificationText : ScalarValues::String;
    }

    item def RegistrationRecord {
        attribute attendeeId : ScalarValues::String;
        attribute badgeName : ScalarValues::String;
        attribute affiliation : ScalarValues::String;
        attribute feePaid : RegistrationFee;
        attribute checkedIn : ScalarValues::Boolean;
    }

    item def PresentationStream {
        attribute streamId : ScalarValues::String;
        attribute bitrate : BandwidthMbps;
        attribute duration : DurationMinutes;
        attribute recordingEnabled : ScalarValues::Boolean;
    }

    item def ScheduleEntry {
        attribute sessionId : ScalarValues::String;
        attribute roomName : ScalarValues::String;
        attribute startMinuteOfDay : DurationMinutes;
        attribute duration : DurationMinutes;
        attribute trackName : ScalarValues::String;
    }

    port def ManuscriptInPort {
        in item manuscript : Manuscript;
    }

    port def ReviewOutPort {
        out item review : Review;
    }

    port def ReviewInPort {
        in item review : Review;
    }

    port def DecisionOutPort {
        out item decision : Decision;
    }

    port def RegistrationInPort {
        in item registration : RegistrationRecord;
    }

    port def ScheduleOutPort {
        out item scheduleEntry : ScheduleEntry;
    }

    port def StreamOutPort {
        out item stream : PresentationStream;
    }

    port def StreamInPort {
        in item stream : PresentationStream;
    }

    port def PaymentPort {
        in item registration : RegistrationRecord;
        out item receipt : RegistrationRecord;
    }

    action def ReceiveSubmission {
        in item submittedPaper : Manuscript;
        out item storedPaper : Manuscript;
    }

    action def AssignReviewers {
        in item storedPaper : Manuscript;
        out item reviewRequest : Manuscript;
    }

    action def CollectReviews {
        in item completedReview : Review;
        out item validatedReview : Review;
    }

    action def MakeAcceptanceDecision {
        in item paper : Manuscript;
        in item reviewA : Review;
        in item reviewB : Review;
        in item reviewC : Review;
        out item decision : Decision;
    }

    action def BuildTechnicalProgram {
        in item decision : Decision;
        out item scheduleEntry : ScheduleEntry;
    }

    action def RegisterAttendee {
        in item registrationRequest : RegistrationRecord;
        out item confirmedRegistration : RegistrationRecord;
    }

    action def DeliverPresentation {
        in item scheduleEntry : ScheduleEntry;
        out item stream : PresentationStream;
    }

    state def ConferenceLifecycle {
        state planning;
        state submissionOpen;
        state review;
        state decisionNotification;
        state programPublished;
        state liveConference;
        state proceedingsArchived;

        transition first planning then submissionOpen;
        transition planning_to_submission
            first planning
            then submissionOpen;

        transition submission_to_review
            first submissionOpen
            then review;

        transition review_to_notification
            first review
            then decisionNotification;

        transition notification_to_program
            first decisionNotification
            then programPublished;

        transition program_to_live
            first programPublished
            then liveConference;

        transition live_to_archive
            first liveConference
            then proceedingsArchived;
    }

    part def SubmissionPortal {
        attribute maxSubmissions : PaperCount = 1200;
        attribute storageCapacity : StorageGB = 500;
        attribute submissionDeadlineMinute : DurationMinutes = 1439;

        port manuscriptInput : ManuscriptInPort;
        port paperForReview : ManuscriptInPort;

        perform action receive : ReceiveSubmission;
    }

    part def ReviewManagementSystem {
        attribute minimumReviewsPerPaper : ScalarValues::Integer = 3;
        attribute targetReviewPeriod : DurationMinutes = 43200;
        attribute conflictCheckEnabled : ScalarValues::Boolean = true;

        port manuscriptQueue : ManuscriptInPort;
        port reviewInput : ReviewInPort;
        port decisionOutput : DecisionOutPort;

        perform action assign : AssignReviewers;
        perform action collect : CollectReviews;
        perform action decide : MakeAcceptanceDecision;
    }

    part def TechnicalProgramSystem {
        attribute parallelTracks : ScalarValues::Integer = 6;
        attribute acceptedPaperLimit : PaperCount = 350;
        attribute keynoteCount : SessionCount = 4;
        attribute sessionDuration : DurationMinutes = 90;

        port decisionInput : DecisionOutPort;
        port scheduleOutput : ScheduleOutPort;

        perform action buildProgram : BuildTechnicalProgram;
    }

    part def RegistrationSystem {
        attribute attendeeCapacity : AttendeeCount = 2500;
        attribute studentFee : RegistrationFee = 350;
        attribute professionalFee : RegistrationFee = 850;
        attribute onsiteCheckInStations : ScalarValues::Integer = 12;

        port registrationInput : RegistrationInPort;
        port payment : PaymentPort;

        perform action register : RegisterAttendee;
    }

    part def HybridVenueSystem {
        attribute physicalRoomCount : ScalarValues::Integer = 18;
        attribute streamingBandwidth : BandwidthMbps = 2500;
        attribute recordingStorage : StorageGB = 12000;
        attribute averageSessionLength : DurationMinutes = 90;

        port scheduleInput : ScheduleOutPort;
        port streamOutput : StreamOutPort;

        perform action deliver : DeliverPresentation;
    }

    part def ProceedingsArchive {
        attribute archivedPaperCapacity : PaperCount = 1000;
        attribute digitalLibraryStorage : StorageGB = 2000;
        attribute doiAssignmentEnabled : ScalarValues::Boolean = true;

        port finalDecisionInput : DecisionOutPort;
        port presentationStreamInput : StreamInPort;
    }

    part def ICCADConferenceSystem {
        doc
        /*
         * Primary high-level function:
         * The system organizes and operates an International Conference on
         * Computer-Aided Design by collecting research submissions, coordinating
         * peer review, selecting accepted papers, building the technical program,
         * registering participants, delivering sessions, and archiving the final
         * proceedings.
         */

        attribute plannedAttendance : AttendeeCount = 2200;
        attribute expectedSubmissions : PaperCount = 950;
        attribute plannedSessions : SessionCount = 120;
        attribute conferenceDuration : DurationMinutes = 4320;

        part submissionPortal : SubmissionPortal;
        part reviewSystem : ReviewManagementSystem;
        part programSystem : TechnicalProgramSystem;
        part registrationSystem : RegistrationSystem;
        part venueSystem : HybridVenueSystem;
        part archive : ProceedingsArchive;

        port authorSubmissionPort : ManuscriptInPort;
        port attendeeRegistrationPort : RegistrationInPort;
        port publicSchedulePort : ScheduleOutPort;
        port publicStreamPort : StreamOutPort;

        connection authorSubmissionFlow
            connect authorSubmissionPort to submissionPortal.manuscriptInput;

        connection submissionToReviewFlow
            connect submissionPortal.paperForReview to reviewSystem.manuscriptQueue;

        connection decisionToProgramFlow
            connect reviewSystem.decisionOutput to programSystem.decisionInput;

        connection decisionToArchiveFlow
            connect reviewSystem.decisionOutput to archive.finalDecisionInput;

        connection registrationFlow
            connect attendeeRegistrationPort to registrationSystem.registrationInput;

        connection schedulePublicationFlow
            connect programSystem.scheduleOutput to publicSchedulePort;

        connection scheduleToVenueFlow
            connect programSystem.scheduleOutput to venueSystem.scheduleInput;

        connection streamPublicationFlow
            connect venueSystem.streamOutput to publicStreamPort;

        connection streamArchiveFlow
            connect venueSystem.streamOutput to archive.presentationStreamInput;

        perform action receiveSubmissions : ReceiveSubmission;
        perform action coordinateReviews : AssignReviewers;
        perform action collectPeerReviews : CollectReviews;
        perform action selectAcceptedPapers : MakeAcceptanceDecision;
        perform action publishProgram : BuildTechnicalProgram;
        perform action processRegistrations : RegisterAttendee;
        perform action runConferenceSessions : DeliverPresentation;

        exhibit state lifecycle : ConferenceLifecycle;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : ICCADConferenceSystem;
        require constraint {
            system.expectedSubmissions >= 500 and
            system.plannedSessions >= 80 and
            system.plannedAttendance >= 1000
        }
    }

    requirement def PeerReviewRequirement {
        subject reviewSystem : ReviewManagementSystem;
        require constraint {
            reviewSystem.minimumReviewsPerPaper >= 3 and
            reviewSystem.conflictCheckEnabled == true
        }
    }

    requirement def ProgramCapacityRequirement {
        subject programSystem : TechnicalProgramSystem;
        require constraint {
            programSystem.parallelTracks >= 4 and
            programSystem.acceptedPaperLimit <= 400
        }
    }

    requirement def RegistrationCapacityRequirement {
        subject registrationSystem : RegistrationSystem;
        require constraint {
            registrationSystem.attendeeCapacity >= 2000 and
            registrationSystem.onsiteCheckInStations >= 8
        }
    }

    requirement def HybridDeliveryRequirement {
        subject venueSystem : HybridVenueSystem;
        require constraint {
            venueSystem.streamingBandwidth >= 1000 and
            venueSystem.physicalRoomCount >= 12 and
            venueSystem.recordingStorage >= 5000
        }
    }

    requirement def ProceedingsArchiveRequirement {
        subject archive : ProceedingsArchive;
        require constraint {
            archive.archivedPaperCapacity >= 500 and
            archive.doiAssignmentEnabled == true
        }
    }

    satisfy PrimaryFunctionRequirement by ICCADConferenceSystem;
    satisfy PeerReviewRequirement by ICCADConferenceSystem::reviewSystem;
    satisfy ProgramCapacityRequirement by ICCADConferenceSystem::programSystem;
    satisfy RegistrationCapacityRequirement by ICCADConferenceSystem::registrationSystem;
    satisfy HybridDeliveryRequirement by ICCADConferenceSystem::venueSystem;
    satisfy ProceedingsArchiveRequirement by ICCADConferenceSystem::archive;
}