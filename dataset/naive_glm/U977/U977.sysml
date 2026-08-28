package ASPDAC {

  import ScalarValues::*;

  // ===== Value Types =====
  value type Count :> Integer;
  value type Capacity :> Count;
  value type ReviewScore :> Integer;
  value type DateValue :> String;
  value type EmailAddress :> String;

  // ===== Enumerations =====
  enum def PaperStatus {
    literal SUBMITTED;
    literal UNDER_REVIEW;
    literal ACCEPTED;
    literal REJECTED;
    literal WITHDRAWN;
    literal PRESENTED;
  }

  enum def RegistrationType {
    literal EARLY_BIRD;
    literal REGULAR;
    literal STUDENT;
    literal ON_SITE;
  }

  enum def ConferencePhase {
    literal PLANNING;
    literal CALL_FOR_PAPERS;
    literal REVIEWING;
    literal PROGRAM_CREATION;
    literal REGISTRATION_OPEN;
    literal CONFERENCE_EXECUTION;
    literal POST_CONFERENCE;
  }

  enum def TrackType {
    literal MAIN_TRACK;
    literal EMERGING_TRACK;
    literal SPECIAL_SESSION;
  }

  // ===== Item Definitions =====
  item def Author {
    attribute name : String;
    attribute affiliation : String;
    attribute email : EmailAddress;
    attribute isCorresponding : Boolean = false;
  }

  item def Reviewer {
    attribute reviewerId : String;
    attribute name : String;
    attribute affiliation : String;
    attribute expertiseArea : String;
    attribute maxAssignments : Count = 6;
    attribute currentAssignments : Count = 0;
  }

  item def Paper {
    attribute paperId : String;
    attribute title : String;
    attribute abstractText : String;
    attribute submissionDate : DateValue;
    attribute status : PaperStatus = PaperStatus::SUBMITTED;
    attribute keywords : String[0..*];
    ref author : Author[1..*];
  }

  item def Review {
    attribute reviewId : String;
    attribute paperId : String;
    attribute score : ReviewScore;
    attribute confidence : Integer;
    attribute comments : String;
    attribute reviewerId : String;
    attribute submittedDate : DateValue;
    attribute recommendation : String;
  }

  item def Room {
    attribute roomId : String;
    attribute name : String;
    attribute capacity : Capacity;
    attribute location : String;
  }

  item def Session {
    attribute sessionId : String;
    attribute title : String;
    attribute sessionChairName : String;
    attribute startTime : DateValue;
    attribute endTime : DateValue;
    attribute trackNo : Integer;
    attribute trackType : TrackType;
    attribute roomName : String;
    ref acceptedPapers : Paper[1..*];
  }

  item def Participant {
    attribute participantId : String;
    attribute name : String;
    attribute affiliation : String;
    attribute email : EmailAddress;
    attribute regType : RegistrationType;
    attribute registeredOn : DateValue;
    attribute isAuthor : Boolean = false;
  }

  item def ConferenceProgram {
    attribute programId : String;
    attribute totalSessions : Count;
    attribute totalTracks : Integer;
    ref sessions : Session[0..*];
  }

  // ===== Port Definitions =====
  port def PaperFlow {
    attribute paper : Paper;
  }

  port def AcceptedPaperFlow {
    attribute paper : Paper;
  }

  port def ReviewFlow {
    attribute review : Review;
  }

  port def ProgramFlow {
    attribute session : Session;
  }

  port def RegistrationFlow {
    attribute participant : Participant;
  }

  port def VenueInfoFlow {
    attribute room : Room;
  }

  // ===== Part Definitions =====
  part def PaperManagementSystem {
    port paperForReviewOut : PaperFlow;
    port reviewResultIn : ReviewFlow;
    port acceptedPaperOut : AcceptedPaperFlow;

    attribute submissionCount : Count = 0;
    attribute acceptedCount : Count = 0;
    attribute rejectedCount : Count = 0;
    attribute withdrawnCount : Count = 0;
    attribute minReviewsRequired : Count = 3;
    ref submittedPapers : Paper[0..*];
    ref acceptedPapers : Paper[0..*];
    ref rejectedPapers : Paper[0..*];

    action def takeSubmission {
      in paper : Paper;
      out recorded : Paper;
    }

    action def updatePaperStatus {
      in paper : Paper;
      in newStatus : PaperStatus;
      out updated : Paper;
    }

    action def compileStatistics {
      out totalSubmissions : Count;
      out totalAccepted : Count;
      out totalRejected : Count;
    }

    state submissionTracking {
      state Submitted;
      state UnderReview;
      state Accepted;
      state Rejected;
      state Withdrawn;

      transition Submitted->UnderReview when paperAssigned;
      transition UnderReview->Accepted when acceptDecision;
      transition UnderReview->Rejected when rejectDecision;
      transition Submitted->Withdrawn when authorWithdraws;
      transition UnderReview->Withdrawn when authorWithdraws;
    }
  }

  part def ReviewCommitteeSystem {
    port paperForReviewIn : PaperFlow;
    port reviewResultOut : ReviewFlow;

    attribute minReviews : Count = 3;
    attribute activeReviewerCount : Count = 0;
    attribute completedReviewCount : Count = 0;
    ref activeReviewers : Reviewer[0..*];
    ref assignedReviews : Review[0..*];
    ref pendingPapers : Paper[0..*];

    action def assignReviewers {
      in paper : Paper;
      in availableReviewers : Reviewer[1..*];
      out assignment : Review[1..*];
    }

    action def collectReview {
      in review : Review;
      out stored : Review;
    }

    action def aggregateScores {
      in reviewList : Review[1..*];
      out aggregateScore : ReviewScore;
      out recommendation : String;
    }

    action def checkConflict {
      in paper : Paper;
      in reviewer : Reviewer;
      out hasConflict : Boolean;
    }

    state reviewProcess {
      state AwaitingAssignments;
      state InReview;
      state Completed;

      transition AwaitingAssignments->InReview when assignmentComplete;
      transition InReview->Completed when allReviewsReceived;
    }
  }

  part def SessionScheduler {
    port acceptedPaperIn : AcceptedPaperFlow;
    port venueInfoIn : VenueInfoFlow;
    port programOut : ProgramFlow;

    attribute trackCount : Integer = 1;
    attribute sessionCount : Count = 0;
    attribute papersPerSession : Count = 4;
    ref sessions : Session[0..*];
    ref program : ConferenceProgram;

    action def organizeIntoSessions {
      in acceptedPapers : Paper[1..*];
      out sessions : Session[1..*];
    }

    action def assignSessionChair {
      in session : Session;
      in chairName : String;
      out updated : Session;
    }

    action def assignRoom {
      in session : Session;
      in room : Room;
      out updated : Session;
    }

    action def buildSchedule {
      in sessions : Session[1..*];
      in rooms : Room[1..*];
      out program : ConferenceProgram;
    }

    action def resolveConflicts {
      in sessions : Session[1..*];
      out resolved : Session[1..*];
    }

    state schedulingProcess {
      state Collecting;
      state Grouping;
      state Assigning;
      state Finalized;

      transition Collecting->Grouping when allPapersReceived;
      transition Grouping->Assigning when sessionsCreated;
      transition Assigning->Finalized when allRoomsAssigned;
    }
  }

  part def RegistrationSystem {
    port regIn : RegistrationFlow;
    port regAckOut : RegistrationFlow;

    attribute registeredCount : Count = 0;
    attribute earlyBirdCount : Count = 0;
    attribute regularCount : Count = 0;
    attribute studentCount : Count = 0;
    attribute onSiteCount : Count = 0;
    attribute maxCapacity : Capacity;
    attribute earlyBirdDeadline : DateValue;
    attribute regularDeadline : DateValue;
    attribute registrationOpen : Boolean = false;
    ref registeredParticipants : Participant[0..*];

    action def processRegistration {
      in participant : Participant;
      out confirmed : Participant;
    }

    action def updateCounts {
      in reg : Participant;
    }

    action def checkCapacity {
      out hasSpace : Boolean;
    }

    action def closeRegistration {
    }

    state registrationState {
      state Open;
      state Closed;
      state Full;

      transition Open->Closed when deadlinePassed;
      transition Open->Full when atCapacity;
      transition Full->Closed when deadlinePassed;
    }
  }

  part def VenueManagement {
    port venueInfoOut : VenueInfoFlow;

    attribute venueName : String;
    attribute location : String;
    attribute totalRooms : Count = 0;
    attribute totalCapacity : Capacity = 0;
    ref roomsAvailable : Room[0..*];

    action def allocateRooms {
      in sessionCount : Count;
      out allocation : Room[1..*];
    }

    action def checkAvailability {
      in date : DateValue;
      out available : Boolean;
    }

    action def updateCapacity {
    }
  }

  part def ConferenceManagementSystem {
    part paperManagement : PaperManagementSystem;
    part reviewCommittee : ReviewCommitteeSystem;
    part sessionScheduler : SessionScheduler;
    part registration : RegistrationSystem;
    part venue : VenueManagement;

    attribute currentPhase : ConferencePhase = ConferencePhase::PLANNING;
    attribute conferenceYear : Integer;
    attribute conferenceName : String;
    attribute city : String;
    attribute startDate : DateValue;
    attribute endDate : DateValue;
    attribute cfpDeadline : DateValue;
    attribute reviewDeadline : DateValue;

    connect paperManagement.paperForReviewOut to reviewCommittee.paperForReviewIn;
    connect reviewCommittee.reviewResultOut to paperManagement.reviewResultIn;
    connect paperManagement.acceptedPaperOut to sessionScheduler.acceptedPaperIn;
    connect venue.venueInfoOut to sessionScheduler.venueInfoIn;
    connect sessionScheduler.programOut to registration.regAckOut;

    state conferenceLifecycle {
      state planning;
      state callForPapers;
      state reviewing;
      state programCreation;
      state registrationOpen;
      state conferenceExecution;
      state postConference;

      transition planning->callForPapers when cfpAnnounced;
      transition callForPapers->reviewing when submissionDeadlineReached;
      transition reviewing->programCreation when reviewComplete;
      transition programCreation->registrationOpen when programPublished;
      transition registrationOpen->conferenceExecution when conferenceStarts;
      transition conferenceExecution->postConference when conferenceEnds;
      transition postConference->planning when nextYearPlanning;
    }
  }

  // ===== Requirements =====
  requirement def MinReviewRequirement {
    doc "Each submitted paper shall receive at least 3 independent reviews before a decision is made.";
    subject rcs : ReviewCommitteeSystem;
    constraint { rcs.minReviews >= 3 }
  }

  requirement def CapacityRequirement {
    doc "The number of registered attendees shall not exceed the maximum venue capacity.";
    subject rs : RegistrationSystem;
    constraint { rs.registeredCount <= rs.maxCapacity }
  }

  requirement def PaperTrackingRequirement {
    doc "The paper management system shall track all submitted papers through their full lifecycle from submission to final status.";
    subject pms : PaperManagementSystem;
  }

  requirement def SessionSchedulingRequirement {
    doc "The session scheduler shall organize all accepted papers into technical sessions with assigned chairs and rooms across multiple parallel tracks.";
    subject ss : SessionScheduler;
  }

  requirement def VenueTrackingRequirement {
    doc "The venue management component shall track the venue name, location, and all available rooms with their capacities.";
    subject vm : VenueManagement;
  }

  requirement def ConferenceLifecycleRequirement {
    doc "The conference management system shall progress through all defined phases: planning, call for papers, reviewing, program creation, registration, execution, and post-conference.";
    subject cms : ConferenceManagementSystem;
  }

  requirement def SubmissionTargetRequirement {
    doc "The system shall be configurable to handle approximately 400 paper submissions for the conference.";
    subject pms : PaperManagementSystem;
    constraint { pms.submissionCount <= 500 }
  }

  // ===== Specific Instance: ASPDAC 2024 =====
  part aspdac2024 : ConferenceManagementSystem {
    :>> conferenceName = "ASPDAC 2024";
    :>> conferenceYear = 2024;
    :>> city = "Seoul";
    :>> startDate = "2024-01-15";
    :>> endDate = "2024-01-18";
    :>> cfpDeadline = "2023-09-30";
    :>> reviewDeadline = "2023-11-15";

    part :>> paperManagement {
      :>> submissionCount = 400;
      :>> minReviewsRequired = 3;
      :>> acceptedCount = 180;
      :>> rejectedCount = 210;
      :>> withdrawnCount = 10;
    }

    part :>> reviewCommittee {
      :>> minReviews = 3;
      :>> activeReviewerCount = 120;
      :>> completedReviewCount = 1200;
    }

    part :>> sessionScheduler {
      :>> trackCount = 3;
      :>> sessionCount = 24;
      :>> papersPerSession = 7;
    }

    part :>> registration {
      :>> maxCapacity = 650;
      :>> registeredCount = 650;
      :>> earlyBirdCount = 350;
      :>> regularCount = 250;
      :>> studentCount = 120;
      :>> onSiteCount = 30;
      :>> earlyBirdDeadline = "2023-11-30";
      :>> regularDeadline = "2024-01-10";
      :>> registrationOpen = true;
    }

    part :>> venue {
      :>> venueName = "Coex Convention Center";
      :>> location = "Seoul, South Korea";
      :>> totalRooms = 5;
      :>> totalCapacity = 940;
      ref :>> roomsAvailable = (
        Room { roomId = "R1"; name = "Grand Ballroom"; capacity = 500; location = "1st Floor"; },
        Room { roomId = "R2"; name = "Conference Hall A"; capacity = 200; location = "2nd Floor"; },
        Room { roomId = "R3"; name = "Room 101"; capacity = 80; location = "1st Floor"; },
        Room { roomId = "R4"; name = "Room 102"; capacity = 80; location = "1st Floor"; },
        Room { roomId = "R5"; name = "Room 103"; capacity = 80; location = "1st Floor"; }
      );
    }
  }

  // ===== Satisfaction =====
  satisfaction of MinReviewRequirement by aspdac2024.reviewCommittee;
  satisfaction of CapacityRequirement by aspdac2024.registration;
  satisfaction of PaperTrackingRequirement by aspdac2024.paperManagement;
  satisfaction of SessionSchedulingRequirement by aspdac2024.sessionScheduler;
  satisfaction of VenueTrackingRequirement by aspdac2024.venue;
  satisfaction of ConferenceLifecycleRequirement by aspdac2024;
  satisfaction of SubmissionTargetRequirement by aspdac2024.paperManagement;

}
