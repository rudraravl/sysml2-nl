package ExploratoryEngineeringSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def ConfidenceLevel :> Real;
    attribute def ComplexityScore :> Real;
    attribute def FeasibilityIndex :> Real;
    attribute def UncertaintyMetric :> Real;

    item def TechnologicalConcept {
        attribute conceptName : String;
        attribute domainArea : String;
        attribute noveltyLevel : Real;
        attribute technicalChallenge : ComplexityScore;
    }

    item def TheoreticalModel {
        attribute modelType : String;
        attribute assumptions : String[*];
        attribute governingEquations : String[*];
        attribute validityRange : String;
        attribute confidenceLevel : ConfidenceLevel;
    }

    item def DesignSpacePoint {
        attribute designParameters : Real[*];
        attribute performanceMetrics : Real[*];
        attribute estimatedMass : MassValue;
        attribute estimatedPower : PowerValue;
        attribute estimatedCost : Real;
    }

    item def SimulationResult {
        attribute simulationId : String;
        attribute timesteps : Integer;
        attribute convergenceAchieved : Boolean;
        attribute predictedPerformance : Real[*];
        attribute computationTime : TimeValue;
        attribute numericalUncertainty : UncertaintyMetric;
    }

    item def FeasibilityAssessment {
        attribute overallFeasibility : FeasibilityIndex;
        attribute technicalFeasibility : FeasibilityIndex;
        attribute physicalConstraintsSatisfied : Boolean;
        attribute criticalUncertainties : String[*];
        attribute requiredBreakthroughs : String[*];
        attribute confidenceInConclusion : ConfidenceLevel;
        attribute recommendationCategory : String;
    }

    item def AnalysisReport {
        attribute reportId : String;
        attribute exploredDesigns : Integer;
        attribute simulationsRun : Integer;
        attribute keyFindings : String[*];
        attribute sensitivityFactors : String[*];
        attribute nextSteps : String[*];
    }

    port def ConceptInputPort {
        in item concept : TechnologicalConcept;
    }

    port def ModelOutputPort {
        out item model : TheoreticalModel;
    }

    port def DesignDataPort {
        in item designPoint : DesignSpacePoint;
        out item designPoint : DesignSpacePoint;
    }

    port def SimulationDataPort {
        in item simResult : SimulationResult;
        out item simResult : SimulationResult;
    }

    port def AssessmentPort {
        out item assessment : FeasibilityAssessment;
    }

    port def ReportPort {
        out item report : AnalysisReport;
    }

    interface def ConceptToModelingInterface {
        end conceptIn : ConceptInputPort;
        end modelOut : ModelOutputPort;
    }

    interface def ModelToDesignInterface {
        end modelIn : ModelOutputPort;
        end designOut : DesignDataPort;
    }

    interface def DesignToSimulationInterface {
        end designIn : DesignDataPort;
        end simOut : SimulationDataPort;
    }

    interface def SimulationToAssessmentInterface {
        end simIn : SimulationDataPort;
        end assessOut : AssessmentPort;
    }

    part def TheoreticalAnalysisEngine {
        attribute modelingDepth : Integer;
        attribute fidelityLevel : String;
        port conceptPort : ConceptInputPort;
        port modelPort : ModelOutputPort;
        perform action buildTheoreticalModel : BuildTheoreticalModel;
        perform action validateAssumptions : ValidateAssumptions;
    }

    part def DesignSpaceExplorer {
        attribute explorationStrategy : String;
        attribute designPointCount : Integer;
        attribute dimensionality : Integer;
        port modelPort : ModelOutputPort;
        port designPort : DesignDataPort;
        perform action generateDesignPoints : GenerateDesignPoints;
        perform action optimizeDesign : OptimizeDesign;
    }

    part def PerformanceSimulator {
        attribute solverType : String;
        attribute meshResolution : LengthValue;
        attribute timeStepSize : TimeValue;
        attribute parallelProcessors : Integer;
        port designPort : DesignDataPort;
        port simPort : SimulationDataPort;
        perform action runSimulation : RunSimulation;
        perform action computeMetrics : ComputeMetrics;
    }

    part def FeasibilityAnalyzer {
        attribute assessmentCriteria : String[*];
        attribute uncertaintyThreshold : Real;
        port simPort : SimulationDataPort;
        port assessmentPort : AssessmentPort;
        port reportPort : ReportPort;
        perform action analyzeFeasibility : AnalyzeFeasibility;
        perform action identifyUncertainties : IdentifyUncertainties;
        perform action generateReport : GenerateReport;
    }

    action def BuildTheoreticalModel {
        in concept : TechnologicalConcept;
        out model : TheoreticalModel;
    }

    action def ValidateAssumptions {
        in model : TheoreticalModel;
        out validationPassed : Boolean;
    }

    action def GenerateDesignPoints {
        in model : TheoreticalModel;
        in explorationBounds : Real[*];
        out designPoints : DesignSpacePoint[*];
    }

    action def OptimizeDesign {
        in objectives : String[*];
        in designPoints : DesignSpacePoint[*];
        out optimalPoint : DesignSpacePoint;
    }

    action def RunSimulation {
        in designPoint : DesignSpacePoint;
        in simulationTime : TimeValue;
        out result : SimulationResult;
    }

    action def ComputeMetrics {
        in result : SimulationResult;
        out performanceMetrics : Real[*];
    }

    action def AnalyzeFeasibility {
        in simResults : SimulationResult[*];
        out assessment : FeasibilityAssessment;
    }

    action def IdentifyUncertainties {
        in simResults : SimulationResult[*];
        in model : TheoreticalModel;
        out criticalUncertainties : String[*];
    }

    action def GenerateReport {
        in assessment : FeasibilityAssessment;
        in explorationData : DesignSpacePoint[*];
        out report : AnalysisReport;
    }

    action def ConductExploratoryEngineering {
        in inputConcept : TechnologicalConcept;
        out finalAssessment : FeasibilityAssessment;
        out finalReport : AnalysisReport;

        first start;
        then action buildModel : BuildTheoreticalModel {
            in concept = inputConcept;
            out model : TheoreticalModel;
        }
        then action validate : ValidateAssumptions {
            in model = buildModel.model;
            out validationPassed : Boolean;
        }
        then decide;
            if validate.validationPassed then exploreDesigns;
            if not validate.validationPassed then refineModel;
        
        action refineModel : BuildTheoreticalModel {
            in concept = inputConcept;
            out model : TheoreticalModel;
        }
        then exploreDesigns;
        
        action exploreDesigns : GenerateDesignPoints {
            in model = buildModel.model;
            in explorationBounds : Real[*];
            out designPoints : DesignSpacePoint[*];
        }
        then action simulate : RunSimulation {
            in designPoint : DesignSpacePoint;
            in simulationTime : TimeValue;
            out result : SimulationResult;
        }
        then action metrics : ComputeMetrics {
            in result = simulate.result;
            out performanceMetrics : Real[*];
        }
        then action assess : AnalyzeFeasibility {
            in simResults : SimulationResult[*];
            out assessment : FeasibilityAssessment;
        }
        then action identifyGaps : IdentifyUncertainties {
            in simResults : SimulationResult[*];
            in model = buildModel.model;
            out criticalUncertainties : String[*];
        }
        then action report : GenerateReport {
            in assessment = assess.assessment;
            in explorationData = exploreDesigns.designPoints;
            out report : AnalysisReport;
        }
        then done;
    }

    state def ExplorationLifecycle {
        entry; then conceptualization;
        
        state conceptualization;
        transition first conceptualization then modeling;
        
        state modeling;
        transition first modeling then exploration;
        
        state exploration;
        transition first exploration then assessment;
        
        state assessment;
        transition first assessment then completed;
        
        state completed;
    }

    part def ExploratoryEngineeringSystem {
        attribute systemVersion : String;
        attribute processingCapability : PowerValue;
        attribute storageCapacity : Real;
        attribute maximumDesignPoints : Integer;
        attribute simulationAccuracy : Real;
        attribute minimumConfidenceThreshold : ConfidenceLevel;

        port systemInput : ConceptInputPort;
        port systemOutput : AssessmentPort;
        port reportOutput : ReportPort;

        part theoreticalEngine : TheoreticalAnalysisEngine {
            attribute :>> modelingDepth = 3;
            attribute :>> fidelityLevel = "high";
        }

        part designExplorer : DesignSpaceExplorer {
            attribute :>> explorationStrategy = "adaptive_sampling";
            attribute :>> dimensionality = 8;
        }

        part simulator : PerformanceSimulator {
            attribute :>> solverType = "finite_element";
            attribute :>> meshResolution = 0.001 [m];
            attribute :>> timeStepSize = 0.0001 [s];
            attribute :>> parallelProcessors = 64;
        }

        part analyzer : FeasibilityAnalyzer {
            attribute :>> uncertaintyThreshold = 0.15;
        }

        interface conceptToModel : ConceptToModelingInterface
            connect theoreticalEngine.conceptPort to theoreticalEngine.modelPort;

        interface modelToDesign : ModelToDesignInterface
            connect theoreticalEngine.modelPort to designExplorer.modelPort;

        interface designToSim : DesignToSimulationInterface
            connect designExplorer.designPort to simulator.designPort;

        interface simToAssess : SimulationToAssessmentInterface
            connect simulator.simPort to analyzer.simPort;

        perform action primaryFunction : ConductExploratoryEngineering;
        exhibit state lifecycle : ExplorationLifecycle;
    }

    part exploratoryEngineeringSystem : ExploratoryEngineeringSystem {
        attribute :>> systemVersion = "2.1.0";
        attribute :>> processingCapability = 10000 [W];
        attribute :>> storageCapacity = 5.0e13;
        attribute :>> maximumDesignPoints = 10000;
        attribute :>> simulationAccuracy = 0.98;
        attribute :>> minimumConfidenceThreshold = 0.80;
    }

    requirement def <'EXP-REQ-1'> PrimaryFunctionRequirement {
        doc /* The exploratory engineering system shall systematically analyze technological concepts through theoretical modeling, design space exploration, performance simulation, and feasibility assessment to determine viability and identify critical uncertainties. */
        subject system : ExploratoryEngineeringSystem;
        require constraint {
            system.minimumConfidenceThreshold >= 0.75
        }
    }

    requirement def <'EXP-REQ-2'> ModelingCapabilityRequirement {
        doc /* The system shall construct theoretical models with sufficient fidelity to capture relevant physical phenomena and constraints. */
        subject system : ExploratoryEngineeringSystem;
        attribute modelFidelity : Integer = system.theoreticalEngine.modelingDepth;
        require constraint {
            modelFidelity >= 2
        }
    }

    requirement def <'EXP-REQ-3'> DesignExplorationRequirement {
        doc /* The system shall explore a design space of sufficient size to identify promising configurations and performance boundaries. */
        subject system : ExploratoryEngineeringSystem;
        attribute maxPoints : Integer = system.maximumDesignPoints;
        require constraint {
            maxPoints >= 1000
        }
    }

    requirement def <'EXP-REQ-4'> SimulationAccuracyRequirement {
        doc /* Performance simulations shall achieve accuracy sufficient to distinguish between feasible and infeasible designs. */
        subject system : ExploratoryEngineeringSystem;
        attribute accuracy : Real = system.simulationAccuracy;
        require constraint {
            accuracy >= 0.95
        }
    }

    requirement def <'EXP-REQ-5'> UncertaintyIdentificationRequirement {
        doc /* The system shall identify and quantify critical uncertainties that could affect feasibility conclusions. */
        subject system : ExploratoryEngineeringSystem;
        attribute uncertaintyThreshold : Real = system.analyzer.uncertaintyThreshold;
        require constraint {
            uncertaintyThreshold <= 0.20
        }
    }

    requirement def <'EXP-REQ-6'> AssessmentConfidenceRequirement {
        doc /* Feasibility assessments shall include confidence levels that meet or exceed the minimum threshold. */
        subject system : ExploratoryEngineeringSystem;
        attribute minConfidence : ConfidenceLevel = system.minimumConfidenceThreshold;
        require constraint {
            minConfidence >= 0.80
        }
    }

    requirement <'EXP-1'> primaryFunction : PrimaryFunctionRequirement {
        subject :>> system = exploratoryEngineeringSystem;
    }

    requirement <'EXP-2'> modelingCapability : ModelingCapabilityRequirement {
        subject :>> system = exploratoryEngineeringSystem;
    }

    requirement <'EXP-3'> designExploration : DesignExplorationRequirement {
        subject :>> system = exploratoryEngineeringSystem;
    }

    requirement <'EXP-4'> simulationAccuracy : SimulationAccuracyRequirement {
        subject :>> system = exploratoryEngineeringSystem;
    }

    requirement <'EXP-5'> uncertaintyIdentification : UncertaintyIdentificationRequirement {
        subject :>> system = exploratoryEngineeringSystem;
    }

    requirement <'EXP-6'> assessmentConfidence : AssessmentConfidenceRequirement {
        subject :>> system = exploratoryEngineeringSystem;
    }

    requirement overallMission {
        doc /* The exploratory engineering system shall fulfill all functional and quality requirements to enable rigorous analysis of future technological capabilities. */
        subject system : ExploratoryEngineeringSystem = exploratoryEngineeringSystem;
        require primaryFunction;
        require modelingCapability;
        require designExploration;
        require simulationAccuracy;
        require uncertaintyIdentification;
        require assessmentConfidence;
    }
}
