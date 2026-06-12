package SNOTEL_System_Model {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent : Real {
        doc /* Fraction expressed from 0 to 100 percent. */
    }

    attribute def Millimeter : Real {
        doc /* Depth or water equivalent in millimeters. */
    }

    attribute def Celsius : Real {
        doc /* Temperature in degrees Celsius. */
    }

    attribute def Volt : Real {
        doc /* Electrical potential in volts. */
    }

    attribute def Watt : Real {
        doc /* Electrical power in watts. */
    }

    attribute def WattHour : Real {
        doc /* Electrical energy in watt-hours. */
    }

    attribute def Minute : Real {
        doc /* Time duration in minutes. */
    }

    attribute def Second : Real {
        doc /* Time duration in seconds. */
    }

    attribute def KilobitPerSecond : Real {
        doc /* Communication throughput in kilobits per second. */
    }

    attribute def Meter : Real {
        doc /* Length or station elevation in meters. */
    }

    item def SnowWaterEquivalentReading {
        attribute value : Millimeter;
        attribute uncertainty : Millimeter;
        attribute sampleTime : Time;
        attribute sensorStatus : SensorHealth;
    }

    item def SnowDepthReading {
        attribute value : Millimeter;
        attribute uncertainty : Millimeter;
        attribute sampleTime : Time;
        attribute sensorStatus : SensorHealth;
    }

    item def AirTemperatureReading {
        attribute value : Celsius;
        attribute uncertainty : Celsius;
        attribute sampleTime : Time;
        attribute sensorStatus : SensorHealth;
    }

    item def PrecipitationReading {
        attribute accumulatedDepth : Millimeter;
        attribute intervalDepth : Millimeter;
        attribute sampleTime : Time;
        attribute sensorStatus : SensorHealth;
    }

    item def StationTelemetryPacket {
        attribute stationIdentifier : String;
        attribute sequenceNumber : Integer;
        attribute createdAt : Time;
        attribute batteryVoltage : Volt;
        attribute batteryStateOfCharge : Percent;
        attribute snowWaterEquivalent : Millimeter;
        attribute snowDepth : Millimeter;
        attribute airTemperature : Celsius;
        attribute precipitationInterval : Millimeter;
        attribute enclosureTemperature : Celsius;
        attribute qualityCode : TelemetryQualityCode;
    }

    item def ConfigurationCommand {
        attribute commandIdentifier : String;
        attribute requestedSampleInterval : Minute;
        attribute requestedTransmitInterval : Minute;
        attribute issuedAt : Time;
    }

    item def SolarEnergyFlow {
        attribute power : Watt;
        attribute voltage : Volt;
    }

    item def ElectricalEnergyFlow {
        attribute power : Watt;
        attribute voltage : Volt;
        attribute storedEnergy : WattHour;
    }

    item def RadioSignal {
        attribute dataRate : KilobitPerSecond;
        attribute signalStrength : Percent;
        attribute packet : StationTelemetryPacket;
    }

    item def MaintenanceNotice {
        attribute noticeIdentifier : String;
        attribute generatedAt : Time;
        attribute severity : MaintenanceSeverity;
        attribute description : String;
    }

    enum def SensorHealth {
        enum nominal;
        enum degraded;
        enum failed;
        enum uncalibrated;
    }

    enum def TelemetryQualityCode {
        enum valid;
        enum estimated;
        enum suspect;
        enum invalid;
    }

    enum def MaintenanceSeverity {
        enum advisory;
        enum warning;
        enum critical;
    }

    port def SnowWaterEquivalentSensorPort {
        out item reading : SnowWaterEquivalentReading;
    }

    port def SnowDepthSensorPort {
        out item reading : SnowDepthReading;
    }

    port def TemperatureSensorPort {
        out item reading : AirTemperatureReading;
    }

    port def PrecipitationSensorPort {
        out item reading : PrecipitationReading;
    }

    port def TelemetryOutPort {
        out item signal : RadioSignal;
    }

    port def CommandInPort {
        in item command : ConfigurationCommand;
    }

    port def PowerSourcePort {
        out item energy : ElectricalEnergyFlow;
    }

    port def PowerLoadPort {
        in item energy : ElectricalEnergyFlow;
    }

    port def SolarInputPort {
        in item solar : SolarEnergyFlow;
    }

    part def SnowPillowSensor {
        attribute measurementRange : Millimeter = 2500.0;
        attribute accuracy : Millimeter = 12.0;
        attribute calibrationInterval : Month = 12 [SI::month];

        port snowWaterEquivalentOut : SnowWaterEquivalentSensorPort;

        action measureSnowWaterEquivalent {
            out item reading : SnowWaterEquivalentReading;
        }
    }

    part def UltrasonicSnowDepthSensor {
        attribute measurementRange : Millimeter = 5000.0;
        attribute accuracy : Millimeter = 10.0;
        attribute minimumValidEchoStrength : Percent = 35.0;

        port snowDepthOut : SnowDepthSensorPort;

        action measureSnowDepth {
            out item reading : SnowDepthReading;
        }
    }

    part def AirTemperatureSensor {
        attribute measurementRangeLow : Celsius = -50.0;
        attribute measurementRangeHigh : Celsius = 50.0;
        attribute accuracy : Celsius = 0.3;

        port airTemperatureOut : TemperatureSensorPort;

        action measureAirTemperature {
            out item reading : AirTemperatureReading;
        }
    }

    part def PrecipitationGauge {
        attribute bucketCapacity : Millimeter = 750.0;
        attribute resolution : Millimeter = 0.25;
        attribute heaterPowerDemand : Watt = 12.0;

        port precipitationOut : PrecipitationSensorPort;
        port powerIn : PowerLoadPort;

        action measurePrecipitation {
            out item reading : PrecipitationReading;
        }
    }

    part def SolarPanel {
        attribute ratedPower : Watt = 40.0;
        attribute nominalVoltage : Volt = 18.0;

        port solarIn : SolarInputPort;
        port powerOut : PowerSourcePort;

        action convertSolarToElectrical {
            in item solar : SolarEnergyFlow;
            out item electrical : ElectricalEnergyFlow;
        }
    }

    part def BatteryBank {
        attribute nominalVoltage : Volt = 12.0;
        attribute capacity : WattHour = 720.0;
        attribute minimumOperationalStateOfCharge : Percent = 25.0;
        attribute coldWeatherDerating : Percent = 70.0;

        port chargeIn : PowerLoadPort;
        port powerOut : PowerSourcePort;

        action storeElectricalEnergy {
            in item energy : ElectricalEnergyFlow;
        }

        action supplyElectricalEnergy {
            out item energy : ElectricalEnergyFlow;
        }
    }

    part def ChargeController {
        attribute maximumChargeCurrent : Real = 10.0;
        attribute lowVoltageDisconnectThreshold : Volt = 11.4;
        attribute reconnectThreshold : Volt = 12.2;

        port solarPowerIn : PowerLoadPort;
        port batteryPowerOut : PowerSourcePort;
        port regulatedLoadOut : PowerSourcePort;

        action regulateCharging {
            in item sourceEnergy : ElectricalEnergyFlow;
            out item batteryEnergy : ElectricalEnergyFlow;
            out item loadEnergy : ElectricalEnergyFlow;
        }
    }

    part def DataLoggerController {
        attribute stationIdentifier : String;
        attribute sampleInterval : Minute = 15.0;
        attribute transmitInterval : Minute = 60.0;
        attribute localStorageCapacityDays : Integer = 60;
        attribute clockDriftPerMonth : Second = 5.0;

        port powerIn : PowerLoadPort;
        port sweIn : SnowWaterEquivalentSensorPort;
        port depthIn : SnowDepthSensorPort;
        port temperatureIn : TemperatureSensorPort;
        port precipitationIn : PrecipitationSensorPort;
        port telemetryOut : TelemetryOutPort;
        port commandIn : CommandInPort;

        action acquireEnvironmentalMeasurements {
            in item swe : SnowWaterEquivalentReading;
            in item depth : SnowDepthReading;
            in item temperature : AirTemperatureReading;
            in item precipitation : PrecipitationReading;
            out item packet : StationTelemetryPacket;
        }

        action validateMeasurements {
            in item rawPacket : StationTelemetryPacket;
            out item checkedPacket : StationTelemetryPacket;
        }

        action storePacket {
            in item packet : StationTelemetryPacket;
        }

        action applyConfigurationCommand {
            in item command : ConfigurationCommand;
        }

        state def LoggerOperatingState {
            entry action initializeClockAndStorage;
            state initializing;
            state sleeping;
            state sampling;
            state validating;
            state storing;
            state transmitting;
            state faultHandling;

            transition first initializing then sleeping;
            transition sleeping then sampling
                accept after sampleInterval;
            transition sampling then validating;
            transition validating then storing;
            transition storing then transmitting
                if timeSinceLastTransmission >= transmitInterval;
            transition storing then sleeping
                if timeSinceLastTransmission < transmitInterval;
            transition transmitting then sleeping;
            transition sampling then faultHandling
                if anySensorStatus == SensorHealth::failed;
            transition faultHandling then sleeping;
        }

        attribute timeSinceLastTransmission : Minute;
        attribute anySensorStatus : SensorHealth;
    }

    part def RadioTelemetryUnit {
        attribute carrierFrequencyMHz : Real = 401.0;
        attribute nominalDataRate : KilobitPerSecond = 9.6;
        attribute transmitPower : Watt = 5.0;
        attribute retryLimit : Integer = 3;

        port powerIn : PowerLoadPort;
        port telemetryIn : TelemetryOutPort;
        port telemetryOut : TelemetryOutPort;
        port commandOut : CommandInPort;

        action transmitTelemetry {
            in item packet : StationTelemetryPacket;
            out item signal : RadioSignal;
        }

        action receiveCommand {
            in item signal : RadioSignal;
            out item command : ConfigurationCommand;
        }
    }

    part def AntennaAssembly {
        attribute gainDbi : Real = 6.0;
        attribute mastHeight : Meter = 3.0;

        port radioIn : TelemetryOutPort;
        port radioOut : TelemetryOutPort;
    }

    part def WeatherproofEnclosure {
        attribute ingressProtectionRating : String = "IP66";
        attribute lowOperatingTemperature : Celsius = -45.0;
        attribute highOperatingTemperature : Celsius = 45.0;

        part logger : DataLoggerController;
        part radio : RadioTelemetryUnit;
        part battery : BatteryBank;
        part chargeController : ChargeController;
    }

    part def SNOTELStation {
        doc /* A SNOTEL station is an autonomous mountain telemetry system whose primary high-level function is to measure snowpack, precipitation, and temperature conditions at a remote watershed site and transmit quality-controlled hydrologic observations for water supply forecasting and climate monitoring. */

        attribute stationIdentifier : String;
        attribute siteElevation : Meter;
        attribute latitudeDegrees : Real;
        attribute longitudeDegrees : Real;
        attribute samplingInterval : Minute = 15.0;
        attribute telemetryInterval : Minute = 60.0;
        attribute minimumAutonomyWithoutSun : Day = 14 [SI::day];

        port outboundTelemetry : TelemetryOutPort;
        port inboundCommands : CommandInPort;
        port sunlight : SolarInputPort;

        part snowPillow : SnowPillowSensor;
        part snowDepthSensor : UltrasonicSnowDepthSensor;
        part airTemperatureSensor : AirTemperatureSensor;
        part precipitationGauge : PrecipitationGauge;
        part solarPanel : SolarPanel;
        part enclosure : WeatherproofEnclosure;
        part antenna : AntennaAssembly;

        connect sunlight to solarPanel.solarIn;
        connect solarPanel.powerOut to enclosure.chargeController.solarPowerIn;
        connect enclosure.chargeController.batteryPowerOut to enclosure.battery.chargeIn;
        connect enclosure.battery.powerOut to enclosure.chargeController.solarPowerIn;
        connect enclosure.chargeController.regulatedLoadOut to enclosure.logger.powerIn;
        connect enclosure.chargeController.regulatedLoadOut to enclosure.radio.powerIn;
        connect enclosure.chargeController.regulatedLoadOut to precipitationGauge.powerIn;

        connect snowPillow.snowWaterEquivalentOut to enclosure.logger.sweIn;
        connect snowDepthSensor.snowDepthOut to enclosure.logger.depthIn;
        connect airTemperatureSensor.airTemperatureOut to enclosure.logger.temperatureIn;
        connect precipitationGauge.precipitationOut to enclosure.logger.precipitationIn;

        connect enclosure.logger.telemetryOut to enclosure.radio.telemetryIn;
        connect enclosure.radio.telemetryOut to antenna.radioIn;
        connect antenna.radioOut to outboundTelemetry;
        connect inboundCommands to enclosure.logger.commandIn;

        action performSNOTELMission {
            in item solarEnergy : SolarEnergyFlow;
            out item telemetry : RadioSignal;

            first start;
            then powerStation;
            then measureSnowpack;
            then measureWeather;
            then qualityControl;
            then packageTelemetry;
            then transmitObservations;
            then end;

            action powerStation {
                in item solarEnergy : SolarEnergyFlow;
                out item regulatedEnergy : ElectricalEnergyFlow;
            }

            action measureSnowpack {
                out item swe : SnowWaterEquivalentReading;
                out item depth : SnowDepthReading;
            }

            action measureWeather {
                out item temperature : AirTemperatureReading;
                out item precipitation : PrecipitationReading;
            }

            action qualityControl {
                in item swe : SnowWaterEquivalentReading;
                in item depth : SnowDepthReading;
                in item temperature : AirTemperatureReading;
                in item precipitation : PrecipitationReading;
                out item packet : StationTelemetryPacket;
            }

            action packageTelemetry {
                in item packet : StationTelemetryPacket;
                out item signal : RadioSignal;
            }

            action transmitObservations {
                in item signal : RadioSignal;
                out item telemetry : RadioSignal;
            }
        }
    }

    part def SNOTELDataCenter {
        attribute centerIdentifier : String;
        attribute acceptedLatency : Minute = 90.0;
        attribute archiveRetentionYears : Integer = 30;

        port telemetryIn : TelemetryOutPort;
        port commandOut : CommandInPort;

        action ingestTelemetry {
            in item signal : RadioSignal;
            out item packet : StationTelemetryPacket;
        }

        action archiveObservation {
            in item packet : StationTelemetryPacket;
        }

        action publishHydrologicObservation {
            in item packet : StationTelemetryPacket;
        }
    }

    part def SNOTELNetworkSegment {
        part remoteStation : SNOTELStation {
            attribute stationIdentifier = "SNOTEL-REMOTE-WATERSHED-001";
            attribute siteElevation = 2745.0;
            attribute latitudeDegrees = 39.742;
            attribute longitudeDegrees = -106.214;
        }

        part operationsCenter : SNOTELDataCenter {
            attribute centerIdentifier = "HydrologicTelemetryOperationsCenter";
        }

        connect remoteStation.outboundTelemetry to operationsCenter.telemetryIn;
        connect operationsCenter.commandOut to remoteStation.inboundCommands;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The SNOTEL station shall autonomously collect snowpack and meteorological observations from a remote watershed site and transmit quality-controlled telemetry to a data center for hydrologic monitoring. */

        subject station : SNOTELStation;

        require constraint {
            station.samplingInterval <= 15.0 and
            station.telemetryInterval <= 60.0
        }
    }

    requirement def SnowWaterEquivalentRequirement {
        doc /* The station shall measure snow water equivalent over the operational snowpack range with sufficient accuracy for water supply forecasting. */

        subject station : SNOTELStation;

        require constraint {
            station.snowPillow.measurementRange >= 2000.0 and
            station.snowPillow.accuracy <= 15.0
        }
    }

    requirement def SnowDepthRequirement {
        doc /* The station shall measure snow depth using a non-contact sensor. */

        subject station : SNOTELStation;

        require constraint {
            station.snowDepthSensor.measurementRange >= 4000.0 and
            station.snowDepthSensor.accuracy <= 15.0
        }
    }

    requirement def TemperatureRequirement {
        doc /* The station shall measure ambient air temperature across expected alpine winter and summer conditions. */

        subject station : SNOTELStation;

        require constraint {
            station.airTemperatureSensor.measurementRangeLow <= -40.0 and
            station.airTemperatureSensor.measurementRangeHigh >= 40.0
        }
    }

    requirement def PrecipitationRequirement {
        doc /* The station shall measure accumulated precipitation and report interval precipitation in telemetry packets. */

        subject station : SNOTELStation;

        require constraint {
            station.precipitationGauge.resolution <= 0.5 and
            station.precipitationGauge.bucketCapacity >= 500.0
        }
    }

    requirement def PowerAutonomyRequirement {
        doc /* The station shall maintain autonomous operation during extended cloudy winter conditions. */

        subject station : SNOTELStation;

        require constraint {
            station.minimumAutonomyWithoutSun >= 14 [SI::day] and
            station.enclosure.battery.capacity >= 600.0
        }
    }

    requirement def TelemetryRequirement {
        doc /* The station shall transmit validated observations to the operations center at least hourly during nominal operation. */

        subject station : SNOTELStation;

        require constraint {
            station.telemetryInterval <= 60.0 and
            station.enclosure.radio.retryLimit >= 3
        }
    }

    requirement def EnvironmentalSurvivabilityRequirement {
        doc /* The station enclosure shall protect electronics from precipitation, wind-driven snow, and alpine temperature extremes. */

        subject station : SNOTELStation;

        require constraint {
            station.enclosure.ingressProtectionRating == "IP66" and
            station.enclosure.lowOperatingTemperature <= -40.0 and
            station.enclosure.highOperatingTemperature >= 40.0
        }
    }

    satisfy PrimaryFunctionRequirement by SNOTELStation;
    satisfy SnowWaterEquivalentRequirement by SnowPillowSensor;
    satisfy SnowDepthRequirement by UltrasonicSnowDepthSensor;
    satisfy TemperatureRequirement by AirTemperatureSensor;
    satisfy PrecipitationRequirement by PrecipitationGauge;
    satisfy PowerAutonomyRequirement by BatteryBank;
    satisfy TelemetryRequirement by RadioTelemetryUnit;
    satisfy EnvironmentalSurvivabilityRequirement by WeatherproofEnclosure;
}