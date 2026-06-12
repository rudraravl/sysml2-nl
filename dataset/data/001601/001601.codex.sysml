package TechnologyRoadmapBasedSystem {

    import ScalarValues::*;
    import Quantities::*;
    import ISQ::*;
    import SI::*;

    attribute def Currency;
    attribute def Percentage;
    attribute def Score;
    attribute def QuarterIndex;
    attribute def RiskLevel;
    attribute def PriorityLevel;

    enum def RoadmapHorizon {
        enum shortTerm;
        enum midTerm;
        enum longTerm;
    }

    enum def TechnologyMaturity {
        enum emerging;
        enum evaluated;
        enum piloted;
        enum productionReady;
        enum retired;
    }

    enum def InvestmentDecision {
        enum defer;
        enum investigate;
        enum prototype;
        enum scale;
        enum retire;
    }

    item def MarketSignal {
        attribute source : String;
        attribute trendStrength : Score;
        attribute uncertainty : Percentage;
        attribute observedQuarter : QuarterIndex;
    }

    item def CapabilityNeed {
        attribute name : String;
        attribute businessValue : Score;
        attribute urgency : PriorityLevel;
        attribute requiredByQuarter : QuarterIndex;
    }

    item def TechnologyCandidate {
        attribute name : String;
        attribute domain : String;
        attribute maturity : TechnologyMaturity;
        attribute estimatedCost : Currency;
        attribute expectedValue : Currency;
        attribute deliveryRisk : RiskLevel;
        attribute sustainabilityImpact : Percentage;
    }

    item def RoadmapInitiative {
        attribute title : String;
        attribute horizon : RoadmapHorizon;
        attribute startQuarter : QuarterIndex;
        attribute finishQuarter : QuarterIndex;
        attribute budget : Currency;
        attribute expectedBenefit : Currency;
        attribute decision : InvestmentDecision;
    }

    item def PortfolioStatus {
        attribute activeInitiatives : Integer;
        attribute totalBudget : Currency;
        attribute weightedRisk : RiskLevel;
        attribute projectedBenefit : Currency;
        attribute roadmapCoverage : Percentage;
    }

    item def ExecutiveGuidance {
        attribute approvedBudget : Currency;
        attribute strategicPriority : PriorityLevel;
        attribute riskTolerance : RiskLevel;
    }

    port def SignalInputPort {
        in item signal : MarketSignal;
    }

    port def NeedInputPort {
        in item need : CapabilityNeed;
    }

    port def CandidateInputPort {
        in item candidate : TechnologyCandidate;
    }

    port def GuidanceInputPort {
        in item guidance : ExecutiveGuidance;
    }

    port def InitiativeOutputPort {
        out item initiative : RoadmapInitiative;
    }

    port def StatusOutputPort {
        out item status : PortfolioStatus;
    }

    port def ReviewPort {
        in item proposedInitiative : RoadmapInitiative;
        out item approvedInitiative : RoadmapInitiative;
    }

    part def TechnologyRoadmapSystem {
        attribute planningCycleTime : Time = 90 [SI::d];
        attribute minimumValueScore : Score = 70;
        attribute maximumAcceptedRisk : RiskLevel = 6;
        attribute annualPlanningBudget : Currency;

        port marketSignalIn : SignalInputPort;
        port capabilityNeedIn : NeedInputPort;
        port candidateIn : CandidateInputPort;
        port guidanceIn : GuidanceInputPort;
        port initiativeOut : InitiativeOutputPort;
        port portfolioStatusOut : StatusOutputPort;

        part signalCollector : SignalCollectionSubsystem;
        part capabilityAnalyzer : CapabilityAnalysisSubsystem;
        part technologyEvaluator : TechnologyEvaluationSubsystem;
        part roadmapOptimizer : RoadmapOptimizationSubsystem;
        part governanceBoard : GovernanceSubsystem;
        part portfolioMonitor : PortfolioMonitoringSubsystem;

        connect marketSignalIn to signalCollector.externalSignalIn;
        connect capabilityNeedIn to capabilityAnalyzer.externalNeedIn;
        connect candidateIn to technologyEvaluator.externalCandidateIn;
        connect guidanceIn to governanceBoard.guidanceIn;

        connect signalCollector.normalizedSignalOut to capabilityAnalyzer.signalIn;
        connect capabilityAnalyzer.prioritizedNeedOut to roadmapOptimizer.needIn;
        connect technologyEvaluator.rankedCandidateOut to roadmapOptimizer.candidateIn;
        connect roadmapOptimizer.proposedInitiativeOut to governanceBoard.reviewIn;
        connect governanceBoard.approvedInitiativeOut to portfolioMonitor.initiativeIn;
        connect governanceBoard.approvedInitiativeOut to initiativeOut;
        connect portfolioMonitor.statusOut to portfolioStatusOut;

        perform action ManageRoadmapLifecycle;
        exhibit state RoadmapOperatingState;
    }

    part def SignalCollectionSubsystem {
        port externalSignalIn : SignalInputPort;
        port normalizedSignalOut {
            out item signal : MarketSignal;
        }

        action normalizeSignals {
            in item rawSignal : MarketSignal;
            out item normalizedSignal : MarketSignal;
        }
    }

    part def CapabilityAnalysisSubsystem {
        port externalNeedIn : NeedInputPort;
        port signalIn {
            in item signal : MarketSignal;
        }
        port prioritizedNeedOut {
            out item need : CapabilityNeed;
        }

        action assessCapabilityGap {
            in item need : CapabilityNeed;
            in item signal : MarketSignal;
            out item prioritizedNeed : CapabilityNeed;
        }
    }

    part def TechnologyEvaluationSubsystem {
        port externalCandidateIn : CandidateInputPort;
        port rankedCandidateOut {
            out item candidate : TechnologyCandidate;
        }

        action evaluateCandidate {
            in item candidate : TechnologyCandidate;
            out attribute valueScore : Score;
            out attribute riskScore : RiskLevel;
            out item rankedCandidate : TechnologyCandidate;
        }
    }

    part def RoadmapOptimizationSubsystem {
        port needIn {
            in item need : CapabilityNeed;
        }
        port candidateIn {
            in item candidate : TechnologyCandidate;
        }
        port proposedInitiativeOut {
            out item initiative : RoadmapInitiative;
        }

        action buildRoadmapInitiative {
            in item prioritizedNeed : CapabilityNeed;
            in item rankedCandidate : TechnologyCandidate;
            out item proposedInitiative : RoadmapInitiative;
        }

        constraint budgetFeasibility {
            in attribute initiativeBudget : Currency;
            in attribute availableBudget : Currency;
            initiativeBudget <= availableBudget;
        }

        constraint scheduleAlignment {
            in attribute finishQuarter : QuarterIndex;
            in attribute requiredByQuarter : QuarterIndex;
            finishQuarter <= requiredByQuarter;
        }
    }

    part def GovernanceSubsystem {
        port guidanceIn : GuidanceInputPort;
        port reviewIn : ReviewPort;
        port approvedInitiativeOut {
            out item initiative : RoadmapInitiative;
        }

        action approveInvestment {
            in item proposedInitiative : RoadmapInitiative;
            in item guidance : ExecutiveGuidance;
            out item approvedInitiative : RoadmapInitiative;
        }
    }

    part def PortfolioMonitoringSubsystem {
        port initiativeIn {
            in item initiative : RoadmapInitiative;
        }
        port statusOut : StatusOutputPort;

        action updatePortfolioStatus {
            in item initiative : RoadmapInitiative;
            out item status : PortfolioStatus;
        }
    }

    action def ManageRoadmapLifecycle {
        in item signals : MarketSignal;
        in item needs : CapabilityNeed;
        in item candidates : TechnologyCandidate;
        in item guidance : ExecutiveGuidance;
        out item approvedInitiatives : RoadmapInitiative;
        out item portfolioStatus : PortfolioStatus;

        first collectSignals;
        then analyzeNeeds;
        then evaluateTechnologies;
        then optimizeRoadmap;
        then governInvestments;
        then monitorPortfolio;

        action collectSignals {
            in item rawSignals : MarketSignal;
            out item normalizedSignals : MarketSignal;
        }

        action analyzeNeeds {
            in item normalizedSignals : MarketSignal;
            in item rawNeeds : CapabilityNeed;
            out item prioritizedNeeds : CapabilityNeed;
        }

        action evaluateTechnologies {
            in item rawCandidates : TechnologyCandidate;
            out item rankedCandidates : TechnologyCandidate;
        }

        action optimizeRoadmap {
            in item prioritizedNeeds : CapabilityNeed;
            in item rankedCandidates : TechnologyCandidate;
            out item proposedInitiatives : RoadmapInitiative;
        }

        action governInvestments {
            in item proposedInitiatives : RoadmapInitiative;
            in item guidance : ExecutiveGuidance;
            out item approvedInitiatives : RoadmapInitiative;
        }

        action monitorPortfolio {
            in item approvedInitiatives : RoadmapInitiative;
            out item portfolioStatus : PortfolioStatus;
        }
    }

    state def RoadmapOperatingState {
        entry action initializePlanningCycle;

        state CollectingInputs;
        state AssessingCapabilities;
        state EvaluatingTechnologies;
        state OptimizingRoadmap;
        state AwaitingGovernanceDecision;
        state PublishingRoadmap;
        state MonitoringExecution;
        state Replanning;

        transition first CollectingInputs;
        transition CollectingInputs then AssessingCapabilities
            accept after 10 [SI::d];

        transition AssessingCapabilities then EvaluatingTechnologies
            accept when capabilityAnalyzer.prioritizedNeedOut.need.businessValue >= 70;

        transition EvaluatingTechnologies then OptimizingRoadmap
            accept when technologyEvaluator.rankedCandidateOut.candidate.maturity != TechnologyMaturity::emerging;

        transition OptimizingRoadmap then AwaitingGovernanceDecision
            accept when roadmapOptimizer.proposedInitiativeOut.initiative.budget <= guidanceIn.guidance.approvedBudget;

        transition AwaitingGovernanceDecision then PublishingRoadmap
            accept when governanceBoard.approvedInitiativeOut.initiative.decision == InvestmentDecision::scale;

        transition AwaitingGovernanceDecision then Replanning
            accept when governanceBoard.approvedInitiativeOut.initiative.decision == InvestmentDecision::defer;

        transition PublishingRoadmap then MonitoringExecution;
        transition MonitoringExecution then Replanning
            accept after 90 [SI::d];

        transition Replanning then CollectingInputs;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : TechnologyRoadmapSystem;

        doc /* The system shall transform market signals, capability needs, technology candidates, and executive guidance into an approved technology roadmap that prioritizes investments, schedules initiatives, controls risk, and reports portfolio status. */

        require constraint {
            system.planningCycleTime <= 90 [SI::d]
        }
    }

    requirement def RoadmapPrioritizationRequirement {
        subject optimizer : RoadmapOptimizationSubsystem;

        doc /* The roadmap optimizer shall propose initiatives that align high-value capability needs with feasible technology candidates within approved budget and required delivery quarters. */
    }

    requirement def GovernanceRequirement {
        subject governance : GovernanceSubsystem;

        doc /* The governance subsystem shall approve, defer, prototype, scale, or retire roadmap initiatives according to budget authority, strategic priority, and risk tolerance. */
    }

    requirement def MonitoringRequirement {
        subject monitor : PortfolioMonitoringSubsystem;

        doc /* The portfolio monitor shall publish current roadmap coverage, active initiative count, weighted risk, total budget, and projected benefit for executive review each planning cycle. */
    }

    requirement def TraceabilityRequirement {
        subject system : TechnologyRoadmapSystem;

        doc /* Each approved roadmap initiative shall be traceable to at least one capability need, one technology candidate, and one executive guidance input. */
    }

    part roadmapEnterpriseSystem : TechnologyRoadmapSystem {
        attribute annualPlanningBudget = 25000000;
    }

    satisfy PrimaryFunctionRequirement by roadmapEnterpriseSystem;
    satisfy RoadmapPrioritizationRequirement by roadmapEnterpriseSystem.roadmapOptimizer;
    satisfy GovernanceRequirement by roadmapEnterpriseSystem.governanceBoard;
    satisfy MonitoringRequirement by roadmapEnterpriseSystem.portfolioMonitor;
    satisfy TraceabilityRequirement by roadmapEnterpriseSystem;
}