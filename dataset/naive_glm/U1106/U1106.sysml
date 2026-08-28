package ICCADConferenceManagementSystem {

    import ScalarValues::*;

    package Units {
        unit usd;
        unit person;
        unit paper;
        unit reviewer;
        unit minute;
        unit track;
        unit day;
        unit percent;
    }

    package Types {

        value type DateValue :> DateTime;

        value type Percentage :> Real {
            unit percent;
        }

        value type ScoreValue :> Integer {
            doc /* Review score on a 1 to 5 scale. */;
        }

        value type CapacityValue :> Integer {
            unit person;
        }

        value type PaperCount :> Integer {
            unit paper;
        }

        value type ReviewerCount :> Integer {
            unit reviewer;
        }

        value type MoneyAmount :> Real {
            unit usd;
        }

        value type DurationMinutes :> Integer {
            unit minute;
        }

        value type TrackCount :> Integer {
            unit track;
        }

        value type DayCount :> Integer {
            unit day;
        }

        value type PaperId :> String;
        value type SessionId :> String;
        value type DOIString :> String;

        enum def PaperStatus {
            submitted;
            validated;
            underReview;
            accepted;
            rejected;
            revisionRequested;
            finalized;
        }

        enum def ReviewDecision {
            accept;
            reject;
            revise;
        }

        enum def RegistrationType {
            student;
            academic;
            industry;
        }

        enum def SessionType {
            paperSession;
            keynote;
            panel;
            workshop;
        }

        enum def PaymentStatus {
            pending;
            completed;
            failed;
            refunded;
        }
    }

    package Items {

        item def Paper {
            attribute id : Types::PaperId;
            attribute title : String;
            attribute authors : String[0..*];
            attribute abstractText : String;
            attribute keywords : String[0..*];
            attribute topic : String;
            attribute status : Types::PaperStatus = Types::PaperStatus::submitted;
            attribute submissionDate : Types::DateValue;
            attribute doi : Types::DOIString[0..1];
            attribute pageCount : Integer;
        }

        item def Review {
            attribute paperId : Types::PaperId;
            attribute reviewerId : String;
            attribute technicalMerit : Types::ScoreValue;
            attribute novelty : Types::ScoreValue;
            attribute presentation : Types::ScoreValue;
            attribute overallScore : Types::ScoreValue;
            attribute comments : String;
            attribute confidentialComments : String;
            attribute recommendation : Types::ReviewDecision;
            attribute reviewDate : Types::DateValue;
        }

        item def ReviewAssignment {
            attribute paperId : Types::PaperId;
            attribute reviewerIds : String[3];
            attribute assignedDate : Types::DateValue;
            attribute deadline : Types::DateValue;
            attribute completedCount : Integer = 0;
        }

        item def Registration {
            attribute registrationId : String;
            attribute participantName : String;
            attribute affiliation : String;
            attribute registrationType : Types::RegistrationType;
            attribute email : String;
            attribute amountPaid : Types::MoneyAmount;
            attribute paymentStatus : Types::PaymentStatus = Types::PaymentStatus::pending;
            attribute registrationDate : Types::DateValue;
            attribute confirmed : Boolean = false;
            attribute isWaitlisted : Boolean = false;
        }

        item def Session {
            attribute sessionId : Types::SessionId;
            attribute sessionType : Types::SessionType;
            attribute title : String;
            attribute room : String;
            attribute startTime : Types::DateValue;
            attribute duration : Types::DurationMinutes;
            attribute trackNumber : Integer;
            attribute dayNumber : Integer;
            attribute chair : String;
            attribute paperIds : Types::PaperId[0..*];
        }

        item def ConferenceProgram {
            attribute sessions : Session[0..*];
            attribute numTracks : Types::TrackCount;
            attribute numDays : Types::DayCount;
            attribute conferenceTitle : String;
        }

        item def Proceedings {
            attribute papers : Paper[0..*];
            attribute volumeTitle : String;
            attribute isbn : String;
            attribute publicationDate : Types::DateValue;
            attribute digitalLibraryURL : String;
            attribute editorCount : Integer;
        }

        item def Acknowledgement {
            attribute paperId : Types::PaperId;
            attribute authorEmail : String;
            attribute message : String;
            attribute date : Types::DateValue;
        }

        item def Confirmation {
            attribute registrationId : String;
            attribute participantEmail : String;
            attribute message : String;
            attribute date : Types::DateValue;
        }

        item def DecisionNotification {
            attribute paperId : Types::PaperId;
            attribute decision : Types::ReviewDecision;
            attribute authorEmail : String;
            attribute date : Types::DateValue;
        }
    }

    package Calculations {

        calc def CalculateOverallScore {
            in technicalMerit : Types::ScoreValue;
            in novelty : Types::ScoreValue;
            in presentation : Types::ScoreValue;
            out overallScore : Types::ScoreValue;
            doc /* Computes a weighted overall review score. */;
        }

        calc def CalculateAcceptanceRate {
            in acceptedCount : Types::PaperCount;
            in totalCount : Types::PaperCount;
            out rate : Types::Percentage;
            doc /* Computes the acceptance rate as accepted divided by total. */;
        }

        calc def CalculateRegistrationFee {
            in registrationType : Types::RegistrationType;
            in isEarlyBird : Boolean;
            in earlyBirdFee : Types::MoneyAmount;
            in regularFee : Types::MoneyAmount;
            in studentFee : Types::MoneyAmount;
            out fee : Types::MoneyAmount;
            doc /* Determines the registration fee based on type and timing. */;
        }
    }

    package Behaviors {

        state def SubmissionLifecycle {
            entry; then open;

            attribute submissionReceived : Boolean = false;
            attribute validationPassed : Boolean = false;
            attribute validationFailed : Boolean = false;
            attribute deadlineReached : Boolean = false;
            attribute moreExpected : Boolean = true;

            state open {
                doc /* Accepting new paper submissions. */;
            }
            state validating {
                doc /* Checking formatting and completeness. */;
            }
            state acknowledged {
                doc /* Acknowledgement sent to author. */;
            }
            state closed {
                doc /* Submission deadline has passed. */;
            }

            transition from open to validating
                when submissionReceived;
            transition from validating to acknowledged
                when validationPassed;
            transition from validating to open
                when validationFailed;
            transition from acknowledged to open
                when moreExpected;
            transition from open to closed
                when deadlineReached;
        }

        state def ReviewLifecycle {
            entry; then assigning;

            attribute reviewersAssigned : Boolean = false;
            attribute allReviewsReceived : Boolean = false;
            attribute decisionMade : Boolean = false;

            state assigning {
                doc /* Assigning three reviewers to each paper. */;
            }
            state inReview {
                doc /* Reviewers evaluating assigned papers. */;
            }
            state aggregating {
                doc /* Aggregating independent review scores. */;
            }
            state decided {
                doc /* Final accept, reject, or revise decision made. */;
            }

            transition from assigning to inReview
                when reviewersAssigned;
            transition from inReview to aggregating
                when allReviewsReceived;
            transition from aggregating to decided
                when decisionMade;
        }

        state def RegistrationLifecycle {
            entry; then earlyBirdOpen;

            attribute earlyBirdDeadlinePassed : Boolean = false;
            attribute capacityReached : Boolean = false;
            attribute registrationRequested : Boolean = false;
            attribute registrationDeadlinePassed : Boolean = false;
            attribute spotAvailable : Boolean = false;

            state earlyBirdOpen {
                doc /* Early-bird registration with discounted fees. */;
            }
            state regularOpen {
                doc /* Regular registration period. */;
            }
            state full {
                doc /* Maximum venue capacity reached. */;
            }
            state waitlist {
                doc /* Managing waitlist for additional registrants. */;
            }
            state closed {
                doc /* Registration period ended. */;
            }

            transition from earlyBirdOpen to regularOpen
                when earlyBirdDeadlinePassed;
            transition from regularOpen to full
                when capacityReached;
            transition from full to waitlist
                when registrationRequested;
            transition from regularOpen to closed
                when registrationDeadlinePassed;
            transition from waitlist to regularOpen
                when spotAvailable;
        }

        state def SchedulingLifecycle {
            entry; then collecting;

            attribute allPapersCollected : Boolean = false;
            attribute topicsGrouped : Boolean = false;
            attribute scheduleFinalized : Boolean = false;

            state collecting {
                doc /* Collecting all accepted and finalized papers. */;
            }
            state grouping {
                doc /* Grouping papers by research topic. */;
            }
            state assigning {
                doc /* Assigning time slots, rooms, and tracks. */;
            }
            state published {
                doc /* Final conference program published. */;
            }

            transition from collecting to grouping
                when allPapersCollected;
            transition from grouping to assigning
                when topicsGrouped;
            transition from assigning to published
                when scheduleFinalized;
        }

        state def PublicationLifecycle {
            entry; then collecting;

            attribute allPapersCollected : Boolean = false;
            attribute compilationComplete : Boolean = false;
            attribute doIsAssigned : Boolean = false;

            state collecting {
                doc /* Collecting all finalized camera-ready papers. */;
            }
            state compiling {
                doc /* Compiling papers into a single proceedings volume. */;
            }
            state assigningDOI {
                doc /* Assigning permanent DOI identifiers. */;
            }
            state published {
                doc /* Proceedings uploaded to digital library. */;
            }

            transition from collecting to compiling
                when allPapersCollected;
            transition from compiling to assigningDOI
                when compilationComplete;
            transition from assigningDOI to published
                when doIsAssigned;
        }
    }

    package Subsystems {

        part def PaperSubmissionSystem {
            doc /* Entry point for researchers to submit papers. Validates formatting and enforces deadlines. */;

            in port paperIn : Items::Paper;
            out port paperToReview : Items::Paper;
            out port acknowledgementOut : Items::Acknowledgement;

            attribute submissionDeadline : Types::DateValue;
            attribute paperDatabase : Items::Paper[0..*];
            attribute formattingRules : String[0..*];
            attribute maxPaperLength : Integer = 8;
            attribute submissionReceived : Boolean = false;
            attribute validationPassed : Boolean = false;
            attribute validationFailed : Boolean = false;
            attribute deadlineReached : Boolean = false;
            attribute moreExpected : Boolean = true;

            exhibit Behaviors::SubmissionLifecycle;

            action def validateSubmission {
                in paper : Items::Paper;
                out valid : Boolean;
                doc /* Checks that the paper meets formatting requirements. */;
            }

            action def sendAcknowledgement {
                in paper : Items::Paper;
                out ack : Items::Acknowledgement;
                doc /* Sends confirmation to the author that the paper was received. */;
            }

            action def storePaper {
                in paper : Items::Paper;
                out storedPaper : Items::Paper;
                doc /* Stores the paper in the central database. */;
            }

            action def checkDeadline {
                in currentDate : Types::DateValue;
                in deadline : Types::DateValue;
                out passed : Boolean;
                doc /* Determines whether the submission deadline has passed. */;
            }
        }

        part def PeerReviewSystem {
            doc /* Manages the peer review quality control process with three reviewers per paper. */;

            in port paperIn : Items::Paper;
            out port acceptedPaperOut : Items::Paper;
            out port rejectedPaperOut : Items::Paper;
            out port revisionPaperOut : Items::Paper;
            out port reviewOut : Items::Review;
            out port notificationOut : Items::DecisionNotification;

            attribute reviewDeadline : Types::DateValue;
            attribute targetAcceptanceRate : Types::Percentage = 25;
            attribute reviewerPool : String[0..*];
            attribute reviews : Items::Review[0..*];
            attribute assignments : Items::ReviewAssignment[0..*];
            attribute reviewersPerPaper : Integer = 3;
            attribute reviewersAssigned : Boolean = false;
            attribute allReviewsReceived : Boolean = false;
            attribute decisionMade : Boolean = false;

            exhibit Behaviors::ReviewLifecycle;

            action def assignReviewers {
                in paper : Items::Paper;
                in reviewerPool : String[0..*];
                out assignment : Items::ReviewAssignment;
                doc /* Assigns three qualified reviewers to a paper. */;
            }

            action def aggregateReviews {
                in reviews : Items::Review[3];
                out decision : Types::ReviewDecision;
                out overallScore : Types::ScoreValue;
                doc /* Aggregates three independent reviews into a final decision. */;
            }

            action def checkAcceptanceRate {
                in acceptedCount : Types::PaperCount;
                in totalCount : Types::PaperCount;
                out rate : Types::Percentage;
                doc /* Verifies the acceptance rate is within the target range. */;
            }

            action def sendDecisionNotification {
                in paperId : Types::PaperId;
                in decision : Types::ReviewDecision;
                in authorEmail : String;
                out notification : Items::DecisionNotification;
                doc /* Notifies the author of the review decision. */;
            }
        }

        part def RegistrationSystem {
            doc /* Handles attendee registration, payments, capacity management, and waitlisting. */;

            in port registrationIn : Items::Registration;
            in port programIn : Items::ConferenceProgram;
            out port confirmationOut : Items::Confirmation;

            attribute maxCapacity : Types::CapacityValue;
            attribute earlyBirdDeadline : Types::DateValue;
            attribute regularDeadline : Types::DateValue;
            attribute registrations : Items::Registration[0..*];
            attribute waitlist : Items::Registration[0..*];
            attribute earlyBirdFee : Types::MoneyAmount;
            attribute regularFee : Types::MoneyAmount;
            attribute studentFee : Types::MoneyAmount;
            attribute earlyBirdDeadlinePassed : Boolean = false;
            attribute capacityReached : Boolean = false;
            attribute registrationRequested : Boolean = false;
            attribute registrationDeadlinePassed : Boolean = false;
            attribute spotAvailable : Boolean = false;

            exhibit Behaviors::RegistrationLifecycle;

            action def processPayment {
                in registration : Items::Registration;
                out paymentStatus : Types::PaymentStatus;
                doc /* Processes the registration payment. */;
            }

            action def checkCapacity {
                in currentCount : Integer;
                in maxCapacity : Types::CapacityValue;
                out hasSpace : Boolean;
                doc /* Checks whether venue capacity has been reached. */;
            }

            action def addToWaitlist {
                in registration : Items::Registration;
                out waitlistedRegistration : Items::Registration;
                doc /* Adds a registrant to the waitlist when the conference is full. */;
            }

            action def sendConfirmation {
                in registration : Items::Registration;
                out confirmation : Items::Confirmation;
                doc /* Sends a registration confirmation to the participant. */;
            }

            action def promoteFromWaitlist {
                in waitlisted : Items::Registration;
                out promoted : Items::Registration;
                doc /* Promotes a waitlisted registrant when a spot opens. */;
            }
        }

        part def SessionScheduler {
            doc /* Organizes accepted papers into a coherent multi-track conference program. */;

            in port acceptedPaperIn : Items::Paper;
            out port programOut : Items::ConferenceProgram;
            out port programToRegistration : Items::ConferenceProgram;

            attribute numTracks : Types::TrackCount;
            attribute numDays : Types::DayCount;
            attribute rooms : String[0..*];
            attribute timeSlotDuration : Types::DurationMinutes = 30;
            attribute program : Items::ConferenceProgram;
            attribute allPapersCollected : Boolean = false;
            attribute topicsGrouped : Boolean = false;
            attribute scheduleFinalized : Boolean = false;

            exhibit Behaviors::SchedulingLifecycle;

            action def groupByTopic {
                in papers : Items::Paper[0..*];
                out topicGroups : Items::Paper[0..*][0..*];
                doc /* Groups accepted papers by their research topic. */;
            }

            action def assignSlots {
                in groupedPapers : Items::Paper[0..*];
                in rooms : String[0..*];
                in numTracks : Types::TrackCount;
                in numDays : Types::DayCount;
                out sessions : Items::Session[0..*];
                doc /* Assigns papers to time slots, rooms, and tracks. */;
            }

            action def scheduleKeynotes {
                in keynoteSpeakers : String[0..*];
                out keynoteSessions : Items::Session[0..*];
                doc /* Schedules keynote sessions. */;
            }

            action def scheduleWorkshops {
                in workshopTopics : String[0..*];
                out workshopSessions : Items::Session[0..*];
                doc /* Schedules workshop and panel sessions. */;
            }

            action def buildProgram {
                in sessions : Items::Session[0..*];
                in numTracks : Types::TrackCount;
                in numDays : Types::DayCount;
                out program : Items::ConferenceProgram;
                doc /* Assembles the final conference program. */;
            }
        }

        part def PublicationSystem {
            doc /* Compiles accepted papers into proceedings and assigns DOIs. */;

            in port finalizedPaperIn : Items::Paper;
            out port proceedingsOut : Items::Proceedings;

            attribute proceedings : Items::Proceedings;
            attribute doiPrefix : String;
            attribute digitalLibraryURL : String;
            attribute volumeTitle : String;
            attribute allPapersCollected : Boolean = false;
            attribute compilationComplete : Boolean = false;
            attribute doIsAssigned : Boolean = false;

            exhibit Behaviors::PublicationLifecycle;

            action def compileProceedings {
                in papers : Items::Paper[0..*];
                in volumeTitle : String;
                out proceedings : Items::Proceedings;
                doc /* Compiles all finalized papers into a single proceedings volume. */;
            }

            action def assignDOI {
                in paper : Items::Paper;
                in doiPrefix : String;
                out doi : Types::DOIString;
                doc /* Assigns a permanent DOI to a paper. */;
            }

            action def uploadToDigitalLibrary {
                in proceedings : Items::Proceedings;
                in url : String;
                out uploaded : Boolean;
                doc /* Uploads the completed proceedings to a digital library. */;
            }

            action def generateISBN {
                out isbn : String;
                doc /* Generates an ISBN for the proceedings volume. */;
            }
        }
    }

    package Requirements {

        requirement def EnforceSubmissionDeadline {
            subject submissionSystem : Subsystems::PaperSubmissionSystem;
            constraint { submissionSystem.deadlineReached == true implies submissionSystem.paperIn.flowItems.isEmpty }
            doc /* The system must enforce a strict submission deadline and reject late submissions. */;
        }

        requirement def ValidateFormatting {
            subject submissionSystem : Subsystems::PaperSubmissionSystem;
            constraint { submissionSystem.formattingRules.size > 0 }
            doc /* The system must validate that submissions meet formatting requirements. */;
        }

        requirement def SendAcknowledgement {
            subject submissionSystem : Subsystems::PaperSubmissionSystem;
            doc /* The system must send an acknowledgement to the author upon successful submission. */;
        }

        requirement def ThreeReviewersPerPaper {
            subject reviewSystem : Subsystems::PeerReviewSystem;
            constraint { reviewSystem.reviewersPerPaper == 3 }
            doc /* Each paper must be assigned exactly three qualified reviewers. */;
        }

        requirement def TargetAcceptanceRate {
            subject reviewSystem : Subsystems::PeerReviewSystem;
            constraint { reviewSystem.targetAcceptanceRate <= 25 }
            doc /* The review system must target a maximum acceptance rate of 25 percent. */;
        }

        requirement def EnforceReviewDeadline {
            subject reviewSystem : Subsystems::PeerReviewSystem;
            doc /* The review process must complete by the review deadline. */;
        }

        requirement def AggregateReviewScores {
            subject reviewSystem : Subsystems::PeerReviewSystem;
            doc /* The system must aggregate independent review scores to produce a final decision. */;
        }

        requirement def VenueCapacityLimit {
            subject registrationSystem : Subsystems::RegistrationSystem;
            constraint { registrationSystem.registrations.size <= registrationSystem.maxCapacity }
            doc /* Registrations must not exceed the maximum venue capacity. */;
        }

        requirement def WaitlistManagement {
            subject registrationSystem : Subsystems::RegistrationSystem;
            doc /* The system must manage a waitlist when the conference reaches full capacity. */;
        }

        requirement def EarlyBirdDiscount {
            subject registrationSystem : Subsystems::RegistrationSystem;
            constraint { registrationSystem.earlyBirdFee < registrationSystem.regularFee }
            doc /* Early-bird registration must offer a discounted fee compared to regular registration. */;
        }

        requirement def ProcessPayments {
            subject registrationSystem : Subsystems::RegistrationSystem;
            doc /* The system must process registration payments and send confirmations. */;
        }

        requirement def MultiTrackSchedule {
            subject scheduler : Subsystems::SessionScheduler;
            constraint { scheduler.numTracks >= 1 }
            doc /* The scheduler must organize papers into parallel tracks over multiple days. */;
        }

        requirement def ScheduleAllEventTypes {
            subject scheduler : Subsystems::SessionScheduler;
            doc /* The scheduler must schedule paper sessions, keynotes, panels, and workshops. */;
        }

        requirement def NonEmptyProgram {
            subject scheduler : Subsystems::SessionScheduler;
            constraint { scheduler.program.sessions.size > 0 }
            doc /* The final conference program must contain at least one session. */;
        }

        requirement def AssignDOIToEachPaper {
            subject publicationSystem : Subsystems::PublicationSystem;
            doc /* Each paper in the proceedings must be assigned a permanent DOI. */;
        }

        requirement def UploadToDigitalLibrary {
            subject publicationSystem : Subsystems::PublicationSystem;
            doc /* The completed proceedings must be uploaded to a digital library. */;
        }

        requirement def AcceptedPaperWorkflow {
            subject system : ICCADConferenceManagementSystem;
            doc /* Accepted papers must flow simultaneously to the session scheduler and the publication system. */;
        }

        requirement def ProgramToRegistration {
            subject system : ICCADConferenceManagementSystem;
            doc /* The final conference program must be provided to the registration system for attendee access. */;
        }
    }

    part def ICCADConferenceManagementSystem {
        doc /* Top-level conference management system for ICCAD, integrating submission, review, registration, scheduling, and publication. */;

        attribute conferenceName : String = "ICCAD";
        attribute conferenceYear : Integer = 2024;
        attribute conferenceStartDate : Types::DateValue;
        attribute conferenceEndDate : Types::DateValue;
        attribute venue : String;
        attribute venueCapacity : Types::CapacityValue = 500;

        part paperSubmissionSystem : Subsystems::PaperSubmissionSystem {
            attribute submissionDeadline : Types::DateValue;
            attribute maxPaperLength : Integer = 8;
            attribute formattingRules : String[3] = {"double-column", "10pt-font", "letter-size"};
        }

        part peerReviewSystem : Subsystems::PeerReviewSystem {
            attribute reviewDeadline : Types::DateValue;
            attribute targetAcceptanceRate : Types::Percentage = 25;
            attribute reviewersPerPaper : Integer = 3;
        }

        part registrationSystem : Subsystems::RegistrationSystem {
            attribute maxCapacity : Types::CapacityValue = 500;
            attribute earlyBirdDeadline : Types::DateValue;
            attribute regularDeadline : Types::DateValue;
            attribute earlyBirdFee : Types::MoneyAmount = 400;
            attribute regularFee : Types::MoneyAmount = 550;
            attribute studentFee : Types::MoneyAmount = 200;
        }

        part sessionScheduler : Subsystems::SessionScheduler {
            attribute numTracks : Types::TrackCount = 6;
            attribute numDays : Types::DayCount = 3;
            attribute timeSlotDuration : Types::DurationMinutes = 30;
            attribute rooms : String[6] = {"GrandBallroom", "Room101", "Room102", "Room201", "Room202", "Room301"};
        }

        part publicationSystem : Subsystems::PublicationSystem {
            attribute doiPrefix : String = "10.1109/ICCAD";
            attribute digitalLibraryURL : String = "https://doi.org/10.1109/ICCAD.2024";
            attribute volumeTitle : String = "Proceedings of the 2024 International Conference on Computer-Aided Design";
        }

        flow of Items::Paper
            from paperSubmissionSystem.paperToReview
            to peerReviewSystem.paperIn;

        flow of Items::Paper
            from peerReviewSystem.acceptedPaperOut
            to sessionScheduler.acceptedPaperIn;

        flow of Items::Paper
            from peerReviewSystem.acceptedPaperOut
            to publicationSystem.finalizedPaperIn;

        flow of Items::ConferenceProgram
            from sessionScheduler.programToRegistration
            to registrationSystem.programIn;

        flow of Items::Acknowledgement
            from paperSubmissionSystem.acknowledgementOut
            to /* author external interface */;

        flow of Items::DecisionNotification
            from peerReviewSystem.notificationOut
            to /* author external interface */;

        flow of Items::Confirmation
            from registrationSystem.confirmationOut
            to /* participant external interface */;

        flow of Items::ConferenceProgram
            from sessionScheduler.programOut
            to /* attendee external interface */;

        flow of Items::Proceedings
            from publicationSystem.proceedingsOut
            to /* digital library external interface */;

        requirement reqEnforceSubmissionDeadline : Requirements::EnforceSubmissionDeadline;
        requirement reqValidateFormatting : Requirements::ValidateFormatting;
        requirement reqSendAcknowledgement : Requirements::SendAcknowledgement;
        requirement reqThreeReviewers : Requirements::ThreeReviewersPerPaper;
        requirement reqTargetAcceptanceRate : Requirements::TargetAcceptanceRate;
        requirement reqEnforceReviewDeadline : Requirements::EnforceReviewDeadline;
        requirement reqAggregateScores : Requirements::AggregateReviewScores;
        requirement reqVenueCapacity : Requirements::VenueCapacityLimit;
        requirement reqWaitlist : Requirements::WaitlistManagement;
        requirement reqEarlyBird : Requirements::EarlyBirdDiscount;
        requirement reqProcessPayments : Requirements::ProcessPayments;
        requirement reqMultiTrack : Requirements::MultiTrackSchedule;
        requirement reqScheduleEventTypes : Requirements::ScheduleAllEventTypes;
        requirement reqNonEmptyProgram : Requirements::NonEmptyProgram;
        requirement reqAssignDOI : Requirements::AssignDOIToEachPaper;
        requirement reqUploadLibrary : Requirements::UploadToDigitalLibrary;
        requirement reqAcceptedPaperWorkflow : Requirements::AcceptedPaperWorkflow;
        requirement reqProgramToRegistration : Requirements::ProgramToRegistration;

        satisfy reqEnforceSubmissionDeadline by paperSubmissionSystem;
        satisfy reqValidateFormatting by paperSubmissionSystem;
        satisfy reqSendAcknowledgement by paperSubmissionSystem;
        satisfy reqThreeReviewers by peerReviewSystem;
        satisfy reqTargetAcceptanceRate by peerReviewSystem;
        satisfy reqEnforceReviewDeadline by peerReviewSystem;
        satisfy reqAggregateScores by peerReviewSystem;
        satisfy reqVenueCapacity by registrationSystem;
        satisfy reqWaitlist by registrationSystem;
        satisfy reqEarlyBird by registrationSystem;
        satisfy reqProcessPayments by registrationSystem;
        satisfy reqMultiTrack by sessionScheduler;
        satisfy reqScheduleEventTypes by sessionScheduler;
        satisfy reqNonEmptyProgram by sessionScheduler;
        satisfy reqAssignDOI by publicationSystem;
        satisfy reqUploadLibrary by publicationSystem;
    }
}
