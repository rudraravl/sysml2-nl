package CBusBuildingControlSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;
    import USCustomaryUnits::*;

    attribute def Voltage {
        :> ISQ::voltage;
        unit = SI::volt;
    }

    attribute def Current {
        :> ISQ::electricCurrent;
        unit = SI::ampere;
    }

    attribute def Power {
        :> ISQ::power;
        unit = SI::watt;
    }

    attribute def Energy {
        :> ISQ::energy;
        unit = SI::joule;
    }

    attribute def Temperature {
        :> ISQ::thermodynamicTemperature;
        unit = SI::degreeCelsius;
    }

    attribute def Illuminance {
        unit = SI::lux;
    }

    attribute def Percent {
        unit = SI::percent;
    }

    attribute def TimeDuration {
        :> ISQ::time;
        unit = SI::second;
    }

    attribute def DataRate {
        unit = SI::bit / SI::second;
    }

    attribute def Address {
        :> ScalarValues::Integer;
    }

    attribute def GroupAddress {
        :> Address;
    }

    attribute def NetworkAddress {
        :> Address;
    }

    attribute def CBusApplicationId {
        :> Address;
    }

    enum def CBusMessageKind {
        enum command;
        enum status;
        enum ramp;
        enum measurement;
        enum scene;
        enum clock;
        enum diagnostic;
        enum acknowledge;
    }

    enum def OccupancyState {
        enum vacant;
        enum occupied;
        enum unknown;
    }

    enum def BusHealth {
        enum nominal;
        enum degraded;
        enum failed;
    }

    item def CBusFrame {
        attribute networkAddress : NetworkAddress;
        attribute applicationId : CBusApplicationId;
        attribute groupAddress : GroupAddress;
        attribute kind : CBusMessageKind;
        attribute level : Percent;
        attribute checksumValid : Boolean;
        attribute timestamp : TimeDuration;
    }

    item def LightingCommand {
        attribute groupAddress : GroupAddress;
        attribute targetLevel : Percent;
        attribute rampTime : TimeDuration;
        attribute originator : NetworkAddress;
    }

    item def RelayCommand {
        attribute groupAddress : GroupAddress;
        attribute closed : Boolean;
        attribute originator : NetworkAddress;
    }

    item def MeasurementReport {
        attribute sourceAddress : NetworkAddress;
        attribute illuminance : Illuminance;
        attribute temperature : Temperature;
        attribute occupancy : OccupancyState;
        attribute busVoltage : Voltage;
    }

    item def DiagnosticReport {
        attribute sourceAddress : NetworkAddress;
        attribute health : BusHealth;
        attribute busVoltage : Voltage;
        attribute busCurrent : Current;
        attribute errorCount : Integer;
    }

    port def CBusPort {
        in item rxFrame : CBusFrame;
        out item txFrame : CBusFrame;
        attribute nominalVoltage : Voltage = 36 [SI::volt];
        attribute maxSegmentCurrent : Current = 2 [SI::ampere];
        attribute dataRate : DataRate = 3500 [SI::bit / SI::second];
    }

    port def LoadPowerPort {
        in attribute supplyVoltage : Voltage;
        in attribute availableCurrent : Current;
        out attribute consumedPower : Power;
    }

    port def SensorPort {
        out item measurement : MeasurementReport;
    }

    port def UserInputPort {
        out item lightingCommand : LightingCommand;
        out item relayCommand : RelayCommand;
    }

    port def EthernetPort {
        in item inboundFrame : CBusFrame;
        out item outboundFrame : CBusFrame;
        attribute dataRate : DataRate = 100000000 [SI::bit / SI::second];
    }

    part def CBusTwistedPairSegment {
        attribute segmentAddress : NetworkAddress;
        attribute busVoltage : Voltage = 36 [SI::volt];
        attribute busCurrent : Current;
        attribute maximumCableLength : Length = 1000 [SI::metre];
        attribute connectedUnitCount : Integer;
        attribute health : BusHealth;

        port nodePort[0..255] : CBusPort;
    }

    part def CBusPowerSupply {
        attribute outputVoltage : Voltage = 36 [SI::volt];
        attribute ratedCurrent : Current = 2 [SI::ampere];
        attribute inputVoltage : Voltage = 230 [SI::volt];
        attribute healthy : Boolean;

        port bus : CBusPort;

        action provideBusPower {
            in attribute mainsVoltage : Voltage;
            out attribute regulatedBusVoltage : Voltage;
            out attribute availableBusCurrent : Current;

            first start;
            then regulateVoltage;
            then monitorOverload;
            then done;

            action regulateVoltage {
                in attribute mainsVoltage : Voltage;
                out attribute regulatedBusVoltage : Voltage;
            }

            action monitorOverload {
                in attribute availableBusCurrent : Current;
                out attribute overloadDetected : Boolean;
            }
        }
    }

    part def CBusInputUnit {
        attribute unitAddress : NetworkAddress;
        attribute applicationId : CBusApplicationId = 56;
        attribute associatedLightingGroup : GroupAddress;
        attribute associatedRelayGroup : GroupAddress;
        attribute localLedLevel : Percent;

        port bus : CBusPort;
        port user : UserInputPort;

        action translateUserInputToBusCommand {
            in item requestedLightingCommand : LightingCommand;
            in item requestedRelayCommand : RelayCommand;
            out item generatedFrame : CBusFrame;
        }

        state def InputUnitState {
            entry action initialize;
            state idle;
            state buttonPressed;
            state transmitting;
            state awaitingAcknowledge;
            state fault;

            transition first idle;
            transition idle_to_buttonPressed
                first idle
                accept event buttonActivation
                then buttonPressed;

            transition buttonPressed_to_transmitting
                first buttonPressed
                do action translateUserInputToBusCommand
                then transmitting;

            transition transmitting_to_awaitingAcknowledge
                first transmitting
                then awaitingAcknowledge;

            transition acknowledged
                first awaitingAcknowledge
                accept item CBusFrame
                if rxFrame.kind == CBusMessageKind::acknowledge
                then idle;

            transition timeout
                first awaitingAcknowledge
                after 2 [SI::second]
                then fault;

            transition reset
                first fault
                accept event resetCommand
                then idle;
        }
    }

    part def CBusDimmerOutputUnit {
        attribute unitAddress : NetworkAddress;
        attribute controlledGroup : GroupAddress;
        attribute channelCount : Integer = 4;
        attribute channelLevel[4] : Percent;
        attribute maximumChannelPower : Power = 500 [SI::watt];
        attribute thermalLimit : Temperature = 75 [SI::degreeCelsius];
        attribute internalTemperature : Temperature;

        port bus : CBusPort;
        port loadPower[4] : LoadPowerPort;

        action processLightingFrame {
            in item commandFrame : CBusFrame;
            out attribute accepted : Boolean;
            out attribute targetLevel : Percent;
        }

        action rampChannel {
            in attribute targetLevel : Percent;
            in attribute rampTime : TimeDuration;
            out attribute finalLevel : Percent;
        }

        state def DimmerState {
            state off;
            state rampingUp;
            state on;
            state rampingDown;
            state thermalProtection;
            state communicationFault;

            transition first off;

            transition commandOn
                first off
                accept item CBusFrame
                if rxFrame.groupAddress == controlledGroup and rxFrame.level > 0 [%]
                do action processLightingFrame
                then rampingUp;

            transition rampCompleteOn
                first rampingUp
                after 3 [SI::second]
                then on;

            transition commandDim
                first on
                accept item CBusFrame
                if rxFrame.groupAddress == controlledGroup and rxFrame.level > 0 [%]
                do action rampChannel
                then on;

            transition commandOff
                first on
                accept item CBusFrame
                if rxFrame.groupAddress == controlledGroup and rxFrame.level == 0 [%]
                do action rampChannel
                then rampingDown;

            transition rampCompleteOff
                first rampingDown
                after 3 [SI::second]
                then off;

            transition overTemperature
                first on
                if internalTemperature > thermalLimit
                then thermalProtection;

            transition coolDown
                first thermalProtection
                if internalTemperature < 60 [SI::degreeCelsius]
                then off;

            transition busTimeout
                first on
                after 120 [SI::second]
                then communicationFault;
        }
    }

    part def CBusRelayOutputUnit {
        attribute unitAddress : NetworkAddress;
        attribute controlledGroup : GroupAddress;
        attribute channelCount : Integer = 8;
        attribute contactClosed[8] : Boolean;
        attribute maximumSwitchedPower : Power = 2400 [SI::watt];

        port bus : CBusPort;
        port loadPower[8] : LoadPowerPort;

        action switchRelay {
            in item commandFrame : CBusFrame;
            out attribute relayClosed : Boolean;
        }

        state def RelayState {
            state allOpen;
            state switching;
            state energized;
            state contactFault;

            transition first allOpen;

            transition closeContact
                first allOpen
                accept item CBusFrame
                if rxFrame.groupAddress == controlledGroup and rxFrame.level > 0 [%]
                do action switchRelay
                then switching;

            transition closed
                first switching
                after 100 [SI::millisecond]
                then energized;

            transition openContact
                first energized
                accept item CBusFrame
                if rxFrame.groupAddress == controlledGroup and rxFrame.level == 0 [%]
                do action switchRelay
                then allOpen;

            transition faultDetected
                first switching
                if contactClosed[1] == false and rxFrame.level > 0 [%]
                then contactFault;
        }
    }

    part def OccupancyAndLightSensor {
        attribute unitAddress : NetworkAddress;
        attribute reportedGroup : GroupAddress;
        attribute measuredIlluminance : Illuminance;
        attribute measuredTemperature : Temperature;
        attribute occupancy : OccupancyState;
        attribute reportPeriod : TimeDuration = 30 [SI::second];

        port bus : CBusPort;
        port sensor : SensorPort;

        action sampleEnvironment {
            out attribute illuminance : Illuminance;
            out attribute temperature : Temperature;
            out attribute occupancyState : OccupancyState;
        }

        action publishMeasurement {
            in attribute illuminance : Illuminance;
            in attribute temperature : Temperature;
            in attribute occupancyState : OccupancyState;
            out item reportFrame : CBusFrame;
        }

        state def SensorState {
            state initializing;
            state monitoring;
            state reporting;
            state sensorFault;

            transition first initializing;

            transition initialized
                first initializing
                after 1 [SI::second]
                then monitoring;

            transition periodicSample
                first monitoring
                after reportPeriod
                do action sampleEnvironment
                then reporting;

            transition reportSent
                first reporting
                do action publishMeasurement
                then monitoring;

            transition invalidReading
                first monitoring
                if measuredIlluminance < 0 [SI::lux]
                then sensorFault;
        }
    }

    part def CBusNetworkInterface {
        attribute unitAddress : NetworkAddress;
        attribute ipAddressOctet1 : Integer = 192;
        attribute ipAddressOctet2 : Integer = 168;
        attribute ipAddressOctet3 : Integer = 10;
        attribute ipAddressOctet4 : Integer = 20;
        attribute authenticated : Boolean;

        port bus : CBusPort;
        port ethernet : EthernetPort;

        action bridgeEthernetToCBus {
            in item inboundFrame : CBusFrame;
            out item busFrame : CBusFrame;
        }

        action bridgeCBusToEthernet {
            in item busFrame : CBusFrame;
            out item outboundFrame : CBusFrame;
        }
    }

    part def SceneController {
        attribute controllerAddress : NetworkAddress;
        attribute sceneGroup : GroupAddress;
        attribute eveningLightingLevel : Percent = 45 [%];
        attribute cleaningLightingLevel : Percent = 100 [%];
        attribute unoccupiedLightingLevel : Percent = 0 [%];
        attribute targetIlluminance : Illuminance = 350 [SI::lux];

        port bus : CBusPort;

        action evaluateScene {
            in item measurement : MeasurementReport;
            out item sceneCommand : CBusFrame;
        }

        action issueHighLevelControl {
            in attribute occupancy : OccupancyState;
            in attribute illuminance : Illuminance;
            out item lightingFrame : CBusFrame;
            out item relayFrame : CBusFrame;
        }

        state def ControlMode {
            state normalOccupied;
            state daylightHoldOff;
            state afterHoursVacant;
            state cleaningOverride;
            state emergencyOn;

            transition first afterHoursVacant;

            transition occupiedLowLight
                first afterHoursVacant
                accept item MeasurementReport
                if measurement.occupancy == OccupancyState::occupied and measurement.illuminance < targetIlluminance
                do action issueHighLevelControl
                then normalOccupied;

            transition daylightAdequate
                first normalOccupied
                accept item MeasurementReport
                if measurement.illuminance >= targetIlluminance
                do action issueHighLevelControl
                then daylightHoldOff;

            transition daylightFaded
                first daylightHoldOff
                accept item MeasurementReport
                if measurement.illuminance < targetIlluminance
                do action issueHighLevelControl
                then normalOccupied;

            transition vacancy
                first normalOccupied
                accept item MeasurementReport
                if measurement.occupancy == OccupancyState::vacant
                after 600 [SI::second]
                do action issueHighLevelControl
                then afterHoursVacant;

            transition cleaningRequest
                first afterHoursVacant
                accept event cleaningModeEnabled
                then cleaningOverride;

            transition cleaningComplete
                first cleaningOverride
                accept event cleaningModeDisabled
                then afterHoursVacant;

            transition emergencySignal
                first normalOccupied
                accept event emergencyLightingRequest
                then emergencyOn;
        }
    }

    part def DiagnosticMonitor {
        attribute pollingPeriod : TimeDuration = 60 [SI::second];
        attribute lastBusVoltage : Voltage;
        attribute lastBusCurrent : Current;
        attribute communicationErrorCount : Integer;
        attribute networkHealth : BusHealth;

        port bus : CBusPort;

        action pollNetworkHealth {
            out item diagnosticRequest : CBusFrame;
        }

        action classifyHealth {
            in attribute busVoltage : Voltage;
            in attribute errorCount : Integer;
            out attribute health : BusHealth;
        }

        state def MonitorState {
            state starting;
            state observing;
            state degraded;
            state failed;

            transition first starting;

            transition ready
                first starting
                after 5 [SI::second]
                then observing;

            transition poll
                first observing
                after pollingPeriod
                do action pollNetworkHealth
                then observing;

            transition degradedDetected
                first observing
                if lastBusVoltage < 30 [SI::volt] or communicationErrorCount > 10
                do action classifyHealth
                then degraded;

            transition failedDetected
                first degraded
                if lastBusVoltage < 20 [SI::volt] or communicationErrorCount > 100
                do action classifyHealth
                then failed;

            transition recovered
                first degraded
                if lastBusVoltage >= 32 [SI::volt] and communicationErrorCount <= 10
                then observing;
        }
    }

    part def ControlledLightingLoad {
        attribute ratedPower : Power;
        attribute actualPower : Power;
        attribute brightness : Percent;
        attribute energized : Boolean;

        port power : LoadPowerPort;
    }

    part def ControlledAuxiliaryLoad {
        attribute ratedPower : Power;
        attribute actualPower : Power;
        attribute energized : Boolean;

        port power : LoadPowerPort;
    }

    part def CBusBasedBuildingAutomationSystem {
        doc /* Primary function: provide distributed, addressable, high-level control of building lighting and auxiliary electrical loads over a C-Bus network by translating user inputs, sensor measurements, schedules, and scene logic into coordinated bus commands while monitoring network health. */

        attribute systemNominalBusVoltage : Voltage = 36 [SI::volt];
        attribute maximumNetworkCurrent : Current = 2 [SI::ampere];
        attribute installedLightingCapacity : Power = 6200 [SI::watt];
        attribute installedAuxiliaryCapacity : Power = 4800 [SI::watt];
        attribute targetOfficeIlluminance : Illuminance = 350 [SI::lux];
        attribute energyUsedToday : Energy;

        part busSegment : CBusTwistedPairSegment {
            attribute segmentAddress = 1;
            attribute connectedUnitCount = 9;
        }

        part powerSupply : CBusPowerSupply;
        part wallSwitch : CBusInputUnit {
            attribute unitAddress = 11;
            attribute associatedLightingGroup = 101;
            attribute associatedRelayGroup = 201;
        }

        part dimmer : CBusDimmerOutputUnit {
            attribute unitAddress = 21;
            attribute controlledGroup = 101;
        }

        part relay : CBusRelayOutputUnit {
            attribute unitAddress = 31;
            attribute controlledGroup = 201;
        }

        part sensor : OccupancyAndLightSensor {
            attribute unitAddress = 41;
            attribute reportedGroup = 301;
        }

        part sceneController : SceneController {
            attribute controllerAddress = 51;
            attribute sceneGroup = 401;
            attribute targetIlluminance = 350 [SI::lux];
        }

        part networkInterface : CBusNetworkInterface {
            attribute unitAddress = 61;
        }

        part diagnosticMonitor : DiagnosticMonitor;

        part officeLights[4] : ControlledLightingLoad {
            attribute ratedPower = 120 [SI::watt];
        }

        part corridorLights[4] : ControlledLightingLoad {
            attribute ratedPower = 80 [SI::watt];
        }

        part exhaustFan : ControlledAuxiliaryLoad {
            attribute ratedPower = 750 [SI::watt];
        }

        part signageCircuit : ControlledAuxiliaryLoad {
            attribute ratedPower = 450 [SI::watt];
        }

        connect powerSupply.bus to busSegment.nodePort;
        connect wallSwitch.bus to busSegment.nodePort;
        connect dimmer.bus to busSegment.nodePort;
        connect relay.bus to busSegment.nodePort;
        connect sensor.bus to busSegment.nodePort;
        connect sceneController.bus to busSegment.nodePort;
        connect networkInterface.bus to busSegment.nodePort;
        connect diagnosticMonitor.bus to busSegment.nodePort;

        connect dimmer.loadPower[1] to officeLights[1].power;
        connect dimmer.loadPower[2] to officeLights[2].power;
        connect dimmer.loadPower[3] to corridorLights[1].power;
        connect dimmer.loadPower[4] to corridorLights[2].power;

        connect relay.loadPower[1] to corridorLights[3].power;
        connect relay.loadPower[2] to corridorLights[4].power;
        connect relay.loadPower[3] to exhaustFan.power;
        connect relay.loadPower[4] to signageCircuit.power;

        action performPrimaryControlFunction {
            in item userLightingCommand : LightingCommand;
            in item userRelayCommand : RelayCommand;
            in item environmentReport : MeasurementReport;
            out item lightingBusFrame : CBusFrame;
            out item relayBusFrame : CBusFrame;
            out item diagnosticFrame : CBusFrame;

            first receiveInputs;
            then determineRequestedScene;
            then transmitCBusCommands;
            then actuateLoads;
            then reportStatus;

            action receiveInputs {
                in item userLightingCommand : LightingCommand;
                in item environmentReport : MeasurementReport;
                out attribute occupied : Boolean;
                out attribute availableDaylight : Illuminance;
            }

            action determineRequestedScene {
                in attribute occupied : Boolean;
                in attribute availableDaylight : Illuminance;
                out attribute selectedLightingLevel : Percent;
                out attribute auxiliaryEnabled : Boolean;
            }

            action transmitCBusCommands {
                in attribute selectedLightingLevel : Percent;
                in attribute auxiliaryEnabled : Boolean;
                out item lightingBusFrame : CBusFrame;
                out item relayBusFrame : CBusFrame;
            }

            action actuateLoads {
                in item lightingBusFrame : CBusFrame;
                in item relayBusFrame : CBusFrame;
                out attribute deliveredLightingPower : Power;
                out attribute deliveredAuxiliaryPower : Power;
            }

            action reportStatus {
                in attribute deliveredLightingPower : Power;
                in attribute deliveredAuxiliaryPower : Power;
                out item diagnosticFrame : CBusFrame;
            }
        }
    }

    requirement def DistributedControlRequirement {
        doc /* The system shall control lighting and auxiliary loads using distributed C-Bus messages rather than direct point-to-point control wiring. */
    }

    requirement def AddressableGroupRequirement {
        doc /* Each controlled load channel shall respond only to C-Bus frames whose group address matches its configured group address. */
    }

    requirement def OccupancyEnergyRequirement {
        doc /* When an area is vacant for at least 600 seconds, the system shall command associated lighting groups to 0 percent output unless an override or emergency mode is active. */
    }

    requirement def DaylightHarvestingRequirement {
        doc /* When occupancy is detected and measured illuminance is at or above 350 lux, the system shall reduce dimmable lighting output to avoid unnecessary energy use. */
    }

    requirement def ManualOverrideRequirement {
        doc /* A user input unit shall be able to issue a manual C-Bus lighting command within 2 seconds of button activation. */
    }

    requirement def BusPowerRequirement {
        doc /* The C-Bus power supply shall maintain the bus voltage between 30 volts and 38 volts during normal operation. */
    }

    requirement def DiagnosticRequirement {
        doc /* The system shall classify the bus as degraded when bus voltage is below 30 volts or when more than 10 communication errors are detected in one diagnostic period. */
    }

    requirement def NetworkInterfaceRequirement {
        doc /* The network interface shall bridge authenticated Ethernet control frames to equivalent C-Bus frames without changing the C-Bus application identifier or group address. */
    }

    satisfy DistributedControlRequirement by CBusBasedBuildingAutomationSystem;
    satisfy AddressableGroupRequirement by CBusDimmerOutputUnit;
    satisfy AddressableGroupRequirement by CBusRelayOutputUnit;
    satisfy OccupancyEnergyRequirement by SceneController;
    satisfy DaylightHarvestingRequirement by SceneController;
    satisfy ManualOverrideRequirement by CBusInputUnit;
    satisfy BusPowerRequirement by CBusPowerSupply;
    satisfy DiagnosticRequirement by DiagnosticMonitor;
    satisfy NetworkInterfaceRequirement by CBusNetworkInterface;

    concern def PrimaryFunctionConcern {
        doc /* High-level purpose, scope, load control behavior, and C-Bus based network coordination. */
    }

    viewpoint def BuildingOperatorViewpoint {
        concern PrimaryFunctionConcern;
        language "SysML v2 textual notation";
        method "Describe the system as distributed C-Bus units, their connections, their behaviors, and the requirements governing high-level building control.";
    }

    view def BuildingOperatorView {
        viewpoint BuildingOperatorViewpoint;
        expose CBusBasedBuildingAutomationSystem;
        expose CBusTwistedPairSegment;
        expose CBusInputUnit;
        expose CBusDimmerOutputUnit;
        expose CBusRelayOutputUnit;
        expose OccupancyAndLightSensor;
        expose SceneController;
        expose DiagnosticMonitor;
        expose DistributedControlRequirement;
        expose OccupancyEnergyRequirement;
        expose DaylightHarvestingRequirement;
    }
}