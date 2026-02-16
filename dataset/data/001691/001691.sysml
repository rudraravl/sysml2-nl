package AllSeenAllianceIoTSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def DeviceIdentifier;
	attribute def ServicePath;
	attribute def InterfaceName;
	attribute def SessionIdentifier;
	attribute def SecurityToken;
	
	enum def DeviceStatus {
		offline;
		discovering;
		announced;
		connected;
		authenticated;
	}
	
	enum def TransportType {
		wifi;
		bluetooth;
		ethernet;
		zigbee;
	}
	
	attribute def SignalStrength :> Real {
		attribute :>> num : Real;
	}
	
	attribute def DataThroughput :> Real {
		attribute :>> num : Real;
	}
	
	item def AllJoynMessage {
		attribute messageID : String;
		attribute sender : DeviceIdentifier;
		attribute receiver : DeviceIdentifier;
		attribute payload : String;
		attribute timestamp : TimeValue;
		attribute messageSize : LengthValue;
	}
	
	item def ServiceDescriptor {
		attribute serviceName : String;
		attribute interfaceName : InterfaceName;
		attribute servicePath : ServicePath;
		attribute version : Real;
		attribute supportedTransports : TransportType[1..*];
	}
	
	item def SessionCredentials {
		attribute token : SecurityToken;
		attribute encryptionLevel : String;
		attribute expirationTime : TimeValue;
	}
	
	port def AllJoynBusPort {
		out item serviceAnnouncements : ServiceDescriptor[*];
		in item serviceRequests : AllJoynMessage[*];
		out item serviceResponses : AllJoynMessage[*];
		in item sessionRequests : SessionIdentifier[*];
		out item sessionGrants : SessionIdentifier[*];
	}
	
	port def PhysicalTransportPort {
		attribute transportType : TransportType;
		attribute signalStrength : SignalStrength;
		attribute throughput : DataThroughput;
		in item incomingData : AllJoynMessage[*];
		out item outgoingData : AllJoynMessage[*];
	}
	
	part def AllJoynDaemon {
		attribute daemonVersion : String;
		attribute maxConcurrentSessions : Integer;
		attribute routingTableSize : Integer;
		
		port busInterface : AllJoynBusPort;
		port wifiTransport : PhysicalTransportPort;
		port bluetoothTransport : PhysicalTransportPort;
		port ethernetTransport : PhysicalTransportPort;
		
		attribute activeDevices : DeviceIdentifier[*];
		attribute activeSessions : SessionIdentifier[*];
		
		action routeTraffic {
			in message : AllJoynMessage;
			out routedMessage : AllJoynMessage;
		}
		
		action manageDiscovery {
			out announcements : ServiceDescriptor[*];
		}
		
		action establishSession {
			in requester : DeviceIdentifier;
			in provider : DeviceIdentifier;
			out sessionID : SessionIdentifier;
			out success : Boolean;
		}
	}
	
	part def AllJoynDevice {
		attribute deviceID : DeviceIdentifier;
		attribute deviceName : String;
		attribute manufacturer : String;
		attribute firmwareVersion : String;
		attribute currentStatus : DeviceStatus;
		
		port deviceBusPort : AllJoynBusPort;
		
		part allJoynCore {
			attribute supportedInterfaces : InterfaceName[*];
			
			action announcePresence {
				out announcement : ServiceDescriptor;
			}
			
			action discoverPeers {
				out discoveredServices : ServiceDescriptor[*];
			}
			
			action joinSession {
				in targetDevice : DeviceIdentifier;
				in credentials : SessionCredentials;
				out joined : Boolean;
			}
		}
		
		part securityLayer {
			attribute authenticationMethod : String;
			
			action authenticate {
				in peerDevice : DeviceIdentifier;
				out credentials : SessionCredentials;
				out authenticated : Boolean;
			}
			
			action encryptMessage {
				in plainMessage : AllJoynMessage;
				out encryptedMessage : AllJoynMessage;
			}
		}
	}
	
	part def SmartLightBulb :> AllJoynDevice {
		attribute brightness : Real;
		attribute colorTemperature : TemperatureValue;
		attribute powerConsumption : PowerValue;
		attribute isOn : Boolean;
		
		part lightingService {
			attribute serviceName : String;
			
			action setBrightness {
				in level : Real;
				out success : Boolean;
			}
			
			action setColor {
				in temperature : TemperatureValue;
				out success : Boolean;
			}
			
			action togglePower {
				out newState : Boolean;
			}
		}
	}
	
	part def EnvironmentSensor :> AllJoynDevice {
		attribute temperature : TemperatureValue;
		attribute humidity : Real;
		attribute airQuality : Real;
		attribute samplingRate : FrequencyValue;
		
		part sensingService {
			attribute serviceName : String;
			
			action readTemperature {
				out value : TemperatureValue;
			}
			
			action readHumidity {
				out value : Real;
			}
			
			action publishReadings {
				in temp : TemperatureValue;
				in humid : Real;
				out notification : AllJoynMessage;
			}
		}
		
		action continuousSensing {
			loop {
				action measure {
					first action measureTemp;
					then action measureHumid;
				}
				then action publish;
				then action wait;
			}
		}
	}
	
	part def SmartThermostat :> AllJoynDevice {
		attribute targetTemperature : TemperatureValue;
		attribute currentTemperature : TemperatureValue;
		attribute operatingMode : String;
		attribute fanSpeed : Real;
		
		part climateService {
			attribute serviceName : String;
			
			action setTargetTemperature {
				in target : TemperatureValue;
				out success : Boolean;
			}
			
			action setMode {
				in mode : String;
				out success : Boolean;
			}
			
			action regulateClimate {
				in sensorReading : TemperatureValue;
				out hvacCommand : AllJoynMessage;
			}
		}
	}
	
	part def MobileControlApp :> AllJoynDevice {
		attribute userID : String;
		attribute appVersion : String;
		
		part controlInterface {
			action scanForDevices {
				out foundDevices : ServiceDescriptor[*];
			}
			
			action sendCommand {
				in targetDevice : DeviceIdentifier;
				in command : AllJoynMessage;
				out acknowledged : Boolean;
			}
		}
	}
	
	action def DiscoverAllJoynDevices {
		out discoveredDevices : ServiceDescriptor[*];
		out discoveryTime : TimeValue;
	}
	
	action def EstablishSecureConnection {
		in initiator : DeviceIdentifier;
		in responder : DeviceIdentifier;
		in securityLevel : String;
		out sessionID : SessionIdentifier;
		out credentials : SessionCredentials;
		out connectionEstablished : Boolean;
	}
	
	action def TransmitSecureMessage {
		in session : SessionIdentifier;
		in message : AllJoynMessage;
		out deliveryConfirmed : Boolean;
		out transmissionLatency : TimeValue;
	}
	
	action def BroadcastServiceAnnouncement {
		in service : ServiceDescriptor;
		in transport : TransportType;
		out broadcastSuccess : Boolean;
	}
	
	part allSeenIoTEcosystem {
		doc /*
		 * AllSeen Alliance IoT Ecosystem
		 * 
		 * Primary Function: Enable seamless peer-to-peer discovery, secure connection,
		 * and interoperable communication between heterogeneous smart devices from
		 * multiple manufacturers using the AllJoyn distributed software framework.
		 * 
		 * The system operates without requiring cloud infrastructure, allowing devices
		 * to discover and communicate directly over local networks using a common
		 * application-layer protocol. This enables real-time control, monitoring, and
		 * automation across diverse IoT devices while maintaining manufacturer
		 * independence and user privacy.
		 */
		
		part routingDaemon : AllJoynDaemon {
			:>> daemonVersion = "16.04";
			:>> maxConcurrentSessions = 50;
		}
		
		part livingRoomLight : SmartLightBulb {
			:>> deviceName = "Living Room Light";
			:>> manufacturer = "Philips";
		}
		
		part bedroomLight : SmartLightBulb {
			:>> deviceName = "Bedroom Light";
			:>> manufacturer = "LIFX";
		}
		
		part tempSensor : EnvironmentSensor {
			:>> deviceName = "Climate Sensor";
			:>> manufacturer = "Nest";
		}
		
		part thermostat : SmartThermostat {
			:>> deviceName = "Main Thermostat";
			:>> manufacturer = "Honeywell";
		}
		
		part controlApp : MobileControlApp {
			:>> deviceName = "User Control App";
			:>> manufacturer = "AllSeen";
		}
		
		connection lightToDaemon connect 
			livingRoomLight.deviceBusPort to routingDaemon.busInterface;
		
		connection bedroomLightToDaemon connect 
			bedroomLight.deviceBusPort to routingDaemon.busInterface;
		
		connection sensorToDaemon connect 
			tempSensor.deviceBusPort to routingDaemon.busInterface;
		
		connection thermostatToDaemon connect 
			thermostat.deviceBusPort to routingDaemon.busInterface;
		
		connection appToDaemon connect 
			controlApp.deviceBusPort to routingDaemon.busInterface;
		
		action operateAllSeenNetwork {
			first start;
			
			then action initializeNetwork {
				first action startDaemon;
				then action initializeDevices;
			}
			
			then merge operationLoop;
			
			then action discovery : DiscoverAllJoynDevices {
				out discoveredDevices;
				out discoveryTime;
			}
			
			then decide;
				if discovery.discoveredDevices->size() > 0 then establishNetwork;
				if discovery.discoveredDevices->size() == 0 then operationLoop;
			
			action establishNetwork {
				first action announceServices : BroadcastServiceAnnouncement {
					in service;
					out broadcastSuccess;
				}
				
				then action createSecureSessions : EstablishSecureConnection {
					in initiator;
					in responder;
					in securityLevel;
					out sessionID;
					out credentials;
					out connectionEstablished;
				}
				
				then action authenticateDevices;
			}
			
			then action coordinateDeviceOperations {
				first action environmentMonitoring;
				then action climateControl;
				then action lightingControl;
				then action userInteraction;
			}
			
			then operationLoop;
		}
	}
	
	requirement def ProximityBasedDiscoveryRequirement {
		doc /* 
		 * Devices shall discover each other within proximity using multicast
		 * announcements without requiring centralized directory services.
		 */
		
		require constraint discoveryTimeLimit {
			doc /* Discovery shall complete within 5 seconds of device activation. */
		}
	}
	
	requirement def ManufacturerInteroperabilityRequirement {
		doc /* 
		 * Devices from different manufacturers shall communicate using
		 * standardized AllJoyn interface definitions.
		 */
		
		require constraint coreInterfaceCompliance {
			doc /* All devices must implement core AllJoyn interfaces. */
		}
	}
	
	requirement def SecureSessionRequirement {
		doc /* 
		 * All peer-to-peer sessions shall be authenticated and encrypted
		 * using industry-standard cryptographic protocols.
		 */
		
		attribute minimumEncryption : String;
		
		require constraint credentialValidation {
			doc /* Session establishment must validate device credentials. */
		}
	}
	
	requirement def LocalNetworkOperationRequirement {
		doc /* 
		 * The system shall operate entirely on local networks without
		 * mandatory cloud connectivity or internet access.
		 */
		
		require constraint offlineOperation {
			doc /* All core functions must work offline. */
		}
	}
	
	requirement def LowLatencyCommunicationRequirement {
		doc /* 
		 * Device-to-device message latency shall not exceed 100 milliseconds
		 * for real-time control applications.
		 */
		
		attribute maxLatency : TimeValue;
		
		require constraint latencyLimit {
			doc /* Message transmission time must be less than maxLatency. */
		}
	}
	
	requirement def MultiTransportSupportRequirement {
		doc /* 
		 * The system shall support multiple physical transport layers
		 * including WiFi, Bluetooth, and Ethernet simultaneously.
		 */
		
		require constraint heterogeneousRouting {
			doc /* Daemon must route traffic across heterogeneous transports. */
		}
	}
	
	requirement systemRequirements {
		subject allSeenIoTEcosystem;
		
		doc /* 
		 * Comprehensive requirements for AllSeen Alliance IoT ecosystem
		 * ensuring interoperability, security, and performance.
		 */
		
		require proximityDiscovery : ProximityBasedDiscoveryRequirement;
		require interoperability : ManufacturerInteroperabilityRequirement;
		require security : SecureSessionRequirement;
		require localOperation : LocalNetworkOperationRequirement;
		require lowLatency : LowLatencyCommunicationRequirement;
		require multiTransport : MultiTransportSupportRequirement;
	}
}
