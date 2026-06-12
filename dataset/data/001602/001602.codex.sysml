package TechnologyScoutingSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Score : Real {
    doc /* Normalized evaluation score in the range 0.0 to 100.0. */
  }

  attribute def Probability : Real {
    doc /* Normalized probability in the range 0.0 to 1.0. */
  }

  attribute def CurrencyUSD : Real {
    unit = "$";
  }

  attribute def Days : Real {
    unit = "d";
  }

  attribute def Hours : Real {
    unit = "h";
  }

  attribute def Count : Integer;

  attribute def URI : String;
  attribute def OrganizationName : String;
  attribute def TechnologyDomainName : String;
  attribute def MaturityLevel : String;
  attribute def RiskClass : String;
  attribute def RecommendationDecision : String;

  item def SearchQuery {
    attribute keywords : String;
    attribute domain : TechnologyDomainName;
    attribute requestedBy : OrganizationName;
    attribute issuedAt : String;
    attribute maxResults : Count;
  }

  item def SourceRecord {
    attribute sourceId : String;
    attribute sourceUri : URI;
    attribute sourceType : String;
    attribute publisher : OrganizationName;
    attribute publicationDate : String;
    attribute trustScore : Score;
  }

  item def TechnologySignal {
    attribute signalId : String;
    attribute title : String;
    attribute domain : TechnologyDomainName;
    attribute summary : String;
    attribute sourceTrust : Score;
    attribute noveltyScore : Score;
    attribute relevanceScore : Score;
    attribute evidenceCount : Count;
    attribute detectedAt : String;
  }

  item def TechnologyProfile {
    attribute profileId : String;
    attribute name : String;
    attribute domain : TechnologyDomainName;
    attribute description : String;
    attribute maturity : MaturityLevel;
    attribute readinessScore : Score;
    attribute marketFitScore : Score;
    attribute ipStrengthScore : Score;
    attribute integrationComplexityScore : Score;
    attribute risk : RiskClass;
    attribute estimatedAdoptionCost : CurrencyUSD;
    attribute estimatedTimeToPilot : Days;
  }

  item def EvaluationCriteria {
    attribute domainWeight : Real;
    attribute maturityWeight : Real;
    attribute strategicFitWeight : Real;
    attribute costWeight : Real;
    attribute riskWeight : Real;
    attribute noveltyWeight : Real;
  }

  item def TechnologyRecommendation {
    attribute recommendationId : String;
    attribute technologyName : String;
    attribute decision : RecommendationDecision;
    attribute priorityScore : Score;
    attribute confidence : Probability;
    attribute rationale : String;
    attribute recommendedPilotBudget : CurrencyUSD;
    attribute recommendedPilotDuration : Days;
  }

  item def ScoutReport {
    attribute reportId : String;
    attribute title : String;
    attribute generatedAt : String;
    attribute executiveSummary : String;
    attribute candidateCount : Count;
    attribute recommendedCount : Count;
    attribute averageConfidence : Probability;
  }

  port def QueryPort {
    out item query : SearchQuery;
  }

  port def SourcePort {
    in item query : SearchQuery;
    out item sourceRecord : SourceRecord;
  }

  port def SignalPort {
    in item sourceRecord : SourceRecord;
    out item signal : TechnologySignal;
  }

  port def ProfilePort {
    in item signal : TechnologySignal;
    out item profile : TechnologyProfile;
  }

  port def CriteriaPort {
    out item criteria : EvaluationCriteria;
  }

  port def RecommendationPort {
    in item profile : TechnologyProfile;
    in item criteria : EvaluationCriteria;
    out item recommendation : TechnologyRecommendation;
  }

  port def ReportPort {
    in item profile : TechnologyProfile;
    in item recommendation : TechnologyRecommendation;
    out item report : ScoutReport;
  }

  port def ReviewPort {
    in item report : ScoutReport;
    out item decision : RecommendationDecision;
  }

  action def DefineScoutingCampaign {
    in attribute domain : TechnologyDomainName;
    in attribute sponsor : OrganizationName;
    in attribute maxResults : Count;
    out item query : SearchQuery;
  }

  action def HarvestSources {
    in item query : SearchQuery;
    out item sourceRecord : SourceRecord;
  }

  action def ExtractTechnologySignals {
    in item sourceRecord : SourceRecord;
    out item signal : TechnologySignal;
  }

  action def BuildTechnologyProfile {
    in item signal : TechnologySignal;
    out item profile : TechnologyProfile;
  }

  action def EvaluateTechnology {
    in item profile : TechnologyProfile;
    in item criteria : EvaluationCriteria;
    out item recommendation : TechnologyRecommendation;
  }

  action def GenerateScoutReport {
    in item profile : TechnologyProfile;
    in item recommendation : TechnologyRecommendation;
    out item report : ScoutReport;
  }

  state def ScoutingLifecycle {
    state idle;
    state campaignDefined;
    state harvestingSources;
    state extractingSignals;
    state profilingTechnologies;
    state evaluatingCandidates;
    state reportingFindings;
    state awaitingReview;
    state archived;

    transition first idle;
    transition idle_to_campaignDefined
      first idle
      then campaignDefined;

    transition campaignDefined_to_harvestingSources
      first campaignDefined
      then harvestingSources;

    transition harvestingSources_to_extractingSignals
      first harvestingSources
      then extractingSignals;

    transition extractingSignals_to_profilingTechnologies
      first extractingSignals
      then profilingTechnologies;

    transition profilingTechnologies_to_evaluatingCandidates
      first profilingTechnologies
      then evaluatingCandidates;

    transition evaluatingCandidates_to_reportingFindings
      first evaluatingCandidates
      then reportingFindings;

    transition reportingFindings_to_awaitingReview
      first reportingFindings
      then awaitingReview;

    transition awaitingReview_to_archived
      first awaitingReview
      then archived;
  }

  part def TechnologyScoutingPlatform {
    doc /* Primary function: continuously discover, filter, evaluate, and recommend emerging technologies that match strategic business domains and can be advanced into pilots or investment decisions. */

    attribute campaignCycleTime : Days;
    attribute maximumSourceLatency : Hours;
    attribute minimumRecommendationConfidence : Probability;
    attribute annualOperatingBudget : CurrencyUSD;

    port campaignQueryPort : QueryPort;
    port publicSourcePort : SourcePort;
    port patentSourcePort : SourcePort;
    port academicSourcePort : SourcePort;
    port marketSourcePort : SourcePort;
    port extractedSignalPort : SignalPort;
    port profiledTechnologyPort : ProfilePort;
    port evaluationCriteriaPort : CriteriaPort;
    port recommendationPort : RecommendationPort;
    port reportPort : ReportPort;
    port reviewPort : ReviewPort;

    part campaignManager {
      attribute activeCampaigns : Count;
      attribute defaultMaxResults : Count;
      port queryOut : QueryPort;
      perform action defineCampaign : DefineScoutingCampaign;
    }

    part sourceHarvester {
      attribute sourcesPerCampaign : Count;
      attribute refreshInterval : Hours;
      attribute duplicateRemovalThreshold : Score;
      port queryIn : SourcePort;
      port sourceOut : SourcePort;
      perform action harvest : HarvestSources;
    }

    part publicWebAdapter {
      attribute apiQuotaPerDay : Count;
      attribute averageLatency : Hours;
      port sourceAccess : SourcePort;
    }

    part patentDatabaseAdapter {
      attribute jurisdictionsCovered : Count;
      attribute averageLatency : Hours;
      port sourceAccess : SourcePort;
    }

    part academicLiteratureAdapter {
      attribute indexedPublishers : Count;
      attribute averageLatency : Hours;
      port sourceAccess : SourcePort;
    }

    part marketIntelligenceAdapter {
      attribute vendorsTracked : Count;
      attribute averageLatency : Hours;
      port sourceAccess : SourcePort;
    }

    part signalExtractor {
      attribute minimumTrustScore : Score;
      attribute minimumNoveltyScore : Score;
      attribute extractionPrecision : Probability;
      port sourceIn : SignalPort;
      port signalOut : SignalPort;
      perform action extractSignals : ExtractTechnologySignals;
    }

    part knowledgeGraph {
      attribute storedSignals : Count;
      attribute storedProfiles : Count;
      attribute semanticMatchAccuracy : Probability;
      port signalIn : SignalPort;
      port profileOut : ProfilePort;
    }

    part profileBuilder {
      attribute maturityModelVersion : String;
      attribute maximumProfileAge : Days;
      port signalIn : ProfilePort;
      port profileOut : ProfilePort;
      perform action buildProfile : BuildTechnologyProfile;
    }

    part criteriaManager {
      attribute strategicDomainPriority : Score;
      attribute maximumAcceptableRisk : Score;
      attribute targetPilotBudget : CurrencyUSD;
      port criteriaOut : CriteriaPort;
    }

    part evaluationEngine {
      attribute minimumPriorityScore : Score;
      attribute costSensitivity : Real;
      attribute riskSensitivity : Real;
      port profileIn : RecommendationPort;
      port criteriaIn : RecommendationPort;
      port recommendationOut : RecommendationPort;
      perform action evaluate : EvaluateTechnology;
    }

    part reportGenerator {
      attribute reportGenerationTime : Hours;
      attribute maximumRecommendationsPerReport : Count;
      port profileIn : ReportPort;
      port recommendationIn : ReportPort;
      port reportOut : ReportPort;
      perform action generateReport : GenerateScoutReport;
    }

    part executiveReviewBoard {
      attribute reviewers : Count;
      attribute reviewServiceLevel : Days;
      attribute minimumApprovalConfidence : Probability;
      port reportIn : ReviewPort;
    }

    part lifecycleController {
      exhibit state scoutingLifecycle : ScoutingLifecycle;
    }

    connect campaignManager.queryOut to sourceHarvester.queryIn;
    connect sourceHarvester.sourceOut to publicWebAdapter.sourceAccess;
    connect sourceHarvester.sourceOut to patentDatabaseAdapter.sourceAccess;
    connect sourceHarvester.sourceOut to academicLiteratureAdapter.sourceAccess;
    connect sourceHarvester.sourceOut to marketIntelligenceAdapter.sourceAccess;

    connect publicWebAdapter.sourceAccess to signalExtractor.sourceIn;
    connect patentDatabaseAdapter.sourceAccess to signalExtractor.sourceIn;
    connect academicLiteratureAdapter.sourceAccess to signalExtractor.sourceIn;
    connect marketIntelligenceAdapter.sourceAccess to signalExtractor.sourceIn;

    connect signalExtractor.signalOut to knowledgeGraph.signalIn;
    connect knowledgeGraph.profileOut to profileBuilder.signalIn;
    connect profileBuilder.profileOut to evaluationEngine.profileIn;
    connect criteriaManager.criteriaOut to evaluationEngine.criteriaIn;
    connect evaluationEngine.recommendationOut to reportGenerator.recommendationIn;
    connect profileBuilder.profileOut to reportGenerator.profileIn;
    connect reportGenerator.reportOut to executiveReviewBoard.reportIn;
  }

  requirement def HighLevelPrimaryFunctionRequirement {
    doc /* The system shall provide an integrated technology scouting capability that discovers relevant emerging technologies, evaluates their maturity and strategic fit, and produces actionable recommendations for pilot or investment decisions. */
    subject platform : TechnologyScoutingPlatform;
    require constraint {
      platform.minimumRecommendationConfidence >= 0.70
    }
  }

  requirement def SourceCoverageRequirement {
    doc /* The system shall collect evidence from public web, patent, academic, and market intelligence sources for each scouting campaign. */
    subject platform : TechnologyScoutingPlatform;
    require constraint {
      platform.sourceHarvester.sourcesPerCampaign >= 4
    }
  }

  requirement def TimelinessRequirement {
    doc /* The system shall refresh scouting evidence within a maximum source latency suitable for strategic planning cycles. */
    subject platform : TechnologyScoutingPlatform;
    require constraint {
      platform.maximumSourceLatency <= 48 [h]
    }
  }

  requirement def RecommendationQualityRequirement {
    doc /* The system shall issue a recommendation only when the evaluated technology reaches the configured confidence threshold. */
    subject platform : TechnologyScoutingPlatform;
    require constraint {
      platform.evaluationEngine.minimumPriorityScore >= 65.0
    }
  }

  requirement def PilotPlanningRequirement {
    doc /* Each recommended technology shall include estimated adoption cost and time to pilot. */
    subject profile : TechnologyProfile;
    require constraint {
      profile.estimatedAdoptionCost > 0 [$] and profile.estimatedTimeToPilot > 0 [d]
    }
  }

  requirement def ReportUsabilityRequirement {
    doc /* Each scouting report shall summarize candidate technologies and identify the subset recommended for executive review. */
    subject report : ScoutReport;
    require constraint {
      report.candidateCount >= report.recommendedCount
    }
  }

  requirement def EvidenceTrustRequirement {
    doc /* Extracted technology signals shall be based on sources meeting the minimum trust score. */
    subject signal : TechnologySignal;
    require constraint {
      signal.sourceTrust >= 60.0
    }
  }

  part technologyScoutingSystem : TechnologyScoutingPlatform {
    attribute campaignCycleTime = 30 [d];
    attribute maximumSourceLatency = 24 [h];
    attribute minimumRecommendationConfidence = 0.75;
    attribute annualOperatingBudget = 1250000 [$];

    part campaignManager {
      attribute activeCampaigns = 6;
      attribute defaultMaxResults = 500;
    }

    part sourceHarvester {
      attribute sourcesPerCampaign = 4;
      attribute refreshInterval = 24 [h];
      attribute duplicateRemovalThreshold = 85.0;
    }

    part publicWebAdapter {
      attribute apiQuotaPerDay = 10000;
      attribute averageLatency = 2 [h];
    }

    part patentDatabaseAdapter {
      attribute jurisdictionsCovered = 12;
      attribute averageLatency = 4 [h];
    }

    part academicLiteratureAdapter {
      attribute indexedPublishers = 80;
      attribute averageLatency = 6 [h];
    }

    part marketIntelligenceAdapter {
      attribute vendorsTracked = 250;
      attribute averageLatency = 8 [h];
    }

    part signalExtractor {
      attribute minimumTrustScore = 60.0;
      attribute minimumNoveltyScore = 50.0;
      attribute extractionPrecision = 0.88;
    }

    part knowledgeGraph {
      attribute storedSignals = 250000;
      attribute storedProfiles = 12000;
      attribute semanticMatchAccuracy = 0.91;
    }

    part profileBuilder {
      attribute maturityModelVersion = "TRL-MRL-BusinessFit-1.0";
      attribute maximumProfileAge = 90 [d];
    }

    part criteriaManager {
      attribute strategicDomainPriority = 80.0;
      attribute maximumAcceptableRisk = 55.0;
      attribute targetPilotBudget = 250000 [$];
    }

    part evaluationEngine {
      attribute minimumPriorityScore = 70.0;
      attribute costSensitivity = 0.35;
      attribute riskSensitivity = 0.45;
    }

    part reportGenerator {
      attribute reportGenerationTime = 2 [h];
      attribute maximumRecommendationsPerReport = 20;
    }

    part executiveReviewBoard {
      attribute reviewers = 7;
      attribute reviewServiceLevel = 10 [d];
      attribute minimumApprovalConfidence = 0.75;
    }
  }

  satisfy HighLevelPrimaryFunctionRequirement by technologyScoutingSystem;
  satisfy SourceCoverageRequirement by technologyScoutingSystem;
  satisfy TimelinessRequirement by technologyScoutingSystem;
  satisfy RecommendationQualityRequirement by technologyScoutingSystem;

}