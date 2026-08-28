package EnvironmentalMonitoringDevice {
    import ScalarValues::*;

    // ============================================================
    // Value Types with Units
    // ============================================================

    attribute def Temperature :> Real {
        doc "Temperature in degrees Celsius";
        attribute unit : String = "degC";
        attribute min : Real = -40.0;
        attribute max : Real = 85.0;
    }

    attribute def Humidity :> Real {
        doc "Relative humidity in percent";
        attribute unit : String = "%RH";
        attribute min : Real = 0.0;
        attribute max : Real = 100.0;
    }

    attribute def AtmosphericPressure :> Real {
        doc "Atmospheric pressure in hectopascals";
        attribute unit : String = "hPa";
        attribute min : Real = 300.0;
        attribute max : Real = 1100.0;
    }

    attribute def Voltage :> Real {
        doc "Voltage in volts";
        attribute unit : String = "V";
    }

    attribute def Current :> Real {
        doc "Current in amperes";
        attribute unit : String = "A";
    }

    attribute def Power :> Real {
        doc "Power in watts";
        attribute unit : String = "W";
    }

    attribute def Energy :> Real {
        doc "Energy in watt-hours";
        attribute unit : String = "Wh";
    }

    attribute def Frequency :> Real {
        doc "Frequency in megahertz";
        attribute unit : String = "MHz";
    }

    attribute def TimeInterval :> Real {
        doc "Time interval in seconds";
        attribute unit : String = "s";
    }

    // ============================================================
    // Item Definitions
    // ============================================================

    item def EnvironmentalData {
        doc "Aggregate environmental sensor reading";
        attribute temperature : Temperature;
        attribute humidity : Humidity;
        attribute pressure : AtmosphericPressure;
        attribute timestamp : String;
        attribute sensorId : String;
    }

    item def HTTPRequest {
        doc "HTTP request for cloud data transmission";
        attribute method : String;
        attribute url : String;
        attribute contentType : String;
        attribute payload : String;
    }

    item def HTTPResponse {
        doc "HTTP response from cloud server";
        attribute statusCode : Integer;
        attribute body : String;
    }

    item def WiFiCredentials {
        doc "WiFi network credentials";
        attribute ssid : String;
        attribute securityKey : String;
        attribute securityType : String;
    }

    item def PowerSupply {
        doc "Power supply specification";
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }

    // ============================================================
    // Port Definitions
    // ============================================================

    port def PowerInPort {
        doc "Input power port — receives power supply";
        in item power : PowerSupply;
    }

    port def PowerOutPort {
        doc "Output power port — provides regulated power";
        out item power : PowerSupply;
    }

    port def SensorDataOutPort {
        doc "Sensor data output port";
        out item reading : EnvironmentalData;
    }

    port def SensorDataInPort {
        doc "Sensor data input port";
        in item reading : EnvironmentalData;
    }

    port def HTTPClientPort {
        doc "HTTP client port — sends requests, receives responses";
        out item request : HTTPRequest;
        in item response : HTTPResponse;
    }

    port def HTTPServerPort {
        doc "HTTP server port — receives requests, sends responses";
        in item request : HTTPRequest;
        out item response : HTTPResponse;
    }

    // ============================================================
    // Requirements
    // ============================================================

    requirement def EnvironmentalSensingRequirement {
        doc "The system shall measure temperature, humidity, and atmospheric pressure using an integrated environmental sensor.";
        attribute measurementInterval : TimeInterval = 60.0;
        attribute temperatureAccuracy : Real = 1.0;
        attribute humidityAccuracy : Real = 3.0;
        attribute pressureAccuracy : Real = 1.0;
        subject monitor : EnvironmentalMonitoringDevice;
        objective {
            monitor.flyport.sensor.lastReading.temperature >= -40.0 and
            monitor.flyport.sensor.lastReading.temperature <= 85.0 and
            monitor.flyport.sensor.lastReading.humidity >= 0.0 and
            monitor.flyport.sensor.lastReading.humidity <= 100.0 and
            monitor.flyport.sensor.lastReading.pressure >= 300.0 and
            monitor.flyport.sensor.lastReading.pressure <= 1100.0
        }
    }

    requirement def WiFiConnectivityRequirement {
        doc "The system shall connect to a local WiFi network using configured credentials and retry upon connection failure.";
        attribute maxRetryAttempts : Integer = 3;
        attribute retryDelay : TimeInterval = 30.0;
        attribute connectionTimeout : TimeInterval = 15.0;
        subject monitor : EnvironmentalMonitoringDevice;
        objective {
            monitor.flyport.wifiModule.networkConnected == true
        }
    }

    requirement def CloudTransmissionRequirement {
        doc "The system shall transmit environmental data to a designated cloud server via HTTP requests at the configured measurement interval.";
        attribute targetEndpoint : String = "https://cloud.example.com/api/environmental";
        attribute transmissionProtocol : String = "HTTP/1.1";
        attribute expectedResponseCode : Integer = 200;
        subject monitor : EnvironmentalMonitoringDevice;
        objective {
            monitor.cloud.totalReceivedReadings > 0
        }
    }

    requirement def PowerRegulationRequirement {
        doc "The system shall regulate input voltage to provide stable 3.3V power to all internal components and monitor overall energy consumption.";
        attribute inputVoltageNominal : Voltage = 5.0;
        attribute inputVoltageMin : Voltage = 4.5;
        attribute inputVoltageMax : Voltage = 5.5;
        attribute outputVoltageRegulated : Voltage = 3.3;
        attribute outputVoltageTolerance : Real = 0.03;
        subject monitor : EnvironmentalMonitoringDevice;
        objective {
            monitor.powerUnit.regulatedOutputVoltage >= 3.2 and
            monitor.powerUnit.regulatedOutputVoltage <= 3.4
        }
    }

    requirement def AutonomousOperationRequirement {
        doc "The system shall operate autonomously following a defined measurement and transmission cycle without manual intervention.";
        attribute measurementInterval : TimeInterval = 60.0;
        attribute autoRestart : Boolean = true;
        subject monitor : EnvironmentalMonitoringDevice;
        objective {
            monitor.flyport.operationalState == "Active"
        }
    }

    // ============================================================
    // Component Definitions
    // ============================================================

    part def EnvironmentalSensor {
        doc "Integrated environmental sensor (BME280) measuring temperature, humidity, and atmospheric pressure";
        attribute partName : String = "BME280";
        attribute i2cAddress : Integer = 0x76;
        attribute operatingVoltage : Voltage = 3.3;
        attribute lastReading : EnvironmentalData;

        port powerIn : PowerInPort;
        port sensorOut : SensorDataOutPort;

        action takeMeasurement {
            doc "Acquire current environmental readings from sensor registers";
            out result : EnvironmentalData;
        }

        action calibrate {
            doc "Perform sensor calibration procedure at startup";
        }
    }

    part def PIC32Microcontroller {
        doc "PIC32MX microcontroller for data processing and HTTP request formatting";
        attribute partName : String = "PIC32MX695F512L";
        attribute clockFrequency : Frequency = 80.0;
        attribute flashMemoryKB : Integer = 512;
        attribute ramSizeKB : Integer = 128;
        attribute operatingVoltage : Voltage = 3.3;

        port powerIn : PowerInPort;
        port sensorIn : SensorDataInPort;
        port httpOut : HTTPClientPort;

        action processData {
            doc "Process raw sensor data and format into HTTP request payload";
            in rawReading : EnvironmentalData;
            out formattedRequest : HTTPRequest;
        }

        action buildHTTPRequest {
            doc "Construct HTTP POST request with environmental data JSON payload";
            in reading : EnvironmentalData;
            out request : HTTPRequest;
        }

        action handleResponse {
            doc "Process HTTP response from cloud server";
            in response : HTTPResponse;
            out success : Boolean;
        }
    }

    part def WiFiTransceiver {
        doc "WiFi transceiver module (MRF24WB0MA) for wireless network communication";
        attribute partName : String = "MRF24WB0MA";
        attribute networkConnected : Boolean = false;
        attribute ssid : String;
        attribute ipAddress : String;
        attribute signalStrengthdBm : Integer;
        attribute operatingVoltage : Voltage = 3.3;

        port powerIn : PowerInPort;
        port httpIn : HTTPServerPort;
        port networkOut : HTTPClientPort;

        action connectToNetwork {
            doc "Attempt to connect to configured WiFi network";
            in credentials : WiFiCredentials;
            out success : Boolean;
        }

        action disconnect {
            doc "Disconnect from WiFi network";
        }

        action transmitOverNetwork {
            doc "Transmit HTTP request over WiFi to remote cloud server";
            in request : HTTPRequest;
            out response : HTTPResponse;
        }
    }

    part def PowerManagementUnit {
        doc "Power management unit for voltage regulation and energy consumption monitoring";
        attribute partName : String = "TPS63031";
        attribute inputVoltageNominal : Voltage = 5.0;
        attribute regulatedOutputVoltage : Voltage = 3.3;
        attribute outputCurrentMax : Current = 2.0;
        attribute energyConsumed : Energy = 0.0;
        attribute conversionEfficiency : Real = 0.95;

        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;

        action regulateVoltage {
            doc "Convert 5V input to regulated 3.3V output";
            in input : PowerSupply;
            out output : PowerSupply;
        }

        action monitorEnergyConsumption {
            doc "Monitor and accumulate energy consumption over time";
            in currentDraw : Current;
            in duration : TimeInterval;
            out consumed : Energy;
        }
    }

    part def CloudService {
        doc "Cloud-based environmental monitoring service endpoint";
        attribute serviceName : String = "CloudEnvironmentalMonitor";
        attribute endpointURL : String = "https://cloud.example.com/api/environmental";
        attribute totalReceivedReadings : Integer = 0;
        attribute lastReceivedReading : EnvironmentalData;

        port cloudIn : HTTPServerPort;

        action receiveData {
            doc "Receive and store environmental data from IoT device";
            in request : HTTPRequest;
            out response : HTTPResponse;
        }

        action storeReading {
            doc "Store received environmental reading in cloud database";
            in reading : EnvironmentalData;
        }
    }

    // ============================================================
    // Integrated Flyport Module
    // ============================================================

    part def OpenpicusFlyport {
        doc "Openpicus Flyport module integrating environmental sensor, PIC32 MCU, and WiFi transceiver";
        attribute moduleName : String = "FlyportWiFi";
        attribute firmwareVersion : String = "2.0";
        attribute operationalState : String = "PowerOff";
        attribute measurementInterval : TimeInterval = 60.0;
        attribute retryCount : Integer = 0;
        attribute maxRetries : Integer = 3;
        attribute powerApplied : Boolean = false;
        attribute initializationComplete : Boolean = false;
        attribute measurementIntervalElapsed : Boolean = false;
        attribute wifiCredentials : WiFiCredentials;

        port powerIn : PowerInPort;
        port networkOut : HTTPClientPort;

        part sensor : EnvironmentalSensor;
        part mcu : PIC32Microcontroller;
        part wifiModule : WiFiTransceiver;

        // Power distribution — delegation from Flyport powerIn to each sub-component
        connection connect powerIn to sensor.powerIn;
        connection connect powerIn to mcu.powerIn;
        connection connect powerIn to wifiModule.powerIn;

        // Internal data flow — sensor to MCU to WiFi
        connection connect sensor.sensorOut to mcu.sensorIn;
        connection connect mcu.httpOut to wifiModule.httpIn;

        // Network port delegation — Flyport networkOut delegates to WiFi module networkOut
        connection connect networkOut to wifiModule.networkOut;

        // Operational state machine
        state machine OperationalCycle {
            initial state PowerOff {
                doc "Initial state — no power applied";
                entry {
                    operationalState := "PowerOff";
                }
            }

            state Initializing {
                doc "Power applied — initializing all subsystems";
                entry {
                    operationalState := "Initializing";
                    sensor.calibrate();
                    initializationComplete := true;
                }
            }

            state ConnectingWiFi {
                doc "Attempting to connect to configured WiFi network";
                entry {
                    operationalState := "ConnectingWiFi";
                }
            }

            state ErrorState {
                doc "WiFi connection failed — entering retry mode";
                entry {
                    operationalState := "ErrorState";
                    retryCount := retryCount + 1;
                }
            }

            state Active {
                doc "Main operational loop — gathering, packaging, and transmitting data";
                entry {
                    operationalState := "Active";
                }

                initial state Gathering {
                    doc "Reading environmental sensor data";
                    entry {
                        sensor.takeMeasurement();
                    }
                }

                state Packaging {
                    doc "Formatting sensor data into HTTP request payload";
                    entry {
                        mcu.processData(sensor.lastReading);
                    }
                }

                state Transmitting {
                    doc "Transmitting data to cloud server via WiFi";
                    entry {
                        wifiModule.transmitOverNetwork();
                    }
                }

                state Waiting {
                    doc "Waiting for next measurement interval to elapse";
                    entry {
                        measurementIntervalElapsed := false;
                    }
                }

                transition from Gathering to Packaging;
                transition from Packaging to Transmitting;
                transition from Transmitting to Waiting;
                transition from Waiting to Gathering {
                    guard measurementIntervalElapsed == true;
                }
            }

            // Top-level transitions
            transition from PowerOff to Initializing {
                guard powerApplied == true;
            }

            transition from Initializing to ConnectingWiFi {
                guard initializationComplete == true;
            }

            transition from ConnectingWiFi to Active {
                guard wifiModule.networkConnected == true;
            }

            transition from ConnectingWiFi to ErrorState {
                guard wifiModule.networkConnected == false;
            }

            transition from ErrorState to ConnectingWiFi {
                guard retryCount < maxRetries;
            }
        }
    }

    // ============================================================
    // Main IoT Environmental Monitoring Device
    // ============================================================

    part def EnvironmentalMonitoringDevice {
        doc "Self-contained WiFi-enabled IoT environmental monitoring device built on Openpicus Flyport platform";
        attribute deviceName : String = "FlyportEnvMonitor-01";
        attribute deviceId : String = "IOT-ENV-001";
        attribute firmwareVersion : String = "1.0.0";
        attribute manufacturer : String = "Openpicus";

        // Requirement satisfaction
        satisfy EnvironmentalSensingRequirement;
        satisfy WiFiConnectivityRequirement;
        satisfy CloudTransmissionRequirement;
        satisfy PowerRegulationRequirement;
        satisfy AutonomousOperationRequirement;

        // External ports
        port externalPower : PowerInPort;
        port networkOut : HTTPClientPort;

        // Components
        part flyport : OpenpicusFlyport;
        part powerUnit : PowerManagementUnit;
        part cloud : CloudService;

        // Connections — external power to PMU, PMU to Flyport, Flyport network to cloud
        connection connect externalPower to powerUnit.powerIn;
        connection connect powerUnit.powerOut to flyport.powerIn;
        connection connect flyport.networkOut to cloud.cloudIn;

        // System-level actions
        action powerOn {
            doc "Apply power and initiate system startup sequence";
            out supply : PowerSupply;
        }

        action configureWiFi {
            doc "Configure WiFi network credentials for the device";
            in ssid : String;
            in securityKey : String;
            in securityType : String;
        }

        action setMeasurementInterval {
            doc "Set the environmental measurement and transmission interval";
            in interval : TimeInterval;
        }
    }

    // ============================================================
    // System Context — Complete deployment configuration
    // ============================================================

    part def MonitoringSystemContext {
        doc "Complete system context showing IoT device deployed with cloud service backend";

        part device : EnvironmentalMonitoringDevice {
            attribute deviceName = "LabRoomA-Monitor";
            attribute deviceId = "IOT-ENV-001";
            part flyport : OpenpicusFlyport {
                attribute measurementInterval = 60.0;
                attribute wifiCredentials : WiFiCredentials {
                    attribute ssid = "LabNetwork";
                    attribute securityKey = "********";
                    attribute securityType = "WPA2";
                }
                part sensor : EnvironmentalSensor {
                    attribute partName = "BME280";
                    attribute i2cAddress = 0x76;
                }
                part mcu : PIC32Microcontroller {
                    attribute partName = "PIC32MX695F512L";
                }
                part wifiModule : WiFiTransceiver {
                    attribute partName = "MRF24WB0MA";
                    attribute ssid = "LabNetwork";
                }
            }
            part powerUnit : PowerManagementUnit {
                attribute partName = "TPS63031";
                attribute inputVoltageNominal = 5.0;
                attribute regulatedOutputVoltage = 3.3;
            }
            part cloud : CloudService {
                attribute serviceName = "CloudEnvironmentalMonitor";
                attribute endpointURL = "https://cloud.example.com/api/environmental";
            }
        }

        // System-level deployment action
        action deploySystem {
            doc "Deploy the IoT monitoring system with specified configuration";
            in deviceName : String;
            in wifiConfig : WiFiCredentials;
            in cloudEndpoint : String;
            in interval : TimeInterval;
        }

        action verifyOperation {
            doc "Verify that the device is connected and transmitting data";
            out isOperational : Boolean;
        }
    }
}
