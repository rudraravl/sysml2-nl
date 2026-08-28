package IoT_Environmental_Monitoring_System {

    import ScalarValues::*;
    import ISQ::*;
    import ISQ::TemperatureUnit;
    import ISQ::ThermodynamicTemperature;
    import ISQ::Mass;
    import ISQ::Time;

    // ---------- Value Types with Units ----------
    value def TemperatureValue :> Real {
        unit unit TemperatureUnitValue :> TemperatureUnit { /* Celsius */ }
    }

    value def HumidityValue :> Real {
        unit unit PercentValue :> One { }
        attribute redefinition magnitude : Real [1] = 100;
    }

    value def AirQualityValue :> Real {
        unit unit PPMValue :> One { }
        doc /* Parts per million of CO2 equivalent */
    }

    value def LightLevelValue :> Real {
        unit unit LuxValue :> One { }
    }

    value def FanSpeedValue :> Real {
        unit unit RPMValue :> One { }
    }

    value def PowerValue :> Real {
        unit unit WattValue :> One { }
    }

    // ---------- Item Definitions ----------
    item def SensorReading {
        attribute deviceId : String;
        attribute zoneId : String;
        attribute timestamp : String;
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute airQuality : AirQualityValue;
        attribute lightLevel : LightLevelValue;
    }

    item def AggregatedData {
        attribute gatewayId : String;
        attribute timestamp : String;
        attribute readings : SensorReading[0..*];
    }

    item def ControlCommand {
        attribute targetDeviceId : String;
        attribute zoneId : String;
        attribute hvacMode : HVACMode;
        attribute fanSpeed : FanSpeedValue;
        attribute issuedAt : String;
    }

    item def AlertNotification {
        attribute alertId : String;
        attribute zoneId : String;
        attribute severity : AlertSeverity;
        attribute message : String;
        attribute timestamp : String;
    }

    item def DashboardUpdate {
        attribute zoneId : String;
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute airQuality : AirQualityValue;
        attribute lightLevel : LightLevelValue;
        attribute hvacMode : HVACMode;
        attribute fanSpeed : FanSpeedValue;
        attribute timestamp : String;
    }

    item def HistoricalReport {
        attribute zoneId : String;
        attribute periodStart : String;
        attribute periodEnd : String;
        attribute averageTemperature : TemperatureValue;
        attribute averageHumidity : HumidityValue;
        attribute trendSummary : String;
    }

    item def ManualOverride {
        attribute zoneId : String;
        attribute userId : String;
        attribute hvacMode : HVACMode;
        attribute fanSpeed : FanSpeedValue;
        attribute timestamp : String;
    }

    // ---------- Enumerations ----------
    enum def HVACMode { off; heating; cooling; ventilating; }
    enum def AlertSeverity { info; warning; critical; }
    enum def ConnectionState { disconnected; connected; authenticated; }

    // ---------- Port Definitions ----------
    port def SensorOutPort {
        out reading : SensorReading;
    }

    port def GatewaySensorInPort {
        in reading : SensorReading;
    }

    port def GatewayCloudOutPort {
        out data : AggregatedData;
        in command : ControlCommand;
    }

    port def CloudGatewayInPort {
        in data : AggregatedData;
        out command : ControlCommand;
    }

    port def GatewayActuatorOutPort {
        out command : ControlCommand;
    }

    port def ActuatorInPort {
        in command : ControlCommand;
    }

    port def CloudAppPort {
        out dashboard : DashboardUpdate;
        out alert : AlertNotification;
        out report : HistoricalReport;
        in override : ManualOverride;
    }

    port def AppCloudPort {
        in dashboard : DashboardUpdate;
        in alert : AlertNotification;
        in report : HistoricalReport;
        out override : ManualOverride;
    }

    // ---------- Sensor Suite ----------
    part def SensorSuite {
        port sensorOut : SensorOutPort;

        part temperatureSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part airQualitySensor : AirQualitySensor;
        part lightSensor : LightSensor;

        action def collectReadings {
            in zoneId : String;
            out reading : SensorReading;
        }

        action collect : collectReadings {
            // Aggregates individual sensor values into a single reading
        }

        connection tempConn : temperatureSensor.valueOut connect sensorOut.reading.temperature;
        connection humidConn : humiditySensor.valueOut connect sensorOut.reading.humidity;
        connection airConn : airQualitySensor.valueOut connect sensorOut.reading.airQuality;
        connection lightConn : lightSensor.valueOut connect sensorOut.reading.lightLevel;
    }

    part def TemperatureSensor {
        out valueOut : TemperatureValue;
        attribute deviceId : String;
        attribute samplingInterval : TimeValue = 5 [s];
    }

    part def HumiditySensor {
        out valueOut : HumidityValue;
        attribute deviceId : String;
        attribute samplingInterval : TimeValue = 5 [s];
    }

    part def AirQualitySensor {
        out valueOut : AirQualityValue;
        attribute deviceId : String;
        attribute samplingInterval : TimeValue = 10 [s];
    }

    part def LightSensor {
        out valueOut : LightLevelValue;
        attribute deviceId : String;
        attribute samplingInterval : TimeValue = 15 [s];
    }

    value def TimeValue :> Real {
        unit unit SecondValue :> One { }
    }

    // ---------- Actuator Suite ----------
    part def ActuatorSuite {
        port actuatorIn : ActuatorInPort;

        part hvacUnit : HVACUnit;
        part ventilationFan : VentilationFan;

        connection cmdSplit : actuatorIn.command connect hvacUnit.commandIn;
        connection cmdSplit2 : actuatorIn.command connect ventilationFan.commandIn;
    }

    part def HVACUnit {
        in commandIn : ControlCommand;
        attribute deviceId : String;
        attribute currentMode : HVACMode = HVACMode::off;
        attribute powerConsumption : PowerValue = 0 [W];

        state machine behavior : HVACStateMachine {
            entry; then Off;

            state Off;
            state Heating;
            state Cooling;
            state Ventilating;

            transition off_to_heating
                source Off
                target Heating
                accept commandIn
                guard commandIn.hvacMode == HVACMode::heating
                do action setHeating;

            transition off_to_cooling
                source Off
                target Cooling
                accept commandIn
                guard commandIn.hvacMode == HVACMode::cooling
                do action setCooling;

            transition off_to_ventilating
                source Off
                target Ventilating
                accept commandIn
                guard commandIn.hvacMode == HVACMode::ventilating
                do action setVentilating;

            transition active_to_off
                source Heating
                target Off
                accept commandIn
                guard commandIn.hvacMode == HVACMode::off
                do action setOff;

            transition cooling_to_off
                source Cooling
                target Off
                accept commandIn
                guard commandIn.hvacMode == HVACMode::off
                do action setOff;

            transition vent_to_off
                source Ventilating
                target Off
                accept commandIn
                guard commandIn.hvacMode == HVACMode::off
                do action setOff;
        }

        action setHeating { assign currentMode = HVACMode::heating; assign powerConsumption = 1500 [W]; }
        action setCooling { assign currentMode = HVACMode::cooling; assign powerConsumption = 1800 [W]; }
        action setVentilating { assign currentMode = HVACMode::ventilating; assign powerConsumption = 400 [W]; }
        action setOff { assign currentMode = HVACMode::off; assign powerConsumption = 0 [W]; }
    }

    part def VentilationFan {
        in commandIn : ControlCommand;
        attribute deviceId : String;
        attribute currentSpeed : FanSpeedValue = 0 [rpm];

        action adjustSpeed {
            in cmd : ControlCommand;
            then assign currentSpeed = cmd.fanSpeed;
        }
    }

    // ---------- Zone ----------
    part def Zone {
        attribute zoneId : String;
        attribute targetTemperature : TemperatureValue = 22 [degC];
        attribute targetHumidity : HumidityValue = 50 [%];
        attribute targetAirQuality : AirQualityValue = 600 [ppm];
        attribute targetLightLevel : LightLevelValue = 300 [lux];

        part sensorSuite : SensorSuite;
        part actuatorSuite : ActuatorSuite;

        connection sensorToActuatorLocal :> Connection {
            // Local pass-through not required; gateway mediates
        }
    }

    // ---------- IoT Gateway ----------
    part def IoTGateway {
        attribute gatewayId : String;
        attribute connectionState : ConnectionState = ConnectionState::disconnected;

        port sensorIn : GatewaySensorInPort[0..*];
        port cloudPort : GatewayCloudOutPort;
        port actuatorOut : GatewayActuatorOutPort[0..*];

        attribute aggregatedBuffer : SensorReading[0..*];

        action def processData {
            in readings : SensorReading[0..*];
            out aggregated : AggregatedData;
        }

        action aggregate : processData {
            // Aggregates incoming readings, attaches gatewayId and timestamp
        }

        action forwardToCloud {
            in data : AggregatedData;
        }

        action forwardToActuator {
            in command : ControlCommand;
        }

        state machine gatewayBehavior : GatewayStateMachine {
            entry; then Disconnected;

            state Disconnected;
            state Connected;
            state Authenticated;

            transition connect
                source Disconnected
                target Connected
                accept networkAvailable;

            transition authenticate
                source Connected
                target Authenticated
                accept credentialsValid;

            transition disconnect
                source Authenticated
                target Disconnected
                accept connectionLost;
        }

        flow from sensorIn.reading to aggregate.readings;
        flow from aggregate.aggregated to cloudPort.data;
        flow from cloudPort.command to forwardToActuator.command;
        flow from forwardToActuator.command to actuatorOut.command;
    }

    // ---------- Cloud Platform ----------
    part def CloudPlatform {
        attribute platformId : String;

        port gatewayPort : CloudGatewayInPort[0..*];
        port appPort : CloudAppPort[0..*];

        attribute storedData : AggregatedData[0..*];
        attribute activeAlerts : AlertNotification[0..*];

        action def storeData {
            in data : AggregatedData;
        }

        action def analyzeData {
            in data : AggregatedData;
            out command : ControlCommand;
            out alert : AlertNotification;
        }

        action def generateReport {
            in zoneId : String;
            out report : HistoricalReport;
        }

        action def applyOverride {
            in override : ManualOverride;
            out command : ControlCommand;
        }

        action store : storeData;
        action analyze : analyzeData;
        action reportGen : generateReport;
        action overrideHandler : applyOverride;

        flow from gatewayPort.data to store.data;
        flow from gatewayPort.data to analyze.data;
        flow from analyze.command to gatewayPort.command;
        flow from analyze.alert to appPort.alert;
        flow from appPort.override to overrideHandler.override;
        flow from overrideHandler.command to gatewayPort.command;
        flow from reportGen.report to appPort.report;

        // Dashboard update generation
        action def buildDashboard {
            in data : AggregatedData;
            out dashboard : DashboardUpdate;
        }

        action dashboardBuilder : buildDashboard;
        flow from store.data to dashboardBuilder.data;
        flow from dashboardBuilder.dashboard to appPort.dashboard;
    }

    // ---------- Mobile Application ----------
    part def MobileApp {
        attribute userId : String;

        port cloudPort : AppCloudPort;

        attribute currentDashboard : DashboardUpdate[0..*];
        attribute alertLog : AlertNotification[0..*];

        action def displayDashboard {
            in dashboard : DashboardUpdate;
        }

        action def displayAlert {
            in alert : AlertNotification;
        }

        action def viewReport {
            in report : HistoricalReport;
        }

        action def sendOverride {
            in zoneId : String;
            in hvacMode : HVACMode;
            in fanSpeed : FanSpeedValue;
            out override : ManualOverride;
        }

        action dashboardDisplay : displayDashboard;
        action alertDisplay : displayAlert;
        action reportViewer : viewReport;
        action overrideSender : sendOverride;

        flow from cloudPort.dashboard to dashboardDisplay.dashboard;
        flow from cloudPort.alert to alertDisplay.alert;
        flow from cloudPort.report to reportViewer.report;
        flow from overrideSender.override to cloudPort.override;
    }

    // ---------- System Assembly ----------
    part system : EnvironmentalMonitoringSystem;

    part def EnvironmentalMonitoringSystem {
        attribute systemId : String = "IOT-EMS-001";

        part zones : Zone[1..*];
        part gateway : IoTGateway;
        part cloud : CloudPlatform;
        part mobileApp : MobileApp;

        // Connect each zone's sensor suite to the gateway
        connection def ZoneSensorToGateway {
            end sourceSensor : SensorOutPort;
            end destGateway : GatewaySensorInPort;
        }

        connection def GatewayToCloud {
            end gatewaySide : GatewayCloudOutPort;
            end cloudSide : CloudGatewayInPort;
        }

        connection def CloudToGatewayCommand {
            end cloudSide : CloudGatewayInPort;
            end gatewaySide : GatewayCloudOutPort;
        }

        connection def GatewayToActuator {
            end gatewaySide : GatewayActuatorOutPort;
            end actuatorSide : ActuatorInPort;
        }

        connection def CloudToApp {
            end cloudSide : CloudAppPort;
            end appSide : AppCloudPort;
        }

        // Bindings
        binding zones.sensorSuite.sensorOut connect gateway.sensorIn;
        binding gateway.cloudPort connect cloud.gatewayPort;
        binding cloud.gatewayPort connect gateway.cloudPort;
        binding gateway.actuatorOut connect zones.actuatorSuite.actuatorIn;
        binding cloud.appPort connect mobileApp.cloudPort;
    }

    // ---------- Requirements ----------
    requirement def EnvironmentalMonitoringRequirement {
        doc /* The system shall monitor and optimize indoor climate conditions across multiple zones. */
    }

    requirement def SensorDataCollectionRequirement :> EnvironmentalMonitoringRequirement {
        doc /* Each zone shall continuously collect temperature, humidity, air quality, and ambient light data. */
        subject sensorSuite : SensorSuite;
        attribute samplingIntervalMax : TimeValue = 15 [s];
        require sensorSuite.sensorOut.reading.temperature != null;
        require sensorSuite.sensorOut.reading.humidity != null;
        require sensorSuite.sensorOut.reading.airQuality != null;
        require sensorSuite.sensorOut.reading.lightLevel != null;
    }

    requirement def GatewayAggregationRequirement :> EnvironmentalMonitoringRequirement {
        doc /* The gateway shall aggregate sensor data with timestamp and device ID and transmit to the cloud. */
        subject gateway : IoTGateway;
        require gateway.cloudPort.data != null;
    }

    requirement def CloudAnalyticsRequirement :> EnvironmentalMonitoringRequirement {
        doc /* The cloud platform shall store data, perform analytics, detect anomalies, and generate control commands. */
        subject cloud : CloudPlatform;
        require cloud.gatewayPort.command != null;
    }

    requirement def ActuatorControlRequirement :> EnvironmentalMonitoringRequirement {
        doc /* Actuators shall execute control commands including HVAC mode and fan speed adjustments. */
        subject actuatorSuite : ActuatorSuite;
        require actuatorSuite.actuatorIn.command != null;
    }

    requirement def MobileAppRequirement :> EnvironmentalMonitoringRequirement {
        doc /* The mobile app shall display real-time dashboards, alerts, historical reports, and allow manual override. */
        subject app : MobileApp;
        require app.cloudPort.dashboard != null;
        require app.cloudPort.alert != null;
        require app.cloudPort.report != null;
        require app.cloudPort.override != null;
    }

    requirement def AutonomousControlRequirement :> EnvironmentalMonitoringRequirement {
        doc /* The system shall autonomously activate cooling when temperature exceeds threshold and increase fan speed when air quality drops. */
        subject system : EnvironmentalMonitoringSystem;
        attribute temperatureThreshold : TemperatureValue = 26 [degC];
        attribute airQualityThreshold : AirQualityValue = 800 [ppm];
    }

    requirement def SecurityRequirement :> EnvironmentalMonitoringRequirement {
        doc /* Data transmission between gateway and cloud shall be secure. */
        subject gateway : IoTGateway;
        require gateway.connectionState == ConnectionState::authenticated;
    }

    requirement systemRequirement : EnvironmentalMonitoringRequirement {
        satisfy by system;
    }

    requirement sensorReq : SensorDataCollectionRequirement {
        satisfy by zones.sensorSuite;
    }

    requirement gatewayReq : GatewayAggregationRequirement {
        satisfy by gateway;
    }

    requirement cloudReq : CloudAnalyticsRequirement {
        satisfy by cloud;
    }

    requirement actuatorReq : ActuatorControlRequirement {
        satisfy by zones.actuatorSuite;
    }

    requirement appReq : MobileAppRequirement {
        satisfy by mobileApp;
    }

    requirement autonomousReq : AutonomousControlRequirement {
        satisfy by system;
    }

    requirement securityReq : SecurityRequirement {
        satisfy by gateway;
    }

}
