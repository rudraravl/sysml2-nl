package TechnologicalUnemploymentSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percent : Real {
        unit = "%";
    }

    attribute def PeopleCount : Integer;

    attribute def JobsCount : Integer;

    attribute def CurrencyUSD : Real {
        unit = "$";
    }

    attribute def CurrencyPerMonth : Real {
        unit = "$/mo";
    }

    attribute def HoursPerWeek : Real {
        unit = "h/wk";
    }

    attribute def Months : Real {
        unit = "mo";
    }

    attribute def SkillIndex : Real {
        range = 0.0 .. 1.0;
    }

    attribute def RiskIndex : Real {
        range = 0.0 .. 1.0;
    }

    attribute def AutomationReadinessIndex : Real {
        range = 0.0 .. 1.0;
    }

    attribute def ConfidenceIndex : Real {
        range = 0.0 .. 1.0;
    }

    item def LaborMarketData {
        attribute totalWorkers : PeopleCount;
        attribute employedWorkers : PeopleCount;
        attribute unemployedWorkers : PeopleCount;
        attribute openJobs : JobsCount;
        attribute medianWage : CurrencyPerMonth;
        attribute unemploymentRate : Percent;
        attribute reportingPeriod : Months;
    }

    item def OccupationAutomationProfile {
        attribute occupationCode : String;
        attribute occupationName : String;
        attribute currentJobs : JobsCount;
        attribute automationExposure : RiskIndex;
        attribute reskillDifficulty : SkillIndex;
        attribute averageWage : CurrencyPerMonth;
        attribute projectedDisplacedJobs : JobsCount;
    }

    item def WorkerProfile {
        attribute workerId : String;
        attribute currentOccupation : String;
        attribute monthlyIncome : CurrencyPerMonth;
        attribute weeklyWorkHours : HoursPerWeek;
        attribute digitalSkillLevel : SkillIndex;
        attribute transferableSkillLevel : SkillIndex;
        attribute displacementRisk : RiskIndex;
        attribute preferredTrainingMonths : Months;
    }

    item def InterventionPlan {
        attribute targetOccupation : String;
        attribute trainingDuration : Months;
        attribute stipendAmount : CurrencyPerMonth;
        attribute placementProbability : Percent;
        attribute estimatedMonthlyWageAfterPlacement : CurrencyPerMonth;
    }

    item def AutomationImpactForecast {
        attribute forecastHorizon : Months;
        attribute jobsAtHighRisk : JobsCount;
        attribute expectedDisplacedWorkers : PeopleCount;
        attribute expectedNewJobs : JobsCount;
        attribute netEmploymentChange : JobsCount;
        attribute confidence : ConfidenceIndex;
    }

    item def PolicyRecommendation {
        attribute title : String;
        attribute affectedWorkers : PeopleCount;
        attribute monthlyBudget : CurrencyUSD;
        attribute expectedReemploymentRate : Percent;
        attribute expectedPovertyReduction : Percent;
    }

    port def LaborMarketDataIn {
        in item laborMarketData : LaborMarketData;
    }

    port def OccupationProfileIn {
        in item occupationProfile : OccupationAutomationProfile;
    }

    port def WorkerProfileIn {
        in item workerProfile : WorkerProfile;
    }

    port def ForecastOut {
        out item forecast : AutomationImpactForecast;
    }

    port def InterventionPlanOut {
        out item interventionPlan : InterventionPlan;
    }

    port def PolicyRecommendationOut {
        out item policyRecommendation : PolicyRecommendation;
    }

    part def TechnologicalUnemploymentResponseSystem {
        doc
        /* Primary function: monitor labor displacement caused by automation, estimate unemployment risk, and coordinate training, placement, and policy interventions that reduce long-term technological unemployment. */

        port laborMarketInput : LaborMarketDataIn;
        port occupationInput : OccupationProfileIn;
        port workerInput : WorkerProfileIn;
        port forecastOutput : ForecastOut;
        port interventionOutput : InterventionPlanOut;
        port policyOutput : PolicyRecommendationOut;

        attribute maximumAcceptedForecastError : Percent = 8.0 [%];
        attribute targetReemploymentRate : Percent = 70.0 [%];
        attribute targetInterventionStartTime : Months = 1.0 [mo];
        attribute maximumTrainingDuration : Months = 12.0 [mo];
        attribute minimumPlacementProbability : Percent = 55.0 [%];

        part dataAcquisition : LaborMarketDataAcquisition;
        part automationRiskEngine : AutomationRiskAssessmentEngine;
        part displacementForecaster : DisplacementForecastingEngine;
        part workerTransitionPlanner : WorkerTransitionPlanner;
        part trainingCoordinator : ReskillingProgramCoordinator;
        part placementCoordinator : EmploymentPlacementCoordinator;
        part policyOptimizer : SocialPolicyOptimizer;
        part outcomeMonitor : OutcomeMonitoringService;

        connect laborMarketInput.laborMarketData to dataAcquisition.rawLaborMarketData;
        connect occupationInput.occupationProfile to automationRiskEngine.occupationProfile;
        connect workerInput.workerProfile to automationRiskEngine.workerProfile;
        connect dataAcquisition.normalizedLaborMarketData to displacementForecaster.laborMarketData;
        connect automationRiskEngine.riskProfile to displacementForecaster.riskProfile;
        connect displacementForecaster.forecast to workerTransitionPlanner.forecast;
        connect automationRiskEngine.riskProfile to workerTransitionPlanner.workerRiskProfile;
        connect workerTransitionPlanner.interventionPlan to trainingCoordinator.plan;
        connect trainingCoordinator.completedTrainingRecord to placementCoordinator.trainingRecord;
        connect placementCoordinator.placementOutcome to outcomeMonitor.placementOutcome;
        connect displacementForecaster.forecast to policyOptimizer.forecast;
        connect outcomeMonitor.outcomeMetrics to policyOptimizer.outcomeMetrics;
        connect displacementForecaster.forecast to forecastOutput.forecast;
        connect workerTransitionPlanner.interventionPlan to interventionOutput.interventionPlan;
        connect policyOptimizer.policyRecommendation to policyOutput.policyRecommendation;

        perform action assessAndRespondToTechnologicalUnemployment;
        exhibit state responseLifecycle;
    }

    part def LaborMarketDataAcquisition {
        port input : LaborMarketDataIn;
        in item rawLaborMarketData : LaborMarketData;
        out item normalizedLaborMarketData : LaborMarketData;

        attribute updateInterval : Months = 1.0 [mo];
        attribute minimumCompleteness : Percent = 95.0 [%];

        action normalizeLaborMarketData {
            in item sourceData : LaborMarketData;
            out item normalizedData : LaborMarketData;
        }
    }

    part def AutomationRiskAssessmentEngine {
        port occupationInput : OccupationProfileIn;
        port workerInput : WorkerProfileIn;

        in item occupationProfile : OccupationAutomationProfile;
        in item workerProfile : WorkerProfile;
        out item riskProfile : WorkerProfile;

        attribute highRiskThreshold : RiskIndex = 0.70;
        attribute criticalRiskThreshold : RiskIndex = 0.85;
        attribute minimumSkillConfidence : ConfidenceIndex = 0.80;

        action computeDisplacementRisk {
            in item worker : WorkerProfile;
            in item occupation : OccupationAutomationProfile;
            out item assessedWorker : WorkerProfile;
        }
    }

    part def DisplacementForecastingEngine {
        in item laborMarketData : LaborMarketData;
        in item riskProfile : WorkerProfile;
        out item forecast : AutomationImpactForecast;

        attribute standardForecastHorizon : Months = 24.0 [mo];
        attribute confidenceTarget : ConfidenceIndex = 0.85;
        attribute minimumSampleSize : PeopleCount = 10000;

        action forecastAutomationImpact {
            in item market : LaborMarketData;
            in item workerRisk : WorkerProfile;
            out item impactForecast : AutomationImpactForecast;
        }
    }

    part def WorkerTransitionPlanner {
        in item forecast : AutomationImpactForecast;
        in item workerRiskProfile : WorkerProfile;
        out item interventionPlan : InterventionPlan;

        attribute maximumAllowedIncomeLoss : Percent = 15.0 [%];
        attribute maximumPreferredTrainingMonths : Months = 9.0 [mo];
        attribute defaultStipend : CurrencyPerMonth = 2200.0 [$/mo];

        action selectTransitionPath {
            in item worker : WorkerProfile;
            in item impactForecast : AutomationImpactForecast;
            out item plan : InterventionPlan;
        }
    }

    part def ReskillingProgramCoordinator {
        in item plan : InterventionPlan;
        out item completedTrainingRecord : InterventionPlan;

        attribute trainingCapacity : PeopleCount = 50000;
        attribute minimumCompletionRate : Percent = 75.0 [%];
        attribute learnerSupportBudget : CurrencyUSD = 120000000.0 [$];

        action enrollWorker {
            in item plan : InterventionPlan;
            out item activePlan : InterventionPlan;
        }

        action completeTraining {
            in item activePlan : InterventionPlan;
            out item completionRecord : InterventionPlan;
        }
    }

    part def EmploymentPlacementCoordinator {
        in item trainingRecord : InterventionPlan;
        out item placementOutcome : InterventionPlan;

        attribute employerPartnerCount : Integer = 1200;
        attribute targetPlacementTime : Months = 2.0 [mo];
        attribute minimumPostPlacementWage : CurrencyPerMonth = 3600.0 [$/mo];

        action matchWorkerToJob {
            in item completionRecord : InterventionPlan;
            out item placement : InterventionPlan;
        }
    }

    part def SocialPolicyOptimizer {
        in item forecast : AutomationImpactForecast;
        in item outcomeMetrics : PolicyRecommendation;
        out item policyRecommendation : PolicyRecommendation;

        attribute monthlyPolicyBudgetLimit : CurrencyUSD = 900000000.0 [$];
        attribute minimumExpectedReemploymentRate : Percent = 65.0 [%];
        attribute minimumPovertyReduction : Percent = 10.0 [%];

        action optimizePolicyPortfolio {
            in item impactForecast : AutomationImpactForecast;
            in item currentOutcomes : PolicyRecommendation;
            out item recommendation : PolicyRecommendation;
        }
    }

    part def OutcomeMonitoringService {
        in item placementOutcome : InterventionPlan;
        out item outcomeMetrics : PolicyRecommendation;

        attribute monitoringWindow : Months = 18.0 [mo];
        attribute minimumRetentionRate : Percent = 70.0 [%];

        action evaluateOutcomes {
            in item placement : InterventionPlan;
            out item policyMetrics : PolicyRecommendation;
        }
    }

    action def AssessAndRespondToTechnologicalUnemployment {
        in item marketData : LaborMarketData;
        in item occupationProfile : OccupationAutomationProfile;
        in item workerProfile : WorkerProfile;
        out item forecast : AutomationImpactForecast;
        out item interventionPlan : InterventionPlan;
        out item policyRecommendation : PolicyRecommendation;

        first start;
        then normalizeData;
        then assessAutomationRisk;
        then forecastDisplacement;
        then planWorkerTransition;
        then coordinateReskilling;
        then coordinatePlacement;
        then optimizePolicy;
        then publishOutputs;

        action normalizeData {
            in item marketData : LaborMarketData;
            out item normalizedMarketData : LaborMarketData;
        }

        action assessAutomationRisk {
            in item occupationProfile : OccupationAutomationProfile;
            in item workerProfile : WorkerProfile;
            out item assessedWorker : WorkerProfile;
        }

        action forecastDisplacement {
            in item normalizedMarketData : LaborMarketData;
            in item assessedWorker : WorkerProfile;
            out item forecast : AutomationImpactForecast;
        }

        action planWorkerTransition {
            in item forecast : AutomationImpactForecast;
            in item assessedWorker : WorkerProfile;
            out item interventionPlan : InterventionPlan;
        }

        action coordinateReskilling {
            in item interventionPlan : InterventionPlan;
            out item completedTraining : InterventionPlan;
        }

        action coordinatePlacement {
            in item completedTraining : InterventionPlan;
            out item placementOutcome : InterventionPlan;
        }

        action optimizePolicy {
            in item forecast : AutomationImpactForecast;
            in item placementOutcome : InterventionPlan;
            out item policyRecommendation : PolicyRecommendation;
        }

        action publishOutputs {
            in item forecast : AutomationImpactForecast;
            in item interventionPlan : InterventionPlan;
            in item policyRecommendation : PolicyRecommendation;
        }
    }

    state def TechnologicalUnemploymentResponseLifecycle {
        state idle;
        state collectingData;
        state assessingRisk;
        state forecastingImpact;
        state planningInterventions;
        state executingReskilling;
        state matchingEmployment;
        state optimizingPolicy;
        state monitoringOutcomes;
        state completed;

        transition initial then idle;

        transition idle_to_collectingData
            first idle
            accept LaborMarketUpdate
            then collectingData;

        transition collectingData_to_assessingRisk
            first collectingData
            if dataCompleteness >= 95.0 [%]
            then assessingRisk;

        transition assessingRisk_to_forecastingImpact
            first assessingRisk
            if assessedDisplacementRisk >= 0.70
            then forecastingImpact;

        transition assessingRisk_to_monitoringOutcomes
            first assessingRisk
            if assessedDisplacementRisk < 0.70
            then monitoringOutcomes;

        transition forecastingImpact_to_planningInterventions
            first forecastingImpact
            if forecastConfidence >= 0.85
            then planningInterventions;

        transition planningInterventions_to_executingReskilling
            first planningInterventions
            if selectedTrainingDuration <= 12.0 [mo]
            then executingReskilling;

        transition executingReskilling_to_matchingEmployment
            first executingReskilling
            if trainingCompletionRate >= 75.0 [%]
            then matchingEmployment;

        transition matchingEmployment_to_optimizingPolicy
            first matchingEmployment
            if placementProbability >= 55.0 [%]
            then optimizingPolicy;

        transition optimizingPolicy_to_monitoringOutcomes
            first optimizingPolicy
            then monitoringOutcomes;

        transition monitoringOutcomes_to_completed
            first monitoringOutcomes
            if retentionRate >= 70.0 [%]
            then completed;

        transition monitoringOutcomes_to_planningInterventions
            first monitoringOutcomes
            if retentionRate < 70.0 [%]
            then planningInterventions;

        attribute dataCompleteness : Percent;
        attribute assessedDisplacementRisk : RiskIndex;
        attribute forecastConfidence : ConfidenceIndex;
        attribute selectedTrainingDuration : Months;
        attribute trainingCompletionRate : Percent;
        attribute placementProbability : Percent;
        attribute retentionRate : Percent;
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The system shall identify workers and occupations at risk of displacement from automation and produce coordinated forecasts, transition plans, and policy recommendations to reduce technological unemployment. */

        subject system : TechnologicalUnemploymentResponseSystem;

        require constraint {
            system.targetReemploymentRate >= 70.0 [%]
        }
    }

    requirement def ForecastAccuracyRequirement {
        subject system : TechnologicalUnemploymentResponseSystem;

        require constraint {
            system.maximumAcceptedForecastError <= 8.0 [%]
        }
    }

    requirement def InterventionTimelinessRequirement {
        subject system : TechnologicalUnemploymentResponseSystem;

        require constraint {
            system.targetInterventionStartTime <= 1.0 [mo]
        }
    }

    requirement def TrainingDurationRequirement {
        subject system : TechnologicalUnemploymentResponseSystem;

        require constraint {
            system.maximumTrainingDuration <= 12.0 [mo]
        }
    }

    requirement def PlacementEffectivenessRequirement {
        subject system : TechnologicalUnemploymentResponseSystem;

        require constraint {
            system.minimumPlacementProbability >= 55.0 [%]
        }
    }

    requirement def IncomeProtectionRequirement {
        doc
        /* The system shall prefer transition paths that limit expected worker income loss after reemployment. */

        subject planner : WorkerTransitionPlanner;

        require constraint {
            planner.maximumAllowedIncomeLoss <= 15.0 [%]
        }
    }

    part technologicalUnemploymentResponseSystem : TechnologicalUnemploymentResponseSystem {
        attribute maximumAcceptedForecastError = 8.0 [%];
        attribute targetReemploymentRate = 72.0 [%];
        attribute targetInterventionStartTime = 1.0 [mo];
        attribute maximumTrainingDuration = 12.0 [mo];
        attribute minimumPlacementProbability = 58.0 [%];

        perform action assessAndRespondToTechnologicalUnemployment : AssessAndRespondToTechnologicalUnemployment;
        exhibit state responseLifecycle : TechnologicalUnemploymentResponseLifecycle;
    }

    satisfy PrimaryFunctionRequirement by technologicalUnemploymentResponseSystem;
    satisfy ForecastAccuracyRequirement by technologicalUnemploymentResponseSystem;
    satisfy InterventionTimelinessRequirement by technologicalUnemploymentResponseSystem;
    satisfy TrainingDurationRequirement by technologicalUnemploymentResponseSystem;
    satisfy PlacementEffectivenessRequirement by technologicalUnemploymentResponseSystem;
    satisfy IncomeProtectionRequirement by technologicalUnemploymentResponseSystem.workerTransitionPlanner;
}