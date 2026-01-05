package TechnologicalUnemploymentSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def EmploymentRate {
        attribute value : Real;
    }
    
    attribute def AutomationIndex {
        attribute value : Real;
    }
    
    attribute def SkillLevel {
        attribute value : Real;
    }
    
    attribute def WorkforceCount {
        attribute value : Integer;
    }
    
    attribute def RetrainingCapacity {
        attribute value : Integer;
    }
    
    attribute def BenefitAmount {
        attribute value : Real;
    }
    
    enum def WorkerStatus {
        employed;
        displaced;
        retraining;
        reemployed;
        receiving_benefits;
    }
    
    enum def SectorType {
        manufacturing;
        services;
        technology;
        healthcare;
        education;
    }
    
    item def Worker {
        attribute id : String;
        attribute currentSkillLevel : SkillLevel;
        attribute status : WorkerStatus;
        attribute sector : SectorType;
        attribute yearsExperience : Real;
    }
    
    item def JobOpening {
        attribute title : String;
        attribute requiredSkillLevel : SkillLevel;
        attribute sector : SectorType;
        attribute salary : Real;
    }
    
    item def TrainingProgram {
        attribute name : String;
        attribute duration : Real;
        attribute targetSkillLevel : SkillLevel;
        attribute capacity : Integer;
    }
    
    item def AutomationTrend {
        attribute sector : SectorType;
        attribute automationIndex : AutomationIndex;
        attribute projectedDisplacement : WorkforceCount;
    }
    
    port def EconomicDataPort {
        in automationTrends : AutomationTrend[*];
        out employmentMetrics : EmploymentRate;
    }
    
    port def WorkerDataPort {
        in workers : Worker[*];
        out displacedWorkers : Worker[*];
    }
    
    port def JobMatchingPort {
        in jobOpenings : JobOpening[*];
        out placements : Worker[*];
    }
    
    port def TrainingPort {
        in enrollments : Worker[*];
        out graduates : Worker[*];
    }
    
    port def BenefitPort {
        in beneficiaries : Worker[*];
        out payments : BenefitAmount[*];
    }
    
    action def MonitorEconomicTrends {
        in trends : AutomationTrend[*];
        out employmentRate : EmploymentRate;
    }
    
    action def IdentifyDisplacedWorkers {
        in workers : Worker[*];
        in trends : AutomationTrend[*];
        out displaced : Worker[*];
    }
    
    action def RetrainWorkers {
        in enrolledWorkers : Worker[*];
        out trainedWorkers : Worker[*];
    }
    
    action def MatchWorkersToJobs {
        in availableWorkers : Worker[*];
        in openings : JobOpening[*];
        out matched : Worker[*];
    }
    
    action def ProvideBenefits {
        in recipients : Worker[*];
        out disbursements : BenefitAmount[*];
    }
    
    action def AssessWorkerNeeds {
        in worker : Worker;
        out needsRetraining : Boolean;
        out eligibleForBenefits : Boolean;
    }
    
    part def EconomicMonitor {
        attribute currentEmploymentRate : EmploymentRate;
        attribute automationGrowthRate : Real;
        
        port economicData : EconomicDataPort;
    }
    
    part def DisplacementAnalyzer {
        attribute displacementThreshold : Real;
        
        port workerInput : WorkerDataPort;
        port economicInput : EconomicDataPort;
    }
    
    part def RetrainingCenter {
        attribute maxCapacity : RetrainingCapacity;
        attribute availablePrograms : TrainingProgram[*];
        
        port trainingInterface : TrainingPort;
    }
    
    part def JobMatchingEngine {
        attribute matchingAlgorithmVersion : String;
        
        port workerInput : WorkerDataPort;
        port jobInterface : JobMatchingPort;
    }
    
    part def BenefitDistributor {
        attribute totalBudget : Real;
        attribute benefitDuration : Real;
        
        port benefitInterface : BenefitPort;
    }
    
    part def PolicyCoordinator {
        attribute interventionStrategy : String;
        attribute responseTime : Real;
        
        port economicInput : EconomicDataPort;
        port workerData : WorkerDataPort;
    }
    
    action def ManageTechnologicalTransition {
        in incomingWorkers : Worker[*];
        in economicConditions : AutomationTrend[*];
        out reemployedWorkers : Worker[*];
        out supportedWorkers : Worker[*];
        
        private attribute currentDisplaced : Worker[*];
        private attribute inTraining : Worker[*];
        
        first start;
        then merge continuousOperation;
        
        then action monitor : MonitorEconomicTrends {
            in trends = economicConditions;
            out employmentRate;
        }
        
        then action identify : IdentifyDisplacedWorkers {
            in workers = incomingWorkers;
            in trends = economicConditions;
            out displaced;
        }
        
        then assign currentDisplaced := identify.displaced;
        
        then action assessEach : AssessWorkerNeeds[*] {
            in worker;
            out needsRetraining;
            out eligibleForBenefits;
        }
        
        then decide;
            if assessEach.needsRetraining then enrollInTraining;
            if assessEach.eligibleForBenefits then provideBenefits;
        
        action enrollInTraining : RetrainWorkers {
            in enrolledWorkers = currentDisplaced;
            out trainedWorkers;
        }
        then action matchRetrained : MatchWorkersToJobs {
            in availableWorkers = enrollInTraining.trainedWorkers;
            in openings[*];
            out matched;
        }
        then assign reemployedWorkers := matchRetrained.matched;
        then continuousOperation;
        
        action provideBenefits : ProvideBenefits {
            in recipients = currentDisplaced;
            out disbursements[*];
        }
        then assign supportedWorkers := provideBenefits.recipients;
        then continuousOperation;
        
        then decide;
            if monitor.employmentRate.value < 90.0 then continuousOperation;
            if monitor.employmentRate.value >= 90.0 then complete;
        
        action complete;
        then done;
    }
    
    state def WorkerLifecycle {
        entry; then employed;
        
        state employed {
            entry assign workerStatus = WorkerStatus::employed;
        }
        
        transition automationOccurs
            first employed
            accept AutomationEvent
            then displaced;
        
        state displaced {
            entry assign workerStatus = WorkerStatus::displaced;
        }
        
        transition enrolls
            first displaced
            accept EnrollmentEvent
            then retraining;
        
        transition receivesSupport
            first displaced
            accept BenefitApprovalEvent
            then receiving_benefits;
        
        state retraining {
            entry assign workerStatus = WorkerStatus::retraining;
        }
        
        transition completes
            first retraining
            accept TrainingCompletionEvent
            then reemployed;
        
        state receiving_benefits {
            entry assign workerStatus = WorkerStatus::receiving_benefits;
        }
        
        transition findsJob
            first receiving_benefits
            accept JobOfferEvent
            then reemployed;
        
        state reemployed {
            entry assign workerStatus = WorkerStatus::reemployed;
        }
        
        attribute workerStatus : WorkerStatus;
    }
    
    part technologicalUnemploymentSystem : TechnologicalUnemploymentMitigationSystem {
        doc /*
            This system addresses technological unemployment by managing the transition
            of workers displaced by automation and artificial intelligence.
            
            Primary Function:
            The system continuously monitors economic trends and automation impacts,
            identifies workers at risk of displacement, and coordinates interventions
            through three primary mechanisms:
            
            1. Retraining Programs: Upskills displaced workers for emerging job markets
            2. Job Matching: Connects retrained workers with suitable employment opportunities
            3. Economic Support: Provides temporary financial assistance during transitions
            
            The system operates in a continuous feedback loop, adapting its strategies
            based on employment metrics and automation trends to maintain workforce
            stability and economic resilience in the face of technological change.
        */
        
        part economicMonitor : EconomicMonitor {
            attribute :>> currentEmploymentRate {
                attribute :>> value = 92.5;
            }
            attribute :>> automationGrowthRate = 3.2;
        }
        
        part displacementAnalyzer : DisplacementAnalyzer {
            attribute :>> displacementThreshold = 0.15;
        }
        
        part retrainingCenter : RetrainingCenter {
            attribute :>> maxCapacity {
                attribute :>> value = 50000;
            }
        }
        
        part jobMatchingEngine : JobMatchingEngine {
            attribute :>> matchingAlgorithmVersion = "v2.3.1";
        }
        
        part benefitDistributor : BenefitDistributor {
            attribute :>> totalBudget = 5000000000.0;
        }
        
        part policyCoordinator : PolicyCoordinator {
            attribute :>> interventionStrategy = "adaptive_multi_phase";
        }
        
        connection monitorToAnalyzer connect
            economicMonitor.economicData to displacementAnalyzer.economicInput;
        
        connection analyzerToRetraining connect
            displacementAnalyzer.workerInput to retrainingCenter.trainingInterface;
        
        connection retrainingToMatching connect
            retrainingCenter.trainingInterface to jobMatchingEngine.workerInput;
        
        connection analyzerToBenefits connect
            displacementAnalyzer.workerInput to benefitDistributor.benefitInterface;
        
        connection monitorToPolicy connect
            economicMonitor.economicData to policyCoordinator.economicInput;
        
        connection analyzerToPolicy connect
            displacementAnalyzer.workerInput to policyCoordinator.workerData;
        
        perform action transitionManagement : ManageTechnologicalTransition {
            in incomingWorkers[*];
            in economicConditions[*];
            out reemployedWorkers[*];
            out supportedWorkers[*];
        }
    }
    
    requirement def <'TU-REQ-001'> MaintainEmploymentStability {
        doc /*
            The system shall maintain overall employment rate above 85% during
            periods of technological transition.
        */
        
        subject system : TechnologicalUnemploymentMitigationSystem;
        
        require constraint {
            system.economicMonitor.currentEmploymentRate.value >= 85.0
        }
    }
    
    requirement def <'TU-REQ-002'> RetrainingEffectiveness {
        doc /*
            The system shall successfully retrain and reemploy at least 70% of
            displaced workers within 18 months of displacement.
        */
        
        subject system : TechnologicalUnemploymentMitigationSystem;
    }
    
    requirement def <'TU-REQ-003'> BenefitCoverage {
        doc /*
            The system shall provide economic support to 100% of eligible displaced
            workers within 30 days of displacement identification.
        */
        
        subject system : TechnologicalUnemploymentMitigationSystem;
    }
    
    requirement def <'TU-REQ-004'> ResponseTime {
        doc /*
            The system shall identify and initiate intervention for displaced workers
            within 14 days of automation-related job loss.
        */
        
        subject system : TechnologicalUnemploymentMitigationSystem;
    }
    
    requirement <'TU-MISSION'> technologicalUnemploymentMission {
        doc /*
            The Technological Unemployment Mitigation System shall proactively manage
            workforce transitions caused by automation and AI by providing comprehensive
            retraining, job matching, and economic support services to maintain economic
            stability and social welfare.
        */
        
        assume constraint economicGrowth {
            doc /* The economy continues to generate new job opportunities in emerging sectors. */
        }
        
        assume constraint technologyAdoption {
            doc /* Automation adoption follows predictable patterns allowing proactive intervention. */
        }
        
        require <'TU-REQ-001'> employmentStability : MaintainEmploymentStability;
        require <'TU-REQ-002'> retrainingSuccess : RetrainingEffectiveness;
        require <'TU-REQ-003'> benefitAccess : BenefitCoverage;
        require <'TU-REQ-004'> rapidResponse : ResponseTime;
    }
}
