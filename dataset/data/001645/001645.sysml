package 'Connected Devices System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DeviceIdentifier;
    attribute def NetworkAddress;
    attribute def EncryptionKey;
    
    attribute def SignalStrengthValue :> Real;
    
    attribute def DataRateValue :> Real;
    
    attribute def BatteryCapacityValue :> Real;
    
    item def SensorReading {
        attribute deviceId : DeviceIdentifier;
        attribute timestamp : ISQ::TimeValue;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute humidity : Real;
        attribute pressure : ISQ::PressureValue;
    }
    
    item def ControlCommand {
        attribute targetDevice : DeviceIdentifier;
        attribute commandType : String;
        attribute parameters : Real[*];
    }
    
    item def StatusReport {
        attribute deviceId : DeviceIdentifier;
        attribute batteryLevel : BatteryCapacityValue;
        attribute signalStrength : SignalStrengthValue;
        attribute operationalState : String;
    }
    
    item def DataMessage {
        attribute source : NetworkAddress;
        attribute destination : NetworkAddress;
        attribute payload : String;
        attribute encrypted : Boolean;
    }
    
    port def SensorDataPort {
        out sensorOutput : SensorReading;
        attribute samplingRate : ISQ::FrequencyValue;
    }
    
    port def NetworkPort {
        in dataIn : DataMessage;
        out dataOut : DataMessage;
        attribute address : NetworkAddress;
        attribute bandwidth : DataRateValue;
    }
    
    port def ControlPort {
        in commandIn : ControlCommand;
        out statusOut : StatusReport;
    }
    
    port def PowerPort {
        in powerSupply : ISQ::PowerValue;
        attribute voltage : ISQ::ElectricPotentialValue;
    }
    
    part def IoTSensor {
        attribute id : DeviceIdentifier;
        attribute batteryCapacity : BatteryCapacityValue;
        
        port sensorPort : SensorDataPort;
        port networkPort : NetworkPort;
        port powerPort : PowerPort;
        
        perform action collectSensorData {
            out reading : SensorReading;
            
            first start;
            then action measureEnvironment {
                out temp : ISQ::ThermodynamicTemperatureValue;
                out humid : Real;
                out press : ISQ::PressureValue;
            }
            then action packageReading {
                in temperature = measureEnvironment.temp;
                in humidity = measureEnvironment.humid;
                in pressure = measureEnvironment.press;
                out sensorData : SensorReading;
            }
            then action transmitReading {
                in data = packageReading.sensorData;
                out transmitted : SensorReading;
            }
            then done;
        }
        
        exhibit state machine sensorStateMachine {
            entry; then Sleeping;
            
            state Sleeping {
                entry action enterSleep;
                accept at when 10.0 [SI::s] then Active;
            }
            state Active {
                entry action activateSensors;
                accept after 5.0 [SI::s] then Transmitting;
            }
            state Transmitting {
                entry action sendData;
                accept after 1.0 [SI::s] then Sleeping;
            }
            state LowPower {
                entry action reducePower;
                accept after 60.0 [SI::s] then Sleeping;
            }
        }
    }
    
    part def NetworkGateway {
        attribute maxConnections : Integer = 100;
        attribute currentLoad : Real;
        
        port devicePort : NetworkPort[1..*];
        port cloudPort : NetworkPort;
        port managementPort : ControlPort;
        
        perform action routeMessages {
            in incomingMessage : DataMessage;
            out outgoingMessage : DataMessage;
            
            first start;
            then merge routingDecision;
            then action inspectMessage {
                in msg : DataMessage = incomingMessage;
                out isValid : Boolean;
                out destination : NetworkAddress;
            }
            then decide;
                if inspectMessage.isValid then forwardMessage;
                if not inspectMessage.isValid then dropMessage;
            action forwardMessage {
                in msg : DataMessage = incomingMessage;
                in dest : NetworkAddress = inspectMessage.destination;
                out forwarded : DataMessage;
            }
            then routingDecision;
            action dropMessage;
            then done;
        }
    }
    
    part def SecurityModule {
        attribute encryptionAlgorithm : String = "AES-256";
        attribute keyRotationInterval : ISQ::TimeValue;
        
        port inputPort : NetworkPort;
        port outputPort : NetworkPort;
        
        perform action secureData {
            in plainData : DataMessage;
            out securedData : DataMessage;
            
            first start;
            then action authenticate {
                in data : DataMessage = plainData;
                out isAuthenticated : Boolean;
                out authToken : EncryptionKey;
            }
            then decide;
                if authenticate.isAuthenticated then encryptData;
                if not authenticate.isAuthenticated then rejectData;
            action encryptData {
                in plain : DataMessage = plainData;
                in key : EncryptionKey = authenticate.authToken;
                out encrypted : DataMessage;
            }
            then action validateEncryption {
                in encryptedMsg : DataMessage = encryptData.encrypted;
                out isValid : Boolean;
            }
            then done;
            action rejectData;
            then done;
        }
    }
    
    part def CloudPlatform {
        attribute storageCapacity : Real;
        attribute processingPower : ISQ::PowerValue;
        
        port networkInterface : NetworkPort;
        port apiPort : ControlPort;
        
        perform action processDeviceData {
            in deviceReadings : SensorReading[*];
            out analytics : String;
            out commands : ControlCommand[*];
            
            first start;
            then action aggregateData {
                in readings : SensorReading[*] = deviceReadings;
                out aggregated : String;
            }
            then action analyzePatterns {
                in data : String = aggregateData.aggregated;
                out insights : String;
                out anomalies : Boolean;
            }
            then decide;
                if analyzePatterns.anomalies then generateAlerts;
                if not analyzePatterns.anomalies then storeData;
            action generateAlerts {
                in analysis : String = analyzePatterns.insights;
                out alertCommands : ControlCommand[*];
            }
            then storeData;
            action storeData {
                in data : String = analyzePatterns.insights;
            }
            then action distributeCommands {
                in cmds : ControlCommand[*] = generateAlerts.alertCommands;
                out distributed : ControlCommand[*];
            }
            then done;
        }
    }
    
    part def ActuatorDevice {
        attribute id : DeviceIdentifier;
        attribute actuatorType : String;
        
        port controlPort : ControlPort;
        port networkPort : NetworkPort;
        port powerPort : PowerPort;
        
        perform action executeCommand {
            in command : ControlCommand;
            out status : StatusReport;
            
            first start;
            then action validateCommand {
                in cmd : ControlCommand = command;
                out isValid : Boolean;
            }
            then decide;
                if validateCommand.isValid then performAction;
                if not validateCommand.isValid then reportError;
            action performAction {
                in cmd : ControlCommand = command;
                out actionResult : String;
            }
            then action reportStatus {
                in result : String = performAction.actionResult;
                out statusMsg : StatusReport;
            }
            then done;
            action reportError {
                out errorStatus : StatusReport;
            }
            then done;
        }
    }
    
    part connectedDevicesSystem {
        doc /* 
            The Connected Devices System orchestrates seamless communication and 
            coordination among distributed IoT sensors, actuators, and cloud services.
            Its primary function is to continuously collect environmental data from 
            edge sensors, securely transmit it through a network gateway, aggregate 
            and analyze the data in a cloud platform, and distribute intelligent 
            control commands back to actuator devices for automated responses and 
            system optimization.
        */
        
        part sensor1 : IoTSensor {
            attribute :>> id = "SENSOR-001";
            attribute :>> batteryCapacity = 5000.0;
            perform action :>> collectSensorData;
        }
        
        part sensor2 : IoTSensor {
            attribute :>> id = "SENSOR-002";
            attribute :>> batteryCapacity = 5000.0;
            perform action :>> collectSensorData;
        }
        
        part sensor3 : IoTSensor {
            attribute :>> id = "SENSOR-003";
            attribute :>> batteryCapacity = 5000.0;
            perform action :>> collectSensorData;
        }
        
        part gateway : NetworkGateway {
            attribute :>> maxConnections = 100;
            perform action :>> routeMessages;
        }
        
        part security : SecurityModule {
            attribute :>> encryptionAlgorithm = "AES-256";
            attribute :>> keyRotationInterval = 86400.0 [SI::s];
            perform action :>> secureData;
        }
        
        part cloud : CloudPlatform {
            attribute :>> storageCapacity = 1.0e12;
            attribute :>> processingPower = 1000.0 [SI::W];
            perform action :>> processDeviceData;
        }
        
        part actuator1 : ActuatorDevice {
            attribute :>> id = "ACTUATOR-001";
            attribute :>> actuatorType = "HVAC";
            perform action :>> executeCommand;
        }
        
        part actuator2 : ActuatorDevice {
            attribute :>> id = "ACTUATOR-002";
            attribute :>> actuatorType = "Lighting";
            perform action :>> executeCommand;
        }
        
        connect sensor1.networkPort to gateway.devicePort[1];
        connect sensor2.networkPort to gateway.devicePort[2];
        connect sensor3.networkPort to gateway.devicePort[3];
        connect gateway.cloudPort to security.inputPort;
        connect security.outputPort to cloud.networkInterface;
        connect cloud.apiPort to actuator1.controlPort;
        connect cloud.apiPort to actuator2.controlPort;
        connect actuator1.networkPort to gateway.devicePort[4];
        connect actuator2.networkPort to gateway.devicePort[5];
    }
    
    requirement <'REQ-001'> primaryFunctionRequirement {
        doc /* 
            The Connected Devices System shall collect sensor data from distributed 
            IoT devices, transmit it securely to a cloud platform for analysis, and 
            deliver control commands to actuators with end-to-end latency not 
            exceeding 2 seconds under normal operating conditions.
        */
        
        subject system : connectedDevicesSystem;
        
        require constraint latencyConstraint {
            attribute maxLatency : ISQ::TimeValue = 2.0 [SI::s];
        }
    }
    
    requirement <'REQ-002'> dataSecurityRequirement {
        doc /* 
            All data transmitted between devices and the cloud platform shall be 
            encrypted using AES-256 encryption with key rotation every 24 hours.
        */
        
        subject securityModule : SecurityModule;
        
        require constraint encryptionConstraint {
            securityModule.encryptionAlgorithm == "AES-256"
        }
        
        require constraint keyRotationConstraint {
            securityModule.keyRotationInterval <= 86400.0 [SI::s]
        }
    }
    
    requirement <'REQ-003'> scalabilityRequirement {
        doc /* 
            The network gateway shall support a minimum of 100 concurrent device 
            connections with graceful degradation and load balancing under peak loads.
        */
        
        subject gatewaySystem : NetworkGateway;
        
        require constraint connectionCapacity {
            gatewaySystem.maxConnections >= 100
        }
    }
    
    requirement <'REQ-004'> reliabilityRequirement {
        doc /* 
            IoT sensors shall operate continuously for a minimum of 30 days on 
            battery power with a sampling rate of 1 Hz before requiring recharge.
        */
        
        subject sensors : IoTSensor;
        
        require constraint batteryLifeConstraint {
            attribute minOperatingTime : ISQ::TimeValue = 2592000.0 [SI::s];
            sensors.batteryCapacity >= 5000.0
        }
    }
    
    requirement <'REQ-005'> dataIntegrityRequirement {
        doc /* 
            The cloud platform shall validate and authenticate all incoming sensor 
            data before processing, rejecting invalid or corrupted messages.
        */
        
        subject cloudSystem : CloudPlatform;
    }
    
    requirement systemRequirements {
        doc /* Top-level system requirements for the Connected Devices System. */
        
        require primaryFunctionRequirement;
        require dataSecurityRequirement;
        require scalabilityRequirement;
        require reliabilityRequirement;
        require dataIntegrityRequirement;
    }
}
