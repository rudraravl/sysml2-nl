package 'Journal of Electrical and Computer Engineering' {
	private import ScalarValues::*;
	private import Definitions::*;

	package Definitions {
		item def Manuscript {
			attribute manuscriptId : String;
			attribute title : String;
			attribute abstractText : String;
			attribute submissionDate : String;
		}

		item def Review {
			attribute reviewId : String;
			attribute reviewerId : String;
			attribute technicalQuality : Integer;
			attribute novelty : Integer;
			attribute clarity : Integer;
			attribute comments : String;
		}

		enum def DecisionType {
			Accept;
			Reject;
			Revise;
		}

		item def EditorialDecision {
			attribute decisionId : String;
			attribute recommendation : DecisionType;
			attribute associateEditorId : String;
			attribute editorInChiefId : String;
			attribute eicApproval : Boolean;
			attribute decisionDate : String;
		}

		item def PublishedArticle :> Manuscript {
			attribute doi : String;
			attribute volume : Integer;
			attribute issue : Integer;
			attribute startPage : Integer;
			attribute endPage : Integer;
			attribute publicationDate : String;
		}

		port def ManuscriptOutPort {
			out item manuscript : Manuscript;
		}

		port def ManuscriptInPort {
			in item manuscript : Manuscript;
		}

		port def ReviewOutPort {
			out item reviews : Review[3..5];
		}

		port def ReviewInPort {
			in item reviews : Review[3..5];
		}

		port def DecisionOutPort {
			out item decision : EditorialDecision;
		}

		port def DecisionInPort {
			in item decision : EditorialDecision;
		}

		port def ArticleOutPort {
			out item article : PublishedArticle;
		}

		port def ArticleInPort {
			in item article : PublishedArticle;
		}

		action def SubmitManuscriptAction {
			in item manuscript : Manuscript;
			out item manuscript : Manuscript;
		}

		action def ConductReviewAction {
			in item manuscript : Manuscript;
			out item manuscript : Manuscript;
			out item reviews : Review[3..5];
		}

		action def MakeDecisionAction {
			in item manuscript : Manuscript;
			in item reviews : Review[3..5];
			out item decision : EditorialDecision;
			out item manuscript : Manuscript;
		}

		action def ProduceArticleAction {
			in item manuscript : Manuscript;
			in item decision : EditorialDecision;
			out item article : PublishedArticle;
		}

		action def ArchiveArticleAction {
			in item article : PublishedArticle;
		}

		part def SubmissionManagementSystem {
			port manuscriptIn : ManuscriptInPort;
			port manuscriptOut : ManuscriptOutPort;
			perform action submitManuscript : SubmitManuscriptAction {
				in item manuscript : Manuscript = manuscriptIn.manuscript;
				out item manuscript : Manuscript = manuscriptOut.manuscript;
			}
		}

		part def ReviewManagementSystem {
			port manuscriptIn : ManuscriptInPort;
			port manuscriptOut : ManuscriptOutPort;
			port reviewsOut : ReviewOutPort;
			perform action conductReview : ConductReviewAction {
				in item manuscript : Manuscript = manuscriptIn.manuscript;
				out item manuscript : Manuscript = manuscriptOut.manuscript;
				out item reviews : Review[3..5] = reviewsOut.reviews;
				action selectReviewers {
					out selectedReviewerIds : String[3..5];
				}
				action collectReviews {
					in selectedReviewerIds : String[3..5];
					out collectedReviews : Review[3..5];
				}
				flow selectReviewers.selectedReviewerIds to collectReviews.selectedReviewerIds;
				flow from collectReviews.collectedReviews to reviews;
			}
		}

		part def EditorialDecisionSystem {
			port manuscriptIn : ManuscriptInPort;
			port reviewsIn : ReviewInPort;
			port decisionOut : DecisionOutPort;
			port manuscriptOut : ManuscriptOutPort;
			perform action makeDecision : MakeDecisionAction {
				in item manuscript : Manuscript = manuscriptIn.manuscript;
				in item reviews : Review[3..5] = reviewsIn.reviews;
				out item decision : EditorialDecision = decisionOut.decision;
				out item manuscript : Manuscript = manuscriptOut.manuscript;
				action associateEditorEvaluates {
					in inputReviews : Review[3..5];
					out recommendation : DecisionType;
				}
				action editorInChiefApproves {
					in inputRecommendation : DecisionType;
					out approved : Boolean;
				}
				flow from reviews to associateEditorEvaluates.inputReviews;
				flow associateEditorEvaluates.recommendation to editorInChiefApproves.inputRecommendation;
			}
		}

		part def ProductionSystem {
			port manuscriptIn : ManuscriptInPort;
			port decisionIn : DecisionInPort;
			port articleOut : ArticleOutPort;
			perform action produceArticle : ProduceArticleAction {
				in item manuscript : Manuscript = manuscriptIn.manuscript;
				in item decision : EditorialDecision = decisionIn.decision;
				out item article : PublishedArticle = articleOut.article;
				action typeset {
					out typesetVersion : Manuscript;
				}
				action proofread {
					in typesetVersion : Manuscript;
					out proofreadVersion : Manuscript;
				}
				action assignDOI {
					out doi : String;
				}
				flow typeset.typesetVersion to proofread.typesetVersion;
			}
		}

		part def ArchiveSystem {
			port articleIn : ArticleInPort;
			perform action archiveArticle : ArchiveArticleAction {
				in item article : PublishedArticle = articleIn.article;
			}
		}

		state def ManuscriptLifecycle {
			state submitted;
			state underReview;
			state accepted;
			state inProduction;
			state published;
			state rejected;
			transition submittedToUnderReview first submitted then underReview;
			transition underReviewToAccepted first underReview then accepted;
			transition underReviewToRejected first underReview then rejected;
			transition underReviewToRevise first underReview then underReview;
			transition acceptedToInProduction first accepted then inProduction;
			transition inProductionToPublished first inProduction then published;
		}

		requirement def PeerReviewQualityRequirement {
			doc /* The peer-review process must be rigorous, with at least three and at most five qualified reviewers assessing each manuscript. */
			attribute minReviewers : Integer = 3;
			attribute maxReviewers : Integer = 5;
		}

		requirement def TimelyPublicationRequirement {
			doc /* The time from submission to publication must be minimized and bounded. */
			attribute maxDurationDays : Integer = 180;
		}

		requirement def EditorialIndependenceRequirement {
			doc /* Editorial decisions must be made free from external influence, with Editor-in-Chief approval for major decisions. */
		}

		requirement def PermanentArchivalRequirement {
			doc /* Published articles must be permanently archived and securely accessible. */
			attribute isPermanent : Boolean = true;
		}

		requirement def DOIAssignmentRequirement {
			doc /* Each published article must receive a permanent Digital Object Identifier. */
		}
	}

	package Usages {
		private import Definitions::*;

		part journalSystem {
			requirement peerReviewQuality : PeerReviewQualityRequirement;
			requirement timelyPublication : TimelyPublicationRequirement;
			requirement editorialIndependence : EditorialIndependenceRequirement;
			requirement permanentArchival : PermanentArchivalRequirement;
			requirement doiAssignment : DOIAssignmentRequirement;

			part submissionManagement : SubmissionManagementSystem;
			part reviewManagement : ReviewManagementSystem;
			part editorialDecision : EditorialDecisionSystem;
			part production : ProductionSystem;
			part archive : ArchiveSystem;

			flow of manuscript : Manuscript
				from submissionManagement.manuscriptOut.manuscript to reviewManagement.manuscriptIn.manuscript;
			flow of manuscript : Manuscript
				from reviewManagement.manuscriptOut.manuscript to editorialDecision.manuscriptIn.manuscript;
			flow of reviews : Review[3..5]
				from reviewManagement.reviewsOut.reviews to editorialDecision.reviewsIn.reviews;
			flow of decision : EditorialDecision
				from editorialDecision.decisionOut.decision to production.decisionIn.decision;
			flow of manuscript : Manuscript
				from editorialDecision.manuscriptOut.manuscript to production.manuscriptIn.manuscript;
			flow of article : PublishedArticle
				from production.articleOut.article to archive.articleIn.article;

			exhibit ManuscriptLifecycle;

			satisfy peerReviewQuality by reviewManagement;
			satisfy timelyPublication by journalSystem;
			satisfy editorialIndependence by editorialDecision;
			satisfy permanentArchival by archive;
			satisfy doiAssignment by production;
		}
	}
}
