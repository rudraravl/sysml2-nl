package AllJoynSystem {
    doc /* Distributed communication system for smart devices based on AllJoyn P2P framework. */

    private import ScalarValues::*;

    requirement def AllJoynCommunicationReq {
        doc /* The system shall allow devices to automatically discover each other and communicate directly via Bus Daemons and a Bus Router, supporting service advertisement, discovery, session establishment, method calls, and signals. */
    }

    value type Temperature :> Real;

    item def Message {
        attribute id : String;
    }
    item def ServiceAdvertisement :> Message {
        attribute serviceName : String;
        attribute deviceName : String;
    }
    item def DiscoveryRequest :> Message {
        attribute serviceName : String;
    }
    item def DiscoveryResponse :> Message {
        attribute serviceName : String;
        attribute deviceName : String;
    }
    item def SessionRequest :> Message {
        attribute sessionId : String;
    }
    item def SessionAck :> Message {
        attribute sessionId : String;
        attribute accepted : Boolean;
    }
    item def MethodCall :> Message {
        attribute method : String;
        attribute args : String;
    }
    item def MethodReply :> Message {
        attribute result : String;
    }
    item def Signal :> Message {
        attribute signalName : String;
        attribute payload : String;
    }
    item def SessionTerminate :> Message {
        attribute sessionId : String;
    }

    port def ApplicationPort {
        inout item msg : Message;
    }
    port def RouterPort {
        inout item msg : Message;
    }

    part def BusDaemon {
        port appPort : ApplicationPort;
        port routerPort : RouterPort;
        attribute localServices : String[0..*];
        attribute remoteServices : String[0..*];

        exhibit state DaemonBehavior {
            entry; then Idle;
            state Idle;
            transition receiveAppMsg
                first Idle
                accept msg : Message via appPort
                do send msg via routerPort
                then Idle;
            transition receiveRouterMsg
                first Idle
                accept msg : Message via routerPort
                do send msg via appPort
                then Idle;
        }
    }

    part def BusRouter {
        port routerPort1 : RouterPort;
        port routerPort2 : RouterPort;
        attribute routingTable : String[0..*];

        exhibit state RouterBehavior {
            entry; then Idle;
            state Idle;
            transition routeMsg1to2
                first Idle
                accept msg : Message via routerPort1
                do send msg via routerPort2
                then Idle;
            transition routeMsg2to1
                first Idle
                accept msg : Message via routerPort2
                do send msg via routerPort1
                then Idle;
        }
    }

    part def ServiceProvider {
        attribute serviceName : String = "TemperatureSensor";
        attribute deviceName : String = "TempDevice";
        attribute currentTemp : Temperature = 22.5;
        port appPort : ApplicationPort;

        exhibit state ProviderBehavior {
            entry send new ServiceAdvertisement("1", serviceName, deviceName) via appPort;
            then Advertising;
            state Advertising;
            transition discoverRequest
                first Advertising
                accept req : DiscoveryRequest via appPort
                do send new DiscoveryResponse("2", req.serviceName, deviceName) via appPort
                then WaitingForSession;
            state WaitingForSession;
            transition sessionReq
                first WaitingForSession
                accept req : SessionRequest via appPort
                do send new SessionAck("3", req.sessionId, true) via appPort
                then Active;
            state Active {
                entry send new Signal("5", "TempChanged", "22.5") via appPort;
            }
            transition methodCall
                first Active
                accept call : MethodCall via appPort
                do send new MethodReply("4", "22.5") via appPort
                then Active;
            transition terminate
                first Active
                accept term : SessionTerminate via appPort
                then Advertising;
        }
    }

    part def ServiceClient {
        attribute targetService : String = "TemperatureSensor";
        attribute sessionId : String = "Sess1";
        port appPort : ApplicationPort;

        perform action ClientBehavior {
            action discover send new DiscoveryRequest("6", targetService) via appPort;
            then action acceptDiscovery accept resp : DiscoveryResponse via appPort;
            then action requestSession send new SessionRequest("7", sessionId) via appPort;
            then action acceptSession accept ack : SessionAck via appPort;
            then action callMethod send new MethodCall("8", "GetTemp", "") via appPort;
            then action acceptReply accept reply : MethodReply via appPort;
            then action acceptSignal accept sig : Signal via appPort;
            then action terminate send new SessionTerminate("9", sessionId) via appPort;
        }
    }

    part alljoynNetwork {
        part providerDevice : ServiceProvider;
        part clientDevice : ServiceClient;
        part providerDaemon : BusDaemon;
        part clientDaemon : BusDaemon;
        part router : BusRouter;

        interface ProviderAppToDaemon connect providerDevice.appPort to providerDaemon.appPort;
        interface ClientAppToDaemon connect clientDevice.appPort to clientDaemon.appPort;
        interface ProviderDaemonToRouter connect providerDaemon.routerPort to router.routerPort1;
        interface ClientDaemonToRouter connect clientDaemon.routerPort to router.routerPort2;

        satisfy AllJoynCommunicationReq by providerDevice, clientDevice, providerDaemon, clientDaemon, router;
    }
}
