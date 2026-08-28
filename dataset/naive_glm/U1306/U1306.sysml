package WeatherMonitoringSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ===== Value Types =====
    value type TemperatureValue :> Real {
        :>> unit = kelvin;
    }

    value type HumidityValue :> Real {
        :>> unit = 1;
        :>> quantity = "relative humidity";
    }

    value type VoltageValue :> Real {
        :>> unit = volt;
    }

    value type CurrentValue :> Real {
        :>> unit = ampere;
    }

    value type FrequencyValue :> Real {
        :>> unit = hertz;
    }

    value type TimeInterval :> Real {
        :>> unit = second;
    }

    value type PowerValue :> Real {
        :>> unit = watt;
    }

    // ===== Item Types =====
    item def TemperatureReading {
        attribute value : TemperatureValue;
        attribute timestamp : TimeInterval;
        attribute sensorId : String;
    }

    item def HumidityReading {
        attribute value : HumidityValue;
        attribute timestamp : TimeInterval;
        attribute sensorId : String;
    }

    item def WeatherPacket {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute timestamp : TimeInterval;
        attribute deviceId : String;
        attribute sequenceNumber : Integer;
    }

    item def PowerFlow {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item def StatusSignal {
        attribute message : String;
        attribute severity : String;
    }

    // ===== Port Definitions =====
    port def PowerPort {
        out power : PowerFlow;
    }

    port def SensorDataPort {
        out temperature : TemperatureValue;
        out humidity : HumidityValue;
        out valid : Boolean;
    }

    port def NetworkPort {
        out packet : WeatherPacket;
        out connected : Boolean;
    }

    port def StatusPort {
        out signal : StatusSignal;
    }

    // ===== DHT22 Sensor =====
    part def DHT22Sensor {
        attribute samplingRate : FrequencyValue = 0.5 [Hz];
        attribute operatingVoltage : VoltageValue = 3.3 [V];
        attribute temperatureAccuracy : Real = 0.5;
        attribute humidityAccuracy : Real = 2.0;
        attribute measurementRange : TemperatureValue = 80.0 [K];

        port powerIn : PowerPort;
        port dataOut : SensorDataPort;

        action def ReadSensor :> Action {
            out temperature : TemperatureValue;
            out humidity : HumidityValue;
            out valid : Boolean;
        }

        action readSensor : ReadSensor {
            // Perform one-wire communication and parse data
        }

        state SensorState {
            state Idle;
            state Reading {
                do readSensor;
            }
            state ErrorState {
                do action { dataOut.valid = false; }
            }
            transition Idle to Reading
                when powerIn.power is set;
            transition Reading to Idle
                when readSensor.valid is set;
            transition Reading to ErrorState
                if readSensor.valid == false;
            transition ErrorState to Reading
                if recoveryAttempts < 3;
        }
    }

    // ===== ESP8266 Microcontroller =====
    part def ESP8266Microcontroller {
        attribute clockSpeed : FrequencyValue = 80.0e6 [Hz];
        attribute operatingVoltage : VoltageValue = 3.3 [V];
        attribute flashMemoryKB : Integer = 4096;
        attribute deviceId : String = "NodeMCU-001";
        attribute wifiSSID : String = "WeatherNet";
        attribute wifiPassword : String;
        attribute serverURL : String = "http://weather.server/api";
        attribute samplingInterval : TimeInterval = 60.0 [s];
        attribute maxRetries : Integer = 3;

        port powerIn : PowerPort;
        port sensorIn : SensorDataPort;
        port networkOut : NetworkPort;
        port statusOut : StatusPort;

        attribute currentTemperature : TemperatureValue;
        attribute currentHumidity : HumidityValue;
        attribute sequenceNumber : Integer = 0;
        attribute wifiConnected : Boolean = false;
        attribute errorCount : Integer = 0;

        action def ConnectWiFi :> Action {
            out success : Boolean;
        }

        action def ReadSensorData :> Action {
            in temp : TemperatureValue;
            in hum : HumidityValue;
            in valid : Boolean;
            out temperature : TemperatureValue;
            out humidity : HumidityValue;
            out success : Boolean;
        }

        action def PackageData :> Action {
            in temperature : TemperatureValue;
            in humidity : HumidityValue;
            out packet : WeatherPacket;
        }

        action def TransmitData :> Action {
            in packet : WeatherPacket;
            out success : Boolean;
        }

        action def SignalStatus :> Action {
            in message : String;
            in severity : String;
            out signal : StatusSignal;
        }

        state WeatherMonitorStateMachine {
            entry action {
                statusOut.signal = SignalStatus(message = "Powering on", severity = "info").signal;
            }

            state Initializing {
                entry action {
                    statusOut.signal = SignalStatus(message = "Initializing", severity = "info").signal;
                }
                do connectWiFi : ConnectWiFi {
                    // Attempt WiFi connection
                }
                transition to Measuring
                    if connectWiFi.success == true;
                transition to ErrorRecovery
                    if connectWiFi.success == false;
            }

            state Measuring {
                entry action {
                    statusOut.signal = SignalStatus(message = "Measuring", severity = "info").signal;
                }
                do readData : ReadSensorData {
                    in temp = sensorIn.temperature;
                    in hum = sensorIn.humidity;
                    in valid = sensorIn.valid;
                }
                transition to Processing
                    if readData.success == true;
                transition to ErrorRecovery
                    if readData.success == false;
            }

            state Processing {
                entry action {
                    statusOut.signal = SignalStatus(message = "Processing", severity = "info").signal;
                }
                do packageData : PackageData {
                    in temperature = readData.temperature;
                    in humidity = readData.humidity;
                }
                transition to Transmitting
                    when packageData.packet is set;
            }

            state Transmitting {
                entry action {
                    statusOut.signal = SignalStatus(message = "Transmitting", severity = "info").signal;
                }
                do transmitData : TransmitData {
                    in packet = packageData.packet;
                }
                transition to Measuring
                    if transmitData.success == true;
                transition to ErrorRecovery
                    if transmitData.success == false;
            }

            state ErrorRecovery {
                entry action {
                    statusOut.signal = SignalStatus(message = "Error recovery", severity = "error").signal;
                    errorCount = errorCount + 1;
                }
                do action {
                    // Attempt recovery: reset sensor, reconnect WiFi
                }
                transition to Initializing
                    if errorCount < maxRetries;
                transition to Initializing
                    after 30.0 [s]
                    if errorCount >= maxRetries;
            }
        }
    }

    // ===== Voltage Regulator =====
    part def VoltageRegulator {
        attribute inputVoltage : VoltageValue = 5.0 [V];
        attribute outputVoltage : VoltageValue = 3.3 [V];
        attribute efficiency : Real = 0.95;
        attribute maxOutputCurrent : CurrentValue = 1.0 [A];

        port powerIn : PowerPort;
        port powerOut : PowerPort;

        action regulate {
            in input : PowerFlow;
            out output : PowerFlow;
        }
    }

    // ===== USB Power Supply =====
    part def USBPowerSupply {
        attribute outputVoltage : VoltageValue = 5.0 [V];
        attribute maxCurrent : CurrentValue = 0.5 [A];
        attribute maxPower : PowerValue = 2.5 [W];

        port powerOut : PowerPort;
    }

    // ===== Status LED =====
    part def StatusLED {
        attribute color : String = "Blue";
        attribute operatingVoltage : VoltageValue = 3.3 [V];
        attribute forwardCurrent : CurrentValue = 0.02 [A];
        attribute forwardVoltage : VoltageValue = 2.8 [V];

        port powerIn : PowerPort;
        port statusIn : StatusPort;

        state LEDState {
            state Off;
            state On;
            state Blinking;
            transition Off to On
                when statusIn.signal is set;
            transition On to Blinking
                if statusIn.signal.severity == "error";
            transition Blinking to On
                if statusIn.signal.severity == "info";
            transition On to Off
                when statusIn.signal is set;
        }
    }

    // ===== Remote Server =====
    part def RemoteServer {
        attribute serverURL : String = "http://weather.server/api";
        attribute maxPacketSize : Integer = 1024;

        port networkIn : NetworkPort;

        action receivePacket {
            in packet : WeatherPacket;
        }

        state ServerState {
            state Listening;
            state Receiving {
                do receivePacket;
            }
            transition Listening to Receiving
                when networkIn.packet is set;
            transition Receiving to Listening
                when receivePacket is done;
        }
    }

    // ===== NodeMCU Weather Station Assembly =====
    part def NodeMCUWeatherStation {
        part usbPower : USBPowerSupply;
        part regulator : VoltageRegulator;
        part esp8266 : ESP8266Microcontroller;
        part dht22 : DHT22Sensor;
        part statusLED : StatusLED;
        part remoteServer : RemoteServer;

        connect usbPower.powerOut to regulator.powerIn;
        connect regulator.powerOut to esp8266.powerIn;
        connect regulator.powerOut to dht22.powerIn;
        connect regulator.powerOut to statusLED.powerIn;
        connect dht22.dataOut to esp8266.sensorIn;
        connect esp8266.networkOut to remoteServer.networkIn;
        connect esp8266.statusOut to statusLED.statusIn;
    }

    // ===== Requirements =====
    requirement def EnvironmentalMonitoringRequirement {
        subject weatherStation : NodeMCUWeatherStation;
        objective {
            doc "The system shall autonomously collect environmental data and transmit it wirelessly to a remote server.";
        }
    }

    requirement def WiFiConnectivityRequirement {
        subject esp8266 : ESP8266Microcontroller;
        objective {
            doc "The ESP8266 shall connect to a specified WiFi network on power-up before entering the monitoring loop.";
        }
    }

    requirement def TemperatureSensingRequirement {
        subject dht22 : DHT22Sensor;
        objective {
            doc "The DHT22 sensor shall measure ambient temperature with an accuracy of ±0.5°C.";
        }
    }

    requirement def HumiditySensingRequirement {
        subject dht22 : DHT22Sensor;
        objective {
            doc "The DHT22 sensor shall measure relative humidity with an accuracy of ±2%.";
        }
    }

    requirement def DataTransmissionRequirement {
        subject esp8266 : ESP8266Microcontroller;
        objective {
            doc "The system shall package temperature, humidity, and timestamp data into a packet and transmit it to a pre-configured server at regular intervals.";
        }
    }

    requirement def ErrorHandlingRequirement {
        subject esp8266 : ESP8266Microcontroller;
        objective {
            doc "The system shall handle errors including failed WiFi connection and sensor reading failures, and shall attempt recovery to continue monitoring.";
        }
    }

    requirement def PowerSupplyRequirement {
        subject usbPower : USBPowerSupply;
        subject regulator : VoltageRegulator;
        objective {
            doc "The system shall be powered by a standard USB 5V supply with an onboard voltage regulator stepping down to 3.3V for sensitive electronics.";
        }
    }

    requirement def StatusIndicationRequirement {
        subject statusLED : StatusLED;
        objective {
            doc "A blue LED shall provide visual feedback on the system's operational state, including initialization, measuring, processing, transmitting, and error conditions.";
        }
    }

    requirement def StateTransitionRequirement {
        subject esp8266 : ESP8266Microcontroller;
        objective {
            doc "The system shall transition through distinct states: initializing, measuring, processing, and transmitting, with error recovery handling.";
        }
    }

    // ===== Requirement Usages =====
    requirement environmentalMonitoring : EnvironmentalMonitoringRequirement {
        subject weatherStation = NodeMCUWeatherStation;
    }

    requirement wifiConnectivity : WiFiConnectivityRequirement {
        subject esp8266 = NodeMCUWeatherStation::esp8266;
    }

    requirement temperatureSensing : TemperatureSensingRequirement {
        subject dht22 = NodeMCUWeatherStation::dht22;
    }

    requirement humiditySensing : HumiditySensingRequirement {
        subject dht22 = NodeMCUWeatherStation::dht22;
    }

    requirement dataTransmission : DataTransmissionRequirement {
        subject esp8266 = NodeMCUWeatherStation::esp8266;
    }

    requirement errorHandling : ErrorHandlingRequirement {
        subject esp8266 = NodeMCUWeatherStation::esp8266;
    }

    requirement powerSupply : PowerSupplyRequirement {
        subject usbPower = NodeMCUWeatherStation::usbPower;
        subject regulator = NodeMCUWeatherStation::regulator;
    }

    requirement statusIndication : StatusIndicationRequirement {
        subject statusLED = NodeMCUWeatherStation::statusLED;
    }

    requirement stateTransition : StateTransitionRequirement {
        subject esp8266 = NodeMCUWeatherStation::esp8266;
    }

    // ===== Requirement Satisfaction =====
    satisfaction wifiConnectivity by NodeMCUWeatherStation::esp8266.WeatherMonitorStateMachine.Initializing;
    satisfaction temperatureSensing by NodeMCUWeatherStation::dht22.readSensor;
    satisfaction humiditySensing by NodeMCUWeatherStation::dht22.readSensor;
    satisfaction dataTransmission by NodeMCUWeatherStation::esp8266.WeatherMonitorStateMachine.Transmitting;
    satisfaction errorHandling by NodeMCUWeatherStation::esp8266.WeatherMonitorStateMachine.ErrorRecovery;
    satisfaction powerSupply by NodeMCUWeatherStation::regulator.regulate;
    satisfaction statusIndication by NodeMCUWeatherStation::statusLED.LEDState;
    satisfaction stateTransition by NodeMCUWeatherStation::esp8266.WeatherMonitorStateMachine;
    satisfaction environmentalMonitoring by NodeMCUWeatherStation;
}
