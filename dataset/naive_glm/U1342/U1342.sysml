package SmartHomeAutomationSystem {

    // ─────────── Value Types with Units ───────────
    value type TemperatureValue :> Real { unit "°C"; }
    value type BrightnessValue :> Real { unit "%"; }
    value type HumidityValue :> Real { unit "%RH"; }
    value type PowerValue :> Real { unit "W"; }
    value type SignalStrengthValue :> Real { unit "dBm"; }
    value type TimeOfDayValue :> Real { unit "h"; }
    value type DataRateValue :> Real { unit "Mbps"; }

    // ─────────── Enumerations ───────────
    enumeration def WirelessProtocol {
        Zigbee;
        ZWave;
        WiFi;
        Bluetooth;
    }

    enumeration def DeviceCategory {
        LightBulb;
        TemperatureSensor;
        MotionSensor;
        Thermostat;
        DoorLock;
    }

    enumeration def LockStatus { Locked; Unlocked; }
    enumeration def MotionStatus { MotionDetected; NoMotion; }
    enumeration def InterfaceKind { MobileApp; WebDashboard; VoiceCommand; }
    enumeration def HubOperationalState { Initializing; Pairing; Operating; Error; }

    // ─────────── Item Definitions ───────────
    item def SensorReading {
        attribute sourceDeviceId : String;
        attribute timestamp : String;
    }

    item def TemperatureReading :> SensorReading {
        value temperature : TemperatureValue;
    }

    item def MotionReading :> SensorReading {
        value motionState : MotionStatus;
    }

    item def HumidityReading :> SensorReading {
        value humidity : HumidityValue;
    }

    item def DeviceCommand {
        attribute targetDeviceId : String;
        attribute commandId : String;
    }

    item def BrightnessCommand :> DeviceCommand {
        value brightnessLevel : BrightnessValue;
    }

    item def LockCommand :> DeviceCommand {
        value lockState : LockStatus;
    }

    item def ThermostatCommand :> DeviceCommand {
        value setpoint : TemperatureValue;
    }

    item def DeviceDiscovered {
        attribute deviceId : String;
        attribute deviceType : DeviceCategory;
        attribute protocol : WirelessProtocol;
        attribute zoneId : String;
    }

    item def AutomationRule {
        attribute ruleId : String;
        attribute description : String;
        attribute active : Boolean = true;
        attribute zoneId : String;
    }

    item def UserCommand {
        attribute commandId : String;
        attribute targetDeviceId : String;
        attribute payload : String;
        attribute source : InterfaceKind;
    }

    item def StatusReport {
        attribute hubState : HubOperationalState;
        attribute connectedDevices : Integer;
        attribute activeRules : Integer;
        attribute timestamp : String;
    }

    item def CloudSyncPayload {
        attribute deviceInfo : String;
        attribute ruleData : String;
        attribute timestamp : String;
    }

    // ─────────── Port Definitions ───────────
    port def WirelessCommunicationPort {
        inout item sensorReadings : SensorReading;
        inout item deviceCommands : DeviceCommand;
        inout item discoveredDevices : DeviceDiscovered;
    }

    port def InternalDataPort {
        out item sensorData : SensorReading;
        in item controlCommands : DeviceCommand;
    }

    port def UserInterfacePort {
        in item userCommands : UserCommand;
        out item statusReports : StatusReport;
    }

    port def CloudServicePort {
        out item backupPayload : CloudSyncPayload;
        in item syncPayload : CloudSyncPayload;
    }

    // ─────────── Action Definitions ───────────
    action def AutomationCycleAction {
        in tempReadings : TemperatureReading;
        in motionReadings : MotionReading;
        in currentTime : TimeOfDayValue;
        out brightnessCmd : BrightnessCommand;
        out lockCmd : LockCommand;
        out thermostatCmd : ThermostatCommand;

        action MonitorSensors {
            in tempIn : TemperatureReading;
            in motionIn : MotionReading;
            out currentTemp : TemperatureValue;
            out currentMotion : MotionStatus;
        }
        then action EvaluateRules {
            in currentTemp : TemperatureValue;
            in currentMotion : MotionStatus;
            in currentTime : TimeOfDayValue;
            out triggeredBrightness : BrightnessValue;
            out triggeredLock : LockStatus;
            out triggeredSetpoint : TemperatureValue;
            out ruleTriggered : Boolean;

            // Evening motion light rule
            if (currentMotion == MotionStatus::MotionDetected and currentTime >= 19) {
                assign triggeredBrightness = 50;
                assign ruleTriggered = true;
            }
        }
        then action ExecuteCommands {
            in triggeredBrightness : BrightnessValue;
            in triggeredLock : LockStatus;
            in triggeredSetpoint : TemperatureValue;
            in ruleTriggered : Boolean;
            out brightnessCmdOut : BrightnessCommand;
            out lockCmdOut : LockCommand;
            out thermostatCmdOut : ThermostatCommand;

            if (ruleTriggered) {
                assign brightnessCmdOut.brightnessLevel = triggeredBrightness;
                assign lockCmdOut.lockState = triggeredLock;
                assign thermostatCmdOut.setpoint = triggeredSetpoint;
            }
        }
    }

    action def PairDeviceAction {
        in deviceInfo : DeviceDiscovered;
        out pairedDeviceId : String;
        out success : Boolean;

        action ValidateDevice {
            in device : DeviceDiscovered;
            out valid : Boolean;
        }
        then action AssignNetworkId {
            in device : DeviceDiscovered;
            out networkId : String;
        }
        then action StoreDeviceRecord {
            in device : DeviceDiscovered;
            in networkId : String;
        }
    }

    // ─────────── Smart Device Definitions ───────────
    part def SmartDevice {
        attribute deviceId : String;
        attribute deviceType : DeviceCategory;
        attribute protocol : WirelessProtocol;
        attribute zoneId : String;
        attribute manufacturer : String;
        value signalStrength : SignalStrengthValue;
        port wirelessPort : WirelessCommunicationPort;

        action TransmitTelemetry {
            out reading : SensorReading;
            send reading through wirelessPort;
        }

        action ReceiveCommand {
            in command : DeviceCommand;
            receive command through wirelessPort;
        }
    }

    part def SmartLightBulb :> SmartDevice {
        attribute deviceType = DeviceCategory::LightBulb;
        value brightness : BrightnessValue = 0;
        value power : PowerValue = 0;
        value isOn : Boolean = false;

        action SetBrightness {
            in level : BrightnessValue;
            then assign brightness = level;
            then assign isOn = (level > 0);
        }

        action TurnOff {
            then assign brightness = 0;
            then assign isOn = false;
        }
    }

    part def TemperatureSensorDevice :> SmartDevice {
        attribute deviceType = DeviceCategory::TemperatureSensor;
        value currentTemperature : TemperatureValue;
        value samplingInterval : Integer = 30;

        action ReadTemperature {
            out reading : TemperatureReading;
            assign reading.temperature = currentTemperature;
            assign reading.sourceDeviceId = deviceId;
            send reading through wirelessPort;
        }
    }

    part def MotionSensorDevice :> SmartDevice {
        attribute deviceType = DeviceCategory::MotionSensor;
        value motionState : MotionStatus = MotionStatus::NoMotion;
        value detectionRange : Real = 7.0;

        action DetectMotion {
            out reading : MotionReading;
            assign reading.motionState = motionState;
            assign reading.sourceDeviceId = deviceId;
            send reading through wirelessPort;
        }
    }

    part def SmartThermostat :> SmartDevice {
        attribute deviceType = DeviceCategory::Thermostat;
        value setpoint : TemperatureValue = 22;
        value currentTemperature : TemperatureValue;
        value currentHumidity : HumidityValue;

        action SetSetpoint {
            in newSetpoint : TemperatureValue;
            then assign setpoint = newSetpoint;
        }

        action ReadClimate {
            out tempReading : TemperatureReading;
            assign tempReading.temperature = currentTemperature;
            send tempReading through wirelessPort;
        }
    }

    part def ElectronicDoorLock :> SmartDevice {
        attribute deviceType = DeviceCategory::DoorLock;
        value lockState : LockStatus = LockStatus::Locked;
        value batteryLevel : Integer = 100;

        action SetLockState {
            in newState : LockStatus;
            then assign lockState = newState;
        }

        action ToggleLock {
            if (lockState == LockStatus::Locked) {
                assign lockState = LockStatus::Unlocked;
            } else {
                assign lockState = LockStatus::Locked;
            }
        }
    }

    // ─────────── Zone Definition ───────────
    part def Zone {
        attribute zoneId : String;
        attribute zoneName : String;
        attribute description : String;
        part devices : SmartDevice[0..100];

        action AddDevice {
            in device : SmartDevice;
        }

        action RemoveDevice {
            in deviceId : String;
        }

        action ListDevices {
            out deviceList : SmartDevice[0..*];
        }
    }

    // ─────────── Communication Module ───────────
    part def CommunicationModule {
        attribute supportedProtocols : WirelessProtocol[4] = [
            WirelessProtocol::Zigbee,
            WirelessProtocol::ZWave,
            WirelessProtocol::WiFi,
            WirelessProtocol::Bluetooth
        ];
        value maxDevices : Integer = 100;
        value activeConnections : Integer = 0;
        value dataRate : DataRateValue;
        port wirelessPort : WirelessCommunicationPort;
        port internalPort : InternalDataPort;

        action TransmitCommand {
            in device : SmartDevice;
            in command : DeviceCommand;
            send command through wirelessPort;
        }

        action ReceiveSensorData {
            out reading : SensorReading;
            receive reading through wirelessPort;
            send reading through internalPort;
        }

        action PairDevice {
            in deviceInfo : DeviceDiscovered;
            then action ValidateProtocol {
                in protocol : WirelessProtocol;
                out supported : Boolean;
            }
            then action AssignNetworkAddress {
                in device : DeviceDiscovered;
                out networkAddress : String;
            }
            then assign activeConnections = activeConnections + 1;
        }

        action UnpairDevice {
            in deviceId : String;
            then assign activeConnections = activeConnections - 1;
        }

        action ScanForDevices {
            out discovered : DeviceDiscovered[0..*];
        }
    }

    // ─────────── Local Database ───────────
    part def LocalDatabase {
        attribute deviceRecords : String[0..100];
        attribute ruleRecords : String[0..*];
        attribute configRecords : String[0..*];
        value storageUsed : Integer = 0;
        value maxStorage : Integer = 1024;

        action StoreDeviceInfo {
            in device : SmartDevice;
            then append device.deviceId to deviceRecords;
        }

        action StoreRule {
            in rule : AutomationRule;
            then append rule.ruleId to ruleRecords;
        }

        action RetrieveRules {
            out rules : AutomationRule[0..*];
        }

        action RetrieveDevices {
            out devices : SmartDevice[0..100];
        }

        action DeleteRule {
            in ruleId : String;
        }

        action UpdateDevice {
            in deviceId : String;
            in updatedInfo : String;
        }
    }

    // ─────────── Cloud Service ───────────
    part def CloudService {
        attribute serviceEndpoint : String = "https://cloud.homey.example.com";
        attribute apiKey : String;
        value isConnected : Boolean = false;
        port cloudPort : CloudServicePort;

        action SyncData {
            in payload : CloudSyncPayload;
            out response : CloudSyncPayload;
            receive payload through cloudPort;
            send response through cloudPort;
        }

        action BackupConfiguration {
            in payload : CloudSyncPayload;
            send payload through cloudPort;
        }

        action RestoreConfiguration {
            out payload : CloudSyncPayload;
            receive payload through cloudPort;
        }

        action Authenticate {
            in key : String;
            out authenticated : Boolean;
            then assign isConnected = true;
        }
    }

    // ─────────── User Interface Definitions ───────────
    part def UserInterface {
        attribute interfaceType : InterfaceKind;
        value isActive : Boolean = false;
        port uiPort : UserInterfacePort;

        action SendCommand {
            in command : UserCommand;
            send command through uiPort;
        }

        action ReceiveStatus {
            in status : StatusReport;
            receive status through uiPort;
        }
    }

    part def MobileAppUI :> UserInterface {
        attribute interfaceType = InterfaceKind::MobileApp;
        attribute appVersion : String = "3.2.1";
        value pushNotificationsEnabled : Boolean = true;

        action SendPushNotification {
            in message : String;
        }
    }

    part def WebDashboardUI :> UserInterface {
        attribute interfaceType = InterfaceKind::WebDashboard;
        attribute url : String = "https://homey.local/dashboard";

        action RenderDashboard {
            in status : StatusReport;
        }
    }

    part def VoiceCommandUI :> UserInterface {
        attribute interfaceType = InterfaceKind::VoiceCommand;
        attribute wakeWord : String = "Hey Homey";
        value listening : Boolean = false;

        action ProcessVoiceInput {
            in audioInput : String;
            out command : UserCommand;
        }
    }

    // ─────────── Automation Controller ───────────
    part def AutomationController {
        attribute rules : AutomationRule[0..*];
        value cycleInterval : Integer = 1000;
        value rulesActive : Integer = 0;
        port sensorInput : ~InternalDataPort;
        port controlOutput : InternalDataPort;

        action RunAutomationCycle {
            in tempReadings : TemperatureReading;
            in motionReadings : MotionReading;
            in currentTime : TimeOfDayValue;
            out brightnessCmd : BrightnessCommand;
            out lockCmd : LockCommand;
            out thermostatCmd : ThermostatCommand;

            action Monitor {
                in tempIn : TemperatureReading;
                in motionIn : MotionReading;
                out temp : TemperatureValue;
                out motion : MotionStatus;
            }
            then action Evaluate {
                in temp : TemperatureValue;
                in motion : MotionStatus;
                in time : TimeOfDayValue;
                out brightnessLevel : BrightnessValue;
                out lockTarget : LockStatus;
                out setpointTarget : TemperatureValue;
                out triggered : Boolean;

                if (motion == MotionStatus::MotionDetected and time >= 19) {
                    assign brightnessLevel = 50;
                    assign triggered = true;
                }
            }
            then action Execute {
                in brightnessLevel : BrightnessValue;
                in lockTarget : LockStatus;
                in setpointTarget : TemperatureValue;
                in triggered : Boolean;
                out bCmd : BrightnessCommand;
                out lCmd : LockCommand;
                out tCmd : ThermostatCommand;

                if (triggered) {
                    assign bCmd.brightnessLevel = brightnessLevel;
                    assign lCmd.lockState = lockTarget;
                    assign tCmd.setpoint = setpointTarget;
                    send bCmd through controlOutput;
                    send lCmd through controlOutput;
                    send tCmd through controlOutput;
                }
            }
        }

        action AddRule {
            in rule : AutomationRule;
            then append rule to rules;
            then assign rulesActive = rulesActive + 1;
        }

        action RemoveRule {
            in ruleId : String;
            then assign rulesActive = rulesActive - 1;
        }

        action UpdateRule {
            in ruleId : String;
            in updatedRule : AutomationRule;
        }
    }

    // ─────────── Homey Hub ───────────
    part def HomeyHub {
        attribute hubId : String = "HOMEY-HUB-001";
        attribute firmwareVersion : String = "5.0.2";
        attribute model : String = "Homey Pro";
        value uptime : Integer = 0;
        value connectedDeviceCount : Integer = 0;

        part commModule : CommunicationModule;
        part automationCtrl : AutomationController;
        part localDB : LocalDatabase;

        port uiPort : UserInterfacePort;
        port cloudPort : CloudServicePort;

        part mobileApp : MobileAppUI;
        part webDashboard : WebDashboardUI;
        part voiceInterface : VoiceCommandUI;

        part cloudService : CloudService;

        // Internal connections
        connection CommToAutomation {
            from commModule.internalPort to automationCtrl.sensorInput;
        }

        connection AutomationToComm {
            from automationCtrl.controlOutput to commModule.internalPort;
        }

        connection MobileAppToHub {
            from mobileApp.uiPort to uiPort;
        }

        connection WebDashboardToHub {
            from webDashboard.uiPort to uiPort;
        }

        connection VoiceInterfaceToHub {
            from voiceInterface.uiPort to uiPort;
        }

        connection HubToCloud {
            from cloudPort to cloudService.cloudPort;
        }

        // Hub State Machine
        state HubStateMachine {
            entry; then initializing;

            state initializing {
                entry action InitStartup {
                    // Load device info and rules from local database
                    localDB.RetrieveDevices();
                    localDB.RetrieveRules();
                    commModule.ScanForDevices();
                }
                do action WaitForConnections {
                    // Wait for device connections to be established
                }
                exit action LogInitialized {
                    assign uptime = 0;
                }
            }

            state pairing {
                entry action StartPairingMode {
                    commModule.ScanForDevices();
                }
                do action PairingLoop {
                    // Continuously listen for new device pairing requests
                    commModule.PairDevice();
                }
                exit action PairingComplete {
                    // Store newly paired devices
                    localDB.StoreDeviceInfo();
                }
            }

            state operating {
                entry action StartAutomation {
                    // Begin continuous automation cycle
                    automationCtrl.RunAutomationCycle();
                }
                do action ContinuousAutomation {
                    while (true) {
                        automationCtrl.RunAutomationCycle();
                    }
                }
                exit action PauseAutomation {
                    // Pause automation before leaving operating state
                }
            }

            state error {
                entry action LogError {
                    // Log fault details to local database
                }
                do action AttemptRecovery {
                    commModule.ScanForDevices();
                    localDB.RetrieveDevices();
                    localDB.RetrieveRules();
                }
                exit action ClearError {
                    // Clear error state and prepare for reinitialization
                }
            }

            transition InitToOperating {
                from initializing to operating when commModule.activeConnections > 0;
            }

            transition InitToPairing {
                from initializing to pairing;
            }

            transition PairingToOperating {
                from pairing to operating;
            }

            transition OperatingToPairing {
                from operating to pairing;
            }

            transition OperatingToError {
                from operating to error when commModule.activeConnections == 0;
            }

            transition ErrorToInit {
                from error to initializing;
            }
        }

        action ProcessUserCommand {
            in command : UserCommand;
            out response : StatusReport;

            if (command.commandId == "pair") {
                // Trigger pairing mode
            } else if (command.commandId == "setBrightness") {
                // Forward brightness command to target device
                commModule.TransmitCommand();
            } else if (command.commandId == "setTemperature") {
                // Forward thermostat command
                commModule.TransmitCommand();
            } else if (command.commandId == "lockDoor") {
                // Forward lock command
                commModule.TransmitCommand();
            }
        }

        action SyncWithCloud {
            out payload : CloudSyncPayload;
            cloudService.BackupConfiguration();
        }

        action GenerateStatusReport {
            out report : StatusReport;
            assign report.hubState = HubOperationalState::Operating;
            assign report.connectedDevices = connectedDeviceCount;
            assign report.activeRules = automationCtrl.rulesActive;
        }
    }

    // ─────────── Smart Home (Concrete Instance) ───────────
    part def SmartHome {
        attribute homeName : String = "Smart Residence";
        attribute homeId : String = "HOME-001";

        part hub : HomeyHub;

        // Zones
        part livingRoom : Zone {
            attribute zoneId = "Z1";
            attribute zoneName = "Living Room";
            attribute description = "Main living area with entertainment system";

            part ceilingLight : SmartLightBulb {
                attribute deviceId = "LR-LIGHT-001";
                attribute protocol = WirelessProtocol::Zigbee;
                attribute zoneId = "Z1";
                attribute manufacturer = "Philips Hue";
            }

            part floorLamp : SmartLightBulb {
                attribute deviceId = "LR-LIGHT-002";
                attribute protocol = WirelessProtocol::Zigbee;
                attribute zoneId = "Z1";
                attribute manufacturer = "Philips Hue";
            }

            part tempSensor : TemperatureSensorDevice {
                attribute deviceId = "LR-TEMP-001";
                attribute protocol = WirelessProtocol::Bluetooth;
                attribute zoneId = "Z1";
                attribute manufacturer = "Xiaomi";
                value currentTemperature = 21.5;
            }
        }

        part bedroom : Zone {
            attribute zoneId = "Z2";
            attribute zoneName = "Bedroom";
            attribute description = "Master bedroom";

            part thermostat : SmartThermostat {
                attribute deviceId = "BR-THERM-001";
                attribute protocol = WirelessProtocol::ZWave;
                attribute zoneId = "Z2";
                attribute manufacturer = "Nest";
                value setpoint = 20.0;
                value currentTemperature = 19.8;
            }

            part bedsideLight : SmartLightBulb {
                attribute deviceId = "BR-LIGHT-001";
                attribute protocol = WirelessProtocol::Zigbee;
                attribute zoneId = "Z2";
                attribute manufacturer = "Philips Hue";
            }
        }

        part entrance : Zone {
            attribute zoneId = "Z3";
            attribute zoneName = "Entrance";
            attribute description = "Front entrance and hallway";

            part motionSensor : MotionSensorDevice {
                attribute deviceId = "EN-MOTION-001";
                attribute protocol = WirelessProtocol::Zigbee;
                attribute zoneId = "Z3";
                attribute manufacturer = "Aqara";
                value motionState = MotionStatus::NoMotion;
            }

            part doorLock : ElectronicDoorLock {
                attribute deviceId = "EN-LOCK-001";
                attribute protocol = WirelessProtocol::ZWave;
                attribute zoneId = "Z3";
                attribute manufacturer = "Yale";
                value lockState = LockStatus::Locked;
            }

            part entranceLight : SmartLightBulb {
                attribute deviceId = "EN-LIGHT-001";
                attribute protocol = WirelessProtocol::Zigbee;
                attribute zoneId = "Z3";
                attribute manufacturer = "Philips Hue";
            }
        }

        // Connections from hub to devices
        connection HubToCeilingLight {
            from hub.commModule.wirelessPort to livingRoom.ceilingLight.wirelessPort;
        }

        connection HubToFloorLamp {
            from hub.commModule.wirelessPort to livingRoom.floorLamp.wirelessPort;
        }

        connection HubToLivingRoomTemp {
            from hub.commModule.wirelessPort to livingRoom.tempSensor.wirelessPort;
        }

        connection HubToBedroomThermostat {
            from hub.commModule.wirelessPort to bedroom.thermostat.wirelessPort;
        }

        connection HubToBedsideLight {
            from hub.commModule.wirelessPort to bedroom.bedsideLight.wirelessPort;
        }

        connection HubToEntranceMotion {
            from hub.commModule.wirelessPort to entrance.motionSensor.wirelessPort;
        }

        connection HubToEntranceLock {
            from hub.commModule.wirelessPort to entrance.doorLock.wirelessPort;
        }

        connection HubToEntranceLight {
            from hub.commModule.wirelessPort to entrance.entranceLight.wirelessPort;
        }

        // Evening motion light automation rule
        action EveningMotionLightRule {
            in motionReading : MotionReading;
            in currentTime : TimeOfDayValue;
            out brightnessCommand : BrightnessCommand;

            if (motionReading.motionState == MotionStatus::MotionDetected and currentTime >= 19) {
                assign brightnessCommand.targetDeviceId = "LR-LIGHT-001";
                assign brightnessCommand.brightnessLevel = 50;
                assign brightnessCommand.commandId = "setBrightness";
                hub.commModule.TransmitCommand(
                    device = livingRoom.ceilingLight,
                    command = brightnessCommand
                );
            }
        }
    }

    // ─────────── Requirements ───────────
    requirement MultiProtocolSupport {
        doc "The Homey Hub shall support Zigbee, Z-Wave, WiFi, and Bluetooth wireless protocols for device communication.";
        subject hub : HomeyHub;
        constraint {
            hub.commModule.supportedProtocols == [
                WirelessProtocol::Zigbee,
                WirelessProtocol::ZWave,
                WirelessProtocol::WiFi,
                WirelessProtocol::Bluetooth
            ]
        }
    }

    requirement DeviceCapacity {
        doc "The Homey Hub shall manage up to 100 smart devices simultaneously.";
        subject hub : HomeyHub;
        constraint { hub.commModule.maxDevices == 100 }
    }

    requirement ZoneOrganization {
        doc "The system shall organize smart devices into logical zones including Living Room, Bedroom, and Entrance.";
        subject home : SmartHome;
        constraint {
            home.livingRoom.zoneName == "Living Room" and
            home.bedroom.zoneName == "Bedroom" and
            home.entrance.zoneName == "Entrance"
        }
    }

    requirement ContinuousAutomationCycle {
        doc "The Automation Controller shall continuously monitor sensor inputs, evaluate user-defined rules, and execute commands when conditions are met.";
        subject hub : HomeyHub;
        constraint {
            hub.automationCtrl.RunAutomationCycle.isInvoked == true
        }
    }

    requirement MultiInterfaceControl {
        doc "The system shall be controllable through a mobile app, web dashboard, and voice commands.";
        subject hub : HomeyHub;
        constraint {
            hub.mobileApp.interfaceType == InterfaceKind::MobileApp and
            hub.webDashboard.interfaceType == InterfaceKind::WebDashboard and
            hub.voiceInterface.interfaceType == InterfaceKind::VoiceCommand
        }
    }

    requirement CloudConnectivity {
        doc "The hub shall maintain a connection to a cloud service for remote access and data backup.";
        subject hub : HomeyHub;
        constraint { hub.cloudService.isConnected == true }
    }

    requirement LocalDataPersistence {
        doc "The hub shall include a local database to store device information and automation rules.";
        subject hub : HomeyHub;
        constraint {
            hub.localDB.deviceRecords.size() >= 0 and
            hub.localDB.ruleRecords.size() >= 0
        }
    }

    requirement HubStateManagement {
        doc "The hub shall transition through initializing, pairing, operating, and error states during its lifecycle.";
        subject hub : HomeyHub;
        constraint {
            hub.HubStateMachine.states == {
                HubOperationalState::Initializing,
                HubOperationalState::Pairing,
                HubOperationalState::Operating,
                HubOperationalState::Error
            }
        }
    }

    requirement EveningMotionLightAutomation {
        doc "If the entrance motion sensor detects movement after 7 PM (19:00), the living room ceiling light shall be turned on to 50% brightness.";
        subject home : SmartHome;
        constraint {
            (home.entrance.motionSensor.motionState == MotionStatus::MotionDetected and
             currentTime >= 19)
            implies (home.livingRoom.ceilingLight.brightness == 50)
        }
    }

    requirement ErrorRecovery {
        doc "The hub shall enter an error state upon fault detection and attempt automatic recovery before reinitializing.";
        subject hub : HomeyHub;
        constraint {
            hub.HubStateMachine.error.entry.LogError.isInvoked == true and
            hub.HubStateMachine.error.do.AttemptRecovery.isInvoked == true
        }
    }

    // ─────────── Requirement Satisfaction ───────────
    satisfy MultiProtocolSupport by hub.commModule;
    satisfy DeviceCapacity by hub.commModule;
    satisfy ZoneOrganization by SmartHome;
    satisfy ContinuousAutomationCycle by hub.automationCtrl;
    satisfy MultiInterfaceControl by hub;
    satisfy CloudConnectivity by hub.cloudService;
    satisfy LocalDataPersistence by hub.localDB;
    satisfy HubStateManagement by hub.HubStateMachine;
    satisfy EveningMotionLightAutomation by SmartHome.EveningMotionLightRule;
    satisfy ErrorRecovery by hub.HubStateMachine;
}
