package IntelligentHomeControlModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def TemperatureCelsius :> Real {
        unit = "degC";
    }

    attribute def RelativeHumidityPercent :> Real {
        unit = "%";
    }

    attribute def IlluminanceLux :> Real {
        unit = "lx";
    }

    attribute def PowerWatt :> Real {
        unit = "W";
    }

    attribute def EnergyKiloWattHour :> Real {
        unit = "kWh";
    }

    attribute def CarbonDioxidePPM :> Real {
        unit = "ppm";
    }

    attribute def OccupancyCount :> Integer {
        unit = "person";
    }

    attribute def SecurityConfidence :> Real {
        unit = "%";
    }

    attribute def TimeSecond :> Real {
        unit = "s";
    }

    enum def HomeMode {
        enum idle;
        enum occupied;
        enum away;
        enum sleep;
        enum emergency;
        enum maintenance;
    }

    enum def SecurityMode {
        enum disarmed;
        enum armedStay;
        enum armedAway;
        enum alarm;
    }

    enum def HvacMode {
        enum off;
        enum heating;
        enum cooling;
        enum ventilating;
        enum eco;
    }

    enum def DoorLockState {
        enum locked;
        enum unlocked;
        enum jammed;
    }

    enum def DeviceHealth {
        enum nominal;
        enum degraded;
        enum failed;
    }

    item def SensorReading {
        attribute timestamp : TimeSecond;
        attribute sourceId : String;
        attribute health : DeviceHealth;
    }

    item def TemperatureReading :> SensorReading {
        attribute temperature : TemperatureCelsius;
    }

    item def HumidityReading :> SensorReading {
        attribute humidity : RelativeHumidityPercent;
    }

    item def OccupancyReading :> SensorReading {
        attribute occupants : OccupancyCount;
        attribute confidence : SecurityConfidence;
    }

    item def LightReading :> SensorReading {
        attribute illuminance : IlluminanceLux;
    }

    item def AirQualityReading :> SensorReading {
        attribute co2 : CarbonDioxidePPM;
    }

    item def PowerReading :> SensorReading {
        attribute instantaneousPower : PowerWatt;
        attribute dailyEnergy : EnergyKiloWattHour;
    }

    item def SecurityEvent {
        attribute timestamp : TimeSecond;
        attribute zoneId : String;
        attribute intrusionSuspected : Boolean;
        attribute confidence : SecurityConfidence;
    }

    item def UserCommand {
        attribute timestamp : TimeSecond;
        attribute userId : String;
        attribute requestedMode : HomeMode;
        attribute targetZone : String;
    }

    item def ControlCommand {
        attribute timestamp : TimeSecond;
        attribute targetDeviceId : String;
        attribute priority : Integer;
    }

    item def HvacCommand :> ControlCommand {
        attribute requestedMode : HvacMode;
        attribute setpoint : TemperatureCelsius;
        attribute fanEnabled : Boolean;
    }

    item def LightingCommand :> ControlCommand {
        attribute brightnessPercent : Real;
        attribute colorTemperatureKelvin : Real;
    }

    item def LockCommand :> ControlCommand {
        attribute desiredState : DoorLockState;
    }

    item def AlertMessage {
        attribute timestamp : TimeSecond;
        attribute severity : Integer;
        attribute summary : String;
        attribute requiresAcknowledgement : Boolean;
    }

    port def SensorDataPort {
        out item reading : SensorReading;
    }

    port def EnvironmentalDataPort {
        out item temperature : TemperatureReading;
        out item humidity : HumidityReading;
        out item airQuality : AirQualityReading;
    }

    port def OccupancyDataPort {
        out item occupancy : OccupancyReading;
    }

    port def LightDataPort {
        out item light : LightReading;
    }

    port def PowerDataPort {
        out item power : PowerReading;
    }

    port def SecurityEventPort {
        out item event : SecurityEvent;
    }

    port def UserInterfacePort {
        in item command : UserCommand;
        out item alert : AlertMessage;
    }

    port def HvacControlPort {
        in item command : HvacCommand;
    }

    port def LightingControlPort {
        in item command : LightingCommand;
    }

    port def LockControlPort {
        in item command : LockCommand;
    }

    port def CloudServicePort {
        out item telemetry : SensorReading;
        out item alert : AlertMessage;
        in item command : UserCommand;
    }

    part def EnvironmentalSensor {
        attribute deviceId : String;
        attribute measuredTemperature : TemperatureCelsius;
        attribute measuredHumidity : RelativeHumidityPercent;
        attribute measuredCO2 : CarbonDioxidePPM;
        attribute health : DeviceHealth;
        port environmentData : EnvironmentalDataPort;
    }

    part def OccupancySensor {
        attribute deviceId : String;
        attribute detectedOccupants : OccupancyCount;
        attribute confidence : SecurityConfidence;
        attribute health : DeviceHealth;
        port occupancyData : OccupancyDataPort;
    }

    part def LightSensor {
        attribute deviceId : String;
        attribute measuredIlluminance : IlluminanceLux;
        attribute health : DeviceHealth;
        port lightData : LightDataPort;
    }

    part def SmartMeter {
        attribute deviceId : String;
        attribute currentPower : PowerWatt;
        attribute energyToday : EnergyKiloWattHour;
        attribute health : DeviceHealth;
        port powerData : PowerDataPort;
    }

    part def DoorWindowSensor {
        attribute deviceId : String;
        attribute zoneId : String;
        attribute open : Boolean;
        attribute tamperDetected : Boolean;
        attribute health : DeviceHealth;
        port securityEvents : SecurityEventPort;
    }

    part def HvacUnit {
        attribute deviceId : String;
        attribute currentMode : HvacMode;
        attribute targetTemperature : TemperatureCelsius;
        attribute fanActive : Boolean;
        attribute compressorPower : PowerWatt;
        attribute health : DeviceHealth;
        port hvacControl : HvacControlPort;
    }

    part def SmartLight {
        attribute deviceId : String;
        attribute zoneId : String;
        attribute brightnessPercent : Real;
        attribute colorTemperatureKelvin : Real;
        attribute powerUse : PowerWatt;
        attribute health : DeviceHealth;
        port lightingControl : LightingControlPort;
    }

    part def SmartDoorLock {
        attribute deviceId : String;
        attribute zoneId : String;
        attribute lockState : DoorLockState;
        attribute batteryPercent : Real;
        attribute health : DeviceHealth;
        port lockControl : LockControlPort;
    }

    part def UserConsole {
        attribute activeUserId : String;
        attribute localDisplayEnabled : Boolean;
        port userInterface : UserInterfacePort;
    }

    part def CloudGateway {
        attribute connected : Boolean;
        attribute encryptedSessionActive : Boolean;
        attribute lastSyncAge : TimeSecond;
        port cloud : CloudServicePort;
    }

    action def EvaluateComfort {
        in item temperature : TemperatureReading;
        in item humidity : HumidityReading;
        in currentMode : HomeMode;
        out item hvacCommand : HvacCommand;

        attribute occupiedHeatingSetpoint : TemperatureCelsius = 20.5;
        attribute occupiedCoolingSetpoint : TemperatureCelsius = 24.0;
        attribute sleepHeatingSetpoint : TemperatureCelsius = 18.5;
        attribute sleepCoolingSetpoint : TemperatureCelsius = 25.5;
        attribute awayEcoSetpoint : TemperatureCelsius = 16.0;
    }

    action def OptimizeLighting {
        in item illuminance : LightReading;
        in item occupancy : OccupancyReading;
        in currentMode : HomeMode;
        out item lightingCommand : LightingCommand;

        attribute minimumOccupiedIlluminance : IlluminanceLux = 300.0;
        attribute nightBrightnessPercent : Real = 12.0;
        attribute normalBrightnessPercent : Real = 72.0;
    }

    action def AssessSecurity {
        in item occupancy : OccupancyReading;
        in item securityEvent : SecurityEvent;
        in currentSecurityMode : SecurityMode;
        out newSecurityMode : SecurityMode;
        out item alert : AlertMessage;
        out item lockCommand : LockCommand;
    }

    action def ManageEnergy {
        in item power : PowerReading;
        in currentMode : HomeMode;
        out reduceLoad : Boolean;

        attribute peakPowerLimit : PowerWatt = 5500.0;
        attribute dailyEnergyBudget : EnergyKiloWattHour = 28.0;
    }

    state def HomeControlStateMachine {
        in item userCommand : UserCommand;
        in item occupancy : OccupancyReading;
        in item securityEvent : SecurityEvent;
        in item power : PowerReading;

        attribute mode : HomeMode = HomeMode::idle;
        attribute security : SecurityMode = SecurityMode::disarmed;

        state idle;
        state occupied;
        state away;
        state sleep;
        state emergency;
        state maintenance;

        entry action initializeSystem {
            mode = HomeMode::idle;
            security = SecurityMode::disarmed;
        }

        transition first idle;

        transition idle_to_occupied
            first idle
            then occupied
            if occupancy.occupants > 0;

        transition occupied_to_away
            first occupied
            then away
            if occupancy.occupants == 0;

        transition occupied_to_sleep
            first occupied
            then sleep
            if userCommand.requestedMode == HomeMode::sleep;

        transition sleep_to_occupied
            first sleep
            then occupied
            if occupancy.occupants > 0 and userCommand.requestedMode == HomeMode::occupied;

        transition away_to_occupied
            first away
            then occupied
            if occupancy.occupants > 0 and securityEvent.intrusionSuspected == false;

        transition any_to_emergency_from_security
            first idle, occupied, away, sleep
            then emergency
            if securityEvent.intrusionSuspected == true and securityEvent.confidence >= 80.0;

        transition any_to_emergency_from_power
            first idle, occupied, away, sleep
            then emergency
            if power.instantaneousPower >= 9000.0;

        transition any_to_maintenance
            first idle, occupied, away, sleep
            then maintenance
            if userCommand.requestedMode == HomeMode::maintenance;

        transition maintenance_to_idle
            first maintenance
            then idle
            if userCommand.requestedMode == HomeMode::idle;
    }

    part def IntelligentHomeController {
        attribute controllerId : String;
        attribute currentMode : HomeMode;
        attribute currentSecurityMode : SecurityMode;
        attribute targetTemperature : TemperatureCelsius;
        attribute totalPower : PowerWatt;
        attribute dailyEnergy : EnergyKiloWattHour;
        attribute decisionCyclePeriod : TimeSecond = 5.0;
        attribute localAutonomyEnabled : Boolean = true;

        port environmentInput : EnvironmentalDataPort;
        port occupancyInput : OccupancyDataPort;
        port lightInput : LightDataPort;
        port powerInput : PowerDataPort;
        port securityInput : SecurityEventPort;
        port userInterface : UserInterfacePort;
        port cloudService : CloudServicePort;
        port hvacOutput : HvacControlPort;
        port lightingOutput : LightingControlPort;
        port lockOutput : LockControlPort;

        perform action comfortControl : EvaluateComfort;
        perform action lightingControl : OptimizeLighting;
        perform action securityAssessment : AssessSecurity;
        perform action energyManagement : ManageEnergy;
        exhibit state controlState : HomeControlStateMachine;
    }

    part def IntelligentHomeControlSystem {
        attribute primaryFunction : String =
            "Monitor occupants, environment, energy, and security conditions, then autonomously coordinate heating, cooling, lighting, access control, alerts, and cloud interaction to maintain comfort, safety, efficiency, and user intent across the home.";

        attribute homeIdentifier : String;
        attribute nominalIndoorTemperature : TemperatureCelsius = 22.0;
        attribute maximumAllowedPower : PowerWatt = 7500.0;
        attribute targetDailyEnergy : EnergyKiloWattHour = 24.0;
        attribute maximumAlertLatency : TimeSecond = 3.0;

        part controller : IntelligentHomeController {
            attribute controllerId = "IHC-CTRL-01";
            attribute currentMode = HomeMode::idle;
            attribute currentSecurityMode = SecurityMode::disarmed;
            attribute targetTemperature = 22.0;
        }

        part livingRoomEnvironmentSensor : EnvironmentalSensor {
            attribute deviceId = "ENV-LR-01";
            attribute measuredTemperature = 22.0;
            attribute measuredHumidity = 45.0;
            attribute measuredCO2 = 620.0;
            attribute health = DeviceHealth::nominal;
        }

        part bedroomEnvironmentSensor : EnvironmentalSensor {
            attribute deviceId = "ENV-BR-01";
            attribute measuredTemperature = 21.0;
            attribute measuredHumidity = 47.0;
            attribute measuredCO2 = 580.0;
            attribute health = DeviceHealth::nominal;
        }

        part livingRoomOccupancySensor : OccupancySensor {
            attribute deviceId = "OCC-LR-01";
            attribute detectedOccupants = 0;
            attribute confidence = 95.0;
            attribute health = DeviceHealth::nominal;
        }

        part hallwayOccupancySensor : OccupancySensor {
            attribute deviceId = "OCC-HW-01";
            attribute detectedOccupants = 0;
            attribute confidence = 92.0;
            attribute health = DeviceHealth::nominal;
        }

        part livingRoomLightSensor : LightSensor {
            attribute deviceId = "LUX-LR-01";
            attribute measuredIlluminance = 180.0;
            attribute health = DeviceHealth::nominal;
        }

        part utilityMeter : SmartMeter {
            attribute deviceId = "PWR-MAIN-01";
            attribute currentPower = 1150.0;
            attribute energyToday = 9.7;
            attribute health = DeviceHealth::nominal;
        }

        part frontDoorSensor : DoorWindowSensor {
            attribute deviceId = "SEC-FD-01";
            attribute zoneId = "frontEntry";
            attribute open = false;
            attribute tamperDetected = false;
            attribute health = DeviceHealth::nominal;
        }

        part rearDoorSensor : DoorWindowSensor {
            attribute deviceId = "SEC-RD-01";
            attribute zoneId = "rearEntry";
            attribute open = false;
            attribute tamperDetected = false;
            attribute health = DeviceHealth::nominal;
        }

        part hvac : HvacUnit {
            attribute deviceId = "HVAC-01";
            attribute currentMode = HvacMode::off;
            attribute targetTemperature = 22.0;
            attribute fanActive = false;
            attribute compressorPower = 0.0;
            attribute health = DeviceHealth::nominal;
        }

        part livingRoomLights : SmartLight {
            attribute deviceId = "LIGHT-LR-01";
            attribute zoneId = "livingRoom";
            attribute brightnessPercent = 0.0;
            attribute colorTemperatureKelvin = 3000.0;
            attribute powerUse = 0.0;
            attribute health = DeviceHealth::nominal;
        }

        part bedroomLights : SmartLight {
            attribute deviceId = "LIGHT-BR-01";
            attribute zoneId = "bedroom";
            attribute brightnessPercent = 0.0;
            attribute colorTemperatureKelvin = 2700.0;
            attribute powerUse = 0.0;
            attribute health = DeviceHealth::nominal;
        }

        part frontDoorLock : SmartDoorLock {
            attribute deviceId = "LOCK-FD-01";
            attribute zoneId = "frontEntry";
            attribute lockState = DoorLockState::locked;
            attribute batteryPercent = 82.0;
            attribute health = DeviceHealth::nominal;
        }

        part rearDoorLock : SmartDoorLock {
            attribute deviceId = "LOCK-RD-01";
            attribute zoneId = "rearEntry";
            attribute lockState = DoorLockState::locked;
            attribute batteryPercent = 76.0;
            attribute health = DeviceHealth::nominal;
        }

        part wallConsole : UserConsole {
            attribute activeUserId = "resident-primary";
            attribute localDisplayEnabled = true;
        }

        part cloudGateway : CloudGateway {
            attribute connected = true;
            attribute encryptedSessionActive = true;
            attribute lastSyncAge = 1.0;
        }

        connect livingRoomEnvironmentSensor.environmentData to controller.environmentInput;
        connect bedroomEnvironmentSensor.environmentData to controller.environmentInput;
        connect livingRoomOccupancySensor.occupancyData to controller.occupancyInput;
        connect hallwayOccupancySensor.occupancyData to controller.occupancyInput;
        connect livingRoomLightSensor.lightData to controller.lightInput;
        connect utilityMeter.powerData to controller.powerInput;
        connect frontDoorSensor.securityEvents to controller.securityInput;
        connect rearDoorSensor.securityEvents to controller.securityInput;
        connect wallConsole.userInterface to controller.userInterface;
        connect cloudGateway.cloud to controller.cloudService;
        connect controller.hvacOutput to hvac.hvacControl;
        connect controller.lightingOutput to livingRoomLights.lightingControl;
        connect controller.lightingOutput to bedroomLights.lightingControl;
        connect controller.lockOutput to frontDoorLock.lockControl;
        connect controller.lockOutput to rearDoorLock.lockControl;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : IntelligentHomeControlSystem;

        doc /* The intelligent home control system shall provide integrated autonomous control of comfort, lighting, security, access, energy, user interaction, and remote connectivity for a residential environment. */

        require constraint {
            system.controller.localAutonomyEnabled == true
        }
    }

    requirement def ComfortControlRequirement {
        subject system : IntelligentHomeControlSystem;

        attribute lowerComfortLimit : TemperatureCelsius = 18.0;
        attribute upperComfortLimit : TemperatureCelsius = 26.0;

        require constraint {
            system.nominalIndoorTemperature >= lowerComfortLimit and
            system.nominalIndoorTemperature <= upperComfortLimit
        }
    }

    requirement def EnergyLimitRequirement {
        subject system : IntelligentHomeControlSystem;

        attribute peakLimit : PowerWatt = 7500.0;
        attribute dailyBudget : EnergyKiloWattHour = 24.0;

        require constraint {
            system.maximumAllowedPower <= peakLimit and
            system.targetDailyEnergy <= dailyBudget
        }
    }

    requirement def SecurityResponseRequirement {
        subject system : IntelligentHomeControlSystem;

        attribute maximumResponseTime : TimeSecond = 3.0;

        require constraint {
            system.maximumAlertLatency <= maximumResponseTime
        }
    }

    requirement def SecureRemoteAccessRequirement {
        subject system : IntelligentHomeControlSystem;

        require constraint {
            system.cloudGateway.encryptedSessionActive == true
        }
    }

    requirement def DoorLockBatteryRequirement {
        subject system : IntelligentHomeControlSystem;

        attribute minimumBatteryPercent : Real = 20.0;

        require constraint {
            system.frontDoorLock.batteryPercent >= minimumBatteryPercent and
            system.rearDoorLock.batteryPercent >= minimumBatteryPercent
        }
    }

    requirement def FailOperationalRequirement {
        subject system : IntelligentHomeControlSystem;

        doc /* The controller shall continue local comfort, safety, and access-control decisions when cloud connectivity is unavailable. */

        require constraint {
            system.controller.localAutonomyEnabled == true
        }
    }

    satisfy PrimaryFunctionRequirement by IntelligentHomeControlSystem::controller;
    satisfy ComfortControlRequirement by IntelligentHomeControlSystem::controller;
    satisfy EnergyLimitRequirement by IntelligentHomeControlSystem::utilityMeter;
    satisfy SecurityResponseRequirement by IntelligentHomeControlSystem::controller;
    satisfy SecureRemoteAccessRequirement by IntelligentHomeControlSystem::cloudGateway;
    satisfy DoorLockBatteryRequirement by IntelligentHomeControlSystem::frontDoorLock;
    satisfy DoorLockBatteryRequirement by IntelligentHomeControlSystem::rearDoorLock;
    satisfy FailOperationalRequirement by IntelligentHomeControlSystem::controller;

}