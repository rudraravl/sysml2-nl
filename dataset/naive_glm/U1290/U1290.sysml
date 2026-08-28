package HomeOS {

    import ScalarValues::*;

    // ================================================================
    // Value Type Definitions
    // ================================================================

    value def TemperatureCelsius :> Real;
    value def HumidityPercent :> Real;
    value def IlluminanceLux :> Real;
    value def PowerWatts :> Real;
    value def EnergyKWh :> Real;
    value def BrightnessPercent :> Real;
    value def DurationMinutes :> Real;
    value def TimestampSeconds :> Real;

    // ================================================================
    // Enumeration Definitions
    // ================================================================

    enum ClimateMode {
        heating;
        cooling;
        ventilation;
        idle;
    }

    enum AlertLevel {
        normal;
        warning;
        critical;
    }

    enum OperationalMode {
        activeMonitoring;
        standby;
        securityAlert;
        maintenance;
    }

    enum SystemStatus {
        operational;
        degraded;
        offline;
    }

    enum OverrideType {
        setTemperature;
        setLighting;
        armSecurity;
        disarmSecurity;
        setOperationalMode;
    }

    // ================================================================
    // Item Definitions
    // ================================================================

    item def SensorReading {
        attribute zoneId : String;
        attribute temperature : TemperatureCelsius;
        attribute humidity : HumidityPercent;
        attribute illuminance : IlluminanceLux;
        attribute occupied : Boolean;
        attribute timestamp : TimestampSeconds;
    }

    item def ClimateCommand {
        attribute mode : ClimateMode;
        attribute targetTemperature : TemperatureCelsius;
        attribute fanSpeedLevel : Integer;
    }

    item def LightingCommand {
        attribute fixtureId : String;
        attribute poweredOn : Boolean;
        attribute brightness : BrightnessPercent;
    }

    item def SecurityEvent {
        attribute armed : Boolean;
        attribute intrusionDetected : Boolean;
        attribute alertLevel : AlertLevel;
        attribute zoneId : String;
        attribute timestamp : TimestampSeconds;
    }

    item def EnergyData {
        attribute sourceId : String;
        attribute currentDraw : PowerWatts;
        attribute cumulativeConsumption : EnergyKWh;
        attribute timestamp : TimestampSeconds;
    }

    item def UserPreferences {
        attribute desiredTemperature : TemperatureCelsius;
        attribute temperatureTolerance : TemperatureCelsius;
        attribute wakeTime : String;
        attribute sleepTime : String;
        attribute autoStandbyDelay : DurationMinutes;
        attribute securityAutoArmEnabled : Boolean;
    }

    item def SystemStatusReport {
        attribute currentMode : OperationalMode;
        attribute status : SystemStatus;
        attribute totalPowerDraw : PowerWatts;
        attribute totalEnergyConsumed : EnergyKWh;
        attribute activeZones : Integer;
        attribute timestamp : TimestampSeconds;
    }

    item def UserOverride {
        attribute overrideType : OverrideType;
        attribute targetDevice : String;
        attribute value : Real;
        attribute isActive : Boolean;
    }

    // ================================================================
    // Port Definitions
    // ================================================================

    port def SensorOutputPort {
        out reading : SensorReading;
    }

    port def SensorInputPort {
        in reading : SensorReading;
    }

    port def ClimateCmdOutputPort {
        out command : ClimateCommand;
    }

    port def ClimateCmdInputPort {
        in command : ClimateCommand;
    }

    port def LightingCmdOutputPort {
        out command : LightingCommand;
    }

    port def LightingCmdInputPort {
        in command : LightingCommand;
    }

    port def SecurityEventOutputPort {
        out event : SecurityEvent;
    }

    port def SecurityEventInputPort {
        in event : SecurityEvent;
    }

    port def EnergyOutputPort {
        out data : EnergyData;
    }

    port def EnergyInputPort {
        in data : EnergyData;
    }

    port def StatusReportOutputPort {
        out report : SystemStatusReport;
    }

    port def OverrideInputPort {
        in override : UserOverride;
    }

    // ================================================================
    // Part Definitions — Subsystem Components
    // ================================================================

    part def EnvironmentalSensor {
        attribute zoneId : String;
        attribute samplingInterval : DurationMinutes;
        attribute isOnline : Boolean;
        attribute sensorPowerDraw : PowerWatts;

        port sensorOut : SensorOutputPort;
        port energyOut : EnergyOutputPort;

        action def SampleEnvironment {
            in zone : String;
            out reading : SensorReading;
            out energy : EnergyData;
        }

        perform sample : SampleEnvironment {
            in zone = zoneId;
            out reading -> sensorOut.reading;
            out energy -> energyOut.data;
        }
    }

    part def ClimateController {
        attribute maxHeatingPower : PowerWatts;
        attribute maxCoolingPower : PowerWatts;
        attribute currentMode : ClimateMode;
        attribute currentPowerDraw : PowerWatts;
        attribute isActive : Boolean;

        port climateCmdIn : ClimateCmdInputPort;
        port energyOut : EnergyOutputPort;

        action def ExecuteClimateCommand {
            in cmd : ClimateCommand;
            out energy : EnergyData;
        }

        perform operate : ExecuteClimateCommand {
            in cmd = climateCmdIn.command;
            out energy -> energyOut.data;
        }
    }

    part def LightFixture {
        attribute fixtureId : String;
        attribute zoneId : String;
        attribute maxBrightness : BrightnessPercent;
        attribute currentBrightness : BrightnessPercent;
        attribute poweredOn : Boolean;
        attribute ratedPower : PowerWatts;

        port lightCmdIn : LightingCmdInputPort;
        port energyOut : EnergyOutputPort;

        action def ApplyLightingCommand {
            in cmd : LightingCommand;
            out energy : EnergyData;
        }

        perform setLevel : ApplyLightingCommand {
            in cmd = lightCmdIn.command;
            out energy -> energyOut.data;
        }
    }

    part def LightingSystem {
        attribute systemId : String;

        part fixtures : LightFixture[6] {
            attribute fixtureId = ("L1", "L2", "L3", "L4", "L5", "L6");
        }

        port lightCmdIn : LightingCmdInputPort;
        port energyOut : EnergyOutputPort;

        action def RouteCommand {
            in cmd : LightingCommand;
        }

        perform route : RouteCommand {
            in cmd = lightCmdIn.command;
        }
    }

    part def SecurityMonitor {
        attribute isArmed : Boolean;
        attribute intrusionDetected : Boolean;
        attribute currentAlertLevel : AlertLevel;
        attribute monitorPowerDraw : PowerWatts;

        port securityEventOut : SecurityEventOutputPort;
        port energyOut : EnergyOutputPort;

        action def MonitorSecurity {
            in armed : Boolean;
            out event : SecurityEvent;
            out energy : EnergyData;
        }

        perform watch : MonitorSecurity {
            in armed = isArmed;
            out event -> securityEventOut.event;
            out energy -> energyOut.data;
        }
    }

    part def EnergyManager {
        attribute totalConsumption : EnergyKWh;
        attribute currentTotalDraw : PowerWatts;
        attribute reportingInterval : DurationMinutes;

        port energyIn : EnergyInputPort;
        port statusOut : StatusReportOutputPort;

        action def AggregateEnergyData {
            in data : EnergyData;
            out totalPower : PowerWatts;
            out cumulativeEnergy : EnergyKWh;
        }

        perform collect : AggregateEnergyData {
            in data = energyIn.data;
            out totalPower -> statusOut.report.totalPowerDraw;
            out cumulativeEnergy -> statusOut.report.totalEnergyConsumed;
        }
    }

    // ================================================================
    // Central Controller with State Machine
    // ================================================================

    part def CentralController {
        attribute preferences : UserPreferences;
        attribute currentMode : OperationalMode;
        attribute systemStatus : SystemStatus;
        attribute lastActivityTimestamp : TimestampSeconds;
        attribute standbyDelayDuration : DurationMinutes;
        attribute userOverrideActive : Boolean;
        attribute noActivityTimeout : Boolean;
        attribute activityDetected : Boolean;
        attribute intrusionTriggered : Boolean;
        attribute alertCleared : Boolean;
        attribute maintenanceRequested : Boolean;
        attribute maintenanceComplete : Boolean;

        port sensorInputs : SensorInputPort[4];
        port climateCmdOut : ClimateCmdOutputPort;
        port lightingCmdOut : LightingCmdOutputPort;
        port securityEventIn : SecurityEventInputPort;
        port energyDataIn : EnergyInputPort;
        port statusReportOut : StatusReportOutputPort;
        port overrideIn : OverrideInputPort;

        action def AnalyzeSensorData {
            in reading : SensorReading;
            in prefs : UserPreferences;
            in mode : OperationalMode;
            out climateCmd : ClimateCommand;
            out lightCmd : LightingCommand;
        }

        action def ProcessSecurityEvent {
            in event : SecurityEvent;
            out newMode : OperationalMode;
        }

        action def GenerateStatusReport {
            in mode : OperationalMode;
            in power : PowerWatts;
            in energy : EnergyKWh;
            out report : SystemStatusReport;
        }

        action def HandleUserOverride {
            in override : UserOverride;
        }

        state machine ControllerStateMachine {

            state activeMonitoring {
                entry / systemStatus = operational;
                do analyze : AnalyzeSensorData {
                    in reading = sensorInputs.reading;
                    in prefs = preferences;
                    in mode = currentMode;
                    out climateCmd -> climateCmdOut.command;
                    out lightCmd -> lightingCmdOut.command;
                }
            }

            state standby {
                entry / systemStatus = operational;
            }

            state securityAlert {
                entry / systemStatus = degraded;
            }

            state maintenance {
                entry / systemStatus = offline;
            }

            transition from activeMonitoring to standby
                when noActivityTimeout == true;

            transition from standby to activeMonitoring
                when activityDetected == true;

            transition from activeMonitoring to securityAlert
                when intrusionTriggered == true;

            transition from standby to securityAlert
                when intrusionTriggered == true;

            transition from securityAlert to activeMonitoring
                when alertCleared == true;

            transition from activeMonitoring to maintenance
                when maintenanceRequested == true;

            transition from standby to maintenance
                when maintenanceRequested == true;

            transition from maintenance to activeMonitoring
                when maintenanceComplete == true;
        }
    }

    // ================================================================
    // Requirement Definitions
    // ================================================================

    requirement def ComfortControlRequirement {
        subject home : HomeSystem;
        attribute desiredTemp : TemperatureCelsius;
        attribute tempTolerance : TemperatureCelsius;
        requirement {
            The HomeOS shall maintain the home temperature within the user-defined tolerance
            of the desired temperature when operating in Active Monitoring mode.
        }
    }

    requirement def SecurityAlertRequirement {
        subject home : HomeSystem;
        requirement {
            When the SecurityMonitor detects an intrusion, the HomeOS shall enter Security
            Alert state, triggering alarms and sending notifications to the user.
        }
    }

    requirement def EnergyOptimizationRequirement {
        subject home : HomeSystem;
        attribute standbyDelay : DurationMinutes;
        requirement {
            The HomeOS shall enter Standby mode when no activity is detected for the
            configured standby delay duration to reduce energy consumption.
        }
    }

    requirement def ManualOverrideRequirement {
        subject home : HomeSystem;
        requirement {
            The HomeOS shall allow users to manually override any automated control of
            connected devices at any time, including climate, lighting, and security.
        }
    }

    requirement def MaintenanceModeRequirement {
        subject home : HomeSystem;
        requirement {
            The HomeOS shall provide a Maintenance mode for system updates or service
            during which all automated controls are suspended.
        }
    }

    requirement def EnergyTrackingRequirement {
        subject home : HomeSystem;
        requirement {
            The EnergyManager shall track power draw and total energy consumption of all
            connected subsystems and report this information through the CentralController.
        }
    }

    requirement def EnvironmentalMonitoringRequirement {
        subject home : HomeSystem;
        attribute sensorCount : Integer;
        attribute samplingInterval : DurationMinutes;
        requirement {
            The HomeOS shall deploy environmental sensors throughout the home to monitor
            temperature, humidity, ambient light levels, and room occupancy as primary
            input for controller decisions.
        }
    }

    requirement def LightingControlRequirement {
        subject home : HomeSystem;
        attribute fixtureCount : Integer;
        requirement {
            The HomeOS shall control light fixtures remotely including on/off and
            brightness adjustment according to schedule, time of day, or room occupancy.
        }
    }

    // ================================================================
    // Top-Level Home System Assembly
    // ================================================================

    part def HomeSystem {
        attribute systemName : String;
        attribute firmwareVersion : String;
        attribute installationId : String;

        part controller : CentralController {
            attribute standbyDelayDuration = 30.0;
            attribute currentMode = activeMonitoring;
            attribute systemStatus = operational;
            attribute noActivityTimeout = false;
            attribute activityDetected = false;
            attribute intrusionTriggered = false;
            attribute alertCleared = false;
            attribute maintenanceRequested = false;
            attribute maintenanceComplete = false;
            attribute userOverrideActive = false;
        }

        part sensors : EnvironmentalSensor[4] {
            attribute zoneId = ("LivingRoom", "Bedroom", "Kitchen", "Bathroom");
            attribute samplingInterval = 1.0;
            attribute isOnline = true;
            attribute sensorPowerDraw = 5.0;
        }

        part climate : ClimateController {
            attribute maxHeatingPower = 3500.0;
            attribute maxCoolingPower = 2800.0;
            attribute currentMode = idle;
            attribute currentPowerDraw = 0.0;
            attribute isActive = false;
        }

        part lighting : LightingSystem {
            attribute systemId = "LightingSystem-01";
        }

        part security : SecurityMonitor {
            attribute isArmed = false;
            attribute intrusionDetected = false;
            attribute currentAlertLevel = normal;
            attribute monitorPowerDraw = 10.0;
        }

        part energyMgr : EnergyManager {
            attribute reportingInterval = 15.0;
            attribute totalConsumption = 0.0;
            attribute currentTotalDraw = 0.0;
        }

        // Sensor to Controller connections
        connection from sensors[0].sensorOut to controller.sensorInputs[0];
        connection from sensors[1].sensorOut to controller.sensorInputs[1];
        connection from sensors[2].sensorOut to controller.sensorInputs[2];
        connection from sensors[3].sensorOut to controller.sensorInputs[3];

        // Controller to Climate Controller
        connection from controller.climateCmdOut to climate.climateCmdIn;

        // Controller to Lighting System
        connection from controller.lightingCmdOut to lighting.lightCmdIn;

        // Security Monitor to Controller
        connection from security.securityEventOut to controller.securityEventIn;

        // Energy outputs to Energy Manager
        connection from climate.energyOut to energyMgr.energyIn;
        connection from security.energyOut to energyMgr.energyIn;
        connection from sensors[0].energyOut to energyMgr.energyIn;
        connection from sensors[1].energyOut to energyMgr.energyIn;
        connection from sensors[2].energyOut to energyMgr.energyIn;
        connection from sensors[3].energyOut to energyMgr.energyIn;
        connection from lighting.energyOut to energyMgr.energyIn;

        // Energy Manager to Controller
        connection from energyMgr.statusOut to controller.statusReportOut;

        // Requirement satisfactions
        satisfy ComfortControlRequirement by controller;
        satisfy SecurityAlertRequirement by controller;
        satisfy EnergyOptimizationRequirement by controller;
        satisfy ManualOverrideRequirement by controller;
        satisfy MaintenanceModeRequirement by controller;
        satisfy EnergyTrackingRequirement by energyMgr;
        satisfy EnvironmentalMonitoringRequirement by sensors;
        satisfy LightingControlRequirement by lighting;
    }
}
