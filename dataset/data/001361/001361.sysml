package AutomationBiasSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    enum def ConfidenceLevel {
        veryLow;
        low;
        moderate;
        high;
        veryHigh;
    }
    
    enum def DecisionSource {
        automation;
        operator;
        hybrid;
    }
    
    enum def BiasState {
        minimal;
        emerging;
        significant;
        critical;
    }
    
    attribute def TrustScore :> Real;
    attribute def BiasMetric :> Real;
    attribute def AccuracyRate :> Real;
    attribute def ResponseDuration :> TimeValue;
    
    item def SituationData {
        attribute timestamp : TimeValue;
        attribute complexity : Real;
        attribute urgency : Real;
        attribute dataQuality : Real;
    }
    
    item def AutomatedAssessment {
        attribute recommendation : String;
        attribute confidence : ConfidenceLevel;
        attribute rationale : String;
        attribute computationTime : TimeValue;
    }
    
    item def OperatorResponse {
        attribute decision : String;
        attribute acceptedAutomation : Boolean;
        attribute deliberationTime : ResponseDuration;
        attribute justification : String;
    }
    
    item def FinalDecision {
        attribute decisionAction : String;
        attribute source : DecisionSource;
        attribute biasIndicator : BiasMetric;
        attribute timestamp : TimeValue;
    }
    
    item def BiasAlert {
        attribute severity : BiasState;
        attribute alertMessage : String;
        attribute mitigationGuidance : String;
        attribute requiresAcknowledgment : Boolean;
    }
    
    port def SituationInputPort {
        in item situationData : SituationData;
    }
    
    port def AssessmentOutputPort {
        out item assessment : AutomatedAssessment;
    }
    
    port def OperatorInterfacePort {
        in item operatorResponse : OperatorResponse;
        out item alert : BiasAlert;
        out item assessment : AutomatedAssessment;
    }
    
    port def DecisionOutputPort {
        out item finalDecision : FinalDecision;
    }
    
    port def MonitoringPort {
        in item biasMetrics : BiasMetric;
        out item alert : BiasAlert;
    }
    
    action def AnalyzeSituation {
        in situation : SituationData;
        out processedData : Real;
    }
    
    action def GenerateRecommendation {
        in processedData : Real;
        out assessment : AutomatedAssessment;
    }
    
    action def CaptureOperatorInput {
        in displayedAssessment : AutomatedAssessment;
        out operatorResponse : OperatorResponse;
    }
    
    action def CalculateBiasLevel {
        in automationConfidence : ConfidenceLevel;
        in operatorAcceptanceRate : Real;
        in deliberationTime : ResponseDuration;
        out biasLevel : BiasMetric;
    }
    
    action def IntegrateDecision {
        in assessment : AutomatedAssessment;
        in operatorResponse : OperatorResponse;
        in biasLevel : BiasMetric;
        out finalDecision : FinalDecision;
    }
    
    action def IssueAlert {
        in biasLevel : BiasMetric;
        in currentState : BiasState;
        out alert : BiasAlert;
    }
    
    action def LogDecisionEvent {
        in finalDecision : FinalDecision;
        in biasLevel : BiasMetric;
        in operatorResponse : OperatorResponse;
    }
    
    state def BiasMonitoringStateMachine {
        entry; then monitoring;
        
        state monitoring;
        then decide;
            if true then lowBias;
        
        state lowBias;
        then monitoring;
        
        state moderateBias;
        then awaitAcknowledgment;
        
        state highBias;
        then requireIntervention;
        
        state awaitAcknowledgment;
        then monitoring;
        
        state requireIntervention;
        then monitoring;
    }
    
    action def DecisionCycleWithBiasMonitoring {
        first start;
        then action receiveSituation : AnalyzeSituation {
            in situation : SituationData;
            out processedData : Real;
        }
        then action generateAssessment : GenerateRecommendation {
            in processedData = receiveSituation.processedData;
            out assessment : AutomatedAssessment;
        }
        then merge awaitResponse;
        then action captureResponse : CaptureOperatorInput {
            in displayedAssessment = generateAssessment.assessment;
            out operatorResponse : OperatorResponse;
        }
        then action computeBias : CalculateBiasLevel {
            in automationConfidence = generateAssessment.assessment.confidence;
            in operatorAcceptanceRate : Real;
            in deliberationTime = captureResponse.operatorResponse.deliberationTime;
            out biasLevel : BiasMetric;
        }
        then action formDecision : IntegrateDecision {
            in assessment = generateAssessment.assessment;
            in operatorResponse = captureResponse.operatorResponse;
            in biasLevel = computeBias.biasLevel;
            out finalDecision : FinalDecision;
        }
        then decide;
            if true then issueAlert;
        
        action issueAlert : IssueAlert {
            in biasLevel = computeBias.biasLevel;
            in currentState : BiasState;
            out alert : BiasAlert;
        }
        then logEvent;
        
        action logEvent : LogDecisionEvent {
            in finalDecision = formDecision.finalDecision;
            in biasLevel = computeBias.biasLevel;
            in operatorResponse = captureResponse.operatorResponse;
        }
        then decide;
            if true then awaitResponse;
            if false then done;
    }
    
    part def SituationAnalyzer {
        attribute processingCapacity : Real;
        attribute analysisAccuracy : AccuracyRate;
        
        port situationInput : SituationInputPort;
        
        perform action analyzeSituations : AnalyzeSituation[*];
    }
    
    part def AutomatedAdvisor {
        attribute recommendationConfidenceThreshold : Real;
        attribute algorithmVersion : String;
        attribute historicalAccuracy : AccuracyRate;
        
        port assessmentOutput : AssessmentOutputPort;
        
        perform action generateRecommendations : GenerateRecommendation[*];
    }
    
    part def BiasMonitor {
        attribute detectionSensitivity : Real;
        attribute biasThreshold : BiasMetric;
        attribute trackingWindowSize : Integer;
        attribute currentBiasLevel : BiasMetric;
        
        port monitoringPort : MonitoringPort;
        
        perform action calculateBias : CalculateBiasLevel[*];
        perform state monitoringBehavior : BiasMonitoringStateMachine;
    }
    
    part def OperatorWorkstation {
        attribute operatorTrustLevel : TrustScore;
        attribute averageResponseTime : ResponseDuration;
        attribute overrideFrequency : Real;
        
        port interfacePort : OperatorInterfacePort;
        
        perform action handleOperatorInteraction : CaptureOperatorInput[*];
    }
    
    part def DecisionIntegrator {
        attribute integrationStrategy : String;
        attribute biasCompensationEnabled : Boolean;
        attribute compensationFactor : Real;
        
        port decisionOutput : DecisionOutputPort;
        
        perform action integrateDecisions : IntegrateDecision[*];
    }
    
    part def EventRecorder {
        attribute storageCapacity : Integer;
        attribute recordingEnabled : Boolean;
        
        perform action recordEvents : LogDecisionEvent[*];
    }
    
    part def AutomationBiasSystem {
        doc /*
         * An automation bias system that demonstrates and mitigates the tendency of human
         * operators to over-rely on automated recommendations without sufficient critical
         * evaluation. The system monitors decision-making patterns to detect when operators
         * are accepting automated suggestions too readily, potentially missing errors or
         * alternative solutions.
         * 
         * Primary function: To support human-automation collaboration by providing automated
         * decision support while actively monitoring for and alerting operators to automation
         * bias, ensuring that human judgment remains engaged and that automated recommendations
         * receive appropriate scrutiny based on situation complexity and system confidence.
         */
        
        attribute systemBiasLevel : BiasMetric;
        attribute operatorEngagementScore : Real;
        attribute automationReliability : AccuracyRate;
        attribute totalDecisionsProcessed : Integer;
        attribute biasIncidentCount : Integer;
        
        part analyzer : SituationAnalyzer {
            attribute :>> processingCapacity = 100.0;
            attribute :>> analysisAccuracy = 0.94;
        }
        
        part advisor : AutomatedAdvisor {
            attribute :>> recommendationConfidenceThreshold = 0.80;
            attribute :>> algorithmVersion = "v3.2.1";
            attribute :>> historicalAccuracy = 0.89;
        }
        
        part monitor : BiasMonitor {
            attribute :>> detectionSensitivity = 0.85;
            attribute :>> biasThreshold = 0.65;
            attribute :>> trackingWindowSize = 20;
            attribute :>> currentBiasLevel = 0.35;
        }
        
        part workstation : OperatorWorkstation {
            attribute :>> operatorTrustLevel = 0.78;
            attribute :>> averageResponseTime = 3.5 [s];
            attribute :>> overrideFrequency = 0.12;
        }
        
        part integrator : DecisionIntegrator {
            attribute :>> integrationStrategy = "weighted-hybrid";
            attribute :>> biasCompensationEnabled = true;
            attribute :>> compensationFactor = 0.35;
        }
        
        part recorder : EventRecorder {
            attribute :>> storageCapacity = 10000;
            attribute :>> recordingEnabled = true;
        }
        
        connection analyzerToAdvisor connect analyzer to advisor;
        connection advisorToWorkstation connect advisor.assessmentOutput to workstation.interfacePort;
        connection workstationToIntegrator connect workstation to integrator;
        connection monitorToWorkstation connect monitor.monitoringPort to workstation.interfacePort;
        connection integratorToMonitor connect integrator to monitor;
        connection integratorToRecorder connect integrator to recorder;
        
        perform action mainProcess : DecisionCycleWithBiasMonitoring[*];
    }
    
    requirement <'REQ-AB-001'> detectAutomationBias {
        doc /*
         * The system shall detect automation bias by monitoring the rate at which operators
         * accept automated recommendations without adequate deliberation time or critical
         * evaluation, triggering alerts when bias indicators exceed acceptable thresholds.
         */
        subject system : AutomationBiasSystem;
        
        require constraint {
            system.monitor.biasThreshold >= 0.5 and
            system.monitor.biasThreshold <= 0.8
        }
    }
    
    requirement <'REQ-AB-002'> maintainOperatorEngagement {
        doc /*
         * The system shall maintain operator engagement by requiring acknowledgment of
         * automated recommendations and ensuring deliberation time is proportional to
         * decision complexity and automation confidence levels.
         */
        subject workstation : AutomationBiasSystem::workstation;
        
        require constraint {
            workstation.averageResponseTime >= 2.0 [s] and
            workstation.averageResponseTime <= 8.0 [s]
        }
    }
    
    requirement <'REQ-AB-003'> provideTransparentRecommendations {
        doc /*
         * The system shall provide transparent automated recommendations including
         * confidence levels, rationale, and supporting data to enable informed operator
         * evaluation rather than blind acceptance.
         */
        subject advisor : AutomationBiasSystem::advisor;
        
        require constraint {
            advisor.recommendationConfidenceThreshold >= 0.70
        }
    }
    
    requirement <'REQ-AB-004'> balanceAutomationAndHumanJudgment {
        doc /*
         * The system shall balance automated recommendations with human judgment by
         * applying bias compensation when elevated bias levels are detected, ensuring
         * operator input receives appropriate weight in final decisions.
         */
        subject integrator : AutomationBiasSystem::integrator;
        
        require constraint {
            integrator.biasCompensationEnabled == true and
            integrator.compensationFactor >= 0.2 and
            integrator.compensationFactor <= 0.5
        }
    }
    
    requirement <'REQ-AB-005'> monitorSystemPerformance {
        doc /*
         * The system shall continuously monitor automation reliability and operator
         * engagement to dynamically adjust bias detection sensitivity and maintain
         * optimal human-automation collaboration.
         */
        subject system : AutomationBiasSystem;
        
        require constraint {
            system.automationReliability >= 0.85 and
            system.operatorEngagementScore >= 0.60
        }
    }
    
    requirement <'REQ-AB-006'> recordDecisionHistory {
        doc /*
         * The system shall record all decisions, bias metrics, and operator responses
         * to support post-event analysis, trend identification, and continuous
         * improvement of bias mitigation strategies.
         */
        subject recorder : AutomationBiasSystem::recorder;
        
        require constraint {
            recorder.recordingEnabled == true and
            recorder.storageCapacity >= 5000
        }
    }
    
    part automationBiasSystemInstance : AutomationBiasSystem {
        attribute :>> systemBiasLevel = 0.42;
        attribute :>> operatorEngagementScore = 0.73;
        attribute :>> automationReliability = 0.91;
        attribute :>> totalDecisionsProcessed = 1547;
        attribute :>> biasIncidentCount = 23;
    }
    
    satisfy detectAutomationBias by automationBiasSystemInstance;
    satisfy maintainOperatorEngagement by automationBiasSystemInstance.workstation;
    satisfy provideTransparentRecommendations by automationBiasSystemInstance.advisor;
    satisfy balanceAutomationAndHumanJudgment by automationBiasSystemInstance.integrator;
    satisfy monitorSystemPerformance by automationBiasSystemInstance;
    satisfy recordDecisionHistory by automationBiasSystemInstance.recorder;
}
