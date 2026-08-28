package VoltageDetectorSystemModel {
	private import ScalarValues::*;
	private import SI::*;

	attribute def Voltage :> Real;

	item def VoltageReading {
		attribute value : Voltage;
	}

	item def ThresholdSetting {
		attribute upperLimit : Voltage;
		attribute lowerLimit : Voltage;
	}

	item def OverVoltageAlarm;
	item def UnderVoltageAlarm;
	item def EnableMonitoring;
	item def DisableMonitoring;
	item def ClearAlarm;

	port def VoltageOutPort {
		out item reading : VoltageReading;
	}

	port def VoltageInPort {
		in item reading : VoltageReading;
	}

	port def ThresholdInPort {
		in item setting : ThresholdSetting;
	}

	port def OverVoltageAlarmInPort {
		in item alarm : OverVoltageAlarm;
	}

	port def OverVoltageAlarmOutPort {
		out item alarm : OverVoltageAlarm;
	}

	port def UnderVoltageAlarmInPort {
		in item alarm : UnderVoltageAlarm;
	}

	port def UnderVoltageAlarmOutPort {
		out item alarm : UnderVoltageAlarm;
	}

	port def ControlPort {
		in item enableCmd : EnableMonitoring;
		in item disableCmd : DisableMonitoring;
		in item clearAlarmCmd : ClearAlarm;
	}

	action def Initialize;

	action def MeasureVoltage {
		out reading : VoltageReading;
	}

	action def CompareVoltage {
		in reading : VoltageReading;
		in upperLimit : Voltage;
		in lowerLimit : Voltage;
		out isOverVoltage : Boolean;
		out isUnderVoltage : Boolean;
	}

	action def MonitorVoltage {
		in upperLimit : Voltage;
		in lowerLimit : Voltage;
		out isOverVoltage : Boolean;
		out isUnderVoltage : Boolean;
	}

	action def ActivateAlarm {
		in isOverVoltage : Boolean;
		in isUnderVoltage : Boolean;
	}

	part def VoltageSensor {
		port voltageOut : VoltageOutPort;
		perform action measure : MeasureVoltage;
	}

	part def ThresholdComparator {
		attribute upperThreshold : Voltage;
		attribute lowerThreshold : Voltage;
		port voltageIn : VoltageInPort;
		port thresholdIn : ThresholdInPort;
		port overVoltageAlarmOut : OverVoltageAlarmOutPort;
		port underVoltageAlarmOut : UnderVoltageAlarmOutPort;
		perform action compare : CompareVoltage;
	}

	part def AlarmController {
		port overVoltageAlarmIn : OverVoltageAlarmInPort;
		port underVoltageAlarmIn : UnderVoltageAlarmInPort;
		port overVoltageAlarmOut : OverVoltageAlarmOutPort;
		port underVoltageAlarmOut : UnderVoltageAlarmOutPort;
		perform action activate : ActivateAlarm;
	}

	part def VoltageDetectorSystem {
		attribute upperThreshold : Voltage;
		attribute lowerThreshold : Voltage;

		port controlIn : ControlPort;
		port thresholdIn : ThresholdInPort;
		port overVoltageAlarmOut : OverVoltageAlarmOutPort;
		port underVoltageAlarmOut : UnderVoltageAlarmOutPort;

		part sensor : VoltageSensor;
		part comparator : ThresholdComparator;
		part alarmController : AlarmController;

		connect sensor.voltageOut to comparator.voltageIn;
		connect thresholdIn to comparator.thresholdIn;
		connect comparator.overVoltageAlarmOut to alarmController.overVoltageAlarmIn;
		connect comparator.underVoltageAlarmOut to alarmController.underVoltageAlarmIn;
		connect alarmController.overVoltageAlarmOut to overVoltageAlarmOut;
		connect alarmController.underVoltageAlarmOut to underVoltageAlarmOut;

		exhibit state detectorStates : DetectorStates;
	}

	state def DetectorStates;

	requirement def VoltageMonitoringRequirement {
		doc /* The system shall continuously monitor the incoming voltage and trigger an alarm when the voltage exceeds the upper threshold or drops below the lower threshold. */
		subject detector : VoltageDetectorSystem;
	}

	requirement def ThresholdConfigurationRequirement {
		doc /* The system shall allow configuration of upper and lower voltage thresholds via the control interface. */
		subject detector : VoltageDetectorSystem;
	}

	requirement def AlarmActivationRequirement {
		doc /* The alarm controller shall activate an external alarm upon receiving a voltage violation signal from the comparator. */
		subject controller : AlarmController;
	}

	requirement def StateManagementRequirement {
		doc /* The system shall operate through initialization, standby, active monitoring, and alarm states. */
		subject detector : VoltageDetectorSystem;
	}

	action initialize : Initialize;
	action monitorVoltage : MonitorVoltage;

	part voltageDetectorSystem : VoltageDetectorSystem {
		attribute :>> upperThreshold = 240 [V];
		attribute :>> lowerThreshold = 200 [V];
	}

	state detectorStates : DetectorStates {
		entry; then initialization;
		do monitorVoltage {
			in upperLimit = voltageDetectorSystem.upperThreshold;
			in lowerLimit = voltageDetectorSystem.lowerThreshold;
			out isOverVoltage;
			out isUnderVoltage;
		}

		state initialization {
			entry initialize;
		}
		accept after 1 [s]
			then standby;

		state standby;
		accept EnableMonitoring
			then activeMonitoring;

		state activeMonitoring;
		accept when monitorVoltage.isOverVoltage
			do send new OverVoltageAlarm() to voltageDetectorSystem.alarmController
			then alarm;
		accept when monitorVoltage.isUnderVoltage
			do send new UnderVoltageAlarm() to voltageDetectorSystem.alarmController
			then alarm;
		accept DisableMonitoring
			then standby;

		state alarm;
		accept ClearAlarm
			then activeMonitoring;
		accept DisableMonitoring
			then standby;
	}

	requirement voltageMonitoring : VoltageMonitoringRequirement {
		subject :>> detector = voltageDetectorSystem;
	}

	requirement thresholdConfig : ThresholdConfigurationRequirement {
		subject :>> detector = voltageDetectorSystem;
	}

	requirement alarmActivation : AlarmActivationRequirement {
		subject :>> controller = voltageDetectorSystem.alarmController;
	}

	requirement stateManagement : StateManagementRequirement {
		subject :>> detector = voltageDetectorSystem;
	}
}
