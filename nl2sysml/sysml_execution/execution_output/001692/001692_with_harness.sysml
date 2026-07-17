package ApacheLicensedDistributedSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    metadata def LicenseInfo {
        attribute licenseName : String;
        attribute licenseVersion : String;
        attribute licenseURL : String;
        attribute copyrightNotice : String;
        attribute year : String;
    }

    @LicenseInfo {
        licenseName = "Apache License";
        licenseVersion = "2.0";
        licenseURL = "http://www.apache.org/licenses/LICENSE-2.0";
        copyrightNotice = "Copyright 2025 Open Source Contributors";
        year = "2025";
    }

    attribute def Throughput :> ISQ::PowerAndRelatedQuantities::frequency;
    attribute def Latency :> ISQ::SpaceAndTimeQuantities::time;
    attribute def DataVolume :> ISQ::MechanicsQuantities::mass;

    enum def MessagePriority {
        low;
        medium;
        high;
        critical;
    }

    enum def ProcessingStatus {
        idle;
        receiving;
        validating;
        processing;
        routing;
        transmitting;
        error;
    }

    item def Message {
        attribute messageID : String;
        attribute payload : String;
        attribute priority : MessagePriority;
        attribute timestamp : Real;
        attribute sourceNode : String;
        attribute destinationNode : String;
        attribute size : Real;
    }

    port def MessageInputPort {
        in item messageIn : Message;
    }

    port def MessageOutputPort {
        out item messageOut : Message;
    }

    port def ControlPort {
        in attribute controlCommand : String;
        out attribute statusReport : String;
    }

    part def MessageValidator {
        attribute validationRate : Throughput;
        
        port inputPort : MessageInputPort;
        port outputPort : MessageOutputPort;
        port controlPort : ControlPort;

        action def ValidateMessage {
            in msg : Message;
            out isValid : Boolean;
            out validatedMsg : Message;
        }

        perform action validate {
            first start;
            then action receive {
                out receivedMessage : Message;
            }
            then action checkIntegrity {
                in message : Message = receive.receivedMessage;
                out integrityOK : Boolean;
            }
            then decide;
                if checkIntegrity.integrityOK then forward;
                if !checkIntegrity.integrityOK then reject;
            action forward {
                in validMessage : Message = receive.receivedMessage;
                out forwardedMessage : Message;
            }
            then done;
            action reject {
                in invalidMessage : Message = receive.receivedMessage;
            }
            then done;
        }
    }

    part def MessageProcessor {
        attribute processingCapacity : Throughput;
        attribute currentStatus : ProcessingStatus;
        attribute queueDepth : Integer;

        port inputPort : MessageInputPort;
        port outputPort : MessageOutputPort;
        port controlPort : ControlPort;

        action def ProcessMessage {
            in inputMsg : Message;
            out processedMsg : Message;
        }

        perform action process {
            first start;
            then merge continueProcessing;
            then action dequeue {
                out message : Message;
            }
            then action transform {
                in rawMessage : Message = dequeue.message;
                out transformedMessage : Message;
            }
            then action enrich {
                in baseMessage : Message = transform.transformedMessage;
                out enrichedMessage : Message;
            }
            then action route {
                in finalMessage : Message = enrich.enrichedMessage;
            }
            then continueProcessing;
        }

        state processingStateMachine {
            entry; then idle;

            state idle {
                entry assign currentStatus := ProcessingStatus::idle;
            }
            transition idle_to_receiving
                first idle
                accept at inputPort.messageIn
                then receiving;

            state receiving {
                entry assign currentStatus := ProcessingStatus::receiving;
            }
            transition receiving_to_validating
                first receiving
                then validating;

            state validating {
                entry assign currentStatus := ProcessingStatus::validating;
            }
            transition validating_to_processing
                first validating
                if queueDepth < 100
                then processing;

            state processing {
                entry assign currentStatus := ProcessingStatus::processing;
                do action process;
            }
            transition processing_to_routing
                first processing
                then routing;

            state routing {
                entry assign currentStatus := ProcessingStatus::routing;
            }
            transition routing_to_transmitting
                first routing
                then transmitting;

            state transmitting {
                entry assign currentStatus := ProcessingStatus::transmitting;
            }
            transition transmitting_to_idle
                first transmitting
                then idle;

            transition to_error
                first processing
                if queueDepth >= 100
                then error;

            state error {
                entry assign currentStatus := ProcessingStatus::error;
            }
            transition error_to_idle
                first error
                then idle;
        }
    }

    part def MessageRouter {
        attribute routingCapacity : Throughput;
        attribute routingTableSize : Integer;

        port inputPort : MessageInputPort;
        port outputPort1 : MessageOutputPort;
        port outputPort2 : MessageOutputPort;
        port controlPort : ControlPort;

        action def RouteMessage {
            in message : Message;
            out route1Message : Message;
            out route2Message : Message;
        }

        perform action route {
            first start;
            then action receiveMessage {
                out msg : Message;
            }
            then action determineRoute {
                in inputMessage : Message = receiveMessage.msg;
                out routeDecision : Integer;
            }
            then decide;
                if determineRoute.routeDecision == 1 then sendRoute1;
                if determineRoute.routeDecision == 2 then sendRoute2;
            action sendRoute1 {
                in message : Message = receiveMessage.msg;
            }
            then done;
            action sendRoute2 {
                in message : Message = receiveMessage.msg;
            }
            then done;
        }
    }

    part def MessageStorage {
        attribute storageCapacity : DataVolume;
        attribute currentUtilization : Real;

        port storageControlPort : ControlPort;

        action def StoreMessage {
            in message : Message;
            out storageSuccess : Boolean;
        }

        action def RetrieveMessage {
            in messageID : String;
            out retrievedMessage : Message;
        }

        action def ArchiveMessages {
            in messageList : Message[*];
            out archiveSuccess : Boolean;
        }
    }

    part def NetworkInterface {
        attribute transmitRate : Throughput;
        attribute receiveRate : Throughput;
        attribute maxLatency : Latency;

        port externalInputPort : MessageInputPort;
        port externalOutputPort : MessageOutputPort;
        port internalInputPort : MessageInputPort;
        port internalOutputPort : MessageOutputPort;
        port controlPort : ControlPort;

        action def TransmitExternal {
            in internalMessage : Message;
            out externalMessage : Message;
        }

        action def ReceiveExternal {
            in externalMessage : Message;
            out internalMessage : Message;
        }
    }

    connection def MessageFlow {
        end source : MessageOutputPort;
        end target : MessageInputPort;
    }

    part def DistributedMessageProcessingSystem {
        doc /* 
         * Primary Function: This distributed message processing system receives messages 
         * from external sources, validates their integrity, processes them through multiple 
         * parallel processing nodes, routes them based on priority and destination, and 
         * transmits the processed results to external recipients. The system provides 
         * high-throughput, low-latency message handling with fault tolerance and scalability.
         */

        attribute systemThroughput : Throughput;
        attribute totalStorageCapacity : DataVolume;
        attribute averageLatency : Latency;
        attribute activeProcessors : Integer;

        part networkInterface : NetworkInterface {
            attribute :>> transmitRate = 5000.0 [Hz];
            attribute :>> receiveRate = 5000.0 [Hz];
            attribute :>> maxLatency = 0.05 [s];
        }

        part validator : MessageValidator {
            attribute :>> validationRate = 6000.0 [Hz];
        }

        part processor1 : MessageProcessor {
            attribute :>> processingCapacity = 2000.0 [Hz];
            attribute :>> currentStatus = ProcessingStatus::idle;
            attribute :>> queueDepth = 0;
        }

        part processor2 : MessageProcessor {
            attribute :>> processingCapacity = 2000.0 [Hz];
            attribute :>> currentStatus = ProcessingStatus::idle;
            attribute :>> queueDepth = 0;
        }

        part processor3 : MessageProcessor {
            attribute :>> processingCapacity = 2000.0 [Hz];
            attribute :>> currentStatus = ProcessingStatus::idle;
            attribute :>> queueDepth = 0;
        }

        part router : MessageRouter {
            attribute :>> routingCapacity = 8000.0 [Hz];
            attribute :>> routingTableSize = 1000;
        }

        part storage : MessageStorage {
            attribute :>> storageCapacity = 10000.0 [kg];
            attribute :>> currentUtilization = 0.0;
        }

        connection inputToValidator : MessageFlow
            connect networkInterface.internalOutputPort to validator.inputPort;

        connection validatorToProcessor1 : MessageFlow
            connect validator.outputPort to processor1.inputPort;

        connection validatorToProcessor2 : MessageFlow
            connect validator.outputPort to processor2.inputPort;

        connection validatorToProcessor3 : MessageFlow
            connect validator.outputPort to processor3.inputPort;

        connection processor1ToRouter : MessageFlow
            connect processor1.outputPort to router.inputPort;

        connection processor2ToRouter : MessageFlow
            connect processor2.outputPort to router.inputPort;

        connection processor3ToRouter : MessageFlow
            connect processor3.outputPort to router.inputPort;

        connection routerToOutput1 : MessageFlow
            connect router.outputPort1 to networkInterface.internalInputPort;

        connection routerToOutput2 : MessageFlow
            connect router.outputPort2 to networkInterface.internalInputPort;

        assert constraint totalThroughputCapacity {
            systemThroughput == processor1.processingCapacity + processor2.processingCapacity + processor3.processingCapacity
        }

        assert constraint storageUtilizationLimit {
            storage.currentUtilization <= storage.storageCapacity
        }

        perform action operateSystem {
            first start;
            then merge continuousOperation;
            then action receiveExternalMessages {
                out externalMsg : Message;
            }
            then action validateIncoming {
                in msg : Message = receiveExternalMessages.externalMsg;
                out validMsg : Message;
            }
            then fork parallelProcessing;
            parallel action processInNode1 {
                do processor1.process;
            }
            parallel action processInNode2 {
                do processor2.process;
            }
            parallel action processInNode3 {
                do processor3.process;
            }
            then join mergeProcessedMessages;
            then action routeMessages {
                out routedMsg : Message;
            }
            then action transmitToExternal {
                in msg : Message = routeMessages.routedMsg;
            }
            then continuousOperation;
        }
    }

    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def ReliabilityRequirement;

    requirement <'SYS-REQ-001'> primaryFunction : FunctionalRequirement {
        doc /* 
         * The distributed message processing system shall receive messages from external 
         * sources, validate their integrity, process them through parallel processing nodes, 
         * route them based on priority and destination, and transmit processed results to 
         * external recipients with high throughput and low latency.
         */
        subject system : DistributedMessageProcessingSystem;
    }

    requirement <'SYS-REQ-002'> minimumThroughput : PerformanceRequirement {
        doc /* 
         * The system shall maintain a minimum aggregate processing throughput of 6000 Hz 
         * across all processing nodes under normal operating conditions.
         */
        subject system : DistributedMessageProcessingSystem;
        assert constraint {
            system.systemThroughput >= 6000.0
        }
    }

    requirement <'SYS-REQ-003'> maximumLatency : PerformanceRequirement {
        doc /* 
         * The system shall process and transmit messages with an average end-to-end latency 
         * not exceeding 50 milliseconds.
         */
        subject system : DistributedMessageProcessingSystem;
        assert constraint {
            system.averageLatency <= 0.05
        }
    }

    requirement <'SYS-REQ-004'> parallelProcessing : FunctionalRequirement {
        doc /* 
         * The system shall utilize at least three independent processing nodes operating 
         * in parallel to maximize throughput and provide fault tolerance.
         */
        subject system : DistributedMessageProcessingSystem;
        assert constraint {
            system.activeProcessors >= 3
        }
    }

    requirement <'SYS-REQ-005'> messageValidation : ReliabilityRequirement {
        doc /* 
         * All incoming messages shall be validated for integrity before processing to ensure 
         * data quality and system reliability.
         */
        subject validator : MessageValidator;
    }

    requirement <'SYS-REQ-006'> storageCapacity : PerformanceRequirement {
        doc /* 
         * The system shall provide sufficient storage capacity of at least 10000 units for 
         * message buffering and archival during peak load conditions.
         */
        subject storage : MessageStorage;
        assert constraint {
            storage.storageCapacity >= 10000.0
        }
    }

    requirement <'SYS-REQ-007'> networkCapacity : PerformanceRequirement {
        doc /* 
         * The network interface shall support bidirectional message transmission at a minimum 
         * rate of 5000 Hz to handle expected system load.
         */
        subject network : NetworkInterface;
        assert constraint {
            network.transmitRate >= 5000.0 and network.receiveRate >= 5000.0
        }
    }

    part deployedSystem : DistributedMessageProcessingSystem {
        attribute :>> systemThroughput = 6000.0 [Hz];
        attribute :>> totalStorageCapacity = 10000.0 [kg];
        attribute :>> averageLatency = 0.045 [s];
        attribute :>> activeProcessors = 3;
    }

    satisfy primaryFunction by deployedSystem;
    satisfy minimumThroughput by deployedSystem;
    satisfy maximumLatency by deployedSystem;
    satisfy parallelProcessing by deployedSystem;
    satisfy messageValidation by deployedSystem.validator;
    satisfy storageCapacity by deployedSystem.storage;
    satisfy networkCapacity by deployedSystem.networkInterface;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    private import ApacheLicensedDistributedSystem::*;

    action orchestrator {
        item testMsg : Message {
            attribute messageID = "";
            attribute payload = "";
            attribute priority = MessagePriority::low;
            attribute timestamp = 0.0;
            attribute sourceNode = "";
            attribute destinationNode = "";
            attribute size = 0.0;
        }
        action actionProbe : ValidateMessage {
            in msg = testMsg;
        }
        first actionProbe;
    }
}
