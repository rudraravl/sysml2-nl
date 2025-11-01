// Design a patient monitoring device that tracks vital signs and sends alerts.
package 'Patient Monitoring System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import KerML::Triggers::*;

	// Value Type Definitions for Medical Data
	value type HeartRate :> Real {
		in unit beatsPerMinute;
	}
	unit beatsPerMinute;

	value type BloodPressure :> Real {
		in unit mmHg;
	}
	unit mmHg;

	value type OxygenSaturation :> Percentage;

	// Item Definitions for Data Structures
	item def VitalSigns {
		attribute heartRate : HeartRate;
		attribute systolicPressure : BloodPressure;
		attribute diastolicPressure : BloodPressure;
		attribute spO2 : OxygenSaturation;
	}

	enum def AlertLevel {
		warning,
		critical
	}

	item def Alert {
		attribute level : AlertLevel;
		attribute message : String;
	}

	// Port Definitions for Component Interfaces
	port def SensorOutput {
		out item vitals : VitalSigns;
	}

	port def DataInput {
		in item vitals : VitalSigns;
	}

	port def AlertOutput {
		out item alert : Alert;
	}

	port def AlertInput {
		in item alert : Alert;
	}

	// Component Part Definitions
	abstract part def VitalSignSensor {
		port output : SensorOutput;
	}

	part def HeartRateSensor :> VitalSignSensor {
		attribute currentRate : HeartRate;
		flow of output.vitals {
			heartRate = currentRate;
		}
	}

	part def BloodPressureCuff :> VitalSignSensor {
		attribute currentSystolic : BloodPressure;
		attribute currentDiastolic : BloodPressure;
		flow of output.vitals {
			systolicPressure = currentSystolic;
			diastolicPressure = currentDiastolic;
		}
	}

	part def PulseOximeter :> VitalSignSensor {
		attribute currentSpO2 : OxygenSaturation;
		flow of output.vitals {
			spO2 = currentSpO2;
		}
	}

	part def DisplayUnit {
		port input : DataInput;
		action renderVitals {
			in data : VitalSigns from input;
			// Behavior to show data on a screen
		}
	}

	part def AlarmUnit {
		port trigger : AlertInput;
		state machine AudibleAlert {
			initial state Off;
			state Sounding;

			transition from Off to Sounding on receive trigger;
			transition from Sounding to Off when trigger.level == AlertLevel::warning and after(10[s]);
		}
	}

	part def ProcessingUnit {
		port sensorInput : DataInput;
		port displayOutput : SensorOutput;
		port alertOutput : AlertOutput;

		attribute currentVitals : VitalSigns;
		flow from sensorInput.vitals to currentVitals;
		flow from currentVitals to displayOutput.vitals;

		state machine MonitorAndAlert {
			initial state Monitoring;
			state Alerting;

			exhibit condition isHeartRateCritical : Boolean =
				currentVitals.heartRate < 50[beatsPerMinute] or
				currentVitals.heartRate > 130[beatsPerMinute];

			exhibit condition isSpo2Critical : Boolean =
				currentVitals.spO2 < 92[%];

			exhibit signal heartRateAlertSignal : ChangeSignal {
				signalCondition = isHeartRateCritical;
			}

			exhibit signal spo2AlertSignal : ChangeSignal {
				signalCondition = isSpo2Critical;
			}

			transition CriticalAlert from Monitoring to Alerting
				on receive heartRateAlertSignal or receive spo2AlertSignal;

			transition Stabilized from Alerting to Monitoring
				when not (isHeartRateCritical or isSpo2Critical);

			state Monitoring {
				// Normal operation
			}

			state Alerting {
				entry {
					send alertOutput {
						level = AlertLevel::critical;
						message = "Patient vitals are outside safe limits.";
					};
				}
			}
		}
	}

	// Top-Level System Assembly
	part def PatientMonitoringDevice {
		part hrSensor : HeartRateSensor;
		part bpCuff : BloodPressureCuff;
		part oximeter : PulseOximeter;
		part processor : ProcessingUnit;
		part display : DisplayUnit;
		part alarm : AlarmUnit;

		connect hrSensor.output to processor.sensorInput;
		connect bpCuff.output to processor.sensorInput;
		connect oximeter.output to processor.sensorInput;
		connect processor.displayOutput to display.input;
		connect processor.alertOutput to alarm.trigger;
	}

	// Requirements
	abstract requirement def VitalSignThresholdRequirement {
		subject device : PatientMonitoringDevice;
		doc "A vital sign must remain within its specified safe range.";
	}

	requirement <'R1'> HeartRateSafety : VitalSignThresholdRequirement {
		doc "The patient's heart rate must be monitored and kept within a safe range.";
		attribute lowerBound : HeartRate = 50[beatsPerMinute];
		attribute upperBound : HeartRate = 130[beatsPerMinute];
		require constraint {
			let hr = subject.processor.currentVitals.heartRate;
			hr >= lowerBound and hr <= upperBound
		}
	}

	requirement <'R2'> OxygenSaturationSafety : VitalSignThresholdRequirement {
		doc "The patient's blood oxygen saturation must not fall to critical levels.";
		attribute criticalThreshold : OxygenSaturation = 92[%];
		require constraint {
			subject.processor.currentVitals.spO2 >= criticalThreshold
		}
	}

	// Verification
	satisfy requirement HeartRateSafety by device.processor.MonitorAndAlert;
	satisfy requirement OxygenSaturationSafety by device.processor.MonitorAndAlert;
}
