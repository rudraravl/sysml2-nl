package TechnologyScoutingSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def TRL :> Integer { :>> min = 1; :>> max = 9; }
    value def Score :> Real { :>> min = 0.0; :>> max = 100.0; }
    value def Weight :> Real { :>> min = 0.0; :>> max = 1.0; }
    value def Confidence :> Real { :>> min = 0.0; :>> max = 1.0; }
    value def FrequencyHours :> Real;
    value def Count :> Integer;

    // ===== Enums =====
    enum def SourceType { patent; publication; industryReport; startupNews; conference; }
    enum def SystemState { active; paused; maintenance; }
    enum def AlertChannel { email; dashboard; sms; collaborationPlatform; }
    enum def MaturityStage { research; prototype; pilot; commercial; }

    // ===== Items =====
    item def RawSignal {
        attribute sourceType : SourceType;
        attribute sourceUri : String;
        attribute capturedTimestamp : DateTime;
        attribute content : String;
        attribute confidence : Confidence;
    }

    item def TechnologyCandidate {
        attribute id : String;
        attribute name : String;
        attribute description : String;
        attribute trl : TRL;
        attribute maturityStage : MaturityStage;
        attribute potentialApplications : String[0..*];
        attribute competitiveImpact : String;
        attribute discoveredOn : DateTime;
    }

    item def EvaluationResult {
        attribute candidateId : String;
        attribute technicalFeasibility : Score;
        attribute marketPotential : Score;
        attribute strategicAlignment : Score;
        attribute implementationCost : Score;
        attribute overallScore : Score;
        attribute evaluatedOn : DateTime;
    }

    item def RankedCandidate {
        attribute candidate : TechnologyCandidate;
        attribute evaluation : EvaluationResult;
        attribute rank : Integer;
    }

    item def ScoutingReport {
        attribute reportId : String;
        attribute generatedOn : DateTime;
        attribute executiveSummary : String;
        attribute rankedCandidates : RankedCandidate[0..*];
        attribute trendAnalysis : String;
        attribute recommendations : String[0..*];
    }

    item def Alert {
        attribute message : String;
        attribute channel : AlertChannel;
        attribute priority : Integer;
        attribute createdOn : DateTime;
    }

    item def KnowledgeRecord {
        attribute recordId : String;
        attribute candidate : TechnologyCandidate;
        attribute evaluation : EvaluationResult;
        attribute recordedOn : DateTime;
    }

    // ===== Port Definitions =====
    port def RawSignalOut { out signal : RawSignal[0..*]; }
    port def RawSignalIn { in signal : RawSignal[0..*]; }
    port def CandidateOut { out candidate : TechnologyCandidate[0..*]; }
    port def CandidateIn { in candidate : TechnologyCandidate[0..*]; }
    port def EvaluationOut { out result : EvaluationResult[0..*]; }
    port def EvaluationIn { in result : EvaluationResult[0..*]; }
    port def RankedOut { out ranked : RankedCandidate[0..*]; }
    port def RankedIn { in ranked : RankedCandidate[0..*]; }
    port def RecordFlow { inout record : KnowledgeRecord[0..*]; }
    port def ReportOut { out report : ScoutingReport[0..*]; }
    port def ReportIn { in report : ScoutingReport[0..*]; }
    port def AlertOut { out alert : Alert[0..*]; }
    port def AlertIn { in alert : Alert[0..*]; }

    // ===== Requirements =====
    requirement def ContinuousMonitoring {
        subject : TechnologyScoutingSystem;
        objective {
            doc /* The system shall continuously monitor the global technology landscape. */
            require subject.updateFrequency <= 24 [h];
        }
    }

    requirement def SignalCapture {
        subject : DataCollectionModule;
        objective {
            doc /* The module shall capture technology signals from multiple source types. */
            require subject.supportedSources->size() >= 5;
        }
    }

    requirement def CandidateIdentification {
        subject : DataCollectionModule;
        objective {
            doc /* The module shall transform raw signals into structured TechnologyCandidates. */
            require subject.candidatesProduced >= 1;
        }
    }

    requirement def MultiCriteriaEvaluation {
        subject : AnalysisEngine;
        objective {
            doc /* The engine shall evaluate candidates on technical feasibility, market potential, strategic alignment, and implementation cost. */
            require subject.technicalWeight + subject.marketWeight + subject.strategicWeight + subject.costWeight == 1.0;
        }
    }

    requirement def PrioritizationRanking {
        subject : PrioritizationModule;
        objective {
            doc /* The module shall rank candidates using a weighted scoring system. */
            require subject.rankedOutput->size() >= 1;
        }
    }

    requirement def KnowledgeRetention {
        subject : KnowledgeRepository;
        objective {
            doc /* The repository shall store all past and present findings for trend analysis. */
            require subject.records->size() >= 0;
        }
    }

    requirement def ReportingOutput {
        subject : ReportingModule;
        objective {
            doc /* The module shall compile scouting reports with executive summaries, ranked lists, trend analyses, and recommendations. */
            require subject.reportsGenerated->size() >= 1;
        }
    }

    requirement def StakeholderDelivery {
        subject : StakeholderInterface;
        objective {
            doc /* The interface shall deliver reports and alerts to stakeholders through multiple channels. */
            require subject.supportedChannels->size() >= 2;
        }
    }

    // ===== Parts =====

    part def DataCollectionModule {
        port signalOut : RawSignalOut;
        port candidateOut : CandidateOut;
        port recordPort : RecordFlow;

        attribute supportedSources : SourceType[1..*] = (SourceType::patent, SourceType::publication, SourceType::industryReport, SourceType::startupNews, SourceType::conference);
        attribute candidatesProduced : Count;
        attribute scanInterval : FrequencyHours = 24.0;

        item storedSignals : RawSignal[0..*];

        action def ScanSources {
            in sources : SourceType[1..*];
            out captured : RawSignal[0..*];
        }

        action def ExtractCandidates {
            in signals : RawSignal[0..*];
            out candidates : TechnologyCandidate[0..*];
        }

        perform action scan : ScanSources {
            in sources = self.supportedSources;
            out captured -> self.storedSignals;
        }

        perform action extract : ExtractCandidates {
            in signals = self.storedSignals;
            out candidates -> self.candidateOut.candidate;
        }

        satisfy SignalCapture;
        satisfy CandidateIdentification;
    }

    part def AnalysisEngine {
        port candidateIn : CandidateIn;
        port evaluationOut : EvaluationOut;
        port recordPort : RecordFlow;

        attribute technicalWeight : Weight = 0.30;
        attribute marketWeight : Weight = 0.30;
        attribute strategicWeight : Weight = 0.25;
        attribute costWeight : Weight = 0.15;

        action def EvaluateCandidate {
            in candidate : TechnologyCandidate;
            in techW : Weight;
            in mktW : Weight;
            in stratW : Weight;
            in costW : Weight;
            out result : EvaluationResult;
        }

        perform action evaluate : EvaluateCandidate[0..*] {
            in candidate = self.candidateIn.candidate;
            in techW = self.technicalWeight;
            in mktW = self.marketWeight;
            in stratW = self.strategicWeight;
            in costW = self.costWeight;
            out result -> self.evaluationOut.result;
        }

        satisfy MultiCriteriaEvaluation;
    }

    part def PrioritizationModule {
        port evaluationIn : EvaluationIn;
        port candidateIn : CandidateIn;
        port rankedOut : RankedOut;
        port recordPort : RecordFlow;

        attribute rankedOutput : RankedCandidate[0..*];

        action def RankCandidates {
            in evaluations : EvaluationResult[0..*];
            in candidates : TechnologyCandidate[0..*];
            out ranked : RankedCandidate[0..*];
        }

        perform action rank : RankCandidates {
            in evaluations = self.evaluationIn.result;
            in candidates = self.candidateIn.candidate;
            out ranked -> self.rankedOut.ranked;
        }

        satisfy PrioritizationRanking;
    }

    part def KnowledgeRepository {
        port recordPort : RecordFlow;

        attribute records : KnowledgeRecord[0..*];

        action def StoreRecord {
            inout records : KnowledgeRecord[0..*];
            in record : KnowledgeRecord;
        }

        action def AnalyzeTrends {
            in records : KnowledgeRecord[0..*];
            out trendSummary : String;
        }

        perform action store : StoreRecord[0..*] {
            inout records = self.records;
            in record = self.recordPort.record;
        }

        satisfy KnowledgeRetention;
    }

    part def ReportingModule {
        port rankedIn : RankedIn;
        port recordPort : RecordFlow;
        port reportOut : ReportOut;

        attribute reportsGenerated : ScoutingReport[0..*];

        action def CompileReport {
            in ranked : RankedCandidate[0..*];
            in trendSummary : String;
            out report : ScoutingReport;
        }

        perform action compile : CompileReport[0..*] {
            in ranked = self.rankedIn.ranked;
            in trendSummary = "Aggregated trend analysis from repository";
            out report -> self.reportOut.report;
        }

        satisfy ReportingOutput;
    }

    part def StakeholderInterface {
        port reportIn : ReportIn;
        port alertOut : AlertOut;

        attribute supportedChannels : AlertChannel[1..*] = (AlertChannel::email, AlertChannel::dashboard, AlertChannel::sms, AlertChannel::collaborationPlatform);

        action def RenderDashboard {
            in report : ScoutingReport[0..*];
        }

        action def PushAlert {
            in report : ScoutingReport;
            out alert : Alert;
        }

        perform action render : RenderDashboard {
            in report = self.reportIn.report;
        }

        perform action notify : PushAlert[0..*] {
            in report = self.reportIn.report;
            out alert -> self.alertOut.alert;
        }

        satisfy StakeholderDelivery;
    }

    part def TechnologyScoutingSystem {
        port recordPort : RecordFlow;

        attribute updateFrequency : FrequencyHours = 24.0;
        attribute currentState : SystemState = SystemState::active;

        part dataCollection : DataCollectionModule;
        part analysisEngine : AnalysisEngine;
        part prioritization : PrioritizationModule;
        part knowledgeRepo : KnowledgeRepository;
        part reporting : ReportingModule;
        part stakeholderInterface : StakeholderInterface;

        // Connections
        connection dataToAnalysis connect dataCollection.candidateOut to analysisEngine.candidateIn;
        connection analysisToPrioritization connect analysisEngine.evaluationOut to prioritization.evaluationIn;
        connection candidateBypass connect dataCollection.candidateOut to prioritization.candidateIn;
        connection prioritizationToReporting connect prioritization.rankedOut to reporting.rankedIn;
        connection reportingToStakeholder connect reporting.reportOut to stakeholderInterface.reportIn;

        // Knowledge repository connections (bidirectional record flow)
        connection collectionToRepo connect dataCollection.recordPort to knowledgeRepo.recordPort;
        connection analysisToRepo connect analysisEngine.recordPort to knowledgeRepo.recordPort;
        connection prioritizationToRepo connect prioritization.recordPort to knowledgeRepo.recordPort;
        connection reportingToRepo connect reporting.recordPort to knowledgeRepo.recordPort;
        connection repoToSystem connect knowledgeRepo.recordPort to self.recordPort;

        // State machine governing system lifecycle
        state def SystemLifecycle {
            entry action { :>> currentState = SystemState::active; }
            state active {
                entry action { doc /* System is actively scanning and processing. */ }
                do action { send UpdateCycle() to self; }
                transition activeToPaused first active if (operatorCommand == "pause") then paused;
                transition activeToMaintenance first active if (operatorCommand == "maintenance") then maintenance;
            }
            state paused {
                entry action { :>> currentState = SystemState::paused; }
                transition pausedToActive first paused if (operatorCommand == "resume") then active;
                transition pausedToMaintenance first paused if (operatorCommand == "maintenance") then maintenance;
            }
            state maintenance {
                entry action { :>> currentState = SystemState::maintenance; }
                do action { perform MaintenanceCheck(); }
                transition maintenanceToActive first maintenance if (operatorCommand == "resume") then active;
            }
        }

        attribute operatorCommand : String;

        action def UpdateCycle {
            doc /* Triggers a full scan-evaluate-rank-report cycle. */
        }

        action def MaintenanceCheck {
            doc /* Performs system integrity checks during maintenance. */
        }

        exhibit state lifecycle : SystemLifecycle;

        satisfy ContinuousMonitoring;
    }
}

// ===== Requirement Satisfaction Group =====
package RequirementsVerification {
    import TechnologyScoutingSystem::*;

    requirement group VerificationGroup {
        subject : TechnologyScoutingSystem;
        satisfy ContinuousMonitoring by subject;
        satisfy SignalCapture by subject.dataCollection;
        satisfy CandidateIdentification by subject.dataCollection;
        satisfy MultiCriteriaEvaluation by subject.analysisEngine;
        satisfy PrioritizationRanking by subject.prioritization;
        satisfy KnowledgeRetention by subject.knowledgeRepo;
        satisfy ReportingOutput by subject.reporting;
        satisfy StakeholderDelivery by subject.stakeholderInterface;
    }
}
