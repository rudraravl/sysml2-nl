package XMPPMessagingSystem {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;
    
    attribute def JabberID :> String;
    attribute def MessageContent :> String;
    attribute def StanzaID :> String;
    attribute def ResourceIdentifier :> String;
    
    enum def ConnectionStatus {
        disconnected;
        connecting;
        connected;
        authenticated;
        bound;
        active;
        error;
    }
    
    enum def PresenceState {
        available;
        away;
        chat;
        dnd;
        xa;
        unavailable;
    }
    
    enum def StanzaType {
        messageType;
        presenceType;
        iqType;
    }
    
    enum def MessagePriority {
        low;
        normal;
        high;
    }
    
    item def XMLStanza {
        attribute id : StanzaID;
        attribute fromJID : JabberID;
        attribute toJID : JabberID;
        attribute timestamp : Real;
    }
    
    item def MessageStanza :> XMLStanza {
        attribute body : MessageContent;
        attribute subjectLine : String;
        attribute priority : MessagePriority;
        attribute thread : String;
    }
    
    item def PresenceStanza :> XMLStanza {
        attribute show : PresenceState;
        attribute status : String;
        attribute priorityValue : Integer;
    }
    
    item def IQStanza :> XMLStanza {
        attribute queryType : String;
        attribute payload : String;
    }
    
    port def XMPPClientPort {
        out item outgoingMessages : MessageStanza[*] ordered;
        in item incomingMessages : MessageStanza[*] ordered;
        out item outgoingPresence : PresenceStanza[*];
        in item incomingPresence : PresenceStanza[*];
        out item outgoingIQ : IQStanza[*];
        in item incomingIQ : IQStanza[*];
    }
    
    port def XMPPServerPort {
        in item clientMessages : MessageStanza[*] ordered;
        out item serverMessages : MessageStanza[*] ordered;
        in item clientPresence : PresenceStanza[*];
        out item serverPresence : PresenceStanza[*];
        in item clientIQ : IQStanza[*];
        out item serverIQ : IQStanza[*];
    }
    
    part def XMPPClient {
        attribute jid : JabberID;
        attribute resource : ResourceIdentifier;
        attribute connectionStatus : ConnectionStatus;
        attribute currentPresence : PresenceState;
        
        port clientPort : XMPPClientPort;
        
        part streamManager {
            attribute streamConnectionStatus : ConnectionStatus;
            
            state machine StreamLifecycle {
                entry; then Disconnected;
                
                state Disconnected;
                state Connecting;
                state StreamNegotiation;
                state Authenticating;
                state ResourceBinding;
                state Active;
                state Error;
                
                transition t1 first Disconnected
                    then Connecting
                    accept initiateConnection;
                
                transition t2 first Connecting
                    then StreamNegotiation
                    accept streamOpened;
                
                transition t3 first StreamNegotiation
                    then Authenticating
                    accept featuresNegotiated;
                
                transition t4 first Authenticating
                    then ResourceBinding
                    accept authenticationSuccess;
                
                transition t5 first ResourceBinding
                    then Active
                    accept resourceBound;
                
                transition t6 first Active
                    then Disconnected
                    accept disconnect;
                
                transition t7 first Connecting
                    then Error
                    accept connectionFailed;
                
                transition t8 first Error
                    then Disconnected
                    accept reset;
            }
        }
        
        part messageProcessor {
            perform action processMessages {
                first start;
                then merge awaitMessage;
                then action receiveMessage {
                    out msg : MessageStanza;
                }
                then action validateMessage {
                    in messageToValidate : MessageStanza;
                    out isValid : Boolean;
                }
                then decide;
                    if validateMessage.isValid then handleMessage;
                    else rejectMessage;
                action handleMessage {
                    in messageToHandle : MessageStanza;
                }
                then awaitMessage;
                action rejectMessage;
                then awaitMessage;
            }
        }
        
        part presenceHandler {
            attribute handlerPresence : PresenceState;
            
            perform action managePresence {
                first start;
                then action initializePresence {
                    out presence : PresenceState = PresenceState::available;
                }
                then merge monitorPresence;
                then action checkPresenceChange {
                    out presenceChanged : Boolean;
                }
                then decide;
                    if checkPresenceChange.presenceChanged then updatePresence;
                    else monitorPresence;
                action updatePresence {
                    in newPresence : PresenceState;
                    out presenceStanza : PresenceStanza;
                }
                then action broadcastPresence {
                    in stanza : PresenceStanza;
                }
                then monitorPresence;
            }
        }
        
        part rosterManager {
            attribute contactList : JabberID[*];
            
            perform action manageRoster {
                first start;
                then action loadRoster;
                then merge processRosterUpdates;
                then action receiveRosterUpdate {
                    out addContact : Boolean;
                    out removeContact : Boolean;
                }
                then decide;
                    if receiveRosterUpdate.addContact then addToRoster;
                    if receiveRosterUpdate.removeContact then removeFromRoster;
                    else processRosterUpdates;
                action addToRoster {
                    in contactJID : JabberID;
                }
                then processRosterUpdates;
                action removeFromRoster {
                    in contactJID : JabberID;
                }
                then processRosterUpdates;
            }
        }
    }
    
    part def XMPPServer {
        attribute domain : String;
        attribute maxConnections : Integer;
        attribute activeConnections : Integer;
        attribute messageQueueSize : Integer;
        
        port serverPorts : XMPPServerPort[*];
        
        part connectionManager {
            attribute managerMaxConnections : Integer;
            attribute managerActiveConnections : Integer;
            
            perform action manageConnections {
                first start;
                then merge monitorConnections;
                then action checkConnectionRequest {
                    out canAccept : Boolean;
                }
                then decide;
                    if checkConnectionRequest.canAccept then acceptConnection;
                    else rejectConnection;
                action acceptConnection {
                    out sessionID : String;
                }
                then action incrementActiveConnections;
                then monitorConnections;
                action rejectConnection;
                then monitorConnections;
            }
        }
        
        part routingEngine {
            perform action routeStanzas {
                first start;
                then merge receiveStanza;
                then action getIncomingStanza {
                    out stanza : XMLStanza;
                }
                then action parseRecipient {
                    in stanzaToParse : XMLStanza;
                    out recipientJID : JabberID;
                }
                then action lookupRecipient {
                    in jid : JabberID;
                    out found : Boolean;
                    out isLocal : Boolean;
                }
                then decide;
                    if lookupRecipient.found and lookupRecipient.isLocal then deliverLocal;
                    if lookupRecipient.found and not lookupRecipient.isLocal then forwardRemote;
                    else returnError;
                action deliverLocal {
                    in stanzaToDeliver : XMLStanza;
                    in recipient : JabberID;
                }
                then receiveStanza;
                action forwardRemote {
                    in stanzaToForward : XMLStanza;
                    in remoteDomain : String;
                }
                then receiveStanza;
                action returnError {
                    in originalStanza : XMLStanza;
                }
                then receiveStanza;
            }
        }
        
        part sessionManager {
            attribute activeSessions : Integer;
            
            perform action manageSessions {
                first start;
                then merge monitorSessions;
                then action checkSessionActivity {
                    out sessionTimeout : Boolean;
                }
                then action updateSessionState;
                then decide;
                    if checkSessionActivity.sessionTimeout then terminateSession;
                    else monitorSessions;
                action terminateSession {
                    in sessionID : String;
                }
                then action cleanupSession;
                then monitorSessions;
            }
        }
        
        part presenceAggregator {
            attribute presenceCache : PresenceStanza[*];
            
            perform action aggregatePresence {
                first start;
                then merge collectPresence;
                then action receivePresenceUpdate {
                    out presence : PresenceStanza;
                }
                then action updatePresenceCache {
                    in presenceToCache : PresenceStanza;
                }
                then action determineSubscribers {
                    in presenceToDistribute : PresenceStanza;
                    out subscribers : JabberID[*];
                }
                then action notifySubscribers {
                    in presenceToNotify : PresenceStanza;
                    in subscriberList : JabberID[*];
                }
                then collectPresence;
            }
        }
        
        part offlineStorage {
            attribute offlineMessages : MessageStanza[*];
            attribute storageCapacity : Integer;
            
            perform action manageOfflineMessages {
                first start;
                then merge handleStorage;
                then action checkRecipientStatus {
                    in recipientJID : JabberID;
                    out isOnline : Boolean;
                }
                then decide;
                    if checkRecipientStatus.isOnline then deliverImmediately;
                    else storeMessage;
                action deliverImmediately {
                    in messageToDeliver : MessageStanza;
                }
                then handleStorage;
                action storeMessage {
                    in messageToStore : MessageStanza;
                }
                then action checkStorageLimit;
                then handleStorage;
            }
        }
    }
    
    connection def XMPPConnection {
        end clientEnd : XMPPClientPort;
        end serverEnd : XMPPServerPort;
    }
    
    part def XMPPNetwork {
        attribute networkLatency : Time;
        
        part centralServer : XMPPServer {
            attribute :>> domain = "messaging.example.com";
            attribute :>> maxConnections = 10000;
            attribute :>> activeConnections = 0;
            attribute :>> messageQueueSize = 5000;
        }
        
        part client1 : XMPPClient {
            attribute :>> jid = "alice@messaging.example.com";
            attribute :>> resource = "desktop";
            attribute :>> connectionStatus = ConnectionStatus::disconnected;
            attribute :>> currentPresence = PresenceState::available;
        }
        
        part client2 : XMPPClient {
            attribute :>> jid = "bob@messaging.example.com";
            attribute :>> resource = "mobile";
            attribute :>> connectionStatus = ConnectionStatus::disconnected;
            attribute :>> currentPresence = PresenceState::available;
        }
        
        part client3 : XMPPClient {
            attribute :>> jid = "charlie@messaging.example.com";
            attribute :>> resource = "laptop";
            attribute :>> connectionStatus = ConnectionStatus::disconnected;
            attribute :>> currentPresence = PresenceState::away;
        }
        
        connection conn1 : XMPPConnection connect client1.clientPort to centralServer.serverPorts;
        connection conn2 : XMPPConnection connect client2.clientPort to centralServer.serverPorts;
        connection conn3 : XMPPConnection connect client3.clientPort to centralServer.serverPorts;
        
        perform action operateNetwork {
            first start;
            then action initializeServer {
                out serverReady : Boolean;
            }
            then merge processNetworkActivity;
            then action handleClientConnections;
            then action routeMessages;
            then action synchronizePresence;
            then processNetworkActivity;
        }
    }
    
    constraint def LatencyConstraint {
        in endToEndLatency : Time;
        in maxLatency : Time;
        endToEndLatency <= maxLatency
    }
    
    constraint def ConnectionCapacity {
        in active : Integer;
        in maximum : Integer;
        active <= maximum
    }
    
    requirement <'REQ-XMPP-001'> realTimeMessaging {
        doc /* The XMPP system shall provide real-time bidirectional exchange 
             * of XML-formatted messages between clients through a centralized 
             * server infrastructure using the Extensible Messaging and Presence Protocol.
             */
        subject network : XMPPNetwork;
        
        require <'REQ-XMPP-002'> messageRouting;
        require <'REQ-XMPP-003'> presenceDistribution;
        require <'REQ-XMPP-004'> connectionManagement;
        require <'REQ-XMPP-005'> offlineMessageStorage;
    }
    
    requirement <'REQ-XMPP-002'> messageRouting {
        doc /* The server shall route message stanzas from sender to recipient 
             * based on Jabber ID addressing with support for both local and 
             * remote domain delivery.
             */
        subject server :>> XMPPNetwork::centralServer;
        
        assert constraint {
            server.routingEngine != null
        }
    }
    
    requirement <'REQ-XMPP-003'> presenceDistribution {
        doc /* The system shall track and distribute presence information for 
             * all connected clients to their authorized subscribers in real-time.
             */
        subject server :>> XMPPNetwork::centralServer;
        
        assert constraint {
            server.presenceAggregator != null
        }
    }
    
    requirement <'REQ-XMPP-004'> connectionManagement {
        doc /* Each client shall maintain persistent XML stream connection state 
             * with automatic session management and reconnection capability.
             */
        subject client : XMPPClient;
        
        assert constraint {
            client.streamManager != null and
            client.connectionStatus != null
        }
    }
    
    requirement <'REQ-XMPP-005'> offlineMessageStorage {
        doc /* The server shall store messages for offline recipients and deliver 
             * them upon recipient reconnection.
             */
        subject server :>> XMPPNetwork::centralServer;
        
        assert constraint {
            server.offlineStorage != null and
            server.offlineStorage.storageCapacity > 0
        }
    }
    
    requirement <'REQ-XMPP-006'> scalability {
        doc /* The server shall support concurrent client connections up to the 
             * configured maximum connection limit without degradation.
             */
        subject server :>> XMPPNetwork::centralServer;
        
        assert constraint capacityLimit : ConnectionCapacity {
            in active = server.activeConnections;
            in maximum = server.maxConnections;
        }
    }
    
    requirement <'REQ-XMPP-007'> latencyPerformance {
        doc /* End-to-end message delivery latency shall not exceed 500 milliseconds 
             * under normal network conditions.
             */
        subject network : XMPPNetwork;
        
        assert constraint latencyLimit : LatencyConstraint {
            in endToEndLatency = network.networkLatency;
            in maxLatency = 0.5 [s];
        }
    }
    
    satisfy realTimeMessaging by XMPPNetwork::network;
}
