package 'MQTT Messaging System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def TopicName :> String;
    attribute def MessagePayload :> String;
    attribute def ClientID :> String;
    
    enum def QoSLevel {
        atMostOnce;
        atLeastOnce;
        exactlyOnce;
    }
    
    item def MQTTMessage {
        attribute topic : TopicName;
        attribute payload : MessagePayload;
        attribute qos : QoSLevel;
        attribute retained : Boolean;
    }
    
    item def SubscriptionRequest {
        attribute topic : TopicName;
        attribute qos : QoSLevel;
    }
    
    item def PublishAcknowledgement {
        attribute messageID : Integer;
    }
    
    port def PublisherPort {
        out item outgoingMessage : MQTTMessage;
        in item ack : PublishAcknowledgement;
    }
    
    port def SubscriberPort {
        out item subscription : SubscriptionRequest;
        in item incomingMessage : MQTTMessage;
    }
    
    port def BrokerPort {
        in item receivedMessage : MQTTMessage;
        in item subscriptionReq : SubscriptionRequest;
        out item forwardedMessage : MQTTMessage;
        out item acknowledgement : PublishAcknowledgement;
    }
    
    part def Publisher {
        port publisherPort : PublisherPort;
        attribute clientID : ClientID;
        attribute connected : Boolean;
        
        action def PublishMessage {
            in messageTopic : TopicName;
            in messagePayload : MessagePayload;
            in messageQoS : QoSLevel;
            out publishedMsg : MQTTMessage;
            
            first start;
            then action createMessage {
                out msg : MQTTMessage;
            }
            then action sendMessage {
                in message : MQTTMessage = createMessage.msg;
            }
            then decide;
                if messageQoS == QoSLevel::atLeastOnce or messageQoS == QoSLevel::exactlyOnce then waitForAck;
                if messageQoS == QoSLevel::atMostOnce then done;
            
            action waitForAck {
                out ackReceived : PublishAcknowledgement;
            }
            then done;
        }
    }
    
    part def Subscriber {
        port subscriberPort : SubscriberPort;
        attribute clientID : ClientID;
        attribute subscribedTopics : TopicName[*];
        
        action def SubscribeToTopic {
            in topic : TopicName;
            in qos : QoSLevel;
            
            first start;
            then action createSubscription {
                in topicName : TopicName = topic;
                in qualityOfService : QoSLevel = qos;
                out subReq : SubscriptionRequest;
            }
            then action sendSubscription {
                in request : SubscriptionRequest = createSubscription.subReq;
            }
            then action updateTopics {
                in newTopic : TopicName = topic;
            }
            then done;
        }
        
        action def ReceiveMessages {
            first start;
            then merge waitForMessage;
            then action checkMessage {
                out hasMessage : Boolean;
            }
            then decide;
                if checkMessage.hasMessage then processMessage;
                if not checkMessage.hasMessage then waitForMessage;
            
            action processMessage {
                out msg : MQTTMessage;
            }
            then action matchTopic {
                in message : MQTTMessage = processMessage.msg;
                in topics : TopicName[*] = subscribedTopics;
                out matches : Boolean;
            }
            then decide;
                if matchTopic.matches then deliverMessage;
                if not matchTopic.matches then waitForMessage;
            
            action deliverMessage {
                in message : MQTTMessage = processMessage.msg;
            }
            then waitForMessage;
        }
    }
    
    part def MessageBroker {
        port brokerPorts : BrokerPort[*];
        attribute activeClients : ClientID[*];
        attribute topicSubscriptions : TopicName[*];
        attribute retainedMessages : MQTTMessage[*];
        
        action def RouteMessage {
            in message : MQTTMessage;
            
            first start;
            then action findSubscribers {
                in msg : MQTTMessage = message;
                in subscriptions : TopicName[*] = topicSubscriptions;
                out matchingTopics : TopicName[*];
            }
            then action forwardToSubscribers {
                in msg : MQTTMessage = message;
                in topics : TopicName[*] = findSubscribers.matchingTopics;
            }
            then action checkRetained {
                in msg : MQTTMessage = message;
                out shouldRetain : Boolean;
            }
            then decide;
                if checkRetained.shouldRetain then storeMessage;
                if not checkRetained.shouldRetain then sendAck;
            
            action storeMessage {
                in msg : MQTTMessage = message;
            }
            then sendAck;
            
            action sendAck {
                out ack : PublishAcknowledgement;
            }
            then done;
        }
        
        action def HandleSubscription {
            in subscription : SubscriptionRequest;
            
            first start;
            then action registerSubscription {
                in subReq : SubscriptionRequest = subscription;
            }
            then action sendRetainedMessages {
                in topic : TopicName = subscription.topic;
                in retained : MQTTMessage[*] = retainedMessages;
            }
            then done;
        }
    }
    
    part mqttSystem {
        part broker : MessageBroker {
            perform action routeMessages : RouteMessage[*];
            perform action handleSubs : HandleSubscription[*];
        }
        
        part publisher1 : Publisher {
            attribute :>> clientID = "pub_001";
            perform action publishMsg : PublishMessage[*];
        }
        
        part publisher2 : Publisher {
            attribute :>> clientID = "pub_002";
            perform action publishMsg : PublishMessage[*];
        }
        
        part subscriber1 : Subscriber {
            attribute :>> clientID = "sub_001";
            perform action subscribe : SubscribeToTopic[*];
            perform action receive : ReceiveMessages;
        }
        
        part subscriber2 : Subscriber {
            attribute :>> clientID = "sub_002";
            perform action subscribe : SubscribeToTopic[*];
            perform action receive : ReceiveMessages;
        }
        
        connect publisher1.publisherPort to broker.brokerPorts;
        connect publisher2.publisherPort to broker.brokerPorts;
        connect subscriber1.subscriberPort to broker.brokerPorts;
        connect subscriber2.subscriberPort to broker.brokerPorts;
    }
    
    requirement def MessageRoutingRequirement {
        doc /* The MQTT broker shall route published messages to all subscribers 
             that have subscribed to the matching topic. */
        
        subject mqttBroker : MessageBroker;
        
        require constraint topicMatching {
            doc /* Messages must be delivered only to subscribers whose topic 
                 subscriptions match the published message topic. */
        }
    }
    
    requirement def QoSDeliveryRequirement {
        doc /* The system shall support three Quality of Service levels for 
             message delivery: at most once, at least once, and exactly once. */
        
        subject system : mqttSystem;
        
        require constraint qosCompliance {
            doc /* Message delivery guarantees must conform to the specified QoS level. */
        }
    }
    
    requirement def RetainedMessageRequirement {
        doc /* The broker shall store retained messages and deliver them to 
             new subscribers upon subscription. */
        
        subject mqttBroker : MessageBroker;
        
        require constraint retentionPolicy {
            doc /* Retained messages must be stored per topic and delivered to 
                 new subscribers immediately after subscription. */
        }
    }
    
    requirement mqttSystemRequirements {
        doc /* The MQTT messaging system shall enable asynchronous publish-subscribe 
             communication between distributed clients through a central broker, 
             supporting topic-based message routing with configurable quality of 
             service guarantees. */
        
        require messageRouting : MessageRoutingRequirement;
        require qosDelivery : QoSDeliveryRequirement;
        require retainedMessages : RetainedMessageRequirement;
    }
    
    occurrence def PublishSubscribeFlow {
        ref part :>> publisher1;
        ref part :>> subscriber1;
        ref part :>> broker;
        
        message publishEvent of MQTTMessage
            from publisher1.publisherPort.outgoingMessage
            to broker.brokerPorts.receivedMessage;
        
        then message routeEvent of MQTTMessage = publishEvent
            from broker.brokerPorts.forwardedMessage
            to subscriber1.subscriberPort.incomingMessage;
        
        then message ackEvent of PublishAcknowledgement
            from broker.brokerPorts.acknowledgement
            to publisher1.publisherPort.ack;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import 'MQTT Messaging System'::*;

    action orchestrator {
        attribute testMessageTopic : TopicName = "";
        attribute testMessagePayload : MessagePayload = "";
        item testMessage : MQTTMessage {
            attribute topic : TopicName = "";
            attribute payload : MessagePayload = "";
            attribute qos = QoSLevel::atMostOnce;
            attribute retained = false;
        }
        action actionProbe : PublishMessage {
            in messageTopic = testMessageTopic;
            in messagePayload = testMessagePayload;
            in messageQoS = QoSLevel::atMostOnce;
            in message = testMessage;
        }
        first actionProbe;
    }
}
