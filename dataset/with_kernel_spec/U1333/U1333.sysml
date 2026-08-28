package EmailClientApplication {
	private import ScalarValues::*;

	doc
	/*
	 * Comprehensive Email Client Application Model
	 * Supports composing, sending, receiving, and managing electronic messages.
	 */

	enum def EmailStatus {
		draft;
		sent;
		read;
		failed;
		quarantined;
		received;
	}

	enum def Priority {
		low;
		normal;
		high;
	}

	item def EmailMessage {
		doc /* Detailed representation of an electronic mail message. */
		attribute id : String;
		attribute sender : String;
		attribute recipients : String[1..*];
		attribute emailSubject : String;
		attribute body : String;
		attribute timestamp : String;
		attribute size : Integer;
		attribute status : EmailStatus;
		attribute priority : Priority;
		attribute spamScore : Real = 0.0;
	}

	item def ComposeRequest {
		attribute recipients : String[1..*];
		attribute emailSubject : String;
		attribute body : String;
	}

	item def SmtpCommand {
		attribute command : String;
	}

	item def SmtpResponse {
		attribute code : Integer;
		attribute text : String;
	}

	item def StoreRequest {
		attribute emailMessage : EmailMessage;
	}

	item def QuarantineRequest {
		attribute emailMessage : EmailMessage;
	}

	item def Notification {
		attribute text : String;
	}

	port def UiCommandPort;
	port def DisplayPort;
	port def ComposerPort;
	port def QueuePort;
	port def SmtpServerPort;
	port def MailServerPort;
	port def StorePort;

	part def UserInterface {
		doc /* Primary user interaction component for composing and viewing messages. */
		port commandPort : UiCommandPort;
		port displayPort : DisplayPort;
		port composerPort : ~ComposerPort;
		port storeViewPort : StorePort;

		exhibit state userInterfaceBehavior {
			entry; then viewingInbox;
			state viewingInbox;
			state composing;

			transition startComposing
				first viewingInbox
				accept cmd : ComposeRequest via commandPort
				do send cmd via composerPort
				then composing;

			transition sendComposed
				first composing
				accept cmd : ComposeRequest via commandPort
				do send cmd via composerPort
				then viewingInbox;

			transition cancelCompose
				first composing
				accept cmd : ComposeRequest via commandPort
				then viewingInbox;

			transition receiveNotification
				first viewingInbox
				accept notification : Notification via storeViewPort
				do send notification via displayPort
				then viewingInbox;
		}
	}

	part def MessageComposer {
		doc /* Structures user input into a formal email message with unique ID. */
		attribute nextMessageId : Integer = 0;
		port inputPort : ComposerPort;
		port outputPort : ~QueuePort;

		perform action composeBehavior {
			action receiveCompose accept content : ComposeRequest via inputPort;
			then action createEmail {
				send new EmailMessage via outputPort;
			}
		}
	}

	part def MessageQueue {
		doc /* Buffer holding up to 10,000 pending outgoing messages. */
		attribute capacity : Integer = 10000;
		attribute currentCount : Integer = 0;
		port enqueuePort : QueuePort;
		port dequeuePort : ~QueuePort;

		exhibit state queueBehavior {
			entry; then idle;
			state idle;

			transition enqueue
				first idle
				accept msg : EmailMessage via enqueuePort
				if currentCount < capacity
				do send msg via dequeuePort
				then idle;
		}
	}

	part def SmtpClient {
		doc /* Sends messages over the internet using SMTP protocol. */
		port queuePort : QueuePort;
		port serverPort : ~SmtpServerPort;

		exhibit state smtpSession {
			entry; then idle;
			state idle;
			state connecting;
			state authenticating;
			state transmitting;
			state confirming;
			state success;
			state failure;

			transition startSending
				first idle
				accept msg : EmailMessage via queuePort
				do send new SmtpCommand("EHLO") via serverPort
				then connecting;

			transition connected
				first connecting
				accept resp : SmtpResponse via serverPort
				if resp.code == 220
				do send new SmtpCommand("AUTH LOGIN") via serverPort
				then authenticating;

			transition authenticated
				first authenticating
				accept resp : SmtpResponse via serverPort
				if resp.code == 235
				do send new SmtpCommand("MAIL FROM") via serverPort
				then transmitting;

			transition transmitData
				first transmitting
				accept resp : SmtpResponse via serverPort
				if resp.code == 250
				do send new SmtpCommand("DATA") via serverPort
				then confirming;

			transition confirmSuccess
				first confirming
				accept resp : SmtpResponse via serverPort
				if resp.code == 250
				then success;

			transition errorConnecting
				first connecting
				accept resp : SmtpResponse via serverPort
				if resp.code >= 400
				then failure;

			transition errorAuthenticating
				first authenticating
				accept resp : SmtpResponse via serverPort
				if resp.code >= 400
				then failure;

			transition errorTransmitting
				first transmitting
				accept resp : SmtpResponse via serverPort
				if resp.code >= 400
				then failure;

			transition errorConfirming
				first confirming
				accept resp : SmtpResponse via serverPort
				if resp.code >= 400
				then failure;

			transition resetSuccess
				first success
				then idle;

			transition resetFailure
				first failure
				then idle;
		}
	}

	part def SpamFilter {
		doc /* Analyzes incoming messages and quarantines spam above threshold. */
		attribute threshold : Real = 0.85;
		port incomingPort : MailServerPort;
		port cleanPort : ~StorePort;
		port quarantinePort : ~StorePort;

		exhibit state spamFilterBehavior {
			entry; then idle;
			state idle;

			transition receiveAndQuarantine
				first idle
				accept mail : EmailMessage via incomingPort
				if mail.spamScore > threshold
				do send new QuarantineRequest(mail) via quarantinePort
				then idle;

			transition receiveAndDeliver
				first idle
				accept mail : EmailMessage via incomingPort
				if mail.spamScore <= threshold
				do send new StoreRequest(mail) via cleanPort
				then idle;
		}
	}

	part def MessageStore {
		doc /* Local database for inbox, sent items, and spam folders. */
		attribute capacity : Integer = 1073741824;
		attribute usedStorage : Integer = 0;
		attribute inbox : EmailMessage[0..*];
		attribute sentItems : EmailMessage[0..*];
		attribute spamFolder : EmailMessage[0..*];
		port storePort : StorePort;
		port quarantinePort : StorePort;
		port viewPort : ~StorePort;

		exhibit state storeBehavior {
			entry; then ready;
			state ready;

			transition receiveIncoming
				first ready
				accept req : StoreRequest via storePort
				do send new Notification("new email arrived") via viewPort
				then ready;

			transition receiveQuarantine
				first ready
				accept req : QuarantineRequest via quarantinePort
				do send new Notification("spam quarantined") via viewPort
				then ready;
		}
	}

	part def SmtpServer {
		port serverPort : SmtpServerPort;
	}

	part def IncomingMailServer {
		port serverPort : ~MailServerPort;
	}

	part emailClientApp {
		part ui : UserInterface;
		part composer : MessageComposer;
		part outgoingQueue : MessageQueue;
		part smtpClient : SmtpClient;
		part spamFilter : SpamFilter;
		part messageStore : MessageStore;
		part smtpServer : SmtpServer;
		part incomingMailServer : IncomingMailServer;

		connect ui.composerPort to composer.inputPort;
		connect composer.outputPort to outgoingQueue.enqueuePort;
		connect outgoingQueue.dequeuePort to smtpClient.queuePort;
		connect smtpClient.serverPort to smtpServer.serverPort;
		connect incomingMailServer.serverPort to spamFilter.incomingPort;
		connect spamFilter.cleanPort to messageStore.storePort;
		connect spamFilter.quarantinePort to messageStore.quarantinePort;
		connect messageStore.viewPort to ui.storeViewPort;
	}

	requirement def QueueCapacityRequirement {
		doc /* The Message Queue shall be capable of holding up to 10,000 pending messages. */
		attribute maxPendingMessages : Integer = 10000;
	}

	requirement def SpamThresholdRequirement {
		doc /* The Spam Filter shall quarantine any incoming email with a spam score above 0.85. */
		attribute threshold : Real = 0.85;
	}

	requirement def SmtpStateProtocolRequirement {
		doc /* The SMTP Client shall implement a state machine including connecting, authenticating, transmitting, and confirming delivery success or failure. */
	}

	requirement def StorageCapacityRequirement {
		doc /* The Message Store shall operate within a defined storage capacity. */
		attribute capacity : Integer = 1073741824;
	}

	requirement def EmailMessageRepresentationRequirement {
		doc /* The system shall represent email messages with sender, recipients, subject, body, timestamp, size, status, and priority. */
	}

	requirement queueCapacityReq : QueueCapacityRequirement;
	requirement spamThresholdReq : SpamThresholdRequirement;
	requirement smtpProtocolReq : SmtpStateProtocolRequirement;
	requirement storageCapacityReq : StorageCapacityRequirement;
	requirement messageRepresentationReq : EmailMessageRepresentationRequirement;
}
