package 'Home Medical Equipment System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PatientID :> String;
	
	attribute def OxygenSaturationPercent :> Real;
	
	attribute def HeartRateBPM :> Real;
	
	attribute def RespiratoryRateBPM :> Real;
	
	attribute def TemperatureCelsius :> Real;
	
	enum def AlertSeverity {
		low;
		medium;
		high;
		critical;
	}
	
	item def VitalSignsData {
		attribute timestamp : String;
		attribute patientId : PatientID;
		attribute oxygenSaturation : OxygenSaturationPercent;
		attribute heartRate : HeartRateBPM;
		attribute respiratoryRate : RespiratoryRateBPM;
		attribute bodyTemperature : TemperatureCelsius;
	}
	
	item def OxygenSupply {
		attribute flowRate : Real;
		attribute concentration : OxygenSaturationPercent;
		attribute tankPressure : Real;
	}
	
	item def AlertNotification {
		attribute severity : AlertSeverity;
		attribute messageText : String;
		attribute timestamp : String;
	}
	
	item def TherapyCommand {
		attribute targetFlowRate : Real;
		attribute duration : Real;
	}
	
	port def VitalSignsOutputPort {
		out item vitals : VitalSignsData;
	}
	
	port def VitalSignsInputPort {
		in item vitals : VitalSignsData;
	}
	
	port def OxygenOutputPort {
		out item oxygen : OxygenSupply;
	}
	
	port def OxygenInputPort {
		in item oxygen : OxygenSupply;
	}
	
	port def AlertOutputPort {
		out item alert : AlertNotification;
	}
	
	port def TherapyControlPort {
		in item command : TherapyCommand;
	}
	
	part def BiometricSensor {
		out port vitalsOut : VitalSignsOutputPort;
		attribute sensorId : String;
		attribute calibrationDate : String;
		attribute measurementAccuracy : Real;
	}
	
	part def OxygenConcentrator {
		in port controlIn : TherapyControlPort;
		out port oxygenOut : OxygenOutputPort;
		attribute maxFlowRate : Real;
		attribute powerConsumption : Real;
		attribute operatingHours : Real;
		attribute filterStatus : String;
	}
	
	part def MonitoringDisplay {
		in port vitalsIn : VitalSignsInputPort;
		out port alertOut : AlertOutputPort;
		attribute screenSize : Real;
		attribute displayResolution : String;
		attribute brightnessLevel : Real;
	}
	
	part def CommunicationHub {
		in port dataIn : VitalSignsInputPort;
		in port alertIn : AlertOutputPort;
		attribute networkStatus : Boolean;
		attribute encryptionEnabled : Boolean;
		attribute lastTransmissionTime : String;
	}
	
	part def ControlProcessor {
		in port vitalsIn : VitalSignsInputPort;
		out port therapyOut : TherapyControlPort;
		out port alertOut : AlertOutputPort;
		attribute processorSpeed : Real;
		attribute memoryCapacity : String;
	}
	
	part def PowerManagement {
		attribute batteryLevel : Real;
		attribute acPowerConnected : Boolean;
		attribute backupDuration : Real;
		attribute chargingStatus : String;
	}
	
	action def MeasureVitalSigns {
		out oxygenSaturation : OxygenSaturationPercent;
		out heartRate : HeartRateBPM;
		out respiratoryRate : RespiratoryRateBPM;
		out temperature : TemperatureCelsius;
	}
	
	action def EvaluateVitalSigns {
		in oxygenSaturation : OxygenSaturationPercent;
		in heartRate : HeartRateBPM;
		in respiratoryRate : RespiratoryRateBPM;
		in temperature : TemperatureCelsius;
		out isNormal : Boolean;
		out severity : AlertSeverity;
	}
	
	action def GenerateAlert {
		in severity : AlertSeverity;
		out alert : AlertNotification;
	}
	
	action def CalculateOxygenTherapy {
		in currentSaturation : OxygenSaturationPercent;
		in targetSaturation : OxygenSaturationPercent;
		out therapyCommand : TherapyCommand;
	}
	
	action def DeliverOxygen {
		in command : TherapyCommand;
		out supply : OxygenSupply;
	}
	
	action def TransmitToProvider {
		in vitals : VitalSignsData;
		in alerts : AlertNotification[*];
		out transmissionSuccess : Boolean;
	}
	
	action def ContinuousPatientMonitoring {
		first start;
		then merge monitoringLoop;
		
		then action measureVitals : MeasureVitalSigns {
			out oxygenSaturation : OxygenSaturationPercent;
			out heartRate : HeartRateBPM;
			out respiratoryRate : RespiratoryRateBPM;
			out temperature : TemperatureCelsius;
		}
		
		then action evaluateVitals : EvaluateVitalSigns {
			in oxygenSaturation = measureVitals.oxygenSaturation;
			in heartRate = measureVitals.heartRate;
			in respiratoryRate = measureVitals.respiratoryRate;
			in temperature = measureVitals.temperature;
			out isNormal : Boolean;
			out severity : AlertSeverity;
		}
		
		then decide;
			if evaluateVitals.isNormal then recordNormalData;
			if not evaluateVitals.isNormal then handleAbnormalCondition;
		
		action recordNormalData;
		then monitoringLoop;
		
		action handleAbnormalCondition {
			action generateAlert : GenerateAlert {
				in severity = evaluateVitals.severity;
				out alert : AlertNotification;
			}
			then action calculateTherapy : CalculateOxygenTherapy {
				in currentSaturation = measureVitals.oxygenSaturation;
				in targetSaturation = 95.0;
				out therapyCommand : TherapyCommand;
			}
			then action deliverOxygen : DeliverOxygen {
				in command = calculateTherapy.therapyCommand;
				out supply : OxygenSupply;
			}
			then action transmitData : TransmitToProvider {
				in vitals;
				in alerts = generateAlert.alert;
				out transmissionSuccess : Boolean;
			}
		}
		then monitoringLoop;
	}
	
	part def RespiratoryTherapySystem {
		doc /* This home medical equipment system provides continuous respiratory monitoring
		     and automated oxygen therapy for patients with chronic respiratory conditions.
		     The system measures vital signs including oxygen saturation, heart rate, respiratory
		     rate, and body temperature. When abnormal conditions are detected, it automatically
		     adjusts oxygen delivery and alerts healthcare providers. */
		
		part sensor : BiometricSensor;
		part display : MonitoringDisplay;
		part concentrator : OxygenConcentrator;
		part processor : ControlProcessor;
		part commHub : CommunicationHub;
		part power : PowerManagement;
		
		connect sensor.vitalsOut to display.vitalsIn;
		connect sensor.vitalsOut to processor.vitalsIn;
		connect processor.therapyOut to concentrator.controlIn;
		connect processor.alertOut to display.alertOut;
		connect display.alertOut to commHub.alertIn;
		connect sensor.vitalsOut to commHub.dataIn;
	}
	
	part respiratorySystem : RespiratoryTherapySystem {
		perform action patientCare : ContinuousPatientMonitoring;
	}
	
	requirement def SafetyRequirement;
	requirement def PerformanceRequirement;
	requirement def ReliabilityRequirement;
	requirement def UsabilityRequirement;
	
	requirement <'REQ-001'> oxygenDeliveryPrecision : PerformanceRequirement {
		doc /* The oxygen concentrator shall deliver oxygen at the commanded flow rate
		     with an accuracy of +/- 0.5 liters per minute under all operating conditions. */
		
		subject system : RespiratoryTherapySystem;
		
		require constraint {
			system.concentrator.maxFlowRate >= 0.5
		}
	}
	
	requirement <'REQ-002'> continuousMonitoringFrequency : PerformanceRequirement {
		doc /* The biometric sensor shall measure and transmit patient vital signs
		     at least once every 30 seconds during active monitoring. */
		
		subject system : RespiratoryTherapySystem;
	}
	
	requirement <'REQ-003'> criticalAlertResponseTime : SafetyRequirement {
		doc /* The system shall detect critical vital sign deviations and generate
		     an alert within 10 seconds of measurement. */
		
		subject system : RespiratoryTherapySystem;
		
		attribute alertResponseTime : Real;
		
		require constraint {
			alertResponseTime <= 10.0
		}
	}
	
	requirement <'REQ-004'> batteryBackupCapacity : ReliabilityRequirement {
		doc /* The power management system shall provide at least 8 hours of continuous
		     operation on battery power in case of AC power failure. */
		
		subject system : RespiratoryTherapySystem;
		
		require constraint {
			system.power.backupDuration >= 8.0
		}
	}
	
	requirement <'REQ-005'> dataTransmissionSecurity : SafetyRequirement {
		doc /* All patient data transmitted to healthcare providers shall be encrypted
		     using industry-standard protocols to ensure privacy and security. */
		
		subject system : RespiratoryTherapySystem;
		
		require constraint {
			system.commHub.encryptionEnabled == true
		}
	}
	
	requirement <'REQ-006'> userInterfaceClarity : UsabilityRequirement {
		doc /* The monitoring display shall present vital signs and alerts in a clear,
		     easily readable format suitable for patients and caregivers. */
		
		subject system : RespiratoryTherapySystem;
	}
	
	requirement <'MISSION-001'> primarySystemMission {
		doc /* The respiratory therapy system shall continuously monitor patient vital signs,
		     automatically deliver supplemental oxygen therapy when oxygen saturation falls
		     below safe levels, generate timely alerts for abnormal conditions, and securely
		     transmit patient data to healthcare providers for remote monitoring. */
		
		subject system : RespiratoryTherapySystem;
		
		assume constraint patientConnected {
			doc /* A patient is properly connected to the biometric sensor. */
		}
		
		assume constraint powerAvailable {
			doc /* Either AC power or sufficient battery charge is available. */
			system.power.acPowerConnected or system.power.batteryLevel > 15.0
		}
		
		assume constraint networkConnectivity {
			doc /* Network connectivity is available for data transmission. */
			system.commHub.networkStatus == true
		}
		
		require oxygenDeliveryPrecision;
		require continuousMonitoringFrequency;
		require criticalAlertResponseTime;
		require batteryBackupCapacity;
		require dataTransmissionSecurity;
		require userInterfaceClarity;
	}
}
