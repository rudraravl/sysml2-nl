package OpportunityCostModel {

  import ScalarValues::*;

  value type USD specializes Real {
    unit = "USD";
  }

  value type Hour specializes Real {
    unit = "h";
  }

  value type Percent specializes Real {
    unit = "%";
  }

  value type Score specializes Real {
    unit = "point";
  }

  item def Alternative {
    attribute name : String;
    attribute directCost : USD;
    attribute expectedBenefit : USD;
    attribute timeRequired : Hour;
    attribute riskProbability : Percent;
    attribute strategicScore : Score;
  }

  item def OpportunityCostAssessment {
    attribute selectedAlternativeName : String;
    attribute forgoneAlternativeName : String;
    attribute netValueOfSelected : USD;
    attribute netValueOfForgoneBest : USD;
    attribute opportunityCost : USD;
    attribute recommendationConfidence : Percent;
  }

  item def DecisionCriteria {
    attribute availableBudget : USD;
    attribute availableTime : Hour;
    attribute minimumStrategicScore : Score;
    attribute maximumRiskProbability : Percent;
  }

  port def AlternativeInputPort {
    in item alternative : Alternative;
  }

  port def CriteriaInputPort {
    in item criteria : DecisionCriteria;
  }

  port def AssessmentOutputPort {
    out item assessment : OpportunityCostAssessment;
  }

  port def AuditOutputPort {
    out item assessmentRecord : OpportunityCostAssessment;
  }

  part def AlternativeRepository {
    port alternativeIn : AlternativeInputPort;
    port alternativesOut : AlternativeInputPort;
    attribute storedAlternativeCount : Integer;
  }

  part def CriteriaManager {
    port criteriaIn : CriteriaInputPort;
    port criteriaOut : CriteriaInputPort;
    attribute activeBudget : USD;
    attribute activeTimeLimit : Hour;
    attribute activeRiskLimit : Percent;
  }

  part def NetValueAnalyzer {
    port alternativeIn : AlternativeInputPort;
    port criteriaIn : CriteriaInputPort;
    port assessmentOut : AssessmentOutputPort;

    attribute riskPenaltyWeight : Percent;
    attribute strategicWeight : Percent;
  }

  part def RankingEngine {
    port candidateAssessmentsIn : AssessmentOutputPort;
    port selectedAssessmentOut : AssessmentOutputPort;

    attribute rankedCandidateCount : Integer;
    attribute bestNetValue : USD;
    attribute secondBestNetValue : USD;
  }

  part def RecommendationPresenter {
    port assessmentIn : AssessmentOutputPort;
    port userAssessmentOut : AssessmentOutputPort;

    attribute displayedOpportunityCost : USD;
    attribute displayedConfidence : Percent;
  }

  part def AuditLog {
    port recordIn : AuditOutputPort;
    attribute retainedRecordCount : Integer;
  }

  action def CalculateNetValue {
    in alternative : Alternative;
    in criteria : DecisionCriteria;
    out feasible : Boolean;
    out netValue : USD;

    action computeRiskAdjustedBenefit;
    action computeResourceFit;
    action computeStrategicAdjustment;
    action computeNetValue;
  }

  action def CompareAlternatives {
    in selected : Alternative;
    in forgoneBest : Alternative;
    out assessment : OpportunityCostAssessment;

    action calculateSelectedNetValue;
    action calculateForgoneNetValue;
    action subtractSelectedFromForgone;
    action estimateConfidence;
  }

  state def DecisionEvaluationStateMachine {
    entry action initializeEvaluation;

    state Idle;
    state CollectingInputs;
    state ValidatingCriteria;
    state EvaluatingAlternatives;
    state RankingChoices;
    state ReportingOpportunityCost;
    state ArchivingDecision;
    state Error;

    transition first Idle to CollectingInputs
      accept collectRequest;

    transition inputsCollected CollectingInputs to ValidatingCriteria
      accept alternativesReceived;

    transition criteriaValid ValidatingCriteria to EvaluatingAlternatives
      if validCriteria == true;

    transition criteriaInvalid ValidatingCriteria to Error
      if validCriteria == false;

    transition evaluationComplete EvaluatingAlternatives to RankingChoices
      accept netValuesComputed;

    transition rankingComplete RankingChoices to ReportingOpportunityCost
      accept bestAndForgoneIdentified;

    transition reportPublished ReportingOpportunityCost to ArchivingDecision
      accept assessmentDelivered;

    transition archiveComplete ArchivingDecision to Idle
      accept recordStored;

    transition recover Error to Idle
      accept resetRequest;
  }

  part def OpportunityCostDecisionSupportSystem {
    doc
    /* Primary function: evaluate competing alternatives and quantify the value of the best forgone option so a decision maker can understand the opportunity cost of selecting one alternative over another. */

    port alternativeInput : AlternativeInputPort;
    port criteriaInput : CriteriaInputPort;
    port assessmentOutput : AssessmentOutputPort;
    port auditOutput : AuditOutputPort;

    part repository : AlternativeRepository;
    part criteriaManager : CriteriaManager;
    part analyzer : NetValueAnalyzer;
    part rankingEngine : RankingEngine;
    part presenter : RecommendationPresenter;
    part auditLog : AuditLog;

    attribute maximumAlternatives : Integer = 50;
    attribute minimumConfidenceThreshold : Percent = 70.0;
    attribute defaultRiskPenaltyWeight : Percent = 35.0;
    attribute defaultStrategicWeight : Percent = 20.0;

    connection alternativeFlow
      connect alternativeInput to repository.alternativeIn;

    connection criteriaFlow
      connect criteriaInput to criteriaManager.criteriaIn;

    connection repositoryToAnalyzer
      connect repository.alternativesOut to analyzer.alternativeIn;

    connection criteriaToAnalyzer
      connect criteriaManager.criteriaOut to analyzer.criteriaIn;

    connection analyzerToRanking
      connect analyzer.assessmentOut to rankingEngine.candidateAssessmentsIn;

    connection rankingToPresenter
      connect rankingEngine.selectedAssessmentOut to presenter.assessmentIn;

    connection presenterToUser
      connect presenter.userAssessmentOut to assessmentOutput;

    connection presenterToAudit
      connect presenter.userAssessmentOut to auditOutput;

    connection auditRecordFlow
      connect auditOutput to auditLog.recordIn;

    perform DecisionEvaluationStateMachine;
  }

  requirement def ReqPrimaryFunction {
    doc
    /* The system shall calculate and report the opportunity cost of a selected alternative as the net value of the best feasible forgone alternative minus the net value of the selected alternative. */
  }

  requirement def ReqAlternativeInputs {
    doc
    /* The system shall accept at least two alternatives, each including direct cost, expected benefit, time required, risk probability, and strategic score. */
  }

  requirement def ReqFeasibilityScreening {
    doc
    /* The system shall exclude alternatives that exceed available budget, exceed available time, exceed maximum risk probability, or fall below minimum strategic score. */
  }

  requirement def ReqRecommendationConfidence {
    doc
    /* The system shall provide a recommendation confidence percentage based on value separation, input completeness, and risk uncertainty. */
  }

  requirement def ReqAuditability {
    doc
    /* The system shall retain the reported assessment record for later review of the decision rationale. */
  }

  satisfy ReqPrimaryFunction by OpportunityCostDecisionSupportSystem;
  satisfy ReqAlternativeInputs by AlternativeRepository;
  satisfy ReqFeasibilityScreening by NetValueAnalyzer;
  satisfy ReqRecommendationConfidence by RankingEngine;
  satisfy ReqAuditability by AuditLog;

}