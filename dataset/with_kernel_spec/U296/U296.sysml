package MedicalEncyclopediaSystem {
	private import ScalarValues::*;
	private import SequenceFunctions::size;
	private import ControlFunctions::forAll;
	private import ControlFunctions::collect;
	private import ControlFunctions::select;

	doc
	/*
	 * Digital Medical Encyclopedia System providing searchable, evidence-based medical information.
	 * Composed of Content Database, User Interface Module, Search Module, and Content Review Module.
	 */

	attribute def DateStr :> String;
	attribute def MedicalAccuracyScore :> Real;
	attribute def RelevanceScore :> Real;

	attribute def ArticleMetadata {
		attribute title : String;
		attribute category : String;
		attribute lastReviewedDate : DateStr;
		attribute accuracyConfidence : MedicalAccuracyScore;
		attribute readingLevel : String;
	}

	item def MedicalArticle {
		attribute id : String;
		attribute mainText : String;
		attribute citations : String[0..*];
		attribute illustrations : String[0..*];
		attribute relatedTopics : String[0..*];
		attribute articleMetadata : ArticleMetadata;
	}

	item def SearchQuery {
		attribute terms : String;
		attribute categoryFilter : String;
	}

	item def RankedSearchResult {
		attribute article : MedicalArticle;
		attribute relevanceScore : RelevanceScore;
	}

	item def QueryMessage {
		attribute query : SearchQuery;
	}

	item def ResultsMessage {
		attribute results : RankedSearchResult[0..*] ordered;
	}

	item def DBSearchMessage {
		attribute terms : String;
		attribute categoryFilter : String;
	}

	item def DBResultsMessage {
		attribute articles : MedicalArticle[0..*] ordered;
	}

	item def ArticleRequestMessage {
		attribute articleId : String;
	}

	item def ArticleResponseMessage {
		attribute article : MedicalArticle;
	}

	item def SubmitReviewMessage {
		attribute article : MedicalArticle;
	}

	item def PublishMessage {
		attribute article : MedicalArticle;
	}

	item def RejectMessage {
		attribute articleId : String;
		attribute reason : String;
	}

	port def UserInputPort;
	port def QueryPort;
	port def ResultPort;
	port def DBSearchPort;
	port def DBResultPort;
	port def ArticleReqPort;
	port def ArticleRespPort;
	port def SubmissionPort;
	port def PublishPort;
	port def RejectPort;

	calc def ComputeRelevance {
		in article : MedicalArticle;
		in terms : String;
		return : RelevanceScore = article.articleMetadata.title == terms ? 0.9 : 0.5;
	}

	calc def RankResults {
		in articles : MedicalArticle[0..*];
		in query : SearchQuery;
		return : RankedSearchResult[0..*] =
			articles->collect { in a;
				new RankedSearchResult(a, ComputeRelevance(a, query.terms))
			};
	}

	calc def ValidateMedicalAccuracy {
		in article : MedicalArticle;
		return : Boolean =
			article.articleMetadata.accuracyConfidence >= 0.8 and
			size(article.citations) >= 3;
	}

	calc def FindArticles {
		in articles : MedicalArticle[0..*];
		in searchTerms : String;
		in categoryFilter : String;
		return : MedicalArticle[0..*] =
			articles->select { in a;
				(categoryFilter == "" or a.articleMetadata.category == categoryFilter)
			};
	}

	calc def FindArticleById {
		in articles : MedicalArticle[0..*];
		in id : String;
		return : MedicalArticle =
			(articles->select { in a; a.id == id })#(1);
	}

	part def ContentDatabase {
		port dbSearchIn : DBSearchPort;
		port dbSearchOut : ~DBResultPort;
		port dbArticleIn : ArticleReqPort;
		port dbArticleOut : ~ArticleRespPort;
		port dbPublishIn : PublishPort;

		attribute articles : MedicalArticle[0..*] ordered;

		exhibit state DatabaseBehavior {
			entry; then idle;
			state idle;
			transition handleSearch
				first idle
				accept req : DBSearchMessage via dbSearchIn
				do send new DBResultsMessage(FindArticles(articles, req.terms, req.categoryFilter)) via dbSearchOut
				then idle;
			transition handleRetrieve
				first idle
				accept req : ArticleRequestMessage via dbArticleIn
				do send new ArticleResponseMessage(FindArticleById(articles, req.articleId)) via dbArticleOut
				then idle;
			transition handlePublish
				first idle
				accept pub : PublishMessage via dbPublishIn
				then idle;
		}
	}

	part def UserInterfaceModule {
		port userInput : UserInputPort;
		port uiQueryOut : ~QueryPort;
		port uiResultIn : ResultPort;
		port uiArticleReqOut : ~ArticleReqPort;
		port uiArticleRespIn : ArticleRespPort;

		exhibit state UIBehavior {
			entry; then waitForInput;
			state waitForInput;
			transition submitSearch
				first waitForInput
				accept userQuery : QueryMessage via userInput
				do send new QueryMessage(userQuery.query) via uiQueryOut
				then waitForResults;
			state waitForResults;
			transition receiveResults
				first waitForResults
				accept results : ResultsMessage via uiResultIn
				then presentResults;
			state presentResults;
			transition selectArticle
				first presentResults
				accept selection : ArticleRequestMessage via userInput
				do send new ArticleRequestMessage(selection.articleId) via uiArticleReqOut
				then waitForArticle;
			state waitForArticle;
			transition displayArticle
				first waitForArticle
				accept articleMsg : ArticleResponseMessage via uiArticleRespIn
				then showingArticle;
			state showingArticle;
			transition newSearch
				first showingArticle
				accept req : QueryMessage via userInput
				then waitForInput;
		}
	}

	part def SearchModule {
		port searchQueryIn : QueryPort;
		port searchResultOut : ~ResultPort;
		port searchDBOut : ~DBSearchPort;
		port searchDBIn : DBResultPort;

		exhibit state SearchBehavior {
			entry; then idle;
			state idle;
			transition processQuery
				first idle
				accept queryMsg : QueryMessage via searchQueryIn
				do send new DBSearchMessage(queryMsg.query.terms, queryMsg.query.categoryFilter) via searchDBOut
				then awaitingDB;
			state awaitingDB;
			transition rankAndReturn
				first awaitingDB
				accept dbResults : DBResultsMessage via searchDBIn
				do send new ResultsMessage(RankResults(dbResults.articles, processQuery.queryMsg.query)) via searchResultOut
				then idle;
		}
	}

	part def ContentReviewModule {
		port submissionIn : SubmissionPort;
		port reviewOut : ~PublishPort;
		port reviewRejectOut : ~RejectPort;

		exhibit state ReviewBehavior {
			entry; then pendingReview;
			state pendingReview;
			transition receiveSubmission
				first pendingReview
				accept submission : SubmitReviewMessage via submissionIn
				then reviewing;
			state reviewing;
			transition approve
				first reviewing
				if ValidateMedicalAccuracy(receiveSubmission.submission.article)
				do send new PublishMessage(receiveSubmission.submission.article) via reviewOut
				then pendingReview;
			transition reject
				first reviewing
				if not ValidateMedicalAccuracy(receiveSubmission.submission.article)
				do send new RejectMessage(receiveSubmission.submission.article.id, "Insufficient accuracy or references") via reviewRejectOut
				then pendingReview;
		}
	}

	part def MedicalEncyclopediaSystem {
		part contentDB : ContentDatabase;
		part ui : UserInterfaceModule;
		part search : SearchModule;
		part review : ContentReviewModule;

		interface ui.uiQueryOut to search.searchQueryIn;
		interface search.searchResultOut to ui.uiResultIn;
		interface search.searchDBOut to contentDB.dbSearchIn;
		interface contentDB.dbSearchOut to search.searchDBIn;
		interface ui.uiArticleReqOut to contentDB.dbArticleIn;
		interface contentDB.dbArticleOut to ui.uiArticleRespIn;
		interface review.reviewOut to contentDB.dbPublishIn;

		requirement medicalAccuracyReq : MedicalAccuracyRequirement;
		requirement minRefsReq : MinimumReferencesRequirement;
		requirement reviewApprovalReq : ReviewApprovalRequirement;
		requirement searchRelevanceReq : SearchRelevanceRequirement;
		requirement metadataCompletenessReq : MetadataCompletenessRequirement;
		requirement contentReviewWorkflowReq : ContentReviewWorkflowRequirement;

		satisfy medicalAccuracyReq by contentDB;
		satisfy minRefsReq by review;
		satisfy reviewApprovalReq by review;
		satisfy searchRelevanceReq by search;
		satisfy metadataCompletenessReq by contentDB;
		satisfy contentReviewWorkflowReq by contentDB;
	}

	requirement def MedicalAccuracyRequirement {
		subject article : MedicalArticle;
		constraint { article.articleMetadata.accuracyConfidence >= 0.8; }
	}

	requirement def MinimumReferencesRequirement {
		subject article : MedicalArticle;
		constraint { size(article.citations) >= 3; }
	}

	requirement def ReviewApprovalRequirement {
		subject article : MedicalArticle;
		constraint { article.articleMetadata.accuracyConfidence >= 0.8 and size(article.citations) >= 3; }
	}

	requirement def SearchRelevanceRequirement {
		subject results : RankedSearchResult[0..*];
		constraint {
			(1..size(results)-1)->forAll { in i; results.relevanceScore#(i) >= results.relevanceScore#(i+1); }
		}
	}

	requirement def MetadataCompletenessRequirement {
		subject article : MedicalArticle;
		constraint {
			article.articleMetadata.title != "" and
			article.articleMetadata.category != "" and
			article.articleMetadata.lastReviewedDate != "" and
			article.articleMetadata.readingLevel != "";
		}
	}

	requirement def ContentReviewWorkflowRequirement {
		subject database : ContentDatabase;
		constraint {
			database.articles->forAll { in a; a.articleMetadata.accuracyConfidence >= 0.8; }
		}
	}
}
