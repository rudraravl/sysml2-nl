package 'OCF Smart Building System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def DeviceUUID;
	attribute def ResourcePath;
	attribute def OCFMethodType;
	
	enum def DeviceState { uninitialized; discovered; provisioned; operational; offline; }
	enum def SecurityMode { none; presharedKey; certificate; }
	enum def OCFMethod { GET; POST; PUT; DELETE; OBSERVE; }
	
	attribute def TemperatureMeasurement {
		attribute value : TemperatureValue;
		attribute timestamp : Real;
		attribute accuracy : TemperatureValue;
	}
	
	attribute def OccupancyStatus {
		attribute occupied : Boolean;
		attribute count : Integer;
		attribute timestamp : Real;
	}
	
	attribute def LightingState {
		attribute powerOn : Boolean;
		attribute brightness : Real;
		attribute colorTemperature : Real;
	}
	
	attribute def HVACCommand {
		attribute mode : String;
		attribute setpoint : TemperatureValue;
		attribute fanSpeed : Integer;
	}
	
	item def OCFMessage {
		attribute method : OCFMethod;
		attribute resourcePath : ResourcePath;
		attribute payload : String;
		attribute messageId : String;
		attribute securityToken : String;
	}
	
	item def OCFResponse {
		attribute statusCode : Integer;
		attribute payload : String;
		attribute messageId : String;
	}
	
	port def OCFDevicePort {
		in request : OCFMessage;
		out response : OCFResponse;
		out notification : OCFMessage;
	}
	
	port def OCFClientPort {
		out request : OCFMessage;
		in response : OCFResponse;
		in notification : OCFMessage;
	}
	
	port def SensorOutputPort {
		out measurement : TemperatureMeasurement;
		out occupancy : OccupancyStatus;
	}
	
	port def ActuatorInputPort {
		in lightingCommand : LightingState;
		in hvacCommand : HVACCommand;
	}
	
	action def DiscoverOCFDevices {
		in multicastAddress : String;
		in discoveryTimeout : TimeValue;
		out discoveredDevices : DeviceUUID[*];
		out deviceResources : ResourcePath[*];
	}
	
	action def ProvisionDevice {
		in deviceId : DeviceUUID;
		in securityMode : SecurityMode;
		in credentials : String;
		out provisioningSuccess : Boolean;
		out securityToken : String;
	}
	
	action def ReadOCFResource {
		in resourcePath : ResourcePath;
		in securityToken : String;
		out resourceData : String;
		out readSuccess : Boolean;
	}
	
	action def UpdateOCFResource {
		in resourcePath : ResourcePath;
		in securityToken : String;
		in newValue : String;
		out updateSuccess : Boolean;
	}
	
	action def ObserveOCFResource {
		in resourcePath : ResourcePath;
		in securityToken : String;
		in observationPeriod : TimeValue;
		out observationId : String;
	}
	
	action def AggregateEnvironmentalData {
		in temperature : TemperatureMeasurement;
		in occupancy : OccupancyStatus;
		out comfortIndex : Real;
		out energyOptimizationRecommendation : String;
	}
	
	part def OCFTemperatureSensor {
		attribute deviceId : DeviceUUID;
		attribute deviceName : String;
		attribute currentState : DeviceState;
		attribute currentTemperature : TemperatureValue;
		attribute samplingRate : FrequencyValue;
		
		port ocfPort : OCFDevicePort;
		port sensorPort : SensorOutputPort;
		
		state sensorLifecycle {
			entry; then uninitialized;
			
			state uninitialized;
			state discovered;
			state provisioned;
			state active {
				entry; then startSampling;
				action startSampling;
				then sampleTemperature;
				action sampleTemperature;
				then startSampling;
			}
			state fault;
			
			transition uninitialized_to_discovered
				first uninitialized
				accept discoveryRequest : OCFMessage via ocfPort.request
				then discovered;
			
			transition discovered_to_provisioned
				first discovered
				accept provisionRequest : OCFMessage via ocfPort.request
				then provisioned;
			
			transition provisioned_to_active
				first provisioned
				accept activateCommand : OCFMessage via ocfPort.request
				then active;
			
			transition active_to_fault
				first active
				if sensorFailure
				then fault;
			
			transition fault_to_active
				first fault
				if faultCleared
				then active;
		}
		
		action respondToRequest {
			in req : OCFMessage;
			out resp : OCFResponse;
		}
	}
	
	part def OCFOccupancySensor {
		attribute deviceId : DeviceUUID;
		attribute deviceName : String;
		attribute currentState : DeviceState;
		attribute detectionRange : LengthValue;
		attribute sensitivity : Real;
		
		port ocfPort : OCFDevicePort;
		port sensorPort : SensorOutputPort;
		
		action detectOccupancy {
			out status : OccupancyStatus;
		}
		
		action publishOccupancyChange {
			in status : OccupancyStatus;
			out notification : OCFMessage;
		}
	}
	
	part def OCFSmartLight {
		attribute deviceId : DeviceUUID;
		attribute deviceName : String;
		attribute currentState : DeviceState;
		attribute maxBrightness : Real;
		attribute minColorTemp : Real;
		attribute maxColorTemp : Real;
		attribute powerConsumption : PowerValue;
		
		port ocfPort : OCFDevicePort;
		port actuatorPort : ActuatorInputPort;
		
		state lightControl {
			entry; then off;
			
			state off;
			state on {
				entry; then dimming;
				state dimming;
				state fullBrightness;
				
				transition dimming_to_full
					first dimming
					if brightnessIncreased
					then fullBrightness;
				
				transition full_to_dimming
					first fullBrightness
					if brightnessReduced
					then dimming;
			}
			
			transition off_to_on
				first off
				accept powerCommand : LightingState via actuatorPort.lightingCommand
				if powerCommand.powerOn == true
				then on;
			
			transition on_to_off
				first on
				accept powerCommand : LightingState via actuatorPort.lightingCommand
				if powerCommand.powerOn == false
				then off;
		}
		
		action adjustBrightness {
			in targetBrightness : Real;
			out success : Boolean;
		}
		
		action setColorTemperature {
			in targetTemp : Real;
			out success : Boolean;
		}
	}
	
	part def OCFThermostat {
		attribute deviceId : DeviceUUID;
		attribute deviceName : String;
		attribute currentState : DeviceState;
		attribute currentSetpoint : TemperatureValue;
		attribute operatingMode : String;
		attribute minSetpoint : TemperatureValue;
		attribute maxSetpoint : TemperatureValue;
		
		port ocfPort : OCFDevicePort;
		port actuatorPort : ActuatorInputPort;
		
		action setTemperature {
			in newSetpoint : TemperatureValue;
			out success : Boolean;
		}
		
		action changeMode {
			in mode : String;
			out success : Boolean;
		}
		
		action regulateTemperature {
			in currentTemp : TemperatureValue;
			in targetTemp : TemperatureValue;
			out hvacAction : String;
		}
	}
	
	part def OCFBuildingGateway {
		attribute gatewayId : DeviceUUID;
		attribute networkAddress : String;
		attribute connectedDeviceCount : Integer;
		attribute securityEnabled : Boolean;
		attribute maxDevices : Integer;
		
		port clientPort : OCFClientPort[*];
		port serverPort : OCFDevicePort;
		
		part discoveryService {
			action discover : DiscoverOCFDevices;
			
			action maintainDeviceRegistry {
				in devices : DeviceUUID[*];
				out activeDevices : DeviceUUID[*];
			}
		}
		
		part securityService {
			action provision : ProvisionDevice;
			
			action validateToken {
				in token : String;
				out valid : Boolean;
			}
			
			action renewToken {
				in deviceId : DeviceUUID;
				out newToken : String;
			}
		}
		
		part resourceManager {
			action read : ReadOCFResource;
			action update : UpdateOCFResource;
			action observe : ObserveOCFResource;
			
			action routeRequest {
				in request : OCFMessage;
				out targetDevice : DeviceUUID;
			}
		}
		
		part automationEngine {
			action evaluateRules {
				in sensorData : String[*];
				out actions : String[*];
			}
			
			action executeAutomation {
				in trigger : String;
				out commands : OCFMessage[*];
			}
		}
	}
	
	part def OCFCloudBridge {
		attribute bridgeId : DeviceUUID;
		attribute cloudEndpoint : String;
		attribute connectionStatus : Boolean;
		
		port localPort : OCFClientPort;
		port cloudPort : OCFDevicePort;
		
		action synchronizeData {
			in localData : String;
			out cloudData : String;
			out syncSuccess : Boolean;
		}
		
		action forwardCommand {
			in cloudCommand : OCFMessage;
			out localCommand : OCFMessage;
		}
		
		action aggregateAnalytics {
			in deviceData : String[*];
			in timeWindow : TimeValue;
			out analyticsReport : String;
		}
	}
	
	part ocfSmartBuildingSystem {
		doc /*
		This system implements the Open Connectivity Foundation (OCF) standard
		to create an intelligent building automation platform. Its primary function
		is to enable seamless interoperability and coordinated control of diverse
		IoT devices from multiple manufacturers within a commercial building environment.
		
		The system provides unified device discovery, secure provisioning, real-time
		monitoring, and automated control of environmental systems including HVAC,
		lighting, and occupancy sensing. By leveraging OCF's standardized resource
		models and RESTful communication patterns, the system allows heterogeneous
		devices to communicate through a common protocol, enabling sophisticated
		automation scenarios that optimize energy efficiency and occupant comfort.
		
		The gateway serves as the central coordination point, discovering OCF-compliant
		devices on the local network, managing their security credentials, and
		orchestrating data flows between sensors and actuators. Environmental data
		from temperature and occupancy sensors is continuously collected and analyzed
		to make intelligent decisions about lighting and HVAC control, reducing
		energy consumption while maintaining optimal conditions.
		*/
		
		part gateway : OCFBuildingGateway {
			attribute gatewayId = "GW-BUILDING-001";
			attribute networkAddress = "192.168.1.100";
			attribute securityEnabled = true;
			attribute maxDevices = 100;
		}
		
		part tempSensor1 : OCFTemperatureSensor {
			attribute deviceId = "TEMP-ZONE-A-001";
			attribute deviceName = "Conference Room A Temperature";
			attribute currentState = DeviceState::operational;
			attribute samplingRate = 0.1 [SI::Hz];
		}
		
		part tempSensor2 : OCFTemperatureSensor {
			attribute deviceId = "TEMP-ZONE-B-001";
			attribute deviceName = "Office Area B Temperature";
			attribute currentState = DeviceState::operational;
			attribute samplingRate = 0.1 [SI::Hz];
		}
		
		part occupancySensor1 : OCFOccupancySensor {
			attribute deviceId = "OCC-ZONE-A-001";
			attribute deviceName = "Conference Room A Occupancy";
			attribute currentState = DeviceState::operational;
			attribute detectionRange = 8.0 [SI::m];
			attribute sensitivity = 0.85;
		}
		
		part occupancySensor2 : OCFOccupancySensor {
			attribute deviceId = "OCC-ZONE-B-001";
			attribute deviceName = "Office Area B Occupancy";
			attribute currentState = DeviceState::operational;
			attribute detectionRange = 12.0 [SI::m];
			attribute sensitivity = 0.80;
		}
		
		part smartLight1 : OCFSmartLight {
			attribute deviceId = "LIGHT-ZONE-A-001";
			attribute deviceName = "Conference Room A Lighting";
			attribute currentState = DeviceState::operational;
			attribute maxBrightness = 100.0;
			attribute minColorTemp = 2700.0;
			attribute maxColorTemp = 6500.0;
			attribute powerConsumption = 45.0 [SI::W];
		}
		
		part smartLight2 : OCFSmartLight {
			attribute deviceId = "LIGHT-ZONE-B-001";
			attribute deviceName = "Office Area B Lighting";
			attribute currentState = DeviceState::operational;
			attribute maxBrightness = 100.0;
			attribute minColorTemp = 2700.0;
			attribute maxColorTemp = 6500.0;
			attribute powerConsumption = 60.0 [SI::W];
		}
		
		part thermostat1 : OCFThermostat {
			attribute deviceId = "HVAC-ZONE-A-001";
			attribute deviceName = "Conference Room A Climate";
			attribute currentState = DeviceState::operational;
			attribute currentSetpoint = 295.15 [SI::K];
			attribute operatingMode = "auto";
			attribute minSetpoint = 291.15 [SI::K];
			attribute maxSetpoint = 299.15 [SI::K];
		}
		
		part thermostat2 : OCFThermostat {
			attribute deviceId = "HVAC-ZONE-B-001";
			attribute deviceName = "Office Area B Climate";
			attribute currentState = DeviceState::operational;
			attribute currentSetpoint = 294.65 [SI::K];
			attribute operatingMode = "auto";
			attribute minSetpoint = 291.15 [SI::K];
			attribute maxSetpoint = 299.15 [SI::K];
		}
		
		part cloudBridge : OCFCloudBridge {
			attribute bridgeId = "BRIDGE-CLOUD-001";
			attribute cloudEndpoint = "https://ocf-analytics.building.com";
			attribute connectionStatus = true;
		}
		
		connection tempSensor1ToGateway connect 
			tempSensor1.ocfPort to gateway.serverPort;
		
		connection tempSensor2ToGateway connect 
			tempSensor2.ocfPort to gateway.serverPort;
		
		connection occupancySensor1ToGateway connect 
			occupancySensor1.ocfPort to gateway.serverPort;
		
		connection occupancySensor2ToGateway connect 
			occupancySensor2.ocfPort to gateway.serverPort;
		
		connection smartLight1ToGateway connect 
			smartLight1.ocfPort to gateway.serverPort;
		
		connection smartLight2ToGateway connect 
			smartLight2.ocfPort to gateway.serverPort;
		
		connection thermostat1ToGateway connect 
			thermostat1.ocfPort to gateway.serverPort;
		
		connection thermostat2ToGateway connect 
			thermostat2.ocfPort to gateway.serverPort;
		
		connection gatewayToCloud connect 
			gateway.clientPort to cloudBridge.localPort;
		
		action buildingAutomationOperation {
			first start;
			
			then action initializeGateway {
				action powerUp;
				then action enableSecurity {
					perform gateway.securityService.provision;
				}
			}
			
			then action discoverAllDevices : DiscoverOCFDevices {
				in multicastAddress = "224.0.1.187";
				in discoveryTimeout = 30.0 [SI::s];
				out discoveredDevices;
				out deviceResources;
			}
			
			then action provisionDevices {
				for device in discoverAllDevices.discoveredDevices {
					action provisionSingle : ProvisionDevice {
						in deviceId = device;
						in securityMode = SecurityMode::certificate;
						in credentials;
						out provisioningSuccess;
						out securityToken;
					}
				}
			}
			
			then merge operationalLoop;
			
			then action operationalCycle {
				action collectEnvironmentalData {
					action readTemperatureZoneA : ReadOCFResource {
						in resourcePath = "/oic/r/temperature";
						in securityToken;
						out resourceData;
						out readSuccess;
					}
					
					action readOccupancyZoneA : ReadOCFResource {
						in resourcePath = "/oic/r/sensor.occupancy";
						in securityToken;
						out resourceData;
						out readSuccess;
					}
					
					action readTemperatureZoneB : ReadOCFResource {
						in resourcePath = "/oic/r/temperature";
						in securityToken;
						out resourceData;
						out readSuccess;
					}
					
					action readOccupancyZoneB : ReadOCFResource {
						in resourcePath = "/oic/r/sensor.occupancy";
						in securityToken;
						out resourceData;
						out readSuccess;
					}
				}
				
				then action analyzeData : AggregateEnvironmentalData {
					in temperature;
					in occupancy;
					out comfortIndex;
					out energyOptimizationRecommendation;
				}
				
				then decide;
					if analyzeData.comfortIndex < 0.6 then adjustEnvironment;
					if analyzeData.comfortIndex >= 0.6 then maintainCurrent;
				
				action adjustEnvironment {
					action updateLighting : UpdateOCFResource {
						in resourcePath = "/oic/r/light.dimming";
						in securityToken;
						in newValue;
						out updateSuccess;
					}
					
					then action updateHVAC : UpdateOCFResource {
						in resourcePath = "/oic/r/temperature";
						in securityToken;
						in newValue;
						out updateSuccess;
					}
				}
				
				action maintainCurrent;
				
				then action syncToCloud {
					perform cloudBridge.synchronizeData;
				}
			}
			
			then operationalLoop;
		}
	}
	
	requirement def OCFStandardCompliance {
		doc /*
		All devices and the gateway shall comply with OCF Core Framework
		specification version 2.0 or higher, including support for standard
		resource types, discovery mechanisms, and security protocols.
		*/
		
		subject system : OCFBuildingGateway;
		
		require constraint {
			system.securityEnabled == true
		}
	}
	
	requirement def DeviceInteroperability {
		doc /*
		The system shall support seamless interoperability between OCF-compliant
		devices from different manufacturers without requiring custom integration code.
		*/
		
		subject gateway : OCFBuildingGateway;
		
		require constraint {
			gateway.connectedDeviceCount >= 1
		}
	}
	
	requirement def SecureProvisioning {
		doc /*
		All devices shall be securely provisioned using OCF-specified onboarding
		mechanisms with certificate-based authentication before operational use.
		*/
		
		subject device : OCFTemperatureSensor;
		
		require constraint {
			device.currentState == DeviceState::provisioned or
			device.currentState == DeviceState::operational
		}
	}
	
	requirement def RealTimeMonitoring {
		doc /*
		The system shall collect and process environmental sensor data with
		a maximum latency of 5 seconds from measurement to decision.
		*/
	}
	
	requirement def EnergyOptimization {
		doc /*
		The system shall reduce building energy consumption by at least 20%
		compared to manual control through intelligent automation based on
		occupancy and environmental conditions.
		*/
	}
	
	requirement def CloudConnectivity {
		doc /*
		The system shall maintain persistent connection to cloud analytics
		platform with 99.5% uptime for data synchronization and remote management.
		*/
		
		subject bridge : OCFCloudBridge;
		
		require constraint {
			bridge.connectionStatus == true
		}
	}
	
	requirement ocfBuildingSystemRequirements {
		doc /*
		Top-level requirements for OCF-based smart building automation system
		ensuring standards compliance, security, and operational effectiveness.
		*/
		
		require OCFStandardCompliance;
		require DeviceInteroperability;
		require SecureProvisioning;
		require RealTimeMonitoring;
		require EnergyOptimization;
		require CloudConnectivity;
		
		requirement scalabilityRequirement {
			doc /*
			The gateway shall support at least 100 simultaneously connected
			OCF devices with response time under 500ms per request.
			*/
			
			subject gateway : OCFBuildingGateway;
			
			require constraint {
				gateway.maxDevices >= 100
			}
		}
		
		requirement automationRequirement {
			doc /*
			The system shall execute automated control actions based on
			sensor inputs and predefined rules without manual intervention.
			*/
			
			satisfy by ocfSmartBuildingSystem.buildingAutomationOperation;
		}
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'OCF Smart Building System'::*;

    part testSubject = ocfSmartBuildingSystem {
    :>> deviceId = testDeviceId;
    // TODO(human): unsupported input type for securityMode: SecurityMode (type is not a primitive, enum, extracted payload def, or known value type)
    :>> credentials = "";
    }

    action orchestrator {
        attribute testDeviceId : DeviceUUID;
    }
}
