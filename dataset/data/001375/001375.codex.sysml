package BuildingAutomationSystemModel {

    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    attribute def Temperature {
        :> scalarValues::Real;
        unit = "degC";
    }

    attribute def RelativeHumidity {
        :> scalarValues::Real;
        unit = "%";
    }

    attribute def CarbonDioxideConcentration {
        :> scalarValues::Real;
        unit = "ppm";
    }

    attribute def AirFlowRate {
        :> scalarValues::Real;
        unit = "m3/s";
    }

    attribute def ElectricPower {
        :> scalarValues::Real;
        unit = "kW";
    }

    attribute def Illuminance {
        :> scalarValues::Real;
        unit = "lx";
    }

    attribute def OccupancyCount {
        :> scalarValues::Integer;
        unit = "person";
    }

    attribute def TimeDuration {
        :> scalarValues::Real;
        unit = "s";
    }

    item def SensorReading {
        attribute value : Real;
        attribute timestamp : Real;
        attribute quality : Real;
    }

    item def TemperatureReading :> SensorReading {
        attribute :>> value : Temperature;
    }

    item def HumidityReading :> SensorReading {
        attribute :>> value : RelativeHumidity;
    }

    item def CO2Reading :> SensorReading {
        attribute :>> value : CarbonDioxideConcentration;
    }

    item def OccupancyReading :> SensorReading {
        attribute :>> value : OccupancyCount;
    }

    item def LightLevelReading :> SensorReading {
        attribute :>> value : Illuminance;
    }

    item def ControlCommand {
        attribute commandId : String;
        attribute priority : Integer;
        attribute issuedAt : Real;
    }

    item def DamperCommand :> ControlCommand {
        attribute positionPercent : Real;
    }

    item def ValveCommand :> ControlCommand {
        attribute openingPercent : Real;
    }

    item def FanCommand :> ControlCommand {
        attribute speedPercent : Real;
    }

    item def LightingCommand :> ControlCommand {
        attribute dimmingPercent : Real;
    }

    item def AlarmNotification {
        attribute severity : Integer;
        attribute message : String;
        attribute active : Boolean;
    }

    port def SensorDataPort {
        out item reading : SensorReading;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def AlarmPort {
        out item alarm : AlarmNotification;
    }

    port def NetworkPort {
        in item inboundCommand : ControlCommand;
        out item outboundReading : SensorReading;
        out item outboundAlarm : AlarmNotification;
    }

    port def AirPort {
        flow attribute supplyAirFlow : AirFlowRate;
        flow attribute returnAirFlow : AirFlowRate;
        flow attribute airTemperature : Temperature;
        flow attribute co2Level : CarbonDioxideConcentration;
    }

    port def ElectricPowerPort {
        in attribute suppliedPower : ElectricPower;
    }

    part def TemperatureSensor {
        attribute measuredTemperature : Temperature;
        attribute samplePeriod : TimeDuration = 10.0;
        port data : SensorDataPort;
    }

    part def HumiditySensor {
        attribute measuredHumidity : RelativeHumidity;
        attribute samplePeriod : TimeDuration = 30.0;
        port data : SensorDataPort;
    }

    part def CO2Sensor {
        attribute measuredCO2 : CarbonDioxideConcentration;
        attribute samplePeriod : TimeDuration = 30.0;
        port data : SensorDataPort;
    }

    part def OccupancySensor {
        attribute occupiedPeople : OccupancyCount;
        attribute samplePeriod : TimeDuration = 5.0;
        port data : SensorDataPort;
    }

    part def LightSensor {
        attribute measuredIlluminance : Illuminance;
        attribute samplePeriod : TimeDuration = 10.0;
        port data : SensorDataPort;
    }

    part def SupplyFan {
        attribute speedPercent : Real;
        attribute maximumFlow : AirFlowRate = 6.0;
        attribute powerDemand : ElectricPower;
        port command : CommandPort;
        port air : AirPort;
        port power : ElectricPowerPort;
    }

    part def HeatingValve {
        attribute openingPercent : Real;
        attribute heatCapacity : ElectricPower = 45.0;
        port command : CommandPort;
    }

    part def CoolingValve {
        attribute openingPercent : Real;
        attribute coolingCapacity : ElectricPower = 55.0;
        port command : CommandPort;
    }

    part def OutdoorAirDamper {
        attribute positionPercent : Real;
        attribute minimumVentilationPosition : Real = 15.0;
        port command : CommandPort;
        port air : AirPort;
    }

    part def LightingCircuit {
        attribute dimmingPercent : Real;
        attribute ratedPower : ElectricPower = 4.8;
        attribute currentPower : ElectricPower;
        port command : CommandPort;
        port power : ElectricPowerPort;
    }

    part def ZoneController {
        attribute occupiedHeatingSetpoint : Temperature = 21.0;
        attribute occupiedCoolingSetpoint : Temperature = 24.0;
        attribute unoccupiedHeatingSetpoint : Temperature = 16.0;
        attribute unoccupiedCoolingSetpoint : Temperature = 28.0;
        attribute co2Limit : CarbonDioxideConcentration = 900.0;
        attribute targetIlluminance : Illuminance = 500.0;
        attribute controlPeriod : TimeDuration = 60.0;

        port temperatureInput : SensorDataPort;
        port humidityInput : SensorDataPort;
        port co2Input : SensorDataPort;
        port occupancyInput : SensorDataPort;
        port lightInput : SensorDataPort;

        port fanOutput : CommandPort;
        port heatingValveOutput : CommandPort;
        port coolingValveOutput : CommandPort;
        port damperOutput : CommandPort;
        port lightingOutput : CommandPort;
        port alarmOutput : AlarmPort;
    }

    part def SupervisoryController {
        attribute demandLimit : ElectricPower = 120.0;
        attribute nightPurgeEnabled : Boolean = true;
        attribute remoteAccessEnabled : Boolean = true;
        port network : NetworkPort;
        port alarmInput : AlarmPort;
    }

    part def ThermalZone {
        attribute zoneName : String;
        attribute area : Real;
        attribute currentTemperature : Temperature;
        attribute currentHumidity : RelativeHumidity;
        attribute currentCO2 : CarbonDioxideConcentration;
        attribute currentIlluminance : Illuminance;
        attribute currentOccupancy : OccupancyCount;

        part temperatureSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part co2Sensor : CO2Sensor;
        part occupancySensor : OccupancySensor;
        part lightSensor : LightSensor;
        part supplyFan : SupplyFan;
        part heatingValve : HeatingValve;
        part coolingValve : CoolingValve;
        part outdoorAirDamper : OutdoorAirDamper;
        part lightingCircuit : LightingCircuit;
        part controller : ZoneController;

        port supplyAir : AirPort;
        port returnAir : AirPort;
        port power : ElectricPowerPort;
        port alarms : AlarmPort;

        connect temperatureSensor.data to controller.temperatureInput;
        connect humiditySensor.data to controller.humidityInput;
        connect co2Sensor.data to controller.co2Input;
        connect occupancySensor.data to controller.occupancyInput;
        connect lightSensor.data to controller.lightInput;

        connect controller.fanOutput to supplyFan.command;
        connect controller.heatingValveOutput to heatingValve.command;
        connect controller.coolingValveOutput to coolingValve.command;
        connect controller.damperOutput to outdoorAirDamper.command;
        connect controller.lightingOutput to lightingCircuit.command;
        connect controller.alarmOutput to alarms;

        connect supplyFan.air to supplyAir;
        connect outdoorAirDamper.air to returnAir;
        connect supplyFan.power to power;
        connect lightingCircuit.power to power;
    }

    action def ReadZoneSensors {
        in part zone : ThermalZone;
        out item temperature : TemperatureReading;
        out item humidity : HumidityReading;
        out item co2 : CO2Reading;
        out item occupancy : OccupancyReading;
        out item lightLevel : LightLevelReading;
    }

    action def ComputeComfortControl {
        in item temperature : TemperatureReading;
        in item humidity : HumidityReading;
        in item co2 : CO2Reading;
        in item occupancy : OccupancyReading;
        in item lightLevel : LightLevelReading;
        out item fanCommand : FanCommand;
        out item heatCommand : ValveCommand;
        out item coolCommand : ValveCommand;
        out item damperCommand : DamperCommand;
        out item lightingCommand : LightingCommand;
    }

    action def DispatchActuatorCommands {
        in part zone : ThermalZone;
        in item fanCommand : FanCommand;
        in item heatCommand : ValveCommand;
        in item coolCommand : ValveCommand;
        in item damperCommand : DamperCommand;
        in item lightingCommand : LightingCommand;
    }

    action def DetectFaults {
        in part zone : ThermalZone;
        out item alarm : AlarmNotification;
    }

    action def OptimizeBuildingEnergy {
        in part building : BuildingAutomationSystem;
        out attribute totalPowerLimit : ElectricPower;
    }

    state def ZoneOperatingState {
        entry action initializeZone;

        state Unoccupied;
        state Occupied;
        state Warmup;
        state Cooldown;
        state VentilationBoost;
        state Fault;

        transition first Unoccupied;

        transition Unoccupied_to_Warmup
            first Unoccupied
            then Warmup
            if zone.currentOccupancy > 0 and zone.currentTemperature < zone.controller.occupiedHeatingSetpoint;

        transition Unoccupied_to_Cooldown
            first Unoccupied
            then Cooldown
            if zone.currentOccupancy > 0 and zone.currentTemperature > zone.controller.occupiedCoolingSetpoint;

        transition Unoccupied_to_Occupied
            first Unoccupied
            then Occupied
            if zone.currentOccupancy > 0;

        transition Warmup_to_Occupied
            first Warmup
            then Occupied
            if zone.currentTemperature >= zone.controller.occupiedHeatingSetpoint;

        transition Cooldown_to_Occupied
            first Cooldown
            then Occupied
            if zone.currentTemperature <= zone.controller.occupiedCoolingSetpoint;

        transition Occupied_to_VentilationBoost
            first Occupied
            then VentilationBoost
            if zone.currentCO2 > zone.controller.co2Limit;

        transition VentilationBoost_to_Occupied
            first VentilationBoost
            then Occupied
            if zone.currentCO2 <= 750.0;

        transition Occupied_to_Unoccupied
            first Occupied
            then Unoccupied
            if zone.currentOccupancy == 0;

        transition Any_to_Fault
            then Fault
            if zone.temperatureSensor.measuredTemperature < -20.0 or zone.temperatureSensor.measuredTemperature > 60.0;
    }

    part def BuildingAutomationSystem {
        attribute buildingName : String = "Integrated Smart Building";
        attribute primaryFunction : String =
            "Automatically monitor building conditions and coordinate HVAC, lighting, ventilation, alarms, and supervisory optimization to maintain occupant comfort, indoor air quality, safety, and energy efficiency.";

        part supervisoryController : SupervisoryController;

        part lobby : ThermalZone {
            :>> zoneName = "Lobby";
            :>> area = 180.0;
        }

        part officeNorth : ThermalZone {
            :>> zoneName = "North Office";
            :>> area = 420.0;
        }

        part officeSouth : ThermalZone {
            :>> zoneName = "South Office";
            :>> area = 390.0;
        }

        part conferenceSuite : ThermalZone {
            :>> zoneName = "Conference Suite";
            :>> area = 160.0;
        }

        port buildingNetwork : NetworkPort;
        port utilityPower : ElectricPowerPort;

        connect supervisoryController.network to buildingNetwork;
        connect lobby.power to utilityPower;
        connect officeNorth.power to utilityPower;
        connect officeSouth.power to utilityPower;
        connect conferenceSuite.power to utilityPower;

        connect lobby.alarms to supervisoryController.alarmInput;
        connect officeNorth.alarms to supervisoryController.alarmInput;
        connect officeSouth.alarms to supervisoryController.alarmInput;
        connect conferenceSuite.alarms to supervisoryController.alarmInput;

        perform action monitorAndControl {
            action readLobby : ReadZoneSensors { in zone = lobby; }
            action controlLobby : ComputeComfortControl;
            action dispatchLobby : DispatchActuatorCommands { in zone = lobby; }

            action readNorth : ReadZoneSensors { in zone = officeNorth; }
            action controlNorth : ComputeComfortControl;
            action dispatchNorth : DispatchActuatorCommands { in zone = officeNorth; }

            action readSouth : ReadZoneSensors { in zone = officeSouth; }
            action controlSouth : ComputeComfortControl;
            action dispatchSouth : DispatchActuatorCommands { in zone = officeSouth; }

            action readConference : ReadZoneSensors { in zone = conferenceSuite; }
            action controlConference : ComputeComfortControl;
            action dispatchConference : DispatchActuatorCommands { in zone = conferenceSuite; }

            action optimize : OptimizeBuildingEnergy { in building = self; }
        }
    }

    requirement def MaintainThermalComfort {
        subject zone : ThermalZone;
        attribute lowerComfortLimit : Temperature = 20.0;
        attribute upperComfortLimit : Temperature = 25.0;

        require constraint {
            zone.currentTemperature >= lowerComfortLimit and
            zone.currentTemperature <= upperComfortLimit
        }

        doc
            /* Each occupied thermal zone shall maintain temperature between 20 degC and 25 degC during normal occupied operation. */
    }

    requirement def MaintainIndoorAirQuality {
        subject zone : ThermalZone;
        attribute maximumCO2 : CarbonDioxideConcentration = 1000.0;

        require constraint {
            zone.currentCO2 <= maximumCO2
        }

        doc
            /* Each occupied zone shall maintain carbon dioxide concentration at or below 1000 ppm by increasing outdoor air ventilation when needed. */
    }

    requirement def ProvideAutomaticLighting {
        subject zone : ThermalZone;
        attribute minimumTaskIlluminance : Illuminance = 450.0;
        attribute maximumUnoccupiedDimming : Real = 10.0;

        require constraint {
            (zone.currentOccupancy > 0 implies zone.currentIlluminance >= minimumTaskIlluminance) and
            (zone.currentOccupancy == 0 implies zone.lightingCircuit.dimmingPercent <= maximumUnoccupiedDimming)
        }

        doc
            /* Lighting shall provide task-level illumination when occupied and reduce output when the zone is unoccupied. */
    }

    requirement def LimitBuildingDemand {
        subject system : BuildingAutomationSystem;
        attribute maximumDemand : ElectricPower = 120.0;

        require constraint {
            system.supervisoryController.demandLimit <= maximumDemand
        }

        doc
            /* The supervisory controller shall coordinate HVAC and lighting loads to keep building electrical demand at or below 120 kW. */
    }

    requirement def DetectAndReportSensorFaults {
        subject zone : ThermalZone;
        attribute maximumDetectionTime : TimeDuration = 300.0;

        require constraint {
            zone.controller.controlPeriod <= maximumDetectionTime
        }

        doc
            /* Sensor values outside credible operating limits shall be detected and reported as alarms within 300 seconds. */
    }

    requirement def HighLevelAutomationFunction {
        subject system : BuildingAutomationSystem;

        require constraint {
            system.supervisoryController.remoteAccessEnabled == true
        }

        doc
            /* The building automation system shall provide centralized automatic control of comfort, air quality, lighting, safety alarms, and energy optimization across all controlled zones. */
    }

    satisfy MaintainThermalComfort by BuildingAutomationSystem::lobby;
    satisfy MaintainThermalComfort by BuildingAutomationSystem::officeNorth;
    satisfy MaintainThermalComfort by BuildingAutomationSystem::officeSouth;
    satisfy MaintainThermalComfort by BuildingAutomationSystem::conferenceSuite;

    satisfy MaintainIndoorAirQuality by BuildingAutomationSystem::lobby;
    satisfy MaintainIndoorAirQuality by BuildingAutomationSystem::officeNorth;
    satisfy MaintainIndoorAirQuality by BuildingAutomationSystem::officeSouth;
    satisfy MaintainIndoorAirQuality by BuildingAutomationSystem::conferenceSuite;

    satisfy ProvideAutomaticLighting by BuildingAutomationSystem::lobby;
    satisfy ProvideAutomaticLighting by BuildingAutomationSystem::officeNorth;
    satisfy ProvideAutomaticLighting by BuildingAutomationSystem::officeSouth;
    satisfy ProvideAutomaticLighting by BuildingAutomationSystem::conferenceSuite;

    satisfy LimitBuildingDemand by BuildingAutomationSystem;
    satisfy DetectAndReportSensorFaults by BuildingAutomationSystem::lobby;
    satisfy DetectAndReportSensorFaults by BuildingAutomationSystem::officeNorth;
    satisfy DetectAndReportSensorFaults by BuildingAutomationSystem::officeSouth;
    satisfy DetectAndReportSensorFaults by BuildingAutomationSystem::conferenceSuite;
    satisfy HighLevelAutomationFunction by BuildingAutomationSystem;

}