package DesignAutomationConferenceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def PaperID :> String;
    attribute def ReviewerID :> String;
    attribute def SessionID :> String;
    attribute def AttendeeID :> String;
    attribute def TrackName :> String;
    attribute def ReviewScore :> Real;
    
    enum def SubmissionStatus {
        submitted;
        underReview;
        accepted;
        rejected;
        withdrawn;
    }
    
    enum def ReviewPhase {
        notStarted;
        inProgress;
        completed;
    }
    
    enum def RegistrationTier {
        student;
        academic;
        industry;
        exhibitor;
    }

    item def Paper {
        attribute id : PaperID;
        attribute title : String;
        attribute authors : String[1..*];
        attribute track : TrackName;
        attribute submissionDate : TimeValue;
        attribute status : SubmissionStatus;
        attribute reviewScores : ReviewScore[0..*];
        attribute finalScore : ReviewScore;
    }

    item def Reviewer {
        attribute id : ReviewerID;
        attribute name : String;
        attribute expertise : TrackName[1..*];
        attribute assignedPapers : PaperID[0..*];
        attribute completedReviews : Integer;
    }

    item def TechnicalSession {
        attribute id : SessionID;
        attribute title : String;
        attribute track : TrackName;
        attribute scheduledTime : TimeValue;
        attribute duration : DurationValue;
        attribute room : String;
        attribute papers : PaperID[1..*];
        attribute chairperson : String;
    }

    item def Attendee {
        attribute id : AttendeeID;
        attribute name : String;
        attribute affiliation : String;
        attribute tier : RegistrationTier;
        attribute registrationDate : TimeValue;
        attribute sessionsAttended : SessionID[0..*];
    }

    item def ConferenceProgram {
        attribute sessions : TechnicalSession[1..*];
        attribute tracks : TrackName[1..*];
        attribute publicationDate : TimeValue;
    }

    port def SubmissionPort {
        in item paperSubmission : Paper;
        out item submissionConfirmation : String;
    }

    port def ReviewPort {
        in item reviewAssignment : Paper;
        out item reviewResult : ReviewScore;
    }

    port def SchedulingPort {
        in item acceptedPapers : Paper[1..*];
        out item program : ConferenceProgram;
    }

    port def RegistrationPort {
        in item attendeeRegistration : Attendee;
        out item registrationConfirmation : String;
    }

    part def SubmissionManagementSystem {
        attribute totalSubmissions : Integer;
        attribute submissionDeadline : TimeValue;
        attribute acceptanceRate : Real;
        
        port submissionInterface : SubmissionPort;
        
        perform action processPaperSubmission {
            in paper : Paper;
            out confirmation : String;
            
            first start;
            then action validateSubmission {
                in paperData : Paper = paper;
                out isValid : Boolean;
            }
            then decide;
                if validateSubmission.isValid then acceptSubmission;
                if not validateSubmission.isValid then rejectSubmission;
            action acceptSubmission {
                out status : String = "Submission Accepted";
            }
            then done;
            action rejectSubmission {
                out status : String = "Submission Rejected - Invalid Format";
            }
            then done;
        }
    }

    part def PeerReviewSystem {
        attribute reviewerPool : Integer;
        attribute reviewsPerPaper : Integer = 3;
        attribute reviewDeadline : TimeValue;
        attribute currentPhase : ReviewPhase;
        
        port reviewInterface : ReviewPort;
        
        perform action coordinateReview {
            in paper : Paper;
            out finalDecision : SubmissionStatus;
            
            first start;
            then merge reviewCycle;
            then action assignReviewers {
                in paperToReview : Paper = paper;
                out assignments : Reviewer[3];
            }
            then action collectReviews {
                in assignments : Reviewer[3] = assignReviewers.assignments;
                out reviews : ReviewScore[3];
            }
            then action evaluateReviews {
                in scores : ReviewScore[3] = collectReviews.reviews;
                out avgScore : ReviewScore;
            }
            then decide;
                if evaluateReviews.avgScore >= 3.5 then acceptPaper;
                if evaluateReviews.avgScore < 3.5 and evaluateReviews.avgScore >= 2.5 then requestAdditionalReview;
                if evaluateReviews.avgScore < 2.5 then rejectPaper;
            action acceptPaper {
                out decision : SubmissionStatus = SubmissionStatus::accepted;
            }
            then done;
            action requestAdditionalReview;
            then reviewCycle;
            action rejectPaper {
                out decision : SubmissionStatus = SubmissionStatus::rejected;
            }
            then done;
        }
    }

    part def ProgramSchedulingSystem {
        attribute totalSessions : Integer;
        attribute parallelTracks : Integer = 8;
        attribute conferenceDuration : DurationValue = 4 [day];
        attribute programPublicationDeadline : TimeValue;
        
        port schedulingInterface : SchedulingPort;
        
        perform action buildConferenceProgram {
            in acceptedPapers : Paper[1..*];
            out program : ConferenceProgram;
            
            first start;
            then action groupPapersByTrack {
                in papers : Paper[1..*] = acceptedPapers;
                out trackGroups : Paper[1..*][1..*];
            }
            then action allocateTimeSlots {
                in groups : Paper[1..*][1..*] = groupPapersByTrack.trackGroups;
                out sessions : TechnicalSession[1..*];
            }
            then action assignRooms {
                in sessionList : TechnicalSession[1..*] = allocateTimeSlots.sessions;
                out finalSessions : TechnicalSession[1..*];
            }
            then action publishProgram {
                in sessions : TechnicalSession[1..*] = assignRooms.finalSessions;
                out conferenceProgram : ConferenceProgram;
            }
            then done;
        }
    }

    part def AttendeeRegistrationSystem {
        attribute registeredCount : Integer;
        attribute maxCapacity : Integer = 3000;
        attribute earlyBirdDeadline : TimeValue;
        
        port registrationInterface : RegistrationPort;
        
        perform action processRegistration {
            in attendee : Attendee;
            out confirmation : String;
            
            first start;
            then action checkCapacity {
                out hasSpace : Boolean;
            }
            then decide;
                if checkCapacity.hasSpace then registerAttendee;
                if not checkCapacity.hasSpace then waitlistAttendee;
            action registerAttendee {
                in attendeeData : Attendee = attendee;
                out status : String = "Registration Confirmed";
            }
            then done;
            action waitlistAttendee {
                out status : String = "Added to Waitlist";
            }
            then done;
        }
    }

    part def VenueManagementSystem {
        attribute totalRooms : Integer = 15;
        attribute mainHallCapacity : Integer = 800;
        attribute breakoutRoomCapacity : Integer = 150;
        
        part mainAuditorium {
            attribute capacity : Integer = 800;
            attribute audioVisual : Boolean = true;
            attribute recording : Boolean = true;
        }
        
        part breakoutRoom1 {
            attribute capacity : Integer = 150;
            attribute audioVisual : Boolean = true;
        }
        
        part breakoutRoom2 {
            attribute capacity : Integer = 150;
            attribute audioVisual : Boolean = true;
        }
        
        part breakoutRoom3 {
            attribute capacity : Integer = 150;
            attribute audioVisual : Boolean = true;
        }
        
        part exhibitionHall {
            attribute capacity : Integer = 500;
            attribute boothCount : Integer = 80;
        }
        
        part posterArea {
            attribute capacity : Integer = 200;
            attribute posterSlots : Integer = 100;
        }
    }

    part def NetworkingPlatform {
        attribute activeUsers : Integer;
        attribute matchingAlgorithmEnabled : Boolean = true;
        
        perform action facilitateNetworking {
            first start;
            then action matchParticipants {
                out matches : String[0..*];
            }
            then action scheduleNetworkingEvents {
                in matchData : String[0..*] = matchParticipants.matches;
                out events : String[0..*];
            }
            then action sendNotifications {
                in eventList : String[0..*] = scheduleNetworkingEvents.events;
            }
            then done;
        }
    }

    part conferenceSystem : DesignAutomationConference {
        attribute conferenceName : String = "Design Automation Conference";
        attribute conferenceYear : Integer = 2025;
        attribute startDate : TimeValue;
        attribute endDate : TimeValue;
        attribute expectedAttendees : Integer = 2500;
        attribute submissionDeadline : TimeValue;
        attribute notificationDate : TimeValue;
        
        part submissionMgmt : SubmissionManagementSystem {
            attribute :>> totalSubmissions = 850;
            attribute :>> acceptanceRate = 0.25;
        }
        
        part reviewMgmt : PeerReviewSystem {
            attribute :>> reviewerPool = 400;
            attribute :>> reviewsPerPaper = 3;
        }
        
        part programMgmt : ProgramSchedulingSystem {
            attribute :>> totalSessions = 60;
            attribute :>> parallelTracks = 8;
        }
        
        part registrationMgmt : AttendeeRegistrationSystem {
            attribute :>> maxCapacity = 3000;
        }
        
        part venueMgmt : VenueManagementSystem {
            attribute :>> totalRooms = 15;
        }
        
        part networkingPlatform : NetworkingPlatform;
        
        connection submissionToReview connect 
            submissionMgmt.submissionInterface to reviewMgmt.reviewInterface;
        
        connection reviewToScheduling connect 
            reviewMgmt.reviewInterface to programMgmt.schedulingInterface;
        
        perform action operateConference {
            first start;
            then action openSubmissions {
                perform submissionMgmt.processPaperSubmission;
            }
            then action conductReviews {
                perform reviewMgmt.coordinateReview;
            }
            then action createProgram {
                perform programMgmt.buildConferenceProgram;
            }
            then merge conferenceOperations;
            then action manageRegistrations {
                perform registrationMgmt.processRegistration;
            }
            then action runSessions;
            then action enableNetworking {
                perform networkingPlatform.facilitateNetworking;
            }
            then conferenceOperations;
        }
    }

    requirement <'REQ-DAC-001'> primaryFunction {
        doc /* The Design Automation Conference system shall orchestrate 
             * a comprehensive technical conference by managing paper submissions, 
             * coordinating peer review processes, scheduling technical sessions, 
             * handling attendee registration, managing venue resources, and 
             * facilitating professional networking to advance the field of 
             * electronic design automation.
            */
        subject system :> conferenceSystem;
    }

    requirement <'REQ-DAC-002'> submissionManagement {
        doc /* The system shall accept and process technical paper submissions 
             * with validation, tracking, and status notification capabilities.
            */
        subject submission :>> conferenceSystem.submissionMgmt;
        assert constraint {
            submission.totalSubmissions >= 500
        }
    }

    requirement <'REQ-DAC-003'> peerReviewQuality {
        doc /* Each submitted paper shall be reviewed by at least three 
             * qualified reviewers with expertise in the relevant technical area.
            */
        subject review :>> conferenceSystem.reviewMgmt;
        assert constraint {
            review.reviewsPerPaper >= 3 and review.reviewerPool >= 300
        }
    }

    requirement <'REQ-DAC-004'> programScheduling {
        doc /* The system shall generate a comprehensive conference program 
             * with multiple parallel tracks and publish it at least 30 days 
             * before the conference start date.
            */
        subject program :>> conferenceSystem.programMgmt;
        assert constraint {
            program.totalSessions >= 50 and program.parallelTracks >= 6
        }
    }

    requirement <'REQ-DAC-005'> attendeeCapacity {
        doc /* The system shall support registration and management of 
             * at least 2500 conference attendees across multiple registration tiers.
            */
        subject registration :>> conferenceSystem.registrationMgmt;
        assert constraint {
            registration.maxCapacity >= 2500
        }
    }

    requirement <'REQ-DAC-006'> venueAdequacy {
        doc /* The venue shall provide sufficient facilities including 
             * a main auditorium, multiple breakout rooms, exhibition space, 
             * and poster presentation areas to accommodate all conference activities.
            */
        subject venue :>> conferenceSystem.venueMgmt;
        assert constraint {
            venue.totalRooms >= 10 and venue.mainHallCapacity >= 500
        }
    }

    satisfy primaryFunction by conferenceSystem;
    satisfy submissionManagement by conferenceSystem.submissionMgmt;
    satisfy peerReviewQuality by conferenceSystem.reviewMgmt;
    satisfy programScheduling by conferenceSystem.programMgmt;
    satisfy attendeeCapacity by conferenceSystem.registrationMgmt;
    satisfy venueAdequacy by conferenceSystem.venueMgmt;
}
