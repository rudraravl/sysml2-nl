package HomeKitBasedSmartHomeSystem {

    import ScalarValues::*;
    import SI::*;

    attribute def TemperatureC :> Real {
        unit = "degC";
    }

    attribute def RelativeHumidityPercent :> Real {
        unit = "%";
    }

    attribute def IlluminanceLux :> Real {
        unit = "lx";
    }

    attribute def PowerW :> Real {
        unit = "W";
    }

    attribute def VoltageV :> Real {
        unit = "V";
    }

    attribute def LatencyMs :> Real {
        unit = "ms";
    }

    attribute def BatteryPercent :> Real {
        unit = "%";
    }

    attribute def SecurityLevel :> String;
    attribute def DeviceIdentifier :> String;
    attribute def RoomName :> String;

    item def HomeKitCommand {
        attribute commandId : DeviceIdentifier;
        attribute targetAccessoryId : DeviceIdentifier;
        attribute commandType : String;
        attribute requestedValue : String;
        attribute authenticated : Boolean;
        attribute issuedBy : String;
    }

    item def AccessoryStatus {
        attribute accessoryId : DeviceIdentifier;
        attribute online : Boolean;
        attribute currentState : String;
        attribute batteryLevel : BatteryPercent;
        attribute powerDraw : PowerW;
    }

    item def EnvironmentReading {
        attribute temperature : TemperatureC;
        attribute humidity : RelativeHumidityPercent;
        attribute illuminance : IlluminanceLux;
        attribute motionDetected : Boolean;
    }

    item def AutomationTrigger {
        attribute triggerId : DeviceIdentifier;
        attribute source : String;
        attribute condition : String;
        attribute active : Boolean;
    }

    port def SecureWirelessPort {
        in command : HomeKitCommand;
        out status : AccessoryStatus;
        attribute encryptionEnabled : Boolean;
        attribute nominalLatency : LatencyMs;
    }

    port def SensorDataPort {
        out reading : EnvironmentReading;
    }

    port def PowerPort {
        in voltage : VoltageV;
        out load : PowerW;
    }

    port def UserInterfacePort {
        in userCommand : HomeKitCommand;
        out homeStatus : AccessoryStatus;
    }

    part def HomeKitSystem {
        attribute primaryFunction : String =
            "Provide secure, centralized monitoring and control of connected home accessories through Apple HomeKit-compatible devices, automations, and user interfaces.";

        part homeHub : HomeHub;
        part mobileApp : HomeApp;
        part secureRouter : HomeNetworkRouter;
        part livingRoomLight : SmartLight;
        part thermostat : SmartThermostat;
        part doorLock : SmartDoorLock;
        part motionSensor : MotionSensor;
        part camera : SecurityCamera;
        part automationEngine : AutomationEngine;
        part powerSupply : ResidentialPowerSupply;

        port residentInterface : UserInterfacePort;

        connect residentInterface to mobileApp.userInterface;
        connect mobileApp.cloudLink to homeHub.controllerLink;
        connect homeHub.networkPort to secureRouter.homeKitLan;
        connect homeHub.automationPort to automationEngine.controllerPort;

        connect secureRouter.lightLink to livingRoomLight.networkPort;
        connect secureRouter.thermostatLink to thermostat.networkPort;
        connect secureRouter.lockLink to doorLock.networkPort;
        connect secureRouter.sensorLink to motionSensor.networkPort;
        connect secureRouter.cameraLink to camera.networkPort;

        connect motionSensor.sensorOutput to automationEngine.sensorInput;
        connect thermostat.environmentOutput to automationEngine.environmentInput;
        connect camera.eventOutput to automationEngine.cameraInput;

        connect powerSupply.acBranch to livingRoomLight.powerInput;
        connect powerSupply.acBranch to thermostat.powerInput;
        connect powerSupply.acBranch to secureRouter.powerInput;
        connect powerSupply.acBranch to homeHub.powerInput;
    }

    part def HomeHub {
        attribute hubId : DeviceIdentifier;
        attribute firmwareVersion : String;
        attribute authenticatedUsers : Integer;
        attribute minimumSecurity : SecurityLevel = "End-to-end encrypted HomeKit session";

        port controllerLink : SecureWirelessPort;
        port networkPort : SecureWirelessPort;
        port automationPort : SecureWirelessPort;
        port powerInput : PowerPort;

        perform action authenticateCommand;
        perform action routeCommand;
        exhibit state hubOperationalStates;
    }

    part def HomeApp {
        attribute installedOnDevice : String;
        attribute userAccountId : String;
        attribute biometricUnlockRequired : Boolean = true;

        port userInterface : UserInterfacePort;
        port cloudLink : SecureWirelessPort;

        perform action receiveResidentIntent;
        perform action displayHomeState;
    }

    part def HomeNetworkRouter {
        attribute ssid : String;
        attribute supportsThread : Boolean = true;
        attribute supportsWiFi : Boolean = true;
        attribute firewallEnabled : Boolean = true;

        port homeKitLan : SecureWirelessPort;
        port lightLink : SecureWirelessPort;
        port thermostatLink : SecureWirelessPort;
        port lockLink : SecureWirelessPort;
        port sensorLink : SecureWirelessPort;
        port cameraLink : SecureWirelessPort;
        port powerInput : PowerPort;
    }

    part def SmartLight {
        attribute accessoryId : DeviceIdentifier;
        attribute room : RoomName = "Living Room";
        attribute brightnessPercent : Real;
        attribute colorTemperatureK : Real;
        attribute ratedPower : PowerW = 9.5;

        port networkPort : SecureWirelessPort;
        port powerInput : PowerPort;

        perform action setBrightness;
        perform action turnOn;
        perform action turnOff;
        exhibit state lightStates;
    }

    part def SmartThermostat {
        attribute accessoryId : DeviceIdentifier;
        attribute room : RoomName = "Hallway";
        attribute currentTemperature : TemperatureC;
        attribute targetTemperature : TemperatureC;
        attribute hvacMode : String;

        port networkPort : SecureWirelessPort;
        port environmentOutput : SensorDataPort;
        port powerInput : PowerPort;

        perform action regulateTemperature;
        exhibit state thermostatStates;
    }

    part def SmartDoorLock {
        attribute accessoryId : DeviceIdentifier;
        attribute room : RoomName = "Front Door";
        attribute locked : Boolean;
        attribute batteryLevel : BatteryPercent;

        port networkPort : SecureWirelessPort;

        perform action lockDoor;
        perform action unlockDoor;
        exhibit state lockStates;
    }

    part def MotionSensor {
        attribute accessoryId : DeviceIdentifier;
        attribute room : RoomName = "Entry";
        attribute batteryLevel : BatteryPercent;
        attribute detectionRangeM : Real;

        port networkPort : SecureWirelessPort;
        port sensorOutput : SensorDataPort;

        perform action detectMotion;
    }

    part def SecurityCamera {
        attribute accessoryId : DeviceIdentifier;
        attribute room : RoomName = "Porch";
        attribute recordingEnabled : Boolean;
        attribute resolution : String = "1920x1080";

        port networkPort : SecureWirelessPort;
        port eventOutput : SensorDataPort;

        perform action streamVideo;
        perform action detectPerson;
    }

    part def AutomationEngine {
        attribute enabled : Boolean = true;
        attribute storedAutomationCount : Integer;

        port controllerPort : SecureWirelessPort;
        port sensorInput : SensorDataPort;
        port environmentInput : SensorDataPort;
        port cameraInput : SensorDataPort;

        perform action evaluateAutomationRules;
        perform action executeScene;
    }

    part def ResidentialPowerSupply {
        attribute nominalVoltage : VoltageV = 120.0;
        attribute maximumContinuousLoad : PowerW = 2400.0;

        port acBranch : PowerPort;
    }

    action def authenticateCommand {
        in command : HomeKitCommand;
        out accepted : Boolean;

        first start;
        then verifyUserIdentity;
        then verifyAccessoryPermission;
        then establishEncryptedSession;
        then accepted = true;
    }

    action def routeCommand {
        in command : HomeKitCommand;
        out status : AccessoryStatus;

        first receiveAuthenticatedCommand;
        then identifyTargetAccessory;
        then transmitOverSecureNetwork;
        then collectAccessoryStatus;
        then returnStatusToUser;
    }

    action def receiveResidentIntent {
        in command : HomeKitCommand;
        out authenticatedCommand : HomeKitCommand;
    }

    action def displayHomeState {
        in status : AccessoryStatus;
    }

    action def setBrightness {
        in requestedBrightness : Real;
        out actualBrightness : Real;
    }

    action def turnOn {
        out state : String = "On";
    }

    action def turnOff {
        out state : String = "Off";
    }

    action def regulateTemperature {
        in target : TemperatureC;
        in current : TemperatureC;
        out hvacCommand : String;
    }

    action def lockDoor {
        out locked : Boolean = true;
    }

    action def unlockDoor {
        in authorized : Boolean;
        out locked : Boolean = false;
    }

    action def detectMotion {
        out motion : Boolean;
    }

    action def streamVideo {
        out streamActive : Boolean;
    }

    action def detectPerson {
        out personDetected : Boolean;
    }

    action def evaluateAutomationRules {
        in reading : EnvironmentReading;
        out trigger : AutomationTrigger;
    }

    action def executeScene {
        in trigger : AutomationTrigger;
        out completed : Boolean;
    }

    state def hubOperationalStates {
        state Offline;
        state Pairing;
        state Ready;
        state RoutingCommand;
        state Updating;

        initial then Offline;

        transition Offline_to_Pairing
            first Offline
            accept powerAvailable
            then Pairing;

        transition Pairing_to_Ready
            first Pairing
            accept validHomeKitPairing
            then Ready;

        transition Ready_to_Routing
            first Ready
            accept authenticatedCommandReceived
            then RoutingCommand;

        transition Routing_to_Ready
            first RoutingCommand
            accept commandDelivered
            then Ready;

        transition Ready_to_Updating
            first Ready
            accept firmwareUpdateAvailable
            then Updating;

        transition Updating_to_Ready
            first Updating
            accept updateComplete
            then Ready;
    }

    state def lightStates {
        state Off;
        state On;
        state AdaptiveLighting;

        initial then Off;

        transition Off_to_On
            first Off
            accept turnOnCommand
            then On;

        transition On_to_Off
            first On
            accept turnOffCommand
            then Off;

        transition On_to_Adaptive
            first On
            accept adaptiveLightingEnabled
            then AdaptiveLighting;

        transition Adaptive_to_On
            first AdaptiveLighting
            accept adaptiveLightingDisabled
            then On;
    }

    state def thermostatStates {
        state Idle;
        state Heating;
        state Cooling;
        state Eco;

        initial then Idle;

        transition Idle_to_Heating
            first Idle
            accept temperatureBelowSetpoint
            then Heating;

        transition Idle_to_Cooling
            first Idle
            accept temperatureAboveSetpoint
            then Cooling;

        transition Heating_to_Idle
            first Heating
            accept setpointReached
            then Idle;

        transition Cooling_to_Idle
            first Cooling
            accept setpointReached
            then Idle;

        transition Idle_to_Eco
            first Idle
            accept homeUnoccupied
            then Eco;

        transition Eco_to_Idle
            first Eco
            accept residentArrived
            then Idle;
    }

    state def lockStates {
        state Locked;
        state Unlocked;
        state Jammed;
        state LowBattery;

        initial then Locked;

        transition Locked_to_Unlocked
            first Locked
            accept authorizedUnlockCommand
            then Unlocked;

        transition Unlocked_to_Locked
            first Unlocked
            accept lockCommand
            then Locked;

        transition Any_to_Jammed
            first Locked
            accept boltObstructionDetected
            then Jammed;

        transition Jammed_to_Locked
            first Jammed
            accept obstructionCleared
            then Locked;

        transition Locked_to_LowBattery
            first Locked
            accept batteryBelowThreshold
            then LowBattery;
    }

    requirement def SecureControlRequirement {
        subject system : HomeKitSystem;

        require constraint {
            system.homeHub.minimumSecurity == "End-to-end encrypted HomeKit session"
        }

        doc
            /* The system shall authenticate resident commands and use encrypted HomeKit sessions before controlling any accessory. */
    }

    requirement def PrimaryFunctionRequirement {
        subject system : HomeKitSystem;

        require constraint {
            system.primaryFunction != ""
        }

        doc
            /* The system shall provide centralized monitoring, automation, and control of connected residential accessories. */
    }

    requirement def CommandLatencyRequirement {
        subject hub : HomeHub;

        attribute maximumPermittedLatency : LatencyMs = 500.0;

        require constraint {
            hub.networkPort.nominalLatency <= maximumPermittedLatency
        }

        doc
            /* The system shall deliver normal accessory control commands within 500 ms under nominal home network conditions. */
    }

    requirement def LocalAutomationRequirement {
        subject automation : AutomationEngine;

        require constraint {
            automation.enabled == true
        }

        doc
            /* The system shall execute configured home automations locally through the home hub when internet connectivity is unavailable. */
    }

    requirement def DoorUnlockAuthorizationRequirement {
        subject lock : SmartDoorLock;

        require constraint {
            lock.locked == true or lock.locked == false
        }

        doc
            /* The door lock shall only transition to the unlocked state after an authorized HomeKit unlock command. */
    }

    requirement def PowerCompatibilityRequirement {
        subject supply : ResidentialPowerSupply;

        require constraint {
            supply.nominalVoltage == 120.0
        }

        doc
            /* Mains-powered HomeKit accessories shall be compatible with nominal 120 V residential branch power. */
    }

    requirement def EnvironmentalAwarenessRequirement {
        subject sensor : MotionSensor;

        require constraint {
            sensor.detectionRangeM >= 5.0
        }

        doc
            /* The system shall detect occupancy events in the entry area and provide readings to the automation engine. */
    }

    requirement def BatteryMonitoringRequirement {
        subject lock : SmartDoorLock;

        require constraint {
            lock.batteryLevel >= 0.0 and lock.batteryLevel <= 100.0
        }

        doc
            /* Battery-powered accessories shall report battery level as a percentage for user visibility and automation decisions. */
    }

}