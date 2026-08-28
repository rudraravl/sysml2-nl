package SmartHomeAutomation {
    import ISQ::*;
    import ScalarValues::*;
    import ScalarFunctions::*;

    // ---- Value types with units ----
    value def TemperatureValue :> Real { 
        attribute unit : String = "degC"; 
        attribute min : Real = -40.0; 
        attribute max : Real = 85.0; 
    }
    value def BrightnessValue :> Real { 
        attribute unit : String = "lux"; 
        attribute min : Real = 0.0; 
    }
    value def PercentValue :> Real { 
        attribute unit : String = "%"; 
        attribute min : Real = 0.0; 
        attribute max : Real = 100.0; 
    }
    value def SignalStrength :> Real { 
        attribute unit : String = "dBm"; 
    }
    value def LatencyValue :> Real { 
        attribute unit : String = "ms"; 
    }
    value def MotionFlag :> Boolean;
    value def LockFlag :> Boolean;
    value def OnOffFlag :> Boolean;

    // ---- Item definitions ----
    item def SensorReading {
        attribute deviceId : String;
        attribute timestamp : Time;
        attribute location : String;
    }
    item def TemperatureReading :> SensorReading {
        attribute temperature : TemperatureValue;
    }
    item def MotionReading :> SensorReading {
        attribute motionDetected : MotionFlag;
    }
    item def LightLevelReading :> SensorReading {
        attribute brightness : BrightnessValue;
    }

    item def DeviceCommand {
        attribute targetDeviceId : String;
        attribute issuedAt : Time;
    }
    item def LightCommand :> DeviceCommand {
        attribute onOff : OnOffFlag;
        attribute brightness : PercentValue;
    }
    item def ThermostatCommand :> DeviceCommand {
        attribute setpoint : TemperatureValue;
    }
    item def LockCommand :> DeviceCommand {
        attribute lock : LockFlag;
    }

    item def DeviceStatus {
        attribute deviceId : String;
        attribute operationalState : String;
        attribute reportedAt : Time;
    }
    item def LightStatus :> DeviceStatus {
        attribute onOff : OnOffFlag;
        attribute brightness : PercentValue;
    }
    item def ThermostatStatus :> DeviceStatus {
        attribute currentSetpoint : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
    }
    item def LockStatus :> DeviceStatus {
        attribute locked : LockFlag;
    }

    item def Notification {
        attribute message : String;
        attribute priority : Integer;
        attribute timestamp : Time;
    }

    item def AutomationRule {
        attribute ruleId : String;
        attribute name : String;
        attribute conditionExpression : String;
        attribute actionDescription : String;
        attribute enabled : Boolean;
        attribute created : Time;
    }

    // ---- Port definitions ----
    port def SensorOutPort {
        out reading : SensorReading;
    }
    port def SensorInPort conjugate :> SensorOutPort {
        in reading : SensorReading;
    }
    port def CommandOutPort {
        out command : DeviceCommand;
    }
    port def CommandInPort conjugate :> CommandOutPort {
        in command : DeviceCommand;
    }
    port def StatusOutPort {
        out status : DeviceStatus;
    }
    port def StatusInPort conjugate :> StatusOutPort {
        in status : DeviceStatus;
    }
    port def AppToHubPort {
        out manualCommand : DeviceCommand;
        out ruleUpdate : AutomationRule;
        in statusReport : DeviceStatus;
        in notification : Notification;
    }
    port def HubToAppPort conjugate :> AppToHubPort {
        in manualCommand : DeviceCommand;
        in ruleUpdate : AutomationRule;
        out statusReport : DeviceStatus;
        out notification : Notification;
    }

    // ---- Abstract smart device ----
    part def SmartDevice {
        attribute deviceId : String;
        attribute location : String;
        attribute firmwareVersion : String;
        attribute signal : SignalStrength;
        port cmdPort : CommandInPort;
        port statusPort : StatusOutPort;

        state machine DeviceStateMachine {
            state Connected;
            state Idle;
            state Active;
            state Fault;

            transition init to Connected;
            transition Connected to Idle 
                when cmdPort.command is received 
                do send statusPort.status(DeviceStatus{deviceId = deviceId, operationalState = "Idle", reportedAt = now});
            transition Idle to Active 
                when cmdPort.command is received 
                do execute;
            transition Active to Idle 
                when execute.done 
                do send statusPort.status(DeviceStatus{deviceId = deviceId, operationalState = "Idle", reportedAt = now});
            transition Connected to Fault 
                when faultDetected;
            transition Idle to Fault 
                when faultDetected;
            transition Active to Fault 
                when faultDetected;
            transition Fault to Connected 
                when resetComplete;

            action execute {
                in command : DeviceCommand;
            }
            action faultDetected { out trigger : Boolean; }
            action resetComplete { out trigger : Boolean; }
        }
    }

    // ---- Sensors ----
    part def TemperatureSensor :> SmartDevice {
        attribute measuredTemperature : TemperatureValue;
        port sensorOut : SensorOutPort;
        action def SenseTemperature {
            out reading : TemperatureReading;
        }
        perform action senseTemp : SenseTemperature {
            assign sensorOut.reading = TemperatureReading{
                deviceId = deviceId, 
                timestamp = now, 
                location = location, 
                temperature = measuredTemperature
            };
        }
    }

    part def MotionSensor :> SmartDevice {
        attribute motionDetected : MotionFlag;
        port sensorOut : SensorOutPort;
        action def DetectMotion {
            out reading : MotionReading;
        }
        perform action detectMotion : DetectMotion {
            assign sensorOut.reading = MotionReading{
                deviceId = deviceId, 
                timestamp = now, 
                location = location, 
                motionDetected = motionDetected
            };
        }
    }

    part def LightSensor :> SmartDevice {
        attribute ambientBrightness : BrightnessValue;
        port sensorOut : SensorOutPort;
        action def MeasureBrightness {
            out reading : LightLevelReading;
        }
        perform action measureBrightness : MeasureBrightness {
            assign sensorOut.reading = LightLevelReading{
                deviceId = deviceId, 
                timestamp = now, 
                location = location, 
                brightness = ambientBrightness
            };
        }
    }

    // ---- Controllable devices ----
    part def SmartLight :> SmartDevice {
        attribute onOff : OnOffFlag = false;
        attribute brightness : PercentValue = 0.0;
        port sensorOut : SensorOutPort;
        action redefines execute {
            in command : LightCommand;
            do assign onOff = command.onOff;
            do assign brightness = command.brightness;
            do send statusPort.status(LightStatus{
                deviceId = deviceId, 
                operationalState = "Active", 
                reportedAt = now, 
                onOff = onOff, 
                brightness = brightness
            });
        }
    }

    part def SmartThermostat :> SmartDevice {
        attribute currentSetpoint : TemperatureValue = 22.0;
        attribute currentTemperature : TemperatureValue;
        port sensorOut : SensorOutPort;
        action redefines execute {
            in command : ThermostatCommand;
            do assign currentSetpoint = command.setpoint;
            do send statusPort.status(ThermostatStatus{
                deviceId = deviceId, 
                operationalState = "Active", 
                reportedAt = now, 
                currentSetpoint = currentSetpoint, 
                currentTemperature = currentTemperature
            });
        }
    }

    part def SmartDoorLock :> SmartDevice {
        attribute locked : LockFlag = true;
        action redefines execute {
            in command : LockCommand;
            do assign locked = command.lock;
            do send statusPort.status(LockStatus{
                deviceId = deviceId, 
                operationalState = "Active", 
                reportedAt = now, 
                locked = locked
            });
        }
    }

    // ---- Rule engine ----
    part def RuleEngine {
        attribute rules : AutomationRule[0..*];
        attribute sunsetPosition : Time;
        attribute isAway : Boolean = false;

        action def EvaluateRule {
            in reading : SensorReading;
            out matchedCommand : DeviceCommand optional;
            out notification : Notification optional;
        }

        action def ProcessReadings {
            in readings : SensorReading[0..*];
            out commands : DeviceCommand[0..*];
            out notifications : Notification[0..*];
            do for r in readings {
                perform action eval : EvaluateRule {
                    in reading = r;
                    out matchedCommand;
                    out notification;
                }
                if eval.matchedCommand.isPresent then send commands.append(eval.matchedCommand);
                if eval.notification.isPresent then send notifications.append(eval.notification);
            }
        }

        perform action process : ProcessReadings;
    }

    // ---- SmartThings Hub ----
    part def SmartThingsHub {
        attribute hubId : String;
        attribute maxLatency : LatencyValue = 500.0;
        port sensorPorts : SensorInPort[0..*];
        port commandPorts : CommandOutPort[0..*];
        port statusPorts : StatusInPort[0..*];
        port appPort : HubToAppPort;

        part ruleEngine : RuleEngine;

        action def ReceiveSensorData {
            in readings : SensorReading[0..*];
            out commands : DeviceCommand[0..*];
            out notifications : Notification[0..*];
            do perform ruleEngine.process {
                in readings = readings;
                out commands = commands;
                out notifications = notifications;
            }
        }

        action def DispatchCommands {
            in commands : DeviceCommand[0..*];
            do for c in commands {
                // route to appropriate command port based on targetDeviceId
            }
        }

        action def ForwardToApp {
            in statuses : DeviceStatus[0..*];
            in notifications : Notification[0..*];
            do for s in statuses { send appPort.statusReport(s); }
            do for n in notifications { send appPort.notification(n); }
        }

        state machine HubStateMachine {
            state Booting;
            state Operational;
            state Degraded;
            state Offline;

            transition init to Booting;
            transition Booting to Operational when bootComplete;
            transition Operational to Degraded when anySensorFault;
            transition Degraded to Operational when allSensorsRecovered;
            transition Operational to Offline when networkLost;
            transition Offline to Operational when networkRestored;
        }

        action bootComplete { out trigger : Boolean; }
        action anySensorFault { out trigger : Boolean; }
        action allSensorsRecovered { out trigger : Boolean; }
        action networkLost { out trigger : Boolean; }
        action networkRestored { out trigger : Boolean; }
    }

    // ---- Mobile application ----
    part def MobileApp {
        attribute appName : String = "SmartThings Mobile";
        attribute userId : String;
        attribute connected : Boolean = false;
        port hubPort : AppToHubPort;

        action def ViewDashboard {
            in statuses : DeviceStatus[0..*];
        }
        action def SendManualCommand {
            out command : DeviceCommand;
        }
        action def EditRule {
            out rule : AutomationRule;
        }
        action def ReceiveNotification {
            in notification : Notification;
        }

        state machine AppStateMachine {
            state LoggedOut;
            state Connected;
            state Disconnected;

            transition init to LoggedOut;
            transition LoggedOut to Connected when loginSuccess;
            transition Connected to Disconnected when connectionLost;
            transition Disconnected to Connected when connectionRestored;
            transition Connected to LoggedOut when logout;
        }

        action loginSuccess { out trigger : Boolean; }
        action connectionLost { out trigger : Boolean; }
        action connectionRestored { out trigger : Boolean; }
        action logout { out trigger : Boolean; }
    }

    // ---- Smartphone ----
    part def Smartphone {
        attribute model : String;
        attribute osVersion : String;
        part app : MobileApp;
    }

    // ---- The home system ----
    part def SmartHomeSystem {
        attribute homeName : String;
        attribute timeZone : String;

        part hub : SmartThingsHub {
            part ruleEngine : RuleEngine {
                attribute rules = AutomationRule{
                    ruleId = "R001", 
                    name = "HallwayMotionAtNight", 
                    conditionExpression = "motionDetected == true && timeOfDay == 'night'", 
                    actionDescription = "Set hallway light to 50%", 
                    enabled = true, 
                    created = now
                };
            }
        }

        part livingRoomTempSensor : TemperatureSensor {
            attribute deviceId = "TS-LR-01";
            attribute location = "Living Room";
        }
        part hallwayMotionSensor : MotionSensor {
            attribute deviceId = "MS-HW-01";
            attribute location = "Hallway";
        }
        part bedroomLightSensor : LightSensor {
            attribute deviceId = "LS-BR-01";
            attribute location = "Bedroom";
        }
        part hallwayLight : SmartLight {
            attribute deviceId = "SL-HW-01";
            attribute location = "Hallway";
        }
        part livingRoomLight : SmartLight {
            attribute deviceId = "SL-LR-01";
            attribute location = "Living Room";
        }
        part thermostat : SmartThermostat {
            attribute deviceId = "TH-01";
            attribute location = "Living Room";
        }
        part frontDoorLock : SmartDoorLock {
            attribute deviceId = "DL-FD-01";
            attribute location = "Front Door";
        }
        part userPhone : Smartphone {
            attribute model = "Galaxy S24";
            part app : MobileApp {
                attribute userId = "user-001";
            }
        }

        // Connections from sensors to hub
        connection livingRoomTempSensor.sensorOut to hub.sensorPorts[1];
        connection hallwayMotionSensor.sensorOut to hub.sensorPorts[2];
        connection bedroomLightSensor.sensorOut to hub.sensorPorts[3];

        // Connections from hub to controllable devices
        connection hub.commandPorts[1] to hallwayLight.cmdPort;
        connection hub.commandPorts[2] to livingRoomLight.cmdPort;
        connection hub.commandPorts[3] to thermostat.cmdPort;
        connection hub.commandPorts[4] to frontDoorLock.cmdPort;

        // Status connections from devices to hub
        connection hallwayLight.statusPort to hub.statusPorts[1];
        connection livingRoomLight.statusPort to hub.statusPorts[2];
        connection thermostat.statusPort to hub.statusPorts[3];
        connection frontDoorLock.statusPort to hub.statusPorts[4];

        // Bidirectional app-hub connection
        connection userPhone.app.hubPort to hub.appPort;

        // Sensor status connections to hub
        connection livingRoomTempSensor.statusPort to hub.statusPorts[5];
        connection hallwayMotionSensor.statusPort to hub.statusPorts[6];
        connection bedroomLightSensor.statusPort to hub.statusPorts[7];
    }

    // ---- Requirements ----
    requirement def HubShallIntegrateDevices {
        attribute id = "REQ-001";
        subject : SmartThingsHub;
        objective {
            doc /* The Hub shall connect to and integrate temperature sensors, motion sensors, light sensors, smart lights, smart thermostats, and smart door locks. */
        }
    }

    requirement def SensorsShallReportToHub {
        attribute id = "REQ-002";
        subject : SmartDevice;
        objective {
            doc /* Each sensor shall continuously gather environmental data and report readings to the Hub. */
        }
    }

    requirement def RuleEngineShallEvaluateRules {
        attribute id = "REQ-003";
        subject : RuleEngine;
        objective {
            doc /* The Hub's rule engine shall evaluate sensor data against user-defined automation rules and dispatch commands when conditions are met. */
        }
    }

    requirement def DevicesShallExecuteCommands {
        attribute id = "REQ-004";
        subject : SmartDevice;
        objective {
            doc /* Controllable devices shall execute commands received from the Hub and report their new status back to the Hub. */
        }
    }

    requirement def AppShallProvideDashboard {
        attribute id = "REQ-005";
        subject : MobileApp;
        objective {
            doc /* The mobile application shall display device status, allow manual control, enable rule editing, and deliver notifications to the user. */
        }
    }

    requirement def SystemShallBeResponsive {
        attribute id = "REQ-006";
        subject : SmartHomeSystem;
        attribute maxLatency : LatencyValue = 500.0;
        objective {
            doc /* The system shall complete automated actions and deliver notifications within 500 ms of the triggering event. */
        }
        require maxLatency <= 500.0;
    }

    requirement def DevicesShallReportOperationalState {
        attribute id = "REQ-007";
        subject : SmartDevice;
        objective {
            doc /* Each smart device shall report its operational state among Connected, Idle, Active, or Fault to the Hub. */
        }
    }

    requirement package SmartHomeRequirements {
        requirement req1 : HubShallIntegrateDevices;
        requirement req2 : SensorsShallReportToHub;
        requirement req3 : RuleEngineShallEvaluateRules;
        requirement req4 : DevicesShallExecuteCommands;
        requirement req5 : AppShallProvideDashboard;
        requirement req6 : SystemShallBeResponsive;
        requirement req7 : DevicesShallReportOperationalState;
    }

    // ---- Satisfaction bindings ----
    satisfaction SmartHomeSystem::hub satisfies HubShallIntegrateDevices;
    satisfaction SmartHomeSystem::livingRoomTempSensor satisfies SensorsShallReportToHub;
    satisfaction SmartHomeSystem::hallwayMotionSensor satisfies SensorsShallReportToHub;
    satisfaction SmartHomeSystem::bedroomLightSensor satisfies SensorsShallReportToHub;
    satisfaction SmartHomeSystem::hub.ruleEngine satisfies RuleEngineShallEvaluateRules;
    satisfaction SmartHomeSystem::hallwayLight satisfies DevicesShallExecuteCommands;
    satisfaction SmartHomeSystem::thermostat satisfies DevicesShallExecuteCommands;
    satisfaction SmartHomeSystem::frontDoorLock satisfies DevicesShallExecuteCommands;
    satisfaction SmartHomeSystem::userPhone.app satisfies AppShalProvideDashboard;
    satisfaction SmartHomeSystem satisfies SystemShallBeResponsive;
    satisfaction SmartHomeSystem::hallwayLight satisfies DevicesShallReportOperationalState;
}
