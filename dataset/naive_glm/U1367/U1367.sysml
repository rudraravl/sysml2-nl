package XMPPSystem {
    import ISQ::*;
    
    item def XMLStanza;
    item def MessageStanza :> XMLStanza;
    item def PresenceStanza :> XMLStanza;
    item def IQStanza :> XMLStanza;
    item def ConnectionRequest;
    
    value def LatencyValue = Real { unit "ms"; }
    
    port def StanzaPort {
        in item inStanzas: XMLStanza[*];
        out item outStanzas: XMLStanza[*];
    }
    
    port def RequestPort {
        in item inRequests: ConnectionRequest[*];
        out item outResponses: ConnectionRequest[*];
    }
    
    part def ConnectionManager {
        attribute maxCapacity: Integer = 10000;
        attribute currentConnections: Integer = 0;
        
        port stanzaPort: StanzaPort;
        port requestPort: RequestPort;
        
        action acceptRequest;
        action rejectRequest;
        
        state def ConnectionManagerStates {
            entry; 
            state Accepting {
                entry; 
                do acceptRequest;
            }
            state Rejecting {
                entry; 
                do rejectRequest;
            }
            transition t1 first Accepting if (currentConnections >= maxCapacity) -> Rejecting;
            transition t2 Rejecting if (currentConnections < maxCapacity) -> Accepting;
        }
        
        exhibit state ConnectionManagerStates;
    }
    
    part def RoutingEngine {
        port inStanzas: StanzaPort;
        port outStanzas: StanzaPort;
        
        action def RouteAction {
            in stanza: XMLStanza;
            out routedStanza: XMLStanza;
        }
        perform route: RouteAction;
    }
    
    part def OfflineStorage {
        port inMessages: StanzaPort;
        port outMessages: StanzaPort;
        
        action def StoreAction {
            in message: MessageStanza;
        }
        perform store: StoreAction;
    }
    
    part def PresenceAggregator {
        port inPresence: StanzaPort;
        port outPresence: StanzaPort;
        
        action def AggregateAction {
            in presence: PresenceStanza;
            out broadcast: PresenceStanza;
        }
        perform aggregate: AggregateAction;
    }
    
    part def XMPPServer {
        port externalStanzaPort: StanzaPort;
        port externalRequestPort: RequestPort;
        
        part connectionManager: ConnectionManager;
        part routingEngine: RoutingEngine;
        part offlineStorage: OfflineStorage;
        part presenceAggregator: PresenceAggregator;
        
        connection: StanzaPort connect externalStanzaPort to connectionManager.stanzaPort;
        connection: StanzaPort connect connectionManager.stanzaPort to routingEngine.inStanzas;
        connection: StanzaPort connect routingEngine.outStanzas to offlineStorage.inMessages;
        connection: StanzaPort connect routingEngine.outStanzas to presenceAggregator.inPresence;
        connection: StanzaPort connect offlineStorage.outMessages to externalStanzaPort;
        connection: StanzaPort connect presenceAggregator.outPresence to externalStanzaPort;
        connection: RequestPort connect externalRequestPort to connectionManager.requestPort;
    }
    
    part def MessageProcessor {
        port stanzaPort: StanzaPort;
        action processMessage;
    }
    
    part def PresenceManager {
        port stanzaPort: StanzaPort;
        action updatePresence;
    }
    
    part def RosterManager {
        port stanzaPort: StanzaPort;
        action updateRoster;
    }
    
    part def XMPPClient {
        port stanzaPort: StanzaPort;
        port requestPort: RequestPort;
        
        part messageProcessor: MessageProcessor;
        part presenceManager: PresenceManager;
        part rosterManager: RosterManager;
        
        connection: StanzaPort connect stanzaPort to messageProcessor.stanzaPort;
        connection: StanzaPort connect stanzaPort to presenceManager.stanzaPort;
        connection: StanzaPort connect stanzaPort to rosterManager.stanzaPort;
        
        action connect;
        action authenticate;
        action active;
        action disconnect;
        
        state def ClientLifecycle {
            state Connecting {
                entry; 
                do connect;
            }
            state Authenticating {
                entry; 
                do authenticate;
            }
            state Active {
                entry; 
                do active;
            }
            state Disconnected {
                entry; 
                do disconnect;
            }
            
            transition t1 first Connecting if (connectionEstablished) -> Authenticating;
            transition t2 Authenticating if (authSuccess) -> Active;
            transition t3 Active if (connectionLost) -> Disconnected;
            transition t4 Disconnected if (retry) -> Connecting;
        }
        
        exhibit state ClientLifecycle;
    }
    
    part def XMPPNetwork {
        part server: XMPPServer;
        part clients: XMPPClient[*];
        
        connection: StanzaPort connect clients.stanzaPort to server.externalStanzaPort;
        connection: RequestPort connect clients.requestPort to server.externalRequestPort;
    }
    
    requirement def ScalabilityRequirement {
        subject system: XMPPNetwork;
        requirement {
            doc "The system must support thousands of concurrent users."
            constraint system.server.connectionManager.maxCapacity >= 10000;
        }
    }
    
    requirement def LowLatencyRequirement {
        subject system: XMPPNetwork;
        attribute maxLatency: LatencyValue = 50;
        requirement {
            doc "The system must ensure low-latency, real-time message delivery."
            constraint system.messageDeliveryLatency <= maxLatency;
        }
    }
}
