package 'Collingridge Dilemma System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SequenceFunctions::*;
	
	attribute def MaturityLevel {
		attribute value : Real;
		doc /* Technology maturity from 0.0 (concept) to 1.0 (fully deployed) */
	}
	
	attribute def KnowledgeLevel {
		attribute completeness : Real;
		attribute reliability : Real;
		doc /* Quality of understanding about technology impacts */
	}
	
	attribute def ControlAuthority {
		attribute regulatory : Real;
		attribute technical : Real;
		attribute economic : Real;
		doc /* Ability to modify or redirect technology development */
	}
	
	attribute def SocietalImpact {
		attribute environmental : Real;
		attribute economic : Real;
		attribute social : Real;
		attribute ethical : Real;
		doc /* Measured impacts on society, range -1.0 (harmful) to 1.0 (beneficial) */
	}
	
	item def TechnologyProfile {
		attribute maturity : MaturityLevel;
		attribute knowledge : KnowledgeLevel;
		attribute control : ControlAuthority;
		attribute impact : SocietalImpact;
		attribute adoptionRate : Real;
		attribute infrastructureIntegration : Real;
	}
	
	item def InterventionDirective {
		attribute interventionType : InterventionKind;
		attribute urgency : Real;
		attribute resourceAllocation : ISQ::PowerValue;
		attribute targetMaturity : Real;
	}
	
	enum def InterventionKind {
		enum monitor;
		enum research;
		enum regulate;
		enum restrict;
		enum redirect;
		enum accelerate;
	}
	
	port def TechnologyMonitoringPort {
		out item profile : TechnologyProfile;
	}
	
	port def KnowledgeAcquisitionPort {
		in item researchDirective : Real;
		out item knowledgeUpdate : KnowledgeLevel;
	}
	
	port def ControlExecutionPort {
		in item directive : InterventionDirective;
		out item effectivenessReport : Real;
	}
	
	part def TechnologyMonitor {
		doc /* Continuously observes emerging technology development and deployment */
		
		port monitorOut : TechnologyMonitoringPort;
		
		attribute scanningFrequency : ISQ::FrequencyValue;
		attribute detectionThreshold : Real;
		
		perform action scanTechnology : ScanTechnology;
	}
	
	part def ImpactAnalyzer {
		doc /* Analyzes potential and actual societal impacts based on available knowledge */
		
		port profileIn : TechnologyMonitoringPort;
		port knowledgePort : KnowledgeAcquisitionPort;
		
		attribute analysisConfidence : Real;
		attribute projectionHorizon : ISQ::TimeValue;
		
		perform action analyzeImpacts : AnalyzeImpacts;
	}
	
	part def DilemmaResolver {
		doc /* Makes intervention decisions balancing incomplete knowledge against diminishing control */
		
		port analysisIn;
		port directiveOut : ControlExecutionPort;
		
		attribute riskTolerance : Real;
		attribute knowledgeThreshold : Real;
		attribute controlThreshold : Real;
		
		perform action resolveIntervention : ResolveIntervention;
	}
	
	part def InterventionExecutor {
		doc /* Executes control actions on technology development and deployment */
		
		port controlIn : ControlExecutionPort;
		
		attribute executionCapacity : Real;
		attribute responseTime : ISQ::TimeValue;
		
		perform action executeControl : ExecuteControl;
	}
	
	enum def GovernancePhase {
		enum earlyStage;
		enum transitionStage;
		enum matureStage;
		enum entrenched;
	}
	
	part def TechnologyGovernanceSystem {
		doc /* System managing the Collingridge dilemma: early intervention with limited knowledge 
		       versus delayed intervention with reduced control capability */
		
		attribute systemPhase : GovernancePhase;
		attribute cumulativeKnowledge : Real;
		attribute cumulativeControl : Real;
		
		part monitor : TechnologyMonitor {
			port monitorOut;
		}
		
		part analyzer : ImpactAnalyzer {
			port profileIn;
			port knowledgePort;
		}
		
		part resolver : DilemmaResolver {
			port analysisIn;
			port directiveOut;
		}
		
		part executor : InterventionExecutor {
			port controlIn;
		}
		
		connection monitorToAnalyzer connect monitor.monitorOut to analyzer.profileIn;
		connection analyzerToResolver connect analyzer to resolver.analysisIn;
		connection resolverToExecutor connect resolver.directiveOut to executor.controlIn;
		
		perform action governTechnology : GovernTechnology;
	}
	
	action def ScanTechnology {
		in attribute scanInterval : ISQ::TimeValue;
		out attribute currentProfile : TechnologyProfile;
		out attribute trendIndicators : Real[*];
	}
	
	action def AnalyzeImpacts {
		in attribute techProfile : TechnologyProfile;
		in attribute knowledgeBase : KnowledgeLevel;
		out attribute projectedImpact : SocietalImpact;
		out attribute uncertaintyBounds : Real;
		out attribute confidenceScore : Real;
	}
	
	action def ResolveIntervention {
		in attribute impact : SocietalImpact;
		in attribute confidence : Real;
		in attribute currentControl : ControlAuthority;
		in attribute maturity : MaturityLevel;
		out attribute decision : InterventionDirective;
		out attribute rationale : String;
	}
	
	action def ExecuteControl {
		in attribute directive : InterventionDirective;
		in attribute availableControl : ControlAuthority;
		out attribute actualEffect : Real;
		out attribute controlCost : ISQ::PowerValue;
	}
	
	action def GovernTechnology {
		doc /* Primary system function: continuously monitor emerging technology, assess impacts 
		       under uncertainty, and execute timely interventions balancing knowledge gaps 
		       against control effectiveness to optimize societal outcomes */
		
		in attribute initialMaturity : Real;
		in attribute acceptableImpactThreshold : Real;
		in attribute maxInterventionDelay : ISQ::TimeValue;
		out attribute finalOutcome : String;
		out attribute interventionHistory : InterventionDirective[*];
		
		private attribute currentKnowledge : Real := 0.2;
		private attribute currentControl : Real := 0.95;
		private attribute timeElapsed : ISQ::TimeValue := 0.0;
		private attribute maturityLevel : Real := initialMaturity;
		private attribute interventions : InterventionDirective[*] := ();
		
		first start;
		then merge monitoringCycle;
		
		then action scan : ScanTechnology {
			in scanInterval = 1.0;
			out currentProfile;
			out trendIndicators;
		}
		
		then assign maturityLevel := scan.currentProfile.maturity.value;
		then assign currentKnowledge := 0.2 + (maturityLevel * 0.7);
		then assign currentControl := 0.95 - (maturityLevel * 0.85);
		
		then action analyze : AnalyzeImpacts {
			in techProfile = scan.currentProfile;
			in knowledgeBase.completeness = currentKnowledge;
			in knowledgeBase.reliability = currentKnowledge * 0.9;
			out projectedImpact;
			out uncertaintyBounds;
			out confidenceScore;
		}
		
		then decide interventionDecision;
			if analyze.confidenceScore < 0.4 and analyze.projectedImpact.social < 0.3 
				then continueMonitoring;
			if analyze.confidenceScore >= 0.4 and analyze.projectedImpact.social < -0.2 
				then earlyIntervention;
			if maturityLevel > 0.7 and analyze.projectedImpact.social < -0.4 
				then lateIntervention;
			if analyze.projectedImpact.social >= -0.2 
				then continueMonitoring;
		
		action continueMonitoring {
			then assign timeElapsed := timeElapsed + 1.0;
		}
		then monitoringCycle;
		
		action earlyIntervention : ResolveIntervention {
			in impact = analyze.projectedImpact;
			in confidence = analyze.confidenceScore;
			in currentControl.regulatory = currentControl;
			in currentControl.technical = currentControl;
			in currentControl.economic = currentControl * 0.8;
			in maturity.value = maturityLevel;
			out decision;
			out rationale;
		}
		then action executeEarly : ExecuteControl {
			in directive = earlyIntervention.decision;
			in availableControl.regulatory = currentControl;
			in availableControl.technical = currentControl;
			in availableControl.economic = currentControl * 0.8;
			out actualEffect;
			out controlCost;
		}
		then assign interventions := interventions->including(earlyIntervention.decision);
		then decide earlyOutcome;
			if executeEarly.actualEffect > 0.6 then earlySuccess;
			if executeEarly.actualEffect <= 0.6 then partialSuccess;
		
		action earlySuccess {
			then assign finalOutcome := "Success: Early intervention with high control effectiveness despite knowledge gaps";
		}
		then done;
		
		action partialSuccess {
			then assign finalOutcome := "Partial: Early intervention limited by knowledge uncertainty";
			then assign timeElapsed := timeElapsed + 2.0;
		}
		then monitoringCycle;
		
		action lateIntervention : ResolveIntervention {
			in impact = analyze.projectedImpact;
			in confidence = analyze.confidenceScore;
			in currentControl.regulatory = currentControl;
			in currentControl.technical = currentControl;
			in currentControl.economic = currentControl * 0.5;
			in maturity.value = maturityLevel;
			out decision;
			out rationale;
		}
		then action executeLate : ExecuteControl {
			in directive = lateIntervention.decision;
			in availableControl.regulatory = currentControl;
			in availableControl.technical = currentControl;
			in availableControl.economic = currentControl * 0.5;
			out actualEffect;
			out controlCost;
		}
		then assign interventions := interventions->including(lateIntervention.decision);
		then decide lateOutcome;
			if executeLate.actualEffect > 0.4 then lateSuccess;
			if executeLate.actualEffect <= 0.4 then dilemmaFailure;
		
		action lateSuccess {
			then assign finalOutcome := "Success: Late intervention with good knowledge but reduced control";
		}
		then done;
		
		action dilemmaFailure {
			then assign finalOutcome := "Failure: Technology too entrenched for effective intervention despite complete knowledge";
		}
		then done;
	}
	
	requirement def CollingridgeDilemmaRequirement {
		doc /* The system shall address the fundamental Collingridge dilemma: when technology 
		       is easily controllable (early stage), knowledge of its impacts is limited; 
		       when knowledge becomes comprehensive (late stage), the technology is too 
		       embedded in infrastructure to control effectively */
		
		subject governanceSystem : TechnologyGovernanceSystem;
		
		require constraint earlyStageCharacteristics {
			doc /* In early development, control authority shall exceed 0.8 while knowledge completeness remains below 0.4 */
			governanceSystem.systemPhase == GovernancePhase::earlyStage implies
			(governanceSystem.cumulativeControl > 0.8 and governanceSystem.cumulativeKnowledge < 0.4)
		}
		
		require constraint lateStageCharacteristics {
			doc /* In mature deployment, knowledge completeness shall exceed 0.8 while control authority falls below 0.3 */
			governanceSystem.systemPhase == GovernancePhase::matureStage implies
			(governanceSystem.cumulativeKnowledge > 0.8 and governanceSystem.cumulativeControl < 0.3)
		}
		
		require constraint inverseRelationship {
			doc /* Control authority and knowledge completeness shall exhibit inverse correlation across lifecycle */
			governanceSystem.cumulativeControl + governanceSystem.cumulativeKnowledge <= 1.2
		}
	}
	
	requirement def OptimalInterventionTimingRequirement {
		doc /* The system shall determine optimal intervention timing that maximizes expected 
		       societal benefit by balancing knowledge uncertainty against control effectiveness */
		
		subject resolver : DilemmaResolver;
		
		require constraint balancedThresholds {
			doc /* Decision thresholds shall balance risk tolerance with available control */
			resolver.knowledgeThreshold >= 0.3 and 
			resolver.knowledgeThreshold <= 0.6 and
			resolver.controlThreshold >= 0.25
		}
		
		require constraint adaptiveResponse {
			doc /* Intervention urgency shall increase as control authority diminishes */
		}
	}
	
	requirement def ContinuousMonitoringRequirement {
		doc /* The system shall maintain continuous surveillance of technology development 
		       to detect emerging impacts before control capability is lost */
		
		subject monitor : TechnologyMonitor;
		
		require constraint minimumScanRate {
			doc /* Technology scanning shall occur at minimum frequency of 1 Hz during critical phases */
			monitor.scanningFrequency >= 1.0
		}
	}
	
	requirement systemMissionRequirement {
		doc /* The Technology Governance System shall manage the Collingridge dilemma by 
		       continuously monitoring emerging technologies, analyzing their potential societal 
		       impacts under conditions of uncertainty, and executing timely interventions that 
		       optimize the trade-off between knowledge completeness and control effectiveness 
		       to maximize positive societal outcomes while minimizing harmful impacts */
		
		assume constraint technologyMaturationProgression {
			doc /* Technology systems progressively mature from concept through deployment to infrastructure integration */
		}
		
		assume constraint knowledgeAccumulationOverTime {
			doc /* Understanding of technology impacts improves monotonically with deployment experience */
		}
		
		assume constraint controlDegradationWithEmbeddedness {
			doc /* Ability to modify or redirect technology decreases as infrastructure integration increases */
		}
		
		require CollingridgeDilemmaRequirement;
		require OptimalInterventionTimingRequirement;
		require ContinuousMonitoringRequirement;
	}
	
	part governanceSystem : TechnologyGovernanceSystem {
		perform action manage : GovernTechnology {
			in initialMaturity = 0.1;
			in acceptableImpactThreshold = -0.3;
			in maxInterventionDelay = 10.0;
		}
	}
	
	satisfy systemMissionRequirement by governanceSystem.manage;
}
