package VivintSmartHomeSecuritySystemModel {
    import ScalarValues::*;
    import SI::*;

    attribute def Percent : Real {
        doc /* Percentage from 0 to 100. */
    }

    attribute def CurrencyUSD : Real {
        doc /* Monetary value in United States dollars. */
    }

    attribute def Decibel : Real {
        doc /* Sound pressure level in decibels. */
    }

    attribute def Lux : Real {
        doc /* Illuminance in lux. */
    }

    attribute def DataRateMbps : Real {
        doc /* Network data rate in megabits per second. */
    }

    attribute def BatteryPercent : Percent {
        constraint range { 0.0 <= self <= 100.0 }
    }

    item def AlarmEvent {
        attribute eventId : String;
        attribute eventTime : String;
        attribute zoneName : String;
        attribute severity : AlarmSeverity;
        attribute eventKind : AlarmEventKind;
    }

    enum def AlarmSeverity {
        enum low;
        enum medium;
        enum high;
        enum critical;
    }

    enum def AlarmEventKind {
        enum doorOpened;
        enum windowOpened;
        enum motionDetected;
        enum glassBreakDetected;
        enum smokeDetected;
        enum carbonMonoxideDetected;
        enum waterLeakDetected;
        enum tamperDetected;
        enum panicPressed;
    }

    item def VideoFrame {
        attribute timestamp : String;
        attribute widthPixels : Integer;
        attribute heightPixels : Integer;
        attribute encodedSizeBytes : Integer;
        attribute nightVisionEnabled : Boolean;
    }

    item def ControlCommand {
        attribute commandId : String;
        attribute issuedBy : String;
        attribute commandKind : CommandKind;
        attribute targetDeviceId : String;
    }

    enum def CommandKind {
        enum armStay;
        enum armAway;
        enum disarm;
        enum lockDoor;
        enum unlockDoor;
        enum turnLightOn;
        enum turnLightOff;
        enum setThermostat;
        enum silenceAlarm;
        enum requestLiveVideo;
    }

    item def NotificationMessage {
        attribute notificationId : String;
        attribute recipientUserId : String;
        attribute messageText : String;
        attribute priority : AlarmSeverity;
    }

    item def MonitoringSignal {
        attribute accountId : String;
        attribute premisesAddress : String;
        attribute alarm : AlarmEvent;
        attribute verifiedVideoAvailable : Boolean;
    }

    port def PowerPort {
        out item power : ElectricalPower;
    }

    port def SensorEventPort {
        out item alarmEvent : AlarmEvent;
    }

    port def VideoPort {
        out item videoFrame : VideoFrame;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def NotificationPort {
        out item notification : NotificationMessage;
    }

    port def MonitoringPort {
        out item signal : MonitoringSignal;
    }

    port def NetworkPort {
        in item inboundCommand : ControlCommand;
        out item outboundNotification : NotificationMessage;
        out item outboundMonitoringSignal : MonitoringSignal;
        out item outboundVideo : VideoFrame;
    }

    part def DoorWindowSensor {
        attribute deviceId : String;
        attribute zoneName : String;
        attribute batteryLevel : BatteryPercent;
        attribute tamperDetected : Boolean;
        attribute openState : Boolean;

        port eventOut : SensorEventPort;

        state def DoorWindowSensorBehavior {
            state closed;
            state open;
            state tampered;

            transition first closed;
            transition closed_to_open
                first closed then open
                accept AlarmEventKind::doorOpened;
            transition open_to_closed
                first open then closed
                accept AlarmEventKind::doorOpened;
            transition any_to_tampered
                first closed then tampered
                accept AlarmEventKind::tamperDetected;
        }
    }

    part def MotionSensor {
        attribute deviceId : String;
        attribute zoneName : String;
        attribute batteryLevel : BatteryPercent;
        attribute detectionRange : Length;
        attribute petImmunityMassLimit : Mass;

        port eventOut : SensorEventPort;
    }

    part def GlassBreakSensor {
        attribute deviceId : String;
        attribute zoneName : String;
        attribute batteryLevel : BatteryPercent;
        attribute acousticThreshold : Decibel;

        port eventOut : SensorEventPort;
    }

    part def SmokeCOSensor {
        attribute deviceId : String;
        attribute zoneName : String;
        attribute batteryLevel : BatteryPercent;
        attribute smokeDetected : Boolean;
        attribute carbonMonoxidePpm : Real;

        port eventOut : SensorEventPort;
    }

    part def WaterLeakSensor {
        attribute deviceId : String;
        attribute zoneName : String;
        attribute batteryLevel : BatteryPercent;
        attribute moistureDetected : Boolean;

        port eventOut : SensorEventPort;
    }

    part def OutdoorCamera {
        attribute deviceId : String;
        attribute locationName : String;
        attribute resolutionWidth : Integer = 1920;
        attribute resolutionHeight : Integer = 1080;
        attribute fieldOfView : Angle;
        attribute nightVisionRange : Length;
        attribute minimumIllumination : Lux;
        attribute localStorageHours : Real;

        port videoOut : VideoPort;
        port commandIn : CommandPort;
    }

    part def DoorbellCamera {
        attribute deviceId : String;
        attribute locationName : String;
        attribute resolutionWidth : Integer = 1920;
        attribute resolutionHeight : Integer = 1080;
        attribute twoWayAudioEnabled : Boolean = true;
        attribute chimeEnabled : Boolean = true;

        port videoOut : VideoPort;
        port commandIn : CommandPort;
        port eventOut : SensorEventPort;
    }

    part def SmartLock {
        attribute deviceId : String;
        attribute doorName : String;
        attribute batteryLevel : BatteryPercent;
        attribute locked : Boolean;
        attribute autoLockDelay : Time;

        port commandIn : CommandPort;
        port eventOut : SensorEventPort;
    }

    part def SmartLight {
        attribute deviceId : String;
        attribute roomName : String;
        attribute dimLevel : Percent;
        attribute powerConsumption : ElectricalPower;

        port commandIn : CommandPort;
    }

    part def SmartThermostat {
        attribute deviceId : String;
        attribute currentTemperature : Temperature;
        attribute heatingSetpoint : Temperature;
        attribute coolingSetpoint : Temperature;
        attribute humidity : Percent;

        port commandIn : CommandPort;
    }

    part def Siren {
        attribute deviceId : String;
        attribute soundLevel : Decibel = 100.0;
        attribute active : Boolean;

        port commandIn : CommandPort;
    }

    part def TouchscreenPanel {
        attribute panelId : String;
        attribute accountId : String;
        attribute backupBatteryLevel : BatteryPercent;
        attribute cellularSignalStrength : Percent;
        attribute wifiDataRate : DataRateMbps;
        attribute premisesAddress : String;

        port sensorEventsIn : SensorEventPort;
        port cameraVideoIn : VideoPort;
        port deviceCommandsOut : CommandPort;
        port network : NetworkPort;

        state def SecurityPanelStateMachine {
            state disarmed;
            state armedStay;
            state armedAway;
            state entryDelay;
            state alarmActive;
            state communicatingWithMonitoringCenter;

            transition initial_to_disarmed first disarmed;

            transition arm_stay
                first disarmed then armedStay
                accept CommandKind::armStay;

            transition arm_away
                first disarmed then armedAway
                accept CommandKind::armAway;

            transition disarm_from_stay
                first armedStay then disarmed
                accept CommandKind::disarm;

            transition disarm_from_away
                first armedAway then disarmed
                accept CommandKind::disarm;

            transition protected_open_while_armed
                first armedAway then entryDelay
                accept AlarmEventKind::doorOpened;

            transition instant_alarm_stay
                first armedStay then alarmActive
                accept AlarmEventKind::glassBreakDetected;

            transition entry_delay_expired
                first entryDelay then alarmActive
                accept AlarmEventKind::motionDetected;

            transition alarm_to_monitoring
                first alarmActive then communicatingWithMonitoringCenter
                accept AlarmSeverity::critical;

            transition silence_alarm
                first alarmActive then disarmed
                accept CommandKind::silenceAlarm;

            transition monitoring_complete
                first communicatingWithMonitoringCenter then alarmActive
                accept AlarmSeverity::high;
        }
    }

    part def CloudService {
        attribute serviceName : String = "Vivint Cloud Service";
        attribute videoRetentionDays : Integer = 14;
        attribute averageCommandLatency : Time;
        attribute encryptionEnabled : Boolean = true;

        port panelNetwork : NetworkPort;
        port userAppCommands : CommandPort;
        port userNotifications : NotificationPort;
        port monitoringDispatch : MonitoringPort;
    }

    part def MobileApp {
        attribute appName : String = "Vivint Mobile App";
        attribute userId : String;
        attribute biometricLoginEnabled : Boolean;
        attribute pushNotificationsEnabled : Boolean;

        port commandOut : CommandPort;
        port notificationIn : NotificationPort;
        port videoIn : VideoPort;
    }

    part def ProfessionalMonitoringCenter {
        attribute centerId : String;
        attribute staffedContinuously : Boolean = true;
        attribute targetSignalAcknowledgementTime : Time;
        attribute emergencyDispatchEnabled : Boolean = true;

        port monitoringIn : MonitoringPort;
    }

    action def DetectIntrusion {
        in item sensorEvent : AlarmEvent;
        out item alarm : AlarmEvent;

        first start;
        then evaluateSeverity;
        then publishAlarm;
        then done;

        action evaluateSeverity {
            in item event : AlarmEvent = sensorEvent;
            out item classifiedEvent : AlarmEvent;
        }

        action publishAlarm {
            in item classifiedEvent : AlarmEvent;
            out item emittedAlarm : AlarmEvent = alarm;
        }
    }

    action def NotifyUserAndMonitoringCenter {
        in item alarm : AlarmEvent;
        in verifiedVideoAvailable : Boolean;
        out item userNotification : NotificationMessage;
        out item monitoringSignal : MonitoringSignal;

        first start;
        then createPushNotification;
        then createMonitoringSignal;
        then transmitMessages;
        then done;

        action createPushNotification {
            out item message : NotificationMessage = userNotification;
        }

        action createMonitoringSignal {
            out item signal : MonitoringSignal = monitoringSignal;
        }

        action transmitMessages;
    }

    action def ExecuteRemoteCommand {
        in item command : ControlCommand;
        out accepted : Boolean;

        first start;
        then authenticateUser;
        then routeCommand;
        then confirmExecution;
        then done;

        action authenticateUser {
            out authenticated : Boolean;
        }

        action routeCommand {
            in item routedCommand : ControlCommand = command;
        }

        action confirmExecution {
            out commandAccepted : Boolean = accepted;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide integrated residential security and smart-home control by detecting safety or intrusion events, alerting occupants, notifying a professional monitoring center, and allowing authorized users to view cameras and control connected devices remotely. */
    }

    requirement def IntrusionDetectionRequirement {
        doc /* The system shall detect unauthorized opening, motion, glass breakage, tamper, and panic events in protected zones when armed. */
    }

    requirement def LifeSafetyRequirement {
        doc /* The system shall detect smoke, carbon monoxide, and water leak hazards regardless of armed mode. */
    }

    requirement def RemoteControlRequirement {
        doc /* The system shall allow an authorized mobile user to arm, disarm, lock, unlock, view video, adjust lighting, and adjust thermostat settings. */
    }

    requirement def MonitoringRequirement {
        doc /* The system shall transmit critical alarm signals to a professional monitoring center using broadband or cellular communication. */
    }

    requirement def LocalAlarmRequirement {
        doc /* The system shall activate an audible siren for critical intrusion or life-safety events. */
    }

    part def VivintBasedSmartHomeSecuritySystem {
        attribute systemName : String = "Vivint-Based Smart Home Security System";
        attribute primaryFunction : String = "Integrated home protection, video awareness, professional monitoring, and remote smart-home control.";
        attribute protectedArea : Area;
        attribute nominalMonthlyServiceCost : CurrencyUSD;
        attribute broadbandAvailable : Boolean;
        attribute cellularBackupAvailable : Boolean = true;

        part panel : TouchscreenPanel {
            attribute accountId = "VIVINT-ACCOUNT-001";
            attribute premisesAddress = "123 Protected Residence, United States";
            attribute backupBatteryLevel = 100.0;
            attribute cellularSignalStrength = 85.0;
            attribute wifiDataRate = 50.0;
        }

        part cloud : CloudService {
            attribute averageCommandLatency = 2.0 [SI::s];
        }

        part app : MobileApp {
            attribute userId = "primary-homeowner";
            attribute biometricLoginEnabled = true;
            attribute pushNotificationsEnabled = true;
        }

        part monitoringCenter : ProfessionalMonitoringCenter {
            attribute centerId = "MONITORING-CENTER-US";
            attribute targetSignalAcknowledgementTime = 30.0 [SI::s];
        }

        part frontDoorSensor : DoorWindowSensor {
            attribute deviceId = "DWS-FRONT";
            attribute zoneName = "Front Door";
            attribute batteryLevel = 92.0;
            attribute tamperDetected = false;
            attribute openState = false;
        }

        part backDoorSensor : DoorWindowSensor {
            attribute deviceId = "DWS-BACK";
            attribute zoneName = "Back Door";
            attribute batteryLevel = 88.0;
            attribute tamperDetected = false;
            attribute openState = false;
        }

        part livingRoomMotion : MotionSensor {
            attribute deviceId = "MOT-LIVING";
            attribute zoneName = "Living Room";
            attribute batteryLevel = 95.0;
            attribute detectionRange = 12.0 [SI::m];
            attribute petImmunityMassLimit = 18.0 [SI::kg];
        }

        part bedroomGlassBreak : GlassBreakSensor {
            attribute deviceId = "GBS-BEDROOM";
            attribute zoneName = "Primary Bedroom";
            attribute batteryLevel = 90.0;
            attribute acousticThreshold = 85.0;
        }

        part hallwaySmokeCO : SmokeCOSensor {
            attribute deviceId = "SCO-HALLWAY";
            attribute zoneName = "Upstairs Hallway";
            attribute batteryLevel = 98.0;
            attribute smokeDetected = false;
            attribute carbonMonoxidePpm = 0.0;
        }

        part laundryLeakSensor : WaterLeakSensor {
            attribute deviceId = "WLS-LAUNDRY";
            attribute zoneName = "Laundry Room";
            attribute batteryLevel = 87.0;
            attribute moistureDetected = false;
        }

        part drivewayCamera : OutdoorCamera {
            attribute deviceId = "CAM-DRIVEWAY";
            attribute locationName = "Driveway";
            attribute fieldOfView = 140.0 [SI::deg];
            attribute nightVisionRange = 15.0 [SI::m];
            attribute minimumIllumination = 0.1;
            attribute localStorageHours = 24.0;
        }

        part porchDoorbell : DoorbellCamera {
            attribute deviceId = "DBC-PORCH";
            attribute locationName = "Front Porch";
        }

        part frontDoorLock : SmartLock {
            attribute deviceId = "LOCK-FRONT";
            attribute doorName = "Front Door";
            attribute batteryLevel = 80.0;
            attribute locked = true;
            attribute autoLockDelay = 120.0 [SI::s];
        }

        part porchLight : SmartLight {
            attribute deviceId = "LIGHT-PORCH";
            attribute roomName = "Porch";
            attribute dimLevel = 75.0;
            attribute powerConsumption = 9.0 [SI::W];
        }

        part thermostat : SmartThermostat {
            attribute deviceId = "THERM-HALL";
            attribute currentTemperature = 295.15 [SI::K];
            attribute heatingSetpoint = 293.15 [SI::K];
            attribute coolingSetpoint = 297.15 [SI::K];
            attribute humidity = 45.0;
        }

        part indoorSiren : Siren {
            attribute deviceId = "SIREN-PANEL";
            attribute soundLevel = 100.0;
            attribute active = false;
        }

        connect frontDoorSensor.eventOut to panel.sensorEventsIn;
        connect backDoorSensor.eventOut to panel.sensorEventsIn;
        connect livingRoomMotion.eventOut to panel.sensorEventsIn;
        connect bedroomGlassBreak.eventOut to panel.sensorEventsIn;
        connect hallwaySmokeCO.eventOut to panel.sensorEventsIn;
        connect laundryLeakSensor.eventOut to panel.sensorEventsIn;
        connect porchDoorbell.eventOut to panel.sensorEventsIn;

        connect drivewayCamera.videoOut to panel.cameraVideoIn;
        connect porchDoorbell.videoOut to panel.cameraVideoIn;

        connect panel.deviceCommandsOut to frontDoorLock.commandIn;
        connect panel.deviceCommandsOut to porchLight.commandIn;
        connect panel.deviceCommandsOut to thermostat.commandIn;
        connect panel.deviceCommandsOut to indoorSiren.commandIn;
        connect panel.deviceCommandsOut to drivewayCamera.commandIn;
        connect panel.deviceCommandsOut to porchDoorbell.commandIn;

        connect panel.network to cloud.panelNetwork;
        connect app.commandOut to cloud.userAppCommands;
        connect cloud.userNotifications to app.notificationIn;
        connect cloud.monitoringDispatch to monitoringCenter.monitoringIn;

        perform action intrusionProcessing : DetectIntrusion;
        perform action alertingProcessing : NotifyUserAndMonitoringCenter;
        perform action remoteCommandProcessing : ExecuteRemoteCommand;

        satisfy PrimaryFunctionRequirement by VivintBasedSmartHomeSecuritySystem;
        satisfy IntrusionDetectionRequirement by frontDoorSensor;
        satisfy IntrusionDetectionRequirement by backDoorSensor;
        satisfy IntrusionDetectionRequirement by livingRoomMotion;
        satisfy IntrusionDetectionRequirement by bedroomGlassBreak;
        satisfy LifeSafetyRequirement by hallwaySmokeCO;
        satisfy LifeSafetyRequirement by laundryLeakSensor;
        satisfy RemoteControlRequirement by app;
        satisfy RemoteControlRequirement by cloud;
        satisfy RemoteControlRequirement by panel;
        satisfy MonitoringRequirement by panel;
        satisfy MonitoringRequirement by cloud;
        satisfy MonitoringRequirement by monitoringCenter;
        satisfy LocalAlarmRequirement by indoorSiren;
    }
}