package OutOfTheLoopPerformanceSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def AlertnessLevel {
		attribute value : Real;
		doc /* Operator alertness from 0.0 (unaware) to 1.0 (fully alert) */
	}
	
	attribute def ReactionTime {
		attribute value : Real;
		doc /* Time in seconds for operator to respond */
	}
	
	attribute def AutomationMode {
		attribute level : Real;
		doc /* Automation level from 0.0 (manual) to 1.0 (fully automated) */
	}
	
	value def TimeValue :> Real {
		attribute unit : String = "s";
	}
	
	value def SpeedValue :> Real {
		attribute unit : String = "m/s";
	}
	
	item def ControlInput {
		attribute inputType : String;
		attribute magnitude : Real;
		attribute timestamp : TimeValue;
	}
	
	item def SystemAlert {
		attribute severity : String;
		attribute message : String;
		attribute requiresIntervention : Boolean;
	}
	
	item def AutomationCommand {
		attribute commandType : String;
		attribute targetValue : Real;
		attribute executionTime : TimeValue;
	}
	
	item def SystemStatus {
		attribute operationalState : String;
		attribute performanceMetric : Real;
		attribute anomalyDetected : Boolean;
	}
	
	port def OperatorControlPort {
		in item alertToOperator : SystemAlert;
		out item operatorInput : ControlInput;
	}
	
	port def AutomationControlPort {
		out item automationOutput : AutomationCommand;
		in item manualOverride : ControlInput;
	}
	
	port def SystemMonitorPort {
		out item statusReport : SystemStatus;
	}
	
	part def HumanOperator {
		attribute currentAlertness : AlertnessLevel;
		attribute normalReactionTime : ReactionTime;
		attribute degradedReactionTime : ReactionTime;
		attribute situationalAwareness : Real;
		
		port operatorInterface : OperatorControlPort;
		
		action def MonitorAutomation {
			in status : SystemStatus;
			out awarenessLevel : Real;
		}
		
		action def RespondToAlert {
			in alert : SystemAlert;
			in currentAlertness : Real;
			out response : ControlInput;
			out responseTime : Real;
		}
		
		action def UpdateAwareness {
			in automationActive : Boolean;
			in timeInLoop : Real;
			out newAlertness : Real;
		}
		
		state machine OperatorEngagement {
			entry; then activelyEngaged;
			
			state activelyEngaged {
				doc /* Operator maintains high situational awareness */
				entry assign currentAlertness.value := 0.9;
			}
			
			transition toMonitoring
				first activelyEngaged
				accept when situationalAwareness < 0.7
				then passiveMonitoring;
			
			state passiveMonitoring {
				doc /* Operator awareness degrading due to prolonged automation */
				entry assign currentAlertness.value := currentAlertness.value * 0.5;
			}
			
			transition toDisengaged
				first passiveMonitoring
				accept when currentAlertness.value < 0.3
				then disengaged;
			
			state disengaged {
				doc /* Operator out-of-the-loop with minimal awareness */
				entry assign currentAlertness.value := 0.2;
			}
			
			transition toRecovery
				first disengaged
				accept alertReceived : SystemAlert
				then recoveryMode;
			
			state recoveryMode {
				doc /* Operator attempting to regain situational awareness */
				entry assign degradedReactionTime.value := normalReactionTime.value * 4.0;
			}
			
			transition backToActive
				first recoveryMode
				accept when currentAlertness.value >= 0.7
				then activelyEngaged;
		}
	}
	
	part def AutomationController {
		attribute automationEnabled : Boolean;
		attribute currentMode : AutomationMode;
		attribute operationDuration : TimeValue;
		attribute anomalyThreshold : Real;
		
		port automationInterface : AutomationControlPort;
		port monitoringInterface : SystemMonitorPort;
		
		action def ExecuteAutomatedControl {
			out command : AutomationCommand;
		}
		
		action def MonitorSystemHealth {
			in status : SystemStatus;
			out anomalyDetected : Boolean;
		}
		
		action def GenerateAlert {
			in anomaly : Boolean;
			out alert : SystemAlert;
		}
		
		action def TransferControl {
			in override : ControlInput;
			out controlTransferred : Boolean;
		}
		
		state machine AutomationState {
			entry; then normalOperation;
			
			state normalOperation {
				doc /* Automation controlling system normally */
				entry assign automationEnabled := true;
				do action control : ExecuteAutomatedControl;
			}
			
			transition toAnomalyDetection
				first normalOperation
				accept when MonitorSystemHealth.anomalyDetected
				then anomalyHandling;
			
			state anomalyHandling {
				doc /* Anomaly detected requiring operator intervention */
				entry assign automationEnabled := false;
				do action alerting : GenerateAlert;
			}
			
			transition toManualControl
				first anomalyHandling
				accept manualInput : ControlInput
				then manualOverride;
			
			state manualOverride {
				doc /* Operator has assumed manual control */
			}
			
			transition backToNormal
				first manualOverride
				accept when not anomalyDetected
				then normalOperation;
		}
	}
	
	part def ControlledProcess {
		attribute processState : String;
		attribute performanceLevel : Real;
		attribute stabilityMetric : Real;
		
		action def ApplyControlCommand {
			in command : AutomationCommand;
			out newState : String;
			out performance : Real;
		}
		
		action def ApplyManualInput {
			in input : ControlInput;
			out newState : String;
			out performance : Real;
		}
		
		action def ReportStatus {
			out status : SystemStatus;
		}
	}
	
	part def SituationalAwarenessMonitor {
		attribute awarenessThreshold : Real;
		attribute monitoringInterval : TimeValue;
		
		action def AssessOperatorAwareness {
			in operatorAlertness : Real;
			in automationDuration : Real;
			out awarenessScore : Real;
		}
		
		action def TriggerAwarenessAlert {
			in awarenessScore : Real;
			out alert : SystemAlert;
		}
	}
	
	part outOfLoopSystem : OutOfLoopControlSystem;
	
	part def OutOfLoopControlSystem {
		doc /* 
			System demonstrating out-of-the-loop performance problem where prolonged 
			automation reduces operator engagement and situational awareness, resulting 
			in degraded performance when manual intervention becomes necessary. The system 
			monitors operator alertness and provides mechanisms to maintain engagement.
		*/
		
		part operator : HumanOperator {
			:>> currentAlertness.value = 0.9;
			:>> normalReactionTime.value = 2.5;
			:>> degradedReactionTime.value = 10.0;
			:>> situationalAwareness = 0.85;
		}
		
		part automation : AutomationController {
			:>> automationEnabled = true;
			:>> currentMode.level = 0.95;
			:>> operationDuration.value = 0.0;
			:>> anomalyThreshold = 0.15;
		}
		
		part process : ControlledProcess {
			:>> processState = "stable";
			:>> performanceLevel = 0.92;
			:>> stabilityMetric = 0.88;
		}
		
		part awarenessMonitor : SituationalAwarenessMonitor {
			:>> awarenessThreshold = 0.5;
			:>> monitoringInterval.value = 30.0;
		}
		
		connect operator.operatorInterface to automation.automationInterface;
		connect automation.monitoringInterface to process.ReportStatus;
		
		perform action systemOperation {
			first start;
			then merge operationLoop;
			
			action automatedControl {
				action executeControl : automation.ExecuteAutomatedControl;
				then action applyToProcess : process.ApplyControlCommand {
					in command = executeControl.command;
				}
				then action monitorHealth : automation.MonitorSystemHealth {
					in status.operationalState = applyToProcess.newState;
					in status.performanceMetric = applyToProcess.performance;
				}
				then action updateOperatorState : operator.UpdateAwareness {
					in automationActive = automation.automationEnabled;
					in timeInLoop = automation.operationDuration.value;
				}
				then action assessAwareness : awarenessMonitor.AssessOperatorAwareness {
					in operatorAlertness = operator.currentAlertness.value;
					in automationDuration = automation.operationDuration.value;
				}
			}
			
			then decide;
				if automatedControl.monitorHealth.anomalyDetected then handleAnomaly;
				if automatedControl.assessAwareness.awarenessScore < awarenessMonitor.awarenessThreshold 
					then maintainAwareness;
				else operationLoop;
			
			action handleAnomaly {
				action generateAlert : automation.GenerateAlert {
					in anomaly = true;
					out alert;
				}
				then action operatorResponse : operator.RespondToAlert {
					in alert = generateAlert.alert;
					in currentAlertness = operator.currentAlertness.value;
				}
				then action transferControl : automation.TransferControl {
					in override = operatorResponse.response;
				}
				then action manualControl : process.ApplyManualInput {
					in input = operatorResponse.response;
				}
			}
			
			action maintainAwareness {
				action triggerAlert : awarenessMonitor.TriggerAwarenessAlert {
					in awarenessScore = awarenessMonitor.AssessOperatorAwareness.awarenessScore;
				}
				then action operatorReengage : operator.MonitorAutomation {
					in status.operationalState = process.processState;
				}
			}
			
			then operationLoop;
			then done;
		}
	}
	
	requirement def PerformanceRequirement;
	requirement def SafetyRequirement;
	
	requirement <'OOTL-REQ-1'> maintainOperatorEngagement : PerformanceRequirement {
		doc /* 
			The system shall maintain operator situational awareness above 
			minimum threshold during automated operation to ensure effective 
			intervention capability.
		*/
		subject system : OutOfLoopControlSystem;
		require constraint {
			system.operator.currentAlertness.value >= 0.5
		}
	}
	
	requirement <'OOTL-REQ-2'> boundResponseTime : SafetyRequirement {
		doc /* 
			Operator response time to critical alerts shall not exceed 
			maximum allowable time to ensure safe system recovery.
		*/
		subject system : OutOfLoopControlSystem;
		require constraint {
			system.operator.RespondToAlert.responseTime <= 12.0
		}
	}
	
	requirement <'OOTL-REQ-3'> continuousAwarenessMonitoring : PerformanceRequirement {
		doc /* 
			System shall continuously monitor operator awareness and provide 
			engagement prompts when degradation is detected.
		*/
		subject monitor : SituationalAwarenessMonitor;
		require constraint {
			monitor.monitoringInterval.value <= 60.0
		}
	}
	
	requirement <'OOTL-REQ-4'> mitigateOutOfLoopDegradation {
		doc /* 
			System shall implement countermeasures to mitigate out-of-the-loop 
			performance degradation through awareness monitoring, timely alerts, 
			and operator engagement mechanisms.
		*/
		assume constraint prolongedAutomation {
			doc /* Automation operates for extended periods reducing operator engagement */
		}
		require maintainOperatorEngagement;
		require boundResponseTime;
		require continuousAwarenessMonitoring;
	}
}
