package PortBasedSystemModel {
    import ScalarValues::*;
    import SI::*;

    attribute def Voltage :> Real {
        unit = "V";
    }

    attribute def Current :> Real {
        unit = "A";
    }

    attribute def Power :> Real {
        unit = "W";
    }

    attribute def Temperature :> Real {
        unit = "degC";
    }

    attribute def DataRate :> Real {
        unit = "Mb/s";
    }

    attribute def TimeDuration :> Real {
        unit = "s";
    }

    enum def PortMode {
        enum idle;
        enum detecting;
        enum connected;
        enum transferring;
        enum faulted;
        enum shutdown;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }

    item def DigitalDataPacket {
        attribute payloadSizeBytes : Integer;
        attribute checksumValid : Boolean;
        attribute priorityLevel : Integer;
    }

    item def PortStatusMessage {
        attribute mode : PortMode;
        attribute connected : Boolean;
        attribute measuredVoltage : Voltage;
        attribute measuredCurrent : Current;
        attribute measuredTemperature : Temperature;
        attribute errorCode : Integer;
    }

    port def ManagedInterfacePort {
        in item externalPower : ElectricalPower;
        in item inboundData : DigitalDataPacket;
        out item conditionedPower : ElectricalPower;
        out item outboundData : DigitalDataPacket;
        out item status : PortStatusMessage;
    }

    port def InternalPowerPort {
        in item rawPower : ElectricalPower;
        out item regulatedPower : ElectricalPower;
    }

    port def InternalDataPort {
        in item rxPacket : DigitalDataPacket;
        out item txPacket : DigitalDataPacket;
    }

    action def DetectConnection {
        in item sensedPower : ElectricalPower;
        out connected : Boolean;
        out safeToEnergize : Boolean;
    }

    action def RegulatePower {
        in item inputPower : ElectricalPower;
        out item outputPower : ElectricalPower;
    }

    action def ValidatePacket {
        in item packet : DigitalDataPacket;
        out valid : Boolean;
    }

    action def RoutePacket {
        in item packet : DigitalDataPacket;
        out item routedPacket : DigitalDataPacket;
    }

    action def BuildStatus {
        in mode : PortMode;
        in connected : Boolean;
        in voltage : Voltage;
        in current : Current;
        in temperature : Temperature;
        in errorCode : Integer;
        out item status : PortStatusMessage;
    }

    action def PortPrimaryFunction {
        in item receivedPower : ElectricalPower;
        in item receivedData : DigitalDataPacket;
        out item deliveredPower : ElectricalPower;
        out item deliveredData : DigitalDataPacket;
        out item reportedStatus : PortStatusMessage;

        action detect : DetectConnection {
            in sensedPower = receivedPower;
        }

        action regulate : RegulatePower {
            in inputPower = receivedPower;
        }

        action validate : ValidatePacket {
            in packet = receivedData;
        }

        action route : RoutePacket {
            in packet = receivedData;
        }

        action report : BuildStatus {
            in mode = PortMode::transferring;
            in connected = detect.connected;
            in voltage = receivedPower.voltage;
            in current = receivedPower.current;
            in temperature = 32.0 [Temperature];
            in errorCode = 0;
        }

        bind deliveredPower = regulate.outputPower;
        bind deliveredData = route.routedPacket;
        bind reportedStatus = report.status;
    }

    state def ManagedPortStateMachine {
        entry action initialize {
        }

        state idle;
        state detecting;
        state connected;
        state transferring;
        state faulted;
        state shutdown;

        transition initial then idle;

        transition idle_to_detecting
            first idle
            accept connectionSense
            then detecting;

        transition detecting_to_connected
            first detecting
            if connectionValid
            then connected;

        transition detecting_to_faulted
            first detecting
            if not connectionValid
            then faulted;

        transition connected_to_transferring
            first connected
            accept dataAvailable
            then transferring;

        transition transferring_to_connected
            first transferring
            accept transferComplete
            then connected;

        transition connected_to_idle
            first connected
            accept disconnect
            then idle;

        transition transferring_to_faulted
            first transferring
            if overCurrentDetected
            then faulted;

        transition faulted_to_idle
            first faulted
            accept reset
            then idle;

        transition idle_to_shutdown
            first idle
            accept powerDown
            then shutdown;
    }

    part def PowerConditioner {
        port power : InternalPowerPort;

        attribute inputVoltage : Voltage;
        attribute outputVoltage : Voltage;
        attribute outputCurrentLimit : Current;
        attribute conversionEfficiency : Real;

        perform action regulate : RegulatePower;
    }

    part def DataController {
        port data : InternalDataPort;

        attribute nominalDataRate : DataRate;
        attribute maximumPacketSizeBytes : Integer;
        attribute droppedPacketCount : Integer;

        perform action validate : ValidatePacket;
        perform action route : RoutePacket;
    }

    part def PortMonitor {
        port monitoredPort : ManagedInterfacePort;

        attribute measuredVoltage : Voltage;
        attribute measuredCurrent : Current;
        attribute measuredTemperature : Temperature;
        attribute faultCode : Integer;
        attribute reportingPeriod : TimeDuration;

        perform action reportStatus : BuildStatus;
    }

    part def ManagedPortAssembly {
        port interfacePort : ManagedInterfacePort;

        part conditioner : PowerConditioner {
            attribute outputCurrentLimit = 3.0 [Current];
            attribute conversionEfficiency = 0.94;
        }

        part controller : DataController {
            attribute nominalDataRate = 480.0 [DataRate];
            attribute maximumPacketSizeBytes = 4096;
            attribute droppedPacketCount = 0;
        }

        part monitor : PortMonitor {
            attribute reportingPeriod = 1.0 [TimeDuration];
            attribute faultCode = 0;
        }

        attribute operatingMode : PortMode;
        attribute maximumInputVoltage : Voltage = 24.0 [Voltage];
        attribute minimumInputVoltage : Voltage = 4.75 [Voltage];
        attribute maximumPortTemperature : Temperature = 70.0 [Temperature];

        connection powerInputConnection
            connect interfacePort.externalPower to conditioner.power.rawPower;

        connection powerOutputConnection
            connect conditioner.power.regulatedPower to interfacePort.conditionedPower;

        connection dataInputConnection
            connect interfacePort.inboundData to controller.data.rxPacket;

        connection dataOutputConnection
            connect controller.data.txPacket to interfacePort.outboundData;

        connection statusConnection
            connect monitor.monitoredPort.status to interfacePort.status;

        exhibit state portLifecycle : ManagedPortStateMachine;

        perform action primaryFunction : PortPrimaryFunction {
            in receivedPower = interfacePort.externalPower;
            in receivedData = interfacePort.inboundData;
            out deliveredPower = interfacePort.conditionedPower;
            out deliveredData = interfacePort.outboundData;
            out reportedStatus = interfacePort.status;
        }
    }

    part def ExternalDevice {
        port devicePort : ManagedInterfacePort;
        attribute requestedPower : Power;
        attribute requestedDataRate : DataRate;
    }

    part def PortBasedSystem {
        part managedPort : ManagedPortAssembly;
        part attachedDevice : ExternalDevice {
            attribute requestedPower = 12.0 [Power];
            attribute requestedDataRate = 120.0 [DataRate];
        }

        connection devicePowerConnection
            connect attachedDevice.devicePort.externalPower to managedPort.interfacePort.externalPower;

        connection deviceDataConnection
            connect attachedDevice.devicePort.inboundData to managedPort.interfacePort.inboundData;

        connection suppliedPowerConnection
            connect managedPort.interfacePort.conditionedPower to attachedDevice.devicePort.conditionedPower;

        connection returnedDataConnection
            connect managedPort.interfacePort.outboundData to attachedDevice.devicePort.outboundData;

        connection statusFeedbackConnection
            connect managedPort.interfacePort.status to attachedDevice.devicePort.status;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : PortBasedSystem;

        require constraint {
            system.managedPort.interfacePort.conditionedPower.power >= 10.0 [Power]
        }

        doc
        /* The system shall use a managed port as its central interface to detect an attached device, condition incoming electrical power, exchange digital data, and publish port health status. */
    }

    requirement def SafeVoltageRequirement {
        subject portAssembly : ManagedPortAssembly;

        require constraint {
            portAssembly.interfacePort.externalPower.voltage <= portAssembly.maximumInputVoltage and
            portAssembly.interfacePort.externalPower.voltage >= portAssembly.minimumInputVoltage
        }

        doc
        /* The managed port shall accept external power only within its permitted voltage range. */
    }

    requirement def CurrentLimitRequirement {
        subject conditioner : PowerConditioner;

        require constraint {
            conditioner.power.regulatedPower.current <= conditioner.outputCurrentLimit
        }

        doc
        /* The power conditioner shall limit output current before delivering power through the port. */
    }

    requirement def PacketIntegrityRequirement {
        subject controller : DataController;

        require constraint {
            controller.droppedPacketCount >= 0
        }

        doc
        /* The data controller shall validate packet integrity before routing data across the managed port. */
    }

    requirement def ThermalProtectionRequirement {
        subject portAssembly : ManagedPortAssembly;

        require constraint {
            portAssembly.monitor.measuredTemperature <= portAssembly.maximumPortTemperature
        }

        doc
        /* The managed port shall report or enter a fault state when monitored temperature exceeds the allowed operating limit. */
    }

    satisfy PrimaryFunctionRequirement by PortBasedSystem;
    satisfy SafeVoltageRequirement by ManagedPortAssembly;
    satisfy CurrentLimitRequirement by PowerConditioner;
    satisfy PacketIntegrityRequirement by DataController;
    satisfy ThermalProtectionRequirement by ManagedPortAssembly;
}