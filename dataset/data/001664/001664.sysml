package IoBridgeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DataRate :> ISQ::FrequencyValue;
    
    attribute def SignalVoltage :> ISQ::ElectricPotentialValue;
    
    item def FieldData {
        attribute sensorId : Integer;
        attribute timestamp : ISQ::TimeValue;
        attribute value : Real;
        attribute quality : Real;
    }
    
    item def ControlCommand {
        attribute actuatorId : Integer;
        attribute commandType : Integer;
        attribute setpoint : Real;
        attribute priority : Integer;
    }
    
    item def DiagnosticMessage {
        attribute sourceId : Integer;
        attribute statusCode : Integer;
        attribute errorFlags : Integer;
        attribute messageText : String;
    }
    
    port def FieldBusPort {
        in item fieldDataIn : FieldData;
        out item commandOut : ControlCommand;
        in item diagnosticIn : DiagnosticMessage;
        attribute busVoltage : SignalVoltage;
        attribute dataRate : DataRate;
    }
    
    port def NetworkPort {
        out item dataUplink : FieldData;
        in item commandDownlink : ControlCommand;
        out item diagnosticUplink : DiagnosticMessage;
        attribute networkSpeed : DataRate;
    }
    
    part def FieldDevice {
        attribute deviceId : Integer;
        attribute operatingVoltage : SignalVoltage;
        port fieldInterface : FieldBusPort;
        
        action def GenerateFieldData {
            out data : FieldData;
        }
        
        action def ExecuteCommand {
            in command : ControlCommand;
            out status : DiagnosticMessage;
        }
    }
    
    part def NetworkController {
        attribute controllerId : Integer;
        attribute maxThroughput : DataRate;
        port networkInterface : NetworkPort;
        
        action def SendData {
            in data : FieldData;
            out transmitStatus : Boolean;
        }
        
        action def ReceiveCommand {
            out command : ControlCommand;
            out receiveStatus : Boolean;
        }
    }
    
    part def DataBuffer {
        attribute capacity : Integer;
        attribute currentOccupancy : Integer;
        
        action def StoreData {
            in data : FieldData;
            out stored : Boolean;
        }
        
        action def RetrieveData {
            out data : FieldData;
            out available : Boolean;
        }
    }
    
    part def ProtocolConverter {
        attribute supportedProtocols : String[*];
        
        action def ConvertFieldToNetwork {
            in fieldData : FieldData;
            out networkData : FieldData;
        }
        
        action def ConvertNetworkToField {
            in networkCommand : ControlCommand;
            out fieldCommand : ControlCommand;
        }
    }
    
    part def DiagnosticMonitor {
        attribute uptime : ISQ::TimeValue;
        attribute errorCount : Integer;
        attribute throughput : DataRate;
        
        action def GenerateDiagnostics {
            out diagnostic : DiagnosticMessage;
        }
        
        action def CheckHealth {
            out healthy : Boolean;
        }
    }
    
    part def IoBridge {
        doc /*
            The IoBridge system serves as a bidirectional communication gateway that bridges
            field-level devices with network-level systems. Its primary function is to collect
            data from multiple field devices, perform protocol conversion and buffering, and
            reliably forward the information to network controllers while simultaneously
            receiving control commands from the network and distributing them to appropriate
            field devices. The system ensures data integrity, manages communication timing,
            and provides continuous diagnostic monitoring of the bridge operation.
        */
        
        attribute bridgeId : Integer;
        attribute operatingVoltage : SignalVoltage;
        attribute maxFieldDevices : Integer;
        attribute maxNetworkThroughput : DataRate;
        
        port fieldBus : FieldBusPort[8];
        port networkBus : NetworkPort;
        
        part buffer : DataBuffer {
            attribute :>> capacity = 1024;
            attribute :>> currentOccupancy = 0;
        }
        
        part converter : ProtocolConverter {
            attribute :>> supportedProtocols = ("Modbus", "Profibus", "EthernetIP");
        }
        
        part monitor : DiagnosticMonitor {
            attribute :>> uptime : ISQ::TimeValue;
            attribute :>> errorCount = 0;
            attribute :>> throughput : DataRate;
        }
        
        connection fieldToBuffer connect fieldBus to buffer;
        connection bufferToConverter connect buffer to converter;
        connection converterToNetwork connect converter to networkBus;
        connection monitorToDiagnostic connect monitor to networkBus;
        
        perform action bridgeOperation : BridgeOperation;
    }
    
    action def BridgeOperation {
        in fieldInputs : FieldData[8];
        in networkCommands : ControlCommand;
        out networkOutputs : FieldData[8];
        out fieldCommands : ControlCommand[8];
        out diagnostics : DiagnosticMessage;
        
        first start;
        then merge continuousOperation;
        
        action collectFieldData {
            in inputs : FieldData[8];
            out collected : FieldData[8];
        }
        
        then action bufferData {
            in data : FieldData[8];
            out buffered : FieldData[8];
        }
        
        then action convertToNetwork {
            in fieldData : FieldData[8];
            out networkData : FieldData[8];
        }
        
        then action forwardToNetwork {
            in data : FieldData[8];
            out transmitted : FieldData[8];
        }
        
        then action receiveNetworkCommands {
            out commands : ControlCommand;
            out commandReceived : Boolean;
        }
        
        then decide;
            if receiveNetworkCommands.commandReceived then processCommands;
            if !receiveNetworkCommands.commandReceived then monitorHealth;
        
        action processCommands {
            in networkCmd : ControlCommand;
            out fieldCmd : ControlCommand[8];
        }
        
        then action distributeCommands {
            in commands : ControlCommand[8];
            out distributed : ControlCommand[8];
        }
        
        then monitorHealth;
        
        action monitorHealth {
            out healthStatus : DiagnosticMessage;
        }
        
        then continuousOperation;
    }
    
    requirement def BridgeThroughputRequirement {
        doc /*
            The IoBridge shall support a minimum aggregate data throughput of 1 Mbps
            across all field bus connections with maximum latency of 100 milliseconds
            for data forwarding from field to network.
        */
        
        subject bridge : IoBridge;
        
        require constraint throughputConstraint {
            bridge.maxNetworkThroughput >= 1.0e6
        }
    }
    
    requirement def BridgeReliabilityRequirement {
        doc /*
            The IoBridge shall maintain continuous operation with data integrity
            error rate below 0.001 percent and provide diagnostic reporting
            for all communication failures.
        */
        
        subject bridge : IoBridge;
    }
    
    requirement def BridgeCapacityRequirement {
        doc /*
            The IoBridge shall support simultaneous connections to at least
            8 field devices and maintain buffering capacity for 1024 data packets.
        */
        
        subject bridge : IoBridge;
        
        require constraint deviceCapacity {
            bridge.maxFieldDevices >= 8
        }
        
        require constraint bufferCapacity {
            bridge.buffer.capacity >= 1024
        }
    }
    
    requirement systemRequirements {
        require bridgeThroughput : BridgeThroughputRequirement;
        require bridgeReliability : BridgeReliabilityRequirement;
        require bridgeCapacity : BridgeCapacityRequirement;
    }
    
    part ioBridgeSystem : IoBridge {
        attribute :>> bridgeId = 1;
        attribute :>> operatingVoltage : SignalVoltage;
        attribute :>> maxFieldDevices = 8;
        attribute :>> maxNetworkThroughput : DataRate;
        
        part fieldDevice1 : FieldDevice {
            attribute :>> deviceId = 101;
        }
        
        part fieldDevice2 : FieldDevice {
            attribute :>> deviceId = 102;
        }
        
        part networkCtrl : NetworkController {
            attribute :>> controllerId = 201;
        }
        
        connection field1Connection connect fieldDevice1.fieldInterface to fieldBus;
        connection field2Connection connect fieldDevice2.fieldInterface to fieldBus;
        connection networkConnection connect networkBus to networkCtrl.networkInterface;
        
        satisfy systemRequirements;
    }
}
