package QIVICON_Smart_Home_System {

    import SI::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====

    value def TemperatureValue :> Real { unit '°C'; }
    value def BrightnessValue :> Real { unit 'lm'; }
    value def ColorTemperatureValue :> Real { unit 'K'; }
    value def PowerValue :> Real { unit 'W'; }
    value def EnergyValue :> Real { unit 'kWh'; }
    value def Percentage :> Real { unit '%'; }
    value def SignalStrength :> Real { unit 'dBm'; }

    // ===== Enumerations =====

    enum def SecurityModeKind { enum home; enum away; enum night; }

    enum def DoorWindowStateKind { enum open; enum closed; }

    enum def LightStateKind { enum on; enum off; }

    enum def MotionStateKind { enum motionDetected; enum noMotion; }

    enum def CommandKind {
        enum setTemperature;
        enum turnLightOn;
        enum turnLightOff;
        enum setBrightness;
        enum setColorTemperature;
        enum setPlugOn;
        enum setPlugOff;
        enum setSecurityMode;
    }

    enum def AlertKind { enum doorOpenAlert; enum motionAlert; enum powerOverloadAlert; }

    // ===== Item Types =====

    item def UserCommand {
        attribute commandType : CommandKind;
        attribute targetDeviceId : String;
        attribute value : Real[0..1];
        attribute issuedAt : Time;
    }

    item def DeviceStatus {
        attribute deviceId : String;
        attribute deviceType : String;
        attribute timestamp : Time;
        attribute measurement : Real[0..*];
    }

    item def Alert {
        attribute alertType : AlertKind;
        attribute deviceId : String;
        attribute timestamp : Time;
        attribute severity : Integer;
    }

    item def AutomationRule {
        attribute ruleId : String;
        attribute triggerDeviceId : String;
        attribute triggerCondition : String;
        attribute actionDeviceId : String;
        attribute actionCommand : CommandKind;
        attribute actionValue : Real[0..1];
        attribute enabled : Boolean;
    }

    item def HistoricalRecord {
        attribute deviceId : String;
        attribute timestamp : Time;
        attribute attributeName : String;
        attribute value : Real;
    }

    item def AuthenticationToken {
        attribute userId : String;
        attribute token : String;
        attribute validUntil : Time;
    }

    // ===== Port Definitions =====

    port def CloudAppPort {
        out userCommands : UserCommand[*];
        in deviceStatuses : DeviceStatus[*];
        in alerts : Alert[*];
    }

    port def CloudBasePort {
        in userCommands : UserCommand[*];
        out deviceStatuses : DeviceStatus[*];
        out alerts : Alert[*];
    }

    port def BaseDevicePort {
        out userCommands : UserCommand[*];
        in deviceStatuses : DeviceStatus[*];
        in alerts : Alert[*];
    }

    port def DeviceBasePort {
        in userCommands : UserCommand[*];
        out deviceStatuses : DeviceStatus[*];
        out alerts : Alert[*];
    }

    // ===== Interfaces =====

    interface def AppToCloudInterface {
        end appSide : CloudAppPort;
        end cloudSide : CloudAppPort;
    }

    interface def CloudToBaseInterface {
        end cloudSide : CloudBasePort;
        end baseSide : CloudBasePort;
    }

    interface def BaseToDeviceInterface {
        end baseSide : BaseDevicePort;
        end deviceSide : DeviceBasePort;
    }

    // ===== Abstract Smart Device =====

    part def SmartDevice {
        attribute deviceId : String;
        attribute deviceName : String;
        attribute manufacturer : String;
        attribute firmwareVersion : String;
        attribute batteryLevel : Percentage[0..1];
        attribute signalStrength : SignalStrength[0..1];
        port baseIf : DeviceBasePort;

        abstract action def reportStatus;
        abstract action def receiveCommand(cmd : UserCommand);

        state def DeviceLifecycle {
            initial start;
            state Initializing;
            state Operational;
            state Offline;
            state Error;
            transition init_to_operational
                first Initializing
                if (self.initialized == true)
                then Operational;
            transition operational_to_offline
                first Operational
                if (self.connected == false)
                then Offline;
            transition offline_to_operational
                first Offline
                if (self.connected == true)
                then Operational;
            transition operational_to_error
                first Operational
                if (self.faultDetected == true)
                then Error;
            transition error_to_operational
                first Error
                if (self.faultDetected == false)
                then Operational;
        }

        attribute initialized : Boolean = false;
        attribute connected : Boolean = false;
        attribute faultDetected : Boolean = false;
    }

    // ===== Heating Thermostat =====

    part def HeatingThermostat :> SmartDevice {
        attribute currentTemperature : TemperatureValue;
        attribute targetSetpoint : TemperatureValue;
        attribute heatingActive : Boolean = false;
        attribute coolingActive : Boolean = false;

        action def regulateTemperature {
            input currentTemp : TemperatureValue;
            input setpoint : TemperatureValue;
            decision compare {
                if (currentTemp < setpoint - 0.5) then activateHeating();
                if (currentTemp > setpoint + 0.5) then activateCooling();
                else deactivateHVAC();
            }
        }

        action activateHeating { in currentTemp : TemperatureValue; }
        action activateCooling { in currentTemp : TemperatureValue; }
        action deactivateHVAC;

        state def ThermostatOperation {
            initial start;
            state Idle;
            state Heating;
            state Cooling;
            transition idle_to_heating
                first Idle
                if (currentTemperature < targetSetpoint - 0.5)
                then Heating;
            transition heating_to_idle
                first Heating
                if (currentTemperature >= targetSetpoint)
                then Idle;
            transition idle_to_cooling
                first Idle
                if (currentTemperature > targetSetpoint + 0.5)
                then Cooling;
            transition cooling_to_idle
                first Cooling
                if (currentTemperature <= targetSetpoint)
                then Idle;
        }

        action def receiveCommand(cmd : UserCommand) {
            if (cmd.commandType == CommandKind::setTemperature) {
                targetSetpoint := cmd.value;
            }
        }
    }

    // ===== Smart Light Bulb =====

    part def SmartLightBulb :> SmartDevice {
        attribute lightState : LightStateKind = LightStateKind::off;
        attribute brightness : Percentage = 0;
        attribute colorTemperature : ColorTemperatureValue = 2700;

        action def turnOn {
            lightState := LightStateKind::on;
            if (brightness == 0) { brightness := 100; }
        }

        action def turnOff {
            lightState := LightStateKind::off;
        }

        action def setBrightnessLevel(level : Percentage) {
            brightness := level;
            if (level > 0) { lightState := LightStateKind::on; }
            else { lightState := LightStateKind::off; }
        }

        action def setColorTemp(ct : ColorTemperatureValue) {
            colorTemperature := ct;
        }

        action def receiveCommand(cmd : UserCommand) {
            if (cmd.commandType == CommandKind::turnLightOn) { turnOn(); }
            if (cmd.commandType == CommandKind::turnLightOff) { turnOff(); }
            if (cmd.commandType == CommandKind::setBrightness) { setBrightnessLevel(cmd.value); }
            if (cmd.commandType == CommandKind::setColorTemperature) { setColorTemp(cmd.value); }
        }
    }

    // ===== Door & Window Sensor =====

    part def DoorWindowSensor :> SmartDevice {
        attribute windowState : DoorWindowStateKind = DoorWindowStateKind::closed;
        attribute lastStateChangedAt : Time;
        attribute alertOnOpen : Boolean = true;

        action def detectStateChange {
            if (windowState == DoorWindowStateKind::open) {
                emit Alert { alertType = AlertKind::doorOpenAlert; deviceId = self.deviceId; severity = 2; };
            }
        }

        action def receiveCommand(cmd : UserCommand) {
            if (cmd.commandType == CommandKind::setSecurityMode) {
                if (cmd.value == 0) { alertOnOpen := false; }
                else { alertOnOpen := true; }
            }
        }

        state def SensorOperation {
            initial start;
            state Closed;
            state Open;
            transition closed_to_open
                first Closed
                if (self.magneticContactBroken == true)
                then Open;
            transition open_to_closed
                first Open
                if (self.magneticContactBroken == false)
                then Closed;
        }

        attribute magneticContactBroken : Boolean = false;
    }

    // ===== Motion Sensor =====

    part def MotionSensor :> SmartDevice {
        attribute motionState : MotionStateKind = MotionStateKind::noMotion;
        attribute sensitivity : Percentage = 80;
        attribute detectionTimeout : Time;
        attribute lastMotionAt : Time;

        action def detectMotion {
            if (motionState == MotionStateKind::motionDetected) {
                emit Alert { alertType = AlertKind::motionAlert; deviceId = self.deviceId; severity = 3; };
            }
        }

        action def receiveCommand(cmd : UserCommand) {
            if (cmd.commandType == CommandKind::setSecurityMode) {
                if (cmd.value == 1) { sensitivity := 100; }
                else { sensitivity := 50; }
            }
        }

        state def MotionSensorOperation {
            initial start;
            state NoMotion;
            state MotionDetected;
            transition noMotion_to_motion
                first NoMotion
                if (self.pirTriggered == true)
                then MotionDetected;
            transition motion_to_noMotion
                first MotionDetected
                if (self.pirTriggered == false)
                then NoMotion;
        }

        attribute pirTriggered : Boolean = false;
    }

    // ===== Smart Plug =====

    part def SmartPlug :> SmartDevice {
        attribute plugOn : Boolean = false;
        attribute currentPower : PowerValue = 0;
        attribute totalEnergy : EnergyValue = 0;
        attribute maxPower : PowerValue = 3680;

        action def turnPlugOn { plugOn := true; }
        action def turnPlugOff { plugOn := false; }

        action def measurePower {
            if (currentPower > maxPower) {
                emit Alert { alertType = AlertKind::powerOverloadAlert; deviceId = self.deviceId; severity = 5; };
                turnPlugOff();
            }
            totalEnergy := totalEnergy + (currentPower * 0.001 / 3600);
        }

        action def receiveCommand(cmd : UserCommand) {
            if (cmd.commandType == CommandKind::setPlugOn) { turnPlugOn(); }
            if (cmd.commandType == CommandKind::setPlugOff) { turnPlugOff(); }
        }

        state def PlugOperation {
            initial start;
            state Off;
            state On;
            state Overload;
            transition off_to_on
                first Off
                if (plugOn == true)
                then On;
            transition on_to_off
                first On
                if (plugOn == false)
                then Off;
            transition on_to_overload
                first On
                if (currentPower > maxPower)
                then Overload;
            transition overload_to_off
                first Overload
                if (true)
                then Off;
        }
    }

    // ===== Cloud Backend =====

    part def CloudBackend {
        attribute backendUrl : String;
        attribute dataRetentionDays : Integer = 90;
        attribute maxConcurrentUsers : Integer = 100000;
        port appIf : CloudAppPort;
        port baseIf : CloudBasePort;

        attribute authenticatedTokens : AuthenticationToken[*];
        attribute storedRules : AutomationRule[*];
        attribute historicalData : HistoricalRecord[*];

        action def authenticateUser(userId : String, token : String) : Boolean {
            // validate token against stored credentials
            return true;
        }

        action def processUserCommand(cmd : UserCommand) {
            if (authenticateUser(cmd.targetDeviceId, "token") == true) {
                send cmd to baseIf.userCommands;
            }
        }

        action def storeHistoricalData(status : DeviceStatus) {
            append HistoricalRecord { deviceId = status.deviceId; timestamp = status.timestamp; attributeName = "measurement"; value = status.measurement(1); } to historicalData;
        }

        action def evaluateAutomationRules(status : DeviceStatus) {
            for rule in storedRules {
                if (rule.enabled == true and rule.triggerDeviceId == status.deviceId) {
                    emit UserCommand { commandType = rule.actionCommand; targetDeviceId = rule.actionDeviceId; value = rule.actionValue; };
                }
            }
        }

        action def receiveDeviceStatus(status : DeviceStatus) {
            storeHistoricalData(status);
            evaluateAutomationRules(status);
            send status to appIf.deviceStatuses;
        }

        action def receiveAlert(alert : Alert) {
            send alert to appIf.alerts;
        }

        state def CloudOperation {
            initial start;
            state Running;
            state Maintenance;
            state Degraded;
            transition running_to_maintenance
                first Running
                if (self.scheduledMaintenance == true)
                then Maintenance;
            transition maintenance_to_running
                first Maintenance
                if (self.scheduledMaintenance == false)
                then Running;
            transition running_to_degraded
                first Running
                if (self.highLoad == true)
                then Degraded;
            transition degraded_to_running
                first Degraded
                if (self.highLoad == false)
                then Running;
        }

        attribute scheduledMaintenance : Boolean = false;
        attribute highLoad : Boolean = false;
    }

    // ===== Mobile App =====

    part def MobileApp {
        attribute appVersion : String;
        attribute userId : String;
        attribute authToken : AuthenticationToken;
        port cloudIf : CloudAppPort;

        action def sendCommand(cmd : UserCommand) {
            send cmd to cloudIf.userCommands;
        }

        action def displayDeviceStatus(status : DeviceStatus) {
            // render status to user interface
        }

        action def displayAlert(alert : Alert) {
            // push notification to user
        }

        action def checkDoorStatus(deviceId : String) {
            send UserCommand { commandType = CommandKind::setSecurityMode; targetDeviceId = deviceId; } to cloudIf.userCommands;
        }

        action def adjustThermostat(deviceId : String, setpoint : TemperatureValue) {
            send UserCommand { commandType = CommandKind::setTemperature; targetDeviceId = deviceId; value = setpoint; } to cloudIf.userCommands;
        }

        action def controlLight(deviceId : String, on : Boolean, brightness : Percentage) {
            if (on == true) {
                send UserCommand { commandType = CommandKind::turnLightOn; targetDeviceId = deviceId; } to cloudIf.userCommands;
                send UserCommand { commandType = CommandKind::setBrightness; targetDeviceId = deviceId; value = brightness; } to cloudIf.userCommands;
            } else {
                send UserCommand { commandType = CommandKind::turnLightOff; targetDeviceId = deviceId; } to cloudIf.userCommands;
            }
        }

        state def AppSession {
            initial start;
            state LoggedOut;
            state LoggedIn;
            state Syncing;
            transition loggedOut_to_loggedIn
                first LoggedOut
                if (self.authToken != null)
                then LoggedIn;
            transition loggedIn_to_syncing
                first LoggedIn
                if (self.refreshRequested == true)
                then Syncing;
            transition syncing_to_loggedIn
                first Syncing
                if (self.refreshRequested == false)
                then LoggedIn;
            transition loggedIn_to_loggedOut
                first LoggedIn
                if (self.logoutRequested == true)
                then LoggedOut;
        }

        attribute refreshRequested : Boolean = false;
        attribute logoutRequested : Boolean = false;
    }

    // ===== QIVICON Home Base =====

    part def QIVICONHomeBase {
        attribute baseId : String;
        attribute serialNumber : String;
        attribute firmwareVersion : String;
        attribute localIP : String;
        attribute internetConnected : Boolean = false;
        attribute currentSecurityMode : SecurityModeKind = SecurityModeKind::home;
        port cloudIf : CloudBasePort;
        port deviceIf : BaseDevicePort;

        attribute registeredDevices : SmartDevice[*];

        action def routeCommandToDevice(cmd : UserCommand) {
            for device in registeredDevices {
                if (device.deviceId == cmd.targetDeviceId) {
                    send cmd to deviceIf.userCommands;
                }
            }
        }

        action def receiveCommandFromCloud(cmd : UserCommand) {
            if (cmd.commandType == CommandKind::setSecurityMode) {
                setSecurityMode(cmd.value);
            } else {
                routeCommandToDevice(cmd);
            }
        }

        action def setSecurityMode(modeValue : Real) {
            if (modeValue == 0) { currentSecurityMode := SecurityModeKind::home; }
            if (modeValue == 1) { currentSecurityMode := SecurityModeKind::away; }
            if (modeValue == 2) { currentSecurityMode := SecurityModeKind::night; }
        }

        action def receiveDeviceStatus(status : DeviceStatus) {
            send status to cloudIf.deviceStatuses;
        }

        action def receiveDeviceAlert(alert : Alert) {
            send alert to cloudIf.alerts;
        }

        action def registerDevice(device : SmartDevice) {
            append device to registeredDevices;
        }

        action def unregisterDevice(deviceId : String) {
            // remove device from registeredDevices
        }

        state def BaseOperation {
            initial start;
            state Booting;
            state Online;
            state Offline;
            state SecurityArmed;
            transition booting_to_online
                first Booting
                if (self.internetConnected == true)
                then Online;
            transition online_to_offline
                first Online
                if (self.internetConnected == false)
                then Offline;
            transition offline_to_online
                first Offline
                if (self.internetConnected == true)
                then Online;
            transition online_to_armed
                first Online
                if (self.currentSecurityMode == SecurityModeKind::away)
                then SecurityArmed;
            transition armed_to_online
                first SecurityArmed
                if (self.currentSecurityMode != SecurityModeKind::away)
                then Online;
        }
    }

    // ===== QIVICON System Top-Level =====

    part QIVICONSystem {
        part mobileApp : MobileApp {
            port cloudIf : CloudAppPort;
        }
        part cloudBackend : CloudBackend {
            port appIf : CloudAppPort;
            port baseIf : CloudBasePort;
        }
        part homeBase : QIVICONHomeBase {
            port cloudIf : CloudBasePort;
            port deviceIf : BaseDevicePort;
        }

        part thermostat1 : HeatingThermostat {
            attribute deviceId := "thermostat-livingroom";
            attribute deviceName := "Living Room Thermostat";
            port baseIf : DeviceBasePort;
        }
        part thermostat2 : HeatingThermostat {
            attribute deviceId := "thermostat-bedroom";
            attribute deviceName := "Bedroom Thermostat";
            port baseIf : DeviceBasePort;
        }
        part light1 : SmartLightBulb {
            attribute deviceId := "light-livingroom";
            attribute deviceName := "Living Room Light";
            port baseIf : DeviceBasePort;
        }
        part light2 : SmartLightBulb {
            attribute deviceId := "light-kitchen";
            attribute deviceName := "Kitchen Light";
            port baseIf : DeviceBasePort;
        }
        part doorSensor1 : DoorWindowSensor {
            attribute deviceId := "door-front";
            attribute deviceName := "Front Door Sensor";
            port baseIf : DeviceBasePort;
        }
        part windowSensor1 : DoorWindowSensor {
            attribute deviceId := "window-livingroom";
            attribute deviceName := "Living Room Window Sensor";
            port baseIf : DeviceBasePort;
        }
        part motionSensor1 : MotionSensor {
            attribute deviceId := "motion-hallway";
            attribute deviceName := "Hallway Motion Sensor";
            port baseIf : DeviceBasePort;
        }
        part motionSensor2 : MotionSensor {
            attribute deviceId := "motion-garage";
            attribute deviceName := "Garage Motion Sensor";
            port baseIf : DeviceBasePort;
        }
        part smartPlug1 : SmartPlug {
            attribute deviceId := "plug-livingroom";
            attribute deviceName := "Living Room Plug";
            port baseIf : DeviceBasePort;
        }
        part smartPlug2 : SmartPlug {
            attribute deviceId := "plug-kitchen";
            attribute deviceName := "Kitchen Plug";
            port baseIf : DeviceBasePort;
        }

        // Connections: App <-> Cloud
        connection appToCloud : AppToCloudInterface connect mobileApp.cloudIf to cloudBackend.appIf;

        // Connections: Cloud <-> Home Base
        connection cloudToBase : CloudToBaseInterface connect cloudBackend.baseIf to homeBase.cloudIf;

        // Connections: Home Base <-> Devices
        connection baseToThermostat1 : BaseToDeviceInterface connect homeBase.deviceIf to thermostat1.baseIf;
        connection baseToThermostat2 : BaseToDeviceInterface connect homeBase.deviceIf to thermostat2.baseIf;
        connection baseToLight1 : BaseToDeviceInterface connect homeBase.deviceIf to light1.baseIf;
        connection baseToLight2 : BaseToDeviceInterface connect homeBase.deviceIf to light2.baseIf;
        connection baseToDoorSensor1 : BaseToDeviceInterface connect homeBase.deviceIf to doorSensor1.baseIf;
        connection baseToWindowSensor1 : BaseToDeviceInterface connect homeBase.deviceIf to windowSensor1.baseIf;
        connection baseToMotionSensor1 : BaseToDeviceInterface connect homeBase.deviceIf to motionSensor1.baseIf;
        connection baseToMotionSensor2 : BaseToDeviceInterface connect homeBase.deviceIf to motionSensor2.baseIf;
        connection baseToPlug1 : BaseToDeviceInterface connect homeBase.deviceIf to smartPlug1.baseIf;
        connection baseToPlug2 : BaseToDeviceInterface connect homeBase.deviceIf to smartPlug2.baseIf;

        // Automation rules stored in cloud
        attribute automationRules : AutomationRule[*] := {
            AutomationRule { ruleId = "rule-001"; triggerDeviceId = "motion-hallway"; triggerCondition = "motionDetected and isAfterSunset"; actionDeviceId = "light-livingroom"; actionCommand = CommandKind::turnLightOn; actionValue = 80; enabled = true; },
            AutomationRule { ruleId = "rule-002"; triggerDeviceId = "door-front"; triggerCondition = "open and securityMode==away"; actionDeviceId = "motion-garage"; actionCommand = CommandKind::setSecurityMode; actionValue = 1; enabled = true; },
            AutomationRule { ruleId = "rule-003"; triggerDeviceId = "window-livingroom"; triggerCondition = "open"; actionDeviceId = "thermostat-livingroom"; actionCommand = CommandKind::setTemperature; actionValue = 18; enabled = true; }
        };
    }

    // ===== Requirements =====

    package QIVICONRequirements {

        requirement def RemoteAccessRequirement {
            doc /* The system shall allow users to monitor and control smart devices remotely via the Mobile App connected to the Cloud Backend. */
            attribute maxResponseTime : Time = 2.0;
            subject QIVICONSystem;
            objective {
                verify that all UserCommand messages sent from MobileApp reach the target SmartDevice within maxResponseTime;
            }
        }

        requirement def SecurityModeRequirement {
            doc /* The Home Base shall support home, away, and night security modes, each affecting device behavior and alert routing. */
            subject QIVICONHomeBase;
            objective {
                verify that currentSecurityMode can be set to SecurityModeKind::home, SecurityModeKind::away, or SecurityModeKind::night;
            }
        }

        requirement def AuthenticationRequirement {
            doc /* The Cloud Backend shall authenticate all user commands before relaying them to the Home Base. */
            subject CloudBackend;
            objective {
                verify that processUserCommand invokes authenticateUser before sending to baseIf.userCommands;
            }
        }

        requirement def AutomationRuleRequirement {
            doc /* The Cloud Backend shall evaluate automation rules upon receiving device status and trigger configured actions automatically. */
            subject CloudBackend;
            objective {
                verify that evaluateAutomationRules is invoked after receiveDeviceStatus;
            }
        }

        requirement def ThermostatControlRequirement {
            doc /* Heating Thermostats shall maintain the ambient temperature within +/-0.5 degrees of the target setpoint. */
            attribute tolerance : TemperatureValue = 0.5;
            subject HeatingThermostat;
            objective {
                verify that |currentTemperature - targetSetpoint| <= tolerance;
            }
        }

        requirement def LightControlRequirement {
            doc /* Smart Light Bulbs shall support on/off, brightness (0-100%), and color temperature adjustment. */
            subject SmartLightBulb;
            objective {
                verify that turnOn, turnOff, setBrightnessLevel, and setColorTemp actions exist and modify corresponding attributes;
            }
        }

        requirement def DoorWindowSensorRequirement {
            doc /* Door and Window Sensors shall detect open/closed states and emit alerts when opened while armed. */
            subject DoorWindowSensor;
            objective {
                verify that detectStateChange emits a doorOpenAlert when windowState is open and alertOnOpen is true;
            }
        }

        requirement def MotionSensorRequirement {
            doc /* Motion Sensors shall detect movement and emit motion alerts usable for security and automation. */
            subject MotionSensor;
            objective {
                verify that detectMotion emits a motionAlert when motionState is motionDetected;
            }
        }

        requirement def SmartPlugRequirement {
            doc /* Smart Plugs shall control appliance power and monitor real-time power and cumulative energy usage. */
            attribute maxLoad : PowerValue = 3680;
            subject SmartPlug;
            objective {
                verify that measurePower updates totalEnergy and emits powerOverloadAlert when currentPower exceeds maxLoad;
            }
        }

        requirement def HistoricalDataRequirement {
            doc /* The Cloud Backend shall store historical device data for at least 90 days. */
            attribute retentionDays : Integer = 90;
            subject CloudBackend;
            objective {
                verify that dataRetentionDays >= retentionDays;
            }
        }

        requirement def CommandRoutingRequirement {
            doc /* The Home Base shall route incoming commands from the Cloud Backend to the appropriate registered device. */
            subject QIVICONHomeBase;
            objective {
                verify that routeCommandToDevice sends the command to the device whose deviceId matches cmd.targetDeviceId;
            }
        }

        requirement QIVICONRemoteAccess : RemoteAccessRequirement {
            subject :>> QIVICONSystem;
        }

        requirement QIVICONSecurityModes : SecurityModeRequirement {
            subject :>> QIVICONSystem.homeBase;
        }

        requirement QIVICONAuthentication : AuthenticationRequirement {
            subject :>> QIVICONSystem.cloudBackend;
        }

        requirement QIVICONAutomation : AutomationRuleRequirement {
            subject :>> QIVICONSystem.cloudBackend;
        }

        requirement QIVICONThermostat : ThermostatControlRequirement {
            subject :>> QIVICONSystem.thermostat1;
        }

        requirement QIVICONLight : LightControlRequirement {
            subject :>> QIVICONSystem.light1;
        }

        requirement QIVICONDoorSensor : DoorWindowSensorRequirement {
            subject :>> QIVICONSystem.doorSensor1;
        }

        requirement QIVICONMotionSensor : MotionSensorRequirement {
            subject :>> QIVICONSystem.motionSensor1;
        }

        requirement QIVICONSmartPlug : SmartPlugRequirement {
            subject :>> QIVICONSystem.smartPlug1;
        }

        requirement QIVICONHistoricalData : HistoricalDataRequirement {
            subject :>> QIVICONSystem.cloudBackend;
        }

        requirement QIVICONCommandRouting : CommandRoutingRequirement {
            subject :>> QIVICONSystem.homeBase;
        }
    }
}
