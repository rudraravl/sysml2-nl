package WoT_SmartHome_System {
    import ScalarValues::*;

    // ===== Units =====
    unit def Celsius;
    unit def Percent;
    unit def Watt;
    unit def Second;

    // ===== Value Types =====
    value def TemperatureCelsius :> Real {
        unit Celsius;
    }
    value def HumidityPercent :> Real {
        unit Percent;
    }
    value def BrightnessPercent :> Real {
        unit Percent;
    }
    value def PowerWatt :> Real {
        unit Watt;
    }
    value def DurationSeconds :> Real {
        unit Second;
    }

    // ===== Attribute Types =====
    attribute def DeviceId :> String;
    attribute def EndpointURL :> String;
    attribute def Capability :> String;
    attribute def Timestamp :> String;

    // ===== Enumerations =====
    enum def ThermostatMode {
        off;
        heating;
        cooling;
        idle;
    }

    enum def LightState {
        on;
        off;
    }

    enum def DeviceStatus {
        unregistered;
        registering;
        online;
        offline;
        error;
    }

    enum def RegistrationStatus {
        success;
        failure;
    }

    enum def GatewayOperationMode {
        ready;
        forwardingData;
        forwardingCommand;
        authenticating;
    }

    // ===== Item Definitions =====
    item def SensorReading {
        attribute deviceId : DeviceId;
        attribute timestamp : Timestamp;
    }

    item def TemperatureReading :> SensorReading {
        attribute value : TemperatureCelsius;
    }

    item def HumidityReading :> SensorReading {
        attribute value : HumidityPercent;
    }

    item def ActuatorCommand {
        attribute deviceId : DeviceId;
        attribute timestamp : Timestamp;
    }

    item def ThermostatCommand :> ActuatorCommand {
        attribute mode : ThermostatMode;
        attribute targetTemp : TemperatureCelsius;
    }

    item def LightCommand :> ActuatorCommand {
        attribute state : LightState;
        attribute brightness : BrightnessPercent;
    }

    item def ThingDescription {
        attribute deviceId : DeviceId;
        attribute endpoint : EndpointURL;
        attribute capabilities : Capability[0..*];
    }

    item def RegistrationRequest {
        attribute description : ThingDescription;
    }

    item def RegistrationAck {
        attribute status : RegistrationStatus;
        attribute deviceId : DeviceId;
    }

    item def DiscoveryQuery {
        attribute capability : Capability;
    }

    item def DiscoveryResult {
        attribute descriptions : ThingDescription[0..*];
    }

    // ===== Port Definitions =====
    port def DeviceWebPort {
        out reading : SensorReading;
        in command : ActuatorCommand;
        out td : ThingDescription;
    }

    port def GatewayAppPort {
        out sensorData : SensorReading;
        in command : ActuatorCommand;
    }

    port def DirectoryPort {
        in registration : RegistrationRequest;
        out ack : RegistrationAck;
        in query : DiscoveryQuery;
        out result : DiscoveryResult;
    }

    // ===== Thing Abstraction =====
    abstract part def Thing {
        attribute id : DeviceId;
        attribute endpoint : EndpointURL;
        attribute status : DeviceStatus;
        port webPort : DeviceWebPort;

        action def publishTD;

        exhibit state def Lifecycle {
            entry; then Unregistered;
            state Unregistered;
            transition beginRegistration
                first Unregistered
                if status == DeviceStatus::registering
                then Registering;
            state Registering {
                entry action publishTD;
            }
            transition registrationComplete
                first Registering
                if status == DeviceStatus::online
                then Online;
            state Online;
            transition goOffline
                first Online
                if status == DeviceStatus::offline
                then Offline;
            state Offline;
            transition reconnect
                first Offline
                if status == DeviceStatus::online
                then Online;
            transition errorOccurred
                first Online
                if status == DeviceStatus::error
                then Error;
            state Error;
            transition recoverFromError
                first Error
                if status == DeviceStatus::online
                then Online;
        }
    }

    // ===== Sensor Abstraction =====
    abstract part def Sensor :> Thing {
        attribute samplingInterval : DurationSeconds;

        action def sample {
            out reading : SensorReading;
        }

        exhibit state def SamplingBehavior {
            entry; then Idle;
            state Idle;
            transition sampleTrigger
                first Idle
                if true
                then Sampling;
            state Sampling {
                do action sample;
            }
            transition sampleComplete
                first Sampling
                then Idle;
        }
    }

    // ===== Actuator Abstraction =====
    abstract part def Actuator :> Thing {
        action def executeCommand {
            in cmd : ActuatorCommand;
        }
    }

    // ===== Temperature Sensor =====
    part def TemperatureSensor :> Sensor {
        attribute currentTemp : TemperatureCelsius;
        attribute calibrationOffset : TemperatureCelsius = 0;

        action def takeSample :> sample {
            out reading : TemperatureReading;
        }
    }

    // ===== Humidity Sensor =====
    part def HumiditySensor :> Sensor {
        attribute currentHumidity : HumidityPercent;
        attribute calibrationOffset : HumidityPercent = 0;

        action def takeSample :> sample {
            out reading : HumidityReading;
        }
    }

    // ===== Smart Thermostat =====
    part def SmartThermostat :> Actuator {
        attribute mode : ThermostatMode = ThermostatMode::idle;
        attribute targetTemp : TemperatureCelsius = 22;
        attribute currentPower : PowerWatt;
        attribute maxPower : PowerWatt = 2000;

        action def executeCommand :> Actuator::executeCommand {
            in cmd : ThermostatCommand;
        }

        action def setMode {
            in newMode : ThermostatMode;
        }

        action def setTargetTemp {
            in newTemp : TemperatureCelsius;
        }

        exhibit state def Operation {
            entry; then Idle;
            state Idle;
            transition startHeating
                first Idle
                if mode == ThermostatMode::heating
                then Heating;
            state Heating {
                entry action setMode;
            }
            transition startCooling
                first Idle
                if mode == ThermostatMode::cooling
                then Cooling;
            state Cooling {
                entry action setMode;
            }
            transition stopHeating
                first Heating
                if mode == ThermostatMode::idle
                then Idle;
            transition stopCooling
                first Cooling
                if mode == ThermostatMode::idle
                then Idle;
            transition heatingToCooling
                first Heating
                if mode == ThermostatMode::cooling
                then Cooling;
            transition coolingToHeating
                first Cooling
                if mode == ThermostatMode::heating
                then Heating;
            transition heatingToOff
                first Heating
                if mode == ThermostatMode::off
                then Off;
            transition coolingToOff
                first Cooling
                if mode == ThermostatMode::off
                then Off;
            state Off;
            transition offToIdle
                first Off
                if mode == ThermostatMode::idle
                then Idle;
        }
    }

    // ===== Smart Light =====
    part def SmartLight :> Actuator {
        attribute state : LightState = LightState::off;
        attribute brightness : BrightnessPercent = 0;
        attribute maxBrightness : BrightnessPercent = 100;

        action def executeCommand :> Actuator::executeCommand {
            in cmd : LightCommand;
        }

        action def toggleState;
        action def adjustBrightness {
            in newBrightness : BrightnessPercent;
        }

        exhibit state def Operation {
            entry; then Off;
            state Off;
            transition turnOn
                first Off
                if state == LightState::on
                then On;
            state On;
            transition turnOff
                first On
                if state == LightState::off
                then Off;
            transition adjustWhileOn
                first On
                if brightness != brightness
                then Adjusting;
            state Adjusting {
                do action adjustBrightness;
            }
            transition adjustComplete
                first Adjusting
                then On;
        }
    }

    // ===== WoT Directory =====
    part def WoTDirectory {
        attribute registeredDevices : ThingDescription[0..*];
        attribute maxDevices : Integer = 1000;
        port directoryPort : DirectoryPort;

        action def registerDevice {
            in req : RegistrationRequest;
            out ack : RegistrationAck;
        }

        action def queryDevices {
            in q : DiscoveryQuery;
            out r : DiscoveryResult;
        }

        action def removeDevice {
            in deviceId : DeviceId;
        }

        action def updateDevice {
            in description : ThingDescription;
        }

        exhibit state def Operation {
            entry; then Listening;
            state Listening;
            transition handleRegistration
                first Listening
                if true
                then ProcessingRegistration;
            state ProcessingRegistration {
                do action registerDevice;
            }
            transition backToListening1
                first ProcessingRegistration
                then Listening;
            transition handleQuery
                first Listening
                if true
                then ProcessingQuery;
            state ProcessingQuery {
                do action queryDevices;
            }
            transition backToListening2
                first ProcessingQuery
                then Listening;
            transition handleRemoval
                first Listening
                if true
                then ProcessingRemoval;
            state ProcessingRemoval {
                do action removeDevice;
            }
            transition backToListening3
                first ProcessingRemoval
                then Listening;
        }
    }

    // ===== WoT Gateway =====
    part def WoTGateway {
        attribute routeTable : DeviceId[0..*];
        attribute mode : GatewayOperationMode = GatewayOperationMode::ready;
        port deviceSide : DeviceWebPort[0..*];
        port appSide : GatewayAppPort;

        action def routeCommand {
            in cmd : ActuatorCommand;
        }

        action def aggregateData {
            in readings : SensorReading[0..*];
            out aggregated : SensorReading;
        }

        action def authenticateRequest {
            in request : ActuatorCommand;
            out authorized : Boolean;
        }

        action def updateRouteTable {
            in deviceId : DeviceId;
        }

        exhibit state def Operation {
            entry; then Ready;
            state Ready;
            transition receiveSensorData
                first Ready
                if true
                then ForwardingSensorData;
            state ForwardingSensorData {
                do action aggregateData;
            }
            transition backToReady1
                first ForwardingSensorData
                then Ready;
            transition receiveCommand
                first Ready
                if true
                then Authenticating;
            state Authenticating {
                do action authenticateRequest;
            }
            transition authSuccess
                first Authenticating
                if true
                then ForwardingCommand;
            transition authFailure
                first Authenticating
                if true
                then Ready;
            state ForwardingCommand {
                do action routeCommand;
            }
            transition backToReady2
                first ForwardingCommand
                then Ready;
        }
    }

    // ===== Application Server =====
    part def ApplicationServer {
        attribute tempThresholdHigh : TemperatureCelsius = 26;
        attribute tempThresholdLow : TemperatureCelsius = 18;
        attribute humidityThreshold : HumidityPercent = 60;
        attribute lightBrightnessDefault : BrightnessPercent = 80;
        attribute knownDevices : ThingDescription[0..*];

        port appPort : GatewayAppPort;
        port discoveryPort : DirectoryPort;

        action def analyzeData {
            in readings : SensorReading[0..*];
            out commands : ActuatorCommand[0..*];
        }

        action def decideThermostat {
            in temp : TemperatureReading;
            out cmd : ThermostatCommand;
        }

        action def decideLight {
            in humidity : HumidityReading;
            out cmd : LightCommand;
        }

        action def discoverDevices {
            in q : DiscoveryQuery;
            out r : DiscoveryResult;
        }

        action def updateThresholds {
            in newHigh : TemperatureCelsius;
            in newLow : TemperatureCelsius;
        }

        exhibit state def ControlLoop {
            entry; then Monitoring;
            state Monitoring;
            transition dataReceived
                first Monitoring
                if true
                then Analyzing;
            state Analyzing {
                do action analyzeData;
            }
            transition analysisComplete
                first Analyzing
                if true
                then DecisionMaking;
            state DecisionMaking {
                do action decideThermostat;
                do action decideLight;
            }
            transition decisionsMade
                first DecisionMaking
                if true
                then SendingCommands;
            state SendingCommands;
            transition commandsSent
                first SendingCommands
                then Monitoring;
            transition discoverNewDevices
                first Monitoring
                if true
                then Discovering;
            state Discovering {
                do action discoverDevices;
            }
            transition discoveryComplete
                first Discovering
                then Monitoring;
        }
    }

    // ===== Connection Definitions =====
    connection def DeviceToGatewayConnection {
        end deviceEnd : DeviceWebPort;
        end gatewayEnd : DeviceWebPort;
    }

    connection def GatewayToAppConnection {
        end gatewayEnd : GatewayAppPort;
        end appEnd : GatewayAppPort;
    }

    connection def AppToDirectoryConnection {
        end appEnd : DirectoryPort;
        end directoryEnd : DirectoryPort;
    }

    // ===== System Composition =====
    part def WoTSystem {
        attribute systemId : String;
        attribute deploymentLocation : String;

        part directory : WoTDirectory;
        part gateway : WoTGateway;
        part appServer : ApplicationServer;
        part tempSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part thermostat : SmartThermostat;
        part light : SmartLight;

        connection : DeviceToGatewayConnection
            connect tempSensor.webPort to gateway.deviceSide;

        connection : DeviceToGatewayConnection
            connect humiditySensor.webPort to gateway.deviceSide;

        connection : DeviceToGatewayConnection
            connect thermostat.webPort to gateway.deviceSide;

        connection : DeviceToGatewayConnection
            connect light.webPort to gateway.deviceSide;

        connection : GatewayToAppConnection
            connect gateway.appSide to appServer.appPort;

        connection : AppToDirectoryConnection
            connect appServer.discoveryPort to directory.directoryPort;

        exhibit state def SystemOperation {
            entry; then Initializing;
            state Initializing;
            transition initComplete
                first Initializing
                if true
                then Running;
            state Running;
            transition shutdown
                first Running
                if true
                then Stopped;
            state Stopped;
        }
    }

    // ===== Requirements =====
    requirement def DeviceIdentificationRequirement {
        subject t : Thing;
        attribute requiredId : DeviceId;
        attribute requiredEndpoint : EndpointURL;
        objective {
            doc /* Each Thing shall have a unique identifier and a standard web-based interface endpoint for interaction. */
        }
    }

    requirement def DeviceDiscoveryRequirement {
        subject dir : WoTDirectory;
        objective {
            doc /* The WoT Directory shall maintain a registry of all devices, allowing new devices to register themselves and applications to query for available devices and their capabilities. */
        }
    }

    requirement def SecureGatewayRequirement {
        subject gw : WoTGateway;
        objective {
            doc /* The WoT Gateway shall serve as a single secure entry point, routing requests from the Application Server to the correct device and aggregating data coming back from devices. */
        }
    }

    requirement def AutomationControlRequirement {
        subject app : ApplicationServer;
        attribute tempHigh : TemperatureCelsius = 26;
        attribute tempLow : TemperatureCelsius = 18;
        attribute humidityMax : HumidityPercent = 60;
        objective {
            doc /* The Application Server shall receive and analyze combined sensor data from all sensors to determine environmental conditions and issue appropriate commands to actuators. */
        }
    }

    requirement def ClosedLoopMonitoringRequirement {
        subject sys : WoTSystem;
        objective {
            doc /* The system shall continuously monitor sensors, analyze data, and control actuators in a closed feedback loop without manual intervention to maintain optimal conditions. */
        }
    }

    requirement def SensorReportingRequirement {
        subject s : Sensor;
        attribute interval : DurationSeconds;
        objective {
            doc /* Sensors shall periodically report their readings to the Application Server via the Gateway at the specified sampling interval. */
        }
    }

    requirement def ActuatorControlRequirement {
        subject a : Actuator;
        objective {
            doc /* Actuators shall execute commands received from the Application Server via the Gateway to physically alter the environment. */
        }
    }

    requirement def ThermostatControlRequirement {
        subject th : SmartThermostat;
        objective {
            doc /* The Smart Thermostat shall support heating and cooling modes, accept target temperature settings, and transition between modes based on received commands. */
        }
    }

    requirement def LightControlRequirement {
        subject li : SmartLight;
        objective {
            doc /* The Smart Light shall support on/off control and brightness adjustment from 0 to 100 percent based on received commands. */
        }
    }

    requirement def InteroperabilityRequirement {
        subject sys : WoTSystem;
        objective {
            doc /* The system shall use standardized web technologies to enable interoperability between different device types from different manufacturers. */
        }
    }

    requirement def ScalabilityRequirement {
        subject dir : WoTDirectory;
        attribute maxDevices : Integer = 1000;
        objective {
            doc /* The system shall support expansion with new devices without requiring reconfiguration of existing components. */
        }
    }

    // ===== Satisfaction Relationships =====
    satisfaction DeviceIdentificationRequirement by Thing;
    satisfaction DeviceDiscoveryRequirement by WoTDirectory;
    satisfaction SecureGatewayRequirement by WoTGateway;
    satisfaction AutomationControlRequirement by ApplicationServer;
    satisfaction ClosedLoopMonitoringRequirement by WoTSystem;
    satisfaction SensorReportingRequirement by Sensor;
    satisfaction ActuatorControlRequirement by Actuator;
    satisfaction ThermostatControlRequirement by SmartThermostat;
    satisfaction LightControlRequirement by SmartLight;
    satisfaction InteroperabilityRequirement by WoTSystem;
    satisfaction ScalabilityRequirement by WoTDirectory;
}
