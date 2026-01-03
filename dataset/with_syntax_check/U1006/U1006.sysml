package 'Bus SCS System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MessageID :> Integer;
    attribute def DataPayload :> String;
    attribute def BusLoad :> Real;
    attribute def TransmissionStatus;
    
    enum def TransmissionStatusKind {
        enum idle;
        enum transmitting;
        enum receiving;
        enum error;
    }
    
    enum def BusStateKind {
        enum offline;
        enum initializing;
        enum operational;
        enum degraded;
        enum fault;
    }
    
    item def Message {
        attribute id : MessageID;
        attribute payload : DataPayload;
        attribute timestamp : TimeValue;
        attribute priority : Integer;
    }
    
    item def DiagnosticData {
        attribute errorCount : Integer;
        attribute busUtilization : BusLoad;
        attribute lastError : String;
    }
    
    port def BusPort {
        attribute bandwidth : Real;
        attribute messageIn : Message;
        attribute messageOut : Message;
    }
    
    port def PowerPort {
        attribute voltage : Real;
        attribute current : Real;
    }
    
    port def DiagnosticPort {
        attribute diagnostics : DiagnosticData;
        attribute configCommand : String;
    }
    
    part def ElectronicControlUnit {
        doc /* Electronic Control Unit connected to the bus network */
        
        port busInterface : BusPort;
        port power : PowerPort;
        
        attribute ecuID : String;
        attribute operationalState : BusStateKind;
        
        perform action processMessages;
    }
    
    part def BusController {
        doc /* Central controller managing bus arbitration and scheduling */
        
        port busInterface : BusPort;
        port power : PowerPort;
        port diagnosticInterface : DiagnosticPort;
        
        attribute currentLoad : BusLoad;
        attribute messageQueue : Message[*];
        attribute txState : TransmissionStatusKind;
        
        perform action manageBusTraffic;
    }
    
    part def BusTransceiver {
        doc /* Physical layer transceiver for bus communication */
        
        port busInterface : BusPort;
        port power : PowerPort;
        
        attribute signalStrength : Real;
        attribute errorRate : Real;
        
        perform action transmitReceive;
    }
    
    part def PowerManagementUnit {
        doc /* Manages power distribution to bus components */
        
        port mainPower : PowerPort;
        port distributedPower : PowerPort[*];
        
        attribute inputVoltage : Real;
        attribute outputVoltage : Real;
        attribute totalCurrent : Real;
        
        perform action distributePower;
    }
    
    action def ArbitrateMessages {
        in incomingMessages : Message[*];
        in currentLoad : BusLoad;
        out scheduledMessages : Message[*];
        out updatedLoad : BusLoad;
        
        first start;
        then action sortByPriority {
            in messages : Message[*];
            out sortedMessages : Message[*];
        }
        then action checkCapacity {
            in messages : Message[*];
            in load : BusLoad;
            out canTransmit : Boolean;
            out newLoad : BusLoad;
        }
        then decide;
            if checkCapacity.canTransmit then scheduleTransmission;
            if !checkCapacity.canTransmit then queueMessages;
        
        action scheduleTransmission {
            in messages : Message[*];
            out scheduled : Message[*];
        }
        then done;
        
        action queueMessages {
            in messages : Message[*];
            out queued : Message[*];
        }
        then done;
    }
    
    action def ManageBusOperations {
        in messageTraffic : Message[*];
        in maxLoad : BusLoad;
        out busStatus : BusStateKind;
        out diagnosticInfo : DiagnosticData;
        
        first start;
        then merge monitorBus;
        
        action monitorBus {
            in traffic : Message[*];
            out opState : BusStateKind;
            out load : BusLoad;
        }
        then decide;
            if monitorBus.opState == BusStateKind::offline then initializeBus;
            if monitorBus.opState == BusStateKind::operational then processTraffic;
            if monitorBus.opState == BusStateKind::degraded then attemptRecovery;
            if monitorBus.opState == BusStateKind::fault then handleFault;
        
        action initializeBus {
            out initialized : Boolean;
        }
        then transitionToOperational;
        
        action processTraffic {
            in messages : Message[*];
            in load : BusLoad;
            out processed : Boolean;
        }
        then action arbitrate : ArbitrateMessages {
            in incomingMessages = processTraffic.messages;
            in currentLoad = processTraffic.load;
            out scheduledMessages;
            out updatedLoad;
        }
        then monitorBus;
        
        action attemptRecovery {
            out recovered : Boolean;
        }
        then decide;
            if attemptRecovery.recovered then transitionToOperational;
            if !attemptRecovery.recovered then handleFault;
        
        action handleFault {
            out faultCleared : Boolean;
        }
        then decide;
            if handleFault.faultCleared then initializeBus;
            if !handleFault.faultCleared then monitorBus;
        
        action transitionToOperational {
            out operational : Boolean;
        }
        then monitorBus;
    }
    
    action def TransmitMessage {
        in message : Message;
        in busAvailable : Boolean;
        out transmitted : Boolean;
        out status : TransmissionStatusKind;
        
        first start;
        then decide;
            if busAvailable then beginTransmission;
            if !busAvailable then waitForBus;
        
        action beginTransmission {
            in msg : Message;
            out success : Boolean;
        }
        then done;
        
        action waitForBus {
            out ready : Boolean;
        }
        then beginTransmission;
    }
    
    state def BusControllerStateMachine {
        entry; then Offline;
        
        state Offline;
        state Initializing;
        state Operational;
        state Degraded;
        state Fault;
        
        transition first Offline then Initializing;
        transition Initializing then Operational;
        transition Operational then Degraded;
        transition Degraded then Operational;
        transition Operational then Fault;
        transition Fault then Initializing;
    }
    
    part def BusSCS {
        doc /* 
            Bus Supervisory Control System (SCS) coordinates communication between 
            distributed electronic control units through a shared communication bus,
            managing message arbitration, scheduling, power distribution, and fault 
            detection to ensure reliable real-time data exchange across the system.
        */
        
        attribute systemID : String;
        attribute maxBusLoad : BusLoad;
        attribute operatingVoltage : Real;
        attribute nominalBandwidth : Real;
        
        part controller : BusController {
            :>> currentLoad = 0.0;
            :>> txState = TransmissionStatusKind::idle;
        }
        
        part transceiver : BusTransceiver {
            :>> signalStrength = 5.0;
            :>> errorRate = 0.001;
        }
        
        part powerUnit : PowerManagementUnit {
            :>> inputVoltage = 12.0;
            :>> outputVoltage = 5.0;
        }
        
        part ecu1 : ElectronicControlUnit {
            :>> ecuID = "ECU-001";
            :>> operationalState = BusStateKind::offline;
        }
        
        part ecu2 : ElectronicControlUnit {
            :>> ecuID = "ECU-002";
            :>> operationalState = BusStateKind::offline;
        }
        
        part ecu3 : ElectronicControlUnit {
            :>> ecuID = "ECU-003";
            :>> operationalState = BusStateKind::offline;
        }
        
        connection powerToController connect powerUnit.distributedPower to controller.power;
        connection powerToTransceiver connect powerUnit.distributedPower to transceiver.power;
        connection powerToECU1 connect powerUnit.distributedPower to ecu1.power;
        connection powerToECU2 connect powerUnit.distributedPower to ecu2.power;
        connection powerToECU3 connect powerUnit.distributedPower to ecu3.power;
        
        connection controllerToTransceiver connect controller.busInterface to transceiver.busInterface;
        connection transceiverToECU1 connect transceiver.busInterface to ecu1.busInterface;
        connection transceiverToECU2 connect transceiver.busInterface to ecu2.busInterface;
        connection transceiverToECU3 connect transceiver.busInterface to ecu3.busInterface;
        
        perform action operateBus : ManageBusOperations {
            in messageTraffic;
            in maxLoad = busSCS.maxBusLoad;
            out busStatus;
            out diagnosticInfo;
        }
        
        state machine behavior controllerBehavior : BusControllerStateMachine;
    }
    
    part busSCS : BusSCS {
        :>> systemID = "BUS-SCS-001";
        :>> maxBusLoad = 0.85;
        :>> operatingVoltage = 12.0;
        :>> nominalBandwidth = 1.0;
        
        perform operateBus;
    }
    
    requirement def FunctionalRequirement {
        doc /* Functional requirements for Bus SCS operation */
        subject scs : BusSCS;
    }
    
    requirement def PerformanceRequirement {
        doc /* Performance requirements for Bus SCS operation */
        subject scs : BusSCS;
    }
    
    requirement primaryFunction : FunctionalRequirement {
        doc /* 
            The Bus SCS shall coordinate real-time communication between all connected 
            electronic control units by managing message arbitration, transmission 
            scheduling, and bus access control to ensure deterministic data exchange.
        */
        subject busSCS;
    }
    
    requirement messageArbitration : FunctionalRequirement {
        doc /* 
            The Bus SCS shall arbitrate message transmission based on priority to 
            ensure critical messages are transmitted before lower-priority messages.
        */
        subject busSCS.controller;
    }
    
    requirement busLoadManagement : PerformanceRequirement {
        doc /* 
            The Bus SCS shall maintain bus utilization below 85% to prevent 
            message collisions and ensure timely delivery.
        */
        subject busSCS.controller;
    }
    
    requirement faultDetection : FunctionalRequirement {
        doc /* 
            The Bus SCS shall detect bus faults and transition to degraded mode 
            within 50 milliseconds of fault occurrence.
        */
        subject busSCS.controller;
    }
    
    requirement powerDistribution : FunctionalRequirement {
        doc /* 
            The Bus SCS shall provide stable power at 5V to all connected 
            electronic control units.
        */
        subject busSCS.powerUnit;
    }
    
    requirement communicationReliability : PerformanceRequirement {
        doc /* 
            The Bus SCS shall maintain a message error rate below 0.1% during 
            normal operational conditions.
        */
        subject busSCS.transceiver;
    }
}
