package PLCBUSSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    doc /* 
     * Primary function:
     * The PLCBUS-based automation system distributes command, status, and telemetry messages
     * over existing mains power wiring so that a central controller can monitor and control
     * distributed loads, sensors, and actuators without a separate communication cable.
     */

    attribute def MessagePriority {
        enum normal;
        enum urgent;
        enum diagnostic;
    }

    attribute def DeviceRole {
        enum masterController;
        enum actuatorNode;
        enum sensorNode;
        enum bridgeNode;
        enum repeaterNode;
    }

    attribute def BusHealthState {
        enum nominal;
        enum degraded;
        enum failed;
    }

    attribute def SwitchState {
        enum open;
        enum closed;
    }

    attribute def CommandKind {
        enum switchOn;
        enum switchOff;
        enum dimToLevel;
        enum requestStatus;
        enum resetDevice;
        enum acknowledgeAlarm;
    }

    value def VoltageRMS :> ISQ::voltage {
        unit = SI::volt;
    }

    value def CurrentRMS :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    value def Frequency :> ISQ::frequency {
        unit = SI::hertz;
    }

    value def Power :> ISQ::power {
        unit = SI::watt;
    }

    value def Energy :> ISQ::energy {
        unit = SI::joule;
    }

    value def TimeMs :> ISQ::time {
        unit = SI::millisecond;
    }

    value def Percent {
        unit = "%";
    }

    value def BaudRate {
        unit = "bit/s";
    }

    item def PLCFrame {
        attribute sourceAddress : Integer;
        attribute destinationAddress : Integer;
        attribute sequenceNumber : Integer;
        attribute command : CommandKind;
        attribute priority : MessagePriority;
        attribute payloadLength : Integer;
        attribute crc16 : Integer;
    }

    item def StatusReport {
        attribute reportingAddress : Integer;
        attribute loadPower : Power;
        attribute rmsVoltage : VoltageRMS;
        attribute rmsCurrent : CurrentRMS;
        attribute linkQuality : Percent;
        attribute localFaultActive : Boolean;
    }

    item def ControlCommand {
        attribute targetAddress : Integer;
        attribute command : CommandKind;
        attribute dimLevel : Percent;
        attribute requestedResponse : Boolean;
    }

    item def BusDiagnostic {
        attribute measuredNoiseLevel : Percent;
        attribute frameErrorRate : Percent;
        attribute activeRepeaters : Integer;
        attribute health : BusHealthState;
    }

    port def PowerLinePort {
        out frameOut : PLCFrame;
        in frameIn : PLCFrame;
        attribute nominalVoltage : VoltageRMS;
        attribute lineFrequency : Frequency;
        attribute signalingRate : BaudRate;
    }

    port def LoadPowerPort {
        out switchedVoltage : VoltageRMS;
        out loadCurrent : CurrentRMS;
        attribute switchState : SwitchState;
    }

    port def SensorDataPort {
        out status : StatusReport;
    }

    port def OperatorPort {
        in commandRequest : ControlCommand;
        out systemStatus : StatusReport;
        out diagnostics : BusDiagnostic;
    }

    port def GatewayPort {
        in externalCommand : ControlCommand;
        out externalStatus : StatusReport;
        out externalDiagnostic : BusDiagnostic;
    }

    action def EncodeControlCommand {
        in command : ControlCommand;
        out frame : PLCFrame;
    }

    action def DecodePLCFrame {
        in frame : PLCFrame;
        out command : ControlCommand;
    }

    action def ValidateFrame {
        in frame : PLCFrame;
        out valid : Boolean;
    }

    action def MeasureLineQuality {
        in sampleWindow : TimeMs;
        out diagnostic : BusDiagnostic;
    }

    action def ApplyLoadCommand {
        in command : ControlCommand;
        out switchState : SwitchState;
        out dimLevel : Percent;
    }

    action def PublishStatus {
        in status : StatusReport;
        out frame : PLCFrame;
    }

    part def PLCBusSegment {
        attribute nominalVoltage : VoltageRMS = 120 [SI::volt];
        attribute lineFrequency : Frequency = 60 [SI::hertz];
        attribute signalingRate : BaudRate = 4800 ["bit/s"];
        attribute maximumNodes : Integer = 64;
        attribute health : BusHealthState = BusHealthState::nominal;

        port controllerTap : PowerLinePort;
        port nodeTap[1..64] : PowerLinePort;
        port repeaterTap[0..8] : PowerLinePort;
    }

    part def PLCBusController {
        attribute address : Integer = 1;
        attribute role : DeviceRole = DeviceRole::masterController;
        attribute commandTimeout : TimeMs = 500 [SI::millisecond];
        attribute retryLimit : Integer = 3;
        attribute busHealth : BusHealthState = BusHealthState::nominal;

        port operatorInterface : OperatorPort;
        port busPort : PowerLinePort;
        port gateway : GatewayPort;

        action encode : EncodeControlCommand;
        action validate : ValidateFrame;
        action measure : MeasureLineQuality;

        state def ControllerOperationalStates {
            state initializing;
            state idle;
            state transmitting;
            state awaitingAcknowledgement;
            state pollingStatus;
            state degradedOperation;
            state faulted;

            entry initial then initializing;
            transition initializing_to_idle first initializing then idle;

            transition command_received
                first idle
                accept operatorInterface.commandRequest
                then transmitting;

            transition frame_sent
                first transmitting
                then awaitingAcknowledgement;

            transition ack_received
                first awaitingAcknowledgement
                accept busPort.frameIn
                then idle;

            transition ack_timeout
                first awaitingAcknowledgement
                then degradedOperation;

            transition poll_due
                first idle
                then pollingStatus;

            transition poll_complete
                first pollingStatus
                then idle;

            transition excessive_errors
                first degradedOperation
                then faulted;

            transition diagnostics_clear
                first degradedOperation
                then idle;
        }
    }

    part def PLCActuatorNode {
        attribute address : Integer;
        attribute role : DeviceRole = DeviceRole::actuatorNode;
        attribute ratedLoadPower : Power;
        attribute presentDimLevel : Percent = 0 ["%"];
        attribute localSwitchState : SwitchState = SwitchState::open;
        attribute frameErrorCounter : Integer = 0;

        port busPort : PowerLinePort;
        port loadOutput : LoadPowerPort;
        port statusOutput : SensorDataPort;

        action validate : ValidateFrame;
        action decode : DecodePLCFrame;
        action apply : ApplyLoadCommand;
        action publish : PublishStatus;

        state def ActuatorNodeStates {
            state unpowered;
            state joiningBus;
            state ready;
            state receivingCommand;
            state drivingLoad;
            state reportingStatus;
            state localFault;

            entry initial then unpowered;

            transition power_available
                first unpowered
                then joiningBus;

            transition address_confirmed
                first joiningBus
                then ready;

            transition frame_detected
                first ready
                accept busPort.frameIn
                then receivingCommand;

            transition valid_load_command
                first receivingCommand
                then drivingLoad;

            transition command_applied
                first drivingLoad
                then reportingStatus;

            transition report_sent
                first reportingStatus
                then ready;

            transition invalid_frame
                first receivingCommand
                then ready;

            transition overload_detected
                first drivingLoad
                then localFault;

            transition reset_received
                first localFault
                then joiningBus;
        }
    }

    part def PLCSensorNode {
        attribute address : Integer;
        attribute role : DeviceRole = DeviceRole::sensorNode;
        attribute samplePeriod : TimeMs = 1000 [SI::millisecond];
        attribute measuredVoltage : VoltageRMS;
        attribute measuredCurrent : CurrentRMS;
        attribute measuredPower : Power;
        attribute linkQuality : Percent;

        port busPort : PowerLinePort;
        port sensorOutput : SensorDataPort;

        action validate : ValidateFrame;
        action publish : PublishStatus;

        state def SensorNodeStates {
            state unpowered;
            state synchronizing;
            state sampling;
            state reporting;
            state sleep;
            state faulted;

            entry initial then unpowered;

            transition energized
                first unpowered
                then synchronizing;

            transition synchronized
                first synchronizing
                then sampling;

            transition sample_ready
                first sampling
                then reporting;

            transition report_complete
                first reporting
                then sleep;

            transition wake_timer
                first sleep
                then sampling;

            transition self_test_failed
                first sampling
                then faulted;

            transition reset_received
                first faulted
                then synchronizing;
        }
    }

    part def PLCRepeaterNode {
        attribute address : Integer;
        attribute role : DeviceRole = DeviceRole::repeaterNode;
        attribute retransmissionDelay : TimeMs = 20 [SI::millisecond];
        attribute repeatedFrameCount : Integer = 0;
        attribute linkQualityThreshold : Percent = 45 ["%"];

        port upstream : PowerLinePort;
        port downstream : PowerLinePort;

        action validate : ValidateFrame;

        state def RepeaterStates {
            state standby;
            state listening;
            state repeating;
            state suppressingDuplicate;
            state faulted;

            entry initial then standby;

            transition bus_power_detected
                first standby
                then listening;

            transition weak_valid_frame
                first listening
                accept upstream.frameIn
                then repeating;

            transition repeated
                first repeating
                then suppressingDuplicate;

            transition duplicate_window_expired
                first suppressingDuplicate
                then listening;

            transition hardware_fault
                first listening
                then faulted;

            transition reset
                first faulted
                then standby;
        }
    }

    part def PLCGateway {
        attribute address : Integer = 2;
        attribute role : DeviceRole = DeviceRole::bridgeNode;
        attribute acceptedExternalSessions : Integer = 4;
        attribute commandQueueDepth : Integer = 32;

        port busPort : PowerLinePort;
        port externalPort : GatewayPort;

        action encode : EncodeControlCommand;
        action validate : ValidateFrame;

        state def GatewayStates {
            state offline;
            state registering;
            state online;
            state forwardingToBus;
            state forwardingToExternal;
            state congested;

            entry initial then offline;

            transition network_available
                first offline
                then registering;

            transition registered
                first registering
                then online;

            transition external_command
                first online
                accept externalPort.externalCommand
                then forwardingToBus;

            transition bus_status
                first online
                accept busPort.frameIn
                then forwardingToExternal;

            transition forward_complete
                first forwardingToBus
                then online;

            transition status_forwarded
                first forwardingToExternal
                then online;

            transition queue_full
                first online
                then congested;

            transition queue_drained
                first congested
                then online;
        }
    }

    part def PLCBUSAutomationSystem {
        attribute systemName : String = "PLCBUS Building Automation System";
        attribute primaryFunction : String =
            "Monitor and control distributed electrical loads by exchanging encoded PLCBUS messages over existing power-line wiring.";
        attribute nominalMainsVoltage : VoltageRMS = 120 [SI::volt];
        attribute nominalMainsFrequency : Frequency = 60 [SI::hertz];
        attribute requiredCommandDeliveryTime : TimeMs = 750 [SI::millisecond];
        attribute requiredStatusRefreshTime : TimeMs = 5000 [SI::millisecond];

        part bus : PLCBusSegment;
        part controller : PLCBusController;
        part gateway : PLCGateway;
        part repeater[2] : PLCRepeaterNode;
        part lightingNode[4] : PLCActuatorNode {
            attribute ratedLoadPower : Power = 300 [SI::watt];
        }
        part receptacleNode[2] : PLCActuatorNode {
            attribute ratedLoadPower : Power = 1200 [SI::watt];
        }
        part meteringNode[3] : PLCSensorNode;

        port operatorConsole : OperatorPort;
        port externalAutomationNetwork : GatewayPort;

        connect operatorConsole to controller.operatorInterface;
        connect externalAutomationNetwork to gateway.externalPort;

        connect controller.busPort to bus.controllerTap;
        connect gateway.busPort to bus.nodeTap;
        connect repeater.upstream to bus.repeaterTap;
        connect repeater.downstream to bus.nodeTap;
        connect lightingNode.busPort to bus.nodeTap;
        connect receptacleNode.busPort to bus.nodeTap;
        connect meteringNode.busPort to bus.nodeTap;

        perform controller.measure;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : PLCBUSAutomationSystem;
        require constraint {
            system.primaryFunction ==
            "Monitor and control distributed electrical loads by exchanging encoded PLCBUS messages over existing power-line wiring."
        }
    }

    requirement def CommandDeliveryRequirement {
        subject system : PLCBUSAutomationSystem;
        require constraint {
            system.requiredCommandDeliveryTime <= 750 [SI::millisecond]
        }
    }

    requirement def StatusRefreshRequirement {
        subject system : PLCBUSAutomationSystem;
        require constraint {
            system.requiredStatusRefreshTime <= 5000 [SI::millisecond]
        }
    }

    requirement def AddressCapacityRequirement {
        subject bus : PLCBusSegment;
        require constraint {
            bus.maximumNodes >= 16
        }
    }

    requirement def NominalPowerCompatibilityRequirement {
        subject system : PLCBUSAutomationSystem;
        require constraint {
            system.nominalMainsVoltage == 120 [SI::volt] and
            system.nominalMainsFrequency == 60 [SI::hertz]
        }
    }

    requirement def FaultIsolationRequirement {
        subject node : PLCActuatorNode;
        require constraint {
            node.frameErrorCounter <= 100
        }
    }

    satisfy PrimaryFunctionRequirement by PLCBUSAutomationSystem;
    satisfy CommandDeliveryRequirement by PLCBUSAutomationSystem;
    satisfy StatusRefreshRequirement by PLCBUSAutomationSystem;
    satisfy AddressCapacityRequirement by PLCBusSegment;
    satisfy NominalPowerCompatibilityRequirement by PLCBUSAutomationSystem;
    satisfy FaultIsolationRequirement by PLCActuatorNode;
}