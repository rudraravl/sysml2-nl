package MessageProcessingSystem {
    import ScalarValues::*;
    import SI::*;

    item def Message {
        attribute id : String;
        attribute payload : String;
        attribute destination : String;
        attribute priority : Integer;
        attribute isValid : Boolean := true;
    }

    value type ProcessingRate :> Real { unit "msg/s" }
    value type Delay :> Real { unit "ms" }

    requirement def PerformanceRequirement {
        doc "The system must process at least 6000 messages per second with an end-to-end delay under 50 ms."
        attribute minProcessingRate : ProcessingRate = 6000;
        attribute maxEndToEndDelay : Delay = 50;
        subject system : DistributedMessageSystem;
        objective {
            doc "Ensure high throughput and low latency."
            constraint { system.processingRate >= minProcessingRate }
            constraint { system.endToEndDelay <= maxEndToEndDelay }
        }
    }

    port def MessageInPort {
        in item messages : Message[*];
    }
    port def MessageOutPort {
        out item messages : Message[*];
    }
    port def MessageInOutPort {
        in item inMessages : Message[*];
        out item outMessages : Message[*];
    }

    part def NetworkInterface {
        port externalIn : MessageInPort;
        port externalOut : MessageOutPort;
        port internalOut : MessageOutPort;
        port internalIn : MessageInPort;

        action def receiveAction {
            in message : Message;
        }
        action def sendAction {
            in message : Message;
        }
    }

    part def MessageValidator {
        port inPort : MessageInPort;
        port validOutPort : MessageOutPort;
        port invalidOutPort : MessageOutPort;

        action def validateAction {
            in message : Message;
            out validMessage : Message;
            out invalidMessage : Message;
        }
    }

    part def MessageProcessor {
        port inPort : MessageInPort;
        port outPort : MessageOutPort;
        port storagePort : MessageOutPort;

        attribute queueSize : Integer = 0;
        attribute maxQueueSize : Integer = 1000;

        state machine def ProcessorStateMachine {
            entry; then idle;
            state idle;
            state processing;
            state error;
            transition idle to processing when inPort.messages.size() > 0;
            transition processing to idle when queueSize == 0;
            transition processing to error when queueSize > maxQueueSize;
            transition error to idle when queueSize < maxQueueSize / 2;
        }

        action def processAction {
            in message : Message;
            out processedMessage : Message;
        }
    }

    part def MessageRouter {
        port inPort : MessageInPort;
        port outPort : MessageOutPort;
        port storagePort : MessageOutPort;

        action def routeAction {
            in message : Message;
            out routedMessage : Message;
        }
    }

    part def MessageStorage {
        port bufferPort : MessageInOutPort;
        port archivePort : MessageInPort;

        action def storeAction {
            in message : Message;
        }
        action def retrieveAction {
            out message : Message;
        }
    }

    part def DistributedMessageSystem {
        attribute processingRate : ProcessingRate;
        attribute endToEndDelay : Delay;

        part networkInterface : NetworkInterface;
        part validator : MessageValidator;
        part processors : MessageProcessor[3];
        part router : MessageRouter;
        part storage : MessageStorage;

        satisfy PerformanceRequirement;

        connection networkInterface.internalOut to validator.inPort;
        connection validator.validOutPort to processors.inPort;
        connection processors.outPort to router.inPort;
        connection router.outPort to networkInterface.internalIn;

        connection validator.invalidOutPort to storage.archivePort;
        connection processors.storagePort to storage.bufferPort;
        connection router.storagePort to storage.bufferPort;
    }
}
