package MedicalEncyclopediaSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value type ConfidenceScore {
        :>> unit = "percent";
        attribute value : Real;
    }

    value type ReadingLevel {
        :>> unit = "grade";
        attribute value : Integer;
    }

    value type RelevanceScore {
        :>> unit = "score";
        attribute value : Real;
    }

    value type ReviewDuration {
        :>> unit = "day";
        attribute value : Real;
    }

    // ===== Item Definitions =====
    item def MedicalArticle {
        attribute id : String;
        attribute title : String;
        attribute bodyText : String;
        attribute references : String[0..*];
        attribute illustrations : String[0..*];
        attribute relatedLinks : String[0..*];
        attribute category : String;
        attribute lastReviewedDate : Date;
        attribute confidenceScore : ConfidenceScore;
        attribute readingLevel : ReadingLevel;
    }

    item def ArticleMetadata {
        attribute title : String;
        attribute category : String;
        attribute lastReviewedDate : Date;
        attribute confidenceScore : ConfidenceScore;
        attribute readingLevel : ReadingLevel;
    }

    item def SearchQuery {
        attribute terms : String;
        attribute categoryFilter : String[0..*];
    }

    item def RankedResult {
        attribute articleId : String;
        attribute title : String;
        attribute snippet : String;
        attribute relevance : RelevanceScore;
    }

    item def ArticleSubmission {
        attribute article : MedicalArticle;
        attribute submitter : String;
        attribute submissionDate : Date;
    }

    item def ReviewDecision {
        attribute articleId : String;
        attribute approved : Boolean;
        attribute reviewer : String;
        attribute comments : String;
        attribute reviewDuration : ReviewDuration;
    }

    // ===== Port Definitions =====
    port def QueryPort {
        out query : SearchQuery;
    }

    port def ResultPort {
        in results : RankedResult[0..*];
    }

    port def ArticleRequestPort {
        out articleId : String;
    }

    port def ArticleResponsePort {
        in article : MedicalArticle;
    }

    port def DBQueryPort {
        in query : SearchQuery;
        out candidateArticles : MedicalArticle[0..*];
    }

    port def ReviewSubmissionPort {
        out submission : ArticleSubmission;
    }

    port def ReviewDecisionPort {
        in decision : ReviewDecision;
    }

    port def PublishPort {
        out article : MedicalArticle;
    }

    // ===== Parts =====
    part def ContentDatabase {
        port dbQuery : DBQueryPort;
        port publish : PublishPort;

        attribute articles : MedicalArticle[0..*];

        state def DatabaseLifecycle {
            state Operational;
            state Maintenance;
            transition Operational -> Maintenance;
            transition Maintenance -> Operational;
        }

        action def RetrieveArticles {
            in query : SearchQuery;
            out candidates : MedicalArticle[0..*];
        }

        action def StoreArticle {
            in article : MedicalArticle;
        }

        exhibit state DatabaseLifecycle;

        perform RetrieveArticles;
        perform StoreArticle;
    }

    part def UserInterfaceModule {
        port queryOut : QueryPort;
        port resultIn : ResultPort;
        port articleReq : ArticleRequestPort;
        port articleResp : ArticleResponsePort;

        attribute currentResults : RankedResult[0..*];
        attribute displayedArticle : MedicalArticle;

        state def UIState {
            state Idle;
            state AwaitingResults;
            state DisplayingResults;
            state AwaitingArticle;
            state DisplayingArticle;
            transition Idle -> AwaitingResults when queryOut.query.sent;
            transition AwaitingResults -> DisplayingResults when resultIn.results.received;
            transition DisplayingResults -> AwaitingArticle when articleReq.articleId.sent;
            transition AwaitingArticle -> DisplayingArticle when articleResp.article.received;
            transition DisplayingArticle -> Idle;
        }

        action def AcceptUserQuery {
            out query : SearchQuery;
        }

        action def DisplayResults {
            in results : RankedResult[0..*];
        }

        action def RequestArticle {
            out articleId : String;
        }

        action def DisplayArticle {
            in article : MedicalArticle;
        }

        exhibit state UIState;
        perform AcceptUserQuery;
        perform DisplayResults;
        perform RequestArticle;
        perform DisplayArticle;
    }

    part def SearchModule {
        port queryIn : QueryPort;
        port dbQuery : DBQueryPort;
        port resultOut : ResultPort;

        attribute rankedResults : RankedResult[0..*];

        action def ProcessQuery {
            in query : SearchQuery;
            out processedTerms : String[0..*];
        }

        action def RankResults {
            in candidates : MedicalArticle[0..*];
            in query : SearchQuery;
            out ranked : RankedResult[0..*];
        }

        perform ProcessQuery;
        perform RankResults;
    }

    part def ContentReviewModule {
        port submissionIn : ReviewSubmissionPort;
        port decisionOut : ReviewDecisionPort;
        port publishOut : PublishPort;

        attribute pendingSubmissions : ArticleSubmission[0..*];
        attribute reviewQueue : ArticleSubmission[0..*];

        state def ReviewWorkflow {
            state AwaitingSubmission;
            state UnderReview;
            state Approved;
            state Rejected;
            transition AwaitingSubmission -> UnderReview when submissionIn.submission.received;
            transition UnderReview -> Approved when decisionOut.decision.approved == true;
            transition UnderReview -> Rejected when decisionOut.decision.approved == false;
            transition Approved -> AwaitingSubmission;
            transition Rejected -> AwaitingSubmission;
        }

        action def ValidateMedicalAccuracy {
            in article : MedicalArticle;
            out isValid : Boolean;
        }

        action def AssignReviewer {
            in submission : ArticleSubmission;
            out reviewer : String;
        }

        action def PublishArticle {
            in article : MedicalArticle;
        }

        exhibit state ReviewWorkflow;
        perform ValidateMedicalAccuracy;
        perform AssignReviewer;
        perform PublishArticle;
    }

    // ===== System =====
    part def MedicalEncyclopedia {
        part ui : UserInterfaceModule;
        part search : SearchModule;
        part database : ContentDatabase;
        part review : ContentReviewModule;

        connection ui.queryOut to search.queryIn;
        connection search.dbQuery to database.dbQuery;
        connection search.resultOut to ui.resultIn;
        connection ui.articleReq to database.dbQuery;
        connection database.publish to ui.articleResp;
        connection review.publishOut to database.publish;
    }

    // ===== Requirements =====
    requirement def ProvideAccurateMedicalInfo {
        doc "The system shall provide users with accurate, evidence-based medical information."
    }

    requirement def SupportSearchFunctionality {
        doc "The system shall allow users to search medical articles by terms and category filters."
    }

    requirement def RankSearchResults {
        doc "The Search Module shall rank search results by relevance before returning them to the UI."
    }

    requirement def DisplayFullArticle {
        doc "The UI shall display the full formatted medical article upon user selection."
    }

    requirement def EnforceContentReview {
        doc "All new or updated articles shall be validated by the Content Review Module before publication."
    }

    requirement def MaintainArticleMetadata {
        doc "Each article shall include metadata: title, category, last reviewed date, confidence score, and reading level."
    }

    requirement def EnsureContentQuality {
        doc "The Content Review Module shall validate medical accuracy and only publish approved articles."
    }

    requirement MedicalEncyclopediaAccuracy : ProvideAccurateMedicalInfo;
    requirement MedicalEncyclopediaSearch : SupportSearchFunctionality;
    requirement MedicalEncyclopediaRanking : RankSearchResults;
    requirement MedicalEncyclopediaDisplay : DisplayFullArticle;
    requirement MedicalEncyclopediaReview : EnforceContentReview;
    requirement MedicalEncyclopediaMetadata : MaintainArticleMetadata;
    requirement MedicalEncyclopediaQuality : EnsureContentQuality;

    satisfy MedicalEncyclopediaSearch by MedicalEncyclopedia::ui::AcceptUserQuery;
    satisfy MedicalEncyclopediaRanking by MedicalEncyclopedia::search::RankResults;
    satisfy MedicalEncyclopediaDisplay by MedicalEncyclopedia::ui::DisplayArticle;
    satisfy MedicalEncyclopediaReview by MedicalEncyclopedia::review::ReviewWorkflow;
    satisfy MedicalEncyclopediaMetadata by MedicalEncyclopedia::database::articles;
    satisfy MedicalEncyclopediaQuality by MedicalEncyclopedia::review::ValidateMedicalAccuracy;
}
