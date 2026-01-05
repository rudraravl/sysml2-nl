package 'IoT Environmental Monitoring System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TemperatureReading :> ISQ::ThermodynamicTemperatureValue;
	attribute def HumidityLevel :> ScalarValues::Real;
	attribute def AirQualityIndex :> ScalarValues::Real;
	attribute def LightIntensity :> ISQ::LuminousIntensityValue;
	attribute def DeviceIdentifier :> ScalarValues::String;
	attribute def Timestamp :> ISQ::TimeValue;
	
	item def SensorDataPacket {
		attribute deviceId : DeviceIdentifier;
		attribute timestamp : Timestamp;
		attribute temperature : TemperatureReading;
		attribute humidity : HumidityLevel;
		attribute airQuality : AirQualityIndex;
		attribute lightLevel : LightIntensity;
	}
	
	item def ControlCommand {
		attribute targetDeviceId : DeviceIdentifier;
		attribute commandType : ScalarValues::String;
		attribute commandValue : ScalarValues::Real;
		attribute issuedAt : Timestamp;
	}
	
	item def AlertNotification {
		attribute severity : ScalarValues::String;
		attribute notificationMessage : ScalarValues::String;
		attribute sourceDeviceId : DeviceIdentifier;
		attribute triggeredAt : Timestamp;
	}
	
	item def AnalyticsReport {
		attribute reportId : ScalarValues::String;
		attribute generatedAt : Timestamp;
		attribute averageTemperature : TemperatureReading;
		attribute averageHumidity : HumidityLevel;
		attribute trendAnalysis : ScalarValues::String;
	}
	
	port def SensorDataPort {
		out sensorData : SensorDataPacket;
	}
	
	port def ActuatorControlPort {
		in controlCmd : ControlCommand;
	}
	
	port def GatewayUplink {
		in dataFromSensor : SensorDataPacket;
		out commandToActuator : ControlCommand;
	}
	
	port def CloudInterface {
		in uploadedData : SensorDataPacket;
		out downloadedCommand : ControlCommand;
		out alert : AlertNotification;
	}
	
	port def UserInterface {
		in displayData : SensorDataPacket;
		in notification : AlertNotification;
		in report : AnalyticsReport;
		out userCommand : ControlCommand;
	}
	
	part def TemperatureSensor {
		attribute sensorId : DeviceIdentifier;
		attribute currentTemperature : TemperatureReading;
		port dataOut : SensorDataPort;
		
		action measureTemperature {
			out reading : TemperatureReading;
		}
		
		action packageData {
			in temp : TemperatureReading;
			out packet : SensorDataPacket;
		}
	}
	
	part def HumiditySensor {
		attribute sensorId : DeviceIdentifier;
		attribute currentHumidity : HumidityLevel;
		port dataOut : SensorDataPort;
		
		action measureHumidity {
			out reading : HumidityLevel;
		}
	}
	
	part def AirQualitySensor {
		attribute sensorId : DeviceIdentifier;
		attribute currentAQI : AirQualityIndex;
		port dataOut : SensorDataPort;
		
		action measureAirQuality {
			out reading : AirQualityIndex;
		}
	}
	
	part def LightSensor {
		attribute sensorId : DeviceIdentifier;
		attribute currentLightLevel : LightIntensity;
		port dataOut : SensorDataPort;
		
		action measureLight {
			out reading : LightIntensity;
		}
	}
	
	part def HVACActuator {
		attribute actuatorId : DeviceIdentifier;
		attribute targetTemperature : TemperatureReading;
		attribute operatingMode : ScalarValues::String;
		port controlIn : ActuatorControlPort;
		
		action executeCommand {
			in cmd : ControlCommand;
		}
		
		state def OperationControlState {
			entry action enterState;
			do action maintainState;
			exit action exitState;
		}
		
		state machine operationControl {
			initial state initialState;
			
			state standby : OperationControlState {
				entry assign operatingMode := "standby";
			}
			
			state heating : OperationControlState {
				entry assign operatingMode := "heating";
			}
			
			state cooling : OperationControlState {
				entry assign operatingMode := "cooling";
			}
			
			state ventilating : OperationControlState {
				entry assign operatingMode := "ventilating";
			}
			
			transition initialState_to_standby
				first initialState
				then standby;
			
			transition standby_to_heating
				first standby
				then heating;
			
			transition standby_to_cooling
				first standby
				then cooling;
			
			transition standby_to_ventilating
				first standby
				then ventilating;
			
			transition heating_to_standby
				first heating
				then standby;
			
			transition cooling_to_standby
				first cooling
				then standby;
			
			transition ventilating_to_standby
				first ventilating
				then standby;
		}
	}
	
	part def VentilationActuator {
		attribute actuatorId : DeviceIdentifier;
		attribute fanSpeed : ScalarValues::Real;
		port controlIn : ActuatorControlPort;
		
		action adjustVentilation {
			in cmd : ControlCommand;
		}
	}
	
	part def IoTGateway {
		attribute gatewayId : DeviceIdentifier;
		port sensorLink : GatewayUplink[4];
		port actuatorLink : GatewayUplink[2];
		port cloudLink : CloudInterface;
		
		action aggregateSensorData {
			in sensorPackets : SensorDataPacket[*];
			out aggregatedData : SensorDataPacket;
		}
		
		action routeCommands {
			in cloudCommand : ControlCommand;
			out localCommand : ControlCommand;
		}
		
		action performEdgeProcessing {
			in rawData : SensorDataPacket;
			out processedData : SensorDataPacket;
			out localAlert : AlertNotification;
		}
	}
	
	part def CloudPlatform {
		attribute platformId : DeviceIdentifier;
		port gatewayInterface : CloudInterface;
		port applicationInterface : UserInterface;
		
		attribute historicalData : SensorDataPacket[*];
		attribute activeAlerts : AlertNotification[*];
		
		action storeData {
			in incomingData : SensorDataPacket;
		}
		
		action analyzeData {
			in dataSet : SensorDataPacket[*];
			out insights : AnalyticsReport;
		}
		
		action detectAnomalies {
			in currentData : SensorDataPacket;
			out anomalyDetected : ScalarValues::Boolean;
			out alert : AlertNotification;
		}
		
		action generateControlStrategy {
			in analytics : AnalyticsReport;
			in userPreferences : ControlCommand;
			out optimizedCommand : ControlCommand;
		}
		
		state machine dataProcessingPipeline {
			initial state initialState;
			
			state receiving {
				entry action receiveData;
			}
			
			state storing {
				entry action persistData;
			}
			
			state analyzing {
				entry action runAnalytics;
			}
			
			state responding {
				entry action issueCommands;
			}
			
			transition init_to_receiving
				first initialState
				then receiving;
			
			transition receiving_to_storing
				first receiving
				then storing;
			
			transition storing_to_analyzing
				first storing
				then analyzing;
			
			transition analyzing_to_responding
				first analyzing
				then responding;
			
			transition responding_to_receiving
				first responding
				then receiving;
		}
	}
	
	part def MobileApplication {
		attribute userId : DeviceIdentifier;
		port appInterface : UserInterface;
		
		action displayDashboard {
			in liveData : SensorDataPacket;
		}
		
		action showAlerts {
			in alerts : AlertNotification[*];
		}
		
		action sendUserCommand {
			out command : ControlCommand;
		}
		
		action viewReports {
			in report : AnalyticsReport;
		}
	}
	
	action def MonitorEnvironment {
		in tempReading : TemperatureReading;
		in humidityReading : HumidityLevel;
		in aqiReading : AirQualityIndex;
		in lightReading : LightIntensity;
		out environmentalStatus : ScalarValues::String;
	}
	
	action def OptimizeEnvironment {
		in currentStatus : ScalarValues::String;
		in targetConditions : SensorDataPacket;
		out controlActions : ControlCommand[*];
	}
	
	part def MonitoringZone {
		part tempSensor : TemperatureSensor;
		part humiditySensor : HumiditySensor;
		part aqSensor : AirQualitySensor;
		part lightSensor : LightSensor;
		part hvac : HVACActuator;
		part vent : VentilationActuator;
	}
	
	part def EnvironmentalMonitoringSystem {
		part zone1 : MonitoringZone;
		part zone2 : MonitoringZone;
		part gateway : IoTGateway;
		part cloudService : CloudPlatform;
		part mobileApp : MobileApplication;
	}
	
	part environmentalMonitoringSystem : EnvironmentalMonitoringSystem {
		part zone1 : MonitoringZone {
			part tempSensor1 : TemperatureSensor {
				attribute sensorId = "TEMP-Z1-001";
			}
			part humiditySensor1 : HumiditySensor {
				attribute sensorId = "HUM-Z1-001";
			}
			part aqSensor1 : AirQualitySensor {
				attribute sensorId = "AQ-Z1-001";
			}
			part lightSensor1 : LightSensor {
				attribute sensorId = "LIGHT-Z1-001";
			}
			part hvac1 : HVACActuator {
				attribute actuatorId = "HVAC-Z1-001";
			}
			part vent1 : VentilationActuator {
				attribute actuatorId = "VENT-Z1-001";
			}
		}
		
		part zone2 : MonitoringZone {
			part tempSensor2 : TemperatureSensor {
				attribute sensorId = "TEMP-Z2-001";
			}
			part humiditySensor2 : HumiditySensor {
				attribute sensorId = "HUM-Z2-001";
			}
			part aqSensor2 : AirQualitySensor {
				attribute sensorId = "AQ-Z2-001";
			}
			part lightSensor2 : LightSensor {
				attribute sensorId = "LIGHT-Z2-001";
			}
			part hvac2 : HVACActuator {
				attribute actuatorId = "HVAC-Z2-001";
			}
			part vent2 : VentilationActuator {
				attribute actuatorId = "VENT-Z2-001";
			}
		}
		
		part gateway : IoTGateway {
			attribute gatewayId = "GW-MAIN-001";
		}
		
		part cloudService : CloudPlatform {
			attribute platformId = "CLOUD-ENV-001";
		}
		
		part mobileApp : MobileApplication {
			attribute userId = "USER-001";
		}
		
		connect zone1.tempSensor1.dataOut to gateway.sensorLink[1];
		connect zone1.humiditySensor1.dataOut to gateway.sensorLink[1];
		connect zone1.aqSensor1.dataOut to gateway.sensorLink[1];
		connect zone1.lightSensor1.dataOut to gateway.sensorLink[1];
		
		connect zone2.tempSensor2.dataOut to gateway.sensorLink[2];
		connect zone2.humiditySensor2.dataOut to gateway.sensorLink[2];
		connect zone2.aqSensor2.dataOut to gateway.sensorLink[2];
		connect zone2.lightSensor2.dataOut to gateway.sensorLink[2];
		
		connect gateway.actuatorLink[1] to zone1.hvac1.controlIn;
		connect gateway.actuatorLink[1] to zone1.vent1.controlIn;
		connect gateway.actuatorLink[2] to zone2.hvac2.controlIn;
		connect gateway.actuatorLink[2] to zone2.vent2.controlIn;
		
		connect gateway.cloudLink to cloudService.gatewayInterface;
		connect cloudService.applicationInterface to mobileApp.appInterface;
		
		perform action autonomousMonitoringAndControl {
			first start;
			then merge monitoringCycle;
			
			action collectSensorData {
				action readZone1Sensors : MonitorEnvironment;
				action readZone2Sensors : MonitorEnvironment;
			}
			then monitoringCycle;
			
			then action transmitToGateway {
				in sensorData : SensorDataPacket[*];
			}
			
			then action gatewayProcessing {
				action edgeAnalysis;
				action forwardToCloud;
			}
			
			then action cloudProcessing {
				action storeHistoricalData;
				action performAnalytics;
				action detectAnomalies;
			}
			
			then decide;
				if cloudProcessing.detectAnomalies then generateAlert;
				if cloudProcessing.performAnalytics then optimizeControl;
				else continueMonitoring;
			
			action generateAlert {
				action createNotification;
				then action sendToUser;
			}
			then monitoringCycle;
			
			action optimizeControl : OptimizeEnvironment {
				out commands : ControlCommand[*];
			}
			then action distributeCommands {
				in commands : ControlCommand[*];
			}
			then action executeActuatorCommands;
			then monitoringCycle;
			
			action continueMonitoring;
			then monitoringCycle;
		}
	}
	
	requirement <'IoT-SYS-001'> primarySystemRequirement {
		doc /* The IoT Environmental Monitoring System shall continuously collect environmental data from distributed sensors across multiple zones, transmit this data through a gateway to a cloud platform for storage and analysis, and autonomously control HVAC and ventilation actuators to maintain optimal environmental conditions while providing real-time monitoring and alerting capabilities to users through a mobile application. */
		
		subject environmentalMonitoringSystem;
		
		require dataCollectionRequirement;
		require dataTransmissionRequirement;
		require cloudProcessingRequirement;
		require autonomousControlRequirement;
		require userInterfaceRequirement;
	}
	
	requirement <'IoT-SYS-002'> dataCollectionRequirement {
		doc /* The system shall collect temperature, humidity, air quality, and light level measurements from sensors in each monitoring zone at intervals not exceeding 30 seconds. */
	}
	
	requirement <'IoT-SYS-003'> dataTransmissionRequirement {
		doc /* The IoT gateway shall aggregate sensor data from all zones and transmit to the cloud platform with latency not exceeding 5 seconds under normal network conditions. */
	}
	
	requirement <'IoT-SYS-004'> cloudProcessingRequirement {
		doc /* The cloud platform shall store all incoming sensor data, perform real-time anomaly detection, generate analytics reports, and maintain historical data for trend analysis. */
	}
	
	requirement <'IoT-SYS-005'> autonomousControlRequirement {
		doc /* The system shall automatically generate and execute control commands to HVAC and ventilation actuators based on analyzed sensor data and optimization algorithms to maintain target environmental conditions. */
	}
	
	requirement <'IoT-SYS-006'> userInterfaceRequirement {
		doc /* The mobile application shall provide real-time visualization of environmental data, display alerts within 10 seconds of detection, allow manual control override, and present historical analytics reports. */
	}
	
	requirement <'IoT-SYS-007'> reliabilityRequirement {
		doc /* The system shall maintain 99.5% uptime for data collection and transmission, with automatic failover and recovery mechanisms for gateway and cloud platform components. */
	}
	
	requirement <'IoT-SYS-008'> scalabilityRequirement {
		doc /* The system architecture shall support expansion to at least 50 monitoring zones and 200 individual sensors without degradation of performance or increase in data transmission latency. */
	}
}
