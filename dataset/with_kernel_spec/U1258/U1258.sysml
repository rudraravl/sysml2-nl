package WoTSmartHome {
    private import ScalarValues::*;

    value type TemperatureValue :> Real;
    value type HumidityValue :> Real;
    value type BrightnessValue :> Real;

    enum def ThermostatMode {
        enum heating;
        enum cooling;
        enum off;
    }

    item def TemperatureReading {
        attribute value : TemperatureValue;
        attribute timestamp : String;
        attribute thingId : String;
    }

    item def HumidityReading {
        attribute value : HumidityValue;
        attribute timestamp : String;
        attribute thingId : String;
    }

    item def ThermostatCommand {
        attribute mode : ThermostatMode;
        attribute targetTemp : TemperatureValue;
        attribute thingId : String;
    }

    item def LightCommand {
        attribute on : Boolean;
        attribute brightness : BrightnessValue;
        attribute thingId : String;
    }

    item def DeviceRegistration {
        attribute thingId : String;
        attribute deviceType : String;
        attribute capabilities : String;
    }

    item def DiscoveryQuery {
        attribute deviceType : String;
    }

    item def DiscoveryResponse {
        attribute deviceList : String;
    }

    port def SensorReportPort {
        in tempReport : TemperatureReading;
        in humReport : HumidityReading;
    }

    port def ActuatorCommandPort {
        in thermoCmd : ThermostatCommand;
        in lightCmd : LightCommand;
    }

    port def GatewayDevicePort {
        in tempReport : TemperatureReading;
        in humReport : HumidityReading;
        out thermoCmd : ThermostatCommand;
        out lightCmd : LightCommand;
    }

    port def GatewayAppPort {
        out tempReport : TemperatureReading;
        out humReport : HumidityReading;
        in thermoCmd : ThermostatCommand;
        in lightCmd : LightCommand;
    }

    port def AppAnalysisPort {
        in tempReport : TemperatureReading;
        in humReport : HumidityReading;
        out thermoCmd : ThermostatCommand;
        out lightCmd : LightCommand;
    }

    port def DirectoryRegistrationPort {
        in registration : DeviceRegistration;
        in query : DiscoveryQuery;
        out queryResult : DiscoveryResponse;
    }

    interface def SensorToGatewayInterface {
        end source : ~SensorReportPort;
        end target : GatewayDevicePort;
    }

    interface def AppGatewayInterface {
        end gateway : GatewayAppPort;
        end app : AppAnalysisPort;
    }

    interface def GatewayToActuatorInterface {
        end source : GatewayDevicePort;
        end target : ActuatorCommandPort;
    }

    interface def DeviceRegistrationInterface {
        end source : ~DirectoryRegistrationPort;
        end target : DirectoryRegistrationPort;
    }

    part def Thing {
        attribute thingId : String;
        attribute deviceType : String;
        port registrationPort : ~DirectoryRegistrationPort;
    }

    abstract part def Sensor :> Thing {
        port reportPort : ~SensorReportPort;
    }

    part def TemperatureSensor :> Sensor {
        :>> deviceType = "TemperatureSensor";
        attribute currentTemp : TemperatureValue;
        state TempSensorState {
            entry send new DeviceRegistration(thingId, deviceType, "temperature") via registrationPort.registration;
            then Idle;
            state Idle;
        }
    }

    part def HumiditySensor :> Sensor {
        :>> deviceType = "HumiditySensor";
        attribute currentHumidity : HumidityValue;
        state HumiditySensorState {
            entry send new DeviceRegistration(thingId, deviceType, "humidity") via registrationPort.registration;
            then Idle;
            state Idle;
        }
    }

    abstract part def Actuator :> Thing {
        port commandPort : ActuatorCommandPort;
    }

    part def SmartThermostat :> Actuator {
        :>> deviceType = "SmartThermostat";
        attribute mode : ThermostatMode = ThermostatMode::off;
        attribute targetTemp : TemperatureValue;
        state ThermostatState {
            entry send new DeviceRegistration(thingId, deviceType, "heating,cooling") via registrationPort.registration;
            then Idle;
            state Idle;
            accept cmd : ThermostatCommand via commandPort.thermoCmd
            then Idle;
        }
    }

    part def SmartLight :> Actuator {
        :>> deviceType = "SmartLight";
        attribute on : Boolean = false;
        attribute brightness : BrightnessValue = 0.0;
        state LightState {
            entry send new DeviceRegistration(thingId, deviceType, "onOff,brightness") via registrationPort.registration;
            then Idle;
            state Idle;
            accept cmd : LightCommand via commandPort.lightCmd
            then Idle;
        }
    }

    part def WoTDirectory {
        attribute registeredDevices : String = "";
        port directoryPort : DirectoryRegistrationPort;
        state DirectoryState {
            state Listening;
            accept reg : DeviceRegistration via directoryPort.registration
            then Listening;
            accept q : DiscoveryQuery via directoryPort.query
            do action {
                first start;
                then send new DiscoveryResponse(registeredDevices) via directoryPort.queryResult;
            }
            then Listening;
        }
    }

    part def WoTGateway {
        port devicePort : GatewayDevicePort;
        port appPort : GatewayAppPort;
        state GatewayState {
            state Idle;
            accept t : TemperatureReading via devicePort.tempReport
            do action {
                first start;
                then send t via appPort.tempReport;
            }
            then Idle;
            accept h : HumidityReading via devicePort.humReport
            do action {
                first start;
                then send h via appPort.humReport;
            }
            then Idle;
            accept tc : ThermostatCommand via appPort.thermoCmd
            do action {
                first start;
                then send tc via devicePort.thermoCmd;
            }
            then Idle;
            accept lc : LightCommand via appPort.lightCmd
            do action {
                first start;
                then send lc via devicePort.lightCmd;
            }
            then Idle;
        }
    }

    part def ApplicationServer {
        attribute tempThresholdHigh : TemperatureValue = 25.0;
        attribute tempThresholdLow : TemperatureValue = 18.0;
        attribute latestTemp : TemperatureValue;
        attribute latestHumidity : HumidityValue;
        port analysisPort : AppAnalysisPort;
        state AppServerState {
            state Monitoring;
            accept t : TemperatureReading via analysisPort.tempReport
            do action {
                first start;
                then send new ThermostatCommand(ThermostatMode::cooling, tempThresholdLow, "thermostat_01") via analysisPort.thermoCmd;
            }
            then Monitoring;
            accept h : HumidityReading via analysisPort.humReport
            do action {
                first start;
                then send new LightCommand(true, 75.0, "light_01") via analysisPort.lightCmd;
            }
            then Monitoring;
        }
    }

    part def WoTSystem {
        part directory : WoTDirectory;
        part gateway : WoTGateway;
        part appServer : ApplicationServer;

        part tempSensor1 : TemperatureSensor {
            :>> thingId = "temp_sensor_01";
            :>> currentTemp = 26.0;
        }
        part humiditySensor1 : HumiditySensor {
            :>> thingId = "humidity_sensor_01";
            :>> currentHumidity = 55.0;
        }
        part thermostat1 : SmartThermostat {
            :>> thingId = "thermostat_01";
            :>> targetTemp = 22.0;
        }
        part light1 : SmartLight {
            :>> thingId = "light_01";
        }

        interface tempSensorRegistration : DeviceRegistrationInterface
            connect tempSensor1.registrationPort to directory.directoryPort;
        interface humiditySensorRegistration : DeviceRegistrationInterface
            connect humiditySensor1.registrationPort to directory.directoryPort;
        interface thermostatRegistration : DeviceRegistrationInterface
            connect thermostat1.registrationPort to directory.directoryPort;
        interface lightRegistration : DeviceRegistrationInterface
            connect light1.registrationPort to directory.directoryPort;

        interface tempToGateway : SensorToGatewayInterface
            connect tempSensor1.reportPort to gateway.devicePort;
        interface humidityToGateway : SensorToGatewayInterface
            connect humiditySensor1.reportPort to gateway.devicePort;

        interface appGatewayLink : AppGatewayInterface
            connect gateway.appPort to appServer.analysisPort;

        interface gatewayToThermostat : GatewayToActuatorInterface
            connect gateway.devicePort to thermostat1.commandPort;
        interface gatewayToLight : GatewayToActuatorInterface
            connect gateway.devicePort to light1.commandPort;
    }

    requirement DeviceRegistrationRequirement {
        doc /* Every Thing shall register itself with the WoT Directory upon initialization. */
    }

    requirement SensorReportingRequirement {
        doc /* Sensors shall periodically report readings to the Application Server via the WoT Gateway. */
    }

    requirement ActuatorControlRequirement {
        doc /* Actuators shall accept commands from the Application Server via the WoT Gateway and change state accordingly. */
    }

    requirement GatewayRoutingRequirement {
        doc /* The WoT Gateway shall route all sensor data to the Application Server and all commands to the correct actuator. */
    }

    requirement DirectoryDiscoveryRequirement {
        doc /* The WoT Directory shall maintain a registry of all devices and respond to discovery queries. */
    }

    requirement AutomationLoopRequirement {
        doc /* The system shall continuously monitor environmental conditions and control actuators to maintain optimal conditions. */
    }

    part def WoTSystemWithRequirements :> WoTSystem {
        satisfy DeviceRegistrationRequirement by tempSensor1;
        satisfy DeviceRegistrationRequirement by humiditySensor1;
        satisfy DeviceRegistrationRequirement by thermostat1;
        satisfy DeviceRegistrationRequirement by light1;
        satisfy SensorReportingRequirement by tempSensor1;
        satisfy SensorReportingRequirement by humiditySensor1;
        satisfy ActuatorControlRequirement by thermostat1;
        satisfy ActuatorControlRequirement by light1;
        satisfy GatewayRoutingRequirement by gateway;
        satisfy DirectoryDiscoveryRequirement by directory;
        satisfy AutomationLoopRequirement by self;
    }
}
