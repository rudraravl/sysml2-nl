package TechnologicalUnemploymentMitigationSystem {
    private import ScalarValues::*;

    value def EmploymentRate :> Real;
    value def AutomationGrowthRate :> Real;
    value def DisplacementRiskScore :> Real;
    value def BenefitAmount :> Real;
    value def JobMatchScore :> Real;
    value def WorkerCount :> Integer;

    item def WorkerProfile {
        attribute workerId : String;
        attribute sector : String;
        attribute skillSet : String;
    }

    item def EconomicIndicator {
        attribute employmentRate : EmploymentRate;
        attribute automationGrowth : AutomationGrowthRate;
        attribute sector : String;
        attribute workforceCount : WorkerCount;
    }

    item def DisplacementAlert {
        attribute alertId : String;
        attribute worker : WorkerProfile;
        attribute riskScore : DisplacementRiskScore;
        attribute reason : String;
    }

    item def InterventionPlan {
        attribute planId : String;
        attribute worker : WorkerProfile;
        attribute requiresRetraining : Boolean;
        attribute requiresBenefits : Boolean;
        attribute priority : Integer;
    }

    item def TrainingCompletion {
        attribute worker : WorkerProfile;
        attribute programId : String;
        attribute newSkillSet : String;
        attribute certified : Boolean;
    }

    item def FinancialAid {
        attribute worker : WorkerProfile;
        attribute amount : BenefitAmount;
        attribute durationWeeks : Integer;
    }

    item def JobOpening {
        attribute jobId : String;
        attribute title : String;
        attribute requiredSkillSet : String;
        attribute employer : String;
    }

    item def JobMatchResult {
        attribute worker : WorkerProfile;
        attribute jobOpening : JobOpening;
        attribute matchScore : JobMatchScore;
    }

    port def EconomicDataOut {
        out indicators : EconomicIndicator;
    }

    port def EconomicDataIn {
        in indicators : EconomicIndicator;
    }

    port def DisplacementAlertOut {
        out alerts : DisplacementAlert;
    }

    port def DisplacementAlertIn {
        in alerts : DisplacementAlert;
    }

    port def InterventionPlanOut {
        out plans : InterventionPlan;
    }

    port def InterventionPlanIn {
        in plans : InterventionPlan;
    }

    port def TrainingCompletionOut {
        out completion : TrainingCompletion;
    }

    port def TrainingCompletionIn {
        in completion : TrainingCompletion;
    }

    port def FinancialAidOut {
        out aid : FinancialAid;
    }

    port def FinancialAidIn {
        in aid : FinancialAid;
    }

    port def JobOpeningOut {
        out openings : JobOpening;
    }

    port def JobOpeningIn {
        in openings : JobOpening;
    }

    port def JobMatchResultOut {
        out result : JobMatchResult;
    }

    part def EconomicMonitor {
        port dataOut : EconomicDataOut;
        action monitorEconomy {
            out indicators : EconomicIndicator;
        }
    }

    part def DisplacementAnalyzer {
        port dataIn : EconomicDataIn;
        port alertOut : DisplacementAlertOut;
        action analyzeDisplacement {
            in indicators : EconomicIndicator;
            out alerts : DisplacementAlert;
        }
    }

    part def PolicyCoordinator {
        port alertIn : DisplacementAlertIn;
        port planOut : InterventionPlanOut;
        action coordinateIntervention {
            in alerts : DisplacementAlert;
            out plans : InterventionPlan;
        }
    }

    part def RetrainingCenter {
        port planIn : InterventionPlanIn;
        port completionOut : TrainingCompletionOut;
        action deliverTraining {
            in plans : InterventionPlan;
            out completion : TrainingCompletion;
        }
    }

    part def BenefitDistributor {
        port planIn : InterventionPlanIn;
        port aidOut : FinancialAidOut;
        action disburseAid {
            in plans : InterventionPlan;
            out aid : FinancialAid;
        }
    }

    part def JobMatchingEngine {
        port completionIn : TrainingCompletionIn;
        port openingIn : JobOpeningIn;
        port resultOut : JobMatchResultOut;
        action matchWorkerToJob {
            in completion : TrainingCompletion;
            in openings : JobOpening;
            out result : JobMatchResult;
        }
    }

    part def LaborMarket {
        port openingOut : JobOpeningOut;
    }

    state machine def WorkerLifecycle {
        state employed;
        state displaced;
        state retraining;
        state receivingBenefits;
        state reemployed;
        transition from employed to displaced;
        transition from displaced to retraining;
        transition from displaced to receivingBenefits;
        transition from retraining to reemployed;
        transition from receivingBenefits to reemployed;
    }

    part def Worker {
        attribute profile : WorkerProfile;
        port aidIn : FinancialAidIn;
        exhibit workerLifecycle : WorkerLifecycle;
    }

    part def MitigationSystem {
        port matchedResultsOut : JobMatchResultOut;

        part economicMonitor : EconomicMonitor;
        part displacementAnalyzer : DisplacementAnalyzer;
        part policyCoordinator : PolicyCoordinator;
        part retrainingCenter : RetrainingCenter;
        part benefitDistributor : BenefitDistributor;
        part jobMatchingEngine : JobMatchingEngine;
        part laborMarket : LaborMarket;
        part workers : Worker[*];

        flow economicDataFlow of EconomicIndicator
            from economicMonitor.dataOut.indicators
            to displacementAnalyzer.dataIn.indicators;

        flow displacementAlertFlow of DisplacementAlert
            from displacementAnalyzer.alertOut.alerts
            to policyCoordinator.alertIn.alerts;

        flow trainingPlanFlow of InterventionPlan
            from policyCoordinator.planOut.plans
            to retrainingCenter.planIn.plans;

        flow benefitPlanFlow of InterventionPlan
            from policyCoordinator.planOut.plans
            to benefitDistributor.planIn.plans;

        flow trainingCompletionFlow of TrainingCompletion
            from retrainingCenter.completionOut.completion
            to jobMatchingEngine.completionIn.completion;

        flow jobOpeningFlow of JobOpening
            from laborMarket.openingOut.openings
            to jobMatchingEngine.openingIn.openings;

        flow financialAidFlow of FinancialAid
            from benefitDistributor.aidOut.aid
            to workers.aidIn.aid;

        flow jobMatchResultFlow of JobMatchResult
            from jobMatchingEngine.resultOut.result
            to matchedResultsOut.result;
    }

    action def MitigationPipeline {
        action monitorEconomy {
            out indicators : EconomicIndicator;
        }
        then analyzeDisplacement;
        action analyzeDisplacement {
            in indicators : EconomicIndicator;
            out alerts : DisplacementAlert;
        }
        then coordinateIntervention;
        action coordinateIntervention {
            in alerts : DisplacementAlert;
            out plan : InterventionPlan;
        }
        then fork F {
            in plan;
            out plan1;
            out plan2;
        }
        flow coordinateIntervention.plan to F.plan;
        then provideRetraining;
        then distributeBenefits;
        flow F.plan1 to provideRetraining.plan;
        flow F.plan2 to distributeBenefits.plan;
        action provideRetraining {
            in plan : InterventionPlan;
            out completion : TrainingCompletion;
        }
        then M;
        action distributeBenefits {
            in plan : InterventionPlan;
            out aid : FinancialAid;
        }
        then M;
        merge M;
        then matchJobs;
        action matchJobs {
            in completion : TrainingCompletion;
            out result : JobMatchResult;
        }
        flow monitorEconomy.indicators to analyzeDisplacement.indicators;
        flow analyzeDisplacement.alerts to coordinateIntervention.alerts;
        flow provideRetraining.completion to matchJobs.completion;
    }

    part nationalMitigationSystem : MitigationSystem;

    requirement def MitigateUnemploymentRequirement {
        doc /* The system shall mitigate societal and economic impacts of technological unemployment by managing worker transitions. */
        subject system : MitigationSystem;
    }
    requirement def MonitorEconomyRequirement {
        doc /* The Economic Monitor shall track national employment rates and automation growth across industry sectors. */
        subject monitor : EconomicMonitor;
    }
    requirement def AnalyzeDisplacementRequirement {
        doc /* The Displacement Analyzer shall identify workers displaced by or at high risk from new technologies. */
        subject analyzer : DisplacementAnalyzer;
    }
    requirement def CoordinateInterventionRequirement {
        doc /* The Policy Coordinator shall assess displaced workers and direct them to appropriate support pathways. */
        subject coordinator : PolicyCoordinator;
    }
    requirement def ProvideRetrainingRequirement {
        doc /* The Retraining Center shall upskill workers for high-demand jobs. */
        subject center : RetrainingCenter;
    }
    requirement def DistributeBenefitsRequirement {
        doc /* The Benefit Distributor shall disburse financial aid to eligible workers during transition. */
        subject distributor : BenefitDistributor;
    }
    requirement def MatchJobsRequirement {
        doc /* The Job Matching Engine shall match retrained workers with suitable job openings in the market. */
        subject engine : JobMatchingEngine;
    }

    requirement topMitigationReq : MitigateUnemploymentRequirement {
        subject :>> system = nationalMitigationSystem;
    }
    requirement monitorReq : MonitorEconomyRequirement {
        subject :>> monitor = nationalMitigationSystem.economicMonitor;
    }
    requirement analyzerReq : AnalyzeDisplacementRequirement {
        subject :>> analyzer = nationalMitigationSystem.displacementAnalyzer;
    }
    requirement coordinatorReq : CoordinateInterventionRequirement {
        subject :>> coordinator = nationalMitigationSystem.policyCoordinator;
    }
    requirement retrainingReq : ProvideRetrainingRequirement {
        subject :>> center = nationalMitigationSystem.retrainingCenter;
    }
    requirement benefitReq : DistributeBenefitsRequirement {
        subject :>> distributor = nationalMitigationSystem.benefitDistributor;
    }
    requirement jobMatchReq : MatchJobsRequirement {
        subject :>> engine = nationalMitigationSystem.jobMatchingEngine;
    }
}
