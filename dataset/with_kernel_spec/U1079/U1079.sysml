package SmartHomeAssistiveLiving {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		value def HeartRateValue :> ScalarValues::Real { unit "bpm"; }
		value def TemperatureValue :> ScalarValues::Real { unit "degC"; }
		value def IlluminanceValue :> ScalarValues::Real { unit "lux"; }
		value def AccelerationValue :> ScalarValues::Real { unit "m/s^2"; }

		enum def Severity {
			enum literal low;
			enum literal medium;
			enum literal high;
		}

		item def VitalSigns { attribute heartRate : HeartRateValue; }
		item def FallEvent { attribute location : ScalarValues::String; attribute severity : Severity; }
		item def VoiceCommand { attribute command : ScalarValues::String; }
		item def Alert { attribute severity : Severity; attribute message : ScalarValues::String; }
		item def MedicationDose { attribute name : ScalarValues::String; attribute amount : ScalarValues::String; }

		attribute def Reset;
		attribute def ManualOverride;
		attribute def AutoMode;
		attribute def UserConfirmation;

		port def VitalSignsPort { out vitalSigns : VitalSigns; }
		port def AlertPort { out alert : Alert; }
		port def FallEventPort { out fallEvent : FallEvent; }
		port def VoiceCommandPort { out voiceCommand : VoiceCommand; }
		port def EnvironmentControlPort { out tempSetpoint : TemperatureValue; out lightSetpoint : IlluminanceValue; }
		port def MedicationReminderPort { out reminder : ScalarValues::String; }
		port def DispenseCommandPort { out dispense : ScalarValues::Boolean; }

		action def DispensePills;
		action def CallEmergencyServices;
		action def NotifyCaregiver;
		action def IssueVoiceReminder;

		part def WearableHealthMonitor {
			port vitalSignsPort : VitalSignsPort;
			port alertPort : AlertPort;
			attribute heartRate : HeartRateValue;
			exhibit state 'monitoring states' {
				entry; then normal;
				state normal;
				accept when heartRate > 120 or heartRate < 40
					do send new Alert() to alertPort
					then alert;
				state alert;
				accept when heartRate >= 40 and heartRate <= 120
					then normal;
			}
		}

		part def FallDetectionSensor {
			port fallEventPort : FallEventPort;
			attribute acceleration : AccelerationValue;
			exhibit state 'detection states' {
				entry; then idle;
				state idle;
				accept when acceleration > 2.0
					do send new FallEvent() to fallEventPort
					then fallDetected;
				state fallDetected;
				accept Reset
					then idle;
			}
		}

		part def VoiceAssistant {
			port voiceCommandPort : VoiceCommandPort;
			port envControlPort : EnvironmentControlPort;
			port medReminderPort : MedicationReminderPort;
			port dispenseCommandPort : DispenseCommandPort;
		}

		part def EnvironmentController {
			port voiceCommandPort : ~VoiceCommandPort;
			port envControlPort : ~EnvironmentControlPort;
			exhibit state 'environment states' {
				entry; then auto;
				state auto;
				accept ManualOverride
					then manual;
				state manual;
				accept AutoMode
					then auto;
			}
		}

		part def EmergencyResponseUnit {
			port healthAlertPort : ~AlertPort;
			port fallAlertPort : ~FallEventPort;
			perform action callEmergency : CallEmergencyServices;
			perform action notifyCaregiver : NotifyCaregiver;
			exhibit state 'response states' {
				entry; then standby;
				state standby;
				accept a : Alert
					if a.severity == Severity::high
					do callEmergency
					then criticalResponse;
				accept a : Alert
					if a.severity == Severity::low or a.severity == Severity::medium
					do notifyCaregiver
					then nonCriticalResponse;
				accept f : FallEvent
					if f.severity == Severity::high
					do callEmergency
					then criticalResponse;
				state criticalResponse;
				accept Reset
					then standby;
				state nonCriticalResponse;
				accept Reset
					then standby;
			}
		}

		part def MedicationDispenser {
			port reminderPort : ~MedicationReminderPort;
			port dispensePort : ~DispenseCommandPort;
			attribute nextDoseTime : ScalarValues::Real;
			perform action issueReminder : IssueVoiceReminder;
			perform action dispensePills : DispensePills;
			exhibit state 'dispenser states' {
				entry; then idle;
				state idle;
				accept at nextDoseTime
					then reminding;
				state reminding {
					entry issueReminder;
				}
				accept UserConfirmation
					then dispensing;
				state dispensing {
					entry dispensePills;
				}
				transition dispensing then idle;
			}
		}

		part def SmartHomeSystem {
			part healthMonitor : WearableHealthMonitor;
			part fallSensor : FallDetectionSensor;
			part voiceAssistant : VoiceAssistant;
			part envController : EnvironmentController;
			part emergencyUnit : EmergencyResponseUnit;
			part medDispenser : MedicationDispenser;

			connect healthMonitor.alertPort to emergencyUnit.healthAlertPort;
			connect fallSensor.fallEventPort to emergencyUnit.fallAlertPort;
			connect voiceAssistant.voiceCommandPort to envController.voiceCommandPort;
			connect voiceAssistant.envControlPort to envController.envControlPort;
			connect voiceAssistant.medReminderPort to medDispenser.reminderPort;
			connect voiceAssistant.dispenseCommandPort to medDispenser.dispensePort;

			flow healthAlertFlow of Alert
				from healthMonitor.alertPort.alert to emergencyUnit.healthAlertPort.alert;
			flow fallAlertFlow of FallEvent
				from fallSensor.fallEventPort.fallEvent to emergencyUnit.fallAlertPort.fallEvent;
			flow voiceCommandFlow of VoiceCommand
				from voiceAssistant.voiceCommandPort.voiceCommand to envController.voiceCommandPort.voiceCommand;
			flow envControlTempFlow of TemperatureValue
				from voiceAssistant.envControlPort.tempSetpoint to envController.envControlPort.tempSetpoint;
			flow envControlLightFlow of IlluminanceValue
				from voiceAssistant.envControlPort.lightSetpoint to envController.envControlPort.lightSetpoint;
			flow medReminderFlow of ScalarValues::String
				from voiceAssistant.medReminderPort.reminder to medDispenser.reminderPort.reminder;
			flow dispenseCommandFlow of ScalarValues::Boolean
				from voiceAssistant.dispenseCommandPort.dispense to medDispenser.dispensePort.dispense;
		}

		requirement def HealthMonitoringReq {
			doc /* The system shall continuously monitor user vital signs and analyze for abnormalities. */
		}
		requirement def FallDetectionReq {
			doc /* The system shall detect sudden falls and determine user location. */
		}
		requirement def EmergencyResponseReq {
			doc /* The system shall automatically dispatch emergency services for severe alerts and notify caregivers for non-urgent events. */
		}
		requirement def MedicationComplianceReq {
			doc /* The system shall remind users of medication schedules and dispense only upon confirmation. */
		}
	}

	package Usages {
		private import Definitions::*;

		part smartHome : SmartHomeSystem {
			satisfy HealthMonitoringReq by healthMonitor;
			satisfy FallDetectionReq by fallSensor;
			satisfy EmergencyResponseReq by emergencyUnit;
			satisfy MedicationComplianceReq by medDispenser;
		}
	}
}
