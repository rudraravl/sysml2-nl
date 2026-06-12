package SMSSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def MessageIdentifier : String;
    attribute def SubscriberIdentifier : String;
    attribute def NetworkAddress : String;
    attribute def Timestamp : String;

    enum def MessagePriority {
        enum normal;
        enum urgent;
        enum emergency;
    }

    enum def DeliveryStatus {
        enum created;
        enum submitted;
        enum authenticated;
        enum routed;
        enum stored;
        enum delivered;
        enum expired;
        enum rejected;
        enum failed;
    }

    enum def MessageEncoding {
        enum gsm7;
        enum ucs2;
        enum binary8;
    }

    enum def RadioAccessTechnology {
        enum gsm;
        enum umts;
        enum lte;
        enum nr5g;
        enum wifiCalling;
    }

    item def SMSPayload {
        attribute text : String;
        attribute encoding : MessageEncoding;
        attribute characterCount : Integer;
        attribute concatenated : Boolean;
        attribute segmentCount : Integer;
    }

    item def SMSMessage {
        attribute id : MessageIdentifier;
        attribute originator : SubscriberIdentifier;
        attribute recipient : SubscriberIdentifier;
        attribute createdAt : Timestamp;
        attribute priority : MessagePriority;
        attribute payload : SMSPayload;
        attribute validityPeriod : Time = 48 [h];
        attribute status : DeliveryStatus;
        attribute retryCount : Integer;
    }

    item def DeliveryReport {
        attribute messageId : MessageIdentifier;
        attribute recipient : SubscriberIdentifier;
        attribute status : DeliveryStatus;
        attribute reportedAt : Timestamp;
        attribute failureCause : String;
    }

    item def SubscriberProfile {
        attribute subscriberId : SubscriberIdentifier;
        attribute homeNetwork : NetworkAddress;
        attribute roamingNetwork : NetworkAddress;
        attribute smsEnabled : Boolean;
        attribute barringActive : Boolean;
        attribute reachable : Boolean;
    }

    item def AuthenticationDecision {
        attribute subscriberId : SubscriberIdentifier;
        attribute accepted : Boolean;
        attribute reason : String;
    }

    item def RoutingDecision {
        attribute messageId : MessageIdentifier;
        attribute destinationNetwork : NetworkAddress;
        attribute useStoreAndForward : Boolean;
        attribute maxRetryInterval : Time = 10 [min];
    }

    port def MessageSubmissionPort {
        in item submittedMessage : SMSMessage;
        out item submissionReport : DeliveryReport;
    }

    port def MessageDeliveryPort {
        out item deliveredMessage : SMSMessage;
        in item deliveryAcknowledgement : DeliveryReport;
    }

    port def SubscriberLookupPort {
        out item lookupRequest : SubscriberIdentifier;
        in item profileResponse : SubscriberProfile;
    }

    port def AuthenticationPort {
        in item profile : SubscriberProfile;
        out item decision : AuthenticationDecision;
    }

    port def RoutingPort {
        in item messageForRouting : SMSMessage;
        in item recipientProfile : SubscriberProfile;
        out item route : RoutingDecision;
    }

    port def StoreForwardPort {
        in item messageToStore : SMSMessage;
        out item messageForRetry : SMSMessage;
        out item expirationReport : DeliveryReport;
    }

    port def NetworkTransportPort {
        in item outboundMessage : SMSMessage;
        out item inboundReport : DeliveryReport;
    }

    port def OperationsPort {
        out attribute availability : Real;
        out attribute queueDepth : Integer;
        out attribute meanDeliveryLatency : Time;
    }

    action def SubmitSMS {
        in item message : SMSMessage;
        out item acceptedMessage : SMSMessage;
        out item report : DeliveryReport;

        first start;
        then validatePayload;
        then validateAddress;
        then createSubmissionReport;
        then done;

        action validatePayload {
            in item message : SMSMessage;
        }

        action validateAddress {
            in item message : SMSMessage;
        }

        action createSubmissionReport {
            out item report : DeliveryReport;
        }
    }

    action def AuthenticateSubscriber {
        in item profile : SubscriberProfile;
        out item decision : AuthenticationDecision;

        first checkSmsServiceEnabled;
        then checkBarring;
        then issueDecision;
        then done;

        action checkSmsServiceEnabled;
        action checkBarring;
        action issueDecision;
    }

    action def RouteSMS {
        in item message : SMSMessage;
        in item profile : SubscriberProfile;
        out item decision : RoutingDecision;

        first determineDestinationNetwork;
        then selectDeliveryMode;
        then publishRoute;
        then done;

        action determineDestinationNetwork;
        action selectDeliveryMode;
        action publishRoute;
    }

    action def DeliverSMS {
        in item message : SMSMessage;
        in item route : RoutingDecision;
        out item report : DeliveryReport;

        first transmitToServingNetwork;
        then awaitAcknowledgement;
        then emitDeliveryReport;
        then done;

        action transmitToServingNetwork;
        action awaitAcknowledgement;
        action emitDeliveryReport;
    }

    action def StoreAndRetrySMS {
        in item undeliveredMessage : SMSMessage;
        out item retryMessage : SMSMessage;
        out item expirationReport : DeliveryReport;

        first storeMessage;
        then waitForRetryWindow;
        then evaluateValidity;
        then retryOrExpire;
        then done;

        action storeMessage;
        action waitForRetryWindow;
        action evaluateValidity;
        action retryOrExpire;
    }

    state def SMSMessageLifecycle {
        entry action initializeStatus;

        state Created;
        state Submitted;
        state Authenticated;
        state Routed;
        state Stored;
        state Delivering;
        state Delivered;
        state Rejected;
        state Expired;
        state Failed;

        transition first Created;
        transition Created_to_Submitted
            first Created
            then Submitted;

        transition Submitted_to_Authenticated
            first Submitted
            then Authenticated
            accept AuthenticationDecision
            if accepted == true;

        transition Submitted_to_Rejected
            first Submitted
            then Rejected
            accept AuthenticationDecision
            if accepted == false;

        transition Authenticated_to_Routed
            first Authenticated
            then Routed
            accept RoutingDecision;

        transition Routed_to_Delivering
            first Routed
            then Delivering
            if useStoreAndForward == false;

        transition Routed_to_Stored
            first Routed
            then Stored
            if useStoreAndForward == true;

        transition Stored_to_Delivering
            first Stored
            then Delivering
            accept SMSMessage;

        transition Delivering_to_Delivered
            first Delivering
            then Delivered
            accept DeliveryReport
            if status == DeliveryStatus::delivered;

        transition Delivering_to_Failed
            first Delivering
            then Failed
            accept DeliveryReport
            if status == DeliveryStatus::failed;

        transition Stored_to_Expired
            first Stored
            then Expired
            accept DeliveryReport
            if status == DeliveryStatus::expired;
    }

    part def MobileStation {
        attribute subscriberId : SubscriberIdentifier;
        attribute radioAccess : RadioAccessTechnology;
        attribute reachable : Boolean;
        attribute batteryAvailable : Boolean;

        port submitPort : MessageSubmissionPort;
        port deliveryPort : MessageDeliveryPort;
    }

    part def BaseStationSubsystem {
        attribute cellIdentifier : String;
        attribute supportedAccess : RadioAccessTechnology;
        attribute radioCoverageAvailable : Boolean;

        port mobileSubmissionPort : MessageSubmissionPort;
        port mobileDeliveryPort : MessageDeliveryPort;
        port coreTransportPort : NetworkTransportPort;
    }

    part def MobileSwitchingCenter {
        attribute switchAddress : NetworkAddress;
        attribute currentLoad : Real;
        attribute connectedCells : Integer;

        port radioTransportPort : NetworkTransportPort;
        port smsSubmissionPort : MessageSubmissionPort;
        port smsDeliveryPort : MessageDeliveryPort;
        port subscriberLookupPort : SubscriberLookupPort;
    }

    part def HomeLocationRegister {
        attribute registryAddress : NetworkAddress;
        attribute profileCount : Integer;

        port lookupPort : SubscriberLookupPort;
    }

    part def AuthenticationCenter {
        attribute authenticationPolicyVersion : String;

        port authPort : AuthenticationPort;
    }

    part def SMSCenter {
        attribute centerAddress : NetworkAddress;
        attribute maximumMessageSegments : Integer = 6;
        attribute maximumPayloadGsm7Characters : Integer = 918;
        attribute maximumPayloadUcs2Characters : Integer = 402;
        attribute nominalAvailability : Real = 0.9999;
        attribute targetDeliveryLatency : Time = 5 [s];
        attribute maximumRetentionTime : Time = 48 [h];

        port submissionPort : MessageSubmissionPort;
        port routingPort : RoutingPort;
        port storeForwardPort : StoreForwardPort;
        port transportPort : NetworkTransportPort;
        port operationsPort : OperationsPort;

        perform action submit : SubmitSMS;
        perform action route : RouteSMS;
        perform action storeAndRetry : StoreAndRetrySMS;
        perform action deliver : DeliverSMS;

        exhibit state lifecycle : SMSMessageLifecycle;
    }

    part def ExternalMessagingNetwork {
        attribute networkAddress : NetworkAddress;
        attribute supportsInterconnectDeliveryReports : Boolean;

        port interconnectPort : NetworkTransportPort;
    }

    part def SMSBasedCommunicationSystem {
        attribute systemName : String = "Short Message Service Communication System";
        attribute primaryFunction : String =
            "Accept text messages from an originating subscriber, validate and route them through mobile network infrastructure, store them when the recipient is unavailable, and deliver them to the intended subscriber with delivery status reporting.";
        attribute supportedMessageValidityPeriod : Time = 48 [h];
        attribute normalDeliveryLatencyObjective : Time = 5 [s];
        attribute minimumAvailabilityObjective : Real = 0.999;

        part originatingHandset : MobileStation {
            attribute subscriberId = "MSISDN:+15550100001";
            attribute radioAccess = RadioAccessTechnology::lte;
            attribute reachable = true;
            attribute batteryAvailable = true;
        }

        part recipientHandset : MobileStation {
            attribute subscriberId = "MSISDN:+15550100002";
            attribute radioAccess = RadioAccessTechnology::nr5g;
            attribute reachable = true;
            attribute batteryAvailable = true;
        }

        part radioAccessNetwork : BaseStationSubsystem {
            attribute cellIdentifier = "CELL-1042";
            attribute supportedAccess = RadioAccessTechnology::lte;
            attribute radioCoverageAvailable = true;
        }

        part switchingCenter : MobileSwitchingCenter {
            attribute switchAddress = "MSC:central-01";
            attribute currentLoad = 0.42;
            attribute connectedCells = 128;
        }

        part subscriberRegistry : HomeLocationRegister {
            attribute registryAddress = "HLR:home-01";
            attribute profileCount = 2500000;
        }

        part authenticationCenter : AuthenticationCenter {
            attribute authenticationPolicyVersion = "SMS-AUTH-2026.1";
        }

        part messageCenter : SMSCenter {
            attribute centerAddress = "SMSC:regional-01";
        }

        part externalNetwork : ExternalMessagingNetwork {
            attribute networkAddress = "IPX:partner-network";
            attribute supportsInterconnectDeliveryReports = true;
        }

        connect originatingHandset.submitPort to radioAccessNetwork.mobileSubmissionPort;
        connect radioAccessNetwork.coreTransportPort to switchingCenter.radioTransportPort;
        connect switchingCenter.smsSubmissionPort to messageCenter.submissionPort;
        connect switchingCenter.subscriberLookupPort to subscriberRegistry.lookupPort;
        connect subscriberRegistry.lookupPort to authenticationCenter.authPort;
        connect messageCenter.routingPort to switchingCenter.subscriberLookupPort;
        connect messageCenter.transportPort to externalNetwork.interconnectPort;
        connect messageCenter.transportPort to switchingCenter.smsDeliveryPort;
        connect switchingCenter.smsDeliveryPort to radioAccessNetwork.mobileDeliveryPort;
        connect radioAccessNetwork.mobileDeliveryPort to recipientHandset.deliveryPort;
    }

    requirement def SMSPrimaryFunctionRequirement {
        subject system : SMSBasedCommunicationSystem;

        doc /* The SMS-based communication system shall provide store-and-forward text messaging between mobile subscribers. */

        require constraint {
            system.supportedMessageValidityPeriod >= 24 [h] and
            system.normalDeliveryLatencyObjective <= 10 [s] and
            system.minimumAvailabilityObjective >= 0.999
        }
    }

    requirement def SMSPayloadRequirement {
        subject center : SMSCenter;

        doc /* The SMS center shall support segmented payloads using GSM 7-bit, UCS-2, or 8-bit binary encoding. */

        require constraint {
            center.maximumMessageSegments >= 6 and
            center.maximumPayloadGsm7Characters >= 918 and
            center.maximumPayloadUcs2Characters >= 402
        }
    }

    requirement def SMSStoreAndForwardRequirement {
        subject center : SMSCenter;

        doc /* The SMS center shall retain accepted undelivered messages until delivery succeeds or the message validity period expires. */

        require constraint {
            center.maximumRetentionTime >= 48 [h]
        }
    }

    requirement def SMSDeliveryReportingRequirement {
        subject system : SMSBasedCommunicationSystem;

        doc /* The system shall provide a delivery report for submitted messages when the final delivery state is delivered, expired, rejected, or failed. */
    }

    requirement def SMSAuthenticationRequirement {
        subject auth : AuthenticationCenter;

        doc /* The authentication center shall reject message submission when the subscriber profile indicates SMS service is disabled or barring is active. */
    }

    satisfy SMSPrimaryFunctionRequirement by SMSBasedCommunicationSystem;
    satisfy SMSPayloadRequirement by SMSCenter;
    satisfy SMSStoreAndForwardRequirement by SMSCenter;
    satisfy SMSDeliveryReportingRequirement by SMSBasedCommunicationSystem;
    satisfy SMSAuthenticationRequirement by AuthenticationCenter;
}