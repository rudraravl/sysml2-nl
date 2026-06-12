package X10BasedHomeAutomationSystem {

    import ScalarValues::*;
    import SI::*;

    attribute def Address {
        houseCode : HouseCode;
        unitCode : Integer;
    }

    enum def HouseCode {
        enum A;
        enum B;
        enum C;
        enum D;
        enum E;
        enum F;
        enum G;
        enum H;
        enum I;
        enum J;
        enum K;
        enum L;
        enum M;
        enum N;
        enum O;
        enum P;
    }

    enum def CommandKind {
        enum On;
        enum Off;
        enum Dim;
        enum Bright;
        enum AllLightsOn;
        enum AllUnitsOff;
        enum StatusRequest;
        enum StatusResponse;
    }

    enum def DeviceState {
        enum Offline;
        enum Idle;
        enum Receiving;
        enum Transmitting;
        enum Executing;
        enum Faulted;
    }

    item def X10Command {
        attribute source : Address;
        attribute destination : Address;
        attribute kind : CommandKind;
        attribute dimLevel : Real;
        attribute repeatCount : Integer;
        attribute checksumValid : Boolean;
    }

    item def PowerLineSignal {
        attribute carrierFrequency : FrequencyValue;
        attribute burstDuration : TimeValue;
        attribute zeroCrossingAligned : Boolean;
        attribute encodedCommand : X10Command;
    }

    item def UserIntent {
        attribute target : Address;
        attribute requestedCommand : CommandKind;
        attribute requestedDimLevel : Real;
    }

    item def DeviceStatus {
        attribute deviceAddress : Address;
        attribute isPowered : Boolean;
        attribute currentLoadPower : PowerValue;
        attribute currentDimLevel : Real;
        attribute faultPresent : Boolean;
    }

    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute frequency : FrequencyValue;
        attribute availableCurrent : CurrentValue;
    }

    attribute def FrequencyValue :> Real {
        unit = "Hz";
    }

    attribute def TimeValue :> Real {
        unit = "s";
    }

    attribute def VoltageValue :> Real {
        unit = "V";
    }

    attribute def CurrentValue :> Real {
        unit = "A";
    }

    attribute def PowerValue :> Real {
        unit = "W";
    }

    attribute def PercentValue :> Real {
        unit = "%";
    }

    port def UserCommandPort {
        in item intent : UserIntent;
        out item status : DeviceStatus;
    }

    port def PowerLinePort {
        inout item signal : PowerLineSignal;
        in item mainsPower : ElectricalPower;
    }

    port def LoadPowerPort {
        out item switchedPower : ElectricalPower;
        out item loadStatus : DeviceStatus;
    }

    part def X10HomeAutomationSystem {
        attribute primaryFunction : String = "Provide centralized and scheduled control of household electrical loads by encoding user commands as X10 power-line carrier signals and executing them at addressed modules.";

        part controller : X10Controller;
        part powerInterface : PowerLineInterface;
        part lightingModule : X10LampModule;
        part applianceModule : X10ApplianceModule;
        part wallSwitchModule : X10WallSwitchModule;
        part scheduler : AutomationScheduler;
        part statusMonitor : StatusMonitor;

        port userPort : UserCommandPort;
        port mainsPort : PowerLinePort;
        port livingRoomLampPower : LoadPowerPort;
        port coffeeMakerPower : LoadPowerPort;
        port porchLightPower : LoadPowerPort;

        connect userPort to controller.userPort;
        connect controller.schedulerPort to scheduler.commandPort;
        connect controller.statusPort to statusMonitor.statusPort;
        connect controller.powerLinePort to powerInterface.controllerPort;
        connect powerInterface.mainsPort to mainsPort;
        connect powerInterface.busPort to lightingModule.powerLinePort;
        connect powerInterface.busPort to applianceModule.powerLinePort;
        connect powerInterface.busPort to wallSwitchModule.powerLinePort;
        connect lightingModule.loadPort to livingRoomLampPower;
        connect applianceModule.loadPort to coffeeMakerPower;
        connect wallSwitchModule.loadPort to porchLightPower;
    }

    part def X10Controller {
        attribute address : Address = (houseCode = HouseCode::A, unitCode = 1);
        attribute maxQueuedCommands : Integer = 32;
        attribute defaultRepeatCount : Integer = 2;
        attribute commandTimeout : TimeValue = 2.0 [s];

        port userPort : UserCommandPort;
        port powerLinePort : PowerLinePort;
        port schedulerPort : UserCommandPort;
        port statusPort : UserCommandPort;

        action encodeUserIntent {
            in item intent : UserIntent;
            out item command : X10Command;

            command.source = address;
            command.destination = intent.target;
            command.kind = intent.requestedCommand;
            command.dimLevel = intent.requestedDimLevel;
            command.repeatCount = defaultRepeatCount;
            command.checksumValid = true;
        }

        action transmitCommand {
            in item command : X10Command;
            out item signal : PowerLineSignal;

            signal.carrierFrequency = 120000 [Hz];
            signal.burstDuration = 0.001 [s];
            signal.zeroCrossingAligned = true;
            signal.encodedCommand = command;
        }

        state def ControllerStateMachine {
            state idle;
            state acceptingIntent;
            state encoding;
            state transmitting;
            state awaitingStatus;
            state faulted;

            initial then idle;

            transition idle_to_accepting
                first idle
                accept UserIntent
                then acceptingIntent;

            transition accepting_to_encoding
                first acceptingIntent
                do encodeUserIntent
                then encoding;

            transition encoding_to_transmitting
                first encoding
                do transmitCommand
                then transmitting;

            transition transmitting_to_awaiting
                first transmitting
                then awaitingStatus;

            transition awaiting_to_idle
                first awaitingStatus
                accept DeviceStatus
                then idle;

            transition awaiting_timeout_to_fault
                first awaitingStatus
                if commandTimeout > 0.0 [s]
                then faulted;

            transition fault_reset_to_idle
                first faulted
                accept UserIntent
                then idle;
        }

        exhibit state ControllerStateMachine;
    }

    part def PowerLineInterface {
        attribute nominalVoltage : VoltageValue = 120 [V];
        attribute nominalFrequency : FrequencyValue = 60 [Hz];
        attribute carrierFrequency : FrequencyValue = 120000 [Hz];
        attribute injectionImpedanceOhms : Real = 5.0;
        attribute isolationRating : VoltageValue = 1500 [V];

        port controllerPort : PowerLinePort;
        port mainsPort : PowerLinePort;
        port busPort : PowerLinePort;

        action injectCarrierBurst {
            in item commandSignal : PowerLineSignal;
            out item coupledSignal : PowerLineSignal;

            coupledSignal = commandSignal;
            coupledSignal.zeroCrossingAligned = true;
            coupledSignal.carrierFrequency = carrierFrequency;
        }

        action detectIncomingBurst {
            in item lineSignal : PowerLineSignal;
            out item decodedCommand : X10Command;

            decodedCommand = lineSignal.encodedCommand;
        }
    }

    part def X10ControlledModule {
        attribute address : Address;
        attribute state : DeviceState = DeviceState::Idle;
        attribute maximumLoadPower : PowerValue;
        attribute currentDimLevel : PercentValue = 0 [%];
        attribute localFaultPresent : Boolean = false;

        port powerLinePort : PowerLinePort;
        port loadPort : LoadPowerPort;

        action decodeAddressedCommand {
            in item signal : PowerLineSignal;
            out item command : X10Command;
            out attribute isAddressed : Boolean;

            command = signal.encodedCommand;
            isAddressed = command.destination.houseCode == address.houseCode and command.destination.unitCode == address.unitCode;
        }

        action reportStatus {
            out item status : DeviceStatus;

            status.deviceAddress = address;
            status.isPowered = currentDimLevel > 0 [%];
            status.currentDimLevel = currentDimLevel;
            status.currentLoadPower = maximumLoadPower * currentDimLevel / 100 [%];
            status.faultPresent = localFaultPresent;
        }

        state def ModuleStateMachine {
            state offline;
            state idle;
            state receiving;
            state executing;
            state reportingStatus;
            state faulted;

            initial then offline;

            transition powered_to_idle
                first offline
                accept ElectricalPower
                then idle;

            transition idle_to_receiving
                first idle
                accept PowerLineSignal
                then receiving;

            transition receiving_to_executing
                first receiving
                if localFaultPresent == false
                then executing;

            transition executing_to_reporting
                first executing
                do reportStatus
                then reportingStatus;

            transition reporting_to_idle
                first reportingStatus
                then idle;

            transition receiving_to_faulted
                first receiving
                if localFaultPresent == true
                then faulted;

            transition faulted_to_idle
                first faulted
                accept X10Command
                if localFaultPresent == false
                then idle;
        }

        exhibit state ModuleStateMachine;
    }

    part def X10LampModule :> X10ControlledModule {
        attribute address : Address = (houseCode = HouseCode::A, unitCode = 2);
        attribute maximumLoadPower : PowerValue = 300 [W];
        attribute minimumDimLevel : PercentValue = 10 [%];

        action executeLampCommand {
            in item command : X10Command;

            if command.kind == CommandKind::On {
                currentDimLevel = 100 [%];
            }
            if command.kind == CommandKind::Off {
                currentDimLevel = 0 [%];
            }
            if command.kind == CommandKind::Dim {
                currentDimLevel = command.dimLevel;
            }
            if command.kind == CommandKind::Bright {
                currentDimLevel = 100 [%];
            }
        }
    }

    part def X10ApplianceModule :> X10ControlledModule {
        attribute address : Address = (houseCode = HouseCode::A, unitCode = 3);
        attribute maximumLoadPower : PowerValue = 1500 [W];
        attribute relayClosed : Boolean = false;

        action executeApplianceCommand {
            in item command : X10Command;

            if command.kind == CommandKind::On {
                relayClosed = true;
                currentDimLevel = 100 [%];
            }
            if command.kind == CommandKind::Off {
                relayClosed = false;
                currentDimLevel = 0 [%];
            }
            if command.kind == CommandKind::AllUnitsOff {
                relayClosed = false;
                currentDimLevel = 0 [%];
            }
        }
    }

    part def X10WallSwitchModule :> X10ControlledModule {
        attribute address : Address = (houseCode = HouseCode::A, unitCode = 4);
        attribute maximumLoadPower : PowerValue = 600 [W];
        attribute manualOverrideEnabled : Boolean = true;

        action executeSwitchCommand {
            in item command : X10Command;

            if command.kind == CommandKind::On or command.kind == CommandKind::AllLightsOn {
                currentDimLevel = 100 [%];
            }
            if command.kind == CommandKind::Off or command.kind == CommandKind::AllUnitsOff {
                currentDimLevel = 0 [%];
            }
            if command.kind == CommandKind::Dim {
                currentDimLevel = command.dimLevel;
            }
        }
    }

    part def AutomationScheduler {
        attribute morningSceneTime : TimeValue = 21600 [s];
        attribute eveningSceneTime : TimeValue = 64800 [s];
        attribute awayModeEnabled : Boolean = false;

        port commandPort : UserCommandPort;

        action createMorningScene {
            out item lampIntent : UserIntent;
            out item applianceIntent : UserIntent;

            lampIntent.target = (houseCode = HouseCode::A, unitCode = 2);
            lampIntent.requestedCommand = CommandKind::Bright;
            lampIntent.requestedDimLevel = 100 [%];

            applianceIntent.target = (houseCode = HouseCode::A, unitCode = 3);
            applianceIntent.requestedCommand = CommandKind::On;
            applianceIntent.requestedDimLevel = 100 [%];
        }

        action createEveningScene {
            out item porchIntent : UserIntent;
            out item lampIntent : UserIntent;

            porchIntent.target = (houseCode = HouseCode::A, unitCode = 4);
            porchIntent.requestedCommand = CommandKind::On;
            porchIntent.requestedDimLevel = 100 [%];

            lampIntent.target = (houseCode = HouseCode::A, unitCode = 2);
            lampIntent.requestedCommand = CommandKind::Dim;
            lampIntent.requestedDimLevel = 40 [%];
        }
    }

    part def StatusMonitor {
        attribute statusRetentionTime : TimeValue = 86400 [s];
        attribute faultCount : Integer = 0;
        attribute lastKnownTotalLoad : PowerValue = 0 [W];

        port statusPort : UserCommandPort;

        action aggregateStatus {
            in item lampStatus : DeviceStatus;
            in item applianceStatus : DeviceStatus;
            in item switchStatus : DeviceStatus;
            out attribute totalLoad : PowerValue;
            out attribute anyFault : Boolean;

            totalLoad = lampStatus.currentLoadPower + applianceStatus.currentLoadPower + switchStatus.currentLoadPower;
            anyFault = lampStatus.faultPresent or applianceStatus.faultPresent or switchStatus.faultPresent;
            lastKnownTotalLoad = totalLoad;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : X10HomeAutomationSystem;

        doc /* The system shall provide high-level home automation by receiving user or scheduled intents, translating them into addressed X10 commands, transmitting those commands over residential power wiring, and controlling connected lighting and appliance loads. */

        require constraint {
            system.controller.defaultRepeatCount >= 2;
        }
    }

    requirement def AddressedControlRequirement {
        subject module : X10ControlledModule;

        doc /* Each controlled module shall execute only commands whose X10 house code and unit code match the module address. */

        require constraint {
            module.address.unitCode >= 1 and module.address.unitCode <= 16;
        }
    }

    requirement def PowerLineCarrierRequirement {
        subject interface : PowerLineInterface;

        doc /* The power-line interface shall couple X10 carrier bursts onto the mains at the standard carrier frequency and align bursts to AC zero crossings. */

        require constraint {
            interface.carrierFrequency == 120000 [Hz];
        }
    }

    requirement def LoadSafetyRequirement {
        subject module : X10ControlledModule;

        doc /* A controlled module shall not command a load above its declared maximum load rating. */

        require constraint {
            module.maximumLoadPower > 0 [W];
        }
    }

    requirement def StatusReportingRequirement {
        subject monitor : StatusMonitor;

        doc /* The system shall maintain current load state, dim level, and fault state for each controlled X10 module. */

        require constraint {
            monitor.statusRetentionTime >= 3600 [s];
        }
    }

    satisfy PrimaryFunctionRequirement by X10HomeAutomationSystem;
    satisfy PowerLineCarrierRequirement by PowerLineInterface;
    satisfy LoadSafetyRequirement by X10LampModule;
    satisfy LoadSafetyRequirement by X10ApplianceModule;
    satisfy LoadSafetyRequirement by X10WallSwitchModule;
    satisfy StatusReportingRequirement by StatusMonitor;

}