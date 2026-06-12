package SmartHomeHubSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def TemperatureValue :> Real {
        unit = "degC";
    }

    attribute def HumidityValue :> Real {
        unit = "%";
    }

    attribute def PowerValue :> Real {
        unit = "W";
    }

    attribute def EnergyValue :> Real {
        unit = "kWh";
    }

    attribute def VoltageValue :> Real {
        unit = "V";
    }

    attribute def FrequencyValue :> Real {
        unit = "Hz";
    }

    attribute def TimeValue :> Real {
        unit = "s";
    }

    attribute def DistanceValue :> Real {
        unit = "m";
    }

    attribute def SignalStrengthValue :> Real {
        unit = "dBm";
    }

    attribute def DataRateValue :> Real {
        unit = "Mbps";
    }

    enum def HubOperatingMode {
        enum idle;
        enum monitoring;
        enum automating;
        enum alerting;
        enum updating;
        enum faulted;
    }

    enum def DeviceConnectivityStatus {
        enum connected;
        enum disconnected;
        enum degraded;
        enum pairing;
    }

    enum def SecurityArmingState {
        enum disarmed;
        enum armedHome;
        enum armedAway;
        enum alarmActive;
    }

    enum def AutomationPriority {
        enum safetyCritical;
        enum energySaving;
        enum comfort;
        enum convenience;
    }

    item def SensorReading {
        attribute sourceDeviceId : String;
        attribute timestamp : TimeValue;
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute motionDetected : Boolean;
        attribute illuminanceLux : Real;
        attribute batteryPercent : Real;
    }

    item def DeviceCommand {
        attribute targetDeviceId : String;
        attribute commandName : String;
        attribute requestedValue : String;
        attribute priority : AutomationPriority;
        attribute issuedAt : TimeValue;
    }

    item def SecurityEvent {
        attribute sourceDeviceId : String;
        attribute timestamp : TimeValue;
        attribute intrusionDetected : Boolean;
        attribute smokeDetected : Boolean;
        attribute waterLeakDetected : Boolean;
        attribute severity : Integer;
    }

    item def UserRequest {
        attribute userId : String;
        attribute requestText : String;
        attribute authenticated : Boolean;
        attribute timestamp : TimeValue;
    }

    item def AutomationRule {
        attribute ruleId : String;
        attribute enabled : Boolean;
        attribute triggerExpression : String;
        attribute actionExpression : String;
        attribute priority : AutomationPriority;
    }

    item def HubNotification {
        attribute recipientUserId : String;
        attribute title : String;
        attribute message : String;
        attribute critical : Boolean;
        attribute timestamp : TimeValue;
    }

    port def SensorInputPort {
        in item reading : SensorReading;
        in item securityEvent : SecurityEvent;
    }

    port def CommandOutputPort {
        out item command : DeviceCommand;
    }

    port def UserInterfacePort {
        in item request : UserRequest;
        out item notification : HubNotification;
    }

    port def CloudServicePort {
        out item telemetry : SensorReading;
        out item notification : HubNotification;
        in item cloudRuleUpdate : AutomationRule;
    }

    port def PowerInputPort {
        in attribute supplyVoltage : VoltageValue;
        in attribute inputPower : PowerValue;
    }

    port def NetworkPort {
        inout item request : UserRequest;
        inout item notification : HubNotification;
        attribute signalStrength : SignalStrengthValue;
        attribute dataRate : DataRateValue;
    }

    part def SmartDevice {
        attribute deviceId : String;
        attribute deviceName : String;
        attribute connectivityStatus : DeviceConnectivityStatus;
        attribute nominalPowerDraw : PowerValue;
        attribute lastHeartbeatAge : TimeValue;

        port commandIn : CommandOutputPort;
    }

    part def EnvironmentalSensor :> SmartDevice {
        attribute measuredTemperature : TemperatureValue;
        attribute measuredHumidity : HumidityValue;
        attribute batteryPercent : Real;

        port sensorOut : SensorInputPort;
    }

    part def MotionSensor :> SmartDevice {
        attribute detectionRange : DistanceValue;
        attribute motionDetected : Boolean;
        attribute batteryPercent : Real;

        port sensorOut : SensorInputPort;
    }

    part def DoorLock :> SmartDevice {
        attribute locked : Boolean;
        attribute tamperDetected : Boolean;

        port sensorOut : SensorInputPort;
    }

    part def SmartLight :> SmartDevice {
        attribute brightnessPercent : Real;
        attribute colorTemperatureKelvin : Real;
    }

    part def SmartThermostat :> SmartDevice {
        attribute setpointHeating : TemperatureValue;
        attribute setpointCooling : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        attribute hvacCalling : Boolean;

        port sensorOut : SensorInputPort;
    }

    part def Siren :> SmartDevice {
        attribute active : Boolean;
        attribute soundPressureDb : Real;
    }

    part def HubProcessor {
        attribute cpuUtilizationPercent : Real;
        attribute memoryUtilizationPercent : Real;
        attribute ruleEvaluationPeriod : TimeValue;
    }

    part def LocalStorage {
        attribute retainedEventCapacity : Integer;
        attribute storedRuleCount : Integer;
        attribute encrypted : Boolean;
        attribute usedStoragePercent : Real;
    }

    part def WirelessRadio {
        attribute wifiFrequency : FrequencyValue;
        attribute zigbeeFrequency : FrequencyValue;
        attribute threadFrequency : FrequencyValue;
        attribute maxDeviceCount : Integer;
        attribute averageSignalStrength : SignalStrengthValue;

        port network : NetworkPort;
        port sensorInput : SensorInputPort;
        port commandOutput : CommandOutputPort;
    }

    part def UserAppGateway {
        attribute activeSessionCount : Integer;
        attribute remoteAccessEnabled : Boolean;

        port ui : UserInterfacePort;
        port cloud : CloudServicePort;
    }

    part def AutomationEngine {
        attribute activeRuleCount : Integer;
        attribute averageDecisionLatency : TimeValue;

        in item readings : SensorReading;
        in item events : SecurityEvent;
        in item requests : UserRequest;
        in item ruleUpdates : AutomationRule;
        out item commands : DeviceCommand;
        out item notifications : HubNotification;

        action evaluateAutomationRules {
            in item latestReading : SensorReading;
            in item activeSecurityEvent : SecurityEvent;
            in item applicableRule : AutomationRule;
            out item generatedCommand : DeviceCommand;
            out item generatedNotification : HubNotification;
        }

        action optimizeEnergyUse {
            in item latestReading : SensorReading;
            out item thermostatCommand : DeviceCommand;
            out item lightingCommand : DeviceCommand;
        }

        action executeUserIntent {
            in item request : UserRequest;
            out item generatedCommand : DeviceCommand;
            out item responseNotification : HubNotification;
        }
    }

    part def SecurityManager {
        attribute armingState : SecurityArmingState;
        attribute alarmTimeout : TimeValue;
        attribute lastAlarmTimestamp : TimeValue;

        in item event : SecurityEvent;
        out item sirenCommand : DeviceCommand;
        out item alertNotification : HubNotification;

        state def SecurityStateMachine {
            state disarmed;
            state armedHome;
            state armedAway;
            state alarmActive;

            transition disarmed_to_armedHome
                first disarmed
                then armedHome;

            transition disarmed_to_armedAway
                first disarmed
                then armedAway;

            transition armedHome_to_alarmActive
                first armedHome
                then alarmActive;

            transition armedAway_to_alarmActive
                first armedAway
                then alarmActive;

            transition alarmActive_to_disarmed
                first alarmActive
                then disarmed;
        }

        action classifySecurityEvent {
            in item event : SecurityEvent;
            out attribute alarmRequired : Boolean;
            out attribute severity : Integer;
        }
    }

    part def SmartHomeHub {
        attribute hubId : String = "SHH-PRIMARY-001";
        attribute operatingMode : HubOperatingMode;
        attribute supportedDeviceCapacity : Integer = 128;
        attribute ruleEvaluationCycle : TimeValue = 1.0;
        attribute maxAutomationLatency : TimeValue = 2.0;
        attribute standbyPowerDraw : PowerValue = 6.0;
        attribute peakPowerDraw : PowerValue = 18.0;

        port powerIn : PowerInputPort;
        port sensorIn : SensorInputPort;
        port commandOut : CommandOutputPort;
        port userInterface : UserInterfacePort;
        port cloudService : CloudServicePort;
        port homeNetwork : NetworkPort;

        part processor : HubProcessor {
            attribute ruleEvaluationPeriod = 1.0;
        }

        part storage : LocalStorage {
            attribute retainedEventCapacity = 100000;
            attribute encrypted = true;
        }

        part radio : WirelessRadio {
            attribute wifiFrequency = 2.4;
            attribute zigbeeFrequency = 2.4;
            attribute threadFrequency = 2.4;
            attribute maxDeviceCount = 128;
        }

        part automationEngine : AutomationEngine {
            attribute averageDecisionLatency = 0.5;
        }

        part securityManager : SecurityManager {
            attribute alarmTimeout = 300.0;
        }

        part appGateway : UserAppGateway {
            attribute remoteAccessEnabled = true;
        }

        action collectDeviceTelemetry {
            in item reading : SensorReading;
            out item normalizedReading : SensorReading;
        }

        action coordinateHomeAutomation {
            in item reading : SensorReading;
            in item request : UserRequest;
            in item event : SecurityEvent;
            out item command : DeviceCommand;
            out item notification : HubNotification;
        }

        action maintainDeviceConnectivity {
            in attribute heartbeatAge : TimeValue;
            out attribute status : DeviceConnectivityStatus;
        }

        action dispatchCommand {
            in item command : DeviceCommand;
            out attribute accepted : Boolean;
        }

        state def HubLifecycle {
            state initializing;
            state idle;
            state monitoring;
            state automating;
            state alerting;
            state updating;
            state faulted;

            transition start_to_idle
                first initializing
                then idle;

            transition idle_to_monitoring
                first idle
                then monitoring;

            transition monitoring_to_automating
                first monitoring
                then automating;

            transition automating_to_monitoring
                first automating
                then monitoring;

            transition monitoring_to_alerting
                first monitoring
                then alerting;

            transition alerting_to_monitoring
                first alerting
                then monitoring;

            transition monitoring_to_updating
                first monitoring
                then updating;

            transition updating_to_monitoring
                first updating
                then monitoring;

            transition any_to_faulted
                first monitoring
                then faulted;
        }

        bind sensorIn = radio.sensorInput;
        bind commandOut = radio.commandOutput;
        bind homeNetwork = radio.network;
        bind userInterface = appGateway.ui;
        bind cloudService = appGateway.cloud;
    }

    part def SmartHomeSystem {
        part hub : SmartHomeHub;

        part livingRoomSensor : EnvironmentalSensor {
            attribute deviceId = "ENV-LIVING-001";
            attribute deviceName = "Living Room Climate Sensor";
            attribute connectivityStatus = DeviceConnectivityStatus::connected;
            attribute nominalPowerDraw = 0.1;
            attribute measuredTemperature = 21.0;
            attribute measuredHumidity = 45.0;
            attribute batteryPercent = 88.0;
        }

        part hallwayMotionSensor : MotionSensor {
            attribute deviceId = "MOT-HALL-001";
            attribute deviceName = "Hallway Motion Sensor";
            attribute connectivityStatus = DeviceConnectivityStatus::connected;
            attribute nominalPowerDraw = 0.05;
            attribute detectionRange = 8.0;
            attribute motionDetected = false;
            attribute batteryPercent = 76.0;
        }

        part frontDoorLock : DoorLock {
            attribute deviceId = "LOCK-FRONT-001";
            attribute deviceName = "Front Door Lock";
            attribute connectivityStatus = DeviceConnectivityStatus::connected;
            attribute nominalPowerDraw = 0.3;
            attribute locked = true;
            attribute tamperDetected = false;
        }

        part livingRoomLight : SmartLight {
            attribute deviceId = "LIGHT-LIVING-001";
            attribute deviceName = "Living Room Ceiling Light";
            attribute connectivityStatus = DeviceConnectivityStatus::connected;
            attribute nominalPowerDraw = 12.0;
            attribute brightnessPercent = 40.0;
            attribute colorTemperatureKelvin = 3000.0;
        }

        part thermostat : SmartThermostat {
            attribute deviceId = "THERM-HALL-001";
            attribute deviceName = "Main Thermostat";
            attribute connectivityStatus = DeviceConnectivityStatus::connected;
            attribute nominalPowerDraw = 2.0;
            attribute setpointHeating = 20.0;
            attribute setpointCooling = 25.0;
            attribute currentTemperature = 21.0;
            attribute hvacCalling = false;
        }

        part securitySiren : Siren {
            attribute deviceId = "SIREN-ENTRY-001";
            attribute deviceName = "Entry Siren";
            attribute connectivityStatus = DeviceConnectivityStatus::connected;
            attribute nominalPowerDraw = 8.0;
            attribute active = false;
            attribute soundPressureDb = 95.0;
        }

        connect livingRoomSensor.sensorOut to hub.sensorIn;
        connect hallwayMotionSensor.sensorOut to hub.sensorIn;
        connect frontDoorLock.sensorOut to hub.sensorIn;
        connect thermostat.sensorOut to hub.sensorIn;

        connect hub.commandOut to livingRoomLight.commandIn;
        connect hub.commandOut to thermostat.commandIn;
        connect hub.commandOut to frontDoorLock.commandIn;
        connect hub.commandOut to securitySiren.commandIn;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The smart home hub shall provide centralized coordination of connected residential devices by collecting local sensor telemetry, evaluating automation rules, processing authenticated user requests, issuing commands to controlled devices, and notifying users of significant comfort, security, and energy events. */
    }

    requirement def LocalAutomationLatencyRequirement {
        attribute maximumLatency : TimeValue = 2.0;
        doc /* The smart home hub shall evaluate local automation triggers and issue resulting device commands within 2 seconds during normal operation. */
    }

    requirement def DeviceCapacityRequirement {
        attribute minimumSupportedDevices : Integer = 64;
        doc /* The smart home hub shall support at least 64 simultaneously paired smart home devices across lighting, climate, access control, security, and environmental sensing categories. */
    }

    requirement def SecurityAlertRequirement {
        attribute maximumAlertLatency : TimeValue = 1.0;
        doc /* The smart home hub shall activate local alarm outputs and generate a user notification within 1 second of receiving a confirmed high-severity intrusion, smoke, or water-leak event while armed. */
    }

    requirement def PowerRequirement {
        attribute maximumStandbyPower : PowerValue = 8.0;
        attribute maximumPeakPower : PowerValue = 20.0;
        doc /* The smart home hub shall consume no more than 8 watts in standby monitoring mode and no more than 20 watts during peak wireless, processing, and alert activity. */
    }

    requirement def OfflineOperationRequirement {
        attribute minimumOfflineDuration : TimeValue = 86400.0;
        doc /* The smart home hub shall continue local automation, security monitoring, and direct device control for at least 24 hours without cloud connectivity. */
    }

    satisfy PrimaryFunctionRequirement by SmartHomeSystem::hub;
    satisfy LocalAutomationLatencyRequirement by SmartHomeSystem::hub::automationEngine;
    satisfy DeviceCapacityRequirement by SmartHomeSystem::hub::radio;
    satisfy SecurityAlertRequirement by SmartHomeSystem::hub::securityManager;
    satisfy PowerRequirement by SmartHomeSystem::hub;
    satisfy OfflineOperationRequirement by SmartHomeSystem::hub;

    analysis def EstimateHubPowerUse {
        in attribute standbyPower : PowerValue;
        in attribute peakPower : PowerValue;
        in attribute activeHoursPerDay : TimeValue;
        out attribute dailyEnergy : EnergyValue;

        action calculateDailyEnergy {
            in attribute standbyPower : PowerValue;
            in attribute peakPower : PowerValue;
            in attribute activeHoursPerDay : TimeValue;
            out attribute dailyEnergy : EnergyValue;
        }
    }

    view def HighLevelOperationalView {
        expose SmartHomeSystem::hub;
        expose SmartHomeSystem::livingRoomSensor;
        expose SmartHomeSystem::hallwayMotionSensor;
        expose SmartHomeSystem::frontDoorLock;
        expose SmartHomeSystem::livingRoomLight;
        expose SmartHomeSystem::thermostat;
        expose SmartHomeSystem::securitySiren;
    }

    view def RequirementTraceabilityView {
        expose PrimaryFunctionRequirement;
        expose LocalAutomationLatencyRequirement;
        expose DeviceCapacityRequirement;
        expose SecurityAlertRequirement;
        expose PowerRequirement;
        expose OfflineOperationRequirement;
        expose SmartHomeSystem::hub;
    }
}