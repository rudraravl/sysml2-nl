package DesignAutomationConference {
    private import ScalarValues::*;
    private import SI::*;
    private import Time::*;

    value def Score :> Real;
    value def Percentage :> Real;
    value def Capacity :> Integer;

    enum def PaperStatus {
        submitted;
        underReview;
        accepted;
        rejected;
        pendingRevision;
    }
    enum def Recommendation {
        approve;
        reject;
        revise;
    }
    enum def AttendeeTier {
        student;
        academic;
        industry;
        speaker;
    }
    enum def RegistrationStatus {
        pending;
        confirmed;
        waitlisted;
        cancelled;
    }

    item def Paper {
        attribute id : String;
        attribute title : String;
        attribute authors : String[1..*];
        attribute abstractText : String;
        attribute submissionDate : DateTime;
        attribute status : PaperStatus;
        attribute averageScore : Score[0..1];
        ref item reviews : Review[0..*];
    }

    item def Review {
        attribute reviewerId : String;
        attribute paperId : String;
        attribute score : Score;
        attribute comments : String;
        attribute recommendation : Recommendation;
    }

    item def Reviewer {
        attribute id : String;
        attribute name : String;
        attribute expertise : String[1..*];
        ref item assignedPapers : Paper[0..*];
    }

    item def Attendee {
        attribute id : String;
        attribute name : String;
        attribute tier : AttendeeTier;
        attribute interests : String[0..*];
        attribute registrationStatus : RegistrationStatus;
    }

    item def TimeSlot {
        attribute day : Integer;
        attribute startTime : DateTime;
        attribute endTime : DateTime;
    }

    part def Room {
        attribute name : String;
        attribute capacity : Capacity;
        attribute equipment : String[0..*];
    }

    item def Track {
        attribute name : String;
        ref item sessions : Session[0..*];
    }

    item def Session {
        attribute id : String;
        attribute title : String;
        attribute trackName : String;
        ref item papers : Paper[1..*];
        attribute chair : String;
        attribute timeSlot : TimeSlot;
        ref part room : Room;
        attribute expectedAttendance : Capacity;
    }

    item def Schedule {
        ref item sessions : Session[0..*];
    }

    item def ReviewerAssignment {
        attribute reviewerId : String;
        ref item papers : Paper[1..*];
    }

    item def Decision {
        ref item paper : Paper;
        attribute finalVerdict : Recommendation;
    }

    item def AttendeeConnection {
        attribute attendeeAId : String;
        attribute attendeeBId : String;
        attribute mutualInterests : String[0..*];
    }

    requirement def ConferenceRequirement {
        text "A requirement for the Design Automation Conference management system.";
    }

    requirement def SubmissionDeadlineRequirement :> ConferenceRequirement {
        text "Submissions must be validated against a strict deadline.";
    }

    requirement def ThreeReviewersRequirement :> ConferenceRequirement {
        text "Each paper must be assigned to exactly three reviewers.";
    }

    requirement def AcceptanceRateRequirement :> ConferenceRequirement {
        text "System shall calculate acceptance rate as (accepted / submitted) * 100.";
    }

    requirement def CapacityRequirement :> ConferenceRequirement {
        text "Registrations exceeding venue capacity must be placed on a waitlist.";
    }

    requirement def RoomCapacityRequirement :> ConferenceRequirement {
        text "Assigned rooms must have capacity >= expected session attendance.";
    }

    requirement def NetworkingRequirement :> ConferenceRequirement {
        text "Networking suggestions must be based on shared interests.";
    }

    action def ValidatePaperFormat {
        in paper : Paper;
        out isValid : Boolean;
    }

    action def CalculateAcceptanceRate {
        in submitted : Paper[0..*];
        in accepted : Paper[0..*];
        out rate : Percentage;
    }

    action def AssignReviewers {
        in paper : Paper;
        in reviewerPool : Reviewer[0..*];
        out assignments : ReviewerAssignment[0..*];
    }

    action def CalculateFinalScore {
        in reviews : Review[0..*];
        out score : Score;
    }

    action def MakeDecision {
        in score : Score;
        in reviews : Review[0..*];
        out decision : Decision;
    }

    action def GroupPapersIntoTracks {
        in papers : Paper[0..*];
        out tracks : Track[0..*];
    }

    action def CreateSessions {
        in tracks : Track[0..*];
        out sessions : Session[0..*];
    }

    action def AllocateTimeAndRooms {
        in sessions : Session[0..*];
        in rooms : Room[0..*];
        in timeSlots : TimeSlot[0..*];
        out scheduledSessions : Session[0..*];
    }

    action def ProcessRegistration {
        in attendee : Attendee;
        in currentCount : Integer;
        in maxCapacity : Integer;
        out status : RegistrationStatus;
    }

    action def AssignRoomToSession {
        in session : Session;
        in rooms : Room[0..*];
        out room : Room;
    }

    action def SuggestConnections {
        in attendees : Attendee[0..*];
        out connections : AttendeeConnection[0..*];
    }

    action def ScheduleNetworkingEvents {
        in connections : AttendeeConnection[0..*];
        out events : String[0..*];
    }

    state def SubmissionLifecycle {
        state open;
        state closed;
        transition open to closed accept deadlineReached;
    }

    state def ReviewProcess {
        state awaitingAssignment;
        state underReview;
        state decisionMade;
        transition awaitingAssignment to underReview accept assignmentComplete;
        transition underReview to decisionMade accept allReviewsCollected;
        transition decisionMade to awaitingAssignment accept newPapers;
    }

    state def RegistrationLifecycle {
        state open;
        state full;
        state closed;
        transition open to full accept capacityReached;
        transition full to open accept spotAvailable;
        transition open to closed accept registrationClosed;
    }

    state def ConferenceLifecycle {
        state submissionPhase;
        state reviewPhase;
        state schedulingPhase;
        state registrationPhase;
        state eventPhase;
        state postEventPhase;
        transition submissionPhase to reviewPhase accept deadlineReached;
        transition reviewPhase to schedulingPhase accept allDecisionsMade;
        transition schedulingPhase to registrationPhase accept schedulePublished;
        transition registrationPhase to eventPhase accept conferenceStart;
        transition eventPhase to postEventPhase accept conferenceEnd;
    }

    part def SubmissionManagementSystem {
        in paper : Paper;
        out paperList : Paper[0..*];
        attribute submissionDeadline : DateTime;
        attribute acceptanceRate : Percentage;
        ref item submittedPapers : Paper[0..*];
        ref item acceptedPapers : Paper[0..*];
        exhibit submissionSM : SubmissionLifecycle;
        action validate : ValidatePaperFormat;
        action calcRate : CalculateAcceptanceRate;
    }

    part def PeerReviewSystem {
        in papers : Paper[0..*];
        out decisions : Decision[0..*];
        out acceptedPapers : Paper[0..*];
        ref item reviewerPool : Reviewer[0..*];
        ref item reviews : Review[0..*];
        attribute reviewersPerPaper : Integer = 3;
        exhibit reviewSM : ReviewProcess;
        action assign : AssignReviewers;
        action calcScore : CalculateFinalScore;
        action decide : MakeDecision;
        assert constraint minReviews {
            reviews->size() >= 3
        }
    }

    part def ProgramSchedulingSystem {
        in acceptedPapers : Paper[0..*];
        out sessions : Session[0..*];
        out schedule : Schedule;
        ref item tracks : Track[0..*];
        ref item timeSlots : TimeSlot[0..*];
        action group : GroupPapersIntoTracks;
        action createSessions : CreateSessions;
        action allocate : AllocateTimeAndRooms;
    }

    part def AttendeeRegistrationSystem {
        in attendee : Attendee;
        out confirmation : RegistrationStatus;
        out attendeeList : Attendee[0..*];
        attribute maxCapacity : Capacity = 2000;
        attribute currentRegistrations : Integer = 0;
        ref item waitlist : Attendee[0..*];
        exhibit registrationSM : RegistrationLifecycle;
        action process : ProcessRegistration;
        assert constraint capacityConstraint {
            currentRegistrations <= maxCapacity
        }
    }

    part def VenueManagementSystem {
        in sessions : Session[0..*];
        out roomAssignments : Room[0..*];
        part mainAuditorium : Room {
            attribute name = "Main Auditorium";
            attribute capacity = 1000;
        }
        part breakoutRooms : Room[5] {
            attribute capacity = 200;
        }
        part exhibitionHall : Room {
            attribute name = "Exhibition Hall";
            attribute capacity = 500;
        }
        part posterArea : Room {
            attribute name = "Poster Area";
            attribute capacity = 300;
        }
        action assignRoom : AssignRoomToSession;
    }

    part def NetworkingPlatform {
        in attendees : Attendee[0..*];
        out suggestions : AttendeeConnection[0..*];
        out events : String[0..*];
        action suggest : SuggestConnections;
        action scheduleEvents : ScheduleNetworkingEvents;
    }

    part def ConferenceManagementSystem {
        part submissionSystem : SubmissionManagementSystem;
        part peerReviewSystem : PeerReviewSystem;
        part schedulingSystem : ProgramSchedulingSystem;
        part registrationSystem : AttendeeRegistrationSystem;
        part venueSystem : VenueManagementSystem;
        part networkingPlatform : NetworkingPlatform;

        flow submissionSystem.paperList to peerReviewSystem.papers;
        flow peerReviewSystem.acceptedPapers to schedulingSystem.acceptedPapers;
        flow schedulingSystem.sessions to venueSystem.sessions;
        flow registrationSystem.attendeeList to networkingPlatform.attendees;

        exhibit conferenceSM : ConferenceLifecycle;
    }

    part dac2025 : ConferenceManagementSystem;
}
