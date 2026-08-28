package EcobeeSmartThermostatSystem {

    private import ISQ::TemperatureValue;
    private import ISQ::DurationValue;
    private import ISQ::EnergyValue;
    private import ISQ::PowerValue;
    private import ISQ::ElectricPotentialValue;
    private import ISQ::ElectricChargeValue;
    private import SI::h;
    private import SI::W;
    private import SI::V;
    private import SI::A;
    private import SI::J;
    private import Time::TimeInstantValue;
    private import ScalarValues::Boolean;
    private import ScalarValues::Integer;
    private import ScalarValues::Real;
    private import ScalarValues::String;

    attribute def HumidityPercentage {
        attribute value : Real;
    }

    attribute def BatteryLevel {
        attribute value : Real;
    }

    item def TemperatureReading {
        attribute value : TemperatureValue;
        attribute timestamp : TimeInstantValue;
        attribute sensorId : String;
    }

    item def OccupancyReading {
        attribute occupied : Boolean;
        attribute timestamp : TimeInstantValue;
        attribute sensorId : String;
    }

    item def WeatherForecast {
        attribute outdoorTemp : TemperatureValue;
        attribute humidity : HumidityPercentage;
        attribute condition : String;
    }

    item def ElectricityPrice {
        attribute pricePerKWh : Real;
        attribute timestamp : TimeInstantValue;
    }

    item def EnergyReport {
        attribute runtime : DurationValue;
        attribute energyUsed : EnergyValue;
        attribute estimatedCost : Real;
        attribute period : DurationValue;
    }

    item def MaintenanceAlert {
        attribute alertType : String;
        attribute alertText : String;
        attribute severity : Integer;
    }

    item def ScheduleEntry {
        attribute startTime : TimeInstantValue;
        attribute targetTemp : TemperatureValue;
        attribute mode : String;
    }

    item def UserCommand {
        attribute commandType : String;
        attribute paramValue : Real;
    }

    item def DisplayOutput {
        attribute text : String;
    }

    item def HeatOnSignal;
    item def CoolOnSignal;
    item def FanOnSignal;
    item def AllOffSignal;
    item def SmartAwayNotification;
    item def EcoModeActiveSignal;
    item def FanOnlyCommand;
    item def EcoModeCommand;
    item def NormalModeCommand;

    port def HVACControlPort {
        out item heatSignal : HeatOnSignal;
        out item coolSignal : CoolOnSignal;
        out item fanSignal : FanOnSignal;
        out item offSignal : AllOffSignal;
    }

    port def SensorReceiverPort {
        in item tempData : TemperatureReading;
        in item occupancyData : OccupancyReading;
    }

    port def SensorTransmitterPort {
        out item tempData : TemperatureReading;
        out item occupancyData : OccupancyReading;
    }

    port def WiFiPort {
        in item forecast : WeatherForecast;
        in item priceData : ElectricityPrice;
        in item remoteCmd : UserCommand;
        out item statusReport : EnergyReport;
        out item alert : MaintenanceAlert;
    }

    port def FurnacePort {
        in item heatOn : HeatOnSignal;
    }

    port def ACPort {
        in item coolOn : CoolOnSignal;
    }

    port def FanPort {
        in item fanOn : FanOnSignal;
    }

    part def Battery {
        attribute voltage : ElectricPotentialValue;
        attribute charge : ElectricChargeValue;
        attribute level : BatteryLevel;
    }

    part def TouchscreenDisplay {
        attribute brightness : Real;
        attribute width : Integer;
        attribute height : Integer;
        in item userCommand : UserCommand;
        out item displayOutput : DisplayOutput;
    }

    part def TemperatureSensor {
        out item reading : TemperatureReading;
    }

    part def MotionDetector {
        out item reading : OccupancyReading;
    }

    part def WiFiModule {
        port internetPort : WiFiPort;
        in item forecast : WeatherForecast;
        in item priceData : ElectricityPrice;
        in item remoteCmd : UserCommand;
        out item statusReport : EnergyReport;
        out item alert : MaintenanceAlert;
    }

    part def CloudServer {
        port internetPort : WiFiPort;
    }

    part def HVACEquipment {
        attribute totalRuntime : DurationValue;
        attribute filterRuntime : DurationValue;
        attribute maxFilterRuntime : DurationValue = 4000 [h];
    }

    part def Furnace :> HVACEquipment {
        port furnacePort : FurnacePort;
        attribute heatingCapacity : PowerValue;
    }

    part def AirConditioner :> HVACEquipment {
        port acPort : ACPort;
        attribute coolingCapacity : PowerValue;
    }

    part def Fan :> HVACEquipment {
        port fanPort : FanPort;
        attribute fanSpeed : Integer;
    }

    part def RemoteSensor {
        attribute sensorId : String;
        attribute roomName : String;
        part battery : Battery;
        part tempSensor : TemperatureSensor;
        part motionSensor : MotionDetector;
        port wirelessPort : SensorTransmitterPort;

        action measureTemperature {
            out reading : TemperatureReading;
        }

        action detectOccupancy {
            out reading : OccupancyReading;
        }

        action transmitData {
            in temp : TemperatureReading;
            in occ : OccupancyReading;
            out tempData : TemperatureReading;
            out occupancyData : OccupancyReading;
        }
    }

    part def ThermostatUnit {
        port hvacControlPort : HVACControlPort;
        port sensorHubPort : SensorReceiverPort;
        port wifiPort : WiFiPort;

        part display : TouchscreenDisplay;
        part primaryTempSensor : TemperatureSensor;
        part motionDetector : MotionDetector;
        part wifi : WiFiModule;

        attribute setTemperature : TemperatureValue;
        attribute currentHumidity : HumidityPercentage;
        attribute avgOccupiedTemp : TemperatureValue;
        attribute occupancyDetected : Boolean;
        attribute occupancyPattern : String;
        attribute energySchedule : String;
        attribute unoccupiedDuration : DurationValue;
        attribute hvacRuntime : DurationValue;
        attribute filterRuntime : DurationValue;

        in item remoteTempReadings : TemperatureReading[*];
        in item remoteOccupancyReadings : OccupancyReading[*];

        action calculateAverageTemperature {
            in tempReadings : TemperatureReading[*];
            in occupancyReadings : OccupancyReading[*];
            out avgTemp : TemperatureValue;
        }

        action learnOccupancyPatterns {
            in occupancyHistory : OccupancyReading[*];
            out pattern : String;
        }

        action optimizeEnergySchedule {
            in pattern : String;
            in weather : WeatherForecast;
            in price : ElectricityPrice;
            out schedule : String;
        }

        action generateEnergyReport {
            in runtime : DurationValue;
            in price : ElectricityPrice;
            out report : EnergyReport;
        }

        action checkMaintenance {
            in filterRuntime : DurationValue;
            in maxRuntime : DurationValue;
            out alert : MaintenanceAlert;
        }

        action monitorHumidity {
            out humidity : HumidityPercentage;
        }

        action controlHeating {
            out signal : HeatOnSignal;
        }

        action controlCooling {
            out signal : CoolOnSignal;
        }

        action controlFan {
            out signal : FanOnSignal;
        }
    }

    state def ThermostatStates {
        in thermostat : ThermostatUnit;
        in furnace : Furnace;
        in ac : AirConditioner;
        in fan : Fan;
        entry; then off;

        state off;

        transition off_to_heating
            first off
            accept when thermostat.avgOccupiedTemp < thermostat.setTemperature
            then heating;

        transition off_to_cooling
            first off
            accept when thermostat.avgOccupiedTemp > thermostat.setTemperature
            then cooling;

        transition off_to_fan_only
            first off
            accept FanOnlyCommand
            then fan_only;

        transition off_to_eco
            first off
            accept EcoModeCommand
            then eco;

        transition off_to_smart_away
            first off
            accept when thermostat.unoccupiedDuration >= 2 [h]
            then smart_away;

        state heating {
            do thermostat.controlHeating;
        }

        transition heating_to_off
            first heating
            accept when thermostat.avgOccupiedTemp >= thermostat.setTemperature
            then off;

        transition heating_to_smart_away
            first heating
            accept when thermostat.unoccupiedDuration >= 2 [h]
            then smart_away;

        state cooling {
            do thermostat.controlCooling;
        }

        transition cooling_to_off
            first cooling
            accept when thermostat.avgOccupiedTemp <= thermostat.setTemperature
            then off;

        transition cooling_to_smart_away
            first cooling
            accept when thermostat.unoccupiedDuration >= 2 [h]
            then smart_away;

        state fan_only {
            do thermostat.controlFan;
        }

        transition fan_only_to_off
            first fan_only
            accept NormalModeCommand
            then off;

        state eco {
            entry assign thermostat.setTemperature := thermostat.setTemperature - 2;
            do thermostat.controlHeating;
        }

        transition eco_to_off
            first eco
            accept NormalModeCommand
            then off;

        state smart_away {
            entry assign thermostat.setTemperature := thermostat.setTemperature - 5;
            do thermostat.optimizeEnergySchedule;
        }

        transition smart_away_to_off
            first smart_away
            accept when thermostat.occupancyDetected == true
            then off;

        transition smart_away_to_off_timer
            first smart_away
            accept after 24 [h]
            then off;
    }

    connection def WirelessSensorLink {
        end sensorEnd : RemoteSensor;
        end hubEnd : ThermostatUnit;
        attribute frequency : Real;
    }

    connection def HVACControlLink {
        end thermostatEnd : ThermostatUnit;
        end furnaceEnd : Furnace;
        end acEnd : AirConditioner;
        end fanEnd : Fan;
    }

    connection def InternetLink {
        end wifiEnd : WiFiModule;
        end cloudEnd : CloudServer;
    }

    part def Home {
        part thermostat : ThermostatUnit {
            part display : TouchscreenDisplay;
            part primaryTempSensor : TemperatureSensor;
            part motionDetector : MotionDetector;
            part wifi : WiFiModule;
        }

        part furnace : Furnace {
            attribute heatingCapacity = 20000 [W];
        }

        part airConditioner : AirConditioner {
            attribute coolingCapacity = 18000 [W];
        }

        part fan : Fan {
            attribute fanSpeed = 3;
        }

        part livingRoomSensor : RemoteSensor {
            attribute sensorId = "RS-001";
            attribute roomName = "Living Room";
        }

        part bedroomSensor : RemoteSensor {
            attribute sensorId = "RS-002";
            attribute roomName = "Bedroom";
        }

        part kitchenSensor : RemoteSensor {
            attribute sensorId = "RS-003";
            attribute roomName = "Kitchen";
        }

        part cloudServer : CloudServer;

        connection : WirelessSensorLink {
            end :>> sensorEnd ::> livingRoomSensor;
            end :>> hubEnd ::> thermostat;
        }

        connection : WirelessSensorLink {
            end :>> sensorEnd ::> bedroomSensor;
            end :>> hubEnd ::> thermostat;
        }

        connection : WirelessSensorLink {
            end :>> sensorEnd ::> kitchenSensor;
            end :>> hubEnd ::> thermostat;
        }

        connection : HVACControlLink {
            end :>> thermostatEnd ::> thermostat;
            end :>> furnaceEnd ::> furnace;
            end :>> acEnd ::> airConditioner;
            end :>> fanEnd ::> fan;
        }

        connection : InternetLink {
            end :>> wifiEnd ::> thermostat.wifi;
            end :>> cloudEnd ::> cloudServer;
        }
    }

    requirement def ClimateControlReqDef {
        doc /* The thermostat shall maintain the home temperature within 1 degree of the set temperature. */
        attribute setTemp : TemperatureValue;
        attribute actualTemp : TemperatureValue;
        require constraint { actualTemp >= setTemp - 1 and actualTemp <= setTemp + 1 }
    }

    requirement def DistributedSensingReqDef {
        doc /* The system shall use remote sensor data from occupied rooms to calculate average temperature. */
        attribute sensorCount : Integer;
        attribute minSensors : Integer;
        require constraint { sensorCount >= minSensors }
    }

    requirement def EnergyEfficiencyReqDef {
        doc /* The system shall optimize energy usage based on occupancy, weather, and electricity pricing. */
        attribute energyConsumption : EnergyValue;
        attribute maxConsumption : EnergyValue;
        require constraint { energyConsumption <= maxConsumption }
    }

    requirement def SmartAwayReqDef {
        doc /* The system shall enter Smart Away mode when no occupancy is detected for 2 hours and resume upon return. */
        attribute unoccupiedDuration : DurationValue;
        attribute triggerDuration : DurationValue;
        require constraint { unoccupiedDuration >= triggerDuration }
    }

    requirement def HumidityMonitoringReqDef {
        doc /* The system shall monitor indoor humidity and maintain it within a comfortable range. */
        attribute humidity : Real;
        attribute minHumidity : Real;
        attribute maxHumidity : Real;
        require constraint { humidity >= minHumidity and humidity <= maxHumidity }
    }

    requirement def MaintenanceAlertReqDef {
        doc /* The system shall track HVAC runtime and provide maintenance alerts for air filter replacement. */
        attribute filterRuntime : DurationValue;
        attribute maxFilterRuntime : DurationValue;
        require constraint { filterRuntime >= maxFilterRuntime }
    }

    requirement def EnergyReportingReqDef {
        doc /* The system shall generate energy usage reports and estimate costs. */
        attribute reportGenerated : Boolean;
        require constraint { reportGenerated == true }
    }

    requirement def RemoteControlReqDef {
        doc /* The system shall enable remote control via a mobile app through the Wi-Fi module. */
        attribute remoteAccessEnabled : Boolean;
        require constraint { remoteAccessEnabled == true }
    }

    requirement def OccupancyLearningReqDef {
        doc /* The system shall learn household occupancy patterns to optimize the energy schedule. */
        attribute patternLearned : Boolean;
        require constraint { patternLearned == true }
    }

    requirement def WeatherIntegrationReqDef {
        doc /* The system shall fetch and use weather forecasts to optimize heating and cooling. */
        attribute forecastFetched : Boolean;
        require constraint { forecastFetched == true }
    }

    requirement def RemoteSensorBatteryReqDef {
        doc /* Remote sensors shall operate for at least 2 years on a single battery charge. */
        attribute batteryLife : DurationValue;
        attribute minBatteryLife : DurationValue;
        require constraint { batteryLife >= minBatteryLife }
    }

    part ecobeeSystem : Home;

    part EcobeeDesignContext {
        ref system :> ecobeeSystem;

        requirement climateControlReq : ClimateControlReqDef;
        requirement distributedSensingReq : DistributedSensingReqDef;
        requirement energyEfficiencyReq : EnergyEfficiencyReqDef;
        requirement smartAwayReq : SmartAwayReqDef;
        requirement humidityMonitoringReq : HumidityMonitoringReqDef;
        requirement maintenanceAlertReq : MaintenanceAlertReqDef;
        requirement energyReportingReq : EnergyReportingReqDef;
        requirement remoteControlReq : RemoteControlReqDef;
        requirement occupancyLearningReq : OccupancyLearningReqDef;
        requirement weatherIntegrationReq : WeatherIntegrationReqDef;
        requirement remoteSensorBatteryReq : RemoteSensorBatteryReqDef;

        satisfy climateControlReq by system.thermostat;
        satisfy distributedSensingReq by system.thermostat;
        satisfy energyEfficiencyReq by system.thermostat;
        satisfy smartAwayReq by system.thermostat;
        satisfy humidityMonitoringReq by system.thermostat;
        satisfy maintenanceAlertReq by system.thermostat;
        satisfy energyReportingReq by system.thermostat;
        satisfy remoteControlReq by system.thermostat.wifi;
        satisfy occupancyLearningReq by system.thermostat;
        satisfy weatherIntegrationReq by system.thermostat.wifi;
        satisfy remoteSensorBatteryReq by system.livingRoomSensor;
    }
}
