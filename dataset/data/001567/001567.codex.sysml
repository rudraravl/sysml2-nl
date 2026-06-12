package SecuritySystemModel {
    import ScalarValues::*;
    import SI::*;

    item def DetectionEvent {
        attribute eventId : String;
        attribute sourceId : String;
        attribute zoneId : String;
        attribute confidence : Real;
        attribute detectedAt_s : Real;
    }

    item def Credential {
        attribute credentialId : String;
        attribute holderRole : String;
        attribute expiresAt_s : Real;
        attribute cryptographicStrength_bits : Integer;
    }

    item def AlarmCommand {
        attribute commandId : String;
        attribute severity : AlarmSeverity;
        attribute issuedAt_s : Real;
    }

    item def IncidentReport {
        attribute reportId : String;
        attribute zoneId : String;
        attribute verifiedThreat : Boolean;
        attribute responseStartedAt_s : Real;
        attribute notificationLatency_s : Real;
    }

    enum def AlarmSeverity {
        enum low;
        enum elevated;
        enum critical;
    }

    enum def ZoneMode {
        enum open;
        enum monitored;
        enum restricted;
        enum lockedDown;
    }

    attribute def Time_s : Real {
        unit = s;
    }

    attribute def Distance_m : Real {
        unit = m;
    }

    attribute def Power_W : Real {
        unit = W;
    }

    attribute def Energy_Wh : Real;

    attribute def Probability : Real;

    port def SensorEventPort {
        out detection : DetectionEvent;
        out healthStatus : String;
        in calibrationRequest : String;
    }

    port def CredentialPort {
        in credential : Credential;
        out authorizationDecision : Boolean;
    }

    port def AlarmPort {
        in alarmCommand : AlarmCommand;
        out alarmStatus : String;
    }

    port def NotificationPort {
        out incidentReport : IncidentReport;
        in acknowledgement : Boolean;
    }

    port def PowerPort {
        in supplyPower_W : Power_W;
        out loadDemand_W : Power_W;
    }

    part def Security {
        attribute primaryFunction : String = "Protect people, assets, and controlled areas by detecting security-relevant events, verifying threats, controlling access, and coordinating timely response.";
    }

    part def SecurityZone {
        attribute zoneId : String;
        attribute mode : ZoneMode;
        attribute floorArea_m2 : Real;
        attribute perimeterLength_m : Distance_m;
        attribute occupancyLimit : Integer;
        port sensorPort : SensorEventPort;
        port accessPort : CredentialPort;
    }

    part def CameraSensor {
        attribute sensorId : String;
        attribute fieldOfView_deg : Real;
        attribute detectionRange_m : Distance_m;
        attribute falseAlarmProbability : Probability;
        attribute activePower_W : Power_W;
        port eventPort : SensorEventPort;
        port powerPort : PowerPort;
    }

    part def DoorContactSensor {
        attribute sensorId : String;
        attribute debounceTime_s : Time_s;
        attribute tamperDetected : Boolean;
        attribute standbyPower_W : Power_W;
        port eventPort : SensorEventPort;
        port powerPort : PowerPort;
    }

    part def BadgeReader {
        attribute readerId : String;
        attribute maxDecisionLatency_s : Time_s;
        attribute failedAttemptCount : Integer;
        port credentialPort : CredentialPort;
        port powerPort : PowerPort;
    }

    part def AccessController {
        attribute controllerId : String;
        attribute authorizationCacheSize : Integer;
        attribute maxUnlockDuration_s : Time_s;
        port frontDoorPort : CredentialPort;
        port serverRoomPort : CredentialPort;
        port powerPort : PowerPort;
    }

    part def SecurityController {
        attribute controllerId : String;
        attribute eventProcessingLatency_s : Time_s;
        attribute incidentVerificationThreshold : Probability;
        attribute retainedEventDays : Integer;
        port lobbySensorInput : SensorEventPort;
        port serverRoomSensorInput : SensorEventPort;
        port doorSensorInput : SensorEventPort;
        port alarmOutput : AlarmPort;
        port notificationOutput : NotificationPort;
        port powerPort : PowerPort;
    }

    part def AlarmAnnunciator {
        attribute annunciatorId : String;
        attribute soundPressureLevel_dBA : Real;
        attribute strobeIntensity_cd : Real;
        attribute activePower_W : Power_W;
        port alarmPort : AlarmPort;
        port powerPort : PowerPort;
    }

    part def ResponseConsole {
        attribute consoleId : String;
        attribute operatorAcknowledgementDeadline_s : Time_s;
        attribute availableOperators : Integer;
        port notificationPort : NotificationPort;
        port powerPort : PowerPort;
    }

    part def BackupPowerSupply {
        attribute supplyId : String;
        attribute storedEnergy_Wh : Energy_Wh;
        attribute minimumRuntime_s : Time_s;
        attribute outputPowerLimit_W : Power_W;
        port controllerPower : PowerPort;
        port sensorPower : PowerPort;
        port alarmPower : PowerPort;
        port consolePower : PowerPort;
    }

    action def DetectSecurityEvent {
        in sensorDetection : DetectionEvent;
        in zoneMode : ZoneMode;
        out normalizedDetection : DetectionEvent;
        out requiresVerification : Boolean;
    }

    action def VerifyThreat {
        in normalizedDetection : DetectionEvent;
        in verificationThreshold : Probability;
        out verifiedThreat : Boolean;
        out severity : AlarmSeverity;
    }

    action def ControlAccess {
        in presentedCredential : Credential;
        in zoneMode : ZoneMode;
        out authorized : Boolean;
        out unlockDuration_s : Time_s;
    }

    action def CoordinateResponse {
        in verifiedThreat : Boolean;
        in severity : AlarmSeverity;
        out alarmCommand : AlarmCommand;
        out incidentReport : IncidentReport;
    }

    state def SecurityControllerLifecycle {
        state initializing;
        state disarmed;
        state armedMonitoring;
        state verifying;
        state responding;
        state degraded;
        state maintenance;

        transition first initializing;
        transition initializing_to_disarmed
            first initializing then disarmed;

        transition arm
            first disarmed then armedMonitoring
            accept ArmRequest;

        transition detection_received
            first armedMonitoring then verifying
            accept DetectionEvent;

        transition threat_confirmed
            first verifying then responding
            if verifiedThreat == true;

        transition nuisance_event
            first verifying then armedMonitoring
            if verifiedThreat == false;

        transition response_acknowledged
            first responding then armedMonitoring
            accept OperatorAcknowledgement;

        transition component_fault
            first armedMonitoring then degraded
            accept HealthFault;

        transition service_start
            first degraded then maintenance
            accept MaintenanceRequest;

        transition service_complete
            first maintenance then disarmed
            accept MaintenanceComplete;
    }

    part def IntegratedSecuritySystem :> Security {
        attribute siteName : String;
        attribute maximumNotificationLatency_s : Time_s = 10.0;
        attribute maximumEventProcessingLatency_s : Time_s = 2.0;
        attribute minimumBackupRuntime_s : Time_s = 14400.0;
        attribute requiredDetectionConfidence : Probability = 0.92;

        part lobby : SecurityZone {
            attribute zoneId = "LOBBY";
            attribute mode = ZoneMode::monitored;
            attribute floorArea_m2 = 85.0;
            attribute perimeterLength_m = 42.0;
            attribute occupancyLimit = 40;
        }

        part serverRoom : SecurityZone {
            attribute zoneId = "SERVER_ROOM";
            attribute mode = ZoneMode::restricted;
            attribute floorArea_m2 = 28.0;
            attribute perimeterLength_m = 22.0;
            attribute occupancyLimit = 4;
        }

        part lobbyCamera : CameraSensor {
            attribute sensorId = "CAM-LOBBY-01";
            attribute fieldOfView_deg = 110.0;
            attribute detectionRange_m = 18.0;
            attribute falseAlarmProbability = 0.015;
            attribute activePower_W = 12.0;
        }

        part serverRoomCamera : CameraSensor {
            attribute sensorId = "CAM-SRV-01";
            attribute fieldOfView_deg = 95.0;
            attribute detectionRange_m = 10.0;
            attribute falseAlarmProbability = 0.008;
            attribute activePower_W = 10.0;
        }

        part serverRoomDoorContact : DoorContactSensor {
            attribute sensorId = "DCS-SRV-01";
            attribute debounceTime_s = 0.15;
            attribute tamperDetected = false;
            attribute standbyPower_W = 1.5;
        }

        part lobbyBadgeReader : BadgeReader {
            attribute readerId = "BR-LOBBY-01";
            attribute maxDecisionLatency_s = 0.75;
            attribute failedAttemptCount = 0;
        }

        part serverRoomBadgeReader : BadgeReader {
            attribute readerId = "BR-SRV-01";
            attribute maxDecisionLatency_s = 0.5;
            attribute failedAttemptCount = 0;
        }

        part accessController : AccessController {
            attribute controllerId = "AC-01";
            attribute authorizationCacheSize = 5000;
            attribute maxUnlockDuration_s = 8.0;
        }

        part securityController : SecurityController {
            attribute controllerId = "SC-PRIMARY-01";
            attribute eventProcessingLatency_s = 1.25;
            attribute incidentVerificationThreshold = 0.92;
            attribute retainedEventDays = 365;
        }

        part alarmAnnunciator : AlarmAnnunciator {
            attribute annunciatorId = "ALM-01";
            attribute soundPressureLevel_dBA = 92.0;
            attribute strobeIntensity_cd = 75.0;
            attribute activePower_W = 18.0;
        }

        part responseConsole : ResponseConsole {
            attribute consoleId = "SOC-CONSOLE-01";
            attribute operatorAcknowledgementDeadline_s = 30.0;
            attribute availableOperators = 2;
        }

        part backupPower : BackupPowerSupply {
            attribute supplyId = "UPS-SEC-01";
            attribute storedEnergy_Wh = 1200.0;
            attribute minimumRuntime_s = 14400.0;
            attribute outputPowerLimit_W = 250.0;
        }

        connect lobbyCamera.eventPort to lobby.sensorPort;
        connect serverRoomCamera.eventPort to serverRoom.sensorPort;
        connect serverRoomDoorContact.eventPort to securityController.doorSensorInput;
        connect lobby.sensorPort to securityController.lobbySensorInput;
        connect serverRoom.sensorPort to securityController.serverRoomSensorInput;
        connect lobbyBadgeReader.credentialPort to accessController.frontDoorPort;
        connect serverRoomBadgeReader.credentialPort to accessController.serverRoomPort;
        connect securityController.alarmOutput to alarmAnnunciator.alarmPort;
        connect securityController.notificationOutput to responseConsole.notificationPort;
        connect backupPower.controllerPower to securityController.powerPort;
        connect backupPower.sensorPower to lobbyCamera.powerPort;
        connect backupPower.sensorPower to serverRoomCamera.powerPort;
        connect backupPower.sensorPower to serverRoomDoorContact.powerPort;
        connect backupPower.sensorPower to lobbyBadgeReader.powerPort;
        connect backupPower.sensorPower to serverRoomBadgeReader.powerPort;
        connect backupPower.alarmPower to alarmAnnunciator.powerPort;
        connect backupPower.consolePower to responseConsole.powerPort;

        perform action DetectSecurityEvent;
        perform action VerifyThreat;
        perform action ControlAccess;
        perform action CoordinateResponse;

        exhibit state SecurityControllerLifecycle;
    }

    requirement def PrimarySecurityFunctionRequirement {
        subject system : IntegratedSecuritySystem;
        doc "The integrated security system shall protect controlled areas by detecting events, verifying threats, controlling access, alarming locally, and notifying response personnel.";
        require constraint {
            system.maximumEventProcessingLatency_s <= 2.0 and
            system.maximumNotificationLatency_s <= 10.0 and
            system.requiredDetectionConfidence >= 0.90
        }
    }

    requirement def AccessControlRequirement {
        subject controller : AccessController;
        doc "The access controller shall decide whether a presented credential is authorized for the requested zone within the configured latency.";
        require constraint {
            controller.maxUnlockDuration_s <= 10.0
        }
    }

    requirement def BackupPowerRequirement {
        subject supply : BackupPowerSupply;
        doc "The backup power supply shall support security monitoring, access control, alarming, and response notification during utility power loss.";
        require constraint {
            supply.minimumRuntime_s >= 14400.0 and
            supply.outputPowerLimit_W >= 100.0
        }
    }

    requirement def AlarmRequirement {
        subject annunciator : AlarmAnnunciator;
        doc "The alarm annunciator shall provide audible and visible indication when a verified critical threat is declared.";
        require constraint {
            annunciator.soundPressureLevel_dBA >= 85.0 and
            annunciator.strobeIntensity_cd >= 60.0
        }
    }

    requirement def DetectionQualityRequirement {
        subject camera : CameraSensor;
        doc "Each camera sensor shall detect motion or presence in its assigned zone with low nuisance alarm probability.";
        require constraint {
            camera.detectionRange_m >= 10.0 and
            camera.falseAlarmProbability <= 0.02
        }
    }

    part securitySystem : IntegratedSecuritySystem {
        attribute siteName = "Controlled Facility Security System";
    }

    satisfy PrimarySecurityFunctionRequirement by securitySystem;
    satisfy BackupPowerRequirement by securitySystem.backupPower;
    satisfy AlarmRequirement by securitySystem.alarmAnnunciator;
    satisfy DetectionQualityRequirement by securitySystem.lobbyCamera;
    satisfy DetectionQualityRequirement by securitySystem.serverRoomCamera;
    satisfy AccessControlRequirement by securitySystem.accessController;
}