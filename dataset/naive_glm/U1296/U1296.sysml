package IndustrialIoBridge {

    // ---- Standard SI-based value types ----
    value type Time {
        unit 'ms';
    }
    value type DataRate {
        unit 'Mbps';
    }
    value type Count {
        unit 'count';
    }
    value type Percent {
        unit '%';
    }
    value type Temperature {
        unit 'degC';
    }
    value type Voltage {
        unit 'V';
    }
    value type Pressure {
        unit 'bar';
    }
    value type FlowRate {
        unit 'L/min';
    }
    value type Frequency {
        unit 'Hz';
    }
    value type Angle {
        unit 'deg';
    }

    // ---- Enumerations ----
    enum ProtocolKind { modbus, profibus, ethernetIP, opcua }
    enum DataQuality { good, uncertain, bad }
    enum DeviceKind { sensor, actuator }
    enum CommandKind { setpoint, enable, disable, reset, calibrate }
    enum HealthStatus { nominal, degraded, faulted }

    // ---- Item definitions ----
    item def SensorReading {
        attribute deviceId : String;
        attribute value : Real;
        attribute unit : String;
        attribute timestamp : Time;
        attribute quality : DataQuality;
    }

    item def ControlCommand {
        attribute targetDeviceId : String;
        attribute command : CommandKind;
        attribute value : Real;
        attribute unit : String;
        attribute issuedAt : Time;
    }

    item def DataPacket {
        attribute packetId : Integer;
        attribute sourceProtocol : ProtocolKind;
        attribute destinationProtocol : ProtocolKind;
        attribute payload : SensorReading;
        attribute enqueuedAt : Time;
    }

    item def DiagnosticMessage {
        attribute bridgeId : String;
        attribute status : HealthStatus;
        attribute uptime : Time;
        attribute errorCount : Count;
        attribute throughput : DataRate;
        attribute reportedAt : Time;
    }

    item def Acknowledgement {
        attribute deviceId : String;
        attribute accepted : Boolean;
        attribute respondedAt : Time;
    }

    // ---- Port definitions ----
    port def FieldPort {
        attribute protocol : ProtocolKind;
        in item sensorReadings : SensorReading;
        out item commands : ControlCommand;
        in item acks : Acknowledgement;
    }

    port def NetworkPort {
        attribute protocol : ProtocolKind = ProtocolKind::ethernetIP;
        out item aggregatedReadings : DataPacket;
        in item networkCommands : ControlCommand;
        out item diagnostics : DiagnosticMessage;
    }

    port def InternalDataPort {
        out item packets : DataPacket;
        in item convertedPackets : DataPacket;
    }

    port def InternalCommandPort {
        in item commands : ControlCommand;
        out item fieldCommands : ControlCommand;
    }

    port def DiagnosticPort {
        in item healthStatus : HealthStatus;
        out item diagnosticMessages : DiagnosticMessage;
    }

    // ---- Parts ----
    part def FieldDevice {
        attribute deviceId : String;
        attribute deviceKind : DeviceKind;
        attribute nativeProtocol : ProtocolKind;
        port fieldIf : FieldPort;

        attribute samplingInterval : Time;
        attribute operatingTemperature : Temperature;

        state deviceBehavior {
            entry;
            state Idle;
            state Sampling {
                entry;
                do send SensorReading(deviceId = deviceId, value = 0.0, unit = "", timestamp = 0 [ms], quality = DataQuality::good) to fieldIf.sensorReadings;
            }
            state Executing {
                entry;
                do send Acknowledgement(deviceId = deviceId, accepted = true, respondedAt = 0 [ms]) to fieldIf.acks;
            }
            transition idle_to_sampling
                source Idle
                target Sampling
                when samplingInterval elapsed;
            transition sampling_to_idle
                source Sampling
                target Idle
                when Sampling.done;
            transition idle_to_executing
                source Idle
                target Executing
                when fieldIf.commands received;
            transition executing_to_idle
                source Executing
                target Idle
                when Executing.done;
        }
    }

    part def TemperatureSensor :> FieldDevice {
        attribute measuredTemperature : Temperature;
        redef deviceKind = DeviceKind::sensor;
        redef nativeProtocol = ProtocolKind::modbus;
        redef samplingInterval = 100 [ms];
    }

    part def PressureSensor :> FieldDevice {
        attribute measuredPressure : Pressure;
        redef deviceKind = DeviceKind::sensor;
        redef nativeProtocol = ProtocolKind::profibus;
        redef samplingInterval = 50 [ms];
    }

    part def FlowSensor :> FieldDevice {
        attribute measuredFlow : FlowRate;
        redef deviceKind = DeviceKind::sensor;
        redef nativeProtocol = ProtocolKind::modbus;
        redef samplingInterval = 200 [ms];
    }

    part def MotorActuator :> FieldDevice {
        attribute setpointSpeed : Frequency;
        redef deviceKind = DeviceKind::actuator;
        redef nativeProtocol = ProtocolKind::profibus;
        redef samplingInterval = 1000 [ms];
    }

    part def ValveActuator :> FieldDevice {
        attribute valvePosition : Angle;
        redef deviceKind = DeviceKind::actuator;
        redef nativeProtocol = ProtocolKind::modbus;
        redef samplingInterval = 500 [ms];
    }

    part def NetworkController {
        attribute controllerId : String;
        port netIf : NetworkPort;

        attribute expectedThroughput : DataRate;
        attribute maxLatency : Time;

        state controllerBehavior {
            state Monitoring;
            state IssuingCommands {
                entry;
                do send ControlCommand(targetDeviceId = "", command = CommandKind::setpoint, value = 0.0, unit = "", issuedAt = 0 [ms]) to netIf.networkCommands;
            }
            state ReceivingDiagnostics;
            transition monitor_to_issue
                source Monitoring
                target IssuingCommands
                when controllerLogic.triggerCommand;
            transition issue_to_monitor
                source IssuingCommands
                target Monitoring
                when IssuingCommands.done;
            transition monitor_to_diag
                source Monitoring
                target ReceivingDiagnostics
                when netIf.diagnostics received;
            transition diag_to_monitor
                source ReceivingDiagnostics
                target Monitoring
                when ReceivingDiagnostics.done;
        }
    }

    part def ProtocolConverter {
        attribute supportedProtocols : ProtocolKind[0..*];
        attribute conversionLatency : Time;

        port dataIn : InternalDataPort;
        port cmdIn : InternalCommandPort;
        port diagOut : DiagnosticPort;

        action def convertReading {
            in incoming : DataPacket;
            out outgoing : DataPacket;
            // Translate payload from source protocol to destination protocol
        }

        action def convertCommand {
            in incoming : ControlCommand;
            out outgoing : ControlCommand;
            // Translate command from network protocol to field protocol
        }

        state converterBehavior {
            state Idle;
            state ConvertingData {
                do convertReading;
            }
            state ConvertingCommand {
                do convertCommand;
            }
            transition idle_to_convertData
                source Idle
                target ConvertingData
                when dataIn.packets received;
            transition convertData_to_idle
                source ConvertingData
                target Idle
                when ConvertingData.done;
            transition idle_to_convertCmd
                source Idle
                target ConvertingCommand
                when cmdIn.commands received;
            transition convertCmd_to_idle
                source ConvertingCommand
                target Idle
                when ConvertingCommand.done;
        }
    }

    part def DataBuffer {
        attribute capacity : Count = 1024 [count];
        attribute currentLoad : Count;
        attribute overflowCount : Count;

        port bufIn : InternalDataPort;
        port bufOut : InternalDataPort;

        state bufferBehavior {
            state Empty;
            state Filling;
            state Full {
                // Drop oldest packet and increment overflowCount
            }
            transition empty_to_filling
                source Empty
                target Filling
                when bufIn.packets received;
            transition filling_to_full
                source Filling
                target Full
                when currentLoad >= capacity;
            transition full_to_filling
                source Full
                target Filling
                when bufOut.convertedPackets sent;
            transition filling_to_empty
                source Filling
                target Empty
                when currentLoad == 0 [count];
        }
    }

    part def DiagnosticMonitor {
        attribute bridgeId : String;
        attribute uptime : Time;
        attribute errorCount : Count;
        attribute throughput : DataRate;
        attribute status : HealthStatus;

        port diagIn : DiagnosticPort;
        port netOut : NetworkPort;

        action def collectMetrics {
            out msg : DiagnosticMessage;
        }

        state monitorBehavior {
            state Running;
            state Reporting {
                do collectMetrics;
            }
            state Faulted;
            transition running_to_reporting
                source Running
                target Reporting
                when reportingInterval.elapsed;
            transition reporting_to_running
                source Reporting
                target Running
                when Reporting.done;
            transition running_to_faulted
                source Running
                target Faulted
                when errorCount > threshold;
            transition faulted_to_running
                source Faulted
                target Running
                when resetCommand.received;
        }
    }

    part def IoBridge {
        attribute bridgeId : String;
        attribute maxFieldPorts : Integer = 8;
        attribute networkSpeed : DataRate = 100 [Mbps];

        port fieldPorts : FieldPort[0..8];
        port networkPort : NetworkPort;

        part protocolConverter : ProtocolConverter {
            redef supportedProtocols = {ProtocolKind::modbus, ProtocolKind::profibus, ProtocolKind::ethernetIP, ProtocolKind::opcua};
            redef conversionLatency = 2 [ms];
        }

        part dataBuffer : DataBuffer {
            redef capacity = 1024 [count];
        }

        part diagnosticMonitor : DiagnosticMonitor {
            redef bridgeId = bridgeId;
            redef uptime = 0 [ms];
            redef errorCount = 0 [count];
            redef throughput = 0 [Mbps];
            redef status = HealthStatus::nominal;
        }

        // Internal connections
        connection fieldToBuffer connect fieldPorts.sensorReadings to dataBuffer.bufIn.packets;
        connection bufferToConverter connect dataBuffer.bufOut.convertedPackets to protocolConverter.dataIn.packets;
        connection converterToNetwork connect protocolConverter.dataIn.convertedPackets to networkPort.aggregatedReadings;
        connection networkToConverter connect networkPort.networkCommands to protocolConverter.cmdIn.commands;
        connection converterToField connect protocolConverter.cmdIn.fieldCommands to fieldPorts.commands;
        connection converterToDiag connect protocolConverter.diagOut.healthStatus to diagnosticMonitor.diagIn.healthStatus;
        connection diagToNetwork connect diagnosticMonitor.netOut.diagnostics to networkPort.diagnostics;

        state bridgeOperation {
            state Initializing {
                // Power-up self-test, port enumeration
            }
            state Operational {
                // Normal data and command flow
            }
            state Degraded {
                // Reduced throughput, buffer near full
            }
            state Maintenance {
                // Offline for firmware update
            }
            transition init_to_op
                source Initializing
                target Operational
                when selfTest.passed;
            transition op_to_degraded
                source Operational
                target Degraded
                when dataBuffer.currentLoad > 768 [count];
            transition degraded_to_op
                source Degraded
                target Operational
                when dataBuffer.currentLoad < 256 [count];
            transition op_to_maint
                source Operational
                target Maintenance
                when maintenanceTrigger.received;
            transition maint_to_init
                source Maintenance
                target Initializing
                when maintenanceComplete.received;
        }
    }

    // ---- Top-level system ----
    part IndustrialIoSystem {
        attribute systemName : String = "IndustrialIoBridgeSystem";

        part ioBridge : IoBridge {
            redef bridgeId = "IOB-001";
        }

        part networkController : NetworkController {
            redef controllerId = "NC-100";
            redef expectedThroughput = 50 [Mbps];
            redef maxLatency = 10 [ms];
        }

        part fieldDevices : FieldDevice[0..8] {
            part tempSensor1 : TemperatureSensor { redef deviceId = "TS-01"; }
            part tempSensor2 : TemperatureSensor { redef deviceId = "TS-02"; }
            part pressureSensor1 : PressureSensor { redef deviceId = "PS-01"; }
            part flowSensor1 : FlowSensor { redef deviceId = "FS-01"; }
            part motor1 : MotorActuator { redef deviceId = "MA-01"; }
            part motor2 : MotorActuator { redef deviceId = "MA-02"; }
            part valve1 : ValveActuator { redef deviceId = "VA-01"; }
            part valve2 : ValveActuator { redef deviceId = "VA-02"; }
        }

        // External connections between bridge and field devices
        connection fieldDeviceToBridge connect fieldDevices.fieldIf to ioBridge.fieldPorts;
        // External connection between bridge and network controller
        connection bridgeToController connect ioBridge.networkPort to networkController.netIf;
    }

    // ---- Requirements ----
    requirement def ThroughputRequirement {
        attribute minThroughput : DataRate;
        subject : IoBridge;
        require throughput >= minThroughput;
    }

    requirement def LatencyRequirement {
        attribute maxLatency : Time;
        subject : IoBridge;
        require endToEndLatency <= maxLatency;
    }

    requirement def BufferCapacityRequirement {
        attribute minCapacity : Count;
        subject : DataBuffer;
        require capacity >= minCapacity;
    }

    requirement def PortCountRequirement {
        attribute minFieldPorts : Integer;
        subject : IoBridge;
        require maxFieldPorts >= minFieldPorts;
    }

    requirement def ProtocolSupportRequirement {
        attribute requiredProtocols : ProtocolKind[0..*];
        subject : ProtocolConverter;
        require supportedProtocols includesAll requiredProtocols;
    }

    requirement def DiagnosticReportingRequirement {
        subject : DiagnosticMonitor;
        require diagnosticMessages sent on failure;
    }

    requirement HighThroughput :> ThroughputRequirement {
        redef minThroughput = 40 [Mbps];
    }

    requirement LowLatency :> LatencyRequirement {
        redef maxLatency = 15 [ms];
    }

    requirement BufferHolds1024 :> BufferCapacityRequirement {
        redef minCapacity = 1024 [count];
    }

    requirement EightFieldPorts :> PortCountRequirement {
        redef minFieldPorts = 8;
    }

    requirement MultiProtocolSupport :> ProtocolSupportRequirement {
        redef requiredProtocols = {ProtocolKind::modbus, ProtocolKind::profibus, ProtocolKind::ethernetIP};
    }

    requirement ReportErrors :> DiagnosticReportingRequirement;

    // ---- Satisfaction ----
    satisfaction satisfy HighThroughput by ioBridge;
    satisfaction satisfy LowLatency by ioBridge;
    satisfaction satisfy BufferHolds1024 by ioBridge.dataBuffer;
    satisfaction satisfy EightFieldPorts by ioBridge;
    satisfaction satisfy MultiProtocolSupport by ioBridge.protocolConverter;
    satisfaction satisfy ReportErrors by ioBridge.diagnosticMonitor;

}
