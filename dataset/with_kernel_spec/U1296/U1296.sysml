package IndustrialIoBridge {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def TimeStampValue :> Real;
    attribute def TimeValue :> Real;
    attribute def ThroughputValue :> Real;

    enum def QualityStatus { GOOD; BAD; UNCERTAIN; }
    enum def CommandType { SETPOINT; START; STOP; RESET; }
    enum def OperationalStatus { NORMAL; WARNING; ERROR; }
    enum def ProtocolType { MODBUS; PROFIBUS; ETHERNET_IP; }

    item def SensorData {
        attribute reading : Real;
        attribute timestamp : TimeStampValue;
        attribute quality : QualityStatus;
        attribute sourceDeviceId : Integer;
    }

    item def ControlCommand {
        attribute commandId : String;
        attribute targetDeviceId : Integer;
        attribute commandType : CommandType;
        attribute value : Real;
    }

    item def DiagnosticMessage {
        attribute uptime : TimeValue;
        attribute errorCount : Integer;
        attribute throughput : ThroughputValue;
        attribute status : OperationalStatus;
    }

    port def FieldPort {
        in data : SensorData;
        out command : ControlCommand;
        attribute protocol : ProtocolType;
    }

    port def NetworkPort {
        out data : SensorData;
        in command : ControlCommand;
        out diagnostic : DiagnosticMessage;
    }

    action def ConvertToNetwork {
        in fieldData : SensorData;
        out networkData : SensorData;
    }

    action def ConvertToField {
        in networkCommand : ControlCommand;
        out fieldCommand : ControlCommand;
    }

    action def GenerateDiagnostic {
        out diag : DiagnosticMessage;
    }

    part def FieldDevice {
        port fieldPort : ~FieldPort;
        attribute deviceId : Integer;
    }

    part def Sensor :> FieldDevice {
        attribute reading : Real;
    }

    part def Actuator :> FieldDevice {
        attribute setpoint : Real;
    }

    part def NetworkController {
        port networkPort : ~NetworkPort;
    }

    state def ConverterStateMachine {
        event occurrence fieldDataReceived;
        event occurrence networkDataSent;
        event occurrence errorDetected;
        event occurrence reset;
        state idle;
        state converting;
        state errorState;
        transition from idle to converting on fieldDataReceived;
        transition from converting to idle on networkDataSent;
        transition from converting to errorState on errorDetected;
        transition from errorState to idle on reset;
    }

    state def BufferState {
        event occurrence dataStored;
        event occurrence dataRetrieved;
        event occurrence capacityReached;
        event occurrence bufferEmpty;
        state Empty;
        state Normal;
        state Full;
        transition from Empty to Normal on dataStored;
        transition from Normal to Full on capacityReached;
        transition from Full to Normal on dataRetrieved;
        transition from Normal to Empty on bufferEmpty;
    }

    state def MonitorStateMachine {
        event occurrence errorDetected;
        event occurrence diagnosticSent;
        state monitoring;
        state reporting;
        transition from monitoring to reporting on errorDetected;
        transition from reporting to monitoring on diagnosticSent;
    }

    state def BridgeStateMachine {
        event occurrence fieldDataReceived;
        event occurrence dataReceived;
        event occurrence bufferReady;
        event occurrence conversionComplete;
        event occurrence transmissionAck;
        event occurrence networkCommandReceived;
        event occurrence commandParsed;
        event occurrence fieldConversionComplete;
        event occurrence fieldTransmissionAck;
        event occurrence timerTick;
        event occurrence diagSent;

        state idle;
        state receivingFieldData;
        state buffering;
        state convertingToNetwork;
        state transmittingToNetwork;
        state receivingNetworkCommand;
        state convertingToField;
        state transmittingToField;
        state monitoringDiagnostics;

        transition from idle to receivingFieldData on fieldDataReceived;
        transition from receivingFieldData to buffering on dataReceived;
        transition from buffering to convertingToNetwork on bufferReady;
        transition from convertingToNetwork to transmittingToNetwork on conversionComplete;
        transition from transmittingToNetwork to idle on transmissionAck;
        transition from idle to receivingNetworkCommand on networkCommandReceived;
        transition from receivingNetworkCommand to convertingToField on commandParsed;
        transition from convertingToField to transmittingToField on fieldConversionComplete;
        transition from transmittingToField to idle on fieldTransmissionAck;
        transition from idle to monitoringDiagnostics on timerTick;
        transition from monitoringDiagnostics to idle on diagSent;
    }

    part def ProtocolConverter {
        port fieldSide {
            in data : SensorData;
            out command : ControlCommand;
        }
        port networkSide {
            out data : SensorData;
            in command : ControlCommand;
        }
        attribute supportedProtocols : ProtocolType[0..*] = (ProtocolType::MODBUS, ProtocolType::PROFIBUS, ProtocolType::ETHERNET_IP);

        action convertToNetwork : ConvertToNetwork;
        action convertToField : ConvertToField;

        state machine converterStateMachine : ConverterStateMachine;
    }

    part def DataBuffer {
        port input {
            in data : SensorData;
        }
        port output {
            out data : SensorData;
        }
        attribute capacity : Integer = 1024;
        attribute currentSize : Integer;

        state machine bufferState : BufferState;
    }

    part def DiagnosticMonitor {
        port monitorPort {
            in data : SensorData;
            in command : ControlCommand;
            out diagnostic : DiagnosticMessage;
        }
        attribute uptime : TimeValue;
        attribute errorCount : Integer = 0;
        attribute throughput : ThroughputValue;

        action generateDiagnostic : GenerateDiagnostic;

        state machine monitorStateMachine : MonitorStateMachine;
    }

    part def IoBridge {
        port fieldPorts : FieldPort[0..8];
        port networkPort : NetworkPort;

        part protocolConverter : ProtocolConverter;
        part dataBuffer : DataBuffer;
        part diagnosticMonitor : DiagnosticMonitor;

        state machine bridgeStateMachine : BridgeStateMachine;
    }

    requirement def HighThroughputRequirement {
        attribute minThroughput : ThroughputValue = 1000.0;
        doc /* The system shall support a data throughput of at least 1000 packets per second. */
    }

    requirement def LowLatencyRequirement {
        attribute maxLatency : TimeValue = 0.01;
        doc /* The system shall process and forward data with a maximum latency of 10 milliseconds. */
    }

    requirement def ErrorReportingRequirement {
        attribute maxReportingDelay : TimeValue = 1.0;
        doc /* The system shall report any operational errors to the network controller within 1 second of detection. */
    }

    requirement def BufferReliabilityRequirement {
        attribute bufferCapacity : Integer = 1024;
        doc /* The data buffer shall hold up to 1024 data packets to prevent loss of sensor readings during network unavailability. */
    }

    requirement IoBridgeRequirements {
        requirement highThroughput : HighThroughputRequirement;
        requirement lowLatency : LowLatencyRequirement;
        requirement errorReporting : ErrorReportingRequirement;
        requirement bufferReliability : BufferReliabilityRequirement;
    }

    part industrialIoSystem {
        part ioBridge : IoBridge {
            flow fieldDataFlow of SensorData
                from fieldPorts.data to dataBuffer.input.data;
            flow bufferToConverterFlow of SensorData
                from dataBuffer.output.data to protocolConverter.fieldSide.data;
            flow converterToNetworkFlow of SensorData
                from protocolConverter.networkSide.data to networkPort.data;
            flow networkToConverterFlow of ControlCommand
                from networkPort.command to protocolConverter.networkSide.command;
            flow converterToFieldFlow of ControlCommand
                from protocolConverter.fieldSide.command to fieldPorts.command;
            flow monitorDataFlow of SensorData
                from dataBuffer.output.data to diagnosticMonitor.monitorPort.data;
            flow monitorCommandFlow of ControlCommand
                from protocolConverter.fieldSide.command to diagnosticMonitor.monitorPort.command;
            flow diagnosticFlow of DiagnosticMessage
                from diagnosticMonitor.monitorPort.diagnostic to networkPort.diagnostic;
        }

        part sensor1 : Sensor {
            :>> fieldPort {
                :>> protocol = ProtocolType::MODBUS;
            }
            :>> deviceId = 1;
        }
        part sensor2 : Sensor {
            :>> fieldPort {
                :>> protocol = ProtocolType::PROFIBUS;
            }
            :>> deviceId = 2;
        }
        part actuator1 : Actuator {
            :>> fieldPort {
                :>> protocol = ProtocolType::ETHERNET_IP;
            }
            :>> deviceId = 3;
        }

        part networkController : NetworkController;

        interface sensor1Connection connect sensor1.fieldPort to ioBridge.fieldPorts[1];
        interface sensor2Connection connect sensor2.fieldPort to ioBridge.fieldPorts[2];
        interface actuator1Connection connect actuator1.fieldPort to ioBridge.fieldPorts[3];
        interface networkConnection connect networkController.networkPort to ioBridge.networkPort;

        satisfy IoBridgeRequirements by ioBridge;
    }
}
