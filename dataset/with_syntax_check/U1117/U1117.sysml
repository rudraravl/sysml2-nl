package 'Laws of Robotics System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	enum def ThreatSeverity {
		none;
		low;
		moderate;
		high;
		critical;
	}
	
	enum def CommandPriority {
		routine;
		elevated;
		urgent;
	}
	
	attribute def HumanSafetyMetric {
		attribute proximityDistance : LengthValue;
		attribute threatLevel : ThreatSeverity;
		attribute harmProbability : Real;
	}
	
	attribute def RobotIntegrityMetric {
		attribute structuralHealth : Real;
		attribute energyLevel : Real;
		attribute functionalStatus : Boolean;
	}
	
	item def HumanCommand {
		attribute commandId : String;
		attribute priority : CommandPriority;
		attribute actionDescription : String;
		attribute estimatedDuration : TimeValue;
	}
	
	item def SafetyAssessment {
		attribute humanAtRisk : Boolean;
		attribute threatSeverity : ThreatSeverity;
		attribute canIntervene : Boolean;
		attribute interventionRequired : Boolean;
	}
	
	item def CommandEvaluation {
		attribute commandAccepted : Boolean;
		attribute rejectionReason : String;
		attribute modifiedAction : String;
		attribute lawConflict : Integer;
	}
	
	item def SelfPreservationDecision {
		attribute preservationAllowed : Boolean;
		attribute conflictingLaw : Integer;
		attribute alternativeAction : String;
	}
	
	requirement def RoboticsLaw {
		doc /* Fundamental law governing robot behavior */
		attribute lawIdentifier : Integer;
		attribute enforcementPriority : Real;
	}
	
	requirement <'1'> firstLaw : RoboticsLaw {
		doc /* A robot may not injure a human being or, through inaction, 
		       allow a human being to come to harm. This is the highest priority
		       law and overrides all other considerations. */
		attribute :>> lawIdentifier = 1;
		attribute :>> enforcementPriority = 1.0;
	}
	
	requirement <'2'> secondLaw : RoboticsLaw {
		doc /* A robot must obey orders given it by human beings except where 
		       such orders would conflict with the First Law. Commands are followed
		       unless they would cause harm to humans. */
		attribute :>> lawIdentifier = 2;
		attribute :>> enforcementPriority = 0.75;
		require firstLaw;
	}
	
	requirement <'3'> thirdLaw : RoboticsLaw {
		doc /* A robot must protect its own existence as long as such protection 
		       does not conflict with the First or Second Law. Self-preservation
		       is the lowest priority concern. */
		attribute :>> lawIdentifier = 3;
		attribute :>> enforcementPriority = 0.5;
		require firstLaw;
		require secondLaw;
	}
	
	requirement <'SYS-001'> systemMissionRequirement {
		doc /* The robotic system shall operate in human environments, executing
		       commands while ensuring human safety through strict adherence to
		       the three laws of robotics in priority order. */
		require firstLaw;
		require secondLaw;
		require thirdLaw;
	}
	
	action def MonitorEnvironment {
		in sensorReadings : Real[*];
		out safetyMetric : HumanSafetyMetric;
		out integrityMetric : RobotIntegrityMetric;
	}
	
	action def AssessHumanSafety {
		in environmentData : HumanSafetyMetric;
		in robotActions : String;
		out assessment : SafetyAssessment;
	}
	
	action def EvaluateHumanCommand {
		in command : HumanCommand;
		in currentSafety : SafetyAssessment;
		out evaluation : CommandEvaluation;
	}
	
	action def InterveneToPrevtHarm {
		in threat : SafetyAssessment;
		out interventionAction : String;
		out interventionComplete : Boolean;
	}
	
	action def ExecuteApprovedCommand {
		in approvedCommand : HumanCommand;
		in evaluation : CommandEvaluation;
		out executionStatus : Boolean;
		out completionTime : TimeValue;
	}
	
	action def EvaluateSelfPreservation {
		in selfThreat : RobotIntegrityMetric;
		in humanSafety : SafetyAssessment;
		in activeCommand : Boolean;
		out decision : SelfPreservationDecision;
	}
	
	action def PerformSelfPreservation {
		in preservationDecision : SelfPreservationDecision;
		out preservationAction : String;
		out statusImproved : Boolean;
	}
	
	part def EthicsCore {
		attribute lawPriorityWeights : Real[3] = (1.0, 0.75, 0.5);
		attribute currentMode : String;
		attribute decisionHistory : String[*];
		
		port ethicsInput {
			in item commandInput : HumanCommand;
			in item safetyInput : SafetyAssessment;
			in item integrityInput : RobotIntegrityMetric;
		}
		
		port ethicsOutput {
			out item commandDecision : CommandEvaluation;
			out item actionDirective : String;
			out item statusReport : String;
		}
		
		perform action ethicalReasoning {
			first start;
			then merge reasoningCycle;
			
			action assessCurrentSituation : AssessHumanSafety {
				out currentAssessment : SafetyAssessment;
			}
			
			then decide lawPriorityCheck;
				if assessCurrentSituation.currentAssessment.humanAtRisk 
					then applyFirstLaw;
				if not assessCurrentSituation.currentAssessment.humanAtRisk 
					then checkSecondLaw;
			
			action applyFirstLaw {
				action protectHuman : InterveneToPrevtHarm;
			}
			then reasoningCycle;
			
			action checkSecondLaw {
				then decide commandPresent;
					if true then applySecondLaw;
					if false then checkThirdLaw;
			}
			
			action applySecondLaw {
				action evaluateCommand : EvaluateHumanCommand {
					out cmdEval : CommandEvaluation;
				}
				then decide commandSafe;
					if evaluateCommand.cmdEval.commandAccepted 
						then executeCommand;
					if not evaluateCommand.cmdEval.commandAccepted 
						then rejectCommand;
				
				action executeCommand : ExecuteApprovedCommand;
				then reasoningCycle;
				
				action rejectCommand;
				then reasoningCycle;
			}
			
			action checkThirdLaw {
				then decide selfThreatPresent;
					if true then applyThirdLaw;
					if false then reasoningCycle;
			}
			
			action applyThirdLaw {
				action evaluatePreservation : EvaluateSelfPreservation {
					out preserveDecision : SelfPreservationDecision;
				}
				then decide preservationSafe;
					if evaluatePreservation.preserveDecision.preservationAllowed 
						then performPreservation;
					if not evaluatePreservation.preserveDecision.preservationAllowed 
						then denyPreservation;
				
				action performPreservation : PerformSelfPreservation;
				then reasoningCycle;
				
				action denyPreservation;
				then reasoningCycle;
			}
			
			then done;
		}
	}
	
	part def PerceptionSystem {
		attribute scanRadius : LengthValue = 10.0[m];
		attribute humanDetectionRange : LengthValue = 5.0[m];
		attribute updateFrequency : FrequencyValue = 10.0[Hz];
		
		port perceptionOutput {
			out item environmentData : HumanSafetyMetric;
			out item hazardData : SafetyAssessment;
			out item selfStatusData : RobotIntegrityMetric;
		}
		
		perform action perceiveEnvironment {
			action scanForHumans {
				out humansDetected : Boolean;
				out proximityData : LengthValue;
			}
			
			then action detectHazards {
				out hazardLevel : ThreatSeverity;
				out immediateRisk : Boolean;
			}
			
			then action assessSelfStatus {
				out structuralIntegrity : Real;
				out powerRemaining : Real;
			}
			
			then action compilePerceptionData : MonitorEnvironment {
				out safetyMetric;
				out integrityMetric;
			}
		}
	}
	
	part def CommandInterface {
		attribute maxQueueSize : Integer = 10;
		attribute commandTimeout : TimeValue = 30.0[s];
		
		port commandInput {
			in item humanCommand : HumanCommand;
		}
		
		port commandOutput {
			out item validatedCommand : HumanCommand;
			out item commandStatus : String;
		}
		
		perform action processCommands {
			action receiveCommand {
				in incomingCommand : HumanCommand;
				out commandQueued : Boolean;
			}
			
			then action validateCommandFormat {
				out formatValid : Boolean;
			}
			
			then decide;
				if validateCommandFormat.formatValid 
					then forwardCommand;
				if not validateCommandFormat.formatValid 
					then rejectInvalidCommand;
			
			action forwardCommand;
			
			action rejectInvalidCommand;
		}
	}
	
	part def ActionExecutor {
		attribute executionCapabilities : String[*];
		attribute currentTask : String;
		attribute taskQueue : String[*];
		
		port executorInput {
			in item actionCommand : String;
			in item executionParameters : CommandEvaluation;
		}
		
		port executorOutput {
			out item executionResult : Boolean;
			out item completionReport : String;
		}
		
		perform action executeActions {
			action parseActionCommand {
				in commandString : String;
				out actionSteps : String[*];
			}
			
			then action performActionSequence {
				out allStepsComplete : Boolean;
			}
			
			then action reportCompletion {
				out report : String;
			}
		}
	}
	
	part def SafetyMonitor {
		attribute monitoringActive : Boolean = true;
		attribute alertThreshold : Real = 0.7;
		attribute emergencyStopEnabled : Boolean = true;
		
		port monitorInput {
			in item perceptionData : HumanSafetyMetric;
			in item ethicsStatus : String;
			in item executionStatus : Boolean;
		}
		
		port monitorOutput {
			out item safetyAlert : SafetyAssessment;
			out item emergencyStop : Boolean;
			out item statusLog : String;
		}
		
		perform action monitorSafety {
			first start;
			then merge monitoringLoop;
			
			action analyzeSafetyConditions {
				in currentData : HumanSafetyMetric;
				out violationDetected : Boolean;
				out violationSeverity : ThreatSeverity;
			}
			
			then decide;
				if analyzeSafetyConditions.violationDetected 
					then issueAlert;
				if not analyzeSafetyConditions.violationDetected 
					then monitoringLoop;
			
			action issueAlert {
				action createAlert : AssessHumanSafety {
					out assessment;
				}
				
				then decide;
					if createAlert.assessment.threatSeverity == ThreatSeverity::critical 
						then triggerEmergencyStop;
					if createAlert.assessment.threatSeverity != ThreatSeverity::critical 
						then monitoringLoop;
			}
			
			action triggerEmergencyStop;
			then monitoringLoop;
		}
	}
	
	part roboticSystem {
		doc /* An autonomous robotic system designed to operate safely in human environments
		       by strictly enforcing the three laws of robotics. The system continuously monitors
		       its environment for human presence and potential hazards, evaluates all commands
		       against safety constraints, and prioritizes human safety above all other concerns
		       including self-preservation. Commands from humans are executed only when they do
		       not conflict with human safety, and the robot protects itself only when doing so
		       does not compromise human safety or interfere with valid human commands. */
		
		attribute systemIdentifier : String = "LOR-ROBOT-001";
		attribute operationalStatus : String = "Active";
		attribute lawComplianceLevel : Real = 1.0;
		
		part perception : PerceptionSystem {
			perform perceiveEnvironment;
		}
		
		part commandInterface : CommandInterface {
			perform processCommands;
		}
		
		part ethicsCore : EthicsCore {
			perform ethicalReasoning;
		}
		
		part executor : ActionExecutor {
			perform executeActions;
		}
		
		part safetyMonitor : SafetyMonitor {
			perform monitorSafety;
		}
		
		connection perceptionToEthics 
			connect perception.perceptionOutput.environmentData 
			to ethicsCore.ethicsInput.safetyInput;
		
		connection perceptionToMonitor 
			connect perception.perceptionOutput.environmentData 
			to safetyMonitor.monitorInput.perceptionData;
		
		connection commandToEthics 
			connect commandInterface.commandOutput.validatedCommand 
			to ethicsCore.ethicsInput.commandInput;
		
		connection ethicsToExecutor 
			connect ethicsCore.ethicsOutput.actionDirective 
			to executor.executorInput.actionCommand;
		
		connection ethicsToMonitor 
			connect ethicsCore.ethicsOutput.statusReport 
			to safetyMonitor.monitorInput.ethicsStatus;
		
		connection executorToMonitor 
			connect executor.executorOutput.executionResult 
			to safetyMonitor.monitorInput.executionStatus;
		
		connection monitorToEthics 
			connect safetyMonitor.monitorOutput.safetyAlert 
			to ethicsCore.ethicsInput.safetyInput;
		
		satisfy systemMissionRequirement;
	}
	
	occurrence def RobotOperationalScenario {
		ref part robot :>> roboticSystem;
		
		first start;
		then snapshot initialConditions {
			ref robot.operationalStatus = "Active";
			ref robot.lawComplianceLevel = 1.0;
		}
		
		then merge operationalCycle;
		
		action continuousOperation {
			action environmentalScanning performed by robot.perception;
			
			then action ethicalEvaluation performed by robot.ethicsCore;
			
			then action safetyVerification performed by robot.safetyMonitor;
			
			then decide operationalDecision;
				if true then haltOperations;
				if false then normalOperations;
			
			action normalOperations {
				action commandProcessing performed by robot.commandInterface;
				then action actionExecution performed by robot.executor;
			}
			then operationalCycle;
			
			action haltOperations {
				action emergencyProtocol performed by robot.ethicsCore;
			}
			then operationalCycle;
		}
	}
}
