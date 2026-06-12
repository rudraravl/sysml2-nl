package LightingControlSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percent :> Real {
        doc /* Percentage value from 0 to 100. */
    }

    attribute def Lux :> Real {
        doc /* Illuminance measured in lumen per square meter. */
    }

    attribute def Watt :> Real {
        doc /* Electrical power in watts. */
    }

    attribute def Volt :> Real {
        doc /* Electrical potential in volts. */
    }

    attribute def Ampere :> Real {
        doc /* Electrical current in amperes. */
    }

    attribute def Second :> Real {
        doc /* Time duration in seconds. */
    }

    attribute def BooleanCommand :> Boolean;

    enum def OccupancyState {
        enum occupied;
        enum vacant;
        enum unknown;
    }

    enum def LightingMode {
        enum off;
        enum standby;
        enum automatic;
        enum manualOverride;
        enum emergency;
        enum fault;
    }

    item def AmbientLightReading {
        attribute illuminance : Lux;
        attribute sampleAge : Second;
    }

    item def OccupancyReading {
        attribute state : OccupancyState;
        attribute confidence : Percent;
        attribute sampleAge : Second;
    }

    item def DimmerCommand {
        attribute commandedLevel : Percent;
        attribute fadeTime : Second;
    }

    item def ManualSwitchCommand {
        attribute requestedOn : Boolean;
        attribute requestedLevel : Percent;
    }

    item def EmergencyLightingCommand {
        attribute emergencyActive : Boolean;
    }

    item def ElectricalPower {
        attribute voltage : Volt;
        attribute current : Ampere;
        attribute power : Watt;
    }

    item def DiagnosticReport {
        attribute sensorHealthy : Boolean;
        attribute driverHealthy : Boolean;
        attribute luminaireHealthy : Boolean;
        attribute controllerHealthy : Boolean;
    }

    port def AmbientLightSensorPort {
        out item reading : AmbientLightReading;
    }

    port def OccupancySensorPort {
        out item reading : OccupancyReading;
    }

    port def ManualControlPort {
        out item command : ManualSwitchCommand;
    }

    port def EmergencyInputPort {
        out item command : EmergencyLightingCommand;
    }

    port def LightingCommandPort {
        in item command : DimmerCommand;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def PowerOutputPort {
        out item power : ElectricalPower;
    }

    port def DiagnosticsPort {
        out item report : DiagnosticReport;
    }

    part def AmbientLightSensor {
        attribute measuredIlluminance : Lux;
        attribute updatePeriod : Second = 1.0;
        attribute isHealthy : Boolean = true;

        port sensingPort : AmbientLightSensorPort;

        action senseAmbientLight {
            out item sensedReading : AmbientLightReading;
        }
    }

    part def OccupancySensor {
        attribute detectionRangeMeters : Real = 8.0;
        attribute holdTime : Second = 300.0;
        attribute isHealthy : Boolean = true;

        port occupancyPort : OccupancySensorPort;

        action detectOccupancy {
            out item occupancyReading : OccupancyReading;
        }
    }

    part def WallSwitch {
        attribute lastRequestedLevel : Percent = 100.0;
        attribute manualOverrideTimeout : Second = 1800.0;

        port manualPort : ManualControlPort;

        action requestManualLighting {
            in attribute requestedOn : Boolean;
            in attribute requestedLevel : Percent;
            out item command : ManualSwitchCommand;
        }
    }

    part def EmergencyInterface {
        attribute emergencyActive : Boolean = false;

        port emergencyPort : EmergencyInputPort;

        action detectEmergencySignal {
            out item command : EmergencyLightingCommand;
        }
    }

    part def PowerSupply {
        attribute nominalVoltage : Volt = 120.0;
        attribute maxOutputPower : Watt = 600.0;
        attribute efficiency : Percent = 92.0;
        attribute isHealthy : Boolean = true;

        port mainsInput : PowerInputPort;
        port regulatedOutput : PowerOutputPort;
    }

    part def LEDDriver {
        attribute inputVoltage : Volt = 120.0;
        attribute outputPowerLimit : Watt = 240.0;
        attribute commandedLevel : Percent = 0.0;
        attribute isHealthy : Boolean = true;

        port powerIn : PowerInputPort;
        port powerOut : PowerOutputPort;
        port commandIn : LightingCommandPort;
        port diagnosticsOut : DiagnosticsPort;

        action convertDimCommandToPower {
            in item dimmerCommand : DimmerCommand;
            out item deliveredPower : ElectricalPower;
        }
    }

    part def LuminaireArray {
        attribute fixtureCount : Integer = 12;
        attribute ratedPowerPerFixture : Watt = 18.0;
        attribute maximumIlluminance : Lux = 750.0;
        attribute currentOutputLevel : Percent = 0.0;
        attribute isHealthy : Boolean = true;

        port powerIn : PowerInputPort;
        port diagnosticsOut : DiagnosticsPort;

        action emitLight {
            in item suppliedPower : ElectricalPower;
            out attribute deliveredIlluminance : Lux;
        }
    }

    part def LightingController {
        attribute targetOccupiedIlluminance : Lux = 500.0;
        attribute targetVacantIlluminance : Lux = 50.0;
        attribute daylightHarvestingEnabled : Boolean = true;
        attribute minimumDimLevel : Percent = 10.0;
        attribute maximumDimLevel : Percent = 100.0;
        attribute vacantDelay : Second = 300.0;
        attribute manualOverrideActive : Boolean = false;
        attribute currentMode : LightingMode = LightingMode::standby;
        attribute currentCommandedLevel : Percent = 0.0;
        attribute isHealthy : Boolean = true;

        port ambientInput : AmbientLightSensorPort;
        port occupancyInput : OccupancySensorPort;
        port manualInput : ManualControlPort;
        port emergencyInput : EmergencyInputPort;
        port driverCommandOut : LightingCommandPort;
        port diagnosticsOut : DiagnosticsPort;

        action computeAutomaticDimLevel {
            in item ambient : AmbientLightReading;
            in item occupancy : OccupancyReading;
            out item command : DimmerCommand;
        }

        action applyManualOverride {
            in item manualCommand : ManualSwitchCommand;
            out item command : DimmerCommand;
        }

        action forceEmergencyLighting {
            in item emergencyCommand : EmergencyLightingCommand;
            out item command : DimmerCommand;
        }

        action publishDiagnostics {
            out item report : DiagnosticReport;
        }

        state def ControllerStateMachine {
            state initial;

            state Standby;
            state AutomaticControl;
            state ManualOverride;
            state VacantLowLight;
            state EmergencyLighting;
            state FaultDetected;

            transition initial then Standby;

            transition Standby then AutomaticControl
                accept OccupancyReading
                if state == OccupancyState::occupied;

            transition AutomaticControl then VacantLowLight
                accept OccupancyReading
                if state == OccupancyState::vacant;

            transition VacantLowLight then AutomaticControl
                accept OccupancyReading
                if state == OccupancyState::occupied;

            transition AutomaticControl then ManualOverride
                accept ManualSwitchCommand;

            transition VacantLowLight then ManualOverride
                accept ManualSwitchCommand;

            transition ManualOverride then AutomaticControl
                after 1800.0 [Second];

            transition Standby then EmergencyLighting
                accept EmergencyLightingCommand
                if emergencyActive == true;

            transition AutomaticControl then EmergencyLighting
                accept EmergencyLightingCommand
                if emergencyActive == true;

            transition ManualOverride then EmergencyLighting
                accept EmergencyLightingCommand
                if emergencyActive == true;

            transition VacantLowLight then EmergencyLighting
                accept EmergencyLightingCommand
                if emergencyActive == true;

            transition EmergencyLighting then Standby
                accept EmergencyLightingCommand
                if emergencyActive == false;

            transition Standby then FaultDetected
                accept DiagnosticReport
                if controllerHealthy == false;

            transition AutomaticControl then FaultDetected
                accept DiagnosticReport
                if sensorHealthy == false or driverHealthy == false or luminaireHealthy == false;

            transition ManualOverride then FaultDetected
                accept DiagnosticReport
                if driverHealthy == false;

            transition VacantLowLight then FaultDetected
                accept DiagnosticReport
                if sensorHealthy == false;

            transition FaultDetected then Standby
                accept DiagnosticReport
                if sensorHealthy == true and driverHealthy == true and luminaireHealthy == true and controllerHealthy == true;
        }
    }

    part def LightingControlSystem {
        doc /* Primary function: automatically provide safe, efficient, and occupant-responsive illumination by combining occupancy sensing, ambient daylight measurement, user override input, and emergency commands to regulate LED fixture output. */

        attribute designAreaSquareMeters : Real = 160.0;
        attribute maximumInstalledPower : Watt = 216.0;
        attribute normalTargetIlluminance : Lux = 500.0;
        attribute vacantTargetIlluminance : Lux = 50.0;
        attribute emergencyOutputLevel : Percent = 100.0;
        attribute energySavingModeEnabled : Boolean = true;

        part controller : LightingController;
        part ambientSensor : AmbientLightSensor;
        part occupancySensor : OccupancySensor;
        part wallSwitch : WallSwitch;
        part emergencyInterface : EmergencyInterface;
        part powerSupply : PowerSupply;
        part driver : LEDDriver;
        part luminaires : LuminaireArray;

        port buildingPowerInput : PowerInputPort;
        port systemDiagnostics : DiagnosticsPort;

        connect buildingPowerInput to powerSupply.mainsInput;
        connect powerSupply.regulatedOutput to driver.powerIn;
        connect driver.powerOut to luminaires.powerIn;

        connect ambientSensor.sensingPort to controller.ambientInput;
        connect occupancySensor.occupancyPort to controller.occupancyInput;
        connect wallSwitch.manualPort to controller.manualInput;
        connect emergencyInterface.emergencyPort to controller.emergencyInput;
        connect controller.driverCommandOut to driver.commandIn;

        connect controller.diagnosticsOut to systemDiagnostics;
        connect driver.diagnosticsOut to systemDiagnostics;
        connect luminaires.diagnosticsOut to systemDiagnostics;

        action operateLightingControl {
            first startSensing;
            then evaluateEnvironment;
            then determineLightingMode;
            then commandDriver;
            then illuminateArea;

            action startSensing {
                out item ambient : AmbientLightReading;
                out item occupancy : OccupancyReading;
            }

            action evaluateEnvironment {
                in item ambient : AmbientLightReading;
                in item occupancy : OccupancyReading;
                out attribute daylightContribution : Lux;
                out attribute occupied : Boolean;
            }

            action determineLightingMode {
                in attribute daylightContribution : Lux;
                in attribute occupied : Boolean;
                out item command : DimmerCommand;
            }

            action commandDriver {
                in item command : DimmerCommand;
                out item deliveredPower : ElectricalPower;
            }

            action illuminateArea {
                in item deliveredPower : ElectricalPower;
                out attribute maintainedIlluminance : Lux;
            }
        }
    }

    requirement def ProvideAutomaticLighting {
        doc /* The system shall automatically regulate lighting output according to occupancy and ambient light. */
        subject system : LightingControlSystem;
        require constraint {
            system.energySavingModeEnabled == true
        }
    }

    requirement def MaintainOccupiedIlluminance {
        doc /* When the area is occupied and no emergency or fault is active, the maintained work-plane illuminance shall be at least 500 lux. */
        subject system : LightingControlSystem;
        attribute requiredIlluminance : Lux = 500.0;
    }

    requirement def ReduceLightingWhenVacant {
        doc /* When the area is vacant beyond the configured delay, lighting output shall be reduced to a low standby level. */
        subject system : LightingControlSystem;
        attribute maximumVacantIlluminance : Lux = 50.0;
        attribute vacancyDelay : Second = 300.0;
    }

    requirement def SupportManualOverride {
        doc /* The system shall allow a local user to override automatic dimming through a wall control. */
        subject system : LightingControlSystem;
        attribute overrideTimeout : Second = 1800.0;
    }

    requirement def SupportEmergencyLighting {
        doc /* Upon emergency input, the system shall command full lighting output regardless of occupancy or daylight. */
        subject system : LightingControlSystem;
        attribute emergencyLevel : Percent = 100.0;
    }

    requirement def LimitInstalledPower {
        doc /* The installed lighting load shall not exceed 216 watts for the controlled area. */
        subject system : LightingControlSystem;
        attribute maximumAllowedPower : Watt = 216.0;
        require constraint {
            system.maximumInstalledPower <= maximumAllowedPower
        }
    }

    requirement def ProvideDiagnostics {
        doc /* The system shall report health status for sensors, controller, driver, and luminaires. */
        subject system : LightingControlSystem;
    }

    satisfy ProvideAutomaticLighting by LightingControlSystem::controller;
    satisfy MaintainOccupiedIlluminance by LightingControlSystem::luminaires;
    satisfy ReduceLightingWhenVacant by LightingControlSystem::controller;
    satisfy SupportManualOverride by LightingControlSystem::wallSwitch;
    satisfy SupportEmergencyLighting by LightingControlSystem::emergencyInterface;
    satisfy LimitInstalledPower by LightingControlSystem::luminaires;
    satisfy ProvideDiagnostics by LightingControlSystem::controller;

    constraint def DimLevelBounds {
        in attribute commandedLevel : Percent;
        constraint {
            commandedLevel >= 0.0 and commandedLevel <= 100.0
        }
    }

    constraint def OccupiedLightingPolicy {
        in attribute ambientIlluminance : Lux;
        in attribute targetIlluminance : Lux;
        in attribute commandedLevel : Percent;
        constraint {
            if ambientIlluminance >= targetIlluminance then commandedLevel == 0.0
            else commandedLevel > 0.0
        }
    }

    constraint def EmergencyLightingPolicy {
        in attribute emergencyActive : Boolean;
        in attribute commandedLevel : Percent;
        constraint {
            if emergencyActive then commandedLevel == 100.0
        }
    }

    part lightingControlSystem : LightingControlSystem;

}