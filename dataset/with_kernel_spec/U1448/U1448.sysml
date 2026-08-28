package 'Reliability Management System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;

	item def OperationalData {
		attribute componentId : String;
		attribute operationalHours : DurationValue;
		attribute failureCount : Integer;
	}

	item def ReliabilityReport {
		attribute reliability : Real;
		attribute mtbf : DurationValue;
	}

	item def FailureNotification {
		attribute componentId : String;
		attribute severity : Integer;
	}

	item def MaintenanceCommand {
		attribute componentId : String;
		attribute priority : Integer;
	}

	item def MaintenanceComplete;
	item def SystemReset;

	action def 'Track Operational Hours' {
		out hours : DurationValue;
	}
	action def 'Calculate Reliability' {
		out reliability : Real;
	}
	action def 'Calculate MTBF' {
		out mtbf : DurationValue;
	}
	action def 'Log Event';
	action def 'Perform Maintenance';
	action def 'Emergency Shutdown';
	action def 'Activate Backup';

	part def CriticalComponent {
		attribute componentId : String;
		attribute operationalHours : DurationValue;
		attribute expectedLife : DurationValue;
		attribute failureCount : Integer;
		attribute isActive : Boolean;

		port dataPort {
			out operationalData : OperationalData;
		}
		port failurePort {
			out failure : FailureNotification;
		}
		port maintenancePort {
			in maintenanceCommand : MaintenanceCommand;
		}

		state 'component states' {
			entry; then active;
			state active;
			accept when operationalHours >= expectedLife
				then failed;
			state failed;
			accept MaintenanceCommand via maintenancePort
				then active;
		}
	}

	part def ReliabilityMonitor {
		attribute systemReliability : Real;
		attribute systemMTBF : DurationValue;
		attribute reliabilityThreshold : Real;
		attribute criticalThreshold : Real;

		port dataInPort {
			in operationalData : OperationalData;
		}
		port failureInPort {
			in failure : FailureNotification;
		}
		port reportPort {
			out reliabilityReport : ReliabilityReport;
		}
	}

	part def MaintenanceController {
		attribute maintenanceThreshold : Real;
		attribute nextMaintenanceTime : TimeInstantValue;
		attribute maintenanceInterval : DurationValue;

		port reportInPort {
			in reliabilityReport : ReliabilityReport;
		}
		port commandPort {
			out maintenanceCommand : MaintenanceCommand;
		}
	}

	part def DataRecorder {
		attribute totalFailuresLogged : Integer;
		attribute totalMaintenanceLogged : Integer;

		port failureLogPort {
			in failure : FailureNotification;
		}
		port maintenanceLogPort {
			in maintenanceCommand : MaintenanceCommand;
		}
	}

	part def ReliabilitySystem {
		part primaryComponent : CriticalComponent;
		part secondaryComponent : CriticalComponent;
		part backupComponent : CriticalComponent;
		part reliabilityMonitor : ReliabilityMonitor;
		part maintenanceController : MaintenanceController;
		part dataRecorder : DataRecorder;

		action 'calculate reliability' : 'Calculate Reliability';
		action 'calculate mtbf' : 'Calculate MTBF';
		action 'log event' : 'Log Event';
		action 'perform maintenance' : 'Perform Maintenance';
		action 'emergency shutdown' : 'Emergency Shutdown';
		action 'activate backup' : 'Activate Backup';

		flow primaryDataFlow of OperationalData
			from primaryComponent.dataPort.operationalData
			to reliabilityMonitor.dataInPort.operationalData;
		flow secondaryDataFlow of OperationalData
			from secondaryComponent.dataPort.operationalData
			to reliabilityMonitor.dataInPort.operationalData;
		flow backupDataFlow of OperationalData
			from backupComponent.dataPort.operationalData
			to reliabilityMonitor.dataInPort.operationalData;

		flow primaryFailureFlow of FailureNotification
			from primaryComponent.failurePort.failure
			to reliabilityMonitor.failureInPort.failure;
		flow secondaryFailureFlow of FailureNotification
			from secondaryComponent.failurePort.failure
			to reliabilityMonitor.failureInPort.failure;
		flow backupFailureFlow of FailureNotification
			from backupComponent.failurePort.failure
			to reliabilityMonitor.failureInPort.failure;

		flow reliabilityReportFlow of ReliabilityReport
			from reliabilityMonitor.reportPort.reliabilityReport
			to maintenanceController.reportInPort.reliabilityReport;

		flow primaryMaintenanceFlow of MaintenanceCommand
			from maintenanceController.commandPort.maintenanceCommand
			to primaryComponent.maintenancePort.maintenanceCommand;
		flow secondaryMaintenanceFlow of MaintenanceCommand
			from maintenanceController.commandPort.maintenanceCommand
			to secondaryComponent.maintenancePort.maintenanceCommand;
		flow backupMaintenanceFlow of MaintenanceCommand
			from maintenanceController.commandPort.maintenanceCommand
			to backupComponent.maintenancePort.maintenanceCommand;

		flow primaryFailureLogFlow of FailureNotification
			from primaryComponent.failurePort.failure
			to dataRecorder.failureLogPort.failure;
		flow secondaryFailureLogFlow of FailureNotification
			from secondaryComponent.failurePort.failure
			to dataRecorder.failureLogPort.failure;
		flow backupFailureLogFlow of FailureNotification
			from backupComponent.failurePort.failure
			to dataRecorder.failureLogPort.failure;

		flow maintenanceLogFlow of MaintenanceCommand
			from maintenanceController.commandPort.maintenanceCommand
			to dataRecorder.maintenanceLogPort.maintenanceCommand;

		state 'system states' parallel {
			state 'operational states' {
				entry; then 'normal operation';
				state 'normal operation' {
					do 'calculate reliability';
					do 'calculate mtbf';
					do 'log event';
				}
				accept when reliabilityMonitor.systemReliability < reliabilityMonitor.reliabilityThreshold
					do 'activate backup'
					then 'degraded operation';
				accept at maintenanceController.nextMaintenanceTime
					then 'scheduled maintenance';
				state 'degraded operation';
				accept when reliabilityMonitor.systemReliability >= reliabilityMonitor.reliabilityThreshold
					then 'normal operation';
				accept when reliabilityMonitor.systemReliability < reliabilityMonitor.criticalThreshold
					do 'emergency shutdown'
					then 'critical failure';
				state 'scheduled maintenance' {
					do 'perform maintenance';
					do 'log event';
				}
				accept MaintenanceComplete
					then 'normal operation';
				state 'critical failure' {
					entry 'emergency shutdown';
				}
				accept SystemReset
					then 'normal operation';
			}
			state 'health monitoring states' {
				entry; then 'monitoring';
				state 'monitoring' {
					do 'calculate reliability';
					do 'calculate mtbf';
				}
				accept when reliabilityMonitor.systemReliability < reliabilityMonitor.criticalThreshold
					then 'alerting';
				state 'alerting';
				accept when reliabilityMonitor.systemReliability >= reliabilityMonitor.reliabilityThreshold
					then 'monitoring';
			}
		}
	}

	part reliabilitySystem : ReliabilitySystem {
		:>> primaryComponent {
			:>> componentId = "primary";
			:>> operationalHours = 1200 [h];
			:>> expectedLife = 2000 [h];
			:>> failureCount = 2;
			:>> isActive = true;
		}
		:>> secondaryComponent {
			:>> componentId = "secondary";
			:>> operationalHours = 800 [h];
			:>> expectedLife = 2000 [h];
			:>> failureCount = 1;
			:>> isActive = true;
		}
		:>> backupComponent {
			:>> componentId = "backup";
			:>> operationalHours = 100 [h];
			:>> expectedLife = 2000 [h];
			:>> failureCount = 0;
			:>> isActive = false;
		}
		:>> reliabilityMonitor {
			:>> reliabilityThreshold = 0.85;
			:>> criticalThreshold = 0.50;
			:>> systemMTBF = 500 [h];
		}
		:>> maintenanceController {
			:>> maintenanceThreshold = 0.75;
			:>> maintenanceInterval = 720 [h];
		}
		:>> dataRecorder {
			:>> totalFailuresLogged = 0;
			:>> totalMaintenanceLogged = 0;
		}
	}

	requirement def 'Reliability Requirement' {
		attribute minReliability : Real;
		attribute minMTBF : DurationValue;
		subject reliabilityMonitor : ReliabilityMonitor;
		require {
			reliabilityMonitor.systemReliability >= minReliability and
			reliabilityMonitor.systemMTBF >= minMTBF
		}
	}

	requirement 'System Reliability Req' : 'Reliability Requirement' {
		:>> minReliability = 0.85;
		:>> minMTBF = 500 [h];
	}

	requirement def 'Maintenance Scheduling Requirement' {
		attribute schedulingThreshold : Real;
		subject maintenanceController : MaintenanceController;
		require {
			maintenanceController.maintenanceThreshold <= schedulingThreshold
		}
	}

	requirement 'Preventive Maintenance Req' : 'Maintenance Scheduling Requirement' {
		:>> schedulingThreshold = 0.75;
	}

	requirement def 'Data Logging Requirement' {
		subject dataRecorder : DataRecorder;
		require {
			dataRecorder.totalFailuresLogged >= 0 and
			dataRecorder.totalMaintenanceLogged >= 0
		}
	}

	requirement 'Event Logging Req' : 'Data Logging Requirement';

	requirement def 'Component Life Tracking Requirement' {
		attribute maxUtilizationRatio : Real;
		subject component : CriticalComponent;
		require {
			component.operationalHours <= component.expectedLife
		}
	}

	requirement 'Primary Component Life Req' : 'Component Life Tracking Requirement' {
		subject :>> component = reliabilitySystem.primaryComponent;
	}
}
