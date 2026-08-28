package ASPDAC_Conference_Management_System {
	private import ScalarValues::*;
	private import Time::DateTime;

	package Definitions {

		enum def PaperStatus {
			Submitted;
			UnderReview;
			Accepted;
			Rejected;
		}

		enum def RegistrationType {
			EarlyBird;
			Regular;
			Student;
			Onsite;
		}

		item def Author {
			attribute authorId : String;
			attribute name : String;
			attribute affiliation : String;
			attribute email : String;
		}

		item def Reviewer {
			attribute reviewerId : String;
			attribute name : String;
			attribute expertise : String;
			attribute email : String;
		}

		item def Paper {
			attribute paperId : String;
			attribute title : String;
			attribute abstractText : String;
			attribute submissionDate : DateTime;
			attribute status : PaperStatus;
			ref item authors : Author[1..*];
		}

		item def Review {
			attribute reviewId : String;
			attribute score : Integer;
			attribute confidence : Integer;
			attribute comments : String;
			attribute reviewDate : DateTime;
			ref item reviewer : Reviewer[1];
			ref item paper : Paper[1];
		}

		item def Participant {
			attribute participantId : String;
			attribute name : String;
			attribute affiliation : String;
			attribute email : String;
			attribute registrationType : RegistrationType;
			attribute registrationDate : DateTime;
		}

		item def SessionChair {
			attribute chairId : String;
			attribute name : String;
			attribute affiliation : String;
		}

		item def Session {
			attribute sessionId : String;
			attribute title : String;
			attribute track : String;
			attribute startTime : DateTime;
			attribute endTime : DateTime;
			ref item chair : SessionChair[1];
			ref item papers : Paper[1..*];
		}

		item def Room {
			attribute roomId : String;
			attribute name : String;
			attribute capacity : Integer;
		}

		item def Venue {
			attribute venueName : String;
			attribute location : String;
			ref item rooms : Room[1..*];
			attribute totalCapacity : Integer;
		}

		port def PaperSubmissionPort {
			in item submittedPapers : Paper[*];
		}

		port def ReviewAssignmentPort {
			out item papersToReview : Paper[*];
			in item completedReviews : Review[*];
		}

		port def AcceptedPapersPort {
			out item acceptedPapers : Paper[*];
		}

		port def SchedulePort {
			out item sessions : Session[*];
		}

		port def RegistrationPort {
			in item participants : Participant[*];
			out item registrationCount : Integer;
		}

		port def VenueInfoPort {
			out item venue : Venue[1];
		}

		part def PaperManagementSystem {
			port submissionPort : PaperSubmissionPort;
			port reviewPort : ReviewAssignmentPort;
			port acceptedPapersPort : AcceptedPapersPort;
			attribute paperCount : Integer;
			ref item papers : Paper[*];
			action def ManagePapers {
				in item incomingPapers : Paper[*];
				out item acceptedPapers : Paper[*];
				action receiveSubmissions;
				action assignToReview;
				action recordDecisions;
				first receiveSubmissions then assignToReview;
				first assignToReview then recordDecisions;
			}
		}

		part def ReviewCommittee {
			port reviewPort : ReviewAssignmentPort;
			ref item reviewers : Reviewer[*];
			ref item reviews : Review[*];
			attribute minReviewsPerPaper : Integer = 3;
			action def ConductReviews {
				in item papersToReview : Paper[*];
				out item completedReviews : Review[*];
				action assignReviewers;
				action collectReviews;
				action aggregateScores;
				first assignReviewers then collectReviews;
				first collectReviews then aggregateScores;
			}
		}

		part def SessionScheduler {
			port acceptedPapersPort : AcceptedPapersPort;
			port schedulePort : SchedulePort;
			ref item sessions : Session[*];
			action def BuildSchedule {
				in item acceptedPapers : Paper[*];
				out item sessions : Session[*];
				action groupPapers;
				action assignChairs;
				action assignRooms;
				action createTimetable;
				first groupPapers then assignChairs;
				first assignChairs then assignRooms;
				first assignRooms then createTimetable;
			}
		}

		part def RegistrationSystem {
			port registrationPort : RegistrationPort;
			attribute maxCapacity : Integer;
			attribute currentCount : Integer;
			ref item participants : Participant[*];
			action def ProcessRegistrations {
				in item participants : Participant[*];
				out item registrationCount : Integer;
				action receiveRegistration;
				action validateCapacity;
				action confirmRegistration;
				first receiveRegistration then validateCapacity;
				first validateCapacity then confirmRegistration;
			}
		}

		part def VenueManagement {
			port venueInfoPort : VenueInfoPort;
			ref item venue : Venue[1];
			attribute totalCapacity : Integer;
		}

		state def ConferenceLifecycle {
			state planning;
			state callForPapers;
			state reviewing;
			state programCreation;
			state registrationOpen;
			state conferenceExecution;
			state postConference;
			transition from planning to callForPapers;
			transition from callForPapers to reviewing;
			transition from reviewing to programCreation;
			transition from programCreation to registrationOpen;
			transition from registrationOpen to conferenceExecution;
			transition from conferenceExecution to postConference;
		}

		part def Conference {
			attribute conferenceName : String;
			attribute year : Integer;
			attribute location : String;
			part paperManagement : PaperManagementSystem;
			part reviewCommittee : ReviewCommittee;
			part sessionScheduler : SessionScheduler;
			part registrationSystem : RegistrationSystem;
			part venueManagement : VenueManagement;
			connect paperManagement.reviewPort to reviewCommittee.reviewPort;
			connect paperManagement.acceptedPapersPort to sessionScheduler.acceptedPapersPort;
			exhibit ConferenceLifecycle;
		}

		requirement def MinReviewRequirement {
			doc
			/*
			 * Each submitted paper must receive at least three independent reviews.
			 */
			subject reviewCommittee : ReviewCommittee;
			attribute requiredReviews : Integer = 3;
			require reviewCommittee.minReviewsPerPaper >= requiredReviews;
		}

		requirement def CapacityRequirement {
			doc
			/*
			 * The number of registered attendees must not exceed the maximum venue capacity.
			 */
			subject registrationSystem : RegistrationSystem;
			require registrationSystem.currentCount <= registrationSystem.maxCapacity;
		}

		requirement def PaperTrackingRequirement {
			doc
			/*
			 * The Paper Management System must track the status of every submitted paper
			 * from submission through final acceptance or rejection.
			 */
			subject paperManagement : PaperManagementSystem;
			require paperManagement.paperCount == paperManagement.papers->size();
		}

		requirement def ScheduleCompletenessRequirement {
			doc
			/*
			 * Every accepted paper must be assigned to exactly one technical session.
			 */
			subject sessionScheduler : SessionScheduler;
			require sessionScheduler.sessions->size() > 0;
		}
	}

	package Usages {
		public import Definitions::*;

		individual part def ASPDAC2024 :> Conference {
			doc
			/*
			 * The 2024 instance of the Asia and South Pacific Design Automation Conference,
			 * held in Seoul, South Korea, configured for approximately 400 paper submissions
			 * and 650 attendees.
			 */
			attribute conferenceName = "ASPDAC 2024";
			attribute year = 2024;
			attribute location = "Seoul, South Korea";

			part :>> paperManagement {
				attribute paperCount = 400;
			}

			part :>> reviewCommittee {
				attribute minReviewsPerPaper = 3;
			}

			part :>> registrationSystem {
				attribute maxCapacity = 650;
				attribute currentCount = 0;
			}

			part :>> venueManagement {
				ref item :>> venue {
					attribute :>> venueName = "COEX Convention Center";
					attribute :>> location = "Seoul, South Korea";
					attribute :>> totalCapacity = 650;
					ref item room1 : Room :>> rooms {
						attribute :>> roomId = "R1";
						attribute :>> name = "Grand Ballroom";
						attribute :>> capacity = 300;
					}
					ref item room2 : Room :>> rooms {
						attribute :>> roomId = "R2";
						attribute :>> name = "Hall A";
						attribute :>> capacity = 200;
					}
					ref item room3 : Room :>> rooms {
						attribute :>> roomId = "R3";
						attribute :>> name = "Hall B";
						attribute :>> capacity = 150;
					}
				}
			}
		}

		part aspdac2024 : ASPDAC2024;

		requirement aspdac2024_minReviews : MinReviewRequirement {
			:>> reviewCommittee = aspdac2024.reviewCommittee;
		}

		requirement aspdac2024_capacity : CapacityRequirement {
			:>> registrationSystem = aspdac2024.registrationSystem;
		}

		requirement aspdac2024_paperTracking : PaperTrackingRequirement {
			:>> paperManagement = aspdac2024.paperManagement;
		}

		requirement aspdac2024_schedule : ScheduleCompletenessRequirement {
			:>> sessionScheduler = aspdac2024.sessionScheduler;
		}
	}
}
