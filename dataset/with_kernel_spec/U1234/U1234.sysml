package 'Technology Scouting System' {
	private import ScalarValues::*;

	value type TRL :> Integer;
	value type ScoreValue :> Real;
	value type USDAmount :> Real;

	item def TechnologySignal {
		attribute sourceType : String;
		attribute sourceId : String;
		attribute snippet : String;
		attribute capturedTimestamp : Real;
	}

	item def TechnologyCandidate {
		attribute name : String;
		attribute description : String;
		attribute maturityLevel : TRL;
		attribute potentialApplications : String[*];
		attribute competitiveImpact : String;
	}

	item def AnalysisResult {
		attribute candidateName : String;
		attribute technicalFeasibility : ScoreValue;
		attribute marketPotential : ScoreValue;
		attribute strategicAlignment : ScoreValue;
		attribute implementationCost : USDAmount;
		attribute overallScore : ScoreValue;
	}

	item def PrioritizedCandidate {
		attribute rank : Integer;
		attribute candidateName : String;
		attribute overallScore : ScoreValue;
	}

	item def ScoutingReport {
		attribute executiveSummary : String;
		attribute topCandidates : PrioritizedCandidate[*];
		attribute trendAnalysis : String;
		attribute recommendations : String;
		attribute generatedTimestamp : Real;
	}

	item def AlertNotification {
		attribute subject : String;
		attribute body : String;
		attribute deliveryChannel : String;
	}

	attribute def PauseRequested;
	attribute def ResumeRequested;
	attribute def MaintenanceRequested;
	attribute def MaintenanceComplete;

	calc def TechFeasibilityCalc {
		in candidate : TechnologyCandidate;
		return score : ScoreValue;
	}
	calc def MarketPotentialCalc {
		in candidate : TechnologyCandidate;
		return score : ScoreValue;
	}
	calc def StrategicAlignmentCalc {
		in candidate : TechnologyCandidate;
		return score : ScoreValue;
	}
	calc def ImplementationCostCalc {
		in candidate : TechnologyCandidate;
		return cost : USDAmount;
	}
	calc def WeightedScoreCalc {
		in technicalFeasibility : ScoreValue;
		in marketPotential : ScoreValue;
		in strategicAlignment : ScoreValue;
		in implementationCost : USDAmount;
		return overallScore : ScoreValue;
	}

	part def DataSource {
		attribute sourceType : String;
		port signalOut {
			out signal : TechnologySignal;
		}
	}

	part def PatentDatabase :> DataSource {
		attribute :>> sourceType = "Patent Database";
	}
	part def ResearchPublicationDB :> DataSource {
		attribute :>> sourceType = "Research Publication";
	}
	part def IndustryReportDB :> DataSource {
		attribute :>> sourceType = "Industry Report";
	}
	part def StartupNewsFeed :> DataSource {
		attribute :>> sourceType = "Startup News";
	}

	part def DataCollectionModule {
		port signalIn {
			in signal : TechnologySignal;
		}
		port candidateOut {
			out candidate : TechnologyCandidate;
		}
		action captureSignal {
			in signal : TechnologySignal;
			out candidate : TechnologyCandidate;
		}
	}

	part def AnalysisEngine {
		port candidateIn {
			in candidate : TechnologyCandidate;
		}
		port resultOut {
			out result : AnalysisResult;
		}
		action analyzeCandidate {
			in candidate : TechnologyCandidate;
			out result : AnalysisResult;
		}
	}

	part def PrioritizationModule {
		port resultIn {
			in result : AnalysisResult;
		}
		port rankedOut {
			out ranked : PrioritizedCandidate;
		}
		action prioritize {
			in results : AnalysisResult[*];
			out ranked : PrioritizedCandidate[*];
		}
	}

	part def KnowledgeRepository {
		port storeIn {
			in report : ScoutingReport;
		}
		attribute historicalReports : ScoutingReport[*];
		action storeReport {
			in report : ScoutingReport;
		}
	}

	part def ReportingModule {
		port rankedIn {
			in ranked : PrioritizedCandidate;
		}
		port reportOut {
			out report : ScoutingReport;
		}
		port alertOut {
			out alert : AlertNotification;
		}
		action generateReport {
			in ranked : PrioritizedCandidate[*];
			out report : ScoutingReport;
		}
	}

	part def StakeholderInterface {
		port reportIn {
			in report : ScoutingReport;
		}
		port alertIn {
			in alert : AlertNotification;
		}
		action pushAlert {
			in alert : AlertNotification;
		}
		action updateDashboard {
			in report : ScoutingReport;
		}
	}

	part def TechnologyScoutingSystem {
		attribute cycleFrequencyDays : Integer = 1;

		part patentDB : PatentDatabase;
		part researchDB : ResearchPublicationDB;
		part industryDB : IndustryReportDB;
		part startupFeed : StartupNewsFeed;
		part dataCollection : DataCollectionModule;
		part analysisEngine : AnalysisEngine;
		part prioritization : PrioritizationModule;
		part knowledgeRepo : KnowledgeRepository;
		part reporting : ReportingModule;
		part stakeholderInterface : StakeholderInterface;

		flow patentSignal of TechnologySignal
			from patentDB.signalOut.signal to dataCollection.signalIn.signal;
		flow researchSignal of TechnologySignal
			from researchDB.signalOut.signal to dataCollection.signalIn.signal;
		flow industrySignal of TechnologySignal
			from industryDB.signalOut.signal to dataCollection.signalIn.signal;
		flow startupSignal of TechnologySignal
			from startupFeed.signalOut.signal to dataCollection.signalIn.signal;
		flow candidateFlow of TechnologyCandidate
			from dataCollection.candidateOut.candidate to analysisEngine.candidateIn.candidate;
		flow resultFlow of AnalysisResult
			from analysisEngine.resultOut.result to prioritization.resultIn.result;
		flow rankedFlow of PrioritizedCandidate
			from prioritization.rankedOut.ranked to reporting.rankedIn.ranked;
		flow reportToStakeholder of ScoutingReport
			from reporting.reportOut.report to stakeholderInterface.reportIn.report;
		flow alertToStakeholder of AlertNotification
			from reporting.alertOut.alert to stakeholderInterface.alertIn.alert;
		flow reportToRepository of ScoutingReport
			from reporting.reportOut.report to knowledgeRepo.storeIn.report;

		action dailyUpdateCycle {
			first collectSignals;
			then analyzeCandidates;
			then prioritizeCandidates;
			then generateScoutingReport;
			then pushAlerts;
			then storeInRepository;
		}
		action collectSignals {
			out signals : TechnologySignal[*];
		}
		action analyzeCandidates {
			in signals : TechnologySignal[*];
			out results : AnalysisResult[*];
		}
		action prioritizeCandidates {
			in results : AnalysisResult[*];
			out ranked : PrioritizedCandidate[*];
		}
		action generateScoutingReport {
			in ranked : PrioritizedCandidate[*];
			out report : ScoutingReport;
		}
		action pushAlerts {
			in report : ScoutingReport;
			out alert : AlertNotification;
		}
		action storeInRepository {
			in report : ScoutingReport;
		}

		state def SystemStates {
			state active {
				entry dailyUpdateCycle;
			}
			state paused;
			state maintenance;
			transition from active to paused accept PauseRequested;
			transition from paused to active accept ResumeRequested;
			transition from active to maintenance accept MaintenanceRequested;
			transition from maintenance to active accept MaintenanceComplete;
		}

		state systemStates : SystemStates;
	}

	requirement def StrategicIntelligenceRequirement {
		doc /* The system shall transform raw, unstructured information into actionable strategic intelligence for innovation leaders and decision-makers. */
	}

	requirement def DailyUpdateRequirement {
		doc /* The system shall refresh its scouting analysis on a daily cycle to maintain a current view of the technology landscape. */
	}

	requirement def MultiCriteriaEvaluationRequirement {
		doc /* Each technology candidate shall be evaluated on technical feasibility, market potential, strategic alignment, and implementation cost. */
	}

	requirement def HistoricalTrendRequirement {
		doc /* The system shall retain past analyses in a knowledge repository to support long-term trend analysis and continuous learning. */
	}

	requirement def StakeholderDeliveryRequirement {
		doc /* Scouting reports and alerts shall be delivered to stakeholders through an interactive dashboard and a notification system. */
	}

	requirement def OperationalStatesRequirement {
		doc /* The system shall support active, paused, and maintenance operational states. */
	}

	requirement def TechnologyCandidateProfileRequirement {
		doc /* Each technology candidate shall specify name, description, maturity level (TRL), potential applications, and competitive impact. */
	}

	requirement def SourceCoverageRequirement {
		doc /* The data collection module shall scan patent databases, research publications, industry reports, and startup news. */
	}

	part techScoutingSystem : TechnologyScoutingSystem {
		satisfy StrategicIntelligenceRequirement;
		satisfy DailyUpdateRequirement;
		satisfy MultiCriteriaEvaluationRequirement;
		satisfy HistoricalTrendRequirement;
		satisfy StakeholderDeliveryRequirement;
		satisfy OperationalStatesRequirement;
		satisfy TechnologyCandidateProfileRequirement;
		satisfy SourceCoverageRequirement;
	}
}
