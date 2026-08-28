package 'Supervisory Control System' {
	private import ScalarValues::*;
	private import ISQ::*;

	enum def EngagementLevel {
		active;
		passive;
		disengaged;
	}

	item def CriticalAlert;
	item def EngagementPrompt;
	item def ControlCommand;
	item def ManualControlCommand;
	item def ProcessStatus;
	item def AnomalyDetected :> ProcessStatus;
	item def ProcessNormalized :> ProcessStatus;
	item def DisengagementDetected;
	item def ResumeAutomation;
	item def ResumeAutomationTrigger;

	part def HumanOperator {
		attribute reactionTime : Real;
		port engagementSignal : DisengagementDetected;
		port criticalAlert : CriticalAlert;
		port prompt : EngagementPrompt;
		port manualControl : ManualControlCommand;
		port resumeAutomation : ResumeAutomation;

		exhibit state 'Operator Engagement' {
			entry; then active;
			state active;
			accept after 300.0 s
				then passive;
			state passive;
			accept after 300.0 s
				do send new DisengagementDetected() to engagementSignal
				then disengaged;
			state disengaged;
			accept EngagementPrompt via prompt
				then active;
			accept CriticalAlert via criticalAlert
				do send new ManualControlCommand() to manualControl
				then manualOverride;
			state manualOverride;
			accept ResumeAutomationTrigger
				do send new ResumeAutomation() to resumeAutomation
				then active;
		}
	}

	part def AutomationController {
		port processCommand : ControlCommand;
		port processStatus : ProcessStatus;
		port criticalAlert : CriticalAlert;
		port resumeAutomation : ResumeAutomation;

		exhibit state 'Controller States' {
			entry; then autonomous;
			state autonomous {
				do action manageProcess { }
			}
			accept AnomalyDetected via processStatus
				do send new CriticalAlert() to criticalAlert
				then manualHandover;
			state manualHandover;
			accept ResumeAutomation via resumeAutomation
				then autonomous;
		}
	}

	part def ControlledProcess {
		port autoCommand : ControlCommand;
		port manualCommand : ManualControlCommand;
		port status : ProcessStatus;

		exhibit state 'Process States' {
			entry; then nominal;
			state nominal;
			accept AnomalyDetected
				do send new AnomalyDetected() to status
				then faulted;
			state faulted;
			accept ManualControlCommand via manualCommand
				then manualControlState;
			state manualControlState;
			accept ControlCommand via autoCommand
				do send new ProcessNormalized() to status
				then nominal;
		}
	}

	part def SituationalAwarenessMonitor {
		port operatorSignal : DisengagementDetected;
		port prompt : EngagementPrompt;

		exhibit state 'Monitor States' {
			entry; then monitoring;
			state monitoring;
			accept DisengagementDetected via operatorSignal
				do send new EngagementPrompt() to prompt
				then monitoring;
		}
	}

	part 'Supervisory System' {
		part operator : HumanOperator;
		part controller : AutomationController;
		part process : ControlledProcess;
		part saMonitor : SituationalAwarenessMonitor;

		connect controller.processCommand to process.autoCommand;
		connect process.status to controller.processStatus;
		connect controller.criticalAlert to operator.criticalAlert;
		connect operator.manualControl to process.manualCommand;
		connect operator.resumeAutomation to controller.resumeAutomation;
		connect operator.engagementSignal to saMonitor.operatorSignal;
		connect saMonitor.prompt to operator.prompt;
	}

	requirement def 'Prevent Out-of-the-Loop' {
		doc /* The system shall prevent the operator from becoming deeply disengaged by monitoring engagement and issuing prompts. */
	}

	requirement def 'Effective Manual Takeover' {
		doc /* The system shall issue critical alerts and hand over control to the operator when automation detects an anomaly. */
	}
}
