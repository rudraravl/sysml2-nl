package 'DARPA Advanced Technology Development System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SecurityClassification;
	attribute def TechnologyReadinessLevel;
	attribute def RiskLevel;
	
	item def ResearchProposal {
		attribute proposalId : String;
		attribute technicalArea : String;
		attribute requestedFunding : Real;
		attribute proposedDuration : TimeValue;
		attribute innovationScore : Real;
	}
	
	item def FundingDecision {
		attribute approved : Boolean;
		attribute allocatedAmount : Real;
		attribute conditions : String[*];
	}
	
	item def TechnicalData {
		attribute dataId : String;
		attribute classification : SecurityClassification;
		attribute trl : TechnologyReadinessLevel;
		attribute performanceMetrics : Real[*];
	}
	
	item def Prototype {
		attribute prototypeId : String;
		attribute trl : TechnologyReadinessLevel;
		attribute capabilities : String[*];
		attribute testResults : Real[*];
	}
	
	item def TransitionPackage {
		attribute targetAgency : String;
		attribute prototype : Prototype;
		attribute documentation : String[*];
		attribute readinessAssessment : Boolean;
	}
	
	value def FundingValue {
		attribute amount : Real;
		attribute currency : String = "USD";
	}
	
	port def ProposalIntakePort {
		in item proposal : ResearchProposal;
	}
	
	port def FundingPort {
		out item decision : FundingDecision;
		out attribute funding : FundingValue;
	}
	
	port def DataExchangePort {
		inout item technicalData : TechnicalData;
	}
	
	port def PrototypeDeliveryPort {
		out item prototype : Prototype;
	}
	
	port def TransitionPort {
		out item transitionPackage : TransitionPackage;
	}
	
	part def ProgramManager {
		attribute programName : String;
		attribute focusArea : String;
		port proposalInput : ProposalIntakePort;
		port fundingOutput : FundingPort;
		port dataExchange : DataExchangePort;
		perform action manageProgram;
	}
	
	part def TechnicalReviewBoard {
		attribute reviewers : String[*];
		port proposalReview : ProposalIntakePort;
		perform action evaluateProposal;
	}
	
	part def ResearchPerformer {
		attribute organizationName : String;
		attribute expertise : String[*];
		port fundingInput : FundingPort;
		port dataOutput : DataExchangePort;
		port prototypeOutput : PrototypeDeliveryPort;
		perform action conductResearch;
	}
	
	part def TestAndEvaluationFacility {
		attribute facilityName : String;
		attribute capabilities : String[*];
		port prototypeInput : PrototypeDeliveryPort;
		port dataOutput : DataExchangePort;
		perform action testPrototype;
	}
	
	part def TransitionOffice {
		attribute partnerAgencies : String[*];
		port prototypeInput : PrototypeDeliveryPort;
		port transitionOutput : TransitionPort;
		perform action transitionTechnology;
	}
	
	action def EvaluateProposal {
		in proposal : ResearchProposal;
		out technicalScore : Real;
		out innovationScore : Real;
		out riskAssessment : RiskLevel;
		out fundingRecommendation : FundingDecision;
	}
	
	action def AllocateFunding {
		in fundingRecommendation : FundingDecision;
		in availableBudget : FundingValue;
		out fundingDecision : FundingDecision;
		out allocatedFunding : FundingValue;
	}
	
	action def ConductResearchPhase {
		in fundingAmount : FundingValue;
		in objectives : String[*];
		in phaseDuration : TimeValue;
		out technicalData : TechnicalData;
		out prototype : Prototype;
		out phaseComplete : Boolean;
	}
	
	action def TestPrototype {
		in prototype : Prototype;
		in testCriteria : String[*];
		out testResults : Real[*];
		out performanceValidated : Boolean;
		out updatedTRL : TechnologyReadinessLevel;
	}
	
	action def AssessTransitionReadiness {
		in prototype : Prototype;
		in trl : TechnologyReadinessLevel;
		out transitionReady : Boolean;
		out transitionPlan : String[*];
	}
	
	action def TransferTechnology {
		in prototype : Prototype;
		in targetAgency : String;
		out transitionPackage : TransitionPackage;
		out transferComplete : Boolean;
	}
	
	action def ManageDARPAProgram {
		first start;
		then merge programLoop;
		
		then action solicitProposals {
			out proposals : ResearchProposal[*];
		}
		
		then action evaluateSubmissions : EvaluateProposal[*] {
			in proposal : ResearchProposal[*] = solicitProposals.proposals;
			out technicalScore : Real[*];
			out innovationScore : Real[*];
			out fundingRecommendation : FundingDecision[*];
		}
		
		then action allocateFunds : AllocateFunding[*] {
			in fundingRecommendation : FundingDecision[*] = evaluateSubmissions.fundingRecommendation;
			out fundingDecision : FundingDecision[*];
			out allocatedFunding : FundingValue[*];
		}
		
		then decide;
			if allocateFunds.fundingDecision->exists(d | d.approved) then executeProgram;
			if allocateFunds.fundingDecision->forAll(d | not d.approved) then programLoop;
		
		action executeProgram {
			first startExecution;
			then merge researchCycle;
			
			then action performResearch : ConductResearchPhase {
				in fundingAmount : FundingValue;
				in objectives : String[*];
				out technicalData : TechnicalData;
				out prototype : Prototype;
				out phaseComplete : Boolean;
			}
			
			then action testResults : TestPrototype {
				in prototype = performResearch.prototype;
				out testResults : Real[*];
				out performanceValidated : Boolean;
				out updatedTRL : TechnologyReadinessLevel;
			}
			
			then action assessReadiness : AssessTransitionReadiness {
				in prototype = performResearch.prototype;
				in trl = testResults.updatedTRL;
				out transitionReady : Boolean;
			}
			
			then decide;
				if assessReadiness.transitionReady then transitionPhase;
				if not assessReadiness.transitionReady and testResults.performanceValidated then researchCycle;
				if not testResults.performanceValidated then terminateProgram;
			
			action terminateProgram;
			then programLoop;
		}
		
		then action transitionPhase : TransferTechnology {
			in prototype = executeProgram.performResearch.prototype;
			out transitionPackage : TransitionPackage;
			out transferComplete : Boolean;
		}
		
		then decide;
			if transitionPhase.transferComplete then programSuccess;
			if not transitionPhase.transferComplete then programLoop;
		
		action programSuccess;
		then done;
	}
	
	part darpaSystem : DARPASystem {
		part programOffice : ProgramManager {
			attribute programName = "Advanced Technology Development";
			attribute focusArea = "Breakthrough Military Capabilities";
			perform action manageProgramLifecycle : ManageDARPAProgram;
		}
		
		part reviewBoard : TechnicalReviewBoard {
			attribute reviewers = ("Technical Expert 1", "Technical Expert 2", "Military Advisor");
			perform manageProgramLifecycle.evaluateSubmissions;
		}
		
		part performers : ResearchPerformer[1..*] {
			perform manageProgramLifecycle.executeProgram.performResearch;
		}
		
		part testFacility : TestAndEvaluationFacility {
			attribute facilityName = "Advanced Testing Center";
			attribute capabilities = ("Prototype Testing", "Performance Validation", "Environmental Testing");
			perform manageProgramLifecycle.executeProgram.testResults;
		}
		
		part transitionTeam : TransitionOffice {
			attribute partnerAgencies = ("Department of Defense", "Military Services", "Intelligence Community");
			perform manageProgramLifecycle.transitionPhase;
		}
		
		connection proposalFlow : ProposalConnection
			connect programOffice.proposalInput to reviewBoard.proposalReview;
		
		connection fundingFlow : FundingConnection[*]
			connect programOffice.fundingOutput to performers.fundingInput;
		
		connection dataFlow : DataConnection[*]
			connect performers.dataOutput to programOffice.dataExchange;
		
		connection prototypeToTest : PrototypeConnection[*]
			connect performers.prototypeOutput to testFacility.prototypeInput;
		
		connection prototypeToTransition : PrototypeConnection[*]
			connect performers.prototypeOutput to transitionTeam.prototypeInput;
		
		connection testDataFlow : DataConnection
			connect testFacility.dataOutput to programOffice.dataExchange;
	}
	
	part def DARPASystem {
		attribute missionStatement : String = "Create breakthrough technologies and capabilities for national security";
		attribute strategicFocusAreas : String[*] = ("Artificial Intelligence", "Hypersonics", "Biotechnology", "Quantum Science", "Space Technology", "Cyber Capabilities");
		attribute operatingPrinciple : String = "High-risk, high-reward research to prevent technological surprise";
	}
	
	connection def ProposalConnection {
		end source : ProposalIntakePort;
		end target : ProposalIntakePort;
	}
	
	connection def FundingConnection {
		end source : FundingPort;
		end target : FundingPort;
	}
	
	connection def DataConnection {
		end source : DataExchangePort;
		end target : DataExchangePort;
	}
	
	connection def PrototypeConnection {
		end source : PrototypeDeliveryPort;
		end target : PrototypeDeliveryPort;
	}
	
	requirement def MissionRequirement {
		doc /* DARPA shall develop and transition breakthrough technologies that provide decisive military advantage and prevent technological surprise. */
		
		subject darpaSystem : DARPASystem;
		
		require constraint technologicalLeadership {
			doc /* Technologies developed shall represent significant advancement beyond current state-of-the-art. */
		}
	}
	
	requirement def InnovationRequirement {
		doc /* Research programs shall pursue high-risk, high-reward approaches that conventional funding would not support. */
		
		require constraint riskTolerance {
			doc /* Programs shall accept technical risk in pursuit of revolutionary capabilities. */
		}
		
		require constraint trlProgression {
			doc /* Programs shall advance technology readiness from concept through prototype demonstration. */
		}
	}
	
	requirement def TransitionRequirement {
		doc /* Successful technologies shall transition to military services or other government agencies for operational use. */
		
		assume constraint prototypeValidation {
			doc /* Prototypes must demonstrate required performance in relevant environments. */
		}
		
		require constraint transitionPath {
			doc /* Each program shall identify and engage transition partners early in development. */
		}
	}
	
	requirement def TimelineRequirement {
		doc /* Programs shall progress from concept to prototype demonstration within 3-5 years. */
		
		require constraint acceleratedDevelopment {
			doc /* Development timelines shall be significantly shorter than traditional acquisition programs. */
		}
	}
	
	requirement <'DARPA-MISSION-001'> primaryMission : MissionRequirement {
		subject systemUnderDevelopment = darpaSystem;
		
		assume constraint fundingAuthority {
			doc /* Adequate funding is available to support high-risk research programs. */
		}
		
		assume constraint technicalExpertise {
			doc /* Access to world-class researchers and performers is available. */
		}
		
		require innovationGoal : InnovationRequirement;
		require transitionGoal : TransitionRequirement;
		require timelineGoal : TimelineRequirement;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'DARPA Advanced Technology Development System'::*;

    action orchestrator {
        item testProposal : ResearchProposal {
            attribute proposalId = "";
            attribute technicalArea = "";
            attribute requestedFunding = 0.0;
            attribute proposedDuration : TimeValue;
            attribute innovationScore = 0.0;
        }
        action actionProbe : EvaluateProposal {
            in proposal = testProposal;
        }
        first actionProbe;
    }
}
