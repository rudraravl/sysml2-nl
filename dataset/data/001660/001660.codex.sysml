package HomeAssistantSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percent {
        :> ScalarValues::Real;
        unit = "%";
    }

    attribute def CurrencyUSD {
        :> ScalarValues::Real;
        unit = "USD";
    }

    attribute def LuminanceLux {
        :> ScalarValues::Real;
        unit = "lx";
    }

    attribute def TemperatureCelsius {
        :> ScalarValues::Real;
        unit = "degC";
    }

    attribute def PowerWatt {
        :> ScalarValues::Real;
        unit = "W";
    }

    attribute def EnergyKiloWattHour {
        :> ScalarValues::Real;
        unit = "kW*h";
    }

    attribute def TimeSecond {
        :> ScalarValues::Real;
        unit = "s";
    }

    attribute def VolumeDecibel {
        :> ScalarValues::Real;
        unit = "dB";
    }

    enum def OccupancyState {
        enum vacant;
        enum occupied;
        enum sleeping;
        enum away;
    }

    enum def SecurityMode {
        enum disarmed;
        enum stayArmed;
        enum awayArmed;
        enum alarmActive;
    }

    enum def DeviceHealth {
        enum nominal;
        enum degraded;
        enum offline;
        enum faulted;
    }

    enum def CommandPriority {
        enum routine;
        enum comfort;
        enum safety;
        enum emergency;
    }

    item def VoiceCommand {
        attribute phrase : String;
        attribute confidence : Percent;
        attribute priority : CommandPriority;
        attribute issuedAt : TimeSecond;
    }

    item def AutomationCommand {
        attribute targetDeviceId : String;
        attribute commandName : String;
        attribute priority : CommandPriority;
        attribute requestedAt : TimeSecond;
    }

    item def SensorObservation {
        attribute sourceId : String;
        attribute observedAt : TimeSecond;
        attribute health : DeviceHealth;
    }

    item def TemperatureObservation :> SensorObservation {
        attribute temperature : TemperatureCelsius;
    }

    item def MotionObservation :> SensorObservation {
        attribute occupied : Boolean;
    }

    item def IlluminanceObservation :> SensorObservation {
        attribute illuminance : LuminanceLux;
    }

    item def DoorContactObservation :> SensorObservation {
        attribute open : Boolean;
    }

    item def EnergyObservation :> SensorObservation {
        attribute instantaneousPower : PowerWatt;
        attribute cumulativeEnergy : EnergyKiloWattHour;
    }

    item def UserNotification {
        attribute title : String;
        attribute message : String;
        attribute priority : CommandPriority;
        attribute createdAt : TimeSecond;
    }

    item def CloudMessage {
        attribute topic : String;
        attribute payload : String;
        attribute encrypted : Boolean;
    }

    port def VoiceInputPort {
        in item command : VoiceCommand;
    }

    port def SensorInputPort {
        in item observation : SensorObservation;
    }

    port def DeviceCommandPort {
        out item command : AutomationCommand;
    }

    port def NotificationPort {
        out item notification : UserNotification;
    }

    port def CloudSyncPort {
        in item inbound : CloudMessage;
        out item outbound : CloudMessage;
    }

    port def PowerSupplyPort {
        in attribute voltage : SI::Voltage;
        in attribute availablePower : PowerWatt;
    }

    port def NetworkPort {
        in item inbound : CloudMessage;
        out item outbound : CloudMessage;
    }

    part def SmartLight {
        port control : DeviceCommandPort;
        attribute deviceId : String;
        attribute brightness : Percent;
        attribute colorTemperature : TemperatureCelsius;
        attribute health : DeviceHealth;
        attribute standbyPower : PowerWatt = 0.5 [W];

        action switchOn {
            in attribute requestedBrightness : Percent;
            out attribute appliedBrightness : Percent;
            appliedBrightness = requestedBrightness;
        }

        action switchOff {
            out attribute appliedBrightness : Percent;
            appliedBrightness = 0 [%];
        }
    }

    part def SmartThermostat {
        port control : DeviceCommandPort;
        port measurement : SensorInputPort;
        attribute deviceId : String;
        attribute setpoint : TemperatureCelsius = 21 [degC];
        attribute ambientTemperature : TemperatureCelsius;
        attribute heatingPower : PowerWatt = 1500 [W];
        attribute coolingPower : PowerWatt = 1200 [W];
        attribute health : DeviceHealth;

        action regulateTemperature {
            in attribute requestedSetpoint : TemperatureCelsius;
            in attribute currentTemperature : TemperatureCelsius;
            out attribute hvacDemand : PowerWatt;
            hvacDemand = if currentTemperature < requestedSetpoint then heatingPower else if currentTemperature > requestedSetpoint then coolingPower else 0 [W];
        }
    }

    part def SmartLock {
        port control : DeviceCommandPort;
        port contactSensor : SensorInputPort;
        attribute deviceId : String;
        attribute locked : Boolean;
        attribute doorOpen : Boolean;
        attribute health : DeviceHealth;

        action lockDoor {
            out attribute lockedState : Boolean;
            lockedState = true;
        }

        action unlockDoor {
            out attribute lockedState : Boolean;
            lockedState = false;
        }
    }

    part def MotionSensor {
        port observationOut : SensorInputPort;
        attribute deviceId : String;
        attribute detectionRange : LengthValue = 8 [m];
        attribute lastMotionDetected : Boolean;
        attribute health : DeviceHealth;
    }

    part def AmbientSensor {
        port observationOut : SensorInputPort;
        attribute deviceId : String;
        attribute measuredTemperature : TemperatureCelsius;
        attribute measuredIlluminance : LuminanceLux;
        attribute health : DeviceHealth;
    }

    part def EnergyMeter {
        port observationOut : SensorInputPort;
        attribute deviceId : String;
        attribute measuredPower : PowerWatt;
        attribute dailyEnergy : EnergyKiloWattHour;
        attribute health : DeviceHealth;
    }

    part def VoiceAssistant {
        port voiceIn : VoiceInputPort;
        port commandOut : DeviceCommandPort;
        attribute wakeWord : String = "assistant";
        attribute minimumConfidence : Percent = 75 [%];
        attribute listening : Boolean;

        action interpretSpeech {
            in item spokenCommand : VoiceCommand;
            out item automationRequest : AutomationCommand;
            automationRequest.priority = spokenCommand.priority;
            automationRequest.commandName = spokenCommand.phrase;
            automationRequest.requestedAt = spokenCommand.issuedAt;
        }
    }

    part def AutomationEngine {
        port sensorIn : SensorInputPort;
        port voiceCommandIn : VoiceInputPort;
        port deviceCommandOut : DeviceCommandPort;
        port notificationOut : NotificationPort;

        attribute occupancy : OccupancyState = OccupancyState::vacant;
        attribute securityMode : SecurityMode = SecurityMode::disarmed;
        attribute targetComfortTemperature : TemperatureCelsius = 21 [degC];
        attribute nighttimeIlluminanceThreshold : LuminanceLux = 20 [lx];
        attribute maxAllowedStandbyPower : PowerWatt = 50 [W];

        action evaluateRules {
            in item latestObservation : SensorObservation;
            out item generatedCommand : AutomationCommand;
            out item generatedNotification : UserNotification;
        }

        action handleVoiceIntent {
            in item command : VoiceCommand;
            out item generatedCommand : AutomationCommand;
        }

        state automating {
            entry action initializeRules;
            state idle;
            state observing;
            state executingRoutine;
            state managingSecurity;
            state notifyingUser;

            transition first idle;
            transition idle_to_observing
                first idle
                accept SensorObservation
                then observing;

            transition observing_to_routine
                first observing
                if occupancy == OccupancyState::occupied and securityMode != SecurityMode::alarmActive
                then executingRoutine;

            transition observing_to_security
                first observing
                if securityMode == SecurityMode::awayArmed
                then managingSecurity;

            transition routine_to_idle
                first executingRoutine
                then idle;

            transition security_to_notify
                first managingSecurity
                if securityMode == SecurityMode::alarmActive
                then notifyingUser;

            transition notify_to_idle
                first notifyingUser
                then idle;
        }
    }

    part def MobileApplication {
        port notificationIn : NotificationPort;
        port cloud : CloudSyncPort;
        attribute loggedInUser : String;
        attribute pushEnabled : Boolean = true;
        attribute remoteAccessEnabled : Boolean = true;

        action displayNotification {
            in item notification : UserNotification;
        }
    }

    part def LocalNetwork {
        port assistantConnection : NetworkPort;
        port cloudGateway : NetworkPort;
        attribute wifiAvailable : Boolean = true;
        attribute latency : TimeSecond = 0.05 [s];
        attribute encryptedTransport : Boolean = true;
    }

    part def CloudService {
        port sync : CloudSyncPort;
        attribute region : String = "us-central";
        attribute monthlyCost : CurrencyUSD = 6.99 [USD];
        attribute retainedEventDays : Integer = 30;
    }

    part def HomeAssistantHub {
        port voice : VoiceInputPort;
        port sensors : SensorInputPort;
        port commands : DeviceCommandPort;
        port notifications : NotificationPort;
        port cloud : CloudSyncPort;
        port power : PowerSupplyPort;

        part voiceAssistant : VoiceAssistant;
        part automationEngine : AutomationEngine;
        part networkAdapter : LocalNetwork;

        attribute processorUtilization : Percent;
        attribute storageUsed : Percent;
        attribute uptime : TimeSecond;
        attribute localControlAvailable : Boolean = true;
        attribute primaryFunction : String = "Coordinate home sensors, user commands, and connected devices to automate comfort, security, lighting, and energy management.";

        connect voice to voiceAssistant.voiceIn;
        connect voiceAssistant.commandOut to automationEngine.deviceCommandOut;
        connect sensors to automationEngine.sensorIn;
        connect automationEngine.deviceCommandOut to commands;
        connect automationEngine.notificationOut to notifications;
        connect cloud to networkAdapter.assistantConnection;

        action processHomeContext {
            in item observation : SensorObservation;
            in item spokenCommand : VoiceCommand;
            out item deviceCommand : AutomationCommand;
            out item notification : UserNotification;
        }

        state operatingMode {
            state booting;
            state localReady;
            state cloudConnected;
            state degradedNetwork;
            state emergencyAlert;

            transition first booting;
            transition boot_complete
                first booting
                if localControlAvailable
                then localReady;

            transition cloud_available
                first localReady
                accept CloudMessage
                then cloudConnected;

            transition cloud_lost
                first cloudConnected
                if networkAdapter.wifiAvailable == false
                then degradedNetwork;

            transition local_recovered
                first degradedNetwork
                if networkAdapter.wifiAvailable == true
                then cloudConnected;

            transition emergency_detected
                first localReady
                if automationEngine.securityMode == SecurityMode::alarmActive
                then emergencyAlert;

            transition emergency_cleared
                first emergencyAlert
                if automationEngine.securityMode == SecurityMode::disarmed
                then localReady;
        }
    }

    part def ConnectedHome {
        part hub : HomeAssistantHub;
        part livingRoomLight : SmartLight {
            attribute deviceId = "light-living-room";
            attribute brightness = 0 [%];
        }
        part hallwayLight : SmartLight {
            attribute deviceId = "light-hallway";
            attribute brightness = 0 [%];
        }
        part thermostat : SmartThermostat {
            attribute deviceId = "thermostat-main";
        }
        part frontDoorLock : SmartLock {
            attribute deviceId = "lock-front-door";
            attribute locked = true;
        }
        part livingRoomMotion : MotionSensor {
            attribute deviceId = "motion-living-room";
        }
        part hallwayMotion : MotionSensor {
            attribute deviceId = "motion-hallway";
        }
        part ambientSensor : AmbientSensor {
            attribute deviceId = "ambient-main";
        }
        part wholeHomeEnergyMeter : EnergyMeter {
            attribute deviceId = "energy-main-panel";
        }
        part mobileApp : MobileApplication {
            attribute loggedInUser = "homeowner";
        }
        part cloudService : CloudService;

        connect livingRoomMotion.observationOut to hub.sensors;
        connect hallwayMotion.observationOut to hub.sensors;
        connect ambientSensor.observationOut to hub.sensors;
        connect wholeHomeEnergyMeter.observationOut to hub.sensors;
        connect thermostat.measurement to hub.sensors;
        connect frontDoorLock.contactSensor to hub.sensors;

        connect hub.commands to livingRoomLight.control;
        connect hub.commands to hallwayLight.control;
        connect hub.commands to thermostat.control;
        connect hub.commands to frontDoorLock.control;

        connect hub.notifications to mobileApp.notificationIn;
        connect hub.cloud to mobileApp.cloud;
        connect mobileApp.cloud to cloudService.sync;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : HomeAssistantHub;
        require constraint {
            system.localControlAvailable == true
        }
        doc /* The Home Assistant hub shall provide local coordination of sensors, user inputs, automations, and device commands so the home remains controllable without mandatory cloud connectivity. */
    }

    requirement def ComfortAutomationRequirement {
        subject system : ConnectedHome;
        require constraint {
            system.hub.automationEngine.targetComfortTemperature >= 18 [degC] and
            system.hub.automationEngine.targetComfortTemperature <= 25 [degC]
        }
        doc /* The system shall maintain indoor comfort by regulating the thermostat setpoint within an acceptable residential comfort band. */
    }

    requirement def LightingAutomationRequirement {
        subject system : ConnectedHome;
        require constraint {
            system.hub.automationEngine.nighttimeIlluminanceThreshold <= 30 [lx]
        }
        doc /* The system shall turn on selected lights when occupied areas are detected under low ambient illumination. */
    }

    requirement def SecurityMonitoringRequirement {
        subject system : ConnectedHome;
        require constraint {
            system.frontDoorLock.health != DeviceHealth::offline
        }
        doc /* The system shall monitor entry state and lock status and notify the user when an armed security mode detects unauthorized access. */
    }

    requirement def EnergyAwarenessRequirement {
        subject system : ConnectedHome;
        require constraint {
            system.hub.automationEngine.maxAllowedStandbyPower <= 50 [W]
        }
        doc /* The system shall observe whole-home energy usage and support automation decisions that reduce unnecessary standby power. */
    }

    requirement def RemoteNotificationRequirement {
        subject app : MobileApplication;
        require constraint {
            app.pushEnabled == true
        }
        doc /* The system shall send actionable notifications to a mobile application for high-priority safety, security, and availability events. */
    }

    satisfy PrimaryFunctionRequirement by ConnectedHome::hub;
    satisfy ComfortAutomationRequirement by ConnectedHome::thermostat;
    satisfy LightingAutomationRequirement by ConnectedHome::livingRoomLight;
    satisfy LightingAutomationRequirement by ConnectedHome::hallwayLight;
    satisfy SecurityMonitoringRequirement by ConnectedHome::frontDoorLock;
    satisfy EnergyAwarenessRequirement by ConnectedHome::wholeHomeEnergyMeter;
    satisfy RemoteNotificationRequirement by ConnectedHome::mobileApp;
}