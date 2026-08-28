package ShockDetectionSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	enum def SeverityLevel { none; minor; moderate; severe; critical; }

	item def RawAcceleration {
		attribute magnitude : ISQ::AccelerationValue;
	}
	item def ConditionedAcceleration {
		attribute magnitude : ISQ::AccelerationValue;
	}
	item def ShockEventData {
		attribute timestamp : ISQ::TimeValue = 0;
		attribute severity : SeverityLevel;
		attribute peakAcceleration : ISQ::AccelerationValue;
		attribute duration : ISQ::TimeValue = 0;
	}
	item def ActivationSignal {
		attribute active : ScalarValues::Boolean;
	}
	item def RemoteNotificationMessage {
		attribute severity : SeverityLevel;
		attribute text : ScalarValues::String;
	}

	part def AccelerationSensor {
		port rawAccelPort {
			out raw : RawAcceleration;
		}
		exhibit state sensorStates {
			entry; then measuring;
			state measuring;
		}
	}

	part def SignalConditioner {
		port rawAccelInPort {
			in raw : RawAcceleration;
		}
		port conditionedAccelOutPort {
			out cond : ConditionedAcceleration;
		}
		exhibit state conditionerStates {
			entry; then filtering;
			state filtering;
			accept r : RawAcceleration via rawAccelInPort.raw
				do send new ConditionedAcceleration(magnitude = r.magnitude) via conditionedAccelOutPort.cond
				then filtering;
		}
	}

	part def ShockDetectionProcessor {
		port conditionedAccelInPort {
			in cond : ConditionedAcceleration;
		}
		port shockEventOutPort {
			out evt : ShockEventData;
		}
		port alertOutPort {
			out alert : ShockEventData;
		}
		attribute thresholdMinor : ISQ::AccelerationValue = 10;
		attribute thresholdModerate : ISQ::AccelerationValue = 25;
		attribute thresholdSevere : ISQ::AccelerationValue = 50;
		attribute thresholdCritical : ISQ::AccelerationValue = 100;
		exhibit state processorStates {
			entry; then monitoring;
			state monitoring;
			accept c : ConditionedAcceleration via conditionedAccelInPort.cond
				if c.magnitude > thresholdCritical
				do action {
					first start;
					then send new ShockEventData(severity = SeverityLevel::critical, peakAcceleration = c.magnitude) via shockEventOutPort.evt;
					then send new ShockEventData(severity = SeverityLevel::critical, peakAcceleration = c.magnitude) via alertOutPort.alert;
				}
				then monitoring;
			accept c : ConditionedAcceleration via conditionedAccelInPort.cond
				if c.magnitude > thresholdSevere
				do action {
					first start;
					then send new ShockEventData(severity = SeverityLevel::severe, peakAcceleration = c.magnitude) via shockEventOutPort.evt;
					then send new ShockEventData(severity = SeverityLevel::severe, peakAcceleration = c.magnitude) via alertOutPort.alert;
				}
				then monitoring;
			accept c : ConditionedAcceleration via conditionedAccelInPort.cond
				if c.magnitude > thresholdModerate
				do action {
					first start;
					then send new ShockEventData(severity = SeverityLevel::moderate, peakAcceleration = c.magnitude) via shockEventOutPort.evt;
					then send new ShockEventData(severity = SeverityLevel::moderate, peakAcceleration = c.magnitude) via alertOutPort.alert;
				}
				then monitoring;
			accept c : ConditionedAcceleration via conditionedAccelInPort.cond
				if c.magnitude > thresholdMinor
				do action {
					first start;
					then send new ShockEventData(severity = SeverityLevel::minor, peakAcceleration = c.magnitude) via shockEventOutPort.evt;
					then send new ShockEventData(severity = SeverityLevel::minor, peakAcceleration = c.magnitude) via alertOutPort.alert;
				}
				then monitoring;
		}
	}

	part def EventLogger {
		port eventInPort {
			in evt : ShockEventData;
		}
		attribute log : ShockEventData[*];
		attribute maxLogSize : ScalarValues::Integer = 10000;
		exhibit state loggerStates {
			entry; then ready;
			state ready;
			accept e : ShockEventData via eventInPort.evt
				then ready;
		}
	}

	part def AlertNotificationSystem {
		port alertInPort {
			in alert : ShockEventData;
		}
		port visualOutPort {
			out signal : ActivationSignal;
		}
		port audibleOutPort {
			out signal : ActivationSignal;
		}
		port remoteOutPort {
			out notification : RemoteNotificationMessage;
		}
		exhibit state alertStates {
			entry; then idle;
			state idle;
			accept e : ShockEventData via alertInPort.alert
				if e.severity == SeverityLevel::minor
				do send new ActivationSignal(active = true) via visualOutPort.signal
				then idle;
			accept e : ShockEventData via alertInPort.alert
				if e.severity == SeverityLevel::moderate
				do action {
					first start;
					then send new ActivationSignal(active = true) via visualOutPort.signal;
					then send new ActivationSignal(active = true) via audibleOutPort.signal;
				}
				then idle;
			accept e : ShockEventData via alertInPort.alert
				if e.severity == SeverityLevel::severe or e.severity == SeverityLevel::critical
				do action {
					first start;
					then send new ActivationSignal(active = true) via visualOutPort.signal;
					then send new ActivationSignal(active = true) via audibleOutPort.signal;
					then send new RemoteNotificationMessage(severity = e.severity, text = "Severe shock detected") via remoteOutPort.notification;
				}
				then idle;
		}
	}

	part def VisualAlarmDevice {
		port activationInPort {
			in signal : ActivationSignal;
		}
		exhibit state visualAlarmStates {
			entry; then inactive;
			state inactive;
			accept s : ActivationSignal via activationInPort.signal
				if s.active
				then active;
			state active;
		}
	}

	part def AudibleAlarmDevice {
		port activationInPort {
			in signal : ActivationSignal;
		}
		exhibit state audibleAlarmStates {
			entry; then inactive;
			state inactive;
			accept s : ActivationSignal via activationInPort.signal
				if s.active
				then active;
			state active;
		}
	}

	part def RemoteNotifier {
		port notificationInPort {
			in notification : RemoteNotificationMessage;
		}
		exhibit state notifierStates {
			entry; then standby;
			state standby;
			accept n : RemoteNotificationMessage via notificationInPort.notification
				then standby;
		}
	}

	part shockDetectionSystem {
		part sensor : AccelerationSensor;
		part conditioner : SignalConditioner;
		part processor : ShockDetectionProcessor;
		part logger : EventLogger;
		part notifier : AlertNotificationSystem;
		part visualAlarm : VisualAlarmDevice;
		part audibleAlarm : AudibleAlarmDevice;
		part remoteNotifier : RemoteNotifier;

		interface rawAccelInterface connect sensor.rawAccelPort to conditioner.rawAccelInPort {
			flow of RawAcceleration from sensor.rawAccelPort.raw to conditioner.rawAccelInPort.raw;
		}
		interface conditionedAccelInterface connect conditioner.conditionedAccelOutPort to processor.conditionedAccelInPort {
			flow of ConditionedAcceleration from conditioner.conditionedAccelOutPort.cond to processor.conditionedAccelInPort.cond;
		}
		interface shockEventToLoggerInterface connect processor.shockEventOutPort to logger.eventInPort {
			flow of ShockEventData from processor.shockEventOutPort.evt to logger.eventInPort.evt;
		}
		interface shockEventToAlertInterface connect processor.alertOutPort to notifier.alertInPort {
			flow of ShockEventData from processor.alertOutPort.alert to notifier.alertInPort.alert;
		}
		interface visualAlertInterface connect notifier.visualOutPort to visualAlarm.activationInPort {
			flow of ActivationSignal from notifier.visualOutPort.signal to visualAlarm.activationInPort.signal;
		}
		interface audibleAlertInterface connect notifier.audibleOutPort to audibleAlarm.activationInPort {
			flow of ActivationSignal from notifier.audibleOutPort.signal to audibleAlarm.activationInPort.signal;
		}
		interface remoteAlertInterface connect notifier.remoteOutPort to remoteNotifier.notificationInPort {
			flow of RemoteNotificationMessage from notifier.remoteOutPort.notification to remoteNotifier.notificationInPort.notification;
		}
	}

	requirement def ShockDetectionRequirements {
		doc /* Comprehensive shock detection system for monitoring physical impacts and sudden accelerations. */
		requirement senseImpacts {
			doc /* The AccelerationSensor shall continuously measure physical forces. */
		}
		requirement conditionSignal {
			doc /* The SignalConditioner shall filter raw sensor data to remove electrical noise and interference. */
		}
		requirement classifySeverity {
			doc /* The ShockDetectionProcessor shall classify shock severity into none, minor, moderate, severe, or critical based on pre-configured thresholds. */
		}
		requirement logEvents {
			doc /* The EventLogger shall record time, severity, and peak acceleration for all shock events in a historical log. */
		}
		requirement tieredAlerts {
			doc /* The AlertNotificationSystem shall provide tiered responses: minor activates visual indicator; moderate activates visual and audible; severe and critical activate visual, audible, and remote notification. */
		}
	}
}
