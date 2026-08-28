package MQTT_Messaging_System {
import ScalarValues::*;

doc /*
MQTT Messaging System - A communication network for asynchronous,
publish-subscribe messaging between distributed IoT devices.
Provides Quality of Service levels, retained messages, and
topic-based routing through a central message broker.
*/;

// ============================================================
// Value Types and Units
// ============================================================

value def DataSize :> Real;
unit byte;

value def TimeValue :> Real;
unit second;

value def DataRate :> Real;
unit bytesPerSecond;

// ============================================================
// Enumerations
// ============================================================

enum QoSLevel {
AtMostOnce;
AtLeastOnce;
ExactlyOnce;
}

enum ClientStatus {
Disconnected;
Connecting;
Connected;
Reconnecting;
Error;
}

enum DeliveryStatus {
Pending;
Delivered;
Failed;
}

// ============================================================
// Item Definitions
// ============================================================

item def Payload {
attribute content : String;
attribute size : DataSize;
}

item def Message {
attribute id : Integer;
attribute topic : String;
attribute payload : Payload;
attribute qos : QoSLevel;
attribute retained : Boolean;
attribute timestamp : TimeValue;
}

item def Subscription {
attribute id : Integer;
attribute topic : String;
attribute requestedQoS : QoSLevel;
}

item def Unsubscription {
attribute topic : String;
}

item def PublishAck {
attribute messageId : Integer;
}

item def PubRec {
attribute messageId : Integer;
}

item def PubRel {
attribute messageId : Integer;
}

item def PubComp {
attribute messageId : Integer;
}

// ============================================================
// Port Definitions
// ============================================================

port def ClientPort {
out publishMessages : Message;
out subscribeRequests : Subscription;
out unsubscribeRequests : Unsubscription;
out pubackMessages : PublishAck;
out pubrecMessages : PubRec;
out pubrelMessages : PubRel;
out pubcompMessages : PubComp;
in deliveredMessages : Message;
in brokerPubacks : PublishAck;
in brokerPubrecs : PubRec;
in brokerPubrels : PubRel;
in brokerPubcomps : PubComp;
}

port def BrokerPort {
in publishMessages : Message;
in subscribeRequests : Subscription;
in unsubscribeRequests : Unsubscription;
in pubackMessages : PublishAck;
in pubrecMessages : PubRec;
in pubrelMessages : PubRel;
in pubcompMessages : PubComp;
out deliveredMessages : Message;
out brokerPubacks : PublishAck;
out brokerPubrecs : PubRec;
out brokerPubrels : PubRel;
out brokerPubcomps : PubComp;
}

// ============================================================
// Part Definitions
// ============================================================

part def MQTTClient {
port mqttPort : ClientPort;

attribute clientId : String;
attribute brokerHost : String;
attribute brokerPortNum : Integer = 1883;
attribute keepAlive : TimeValue = 60;
attribute status : ClientStatus = ClientStatus::Disconnected;

state def ConnectionState {
state Disconnected;
state Connecting;
state Connected;
state Reconnecting;
state Error;

transition from Disconnected to Connecting on trigger initiateConnection;
transition from Connecting to Connected on trigger connAck;
transition from Connecting to Error on trigger connFail;
transition from Connected to Reconnecting on trigger connectionLost;
transition from Reconnecting to Connected on trigger reconnected;
transition from Reconnecting to Error on trigger reconnectFail;
transition from Connected to Disconnected on trigger disconnect;
transition from Error to Disconnected on trigger reset;
}

action def connectToBroker;
action def disconnectFromBroker;
action def sendPingRequest;
}

part def Publisher :> MQTTClient {
attribute publishedCount : Integer = 0;
attribute pendingAcks : Integer = 0;

action def publish {
in topic : String;
in payload : Payload;
in qos : QoSLevel;
out result : Message;
}

action def sendPublishPacket;
action def sendPubRelPacket;
action def handlePuback;
action def handlePubrec;
action def handlePubcomp;

// QoS 0: fire and forget - no acknowledgment required
state def QoS0Publish {
state Publish;
state Done;
transition from Publish to Done;
}

// QoS 1: at least once - guaranteed delivery, possible duplicates
state def QoS1Publish {
state Publish;
state WaitForAck;
state Done;
transition from Publish to WaitForAck;
transition from WaitForAck to Done on trigger pubackReceived;
transition from WaitForAck to Publish on trigger retry;
}

// QoS 2: exactly once - guaranteed delivery, no duplicates
state def QoS2Publish {
state Publish;
state WaitForRec;
state SendRelease;
state WaitForComp;
state Done;
transition from Publish to WaitForRec;
transition from WaitForRec to SendRelease on trigger pubrecReceived;
transition from WaitForRec to Publish on trigger retry;
transition from SendRelease to WaitForComp;
transition from WaitForComp to Done on trigger pubcompReceived;
transition from WaitForComp to SendRelease on trigger retry;
}
}

part def Subscriber :> MQTTClient {
attribute subscribedCount : Integer = 0;
attribute receivedCount : Integer = 0;
attribute activeTopics[*] : String;

action def subscribe {
in topic : String;
in qos : QoSLevel;
}

action def unsubscribe {
in topic : String;
}

action def handleMessage {
in msg : Message;
}

action def sendPuback {
in messageId : Integer;
}

action def sendPubrec {
in messageId : Integer;
}

action def sendPubcompToBroker {
in messageId : Integer;
}

// Message reception lifecycle
state def MessageReceive {
state Idle;
state Receiving;
state Processing;
state Acknowledged;
transition from Idle to Receiving on trigger messageReceived;
transition from Receiving to Processing;
transition from Processing to Acknowledged;
transition from Acknowledged to Idle;
}
}

part def MessageBroker {
port clientConnections[*] : BrokerPort;

attribute brokerId : String;
attribute messageCount : Integer = 0;
item retainedMessages[*] : Message;
item activeSubscriptions[*] : Subscription;

action def routeMessage {
in msg : Message;
}

action def storeRetained {
in msg : Message;
}

action def handleSubscription {
in sub : Subscription;
}

action def handleUnsubscription {
in unsub : Unsubscription;
}

action def sendPubackToClient {
in messageId : Integer;
}

action def sendPubrecToClient {
in messageId : Integer;
}

action def sendPubcompToClient {
in messageId : Integer;
}

action def processPubrel {
in messageId : Integer;
}

action def checkTopicMatch {
in topic : String;
in subTopic : String;
out isMatch : Boolean;
}

action def deliverRetainedMessage {
in sub : Subscription;
}

// Broker message processing lifecycle
state def BrokerOperation {
state Idle;
state Receiving;
state Validating;
state Storing;
state Routing;
state Acknowledging;
transition from Idle to Receiving on trigger messageReceived;
transition from Receiving to Validating;
transition from Validating to Storing;
transition from Storing to Routing;
transition from Routing to Acknowledging;
transition from Acknowledging to Idle;
}

// Subscription handling lifecycle
state def SubscriptionHandling {
state WaitingForSubscription;
state ProcessingSubscription;
state CheckingRetained;
state SendingRetained;
state SubscriptionComplete;
transition from WaitingForSubscription to ProcessingSubscription on trigger subscribeReceived;
transition from ProcessingSubscription to CheckingRetained;
transition from CheckingRetained to SendingRetained on trigger retainedFound;
transition from CheckingRetained to SubscriptionComplete on trigger noRetained;
transition from SendingRetained to SubscriptionComplete;
transition from SubscriptionComplete to WaitingForSubscription;
}
}

// ============================================================
// Connection Definition
// ============================================================

connection def MQTTLink {
end clientSide : ClientPort;
end brokerSide : BrokerPort;
}

// ============================================================
// System Definition
// ============================================================

part def MQTTSystem {
part broker : MessageBroker;
part publishers[*] : Publisher;
part subscribers[*] : Subscriber;

// Connect all publishers to the broker
connection connect publishers[*].mqttPort to broker.clientConnections[*];

// Connect all subscribers to the broker
connection connect subscribers[*].mqttPort to broker.clientConnections[*];
}

// ============================================================
// Requirements
// ============================================================

requirement def BrokerRoutingRequirement {
doc /* The broker shall route messages from publishers to all subscribers registered for the matching topic. */;
subject broker : MessageBroker;
}

requirement def QoSSupportRequirement {
doc /* The system shall support three QoS levels: at most once, at least once, and exactly once with appropriate acknowledgements. */;
subject msg : Message;
constraint validQoS {
msg.qos == QoSLevel::AtMostOnce
or msg.qos == QoSLevel::AtLeastOnce
or msg.qos == QoSLevel::ExactlyOnce
}
}

requirement def RetainedMessageRequirement {
doc /* The broker shall store the last retained message per topic and forward it to new subscribers upon subscription. */;
subject broker : MessageBroker;
subject sub : Subscriber;
}

requirement def DecoupledCommunicationRequirement {
doc /* Publishers and subscribers shall communicate without direct knowledge of each other, mediated by the central broker. */;
subject mqttSystem : MQTTSystem;
}

requirement def AsynchronousMessagingRequirement {
doc /* Messages shall be delivered asynchronously between publishers and subscribers via the broker without requiring direct connections. */;
subject broker : MessageBroker;
}

requirement def QoS0FireAndForgetRequirement {
doc /* QoS level AtMostOnce shall deliver messages with no acknowledgment, accepting potential message loss. */;
subject publisher : Publisher;
constraint qos0NoAck {
publisher.QoS0Publish.Publish == Done
}
}

requirement def QoS1AtLeastOnceRequirement {
doc /* QoS level AtLeastOnce shall guarantee message delivery using PUBACK acknowledgments, permitting possible duplicates. */;
subject publisher : Publisher;
}

requirement def QoS2ExactlyOnceRequirement {
doc /* QoS level ExactlyOnce shall guarantee message delivery with no duplicates using a four-step PUBREC, PUBREL, PUBCOMP handshake. */;
subject publisher : Publisher;
}
}
