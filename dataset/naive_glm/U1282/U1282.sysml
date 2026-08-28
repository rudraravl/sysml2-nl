package EnvironmentalSensorDevice {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value type Voltage :> Real { unit 'V'; }
    value type Temperature :> Real { unit '°C'; }
    value type Humidity :> Real { unit '%'; }
    value type Pressure :> Real { unit 'hPa'; }
    value type Frequency :> Real { unit 'GHz'; }
    value type ElapsedTime :> Real { unit 's'; }

    // ---- Item types ----
    item def EnvironmentalReading {
        attribute temperature : Temperature;
        attribute humidity : Humidity;
        attribute pressure : Pressure;
        attribute timestamp : ElapsedTime;
    }

    item def RemoteCommand {
        attribute commandId : String;
        attribute payload : String;
    }

    attribute def BlueColor {
        attribute wavelength : Integer = 470; // nm
    }

    // ---- Port definitions ----
    port def DCInputPort {
        in attribute inputVoltage : Voltage;
    }

    port def PowerOutputPort {
        out attribute outputVoltage : Voltage;
    }

    port def I2CPort {
        out attribute clockSignal : Boolean;
        inout attribute dataSignal : Boolean;
    }

    port def LEDControlPort {
        out attribute ledState : Boolean;
    }

    port def WiFiPort {
        out item transmittedReading : EnvironmentalReading;
        in item receivedCommand : RemoteCommand;
        attribute carrierFrequency : Frequency = 2.4 [GHz];
    }

    // ---- Component part definitions ----
    part def VoltageRegulator {
        attribute minInputVoltage : Voltage = 4.5 [V];
        attribute maxInputVoltage : Voltage = 12.0 [V];
        attribute nominalOutputVoltage : Voltage = 3.3 [V];

        port dcInput : DCInputPort;
        port powerOutput : PowerOutputPort;

        action def regulate {
            in inputVoltage : Voltage;
            out outputVoltage : Voltage = 3.3 [V];
        }

        exhibit action regulateAction : regulate {
            in inputVoltage = dcInput.inputVoltage;
            out outputVoltage = powerOutput.outputVoltage;
        }
    }

    part def BME280Sensor {
        attribute operatingVoltage : Voltage = 3.3 [V];
        attribute temperatureMin : Temperature = -40.0 [°C];
        attribute temperatureMax : Temperature = 85.0 [°C];
        attribute humidityMin : Humidity = 0.0 [%];
        attribute humidityMax : Humidity = 100.0 [%];
        attribute pressureMin : Pressure = 300.0 [hPa];
        attribute pressureMax : Pressure = 1100.0 [hPa];

        port powerInput : PowerOutputPort;
        port i2cInterface : I2CPort;

        action def measure {
            out temperature : Temperature;
            out humidity : Humidity;
            out pressure : Pressure;
        }

        exhibit action measureAction : measure {
            out temperature;
            out humidity;
            out pressure;
        }
    }

    part def ESP32Microcontroller {
        attribute coreCount : Integer = 2;
        attribute operatingVoltage : Voltage = 3.3 [V];
        attribute clockSpeed : Frequency = 0.24 [GHz];

        port powerInput : PowerOutputPort;
        port sensorInterface : I2CPort;
        port ledControl : LEDControlPort;
        port wifiInterface : WiFiPort;

        action def initializeHardware { }
        action def connectToAccessPoint { }
        action def acquireReadings {
            out reading : EnvironmentalReading;
        }
        action def packageData {
            in rawReading : EnvironmentalReading;
            out packagedReading : EnvironmentalReading;
        }
        action def transmitData {
            in reading : EnvironmentalReading;
        }
        action def receiveCommand {
            out command : RemoteCommand;
        }
        action def processCommand {
            in command : RemoteCommand;
        }
    }

    part def BlueLED {
        attribute color : BlueColor;
        attribute operatingVoltage : Voltage = 3.3 [V];

        port powerInput : PowerOutputPort;
        port controlInput : LEDControlPort;

        action def indicate {
            in state : Boolean;
        }
    }

    // ---- State machine definition ----
    state def SensorOperationalStates {
        entry; then off;

        state off {
            entry { /* device unpowered */ }
        }

        state initializing {
            entry action initHardware;
            do initializeHardware;
        }

        state connectingWiFi {
            entry action connectAP;
            do connectToAccessPoint;
        }

        state operational {
            // Main loop: acquire, package, transmit, and listen for commands
            do action mainLoop {
                first acquireReadings;
                then packageData;
                then transmitData;
                then receiveCommand;
                then processCommand;
            }
        }

        transition powerOn
            from off
            to initializing
            when regulator.powerOutput.outputVoltage == 3.3 [V];

        transition initComplete
            from initializing
            to connectingWiFi
            when initializeHardware.done;

        transition wifiConnected
            from connectingWiFi
            to operational
            when connectToAccessPoint.done;

        transition remoteReset
            from operational
            to initializing
            when receivedCommand.commandId == "reset";
    }

    // ---- Top-level system ----
    part def EnvironmentalSensorSystem {
        port dcInput : DCInputPort;
        port wifiLink : WiFiPort;

        part regulator : VoltageRegulator {
            port dcInput redefines EnvironmentalSensorSystem::dcInput;
        }

        part mcu : ESP32Microcontroller;
        part sensor : BME280Sensor;
        part statusLED : BlueLED;

        // Power distribution
        connection regulatorToMCU : PowerOutputPort
            connect regulator.powerOutput to mcu.powerInput;
        connection regulatorToSensor : PowerOutputPort
            connect regulator.powerOutput to sensor.powerInput;
        connection regulatorToLED : PowerOutputPort
            connect regulator.powerOutput to statusLED.powerInput;

        // I2C bus between MCU and BME280
        connection mcuToSensor : I2CPort
            connect mcu.sensorInterface to sensor.i2cInterface;

        // LED control line
        connection mcuToLED : LEDControlPort
            connect mcu.ledControl to statusLED.controlInput;

        // WiFi link to external network
        connection mcuToWiFi : WiFiPort
            connect mcu.wifiInterface to EnvironmentalSensorSystem::wifiLink;

        // Behavioral state machine
        exhibit state deviceStates : SensorOperationalStates;
    }

    // ---- Requirements ----
    requirement def EnvironmentalSensorRequirements {
        subject sensorSystem : EnvironmentalSensorSystem;

        requirement measureTemperature {
            subject :>> sensorSystem;
            doc /* The device shall measure ambient temperature using the BME280 sensor. */
        }

        requirement measureHumidity {
            subject :>> sensorSystem;
            doc /* The device shall measure ambient humidity using the BME280 sensor. */
        }

        requirement measurePressure {
            subject :>> sensorSystem;
            doc /* The device shall measure atmospheric pressure using the BME280 sensor. */
        }

        requirement wirelessReporting {
            subject :>> sensorSystem;
            doc /* The device shall transmit packaged environmental readings wirelessly over a 2.4 GHz WiFi network. */
            constraint { sensorSystem.wifiLink.carrierFrequency == 2.4 [GHz] }
        }

        requirement powerRegulation {
            subject :>> sensorSystem;
            doc /* The device shall accept a DC input voltage between 4.5V and 12V and provide a stable 3.3V supply. */
            constraint { sensorSystem.regulator.minInputVoltage == 4.5 [V] }
            constraint { sensorSystem.regulator.maxInputVoltage == 12.0 [V] }
            constraint { sensorSystem.regulator.nominalOutputVoltage == 3.3 [V] }
        }

        requirement remoteCommandCapability {
            subject :>> sensorSystem;
            doc /* The device shall receive and process remote commands for external control or configuration updates. */
        }

        requirement statusIndication {
            subject :>> sensorSystem;
            doc /* The device shall provide visual operational status feedback via a blue LED indicator. */
            constraint { sensorSystem.statusLED.color.wavelength == 470 }
        }

        requirement dualCoreProcessing {
            subject :>> sensorSystem;
            doc /* The device shall use a dual-core ESP32 microcontroller for processing, data management, and wireless communication. */
            constraint { sensorSystem.mcu.coreCount == 2 }
        }

        requirement continuousOperationCycle {
            subject :>> sensorSystem;
            doc /* The device shall operate in a continuous cycle: acquire readings, package with timestamp, transmit, and listen for commands. */
        }
    }

    // ---- Verification ----
    verification PowerRegulationVerification {
        subject regulator : VoltageRegulator;
        objective {
            doc /* Verify the regulator produces 3.3V output across the specified input range. */
        }
        method {
            action testRegulation {
                in testInput : Voltage = 4.5 [V];
                in testInput2 : Voltage = 12.0 [V];
                out measuredOutput : Voltage;
            }
        }
        verify powerRegulation;
    }
}
