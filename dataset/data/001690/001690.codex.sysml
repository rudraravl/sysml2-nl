package OneWireSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def ElectricPotential :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def ElectricCurrent :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Resistance :> ISQ::resistance {
        unit = SI::ohm;
    }

    attribute def Capacitance :> ISQ::capacitance {
        unit = SI::farad;
    }

    attribute def TimeDuration :> ISQ::time {
        unit = SI::second;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def DataRate {
        unit = "bit/s";
    }

    enum def BusLevel {
        enum low;
        enum high;
        enum released;
    }

    enum def OneWireCommandCode {
        enum reset;
        enum readRom;
        enum matchRom;
        enum skipRom;
        enum convertTemperature;
        enum readScratchpad;
        enum writeScratchpad;
    }

    item def OneWireBit {
        attribute value : Boolean;
        attribute slotDuration : TimeDuration;
    }

    item def OneWireByte {
        attribute value : Integer;
        attribute bitCount : Integer = 8;
    }

    item def RomCode {
        attribute familyCode : Integer;
        attribute serialNumber : Integer;
        attribute crc8 : Integer;
    }

    item def PresencePulse {
        attribute lowTime : TimeDuration;
        attribute detected : Boolean;
    }

    item def TemperatureSample {
        attribute sourceRom : RomCode;
        attribute measuredTemperature : Temperature;
        attribute conversionTime : TimeDuration;
        attribute validCrc : Boolean;
    }

    item def OneWireCommand {
        attribute code : OneWireCommandCode;
        attribute targetRom : RomCode;
    }

    port def OneWirePort {
        out item txBit : OneWireBit;
        in item rxBit : OneWireBit;
        in item presence : PresencePulse;
        attribute lineLevel : BusLevel;
        attribute lineVoltage : ElectricPotential;
    }

    port def PowerPort {
        in attribute supplyVoltage : ElectricPotential;
        in attribute supplyCurrent : ElectricCurrent;
    }

    port def ApplicationDataPort {
        out item sample : TemperatureSample;
        out item deviceIdentity : RomCode;
        in item request : OneWireCommand;
    }

    port def GroundPort {
        attribute referencePotential : ElectricPotential = 0 [SI::volt];
    }

    action def DriveResetPulse {
        inout port bus : OneWirePort;
        attribute resetLowTime : TimeDuration = 480e-6 [SI::second];
        attribute recoveryTime : TimeDuration = 70e-6 [SI::second];
        out item presence : PresencePulse;
    }

    action def WriteOneWireBit {
        in item bitToWrite : OneWireBit;
        inout port bus : OneWirePort;
        attribute writeZeroLowTime : TimeDuration = 60e-6 [SI::second];
        attribute writeOneLowTime : TimeDuration = 6e-6 [SI::second];
        attribute slotTime : TimeDuration = 70e-6 [SI::second];
    }

    action def ReadOneWireBit {
        inout port bus : OneWirePort;
        attribute sampleOffset : TimeDuration = 15e-6 [SI::second];
        attribute readSlotTime : TimeDuration = 70e-6 [SI::second];
        out item receivedBit : OneWireBit;
    }

    action def SendCommand {
        in item command : OneWireCommand;
        inout port bus : OneWirePort;
        out attribute completed : Boolean;
    }

    action def ReadTemperatureScratchpad {
        in item rom : RomCode;
        inout port bus : OneWirePort;
        out item sample : TemperatureSample;
    }

    action def PublishSample {
        in item sample : TemperatureSample;
        out port application : ApplicationDataPort;
    }

    state def OneWireMasterProtocol {
        inout port bus : OneWirePort;
        in port application : ApplicationDataPort;

        state idle;
        state resetBus;
        state waitForPresence;
        state selectDevice;
        state issueFunctionCommand;
        state waitForConversion;
        state readData;
        state validateData;
        state publishData;
        state fault;

        initial then idle;

        transition idle_to_reset
            first idle
            accept OneWireCommand
            then resetBus;

        transition reset_to_presence
            first resetBus
            do DriveResetPulse
            then waitForPresence;

        transition presence_to_select
            first waitForPresence
            if bus.presence.detected
            then selectDevice;

        transition presence_to_fault
            first waitForPresence
            if not bus.presence.detected
            then fault;

        transition select_to_command
            first selectDevice
            do SendCommand
            then issueFunctionCommand;

        transition command_to_conversion
            first issueFunctionCommand
            if application.request.code == OneWireCommandCode::convertTemperature
            then waitForConversion;

        transition command_to_read
            first issueFunctionCommand
            if application.request.code == OneWireCommandCode::readScratchpad
            then readData;

        transition conversion_to_read
            first waitForConversion
            after 750e-3 [SI::second]
            then readData;

        transition read_to_validate
            first readData
            do ReadTemperatureScratchpad
            then validateData;

        transition valid_to_publish
            first validateData
            if true
            then publishData;

        transition publish_to_idle
            first publishData
            do PublishSample
            then idle;

        transition fault_to_idle
            first fault
            after 1 [SI::second]
            then idle;
    }

    part def PullupResistor {
        attribute resistance : Resistance = 4700 [SI::ohm];
        attribute tolerancePercent : Real = 1.0;
        port busSide : OneWirePort;
        port supplySide : PowerPort;
    }

    part def OneWireBusLine {
        attribute nominalHighVoltage : ElectricPotential = 3.3 [SI::volt];
        attribute lowVoltageMaximum : ElectricPotential = 0.8 [SI::volt];
        attribute busCapacitance : Capacitance = 1.0e-9 [SI::farad];
        attribute maximumCableLength : Length = 30 [SI::metre];
        attribute standardDataRate : DataRate = 16300 ["bit/s"];
        port masterConnection : OneWirePort;
        port deviceConnection[1..64] : OneWirePort;
        port pullupConnection : OneWirePort;
    }

    part def OneWireMasterController {
        attribute resetPulseMinimum : TimeDuration = 480e-6 [SI::second];
        attribute presenceSampleTime : TimeDuration = 70e-6 [SI::second];
        attribute readSampleTime : TimeDuration = 15e-6 [SI::second];
        attribute maximumDevicesSupported : Integer = 64;
        port bus : OneWirePort;
        port power : PowerPort;
        port ground : GroundPort;
        port application : ApplicationDataPort;
        perform protocol : OneWireMasterProtocol;
    }

    part def OneWireTemperatureSensor {
        attribute rom : RomCode;
        attribute temperatureResolutionBits : Integer = 12;
        attribute conversionTimeMax : TimeDuration = 750e-3 [SI::second];
        attribute measurementAccuracy : Temperature = 0.5 [SI::kelvin];
        attribute parasitePowerCapable : Boolean = true;
        port bus : OneWirePort;
        port ground : GroundPort;
        port optionalPower : PowerPort;
    }

    part def HostApplication {
        attribute pollingPeriod : TimeDuration = 5 [SI::second];
        port oneWireData : ApplicationDataPort;
    }

    part def RegulatedSupply {
        attribute outputVoltage : ElectricPotential = 3.3 [SI::volt];
        attribute currentCapacity : ElectricCurrent = 0.1 [SI::ampere];
        port output : PowerPort;
        port ground : GroundPort;
    }

    part def SystemGround {
        port reference : GroundPort;
    }

    part def OneWireMonitoringSystem {
        doc /* The primary function of this system is to use a single shared 1-Wire data conductor, referenced to ground and held high by a pull-up, to discover uniquely addressed devices, command temperature conversion, read returned digital measurements, validate the data, and publish high-level temperature samples to a host application. */

        part supply : RegulatedSupply;
        part ground : SystemGround;
        part pullup : PullupResistor;
        part bus : OneWireBusLine;
        part master : OneWireMasterController;
        part host : HostApplication;
        part sensorA : OneWireTemperatureSensor {
            attribute rom.familyCode = 40;
            attribute rom.serialNumber = 1000001;
            attribute rom.crc8 = 91;
        }
        part sensorB : OneWireTemperatureSensor {
            attribute rom.familyCode = 40;
            attribute rom.serialNumber = 1000002;
            attribute rom.crc8 = 172;
        }

        connect supply.output to master.power;
        connect supply.output to pullup.supplySide;
        connect supply.output to sensorA.optionalPower;
        connect supply.output to sensorB.optionalPower;

        connect ground.reference to supply.ground;
        connect ground.reference to master.ground;
        connect ground.reference to sensorA.ground;
        connect ground.reference to sensorB.ground;

        connect master.bus to bus.masterConnection;
        connect sensorA.bus to bus.deviceConnection;
        connect sensorB.bus to bus.deviceConnection;
        connect pullup.busSide to bus.pullupConnection;

        connect master.application to host.oneWireData;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide digital monitoring over a 1-Wire bus by controlling bus timing, addressing devices by ROM code, requesting measurement conversion, reading device data, validating received values, and delivering temperature samples to the host application. */
        subject system : OneWireMonitoringSystem;
        require constraint {
            system.master.maximumDevicesSupported >= 2
        }
    }

    requirement def SingleDataConductorRequirement {
        doc /* The system shall communicate with all connected 1-Wire devices using one shared bidirectional data conductor and a common ground reference. */
        subject system : OneWireMonitoringSystem;
        require constraint {
            system.bus.deviceConnection->size() >= 1
        }
    }

    requirement def PullupRequirement {
        doc /* The 1-Wire bus shall be passively pulled to the regulated high level so that devices and the master can signal by pulling the line low. */
        subject system : OneWireMonitoringSystem;
        require constraint {
            system.pullup.resistance >= 1000 [SI::ohm] and
            system.pullup.resistance <= 10000 [SI::ohm]
        }
    }

    requirement def TimingRequirement {
        doc /* The master shall generate reset and bit time slots compatible with standard-speed 1-Wire communication. */
        subject master : OneWireMasterController;
        require constraint {
            master.resetPulseMinimum >= 480e-6 [SI::second] and
            master.readSampleTime >= 10e-6 [SI::second] and
            master.readSampleTime <= 20e-6 [SI::second]
        }
    }

    requirement def IdentificationRequirement {
        doc /* Each 1-Wire device shall provide a ROM code that enables the master to identify and select the device on the shared bus. */
        subject sensor : OneWireTemperatureSensor;
        require constraint {
            sensor.rom.familyCode > 0 and
            sensor.rom.serialNumber > 0
        }
    }

    requirement def MeasurementPublicationRequirement {
        doc /* The system shall publish only temperature samples associated with a source ROM code and a successful CRC validation result. */
        subject sample : TemperatureSample;
        require constraint {
            sample.validCrc == true
        }
    }

    satisfy PrimaryFunctionRequirement by OneWireMonitoringSystem;
    satisfy SingleDataConductorRequirement by OneWireMonitoringSystem;
    satisfy PullupRequirement by OneWireMonitoringSystem;
    satisfy TimingRequirement by OneWireMasterController;
    satisfy IdentificationRequirement by OneWireTemperatureSensor;
    satisfy MeasurementPublicationRequirement by TemperatureSample;
}