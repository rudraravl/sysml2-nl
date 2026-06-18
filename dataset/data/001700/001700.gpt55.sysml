package EmailSystemModel {
    import ScalarValues::*;

    doc /*
        High-level primary function:
        The EmailService enables authenticated users to compose, submit, store, route, deliver,
        retrieve, and manage electronic mail messages between mailboxes and external domains while
        enforcing addressing, size, content-safety, reliability, and privacy constraints.
    */

    enum def MessagePriority {
        enum low;
        enum normal;
        enum high;
        enum urgent;
    }

    enum def MessageSensitivity {
        enum public;
        enum internal;
        enum confidential;
        enum restricted;
    }

    enum def MessageDisposition {
        enum draft;
        enum submitted;
        enum accepted;
        enum quarantined;
        enum routed;
        enum delivered;
        enum read;
        enum archived;
        enum deleted;
        enum bounced;
    }

    enum def DeliveryStatusKind {
        enum acceptedByService;
        enum delayed;
        enum deliveredToMailbox;
        enum deliveredToRemoteDomain;
        enum rejected;
        enum failed;
    }

    enum def ThreatVerdict {
        enum clean;
        enum suspicious;
        enum malwareDetected;
        enum spamDetected;
        enum phishingDetected;
    }

    enum def AuthenticationResult {
        enum authenticated;
        enum denied;
        enum expired;
        enum locked;
    }

    attribute def EmailAddress :> String;
    attribute def DomainName :> String;
    attribute def MessageIdentifier :> String;
    attribute def HeaderFieldName :> String;
    attribute def HeaderFieldValue :> String;
    attribute def MimeType :> String;
    attribute def Text :> String;
    attribute def SubjectText :> String;
    attribute def TokenValue :> String;

    attribute def Byte :> Integer;
    attribute def Kibibyte :> Real;
    attribute def Mebibyte :> Real;
    attribute def MessagePerSecond :> Real;
    attribute def Millisecond :> Real;
    attribute def Second :> Real;
    attribute def Minute :> Real;
    attribute def Percent :> Real;
    attribute def Count :> Integer;

    item def MailboxUser {
        attribute userId : String;
        attribute displayName : String;
        attribute primaryAddress : EmailAddress;
        attribute homeDomain : DomainName;
    }

    item def Credential {
        attribute accountName : String;
        attribute token : TokenValue;
        attribute tokenAgeSeconds : Second;
        attribute secondFactorVerified : Boolean;
    }

    item def MailboxReference {
        attribute ownerAddress : EmailAddress;
        attribute folderName : String;
        attribute quotaUsedMiB : Mebibyte;
        attribute quotaLimitMiB : Mebibyte;
    }

    item def MessageHeaderField {
        attribute fieldName : HeaderFieldName;
        attribute fieldValue : HeaderFieldValue;
    }

    item def Attachment {
        attribute fileName : String;
        attribute mediaType : MimeType;
        attribute sizeKiB : Kibibyte;
        attribute checksumSha256 : String;
        attribute inlineContent : Boolean;
    }

    item def EmailMessage {
        attribute messageId : MessageIdentifier;
        attribute sender : EmailAddress;
        attribute recipientsTo : EmailAddress[1..*];
        attribute recipientsCc : EmailAddress[0..*];
        attribute recipientsBcc : EmailAddress[0..*];
        attribute replyTo : EmailAddress[0..1];
        attribute subject : SubjectText;
        attribute bodyPlainText : Text;
        attribute bodyHtml : Text[0..1];
        attribute priority : MessagePriority;
        attribute sensitivity : MessageSensitivity;
        attribute totalSizeMiB : Mebibyte;
        attribute createdAgeSeconds : Second;
        attribute disposition : MessageDisposition;
        item headerFields : MessageHeaderField[0..*];
        item attachments : Attachment[0..*];
    }

    item def ComposeRequest {
        item requestingUser : MailboxUser;
        item credential : Credential;
        item draftMessage : EmailMessage;
    }

    item def RetrieveRequest {
        item requestingUser : MailboxUser;
        item credential : Credential;
        attribute folderName : String;
        attribute maximumMessages : Count;
    }

    item def DeleteRequest {
        item requestingUser : MailboxUser;
        item credential : Credential;
        attribute messageId : MessageIdentifier;
        attribute folderName : String;
    }

    item def DeliveryReceipt {
        attribute messageId : MessageIdentifier;
        attribute status : DeliveryStatusKind;
        attribute diagnosticText : Text;
        attribute serviceLatencyMs : Millisecond;
    }

    item def MailboxView {
        item mailbox : MailboxReference;
        item visibleMessages : EmailMessage[0..*];
        attribute unreadCount : Count;
    }

    item def UserNotification {
        attribute recipient : EmailAddress;
        attribute messageId : MessageIdentifier;
        attribute notificationText : Text;
        attribute generatedAfterMs : Millisecond;
    }

    item def AddressResolutionQuery {
        attribute domain : DomainName;
        attribute requester : String;
    }

    item def AddressResolutionAnswer {
        attribute domain : DomainName;
        attribute mailExchangeHost : String;
        attribute preference : Count;
        attribute validForSeconds : Second;
    }

    item def ThreatScanRequest {
        item message : EmailMessage;
        attribute scanDepth : String;
    }

    item def ThreatScanResult {
        attribute messageId : MessageIdentifier;
        attribute verdict : ThreatVerdict;
        attribute confidencePercent : Percent;
        attribute scanLatencyMs : Millisecond;
    }

    item def AuthenticationRequest {
        item credential : Credential;
        attribute requestedAddress : EmailAddress;
    }

    item def AuthenticationResponse {
        attribute result : AuthenticationResult;
        attribute accountAddress : EmailAddress;
        attribute reason : Text;
    }

    port def UserEmailPort {
        in item composeRequest : ComposeRequest;
        in item retrieveRequest : RetrieveRequest;
        in item deleteRequest : DeleteRequest;
        out item deliveryReceipt : DeliveryReceipt;
        out item mailboxView : MailboxView;
        out item userNotification : UserNotification;
    }

    port def SubmissionPort {
        in item submittedMessage : EmailMessage;
        in item submitterCredential : Credential;
        out item submissionReceipt : DeliveryReceipt;
    }

    port def MailboxAccessPort {
        in item retrieveRequest : RetrieveRequest;
        in item deleteRequest : DeleteRequest;
        out item mailboxView : MailboxView;
        out item deletionReceipt : DeliveryReceipt;
    }

    port def StorePort {
        in item messageToStore : EmailMessage;
        in item folderTarget : MailboxReference;
        out item storeReceipt : DeliveryReceipt;
        out item storedMessage : EmailMessage;
    }

    port def RoutePort {
        in item acceptedMessage : EmailMessage;
        out item localDeliveryMessage : EmailMessage;
        out item remoteDeliveryMessage : EmailMessage;
        out item routeReceipt : DeliveryReceipt;
    }

    port def MailExchangePort {
        out item outboundMessage : EmailMessage;
        in item inboundMessage : EmailMessage;
        in item remoteReceipt : DeliveryReceipt;
        out item localReceipt : DeliveryReceipt;
    }

    port def DirectoryPort {
        in item authenticationRequest : AuthenticationRequest;
        out item authenticationResponse : AuthenticationResponse;
    }

    port def DomainResolutionPort {
        out item resolutionQuery : AddressResolutionQuery;
        in item resolutionAnswer : AddressResolutionAnswer;
    }

    port def ThreatScanningPort {
        out item scanRequest : ThreatScanRequest;
        in item scanResult : ThreatScanResult;
    }

    port def NotificationPort {
        in item deliveredMessage : EmailMessage;
        out item notification : UserNotification;
    }

    action def ComposeEmail {
        in item request : ComposeRequest;
        out item composedMessage : EmailMessage;

        action verifyDraftCompleteness;
        action assignMessageIdentifier;
        action normalizeHeaderFields;
        action renderMultipartBody;

        flow request.draftMessage to verifyDraftCompleteness;
        flow verifyDraftCompleteness to assignMessageIdentifier;
        flow assignMessageIdentifier to normalizeHeaderFields;
        flow normalizeHeaderFields to renderMultipartBody;
        flow renderMultipartBody to composedMessage;
    }

    action def AuthenticateUser {
        in item request : AuthenticationRequest;
        out item response : AuthenticationResponse;

        action validateTokenAge;
        action verifySecondFactor;
        action checkAccountState;
        action issueAuthenticationDecision;

        flow request to validateTokenAge;
        flow validateTokenAge to verifySecondFactor;
        flow verifySecondFactor to checkAccountState;
        flow checkAccountState to issueAuthenticationDecision;
        flow issueAuthenticationDecision to response;
    }

    action def ValidateAddressing {
        in item messageIn : EmailMessage;
        out item validatedMessage : EmailMessage;
        out item rejectionReceipt : DeliveryReceipt;

        action parseSenderDomain;
        action parseRecipientDomains;
        action enforceAtLeastOneRecipient;
        action checkAddressSyntax;
        action classifyLocalAndRemoteRecipients;

        flow messageIn to parseSenderDomain;
        flow parseSenderDomain to parseRecipientDomains;
        flow parseRecipientDomains to enforceAtLeastOneRecipient;
        flow enforceAtLeastOneRecipient to checkAddressSyntax;
        flow checkAddressSyntax to classifyLocalAndRemoteRecipients;
        flow classifyLocalAndRemoteRecipients to validatedMessage;
    }

    action def ScanEmailContent {
        in item messageIn : EmailMessage;
        out item cleanMessage : EmailMessage;
        out item quarantineReceipt : DeliveryReceipt;

        action inspectAttachmentTypes;
        action computeAttachmentHashes;
        action evaluateSpamSignals;
        action evaluatePhishingSignals;
        action decideThreatVerdict;

        flow messageIn to inspectAttachmentTypes;
        flow inspectAttachmentTypes to computeAttachmentHashes;
        flow computeAttachmentHashes to evaluateSpamSignals;
        flow evaluateSpamSignals to evaluatePhishingSignals;
        flow evaluatePhishingSignals to decideThreatVerdict;
        flow decideThreatVerdict to cleanMessage;
    }

    action def StoreMessage {
        in item messageIn : EmailMessage;
        in item targetMailbox : MailboxReference;
        out item storedMessage : EmailMessage;
        out item storeReceipt : DeliveryReceipt;

        action verifyQuota;
        action writeMessageRecord;
        action writeAttachmentBlobs;
        action updateMailboxIndex;
        action createStoreReceipt;

        flow messageIn to verifyQuota;
        flow targetMailbox to verifyQuota;
        flow verifyQuota to writeMessageRecord;
        flow writeMessageRecord to writeAttachmentBlobs;
        flow writeAttachmentBlobs to updateMailboxIndex;
        flow updateMailboxIndex to storedMessage;
        flow updateMailboxIndex to createStoreReceipt;
        flow createStoreReceipt to storeReceipt;
    }

    action def RouteEmail {
        in item messageIn : EmailMessage;
        out item localMessage : EmailMessage;
        out item remoteMessage : EmailMessage;
        out item routeReceipt : DeliveryReceipt;

        action identifyRecipientDomains;
        action resolveRemoteMailExchangers;
        action splitByDestination;
        action enqueueLocalDelivery;
        action enqueueRemoteDelivery;

        flow messageIn to identifyRecipientDomains;
        flow identifyRecipientDomains to resolveRemoteMailExchangers;
        flow resolveRemoteMailExchangers to splitByDestination;
        flow splitByDestination to enqueueLocalDelivery;
        flow splitByDestination to enqueueRemoteDelivery;
        flow enqueueLocalDelivery to localMessage;
        flow enqueueRemoteDelivery to remoteMessage;
    }

    action def DeliverToMailbox {
        in item messageIn : EmailMessage;
        out item deliveredMessage : EmailMessage;
        out item deliveryReceipt : DeliveryReceipt;

        action locateRecipientMailbox;
        action appendToInbox;
        action markUnread;
        action publishDeliveryEvent;

        flow messageIn to locateRecipientMailbox;
        flow locateRecipientMailbox to appendToInbox;
        flow appendToInbox to markUnread;
        flow markUnread to publishDeliveryEvent;
        flow publishDeliveryEvent to deliveredMessage;
        flow publishDeliveryEvent to deliveryReceipt;
    }

    action def RetrieveMailbox {
        in item request : RetrieveRequest;
        out item mailboxView : MailboxView;

        action authenticateRetrieval;
        action selectFolder;
        action loadMessageSummaries;
        action applyAccessPolicy;
        action returnMailboxView;

        flow request to authenticateRetrieval;
        flow authenticateRetrieval to selectFolder;
        flow selectFolder to loadMessageSummaries;
        flow loadMessageSummaries to applyAccessPolicy;
        flow applyAccessPolicy to returnMailboxView;
        flow returnMailboxView to mailboxView;
    }

    action def SubmitStoreForwardDeliverEmail {
        in item request : ComposeRequest;
        out item receipt : DeliveryReceipt;

        action compose : ComposeEmail;
        action authenticate : AuthenticateUser;
        action validateAddressing : ValidateAddressing;
        action scanContent : ScanEmailContent;
        action storeSenderCopy : StoreMessage;
        action route : RouteEmail;
        action deliverLocal : DeliverToMailbox;
        action acknowledgeSubmission;

        flow request to compose.request;
        flow request.credential to authenticate.request.credential;
        flow compose.composedMessage to validateAddressing.messageIn;
        flow validateAddressing.validatedMessage to scanContent.messageIn;
        flow scanContent.cleanMessage to storeSenderCopy.messageIn;
        flow storeSenderCopy.storedMessage to route.messageIn;
        flow route.localMessage to deliverLocal.messageIn;
        flow deliverLocal.deliveryReceipt to acknowledgeSubmission;
        flow acknowledgeSubmission to receipt;
    }

    state def EmailMessageLifecycle {
        state Draft;
        state Submitted;
        state Authenticated;
        state Accepted;
        state Scanned;
        state Stored;
        state Routed;
        state Delivered;
        state Read;
        state Archived;
        state Deleted;
        state Quarantined;
        state Bounced;

        transition InitialToDraft first Draft;
        transition SubmitDraft first Draft then Submitted;
        transition AuthenticateSubmission first Submitted then Authenticated;
        transition AcceptMessage first Authenticated then Accepted;
        transition QuarantineUnsafeMessage first Accepted then Quarantined;
        transition CompleteThreatScan first Accepted then Scanned;
        transition StoreAcceptedMessage first Scanned then Stored;
        transition RouteStoredMessage first Stored then Routed;
        transition DeliverRoutedMessage first Routed then Delivered;
        transition MarkAsRead first Delivered then Read;
        transition ArchiveReadMessage first Read then Archived;
        transition DeleteMessage first Delivered then Deleted;
        transition BounceUndeliverableMessage first Routed then Bounced;
    }

    state def EmailServiceOperatingState {
        state Starting;
        state AcceptingTraffic;
        state Degraded;
        state Maintenance;
        state Stopping;
        state Stopped;

        transition InitialStartup first Starting;
        transition StartupComplete first Starting then AcceptingTraffic;
        transition DependencyFailure first AcceptingTraffic then Degraded;
        transition DependencyRecovered first Degraded then AcceptingTraffic;
        transition BeginMaintenance first AcceptingTraffic then Maintenance;
        transition EndMaintenance first Maintenance then AcceptingTraffic;
        transition StopRequested first AcceptingTraffic then Stopping;
        transition StopCompleted first Stopping then Stopped;
    }

    part def EmailClient {
        port userAccess : UserEmailPort;
        port submission : SubmissionPort;
        port mailboxAccess : MailboxAccessPort;

        attribute maximumRenderedAttachmentSizeMiB : Mebibyte = 20.0;
        attribute autosaveIntervalSeconds : Second = 30.0;

        perform action composeEmail : ComposeEmail;
        perform action retrieveMailbox : RetrieveMailbox;
    }

    part def IdentityDirectory {
        port directory : DirectoryPort;

        attribute maximumTokenAgeSeconds : Second = 3600.0;
        attribute minimumPasswordLength : Count = 12;

        perform action authenticateUser : AuthenticateUser;
    }

    part def SmtpSubmissionGateway {
        port submissionIn : SubmissionPort;
        port directoryAccess : DirectoryPort;
        port acceptedOut : RoutePort;

        attribute maximumSubmissionRatePerUser : MessagePerSecond = 2.0;
        attribute submissionTimeoutMs : Millisecond = 5000.0;

        perform action authenticateSubmission : AuthenticateUser;
        perform action validateAddressing : ValidateAddressing;
    }

    part def ContentProtectionService {
        port scanner : ThreatScanningPort;
        port cleanMessageOut : RoutePort;

        attribute maximumScanLatencyMs : Millisecond = 2000.0;
        attribute spamThresholdPercent : Percent = 85.0;
        attribute phishingThresholdPercent : Percent = 75.0;

        perform action scanEmailContent : ScanEmailContent;
    }

    part def MailRouter {
        port routeIn : RoutePort;
        port domainResolver : DomainResolutionPort;
        port localDelivery : StorePort;
        port remoteExchange : MailExchangePort;

        attribute routeDecisionTimeoutMs : Millisecond = 1000.0;
        attribute retryDelayMinutes : Minute = 15.0;
        attribute maximumDeliveryAttempts : Count = 12;

        perform action routeEmail : RouteEmail;
    }

    part def MailboxStore {
        port store : StorePort;
        port mailboxAccess : MailboxAccessPort;

        attribute defaultMailboxQuotaMiB : Mebibyte = 10240.0;
        attribute maximumMessageSizeMiB : Mebibyte = 25.0;
        attribute replicatedCopies : Count = 3;
        attribute targetReadLatencyMs : Millisecond = 200.0;

        perform action storeMessage : StoreMessage;
        perform action retrieveMailbox : RetrieveMailbox;
    }

    part def NotificationService {
        port notifications : NotificationPort;
        port userNotifications : UserEmailPort;

        attribute notificationTargetLatencyMs : Millisecond = 1000.0;
    }

    part def DomainNameServiceConnector {
        port resolver : DomainResolutionPort;

        attribute resolverTimeoutMs : Millisecond = 750.0;
        attribute cacheTtlSeconds : Second = 300.0;
    }

    part def ExternalMailNetwork {
        port mailExchange : MailExchangePort;

        attribute remoteDeliveryTimeoutSeconds : Second = 30.0;
    }

    part def EmailService {
        port userFacing : UserEmailPort;
        port externalMailExchange : MailExchangePort;
        port domainResolution : DomainResolutionPort;

        attribute providesMessageTransfer : Boolean = true;
        attribute maximumAcceptedMessageSizeMiB : Mebibyte = 25.0;
        attribute minimumAvailabilityPercent : Percent = 99.9;
        attribute primaryDeliveryObjectiveMinutes : Minute = 5.0;
        attribute inboundThroughputCapacity : MessagePerSecond = 500.0;
        attribute outboundThroughputCapacity : MessagePerSecond = 500.0;

        part client : EmailClient;
        part identityDirectory : IdentityDirectory;
        part submissionGateway : SmtpSubmissionGateway;
        part contentProtection : ContentProtectionService;
        part router : MailRouter;
        part mailboxStore : MailboxStore;
        part notificationService : NotificationService;
        part dnsConnector : DomainNameServiceConnector;

        perform action primaryEmailFunction : SubmitStoreForwardDeliverEmail;
        exhibit state serviceState : EmailServiceOperatingState;

        connect userFacing to client.userAccess;
        connect client.submission to submissionGateway.submissionIn;
        connect client.mailboxAccess to mailboxStore.mailboxAccess;
        connect submissionGateway.directoryAccess to identityDirectory.directory;
        connect submissionGateway.acceptedOut to contentProtection.cleanMessageOut;
        connect contentProtection.cleanMessageOut to router.routeIn;
        connect router.localDelivery to mailboxStore.store;
        connect router.remoteExchange to externalMailExchange;
        connect router.domainResolver to dnsConnector.resolver;
        connect dnsConnector.resolver to domainResolution;
        connect mailboxStore.store to notificationService.notifications;
        connect notificationService.userNotifications to userFacing;
    }

    part def EmailOperationalContext {
        part emailService : EmailService;
        part externalMailNetwork : ExternalMailNetwork;

        connect emailService.externalMailExchange to externalMailNetwork.mailExchange;
    }

    constraint def MessageSizeLimitConstraint {
        in actualSizeMiB : Mebibyte;
        in allowedSizeMiB : Mebibyte;
        actualSizeMiB <= allowedSizeMiB;
    }

    constraint def DeliveryLatencyConstraint {
        in actualLatencyMinutes : Minute;
        in allowedLatencyMinutes : Minute;
        actualLatencyMinutes <= allowedLatencyMinutes;
    }

    constraint def AvailabilityConstraint {
        in measuredAvailabilityPercent : Percent;
        in requiredAvailabilityPercent : Percent;
        measuredAvailabilityPercent >= requiredAvailabilityPercent;
    }

    constraint def ThreatConfidenceConstraint {
        in threatConfidencePercent : Percent;
        in blockingThresholdPercent : Percent;
        threatConfidencePercent < blockingThresholdPercent;
    }

    constraint def MailboxQuotaConstraint {
        in quotaUsedMiB : Mebibyte;
        in quotaLimitMiB : Mebibyte;
        quotaUsedMiB <= quotaLimitMiB;
    }

    requirement def PrimaryEmailFunctionRequirement {
        doc /*
            The EmailService shall provide a high-level electronic mail function that accepts
            authenticated user messages, stores durable copies, determines local or remote
            destinations, delivers messages to recipients, and provides status feedback.
        */
        subject emailService : EmailService;

        require constraint {
            emailService.providesMessageTransfer == true
        }
    }

    requirement def AuthenticatedSubmissionRequirement {
        doc /*
            The EmailService shall accept message submission only when the submitting user's
            credential is valid, current, and associated with the claimed sender address.
        */
        subject submissionGateway : SmtpSubmissionGateway;
    }

    requirement def MessageSizeRequirement {
        doc /*
            The EmailService shall reject or bounce any submitted EmailMessage whose total encoded
            size exceeds 25 MiB.
        */
        subject emailService : EmailService;

        require constraint messageSizeLimit : MessageSizeLimitConstraint {
            in allowedSizeMiB = emailService.maximumAcceptedMessageSizeMiB;
        }
    }

    requirement def LocalDeliveryLatencyRequirement {
        doc /*
            For a clean message addressed to a local mailbox under normal operating conditions,
            the EmailService shall deliver the message to the recipient inbox within 5 minutes.
        */
        subject emailService : EmailService;

        require constraint deliveryLatency : DeliveryLatencyConstraint {
            in allowedLatencyMinutes = emailService.primaryDeliveryObjectiveMinutes;
        }
    }

    requirement def MailboxDurabilityRequirement {
        doc /*
            The MailboxStore shall maintain three replicated durable copies of accepted messages
            before reporting successful local storage.
        */
        subject mailboxStore : MailboxStore;

        require constraint {
            mailboxStore.replicatedCopies >= 3
        }
    }

    requirement def ContentProtectionRequirement {
        doc /*
            The EmailService shall scan message headers, body content, and attachments for malware,
            spam, and phishing indicators before local delivery or remote relay.
        */
        subject contentProtection : ContentProtectionService;
    }

    requirement def MailboxQuotaRequirement {
        doc /*
            The MailboxStore shall prevent delivery into a mailbox when accepting the message would
            exceed the mailbox quota and shall generate a failure receipt.
        */
        subject mailboxStore : MailboxStore;
    }

    requirement def AvailabilityRequirement {
        doc /*
            The EmailService shall maintain at least 99.9 percent monthly service availability for
            compose, submit, retrieve, and local-delivery functions.
        */
        subject emailService : EmailService;

        require constraint availability : AvailabilityConstraint {
            in requiredAvailabilityPercent = emailService.minimumAvailabilityPercent;
        }
    }

    requirement primaryFunction : PrimaryEmailFunctionRequirement {
        subject emailService : EmailService;
    }

    requirement authenticatedSubmission : AuthenticatedSubmissionRequirement {
        subject submissionGateway : SmtpSubmissionGateway;
    }

    requirement messageSize : MessageSizeRequirement {
        subject emailService : EmailService;
    }

    requirement localDeliveryLatency : LocalDeliveryLatencyRequirement {
        subject emailService : EmailService;
    }

    requirement mailboxDurability : MailboxDurabilityRequirement {
        subject mailboxStore : MailboxStore;
    }

    requirement contentProtection : ContentProtectionRequirement {
        subject contentProtectionService : ContentProtectionService;
    }

    requirement mailboxQuota : MailboxQuotaRequirement {
        subject mailboxStore : MailboxStore;
    }

    requirement availability : AvailabilityRequirement {
        subject emailService : EmailService;
    }

    satisfy primaryFunction by EmailService::primaryEmailFunction;
    satisfy authenticatedSubmission by SmtpSubmissionGateway::authenticateSubmission;
    satisfy messageSize by EmailService::maximumAcceptedMessageSizeMiB;
    satisfy localDeliveryLatency by DeliverToMailbox;
    satisfy mailboxDurability by MailboxStore::replicatedCopies;
    satisfy contentProtection by ContentProtectionService::scanEmailContent;
    satisfy mailboxQuota by StoreMessage::verifyQuota;
    satisfy availability by EmailService::serviceState;
}
