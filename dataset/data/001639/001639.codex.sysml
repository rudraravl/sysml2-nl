package AlertMeSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    value type Percent specializes Real {
        unit = "%";
    }

    value type dB specializes Real {
        unit = "dB";
    }

    value type ms specializes Real {
        unit = "ms";
    }

    value type s specializes Real {
        unit = "s";
    }

    value type min specializes Real {
        unit = "min";
    }

    value type V specializes Real {
        unit = "V";
    }

    value type mA specializes Real {
        unit = "mA";
    }

    value type EventSeverity specializes Integer;
    value type BatteryCharge specializes Percent;
    value type SignalStrength specializes Percent;
    value type ResponseTime specializes ms;
    value type AlertVolume specializes dB;

    enum def AlertKind {
        enum environmental;
        enum security;
        enum health;
        enum connectivity;
        enum power;
        enum userRequested;
    }

    enum def DeliveryChannel {
        enum audible;
        enum visual;
        enum haptic;
        enum mobilePush;
        enum sms;
        enum email;
        enum cloudWebhook;
    }

    enum def AlertStatus {
        enum detected;
        enum validated;
        enum prioritized;
        enum delivered;
        enum acknowledged;
        enum escalated;
        enum cleared;
    }

    item def SensorReading {
        attribute sourceId : String;
        attribute kind : AlertKind;
        attribute measuredValue : Real;
        attribute thresholdValue : Real;
        attribute confidence : Percent;
        attribute timestamp : String;
    }

    item def AlertEvent {
        attribute eventId : String;
        attribute kind : AlertKind;
        attribute severity : EventSeverity;
        attribute confidence : Percent;
        attribute status : AlertStatus;
        attribute detectedAt : String;
        attribute description : String;
    }

    item def NotificationMessage {
        attribute eventId : String;
        attribute channel : DeliveryChannel;
        attribute priority : EventSeverity;
        attribute title : String;
        attribute body : String;
        attribute createdAt : String;
    }

    item def Acknowledgement {
        attribute eventId : String;
        attribute userId : String;
        attribute acknowledgedAt : String;
        attribute accepted : Boolean;
    }

    item def ConfigurationProfile {
        attribute userId : String;
        attribute minimumSeverity : EventSeverity;
        attribute quietHoursEnabled : Boolean;
        attribute localAlarmVolume : AlertVolume;
        attribute escalationDelay : min;
        attribute preferredChannels : DeliveryChannel[1..*];
    }

    item def HealthReport {
        attribute batteryCharge : BatteryCharge;
        attribute wirelessSignal : SignalStrength;
        attribute sensorOnline : Boolean;
        attribute cloudReachable : Boolean;
        attribute lastSelfTestAt : String;
    }

    port def ReadingInputPort {
        in item reading : SensorReading;
    }

    port def AlertEventPort {
        out item event : AlertEvent;
    }

    port def NotificationPort {
        out item message : NotificationMessage;
    }

    port def AcknowledgementPort {
        in item acknowledgement : Acknowledgement;
    }

    port def ConfigurationPort {
        in item profile : ConfigurationProfile;
    }

    port def HealthReportPort {
        out item report : HealthReport;
    }

    port def PowerPort {
        in attribute supplyVoltage : V;
        in attribute availableCurrent : mA;
    }

    port def NetworkPort {
        out item outboundMessage : NotificationMessage;
        in item inboundAcknowledgement : Acknowledgement;
        out item outboundHealthReport : HealthReport;
    }

    part def EnvironmentalSensor {
        attribute sensorId : String;
        attribute enabled : Boolean;
        attribute samplePeriod : s;
        attribute confidenceFloor : Percent;
        port readingOut : AlertEventPort;
    }

    part def SensorHub {
        attribute pollingInterval : s;
        attribute maximumAcceptedLatency : ResponseTime;
        port environmentalReadingIn : ReadingInputPort;
        port securityReadingIn : ReadingInputPort;
        port healthReadingIn : ReadingInputPort;
        port eventOut : AlertEventPort;
    }

    part def AlertAnalyzer {
        attribute duplicateSuppressionWindow : s;
        attribute validationConfidenceThreshold : Percent;
        attribute criticalSeverityThreshold : EventSeverity;
        port rawEventIn : AlertEventPort;
        port configurationIn : ConfigurationPort;
        port prioritizedEventOut : AlertEventPort;
    }

    part def NotificationManager {
        attribute defaultEscalationDelay : min;
        attribute maximumDeliveryLatency : ResponseTime;
        port eventIn : AlertEventPort;
        port acknowledgementIn : AcknowledgementPort;
        port localNotificationOut : NotificationPort;
        port remoteNotificationOut : NotificationPort;
    }

    part def LocalAnnunciator {
        attribute maximumVolume : AlertVolume;
        attribute visualFlashRate : Real;
        attribute hapticPatternEnabled : Boolean;
        port notificationIn : NotificationPort;
    }

    part def MobileGateway {
        attribute networkRetryLimit : Integer;
        attribute retryInterval : s;
        attribute minimumSignalForPush : SignalStrength;
        port notificationIn : NotificationPort;
        port network : NetworkPort;
    }

    part def UserInterface {
        attribute displayBrightness : Percent;
        attribute acknowledgementTimeout : min;
        port notificationIn : NotificationPort;
        port acknowledgementOut : AcknowledgementPort;
        port configurationOut : ConfigurationPort;
        port healthReportIn : HealthReportPort;
    }

    part def PowerManager {
        attribute nominalVoltage : V;
        attribute lowBatteryThreshold : BatteryCharge;
        attribute criticalBatteryThreshold : BatteryCharge;
        port powerIn : PowerPort;
        port healthOut : HealthReportPort;
    }

    part def DiagnosticMonitor {
        attribute selfTestInterval : min;
        attribute degradedSignalThreshold : SignalStrength;
        port healthIn : HealthReportPort;
        port healthOut : HealthReportPort;
        port diagnosticEventOut : AlertEventPort;
    }

    action def DetectAlert {
        in item reading : SensorReading;
        out item event : AlertEvent;

        first start;
        then evaluateThreshold;
        then classifyAlert;
        then assignSeverity;
        then publishEvent;
        then done;

        action evaluateThreshold;
        action classifyAlert;
        action assignSeverity;
        action publishEvent;
    }

    action def PrioritizeAlert {
        in item candidate : AlertEvent;
        in item profile : ConfigurationProfile;
        out item prioritized : AlertEvent;

        first receiveCandidate;
        then suppressDuplicates;
        then validateConfidence;
        then applyUserProfile;
        then setPriority;
        then emitPrioritizedAlert;
        then done;

        action receiveCandidate;
        action suppressDuplicates;
        action validateConfidence;
        action applyUserProfile;
        action setPriority;
        action emitPrioritizedAlert;
    }

    action def DeliverNotification {
        in item alert : AlertEvent;
        out item localMessage : NotificationMessage;
        out item remoteMessage : NotificationMessage;

        first composeMessage;
        then selectChannels;
        then activateLocalAlarm;
        then sendRemoteNotification;
        then waitForAcknowledgement;
        then done;

        action composeMessage;
        action selectChannels;
        action activateLocalAlarm;
        action sendRemoteNotification;
        action waitForAcknowledgement;
    }

    state def AlertMeOperatingState {
        entry action initializeSystem;

        state off;
        state standby;
        state monitoring;
        state alertProcessing;
        state notifying;
        state awaitingAcknowledgement;
        state escalating;
        state degraded;
        state maintenance;

        transition first off then standby;
        transition standby then monitoring accept powerAvailable;
        transition monitoring then alertProcessing accept alertDetected;
        transition alertProcessing then notifying accept alertValidated;
        transition notifying then awaitingAcknowledgement accept notificationDelivered;
        transition awaitingAcknowledgement then monitoring accept userAcknowledged;
        transition awaitingAcknowledgement then escalating accept acknowledgementTimeout;
        transition escalating then monitoring accept escalationDelivered;
        transition monitoring then degraded accept diagnosticFaultDetected;
        transition degraded then maintenance accept serviceRequested;
        transition maintenance then standby accept serviceCompleted;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* AlertMe shall continuously monitor configured sensor inputs, determine whether a meaningful alert condition exists, and notify the responsible user through local and remote channels with sufficient urgency for timely response. */
        attribute maximumDetectionLatency : ResponseTime = 500 [ms];
        attribute maximumNotificationLatency : ResponseTime = 2000 [ms];
    }

    requirement def AlertValidationRequirement {
        doc /* AlertMe shall validate sensor readings before notification to reduce nuisance alerts while preserving critical-alert responsiveness. */
        attribute minimumConfidence : Percent = 80 [%];
        attribute duplicateSuppressionWindow : s = 30 [s];
    }

    requirement def MultiChannelNotificationRequirement {
        doc /* AlertMe shall support audible, visual, mobile push, SMS, email, and cloud webhook notification channels. */
        attribute minimumSupportedChannels : Integer = 6;
    }

    requirement def EscalationRequirement {
        doc /* AlertMe shall escalate an unacknowledged high-severity alert after the configured escalation delay. */
        attribute highSeverityLevel : EventSeverity = 8;
        attribute defaultEscalationDelay : min = 5 [min];
    }

    requirement def HealthMonitoringRequirement {
        doc /* AlertMe shall report battery, sensor, network, and cloud connectivity health to the user interface and remote service. */
        attribute selfTestInterval : min = 15 [min];
        attribute lowBatteryThreshold : BatteryCharge = 20 [%];
    }

    part def AlertMe {
        attribute productName : String = "AlertMe";
        attribute primaryFunction : String = "Monitor safety, security, health, connectivity, and power conditions; determine alert significance; and deliver timely notifications requiring user awareness or action.";
        attribute nominalSupplyVoltage : V = 5 [V];
        attribute standbyCurrent : mA = 80 [mA];
        attribute activeAlertCurrent : mA = 450 [mA];

        port externalPower : PowerPort;
        port remoteNetwork : NetworkPort;

        part sensorHub : SensorHub {
            attribute pollingInterval = 1 [s];
            attribute maximumAcceptedLatency = 250 [ms];
        }

        part analyzer : AlertAnalyzer {
            attribute duplicateSuppressionWindow = 30 [s];
            attribute validationConfidenceThreshold = 80 [%];
            attribute criticalSeverityThreshold = 8;
        }

        part notificationManager : NotificationManager {
            attribute defaultEscalationDelay = 5 [min];
            attribute maximumDeliveryLatency = 2000 [ms];
        }

        part annunciator : LocalAnnunciator {
            attribute maximumVolume = 95 [dB];
            attribute visualFlashRate = 2.0;
            attribute hapticPatternEnabled = true;
        }

        part gateway : MobileGateway {
            attribute networkRetryLimit = 3;
            attribute retryInterval = 10 [s];
            attribute minimumSignalForPush = 25 [%];
        }

        part userInterface : UserInterface {
            attribute displayBrightness = 75 [%];
            attribute acknowledgementTimeout = 5 [min];
        }

        part powerManager : PowerManager {
            attribute nominalVoltage = 5 [V];
            attribute lowBatteryThreshold = 20 [%];
            attribute criticalBatteryThreshold = 8 [%];
        }

        part diagnostics : DiagnosticMonitor {
            attribute selfTestInterval = 15 [min];
            attribute degradedSignalThreshold = 20 [%];
        }

        connection sensorHub.eventOut to analyzer.rawEventIn;
        connection diagnostics.diagnosticEventOut to analyzer.rawEventIn;
        connection analyzer.prioritizedEventOut to notificationManager.eventIn;
        connection notificationManager.localNotificationOut to annunciator.notificationIn;
        connection notificationManager.localNotificationOut to userInterface.notificationIn;
        connection notificationManager.remoteNotificationOut to gateway.notificationIn;
        connection userInterface.acknowledgementOut to notificationManager.acknowledgementIn;
        connection userInterface.configurationOut to analyzer.configurationIn;
        connection externalPower to powerManager.powerIn;
        connection powerManager.healthOut to diagnostics.healthIn;
        connection diagnostics.healthOut to userInterface.healthReportIn;
        connection gateway.network to remoteNetwork;

        perform action detectAlert : DetectAlert;
        perform action prioritizeAlert : PrioritizeAlert;
        perform action deliverNotification : DeliverNotification;

        exhibit state operatingState : AlertMeOperatingState;

        satisfy PrimaryFunctionRequirement by sensorHub;
        satisfy PrimaryFunctionRequirement by analyzer;
        satisfy PrimaryFunctionRequirement by notificationManager;
        satisfy AlertValidationRequirement by analyzer;
        satisfy MultiChannelNotificationRequirement by notificationManager;
        satisfy MultiChannelNotificationRequirement by gateway;
        satisfy MultiChannelNotificationRequirement by annunciator;
        satisfy EscalationRequirement by notificationManager;
        satisfy HealthMonitoringRequirement by powerManager;
        satisfy HealthMonitoringRequirement by diagnostics;
    }

    part alertMeSystem : AlertMe;

}