package MedicalInfusionPumpSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def FlowRate :> Real;
	attribute def Volume :> Real;

	item def TherapeuticSubstance {
		attribute name : String;
		attribute concentration : Real;
	}

	attribute def ReservoirInstalled;
	attribute def PrimeComplete;
	attribute def StartInfusion;
	attribute def PauseCommand;
	attribute def ResumeCommand;
	attribute def StopCommand;
	attribute def TherapyComplete;
	attribute def HighFlowAlarm;
	attribute def LowFlowAlarm;
	attribute def EmptyReservoirAlarm;
	attribute def AlarmCleared;
	attribute def ResetCommand;

	attribute def FlowCommand {
		attribute targetRate : FlowRate;
	}

	action PrimeLine;
	action DeliverSubstance;
	action TriggerAlarm;
	action HaltDelivery;

	state def SystemStates;
	state def MonitorStates;
	state def ControllerStates;

	part def SubstanceReservoir {
		attribute capacity : Volume;
		attribute remainingVolume : Volume;
		port substanceOutPort {
			out substance : TherapeuticSubstance;
		}
		port volumeReportPort {
			out remainingVolume : Volume;
		}
	}

	part def InfusionPump {
		port substanceInPort {
			in substance : TherapeuticSubstance;
		}
		port substanceOutPort {
			out substance : TherapeuticSubstance;
		}
		port flowCommandPort {
			in flowCommand : FlowCommand;
		}
		port flowRateReportPort {
			out flowRate : FlowRate;
		}
		attribute currentRate : FlowRate;
	}

	part def FlowController {
		port setRatePort {
			in setRate : FlowCommand;
		}
		port sensedFlowPort {
			in sensedFlow : FlowRate;
		}
		port flowCommandPort {
			out flowCommand : FlowCommand;
		}
		attribute targetRate : FlowRate;
		exhibit state controllerStates : ControllerStates {
			entry; then idle;
			state idle;
			accept FlowCommand
				then active;
			state active;
			accept StopCommand
				then idle;
		}
	}

	part def SafetyMonitor {
		port flowRatePort {
			in flowRate : FlowRate;
		}
		port volumePort {
			in remainingVolume : Volume;
		}
		port alarmOutPort {
			out highFlowAlarm : HighFlowAlarm;
			out lowFlowAlarm : LowFlowAlarm;
			out emptyReservoirAlarm : EmptyReservoirAlarm;
		}
		attribute maxSafeRate : FlowRate;
		attribute minSafeRate : FlowRate;
		attribute lowVolumeThreshold : Volume;
		exhibit state monitorStates : MonitorStates {
			entry; then monitoring;
			state monitoring;
			accept when flowRatePort.flowRate > maxSafeRate
				do send new HighFlowAlarm() to alarmOutPort
				then alerting;
			accept when flowRatePort.flowRate < minSafeRate
				do send new LowFlowAlarm() to alarmOutPort
				then alerting;
			accept when volumePort.remainingVolume < lowVolumeThreshold
				do send new EmptyReservoirAlarm() to alarmOutPort
				then alerting;
			state alerting;
			accept AlarmCleared
				then monitoring;
		}
	}

	part def PatientInterface {
		port substanceInPort {
			in substance : TherapeuticSubstance;
		}
		port substanceOutPort {
			out substance : TherapeuticSubstance;
		}
	}

	part def Patient {
		port substanceInPort {
			in substance : TherapeuticSubstance;
		}
	}

	part def InfusionPumpSystem {
		port commandPort {
			in startInfusion : StartInfusion;
			in pauseCommand : PauseCommand;
			in resumeCommand : ResumeCommand;
			in stopCommand : StopCommand;
			in resetCommand : ResetCommand;
		}
		port internalAlarmPort {
			in highFlowAlarm : HighFlowAlarm;
			in lowFlowAlarm : LowFlowAlarm;
			in emptyReservoirAlarm : EmptyReservoirAlarm;
		}
		port alarmOutPort {
			out highFlowAlarm : HighFlowAlarm;
			out lowFlowAlarm : LowFlowAlarm;
			out emptyReservoirAlarm : EmptyReservoirAlarm;
		}

		part reservoir : SubstanceReservoir {
			attribute capacity = 500;
			attribute remainingVolume = 500;
		}
		part pump : InfusionPump;
		part controller : FlowController;
		part monitor : SafetyMonitor {
			attribute maxSafeRate = 200;
			attribute minSafeRate = 1;
			attribute lowVolumeThreshold = 20;
		}
		part patientInterface : PatientInterface;
		part patient : Patient;

		flow substanceFlow of TherapeuticSubstance
			from reservoir.substanceOutPort.substance to pump.substanceInPort.substance;
		flow substanceDeliveryFlow of TherapeuticSubstance
			from pump.substanceOutPort.substance to patientInterface.substanceInPort.substance;
		flow patientFlow of TherapeuticSubstance
			from patientInterface.substanceOutPort.substance to patient.substanceInPort.substance;
		flow volumeReportFlow of Volume
			from reservoir.volumeReportPort.remainingVolume to monitor.volumePort.remainingVolume;
		flow flowRateReportFlow of FlowRate
			from pump.flowRateReportPort.flowRate to monitor.flowRatePort.flowRate;
		flow flowRateToControllerFlow of FlowRate
			from pump.flowRateReportPort.flowRate to controller.sensedFlowPort.sensedFlow;
		flow flowCommandFlow of FlowCommand
			from controller.flowCommandPort.flowCommand to pump.flowCommandPort.flowCommand;

		bind monitor.alarmOutPort = internalAlarmPort;

		exhibit state systemStates : SystemStates {
			entry; then standby;

			state standby;
			accept ReservoirInstalled
				then loading;

			state loading;
			accept PrimeComplete
				then priming;

			state priming {
				entry PrimeLine;
			}
			accept StartInfusion
				then infusing;

			state infusing {
				do DeliverSubstance;
			}
			accept HighFlowAlarm
				then alarm;
			accept LowFlowAlarm
				then alarm;
			accept EmptyReservoirAlarm
				then alarm;
			accept PauseCommand
				then paused;
			accept TherapyComplete
				then completed;

			state paused;
			accept ResumeCommand
				then infusing;
			accept StopCommand
				then completed;
			accept HighFlowAlarm
				then alarm;
			accept LowFlowAlarm
				then alarm;
			accept EmptyReservoirAlarm
				then alarm;

			state completed;
			accept ResetCommand
				then standby;

			state alarm {
				entry TriggerAlarm;
				do HaltDelivery;
			}
			accept AlarmCleared
				then standby;
		}
	}

	requirement def SafeFlowRateRequirement {
		subject pumpSystem : InfusionPumpSystem;
		doc /* The infusion pump must maintain flow rate within safe limits. */
		constraint { pumpSystem.monitor.maxSafeRate <= 200 }
		constraint { pumpSystem.monitor.minSafeRate >= 0.1 }
	}

	requirement def ReservoirMonitoringRequirement {
		subject pumpSystem : InfusionPumpSystem;
		doc /* The system must monitor reservoir volume and alert when nearly empty. */
		constraint { pumpSystem.monitor.lowVolumeThreshold >= 10 }
	}

	requirement def AlarmOnSafetyIssueRequirement {
		subject pumpSystem : InfusionPumpSystem;
		doc /* The system must trigger an alarm and halt delivery on any safety issue. */
	}

	requirement def DeliveryAccuracyRequirement {
		subject pumpSystem : InfusionPumpSystem;
		doc /* The pump must deliver medication at the prescribed rate within 5 percent accuracy. */
	}
}
