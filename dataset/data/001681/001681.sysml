package 'SM4All Ambient Assisted Living System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	comment about sm4allInstance
	/* 
	SM4All (Smart hoMes for All) is an ambient assisted living system designed to support 
	independent living for elderly and disabled individuals. Its primary function is to 
	continuously monitor the home environment and occupant activities, detect potentially 
	hazardous situations or deviations from normal patterns, and automatically coordinate 
	appropriate responses through smart home devices and caregiver notifications.
	
	The system integrates environmental sensors, wearable devices, smart actuators, and 
	communication services to provide context-aware assistance, emergency response, and 
	adaptive comfort management while respecting user autonomy and privacy.
	*/
	
	attribute def UserID;
	attribute def DeviceID;
	attribute def EventType;
	attribute def AlertLevel;
	
	attribute def Temperature :> ISQ::ThermodynamicTemperatureValue;
	attribute def Humidity :> Real;
	attribute def LightIntensity :> ISQ::LuminousIntensityValue;
	attribute def MotionDetected :> Boolean;
	attribute def HeartRate :> ISQ::FrequencyValue;
	attribute def FallDetected :> Boolean;
	
	item def SensorReading {
		attribute timestamp : ISQ::DurationValue;
		attribute sensorID : DeviceID;
		attribute temperature : Temperature;
		attribute humidity : Humidity;
		attribute lightLevel : LightIntensity;
		attribute motionDetected : MotionDetected;
	}
	
	item def WearableData {
		attribute timestamp : ISQ::DurationValue;
		attribute userID : UserID;
		attribute heartRate : HeartRate;
		attribute fallDetected : FallDetected;
		attribute activityLevel : Real;
	}
	
	item def AlertNotification {
		attribute eventType : EventType;
		attribute severity : AlertLevel;
		attribute timestamp : ISQ::DurationValue;
		attribute location : String;
		attribute messageText : String;
	}
	
	item def ActuatorCommand {
		attribute deviceID : DeviceID;
		attribute commandType : String;
		attribute targetValue : Real;
	}
	
	port def EnvironmentalSensorPort {
		out sensorData : SensorReading;
	}
	
	port def WearableSensorPort {
		out wearableData : WearableData;
	}
	
	port def ActuatorControlPort {
		in command : ActuatorCommand;
		out status : String;
	}
	
	port def CommunicationPort {
		out alert : AlertNotification;
		in acknowledgment : String;
	}
	
	port def ContextProcessingPort {
		in environmentalData : SensorReading;
		in wearableData : WearableData;
		out contextState : String;
		out anomalyDetected : Boolean;
	}
	
	requirement def <'REQ-SM4-001'> ContinuousMonitoringRequirement {
		doc /* The system shall continuously monitor environmental conditions and user vital signs 24/7. */
		subject system : SM4AllSystem;
		require constraint {
			system.monitoringActive == true
		}
	}
	
	requirement def <'REQ-SM4-002'> EmergencyResponseRequirement {
		doc /* The system shall detect emergency situations and notify caregivers within 30 seconds. */
		subject system : SM4AllSystem;
		require constraint {
			system.responseTime <= 30.0 [SI::s]
		}
	}
	
	requirement def <'REQ-SM4-003'> AdaptiveComfortRequirement {
		doc /* The system shall automatically adjust environmental conditions based on user preferences and detected context. */
		subject system : SM4AllSystem;
		require constraint {
			system.adaptiveControlEnabled == true
		}
	}
	
	requirement def <'REQ-SM4-004'> PrivacyProtectionRequirement {
		doc /* The system shall process sensitive health data locally and encrypt all external communications. */
		subject system : SM4AllSystem;
	}
	
	action def SenseEnvironment {
		out temperature : Temperature;
		out humidity : Humidity;
		out lightLevel : LightIntensity;
		out motion : MotionDetected;
	}
	
	action def MonitorVitalSigns {
		in userID : UserID;
		out heartRate : HeartRate;
		out fallDetected : FallDetected;
		out activityLevel : Real;
	}
	
	action def AnalyzeContext {
		in sensorReadings : SensorReading[*];
		in vitalData : WearableData[*];
		in userProfile : String;
		out currentContext : String;
		out anomalyScore : Real;
		out emergencyDetected : Boolean;
	}
	
	action def DetectAnomalies {
		in contextState : String;
		in historicalPattern : String;
		in vitalSigns : WearableData;
		out anomalyDetected : Boolean;
		out anomalyType : EventType;
		out severityLevel : AlertLevel;
	}
	
	action def GenerateAlert {
		in anomalyType : EventType;
		in severity : AlertLevel;
		in location : String;
		out notification : AlertNotification;
	}
	
	action def NotifyCaregiver {
		in alert : AlertNotification;
		out deliveryStatus : String;
	}
	
	action def AdjustEnvironment {
		in targetTemperature : Temperature;
		in targetLighting : LightIntensity;
		in contextState : String;
		out hvacCommand : ActuatorCommand;
		out lightingCommand : ActuatorCommand;
	}
	
	action def ExecuteActuatorCommand {
		in command : ActuatorCommand;
		out executionStatus : String;
	}
	
	action def LogActivity {
		in eventData : String;
		in timestamp : ISQ::DurationValue;
		out logEntry : String;
	}
	
	action def SM4AllMainOperation {
		first start;
		then merge continuousMonitoring;
		
		then fork monitoringBranch;
			action environmentalMonitoring {
				action sense : SenseEnvironment {
					out temperature;
					out humidity;
					out lightLevel;
					out motion;
				}
			}
			action vitalSignsMonitoring {
				action monitor : MonitorVitalSigns {
					in userID;
					out heartRate;
					out fallDetected;
					out activityLevel;
				}
			}
		join then analyzeData;
		
		action analyzeData {
			action analyze : AnalyzeContext {
				in sensorReadings;
				in vitalData;
				in userProfile;
				out currentContext;
				out anomalyScore;
				out emergencyDetected;
			}
			
			flow analyze.currentContext to detectAnomalies.contextState;
			
			then action detectAnomalies : DetectAnomalies {
				in contextState;
				in historicalPattern;
				in vitalSigns;
				out anomalyDetected;
				out anomalyType;
				out severityLevel;
			}
		}
		
		then decide;
			if analyzeData.detectAnomalies.anomalyDetected == true then handleEmergency;
			if analyzeData.analyze.currentContext == "comfort_adjustment_needed" then adjustComfort;
			else continuousMonitoring;
		
		action handleEmergency {
			first action generateAlert : GenerateAlert {
				in anomalyType;
				in severity;
				in location;
				out notification;
			}
			
			flow generateAlert.notification to notifyCaregiver.alert;
			
			then action notifyCaregiver : NotifyCaregiver {
				in alert;
				out deliveryStatus;
			}
			
			then action logEmergency : LogActivity {
				in eventData;
				in timestamp;
				out logEntry;
			}
		}
		then continuousMonitoring;
		
		action adjustComfort {
			first action adjustEnvironment : AdjustEnvironment {
				in targetTemperature;
				in targetLighting;
				in contextState;
				out hvacCommand;
				out lightingCommand;
			}
			
			flow adjustEnvironment.hvacCommand to executeHVAC.command;
			flow adjustEnvironment.lightingCommand to executeLighting.command;
			
			then fork actuationBranch;
				action executeHVAC : ExecuteActuatorCommand {
					in command;
					out executionStatus;
				}
				action executeLighting : ExecuteActuatorCommand {
					in command;
					out executionStatus;
				}
			join;
		}
		then continuousMonitoring;
		
		then done;
	}
	
	state def SM4AllSystemState {
		entry; then initializing;
		
		state initializing {
			entry assign systemMode := "initialization";
		}
		then normalOperation;
		
		state normalOperation {
			entry assign systemMode := "normal";
			
			state monitoring {
				entry assign monitoringActive := true;
			}
			
			state analyzing;
			
			transition from monitoring to analyzing;
			
			if anomalyDetected then emergencyResponse;
			if comfortAdjustmentNeeded then adaptiveControl;
			else monitoring;
		}
		
		state emergencyResponse {
			entry assign systemMode := "emergency";
		}
		then normalOperation;
		
		state adaptiveControl {
			entry assign systemMode := "adapting";
		}
		then normalOperation;
		
		accept SystemShutdown;
		then shuttingDown;
		
		state shuttingDown {
			entry assign systemMode := "shutdown";
		}
		then final;
	}
	
	part def EnvironmentalSensor {
		attribute sensorID : DeviceID;
		port output : EnvironmentalSensorPort;
		perform action sense : SenseEnvironment;
	}
	
	part def WearableDevice {
		attribute deviceID : DeviceID;
		attribute assignedUser : UserID;
		port output : WearableSensorPort;
		perform action monitor : MonitorVitalSigns;
	}
	
	part def SmartActuator {
		attribute actuatorID : DeviceID;
		attribute actuatorType : String;
		port control : ActuatorControlPort;
		perform action execute : ExecuteActuatorCommand;
	}
	
	part def ContextProcessor {
		attribute processingMode : String;
		port dataInput : ContextProcessingPort;
		perform action analyze : AnalyzeContext;
		perform action detect : DetectAnomalies;
	}
	
	part def CommunicationGateway {
		attribute gatewayID : DeviceID;
		port external : CommunicationPort;
		perform action notify : NotifyCaregiver;
	}
	
	part def SM4AllSystem {
		attribute systemMode : String;
		attribute monitoringActive : Boolean;
		attribute adaptiveControlEnabled : Boolean;
		attribute responseTime : ISQ::DurationValue;
		
		part environmentalSensors : EnvironmentalSensor[5] {
			port :>> output;
		}
		
		part wearableDevices : WearableDevice[2] {
			port :>> output;
		}
		
		part hvacSystem : SmartActuator {
			attribute :>> actuatorType = "HVAC";
			port :>> control;
		}
		
		part lightingSystem : SmartActuator {
			attribute :>> actuatorType = "Lighting";
			port :>> control;
		}
		
		part windowBlinds : SmartActuator {
			attribute :>> actuatorType = "Blinds";
			port :>> control;
		}
		
		part contextProcessor : ContextProcessor {
			port :>> dataInput;
		}
		
		part communicationGateway : CommunicationGateway {
			port :>> external;
		}
		
		part dataLogger {
			perform action log : LogActivity;
		}
		
		connection sensorToProcessor connect 
			environmentalSensors.output to contextProcessor.dataInput;
		
		connection wearableToProcessor connect 
			wearableDevices.output to contextProcessor.dataInput;
		
		connection processorToHVAC connect 
			contextProcessor to hvacSystem.control;
		
		connection processorToLighting connect 
			contextProcessor to lightingSystem.control;
		
		connection processorToBlinds connect 
			contextProcessor to windowBlinds.control;
		
		connection processorToGateway connect 
			contextProcessor to communicationGateway.external;
		
		perform action mainOperation : SM4AllMainOperation;
		
		exhibit state systemBehavior : SM4AllSystemState;
	}
	
	part sm4allInstance : SM4AllSystem {
		attribute :>> systemMode = "initializing";
		attribute :>> monitoringActive = false;
		attribute :>> adaptiveControlEnabled = true;
		attribute :>> responseTime = 25.0 [SI::s];
		
		satisfy <'REQ-SM4-001'> ContinuousMonitoringRequirement;
		satisfy <'REQ-SM4-002'> EmergencyResponseRequirement;
		satisfy <'REQ-SM4-003'> AdaptiveComfortRequirement;
		satisfy <'REQ-SM4-004'> PrivacyProtectionRequirement;
	}
}
