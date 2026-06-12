package ESP32_IoT_Controller_Model {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Power :> ISQ::power {
        unit = SI::watt;
    }

    attribute def Frequency :> ISQ::frequency {
        unit = SI::hertz;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::degreeCelsius;
    }

    attribute def DataRate {
        unit = SI::bit / SI::second;
    }

    attribute def MemorySize {
        unit = SI::byte;
    }

    attribute def Percentage {
        unit = SI::percent;
    }

    attribute def TimeDuration :> ISQ::time {
        unit = SI::second;
    }

    item def DigitalSignal {
        attribute logicLevel : Integer;
        attribute timestamp : TimeDuration;
    }

    item def AnalogSignal {
        attribute voltage : Voltage;
        attribute timestamp : TimeDuration;
    }

    item def PowerSupply {
        attribute voltage : Voltage;
        attribute maxCurrent : Current;
        attribute ripple : Voltage;
    }

    item def WiFiFrame {
        attribute payloadBytes : MemorySize;
        attribute dataRate : DataRate;
        attribute rssi : Integer;
    }

    item def BluetoothPacket {
        attribute payloadBytes : MemorySize;
        attribute channel : Integer;
    }

    item def SensorSample {
        attribute temperature : Temperature;
        attribute humidity : Percentage;
        attribute batteryVoltage : Voltage;
        attribute sampleTime : TimeDuration;
    }

    item def TelemetryMessage {
        attribute deviceId : String;
        attribute temperature : Temperature;
        attribute humidity : Percentage;
        attribute batteryVoltage : Voltage;
        attribute uptime : TimeDuration;
    }

    item def ControlCommand {
        attribute targetOutput : String;
        attribute requestedState : Boolean;
        attribute commandTime : TimeDuration;
    }

    port def PowerInputPort {
        in item supply : PowerSupply;
    }

    port def GroundPort {
        inout item reference : DigitalSignal;
    }

    port def DigitalGPIOPort {
        inout item signal : DigitalSignal;
    }

    port def AnalogInputPort {
        in item signal : AnalogSignal;
    }

    port def I2CPort {
        out item scl : DigitalSignal;
        inout item sda : DigitalSignal;
    }

    port def UARTPort {
        out item tx : DigitalSignal;
        in item rx : DigitalSignal;
    }

    port def SPIPort {
        out item sclk : DigitalSignal;
        out item mosi : DigitalSignal;
        in item miso : DigitalSignal;
        out item cs : DigitalSignal;
    }

    port def WiFiPort {
        out item transmittedFrame : WiFiFrame;
        in item receivedFrame : WiFiFrame;
    }

    port def BluetoothPort {
        out item transmittedPacket : BluetoothPacket;
        in item receivedPacket : BluetoothPacket;
    }

    port def TelemetryPort {
        out item telemetry : TelemetryMessage;
        in item command : ControlCommand;
    }

    part def ESP32Module {
        attribute supplyVoltage : Voltage = 3.3 [SI::volt];
        attribute activeCurrent : Current = 0.24 [SI::ampere];
        attribute deepSleepCurrent : Current = 0.00001 [SI::ampere];
        attribute cpuClock : Frequency = 240 [SI::mega * SI::hertz];
        attribute flashMemory : MemorySize = 4 [SI::mega * SI::byte];
        attribute sramMemory : MemorySize = 520 [SI::kilo * SI::byte];
        attribute wifiSupported : Boolean = true;
        attribute bluetoothSupported : Boolean = true;

        port power : PowerInputPort;
        port ground : GroundPort;
        port gpio0 : DigitalGPIOPort;
        port gpio2 : DigitalGPIOPort;
        port gpio4 : DigitalGPIOPort;
        port gpio5 : DigitalGPIOPort;
        port gpio12 : DigitalGPIOPort;
        port gpio13 : DigitalGPIOPort;
        port gpio14 : DigitalGPIOPort;
        port gpio15 : DigitalGPIOPort;
        port gpio18 : DigitalGPIOPort;
        port gpio19 : DigitalGPIOPort;
        port gpio21 : DigitalGPIOPort;
        port gpio22 : DigitalGPIOPort;
        port gpio23 : DigitalGPIOPort;
        port adc34 : AnalogInputPort;
        port adc35 : AnalogInputPort;
        port i2c0 : I2CPort;
        port uart0 : UARTPort;
        port spi2 : SPIPort;
        port wifiRadio : WiFiPort;
        port bluetoothRadio : BluetoothPort;
        port applicationInterface : TelemetryPort;

        part dualCoreProcessor {
            attribute coreCount : Integer = 2;
            attribute nominalFrequency : Frequency = 240 [SI::mega * SI::hertz];
            attribute instructionSet : String = "Xtensa LX6";
        }

        part radioSubsystem {
            attribute wifiFrequency : Frequency = 2.4 [SI::giga * SI::hertz];
            attribute bluetoothFrequency : Frequency = 2.4 [SI::giga * SI::hertz];
            attribute maxWiFiDataRate : DataRate = 150 [SI::mega * SI::bit / SI::second];
        }

        part memorySubsystem {
            attribute romSize : MemorySize = 448 [SI::kilo * SI::byte];
            attribute sramSize : MemorySize = 520 [SI::kilo * SI::byte];
            attribute externalFlashSize : MemorySize = 4 [SI::mega * SI::byte];
        }
    }

    part def TemperatureHumiditySensor {
        attribute operatingVoltage : Voltage = 3.3 [SI::volt];
        attribute measurementPeriod : TimeDuration = 2 [SI::second];
        attribute temperatureAccuracy : Temperature = 0.5 [SI::degreeCelsius];
        attribute humidityAccuracy : Percentage = 2 [SI::percent];

        port power : PowerInputPort;
        port ground : GroundPort;
        port bus : I2CPort;

        out item measuredSample : SensorSample;
    }

    part def StatusLED {
        attribute forwardVoltage : Voltage = 2.0 [SI::volt];
        attribute nominalCurrent : Current = 0.01 [SI::ampere];

        port anode : DigitalGPIOPort;
        port cathode : GroundPort;
    }

    part def RelayDriver {
        attribute coilVoltage : Voltage = 5.0 [SI::volt];
        attribute switchedCurrentLimit : Current = 2.0 [SI::ampere];

        port controlInput : DigitalGPIOPort;
        port power : PowerInputPort;
        port ground : GroundPort;
        port switchedOutput : DigitalGPIOPort;
    }

    part def VoltageRegulator {
        attribute inputVoltageMin : Voltage = 4.5 [SI::volt];
        attribute inputVoltageMax : Voltage = 12.0 [SI::volt];
        attribute outputVoltage : Voltage = 3.3 [SI::volt];
        attribute outputCurrentLimit : Current = 0.8 [SI::ampere];
        attribute efficiency : Percentage = 88 [SI::percent];

        port inputPower : PowerInputPort;
        port regulatedOutput : PowerInputPort;
        port ground : GroundPort;
    }

    part def BatteryMonitor {
        attribute dividerRatio : Real = 0.25;
        attribute maxMeasuredVoltage : Voltage = 12.0 [SI::volt];

        port batterySense : AnalogInputPort;
        port adcOutput : AnalogInputPort;
        port ground : GroundPort;
    }

    part def CloudService {
        attribute endpoint : String = "mqtts://telemetry.example.net";
        attribute publishTopic : String = "devices/esp32/telemetry";
        attribute commandTopic : String = "devices/esp32/commands";

        port network : TelemetryPort;
    }

    action def BootFirmware {
        in item powerInput : PowerSupply;
        out bootComplete : Boolean;

        first start;
        then initializeClock;
        then initializeMemory;
        then configureGPIO;
        then loadNetworkCredentials;
        then bootComplete = true;
    }

    action def ReadSensors {
        in item rawSensorSample : SensorSample;
        out item filteredSample : SensorSample;

        first acquire;
        then validateRange;
        then filterNoise;
        then filteredSample = rawSensorSample;
    }

    action def BuildTelemetry {
        in item sample : SensorSample;
        in deviceId : String;
        in uptime : TimeDuration;
        out item message : TelemetryMessage;

        first copySensorValues;
        then assignDeviceIdentity;
        then assignUptime;
        then message.deviceId = deviceId;
        then message.temperature = sample.temperature;
        then message.humidity = sample.humidity;
        then message.batteryVoltage = sample.batteryVoltage;
        then message.uptime = uptime;
    }

    action def PublishTelemetry {
        in item message : TelemetryMessage;
        out transmissionAccepted : Boolean;

        first serializeJson;
        then encryptTransport;
        then transmitOverWiFi;
        then waitForAcknowledgement;
        then transmissionAccepted = true;
    }

    action def ApplyCommand {
        in item command : ControlCommand;
        out outputState : Boolean;

        first parseCommand;
        then verifyCommandTarget;
        then updateGPIO;
        then outputState = command.requestedState;
    }

    state def ESP32ApplicationStateMachine {
        entry action BootFirmware;

        state PowerOff;
        state Booting;
        state ConnectingToNetwork;
        state SamplingSensors;
        state PublishingTelemetry;
        state AwaitingCommand;
        state ExecutingCommand;
        state Fault;
        state DeepSleep;

        transition initial then PowerOff;

        transition PowerOff_to_Booting
            first PowerOff
            accept item supply : PowerSupply
            if supply.voltage >= 3.0 [SI::volt]
            then Booting;

        transition Booting_to_Connecting
            first Booting
            accept bootComplete : Boolean
            if bootComplete == true
            then ConnectingToNetwork;

        transition Connecting_to_Sampling
            first ConnectingToNetwork
            accept networkReady : Boolean
            if networkReady == true
            then SamplingSensors;

        transition Connecting_to_Fault
            first ConnectingToNetwork
            accept networkReady : Boolean
            if networkReady == false
            then Fault;

        transition Sampling_to_Publishing
            first SamplingSensors
            accept item sample : SensorSample
            then PublishingTelemetry;

        transition Publishing_to_Awaiting
            first PublishingTelemetry
            accept transmissionAccepted : Boolean
            if transmissionAccepted == true
            then AwaitingCommand;

        transition Awaiting_to_Executing
            first AwaitingCommand
            accept item command : ControlCommand
            then ExecutingCommand;

        transition Awaiting_to_DeepSleep
            first AwaitingCommand
            accept idleTime : TimeDuration
            if idleTime >= 30 [SI::second]
            then DeepSleep;

        transition Executing_to_Sampling
            first ExecutingCommand
            accept commandApplied : Boolean
            if commandApplied == true
            then SamplingSensors;

        transition DeepSleep_to_Sampling
            first DeepSleep
            accept wakeTimer : TimeDuration
            if wakeTimer >= 300 [SI::second]
            then SamplingSensors;

        transition Fault_to_Booting
            first Fault
            accept resetRequested : Boolean
            if resetRequested == true
            then Booting;
    }

    part def ESP32EnvironmentalTelemetrySystem {
        attribute systemName : String = "ESP32 Environmental Telemetry Controller";
        attribute primaryFunction : String = "Measure local environmental conditions, publish telemetry over Wi-Fi, and execute remote control commands through GPIO outputs.";
        attribute nominalInputVoltage : Voltage = 5.0 [SI::volt];
        attribute regulatedLogicVoltage : Voltage = 3.3 [SI::volt];
        attribute telemetryPeriod : TimeDuration = 300 [SI::second];
        attribute expectedAveragePower : Power = 0.18 [SI::watt];

        port externalPowerInput : PowerInputPort;
        port externalGround : GroundPort;
        port cloudLink : TelemetryPort;
        port controlledLoadOutput : DigitalGPIOPort;

        part regulator : VoltageRegulator;
        part esp32 : ESP32Module;
        part environmentSensor : TemperatureHumiditySensor;
        part batteryMonitor : BatteryMonitor;
        part statusLed : StatusLED;
        part relayDriver : RelayDriver;
        part cloud : CloudService;

        connection externalPowerToRegulator
            connect externalPowerInput to regulator.inputPower;

        connection groundReferenceToRegulator
            connect externalGround to regulator.ground;

        connection regulatorToESP32
            connect regulator.regulatedOutput to esp32.power;

        connection groundReferenceToESP32
            connect externalGround to esp32.ground;

        connection regulatorToSensor
            connect regulator.regulatedOutput to environmentSensor.power;

        connection groundReferenceToSensor
            connect externalGround to environmentSensor.ground;

        connection esp32I2CToSensor
            connect esp32.i2c0 to environmentSensor.bus;

        connection esp32ADCToBatteryMonitor
            connect esp32.adc34 to batteryMonitor.adcOutput;

        connection groundReferenceToBatteryMonitor
            connect externalGround to batteryMonitor.ground;

        connection esp32LEDControl
            connect esp32.gpio2 to statusLed.anode;

        connection statusLEDGround
            connect externalGround to statusLed.cathode;

        connection esp32RelayControl
            connect esp32.gpio5 to relayDriver.controlInput;

        connection relayPower
            connect externalPowerInput to relayDriver.power;

        connection relayGround
            connect externalGround to relayDriver.ground;

        connection relayToLoad
            connect relayDriver.switchedOutput to controlledLoadOutput;

        connection esp32ToCloudTelemetry
            connect esp32.applicationInterface to cloudLink;

        connection cloudServiceLink
            connect cloud.network to cloudLink;

        perform action BootFirmware;
        perform action ReadSensors;
        perform action BuildTelemetry;
        perform action PublishTelemetry;
        perform action ApplyCommand;

        exhibit state ESP32ApplicationStateMachine;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : ESP32EnvironmentalTelemetrySystem;

        require constraint {
            system.primaryFunction == "Measure local environmental conditions, publish telemetry over Wi-Fi, and execute remote control commands through GPIO outputs."
        }
    }

    requirement def LogicVoltageRequirement {
        subject system : ESP32EnvironmentalTelemetrySystem;

        require constraint {
            system.regulatedLogicVoltage >= 3.0 [SI::volt] and
            system.regulatedLogicVoltage <= 3.6 [SI::volt]
        }
    }

    requirement def TelemetryPeriodRequirement {
        subject system : ESP32EnvironmentalTelemetrySystem;

        require constraint {
            system.telemetryPeriod <= 300 [SI::second]
        }
    }

    requirement def WirelessTelemetryRequirement {
        subject module : ESP32Module;

        require constraint {
            module.wifiSupported == true and
            module.radioSubsystem.wifiFrequency == 2.4 [SI::giga * SI::hertz]
        }
    }

    requirement def LowPowerSleepRequirement {
        subject module : ESP32Module;

        require constraint {
            module.deepSleepCurrent <= 0.00002 [SI::ampere]
        }
    }

    requirement def ProcessingCapabilityRequirement {
        subject module : ESP32Module;

        require constraint {
            module.dualCoreProcessor.coreCount == 2 and
            module.cpuClock >= 160 [SI::mega * SI::hertz]
        }
    }

    requirement def SensorInterfaceRequirement {
        subject system : ESP32EnvironmentalTelemetrySystem;

        require constraint {
            system.environmentSensor.operatingVoltage == system.regulatedLogicVoltage
        }
    }

    requirement def RemoteControlRequirement {
        subject system : ESP32EnvironmentalTelemetrySystem;

        require constraint {
            system.relayDriver.switchedCurrentLimit >= 1.0 [SI::ampere]
        }
    }

    requirement def BatteryObservationRequirement {
        subject monitor : BatteryMonitor;

        require constraint {
            monitor.maxMeasuredVoltage >= 5.0 [SI::volt]
        }
    }

    satisfy PrimaryFunctionRequirement by ESP32EnvironmentalTelemetrySystem;
    satisfy LogicVoltageRequirement by ESP32EnvironmentalTelemetrySystem;
    satisfy TelemetryPeriodRequirement by ESP32EnvironmentalTelemetrySystem;
    satisfy WirelessTelemetryRequirement by ESP32Module;
    satisfy LowPowerSleepRequirement by ESP32Module;
    satisfy ProcessingCapabilityRequirement by ESP32Module;
    satisfy SensorInterfaceRequirement by ESP32EnvironmentalTelemetrySystem;
    satisfy RemoteControlRequirement by ESP32EnvironmentalTelemetrySystem;
    satisfy BatteryObservationRequirement by BatteryMonitor;

}