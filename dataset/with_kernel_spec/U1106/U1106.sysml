package ConferenceManagementSystem {
	private import ScalarValues::*;

	item def Author {
		attribute name : String;
		attribute affiliation : String;
		attribute email : String;
	}

	enum def PaperStatus {
		Submitted;
		UnderReview;
		Accepted;
		Rejected;
		RevisionRequested;
		Finalized;
	}

	item def Paper {
		attribute paperId : String;
		attribute title : String;
		attribute authors : Author[1..*];
		attribute abstractText : String;
		attribute keywords : String[1..*];
		attribute submissionDate : String;
		attribute status : PaperStatus;
	}

	enum def ReviewRecommendation {
		Accept;
		Reject;
		Revise;
	}

	item def Review {
		attribute reviewId : String;
		attribute reviewerName : String;
		attribute technicalMerit : Integer;
		attribute novelty : Integer;
		attribute presentation : Integer;
		attribute overallScore : Integer;
		attribute comments : String;
		attribute recommendation : ReviewRecommendation;
	}

	item def Decision {
		attribute paper : Paper;
		attribute recommendation : ReviewRecommendation;
		attribute reviews : Review[1..*];
	}

	item def Acknowledgement {
		attribute paperId : String;
		attribute text : String;
		attribute timestamp : String;
	}

	enum def ParticipantType {
		Student;
		Academic;
		Industry;
	}

	enum def PaymentStatus {
		Pending;
		Completed;
		Failed;
		Refunded;
	}

	item def Registration {
		attribute registrationId : String;
		attribute participantName : String;
		attribute participantType : ParticipantType;
		attribute paymentStatus : PaymentStatus;
		attribute registrationDate : String;
		attribute amountPaid : Real;
	}

	item def RegistrationConfirmation {
		attribute registrationId : String;
		attribute participantName : String;
		attribute text : String;
	}

	enum def SessionType {
		Paper;
		Keynote;
		Panel;
		Workshop;
	}

	item def TimeSlot {
		attribute day : Integer;
		attribute startTime : String;
		attribute endTime : String;
	}

	item def Session {
		attribute sessionId : String;
		attribute title : String;
		attribute sessionType : SessionType;
		attribute track : String;
		attribute room : String;
		attribute timeSlot : TimeSlot;
		attribute papers : Paper[0..*];
	}

	item def Schedule {
		attribute sessions : Session[0..*] ordered;
		attribute generatedOn : String;
	}

	item def Proceedings {
		attribute proceedingsId : String;
		attribute title : String;
		attribute publicationDate : String;
		attribute doi : String;
		attribute papers : Paper[0..*];
	}

	attribute def AcceptanceRate :> Real;
	attribute def MaxCapacity :> Integer;
	attribute def ReviewerCount :> Integer;
	attribute def RegistrationFee :> Real;

	port def SubmissionReviewPort {
		out paper : Paper;
		in acknowledgement : Acknowledgement;
		in decision : Decision;
	}

	port def AcceptedPaperPort {
		out acceptedPaper : Paper;
	}

	port def RegistrationPort {
		in registration : Registration;
		out confirmation : RegistrationConfirmation;
	}

	port def SchedulePort {
		out schedule : Schedule;
	}

	port def PublicationPort {
		out proceedings : Proceedings;
	}

	requirement def FormattingRequirement {
		doc
		/*
		 * Submitted papers must meet the conference formatting requirements
		 * including page limits, font size, and template compliance.
		 */
	}

	requirement def SubmissionDeadlineRequirement {
		attribute deadline : String;
		doc
		/*
		 * All paper submissions must be received before the submission deadline.
		 */
	}

	requirement def ReviewDeadlineRequirement {
		attribute deadline : String;
		doc
		/*
		 * All peer reviews must be completed before the review deadline.
		 */
	}

	requirement def AcceptanceRateRequirement {
		attribute targetRate : AcceptanceRate = 25.0;
		doc
		/*
		 * The conference shall target an acceptance rate of approximately 25%
		 * to maintain high academic standards.
		 */
	}

	requirement def VenueCapacityRequirement {
		attribute maxCapacity : MaxCapacity = 500;
		doc
		/*
		 * The total number of registered attendees shall not exceed
		 * the maximum venue capacity.
		 */
	}

	requirement def DOIAssignmentRequirement {
		doc
		/*
		 * Each accepted paper in the proceedings shall be assigned
		 * a permanent Digital Object Identifier (DOI).
		 */
	}

	requirement def EarlyBirdDeadlineRequirement {
		attribute deadline : String;
		doc
		/*
		 * Early-bird registration discounts shall be available only
		 * before the early-bird deadline.
		 */
	}

	part def PaperSubmissionSystem {
		port toReviewSystem : SubmissionReviewPort;
		attribute submissionDeadline : String;
		attribute paperDatabase : Paper[0..*];
		attribute deadlineReached : Boolean = false;

		requirement compliance {
			public import FormattingRequirement;
			public import SubmissionDeadlineRequirement;
		}

		state machine def SubmissionState {
			state Open;
			state Closed;
			transition from Open to Closed if deadlineReached;
		}

		action def SubmitPaper {
			in paper : Paper;
			out validatedPaper : Paper;
			out ack : Acknowledgement;

			action ValidateFormatting {
				in p : Paper;
				out valid : Boolean;
			}
			then CheckDeadline;
			action CheckDeadline {
				in p : Paper;
				out withinDeadline : Boolean;
			}
			then StorePaper;
			action StorePaper {
				in p : Paper;
				out storedPaper : Paper;
			}
			then SendAcknowledgement;
			action SendAcknowledgement {
				in p : Paper;
				out ack : Acknowledgement;
			}
		}
	}

	part def PeerReviewSystem {
		port fromSubmissionSystem : ~SubmissionReviewPort;
		port toScheduler : AcceptedPaperPort;
		port toPublication : AcceptedPaperPort;
		attribute reviewDeadline : String;
		attribute reviewerPool : String[1..*];
		attribute targetAcceptanceRate : AcceptanceRate = 25.0;
		attribute reviewerCount : ReviewerCount = 3;
		attribute reviews : Review[0..*];
		attribute reviewDeadlineReached : Boolean = false;

		requirement reviewCompliance {
			public import ReviewDeadlineRequirement;
			public import AcceptanceRateRequirement;
		}

		action def ReviewProcess {
			in paper : Paper;
			out decision : Decision;
			out acceptedPaper : Paper;

			action AssignReviewers {
				in p : Paper;
				out reviewers : String[3];
			}
			then CollectReviews;
			action CollectReviews {
				in p : Paper;
				in reviewers : String[3];
				out reviews : Review[3];
			}
			then AggregateReviews;
			action AggregateReviews {
				in reviews : Review[3];
				out decision : Decision;
			}
			then NotifyDecision;
			action NotifyDecision {
				in d : Decision;
				out acceptedPaper : Paper;
			}
		}
	}

	part def RegistrationSystem {
		port registrationPort : RegistrationPort;
		attribute maxCapacity : MaxCapacity = 500;
		attribute currentRegistrations : Integer = 0;
		attribute waitlist : Registration[0..*];
		attribute earlyBirdDeadline : String;
		attribute earlyBirdDeadlineReached : Boolean = false;
		attribute isFull : Boolean = false;
		attribute studentFee : RegistrationFee = 200.0;
		attribute academicFee : RegistrationFee = 400.0;
		attribute industryFee : RegistrationFee = 600.0;
		attribute earlyBirdDiscount : Real = 0.2;

		requirement registrationCompliance {
			public import VenueCapacityRequirement;
			public import EarlyBirdDeadlineRequirement;
		}

		state machine def RegistrationState {
			state EarlyBirdOpen;
			state RegularOpen;
			state Full;
			transition from EarlyBirdOpen to RegularOpen if earlyBirdDeadlineReached;
			transition from RegularOpen to Full if isFull;
		}

		action def ProcessRegistration {
			in reg : Registration;
			out confirmation : RegistrationConfirmation;

			action CheckCapacity {
				in r : Registration;
				out hasSpace : Boolean;
			}
			then ProcessPayment;
			action ProcessPayment {
				in r : Registration;
				out paymentStatus : PaymentStatus;
			}
			then SendConfirmation;
			action SendConfirmation {
				in r : Registration;
				out conf : RegistrationConfirmation;
			}
		}
	}

	part def SessionScheduler {
		port fromReviewSystem : ~AcceptedPaperPort;
		port schedulePort : SchedulePort;
		attribute conferenceDays : Integer = 5;
		attribute rooms : String[1..*];
		attribute tracks : String[1..*];
		attribute sessions : Session[0..*];
		attribute acceptedPapers : Paper[0..*];

		action def BuildSchedule {
			in papers : Paper[0..*];
			out schedule : Schedule;

			action GroupByTopic {
				in papers : Paper[0..*];
				out groupedPapers : Paper[0..*];
			}
			then AssignTimeSlots;
			action AssignTimeSlots {
				in groupedPapers : Paper[0..*];
				out scheduledSessions : Session[0..*];
			}
			then AssignRooms;
			action AssignRooms {
				in sessions : Session[0..*];
				out roomedSessions : Session[0..*];
			}
			then OrganizeTracks;
			action OrganizeTracks {
				in sessions : Session[0..*];
				out trackedSessions : Session[0..*];
			}
			then AddKeynotes;
			action AddKeynotes {
				in sessions : Session[0..*];
				out withKeynotes : Session[0..*];
			}
			then CompileProgram;
			action CompileProgram {
				in sessions : Session[0..*];
				out schedule : Schedule;
			}
		}
	}

	part def PublicationSystem {
		port fromReviewSystem : ~AcceptedPaperPort;
		port publicationPort : PublicationPort;
		attribute finalizedPapers : Paper[0..*];
		attribute proceedings : Proceedings;

		requirement publicationCompliance {
			public import DOIAssignmentRequirement;
		}

		action def PublishProceedings {
			in acceptedPapers : Paper[0..*];
			out proceedings : Proceedings;

			action CollectFinalizedPapers {
				in papers : Paper[0..*];
				out finalized : Paper[0..*];
			}
			then CompileVolume;
			action CompileVolume {
				in papers : Paper[0..*];
				out volume : Proceedings;
			}
			then AssignDOIs;
			action AssignDOIs {
				in volume : Proceedings;
				out withDOIs : Proceedings;
			}
			then UploadToLibrary;
			action UploadToLibrary {
				in proceedings : Proceedings;
				out published : Proceedings;
			}
		}
	}

	part def ICCADConferenceSystem {
		doc
		/*
		 * International Conference on Computer-Aided Design (ICCAD)
		 * Conference Management System
		 */

		part paperSubmission : PaperSubmissionSystem {
			attribute submissionDeadline : String = "2024-06-15";
		}

		part peerReview : PeerReviewSystem {
			attribute reviewDeadline : String = "2024-08-01";
			attribute targetAcceptanceRate : AcceptanceRate = 25.0;
		}

		part registration : RegistrationSystem {
			attribute maxCapacity : MaxCapacity = 500;
			attribute earlyBirdDeadline : String = "2024-09-01";
		}

		part sessionScheduler : SessionScheduler {
			attribute conferenceDays : Integer = 5;
			attribute rooms : String[1..*] = ("RoomA", "RoomB", "RoomC", "RoomD");
			attribute tracks : String[1..*] = ("Logic", "Verification", "PhysicalDesign", "Architecture");
		}

		part publication : PublicationSystem;

		interface submissionToReview
			connect paperSubmission.toReviewSystem to peerReview.fromSubmissionSystem {
				flow paperFlow of Paper
					from paperSubmission.toReviewSystem.paper
					to peerReview.fromSubmissionSystem.paper;
				flow acknowledgementFlow of Acknowledgement
					from peerReview.fromSubmissionSystem.acknowledgement
					to paperSubmission.toReviewSystem.acknowledgement;
				flow decisionFlow of Decision
					from peerReview.fromSubmissionSystem.decision
					to paperSubmission.toReviewSystem.decision;
			}

		interface reviewToScheduler
			connect peerReview.toScheduler to sessionScheduler.fromReviewSystem {
				flow acceptedPaperToSchedule of Paper
					from peerReview.toScheduler.acceptedPaper
					to sessionScheduler.fromReviewSystem.acceptedPaper;
			}

		interface reviewToPublication
			connect peerReview.toPublication to publication.fromReviewSystem {
				flow acceptedPaperToPublish of Paper
					from peerReview.toPublication.acceptedPaper
					to publication.fromReviewSystem.acceptedPaper;
			}
	}

	action def ConferenceLifecycle {
		action Submit {
			out paper : Paper;
		}
		then Review;
		action Review {
			in paper : Paper;
			out acceptedPaper : Paper;
		}
		flow Submit.paper to Review.paper;
		then fork F {
			in acceptedPaper : Paper;
			out toSchedule : Paper;
			out toPublish : Paper;
		}
		flow Review.acceptedPaper to F.acceptedPaper;
		then Schedule;
		then Publish;
		action Schedule {
			in paper : Paper;
		}
		then M;
		action Publish {
			in paper : Paper;
		}
		then M;
		flow F.toSchedule to Schedule.paper;
		flow F.toPublish to Publish.paper;
		merge M;
	}

	part iccad2024 : ICCADConferenceSystem {
		doc
		/*
		 * ICCAD 2024 Conference Management System instance.
		 */
	}
}
