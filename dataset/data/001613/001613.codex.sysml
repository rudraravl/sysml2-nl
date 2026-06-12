package UniversalPowerlineBusSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Volt;
    attribute def Ampere;
    attribute def Watt;
    attribute def Hertz;
    attribute def Second;
    attribute def Meter;
    attribute def Percent;

    enum def MessageKind {
        enum command;
        enum status;
        enum acknowledgement;
        enum configuration;
        enum sceneActivation;
        enum faultReport;
    }

    enum def DeviceState {
        enum unpowered;
        enum initializing;
        enum idle;
        enum transmitting;
        enum receiving;
        enum executingCommand;
        enum faulted;
    }

    enum def LoadMode {
        enum off;
        enum on;
        enum dimmed;
    }

    item def PowerlineSignal {
        attribute sourceAddress : Integer;
        attribute destinationAddress : Integer;
        attribute networkId : Integer;
        attribute kind : MessageKind;
        attribute pulsePositionCode : Integer;
        attribute payloadBytes : Integer;
        attribute checksum : Integer;
        attribute signalAmplitude : Volt;
        attribute carrierFrequency : Hertz;
        attribute symbolDuration : Second;
    }

    item def AcMainsPower {
        attribute rmsVoltage : Volt;
        attribute frequency : Hertz;
        attribute branchCurrent : Ampere;
        attribute availablePower : Watt;
    }

    item def LightingCommand {
        attribute destinationAddress : Integer;
        attribute targetMode : LoadMode;
        attribute brightness : Percent;
        attribute fadeTime : Second;
    }

    item def DeviceStatus {
        attribute deviceAddress : Integer;
        attribute state : DeviceState;
        attribute loadMode : LoadMode;
        attribute brightness : Percent;
        attribute measuredVoltage : Volt;
        attribute measuredLoadPower : Watt;
    }

    port def PowerlinePort {
        inout power : AcMainsPower;
        inout signal : PowerlineSignal;
    }

    port def LoadPowerPort {
        out switchedPower : AcMainsPower;
    }

    port def ControlPort {
        in command : LightingCommand;
        out status : DeviceStatus;
    }

    port def UserInterfacePort {
        out command : LightingCommand;
        in status : DeviceStatus;
    }

    action def EncodePowerlineMessage {
        in command : LightingCommand;
        in sourceAddress : Integer;
        in networkId : Integer;
        out signal : PowerlineSignal;

        action assignHeader {
            signal.sourceAddress := sourceAddress;
            signal.destinationAddress := command.destinationAddress;
            signal.networkId := networkId;
            signal.kind := MessageKind::command;
        }

        action encodePayload {
            signal.payloadBytes := command.brightness;
            signal.pulsePositionCode := command.destinationAddress + command.brightness;
            signal.carrierFrequency := 60000 [Hertz];
            signal.symbolDuration := 0.00833 [Second];
            signal.signalAmplitude := 40 [Volt];
        }

        action appendChecksum {
            signal.checksum := signal.sourceAddress + signal.destinationAddress + signal.payloadBytes;
        }

        first start;
        then assignHeader;
        then encodePayload;
        then appendChecksum;
        then done;
    }

    action def DecodePowerlineMessage {
        in signal : PowerlineSignal;
        out command : LightingCommand;

        action validateNetwork {
            assert signal.checksum == signal.sourceAddress + signal.destinationAddress + signal.payloadBytes;
        }

        action mapPayload {
            command.destinationAddress := signal.destinationAddress;
            command.targetMode := LoadMode::dimmed;
            command.brightness := signal.payloadBytes;
            command.fadeTime := 1 [Second];
        }

        first start;
        then validateNetwork;
        then mapPayload;
        then done;
    }

    action def ApplyLightingCommand {
        in command : LightingCommand;
        inout loadMode : LoadMode;
        inout brightness : Percent;
        out status : DeviceStatus;

        action selectMode {
            if command.brightness == 0 then {
                loadMode := LoadMode::off;
            } else if command.brightness == 100 then {
                loadMode := LoadMode::on;
            } else {
                loadMode := LoadMode::dimmed;
            }
        }

        action setBrightness {
            brightness := command.brightness;
        }

        action publishStatus {
            status.loadMode := loadMode;
            status.brightness := brightness;
            status.state := DeviceState::idle;
        }

        first start;
        then selectMode;
        then setBrightness;
        then publishStatus;
        then done;
    }

    state def PowerlineNodeLifecycle {
        in faultDetected : Boolean;
        in transmitRequested : Boolean;
        in receiveDetected : Boolean;
        in commandDecoded : Boolean;
        in resetRequested : Boolean;

        state unpowered;
        state initializing;
        state idle;
        state transmitting;
        state receiving;
        state executingCommand;
        state faulted;

        transition first start then unpowered;
        transition powerApplied from unpowered to initializing;
        transition initializationComplete from initializing to idle;
        transition beginTransmit from idle to transmitting if transmitRequested;
        transition transmitComplete from transmitting to idle;
        transition beginReceive from idle to receiving if receiveDetected;
        transition decodeComplete from receiving to executingCommand if commandDecoded;
        transition commandComplete from executingCommand to idle;
        transition receiveIgnored from receiving to idle if not commandDecoded;
        transition faultDuringIdle from idle to faulted if faultDetected;
        transition faultDuringTransmit from transmitting to faulted if faultDetected;
        transition faultDuringReceive from receiving to faulted if faultDetected;
        transition recover from faulted to initializing if resetRequested;
    }

    part def AcBranchCircuit {
        attribute nominalVoltage : Volt = 120 [Volt];
        attribute nominalFrequency : Hertz = 60 [Hertz];
        attribute maximumCurrent : Ampere = 15 [Ampere];
        attribute wiringLength : Meter = 45 [Meter];

        port panelSide : PowerlinePort;
        port outletSide : PowerlinePort;
    }

    part def PowerlineBusCoupler {
        attribute minimumDetectableSignal : Volt = 5 [Volt];
        attribute maximumInjectedSignal : Volt = 40 [Volt];
        attribute zeroCrossingTolerance : Second = 0.0002 [Second];

        port mains : PowerlinePort;
        port node : PowerlinePort;

        perform action coupleSignal {
            inout mainsSignal : PowerlineSignal = mains.signal;
            inout nodeSignal : PowerlineSignal = node.signal;
            nodeSignal := mainsSignal;
            mainsSignal := nodeSignal;
        }
    }

    part def UniversalPowerlineController {
        attribute address : Integer = 1;
        attribute networkId : Integer = 42;
        attribute state : DeviceState = DeviceState::idle;

        port ui : UserInterfacePort;
        port bus : PowerlinePort;

        perform action encode : EncodePowerlineMessage {
            in command = ui.command;
            in sourceAddress = address;
            in networkId = networkId;
            out signal = bus.signal;
        }

        exhibit stateMachine : PowerlineNodeLifecycle;
    }

    part def WallKeypad {
        attribute address : Integer = 10;
        attribute sceneButtonCount : Integer = 6;
        attribute state : DeviceState = DeviceState::idle;

        port user : UserInterfacePort;
        port bus : PowerlinePort;

        perform action sendSceneActivation : EncodePowerlineMessage {
            in command = user.command;
            in sourceAddress = address;
            in networkId = 42;
            out signal = bus.signal;
        }

        exhibit stateMachine : PowerlineNodeLifecycle;
    }

    part def LampModule {
        attribute address : Integer = 21;
        attribute ratedPower : Watt = 300 [Watt];
        attribute loadMode : LoadMode = LoadMode::off;
        attribute brightness : Percent = 0 [Percent];
        attribute state : DeviceState = DeviceState::idle;

        port bus : PowerlinePort;
        port load : LoadPowerPort;
        port localControl : ControlPort;

        perform action decode : DecodePowerlineMessage {
            in signal = bus.signal;
            out command = localControl.command;
        }

        perform action apply : ApplyLightingCommand {
            in command = localControl.command;
            inout loadMode = loadMode;
            inout brightness = brightness;
            out status = localControl.status;
        }

        exhibit stateMachine : PowerlineNodeLifecycle;
    }

    part def ApplianceModule {
        attribute address : Integer = 22;
        attribute ratedPower : Watt = 1200 [Watt];
        attribute loadMode : LoadMode = LoadMode::off;
        attribute brightness : Percent = 0 [Percent];
        attribute state : DeviceState = DeviceState::idle;

        port bus : PowerlinePort;
        port load : LoadPowerPort;
        port localControl : ControlPort;

        perform action decode : DecodePowerlineMessage {
            in signal = bus.signal;
            out command = localControl.command;
        }

        perform action switchLoad : ApplyLightingCommand {
            in command = localControl.command;
            inout loadMode = loadMode;
            inout brightness = brightness;
            out status = localControl.status;
        }

        exhibit stateMachine : PowerlineNodeLifecycle;
    }

    part def StatusMonitor {
        attribute address : Integer = 30;
        attribute networkId : Integer = 42;
        attribute pollingPeriod : Second = 60 [Second];

        port bus : PowerlinePort;
        port management : ControlPort;

        perform action decodeStatus : DecodePowerlineMessage {
            in signal = bus.signal;
            out command = management.command;
        }

        exhibit stateMachine : PowerlineNodeLifecycle;
    }

    part def UniversalPowerlineBusInstallation {
        attribute primaryFunction : String =
            "Distribute automation commands and status messages over existing AC power wiring so controllers, keypads, lighting modules, and appliance modules can coordinate loads without dedicated communication cabling.";

        part branchCircuit : AcBranchCircuit;
        part serviceCoupler : PowerlineBusCoupler;
        part controller : UniversalPowerlineController;
        part keypad : WallKeypad;
        part livingRoomLamp : LampModule;
        part hallLamp : LampModule {
            attribute address = 23;
            attribute ratedPower = 150 [Watt];
        }
        part coffeeMakerModule : ApplianceModule;
        part monitor : StatusMonitor;

        connect branchCircuit.outletSide to serviceCoupler.mains;
        connect serviceCoupler.node to controller.bus;
        connect serviceCoupler.node to keypad.bus;
        connect serviceCoupler.node to livingRoomLamp.bus;
        connect serviceCoupler.node to hallLamp.bus;
        connect serviceCoupler.node to coffeeMakerModule.bus;
        connect serviceCoupler.node to monitor.bus;

        connect controller.ui to keypad.user;
        connect livingRoomLamp.localControl to monitor.management;
        connect hallLamp.localControl to monitor.management;
        connect coffeeMakerModule.localControl to monitor.management;
    }

    requirement def ExistingWiringCommunication {
        subject installation : UniversalPowerlineBusInstallation;

        require constraint {
            installation.branchCircuit.nominalVoltage == 120 [Volt] and
            installation.branchCircuit.nominalFrequency == 60 [Hertz]
        }

        doc /* The system shall use the existing AC branch circuit as the communication medium for automation messages. */
    }

    requirement def AddressedMessageDelivery {
        subject signal : PowerlineSignal;

        require constraint {
            signal.networkId > 0 and
            signal.sourceAddress > 0 and
            signal.destinationAddress > 0 and
            signal.checksum == signal.sourceAddress + signal.destinationAddress + signal.payloadBytes
        }

        doc /* Each bus message shall include a network identifier, source address, destination address, payload, and checksum sufficient for addressed delivery and validation. */
    }

    requirement def LightingControlFunction {
        subject module : LampModule;

        require constraint {
            module.ratedPower <= 300 [Watt] and
            module.brightness >= 0 [Percent] and
            module.brightness <= 100 [Percent]
        }

        doc /* Lamp modules shall translate valid bus commands into controlled load output from off through full brightness. */
    }

    requirement def ApplianceSwitchingFunction {
        subject module : ApplianceModule;

        require constraint {
            module.ratedPower <= 1200 [Watt] and
            (module.loadMode == LoadMode::off or module.loadMode == LoadMode::on)
        }

        doc /* Appliance modules shall provide addressed on/off control for connected loads within rated power. */
    }

    requirement def FaultRecovery {
        subject controller : UniversalPowerlineController;

        require constraint {
            controller.state != DeviceState::faulted
        }

        doc /* A bus node shall detect communication or powerline coupling faults and support reset-based recovery to initialization. */
    }

    satisfy ExistingWiringCommunication by UniversalPowerlineBusInstallation::branchCircuit;
    satisfy AddressedMessageDelivery by EncodePowerlineMessage;
    satisfy LightingControlFunction by UniversalPowerlineBusInstallation::livingRoomLamp;
    satisfy LightingControlFunction by UniversalPowerlineBusInstallation::hallLamp;
    satisfy ApplianceSwitchingFunction by UniversalPowerlineBusInstallation::coffeeMakerModule;
    satisfy FaultRecovery by UniversalPowerlineBusInstallation::controller;
}