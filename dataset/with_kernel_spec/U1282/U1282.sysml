package EnvironmentalSensorDeviceModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    item def Electricity;
    item def EnvironmentalData {
        attribute temperature: TemperatureValue;
        attribute humidity: Real;
        attribute pressure: PressureValue;
        attribute timestamp: TimeInstant;
    }
    item def RemoteCommand;
    item def LEDSignal;

    port def PowerPort {
        out item power: Electricity;
    }
    port def SensorDataPort {
        out item data: EnvironmentalData;
    }
    port def DataPort {
        out item data: EnvironmentalData;
    }
    port def CommandPort {
        in item command: RemoteCommand;
    }
    port def LEDControlPort {
        out item signal: LEDSignal;
    }
    port def WirelessPort {
        in item command: RemoteCommand;
        out item data: EnvironmentalData;
        attribute frequency: FrequencyValue = 2.4e9 [Hz];
    }

    action def 'Initialize Hardware';
    action def 'Connect WiFi';
    action def 'Acquire Readings' {
        out data: EnvironmentalData;
    }
    action def 'Package Data' {
        in data: EnvironmentalData;
        out packagedData: EnvironmentalData;
    }
    action def 'Transmit Data' {
        in data: EnvironmentalData;
    }
    action def 'Receive Command' {
        out command: RemoteCommand;
    }

    state def 'Operating States' {
        entry action initial;
        state 'Power On';
        state 'Initialize Hardware';
        state 'Connect WiFi';
        state 'Main Loop' parallel {
            state 'Sensing Loop' {
                entry action 'acquire readings': 'Acquire Readings';
                transition 'sensing-to-packaging' first 'Sensing Loop' then 'Packaging';
                state 'Packaging' {
                    entry action 'package data': 'Package Data';
                }
                transition 'packaging-to-transmitting' first 'Packaging' then 'Transmitting';
                state 'Transmitting' {
                    entry action 'transmit data': 'Transmit Data';
                }
                transition 'transmitting-to-sensing' first 'Transmitting' then 'Sensing Loop';
            }
            state 'Command Listener' {
                do action 'receive command': 'Receive Command';
            }
        }
        transition initial then 'Power On';
        transition 'pwr-to-init' first 'Power On' then 'Initialize Hardware';
        transition 'init-to-wifi' first 'Initialize Hardware' then 'Connect WiFi';
        transition 'wifi-to-loop' first 'Connect WiFi' then 'Main Loop';
    }

    part def VoltageRegulator {
        attribute inputVoltageMin: ElectricPotentialValue = 4.5 [V];
        attribute inputVoltageMax: ElectricPotentialValue = 12 [V];
        attribute outputVoltage: ElectricPotentialValue = 3.3 [V];
        port powerIn: ~PowerPort;
        port powerOut: PowerPort;
    }

    part def BME280Sensor {
        out attribute temperature: TemperatureValue;
        out attribute humidity: Real;
        out attribute pressure: PressureValue;
        port powerIn: ~PowerPort;
        port dataOut: SensorDataPort;
    }

    part def ESP32Microcontroller {
        attribute coreCount: Integer = 2;
        attribute wifiFrequency: FrequencyValue = 2.4e9 [Hz];
        port powerIn: ~PowerPort;
        port sensorDataIn: ~SensorDataPort;
        port dataOut: DataPort;
        port commandIn: CommandPort;
        port ledControlOut: LEDControlPort;
        port wirelessPort: WirelessPort;

        exhibit state 'operating states': 'Operating States';
    }

    part def LEDIndicator {
        attribute color: String = "Blue";
        port controlIn: ~LEDControlPort;
    }

    part def EnvironmentalSensorDevice {
        port powerIn: ~PowerPort;
        port wirelessPort: WirelessPort;

        part voltageRegulator: VoltageRegulator;
        part esp32: ESP32Microcontroller;
        part bme280: BME280Sensor;
        part led: LEDIndicator;

        binding powerIn = voltageRegulator.powerIn;
        connection powerToESP32 connect voltageRegulator.powerOut to esp32.powerIn;
        connection powerToBME280 connect voltageRegulator.powerOut to bme280.powerIn;
        connection sensorToESP32 connect bme280.dataOut to esp32.sensorDataIn;
        connection esp32ToLED connect esp32.ledControlOut to led.controlIn;
        binding wirelessPort = esp32.wirelessPort;
    }

    requirement def EnvironmentalSensingRequirement {
        doc /* The device shall measure ambient temperature, humidity, and atmospheric pressure, and transmit the data wirelessly over WiFi. */
    }

    requirement sensingReq : EnvironmentalSensingRequirement;
}
