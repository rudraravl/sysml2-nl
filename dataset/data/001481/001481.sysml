package 'Journal of Electrical and Computer Engineering System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ManuscriptIdentifier :> String;
	attribute def ReviewerIdentifier :> String;
	attribute def DOI :> String;
	
	enum def ManuscriptStatus {
		enum submitted;
		enum underReview;
		enum revisionRequested;
		enum revised;
		enum accepted;
		enum rejected;
		enum inProduction;
		enum published;
	}
	
	enum def ReviewDecision {
		enum acceptDecision;
		enum minorRevision;
		enum majorRevision;
		enum rejectDecision;
	}
	
	item def Manuscript {
		attribute manuscriptID : ManuscriptIdentifier;
		attribute title : ScalarValues::String;
		attribute abstractText : ScalarValues::String;
		attribute keywords : ScalarValues::String[1..*];
		attribute authors : ScalarValues::String[1..*];
		attribute affiliations : ScalarValues::String[1..*];
		attribute submissionDate : ScalarValues::String;
		attribute status : ManuscriptStatus;
		attribute technicalArea : ScalarValues::String;
		attribute pageCount : ScalarValues::Integer;
		attribute wordCount : ScalarValues::Integer;
	}
	
	item def ReviewReport {
		attribute reviewerID : ReviewerIdentifier;
		attribute manuscriptID : ManuscriptIdentifier;
		attribute technicalQuality : ScalarValues::Real;
		attribute novelty : ScalarValues::Real;
		attribute clarity : ScalarValues::Real;
		attribute overallScore : ScalarValues::Real;
		attribute recommendation : ReviewDecision;
		attribute confidentialComments : ScalarValues::String;
		attribute authorComments : ScalarValues::String;
		attribute reviewDate : ScalarValues::String;
	}
	
	item def EditorialDecision {
		attribute manuscriptID : ManuscriptIdentifier;
		attribute decision : ReviewDecision;
		attribute editorComments : ScalarValues::String;
		attribute decisionDate : ScalarValues::String;
		attribute requiresRevision : ScalarValues::Boolean;
	}
	
	item def PublishedArticle {
		attribute manuscriptID : ManuscriptIdentifier;
		attribute doi : DOI;
		attribute volumeNumber : ScalarValues::Integer;
		attribute issueNumber : ScalarValues::Integer;
		attribute pageRange : ScalarValues::String;
		attribute publicationDate : ScalarValues::String;
		attribute openAccess : ScalarValues::Boolean;
	}
	
	port def SubmissionInterfacePort {
		in item manuscriptSubmission : Manuscript;
		out item submissionAcknowledgement : ScalarValues::String;
	}
	
	port def ReviewInterfacePort {
		in item reviewAssignment : Manuscript;
		out item reviewReport : ReviewReport;
	}
	
	port def EditorialInterfacePort {
		in item reviewReports : ReviewReport;
		out item editorialDecision : EditorialDecision;
	}
	
	port def ProductionInterfacePort {
		in item acceptedManuscript : Manuscript;
		out item publishedArticle : PublishedArticle;
	}
	
	part def Author {
		attribute name : ScalarValues::String;
		attribute email : ScalarValues::String;
		attribute institution : ScalarValues::String;
		attribute orcid : ScalarValues::String;
		port submissionPort : SubmissionInterfacePort;
		event occurrence manuscriptSubmitted;
		event occurrence revisionSubmitted;
	}
	
	part def Reviewer {
		attribute name : ScalarValues::String;
		attribute expertise : ScalarValues::String[1..*];
		attribute reviewsCompleted : ScalarValues::Integer;
		attribute averageReviewTime : ScalarValues::Real;
		port reviewPort : ReviewInterfacePort;
		event occurrence reviewAssigned;
		event occurrence reviewCompleted;
	}
	
	part def AssociateEditor {
		attribute name : ScalarValues::String;
		attribute specialization : ScalarValues::String;
		attribute assignedManuscripts : ScalarValues::Integer;
		port editorialPort : EditorialInterfacePort;
		event occurrence decisionMade;
	}
	
	part def EditorInChief {
		attribute name : ScalarValues::String;
		attribute term : ScalarValues::String;
		event occurrence finalApproval;
	}
	
	part def SubmissionManagementSystem {
		attribute totalSubmissions : ScalarValues::Integer;
		attribute activeSubmissions : ScalarValues::Integer;
		port submissionInterface : SubmissionInterfacePort;
		action receiveSubmission {
			in manuscript : Manuscript;
			out acknowledgement : ScalarValues::String;
			out assignedID : ManuscriptIdentifier;
		}
	}
	
	part def ReviewManagementSystem {
		attribute activeReviews : ScalarValues::Integer;
		attribute completedReviews : ScalarValues::Integer;
		attribute averageTurnaroundTime : ScalarValues::Real;
		port reviewInterface : ReviewInterfacePort;
		action assignReviewers {
			in manuscript : Manuscript;
			out selectedReviewers : Reviewer[3..5];
		}
		action collectReviews {
			in reviews : ReviewReport[*];
			out consolidatedReviews : ReviewReport[3..5];
		}
	}
	
	part def EditorialDecisionSystem {
		attribute decisionsThisYear : ScalarValues::Integer;
		attribute acceptanceRate : ScalarValues::Real;
		port decisionInterface : EditorialInterfacePort;
		action evaluateManuscript {
			in manuscript : Manuscript;
			in reviews : ReviewReport[3..5];
			out decision : EditorialDecision;
		}
	}
	
	part def ProductionSystem {
		attribute articlesInProduction : ScalarValues::Integer;
		attribute averageProductionTime : ScalarValues::Real;
		port productionInterface : ProductionInterfacePort;
		action formatArticle {
			in manuscript : Manuscript;
			out formattedArticle : Manuscript;
		}
		action assignDOI {
			in article : Manuscript;
			out doi : DOI;
		}
		action publishOnline {
			in article : Manuscript;
			in doi : DOI;
			out publishedArticle : PublishedArticle;
		}
	}
	
	part def ArchiveSystem {
		attribute totalArticles : ScalarValues::Integer;
		attribute storageCapacity : ScalarValues::Real;
		action storeArticle {
			in article : PublishedArticle;
		}
		action retrieveArticle {
			in doi : DOI;
			out article : PublishedArticle;
		}
	}
	
	state def ManuscriptWorkflow {
		entry; then submitted;
		
		state submitted {
			entry; then do action initialScreening;
		}
		then underReview;
		
		state underReview {
			entry; then do action peerReview;
		}
		then reviewsCollected;
		
		state reviewsCollected;
		then editorialEvaluation;
		
		state editorialEvaluation {
			entry; then do action makeDecision;
		}
		then decisionRendered;
		
		state decisionRendered;
		then acceptedState;
		
		state acceptedState {
			entry; then do action scheduleProduction;
		}
		then inProduction;
		
		state inProduction {
			entry; then do action formatAndProofread;
		}
		then published;
		
		state published {
			entry; then do action archiveAndIndex;
		}
		then done;
	}
	
	action def ManagePublicationProcess {
		first start;
		then merge receiveSubmissions;
		
		action receiveManuscript {
			in newManuscript : Manuscript;
			out confirmation : ScalarValues::String;
		}
		then storeInDatabase;
		
		action storeInDatabase {
			in manuscript : Manuscript = receiveManuscript.newManuscript;
		}
		then performInitialCheck;
		
		action performInitialCheck {
			in manuscript : Manuscript = receiveManuscript.newManuscript;
			out passesCheck : ScalarValues::Boolean;
		}
		then decide;
			if performInitialCheck.passesCheck then assignEditor;
			else rejectManuscript;
		
		action assignEditor {
			in manuscript : Manuscript = receiveManuscript.newManuscript;
			out assignedEditor : AssociateEditor;
		}
		then selectReviewers;
		
		action selectReviewers {
			in manuscript : Manuscript = receiveManuscript.newManuscript;
			out reviewers : Reviewer[3..5];
		}
		then merge conductReviews;
		
		action conductReview {
			in manuscript : Manuscript = receiveManuscript.newManuscript;
			in reviewer : Reviewer;
			out report : ReviewReport;
		}
		then aggregateReviews;
		
		action aggregateReviews {
			in reports : ReviewReport[3..5];
			out consolidatedReports : ReviewReport[3..5];
		}
		then makeEditorialDecision;
		
		action makeEditorialDecision {
			in manuscript : Manuscript = receiveManuscript.newManuscript;
			in reviews : ReviewReport[3..5] = aggregateReviews.consolidatedReports;
			out decision : EditorialDecision;
		}
		then decide;
			if makeEditorialDecision.decision.decision == ReviewDecision::acceptDecision then prepareForProduction;
			else requestRevision;
		
		action requestRevision {
			in manuscript : Manuscript = receiveManuscript.newManuscript;
			in decision : EditorialDecision = makeEditorialDecision.decision;
		}
		then receiveSubmissions;
		
		action prepareForProduction {
			in manuscript : Manuscript = receiveManuscript.newManuscript;
			out productionReady : Manuscript;
		}
		then formatArticle;
		
		action formatArticle {
			in manuscript : Manuscript = prepareForProduction.productionReady;
			out formatted : Manuscript;
		}
		then assignDOI;
		
		action assignDOI {
			in manuscript : Manuscript = formatArticle.formatted;
			out doi : DOI;
		}
		then publishArticle;
		
		action publishArticle {
			in manuscript : Manuscript = formatArticle.formatted;
			in doi : DOI = assignDOI.doi;
			out article : PublishedArticle;
		}
		then archiveArticle;
		
		action archiveArticle {
			in article : PublishedArticle = publishArticle.article;
		}
		then notifyAuthors;
		
		action notifyAuthors {
			in article : PublishedArticle = publishArticle.article;
		}
		then receiveSubmissions;
		
		action rejectManuscript {
			in manuscript : Manuscript = receiveManuscript.newManuscript;
		}
		then receiveSubmissions;
	}
	
	part def JournalOfECESystem {
		doc /*
			The Journal of Electrical and Computer Engineering System is a comprehensive 
			scholarly publication platform that manages the complete lifecycle of academic 
			articles in electrical and computer engineering domains. Its primary function 
			is to facilitate rigorous peer-reviewed publication through systematic manuscript 
			submission, expert review coordination, editorial decision-making, professional 
			production, and digital dissemination of high-quality research contributions.
		*/
		
		part submissionSystem : SubmissionManagementSystem {
			attribute :>> totalSubmissions = 1247;
			attribute :>> activeSubmissions = 183;
		}
		
		part reviewSystem : ReviewManagementSystem {
			attribute :>> activeReviews = 312;
			attribute :>> completedReviews = 2891;
			attribute :>> averageTurnaroundTime = 42.5;
		}
		
		part editorialSystem : EditorialDecisionSystem {
			attribute :>> decisionsThisYear = 456;
			attribute :>> acceptanceRate = 0.28;
		}
		
		part productionSystem : ProductionSystem {
			attribute :>> articlesInProduction = 34;
			attribute :>> averageProductionTime = 21.3;
		}
		
		part archiveSystem : ArchiveSystem {
			attribute :>> totalArticles = 3847;
			attribute :>> storageCapacity = 50000.0;
		}
		
		part editorInChief : EditorInChief {
			attribute :>> name = "Dr. Jennifer Martinez";
			attribute :>> term = "2023-2026";
		}
		
		part associateEditors : AssociateEditor[8];
		
		part reviewerPool : Reviewer[450];
		
		perform action journalOperations : ManagePublicationProcess;
		
		connection submissionToReview connect 
			submissionSystem.submissionInterface to reviewSystem.reviewInterface;
		
		connection reviewToEditorial connect 
			reviewSystem.reviewInterface to editorialSystem.decisionInterface;
		
		connection editorialToProduction connect 
			editorialSystem.decisionInterface to productionSystem.productionInterface;
	}
	
	part journalSystem : JournalOfECESystem;
	
	requirement def PeerReviewQuality {
		doc /* All manuscripts must undergo rigorous peer review by at least three qualified experts. */
	}
	
	requirement def PublicationTimeliness {
		doc /* Average time from submission to publication decision shall not exceed 90 days. */
	}
	
	requirement def EditorialIndependence {
		doc /* Editorial decisions must be based solely on scientific merit and peer review outcomes. */
	}
	
	requirement def OpenAccessCompliance {
		doc /* The journal shall support open access publication options for all accepted articles. */
	}
	
	requirement def ArchivalIntegrity {
		doc /* All published articles must be permanently archived with persistent identifiers. */
	}
	
	requirement journalMissionRequirement {
		doc /* 
			The Journal of Electrical and Computer Engineering shall advance knowledge 
			in electrical and computer engineering through timely, high-quality, and 
			accessible publication of peer-reviewed research while maintaining the 
			highest standards of editorial integrity and scientific rigor.
		*/
		require peerReviewQuality : PeerReviewQuality;
		require publicationTimeliness : PublicationTimeliness;
		require editorialIndependence : EditorialIndependence;
		require openAccessCompliance : OpenAccessCompliance;
		require archivalIntegrity : ArchivalIntegrity;
	}
	
	occurrence def JournalPublicationInteraction {
		ref part author : Author;
		ref part system : JournalOfECESystem;
		
		message manuscriptSubmission of Manuscript
			from author.manuscriptSubmitted to system.submissionSystem.submissionInterface;
		
		then message reviewAssignments of Manuscript
			from system.submissionSystem.submissionInterface to system.reviewSystem.reviewInterface;
		
		then message reviewReports of ReviewReport
			from system.reviewSystem.reviewInterface to system.editorialSystem.decisionInterface;
		
		then message editorialDecision of EditorialDecision
			from system.editorialSystem.decisionInterface to system.productionSystem.productionInterface;
		
		then message publishedArticle of PublishedArticle
			from system.productionSystem.productionInterface to system.archiveSystem;
	}
}
