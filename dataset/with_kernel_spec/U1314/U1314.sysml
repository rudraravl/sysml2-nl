package SMSCommunicationSystem {
    private import ScalarValues::String;
    private import ScalarValues::Integer;
    private import ScalarValues::Boolean;
    private import ScalarValues::Real;

    package Definitions {
        enum def Priority {
            normal;
            high;
            urgent;
        }

        enum def MessageStatus {
            pending;
            validated;
            queued;
            transmitting;
            delivered;
            failed;
            received;
        }

        item def SMSMessage {
            attribute id : String;
            attribute sender : String;
            attribute recipient : String;
            attribute content : String;
            attribute priority : Priority = Priority::normal;
            attribute status : MessageStatus = MessageStatus::pending;
            attribute sentAt : Real;
            attribute deliveredAt : Real;
        }

        item def DeliveryReceipt {
            attribute messageId : String;
            attribute delivered : Boolean;
            attribute latency : Real;
            attribute retryCount : Integer = 0;
        }

        attribute def EnqueueSignal;
        attribute def TransmitSignal;
        attribute def DeliveredSignal;
        attribute def FailureSignal;
        attribute def RetrySignal;
        attribute def MaxRetriesExceededSignal;

        port def MessagePort {
            in ref msg : SMSMessage;
        }

        port def ReceiptPort {
            in ref rcpt : DeliveryReceipt;
        }

        interface def MessageTransfer {
            end source : ~MessagePort;
            end target : MessagePort;
        }

        interface def ReceiptTransfer {
            end source : ~ReceiptPort;
            end target : ReceiptPort;
        }

        action def ValidateMessage {
            in ref msg : SMSMessage;
            out ref validatedMsg : SMSMessage;
            out attribute isValid : Boolean;
        }

        action def StoreMessage {
            in ref msg : SMSMessage;
            out ref storedMsg : SMSMessage;
        }

        action def EnqueueMessage {
            in ref msg : SMSMessage;
            out ref queuedMsg : SMSMessage;
        }

        action def DequeueMessage {
            in ref queuedMsg : SMSMessage;
            out ref msg : SMSMessage;
        }

        action def RouteMessage {
            in ref msg : SMSMessage;
            out ref routedMsg : SMSMessage;
            out attribute operatorId : String;
        }

        action def TransmitMessage {
            in ref msg : SMSMessage;
            out ref rcpt : DeliveryReceipt;
        }

        action def ReceiveMessage {
            in ref msg : SMSMessage;
            out ref receivedMsg : SMSMessage;
        }

        state def MessageLifecycleStates {
            entry; then pending;
            state pending;
            accept EnqueueSignal then queued;
            state queued;
            accept TransmitSignal then transmitting;
            state transmitting;
            accept DeliveredSignal then delivered;
            accept FailureSignal then retry;
            state delivered;
            state retry;
            accept RetrySignal then transmitting;
            accept MaxRetriesExceededSignal then failed;
            state failed;
        }

        part def ValidationModule {
            port msgIn : MessagePort {
                in ref :>> msg;
            }
            port validatedMsgOut : ~MessagePort {
                out ref :>> msg;
            }
            perform action validateMsg : ValidateMessage {
                in ref msg = msgIn.msg;
                out ref validatedMsg = validatedMsgOut.msg;
            }
        }

        part def StorageSystem {
            port validatedMsgIn : MessagePort {
                in ref :>> msg;
            }
            port receivedMsgIn : MessagePort {
                in ref :>> msg;
            }
            port storedMsgOut : ~MessagePort {
                out ref :>> msg;
            }
            port deliveredMsgOut : ~MessagePort {
                out ref :>> msg;
            }
            port receiptIn : ReceiptPort {
                in ref :>> rcpt;
            }
            item msgArchive : SMSMessage[0..*];
            item receiptArchive : DeliveryReceipt[0..*];
            perform action storeValidatedMsg : StoreMessage {
                in ref msg = validatedMsgIn.msg;
                out ref storedMsg = storedMsgOut.msg;
            }
            perform action storeReceivedMsg : StoreMessage {
                in ref msg = receivedMsgIn.msg;
                out ref storedMsg = deliveredMsgOut.msg;
            }
            flow from storeValidatedMsg.storedMsg to msgArchive;
            flow from storeReceivedMsg.storedMsg to msgArchive;
            flow from receiptIn.rcpt to receiptArchive;
        }

        part def MessageQueue {
            port inbound : MessagePort {
                in ref :>> msg;
            }
            port outbound : ~MessagePort {
                out ref :>> msg;
            }
            item queuedMsgs : SMSMessage[0..*];
            attribute queueDepth : Integer = 0;
            perform action enqueueMsg : EnqueueMessage {
                in ref msg = inbound.msg;
                out ref queuedMsg;
            }
            perform action dequeueMsg : DequeueMessage {
                in ref queuedMsg;
                out ref msg = outbound.msg;
            }
            flow from enqueueMsg.queuedMsg to queuedMsgs;
            flow from queuedMsgs to dequeueMsg.queuedMsg;
        }

        part def RoutingComponent {
            port inbound : MessagePort {
                in ref :>> msg;
            }
            port routedOut : ~MessagePort {
                out ref :>> msg;
            }
            perform action routeMsg : RouteMessage {
                in ref msg = inbound.msg;
                out ref routedMsg = routedOut.msg;
            }
        }

        part def NetworkTransceiver {
            port transmitIn : MessagePort {
                in ref :>> msg;
            }
            port cellularIn : MessagePort {
                in ref :>> msg;
            }
            port receiveOut : ~MessagePort {
                out ref :>> msg;
            }
            port receiptOut : ~ReceiptPort {
                out ref :>> rcpt;
            }
            attribute signalStrength : Real;
            attribute maxRetries : Integer = 3;
            attribute currentRetryCount : Integer = 0;
            perform action transmitMsg : TransmitMessage {
                in ref msg = transmitIn.msg;
                out ref rcpt = receiptOut.rcpt;
            }
            perform action receiveMsg : ReceiveMessage {
                in ref msg = cellularIn.msg;
                out ref receivedMsg = receiveOut.msg;
            }
        }

        part def ApplicationEndpoint {
            port msgOut : ~MessagePort {
                out ref :>> msg;
            }
            port msgIn : MessagePort {
                in ref :>> msg;
            }
        }
    }

    package Usages {
        part smsSystem {
            part application : Definitions::ApplicationEndpoint;
            part validationModule : Definitions::ValidationModule;
            part storageSystem : Definitions::StorageSystem;
            part messageQueue : Definitions::MessageQueue;
            part routingComponent : Definitions::RoutingComponent;
            part networkTransceiver : Definitions::NetworkTransceiver;

            state msgLifecycle : Definitions::MessageLifecycleStates;

            interface appToValidation : Definitions::MessageTransfer
                connect application.msgOut to validationModule.msgIn;

            interface validationToStorage : Definitions::MessageTransfer
                connect validationModule.validatedMsgOut to storageSystem.validatedMsgIn;

            interface storageToQueue : Definitions::MessageTransfer
                connect storageSystem.storedMsgOut to messageQueue.inbound;

            interface queueToRouting : Definitions::MessageTransfer
                connect messageQueue.outbound to routingComponent.inbound;

            interface routingToTransceiver : Definitions::MessageTransfer
                connect routingComponent.routedOut to networkTransceiver.transmitIn;

            interface transceiverToStorage : Definitions::MessageTransfer
                connect networkTransceiver.receiveOut to storageSystem.receivedMsgIn;

            interface storageToApplication : Definitions::MessageTransfer
                connect storageSystem.deliveredMsgOut to application.msgIn;

            interface transceiverReceiptToStorage : Definitions::ReceiptTransfer
                connect networkTransceiver.receiptOut to storageSystem.receiptIn;
        }
    }

    package Requirements {
        requirement def FastDelivery {
            /* Messages shall be delivered within 3000 ms under normal network conditions. */
            attribute maxDeliveryTime : Real = 3000;
        }

        requirement def HighReliability {
            /* The system shall handle at least 100 messages per second with less than 0.1 percent failure rate. */
            attribute minThroughput : Real = 100;
            attribute maxFailureRate : Real = 0.001;
        }

        requirement def PersistentStorage {
            /* All sent and received messages shall be archived in persistent storage. */
        }

        requirement def ValidationRequirement {
            /* The system shall validate recipient phone number format and message content before processing. */
        }

        requirement def PriorityQueueing {
            /* The message queue shall organize outgoing messages by priority: normal, high, or urgent. */
        }

        requirement def RetryOnFailure {
            /* The system shall retry failed transmissions up to a maximum of 3 attempts. */
            attribute maxRetries : Integer = 3;
        }

        requirement fastDeliveryReq : FastDelivery;
        requirement highReliabilityReq : HighReliability;
        requirement persistentStorageReq : PersistentStorage;
        requirement validationReq : ValidationRequirement;
        requirement priorityQueueingReq : PriorityQueueing;
        requirement retryOnFailureReq : RetryOnFailure;
    }
}
