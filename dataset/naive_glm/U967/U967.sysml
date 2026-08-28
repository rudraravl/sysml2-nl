package AllJoynCommunicationSystem {
    import ScalarValues::*;
    import ISQ::Time;

    // ===== Value Types =====
    value def TemperatureValue :> Real { unit 'C'; }
    value def HumidityValue :> Real { unit '%'; }
    value def SignalStrength :> Real { unit 'dBm'; }
    value def DataRate :> Real { unit 'kb/s'; }
    value def MessageIdValue :> Integer;
    value def SessionIdValue :> Integer;
    value def TimestampValue :> Integer { unit 'ms'; }
    value def HopCount :> Integer;

    // ===== Enumerations =====
    enum MessageType {
        advertisement,
        discoveryRequest,
        discoveryResponse,
        methodCall,
        methodReply,
        signal,
        sessionJoinRequest,
        sessionJoinResponse,
        sessionLeave,
        error
    }

    enum ServiceType {
        temperatureSensor,
        humiditySensor,
        lightController,
        presenceDetector,
        thermostat,
        custom
    }

    enum SessionState {
        idle,
        discovering,
        connecting,
        active,
        terminating,
        closed
    }

    enum DaemonState {
        offline,
        initializing,
        advertising,
        ready,
        routing,
        error
    }

    enum ProviderState {
        notAdvertised,
        advertised,
        sessionActive,
        terminating,
        terminated
    }

    enum ClientState {
        idle,
        discovering,
        connecting,
        active,
        terminating,
        closed
    }

    // ===== Item Definitions =====
    item def ServiceAdvertisement {
        attr serviceName : String;
        attr serviceType : ServiceType;
        attr providerAppId : String;
        attr portNumber : Integer;
        attr timestamp : TimestampValue;
    }

    item def DiscoveryRequest {
        attr serviceType : ServiceType;
        attr clientAppId : String;
        attr timestamp : TimestampValue;
    }

    item def DiscoveryResponse {
        attr foundServices : ServiceAdvertisement[0..*];
        attr timestamp : TimestampValue;
    }

    item def MethodCall {
        attr methodId : String;
        attr methodName : String;
        attr parameters : String[0..*];
        attr replyExpected : Boolean;
        attr timestamp : TimestampValue;
    }

    item def MethodReply {
        attr methodId : String;
        attr result : String;
        attr success : Boolean;
        attr timestamp : TimestampValue;
    }

    item def SignalMessage {
        attr signalId : String;
        attr signalName : String;
        attr payload : String;
        attr timestamp : TimestampValue;
    }

    item def SessionJoinRequest {
        attr sessionId : SessionIdValue;
        attr clientAppId : String;
        attr providerAppId : String;
        attr timestamp : TimestampValue;
    }

    item def SessionJoinResponse {
        attr sessionId : SessionIdValue;
        attr accepted : Boolean;
        attr timestamp : TimestampValue;
    }

    item def SessionLeave {
        attr sessionId : SessionIdValue;
        attr reason : String;
        attr timestamp : TimestampValue;
    }

    item def Message {
        attr messageId : MessageIdValue;
        attr msgType : MessageType;
        attr sourceId : String;
        attr destinationId : String;
        attr timestamp : TimestampValue;
        attr payload : String;
    }

    item def RoutingTableEntry {
        attr deviceId : String;
        attr networkAddress : String;
        attr lastSeen : TimestampValue;
        attr hopCount : HopCount;
    }

    item def ServiceRegistryEntry {
        attr serviceName : String;
        attr serviceType : ServiceType;
        attr providerAppId : String;
        attr isLocal : Boolean;
        attr isAdvertised : Boolean;
    }

    // ===== Port Definitions =====
    port def NetworkPort {
        out item outgoing : Message[0..*];
        in item incoming : Message[0..*];
    }

    port def ApplicationPort {
        out item methodCalls : MethodCall[0..*];
        in item methodReplies : MethodReply[0..*];
        in item signals : SignalMessage[0..*];
        out item sessionJoinRequests : SessionJoinRequest[0..*];
        in item sessionJoinResponses : SessionJoinResponse[0..*];
        out item sessionLeaves : SessionLeave[0..*];
        out item discoveryRequests : DiscoveryRequest[0..*];
        in item discoveryResponses : DiscoveryResponse[0..*];
    }

    port def ProviderPort {
        in item methodCalls : MethodCall[0..*];
        out item methodReplies : MethodReply[0..*];
        out item signals : SignalMessage[0..*];
        in item sessionJoinRequests : SessionJoinRequest[0..*];
        out item sessionJoinResponses : SessionJoinResponse[0..*];
        in item sessionLeaves : SessionLeave[0..*];
        out item advertisements : ServiceAdvertisement[0..*];
    }

    port def DaemonRouterPort {
        out item outgoing : Message[0..*];
        in item incoming : Message[0..*];
    }

    port def DaemonAppPort {
        in item methodCalls : MethodCall[0..*];
        out item methodReplies : MethodReply[0..*];
        in item signals : SignalMessage[0..*];
        out item sessionJoinRequests : SessionJoinRequest[0..*];
        in item sessionJoinResponses : SessionJoinResponse[0..*];
        out item sessionLeaves : SessionLeave[0..*];
        out item discoveryRequests : DiscoveryRequest[0..*];
        in item discoveryResponses : DiscoveryResponse[0..*];
        in item advertisements : ServiceAdvertisement[0..*];
    }

    // ===== Requirements =====
    requirement def CommunicationRequirement {
        doc "The system shall enable peer-to-peer communication between smart devices on a local network without requiring internet connectivity or a central cloud server.";
        subject system : AllJoynSystem;
    }

    requirement def DiscoveryRequirement {
        doc "Service providers shall broadcast service advertisements, and service clients shall discover these advertisements via the local bus daemon.";
        subject provider : ServiceProvider;
        subject client : ServiceClient;
        subject daemon : BusDaemon;
    }

    requirement def SessionRequirement {
        doc "A secure session shall be established between a client and provider before method calls or signals are exchanged.";
        subject session : Session;
    }

    requirement def RoutingRequirement {
        doc "The bus router shall maintain a routing table and direct messages between bus daemons efficiently.";
        subject router : BusRouter;
    }

    requirement def MethodCallRequirement {
        doc "A client shall be able to invoke a method on a provider and receive a reply within the active session.";
        subject methodCall : MethodCall;
        subject methodReply : MethodReply;
    }

    requirement def SignalRequirement {
        doc "A provider shall be able to broadcast signals to all connected clients subscribed to the signal.";
        subject signal : SignalMessage;
    }

    requirement def TerminationRequirement {
        doc "Either party shall be able to terminate an active session by sending a session leave message.";
        subject session : Session;
        subject leave : SessionLeave;
    }

    requirement def DaemonRegistryRequirement {
        doc "Each bus daemon shall maintain a registry of local services and a cache of discovered remote services.";
        subject daemon : BusDaemon;
    }

    // ===== Action Definitions =====
    action def AdvertiseServiceAction {
        in providerAppId : String;
        in serviceName : String;
        in serviceType : ServiceType;
        out advertisement : ServiceAdvertisement;
    }

    action def DiscoverServicesAction {
        in serviceType : ServiceType;
        in clientAppId : String;
        out request : DiscoveryRequest;
    }

    action def ProcessDiscoveryResponseAction {
        in response : DiscoveryResponse;
        out selectedProvider : String;
    }

    action def JoinSessionAction {
        in providerAppId : String;
        in clientAppId : String;
        out request : SessionJoinRequest;
    }

    action def AcceptSessionAction {
        in request : SessionJoinRequest;
        out response : SessionJoinResponse;
    }

    action def InvokeMethodAction {
        in methodName : String;
        in parameters : String[0..*];
        out call : MethodCall;
    }

    action def HandleMethodCallAction {
        in call : MethodCall;
        out reply : MethodReply;
    }

    action def EmitSignalAction {
        in signalName : String;
        in payload : String;
        out signal : SignalMessage;
    }

    action def LeaveSessionAction {
        in sessionId : SessionIdValue;
        in reason : String;
        out leave : SessionLeave;
    }

    action def RouteMessageAction {
        in msg : Message;
        in routingTable : RoutingTableEntry[0..*];
        out forwarded : Message;
    }

    action def UpdateRoutingTableAction {
        in deviceId : String;
        in address : String;
        in hopCount : HopCount;
        out updatedTable : RoutingTableEntry[0..*];
    }

    // ===== Part Definitions =====
    part def BusRouter {
        port routerPort : NetworkPort;
        attr routingTable : RoutingTableEntry[0..*];
        attr messageCounter : MessageIdValue;
        attr maxHops : HopCount = 10;

        action routeMessage : RouteMessageAction;
        action updateRoutingTable : UpdateRoutingTableAction;

        state routerStateMachine {
            entry { routerPort.outgoing = (); }
            state Idle;
            state Routing {
                entry { routeMessage(routerPort.incoming->first(), routingTable); }
            }
            state Error;
            transition idle_to_routing first Idle if routerPort.incoming->notEmpty() then Routing;
            transition routing_to_idle first Routing if routerPort.incoming->isEmpty() then Idle;
            transition routing_to_error first Routing if routerPort.incoming->isEmpty() then Error;
            transition error_to_idle first Error then Idle;
        }
    }

    part def BusDaemon {
        port networkPort : DaemonRouterPort;
        port appPort : DaemonAppPort;
        attr localRegistry : ServiceRegistryEntry[0..*];
        attr remoteServiceCache : ServiceRegistryEntry[0..*];
        attr deviceId : String;
        attr daemonState : DaemonState;

        action registerLocalService : AdvertiseServiceAction;
        action cacheRemoteService : ProcessDiscoveryResponseAction;
        action forwardToRouter : RouteMessageAction;
        action deliverToApplication : HandleMethodCallAction;

        state daemonStateMachine {
            entry { daemonState = DaemonState::offline; }
            state Offline;
            state Initializing;
            state Advertising;
            state Ready;
            state Routing;
            state Error;
            transition offline_to_init first Offline then Initializing;
            transition init_to_ready first Initializing then Ready;
            transition ready_to_advertising first Ready if localRegistry->notEmpty() then Advertising;
            transition advertising_to_ready first Advertising then Ready;
            transition ready_to_routing first Ready if networkPort.incoming->notEmpty() then Routing;
            transition routing_to_ready first Routing if networkPort.incoming->isEmpty() then Ready;
            transition any_to_error first (Initializing | Advertising | Ready | Routing) if networkPort.incoming->select(msgType == MessageType::error)->notEmpty() then Error;
            transition error_to_ready first Error then Ready;
        }
    }

    part def ServiceProvider {
        port providerPort : ProviderPort;
        attr appId : String;
        attr serviceName : String;
        attr serviceType : ServiceType;
        attr offeredCapability : String;
        attr activeSessions : SessionIdValue[0..*];
        attr providerState : ProviderState;

        action advertiseService : AdvertiseServiceAction;
        action handleMethodCall : HandleMethodCallAction;
        action emitSignal : EmitSignalAction;
        action acceptSession : AcceptSessionAction;

        state providerStateMachine {
            entry { providerState = ProviderState::notAdvertised; }
            state NotAdvertised;
            state Advertised;
            state SessionActive;
            state Terminating;
            state Terminated;
            transition notAdv_to_adv first NotAdvertised then Advertised;
            transition adv_to_session first Advertised if providerPort.sessionJoinRequests->notEmpty() then SessionActive;
            transition session_to_term first SessionActive if providerPort.sessionLeaves->notEmpty() then Terminating;
            transition term_to_termd first Terminating then Terminated;
            transition termd_to_adv first Terminated then Advertised;
        }
    }

    part def ServiceClient {
        port clientPort : ApplicationPort;
        attr appId : String;
        attr subscribedServices : ServiceType[0..*];
        attr activeSessions : SessionIdValue[0..*];
        attr clientState : ClientState;

        action discoverServices : DiscoverServicesAction;
        action processDiscoveryResponse : ProcessDiscoveryResponseAction;
        action invokeMethod : InvokeMethodAction;
        action receiveSignal : EmitSignalAction;
        action joinSession : JoinSessionAction;
        action leaveSession : LeaveSessionAction;

        state clientStateMachine {
            entry { clientState = ClientState::idle; }
            state Idle;
            state Discovering;
            state Connecting;
            state Active;
            state Terminating;
            state Closed;
            transition idle_to_disc first Idle then Discovering;
            transition disc_to_conn first Discovering if clientPort.discoveryResponses->notEmpty() then Connecting;
            transition conn_to_active first Connecting if clientPort.sessionJoinResponses->select(accepted == true)->notEmpty() then Active;
            transition conn_to_idle first Connecting if clientPort.sessionJoinResponses->select(accepted == false)->notEmpty() then Idle;
            transition active_to_term first Active if clientPort.sessionLeaves->notEmpty() then Terminating;
            transition term_to_closed first Terminating then Closed;
            transition closed_to_idle first Closed then Idle;
        }
    }

    part def Session {
        attr sessionId : SessionIdValue;
        attr providerAppId : String;
        attr clientAppId : String;
        attr state : SessionState;
        attr establishedAt : TimestampValue;
        attr terminatedAt : TimestampValue;
        attr messagesExchanged : Integer;
    }

    part def SmartDevice {
        attr deviceId : String;
        attr deviceName : String;
        attr networkAddress : String;
        part daemon : BusDaemon {
            redefines deviceId = SmartDevice::deviceId;
        }
        part providers : ServiceProvider[0..*];
        part clients : ServiceClient[0..*];
        connection daemonToProviders connect daemon.appPort to providers.providerPort;
        connection daemonToClients connect daemon.appPort to clients.clientPort;
    }

    part def AllJoynSystem {
        requirement commsReq : CommunicationRequirement;
        requirement discReq : DiscoveryRequirement;
        requirement sessReq : SessionRequirement;
        requirement routeReq : RoutingRequirement;
        requirement methodReq : MethodCallRequirement;
        requirement signalReq : SignalRequirement;
        requirement termReq : TerminationRequirement;
        requirement registryReq : DaemonRegistryRequirement;

        part router : BusRouter;
        part devices : SmartDevice[2..*];

        connection routerToDaemons connect router.routerPort to devices.daemon.networkPort;

        // Example concrete instance: a temperature sensor device and a monitoring client device
        part tempSensorDevice : SmartDevice {
            redefines deviceId = "device-001";
            redefines deviceName = "LivingRoomTempSensor";
            redefines networkAddress = "192.168.1.101";
            part daemon : BusDaemon {
                redefines deviceId = "device-001";
            }
            part tempProvider : ServiceProvider {
                redefines appId = "app-temp-001";
                redefines serviceName = "org.alljoyn.SmartHome.Temperature";
                redefines serviceType = ServiceType::temperatureSensor;
                redefines offeredCapability = "ambientTemperatureReading";
            }
        }

        part monitorDevice : SmartDevice {
            redefines deviceId = "device-002";
            redefines deviceName = "PhoneMonitorApp";
            redefines networkAddress = "192.168.1.102";
            part daemon : BusDaemon {
                redefines deviceId = "device-002";
            }
            part monitorClient : ServiceClient {
                redefines appId = "app-monitor-001";
                redefines subscribedServices = (ServiceType::temperatureSensor,);
            }
        }

        connection tempDaemonToRouter connect tempSensorDevice.daemon.networkPort to router.routerPort;
        connection monitorDaemonToRouter connect monitorDevice.daemon.networkPort to router.routerPort;
        connection tempProviderToDaemon connect tempSensorDevice.tempProvider.providerPort to tempSensorDevice.daemon.appPort;
        connection monitorClientToDaemon connect monitorDevice.monitorClient.clientPort to monitorDevice.daemon.appPort;

        // Active session example
        part activeSession : Session {
            redefines sessionId = 1001;
            redefines providerAppId = "app-temp-001";
            redefines clientAppId = "app-monitor-001";
            redefines state = SessionState::active;
            redefines establishedAt = 1700000000;
            redefines messagesExchanged = 42;
        }
    }
}
