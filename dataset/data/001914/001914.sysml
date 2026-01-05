package 'Engineering Design System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package 'Value and Item Definitions' {
		attribute def DesignComplexityValue :> Real;
		attribute def QualityScoreValue :> Real;
		attribute def CostValue :> Real;
		
		item def DesignSpecification {
			attribute specId : String;
			attribute functionalRequirements : String;
			attribute performanceCriteria : String;
			attribute constraints : String;
		}
		
		item def AnalysisResults {
			attribute structuralIntegrity : QualityScoreValue;
			attribute thermalPerformance : TemperatureValue;
			attribute stressDistribution : PressureValue;
			attribute safetyFactor : Real;
		}
		
		item def DesignArtifact {
			attribute modelId : String;
			attribute geometryData : String;
			attribute materialSpecification : String;
			attribute revisionNumber : Integer;
		}
		
		item def ValidationReport {
			attribute testId : String;
			attribute complianceStatus : Boolean;
			attribute deviations : String;
			attribute recommendations : String;
		}
	}

	package 'Port and Interface Definitions' {
		private import 'Value and Item Definitions'::*;
		
		port def SpecificationPort {
			in designSpec : DesignSpecification;
			out designFeedback : String;
		}
		
		port def ModelingPort {
			in designParameters : DesignSpecification;
			out designModel : DesignArtifact;
		}
		
		port def AnalysisPort {
			in modelData : DesignArtifact;
			out analysisData : AnalysisResults;
		}
		
		port def ValidationPort {
			in testData : DesignArtifact;
			in analysisData : AnalysisResults;
			out validationResults : ValidationReport;
		}
		
		port def DataManagementPort {
			inout designData : DesignArtifact;
			inout analysisData : AnalysisResults;
			inout validationData : ValidationReport;
		}
		
		interface def SpecificationToModelingInterface {
			end specPort : SpecificationPort;
			end modelPort : ModelingPort;
		}
		
		interface def ModelingToAnalysisInterface {
			end modelPort : ModelingPort;
			end analysisPort : AnalysisPort;
		}
		
		interface def AnalysisToValidationInterface {
			end analysisPort : AnalysisPort;
			end validationPort : ValidationPort;
		}
		
		interface def DataRepositoryInterface {
			end clientPort : DataManagementPort;
			end serverPort : DataManagementPort;
		}
	}

	package 'Action Definitions' {
		private import 'Value and Item Definitions'::*;
		
		action def CaptureRequirements {
			in stakeholderNeeds : String;
			out specification : DesignSpecification;
		}
		
		action def CreateDesignModel {
			in spec : DesignSpecification;
			out model : DesignArtifact;
		}
		
		action def PerformAnalysis {
			in designModel : DesignArtifact;
			out results : AnalysisResults;
		}
		
		action def ValidateDesign {
			in model : DesignArtifact;
			in analysis : AnalysisResults;
			out validation : ValidationReport;
		}
		
		action def OptimizeDesign {
			in currentModel : DesignArtifact;
			in performanceGaps : AnalysisResults;
			out optimizedModel : DesignArtifact;
		}
		
		action def ApproveDesign {
			in validationReport : ValidationReport;
			out approvalDecision : Boolean;
		}
	}

	package 'Component Definitions' {
		private import 'Port and Interface Definitions'::*;
		private import 'Action Definitions'::*;
		private import 'Value and Item Definitions'::*;
		
		part def RequirementsManagementModule {
			port specificationPort : SpecificationPort;
			attribute requirementsDatabase : String;
			perform action captureReqs : CaptureRequirements;
		}
		
		part def CADModelingModule {
			port inputPort : ModelingPort;
			port outputPort : ModelingPort;
			attribute modelingEngine : String;
			attribute designLibrary : String;
			perform action createModel : CreateDesignModel;
		}
		
		part def FiniteElementAnalysisModule {
			port modelInputPort : AnalysisPort;
			port resultsOutputPort : AnalysisPort;
			attribute solverType : String;
			attribute meshResolution : Real;
			perform action runAnalysis : PerformAnalysis;
		}
		
		part def ValidationTestingModule {
			port testInputPort : ValidationPort;
			port testOutputPort : ValidationPort;
			attribute testProtocols : String;
			attribute complianceStandards : String;
			perform action validateDesign : ValidateDesign;
		}
		
		part def OptimizationEngine {
			port dataPort : DataManagementPort;
			attribute optimizationAlgorithm : String;
			attribute convergenceCriteria : Real;
			perform action optimize : OptimizeDesign;
		}
		
		part def DesignDataRepository {
			port repositoryPort : DataManagementPort;
			attribute storageCapacity : Real;
			attribute versionControl : Boolean;
		}
		
		part def ReviewApprovalBoard {
			port reviewPort : ValidationPort;
			attribute approvalAuthority : String;
			perform action approve : ApproveDesign;
		}
	}

	package 'State Machine Definitions' {
		state def EngineeringDesignLifecycle {
			entry; then requirementsPhase;
			
			state requirementsPhase {
				entry; then gatherRequirements;
				state gatherRequirements;
				then reviewRequirements;
				state reviewRequirements;
				accept at reviewRequirements if requirementsApproved then conceptualDesign;
				accept at reviewRequirements if requirementsRejected then gatherRequirements;
			}
			
			state conceptualDesign {
				entry; then createInitialModel;
				state createInitialModel;
				then preliminaryAnalysis;
				state preliminaryAnalysis;
				accept at preliminaryAnalysis if conceptFeasible then detailedDesign;
				accept at preliminaryAnalysis if conceptInfeasible then createInitialModel;
			}
			
			state detailedDesign {
				entry; then developDetailedModel;
				state developDetailedModel;
				then comprehensiveAnalysis;
				state comprehensiveAnalysis;
				then decide;
				accept at decide if analysisAcceptable then validation;
				accept at decide if analysisUnacceptable and optimizationPossible then optimization;
				accept at decide if analysisUnacceptable and not optimizationPossible then developDetailedModel;
				
				state optimization {
					do action performOptimization : OptimizeDesign;
				}
				then comprehensiveAnalysis;
			}
			
			state validation {
				entry; then executeTests;
				state executeTests;
				then evaluateCompliance;
				state evaluateCompliance;
				accept at evaluateCompliance if validationPassed then approval;
				accept at evaluateCompliance if validationFailed then detailedDesign;
			}
			
			state approval {
				entry; then reviewForApproval;
				state reviewForApproval;
				accept at reviewForApproval if designApproved then production;
				accept at reviewForApproval if designRejected then detailedDesign;
			}
			
			state production;
			then done;
		}
	}

	package 'System Definition' {
		private import 'Component Definitions'::*;
		private import 'State Machine Definitions'::*;
		private import 'Action Definitions'::*;
		private import 'Value and Item Definitions'::*;
		
		part def EngineeringDesignSystem {
			doc /* 
			 * An integrated engineering design system that transforms stakeholder requirements 
			 * into validated, production-ready designs through systematic modeling, analysis, 
			 * optimization, and validation processes. The system coordinates multiple engineering 
			 * disciplines to ensure designs meet all functional, performance, and safety requirements.
			 */
			
			attribute totalProjectCost : CostValue;
			attribute designComplexity : DesignComplexityValue;
			attribute overallQualityScore : QualityScoreValue;
			attribute projectSchedule : TimeValue;
			
			part requirementsModule : RequirementsManagementModule {
				port :>> specificationPort;
			}
			
			part cadModule : CADModelingModule {
				port :>> inputPort;
				port :>> outputPort;
			}
			
			part feaModule : FiniteElementAnalysisModule {
				port :>> modelInputPort;
				port :>> resultsOutputPort;
			}
			
			part validationModule : ValidationTestingModule {
				port :>> testInputPort;
				port :>> testOutputPort;
			}
			
			part optimizationModule : OptimizationEngine {
				port :>> dataPort;
			}
			
			part dataRepository : DesignDataRepository {
				port :>> repositoryPort;
			}
			
			part reviewBoard : ReviewApprovalBoard {
				port :>> reviewPort;
			}
			
			interface reqToCAD : SpecificationToModelingInterface
				connect requirementsModule.specificationPort to cadModule.inputPort;
			
			interface cadToFEA : ModelingToAnalysisInterface
				connect cadModule.outputPort to feaModule.modelInputPort;
			
			interface feaToValidation : AnalysisToValidationInterface
				connect feaModule.resultsOutputPort to validationModule.testInputPort;
			
			interface validationToReview
				connect validationModule.testOutputPort to reviewBoard.reviewPort;
			
			interface cadToRepository : DataRepositoryInterface
				connect cadModule.outputPort to dataRepository.repositoryPort;
			
			interface feaToRepository : DataRepositoryInterface
				connect feaModule.resultsOutputPort to dataRepository.repositoryPort;
			
			interface optimizationToRepository : DataRepositoryInterface
				connect optimizationModule.dataPort to dataRepository.repositoryPort;
		}
	}

	package 'System Behavior' {
		private import 'System Definition'::*;
		private import 'Action Definitions'::*;
		private import 'Value and Item Definitions'::*;
		
		action def ExecuteEngineeringDesignProcess {
			doc /* 
			 * Primary function: Transform stakeholder requirements into validated, 
			 * production-ready engineering designs through an integrated process of 
			 * requirements capture, conceptual and detailed design, multi-physics analysis, 
			 * iterative optimization, and comprehensive validation testing.
			 */
			
			in stakeholderInputs : String;
			out finalDesign : DesignArtifact;
			out finalValidation : ValidationReport;
			
			first start;
			then captureRequirements;
			
			action captureRequirements : CaptureRequirements {
				in stakeholderNeeds = stakeholderInputs;
			}
			then createConceptualModel;
			
			action createConceptualModel : CreateDesignModel {
				in spec = captureRequirements.specification;
			}
			then performPreliminaryAnalysis;
			
			action performPreliminaryAnalysis : PerformAnalysis {
				in designModel = createConceptualModel.model;
			}
			then decide conceptFeasibility;
			
			if performPreliminaryAnalysis.results.safetyFactor >= 1.5 then proceedToDetailedDesign;
			if performPreliminaryAnalysis.results.safetyFactor < 1.5 then createConceptualModel;
			
			action proceedToDetailedDesign : CreateDesignModel {
				in spec = captureRequirements.specification;
			}
			then merge iterativeRefinement;
			
			then performDetailedAnalysis : PerformAnalysis {
				in designModel = proceedToDetailedDesign.model;
			}
			then decide optimizationNeeded;
			
			if performDetailedAnalysis.results.safetyFactor >= 2.0 and 
			   performDetailedAnalysis.results.structuralIntegrity >= 0.95 then proceedToValidation;
			if performDetailedAnalysis.results.safetyFactor < 2.0 or 
			   performDetailedAnalysis.results.structuralIntegrity < 0.95 then optimizeDesign;
			
			action optimizeDesign : OptimizeDesign {
				in currentModel = proceedToDetailedDesign.model;
				in performanceGaps = performDetailedAnalysis.results;
			}
			then iterativeRefinement;
			
			action proceedToValidation : ValidateDesign {
				in model = proceedToDetailedDesign.model;
				in analysis = performDetailedAnalysis.results;
			}
			then reviewDesign;
			
			action reviewDesign : ApproveDesign {
				in validationReport = proceedToValidation.validation;
			}
			then decide finalApproval;
			
			if reviewDesign.approvalDecision == true then finalizeDesign;
			if reviewDesign.approvalDecision == false then iterativeRefinement;
			
			action finalizeDesign {
				out finalDesign = proceedToDetailedDesign.model;
				out finalValidation = proceedToValidation.validation;
			}
			then done;
		}
	}

	package 'System Instance' {
		private import 'System Definition'::*;
		private import 'System Behavior'::*;
		private import 'Value and Item Definitions'::*;
		
		part aerospaceStructureDesignSystem : EngineeringDesignSystem {
			attribute :>> totalProjectCost = 2500000.0;
			attribute :>> designComplexity = 8.5;
			attribute :>> overallQualityScore = 0.92;
			attribute :>> projectSchedule = 18.0 [mo];
			
			perform designProcess : ExecuteEngineeringDesignProcess {
				in stakeholderInputs = "Design lightweight aircraft wing structure with 15000 kg load capacity";
			}
			
			part :>> requirementsModule {
				attribute :>> requirementsDatabase = "AerospaceReqDB_v3.2";
			}
			
			part :>> cadModule {
				attribute :>> modelingEngine = "CATIA V6";
				attribute :>> designLibrary = "AerospaceComponents_Std";
			}
			
			part :>> feaModule {
				attribute :>> solverType = "NASTRAN";
				attribute :>> meshResolution = 0.005;
			}
			
			part :>> validationModule {
				attribute :>> testProtocols = "DO-160G, MIL-STD-810H";
				attribute :>> complianceStandards = "FAA Part 25, EASA CS-25";
			}
			
			part :>> optimizationModule {
				attribute :>> optimizationAlgorithm = "Genetic Algorithm with Gradient Descent";
				attribute :>> convergenceCriteria = 0.001;
			}
			
			part :>> dataRepository {
				attribute :>> storageCapacity = 50000.0;
				attribute :>> versionControl = true;
			}
			
			part :>> reviewBoard {
				attribute :>> approvalAuthority = "Chief Engineering Officer";
			}
			
			exhibit state lifecycle : EngineeringDesignLifecycle;
		}
	}

	package 'System Requirements' {
		private import 'System Definition'::*;
		private import 'System Instance'::*;
		private import 'Value and Item Definitions'::*;
		
		requirement def <'REQ-001'> DesignQualityRequirement {
			doc /* The engineering design system shall produce designs that meet minimum quality standards. */
			subject system : EngineeringDesignSystem;
			attribute minimumQuality : QualityScoreValue;
			require constraint {
				system.overallQualityScore >= minimumQuality
			}
		}
		
		requirement def <'REQ-002'> ProjectCostRequirement {
			doc /* The engineering design system shall complete projects within budget constraints. */
			subject system : EngineeringDesignSystem;
			attribute budgetLimit : CostValue;
			require constraint {
				system.totalProjectCost <= budgetLimit
			}
		}
		
		requirement def <'REQ-003'> ScheduleComplianceRequirement {
			doc /* The engineering design system shall deliver validated designs within schedule. */
			subject system : EngineeringDesignSystem;
			attribute scheduleLimit : TimeValue;
			require constraint {
				system.projectSchedule <= scheduleLimit
			}
		}
		
		requirement <'REQ-001.1'> aerospaceQuality : DesignQualityRequirement {
			subject :>> system = aerospaceStructureDesignSystem;
			attribute :>> minimumQuality = 0.90;
		}
		
		requirement <'REQ-002.1'> aerospaceBudget : ProjectCostRequirement {
			subject :>> system = aerospaceStructureDesignSystem;
			attribute :>> budgetLimit = 3000000.0;
		}
		
		requirement <'REQ-003.1'> aerospaceSchedule : ScheduleComplianceRequirement {
			subject :>> system = aerospaceStructureDesignSystem;
			attribute :>> scheduleLimit = 24.0 [mo];
		}
	}
}
