package VivintSmartHomeSecuritySystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    value def BatteryLevel :> Real { unit : '%' [battery]; }
    value def SignalStrength :> Real { unit : 'dBm'; }
    value def SoundPressureLevel :> Real { unit : 'dB'; }
    value def VideoResolution :> Real { unit : 'pixel'; }
    value def Temperature :> Real { unit : 'C'; }
    value def Distance :> Real { unit : 'm'; }
    value def DataRate :> Real { unit : 'Mbps'; }
    value def Timestamp :> String;
    value def Duration_s :> Real { unit : 's'; }
    value def Voltage :> Real { unit : 'V'; }
    value def Current :> Real { unit : 'A'; }
    value def Frequency :> Real { unit : 'Hz'; }

    // ===== Enumerations =====

    enum def SystemMode {
        DISARMED;
        ARMED_AWAY;
        ARMED_STAY;
    }

    enum def ThreatLevel {
        NONE;
        LOW;
        MEDIUM;
        HIGH;
        CONFIRMED;
    }

    enum def SensorState {
        NORMAL;
        TRIGGERED;
        TAMPERED;
        OFFLINE;
    }

    enum def LockState {
        LOCKED;
        UNLOCKED;
    }

    enum def AlertType {
        INTRUSION;
        MOTION_DETECTED;
        DOORBELL_RING;
        TAMPER;
        LOW_BATTERY;
        POWER_OUTAGE;
    }

    enum def ConnectivityType {
        WIFI;
        ZWAVE;
        ZIGBEE;
        CELLULAR;
        ETHERNET;
    }

    // ===== Item Definitions =====

    item def SensorEvent {
        attribute sensorId : String;
        attribute sensorType : String;
        attribute timestamp : Timestamp;
        attribute state : SensorState;
        attribute location : String;
    }

    item def SecurityAlert {
        attribute alertId : String;
        attribute alertType : AlertType;
        attribute threatLevel : ThreatLevel;
        attribute timestamp : Timestamp;
        attribute sourceSensorId : String;
        attribute location : String;
        attribute description : String;
    }

    item def VideoStream {
        attribute cameraId : String;
        attribute resolution : VideoResolution;
        attribute isNightVision : Boolean;
        attribute isRecording : Boolean;
        attribute timestamp : Timestamp;
    }

    item def VideoRecording {
        attribute recordingId : String;
        attribute cameraId : String;
        attribute startTime : Timestamp;
        attribute duration : Duration_s;
        attribute storageLocation : String;
    }

    item def NotificationMessage {
        attribute notificationId : String;
        attribute recipientDevice : String;
        attribute alert : SecurityAlert;
        attribute timestamp : Timestamp;
        attribute messageText : String;
    }

    item def LockCommand {
        attribute lockId : String;
        attribute targetState : LockState;
        attribute source : String;
        attribute timestamp : Timestamp;
    }

    item def SystemCommand {
        attribute commandId : String;
        attribute targetMode : SystemMode;
        attribute source : String;
        attribute timestamp : Timestamp;
        attribute authorized : Boolean;
    }

    item def EventLog {
        attribute logId : String;
        attribute timestamp : Timestamp;
        attribute eventType : String;
        attribute description : String;
        attribute deviceId : String;
    }

    // ===== Port Definitions =====

    port def WirelessPort {
        attribute protocol : ConnectivityType;
        attribute signalStrength : SignalStrength;
        out item events : SensorEvent[*];
        in item commands : SystemCommand[*];
    }

    port def VideoPort {
        attribute dataRate : DataRate;
        out item stream : VideoStream;
    }

    port def CloudPort {
        attribute protocol : ConnectivityType;
        out item alerts : SecurityAlert[*];
        out item recordings : VideoRecording[*];
        out item notifications : NotificationMessage[*];
        in item commands : SystemCommand[*];
        in item lockCommands : LockCommand[*];
    }

    port def PowerPort {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute hasBackup : Boolean;
    }

    port def AudioPort {
        attribute maxSPL : SoundPressureLevel;
        attribute hasStrobe : Boolean;
    }

    // ===== Part Definitions =====

    part def Battery {
        attribute capacity_mAh : Real;
        attribute currentLevel : BatteryLevel;
        attribute voltage : Voltage;

        action def discharge : Duration_s;
        action def recharge : Duration_s;

        state def BatteryHealth {
            state FULL;
            state DEPLETED;
            transition FULL to DEPLETED when currentLevel < 10;
            transition DEPLETED to FULL when currentLevel >= 95;
        }
    }

    part def CentralHub {
        attribute hubId : String;
        attribute firmwareVersion : String;
        attribute currentMode : SystemMode;
        attribute currentThreatLevel : ThreatLevel;
        attribute isOnline : Boolean;
        attribute cellularBackupActive : Boolean;

        port wirelessCoordPort : WirelessPort {
            attribute protocol = ConnectivityType::ZIGBEE;
        }
        port cloudCommPort : CloudPort {
            attribute protocol = ConnectivityType::WIFI;
        }
        port powerInput : PowerPort {
            attribute hasBackup = true;
        }

        part backupBattery : Battery {
            attribute capacity_mAh = 2000;
            attribute currentLevel : BatteryLevel = 100;
            attribute voltage : Voltage = 12;
        }

        action def evaluateThreat(in event : SensorEvent) : ThreatLevel;
        action def activateResponse(in alert : SecurityAlert);
        action def sendAlert(in alert : SecurityAlert);
        action def changeMode(in command : SystemCommand);
        action def logEvent(in event : EventLog);

        state def HubOperation {
            entry action { currentMode = SystemMode::DISARMED; }

            state DISARMED {
                entry action { currentMode = SystemMode::DISARMED; }
                during action { /* continuous sensor monitoring, no alarm response */ }
            }

            state ARMED_AWAY {
                entry action { currentMode = SystemMode::ARMED_AWAY; }
                during action { /* monitor all sensors, trigger on any event */ }
            }

            state ARMED_STAY {
                entry action { currentMode = SystemMode::ARMED_STAY; }
                during action { /* monitor perimeter sensors only, ignore interior motion */ }
            }

            state ALARM_ACTIVE {
                entry action { currentThreatLevel = ThreatLevel::CONFIRMED; }
                during action { /* sirens active, cameras recording, alerts sent */ }
            }

            transition DISARMED to ARMED_AWAY
                when cloudCommPort.commands.targetMode == SystemMode::ARMED_AWAY;
            transition DISARMED to ARMED_STAY
                when cloudCommPort.commands.targetMode == SystemMode::ARMED_STAY;
            transition ARMED_AWAY to DISARMED
                when cloudCommPort.commands.targetMode == SystemMode::DISARMED;
            transition ARMED_STAY to DISARMED
                when cloudCommPort.commands.targetMode == SystemMode::DISARMED;
            transition ARMED_AWAY to ALARM_ACTIVE
                when currentThreatLevel == ThreatLevel::CONFIRMED;
            transition ARMED_STAY to ALARM_ACTIVE
                when currentThreatLevel == ThreatLevel::CONFIRMED;
            transition ALARM_ACTIVE to DISARMED
                when cloudCommPort.commands.targetMode == SystemMode::DISARMED;
        }
    }

    part def ContactSensor {
        attribute sensorId : String;
        attribute location : String;
        attribute sensorType : String = "Contact";
        attribute currentState : SensorState = SensorState::NORMAL;
        attribute batteryLevel : BatteryLevel;
        attribute isTampered : Boolean = false;

        port wirelessPort : WirelessPort {
            attribute protocol = ConnectivityType::ZIGBEE;
        }

        action def detectOpen() : SensorEvent;
        action def detectClose() : SensorEvent;
        action def detectTamper() : SensorEvent;
        action def reportState() : SensorEvent;

        state def ContactSensorOperation {
            state NORMAL;
            state TRIGGERED;
            state TAMPERED;

            transition NORMAL to TRIGGERED when /* door/window opened */ true;
            transition TRIGGERED to NORMAL when /* door/window closed */ true;
            transition NORMAL to TAMPERED when isTampered == true;
            transition TRIGGERED to TAMPERED when isTampered == true;
        }
    }

    part def MotionSensor {
        attribute sensorId : String;
        attribute location : String;
        attribute sensorType : String = "Motion";
        attribute currentState : SensorState = SensorState::NORMAL;
        attribute detectionRange : Distance;
        attribute batteryLevel : BatteryLevel;
        attribute sensitivity : Real;

        port wirelessPort : WirelessPort {
            attribute protocol = ConnectivityType::ZIGBEE;
        }

        action def detectMotion() : SensorEvent;
        action def reportState() : SensorEvent;

        state def MotionSensorOperation {
            state IDLE;
            state MOTION_DETECTED;
            state TAMPERED;

            transition IDLE to MOTION_DETECTED when /* motion detected */ true;
            transition MOTION_DETECTED to IDLE when /* no motion for 30s */ true;
        }
    }

    part def SmartCamera {
        attribute cameraId : String;
        attribute location : String;
        attribute resolution : VideoResolution;
        attribute hasNightVision : Boolean = true;
        attribute isRecording : Boolean = false;
        attribute fieldOfView : Real;
        attribute isOnline : Boolean = true;

        port videoPort : VideoPort;
        port wirelessPort : WirelessPort {
            attribute protocol = ConnectivityType::WIFI;
        }

        action def startRecording() : VideoStream;
        action def stopRecording() : VideoRecording;
        action def streamLive() : VideoStream;
        action def detectPerson() : SensorEvent;
        action def enableNightVision();

        state def CameraOperation {
            state IDLE;
            state STREAMING;
            state RECORDING;
            state NIGHT_VISION_ACTIVE;

            transition IDLE to STREAMING when /* live view requested */ true;
            transition IDLE to RECORDING when /* alarm triggered */ true;
            transition STREAMING to RECORDING when /* alarm triggered */ true;
            transition IDLE to NIGHT_VISION_ACTIVE when /* low light detected */ true;
            transition NIGHT_VISION_ACTIVE to IDLE when /* sufficient light */ true;
            transition RECORDING to IDLE when /* recording stopped */ true;
        }
    }

    part def SmartDoorbell {
        attribute doorbellId : String;
        attribute location : String = "Front Door";
        attribute hasCamera : Boolean = true;
        attribute hasTwoWayAudio : Boolean = true;
        attribute resolution : VideoResolution;
        attribute isOnline : Boolean = true;

        port videoPort : VideoPort;
        port wirelessPort : WirelessPort {
            attribute protocol = ConnectivityType::WIFI;
        }

        action def ringDetected() : SensorEvent;
        action def detectVisitor() : SensorEvent;
        action def streamLive() : VideoStream;
        action def startRecording() : VideoStream;

        state def DoorbellOperation {
            state IDLE;
            state RINGING;
            state RECORDING;
            state TWO_WAY_AUDIO;

            transition IDLE to RINGING when /* button pressed */ true;
            transition RINGING to IDLE when /* ring acknowledged */ true;
            transition IDLE to RECORDING when /* motion detected */ true;
            transition RINGING to TWO_WAY_AUDIO when /* user answers */ true;
            transition TWO_WAY_AUDIO to IDLE when /* call ended */ true;
        }
    }

    part def Siren {
        attribute sirenId : String;
        attribute location : String;
        attribute isIndoor : Boolean;
        attribute maxSPL : SoundPressureLevel;
        attribute hasStrobe : Boolean = true;
        attribute isActive : Boolean = false;

        port audioPort : AudioPort;
        port wirelessPort : WirelessPort {
            attribute protocol = ConnectivityType::ZIGBEE;
        }

        action def activate();
        action def deactivate();
        action def testSiren();

        state def SirenOperation {
            state OFF;
            state ACTIVE;
            state TESTING;

            transition OFF to ACTIVE when /* alarm command received */ true;
            transition ACTIVE to OFF when /* alarm cleared */ true;
            transition OFF to TESTING when /* test command received */ true;
            transition TESTING to OFF when /* test complete */ true;
        }
    }

    part def SmartLock {
        attribute lockId : String;
        attribute location : String;
        attribute currentState : LockState = LockState::LOCKED;
        attribute autoLockEnabled : Boolean = true;
        attribute autoLockDelay : Duration_s;
        attribute batteryLevel : BatteryLevel;

        port wirelessPort : WirelessPort {
            attribute protocol = ConnectivityType::ZIGBEE;
        }

        action def lock() : LockCommand;
        action def unlock() : LockCommand;
        action def autoLock();

        state def LockOperation {
            state LOCKED;
            state UNLOCKED;
            state AUTO_LOCK_PENDING;

            transition LOCKED to UNLOCKED when /* unlock command received */ true;
            transition UNLOCKED to LOCKED when /* lock command received */ true;
            transition UNLOCKED to AUTO_LOCK_PENDING when autoLockEnabled == true;
            transition AUTO_LOCK_PENDING to LOCKED when /* autoLockDelay elapsed */ true;
        }
    }

    part def ControlPanel {
        attribute panelId : String;
        attribute location : String = "Main Entry";
        attribute isOnline : Boolean = true;
        attribute touchscreenEnabled : Boolean = true;

        port wirelessPort : WirelessPort {
            attribute protocol = ConnectivityType::ZIGBEE;
        }

        action def armAway() : SystemCommand;
        action def armStay() : SystemCommand;
        action def disarm() : SystemCommand;
        action def triggerPanic();
        action def displayStatus(in mode : SystemMode, in threat : ThreatLevel);
        action def authenticateUser(in pin : String) : Boolean;

        state def PanelOperation {
            state LOCKED_SCREEN;
            state UNLOCKED_SCREEN;
            state ARMING;
            state DISARMING;
            state PANIC;

            transition LOCKED_SCREEN to UNLOCKED_SCREEN when /* user authenticated */ true;
            transition UNLOCKED_SCREEN to LOCKED_SCREEN when /* timeout */ true;
            transition UNLOCKED_SCREEN to ARMING when /* arm command */ true;
            transition UNLOCKED_SCREEN to DISARMING when /* disarm command */ true;
            transition UNLOCKED_SCREEN to PANIC when /* panic button */ true;
            transition ARMING to LOCKED_SCREEN when /* arming complete */ true;
            transition DISARMING to LOCKED_SCREEN when /* disarming complete */ true;
            transition PANIC to LOCKED_SCREEN when /* panic cleared */ true;
        }
    }

    part def CloudService {
        attribute serviceId : String;
        attribute apiEndpoint : String;
        attribute storageCapacityGB : Real;
        attribute isAvailable : Boolean = true;
        attribute encryptionEnabled : Boolean = true;

        port cloudPort : CloudPort {
            attribute protocol = ConnectivityType::ETHERNET;
        }

        action def receiveAlert(in alert : SecurityAlert);
        action def storeRecording(in recording : VideoRecording);
        action def sendNotification(in alert : SecurityAlert) : NotificationMessage;
        action def processCommand(in command : SystemCommand) : Boolean;
        action def authenticateUser(in credentials : String) : Boolean;
        action def logEvent(in event : EventLog);

        state def CloudOperation {
            state AVAILABLE;
            state MAINTENANCE;
            state DEGRADED;

            transition AVAILABLE to MAINTENANCE when /* scheduled maintenance */ true;
            transition MAINTENANCE to AVAILABLE when /* maintenance complete */ true;
            transition AVAILABLE to DEGRADED when /* high load */ true;
            transition DEGRADED to AVAILABLE when /* load normalized */ true;
        }
    }

    part def MobileDevice {
        attribute deviceId : String;
        attribute ownerName : String;
        attribute pushNotificationsEnabled : Boolean = true;
        attribute isRegistered : Boolean = true;

        action def receiveNotification(in notification : NotificationMessage);
        action def sendArmCommand(in mode : SystemMode) : SystemCommand;
        action def sendDisarmCommand() : SystemCommand;
        action def sendLockCommand(in lockId : String, in state : LockState) : LockCommand;
        action def viewLiveVideo(in cameraId : String) : VideoStream;
    }

    // ===== The Complete System =====

    part def VivintSmartHomeSystem {

        part centralHub : CentralHub {
            attribute hubId = "VIV-HUB-001";
            attribute firmwareVersion = "3.2.1";
        }

        // Contact Sensors
        part frontDoorContactSensor : ContactSensor {
            attribute sensorId = "CS-FRONT-DOOR";
            attribute location = "Front Door";
        }

        part backDoorContactSensor : ContactSensor {
            attribute sensorId = "CS-BACK-DOOR";
            attribute location = "Back Door";
        }

        part garageDoorContactSensor : ContactSensor {
            attribute sensorId = "CS-GARAGE-DOOR";
            attribute location = "Garage Door";
        }

        part windowContactSensor1 : ContactSensor {
            attribute sensorId = "CS-WIN-LIVING-01";
            attribute location = "Living Room Window";
        }

        part windowContactSensor2 : ContactSensor {
            attribute sensorId = "CS-WIN-BED-01";
            attribute location = "Bedroom Window";
        }

        // Motion Sensors
        part livingRoomMotionSensor : MotionSensor {
            attribute sensorId = "MS-LIVING-01";
            attribute location = "Living Room";
            attribute detectionRange = 12.0;
        }

        part hallwayMotionSensor : MotionSensor {
            attribute sensorId = "MS-HALL-01";
            attribute location = "Hallway";
            attribute detectionRange = 8.0;
        }

        part basementMotionSensor : MotionSensor {
            attribute sensorId = "MS-BASE-01";
            attribute location = "Basement";
            attribute detectionRange = 10.0;
        }

        // Cameras
        part frontDoorCamera : SmartCamera {
            attribute cameraId = "CAM-FRONT-01";
            attribute location = "Front Entrance";
            attribute resolution = 1920 * 1080;
        }

        part backyardCamera : SmartCamera {
            attribute cameraId = "CAM-BACK-01";
            attribute location = "Backyard";
            attribute resolution = 1920 * 1080;
        }

        part garageCamera : SmartCamera {
            attribute cameraId = "CAM-GARAGE-01";
            attribute location = "Garage";
            attribute resolution = 1280 * 720;
        }

        // Smart Doorbell
        part frontDoorDoorbell : SmartDoorbell {
            attribute doorbellId = "DB-FRONT-01";
            attribute resolution = 1920 * 1080;
        }

        // Sirens
        part indoorSiren : Siren {
            attribute sirenId = "SIR-INDOOR-01";
            attribute location = "Hallway";
            attribute isIndoor = true;
            attribute maxSPL = 100;
        }

        part outdoorSiren : Siren {
            attribute sirenId = "SIR-OUTDOOR-01";
            attribute location = "Front Exterior";
            attribute isIndoor = false;
            attribute maxSPL = 110;
        }

        // Smart Locks
        part frontDoorLock : SmartLock {
            attribute lockId = "LOCK-FRONT-01";
            attribute location = "Front Door";
            attribute autoLockDelay = 30;
        }

        part backDoorLock : SmartLock {
            attribute lockId = "LOCK-BACK-01";
            attribute location = "Back Door";
            attribute autoLockDelay = 30;
        }

        part garageDoorLock : SmartLock {
            attribute lockId = "LOCK-GARAGE-01";
            attribute location = "Garage Door";
            attribute autoLockDelay = 60;
        }

        // Control Panel
        part controlPanel : ControlPanel {
            attribute panelId = "PANEL-MAIN-01";
        }

        // Cloud Service
        part cloudService : CloudService {
            attribute serviceId = "VIV-CLOUD-PROD";
            attribute storageCapacityGB = 500;
        }

        // Mobile Device
        part homeownerMobile : MobileDevice {
            attribute deviceId = "MOB-HOMEOWNER-01";
            attribute ownerName = "Homeowner";
        }

        // ===== Connections =====

        // Contact sensors to hub
        connection frontDoorContactSensor.wirelessPort to centralHub.wirelessCoordPort;
        connection backDoorContactSensor.wirelessPort to centralHub.wirelessCoordPort;
        connection garageDoorContactSensor.wirelessPort to centralHub.wirelessCoordPort;
        connection windowContactSensor1.wirelessPort to centralHub.wirelessCoordPort;
        connection windowContactSensor2.wirelessPort to centralHub.wirelessCoordPort;

        // Motion sensors to hub
        connection livingRoomMotionSensor.wirelessPort to centralHub.wirelessCoordPort;
        connection hallwayMotionSensor.wirelessPort to centralHub.wirelessCoordPort;
        connection basementMotionSensor.wirelessPort to centralHub.wirelessCoordPort;

        // Cameras to hub
        connection frontDoorCamera.wirelessPort to centralHub.wirelessCoordPort;
        connection backyardCamera.wirelessPort to centralHub.wirelessCoordPort;
        connection garageCamera.wirelessPort to centralHub.wirelessCoordPort;

        // Doorbell to hub
        connection frontDoorDoorbell.wirelessPort to centralHub.wirelessCoordPort;

        // Sirens to hub
        connection indoorSiren.wirelessPort to centralHub.wirelessCoordPort;
        connection outdoorSiren.wirelessPort to centralHub.wirelessCoordPort;

        // Smart locks to hub
        connection frontDoorLock.wirelessPort to centralHub.wirelessCoordPort;
        connection backDoorLock.wirelessPort to centralHub.wirelessCoordPort;
        connection garageDoorLock.wirelessCoordPort to centralHub.wirelessCoordPort;

        // Control panel to hub
        connection controlPanel.wirelessPort to centralHub.wirelessCoordPort;

        // Hub to cloud
        connection centralHub.cloudCommPort to cloudService.cloudPort;

        // Camera video streams to cloud
        connection frontDoorCamera.videoPort to cloudService.cloudPort;
        connection backyardCamera.videoPort to cloudService.cloudPort;
        connection garageCamera.videoPort to cloudService.cloudPort;
        connection frontDoorDoorbell.videoPort to cloudService.cloudPort;

        // Hub power
        connection centralHub.powerInput to centralHub.backupBattery;

        // ===== System-level behavior =====

        action def SystemMonitoringLoop {
            // Continuously monitor all sensors
            action monitorSensors;
            action evaluateEvents;
            action checkThreatLevel;
            action initiateResponse;
            action sendNotifications;
            action logEvents;
        }

        action def AlarmResponseSequence {
            in triggerEvent : SensorEvent;
            action evaluateThreat { in event = triggerEvent; }
            action activateSirens;
            action startCameraRecording;
            action sendCloudAlert;
            action sendMobileNotification;
            action logIncident;

            flow from evaluateThreat to activateSirens;
            flow from evaluateThreat to startCameraRecording;
            flow from evaluateThreat to sendCloudAlert;
            flow from sendCloudAlert to sendMobileNotification;
            flow from activateSirens to logIncident;
            flow from startCameraRecording to logIncident;
            flow from sendMobileNotification to logIncident;
        }
    }

    // ===== Requirements =====

    requirement def SecurityMonitoringRequirement {
        subject : VivintSmartHomeSystem;
        objective {
            /* The system shall continuously monitor all connected sensors
               and evaluate sensor events to determine threat levels. */
        }
    }

    requirement def IntrusionDetectionRequirement {
        subject : VivintSmartHomeSystem;
        attribute maxDetectionTime : Duration_s = 2;
        objective {
            /* When the system is in ARMED_AWAY or ARMED_STAY mode and a
               contact or motion sensor is triggered, the hub shall evaluate
               the threat within maxDetectionTime seconds. */
        }
    }

    requirement def AlarmResponseRequirement {
        subject : VivintSmartHomeSystem;
        attribute maxResponseTime : Duration_s = 5;
        objective {
            /* Upon confirming a threat, the system shall activate indoor
               and outdoor sirens with strobes, begin recording from
               relevant cameras, and send alerts to the cloud and mobile
               device within maxResponseTime seconds. */
        }
    }

    requirement def BackupPowerRequirement {
        subject : CentralHub;
        attribute minBackupDuration : Duration_s = 14400;
        objective {
            /* The central hub shall include a backup battery that provides
               continuous operation for at least minBackupDuration seconds
               (4 hours) during a power outage. */
        }
    }

    requirement def RemoteAccessRequirement {
        subject : CloudService;
        objective {
            /* The cloud service shall enable homeowners to arm or disarm
               the system, view live video, control smart locks, and
               receive instant push notifications on mobile devices. */
        }
    }

    requirement def VideoSurveillanceRequirement {
        subject : SmartCamera;
        attribute minResolution : VideoResolution = 1280 * 720;
        objective {
            /* All smart cameras shall support live video streaming at
               minimum minResolution resolution and include night vision
               capability for low-light recording. */
        }
    }

    requirement def SmartLockRequirement {
        subject : SmartLock;
        attribute maxAutoLockDelay : Duration_s = 300;
        objective {
            /* Smart locks shall support remote locking and unlocking
               commands and shall auto-lock after a configurable delay
               not exceeding maxAutoLockDelay seconds. */
        }
    }

    requirement def DataStorageRequirement {
        subject : CloudService;
        attribute minStorageGB : Real = 100;
        objective {
            /* The cloud service shall provide secure, encrypted storage
               for event logs and video recordings with a minimum capacity
               of minStorageGB gigabytes per household. */
        }
    }

    requirement def NotificationRequirement {
        subject : CloudService;
        attribute maxNotificationDelay : Duration_s = 10;
        objective {
            /* Upon a confirmed security alert, the cloud service shall
               deliver a push notification to the homeowner's registered
               mobile device within maxNotificationDelay seconds. */
        }
    }

    requirement def SystemModeRequirement {
        subject : CentralHub;
        objective {
            /* The central hub shall support DISARMED, ARMED_AWAY, and
               ARMED_STAY modes, with ARMED_STAY ignoring interior motion
               sensors while monitoring all perimeter contact sensors. */
        }
    }

    requirement def TamperDetectionRequirement {
        subject : ContactSensor;
        objective {
            /* All contact sensors and motion sensors shall detect
               tampering attempts and report a TAMPERED state to the
               central hub, which shall generate a tamper alert. */
        }
    }

    // ===== Requirement Satisfaction =====

    satisfaction SecurityMonitoringRequirement {
        subject :> centralHub;
    }

    satisfaction IntrusionDetectionRequirement {
        subject :> centralHub;
    }

    satisfaction AlarmResponseRequirement {
        subject :> centralHub;
    }

    satisfaction BackupPowerRequirement {
        subject :> centralHub.backupBattery;
    }

    satisfaction RemoteAccessRequirement {
        subject :> cloudService;
    }

    satisfaction VideoSurveillanceRequirement {
        subject :> frontDoorCamera;
    }

    satisfaction SmartLockRequirement {
        subject :> frontDoorLock;
    }

    satisfaction DataStorageRequirement {
        subject :> cloudService;
    }

    satisfaction NotificationRequirement {
        subject :> cloudService;
    }

    satisfaction SystemModeRequirement {
        subject :> centralHub;
    }

    satisfaction TamperDetectionRequirement {
        subject :> frontDoorContactSensor;
    }

}
