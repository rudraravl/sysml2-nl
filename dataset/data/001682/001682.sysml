package 'SMS Based Communication System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MessageText;
	attribute def PhoneNumber;
	attribute def MessageIdentifier;
	attribute def DeliveryStatus;
	attribute def NetworkOperator;
	
	enum def MessagePriority {
		enum low;
		enum normal;
		enum high;
		enum urgent;
	}
	
	enum def TransmissionState {
		enum created;
		enum validated;
		enum queued;
		enum transmitting;
		enum delivered;
		enum failed;
		enum expired;
	}
	
	item def SMSMessage {
		attribute id : MessageIdentifier;
		attribute content : MessageText;
		attribute sender : PhoneNumber;
		attribute recipient : PhoneNumber;
		attribute priority : MessagePriority;
		attribute timestamp : ISQ::TimeValue;
		attribute currentState : TransmissionState;
		attribute retryCount : Integer;
	}
	
	attribute def MessageLength {
		attribute characters : Integer;
	}
	
	attribute def SignalStrength {
		attribute level : Real;
	}
	
	port def UserInterfacePort {
		in item incomingMessage : SMSMessage;
		out item outgoingMessage : SMSMessage;
		out attribute statusUpdate : DeliveryStatus;
	}
	
	port def NetworkPort {
		out item messageToNetwork : SMSMessage;
		in item messageFromNetwork : SMSMessage;
		in attribute networkSignal : SignalStrength;
	}
	
	port def StoragePort {
		in item messageToStore : SMSMessage;
		out item messageFromStore : SMSMessage;
	}
	
	part def MessageValidator {
		port inputPort : UserInterfacePort;
		port outputPort : UserInterfacePort;
		
		action def ValidateMessageContent {
			in message : SMSMessage;
			out isValid : Boolean;
			out validatedMessage : SMSMessage;
		}
		
		action def CheckRecipientFormat {
			in recipient : PhoneNumber;
			out isValidFormat : Boolean;
		}
	}
	
	part def MessageQueue {
		attribute maxCapacity : Integer;
		attribute currentLoad : Integer;
		port queueInput : UserInterfacePort;
		port queueOutput : UserInterfacePort;
		
		action def EnqueueMessage {
			in message : SMSMessage;
			in priority : MessagePriority;
			out queued : Boolean;
		}
		
		action def DequeueMessage {
			out message : SMSMessage;
			out available : Boolean;
		}
	}
	
	part def MessageStorage {
		attribute storageCapacity : Integer;
		attribute messagesStored : Integer;
		port storagePort : StoragePort;
		
		action def SaveMessage {
			in message : SMSMessage;
			out saved : Boolean;
		}
		
		action def RetrieveMessage {
			in messageId : MessageIdentifier;
			out message : SMSMessage;
			out found : Boolean;
		}
		
		action def DeleteMessage {
			in messageId : MessageIdentifier;
			out deleted : Boolean;
		}
	}
	
	part def NetworkTransceiver {
		attribute operator : NetworkOperator;
		attribute signalQuality : SignalStrength;
		port networkPort : NetworkPort;
		
		action def TransmitMessage {
			in message : SMSMessage;
			out transmitted : Boolean;
			out deliveryConfirmation : DeliveryStatus;
		}
		
		action def ReceiveMessage {
			out message : SMSMessage;
			out received : Boolean;
		}
		
		action def CheckNetworkStatus {
			out signalStrength : SignalStrength;
			out isAvailable : Boolean;
		}
	}
	
	part def MessageRouter {
		port routerInput : UserInterfacePort;
		port routerOutput : NetworkPort;
		
		action def RouteMessage {
			in message : SMSMessage;
			in networkStatus : Boolean;
			out routedMessage : SMSMessage;
			out routingSuccess : Boolean;
		}
		
		action def DetermineRoute {
			in recipient : PhoneNumber;
			out operator : NetworkOperator;
		}
	}
	
	state def MessageTransmissionLifecycle {
		entry; then idle;
		
		state idle;
		transition idle_to_receiving
			first idle
			accept at idle newMessageEvent
			then receiving;
		
		state receiving;
		transition receiving_to_queuing
			first receiving
			then queuing;
		transition receiving_to_rejected
			first receiving
			then rejected;
		
		state queuing;
		transition queuing_to_routing
			first queuing
			then routing;
		transition queuing_to_failed
			first queuing
			then failed;
		
		state routing;
		transition routing_to_transmitting
			first routing
			then transmitting;
		
		state transmitting;
		transition transmitting_to_delivered
			first transmitting
			then delivered;
		transition transmitting_to_retry
			first transmitting
			then queuing;
		
		state delivered;
		transition delivered_to_done
			first delivered
			then done;
		
		state rejected;
		state failed;
		
		state done;
	}
	
	action def ProcessOutgoingMessage {
		in userMessage : SMSMessage;
		out deliveryResult : DeliveryStatus;
		
		first start;
		then action validate : MessageValidator::ValidateMessageContent {
			in message = userMessage;
			out isValid;
			out validatedMessage;
		}
		then decide;
			if validate.isValid then store;
			if !validate.isValid then reject;
		
		action store : MessageStorage::SaveMessage {
			in message = validate.validatedMessage;
			out saved;
		}
		then action queue : MessageQueue::EnqueueMessage {
			in message = validate.validatedMessage;
			in priority = validate.validatedMessage.priority;
			out queued;
		}
		then action route : MessageRouter::RouteMessage {
			in message = validate.validatedMessage;
			out routedMessage;
			out routingSuccess;
		}
		then action transmit : NetworkTransceiver::TransmitMessage {
			in message = route.routedMessage;
			out transmitted;
			out deliveryConfirmation;
		}
		then assign deliveryResult := transmit.deliveryConfirmation;
		then done;
		
		action reject;
		then done;
	}
	
	action def ProcessIncomingMessage {
		out receivedMessage : SMSMessage;
		
		first start;
		then action receive : NetworkTransceiver::ReceiveMessage {
			out message;
			out received;
		}
		then decide;
			if receive.received then storeIncoming;
			if !receive.received then done;
		
		action storeIncoming : MessageStorage::SaveMessage {
			in message = receive.message;
			out saved;
		}
		then assign receivedMessage := receive.message;
		then done;
	}
	
	part def SMSCommunicationSystem {
		doc /* 
			An SMS-based communication system that enables users to send and receive 
			short text messages through mobile networks. The system validates incoming 
			messages, manages message queuing based on priority, routes messages through 
			appropriate network operators, and ensures reliable delivery with retry 
			mechanisms. It provides persistent storage for message history and handles 
			both outgoing and incoming message flows with comprehensive state tracking.
		*/
		
		part validator : MessageValidator;
		
		part messageQueue : MessageQueue {
			:>> maxCapacity = 5000;
			:>> currentLoad = 0;
		}
		
		part storage : MessageStorage {
			:>> storageCapacity = 100000;
			:>> messagesStored = 0;
		}
		
		part router : MessageRouter;
		
		part transceiver : NetworkTransceiver;
		
		port userInterface : UserInterfacePort;
		port networkInterface : NetworkPort;
		port dataStorage : StoragePort;
		
		connection userInterface to validator.inputPort;
		connection validator.outputPort to messageQueue.queueInput;
		connection messageQueue.queueOutput to router.routerInput;
		connection router.routerOutput to transceiver.networkPort;
		connection transceiver.networkPort to networkInterface;
		connection storage.storagePort to dataStorage;
		
		perform action handleOutgoingMessages {
			first start;
			then merge checkForOutgoing;
			
			action checkForOutgoing {
				out hasOutgoing : Boolean;
			}
			
			then decide;
				if checkForOutgoing.hasOutgoing then processOutgoing;
				if !checkForOutgoing.hasOutgoing then waitForOutgoing;
			
			action processOutgoing : ProcessOutgoingMessage {
				out deliveryResult;
			}
			then checkForOutgoing;
			
			action waitForOutgoing;
			then checkForOutgoing;
		}
		
		perform action handleIncomingMessages {
			first start;
			then merge monitorNetwork;
			
			action monitorNetwork {
				out networkActive : Boolean;
			}
			
			then decide;
				if monitorNetwork.networkActive then processIncoming;
				if !monitorNetwork.networkActive then waitForNetwork;
			
			action processIncoming : ProcessIncomingMessage {
				out receivedMessage;
			}
			then monitorNetwork;
			
			action waitForNetwork;
			then monitorNetwork;
		}
	}
	
	requirement def SystemFunctionalRequirement {
		doc /* The SMS Communication System shall reliably send and receive text messages. */
		
		require constraint messageThroughput {
			doc /* System shall process at least 500 messages per minute. */
		}
		
		require constraint deliveryReliability {
			doc /* System shall achieve 99.5% successful delivery rate. */
		}
		
		require constraint responseTime {
			doc /* System shall deliver messages within 10 seconds under normal conditions. */
		}
	}
	
	requirement def MessageValidationRequirement {
		doc /* All messages shall be validated before transmission. */
		
		require constraint contentLength {
			doc /* Message content shall not exceed 160 characters for standard SMS. */
		}
		
		require constraint recipientFormat {
			doc /* Recipient phone number shall conform to E.164 international format. */
		}
		
		require constraint characterEncoding {
			doc /* Message content shall use GSM 7-bit or Unicode encoding. */
		}
	}
	
	requirement def StorageRequirement {
		doc /* System shall maintain persistent message storage. */
		
		require constraint storageCapacity {
			doc /* System shall store at least 100,000 messages. */
		}
		
		require constraint retentionPeriod {
			doc /* Messages shall be retained for minimum 90 days. */
		}
	}
	
	requirement systemRequirements : SystemFunctionalRequirement {
		subject smsSystem : SMSCommunicationSystem;
		
		assume constraint networkAvailability {
			doc /* Mobile network connectivity is available with adequate signal strength. */
		}
		
		require messageValidation : MessageValidationRequirement;
		require storageReq : StorageRequirement;
	}
	
	part smsCommunicationSystem : SMSCommunicationSystem;
}
