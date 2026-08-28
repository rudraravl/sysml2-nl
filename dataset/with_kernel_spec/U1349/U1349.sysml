package MQTT_Messaging_System {
    private import ScalarValues::*;
    
    package Definitions {
        enum def QoS_Level {
            enum AtMostOnce = 0;
            enum AtLeastOnce = 1;
            enum ExactlyOnce = 2;
        }
        
        item def Payload {
            attribute data : String;
        }
        
        item def MQTT_Message {
            attribute topic : String;
            ref payload : Payload;
            attribute qos : QoS_Level;
            attribute retained : Boolean;
            attribute packetId : Integer;
        }
        
        item def Subscribe_Request {
            attribute topic : String;
            attribute qos : QoS_Level;
            attribute packetId : Integer;
        }
        
        item def Unsubscribe_Request {
            attribute topic : String;
        }
        
        item def Publish_Request {
            ref msg : MQTT_Message;
        }
        
        item def Deliver_Message {
            ref msg : MQTT_Message;
        }
        
        item def Ack {
            attribute packetId : Integer;
            attribute ackType : String;
        }
    }
    
    package Ports_and_Interfaces {
        private import Definitions::*;
        
        port def BrokerPort {
            in ref publish : Publish_Request;
            in ref subscribe : Subscribe_Request;
            in ref unsubscribe : Unsubscribe_Request;
            in ref ack : Ack;
            out ref deliver : Deliver_Message;
            out ref ackOut : Ack;
        }
        
        port def ClientPort {
            out ref publish : Publish_Request;
            out ref subscribe : Subscribe_Request;
            out ref unsubscribe : Unsubscribe_Request;
            out ref ack : Ack;
            in ref deliver : Deliver_Message;
            in ref ackIn : Ack;
        }
        
        interface def ClientBrokerInterface {
            end client : ~ClientPort;
            end broker : BrokerPort;
        }
    }
    
    package Components {
        private import Definitions::*;
        private import Ports_and_Interfaces::*;
        
        part def MQTT_Broker {
            port brokerPort[1..*] : BrokerPort;
            
            attribute retainedMessages : MQTT_Message[0..*];
            
            flow publishFlow from brokerPort.publish to brokerBehavior.handlePublish.request;
            flow subscribeFlow from brokerPort.subscribe to brokerBehavior.handleSubscribe.request;
            flow unsubscribeFlow from brokerPort.unsubscribe to brokerBehavior.handleUnsubscribe.request;
            flow ackFlow from brokerPort.ack to brokerBehavior.handleAck.request;
            flow deliverFlow from brokerBehavior.handleDeliver.response to brokerPort.deliver;
            flow ackOutFlow from brokerBehavior.handleAck.response to brokerPort.ackOut;
            
            perform action brokerBehavior {
                action handleSubscribe {
                    in ref request : Subscribe_Request[1];
                    out ref response : Ack[1];
                    out ref deliver : Deliver_Message[0..1];
                }
                then merge continueProcessing;
                
                then action handlePublish {
                    in ref request : Publish_Request[1];
                    out ref response : Ack[0..1];
                    out ref deliver : Deliver_Message[0..*];
                }
                then continueProcessing;
                
                then action handleUnsubscribe {
                    in ref request : Unsubscribe_Request[1];
                }
                then continueProcessing;
                
                then action handleAck {
                    in ref request : Ack[1];
                    out ref response : Ack[0..1];
                }
                then continueProcessing;
                
                then action handleDeliver {
                    in ref msg : MQTT_Message[1];
                    out ref response : Deliver_Message[1];
                }
                then continueProcessing;
            }
        }
        
        part def Publisher {
            port clientPort : ClientPort;
            
            flow publishFlow from publisherBehavior.publish.request to clientPort.publish;
            flow ackInFlow from clientPort.ackIn to publisherBehavior.handleAck.ack;
            
            perform action publisherBehavior {
                action publish {
                    out ref request : Publish_Request[1];
                }
                then action handleAck {
                    in ref ack : Ack[1];
                }
            }
        }
        
        part def Subscriber {
            port clientPort : ClientPort;
            
            flow subscribeFlow from subscriberBehavior.subscribe.request to clientPort.subscribe;
            flow deliverFlow from clientPort.deliver to subscriberBehavior.handleDeliver.msg;
            flow ackFlow from subscriberBehavior.sendAck.ack to clientPort.ack;
            
            perform action subscriberBehavior {
                action subscribe {
                    out ref request : Subscribe_Request[1];
                }
                then action handleDeliver {
                    in ref msg : Deliver_Message[1];
                }
                then action sendAck {
                    out ref ack : Ack[1];
                }
            }
        }
    }
    
    package System {
        private import Components::*;
        private import Ports_and_Interfaces::*;
        
        part def MQTT_System {
            part broker : MQTT_Broker;
            part publishers[1..*] : Publisher;
            part subscribers[1..*] : Subscriber;
            
            interface pubInterface : ClientBrokerInterface connect publishers.clientPort to broker.brokerPort;
            interface subInterface : ClientBrokerInterface connect subscribers.clientPort to broker.brokerPort;
        }
    }
    
    package Requirements {
        requirement def MQTT_Requirements {
            requirement BrokerRoutingRequirement {
                doc /* The broker shall route messages to subscribers based on topic. */
            }
            requirement QoSRequirement {
                doc /* The system shall support QoS levels 0, 1, and 2. */
            }
            requirement RetainedMessagesRequirement {
                doc /* The broker shall store and forward retained messages. */
            }
            requirement DecouplingRequirement {
                doc /* Publishers and subscribers shall interact exclusively through the central broker. */
            }
        }
    }
}
