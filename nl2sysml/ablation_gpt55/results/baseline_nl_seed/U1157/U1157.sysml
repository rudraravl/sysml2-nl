package PLCBUS_Automation_Model {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def Voltage :> ISQ::electricPotential;
    attribute def Current :> ISQ::electricCurrent;
    attribute def ActivePower :> ISQ::power;
    attribute def Energy :> ISQ::energy;
    attribute def Frequency :> ISQ::frequency;
    attribute def Duration :> ISQ::duration;
    attribute def Temperature :> ISQ::thermodynamicTemperature;
    attribute def Percent :> ScalarValues::Real;
    attribute def Availability :> ScalarValues::Real;
    attribute def PlcAddress :> ScalarValues::Integer;
    attribute def SequenceNumber :> ScalarValues::Integer;
    attribute def FrameLength :> ScalarValues::Integer;

    enum def CommandKind {
        enum switchOn;
        enum switchOff;
        enum setLevel;
        enum requestStatus;
        enum resetFault;
    }

    enum def DeviceKind {
        enum masterController;
        enum lampModule;
        enum hvacModule;
        enum outletModule;
        enum wallSwitch;
        enum lineCoupler;
    }

    enum def DeviceHealth {
        enum healthy;
        enum warning;
        enum degraded;
        enum faulted;
        enum unreachable;
    }

    enum def PlcPriority {
        enum low;
        enum normal;
        enum high;
        enum emergency;
    }

    item def AcPower {
        attribute rmsVoltage: Voltage = 230 [V];
        attribute frequency: Frequency = 50 [Hz];
        attribute maximumCurrent: Current = 16 [A];
        attribute realPower: ActivePower = 0 [W];
    }

    item def ControlCommand {
        attribute sourceAddress: PlcAddress;
        attribute targetAddress: PlcAddress;
        attribute command: CommandKind;
        attribute priority: PlcPriority = PlcPriority::normal;
        attribute requestedLevel: Percent = 100.0;
        attribute sequence: SequenceNumber;
    }

    item def DeviceStatus {
        attribute deviceAddress: PlcAddress;
        attribute deviceType: DeviceKind;
        attribute health: DeviceHealth;
        attribute measuredPower: ActivePower = 0 [W];
        attribute measuredCurrent: Current = 0 [A];
        attribute localTemperature: Temperature = 296.15 [K];
        attribute loadLevel: Percent = 0.0;
        attribute lastSequence: SequenceNumber;
    }

    item def PlcFrame {
        attribute preambleLength: FrameLength = 16;
        attribute sourceAddress: PlcAddress;
        attribute destinationAddress: PlcAddress;
        attribute sequence: SequenceNumber;
        attribute priority: PlcPriority;
        attribute payloadCommand: CommandKind;
        attribute payloadLevel: Percent;
        attribute checksumValid: Boolean = true;
    }

    item def OperatorRequest {
        attribute requestedCommand: CommandKind;
        attribute requestedTarget: PlcAddress;
        attribute requestedLevel: Percent;
    }

    port def ElectricalPowerPort {
        inout item acPower: AcPower;
    }

    port def LowVoltagePlcPort {
        inout item frame: PlcFrame;
    }

    port def PlcPowerLinePort {
        inout item acPower: AcPower;
        inout item frame: PlcFrame;
    }

    port def OperatorInterfacePort {
        in item operatorRequest: OperatorRequest;
        out item acknowledgedStatus: DeviceStatus;
    }

    port def LoadOutputPort {
        out item switchedPower: AcPower;
    }

    port def StatusPort {
        out item status: DeviceStatus;
    }

    action def EncodeControlCommand {
        in item commandIn: ControlCommand;
        out item frameOut: PlcFrame;
        attribute encodingTime: Duration = 0.020 [s];
    }

    action def InjectFrameOnPowerLine {
        in item frameIn: PlcFrame;
        in item carrierPower: AcPower;
        out item modulatedPowerLineFrame: PlcFrame;
        attribute injectionVoltage: Voltage = 5 [V];
        attribute injectionDuration: Duration = 0.080 [s];
    }

    action def DecodeStatusFrame {
        in item statusFrame: PlcFrame;
        out item statusOut: DeviceStatus;
        attribute decodingTime: Duration = 0.025 [s];
    }

    action def ExecuteControlCycle {
        in item operatorRequest: OperatorRequest;
        out item reportedStatus: DeviceStatus;

        action encode: EncodeControlCommand;
        action inject: InjectFrameOnPowerLine;
        action decode: DecodeStatusFrame;

        attribute nominalCycleTime: Duration = 0.750 [s];
    }

    state def PlcBusSystemOperatingState {
        state PowerOff;
        state Initializing;
        state Ready;
        state Commanding;
        state AwaitingStatus;
        state Monitoring;
        state FaultIsolated;

        transition powerApplied first PowerOff then Initializing;
        transition initialized first Initializing then Ready;
        transition commandRequested first Ready accept OperatorRequest then Commanding;
        transition commandTransmitted first Commanding then AwaitingStatus;
        transition statusReceived first AwaitingStatus accept DeviceStatus then Monitoring;
        transition monitorComplete first Monitoring then Ready;
        transition communicationFault first AwaitingStatus then FaultIsolated;
        transition resetAfterFault first FaultIsolated accept ControlCommand then Initializing;
    }

    state def PlcDeviceModuleState {
        state Unpowered;
        state JoiningBus;
        state Listening;
        state ExecutingCommand;
        state ReportingStatus;
        state LocalFault;

        transition energized first Unpowered then JoiningBus;
        transition joined first JoiningBus then Listening;
        transition frameAccepted first Listening accept PlcFrame then ExecutingCommand;
        transition commandComplete first ExecutingCommand then ReportingStatus;
        transition reportSent first ReportingStatus then Listening;
        transition deviceFault first ExecutingCommand then LocalFault;
        transition faultReset first LocalFault accept PlcFrame then JoiningBus;
    }

    part def MainsPanel {
        port acOut: ElectricalPowerPort;
        attribute nominalVoltage: Voltage = 230 [V];
        attribute nominalFrequency: Frequency = 50 [Hz];
        attribute breakerRating: Current = 16 [A];
        attribute availablePower: ActivePower = 3680 [W];
    }

    part def PlcBusMasterController {
        port operatorInterface: OperatorInterfacePort;
        port plcPort: LowVoltagePlcPort;

        attribute address: PlcAddress = 1;
        attribute availability: Availability = 0.998;
        attribute statusRefreshPeriod: Duration = 5 [s];
        attribute maximumCommandLatency: Duration = 1 [s];

        perform action controlCycle: ExecuteControlCycle;
        exhibit state operatingState: PlcBusSystemOperatingState;
    }

    part def PlcLineCoupler {
        port controllerBus: LowVoltagePlcPort;
        port mainsIn: ElectricalPowerPort;
        port powerLinePort: PlcPowerLinePort;

        attribute deviceAddress: PlcAddress = 2;
        attribute coupledSignalVoltage: Voltage = 5 [V];
        attribute isolationWithstandVoltage: Voltage = 2500 [V];
        attribute insertionLoss: Percent = 8.0;

        perform action injection: InjectFrameOnPowerLine;
    }

    part def BuildingPowerLine {
        port feed: PlcPowerLinePort;
        port lightingBranch: PlcPowerLinePort;
        port hvacBranch: PlcPowerLinePort;
        port outletBranch: PlcPowerLinePort;
        port switchBranch: PlcPowerLinePort;

        attribute conductorVoltage: Voltage = 230 [V];
        attribute conductorFrequency: Frequency = 50 [Hz];
        attribute totalBranchCurrentLimit: Current = 16 [A];
        attribute estimatedLineLoss: Percent = 2.5;

        connection feedToLighting connect feed to lightingBranch;
        connection feedToHvac connect feed to hvacBranch;
        connection feedToOutlet connect feed to outletBranch;
        connection feedToSwitch connect feed to switchBranch;
    }

    part def PlcLampModule {
        port plcBus: PlcPowerLinePort;
        port loadOut: LoadOutputPort;
        port statusOut: StatusPort;

        attribute deviceAddress: PlcAddress = 10;
        attribute ratedPower: ActivePower = 120 [W];
        attribute commandedLevel: Percent = 0.0;
        attribute measuredPower: ActivePower = 0 [W];

        exhibit state moduleState: PlcDeviceModuleState;
    }

    part def PlcHvacModule {
        port plcBus: PlcPowerLinePort;
        port loadOut: LoadOutputPort;
        port statusOut: StatusPort;

        attribute deviceAddress: PlcAddress = 20;
        attribute ratedPower: ActivePower = 1800 [W];
        attribute commandedLevel: Percent = 0.0;
        attribute measuredPower: ActivePower = 0 [W];
        attribute measuredTemperature: Temperature = 296.15 [K];

        exhibit state moduleState: PlcDeviceModuleState;
    }

    part def PlcOutletModule {
        port plcBus: PlcPowerLinePort;
        port loadOut: LoadOutputPort;
        port statusOut: StatusPort;

        attribute deviceAddress: PlcAddress = 30;
        attribute ratedPower: ActivePower = 1000 [W];
        attribute commandedLevel: Percent = 0.0;
        attribute measuredPower: ActivePower = 0 [W];

        exhibit state moduleState: PlcDeviceModuleState;
    }

    part def PlcWallSwitch {
        port plcBus: PlcPowerLinePort;
        port statusOut: StatusPort;

        attribute deviceAddress: PlcAddress = 40;
        attribute debounceTime: Duration = 0.050 [s];
        attribute lastRequestedLevel: Percent = 100.0;

        exhibit state moduleState: PlcDeviceModuleState;
    }

    part def PlcBusAutomationSystem {
        doc /* Primary high-level function: control and monitor distributed electrical loads by sending PLCBUS command and status frames over the existing AC mains conductors, avoiding a separate communications cable while maintaining coordinated switching, dimming, and health reporting. */

        port operatorInterface: OperatorInterfacePort;

        part mainsPanel: MainsPanel;
        part controller: PlcBusMasterController;
        part lineCoupler: PlcLineCoupler;
        part powerLine: BuildingPowerLine;
        part lightingController: PlcLampModule;
        part hvacController: PlcHvacModule;
        part outletController: PlcOutletModule;
        part wallSwitch: PlcWallSwitch;

        attribute commandDeliveryLatency: Duration = 0.750 [s];
        attribute statusRefreshPeriod: Duration = 5 [s];
        attribute controllerAvailability: Availability = 0.998;
        attribute injectedSignalVoltage: Voltage = 5 [V];
        attribute maximumSupportedDevices: Integer = 64;
        attribute maximumControlledLoadPower: ActivePower = 2920 [W];
        attribute nominalSupplyVoltage: Voltage = 230 [V];
        attribute nominalSupplyFrequency: Frequency = 50 [Hz];

        connection operatorToController connect operatorInterface to controller.operatorInterface;
        connection mainsToCoupler connect mainsPanel.acOut to lineCoupler.mainsIn;
        connection controllerToCoupler connect controller.plcPort to lineCoupler.controllerBus;
        connection couplerToPowerLine connect lineCoupler.powerLinePort to powerLine.feed;
        connection lineToLightingModule connect powerLine.lightingBranch to lightingController.plcBus;
        connection lineToHvacModule connect powerLine.hvacBranch to hvacController.plcBus;
        connection lineToOutletModule connect powerLine.outletBranch to outletController.plcBus;
        connection lineToWallSwitch connect powerLine.switchBranch to wallSwitch.plcBus;

        perform action normalControlCycle: ExecuteControlCycle;
        exhibit state systemState: PlcBusSystemOperatingState;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The PLCBUS automation system shall use the building power-line conductors as the shared communication medium to issue commands and collect status for distributed loads. */
        subject system: PlcBusAutomationSystem;
        attribute maximumAllowedCommandDeliveryLatency: Duration = 1 [s];
        attribute minimumAllowedAvailability: Availability = 0.995;

        require constraint latencyRequirement {
            system.commandDeliveryLatency <= maximumAllowedCommandDeliveryLatency
        }

        require constraint availabilityRequirement {
            system.controllerAvailability >= minimumAllowedAvailability
        }
    }

    requirement def PowerLineCompatibilityRequirement {
        doc /* The PLCBUS communication signal shall be coupled onto the AC mains without exceeding the modeled safe injected signaling voltage. */
        subject system: PlcBusAutomationSystem;
        attribute maximumInjectedSignalVoltage: Voltage = 10 [V];

        require constraint signalVoltageLimit {
            system.injectedSignalVoltage <= maximumInjectedSignalVoltage
        }

        require constraint nominalVoltageCompatibility {
            system.nominalSupplyVoltage == 230 [V]
        }

        require constraint nominalFrequencyCompatibility {
            system.nominalSupplyFrequency == 50 [Hz]
        }
    }

    requirement def LoadControlCapacityRequirement {
        doc /* The system shall support multiple PLCBUS nodes and enough controlled load power for lighting, HVAC, outlet, and wall-switch functions. */
        subject system: PlcBusAutomationSystem;
        attribute minimumDeviceCapacity: Integer = 32;
        attribute minimumControlledLoadPower: ActivePower = 2500 [W];

        require constraint deviceCapacity {
            system.maximumSupportedDevices >= minimumDeviceCapacity
        }

        require constraint controlledLoadPower {
            system.maximumControlledLoadPower >= minimumControlledLoadPower
        }
    }

    part buildingPlcBusAutomationSystem: PlcBusAutomationSystem;

    requirement primaryFunction: PrimaryFunctionRequirement {
        subject system = buildingPlcBusAutomationSystem;
    }

    requirement powerLineCompatibility: PowerLineCompatibilityRequirement {
        subject system = buildingPlcBusAutomationSystem;
    }

    requirement loadControlCapacity: LoadControlCapacityRequirement {
        subject system = buildingPlcBusAutomationSystem;
    }

    satisfy primaryFunction by buildingPlcBusAutomationSystem;
    satisfy powerLineCompatibility by buildingPlcBusAutomationSystem;
    satisfy loadControlCapacity by buildingPlcBusAutomationSystem;
}
