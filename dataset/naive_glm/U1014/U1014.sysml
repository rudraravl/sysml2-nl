package TechnologyGovernanceSystem {

    import ScalarValues::*;

    // ===== Value Types =====

    value def MaturityLevel :> Real {
        doc /* 0.0 = initial concept, 1.0 = full deployment */;
    }

    value def AdoptionRate :> Real {
        doc /* Fraction of target population adopting per cycle */;
    }

    value def IntegrationDepth :> Real {
        doc /* 0.0 = isolated, 1.0 = deeply embedded in infrastructure */;
    }

    value def CertaintyLevel :> Real {
        doc /* 0.0 = no understanding, 1.0 = complete understanding */;
    }

    value def ControlLevel :> Real {
        doc /* 0.0 = no control, 1.0 = full regulatory/technical/economic control */;
    }

    value def RiskScore :> Real {
        doc /* 0.0 = no risk, 1.0 = maximum risk */;
    }

    value def BenefitScore :> Real {
        doc /* 0.0 = no benefit, 1.0 = maximum benefit */;
    }

    value def KnowledgeCompleteness :> Real {
        doc /* 0.0 = incomplete, 1.0 = complete */;
    }

    value def KnowledgeReliability :> Real {
        doc /* 0.0 = unreliable, 1.0 = fully reliable */;
    }

    value def EnvironmentalImpact :> Real;
    value def EconomicImpact :> Real;
    value def SocialImpact :> Real;
    value def EthicalImpact :> Real;

    value def ResourceAllocation :> Real {
        doc /* Budget fraction 0.0 to 1.0 */;
    }

    value def Priority :> Real {
        doc /* 0.0 = low, 1.0 = critical */;
    }

    // ===== Enumerations =====

    enum def InterventionType {
        continueMonitoring;
        fundResearch;
        createRegulation;
        restrictUse;
        redirectResearch;
        provideIncentives;
    }

    enum def TechnologyPhase {
        concept;
        prototype;
        earlyAdoption;
        widespreadAdoption;
        embedded;
    }

    enum def ImpactDomain {
        environmental;
        economic;
        social;
        ethical;
    }

    // ===== Item Types =====

    item def TechnologyProfile {
        attribute technologyName : String;
        attribute maturity : MaturityLevel;
        attribute adoptionRate : AdoptionRate;
        attribute integrationDepth : IntegrationDepth;
        attribute phase : TechnologyPhase;
    }

    item def MonitoringData {
        attribute profile : TechnologyProfile;
        attribute timestamp : String;
        attribute scanCycleId : Integer;
    }

    item def ImpactAssessment {
        attribute environmentalImpact : EnvironmentalImpact;
        attribute economicImpact : EconomicImpact;
        attribute socialImpact : SocialImpact;
        attribute ethicalImpact : EthicalImpact;
        attribute knowledgeCompleteness : KnowledgeCompleteness;
        attribute knowledgeReliability : KnowledgeReliability;
        attribute overallRisk : RiskScore;
        attribute overallBenefit : BenefitScore;
        attribute assessmentId : Integer;
    }

    item def DilemmaEvaluation {
        attribute certainty : CertaintyLevel;
        attribute control : ControlLevel;
        attribute risk : RiskScore;
        attribute benefit : BenefitScore;
        attribute interventionNeeded : Boolean;
        attribute recommendedIntervention : InterventionType;
        attribute rationale : String;
        attribute evaluationId : Integer;
    }

    item def InterventionDirective {
        attribute interventionType : InterventionType;
        attribute priority : Priority;
        attribute resourceAllocation : ResourceAllocation;
        attribute description : String;
        attribute targetTechnology : String;
        attribute directiveId : Integer;
    }

    // ===== Port Definitions =====

    port def MonitoringDataOut {
        out monitoringData : MonitoringData;
    }

    port def MonitoringDataIn {
        in monitoringData : MonitoringData;
    }

    port def ImpactAssessmentOut {
        out assessment : ImpactAssessment;
    }

    port def ImpactAssessmentIn {
        in assessment : ImpactAssessment;
    }

    port def DilemmaEvaluationOut {
        out evaluation : DilemmaEvaluation;
    }

    port def DilemmaEvaluationIn {
        in evaluation : DilemmaEvaluation;
    }

    port def InterventionDirectiveOut {
        out directive : InterventionDirective;
    }

    port def InterventionDirectiveIn {
        in directive : InterventionDirective;
    }

    // ===== Technology Monitor =====

    part def TechnologyMonitor {
        port monitoringOut : MonitoringDataOut;

        attribute currentProfile : TechnologyProfile;
        attribute scanCycleId : Integer = 0;
        attribute scanInterval : Real = 1.0;

        action scanTechnology(technologyName : String) :> Actions::Action {
            out profile : TechnologyProfile;
        }

        action assessMaturity(in profile : TechnologyProfile) :> Actions::Action {
            out maturity : MaturityLevel;
        }

        action measureAdoption(in profile : TechnologyProfile) :> Actions::Action {
            out adoptionRate : AdoptionRate;
        }

        action assessIntegration(in profile : TechnologyProfile) :> Actions::Action {
            out integrationDepth : IntegrationDepth;
        }

        action determinePhase(in maturity : MaturityLevel, in adoptionRate : AdoptionRate, in integrationDepth : IntegrationDepth) :> Actions::Action {
            out phase : TechnologyPhase;
        }

        action emitMonitoringData(in profile : TechnologyProfile, in cycleId : Integer) :> Actions::Action {
            out data : MonitoringData;
        }

        state monitorBehavior {
            entry action scanTechnology(currentProfile.technologyName);

            state Scanning {
                do scanTechnology(currentProfile.technologyName);
                transition to EvaluatingMaturity;
            }

            state EvaluatingMaturity {
                do assessMaturity(currentProfile);
                transition to MeasuringAdoption;
            }

            state MeasuringAdoption {
                do measureAdoption(currentProfile);
                transition to AssessingIntegration;
            }

            state AssessingIntegration {
                do assessIntegration(currentProfile);
                transition to DeterminingPhase;
            }

            state DeterminingPhase {
                do determinePhase(currentProfile.maturity, currentProfile.adoptionRate, currentProfile.integrationDepth);
                transition to EmittingData;
            }

            state EmittingData {
                do emitMonitoringData(currentProfile, scanCycleId);
                transition to Scanning;
            }
        }
    }

    // ===== Impact Analyzer =====

    part def ImpactAnalyzer {
        port analyzerIn : MonitoringDataIn;
        port analyzerOut : ImpactAssessmentOut;

        attribute currentAssessment : ImpactAssessment;
        attribute assessmentId : Integer = 0;

        action evaluateEnvironmentalImpact(in data : MonitoringData) :> Actions::Action {
            out impact : EnvironmentalImpact;
        }

        action evaluateEconomicImpact(in data : MonitoringData) :> Actions::Action {
            out impact : EconomicImpact;
        }

        action evaluateSocialImpact(in data : MonitoringData) :> Actions::Action {
            out impact : SocialImpact;
        }

        action evaluateEthicalImpact(in data : MonitoringData) :> Actions::Action {
            out impact : EthicalImpact;
        }

        action assessKnowledgeQuality(in data : MonitoringData) :> Actions::Action {
            out completeness : KnowledgeCompleteness;
            out reliability : KnowledgeReliability;
        }

        action computeOverallRisk(in envImpact : EnvironmentalImpact, in ecoImpact : EconomicImpact, in socImpact : SocialImpact, in ethImpact : EthicalImpact) :> Actions::Action {
            out risk : RiskScore;
        }

        action computeOverallBenefit(in envImpact : EnvironmentalImpact, in ecoImpact : EconomicImpact, in socImpact : SocialImpact, in ethImpact : EthicalImpact) :> Actions::Action {
            out benefit : BenefitScore;
        }

        action emitAssessment(in assessment : ImpactAssessment) :> Actions::Action {
        }

        state analyzerBehavior {
            entry action receiveData();

            state ReceivingData {
                transition to AnalyzingEnvironmentalImpact;
            }

            state AnalyzingEnvironmentalImpact {
                do evaluateEnvironmentalImpact(analyzerIn.monitoringData);
                transition to AnalyzingEconomicImpact;
            }

            state AnalyzingEconomicImpact {
                do evaluateEconomicImpact(analyzerIn.monitoringData);
                transition to AnalyzingSocialImpact;
            }

            state AnalyzingSocialImpact {
                do evaluateSocialImpact(analyzerIn.monitoringData);
                transition to AnalyzingEthicalImpact;
            }

            state AnalyzingEthicalImpact {
                do evaluateEthicalImpact(analyzerIn.monitoringData);
                transition to AssessingKnowledgeQuality;
            }

            state AssessingKnowledgeQuality {
                do assessKnowledgeQuality(analyzerIn.monitoringData);
                transition to ComputingOverallScores;
            }

            state ComputingOverallScores {
                do computeOverallRisk(currentAssessment.environmentalImpact, currentAssessment.economicImpact, currentAssessment.socialImpact, currentAssessment.ethicalImpact);
                do computeOverallBenefit(currentAssessment.environmentalImpact, currentAssessment.economicImpact, currentAssessment.socialImpact, currentAssessment.ethicalImpact);
                transition to EmittingAssessment;
            }

            state EmittingAssessment {
                do emitAssessment(currentAssessment);
                transition to ReceivingData;
            }
        }
    }

    // ===== Dilemma Resolver =====

    part def DilemmaResolver {
        port resolverIn : ImpactAssessmentIn;
        port resolverOut : DilemmaEvaluationOut;

        attribute certaintyThreshold : CertaintyLevel = 0.5;
        attribute controlThreshold : ControlLevel = 0.5;
        attribute riskTolerance : RiskScore = 0.3;
        attribute benefitThreshold : BenefitScore = 0.6;
        attribute evaluationId : Integer = 0;

        action evaluateCertainty(in assessment : ImpactAssessment) :> Actions::Action {
            out certainty : CertaintyLevel;
        }

        action evaluateControl(in assessment : ImpactAssessment) :> Actions::Action {
            out control : ControlLevel;
        }

        action weighRiskBenefit(in assessment : ImpactAssessment, in certainty : CertaintyLevel, in control : ControlLevel) :> Actions::Action {
            out adjustedRisk : RiskScore;
            out adjustedBenefit : BenefitScore;
        }

        action determineIntervention(in certainty : CertaintyLevel, in control : ControlLevel, in risk : RiskScore, in benefit : BenefitScore) :> Actions::Action {
            out interventionNeeded : Boolean;
            out recommendedIntervention : InterventionType;
            out rationale : String;
        }

        action emitEvaluation(in evaluation : DilemmaEvaluation) :> Actions::Action {
        }

        state resolverBehavior {
            entry action receiveAssessment();

            state ReceivingAssessment {
                transition to EvaluatingCertainty;
            }

            state EvaluatingCertainty {
                do evaluateCertainty(resolverIn.assessment);
                transition to EvaluatingControl;
            }

            state EvaluatingControl {
                do evaluateControl(resolverIn.assessment);
                transition to WeighingRiskBenefit;
            }

            state WeighingRiskBenefit {
                do weighRiskBenefit(resolverIn.assessment, evaluateCertainty.certainty, evaluateControl.control);
                transition to DeterminingIntervention;
            }

            state DeterminingIntervention {
                do determineIntervention(evaluateCertainty.certainty, evaluateControl.control, weighRiskBenefit.adjustedRisk, weighRiskBenefit.adjustedBenefit);
                transition to EmittingEvaluation;
            }

            state EmittingEvaluation {
                do emitEvaluation(currentEvaluation);
                transition to ReceivingAssessment;
            }
        }

        attribute currentEvaluation : DilemmaEvaluation;
    }

    // ===== Intervention Executor =====

    part def InterventionExecutor {
        port executorIn : DilemmaEvaluationIn;
        port executorOut : InterventionDirectiveOut;

        attribute activeDirectives : InterventionDirective[0..*];
        attribute directiveId : Integer = 0;

        action interpretDirective(in evaluation : DilemmaEvaluation) :> Actions::Action {
            out interventionType : InterventionType;
        }

        action selectAction(in interventionType : InterventionType) :> Actions::Action {
            out description : String;
        }

        action allocateResources(in interventionType : InterventionType, in priority : Priority) :> Actions::Action {
            out resourceAllocation : ResourceAllocation;
        }

        action executeIntervention(in interventionType : InterventionType, in description : String, in resourceAllocation : ResourceAllocation) :> Actions::Action {
            out directive : InterventionDirective;
        }

        action emitDirective(in directive : InterventionDirective) :> Actions::Action {
        }

        state executorBehavior {
            entry action receiveEvaluation();

            state ReceivingEvaluation {
                transition to InterpretingDirective;
            }

            state InterpretingDirective {
                do interpretDirective(executorIn.evaluation);
                transition to SelectingAction;
            }

            state SelectingAction {
                do selectAction(interpretDirective.interventionType);
                transition to AllocatingResources;
            }

            state AllocatingResources {
                do allocateResources(interpretDirective.interventionType, executorIn.evaluation.risk);
                transition to ExecutingIntervention;
            }

            state ExecutingIntervention {
                do executeIntervention(interpretDirective.interventionType, selectAction.description, allocateResources.resourceAllocation);
                transition to EmittingDirective;
            }

            state EmittingDirective {
                do emitDirective(executeIntervention.directive);
                transition to ReceivingEvaluation;
            }
        }
    }

    // ===== Technology Governance System =====

    part def TechnologyGovernanceSystem {
        port governanceInput : MonitoringDataIn;
        port governanceOutput : InterventionDirectiveOut;

        part monitor : TechnologyMonitor {
            port monitoringOut : MonitoringDataOut;
        }

        part analyzer : ImpactAnalyzer {
            port analyzerIn : MonitoringDataIn;
            port analyzerOut : ImpactAssessmentOut;
        }

        part resolver : DilemmaResolver {
            port resolverIn : ImpactAssessmentIn;
            port resolverOut : DilemmaEvaluationOut;
        }

        part executor : InterventionExecutor {
            port executorIn : DilemmaEvaluationIn;
            port executorOut : InterventionDirectiveOut;
        }

        connect monitor.monitoringOut to analyzer.analyzerIn;
        connect analyzer.analyzerOut to resolver.resolverIn;
        connect resolver.resolverOut to executor.executorIn;
        connect executor.executorOut to governanceOutput;

        action runGovernanceCycle(in monitoringData : MonitoringData) :> Actions::Action {
            out directive : InterventionDirective;
        }

        state governanceCycle {
            entry action initialize();

            state Idle {
                transition to Active
                    when governanceInput.monitoringData != null;
            }

            state Active {
                do runGovernanceCycle(governanceInput.monitoringData);
                transition to Idle
                    when executor.executorOut.directive == null;
            }
        }
    }

    // ===== Requirements =====

    requirement def GovernanceRequirement {
        doc /* The system shall guide technological innovation to maximize societal benefits while preemptively mitigating potential harm. */;
    }

    requirement def CollingridgeDilemmaRequirement :> GovernanceRequirement {
        doc /* The system shall identify the optimal intervention window: after enough is known to make an informed decision, but before control is lost. */;
        attribute maxCertaintyThreshold : CertaintyLevel = 0.8;
        attribute minControlThreshold : ControlLevel = 0.2;
        constraint { certainty >= 0.3 and control >= 0.2 }
    }

    requirement def MonitoringRequirement :> GovernanceRequirement {
        doc /* The Technology Monitor shall continuously scan the technological landscape and measure maturity, adoption rate, and integration depth. */;
        attribute requiredScanInterval : Real = 1.0;
        constraint { scanInterval <= requiredScanInterval }
    }

    requirement def AnalysisRequirement :> GovernanceRequirement {
        doc /* The Impact Analyzer shall evaluate environmental, economic, social, and ethical impacts, and assess knowledge completeness and reliability. */;
        attribute minKnowledgeCompleteness : KnowledgeCompleteness = 0.0;
        attribute minKnowledgeReliability : KnowledgeReliability = 0.0;
    }

    requirement def ResolutionRequirement :> GovernanceRequirement {
        doc /* The Dilemma Resolver shall weigh risks and benefits against certainty and control, and determine if intervention is needed and what form it should take. */;
        attribute certaintyThreshold : CertaintyLevel = 0.5;
        attribute controlThreshold : ControlLevel = 0.5;
    }

    requirement def ExecutionRequirement :> GovernanceRequirement {
        doc /* The Intervention Executor shall implement directives including research funding, regulation creation, use restriction, research redirection, and economic incentives. */;
    }

    requirement def ContinuousCycleRequirement :> GovernanceRequirement {
        doc /* The system shall operate as a continuous cycle of monitoring, analysis, resolution, and execution. */;
    }

    requirement governanceReq : GovernanceRequirement;
    requirement collingridgeReq : CollingridgeDilemmaRequirement;
    requirement monitoringReq : MonitoringRequirement;
    requirement analysisReq : AnalysisRequirement;
    requirement resolutionReq : ResolutionRequirement;
    requirement executionReq : ExecutionRequirement;
    requirement cycleReq : ContinuousCycleRequirement;

    // ===== Satisfaction =====

    satisfaction satisfyMonitoring : monitoringReq {
        subject TechnologyGovernanceSystem.monitor;
    }

    satisfaction satisfyAnalysis : analysisReq {
        subject TechnologyGovernanceSystem.analyzer;
    }

    satisfaction satisfyResolution : resolutionReq {
        subject TechnologyGovernanceSystem.resolver;
    }

    satisfaction satisfyExecution : executionReq {
        subject TechnologyGovernanceSystem.executor;
    }

    satisfaction satisfyCollingridge : collingridgeReq {
        subject TechnologyGovernanceSystem;
    }

    satisfaction satisfyCycle : cycleReq {
        subject TechnologyGovernanceSystem;
    }

    satisfaction satisfyGovernance : governanceReq {
        subject TechnologyGovernanceSystem;
    }
}
