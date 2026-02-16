package CustomMedicalDeviceSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def BatteryChargeLevel {
		attribute percentage : Real;
		attribute voltage : Real;
	}
	
	attribute def TherapyParameters {
		attribute intensity : Real;
		attribute duration : Real;
		attribute frequency : Real;
	}
	
	item def TherapySignal {
		attribute amplitude : Real;
		attribute waveform : String;
		attribute pulseWidth : Real;
	}
	
	item def PatientVitals {
		attribute heartRate : Real;
		attribute temperature : Real;
		attribute responseLevel : Real;
	}
	
	item def DeviceCommand {
		attribute commandType : String;
		attribute parameters : TherapyParameters;
	}
	
	item def StatusReport {
		attribute operationalState : String;
		attribute batteryLevel : BatteryChargeLevel;
		attribute errorCode : String;
	}
	
	port def PowerPort {
		in attribute voltage : Real;
		in attribute current : Real;
		out attribute powerAvailable : Boolean;
	}
	
	port def TherapyDeliveryPort {
		out item therapySignal : TherapySignal;
		in item patientResponse : PatientVitals;
	}
	
	port def ControlInterfacePort {
		in item command : DeviceCommand;
		out item status : StatusReport;
	}
	
	port def SensorPort {
		in item vitalSigns : PatientVitals;
		out attribute sensorActive : Boolean;
	}
	
	part def PowerManagementUnit {
		attribute batteryCapacity : Real;
		attribute currentCharge : BatteryChargeLevel;
		
		port powerOutput : PowerPort;
		
		event occurrence batteryDepleted;
		event occurrence batteryLow;
		event occurrence chargingComplete;
		
		exhibit state powerStates {
			entry; then operational;
			
			state operational {
				entry; then monitorCharge;
				
				action monitorCharge;
				then checkLevel;
				
				state checkLevel;
				accept batteryLow then lowPower;
				accept batteryDepleted then depleted;
			}
			
			state lowPower;
			accept chargingComplete then operational;
			
			state depleted;
			accept chargingComplete then operational;
		}
	}
	
	part def BiometricSensor {
		attribute sensorType : String;
		attribute calibrationStatus : Boolean;
		attribute measurementAccuracy : Real;
		
		port sensorInterface : SensorPort;
		
		action def AcquireVitals {
			in sensorReading : Real;
			out vitals : PatientVitals;
		}
		
		action def ValidateReading {
			in rawData : Real;
			out isValid : Boolean;
		}
	}
	
	part def TherapyGenerator {
		attribute maxIntensity : Real;
		attribute signalPrecision : Real;
		attribute safetyLimit : Real;
		
		port deliveryInterface : TherapyDeliveryPort;
		
		action def GenerateTherapySignal {
			in parameters : TherapyParameters;
			in patientData : PatientVitals;
			out signal : TherapySignal;
		}
		
		action def ModulateIntensity {
			in currentIntensity : Real;
			in feedback : PatientVitals;
			out adjustedIntensity : Real;
		}
		
		action def VerifyDelivery {
			in deliveredSignal : TherapySignal;
			out deliveryConfirmed : Boolean;
		}
	}
	
	part def ControlProcessor {
		attribute processorSpeed : Real;
		attribute memorySize : Real;
		attribute firmwareVersion : String;
		
		port controlPort : ControlInterfacePort;
		
		action def ProcessCommand {
			in command : DeviceCommand;
			out therapyParams : TherapyParameters;
		}
		
		action def MonitorSystemStatus {
			in batteryStatus : BatteryChargeLevel;
			in sensorStatus : Boolean;
			out systemStatus : StatusReport;
		}
		
		action def ExecuteSafetyCheck {
			in vitals : PatientVitals;
			in therapyParams : TherapyParameters;
			out safeToOperate : Boolean;
		}
		
		exhibit state controllerStates {
			entry; then standby;
			
			state standby;
			accept at controlPort.command then active;
			
			state active {
				entry; then processInput;
				
				action processInput : ProcessCommand;
				then performSafetyCheck;
				
				action performSafetyCheck : ExecuteSafetyCheck;
				then decide;
					if performSafetyCheck.safeToOperate then delivering;
					if not performSafetyCheck.safeToOperate then standby;
				
				state delivering;
				then monitorStatus;
				
				action monitorStatus : MonitorSystemStatus;
				then done;
			}
			then standby;
		}
	}
	
	part def SafetyInterlock {
		attribute temperatureLimit : Real;
		attribute currentLimit : Real;
		attribute emergencyShutdownEnabled : Boolean;
		
		event occurrence overTemperature;
		event occurrence overCurrent;
		event occurrence safetyViolation;
		event occurrence emergencyStop;
		
		action def MonitorSafetyParameters {
			in temperature : Real;
			in current : Real;
			out safetyStatus : Boolean;
		}
		
		exhibit state safetyStates {
			entry; then monitoring;
			
			state monitoring;
			accept overTemperature then alarm;
			accept overCurrent then alarm;
			accept safetyViolation then alarm;
			
			state alarm {
				entry; then initiateShutdown;
				
				action initiateShutdown;
				then done;
			}
			accept emergencyStop then shutdown;
			
			state shutdown;
		}
	}
	
	part customMedicalDevice {
		attribute deviceSerialNumber : String;
		attribute manufacturerName : String;
		attribute regulatoryApproval : String;
		attribute operatingMode : String;
		
		part powerSystem : PowerManagementUnit {
			:>> batteryCapacity = 3000.0;
			:>> currentCharge = {
				percentage = 100.0;
				voltage = 7.4;
			};
		}
		
		part vitalsSensor : BiometricSensor {
			:>> sensorType = "Multi-parameter";
			:>> calibrationStatus = true;
			:>> measurementAccuracy = 0.98;
		}
		
		part therapyModule : TherapyGenerator {
			:>> maxIntensity = 50.0;
			:>> signalPrecision = 0.99;
			:>> safetyLimit = 45.0;
		}
		
		part mainController : ControlProcessor {
			:>> processorSpeed = 1.8;
			:>> memorySize = 256.0;
			:>> firmwareVersion = "2.1.4";
		}
		
		part safetySystem : SafetyInterlock {
			:>> temperatureLimit = 42.0;
			:>> currentLimit = 2.5;
			:>> emergencyShutdownEnabled = true;
		}
		
		ref patient {
			attribute patientID : String;
			attribute treatmentProtocol : String;
			event occurrence therapyStarted;
			event occurrence therapyCompleted;
			event occurrence adverseEvent;
		}
		
		connection powerDistribution connect powerSystem.powerOutput to mainController.controlPort;
		connection sensorDataLink connect vitalsSensor.sensorInterface to mainController.controlPort;
		connection therapyDeliveryLink connect therapyModule.deliveryInterface to patient;
		connection safetyMonitoring connect safetySystem to mainController.controlPort;
		
		perform action deliverMedicalTherapy;
	}
	
	action def SensePatientCondition {
		in sensorData : Real;
		out patientVitals : PatientVitals;
	}
	
	action def AnalyzeCondition {
		in vitals : PatientVitals;
		in protocol : String;
		out therapyNeeded : Boolean;
		out recommendedParams : TherapyParameters;
	}
	
	action def DeliverTherapy {
		in therapyParams : TherapyParameters;
		in vitals : PatientVitals;
		out therapySignal : TherapySignal;
	}
	
	action def MonitorResponse {
		in deliveredTherapy : TherapySignal;
		in patientResponse : PatientVitals;
		out effectivenessScore : Real;
		out continueTherapy : Boolean;
	}
	
	action deliverMedicalTherapy {
		first start;
		then merge continuousMonitoring;
		
		action senseCondition : SensePatientCondition {
			in sensorData;
			out patientVitals;
		}
		then analyzeCondition;
		
		action analyzeCondition : AnalyzeCondition {
			in vitals = senseCondition.patientVitals;
			in protocol;
			out therapyNeeded;
			out recommendedParams;
		}
		then decide;
			if analyzeCondition.therapyNeeded then deliverTherapy;
			if not analyzeCondition.therapyNeeded then continuousMonitoring;
		
		action deliverTherapy : DeliverTherapy {
			in therapyParams = analyzeCondition.recommendedParams;
			in vitals = senseCondition.patientVitals;
			out therapySignal;
		}
		then monitorResponse;
		
		action monitorResponse : MonitorResponse {
			in deliveredTherapy = deliverTherapy.therapySignal;
			in patientResponse;
			out effectivenessScore;
			out continueTherapy;
		}
		then decide;
			if monitorResponse.continueTherapy then continuousMonitoring;
			if not monitorResponse.continueTherapy then done;
	}
	
	requirement def SafetyRequirement;
	requirement def PerformanceRequirement;
	requirement def ReliabilityRequirement;
	
	requirement <'REQ-001'> deviceSafetyRequirement : SafetyRequirement {
		doc /* The custom medical device shall operate within safe temperature and current limits 
		       and shall automatically shut down if safety parameters are exceeded. */
		
		subject device : customMedicalDevice;
		
		require constraint {
			device.safetySystem.emergencyShutdownEnabled == true and
			device.safetySystem.temperatureLimit <= 45.0 and
			device.safetySystem.currentLimit <= 3.0
		}
	}
	
	requirement <'REQ-002'> therapyAccuracyRequirement : PerformanceRequirement {
		doc /* The therapy generator shall deliver therapy signals with a precision of at least 95%. */
		
		subject therapyModule : TherapyGenerator;
		
		require constraint {
			therapyModule.signalPrecision >= 0.95
		}
	}
	
	requirement <'REQ-003'> sensorAccuracyRequirement : PerformanceRequirement {
		doc /* The biometric sensor shall measure patient vitals with an accuracy of at least 95%. */
		
		subject sensor : BiometricSensor;
		
		require constraint {
			sensor.measurementAccuracy >= 0.95 and
			sensor.calibrationStatus == true
		}
	}
	
	requirement <'REQ-004'> batteryLifeRequirement : ReliabilityRequirement {
		doc /* The power management unit shall provide continuous operation for at least 6 hours 
		       on a full charge. */
		
		subject power : PowerManagementUnit;
		
		require constraint {
			power.batteryCapacity >= 2500.0
		}
	}
	
	requirement <'REQ-005'> primaryFunctionRequirement {
		doc /* The custom medical device shall continuously monitor patient vital signs, 
		       analyze patient condition according to treatment protocol, deliver precise 
		       therapeutic interventions when needed, and monitor patient response to therapy 
		       while maintaining all safety constraints. */
		
		subject device : customMedicalDevice;
		
		assume constraint {
			device.vitalsSensor.calibrationStatus == true and
			device.powerSystem.currentCharge.percentage > 10.0 and
			device.safetySystem.emergencyShutdownEnabled == true
		}
		
		require deviceSafetyRequirement;
		require therapyAccuracyRequirement;
		require sensorAccuracyRequirement;
		require batteryLifeRequirement;
	}
}
