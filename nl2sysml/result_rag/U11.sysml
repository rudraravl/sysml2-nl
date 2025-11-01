// Design a patient monitoring device that tracks vital signs and sends alerts.
package 'Patient Monitoring System' {
	private import SI::*;
	private import ScalarValues::*;
	
	// -------------------------------------------------
	// Value and Item Definitions
	// -------------------------------------------------
	
	unit beatsPerMinute;
	unit millimetersOfMercury;
	
	value type HeartRateValue : Real specializes ScalarValue {
		unit = beatsPerMinute;
	}
	
	value type BloodPressureValue : Real specializes ScalarValue {
		unit = millimetersOfMercury;
	}
	
	value type OxygenSaturationValue : Percentage specializes ScalarValue;
	
	item def VitalSignsData {
		attribute heartRate : HeartRateValue;
		attribute systolicPressure : BloodPressureValue;
		attribute diastolicPressure : BloodPressureValue;
		attribute spO2 : OxygenSaturationValue;
	}
	
	enum AlertLevel {
		advisory,
		caution,
		warning
	}
	
	item def AlertSignal {
		attribute level : AlertLevel;
		attribute message : String;
	}
	
	// -------------------------------------------------
	// Interface Definitions
	// -------------------------------------------------
	
	interface def VitalsInterface {
		flow dataOut : VitalSignsData;
	}
	
	interface def AlertInterface {
		flow alertIn : AlertSignal;
	}
	
	// -------------------------------------------------
	// Behavior Definitions
	// -------------------------------------------------
	
	action def MeasureVitals {
		out vitalSigns : VitalSignsData;
	}
	
	action def MonitorAndAlert {
		in currentVitals : VitalSignsData;
		out displayData : VitalSignsData;
		out localAlert : AlertSignal;
		out remoteAlert : AlertSignal;
		
		first;
		then accept currentVitals;
		then fork;
		
		// Path 1: Check Heart Rate
		then decide {
			if currentVitals.heartRate < 50[beatsPerMinute] or 
			   currentVitals.heartRate > 120[beatsPerMinute] then
				let hrMessage = "Heart Rate out of range: " + currentVitals.heartRate;
				triggerWarning(message := hrMessage);
			else continue;
		}
		
		// Path 2: Check SpO2
		then decide {
			if currentVitals.spO2 < 90[%] then
				let spO2Message = "SpO2 is low: " + currentVitals.spO2;
				triggerWarning(message := spO2Message);
			else continue;
		}
		
		// Path 3: Update Display
		then transfer from currentVitals to displayData;
		
		then join;
		then done;
		
		action triggerWarning(in message: String) {
			let warningSignal = AlertSignal {
				level = AlertLevel::warning;
				message = message;
			};
			then fork;
			then transfer from warningSignal to localAlert;
			then transfer from warningSignal to remoteAlert;
			then join;
		}
	}
	
	// -------------------------------------------------
	// Component Part Definitions
	// -------------------------------------------------
	
	part def SensorSuite {
		port vitalsOut : VitalsInterface;
		
		action measure : MeasureVitals {
			out vitalSigns to vitalsOut.dataOut;
		}
	}
	
	part def ProcessingUnit {
		port vitalsIn : ~VitalsInterface;
		port displayOut : VitalsInterface;
		port localAlerterOut : ~AlertInterface;
		port remoteAlerterOut : ~AlertInterface;
		
		action monitor : MonitorAndAlert {
			in currentVitals from vitalsIn.dataOut;
			out displayData to displayOut.dataOut;
			out localAlert to localAlerterOut.alertIn;
			out remoteAlert to remoteAlerterOut.alertIn;
		}
	}
	
	part def DisplayScreen {
		port dataIn : ~VitalsInterface;
	}
	
	part def AudibleAlerter {
		port alertIn : AlertInterface;
	}
	
	part def NetworkInterface {
		port alertIn : AlertInterface;
	}
	
	// -------------------------------------------------
	// Top-Level System Definition
	// -------------------------------------------------
	
	part def PatientMonitorDevice {
		part sensors : SensorSuite;
		part processor : ProcessingUnit;
		part display : DisplayScreen;
		part speaker : AudibleAlerter;
		part networkCard : NetworkInterface;
		
		port remoteAlerts : AlertInterface;
		
		connect sensors.vitalsOut to processor.vitalsIn;
		connect processor.displayOut to display.dataIn;
		connect processor.localAlerterOut to speaker.alertIn;
		connect processor.remoteAlerterOut to networkCard.alertIn;
		connect networkCard.alertIn to remoteAlerts;
	}
	
	// -------------------------------------------------
	// Requirements
	// -------------------------------------------------
	
	requirement def VitalSignAlertRequirement {
		subject dev : PatientMonitorDevice;
		shall;
	}
	
	requirement <'1.1'> heartRateAlert : VitalSignAlertRequirement {
		subject :>> dev;
		doc "The device shall generate a 'warning' level alert if the patient's heart rate falls outside the range of 50 to 120 beats per minute.";
		
		assume constraint {
			dev.sensors.vitalsOut.dataOut.heartRate < 50[beatsPerMinute] or
			dev.sensors.vitalsOut.dataOut.heartRate > 120[beatsPerMinute]
		}
		
		require constraint {
			dev.remoteAlerts.alertIn.level == AlertLevel::warning
		}
	}
	
	requirement <'1.2'> oxygenSaturationAlert : VitalSignAlertRequirement {
		subject :>> dev;
		doc "The device shall generate a 'warning' level alert if the patient's SpO2 level drops below 90%.";
		
		assume constraint {
			dev.sensors.vitalsOut.dataOut.spO2 < 90[%]
		}
		
		require constraint {
			dev.remoteAlerts.alertIn.level == AlertLevel::warning
		}
	}
}
