package JournalSystemModel {

    package Definitions {
        import ScalarValues::*;
        import ISQ::*;

        item def Manuscript {
            attribute manuscriptId : String;
            attribute title : String;
            attribute abstractText : String;
            attribute submissionDate : Date;
            attribute authorNames : String[1..*];
            attribute keywords : String[0..*];
            attribute status : ManuscriptStatus::Submitted default ManuscriptStatus::Submitted;
        }

        item def Review {
            attribute reviewId : String;
            attribute reviewerId : String;
            attribute technicalQualityScore : Integer(0..10);
            attribute noveltyScore : Integer(0..10);
            attribute clarityScore : Integer(0..10);
            attribute comments : String;
            attribute recommendation : ReviewRecommendation;
            attribute completedDate : Date;
        }

        item def EditorialDecision {
            attribute decisionId : String;
            attribute decisionType : DecisionType;
            attribute associateEditorId : String;
            attribute editorInChiefId : String;
            attribute decisionDate : Date;
            attribute rationale : String;
        }

        item def PublishedArticle {
            attribute doi : String;
            attribute volume : Integer;
            attribute issue : Integer;
            attribute startPage : Integer;
            attribute endPage : Integer;
            attribute publicationDate : Date;
            attribute typesetContent : String;
            attribute proofread : Boolean default false;
        }

        item def ReviewerProfile {
            attribute reviewerId : String;
            attribute expertiseKeywords : String[1..*];
            attribute available : Boolean default true;
            attribute completedReviews : Integer default 0;
        }

        enum def ManuscriptStatus {
            Submitted;
            UnderReview;
            Accepted;
            Rejected;
            RevisionRequested;
            InProduction;
            Published;
            Archived;
        }

        enum def DecisionType {
            Accept;
            Reject;
            MajorRevision;
            MinorRevision;
        }

        enum def ReviewRecommendation {
            StrongAccept;
            Accept;
            WeakAccept;
            Borderline;
            WeakReject;
            Reject;
        }

        value def ReviewDuration :> Real;
        unit def days :> DurationUnit;
        value def MaxReviewDurationDays : ReviewDuration = 30 [days];
        value def MinReviewers : Integer = 3;
        value def MaxReviewers : Integer = 5;
    }

    package Ports {
        import Definitions::*;
        port def ManuscriptPort {
            in item manuscript : Manuscript;
        }
        port def ReviewPort {
            in item reviews : Review[0..*];
        }
        port def DecisionPort {
            in item decision : EditorialDecision;
        }
        port def ArticlePort {
            in item article : PublishedArticle;
        }
        port def ManuscriptOutPort {
            out item manuscript : Manuscript;
        }
        port def ReviewOutPort {
            out item reviews : Review[0..*];
        }
        port def DecisionOutPort {
            out item decision : EditorialDecision;
        }
        port def ArticleOutPort {
            out item article : PublishedArticle;
        }
    }

    package Subsystems {
        import Definitions::*;
        import Ports::*;

        part def SubmissionManagementSystem {
            port manuscriptOut : ManuscriptOutPort;
            port submissionFeedback : ManuscriptPort;

            attribute submissionsReceived : Integer default 0;

            action def ReceiveSubmission {
                in item newManuscript : Manuscript;
                out item processedManuscript : Manuscript;
            }

            perform action receiveSubmission : ReceiveSubmission {
                in item newManuscript = self.submissionFeedback.manuscript;
                out item processedManuscript = self.manuscriptOut.manuscript;
            }
        }

        part def ReviewManagementSystem {
            port manuscriptIn : ManuscriptPort;
            port reviewsOut : ReviewOutPort;
            port reviewerPool : ReviewerProfile[1..*];

            attribute assignedReviewers : ReviewerProfile[0..*];
            attribute collectedReviews : Review[0..*];

            action def AssignReviewers {
                in item manuscript : Manuscript;
                in item pool : ReviewerProfile[1..*];
                out item selectedReviewers : ReviewerProfile[3..5];
            }

            action def CollectReviews {
                in item manuscript : Manuscript;
                in item reviewers : ReviewerProfile[3..5];
                out item reviews : Review[3..5];
            }

            perform action assignReviewers : AssignReviewers {
                in item manuscript = self.manuscriptIn.manuscript;
                in item pool = self.reviewerPool;
                out item selectedReviewers = self.assignedReviewers;
            }

            perform action collectReviews : CollectReviews {
                in item manuscript = self.manuscriptIn.manuscript;
                in item reviewers = self.assignedReviewers;
                out item reviews = self.reviewsOut.reviews;
            }
        }

        part def EditorialDecisionSystem {
            port manuscriptIn : ManuscriptPort;
            port reviewsIn : ReviewPort;
            port decisionOut : DecisionOutPort;

            attribute associateEditorId : String;
            attribute editorInChiefId : String;

            action def EvaluateReviews {
                in item manuscript : Manuscript;
                in item reviews : Review[1..*];
                out item recommendation : DecisionType;
            }

            action def FinalApproval {
                in item recommendation : DecisionType;
                out item finalDecision : EditorialDecision;
            }

            perform action evaluateReviews : EvaluateReviews {
                in item manuscript = self.manuscriptIn.manuscript;
                in item reviews = self.reviewsIn.reviews;
                out item recommendation;
            }

            perform action finalApproval : FinalApproval {
                in item recommendation = evaluateReviews.recommendation;
                out item finalDecision = self.decisionOut.decision;
            }
        }

        part def ProductionSystem {
            port manuscriptIn : ManuscriptPort;
            port decisionIn : DecisionPort;
            port articleOut : ArticleOutPort;

            attribute assignedDoi : String;
            attribute volume : Integer;
            attribute issue : Integer;
            attribute startPage : Integer;

            action def Typeset {
                in item manuscript : Manuscript;
                out item typesetContent : String;
            }

            action def Proofread {
                in item typesetContent : String;
                out item proofreadContent : String;
            }

            action def AssignDOI {
                in item manuscript : Manuscript;
                out item doi : String;
            }

            action def AssignPublicationDetails {
                in item doi : String;
                in item proofreadContent : String;
                out item article : PublishedArticle;
            }

            perform action typeset : Typeset {
                in item manuscript = self.manuscriptIn.manuscript;
                out item typesetContent;
            }

            perform action proofread : Proofread {
                in item typesetContent = typeset.typesetContent;
                out item proofreadContent;
            }

            perform action assignDOI : AssignDOI {
                in item manuscript = self.manuscriptIn.manuscript;
                out item doi;
            }

            perform action assignDetails : AssignPublicationDetails {
                in item doi = assignDOI.doi;
                in item proofreadContent = proofread.proofreadContent;
                out item article = self.articleOut.article;
            }
        }

        part def ArchiveSystem {
            port articleIn : ArticlePort;

            attribute archivedArticles : PublishedArticle[0..*];
            attribute archiveSize : Integer default 0;

            action def ArchiveArticle {
                in item article : PublishedArticle;
                out item archivedArticle : PublishedArticle;
            }

            perform action archiveArticle : ArchiveArticle {
                in item article = self.articleIn.article;
                out item archivedArticle;
            }
        }
    }

    package System {
        import Definitions::*;
        import Ports::*;
        import Subsystems::*;

        part JournalOperationalSystem {
            part submissionSystem : SubmissionManagementSystem;
            part reviewSystem : ReviewManagementSystem;
            part editorialSystem : EditorialDecisionSystem;
            part productionSystem : ProductionSystem;
            part archiveSystem : ArchiveSystem;

            connection submissionToReview connect submissionSystem.manuscriptOut to reviewSystem.manuscriptIn;
            connection reviewToEditorial connect reviewSystem.reviewsOut to editorialSystem.reviewsIn;
            connection editorialToProduction connect editorialSystem.decisionOut to productionSystem.decisionIn;
            connection productionToArchive connect productionSystem.articleOut to archiveSystem.articleIn;

            connection manuscriptToEditorial connect submissionSystem.manuscriptOut to editorialSystem.manuscriptIn;
        }
    }

    package Behaviors {
        import Definitions::*;

        state def ManuscriptLifecycle {
            entry; then Submitted;

            state Submitted {
                entry action {
                    /* Manuscript received from author */
                }
                transition on submitToReview first Submitted then UnderReview;
            }

            state UnderReview {
                entry action {
                    /* Reviewers assigned and reviews collected */
                }
                transition on reviewsComplete first UnderReview then DecisionPending;
            }

            state DecisionPending {
                transition on accept first DecisionPending then Accepted;
                transition on reject first DecisionPending then Rejected;
                transition on revision first DecisionPending then RevisionRequested;
            }

            state RevisionRequested {
                transition on resubmit first RevisionRequested then UnderReview;
            }

            state Accepted {
                transition on sendToProduction first Accepted then InProduction;
            }

            state InProduction {
                entry action {
                    /* Typesetting, proofreading, DOI assignment */
                }
                transition on productionComplete first InProduction then Published;
            }

            state Published {
                transition on archive first Published then Archived;
            }

            state Rejected {
                /* Terminal state */
            }

            state Archived {
                /* Terminal state - permanent storage */
            }
        }
    }

    package Requirements {
        import Definitions::*;

        requirement def PeerReviewQualityRequirement {
            doc /* The system shall ensure rigorous peer-review quality by assigning a minimum of 3 and maximum of 5 qualified reviewers per manuscript. */
            attribute minReviewers : Integer = MinReviewers;
            attribute maxReviewers : Integer = MaxReviewers;
            satisfy by ReviewManagementSystem;
        }

        requirement def TimelyPublicationRequirement {
            doc /* The system shall complete the review process within 30 days of submission. */
            attribute maxDurationDays : ReviewDuration = MaxReviewDurationDays;
            satisfy by ReviewManagementSystem;
        }

        requirement def EditorialIndependenceRequirement {
            doc /* The editorial decision system shall operate independently, with an Associate Editor making recommendations and an Editor-in-Chief providing final approval for major decisions. */
            satisfy by EditorialDecisionSystem;
        }

        requirement def PermanentArchivalRequirement {
            doc /* All published articles shall be permanently stored and made accessible through the digital archive system. */
            satisfy by ArchiveSystem;
        }

        requirement def DOIAssignmentRequirement {
            doc /* Every accepted manuscript shall be assigned a permanent Digital Object Identifier (DOI) before publication. */
            satisfy by ProductionSystem;
        }

        requirement def WorkflowCompletenessRequirement {
            doc /* The system shall manage the complete manuscript lifecycle from submission through archival, tracking states including submitted, under review, accepted, in production, and published. */
            satisfy by JournalOperationalSystem;
        }

        requirement package JournalRequirements {
            requirement peerReviewQuality : PeerReviewQualityRequirement;
            requirement timelyPublication : TimelyPublicationRequirement;
            requirement editorialIndependence : EditorialIndependenceRequirement;
            requirement permanentArchival : PermanentArchivalRequirement;
            requirement doiAssignment : DOIAssignmentRequirement;
            requirement workflowCompleteness : WorkflowCompletenessRequirement;
        }
    }

    package Instances {
        import System::*;
        import Definitions::*;

        part journalSystemInstance : JournalOperationalSystem {
            part submissionSystem {
                attribute submissionsReceived : Integer = 0;
            }
            part reviewSystem {
                attribute reviewerPool : ReviewerProfile[1..*] = (
                    ReviewerProfile { reviewerId = "R001"; expertiseKeywords = ("signal processing", "communications"); },
                    ReviewerProfile { reviewerId = "R002"; expertiseKeywords = ("VLSI", "circuit design"); },
                    ReviewerProfile { reviewerId = "R003"; expertiseKeywords = ("power systems", "control"); },
                    ReviewerProfile { reviewerId = "R004"; expertiseKeywords = ("machine learning", "AI"); },
                    ReviewerProfile { reviewerId = "R005"; expertiseKeywords = ("embedded systems", "IoT"); },
                    ReviewerProfile { reviewerId = "R006"; expertiseKeywords = ("optics", "photonics"); },
                    ReviewerProfile { reviewerId = "R007"; expertiseKeywords = ("antennas", "RF"); },
                    ReviewerProfile { reviewerId = "R008"; expertiseKeywords = ("image processing", "computer vision"); }
                );
            }
            part editorialSystem {
                attribute associateEditorId : String = "AE001";
                attribute editorInChiefId : String = "EIC001";
            }
            part productionSystem {
                attribute volume : Integer = 42;
                attribute issue : Integer = 1;
                attribute startPage : Integer = 1;
            }
            part archiveSystem {
                attribute archiveSize : Integer = 0;
            }
        }
    }
}
