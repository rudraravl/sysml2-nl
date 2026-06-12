package SecuritySystemModel {

    import ScalarValues::*;
    import SI::*;

    attribute def Percentage : Real {
        :>> unit = "%";
    }

    attribute def ConfidenceScore : Real {
        :>> unit = "%";
    }

    attribute def EventCount : Integer;

    attribute def BooleanFlag : Boolean;

    attribute def Identifier : String;

    attribute def SecurityLevel : Integer;

    enum def AlarmMode {
        enum idle;
        enum monitoring;
        enum alert;
        enum lockdown;
        enum maintenance;
    }

    enum def ThreatCategory {
        enum intrusion;
        enum tamper;
        enum forcedEntry;
        enum motionAfterHours;
        enum glassBreak;
        enum accessDenied;
        enum fire;
        enum environmental;
        enum cyberTamper;
    }

    enum def AccessDecision {
        enum granted;
        enum denied;
        enum pending;
    }

    enum def SensorHealth {
        enum nominal;
        enum degraded;
        enum failed;
        enum bypassed;
    }

    item def SecurityEvent {
        attribute eventId : Identifier;
        attribute category : ThreatCategory;
        attribute sourceZone : Identifier;
        attribute confidence : ConfidenceScore;
        attribute timestamp_s : Real;
        attribute severity : SecurityLevel;
    }

    item def AlarmCommand {
        attribute mode : AlarmMode;
        attribute priority : SecurityLevel;
        attribute reason : String;
    }

    item def Credential {
        attribute credentialId : Identifier;
        attribute holderId : Identifier;
        attribute clearanceLevel : SecurityLevel;
        attribute valid : BooleanFlag;
    }

    item def AccessRequest {
        attribute requestId : Identifier;
        attribute zoneId : Identifier;
        attribute credential : Credential;
        attribute timestamp_s : Real;
    }

    item def AccessResponse {
        attribute requestId : Identifier;
        attribute decision : AccessDecision;
        attribute reason : String;
    }

    item def StatusReport {
        attribute mode : AlarmMode;
        attribute armed : BooleanFlag;
        attribute openZoneCount : EventCount;
        attribute failedSensorCount : EventCount;
        attribute activeThreatCount : EventCount;
        attribute backupPowerRemaining_min : Real;
    }

    item def VideoFrame {
        attribute cameraId : Identifier;
        attribute timestamp_s : Real;
        attribute motionConfidence : ConfidenceScore;
        attribute personDetected : BooleanFlag;
    }

    item def PowerFlow {
        attribute voltage_V : Real;
        attribute current_A : Real;
        attribute available : BooleanFlag;
    }

    port def EventOutPort {
        out event : SecurityEvent;
    }

    port def EventInPort {
        in event : SecurityEvent;
    }

    port def AlarmCommandOutPort {
        out command : AlarmCommand;
    }

    port def AlarmCommandInPort {
        in command : AlarmCommand;
    }

    port def AccessRequestPort {
        out request : AccessRequest;
    }

    port def AccessProcessingPort {
        in request : AccessRequest;
        out response : AccessResponse;
    }

    port def AccessResponsePort {
        in response : AccessResponse;
    }

    port def StatusOutPort {
        out report : StatusReport;
    }

    port def VideoOutPort {
        out frame : VideoFrame;
    }

    port def VideoInPort {
        in frame : VideoFrame;
    }

    port def PowerInPort {
        in power : PowerFlow;
    }

    port def PowerOutPort {
        out power : PowerFlow;
    }

    part def Sensor {
        attribute sensorId : Identifier;
        attribute zoneId : Identifier;
        attribute health : SensorHealth;
        attribute detectionThreshold : ConfidenceScore;
        attribute tamperDetected : BooleanFlag;

        port eventOut : EventOutPort;

        action detectThreat {
            in confidence : ConfidenceScore;
            in category : ThreatCategory;
            out event : SecurityEvent;

            first start;
            then evaluateDetection;
            then publishEvent;
            then done;

            action evaluateDetection;
            action publishEvent;
        }
    }

    part def DoorContactSensor :> Sensor {
        attribute open : BooleanFlag;
        attribute forcedOpenConfidence : ConfidenceScore;
    }

    part def MotionSensor :> Sensor {
        attribute motionDetected : BooleanFlag;
        attribute coverageArea_m2 : Real;
    }

    part def GlassBreakSensor :> Sensor {
        attribute acousticLevel_dB : Real;
        attribute breakPatternConfidence : ConfidenceScore;
    }

    part def Camera {
        attribute cameraId : Identifier;
        attribute zoneId : Identifier;
        attribute resolutionWidth_px : Integer;
        attribute resolutionHeight_px : Integer;
        attribute frameRate_Hz : Real;
        attribute health : SensorHealth;

        port videoOut : VideoOutPort;
    }

    part def AlarmAnnunciator {
        attribute sirenLevel_dB : Real;
        attribute strobeEnabled : BooleanFlag;
        attribute active : BooleanFlag;

        port commandIn : AlarmCommandInPort;

        action activateAlarm {
            in command : AlarmCommand;
            out active : BooleanFlag;
        }

        action silenceAlarm {
            out active : BooleanFlag;
        }
    }

    part def AccessController {
        attribute controllerId : Identifier;
        attribute defaultDeny : BooleanFlag;
        attribute maxClearanceLevel : SecurityLevel;

        port accessProcessing : AccessProcessingPort;
        port eventOut : EventOutPort;

        action evaluateCredential {
            in request : AccessRequest;
            out response : AccessResponse;
        }

        action publishDeniedAccessEvent {
            in request : AccessRequest;
            out event : SecurityEvent;
        }
    }

    part def DoorLock {
        attribute lockId : Identifier;
        attribute zoneId : Identifier;
        attribute locked : BooleanFlag;
        attribute failSecure : BooleanFlag;

        port responseIn : AccessResponsePort;

        action unlockTemporarily {
            in duration_s : Real;
            out locked : BooleanFlag;
        }

        action lockImmediately {
            out locked : BooleanFlag;
        }
    }

    part def VideoAnalyticsProcessor {
        attribute processorId : Identifier;
        attribute personDetectionThreshold : ConfidenceScore;
        attribute afterHoursEnabled : BooleanFlag;

        port videoIn : VideoInPort;
        port eventOut : EventOutPort;

        action analyzeFrame {
            in frame : VideoFrame;
            out event : SecurityEvent;
        }
    }

    part def SecurityControlUnit {
        attribute controllerId : Identifier;
        attribute currentMode : AlarmMode;
        attribute armed : BooleanFlag;
        attribute activeThreatCount : EventCount;
        attribute failedSensorCount : EventCount;
        attribute responseTimeLimit_s : Real;

        port eventIn : EventInPort;
        port alarmCommandOut : AlarmCommandOutPort;
        port statusOut : StatusOutPort;

        action classifyEvent {
            in event : SecurityEvent;
            out priority : SecurityLevel;
        }

        action commandAlarm {
            in event : SecurityEvent;
            out command : AlarmCommand;
        }

        action generateStatus {
            out report : StatusReport;
        }

        state def OperatingState {
            entry action generateStatus;

            state Initializing;
            state Disarmed;
            state ArmedMonitoring;
            state ThreatAssessment;
            state AlarmActive;
            state Lockdown;
            state Maintenance;

            transition first Initializing;
            transition Initializing_to_Disarmed
                first Initializing
                then Disarmed;

            transition Disarmed_to_Armed
                first Disarmed
                then ArmedMonitoring
                accept AlarmCommand
                if command.mode == AlarmMode::monitoring;

            transition Armed_to_Assessment
                first ArmedMonitoring
                then ThreatAssessment
                accept SecurityEvent
                if event.confidence >= 70.0;

            transition Assessment_to_Alarm
                first ThreatAssessment
                then AlarmActive
                if activeThreatCount >= 1;

            transition Alarm_to_Lockdown
                first AlarmActive
                then Lockdown
                accept SecurityEvent
                if event.severity >= 4;

            transition Alarm_to_Armed
                first AlarmActive
                then ArmedMonitoring
                accept AlarmCommand
                if command.mode == AlarmMode::monitoring;

            transition Any_to_Maintenance
                first ArmedMonitoring
                then Maintenance
                accept AlarmCommand
                if command.mode == AlarmMode::maintenance;

            transition Maintenance_to_Disarmed
                first Maintenance
                then Disarmed
                accept AlarmCommand
                if command.mode == AlarmMode::idle;
        }
    }

    part def MonitoringConsole {
        attribute consoleId : Identifier;
        attribute operatorAcknowledged : BooleanFlag;
        attribute displayedThreatCount : EventCount;

        port statusIn {
            in report : StatusReport;
        }

        port commandOut : AlarmCommandOutPort;

        action displayStatus {
            in report : StatusReport;
        }

        action acknowledgeAlarm {
            out command : AlarmCommand;
        }
    }

    part def NotificationGateway {
        attribute gatewayId : Identifier;
        attribute cellularAvailable : BooleanFlag;
        attribute ethernetAvailable : BooleanFlag;
        attribute messageLatencyLimit_s : Real;

        port eventIn : EventInPort;
        port statusIn {
            in report : StatusReport;
        }

        action notifyMonitoringService {
            in event : SecurityEvent;
        }

        action notifyOwner {
            in event : SecurityEvent;
        }
    }

    part def PowerSubsystem {
        attribute mainsAvailable : BooleanFlag;
        attribute batteryCharge : Percentage;
        attribute backupDuration_min : Real;
        attribute lowBatteryThreshold : Percentage;

        port powerOut : PowerOutPort;

        action switchToBattery {
            out power : PowerFlow;
        }

        action reportLowBattery {
            out event : SecurityEvent;
        }
    }

    part def SecuritySystem {
        attribute systemId : Identifier = "SEC-SYS-001";
        attribute protectedSiteId : Identifier = "SITE-MAIN";
        attribute primaryFunction : String =
            "Detect unauthorized access or hazardous security events, assess threat severity, restrict protected areas, alarm occupants, and notify responders.";

        part controlUnit : SecurityControlUnit {
            attribute responseTimeLimit_s = 2.0;
        }

        part frontDoorContact : DoorContactSensor {
            attribute sensorId = "S-DOOR-FRONT";
            attribute zoneId = "ENTRY-01";
            attribute detectionThreshold = 80.0;
            attribute health = SensorHealth::nominal;
        }

        part rearDoorContact : DoorContactSensor {
            attribute sensorId = "S-DOOR-REAR";
            attribute zoneId = "ENTRY-02";
            attribute detectionThreshold = 80.0;
            attribute health = SensorHealth::nominal;
        }

        part lobbyMotion : MotionSensor {
            attribute sensorId = "S-MOTION-LOBBY";
            attribute zoneId = "LOBBY";
            attribute detectionThreshold = 75.0;
            attribute coverageArea_m2 = 42.0;
            attribute health = SensorHealth::nominal;
        }

        part officeGlassBreak : GlassBreakSensor {
            attribute sensorId = "S-GLASS-OFFICE";
            attribute zoneId = "OFFICE-01";
            attribute detectionThreshold = 85.0;
            attribute health = SensorHealth::nominal;
        }

        part entryCamera : Camera {
            attribute cameraId = "CAM-ENTRY";
            attribute zoneId = "ENTRY-01";
            attribute resolutionWidth_px = 1920;
            attribute resolutionHeight_px = 1080;
            attribute frameRate_Hz = 30.0;
            attribute health = SensorHealth::nominal;
        }

        part analytics : VideoAnalyticsProcessor {
            attribute processorId = "VA-001";
            attribute personDetectionThreshold = 82.0;
            attribute afterHoursEnabled = true;
        }

        part accessController : AccessController {
            attribute controllerId = "AC-001";
            attribute defaultDeny = true;
            attribute maxClearanceLevel = 5;
        }

        part frontDoorLock : DoorLock {
            attribute lockId = "LOCK-FRONT";
            attribute zoneId = "ENTRY-01";
            attribute locked = true;
            attribute failSecure = true;
        }

        part sirenAndStrobe : AlarmAnnunciator {
            attribute sirenLevel_dB = 105.0;
            attribute strobeEnabled = true;
            attribute active = false;
        }

        part console : MonitoringConsole {
            attribute consoleId = "CONSOLE-SECURITY-DESK";
        }

        part notifications : NotificationGateway {
            attribute gatewayId = "NG-001";
            attribute cellularAvailable = true;
            attribute ethernetAvailable = true;
            attribute messageLatencyLimit_s = 5.0;
        }

        part power : PowerSubsystem {
            attribute mainsAvailable = true;
            attribute batteryCharge = 100.0;
            attribute backupDuration_min = 480.0;
            attribute lowBatteryThreshold = 20.0;
        }

        connect frontDoorContact.eventOut to controlUnit.eventIn;
        connect rearDoorContact.eventOut to controlUnit.eventIn;
        connect lobbyMotion.eventOut to controlUnit.eventIn;
        connect officeGlassBreak.eventOut to controlUnit.eventIn;
        connect entryCamera.videoOut to analytics.videoIn;
        connect analytics.eventOut to controlUnit.eventIn;
        connect accessController.eventOut to controlUnit.eventIn;
        connect controlUnit.alarmCommandOut to sirenAndStrobe.commandIn;
        connect controlUnit.statusOut to console.statusIn;
        connect controlUnit.statusOut to notifications.statusIn;
        connect controlUnit.eventIn to notifications.eventIn;
        connect accessController.accessProcessing.response to frontDoorLock.responseIn.response;
        connect console.commandOut to sirenAndStrobe.commandIn;
        connect power.powerOut to controlUnit.powerIn;

        action performPrimarySecurityFunction {
            in sensorEvent : SecurityEvent;
            out alarmCommand : AlarmCommand;
            out status : StatusReport;

            first receiveEvent;
            then classifyThreat;
            then decideResponse;
            then executeResponse;
            then notifyStakeholders;
            then publishSystemStatus;
            then done;

            action receiveEvent;
            action classifyThreat;
            action decideResponse;
            action executeResponse;
            action notifyStakeholders;
            action publishSystemStatus;
        }
    }

    requirement def DetectThreatsRequirement {
        doc
            /* The security system shall detect intrusion, tamper, forced entry, denied access, glass break, and after-hours motion events across protected zones. */

        subject system : SecuritySystem;

        require constraint {
            system.controlUnit.responseTimeLimit_s <= 2.0
        }
    }

    requirement def AlarmResponseRequirement {
        doc
            /* The security system shall activate audible and visual alarms for confirmed security threats with severity level 3 or greater. */

        subject system : SecuritySystem;

        require constraint {
            system.sirenAndStrobe.sirenLevel_dB >= 100.0
        }
    }

    requirement def AccessControlRequirement {
        doc
            /* The security system shall deny access by default unless the presented credential is valid and has sufficient clearance for the requested zone. */

        subject controller : AccessController;

        require constraint {
            controller.defaultDeny == true
        }
    }

    requirement def BackupPowerRequirement {
        doc
            /* The security system shall continue monitoring and alarm functions during loss of mains power using battery backup for at least 240 minutes. */

        subject system : SecuritySystem;

        require constraint {
            system.power.backupDuration_min >= 240.0
        }
    }

    requirement def NotificationRequirement {
        doc
            /* The security system shall notify the monitoring service and owner within 5 seconds after a confirmed high-priority security event. */

        subject system : SecuritySystem;

        require constraint {
            system.notifications.messageLatencyLimit_s <= 5.0
        }
    }

    requirement def HighLevelPrimaryFunctionRequirement {
        doc
            /* The security system shall provide the high-level function of protecting a site by sensing security-relevant conditions, determining threat severity, initiating local protective actions, and communicating actionable status to responsible parties. */

        subject system : SecuritySystem;

        require constraint {
            system.controlUnit.currentMode != AlarmMode::maintenance
        }
    }

    satisfy SecuritySystem by DetectThreatsRequirement;
    satisfy SecuritySystem by AlarmResponseRequirement;
    satisfy SecuritySystem by BackupPowerRequirement;
    satisfy SecuritySystem by NotificationRequirement;
    satisfy SecuritySystem by HighLevelPrimaryFunctionRequirement;
    satisfy AccessController by AccessControlRequirement;

}