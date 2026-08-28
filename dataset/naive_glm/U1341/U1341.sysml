package HomeSeerAutomation {

    // ---- Standard Library Imports (conceptual) ----
    // ISQ::Temperature, ISQ::MassFraction (humidity), etc. assumed available

    // ---- Value Types ----

    value def TemperatureValue :> Real {
        unit '°C';
    }

    value def HumidityValue :> Real {
        unit '%';
    }

    value def LightLevelValue :> Real {
        unit 'lux';
    }

    value def DimmingLevel :> Real {
        min 0.0;
        max 100.0;
        unit '%';
    }

    value def PowerState :> String {
        constraint { self == 'on' or self == 'off' }
    }

    value def LockState :> String {
        constraint { self == 'locked' or self == 'unlocked' }
    }

    value def DeviceId :> String;

    value def RuleId :> String;

    value def Timestamp :> Real {
        unit 's';
    }

    // ---- Item Definitions ----

    item def SensorEvent {
        attribute deviceId : DeviceId;
        attribute timestamp : Timestamp;
    }

    item def TemperatureEvent :> SensorEvent {
        attribute temperature : TemperatureValue;
    }

    item def HumidityEvent :> SensorEvent {
        attribute humidity : HumidityValue;
    }

    item def MotionEvent :> SensorEvent {
        attribute motionDetected : Boolean;
    }

    item def LightLevelEvent :> SensorEvent {
        attribute lightLevel : LightLevelValue;
    }

    item def DeviceCommand {
        attribute deviceId : DeviceId;
        attribute timestamp : Timestamp;
    }

    item def LightCommand :> DeviceCommand {
        attribute power : PowerState;
        attribute dimming : DimmingLevel;
    }

    item def ThermostatCommand :> DeviceCommand {
        attribute targetTemperature : TemperatureValue;
    }

    item def PlugCommand :> DeviceCommand {
        attribute power : PowerState;
    }

    item def LockCommand :> DeviceCommand {
        attribute lockState : LockState;
    }

    item def DeviceRegistration {
        attribute deviceId : DeviceId;
        attribute deviceType : String;
        attribute location : String;
    }

    item def DeviceStatus {
        attribute deviceId : DeviceId;
        attribute online : Boolean;
        attribute lastSeen : Timestamp;
    }

    item def ErrorReport {
        attribute deviceId : DeviceId;
        attribute errorCode : String;
        attribute description : String;
        attribute timestamp : Timestamp;
    }

    item def AutomationRule {
        attribute ruleId : RuleId;
        attribute name : String;
        attribute condition : String;
        attribute action : String;
        attribute enabled : Boolean;
    }

    // ---- Port Definitions ----

    port def SensorOutPort {
        out sensorEvents : SensorEvent;
    }

    port def ControllerSensorInPort {
        in sensorEvents : SensorEvent;
    }

    port def ControllerCommandOutPort {
        out commands : DeviceCommand;
    }

    port def DeviceCommandInPort {
        in commands : DeviceCommand;
    }

    port def RegistrationPort {
        in registrations : DeviceRegistration;
        out statusResponses : DeviceStatus;
    }

    port def ControllerRegistrationPort {
        out registrations : DeviceRegistration;
        in statusResponses : DeviceStatus;
    }

    port def ErrorReportingPort {
        out errors : ErrorReport;
    }

    port def ControllerErrorInPort {
        in errors : ErrorReport;
    }

    // ---- Sensor Part Definitions ----

    part def TemperatureHumiditySensor {
        attribute deviceId : DeviceId;
        attribute location : String;
        port sensorOut : SensorOutPort;
        attribute currentTemperature : TemperatureValue;
        attribute currentHumidity : HumidityValue;
        attribute samplingInterval : Timestamp;

        action def SenseTemperature {
            in interval : Timestamp;
            out event : TemperatureEvent;
        }

        action def SenseHumidity {
            in interval : Timestamp;
            out event : HumidityEvent;
        }

        perform action senseLoop {
            while true {
                action senseTemp : SenseTemperature {
                    in interval = samplingInterval;
                    out event : TemperatureEvent {
                        deviceId := self.deviceId;
                        timestamp := now();
                        temperature := self.currentTemperature;
                    }
                }
                action senseHum : SenseHumidity {
                    in interval = samplingInterval;
                    out event : HumidityEvent {
                        deviceId := self.deviceId;
                        timestamp := now();
                        humidity := self.currentHumidity;
                    }
                }
                flow senseTemp.event -> sensorOut.sensorEvents;
                flow senseHum.event -> sensorOut.sensorEvents;
            }
        }
    }

    part def MotionDetector {
        attribute deviceId : DeviceId;
        attribute location : String;
        port sensorOut : SensorOutPort;
        attribute motionDetected : Boolean;
        attribute cooldownPeriod : Timestamp;

        action def DetectMotion {
            out event : MotionEvent;
        }

        perform action detectLoop {
            while true {
                action detect : DetectMotion {
                    out event : MotionEvent {
                        deviceId := self.deviceId;
                        timestamp := now();
                        motionDetected := self.motionDetected;
                    }
                }
                flow detect.event -> sensorOut.sensorEvents;
            }
        }
    }

    part def OutdoorLightSensor {
        attribute deviceId : DeviceId;
        attribute location : String;
        port sensorOut : SensorOutPort;
        attribute currentLightLevel : LightLevelValue;
        attribute sunsetThreshold : LightLevelValue = 50.0;
        attribute isDark : Boolean;
        attribute samplingInterval : Timestamp;

        action def SenseLight {
            out event : LightLevelEvent;
        }

        perform action senseLoop {
            while true {
                action sense : SenseLight {
                    out event : LightLevelEvent {
                        deviceId := self.deviceId;
                        timestamp := now();
                        lightLevel := self.currentLightLevel;
                    }
                }
                flow sense.event -> sensorOut.sensorEvents;
            }
        }
    }

    // ---- Actuator Part Definitions ----

    part def SmartLight {
        attribute deviceId : DeviceId;
        attribute location : String;
        port commandIn : DeviceCommandInPort;
        attribute power : PowerState = 'off';
        attribute dimming : DimmingLevel = 100.0;

        action def ExecuteLightCommand {
            in cmd : LightCommand;
        }

        perform action commandHandler {
            while true {
                action handle : ExecuteLightCommand {
                    in cmd : LightCommand;
                }
                flow commandIn.commands -> handle.cmd;
            }
        }
    }

    part def Thermostat {
        attribute deviceId : DeviceId;
        attribute location : String;
        port commandIn : DeviceCommandInPort;
        attribute currentSetpoint : TemperatureValue = 22.0;
        attribute currentTemperature : TemperatureValue;
        attribute mode : String = 'auto';

        action def ExecuteThermostatCommand {
            in cmd : ThermostatCommand;
        }

        perform action commandHandler {
            while true {
                action handle : ExecuteThermostatCommand {
                    in cmd : ThermostatCommand;
                }
                flow commandIn.commands -> handle.cmd;
            }
        }
    }

    part def SmartPlug {
        attribute deviceId : DeviceId;
        attribute location : String;
        attribute appliance : String;
        port commandIn : DeviceCommandInPort;
        attribute power : PowerState = 'off';

        action def ExecutePlugCommand {
            in cmd : PlugCommand;
        }

        perform action commandHandler {
            while true {
                action handle : ExecutePlugCommand {
                    in cmd : PlugCommand;
                }
                flow commandIn.commands -> handle.cmd;
            }
        }
    }

    part def ElectronicLock {
        attribute deviceId : DeviceId;
        attribute location : String;
        port commandIn : DeviceCommandInPort;
        attribute lockState : LockState = 'locked';

        action def ExecuteLockCommand {
            in cmd : LockCommand;
        }

        perform action commandHandler {
            while true {
                action handle : ExecuteLockCommand {
                    in cmd : LockCommand;
                }
                flow commandIn.commands -> handle.cmd;
            }
        }
    }

    // ---- Controller Part Definition ----

    part def HomeSeerController {
        attribute controllerId : DeviceId = 'HS-CTRL-001';
        attribute firmwareVersion : String = '4.2.1';
        attribute maxDevices : Integer = 200;

        port sensorIn : ControllerSensorInPort;
        port commandOut : ControllerCommandOutPort;
        port registration : ControllerRegistrationPort;
        port errorIn : ControllerErrorInPort;

        attribute registeredDevices : DeviceId[0..*];
        attribute automationRules : AutomationRule[0..*];
        attribute isDarkOutside : Boolean = false;
        attribute occupancyMap : String[0..*];
        attribute lastError : ErrorReport;

        // Internal actions

        action def DiscoverDevices {
            out registrations : DeviceRegistration[0..*];
        }

        action def ProcessSensorEvent {
            in event : SensorEvent;
            out updatedState : Boolean;
        }

        action def EvaluateRules {
            in rules : AutomationRule[0..*];
            out commands : DeviceCommand[0..*];
        }

        action def DispatchCommand {
            in cmd : DeviceCommand;
        }

        action def RecoverFromError {
            in error : ErrorReport;
            out recovered : Boolean;
        }

        action def EnterMaintenanceMode {
            out maintenanceActive : Boolean;
        }

        // State Machine

        state def ControllerStateMachine {
            entry; then Initializing;

            state Initializing {
                entry {
                    action discover : DiscoverDevices {
                        out registrations : DeviceRegistration[0..*];
                    }
                }
                do {
                    // Register discovered devices
                }
                transition init_to_idle
                    first Initializing
                    accept RegistrationComplete
                    then Idle;
            }

            state Idle {
                entry {
                    // Enter low-power mode
                }
                transition idle_to_monitoring
                    first Idle
                    accept SensorEvent
                    then Monitoring;

                transition idle_to_maintenance
                    first Idle
                    accept MaintenanceRequest
                    then Maintenance;
            }

            state Monitoring {
                entry {
                    // Collect data from all sensors
                }
                do {
                    action processEvent : ProcessSensorEvent {
                        in event : SensorEvent;
                        out updatedState : Boolean;
                    }
                }
                transition monitoring_to_processing
                    first Monitoring
                    accept DataCollected
                    then ProcessingRules;

                transition monitoring_to_error
                    first Monitoring
                    accept ErrorReport
                    then ErrorRecovery;
            }

            state ProcessingRules {
                entry {
                    action evaluate : EvaluateRules {
                        in rules = automationRules;
                        out commands : DeviceCommand[0..*];
                    }
                }
                transition processing_to_executing
                    first ProcessingRules
                    accept RuleTriggered
                    then ExecutingCommands;

                transition processing_to_idle
                    first ProcessingRules
                    accept NoRuleMatched
                    then Idle;
            }

            state ExecutingCommands {
                do {
                    action dispatch : DispatchCommand {
                        in cmd : DeviceCommand;
                    }
                }
                transition executing_to_idle
                    first ExecutingCommands
                    accept CommandsDispatched
                    then Idle;

                transition executing_to_error
                    first ExecutingCommands
                    accept ErrorReport
                    then ErrorRecovery;
            }

            state ErrorRecovery {
                entry {
                    action recover : RecoverFromError {
                        in error : ErrorReport;
                        out recovered : Boolean;
                    }
                }
                transition error_to_idle
                    first ErrorRecovery
                    accept RecoverySuccessful
                    then Idle;

                transition error_to_maintenance
                    first ErrorRecovery
                    accept RecoveryFailed
                    then Maintenance;
            }

            state Maintenance {
                entry {
                    action enterMaint : EnterMaintenanceMode {
                        out maintenanceActive : Boolean;
                    }
                }
                transition maintenance_to_init
                    first Maintenance
                    accept MaintenanceComplete
                    then Initializing;
            }
        }

        exhibit state machine : ControllerStateMachine;

        // Continuous processing loop
        perform action mainLoop {
            while true {
                action receive : ReceiveSensorEvent {
                    out event : SensorEvent;
                }
                flow sensorIn.sensorEvents -> receive.event;

                action process : ProcessSensorEvent {
                    in event = receive.event;
                    out updatedState : Boolean;
                }

                action evaluate : EvaluateRules {
                    in rules = automationRules;
                    out commands : DeviceCommand[0..*];
                }

                action dispatchAll {
                    in cmds : DeviceCommand[0..*] = evaluate.commands;
                    action dispatch : DispatchCommand {
                        in cmd : DeviceCommand;
                    }
                }
                flow dispatchAll.dispatch.cmd -> commandOut.commands;
            }
        }
    }

    // ---- System Definition ----

    part def HomeSeerSystem {

        part controller : HomeSeerController {
            attribute controllerId = 'HS-CTRL-001';

            // Built-in automation rules
            attribute automationRules = {
                AutomationRule {
                    ruleId = 'RULE-001';
                    name = 'HallwayLightOnMotionAfterSunset';
                    condition = 'motionDetected(hallway) AND isDarkOutside';
                    action = 'turnOn(hallwayLight, dimming=30)';
                    enabled = true;
                },
                AutomationRule {
                    ruleId = 'RULE-002';
                    name = 'BedroomLightOnMotion';
                    condition = 'motionDetected(bedroom)';
                    action = 'turnOn(bedroomLight, dimming=50)';
                    enabled = true;
                },
                AutomationRule {
                    ruleId = 'RULE-003';
                    name = 'ThermostatSchedule';
                    condition = 'temperature(livingRoom) < 20.0';
                    action = 'setThermostat(22.0)';
                    enabled = true;
                },
                AutomationRule {
                    ruleId = 'RULE-004';
                    name = 'CoffeeMakerMorning';
                    condition = 'time == 06:30 AND weekday';
                    action = 'turnOn(coffeeMakerPlug)';
                    enabled = true;
                },
                AutomationRule {
                    ruleId = 'RULE-005';
                    name = 'LockDoorsAtNight';
                    condition = 'isDarkOutside AND noMotion(10min)';
                    action = 'lockAllDoors()';
                    enabled = true;
                },
                AutomationRule {
                    ruleId = 'RULE-006';
                    name = 'OutdoorLightAtDusk';
                    condition = 'lightLevel < 50.0';
                    action = 'turnOn(porchLight, dimming=80)';
                    enabled = true;
                }
            };
        }

        // Sensors
        part livingRoomTempSensor : TemperatureHumiditySensor {
            attribute deviceId = 'SENS-LR-TEMP-001';
            attribute location = 'livingRoom';
            attribute samplingInterval = 30.0;
        }

        part hallwayMotionSensor : MotionDetector {
            attribute deviceId = 'SENS-HALL-MOTION-001';
            attribute location = 'hallway';
            attribute cooldownPeriod = 5.0;
        }

        part bedroomMotionSensor : MotionDetector {
            attribute deviceId = 'SENS-BED-MOTION-001';
            attribute location = 'bedroom';
            attribute cooldownPeriod = 5.0;
        }

        part outdoorLightSensor : OutdoorLightSensor {
            attribute deviceId = 'SENS-OUT-LIGHT-001';
            attribute location = 'outdoor';
            attribute samplingInterval = 60.0;
            attribute sunsetThreshold = 50.0;
        }

        // Actuators - Lights
        part hallwayLight : SmartLight {
            attribute deviceId = 'LIGHT-HALL-001';
            attribute location = 'hallway';
        }

        part bedroomLight : SmartLight {
            attribute deviceId = 'LIGHT-BED-001';
            attribute location = 'bedroom';
        }

        part livingRoomLight : SmartLight {
            attribute deviceId = 'LIGHT-LR-001';
            attribute location = 'livingRoom';
        }

        part porchLight : SmartLight {
            attribute deviceId = 'LIGHT-PORCH-001';
            attribute location = 'porch';
        }

        // Actuator - Thermostat
        part thermostat : Thermostat {
            attribute deviceId = 'THERM-001';
            attribute location = 'livingRoom';
            attribute currentSetpoint = 22.0;
        }

        // Actuators - Smart Plugs
        part coffeeMakerPlug : SmartPlug {
            attribute deviceId = 'PLUG-COFFEE-001';
            attribute location = 'kitchen';
            attribute appliance = 'coffeeMaker';
        }

        part lampPlug : SmartPlug {
            attribute deviceId = 'PLUG-LAMP-001';
            attribute location = 'livingRoom';
            attribute appliance = 'lamp';
        }

        // Actuators - Electronic Locks
        part frontDoorLock : ElectronicLock {
            attribute deviceId = 'LOCK-FRONT-001';
            attribute location = 'frontDoor';
        }

        part backDoorLock : ElectronicLock {
            attribute deviceId = 'LOCK-BACK-001';
            attribute location = 'backDoor';
        }

        // Connections: Sensors -> Controller
        connection livingRoomTempConn connect livingRoomTempSensor.sensorOut to controller.sensorIn;
        connection hallwayMotionConn connect hallwayMotionSensor.sensorOut to controller.sensorIn;
        connection bedroomMotionConn connect bedroomMotionSensor.sensorOut to controller.sensorIn;
        connection outdoorLightConn connect outdoorLightSensor.sensorOut to controller.sensorIn;

        // Connections: Controller -> Actuators
        connection hallwayLightCmdConn connect controller.commandOut to hallwayLight.commandIn;
        connection bedroomLightCmdConn connect controller.commandOut to bedroomLight.commandIn;
        connection livingRoomLightCmdConn connect controller.commandOut to livingRoomLight.commandIn;
        connection porchLightCmdConn connect controller.commandOut to porchLight.commandIn;
        connection thermostatCmdConn connect controller.commandOut to thermostat.commandIn;
        connection coffeeMakerPlugCmdConn connect controller.commandOut to coffeeMakerPlug.commandIn;
        connection lampPlugCmdConn connect controller.commandOut to lampPlug.commandIn;
        connection frontDoorLockCmdConn connect controller.commandOut to frontDoorLock.commandIn;
        connection backDoorLockCmdConn connect controller.commandOut to backDoorLock.commandIn;
    }

    // ---- Requirements ----

    package Requirements {

        requirement def SystemRequirement {
            attribute id : String;
            attribute text : String;
        }

        requirement CentralControl :> SystemRequirement {
            id = 'REQ-001';
            text = 'The HomeSeer Controller shall act as the central hub for registering, managing, and orchestrating all connected smart devices.';
        }

        requirement DeviceRegistration :> SystemRequirement {
            id = 'REQ-002';
            text = 'The controller shall discover and register all connected devices during an initialization phase before entering normal operation.';
        }

        requirement SensorDataCollection :> SystemRequirement {
            id = 'REQ-003';
            text = 'The system shall continuously collect sensor data from temperature, humidity, motion, and light sensors distributed throughout the residence.';
        }

        requirement RuleEvaluation :> SystemRequirement {
            id = 'REQ-004';
            text = 'The controller shall evaluate a set of automation rules against current sensor data and dispatch commands to actuators when rule conditions are met.';
        }

        requirement HallwayMotionLightRule :> SystemRequirement {
            id = 'REQ-005';
            text = 'When motion is detected in the hallway after sunset, the controller shall turn on the hallway light at 30% dimming level.';
        }

        requirement ThermostatControl :> SystemRequirement {
            id = 'REQ-006';
            text = 'The controller shall adjust the thermostat setpoint based on living room temperature readings to maintain comfort.';
        }

        requirement DoorLockAutomation :> SystemRequirement {
            id = 'REQ-007';
            text = 'The controller shall lock all electronic door locks when it is dark outside and no motion has been detected for 10 minutes.';
        }

        requirement ControllerStates :> SystemRequirement {
            id = 'REQ-008';
            text = 'The controller shall operate through states including initialization, idle, monitoring, processing rules, executing commands, error recovery, and maintenance.';
        }

        requirement ErrorRecovery :> SystemRequirement {
            id = 'REQ-009';
            text = 'The controller shall automatically attempt error recovery upon receiving an error report, and enter maintenance mode if recovery fails.';
        }

        requirement LowPowerIdle :> SystemRequirement {
            id = 'REQ-010';
            text = 'The controller shall enter a low-power idle state when no sensor events are pending and no commands are being executed.';
        }

        requirement SmartLightControl :> SystemRequirement {
            id = 'REQ-011';
            text = 'Smart lights shall support on, off, and dimming commands from the controller.';
        }

        requirement SmartPlugControl :> SystemRequirement {
            id = 'REQ-012';
            text = 'Smart plugs shall support on and off commands for managing connected appliances.';
        }

        requirement ElectronicLockControl :> SystemRequirement {
            id = 'REQ-013';
            text = 'Electronic locks shall support lock and unlock commands from the controller.';
        }

        requirement OutdoorLightMonitoring :> SystemRequirement {
            id = 'REQ-014';
            text = 'The outdoor light sensor shall monitor ambient light levels and the controller shall determine sunset conditions when light falls below 50 lux.';
        }

        requirement ContinuousOperation :> SystemRequirement {
            id = 'REQ-015';
            text = 'The system shall operate in a continuous cycle of data collection, analysis, rule evaluation, and command dispatch to ensure reliable home automation.';
        }

        // Satisfaction relationships
        satisfy CentralControl by controller;
        satisfy DeviceRegistration by controller;
        satisfy SensorDataCollection by livingRoomTempSensor;
        satisfy SensorDataCollection by hallwayMotionSensor;
        satisfy SensorDataCollection by bedroomMotionSensor;
        satisfy SensorDataCollection by outdoorLightSensor;
        satisfy RuleEvaluation by controller;
        satisfy HallwayMotionLightRule by controller;
        satisfy ThermostatControl by controller;
        satisfy DoorLockAutomation by controller;
        satisfy ControllerStates by controller;
        satisfy ErrorRecovery by controller;
        satisfy LowPowerIdle by controller;
        satisfy SmartLightControl by hallwayLight;
        satisfy SmartLightControl by bedroomLight;
        satisfy SmartLightControl by livingRoomLight;
        satisfy SmartLightControl by porchLight;
        satisfy SmartPlugControl by coffeeMakerPlug;
        satisfy SmartPlugControl by lampPlug;
        satisfy ElectronicLockControl by frontDoorLock;
        satisfy ElectronicLockControl by backDoorLock;
        satisfy OutdoorLightMonitoring by outdoorLightSensor;
        satisfy ContinuousOperation by controller;
    }

}
