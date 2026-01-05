package AllJoynDistributedSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def DeviceIdentifier :> String;
	attribute def SessionIdentifier :> String;
	attribute def InterfaceDescriptor :> String;
	attribute def ServiceDescriptor :> String;
	attribute def ObjectPath :> String;
	attribute def MemberName :> String;

	attribute def LatencyValue :> ISQ::TimeValue;
	attribute def BandwidthValue :> Real;
	attribute def BandwidthUnit;

	item def AllJoynMessage {
		attribute sender : DeviceIdentifier;
		attribute destination : DeviceIdentifier;
		attribute sessionId : SessionIdentifier;
		attribute messageType : MessageType;
		attribute payload : String;
		attribute timestamp : ISQ::TimeValue;
	}

	enum def MessageType {
		enum methodCall;
		enum methodReturn;
		enum signal;
		enum error;
	}

	item def ServiceAdvertisement {
		attribute serviceName : ServiceDescriptor;
		attribute deviceId : DeviceIdentifier;
		attribute supportedInterfaces : InterfaceDescriptor[1..*];
		attribute objectPath : ObjectPath;
		attribute sessionPort : Integer;
	}

	item def SessionDescriptor {
		attribute sessionId : SessionIdentifier;
		attribute providerId : DeviceIdentifier;
		attribute consumerId : DeviceIdentifier;
		attribute serviceName : ServiceDescriptor;
		attribute established : Boolean;
	}

	item def StartupRequest;
	item def AdvertiseRequest;
	item def DiscoveryRequest;
	item def SessionJoinRequest;
	item def SessionEstablished;
	item def MethodCallReceived;
	item def CommunicationComplete;
	item def SessionTerminated;
	item def ResetRequest;

	port def AllJoynBusPort {
		attribute interfaceName : InterfaceDescriptor;
		out item outgoingSignal : AllJoynMessage;
		in item incomingMethodCall : AllJoynMessage;
		out item methodReply : AllJoynMessage;
		in item incomingSignal : AllJoynMessage;
	}

	port def RouterConnectionPort {
		attribute connectionId : String;
		out item outboundMessage : AllJoynMessage;
		in item inboundMessage : AllJoynMessage;
	}

	part def AllJoynBusRouter {
		attribute routerId : DeviceIdentifier;
		port routerPort : RouterConnectionPort[1..*];

		part messageRouter {
			attribute activeMessages : AllJoynMessage[0..*];
			attribute routingTable : DeviceIdentifier[0..*];
		}

		part sessionManager {
			attribute activeSessions : SessionDescriptor[0..*];
		}

		perform action routeTraffic;
	}

	part def AllJoynBusDaemon {
		attribute daemonId : DeviceIdentifier;
		port localApplicationPort : AllJoynBusPort[1..*];
		port routerLink : RouterConnectionPort;

		part serviceRegistry {
			attribute localServices : ServiceAdvertisement[0..*];
		}

		part discoveryCache {
			attribute remoteServices : ServiceAdvertisement[0..*];
		}

		part sessionCache {
			attribute establishedSessions : SessionDescriptor[0..*];
		}

		perform action manageBus;
		perform action forwardMessages;
	}

	part def ApplicationServiceProvider {
		attribute applicationId : DeviceIdentifier;
		attribute offeredService : ServiceDescriptor;
		port busInterface : AllJoynBusPort;

		part serviceLogic {
			attribute currentState : String;
			attribute requestCount : Integer;
		}

		perform action announceService;
		perform action processRequests;
		perform action broadcastSignals;
	}

	part def ApplicationServiceClient {
		attribute clientId : DeviceIdentifier;
		port busInterface : AllJoynBusPort;

		part serviceCache {
			attribute knownServices : ServiceAdvertisement[0..*];
		}

		part activeConnections {
			attribute sessions : SessionDescriptor[0..*];
		}

		perform action findServices;
		perform action connectToService;
		perform action invokeRemoteMethod;
		perform action handleSignals;
	}

	action def AnnounceService {
		in applicationId : DeviceIdentifier;
		in serviceName : ServiceDescriptor;
		in interfaces : InterfaceDescriptor[1..*];
		in objectPath : ObjectPath;
		in sessionPort : Integer;
		out advertisement : ServiceAdvertisement;
	}

	action def DiscoverService {
		in interfaceFilter : InterfaceDescriptor;
		in timeout : ISQ::TimeValue;
		out foundServices : ServiceAdvertisement[0..*];
	}

	action def JoinSession {
		in clientId : DeviceIdentifier;
		in providerId : DeviceIdentifier;
		in serviceName : ServiceDescriptor;
		in sessionPort : Integer;
		out sessionDescriptor : SessionDescriptor;
		out joinSuccessful : Boolean;
	}

	action def InvokeMethod {
		in sessionId : SessionIdentifier;
		in objectPath : ObjectPath;
		in interfaceName : InterfaceDescriptor;
		in methodName : MemberName;
		in arguments : String;
		out returnValue : String;
		out invocationSuccess : Boolean;
	}

	action def EmitSignal {
		in sessionId : SessionIdentifier;
		in objectPath : ObjectPath;
		in interfaceName : InterfaceDescriptor;
		in signalName : MemberName;
		in signalData : String;
	}

	action def RouteMessageAction {
		in message : AllJoynMessage;
		in routingTable : DeviceIdentifier[0..*];
		out targetDaemon : DeviceIdentifier;
		out routingSuccess : Boolean;
	}

	action def AllJoynServiceInteraction {
		first start;

		then action providerAnnounce : AnnounceService {
			in applicationId;
			in serviceName;
			in interfaces;
			in objectPath;
			in sessionPort;
			out advertisement;
		}

		then action clientDiscover : DiscoverService {
			in interfaceFilter;
			in timeout;
			out foundServices;
		}

		then decide;
			if clientDiscover.foundServices != null then attemptJoin;
			else terminateFlow;

		action attemptJoin : JoinSession {
			in clientId;
			in providerId = providerAnnounce.applicationId;
			in serviceName = providerAnnounce.serviceName;
			in sessionPort = providerAnnounce.sessionPort;
			out sessionDescriptor;
			out joinSuccessful;
		}

		then decide;
			if attemptJoin.joinSuccessful then communicationActive;
			else terminateFlow;

		merge communicationActive;

		then decide;
			if sessionActive then performMethodCall;
			else closeSession;

		action performMethodCall : InvokeMethod {
			in sessionId = attemptJoin.sessionDescriptor.sessionId;
			in objectPath;
			in interfaceName;
			in methodName;
			in arguments;
			out returnValue;
			out invocationSuccess;
		}

		then action emitNotification : EmitSignal {
			in sessionId = attemptJoin.sessionDescriptor.sessionId;
			in objectPath;
			in interfaceName;
			in signalName;
			in signalData;
		}

		then communicationActive;

		action closeSession;
		then terminateFlow;

		action terminateFlow;
		then done;

		private attribute sessionActive : Boolean;
	}

	state def AllJoynDeviceLifecycle {
		entry; then uninitialized;

		state uninitialized;
		transition uninitialized_to_initializing
			first uninitialized
			accept StartupRequest
			then initializing;

		state initializing {
			entry action initializeBus {
				out success : Boolean;
			}
		}
		transition initializing_to_ready
			first initializing
			if initSuccess
			then ready;

		transition initializing_to_error
			first initializing
			if not initSuccess
			then errorState;

		state ready {
			state advertising;
			state discovering;
			state sessionActive;
		}

		transition ready_to_advertising
			first ready
			accept AdvertiseRequest
			then advertising;

		transition ready_to_discovering
			first ready
			accept DiscoveryRequest
			then discovering;

		transition advertising_to_sessionActive
			first advertising
			accept SessionJoinRequest
			then sessionActive;

		transition discovering_to_sessionActive
			first discovering
			accept SessionEstablished
			then sessionActive;

		state sessionActive {
			entry action establishSession;
			state communicating;
			state idle;
		}

		transition sessionActive_to_communicating
			first sessionActive
			accept MethodCallReceived
			then communicating;

		transition communicating_to_idle
			first communicating
			accept CommunicationComplete
			then idle;

		transition sessionActive_to_ready
			first sessionActive
			accept SessionTerminated
			then ready;

		state errorState;
		transition error_to_uninitialized
			first errorState
			accept ResetRequest
			then uninitialized;

		private attribute initSuccess : Boolean;
	}

	part allJoynDistributedSystem {
		doc /*
			AllJoyn-based distributed communication system enabling peer-to-peer
			device interaction across heterogeneous platforms. Primary function:
			Facilitate seamless discovery, connection, and real-time communication
			between smart devices and applications on local networks without
			requiring centralized cloud infrastructure or internet connectivity.
		*/

		part centralRouter : AllJoynBusRouter {
			attribute :>> routerId = "router-main-001";
		}

		part deviceDaemon1 : AllJoynBusDaemon {
			attribute :>> daemonId = "daemon-device-alpha";
		}

		part deviceDaemon2 : AllJoynBusDaemon {
			attribute :>> daemonId = "daemon-device-beta";
		}

		connect deviceDaemon1.routerLink to centralRouter.routerPort;
		connect deviceDaemon2.routerLink to centralRouter.routerPort;

		part temperatureSensorService : ApplicationServiceProvider {
			attribute :>> applicationId = "sensor-temp-001";
			attribute :>> offeredService = "TemperatureMonitoring";

			perform action announceService : AnnounceService {
				in applicationId = temperatureSensorService.applicationId;
				in serviceName = temperatureSensorService.offeredService;
				in interfaces = ("org.alljoyn.TemperatureSensor", "org.alljoyn.DataProvider");
				in objectPath = "/sensors/temperature";
				in sessionPort = 25;
				out advertisement;
			}

			perform action processRequests {
				first start;
				then loop {
					accept methodRequest;
					then action handleRequest {
						action readSensor;
						then action formatResponse;
						then action sendMethodReply;
					}
				}
			}

			perform action broadcastSignals {
				loop {
					action measureTemperature;
					then action emitUpdate : EmitSignal {
						in sessionId;
						in objectPath = "/sensors/temperature";
						in interfaceName = "org.alljoyn.TemperatureSensor";
						in signalName = "TemperatureChanged";
						in signalData;
					}
					then action waitInterval;
				}
			}
		}

		connect temperatureSensorService.busInterface to deviceDaemon1.localApplicationPort;

		part monitoringApplication : ApplicationServiceClient {
			attribute :>> clientId = "monitor-app-001";

			perform action findServices : DiscoverService {
				in interfaceFilter = "org.alljoyn.TemperatureSensor";
				in timeout = 5000[SI::s];
				out foundServices;
			}

			perform action connectToService {
				first start;
				then action joinSensorSession : JoinSession {
					in clientId = monitoringApplication.clientId;
					in providerId;
					in serviceName;
					in sessionPort;
					out sessionDescriptor;
					out joinSuccessful;
				}
				then decide;
					if joinSensorSession.joinSuccessful then activeMonitoring;
					else done;

				action activeMonitoring {
					loop {
						action requestData : InvokeMethod {
							in sessionId = joinSensorSession.sessionDescriptor.sessionId;
							in objectPath = "/sensors/temperature";
							in interfaceName = "org.alljoyn.TemperatureSensor";
							in methodName = "GetCurrentTemperature";
							in arguments = "";
							out returnValue;
							out invocationSuccess;
						}
						then action processData;
					}
				}
			}

			perform action handleSignals {
				loop {
					accept signalMessage;
					then action processSignal;
				}
			}
		}

		connect monitoringApplication.busInterface to deviceDaemon2.localApplicationPort;

		perform action systemOperation : AllJoynServiceInteraction;
	}

	requirement def <'REQ-ALLJOYN-001'> PeerToPeerArchitecture {
		doc /*
			The system shall enable direct peer-to-peer communication between
			devices without mandatory dependence on centralized servers or
			cloud infrastructure.
		*/

		subject allJoynDistributedSystem;
	}

	requirement def <'REQ-ALLJOYN-002'> DynamicServiceDiscovery {
		doc /*
			The system shall support dynamic discovery of services advertised
			by devices on the local network using multicast announcements.
		*/

		subject allJoynDistributedSystem.monitoringApplication;
	}

	requirement def <'REQ-ALLJOYN-003'> SessionBasedCommunication {
		doc /*
			The system shall establish and maintain sessions between service
			providers and consumers to ensure reliable bidirectional communication.
		*/

		subject allJoynDistributedSystem;

		assume constraint {
			allJoynDistributedSystem.temperatureSensorService.applicationId != null
		}
	}

	requirement def <'REQ-ALLJOYN-004'> EfficientMessageRouting {
		doc /*
			The AllJoyn router shall efficiently route messages between daemons
			running on different devices with minimal latency.
		*/

		subject allJoynDistributedSystem.centralRouter;
	}

	requirement def <'REQ-ALLJOYN-005'> CrossPlatformInteroperability {
		doc /*
			The system shall enable interoperability between devices running
			different operating systems and hardware platforms through standardized
			AllJoyn protocol implementation.
		*/

		subject allJoynDistributedSystem;
	}

	requirement allJoynSystemRequirements {
		doc /*
			Top-level requirements for AllJoyn distributed peer-to-peer
			communication system.
		*/

		requirement peerToPeer : PeerToPeerArchitecture;
		requirement discovery : DynamicServiceDiscovery;
		requirement sessions : SessionBasedCommunication;
		requirement routing : EfficientMessageRouting;
		requirement interoperability : CrossPlatformInteroperability;
	}
}
