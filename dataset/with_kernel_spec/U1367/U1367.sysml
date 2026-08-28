package XmppMessagingSystem {
    private import ScalarValues::*;

    package Types {
        value type Latency :> Real;
        value type ConnectionCount :> Integer;
        value type Throughput :> Real;

        item def JID {
            attribute node : String[0..1];
            attribute domain : String[1];
            attribute resource : String[0..1];
        }

        item def XmlStanza {
            attribute sender : JID[0..1];
            attribute recipient : JID[0..1];
            attribute id : String[0..1];
        }

        enum def MessageType { chat; groupchat; normal; headline; error; }
        enum def PresenceType { available; unavailable; subscribe; subscribed; unsubscribe; unsubscribed; probe; error; }
        enum def PresenceShow { away; chat; dnd; xa; }
        enum def IqType { get; set; result; error; }
        enum def SubscriptionType { none; 'to'; 'from'; both; }

        item def MessageStanza :> XmlStanza {
            attribute type : MessageType;
            attribute body : String;
        }

        item def PresenceStanza :> XmlStanza {
            attribute type : PresenceType;
            attribute show : PresenceShow[0..1];
            attribute status : String[0..1];
        }

        item def IqStanza :> XmlStanza {
            attribute type : IqType;
        }

        item def ConnectionRequest {
            attribute username : String;
            attribute password : String;
            attribute resource : String;
        }

        item def ConnectionResponse {
            attribute accepted : Boolean;
            attribute sessionId : String[0..1];
            attribute reason : String[0..1];
        }

        item def RosterItem {
            attribute jid : JID;
            attribute name : String[0..1];
            attribute subscription : SubscriptionType;
        }

        item def DeliveryReceipt {
            attribute stanzaId : String;
            attribute delivered : Boolean;
        }
    }

    package Ports {
        private import Types::*;

        port def ClientServerPort {
            in ref connectRequest : ConnectionRequest;
            out ref connectResponse : ConnectionResponse;
            in ref stanzaIn : XmlStanza;
            out ref stanzaOut : XmlStanza;
            in ref presenceIn : PresenceStanza;
            out ref presenceOut : PresenceStanza;
        }

        port def InterServerPort {
            in ref federatedIn : XmlStanza;
            out ref federatedOut : XmlStanza;
            in ref presenceProbeIn : PresenceStanza;
            out ref presenceProbeOut : PresenceStanza;
        }

        port def InternalStanzaPort {
            in ref inbound : XmlStanza;
            out ref outbound : XmlStanza;
        }

        port def InternalPresencePort {
            in ref presenceUpdate : PresenceStanza;
            out ref presenceDistribution : PresenceStanza;
        }

        interface def ClientServerInterface {
            end client : ~ClientServerPort;
            end server : ClientServerPort;
        }

        interface def InterServerInterface {
            end local : ~InterServerPort;
            end remote : InterServerPort;
        }

        interface def InternalStanzaInterface {
            end source : ~InternalStanzaPort;
            end target : InternalStanzaPort;
        }

        interface def InternalPresenceInterface {
            end source : ~InternalPresencePort;
            end target : InternalPresencePort;
        }
    }

    package Components {
        private import Types::*;
        private import Ports::*;

        part def ConnectionManager {
            attribute maxConnections : ConnectionCount = 10000;
            attribute activeConnections : ConnectionCount = 0;
            port stanzaPort : ~InternalStanzaPort;
            port requestIn : ~ClientServerPort;
            port responseOut : ~ClientServerPort;

            perform action handleConnection {
                action accept {
                    in ref request : ConnectionRequest[1];
                    out ref response : ConnectionResponse;
                }
            }
        }

        part def RoutingEngine {
            attribute localDomain : String;
            port inboundPort : InternalStanzaPort;
            port localOutbound : InternalStanzaPort;
            port federatedPort : InterServerPort;
            port presencePort : ~InternalPresencePort;

            perform action route {
                action inspect {
                    in ref stanza : XmlStanza[1];
                    out ref delivered : XmlStanza[1] = stanza;
                }
                then merge continueRouting;
            }
        }

        part def OfflineStorage {
            port storagePort : ~InternalStanzaPort;
            attribute pendingMessages : MessageStanza[*] nonunique;

            perform action persist {
                action save {
                    in ref message : MessageStanza[1];
                }
                then action deliverOnReconnect {
                    in ref user : JID[1];
                    out ref messages : MessageStanza[*];
                }
                then merge continueStorage;
            }
        }

        part def PresenceAggregator {
            port presencePort : InternalPresencePort;
            attribute subscribedContacts : JID[*] nonunique;

            perform action aggregate {
                action collect {
                    in ref update : PresenceStanza[1];
                    out ref passedUpdate : PresenceStanza[1] = update;
                }
                then action broadcast {
                    in ref update : PresenceStanza[1] = collect.passedUpdate;
                    out ref distribution : PresenceStanza[1] = update;
                }
                then merge continueAggregation;
            }
        }

        part def XmppServer {
            attribute domain : String;
            port clientFacingPort : ClientServerPort;
            port federationPort : InterServerPort;

            part connectionManager : ConnectionManager;
            part routingEngine : RoutingEngine;
            part offlineStorage : OfflineStorage;
            part presenceAggregator : PresenceAggregator;

            connect connectionManager.stanzaPort to routingEngine.inboundPort;
            flow stanzaFlow from connectionManager.stanzaPort.inbound to routingEngine.inboundPort.inbound;

            connect routingEngine.localOutbound to offlineStorage.storagePort;
            flow offlineFlow from routingEngine.localOutbound.outbound to offlineStorage.storagePort.outbound;

            connect routingEngine.presencePort to presenceAggregator.presencePort;
            flow presenceFlow from routingEngine.presencePort.presenceUpdate to presenceAggregator.presencePort.presenceUpdate;

            flow connectRequestFlow from clientFacingPort.connectRequest to connectionManager.handleConnection.accept.request;
            flow connectResponseFlow from connectionManager.handleConnection.accept.response to clientFacingPort.connectResponse;
            flow incomingStanzaFlow from clientFacingPort.stanzaIn to routingEngine.inboundPort.inbound;
            flow outgoingStanzaFlow from routingEngine.localOutbound.outbound to clientFacingPort.stanzaOut;
            flow incomingPresenceFlow from clientFacingPort.presenceIn to presenceAggregator.presencePort.presenceUpdate;
            flow outgoingPresenceFlow from presenceAggregator.presencePort.presenceDistribution to clientFacingPort.presenceOut;
            flow federatedInFlow from federationPort.federatedIn to routingEngine.federatedPort.federatedIn;
            flow federatedOutFlow from routingEngine.federatedPort.federatedOut to federationPort.federatedOut;
        }

        part def MessageHandler {
            perform action processMessage {
                action validate {
                    in ref message : XmlStanza[1];
                    out ref passedMessage : XmlStanza[1] = message;
                }
                then action display {
                    in ref message : XmlStanza[1] = validate.passedMessage;
                }
                then merge done;
            }
        }

        part def PresenceManager {
            attribute currentShow : PresenceShow;
            attribute statusText : String;

            perform action updatePresence {
                action set {
                    in ref presenceUpdate : PresenceStanza[1];
                    out ref passedUpdate : PresenceStanza[1] = presenceUpdate;
                }
                then action broadcast {
                    in ref update : PresenceStanza[1] = set.passedUpdate;
                    out ref output : PresenceStanza[1] = update;
                }
                then merge done;
            }
        }

        part def RosterManager {
            attribute items : RosterItem[*] nonunique;

            perform action manageRoster {
                action add {
                    in ref item : RosterItem[1];
                }
                then action remove {
                    in ref jid : JID[1];
                }
                then action update {
                    in ref item : RosterItem[1];
                }
                then merge done;
            }
        }

        part def XmppClient {
            attribute jid : JID;
            port serverPort : ~ClientServerPort;

            part messageHandler : MessageHandler;
            part presenceManager : PresenceManager;
            part rosterManager : RosterManager;

            state machine connectionLifecycle {
                state disconnected;
                state connecting;
                state authenticating;
                state active;
                state reconnecting;

                transition initial to disconnected;
                transition disconnected to connecting;
                transition connecting to authenticating;
                transition authenticating to active;
                transition active to reconnecting;
                transition reconnecting to connecting;
            }

            flow incomingMessageFlow from serverPort.stanzaIn to messageHandler.processMessage.validate.message;
            flow presenceBroadcastFlow from presenceManager.updatePresence.broadcast.output to serverPort.presenceOut;
            flow incomingPresenceFlow from serverPort.presenceIn to presenceManager.updatePresence.set.presenceUpdate;
        }
    }

    package System {
        private import Components::*;
        private import Ports::*;
        private import Types::*;

        part xmppNetwork {
            part localServer : XmppServer {
                attribute :>> domain = "example.com";
            }
            part remoteServer : XmppServer {
                attribute :>> domain = "remote.org";
                port :>> federationPort : ~InterServerPort;
            }
            part client1 : XmppClient {
                attribute :>> jid = new JID("alice", "example.com", "desktop");
            }
            part client2 : XmppClient {
                attribute :>> jid = new JID("bob", "example.com", "mobile");
            }

            interface conn1 : ClientServerInterface connect client1.serverPort to localServer.clientFacingPort {
                flow connectRequestFlow from conn1.client.connectRequest to conn1.server.connectRequest;
                flow connectResponseFlow from conn1.server.connectResponse to conn1.client.connectResponse;
                flow stanzaInFlow from conn1.client.stanzaIn to conn1.server.stanzaIn;
                flow stanzaOutFlow from conn1.server.stanzaOut to conn1.client.stanzaOut;
                flow presenceInFlow from conn1.client.presenceIn to conn1.server.presenceIn;
                flow presenceOutFlow from conn1.server.presenceOut to conn1.client.presenceOut;
            }
            interface conn2 : ClientServerInterface connect client2.serverPort to localServer.clientFacingPort {
                flow connectRequestFlow from conn2.client.connectRequest to conn2.server.connectRequest;
                flow connectResponseFlow from conn2.server.connectResponse to conn2.client.connectResponse;
                flow stanzaInFlow from conn2.client.stanzaIn to conn2.server.stanzaIn;
                flow stanzaOutFlow from conn2.server.stanzaOut to conn2.client.stanzaOut;
                flow presenceInFlow from conn2.client.presenceIn to conn2.server.presenceIn;
                flow presenceOutFlow from conn2.server.presenceOut to conn2.client.presenceOut;
            }
            connect localServer.federationPort to remoteServer.federationPort;
            flow federatedStanza from localServer.federationPort.federatedOut to remoteServer.federationPort.federatedOut;
            flow federatedResponse from remoteServer.federationPort.federatedIn to localServer.federationPort.federatedIn;
            flow presenceProbe from localServer.federationPort.presenceProbeOut to remoteServer.federationPort.presenceProbeOut;
            flow presenceProbeResponse from remoteServer.federationPort.presenceProbeIn to localServer.federationPort.presenceProbeIn;
        }
    }

    package Requirements {
        private import Types::*;
        private import Components::*;

        requirement def ScalabilityRequirement {
            doc "The XMPP system shall support at least 10000 concurrent users per server.";
            subject : system : XmppServer;
            constraint { system.connectionManager.maxConnections >= 10000; }
        }

        requirement def LatencyRequirement {
            doc "End-to-end message delivery latency shall not exceed 200 milliseconds under peak load.";
            subject : system : XmppServer;
            attribute maxLatency : Latency = 200;
            constraint { maxLatency <= 200; }
        }

        requirement def OfflineDeliveryRequirement {
            doc "Messages stored for offline users shall be delivered upon the user's next successful reconnection.";
            subject : storage : OfflineStorage;
        }

        requirement def PresenceDistributionRequirement {
            doc "Presence updates shall be distributed to all subscribed contacts within 500 milliseconds.";
            subject : aggregator : PresenceAggregator;
            attribute maxDistributionLatency : Latency = 500;
            constraint { maxDistributionLatency <= 500; }
        }

        requirement def FederationRequirement {
            doc "The system shall support server-to-server federation for cross-domain messaging.";
            subject : system : XmppServer;
        }

        requirement def ReliabilityRequirement {
            doc "The system shall guarantee message delivery with at-most-once semantics for chat messages.";
            subject : system : XmppServer;
        }

        package RequirementVerification {
            private import System::*;
            private import Components::*;

            requirement scalabilityCheck : ScalabilityRequirement {
                subject :>> system = xmppNetwork.localServer;
            }
            requirement latencyCheck : LatencyRequirement {
                subject :>> system = xmppNetwork.localServer;
            }
            requirement offlineCheck : OfflineDeliveryRequirement {
                subject :>> storage = xmppNetwork.localServer.offlineStorage;
            }
            requirement presenceCheck : PresenceDistributionRequirement {
                subject :>> aggregator = xmppNetwork.localServer.presenceAggregator;
            }
            requirement federationCheck : FederationRequirement {
                subject :>> system = xmppNetwork.localServer;
            }
            requirement reliabilityCheck : ReliabilityRequirement {
                subject :>> system = xmppNetwork.localServer;
            }
        }
    }
}
