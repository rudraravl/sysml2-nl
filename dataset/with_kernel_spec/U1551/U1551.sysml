package AdvancedTechnologyDevelopmentAgency {
    private import ScalarValues::*;
    private import SI::kilogram;

    unit def usd;
    unit def pct;
    unit def mon;

    value def FundingAmount :> Real {
        :>> unit = usd;
    }
    value def Percentage :> Real {
        :>> unit = pct;
    }
    value def Mass :> Real {
        :>> unit = kilogram;
    }
    value def Duration :> Real {
        :>> unit = mon;
    }

    enum def TechnicalArea {
        artificialIntelligence;
        hypersonics;
        biotechnology;
        quantum;
        cybersecurity;
    }

    enum def RiskLevel {
        low;
        medium;
        high;
        veryHigh;
    }

    enum def TechnologyReadinessLevel {
        trl1 = 1;
        trl2 = 2;
        trl3 = 3;
        trl4 = 4;
        trl5 = 5;
        trl6 = 6;
        trl7 = 7;
        trl8 = 8;
        trl9 = 9;
    }

    item def ResearchProposal {
        attribute title : String;
        attribute technicalArea : TechnicalArea;
        attribute requestedFunding : FundingAmount;
        attribute riskLevel : RiskLevel;
    }

    item def TechnicalData {
        attribute description : String;
        attribute performanceMetrics : Percentage[*];
    }

    item def EvaluationReport {
        attribute summary : String;
        attribute recommendation : String;
    }

    item def Prototype {
        attribute identifier : String;
        attribute trl : TechnologyReadinessLevel;
        attribute performanceMetric : Percentage;
        attribute mass : Mass;
        item technicalData : TechnicalData[*];
    }

    item def TransitionPackage {
        item prototype : Prototype;
        attribute documentationComplete : Boolean;
        attribute assessmentReport : String;
    }

    port def ProposalPort {
        out proposals : ResearchProposal[*];
    }

    port def RecommendationPort {
        out recommendations : Boolean[*];
        out scores : Percentage[*];
    }

    port def FundingPort {
        out funding : FundingAmount;
    }

    port def PrototypePort {
        out prototype : Prototype;
        out technicalData : TechnicalData;
    }

    port def TestResultsPort {
        out validatedPrototype : Prototype;
        out trl : TechnologyReadinessLevel;
        out testReport : EvaluationReport;
    }

    port def TransitionPackagePort {
        out transitionPackage : TransitionPackage;
    }

    action def DefineTechnicalChallenge {
        out challenge : String;
    }

    action def SolicitProposals {
        out proposals : ResearchProposal[*];
    }

    action def EvaluateProposalsAction {
        in proposals : ResearchProposal[*];
        out approved : Boolean;
    }

    action def AwardFunding {
        out funding : FundingAmount;
    }

    action def OverseeTransition {
        in transitionPackage : TransitionPackage;
    }

    action def ReviewProposals {
        in proposals : ResearchProposal[*];
        out recommendations : Boolean[*];
        out scores : Percentage[*];

        action assessTechnicalMerit;
        then assessInnovation;
        action assessInnovation;
        then assessRisk;
        action assessRisk;
        then compileRecommendations;
        action compileRecommendations {
            out recommendations;
            out scores;
        }
    }

    action def ConductResearch {
        in funding : FundingAmount;
        out prototype : Prototype;
        out technicalData : TechnicalData;

        action designConcept;
        then buildPrototype;
        action buildPrototype {
            out prototype;
        }
        then generateMetrics;
        action generateMetrics {
            out technicalData;
        }
    }

    action def ConductTesting {
        in prototype : Prototype;
        in technicalData : TechnicalData;
        out validatedPrototype : Prototype;
        out trl : TechnologyReadinessLevel;
        out testReport : EvaluationReport;

        action setupTest;
        then executeTests;
        action executeTests {
            out rawResults : Percentage;
        }
        then assessTRL;
        action assessTRL {
            out trl;
        }
        then determineOutcome;
        action determineOutcome {
            out validatedPrototype;
            out testReport;
        }
    }

    action def PrepareTransition {
        in validatedPrototype : Prototype;
        in trl : TechnologyReadinessLevel;
        out transitionPackage : TransitionPackage;

        action compileDocumentation;
        then prepareAssessment;
        action prepareAssessment {
            out assessmentReport : String;
        }
        then assemblePackage;
        action assemblePackage {
            out transitionPackage;
        }
    }

    state machine def ProgramLifecycle {
        attribute challengeDefined : Boolean = false;
        attribute proposalsReceived : Boolean = false;
        attribute proposalsApproved : Boolean = false;
        attribute prototypeReady : Boolean = false;
        attribute testSuccessful : Boolean = false;
        attribute testFailed : Boolean = false;
        attribute transitionComplete : Boolean = false;

        entry;
        then conceptDefinition;
        state conceptDefinition;
        transition conceptDefinition to solicitation [challengeDefined];
        state solicitation;
        transition solicitation to proposalEvaluation [proposalsReceived];
        state proposalEvaluation;
        transition proposalEvaluation to researchExecution [proposalsApproved];
        state researchExecution;
        transition researchExecution to prototypeTesting [prototypeReady];
        state prototypeTesting;
        transition prototypeTesting to technologyTransition [testSuccessful];
        transition prototypeTesting to researchExecution [testFailed];
        state technologyTransition;
        transition technologyTransition to done [transitionComplete];
        state done;
    }

    state machine def DevelopmentProcess {
        attribute conceptValidated : Boolean = false;
        attribute prototypeInitialized : Boolean = false;
        attribute prototypeReady : Boolean = false;

        entry;
        then conceptRefinement;
        state conceptRefinement;
        transition conceptRefinement to earlyPrototyping [conceptValidated];
        state earlyPrototyping;
        transition earlyPrototyping to advancedDevelopment [prototypeInitialized];
        state advancedDevelopment;
        transition advancedDevelopment to finalDelivery [prototypeReady];
        state finalDelivery;
    }

    part def ProgramManager {
        port submissionPort : ProposalPort;
        port recommendationInPort : ~RecommendationPort;
        port awardPort : FundingPort;
        port transitionInPort : ~TransitionPackagePort;

        attribute programName : String;
        attribute technicalChallenge : String;
        attribute programBudget : FundingAmount;
    }

    part def TechnicalReviewBoard {
        port reviewPort : ~ProposalPort;
        port recommendationPort : RecommendationPort;

        attribute memberCount : Integer;
        attribute expertiseAreas : TechnicalArea[*];
    }

    part def ResearchPerformer {
        port fundingPort : ~FundingPort;
        port deliveryPort : PrototypePort;

        attribute organizationName : String;
        attribute organizationType : String;
        attribute currentTRL : TechnologyReadinessLevel;
    }

    part def TestAndEvaluationFacility {
        port testPort : ~PrototypePort;
        port resultsPort : TestResultsPort;

        attribute facilityName : String;
        attribute testCriteria : String;
        attribute minimumTRL : TechnologyReadinessLevel = trl6;
    }

    part def TransitionOffice {
        port transitionPort : ~TestResultsPort;
        port handoffPort : TransitionPackagePort;

        attribute partnerAgency : String;
        attribute transitionTimeline : Duration;
    }

    part def PartnerAgency {
        port intakePort : ~TransitionPackagePort;
        attribute agencyName : String;
    }

    part def AdvancedTechnologyDevelopmentAgency {
        part programManager : ProgramManager;
        part reviewBoard : TechnicalReviewBoard;
        part performer : ResearchPerformer;
        part testFacility : TestAndEvaluationFacility;
        part transitionOffice : TransitionOffice;
        part partnerAgency : PartnerAgency;

        connect programManager.submissionPort to reviewBoard.reviewPort;
        connect reviewBoard.recommendationPort to programManager.recommendationInPort;
        connect programManager.awardPort to performer.fundingPort;
        connect performer.deliveryPort to testFacility.testPort;
        connect testFacility.resultsPort to transitionOffice.transitionPort;
        connect transitionOffice.handoffPort to partnerAgency.intakePort;
        connect transitionOffice.handoffPort to programManager.transitionInPort;
    }

    part agency : AdvancedTechnologyDevelopmentAgency {
        part :>> programManager {
            attribute programName = "Project Vanguard";
            attribute technicalChallenge = "Prevent technological surprise in national security domains";
            attribute programBudget = 50.0;
        }
        part :>> reviewBoard {
            attribute memberCount = 7;
            attribute expertiseAreas = (artificialIntelligence, hypersonics, biotechnology);
        }
        part :>> performer {
            attribute organizationName = "Advanced Research Laboratory";
            attribute organizationType = "University";
            attribute currentTRL = trl3;
        }
        part :>> testFacility {
            attribute facilityName = "National Test Center";
            attribute testCriteria = "Performance threshold validation";
        }
        part :>> transitionOffice {
            attribute partnerAgency = "Department of Defense";
            attribute transitionTimeline = 12.0;
        }
        part :>> partnerAgency {
            attribute agencyName = "United States Air Force";
        }

        exhibit programLifecycle : ProgramLifecycle;
    }

    requirement def MissionRequirement {
        doc /* The agency shall create breakthrough technologies and capabilities for national security. */
    }

    requirement def TechnicalChallengeRequirement {
        doc /* The Program Manager shall define a technical challenge to prevent technological surprise. */
    }

    requirement def ProposalEvaluationRequirement {
        doc /* The Technical Review Board shall evaluate the technical merit, innovation, and risk of each Research Proposal. */
    }

    requirement def PrototypeDevelopmentRequirement {
        doc /* The Research Performer shall mature a concept into a functional Prototype. */
    }

    requirement def PrototypeTestingRequirement {
        doc /* The Test and Evaluation Facility shall validate the performance of the Prototype and determine its TRL. */
    }

    requirement def TRLValidationRequirement {
        doc /* Prototypes shall achieve a minimum TRL of 6 before transition. */
        subject prototype : Prototype;
        constraint minTRL: prototype.trl >= trl6;
    }

    requirement def TransitionRequirement {
        doc /* The Transition Office shall prepare a complete Transition Package for operational use. */
    }

    requirement agencyMission : MissionRequirement;
    requirement techChallenge : TechnicalChallengeRequirement;
    requirement proposalEval : ProposalEvaluationRequirement;
    requirement prototypeDev : PrototypeDevelopmentRequirement;
    requirement prototypeTest : PrototypeTestingRequirement;
    requirement trlValid : TRLValidationRequirement;
    requirement transitionReady : TransitionRequirement;

    satisfy agencyMission by agency;
    satisfy techChallenge by agency.programManager;
    satisfy proposalEval by agency.reviewBoard;
    satisfy prototypeDev by agency.performer;
    satisfy prototypeTest by agency.testFacility;
    satisfy trlValid by agency.testFacility;
    satisfy transitionReady by agency.transitionOffice;
}
