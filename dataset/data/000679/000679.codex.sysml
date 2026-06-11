package MedicalEncyclopediaSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def TextString;
  attribute def BooleanFlag;
  attribute def Count;
  attribute def Percentage;
  attribute def Second;
  attribute def DateTime;
  attribute def URI;
  attribute def VersionId;

  item def SearchQuery {
    attribute text : TextString;
    attribute languageCode : TextString;
    attribute userContext : TextString;
  }

  item def MedicalTopicRequest {
    attribute topicName : TextString;
    attribute requestedLanguageCode : TextString;
    attribute readabilityLevel : TextString;
  }

  item def MedicalArticle {
    attribute articleId : TextString;
    attribute title : TextString;
    attribute abstractText : TextString;
    attribute bodyText : TextString;
    attribute lastReviewed : DateTime;
    attribute evidenceGrade : TextString;
    attribute version : VersionId;
    attribute readingTime : Second;
  }

  item def Citation {
    attribute citationId : TextString;
    attribute sourceTitle : TextString;
    attribute sourceUri : URI;
    attribute publicationDate : DateTime;
    attribute evidenceType : TextString;
  }

  item def DisclaimerNotice {
    attribute noticeText : TextString;
    attribute emergencyInstructionText : TextString;
    attribute shownAt : DateTime;
  }

  item def FeedbackReport {
    attribute articleId : TextString;
    attribute userComment : TextString;
    attribute safetyConcern : BooleanFlag;
    attribute submittedAt : DateTime;
  }

  item def AnalyticsEvent {
    attribute eventType : TextString;
    attribute articleId : TextString;
    attribute responseLatency : Second;
    attribute resultCount : Count;
  }

  item def ReviewDecision {
    attribute approved : BooleanFlag;
    attribute reviewerId : TextString;
    attribute decisionRationale : TextString;
    attribute decidedAt : DateTime;
  }

  port def QueryInPort {
    in query : SearchQuery;
  }

  port def TopicRequestInPort {
    in request : MedicalTopicRequest;
  }

  port def ArticleOutPort {
    out article : MedicalArticle;
  }

  port def DisclaimerOutPort {
    out notice : DisclaimerNotice;
  }

  port def FeedbackInPort {
    in feedback : FeedbackReport;
  }

  port def CitationOutPort {
    out citation : Citation;
  }

  port def ReviewPort {
    out candidateArticle : MedicalArticle;
    in decision : ReviewDecision;
  }

  port def AnalyticsOutPort {
    out event : AnalyticsEvent;
  }

  port def RepositoryPort {
    in lookupQuery : SearchQuery;
    in topicRequest : MedicalTopicRequest;
    out storedArticle : MedicalArticle;
    out storedCitation : Citation;
  }

  part def UserInterface {
    port queryInput : QueryInPort;
    port topicInput : TopicRequestInPort;
    port articleDisplay : ArticleOutPort;
    port disclaimerDisplay : DisclaimerOutPort;
    port feedbackCapture : FeedbackInPort;
  }

  part def SearchService {
    port userQueries : QueryInPort;
    port repositoryAccess : RepositoryPort;
    port rankedResults : ArticleOutPort;

    attribute maximumResults : Count = 20;
    attribute maximumSearchLatency : Second = 2;
  }

  part def TopicNavigator {
    port topicRequests : TopicRequestInPort;
    port repositoryAccess : RepositoryPort;
    port selectedArticle : ArticleOutPort;

    attribute supportedTopicCount : Count;
    attribute defaultReadabilityLevel : TextString = "general adult";
  }

  part def ContentRepository {
    port repositoryApi : RepositoryPort;

    attribute articleCount : Count;
    attribute citationCount : Count;
    attribute updateFrequencyDays : Count = 30;
    attribute minimumEvidenceCoverage : Percentage = 95;
  }

  part def EditorialReviewService {
    port reviewWorkflow : ReviewPort;
    port repositoryAccess : RepositoryPort;

    attribute requiredReviewerCount : Count = 2;
    attribute maximumReviewCycleTime : Second = 604800;
  }

  part def SafetyDisclaimerService {
    port noticeOutput : DisclaimerOutPort;

    attribute emergencyText : TextString =
      "For medical emergencies, contact local emergency services immediately.";
    attribute diagnosticBoundaryText : TextString =
      "This encyclopedia supports education and does not replace professional diagnosis or treatment.";
  }

  part def CitationService {
    port repositoryAccess : RepositoryPort;
    port citationOutput : CitationOutPort;

    attribute minimumCitationAgeTracking : BooleanFlag = true;
  }

  part def FeedbackService {
    port feedbackInput : FeedbackInPort;
    port reviewEscalation : ReviewPort;

    attribute safetyEscalationThreshold : Count = 1;
    attribute maximumFeedbackTriageTime : Second = 86400;
  }

  part def AnalyticsService {
    port eventOutput : AnalyticsOutPort;

    attribute dailyActiveUsers : Count;
    attribute medianSearchLatency : Second;
    attribute zeroResultRate : Percentage;
  }

  part def MedicalEncyclopediaSystem {
    part ui : UserInterface;
    part search : SearchService;
    part navigator : TopicNavigator;
    part repository : ContentRepository;
    part review : EditorialReviewService;
    part disclaimer : SafetyDisclaimerService;
    part citations : CitationService;
    part feedback : FeedbackService;
    part analytics : AnalyticsService;

    port publicQueryPort : QueryInPort;
    port publicTopicPort : TopicRequestInPort;
    port publicArticlePort : ArticleOutPort;
    port publicDisclaimerPort : DisclaimerOutPort;
    port publicFeedbackPort : FeedbackInPort;
    port publicAnalyticsPort : AnalyticsOutPort;

    connect publicQueryPort to ui.queryInput;
    connect publicTopicPort to ui.topicInput;
    connect ui.articleDisplay to publicArticlePort;
    connect disclaimer.noticeOutput to ui.disclaimerDisplay;
    connect ui.disclaimerDisplay to publicDisclaimerPort;
    connect publicFeedbackPort to ui.feedbackCapture;

    connect ui.queryInput to search.userQueries;
    connect ui.topicInput to navigator.topicRequests;

    connect search.repositoryAccess to repository.repositoryApi;
    connect navigator.repositoryAccess to repository.repositoryApi;
    connect citations.repositoryAccess to repository.repositoryApi;
    connect review.repositoryAccess to repository.repositoryApi;

    connect search.rankedResults to ui.articleDisplay;
    connect navigator.selectedArticle to ui.articleDisplay;

    connect ui.feedbackCapture to feedback.feedbackInput;
    connect feedback.reviewEscalation to review.reviewWorkflow;

    connect citations.citationOutput to ui.articleDisplay;
    connect analytics.eventOutput to publicAnalyticsPort;
  }

  action def ProcessSearchQuery {
    in query : SearchQuery;
    out article : MedicalArticle;
    out notice : DisclaimerNotice;
    out event : AnalyticsEvent;

    first start;
    then normalizeQuery;
    then retrieveCandidateArticles;
    then rankByRelevanceAndEvidence;
    then attachSafetyDisclaimer;
    then emitAnalyticsEvent;
    then done;

    action normalizeQuery;
    action retrieveCandidateArticles;
    action rankByRelevanceAndEvidence;
    action attachSafetyDisclaimer;
    action emitAnalyticsEvent;
  }

  action def RetrieveMedicalTopic {
    in request : MedicalTopicRequest;
    out article : MedicalArticle;
    out citation : Citation;
    out notice : DisclaimerNotice;

    first start;
    then validateTopicRequest;
    then loadReviewedArticle;
    then loadCurrentCitations;
    then adaptReadingLevel;
    then appendMedicalDisclaimer;
    then done;

    action validateTopicRequest;
    action loadReviewedArticle;
    action loadCurrentCitations;
    action adaptReadingLevel;
    action appendMedicalDisclaimer;
  }

  action def ReviewAndPublishArticle {
    in candidate : MedicalArticle;
    in decision : ReviewDecision;
    out publishedArticle : MedicalArticle;

    first start;
    then checkClinicalAccuracy;
    then verifyCitations;
    then evaluatePlainLanguageQuality;
    then applyReviewDecision;
    then publishApprovedVersion;
    then done;

    action checkClinicalAccuracy;
    action verifyCitations;
    action evaluatePlainLanguageQuality;
    action applyReviewDecision;
    action publishApprovedVersion;
  }

  action def TriageFeedback {
    in report : FeedbackReport;
    out escalation : MedicalArticle;

    first start;
    then classifyFeedback;
    then detectSafetyConcern;
    then routeToEditorialReview;
    then done;

    action classifyFeedback;
    action detectSafetyConcern;
    action routeToEditorialReview;
  }

  state def EncyclopediaOperationalState {
    entry action initializeServices;

    state Offline;
    state Starting;
    state Available;
    state Searching;
    state PresentingArticle;
    state ReviewPending;
    state Maintenance;
    state Degraded;
    state Stopping;

    transition first Offline then Starting;
    transition Starting then Available
      accept after 30 [repositoryReady and indexReady];

    transition Available then Searching
      accept SearchQuery;

    transition Searching then PresentingArticle
      accept MedicalArticle [resultCount > 0];

    transition Searching then Available
      accept AnalyticsEvent [resultCount == 0];

    transition PresentingArticle then Available
      accept after 600;

    transition Available then ReviewPending
      accept FeedbackReport [safetyConcern == true];

    transition ReviewPending then Available
      accept ReviewDecision [approved == true or approved == false];

    transition Available then Maintenance
      accept DateTime [scheduledMaintenance == true];

    transition Maintenance then Available
      accept after 3600 [contentValidationComplete];

    transition Available then Degraded
      accept AnalyticsEvent [responseLatency > 5];

    transition Degraded then Available
      accept after 300 [responseLatency <= 2];

    transition Available then Stopping;
    transition Stopping then Offline;

    exit action flushAnalyticsEvents;

    attribute repositoryReady : BooleanFlag;
    attribute indexReady : BooleanFlag;
    attribute scheduledMaintenance : BooleanFlag;
    attribute contentValidationComplete : BooleanFlag;
    attribute responseLatency : Second;
    attribute resultCount : Count;
  }

  requirement def PrimaryFunctionRequirement {
    doc
      /* The medical encyclopedia system shall provide a searchable, reviewed, evidence-referenced collection of medical information for educational use by the public and clinicians at a high level. */
  }

  requirement def SearchRequirement {
    doc
      /* The system shall return relevant medical articles for user search queries with a maximum normal operating latency of 2 seconds. */

    attribute requiredLatency : Second = 2;
  }

  requirement def DisclaimerRequirement {
    doc
      /* The system shall display a medical disclaimer with every presented article and shall identify emergency care boundaries. */
  }

  requirement def EvidenceRequirement {
    doc
      /* At least 95 percent of published medical articles shall include current citations from traceable medical sources. */

    attribute minimumCoverage : Percentage = 95;
  }

  requirement def EditorialReviewRequirement {
    doc
      /* Each article shall be reviewed by at least two qualified reviewers before publication or major revision. */

    attribute reviewerCount : Count = 2;
  }

  requirement def FeedbackSafetyRequirement {
    doc
      /* Feedback reports marked as safety concerns shall be routed to editorial review within 24 hours. */

    attribute maximumTriageTime : Second = 86400;
  }

  requirement def AccessibilityRequirement {
    doc
      /* The system shall provide article content at a general adult readability level and support language-specific topic requests. */
  }

  satisfy PrimaryFunctionRequirement by MedicalEncyclopediaSystem;
  satisfy SearchRequirement by SearchService;
  satisfy DisclaimerRequirement by SafetyDisclaimerService;
  satisfy EvidenceRequirement by ContentRepository;
  satisfy EditorialReviewRequirement by EditorialReviewService;
  satisfy FeedbackSafetyRequirement by FeedbackService;
  satisfy AccessibilityRequirement by TopicNavigator;

  part encyclopediaSystem : MedicalEncyclopediaSystem {
    repository.articleCount = 125000;
    repository.citationCount = 480000;
    repository.minimumEvidenceCoverage = 97;
    search.maximumResults = 20;
    search.maximumSearchLatency = 2;
    navigator.supportedTopicCount = 35000;
    analytics.zeroResultRate = 3;
  }

}