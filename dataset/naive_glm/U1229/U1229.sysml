package TechnologicalUnemploymentMitigationSystem {
    import ScalarValues::*;
    import Quantities::*;
    import MeasurementReferences::*;
    import Collections::*;

    // ---- Units ----
    unit def percentU { 
        quantityDimension dimensionless; 
    }
    unit def currencyU {
        quantityDimension dimensionless;
    }
    unit def weekU {
        quantityDimension dimensionless;
    }
    unit def yearU {
        quantityDimension dimensionless;
    }

    // ---- Value types ----
    value def EmploymentRate :> Real { unit percentU; }
    value def AutomationGrowthRate :> Real { unit percentU; }
    value def RiskScore :> Real { unit percentU; }
    value def BenefitAmount :> Real { unit currencyU; }
    value def SalaryAmount :> Real { unit currencyU; }
    value def TrainingDuration :> Real { unit weekU; }
    value def TimeInTransition :> Real { unit weekU; }
    value def WorkerId :> String;
    value def ProgramId :> String;
    value def JobId :> String;
    value def SectorId :> String;

    enumeration def WorkerStatus {
        enum employed;
        enum atRisk;
        enum displaced;
        enum retraining;
        enum receivingBenefits;
        enum reemployed;
    }

    enumeration def ProgramType {
        enum technical;
        enum digital;
        enum green;
        enum healthcare;
        enum entrepreneurial;
    }

    // ---- Item definitions ----
    item def EconomicMetrics {
        attribute nationalEmploymentRate : EmploymentRate;
        attribute sectorAutomationGrowth : AutomationGrowthRate [0..*];
        attribute sector : SectorId [0..*];
        attribute reportingYear : Integer;
    }

    item def DisplacementNotice {
        attribute workerId : WorkerId;
        attribute sector : SectorId;
        attribute riskScore : RiskScore;
        attribute displaced : Boolean;
        attribute timestamp : String;
    }

    item def WorkerProfile {
        attribute workerId : WorkerId;
        attribute name : String;
        attribute priorSector : SectorId;
        attribute priorSalary : SalaryAmount;
        attribute status : WorkerStatus;
        attribute riskScore : RiskScore;
        attribute eligibleForBenefits : Boolean;
        attribute recommendedPrograms : ProgramId [0..*];
    }

    item def TrainingProgram {
        attribute programId : ProgramId;
        attribute type : ProgramType;
        attribute duration : TrainingDuration;
        attribute targetSector : SectorId;
        attribute capacity : Integer;
        attribute enrolled : Integer;
    }

    item def JobOpening {
        attribute jobId : JobId;
        attribute sector : SectorId;
        attribute requiredProgram : ProgramId;
        attribute salary : SalaryAmount;
        attribute location : String;
        attribute filled : Boolean;
    }

    item def BenefitPayment {
        attribute workerId : WorkerId;
        attribute amount : BenefitAmount;
        attribute period : Integer;
        attribute issued : Boolean;
    }

    item def PlacementResult {
        attribute workerId : WorkerId;
        attribute jobId : JobId;
        attribute matched : Boolean;
        attribute newSalary : SalaryAmount;
    }

    item def InterventionPlan {
        attribute workerId : WorkerId;
        attribute assignedPrograms : ProgramId [0..*];
        attribute benefitEligible : Boolean;
        attribute priority : Integer;
    }

    // ---- Interfaces / Ports ----
    interface def MetricsFlow {
        end supplier : EconomicMetrics;
        end consumer : EconomicMetrics;
    }

    interface def DisplacementFlow {
        end supplier : DisplacementNotice;
        end consumer : DisplacementNotice;
    }

    interface def ProfileFlow {
        end supplier : WorkerProfile;
        end consumer : WorkerProfile;
    }

    interface def PlanFlow {
        end supplier : InterventionPlan;
        end consumer : InterventionPlan;
    }

    interface def ProgramFlow {
        end supplier : TrainingProgram;
        end consumer : TrainingProgram;
    }

    interface def BenefitFlow {
        end supplier : BenefitPayment;
        end consumer : BenefitPayment;
    }

    interface def JobFlow {
        end supplier : JobOpening;
        end consumer : JobOpening;
    }

    interface def PlacementFlow {
        end supplier : PlacementResult;
        end consumer : PlacementResult;
    }

    port def MetricsOut { out metrics : EconomicMetrics; }
    port def MetricsIn { in metrics : EconomicMetrics; }
    port def DisplacementOut { out notice : DisplacementNotice; }
    port def DisplacementIn { in notice : DisplacementNotice; }
    port def ProfileOut { out profile : WorkerProfile; }
    port def ProfileIn { in profile : WorkerProfile; }
    port def PlanOut { out plan : InterventionPlan; }
    port def PlanIn { in plan : InterventionPlan; }
    port def ProgramOut { out program : TrainingProgram; }
    port def ProgramIn { in program : TrainingProgram; }
    port def BenefitOut { out payment : BenefitPayment; }
    port def BenefitIn { in payment : BenefitPayment; }
    port def JobOut { out opening : JobOpening; }
    port def JobIn { in opening : JobOpening; }
    port def PlacementOut { out result : PlacementResult; }
    port def PlacementIn { in result : PlacementResult; }

    // ---- Part definitions ----
    part def EconomicMonitor {
        port metricsOut : MetricsOut;
        attribute monitoredSectors : SectorId [0..*];
        attribute reportingIntervalWeeks : Integer;
        attribute latestEmploymentRate : EmploymentRate;
        attribute latestAutomationGrowth : AutomationGrowthRate;

        action def collectMetrics {
            in sectorList : SectorId [0..*];
            out producedMetrics : EconomicMetrics;
        }

        perform action collectSectorData : collectMetrics {
            in sectorList = monitoredSectors;
            out producedMetrics -> metricsOut.metrics;
        }
    }

    part def DisplacementAnalyzer {
        port metricsIn : MetricsIn;
        port displacementOut : DisplacementOut;
        port profileOut : ProfileOut;
        attribute riskThreshold : RiskScore;
        attribute trackedWorkers : WorkerProfile [0..*];

        action def analyzeDisplacement {
            in metrics : EconomicMetrics;
            in workers : WorkerProfile [0..*];
            out notices : DisplacementNotice [0..*];
            out updatedProfiles : WorkerProfile [0..*];
        }

        perform action runAnalysis : analyzeDisplacement {
            in metrics = metricsIn.metrics;
            in workers = trackedWorkers;
            out notices -> displacementOut.notice;
            out updatedProfiles -> profileOut.profile;
        }
    }

    part def PolicyCoordinator {
        port displacementIn : DisplacementIn;
        port profileIn : ProfileIn;
        port planOut : PlanOut;
        port programOut : ProgramOut;
        port benefitOut : BenefitOut;
        port placementIn : PlacementIn;
        attribute activePlans : InterventionPlan [0..*];
        attribute priorityQueue : WorkerId [0..*];

        action def assessWorker {
            in notice : DisplacementNotice;
            in profile : WorkerProfile;
            out plan : InterventionPlan;
        }

        action def coordinateIntervention {
            in plan : InterventionPlan;
            out program : TrainingProgram;
            out payment : BenefitPayment;
        }

        perform action orchestrate : assessWorker {
            in notice = displacementIn.notice;
            in profile = profileIn.profile;
            out plan -> planOut.plan;
        }

        perform action dispatch : coordinateIntervention {
            in plan = planOut.plan;
            out program -> programOut.program;
            out payment -> benefitOut.payment;
        }
    }

    part def RetrainingCenter {
        port programIn : ProgramIn;
        port profileIn : ProfileIn;
        port profileOut : ProfileOut;
        attribute catalog : TrainingProgram [0..*];
        attribute enrolledWorkers : WorkerProfile [0..*];

        action def enrollWorker {
            in program : TrainingProgram;
            in profile : WorkerProfile;
            out updatedProfile : WorkerProfile;
        }

        action def completeTraining {
            in profile : WorkerProfile;
            out graduatedProfile : WorkerProfile;
        }

        perform action intake : enrollWorker {
            in program = programIn.program;
            in profile = profileIn.profile;
            out updatedProfile -> profileOut.profile;
        }
    }

    part def BenefitDistributor {
        port benefitIn : BenefitIn;
        port profileIn : ProfileIn;
        port profileOut : ProfileOut;
        attribute maxBenefit : BenefitAmount;
        attribute durationWeeks : TimeInTransition;
        attribute ledger : BenefitPayment [0..*];

        action def disburseBenefit {
            in payment : BenefitPayment;
            in profile : WorkerProfile;
            out confirmedPayment : BenefitPayment;
            out updatedProfile : WorkerProfile;
        }

        perform action issuePayment : disburseBenefit {
            in payment = benefitIn.payment;
            in profile = profileIn.profile;
            out confirmedPayment -> self.ledger;
            out updatedProfile -> profileOut.profile;
        }
    }

    part def JobMatchingEngine {
        port profileIn : ProfileIn;
        port jobIn : JobIn;
        port placementOut : PlacementOut;
        attribute jobDatabase : JobOpening [0..*];
        attribute matchingAlgorithmVersion : String;

        action def matchWorker {
            in profile : WorkerProfile;
            in openings : JobOpening [0..*];
            out result : PlacementResult;
        }

        perform action runMatch : matchWorker {
            in profile = profileIn.profile;
            in openings = jobDatabase;
            out result -> placementOut.result;
        }
    }

    part def Worker {
        attribute workerId : WorkerId;
        attribute name : String;
        attribute status : WorkerStatus;
        attribute riskScore : RiskScore;
        attribute priorSector : SectorId;
        attribute priorSalary : SalaryAmount;
        attribute currentSalary : SalaryAmount;
        attribute assignedPrograms : ProgramId [0..*];
        attribute benefitsReceived : BenefitAmount;

        state def lifecycle {
            entry; then employed;

            state employed;
            state atRisk;
            state displaced;
            state retraining;
            state receivingBenefits;
            state reemployed;

            transition employed_to_atRisk first employed then atRisk
                when (riskScore > 0.6) { 
                    assign status := WorkerStatus::atRisk; 
                }
            transition atRisk_to_displaced first atRisk then displaced
                when (status == WorkerStatus::displaced) { 
                    assign status := WorkerStatus::displaced; 
                }
            transition employed_to_displaced first employed then displaced
                when (status == WorkerStatus::displaced) { 
                    assign status := WorkerStatus::displaced; 
                }
            transition displaced_to_retraining first displaced then retraining
                when (assignedPrograms->size() > 0) { 
                    assign status := WorkerStatus::retraining; 
                }
            transition displaced_to_receivingBenefits first displaced then receivingBenefits
                when (benefitsReceived > 0) { 
                    assign status := WorkerStatus::receivingBenefits; 
                }
            transition retraining_to_receivingBenefits first retraining then receivingBenefits
                when (benefitsReceived > 0) { 
                    assign status := WorkerStatus::receivingBenefits; 
                }
            transition receivingBenefits_to_retraining first receivingBenefits then retraining
                when (assignedPrograms->size() > 0) { 
                    assign status := WorkerStatus::retraining; 
                }
            transition retraining_to_reemployed first retraining then reemployed
                when (currentSalary > 0) { 
                    assign status := WorkerStatus::reemployed; 
                }
            transition receivingBenefits_to_reemployed first receivingBenefits then reemployed
                when (currentSalary > 0) { 
                    assign status := WorkerStatus::reemployed; 
                }
            transition reemployed_to_employed first reemployed then employed
                when (status == WorkerStatus::employed) { 
                    assign status := WorkerStatus::employed; 
                }
        }

        exhibit state lifecycleBehavior : lifecycle;
    }

    // ---- Top-level system ----
    part def MitigationSystem {
        part economicMonitor : EconomicMonitor {
            attribute reportingIntervalWeeks = 4;
            attribute monitoredSectors = (SectorId#"manufacturing", SectorId#"retail", SectorId#"logistics", SectorId#"administration");
        }

        part displacementAnalyzer : DisplacementAnalyzer {
            attribute riskThreshold = 0.65;
        }

        part policyCoordinator : PolicyCoordinator;

        part retrainingCenter : RetrainingCenter {
            attribute catalog = (
                TrainingProgram{programId="TP-001"; type=ProgramType::technical; duration=12; targetSector=SectorId#"informationTechnology"; capacity=500; enrolled=0;},
                TrainingProgram{programId="TP-002"; type=ProgramType::green; duration=16; targetSector=SectorId#"renewableEnergy"; capacity=300; enrolled=0;},
                TrainingProgram{programId="TP-003"; type=ProgramType::healthcare; duration=20; targetSector=SectorId#"healthcare"; capacity=400; enrolled=0;},
                TrainingProgram{programId="TP-004"; type=ProgramType::digital; duration=10; targetSector=SectorId#"digitalServices"; capacity=600; enrolled=0;},
                TrainingProgram{programId="TP-005"; type=ProgramType::entrepreneurial; duration=8; targetSector=SectorId#"selfEmployment"; capacity=200; enrolled=0;}
            );
        }

        part benefitDistributor : BenefitDistributor {
            attribute maxBenefit = 2000;
            attribute durationWeeks = 26;
        }

        part jobMatchingEngine : JobMatchingEngine {
            attribute matchingAlgorithmVersion = "JME-2.4";
        }

        part workforce : Worker [0..*];

        connection economicMonitor.metricsOut to displacementAnalyzer.metricsIn;
        connection displacementAnalyzer.displacementOut to policyCoordinator.displacementIn;
        connection displacementAnalyzer.profileOut to policyCoordinator.profileIn;
        connection policyCoordinator.planOut to retrainingCenter.programIn;
        connection policyCoordinator.benefitOut to benefitDistributor.benefitIn;
        connection retrainingCenter.profileOut to jobMatchingEngine.profileIn;
        connection benefitDistributor.profileOut to jobMatchingEngine.profileIn;
        connection jobMatchingEngine.placementOut to policyCoordinator.placementIn;
    }

    // ---- Requirements ----
    requirement def MonitorEconomicMetrics {
        subject economicMonitor : EconomicMonitor;
        objective {
            doc /* The system shall continuously track national employment rate and automation growth across industry sectors. */
            assert economicMonitor.latestEmploymentRate >= 0.0 and economicMonitor.latestEmploymentRate <= 100.0;
        }
    }

    requirement def IdentifyDisplacedWorkers {
        subject displacementAnalyzer : DisplacementAnalyzer;
        objective {
            doc /* The analyzer shall identify workers displaced or at high risk due to automation. */
            assert displacementAnalyzer.riskThreshold > 0.0 and displacementAnalyzer.riskThreshold < 1.0;
        }
    }

    requirement def CoordinateInterventions {
        subject policyCoordinator : PolicyCoordinator;
        objective {
            doc /* The coordinator shall assess each displaced worker and assign retraining and/or benefits. */
            assert policyCoordinator.activePlans->size() >= 0;
        }
    }

    requirement def ProvideRetraining {
        subject retrainingCenter : RetrainingCenter;
        objective {
            doc /* The retraining center shall offer programs that upskill workers for high-demand jobs. */
            assert retrainingCenter.catalog->size() > 0;
        }
    }

    requirement def DistributeBenefits {
        subject benefitDistributor : BenefitDistributor;
        objective {
            doc /* The benefit distributor shall disburse financial aid to eligible workers during transition. */
            assert benefitDistributor.maxBenefit > 0;
        }
    }

    requirement def MatchWorkersToJobs {
        subject jobMatchingEngine : JobMatchingEngine;
        objective {
            doc /* The job matching engine shall connect retrained workers with suitable job openings. */
            assert jobMatchingEngine.jobDatabase->size() >= 0;
        }
    }

    requirement def MaintainWorkerLifecycle {
        subject worker : Worker;
        objective {
            doc /* Each worker shall progress from employed through displaced to reemployed status. */
            assert worker.status == WorkerStatus::employed or worker.status == WorkerStatus::atRisk or worker.status == WorkerStatus::displaced or worker.status == WorkerStatus::retraining or worker.status == WorkerStatus::receivingBenefits or worker.status == WorkerStatus::reemployed;
        }
    }

    requirement def SystemResilience {
        subject system : MitigationSystem;
        objective {
            doc /* The overall system shall maintain economic stability and provide a social safety net for technologically displaced workers. */
            assert system.workforce->size() >= 0;
        }
    }

    part mitigationSystemInstance : MitigationSystem {
        satisfy MonitorEconomicMetrics by economicMonitor;
        satisfy IdentifyDisplacedWorkers by displacementAnalyzer;
        satisfy CoordinateInterventions by policyCoordinator;
        satisfy ProvideRetraining by retrainingCenter;
        satisfy DistributeBenefits by benefitDistributor;
        satisfy MatchWorkersToJobs by jobMatchingEngine;
        satisfy SystemResilience by self;
    }
}
