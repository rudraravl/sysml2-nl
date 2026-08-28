package SMSCommunicationSystem {
    import ScalarValues::*;

    // Units
    unit dBm;
    unit characters;
    unit seconds;
    unit messagesPerSecond;

    // Value types
    value type SignalStrength :> Real { unit dBm; }
    value type MessageLength :> Integer { unit characters; }
    value type DeliveryTime :> Real { unit seconds; }
    value type Throughput :> Real { unit messagesPerSecond; }
    value type RetryCount :> Integer;

    // Enumerations
    enum def PriorityLevel { normal; high; urgent; }
    enum def MessageStatus { validated; queued; transmitting; delivered; failed; received; }

    // Item definitions
    item def PhoneNumber {
        attribute number : String;
        attribute countryCode : String;
    }

    item def MessageContent {
        attribute text : String;
        attribute length : MessageLength;
    }

    item def SmsMessage {
        attribute id : String;
        attribute sender : PhoneNumber;
        attribute recipient : PhoneNumber;
        attribute content : MessageContent;
        attribute priority : PriorityLevel;
        attribute timestamp : String;
        attribute deliveryStatus : MessageStatus;
    }

    item def DeliveryConfirmation {
        attribute messageId : String;
        attribute status : MessageStatus;
        attribute timestamp : String;
    }

    // Port definitions
    port def SmsOutPort {
        out message : SmsMessage;
    }

    port def SmsInPort {
        in message : SmsMessage;
    }

    // Functions
    function def isValidPhoneNumber(phone : PhoneNumber) : Boolean {
        return phone.number.size >= 7 and phone.number.size <= 15;
    }

    function def isValidContent(content : MessageContent) : Boolean {
        return content.text.size > 0 and content.length <= 160;
    }

    function def determineOperator(phone : PhoneNumber) : String {
        return phone.countryCode;
    }

    // Action definitions
    action def ValidateMessage {
        in message : SmsMessage;
        out validMessage : SmsMessage;
        out invalidMessage : SmsMessage;

        if (isValidPhoneNumber(message.recipient) and isValidContent(message.content)) {
            validMessage := message;
            validMessage.deliveryStatus := MessageStatus::validated;
        } else {
            invalidMessage := message;
            invalidMessage.deliveryStatus := MessageStatus::failed;
        }
    }

    action def StoreMessage {
        in message : SmsMessage;
        out storedMessage : SmsMessage;
        storedMessage := message;
    }

    action def EnqueueMessage {
        in message : SmsMessage;
        // Insert into queue ordered by priority
    }

    action def DequeueMessage {
        out message : SmsMessage;
        // Select highest priority message
    }

    action def RouteMessage {
        in message : SmsMessage;
        out routedMessage : SmsMessage;
        routedMessage := message;
        routedMessage.deliveryStatus := MessageStatus::queued;
    }

    action def TransmitMessage {
        in message : SmsMessage;
        out confirmation : DeliveryConfirmation;
        confirmation.messageId := message.id;
        confirmation.status := MessageStatus::transmitting;
        confirmation.timestamp := message.timestamp;
    }

    action def ReceiveMessage {
        in rawMessage : SmsMessage;
        out receivedMessage : SmsMessage;
        receivedMessage := rawMessage;
        receivedMessage.deliveryStatus := MessageStatus::received;
    }

    // Part definitions
    part def ValidationModule {
        port userInPort : SmsInPort;
        port storageOutPort : SmsOutPort;
        port rejectOutPort : SmsOutPort;

        action validate : ValidateMessage;
    }

    part def StorageSystem {
        port validationInPort : SmsInPort;
        port transceiverInPort : SmsInPort;
        port queueOutPort : SmsOutPort;
        port userOutPort : SmsOutPort;

        attribute storedMessages : SmsMessage[*];

        action storeOutbound : StoreMessage;
        action storeInbound : StoreMessage;
    }

    part def MessageQueue {
        port inPort : SmsInPort;
        port outPort : SmsOutPort;

        attribute queue : SmsMessage[*] ordered;

        action enqueue : EnqueueMessage;
        action dequeue : DequeueMessage;
    }

    part def RoutingComponent {
        port inPort : SmsInPort;
        port outPort : SmsOutPort;

        action route : RouteMessage;
    }

    part def NetworkTransceiver {
        port routingInPort : SmsInPort;
        port networkOutPort : SmsOutPort;
        port networkInPort : SmsInPort;
        port storageOutPort : SmsOutPort;
        port userOutPort : SmsOutPort;

        attribute signalStrength : SignalStrength = -70;
        attribute maxRetries : RetryCount = 3;
        attribute currentRetryCount : RetryCount = 0;

        action transmit : TransmitMessage;
        action receive : ReceiveMessage;

        state machine TransmissionStateMachine {
            state idle;
            state queued;
            state transmitting;
            state delivered;
            state failed;

            transition idle -> queued on messageQueued;
            transition queued -> transmitting on startTransmission;
            transition transmitting -> delivered on deliveryConfirmed;
            transition transmitting -> failed on transmissionFailed;
            transition failed -> transmitting on retryTrigger if currentRetryCount < maxRetries {
                currentRetryCount := currentRetryCount + 1;
            }
            transition failed -> idle on maxRetriesExceeded;
        }
    }

    // Top-level system
    part def SmsSystem {
        port userOutboundPort : SmsInPort;
        port userInboundPort : SmsOutPort;

        part validationModule : ValidationModule;
        part storageSystem : StorageSystem;
        part messageQueue : MessageQueue;
        part routingComponent : RoutingComponent;
        part networkTransceiver : NetworkTransceiver;

        attribute reliability : Real;
        attribute throughput : Throughput;
        attribute averageDeliveryTime : DeliveryTime;
        attribute failureRate : Real;

        connect userOutboundPort to validationModule.userInPort;
        connect validationModule.storageOutPort to storageSystem.validationInPort;
        connect storageSystem.queueOutPort to messageQueue.inPort;
        connect messageQueue.outPort to routingComponent.inPort;
        connect routingComponent.outPort to networkTransceiver.routingInPort;
        connect networkTransceiver.storageOutPort to storageSystem.transceiverInPort;
        connect storageSystem.userOutPort to userInboundPort;
        connect validationModule.rejectOutPort to userInboundPort;

        satisfy reliabilityReq by reliability;
        satisfy throughputReq by throughput;
        satisfy deliveryTimeReq by averageDeliveryTime;
        satisfy failureRateReq by failureRate;
    }

    part smsSystem : SmsSystem;

    // Requirements
    requirement def ReliabilityRequirement {
        doc /* The system shall achieve at least 99% successful delivery of validated messages. */
        attribute minReliability : Real = 0.99;
        require { reliability >= minReliability; }
    }

    requirement def ThroughputRequirement {
        doc /* The system shall support a throughput of at least 1000 messages per second. */
        attribute minThroughput : Throughput = 1000 [messagesPerSecond];
        require { throughput >= minThroughput; }
    }

    requirement def DeliveryTimeRequirement {
        doc /* The average delivery time shall not exceed 5 seconds. */
        attribute maxDeliveryTime : DeliveryTime = 5 [seconds];
        require { averageDeliveryTime <= maxDeliveryTime; }
    }

    requirement def FailureRateRequirement {
        doc /* The failure rate shall not exceed 1%. */
        attribute maxFailureRate : Real = 0.01;
        require { failureRate <= maxFailureRate; }
    }

    requirement reliabilityReq : ReliabilityRequirement {
        subject smsSystem;
    }

    requirement throughputReq : ThroughputRequirement {
        subject smsSystem;
    }

    requirement deliveryTimeReq : DeliveryTimeRequirement {
        subject smsSystem;
    }

    requirement failureRateReq : FailureRateRequirement {
        subject smsSystem;
    }
}
