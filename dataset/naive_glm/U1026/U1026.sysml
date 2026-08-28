package ConferenceManagementSystem {

    import ScalarValues::*;

    value type ScoreValue :> Real {
        doc /* Score on a 1..10 scale. */
    }
    value type Percentage :> Real {
        doc /* Percentage value 0..100. */
    }
    value type DateTime :> String {
        doc /* ISO-8601 date-time string. */
    }
    value type PaperId :> String;
    value type AttendeeId :> String;
    value type ReviewerId :> String;
    value type SessionId :> String;
    value type RoomId :> String;
    value type TrackName :> String;

    enum def ReviewRecommendation {
        accept;
        reject;
        majorRevision;
        minorRevision;
    }

    enum def PaperStatus {
        submitted;
        underReview;
        accepted;
        rejected;
        revisionRequested;
        scheduled;
    }

    enum def RegistrationTier {
        student;
        academic;
        industry;
        speaker;
        organizer;
    }

    enum def RoomType {
        auditorium;
        breakout;
        exhibition;
        poster;
    }

    enum def SessionType {
        keynote;
        technical;
        poster;
        panel;
        networking;
    }

    item def Paper {
        attribute id : PaperId;
        attribute title : String;
        attribute abstractText : String;
        attribute authors : String[0..*];
        attribute keywords : String[0..*];
        attribute submissionDate : DateTime;
        attribute pageCount : Positive;
        attribute formatValid : Boolean;
        attribute status : PaperStatus;
    }

    item def Review {
        attribute reviewerId : ReviewerId;
        attribute paperId : PaperId;
        attribute technicalMerit : ScoreValue;
        attribute clarity : ScoreValue;
        attribute relevance : ScoreValue;
        attribute finalScore : ScoreValue;
        attribute comments : String;
        attribute recommendation : ReviewRecommendation;
    }

    item def Reviewer {
        attribute id : ReviewerId;
        attribute name : String;
        attribute affiliation : String;
        attribute expertiseAreas : String[0..*];
        attribute assignedPaperCount : Natural;
        attribute maxAssignments : Positive = 6;
    }

    item def Attendee {
        attribute id : AttendeeId;
        attribute name : String;
        attribute email : String;
        attribute affiliation : String;
        attribute tier : RegistrationTier;
        attribute interests : String[0..*];
        attribute registered : Boolean;
        attribute waitlisted : Boolean;
    }

    item def Session {
        attribute id : SessionId;
        attribute title : String;
        attribute type : SessionType;
        attribute track : TrackName;
        attribute papers : PaperId[0..*];
        attribute startTime : DateTime;
        attribute endTime : DateTime;
        attribute roomId : RoomId;
        attribute capacity : Positive;
    }

    item def Room {
        attribute id : RoomId;
        attribute name : String;
        attribute type : RoomType;
        attribute capacity : Positive;
        attribute hasAV : Boolean;
        attribute hasStreaming : Boolean;
    }

    item def NetworkingEvent {
        attribute id : String;
        attribute title : String;
        attribute startTime : DateTime;
        attribute endTime : DateTime;
        attribute roomId : RoomId;
        attribute capacity : Positive;
        attribute participants : AttendeeId[0..*];
    }

    item def ConnectionSuggestion {
        attribute attendeeA : AttendeeId;
        attribute attendeeB : AttendeeId;
        attribute sharedInterests : String[0..*];
        attribute matchScore : Percentage;
    }

    item def SubmissionConfirmation {
        attribute paperId : PaperId;
        attribute status : PaperStatus;
        attribute timestamp : DateTime;
    }

    item def ReviewAssignment {
        attribute reviewerId : ReviewerId;
        attribute paperId : PaperId;
        attribute dueDate : DateTime;
    }

    item def PaperDecision {
        attribute paperId : PaperId;
        attribute status : PaperStatus;
        attribute finalScore : ScoreValue;
        attribute rationale : String;
    }

    item def RegistrationRequest {
        attribute attendee : Attendee;
        attribute tier : RegistrationTier;
    }

    item def RegistrationConfirmation {
        attribute attendeeId : AttendeeId;
        attribute confirmed : Boolean;
        attribute waitlisted : Boolean;
        attribute confirmationCode : String;
    }

    item def VenueAllocation {
        attribute sessionId : SessionId;
        attribute roomId : RoomId;
        attribute allocated : Boolean;
        attribute notes : String;
    }

    port def PaperSubmissionPort {
        in item papers : Paper[0..*];
        out item confirmations : SubmissionConfirmation[0..*];
    }

    port def PaperHandoffPort {
        out item validatedPapers : Paper[0..*];
    }

    port def ReviewAssignmentPort {
        out item assignments : ReviewAssignment[0..*];
        in item completedReviews : Review[0..*];
    }

    port def DecisionPort {
        out item decisions : PaperDecision[0..*];
    }

    port def AcceptedPaperPort {
        in item acceptedPapers : Paper[0..*];
    }

    port def SchedulePort {
        out item sessions : Session[0..*];
    }

    port def VenueAllocationPort {
        in item sessionRequests : Session[0..*];
        out item allocations : VenueAllocation[0..*];
    }

    port def RegistrationPort {
        in item requests : RegistrationRequest[0..*];
        out item confirmations : RegistrationConfirmation[0..*];
    }

    port def AttendeeProfilePort {
        out item profiles : Attendee[0..*];
    }

    port def NetworkingPort {
        in item profiles : Attendee[0..*];
        out item suggestions : ConnectionSuggestion[0..*];
        out item events : NetworkingEvent[0..*];
    }

    part def SubmissionManagementSystem {
        attribute submissionDeadline : DateTime;
        attribute totalSubmissions : Natural = 0;
        attribute totalAccepted : Natural = 0;
        attribute acceptanceRate : Percentage = 0;
        attribute paperDatabase : Paper[0..*];

        port paperSubmission : PaperSubmissionPort;
        port paperHandoff : PaperHandoffPort;

        state submissionLifecycle {
            entry; then OpenForSubmission;
            state OpenForSubmission {
                doc /* System accepts new paper submissions. */
            }
            transition from OpenForSubmission to Closed
                when totalSubmissions > 0;
            state Closed {
                doc /* Submission deadline reached; no new papers accepted. */
            }
            transition from Closed to Finalized
                when totalAccepted > 0;
            state Finalized {
                doc /* Acceptance rate computed and results published. */
            }
        }

        action validatePaper {
            in paper : Paper;
            out valid : Boolean;
        }

        action calculateAcceptanceRate {
            in submissions : Natural;
            in accepted : Natural;
            out rate : Percentage;
        }

        action recordSubmission {
            in paper : Paper;
            out confirmation : SubmissionConfirmation;
        }
    }

    part def PeerReviewSystem {
        attribute reviewerPool : Reviewer[0..*];
        attribute reviewsPerPaper : Positive = 3;
        attribute reviewDeadline : DateTime;
        attribute acceptanceThreshold : ScoreValue = 7.0;
        attribute rejectionThreshold : ScoreValue = 4.0;
        attribute collectedReviews : Review[0..*];
        attribute decisions : PaperDecision[0..*];

        port reviewAssignment : ReviewAssignmentPort;
        port decision : DecisionPort;

        state reviewProcess {
            entry; then AssigningReviewers;
            state AssigningReviewers {
                doc /* Assign reviewers to each submitted paper based on expertise. */
            }
            transition from AssigningReviewers to CollectingReviews
                when reviewAssignment.assignments->size() > 0;
            state CollectingReviews {
                doc /* Await reviewer scores until deadline. */
            }
            transition from CollectingReviews to ComputingDecisions
                when collectedReviews->size() >= reviewAssignment.assignments->size();
            state ComputingDecisions {
                doc /* Compute final scores and determine accept/reject. */
            }
            transition from ComputingDecisions to Complete
                when decisions->size() > 0;
            state Complete;
        }

        action assignReviewers {
            in paper : Paper;
            in reviewers : Reviewer[0..*];
            in count : Positive;
            out assignments : ReviewAssignment[0..*];
        }

        action computeFinalScore {
            in reviews : Review[0..*];
            out finalScore : ScoreValue;
        }

        action determineDecision {
            in finalScore : ScoreValue;
            in acceptanceThreshold : ScoreValue;
            in rejectionThreshold : ScoreValue;
            out status : PaperStatus;
        }
    }

    part def ProgramSchedulingSystem {
        attribute sessions : Session[0..*];
        attribute tracks : TrackName[0..*];
        attribute conferenceDays : Positive = 3;
        attribute parallelTracks : Positive = 6;

        port acceptedPaperInput : AcceptedPaperPort;
        port schedule : SchedulePort;
        port venueAllocation : VenueAllocationPort;

        state schedulingProcess {
            entry; then GroupingPapers;
            state GroupingPapers {
                doc /* Group accepted papers into related technical tracks. */
            }
            transition from GroupingPapers to BuildingSessions
                when tracks->size() > 0;
            state BuildingSessions {
                doc /* Organize papers into sessions per track. */
            }
            transition from BuildingSessions to AllocatingTimeSlots
                when sessions->size() > 0;
            state AllocatingTimeSlots {
                doc /* Assign sessions to time slots across conference days. */
            }
            transition from AllocatingTimeSlots to RequestingVenue
                when sessions->forAll(s | s.startTime <> null and s.endTime <> null);
            state RequestingVenue {
                doc /* Request room allocation from venue management. */
            }
            transition from RequestingVenue to Complete
                when venueAllocation.allocations->size() = sessions->size();
            state Complete;
        }

        action groupPapersByTrack {
            in papers : Paper[0..*];
            out tracks : TrackName[0..*];
        }

        action buildSession {
            in papers : Paper[0..*];
            in track : TrackName;
            in sessionType : SessionType;
            out session : Session;
        }

        action allocateTimeSlot {
            in session : Session;
            in day : Positive;
            in slotIndex : Positive;
            out scheduled : Session;
        }
    }

    part def AttendeeRegistrationSystem {
        attribute maxCapacity : Positive = 2000;
        attribute registeredCount : Natural = 0;
        attribute waitlistCount : Natural = 0;
        attribute registrations : Attendee[0..*];

        port registration : RegistrationPort;
        port attendeeProfile : AttendeeProfilePort;

        state registrationLifecycle {
            entry; then AcceptingRegistrations;
            state AcceptingRegistrations {
                doc /* Process registrations while capacity remains. */
            }
            transition from AcceptingRegistrations to Full
                when registeredCount >= maxCapacity;
            state Full {
                doc /* Venue at capacity; new registrants are waitlisted. */
            }
            transition from Full to AcceptingRegistrations
                when registeredCount < maxCapacity;
        }

        action processRegistration {
            in request : RegistrationRequest;
            in currentCount : Natural;
            in maxCapacity : Positive;
            out confirmation : RegistrationConfirmation;
        }

        action addToWaitlist {
            in attendee : Attendee;
            out waitlisted : Boolean;
        }

        action promoteFromWaitlist {
            in attendee : Attendee;
            out confirmed : Boolean;
        }
    }

    part def VenueManagementSystem {
        attribute rooms : Room[0..*];

        port venueAllocation : VenueAllocationPort;

        part mainAuditorium : Room {
            :>> id = "R-MAIN";
            :>> name = "Main Auditorium";
            :>> type = auditorium;
            :>> capacity = 1500;
            :>> hasAV = true;
            :>> hasStreaming = true;
        }
        part breakoutRoom1 : Room {
            :>> id = "R-B1";
            :>> name = "Breakout Room 1";
            :>> type = breakout;
            :>> capacity = 250;
            :>> hasAV = true;
            :>> hasStreaming = false;
        }
        part breakoutRoom2 : Room {
            :>> id = "R-B2";
            :>> name = "Breakout Room 2";
            :>> type = breakout;
            :>> capacity = 200;
            :>> hasAV = true;
            :>> hasStreaming = false;
        }
        part breakoutRoom3 : Room {
            :>> id = "R-B3";
            :>> name = "Breakout Room 3";
            :>> type = breakout;
            :>> capacity = 150;
            :>> hasAV = true;
            :>> hasStreaming = false;
        }
        part breakoutRoom4 : Room {
            :>> id = "R-B4";
            :>> name = "Breakout Room 4";
            :>> type = breakout;
            :>> capacity = 120;
            :>> hasAV = true;
            :>> hasStreaming = false;
        }
        part breakoutRoom5 : Room {
            :>> id = "R-B5";
            :>> name = "Breakout Room 5";
            :>> type = breakout;
            :>> capacity = 100;
            :>> hasAV = true;
            :>> hasStreaming = false;
        }
        part breakoutRoom6 : Room {
            :>> id = "R-B6";
            :>> name = "Breakout Room 6";
            :>> type = breakout;
            :>> capacity = 80;
            :>> hasAV = true;
            :>> hasStreaming = false;
        }
        part exhibitionHall : Room {
            :>> id = "R-EXH";
            :>> name = "Exhibition Hall";
            :>> type = exhibition;
            :>> capacity = 1000;
            :>> hasAV = false;
            :>> hasStreaming = false;
        }
        part posterArea : Room {
            :>> id = "R-POST";
            :>> name = "Poster Presentation Area";
            :>> type = poster;
            :>> capacity = 400;
            :>> hasAV = false;
            :>> hasStreaming = false;
        }

        state venueAllocationProcess {
            entry; then ReceivingRequests;
            state ReceivingRequests {
                doc /* Receive session-to-room allocation requests from scheduler. */
            }
            transition from ReceivingRequests to CheckingAvailability
                when venueAllocation.sessionRequests->size() > 0;
            state CheckingAvailability {
                doc /* Check each room for capacity and equipment suitability. */
            }
            transition from CheckingAvailability to Allocating
                when rooms->size() > 0;
            state Allocating {
                doc /* Assign sessions to suitable rooms. */
            }
            transition from Allocating to Complete
                when venueAllocation.allocations->size() = venueAllocation.sessionRequests->size();
            state Complete;
        }

        action findSuitableRoom {
            in session : Session;
            in rooms : Room[0..*];
            out roomId : RoomId;
        }

        action verifyCapacity {
            in session : Session;
            in room : Room;
            out suitable : Boolean;
        }

        action verifyEquipment {
            in session : Session;
            in room : Room;
            out suitable : Boolean;
        }
    }

    part def NetworkingPlatform {
        attribute suggestions : ConnectionSuggestion[0..*];
        attribute events : NetworkingEvent[0..*];
        attribute matchThreshold : Percentage = 50;

        port networking : NetworkingPort;

        state networkingOperation {
            entry; then CollectingProfiles;
            state CollectingProfiles {
                doc /* Gather attendee profiles from registration system. */
            }
            transition from CollectingProfiles to GeneratingSuggestions
                when networking.profiles->size() > 1;
            state GeneratingSuggestions {
                doc /* Compute match scores and produce connection suggestions. */
            }
            transition from GeneratingSuggestions to SchedulingEvents
                when suggestions->size() > 0;
            state SchedulingEvents {
                doc /* Schedule networking events throughout the conference. */
            }
            transition from SchedulingEvents to Active
                when events->size() > 0;
            state Active {
                doc /* Platform live during conference; continuously updates suggestions. */
            }
        }

        action generateSuggestions {
            in attendees : Attendee[0..*];
            in threshold : Percentage;
            out suggestions : ConnectionSuggestion[0..*];
        }

        action computeMatchScore {
            in a : Attendee;
            in b : Attendee;
            out score : Percentage;
        }

        action scheduleNetworkingEvent {
            in participants : AttendeeId[0..*];
            in rooms : Room[0..*];
            in startTime : DateTime;
            in endTime : DateTime;
            out event : NetworkingEvent;
        }
    }

    part def ConferenceManagementSystem {
        part submissionSystem : SubmissionManagementSystem {
            :>> submissionDeadline = "2025-03-01T23:59:59";
        }
        part reviewSystem : PeerReviewSystem {
            :>> reviewDeadline = "2025-04-15T23:59:59";
            :>> reviewsPerPaper = 3;
            :>> acceptanceThreshold = 7.0;
            :>> rejectionThreshold = 4.0;
        }
        part schedulingSystem : ProgramSchedulingSystem {
            :>> conferenceDays = 3;
            :>> parallelTracks = 6;
        }
        part registrationSystem : AttendeeRegistrationSystem {
            :>> maxCapacity = 2000;
        }
        part venueSystem : VenueManagementSystem;
        part networkingPlatform : NetworkingPlatform {
            :>> matchThreshold = 50;
        }

        connection c1 connect submissionSystem.paperHandoff to reviewSystem.reviewAssignment;
        connection c2 connect reviewSystem.decision to schedulingSystem.acceptedPaperInput;
        connection c3 connect schedulingSystem.venueAllocation to venueSystem.venueAllocation;
        connection c4 connect registrationSystem.attendeeProfile to networkingPlatform.networking;
    }

    part theConference : ConferenceManagementSystem;

    requirement def SubmissionManagementRequirement {
        doc /* The submission management system shall accept, validate, and track papers. */
        attribute submissionDeadline : DateTime;
        attribute totalSubmissions : Natural;
        attribute totalAccepted : Natural;
        attribute acceptanceRate : Percentage;
        constraint { totalSubmissions >= 0 }
        constraint { totalAccepted <= totalSubmissions }
        constraint { acceptanceRate = (totalAccepted * 100) / totalSubmissions }
    }

    requirement def PeerReviewRequirement {
        doc /* The peer review system shall assign three reviewers per paper and compute decisions. */
        attribute reviewsPerPaper : Positive;
        attribute reviewerPoolSize : Natural;
        attribute acceptanceThreshold : ScoreValue;
        attribute rejectionThreshold : ScoreValue;
        constraint { reviewsPerPaper = 3 }
        constraint { reviewerPoolSize >= 100 }
        constraint { acceptanceThreshold > rejectionThreshold }
    }

    requirement def ProgramSchedulingRequirement {
        doc /* The scheduler shall produce a multi-day program with parallel tracks. */
        attribute conferenceDays : Positive;
        attribute parallelTracks : Positive;
        attribute trackCount : Natural;
        constraint { conferenceDays >= 2 }
        constraint { parallelTracks >= 2 }
        constraint { trackCount >= 1 }
    }

    requirement def RegistrationRequirement {
        doc /* The registration system shall enforce capacity and support waitlisting. */
        attribute maxCapacity : Positive;
        attribute registeredCount : Natural;
        attribute waitlistCount : Natural;
        constraint { registeredCount <= maxCapacity }
        constraint { waitlistCount >= 0 }
    }

    requirement def VenueManagementRequirement {
        doc /* The venue shall include an auditorium, breakout rooms, exhibition hall, and poster area. */
        attribute auditoriumExists : Boolean;
        attribute breakoutRoomCount : Natural;
        attribute exhibitionHallExists : Boolean;
        attribute posterAreaExists : Boolean;
        constraint { auditoriumExists = true }
        constraint { breakoutRoomCount >= 2 }
        constraint { exhibitionHallExists = true }
        constraint { posterAreaExists = true }
    }

    requirement def NetworkingRequirement {
        doc /* The networking platform shall suggest connections and schedule networking events. */
        attribute matchThreshold : Percentage;
        attribute suggestionCount : Natural;
        attribute eventCount : Natural;
        constraint { matchThreshold > 0 }
        constraint { suggestionCount >= 0 }
        constraint { eventCount >= 0 }
    }

    requirement submissionReq : SubmissionManagementRequirement {
        :>> submissionDeadline = "2025-03-01T23:59:59";
        :>> totalSubmissions = theConference.submissionSystem.totalSubmissions;
        :>> totalAccepted = theConference.submissionSystem.totalAccepted;
        :>> acceptanceRate = theConference.submissionSystem.acceptanceRate;
    }

    requirement peerReviewReq : PeerReviewRequirement {
        :>> reviewsPerPaper = theConference.reviewSystem.reviewsPerPaper;
        :>> reviewerPoolSize = theConference.reviewSystem.reviewerPool->size();
        :>> acceptanceThreshold = theConference.reviewSystem.acceptanceThreshold;
        :>> rejectionThreshold = theConference.reviewSystem.rejectionThreshold;
    }

    requirement schedulingReq : ProgramSchedulingRequirement {
        :>> conferenceDays = theConference.schedulingSystem.conferenceDays;
        :>> parallelTracks = theConference.schedulingSystem.parallelTracks;
        :>> trackCount = theConference.schedulingSystem.tracks->size();
    }

    requirement registrationReq : RegistrationRequirement {
        :>> maxCapacity = theConference.registrationSystem.maxCapacity;
        :>> registeredCount = theConference.registrationSystem.registeredCount;
        :>> waitlistCount = theConference.registrationSystem.waitlistCount;
    }

    requirement venueReq : VenueManagementRequirement {
        :>> auditoriumExists = true;
        :>> breakoutRoomCount = 6;
        :>> exhibitionHallExists = true;
        :>> posterAreaExists = true;
    }

    requirement networkingReq : NetworkingRequirement {
        :>> matchThreshold = theConference.networkingPlatform.matchThreshold;
        :>> suggestionCount = theConference.networkingPlatform.suggestions->size();
        :>> eventCount = theConference.networkingPlatform.events->size();
    }

    satisfy submissionReq by theConference.submissionSystem;
    satisfy peerReviewReq by theConference.reviewSystem;
    satisfy schedulingReq by theConference.schedulingSystem;
    satisfy registrationReq by theConference.registrationSystem;
    satisfy venueReq by theConference.venueSystem;
    satisfy networkingReq by theConference.networkingPlatform;
}
