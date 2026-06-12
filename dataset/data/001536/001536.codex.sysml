package ProactionaryPrincipleSystemModel {
  import ScalarValues::*;
  import SI::*;

  value type Probability specializes Real {
    doc /* unitless probability from 0.0 to 1.0 */
  }

  value type UtilityScore specializes Real {
    doc /* normalized expected value score from -100.0 to 100.0 */
  }

  value type RiskIndex specializes Real {
    doc /* normalized aggregate risk from 0.0 to 100.0 */
  }

  value type BenefitIndex specializes Real {
    doc /* normalized aggregate benefit from 0.0 to 100.0 */
  }

  value type CurrencyUSD specializes Real {
    doc /* US dollars */
  }

  value type PersonCount specializes Integer {
    doc /* persons */
  }

  value type Hours specializes Real {
    doc /* hours */
  }

  value type Days specializes Real {
    doc /* days */
  }

  value type DataRateMbps specializes Real {
    doc /* megabits per second */
  }

  enum def LifecycleState {
    enum draft;
    enum screened;
    enum simulated;
    enum approvedForSandbox;
    enum sandboxRunning;
    enum expandedTrial;
    enum deployed;
    enum suspended;
    enum retired;
  }

  enum def DecisionKind {
    enum approve;
    enum revise;
    enum reject;
    enum pause;
    enum expand;
    enum rollback;
  }

  item def OpportunitySignal {
    attribute sourceId : String;
    attribute description : String;
    attribute affectedPopulation : PersonCount;
    attribute estimatedBenefit : BenefitIndex;
    attribute novelty : UtilityScore;
  }

  item def InnovationProposal {
    attribute proposalId : String;
    attribute title : String;
    attribute primaryFunction : String;
    attribute expectedBenefit : BenefitIndex;
    attribute uncertainty : Probability;
    attribute reversibility : Probability;
    attribute affectedPopulation : PersonCount;
  }

  item def RiskEstimate {
    attribute safetyRisk : RiskIndex;
    attribute privacyRisk : RiskIndex;
    attribute economicRisk : RiskIndex;
    attribute environmentalRisk : RiskIndex;
    attribute socialRisk : RiskIndex;
    attribute confidence : Probability;
  }

  item def BenefitEstimate {
    attribute directBenefit : BenefitIndex;
    attribute learningBenefit : BenefitIndex;
    attribute publicBenefit : BenefitIndex;
    attribute optionValue : CurrencyUSD;
    attribute confidence : Probability;
  }

  item def ExperimentPlan {
    attribute planId : String;
    attribute duration : Days;
    attribute maxParticipants : PersonCount;
    attribute budgetLimit : CurrencyUSD;
    attribute rollbackTimeLimit : Hours;
    attribute minimumBenefitRiskRatio : Real;
  }

  item def EvidencePacket {
    attribute packetId : String;
    attribute observedBenefit : BenefitIndex;
    attribute observedRisk : RiskIndex;
    attribute confidence : Probability;
    attribute sampleSize : PersonCount;
    attribute elapsedTime : Hours;
  }

  item def GovernanceDecision {
    attribute decisionId : String;
    attribute kind : DecisionKind;
    attribute rationale : String;
    attribute maxAllowedRisk : RiskIndex;
    attribute requiredMonitoringInterval : Hours;
  }

  item def TelemetrySample {
    attribute sampleId : String;
    attribute benefitIndicator : BenefitIndex;
    attribute harmIndicator : RiskIndex;
    attribute uptime : Probability;
    attribute dataRate : DataRateMbps;
    attribute participantCount : PersonCount;
  }

  item def HarmSignal {
    attribute signalId : String;
    attribute severity : RiskIndex;
    attribute probability : Probability;
    attribute reversible : Boolean;
    attribute description : String;
  }

  port def ProposalPort {
    in item signal : OpportunitySignal;
    out item proposal : InnovationProposal;
  }

  port def AssessmentPort {
    in item proposal : InnovationProposal;
    out item risk : RiskEstimate;
    out item benefit : BenefitEstimate;
  }

  port def DecisionPort {
    in item risk : RiskEstimate;
    in item benefit : BenefitEstimate;
    in item evidence : EvidencePacket;
    out item decision : GovernanceDecision;
  }

  port def ExperimentPort {
    in item plan : ExperimentPlan;
    in item decision : GovernanceDecision;
    out item telemetry : TelemetrySample;
    out item evidence : EvidencePacket;
  }

  port def MonitoringPort {
    in item telemetry : TelemetrySample;
    out item harm : HarmSignal;
    out item evidence : EvidencePacket;
  }

  port def RollbackPort {
    in item harm : HarmSignal;
    in item decision : GovernanceDecision;
    out item evidence : EvidencePacket;
  }

  action def GenerateProposal {
    in item signal : OpportunitySignal;
    out item proposal : InnovationProposal;
  }

  action def EstimateBenefitRisk {
    in item proposal : InnovationProposal;
    out item risk : RiskEstimate;
    out item benefit : BenefitEstimate;
  }

  action def SelectExperimentPlan {
    in item proposal : InnovationProposal;
    in item risk : RiskEstimate;
    in item benefit : BenefitEstimate;
    out item plan : ExperimentPlan;
  }

  action def DecideUnderProactionaryPrinciple {
    in item proposal : InnovationProposal;
    in item risk : RiskEstimate;
    in item benefit : BenefitEstimate;
    in item evidence : EvidencePacket;
    out item decision : GovernanceDecision;
  }

  action def RunBoundedExperiment {
    in item plan : ExperimentPlan;
    in item decision : GovernanceDecision;
    out item telemetry : TelemetrySample;
    out item evidence : EvidencePacket;
  }

  action def MonitorForEmergentHarm {
    in item telemetry : TelemetrySample;
    out item harm : HarmSignal;
    out item evidence : EvidencePacket;
  }

  action def ExecuteRollback {
    in item harm : HarmSignal;
    out item evidence : EvidencePacket;
  }

  state def InnovationLifecycle {
    entry action InitializeLifecycle;

    state Draft;
    state Screened;
    state Simulated;
    state ApprovedForSandbox;
    state SandboxRunning;
    state ExpandedTrial;
    state Deployed;
    state Suspended;
    state Retired;

    transition first Draft;
    transition Draft then Screened accept OpportunitySignal;
    transition Screened then Simulated accept InnovationProposal;
    transition Simulated then ApprovedForSandbox accept GovernanceDecision if decision.kind == DecisionKind::approve;
    transition ApprovedForSandbox then SandboxRunning accept ExperimentPlan;
    transition SandboxRunning then ExpandedTrial accept EvidencePacket if evidence.observedBenefit > evidence.observedRisk;
    transition ExpandedTrial then Deployed accept GovernanceDecision if decision.kind == DecisionKind::expand;
    transition SandboxRunning then Suspended accept HarmSignal if harm.severity > 70.0;
    transition ExpandedTrial then Suspended accept HarmSignal if harm.severity > 60.0;
    transition Deployed then Suspended accept HarmSignal if harm.severity > 50.0;
    transition Suspended then Screened accept EvidencePacket;
    transition Deployed then Retired accept GovernanceDecision if decision.kind == DecisionKind::reject;
  }

  part def OpportunityScanner {
    port proposals : ProposalPort;
    action generate : GenerateProposal;
  }

  part def BenefitRiskModel {
    port assessment : AssessmentPort;
    action estimate : EstimateBenefitRisk;
  }

  part def ExperimentDesigner {
    port assessment : AssessmentPort;
    port experiment : ExperimentPort;
    action selectPlan : SelectExperimentPlan;
  }

  part def GovernanceCouncil {
    port decision : DecisionPort;
    action decide : DecideUnderProactionaryPrinciple;
  }

  part def SandboxFacility {
    port experiment : ExperimentPort;
    action run : RunBoundedExperiment;
  }

  part def TelemetryMonitor {
    port monitor : MonitoringPort;
    action observe : MonitorForEmergentHarm;
  }

  part def RollbackManager {
    port rollback : RollbackPort;
    action rollback : ExecuteRollback;
  }

  part def PublicLedger {
    port decisionLog : DecisionPort;
    attribute retainedRecords : Integer;
    attribute auditLatency : Hours;
  }

  part def ProactionaryInnovationSystem {
    doc /* Primary function: accelerate beneficial innovation by allowing bounded experimentation while continuously measuring benefits, risks, reversibility, and emergent harms. */

    attribute lifecycle : LifecycleState;
    attribute defaultMaxRisk : RiskIndex = 40.0;
    attribute minimumExpectedBenefit : BenefitIndex = 55.0;
    attribute minimumReversibility : Probability = 0.65;
    attribute monitoringInterval : Hours = 4.0;
    attribute standardSandboxDuration : Days = 30.0;
    attribute standardRollbackLimit : Hours = 24.0;

    part scanner : OpportunityScanner;
    part model : BenefitRiskModel;
    part designer : ExperimentDesigner;
    part council : GovernanceCouncil;
    part sandbox : SandboxFacility;
    part monitor : TelemetryMonitor;
    part rollbackManager : RollbackManager;
    part ledger : PublicLedger;

    port opportunityInput : ProposalPort;
    port assessmentOutput : AssessmentPort;
    port governanceOutput : DecisionPort;
    port experimentControl : ExperimentPort;
    port monitoringOutput : MonitoringPort;
    port rollbackControl : RollbackPort;

    connect opportunityInput to scanner.proposals;
    connect scanner.proposals to model.assessment;
    connect model.assessment to designer.assessment;
    connect model.assessment to council.decision;
    connect designer.experiment to sandbox.experiment;
    connect council.decision to sandbox.experiment;
    connect sandbox.experiment to monitor.monitor;
    connect monitor.monitor to council.decision;
    connect monitor.monitor to rollbackManager.rollback;
    connect council.decision to ledger.decisionLog;
    connect rollbackManager.rollback to council.decision;

    exhibit state lifecycleBehavior : InnovationLifecycle;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : ProactionaryInnovationSystem;
    require constraint {
      system.minimumExpectedBenefit >= 55.0
    }
  }

  requirement def ProactionaryBiasRequirement {
    subject proposal : InnovationProposal;
    subject risk : RiskEstimate;
    subject benefit : BenefitEstimate;
    require constraint {
      benefit.directBenefit + benefit.learningBenefit + benefit.publicBenefit > risk.safetyRisk + risk.privacyRisk + risk.socialRisk
    }
  }

  requirement def BoundedExperimentRequirement {
    subject plan : ExperimentPlan;
    require constraint {
      plan.duration <= 90.0 and plan.rollbackTimeLimit <= 24.0 and plan.maxParticipants <= 10000
    }
  }

  requirement def ReversibilityRequirement {
    subject proposal : InnovationProposal;
    require constraint {
      proposal.reversibility >= 0.65
    }
  }

  requirement def ProportionalPrecautionRequirement {
    subject risk : RiskEstimate;
    require constraint {
      risk.safetyRisk <= 70.0 and risk.privacyRisk <= 60.0 and risk.environmentalRisk <= 50.0
    }
  }

  requirement def ContinuousMonitoringRequirement {
    subject system : ProactionaryInnovationSystem;
    require constraint {
      system.monitoringInterval <= 4.0
    }
  }

  requirement def RollbackRequirement {
    subject plan : ExperimentPlan;
    subject harm : HarmSignal;
    require constraint {
      harm.severity <= 50.0 or plan.rollbackTimeLimit <= 24.0
    }
  }

  requirement def TransparencyRequirement {
    subject ledger : PublicLedger;
    require constraint {
      ledger.auditLatency <= 24.0 and ledger.retainedRecords >= 1000
    }
  }

  requirement def HumanGovernanceRequirement {
    subject decision : GovernanceDecision;
    require constraint {
      decision.rationale != ""
    }
  }

  satisfy PrimaryFunctionRequirement by ProactionaryInnovationSystem;
  satisfy ContinuousMonitoringRequirement by ProactionaryInnovationSystem;
  satisfy TransparencyRequirement by PublicLedger;
  satisfy RollbackRequirement by RollbackManager;
  satisfy HumanGovernanceRequirement by GovernanceCouncil;
}