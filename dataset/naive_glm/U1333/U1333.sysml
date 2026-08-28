package EmailClientApplication {
    import ScalarValues::*;
    import ISQ::*;

    value type MessageSize :> Real {
        :>> unit = "byte";
    }

    value type SpamScoreValue :> Real {
        :>> unit = "dimensionless";
    }

    value type StorageCapacityValue :> Real {
        :>> unit = "byte";
    }

    value type MessageCount :> Integer {
        :>> unit = "dimensionless";
    }

    attribute def TimestampValue :> String;

    enum def MessageStatus {
        draft;
        queued;
        sending;
        sent;
        read;
        failed;
        quarantined;
    }

    enum def PriorityLevel {
        low;
        normal;
        high;
    }

    enum def DeliveryResult {
        success;
        failure;
    }

    enum def FolderType {
        inbox;
        sent;
        spam;
        drafts;
    }

    item def EmailMessage {
        attribute id : String;
        attribute sender : String;
        attribute recipients : String[0..*];
        attribute subject : String;
        attribute body : String;
        attribute timestamp : TimestampValue;
        attribute size : MessageSize;
        attribute status : MessageStatus;
        attribute priority : PriorityLevel;
        attribute spamScore : SpamScoreValue;
    }

    item def IncomingMessage :> EmailMessage;
    item def OutgoingMessage :> EmailMessage;
    item def DraftMessage :> EmailMessage;

    port def DraftInputPort {
        out item draft : DraftMessage;
    }

    port def ComposedMessagePort {
        in item composed : OutgoingMessage;
        out item message : OutgoingMessage;
    }

    port def QueuedMessagePort {
        in item enqueued : OutgoingMessage;
        out item dequeued : OutgoingMessage;
    }

    port def SMTPDeliveryPort {
        in item toSend : OutgoingMessage;
        out item result : DeliveryResult;
    }

    port def IncomingMailPort {
        in item rawIncoming : IncomingMessage;
        out item accepted : IncomingMessage;
    }

    port def FilteredMessagePort {
        out item legitimate : IncomingMessage;
        out item quarantined : IncomingMessage;
    }

    port def StoragePort {
        in item toStore : EmailMessage;
        out item retrieved : EmailMessage;
    }

    port def DisplayPort {
        in item toDisplay : EmailMessage;
    }

    part def UserInterface {
        port draftOutput : DraftInputPort;
        port displayInput : DisplayPort;
        port storeAccess : StoragePort;

        attribute composeViewActive : Boolean = false;
        attribute inboxViewActive : Boolean = true;

        action def ComposeEmail {
            in draft : DraftMessage;
            out structured : DraftMessage;
            perform action AssignFields {
                in d : DraftMessage;
                out s : DraftMessage;
            }
        }

        action def ViewInbox {
            in messages : EmailMessage[0..*];
        }

        action def OpenMessage {
            in message : EmailMessage;
        }
    }

    part def MessageComposer {
        port draftInput : DraftInputPort;
        port composedOutput : ComposedMessagePort;

        attribute nextId : Integer = 1;

        action def Compose {
            in draft : DraftMessage;
            out message : OutgoingMessage;
            perform action AssignUniqueId {
                in d : DraftMessage;
                out id : String;
            }
            then action StructureFields {
                in d : DraftMessage;
                in id : String;
                out m : OutgoingMessage;
            }
        }

        action def AssignUniqueId {
            in d : DraftMessage;
            out id : String;
        }

        action def StructureFields {
            in d : DraftMessage;
            in id : String;
            out m : OutgoingMessage;
        }
    }

    part def MessageQueue {
        port incoming : ComposedMessagePort;
        port outgoing : QueuedMessagePort;

        attribute capacity : MessageCount = 10000;
        attribute currentCount : MessageCount = 0;
        attribute pending : OutgoingMessage[0..10000];

        state def QueueBehavior {
            entry; then Accepting;

            state Accepting {
                entry action acceptMessage;
            }

            state Full {
                entry action rejectMessage;
            }

            state Delivering {
                entry action dequeueMessage;
            }

            transition Accepting -> Full
                if currentCount >= capacity;

            transition Full -> Accepting
                if currentCount < capacity;

            transition Accepting -> Delivering
                when outgoing.dequeued;

            transition Delivering -> Accepting
                if currentCount < capacity;
        }

        action def acceptMessage;
        action def rejectMessage;
        action def dequeueMessage;
    }

    part def SMTPClient {
        port queueConnection : QueuedMessagePort;
        port delivery : SMTPDeliveryPort;

        attribute serverAddress : String;
        attribute serverPort : Integer = 25;
        attribute authenticated : Boolean = false;
        attribute connected : Boolean = false;

        state def SendingProcess {
            entry; then Disconnected;

            state Disconnected {
                entry action resetConnection;
            }

            state Connecting {
                entry action openConnection;
            }

            state Authenticating {
                entry action authenticate;
            }

            state Transmitting {
                entry action transmitData;
            }

            state Confirming {
                entry action awaitConfirmation;
            }

            state Delivered {
                entry action markSent;
            }

            state Failed {
                entry action markFailed;
            }

            transition Disconnected -> Connecting
                when queueConnection.dequeued;

            transition Connecting -> Authenticating
                if connected;

            transition Connecting -> Failed
                if not connected;

            transition Authenticating -> Transmitting
                if authenticated;

            transition Authenticating -> Failed
                if not authenticated;

            transition Transmitting -> Confirming
                if true;

            transition Confirming -> Delivered
                if delivery.result == DeliveryResult::success;

            transition Confirming -> Failed
                if delivery.result == DeliveryResult::failure;

            transition Delivered -> Disconnected;

            transition Failed -> Disconnected;
        }

        action def resetConnection;
        action def openConnection;
        action def authenticate;
        action def transmitData;
        action def awaitConfirmation;
        action def markSent;
        action def markFailed;
    }

    part def SpamFilter {
        port incoming : IncomingMailPort;
        port legitimate : FilteredMessagePort;
        port quarantined : FilteredMessagePort;

        attribute threshold : SpamScoreValue = 0.7;

        action def AnalyzeMessage {
            in message : IncomingMessage;
            out score : SpamScoreValue;
            perform action CheckSender {
                in m : IncomingMessage;
                out s : SpamScoreValue;
            }
            then action CheckContent {
                in m : IncomingMessage;
                out s : SpamScoreValue;
            }
            then action CombineScores {
                in senderScore : SpamScoreValue;
                in contentScore : SpamScoreValue;
                out total : SpamScoreValue;
            }
        }

        action def CheckSender {
            in m : IncomingMessage;
            out s : SpamScoreValue;
        }

        action def CheckContent {
            in m : IncomingMessage;
            out s : SpamScoreValue;
        }

        action def CombineScores {
            in senderScore : SpamScoreValue;
            in contentScore : SpamScoreValue;
            out total : SpamScoreValue;
        }

        action def Quarantine {
            in message : IncomingMessage;
        }

        action def PassThrough {
            in message : IncomingMessage;
        }
    }

    part def MessageStore {
        port storage : StoragePort;

        attribute capacity : StorageCapacityValue = 1073741824;
        attribute usedSpace : StorageCapacityValue = 0;

        part inbox : EmailMessage[0..*];
        part sentItems : EmailMessage[0..*];
        part spamFolder : EmailMessage[0..*];
        part draftsFolder : EmailMessage[0..*];

        action def StoreMessage {
            in message : EmailMessage;
            in folder : FolderType;
            perform action CheckCapacity {
                in m : EmailMessage;
                out canStore : Boolean;
            }
            then action Persist {
                in m : EmailMessage;
                in folder : FolderType;
            }
        }

        action def RetrieveMessage {
            in id : String;
            out message : EmailMessage;
        }

        action def DeleteMessage {
            in id : String;
        }

        action def CheckCapacity {
            in m : EmailMessage;
            out canStore : Boolean;
        }

        action def Persist {
            in m : EmailMessage;
            in folder : FolderType;
        }
    }

    part def EmailClient {
        port externalSMTP : SMTPDeliveryPort;
        port externalIncoming : IncomingMailPort;

        part ui : UserInterface;
        part composer : MessageComposer;
        part queue : MessageQueue;
        part smtpClient : SMTPClient;
        part spamFilter : SpamFilter;
        part store : MessageStore;

        connection ui.draftOutput to composer.draftInput;
        connection composer.composedOutput to queue.incoming;
        connection queue.outgoing to smtpClient.queueConnection;
        connection smtpClient.delivery to externalSMTP;
        connection externalIncoming to spamFilter.incoming;
        connection spamFilter.legitimate to store.storage;
        connection spamFilter.quarantined to store.storage;
        connection store.storage to ui.displayInput;
        connection ui.storeAccess to store.storage;
    }

    requirement def ComposeEmailRequirement {
        subject composer : MessageComposer;
        objective {
            doc "The system shall allow a user to compose an email with recipients, subject, and body, and assign it a unique ID."
        }
    }

    requirement def QueueCapacityRequirement {
        subject queue : MessageQueue;
        objective {
            doc "The Message Queue shall hold up to 10,000 pending messages."
        }
        constraint { queue.capacity == 10000 }
    }

    requirement def SMTPSendingRequirement {
        subject smtpClient : SMTPClient;
        objective {
            doc "The SMTP Client shall send messages through connecting, authenticating, transmitting, and confirming states, reporting success or failure."
        }
    }

    requirement def SpamFilterRequirement {
        subject spamFilter : SpamFilter;
        objective {
            doc "The Spam Filter shall calculate a spam score and quarantine messages above the threshold, passing legitimate messages to the Message Store."
        }
        constraint { spamFilter.threshold == 0.7 }
    }

    requirement def MessageStoreRequirement {
        subject store : MessageStore;
        objective {
            doc "The Message Store shall manage inbox, sent items, and spam folders within a defined storage capacity."
        }
        constraint { store.capacity == 1073741824 }
    }

    requirement def EmailMessageRequirement {
        subject message : EmailMessage;
        objective {
            doc "The Email Message shall include sender, recipients, subject, body, timestamp, size, status, and priority."
        }
    }

    requirement def BufferPersistenceRequirement {
        subject queue : MessageQueue;
        objective {
            doc "The Message Queue shall preserve pending messages when the network connection is slow or temporarily unavailable."
        }
    }

    requirement def IncomingMailRoutingRequirement {
        subject spamFilter : SpamFilter;
        objective {
            doc "Incoming mail shall be analyzed by the Spam Filter before being stored or displayed to the user."
        }
    }

    requirement def UserInteractionRequirement {
        subject ui : UserInterface;
        objective {
            doc "The User Interface shall allow the user to write new emails and view their inbox."
        }
    }
}
