package InternationalConferenceOnCAD {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PaperID :> String;
    attribute def ReviewerID :> String;
    attribute def SessionID :> String;
    attribute def AttendeeID :> String;
    
    attribute def PaperCount :> Integer;
    attribute def ReviewScore :> Real;
    attribute def AttendeeCount :> Integer;
    attribute def SessionDuration :> Real;
    
    enum def PaperStatus {
        submitted;
        underReview;
        accepted;
        rejected;
        published;
    }
    
    enum def ReviewDecision {
        strongAccept;
        accept;
        borderline;
        reject;
        strongReject;
    }
    
    enum def SessionType {
        keynote;
        technical;
        poster;
        workshop;
        panel;
    }
    
    enum def RegistrationType {
        student;
        academic;
        industry;
        exhibitor;
    }
    
    item def Paper {
        attribute paperID : PaperID;
        attribute title : String;
        attribute authors : String[1..*];
        attribute paperAbstract : String;
        attribute keywords : String[1..*];
        attribute status : PaperStatus;
        attribute submissionDate : String;
        attribute pageCount : Integer;
    }
    
    item def Review {
        attribute reviewerID : ReviewerID;
        attribute paperID : PaperID;
        attribute technicalScore : ReviewScore;
        attribute presentationScore : ReviewScore;
        attribute noveltyScore : ReviewScore;
        attribute overallScore : ReviewScore;
        attribute decision : ReviewDecision;
        attribute confidenceLevel : Real;
        attribute comments : String;
    }
    
    item def Session {
        attribute sessionID : SessionID;
        attribute sessionType : SessionType;
        attribute title : String;
        attribute chairPerson : String;
        attribute startTime : String;
        attribute duration : SessionDuration;
        attribute roomNumber : String;
        attribute capacity : Integer;
    }
    
    item def Attendee {
        attribute attendeeID : AttendeeID;
        attribute name : String;
        attribute affiliation : String;
        attribute email : String;
        attribute registrationType : RegistrationType;
        attribute registrationDate : String;
    }
    
    port def SubmissionPort {
        in submittedPaper : Paper;
        out acknowledgement : Boolean;
    }
    
    port def ReviewPort {
        out paperForReview : Paper;
        in completedReview : Review;
    }
    
    port def RegistrationPort {
        in attendeeInfo : Attendee;
        out confirmation : Boolean;
    }
    
    port def SchedulePort {
        out sessionSchedule : Session[*];
        in attendanceRequest : SessionID;
    }
    
    port def PublicationPort {
        in acceptedPaper : Paper;
        out proceedingsEntry : String;
    }
    
    part def PaperSubmissionSystem {
        attribute totalSubmissions : PaperCount;
        attribute submissionDeadline : String;
        
        port submissionInterface : SubmissionPort;
        
        part database {
            attribute paperRecords : Paper[0..*];
        }
        
        perform action processPaperSubmission {
            in paper : Paper;
            out accepted : Boolean;
            
            first start;
            then action validateFormat {
                in submittedPaper = paper;
                out isValid : Boolean;
            }
            then decide;
                if validateFormat.isValid then storePaper;
                else rejectSubmission;
            action storePaper {
                out stored : Boolean = true;
            }
            then sendAcknowledgement;
            action rejectSubmission {
                out rejected : Boolean = true;
            }
            then sendAcknowledgement;
            action sendAcknowledgement {
                out ack : Boolean;
            }
            then done;
        }
    }
    
    part def PeerReviewSystem {
        attribute reviewersPerPaper : Integer;
        attribute reviewDeadline : String;
        attribute acceptanceRate : Real;
        
        port reviewInterface : ReviewPort;
        
        part reviewerPool {
            attribute reviewers : ReviewerID[0..*];
            attribute expertiseAreas : String[0..*];
        }
        
        perform action conductPeerReview {
            in paper : Paper;
            out finalDecision : PaperStatus;
            
            first start;
            then action assignReviewers {
                in paperToReview = paper;
                out assignedReviewers : ReviewerID[3..5];
            }
            then action collectReviews {
                in reviewers = assignReviewers.assignedReviewers;
                out reviews : Review[3..5];
            }
            then action aggregateScores {
                in reviewSet = collectReviews.reviews;
                out averageScore : ReviewScore;
                out recommendation : ReviewDecision;
            }
            then decide;
                if aggregateScores.averageScore >= 7.5 then acceptPaper;
                if aggregateScores.averageScore >= 5.0 and aggregateScores.averageScore < 7.5 then conditionalAccept;
                if aggregateScores.averageScore < 5.0 then rejectPaper;
            action acceptPaper {
                out status : PaperStatus = PaperStatus::accepted;
            }
            then notifyAuthors;
            action conditionalAccept {
                out status : PaperStatus = PaperStatus::underReview;
            }
            then requestRevision;
            action rejectPaper {
                out status : PaperStatus = PaperStatus::rejected;
            }
            then notifyAuthors;
            action requestRevision {
                out revisionRequest : String;
            }
            then notifyAuthors;
            action notifyAuthors {
                out notification : String;
            }
            then done;
        }
    }
    
    part def RegistrationSystem {
        attribute maxAttendees : AttendeeCount;
        attribute currentAttendees : AttendeeCount;
        attribute earlyBirdDeadline : String;
        
        port registrationInterface : RegistrationPort;
        
        part paymentProcessor {
            attribute transactionRecords : String[0..*];
        }
        
        perform action processRegistration {
            in attendee : Attendee;
            out registered : Boolean;
            
            first start;
            then action checkCapacity {
                in currentCount = currentAttendees;
                in maxCount = maxAttendees;
                out hasSpace : Boolean;
            }
            then decide;
                if checkCapacity.hasSpace then validatePayment;
                else waitlist;
            action validatePayment {
                in attendeeData = attendee;
                out paymentValid : Boolean;
            }
            then confirmRegistration;
            action waitlist {
                out waitlistPosition : Integer;
            }
            then done;
            action confirmRegistration {
                out confirmation : Boolean = true;
            }
            then done;
        }
    }
    
    part def SessionScheduler {
        attribute totalSessions : Integer;
        attribute parallelTracks : Integer;
        attribute conferenceDays : Integer;
        
        port scheduleInterface : SchedulePort;
        
        part venueManagement {
            attribute rooms : String[0..*];
            attribute roomCapacities : Integer[0..*];
        }
        
        perform action createSchedule {
            in acceptedPapers : Paper[*];
            out schedule : Session[*];
            
            first start;
            then action groupByTopic {
                in papers = acceptedPapers;
                out topicGroups : String[*];
            }
            then action allocateTimeSlots {
                in groups = groupByTopic.topicGroups;
                out timeSlots : String[*];
            }
            then action assignRooms {
                in slots = allocateTimeSlots.timeSlots;
                out roomAssignments : String[*];
            }
            then action generateSessions {
                in assignments = assignRooms.roomAssignments;
                out sessions = schedule;
            }
            then publishSchedule;
            action publishSchedule {
                out published : Boolean = true;
            }
            then done;
        }
    }
    
    part def PublicationSystem {
        attribute proceedingsTitle : String;
        attribute publisher : String;
        attribute isbn : String;
        
        port publicationInterface : PublicationPort;
        
        part digitalLibrary {
            attribute publishedPapers : Paper[0..*];
        }
        
        perform action publishProceedings {
            in acceptedPapers : Paper[*];
            out proceedings : String;
            
            first start;
            then action compilePapers {
                in papers = acceptedPapers;
                out compiledVolume : String;
            }
            then action formatProceedings {
                in volume = compilePapers.compiledVolume;
                out formattedProceedings : String;
            }
            then action assignDOI {
                in formatted = formatProceedings.formattedProceedings;
                out withDOI : String;
            }
            then action uploadToLibrary {
                in finalProceedings = assignDOI.withDOI;
                out uploaded : Boolean = true;
            }
            then done;
        }
    }
    
    part def ConferenceManagementSystem {
        attribute conferenceName : String;
        attribute conferenceYear : Integer;
        attribute location : String;
        attribute startDate : String;
        attribute endDate : String;
        attribute expectedSubmissions : PaperCount;
        attribute expectedAttendees : AttendeeCount;
        
        part submissionSys : PaperSubmissionSystem {
            attribute :>> totalSubmissions = 0;
            attribute :>> submissionDeadline = "2025-04-15";
        }
        
        part reviewSys : PeerReviewSystem {
            attribute :>> reviewersPerPaper = 3;
            attribute :>> reviewDeadline = "2025-06-01";
            attribute :>> acceptanceRate = 0.25;
        }
        
        part registrationSys : RegistrationSystem {
            attribute :>> maxAttendees = 800;
            attribute :>> currentAttendees = 0;
            attribute :>> earlyBirdDeadline = "2025-08-01";
        }
        
        part scheduler : SessionScheduler {
            attribute :>> totalSessions = 60;
            attribute :>> parallelTracks = 6;
            attribute :>> conferenceDays = 4;
        }
        
        part publicationSys : PublicationSystem {
            attribute :>> proceedingsTitle = "ICCAD 2025 Proceedings";
            attribute :>> publisher = "ACM";
            attribute :>> isbn = "978-1-4503-XXXX-X";
        }
        
        connection submissionToReview 
            connect submissionSys.submissionInterface to reviewSys.reviewInterface;
        
        connection reviewToScheduler 
            connect reviewSys.reviewInterface to scheduler.scheduleInterface;
        
        connection schedulerToRegistration 
            connect scheduler.scheduleInterface to registrationSys.registrationInterface;
        
        connection reviewToPublication 
            connect reviewSys.reviewInterface to publicationSys.publicationInterface;
    }
    
    requirement <'REQ-ICCAD-001'> primaryConferenceFunction {
        doc /* The International Conference on Computer-Aided Design system 
             * shall facilitate the complete lifecycle of an academic conference,
             * including paper submission, peer review, attendee registration,
             * session scheduling, and proceedings publication, to advance
             * research and knowledge exchange in computer-aided design.
             */
        subject conferenceSystem : ConferenceManagementSystem;
    }
    
    requirement <'REQ-ICCAD-002'> submissionManagement {
        doc /* The system shall accept and manage paper submissions with
             * validation of format requirements and provide acknowledgement
             * to authors within 24 hours of submission.
             */
        subject submissionSystem :>> ConferenceManagementSystem::submissionSys;
    }
    
    requirement <'REQ-ICCAD-003'> peerReviewQuality {
        doc /* The system shall ensure each submitted paper receives at least
             * three independent peer reviews from qualified reviewers with
             * relevant expertise in the paper's topic area.
             */
        subject reviewSystem :>> ConferenceManagementSystem::reviewSys;
        
        assert constraint {
            reviewSystem.reviewersPerPaper >= 3
        }
    }
    
    requirement <'REQ-ICCAD-004'> acceptanceRateControl {
        doc /* The system shall maintain a paper acceptance rate of approximately
             * 25% to ensure high quality of the technical program.
             */
        subject reviewSystem :>> ConferenceManagementSystem::reviewSys;
        
        assert constraint {
            reviewSystem.acceptanceRate >= 0.20 and reviewSystem.acceptanceRate <= 0.30
        }
    }
    
    requirement <'REQ-ICCAD-005'> attendeeCapacity {
        doc /* The system shall support registration and management of up to
             * 800 conference attendees across multiple registration categories.
             */
        subject registrationSystem :>> ConferenceManagementSystem::registrationSys;
        
        assert constraint {
            registrationSystem.maxAttendees >= 800
        }
    }
    
    requirement <'REQ-ICCAD-006'> sessionScheduling {
        doc /* The system shall organize accepted papers into at least 60
             * technical sessions across 6 parallel tracks over 4 conference days.
             */
        subject schedulerSystem :>> ConferenceManagementSystem::scheduler;
        
        assert constraint {
            schedulerSystem.totalSessions >= 60 and
            schedulerSystem.parallelTracks >= 6 and
            schedulerSystem.conferenceDays >= 4
        }
    }
    
    requirement <'REQ-ICCAD-007'> proceedingsPublication {
        doc /* The system shall compile and publish conference proceedings
             * containing all accepted papers with assigned DOIs in both
             * digital and print formats.
             */
        subject publicationSystem :>> ConferenceManagementSystem::publicationSys;
    }
    
    part iccad2025 : ConferenceManagementSystem {
        attribute :>> conferenceName = "International Conference on Computer-Aided Design 2025";
        attribute :>> conferenceYear = 2025;
        attribute :>> location = "San Francisco, CA, USA";
        attribute :>> startDate = "2025-11-02";
        attribute :>> endDate = "2025-11-05";
        attribute :>> expectedSubmissions = 400;
        attribute :>> expectedAttendees = 750;
    }
    
    satisfy primaryConferenceFunction by iccad2025;
    satisfy submissionManagement by iccad2025.submissionSys;
    satisfy peerReviewQuality by iccad2025.reviewSys;
    satisfy acceptanceRateControl by iccad2025.reviewSys;
    satisfy attendeeCapacity by iccad2025.registrationSys;
    satisfy sessionScheduling by iccad2025.scheduler;
    satisfy proceedingsPublication by iccad2025.publicationSys;
}
