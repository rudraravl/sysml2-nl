package SmartHomeAutomationSystem {
    import ScalarValues::*;

    // ============================================================
    // Value Types
    // ============================================================
    value type TemperatureValue > Real { unit "degC"; }
    value type HumidityValue > Real { unit "percent"; min 0; max 100; }
    value type IlluminanceValue > Real { unit "lux"; }
    value type BrightnessValue > Real { unit "percent"; min 0; max 100; }
    value type PowerValue > Real { unit "W"; }
    value type TimeValue > Real { unit "s"; }
    value type TimeOfDayValue > Real { unit "h"; min 0; max 24; }

    // ============================================================
    // Item Definitions
    // ============================================================
    item def SensorData {
        attribute timestamp : TimeValue;
        attribute roomId : String;
    }

    item def TemperatureHumidityData :> SensorData {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
    }

    item def OccupancyData :> SensorData {
        attribute occupied : Boolean;
    }

    item def DeviceCommand {
        attribute deviceId : String;
        attribute timestamp : TimeValue;
    }

    item def ThermostatCommand :> DeviceCommand {
        attribute targetTemperature : TemperatureValue;
    }

    item def LightCommand :> DeviceCommand {
        attribute on : Boolean;
        attribute brightness : BrightnessValue;
    }

    item def LockCommand :> DeviceCommand {
        attribute locked : Boolean;
    }

    item def AccessEvent {
        attribute timestamp : TimeValue;
        attribute userId : String;
        attribute locked : Boolean;
        attribute method : String;
    }

    item def DeviceStatus {
        attribute deviceId : String;
        attribute online : Boolean;
        attribute timestamp : TimeValue;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def SensorOutPort {
        out data : SensorData;
    }

    port def SensorInPort {
        in data : SensorData;
    }

    port def CommandOutPort {
        out command : DeviceCommand;
    }

    port def CommandInPort {
        in command : DeviceCommand;
    }

    port def StatusOutPort {
        out status : DeviceStatus;
    }

    port def StatusInPort {
        in status : DeviceStatus;
    }

    port def AccessEventOutPort {
        out event : AccessEvent;
    }

    port def AccessEventInPort {
        in event : AccessEvent;
    }

    // ============================================================
    // Sensor Devices
    // ============================================================
    part def TemperatureHumiditySensor {
        port sensorOut : SensorOutPort;
        port statusOut : StatusOutPort;
        attribute deviceId : String;
        attribute roomId : String;
        attribute currentTemperature : TemperatureValue;
        attribute currentHumidity : HumidityValue;
        attribute samplingInterval : TimeValue = 60;
        attribute online : Boolean = true;

        action def SampleEnvironment {
            out reading : TemperatureHumidityData;
        }

        action sample : SampleEnvironment {
            bind reading.temperature = currentTemperature;
            bind reading.humidity = currentHumidity;
            bind reading.roomId = roomId;
        }

        state def SensorOperationalState {
            initial Off;
            state Off;
            state Active;
            transition Off -> Active when online == true;
            transition Active -> Off when online == false;
        }
    }

    part def OccupancySensor {
        port sensorOut : SensorOutPort;
        port statusOut : StatusOutPort;
        attribute deviceId : String;
        attribute roomId : String;
        attribute occupied : Boolean = false;
        attribute detectionRange : Real = 5.0;
        attribute online : Boolean = true;

        action def DetectMotion {
            out reading : OccupancyData;
        }

        action detect : DetectMotion {
            bind reading.occupied = occupied;
            bind reading.roomId = roomId;
        }

        state def OccupancySensorState {
            initial Idle;
            state Idle;
            state Triggered;
            transition Idle -> Triggered when occupied == true;
            transition Triggered -> Idle when occupied == false;
        }
    }

    // ============================================================
    // Actuator Devices
    // ============================================================
    part def SmartThermostat {
        port commandIn : CommandInPort;
        port statusOut : StatusOutPort;
        attribute deviceId : String;
        attribute roomId : String;
        attribute setpoint : TemperatureValue = 22.0;
        attribute currentTemperature : TemperatureValue;
        attribute powerConsumption : PowerValue;
        attribute online : Boolean = true;

        action def ApplyThermostatCommand {
            in command : ThermostatCommand;
        }

        action applyCommand : ApplyThermostatCommand {
            bind setpoint = command.targetTemperature;
        }

        state def ThermostatState {
            initial Off;
            state Off;
            state Heating;
            state Cooling;
            transition Off -> Heating when currentTemperature < setpoint;
            transition Off -> Cooling when currentTemperature > setpoint;
            transition Heating -> Off when currentTemperature >= setpoint;
            transition Cooling -> Off when currentTemperature <= setpoint;
            transition Heating -> Cooling when currentTemperature > setpoint;
            transition Cooling -> Heating when currentTemperature < setpoint;
        }
    }

    part def SmartLight {
        port commandIn : CommandInPort;
        port statusOut : StatusOutPort;
        attribute deviceId : String;
        attribute roomId : String;
        attribute on : Boolean = false;
        attribute brightness : BrightnessValue = 100;
        attribute powerConsumption : PowerValue;
        attribute online : Boolean = true;

        action def ApplyLightCommand {
            in command : LightCommand;
        }

        action applyCommand : ApplyLightCommand {
            bind on = command.on;
            bind brightness = command.brightness;
        }

        state def LightState {
            initial Off;
            state Off;
            state On;
            transition Off -> On when commandIn.command.on == true;
            transition On -> Off when commandIn.command.on == false;
        }
    }

    part def SmartDoorLock {
        port commandIn : CommandInPort;
        port statusOut : StatusOutPort;
        port accessEventOut : AccessEventOutPort;
        attribute deviceId : String;
        attribute locked : Boolean = true;
        attribute accessLog : AccessEvent[0..*];
        attribute online : Boolean = true;

        action def ApplyLockCommand {
            in command : LockCommand;
            out event : AccessEvent;
        }

        action applyCommand : ApplyLockCommand {
            bind locked = command.locked;
        }

        state def LockState {
            initial Locked;
            state Locked;
            state Unlocked;
            transition Locked -> Unlocked when commandIn.command.locked == false;
            transition Unlocked -> Locked when commandIn.command.locked == true;
        }
    }

    // ============================================================
    // Automation Controller
    // ============================================================
    part def AutomationController {
        port sensorIn : SensorInPort;
        port commandOut : CommandOutPort;
        port overrideIn : CommandInPort;
        port statusIn : StatusInPort;
        attribute energySavingTemp : TemperatureValue = 18.0;
        attribute comfortTemp : TemperatureValue = 22.0;
        attribute nightStartTime : TimeOfDayValue = 20.0;
        attribute rulesActive : Boolean = true;
        attribute currentTimeOfDay : TimeOfDayValue;

        action def EvaluateRules {
            in sensorData : SensorData;
            out command : DeviceCommand;
        }

        action evaluate : EvaluateRules {
            // Rule 1: vacant room -> energy-saving thermostat setpoint
            if (sensorData.~TemperatureHumidityData ?) {
                // temperature-based comfort handling
            }
        }

        state def ControllerState {
            initial Idle;
            state Idle;
            state Evaluating;
            state Dispatching;
            transition Idle -> Evaluating when sensorIn.data ?;
            transition Evaluating -> Dispatching;
            transition Dispatching -> Idle;
        }
    }

    // ============================================================
    // Communication Module
    // ============================================================
    part def CommunicationModule {
        port sensorIn : SensorInPort;
        port commandOut : CommandOutPort;
        attribute protocol : String = "Zigbee";
        attribute networkId : String;
        attribute encryptionEnabled : Boolean = true;

        action def RouteSensorData {
            in data : SensorData;
        }

        action def RouteCommand {
            in command : DeviceCommand;
        }
    }

    // ============================================================
    // User Dashboard
    // ============================================================
    part def UserDashboard {
        port commandOut : CommandOutPort;
        port statusIn : StatusInPort;
        port accessEventIn : AccessEventInPort;
        attribute dashboardId : String;
        attribute currentUser : String;
        attribute sessionActive : Boolean = false;

        action def DisplayStatus {
            in status : DeviceStatus;
        }

        action def DisplayAccessLog {
            in event : AccessEvent;
        }

        action def SendManualOverride {
            out command : DeviceCommand;
        }

        state def DashboardSessionState {
            initial LoggedOut;
            state LoggedOut;
            state LoggedIn;
            transition LoggedOut -> LoggedIn when sessionActive == true;
            transition LoggedIn -> LoggedOut when sessionActive == false;
        }
    }

    // ============================================================
    // Central Hub
    // ============================================================
    part def CentralHub {
        port sensorIn : SensorInPort;
        port commandOut : CommandOutPort;
        port dashboardCommandIn : CommandInPort;
        port statusIn : StatusInPort;
        port statusOut : StatusOutPort;
        port accessEventIn : AccessEventInPort;
        port accessEventOut : AccessEventOutPort;

        attribute hubId : String;
        attribute firmwareVersion : String = "1.4.0";
        attribute uptime : TimeValue;

        part controller : AutomationController;
        part comm : CommunicationModule;

        connect sensorIn to controller.sensorIn;
        connect controller.sensorIn to comm.sensorIn;
        connect controller.commandOut to commandOut;
        connect controller.commandOut to comm.commandOut;
        connect dashboardCommandIn to controller.overrideIn;
        connect statusIn to controller.statusIn;
        connect controller.statusIn to statusOut;
        connect accessEventIn to accessEventOut;
    }

    // ============================================================
    // Smart Home System (Top-level composition)
    // ============================================================
    part def SmartHomeSystem {
        attribute systemName : String = "HomeAutomationSystem";
        attribute installedLocation : String;

        part hub : CentralHub {
            attribute hubId = "HUB-001";
        }

        part livingRoomTempSensor : TemperatureHumiditySensor {
            attribute deviceId = "THS-LR-01";
            attribute roomId = "livingRoom";
        }

        part bedroomTempSensor : TemperatureHumiditySensor {
            attribute deviceId = "THS-BR-01";
            attribute roomId = "bedroom";
        }

        part livingRoomOccupancy : OccupancySensor {
            attribute deviceId = "OCC-LR-01";
            attribute roomId = "livingRoom";
        }

        part bedroomOccupancy : OccupancySensor {
            attribute deviceId = "OCC-BR-01";
            attribute roomId = "bedroom";
        }

        part thermostat : SmartThermostat {
            attribute deviceId = "TSTAT-01";
            attribute roomId = "livingRoom";
        }

        part livingRoomLight : SmartLight {
            attribute deviceId = "LIGHT-LR-01";
            attribute roomId = "livingRoom";
        }

        part bedroomLight : SmartLight {
            attribute deviceId = "LIGHT-BR-01";
            attribute roomId = "bedroom";
        }

        part frontDoorLock : SmartDoorLock {
            attribute deviceId = "LOCK-FD-01";
        }

        part dashboard : UserDashboard {
            attribute dashboardId = "DASH-01";
        }

        // Sensor data -> Hub
        connect livingRoomTempSensor.sensorOut to hub.sensorIn;
        connect bedroomTempSensor.sensorOut to hub.sensorIn;
        connect livingRoomOccupancy.sensorOut to hub.sensorIn;
        connect bedroomOccupancy.sensorOut to hub.sensorIn;

        // Hub commands -> Devices
        connect hub.commandOut to thermostat.commandIn;
        connect hub.commandOut to livingRoomLight.commandIn;
        connect hub.commandOut to bedroomLight.commandIn;
        connect hub.commandOut to frontDoorLock.commandIn;

        // Device status -> Hub
        connect thermostat.statusOut to hub.statusIn;
        connect livingRoomLight.statusOut to hub.statusIn;
        connect bedroomLight.statusOut to hub.statusIn;
        connect frontDoorLock.statusOut to hub.statusIn;
        connect livingRoomTempSensor.statusOut to hub.statusIn;
        connect bedroomTempSensor.statusOut to hub.statusIn;
        connect livingRoomOccupancy.statusOut to hub.statusIn;
        connect bedroomOccupancy.statusOut to hub.statusIn;

        // Access events -> Hub -> Dashboard
        connect frontDoorLock.accessEventOut to hub.accessEventIn;
        connect hub.accessEventOut to dashboard.accessEventIn;

        // Dashboard status monitoring
        connect hub.statusOut to dashboard.statusIn;

        // Dashboard manual override -> Hub
        connect dashboard.commandOut to hub.dashboardCommandIn;
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def CentralizedControlRequirement {
        doc "The system shall provide a Central Hub that coordinates all connected smart devices from a single point of control.";
        subject system : SmartHomeSystem;
        constraint { system.hub.controller.rulesActive == true }
    }

    requirement def SensorDataCollectionRequirement {
        doc "The system shall continuously collect temperature, humidity, and occupancy data from sensors distributed in each room.";
        subject system : SmartHomeSystem;
        constraint { system.livingRoomTempSensor.online == true }
        constraint { system.bedroomTempSensor.online == true }
        constraint { system.livingRoomOccupancy.online == true }
        constraint { system.bedroomOccupancy.online == true }
    }

    requirement def EnergyEfficiencyRequirement {
        doc "The Automation Controller shall set the Smart Thermostat to an energy-saving temperature when a room is detected as vacant.";
        subject system : SmartHomeSystem;
        constraint { system.hub.controller.energySavingTemp == 18.0 }
    }

    requirement def OccupancyLightingRequirement {
        doc "The system shall turn on the Smart Light in a room when occupancy is detected after the configured night start time.";
        subject system : SmartHomeSystem;
        constraint { system.hub.controller.nightStartTime == 20.0 }
    }

    requirement def DoorLockControlRequirement {
        doc "The Smart Door Lock shall support remote lock and unlock commands and shall log every access event with timestamp and user identity.";
        subject system : SmartHomeSystem;
        constraint { system.frontDoorLock.accessLog->size() >= 0 }
    }

    requirement def DashboardMonitoringRequirement {
        doc "The User Dashboard shall display the status, temperature, and occupancy of all rooms and shall allow manual override of automated actions.";
        subject system : SmartHomeSystem;
        constraint { system.dashboard.sessionActive == true }
    }

    requirement def ManualOverrideRequirement {
        doc "Manual commands issued through the User Dashboard shall take precedence over active automation rules for the targeted device.";
        subject system : SmartHomeSystem;
        constraint { system.dashboard.commandOut.command.deviceId != "" }
    }

    requirement package SmartHomeRequirements {
        requirement centralizedControl : CentralizedControlRequirement;
        requirement sensorCollection : SensorDataCollectionRequirement;
        requirement energyEfficiency : EnergyEfficiencyRequirement;
        requirement occupancyLighting : OccupancyLightingRequirement;
        requirement doorLockControl : DoorLockControlRequirement;
        requirement dashboardMonitoring : DashboardMonitoringRequirement;
        requirement manualOverride : ManualOverrideRequirement;
    }

    // ============================================================
    // Verification
    // ============================================================
    verification def VerifyEnergyEfficiencyRule {
        subject system : SmartHomeSystem;
        objective {
            doc "Confirm that when a room is vacant, the thermostat setpoint is set to the energy-saving temperature."
        }
    }

    verification def VerifyManualOverride {
        subject system : SmartHomeSystem;
        objective {
            doc "Confirm that a manual override command from the dashboard is routed to the target device and applied."
        }
    }

    verification def VerifyAccessLogging {
        subject system : SmartHomeSystem;
        objective {
            doc "Confirm that every lock/unlock command produces an AccessEvent entry in the access log."
        }
    }
}
