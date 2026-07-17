package EmailSystem {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;
    
    attribute def EmailAddress :> String;
    attribute def MessageContent :> String;
    attribute def Subject :> String;
    attribute def Timestamp :> String;
    attribute def MessageSize :> Real;
    attribute def DataRate :> Real;
    
    enum def MessageStatus {
        draft;
        queued;
        sending;
        sent;
        delivered;
        failed;
        read;
    }
    
    enum def Priority {
        low;
        normal;
        high;
        urgent;
    }
    
    item def EmailMessage {
        attribute messageId : String;
        attribute sender : EmailAddress;
        attribute recipient : EmailAddress[1..*];
        attribute cc : EmailAddress[0..*];
        attribute subjectLine : Subject;
        attribute body : MessageContent;
        attribute timestamp : Timestamp;
        attribute size : MessageSize;
        attribute status : MessageStatus;
        attribute priority : Priority;
    }
    
    port def NetworkPort {
        attribute portNumber : Integer;
        attribute protocol : String;
        out item outgoing : EmailMessage;
        in item incoming : EmailMessage;
    }
    
    port def UserInterfacePort {
        in item receivedMessages : EmailMessage[*];
        out item outgoingMessages : EmailMessage[*];
    }
    
    part def UserInterface {
        port uiPort : UserInterfacePort;
        
        action composeEmail {
            in fromAddress : EmailAddress;
            in toAddresses : EmailAddress[1..*];
            in subjectText : Subject;
            in bodyText : MessageContent;
            out newMessage : EmailMessage;
        }
        
        action displayInbox {
            in messages : EmailMessage[*];
        }
    }
    
    part def MessageComposer {
        action createMessage {
            in fromAddress : EmailAddress;
            in toAddresses : EmailAddress[1..*];
            in subjectText : Subject;
            in bodyText : MessageContent;
            out composedMessage : EmailMessage;
            
            first start;
            then action initializeMessage {
                out msg : EmailMessage;
            }
            then action validateRecipients {
                in msg : EmailMessage;
                out validMsg : EmailMessage;
            }
            then action assignMessageId {
                in msg : EmailMessage;
                out finalMsg : EmailMessage;
            }
            then done;
        }
    }
    
    part def MessageQueue {
        attribute queueSize : Integer;
        attribute maxQueueSize : Integer = 10000;
        
        action enqueueMessage {
            in message : EmailMessage;
            out queuedMessage : EmailMessage;
        }
        
        action dequeueMessage {
            out nextMessage : EmailMessage;
        }
        
        assert constraint queueCapacity {
            queueSize <= maxQueueSize
        }
    }
    
    part def SMTPClient {
        port smtpPort : NetworkPort {
            :>> portNumber = 587;
            :>> protocol = "SMTP";
        }
        
        state def SendingStateMachine {
            entry; then idle;
            
            state idle;
            state connecting;
            state authenticating;
            state transmitting;
            state sent;
            state failed;
            
            transition idle_to_connecting
                first idle
                accept message : EmailMessage
                then connecting;
            
            transition connecting_to_authenticating
                first connecting
                then authenticating;
            
            transition connecting_to_failed
                first connecting
                then failed;
            
            transition authenticating_to_transmitting
                first authenticating
                then transmitting;
            
            transition authenticating_to_failed
                first authenticating
                then failed;
            
            transition transmitting_to_sent
                first transmitting
                then sent;
            
            transition transmitting_to_failed
                first transmitting
                then failed;
            
            transition sent_to_idle
                first sent
                then idle;
            
            transition failed_to_idle
                first failed
                then idle;
        }
        
        action sendEmail {
            in message : EmailMessage;
            out result : MessageStatus;
        }
    }
    
    part def MessageStore {
        attribute storageCapacity : MessageSize;
        attribute usedStorage : MessageSize;
        
        action storeMessage {
            in message : EmailMessage;
            out stored : Boolean;
        }
        
        action retrieveMessages {
            in filter : String;
            out messages : EmailMessage[*];
        }
        
        assert constraint storageLimit {
            usedStorage <= storageCapacity
        }
    }
    
    part def SpamFilter {
        attribute spamThreshold : Real = 0.75;
        
        action analyzeMessage {
            in message : EmailMessage;
            out spamScore : Real;
            out isSpam : Boolean;
            
            first start;
            then action checkSender;
            then action analyzeContent;
            then action calculateScore;
            then decide;
                if spamScore >= spamThreshold then markAsSpam;
                if spamScore < spamThreshold then markAsLegitimate;
            
            action markAsSpam {
                out :>> isSpam = true;
            }
            then done;
            
            action markAsLegitimate {
                out :>> isSpam = false;
            }
            then done;
        }
    }
    
    part def EmailClient {
        attribute maxMessageSize : MessageSize = 25.0;
        
        part ui : UserInterface;
        part composer : MessageComposer;
        part queue : MessageQueue;
        part smtpClient : SMTPClient;
        part store : MessageStore;
        part spamFilter : SpamFilter;
        
        action processOutgoingEmail {
            first start;
            then action compose : MessageComposer::createMessage;
            then action enqueue : MessageQueue::enqueueMessage {
                in message = compose.composedMessage;
            }
            then action send : SMTPClient::sendEmail {
                in message = enqueue.queuedMessage;
            }
            then action archive : MessageStore::storeMessage {
                in message = send.message;
            }
            then done;
        }
        
        action processIncomingEmail {
            first start;
            then action receive {
                out incomingMessage : EmailMessage;
            }
            then action filterSpam : SpamFilter::analyzeMessage {
                in message = receive.incomingMessage;
            }
            then decide;
                if filterSpam.isSpam then quarantine;
                if !filterSpam.isSpam then deliver;
            
            action quarantine : MessageStore::storeMessage;
            then done;
            
            action deliver {
                in message : EmailMessage;
            }
            then action storeInInbox : MessageStore::storeMessage {
                in message = deliver.message;
            }
            then action notify : UserInterface::displayInbox;
            then done;
        }
    }
    
    requirement <'REQ-EMAIL-001'> primaryFunction {
        doc /* The email system shall enable users to compose, send, receive, 
             * and manage electronic messages across networks using standard 
             * email protocols.
             */
        subject emailClient : EmailClient;
    }
    
    requirement <'REQ-EMAIL-002'> messageDelivery {
        doc /* The system shall reliably deliver messages to specified 
             * recipients using SMTP protocol.
             */
        subject smtpClient :>> EmailClient::smtpClient;
        
        assert constraint {
            smtpClient.smtpPort.protocol == "SMTP"
        }
    }
    
    requirement <'REQ-EMAIL-003'> spamProtection {
        doc /* The system shall filter incoming messages to identify and 
             * quarantine spam with at least 75% accuracy.
             */
        subject filter :>> EmailClient::spamFilter;
        
        assert constraint {
            filter.spamThreshold >= 0.75
        }
    }
    
    requirement <'REQ-EMAIL-004'> storageManagement {
        doc /* The system shall manage message storage efficiently and 
             * prevent storage overflow.
             */
        subject storage :>> EmailClient::store;
        
        assert constraint {
            storage.usedStorage <= storage.storageCapacity
        }
    }
    
    requirement <'REQ-EMAIL-005'> queueCapacity {
        doc /* The message queue shall handle up to 10000 pending messages 
             * without data loss.
             */
        subject queue :>> EmailClient::queue;
        
        assert constraint {
            queue.maxQueueSize >= 10000
        }
    }
    
    part emailSystem : EmailClient {
        :>> maxMessageSize = 25.0;
        
        part :>> store {
            :>> storageCapacity = 50000.0;
            :>> usedStorage = 15000.0;
        }
        
        part :>> queue {
            :>> maxQueueSize = 10000;
            :>> queueSize = 42;
        }
        
        part :>> spamFilter {
            :>> spamThreshold = 0.80;
        }
    }
    
    satisfy primaryFunction by emailSystem;
    satisfy messageDelivery by emailSystem.smtpClient;
    satisfy spamProtection by emailSystem.spamFilter;
    satisfy storageManagement by emailSystem.store;
    satisfy queueCapacity by emailSystem.queue;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;
    private import EmailSystem::*;

    part testSubject : UserInterface {
        exhibit state sm : SendingStateMachine;
    }
}
